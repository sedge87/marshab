extends Node

## Your body (docs/systems-and-items.md §2, §14 step 1): the place you're in
## acts on you, shown, not told. Step 1 reads the lander cabin (the new core,
## scripts/lander_cabin_life.gd) and the habitat (the old sim's temperature
## and air until its rooms move across). Outside, the suit has its own cues.
##
## | State      | You see, hear and feel                                   | Ignored                     |
## |------------|----------------------------------------------------------|-----------------------------|
## | Cold       | breath fogs, frosted edges, hands shake, sound goes dull, slower | only long, deep cold costs health |
## | Stale air  | a throbbing headache at the screen's edge                | above 3 % CO₂ health falls   |
## | Low O₂     | grey creeping in from the edges, slower                  | below 17 % health falls fast |
##
## At zero health you collapse and wake hours later where you fell, weak,
## with the problem still there (GAR-Y's rescue comes in step 7). It never
## costs the save. The comfort setting (Settings, On screen, Body cues) tones
## the cues down; it never changes the harm.

const COMFORT := {"full": 1.0, "soft": .6, "low": .3}
const COLLAPSE_HOURS := 4.0
const WAKE_HEALTH := 25.0
const SPEED := 120.0             # clock speed while you're out (as when asleep)

var world: Node
var health := 100.0
var cold := 0.0                  # 0–1 cue strengths (before the comfort setting)
var stale := 0.0
var hypoxia := 0.0
var causes: Array = []           # what's hurting you now
var collapsed := false
var _last_hour := -1.0
var _out_for := 0.0
var _layer: CanvasLayer
var _veil: ColorRect
var _veil_mat: ShaderMaterial
var _dark: ColorRect
var _breath: CPUParticles3D
var _breath_wait := 0.0
var _trembling := false
var _filter_bus := -1
var _filter_index := -1
var _clock := 0.0

const VEIL_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float cold = 0.0;
uniform float stale = 0.0;
uniform float hypoxia = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen, uv).rgb;
	float edge = clamp(length(uv - vec2(.5)) * 1.55, 0.0, 1.0);
	// Low O2: colour drains from the edges inwards, and they darken.
	float grey = smoothstep(.95 - hypoxia * .85, 1.0, edge) * hypoxia;
	float lum = dot(c, vec3(.299, .587, .114));
	c = mix(c, vec3(lum) * .55, clamp(grey * 1.4, 0.0, 1.0));
	// Stale air: a dark red throb at the edge.
	float ache = smoothstep(.55, 1.0, edge) * stale * (.55 + .45 * pulse);
	c = mix(c, vec3(.18, .02, .02), ache * .7);
	// Cold: a frosted blue-white rim.
	float frost = smoothstep(.7 - cold * .25, 1.0, edge) * cold;
	c = mix(c, vec3(.78, .86, .95), frost * .55);
	COLOR = vec4(c, 1.0);
}
"""

func setup(target_world: Node, state: Dictionary = {}) -> void:
	world = target_world
	name = "Body"
	add_to_group("body")
	process_mode = Node.PROCESS_MODE_ALWAYS
	health = clampf(float(state.get("health", 100.0)), 0.0, 100.0)
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VEIL_SHADER
	_veil_mat = ShaderMaterial.new()
	_veil_mat.shader = shader
	_veil.material = _veil_mat
	_veil.visible = false
	_layer.add_child(_veil)

func comfort() -> float:
	return float(COMFORT.get(str(MHGame.setting("body_cues")), 1.0))

## What the air around you is like, or {} where the body isn't acted on
## (outside, the rover, or modes without the simulation).
func surroundings() -> Dictionary:
	if not MHGame.simulation_on() or world.player == null: return {}
	var cabin: Node = world.get("cabin_life")
	if cabin != null and cabin.running() and cabin.player_inside() and cabin.breathable(): return cabin.conditions()
	var builder: Node = world.builder
	if builder != null and not builder.build_mode and builder.is_inside(world.player.global_position):
		var sim: RefCounted = builder.simulation()
		if int(sim.inventory().get("cells", 0)) > 0:
			return {"temp_c": float(sim.habitat_temp), "o2_pct": float(sim.o2_pct), "co2_pct": float(sim.co2_pct), "powered": true, "lit": true}
	return {}

## Cue strengths from the air you're in: 0–1 each.
static func cues_for(air: Dictionary) -> Dictionary:
	if air.is_empty(): return {"cold": 0.0, "stale": 0.0, "hypoxia": 0.0}
	return {"cold": clampf((14.0 - float(air.temp_c)) / 16.0, 0.0, 1.0),
		"stale": clampf((float(air.co2_pct) - .5) / 2.0, 0.0, 1.0),
		"hypoxia": clampf((19.5 - float(air.o2_pct)) / 4.0, 0.0, 1.0)}

## Health lost (positive) or regained (negative) per game hour, and why.
static func harm_for(air: Dictionary) -> Dictionary:
	if air.is_empty(): return {"rate": -4.0, "causes": []}
	var rate := 0.0
	var why: Array = []
	var co2 := float(air.co2_pct)
	var o2 := float(air.o2_pct)
	var t := float(air.temp_c)
	if co2 >= 3.0:
		rate += 12.0 + (co2 - 3.0) * 6.0
		why.append("stale air")
	if o2 < 17.0:
		rate += 25.0 + (17.0 - o2) * 8.0
		why.append("too little oxygen")
	if t < 0.0:
		rate += 2.0 if t > -10.0 else 6.0
		why.append("cold")
	return {"rate": rate if rate > 0.0 else -4.0, "causes": why}

func _process(delta: float) -> void:
	_clock += delta
	var hour := MHGame.sol_hour
	var hours := fposmod(hour - _last_hour, 24.0) if _last_hour >= 0.0 else 0.0
	_last_hour = hour
	if collapsed:
		_out_for += hours
		if _out_for >= COLLAPSE_HOURS: _wake()
		return
	if get_tree().paused: return
	var air := surroundings()
	var cue := cues_for(air)
	cold = move_toward(cold, float(cue.cold), delta * .5)
	stale = move_toward(stale, float(cue.stale), delta * .3)
	hypoxia = move_toward(hypoxia, float(cue.hypoxia), delta * .4)
	var harm := harm_for(air)
	# No water for long enough (the lander's tank, scripts/survival_core.gd).
	var cabin: Node = world.get("cabin_life")
	if cabin != null and cabin.running() and bool(cabin.core.thirsty()):
		harm = {"rate": maxf(float(harm.rate), 0.0) + 3.0, "causes": (harm.causes as Array) + ["thirst"]}
	causes = harm.causes
	if MHGame.crew_can_be_harmed() and hours > 0.0 and hours < 6.0:
		health = clampf(health - float(harm.rate) * hours, 0.0, 100.0)
		if health <= 0.0 and not causes.is_empty(): _collapse()
	_show(delta, air)

## Speed while you walk: cold and low oxygen slow you.
func speed_factor() -> float:
	return clampf(1.0 - .3 * cold - .3 * hypoxia - .3 * (1.0 - health / 100.0) * float(health < 50.0), .45, 1.0)

func _show(delta: float, air: Dictionary) -> void:
	var k := comfort()
	var player: Node = world.player
	if player != null: player.set_meta("body_speed", speed_factor())
	var any := cold + stale + hypoxia > .01
	_veil.visible = any
	if any:
		_veil_mat.set_shader_parameter("cold", cold * k)
		_veil_mat.set_shader_parameter("stale", stale * k)
		_veil_mat.set_shader_parameter("hypoxia", hypoxia * k)
		_veil_mat.set_shader_parameter("pulse", .5 + .5 * sin(_clock * 2.4))
	var camera := _camera()
	# Shaking hands: a small tremble of the view in the cold.
	if camera != null:
		if cold > .25:
			var s := (cold - .25) * .006 * k
			camera.h_offset = randf_range(-s, s)
			camera.v_offset = randf_range(-s, s)
			_trembling = true
		elif _trembling:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
			_trembling = false
	# Your breath fogs when it's cold enough.
	if camera != null and not air.is_empty() and float(air.temp_c) < 6.0:
		if _breath == null: _make_breath(camera)
		_breath_wait -= delta
		if _breath_wait <= 0.0:
			_breath_wait = randf_range(2.8, 3.6)
			_breath.amount = maxi(4, roundi(10.0 * k))
			_breath.restart()
	# Sound goes duller in the cold and when you're short of oxygen.
	_muffle(clampf(cold * .6 + hypoxia * .5, 0.0, 1.0) * k)

func _camera() -> Camera3D:
	return world.player.get_node_or_null("Head/Camera3D") as Camera3D if world.player != null else null

func _make_breath(camera: Camera3D) -> void:
	_breath = CPUParticles3D.new()
	_breath.name = "Breath"
	_breath.one_shot = true
	_breath.emitting = false
	_breath.amount = 10
	_breath.lifetime = 1.6
	_breath.explosiveness = .7
	_breath.local_coords = false
	_breath.direction = Vector3(0, .25, -1)
	_breath.spread = 18.0
	_breath.initial_velocity_min = .25
	_breath.initial_velocity_max = .45
	_breath.gravity = Vector3(0, .06, 0)
	_breath.scale_amount_min = .08
	_breath.scale_amount_max = .14
	var grow := Curve.new()
	grow.add_point(Vector2(0, .4)); grow.add_point(Vector2(1, 1.6))
	_breath.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, .22)); fade.set_color(1, Color(1, 1, 1, 0))
	_breath.color_ramp = fade
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(.92, .94, .97)
	quad.material = mat
	_breath.mesh = quad
	_breath.position = Vector3(0, -.12, -.3)
	camera.add_child(_breath)

func _muffle(amount: float) -> void:
	if _filter_bus < 0:
		if amount <= .01: return
		_filter_bus = AudioServer.get_bus_index("Master")
		var filter := AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(_filter_bus, filter)
		_filter_index = AudioServer.get_bus_effect_count(_filter_bus) - 1
	var filter := AudioServer.get_bus_effect(_filter_bus, _filter_index) as AudioEffectLowPassFilter
	if filter == null: return
	AudioServer.set_bus_effect_enabled(_filter_bus, _filter_index, amount > .01)
	filter.cutoff_hz = lerpf(18000.0, 1400.0, amount)

# ---------- collapse ----------

func _collapse() -> void:
	collapsed = true
	_out_for = 0.0
	var sleep: Node = world.get("sleep")
	if sleep != null and bool(sleep.asleep): sleep.wake("alert")
	world.player.set_meta("ui_freeze", true)
	_dark = ColorRect.new()
	_dark.color = Color(0, 0, 0, 0)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.layer = 41
	_layer.add_child(_dark)
	var tween := create_tween()
	tween.tween_property(_dark, "color:a", 1.0, 1.4)
	tween.tween_callback(func() -> void: if collapsed and world.day_night != null: world.day_night.time_scale = SPEED)

func _wake() -> void:
	collapsed = false
	health = maxf(health, WAKE_HEALTH)
	if world.day_night != null: world.day_night.time_scale = 1.0
	world.player.set_meta("ui_freeze", false)
	_layer.layer = 4
	var why := ", ".join(causes) if not causes.is_empty() else "it"
	if world.get("weather") != null:
		world.weather.toast("You came round, hours later", "Weak, on the floor where you fell. The cause is still here: %s." % why, MHStyle.DANGER)
	var dark := _dark
	_dark = null
	var tween := create_tween()
	tween.tween_property(dark, "color:a", 0.0, 1.6)
	tween.tween_callback(dark.queue_free)

func export_state() -> Dictionary:
	return {"health": health}
