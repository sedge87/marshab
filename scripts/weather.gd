extends Node

const MHMissions := preload("res://scripts/mh_missions.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const WEATHER_WEAR := preload("res://scripts/weather_wear.gd")

## Dust storms as the player experiences them. The habitat simulation decides
## when a storm is forecast, arrives and clears (it cuts solar either way);
## this node turns that into a warning pill under the sol clock, a toast and a
## chime at each change, the storm's sound, and, when Settings → Weather
## effects is on: a wall of dust rising on the horizon while it's forecast,
## then closing in all round; thick haze; big billows of dust rolling past;
## and fine wisps streaming by.

const FORECAST_HAZE := .2      # the sky starts to thicken in the last hours before it hits
const RAMP_PER_SECOND := .12   # how fast the haze builds and clears (real seconds)

var world: Node
var _level := 0.0
var _haze := 0.0               # the haze actually shown (none indoors)
var _state := ""               # "", "calm", "forecast" or "storm"
var _sound_age := 0.0
var _layer: CanvasLayer
var _pill: PanelContainer
var _pill_label: Label
var _toast: PanelContainer
var _storm_dust: CPUParticles3D
var _billows: CPUParticles3D
var _wall: MeshInstance3D
var _wall_amount := 0.0
var _wall_angle := 0.0          # where the storm comes from (radians)
var _wall_ring := 0.0           # 0: only on its side of the sky, 1: all round

func setup(target_world: Node) -> void:
	world = target_world
	# Missions teach with their own scripted storms in the Test, so the live
	# base only gets random storms in free play.
	if MHMissions.active(): sim().random_storms = false
	# Dust and frost on the panels and hull (weather_wear.gd): free play, and
	# Missions once storms arrive (Mission 5).
	sim().weather_wear = WEATHER_WEAR.enabled()
	_build_hud()
	_build_storm_dust()
	_build_billows()
	_build_wall()

func sim() -> RefCounted:
	return world.builder.simulation()

func effects_on() -> bool:
	return bool(MHGame.setting("weather"))

# ---------- each frame ----------

func _process(delta: float) -> void:
	if world == null: return
	var simulation := sim()
	var storm_left := float(simulation.storm_hours_left)
	var eta := float(simulation.storm_eta_hours)
	var state := "storm" if storm_left > 0.0 else ("forecast" if eta >= 0.0 else "calm")
	if state != _state:
		if not _state.is_empty(): _announce(state, eta, storm_left)
		if state == "forecast": _wall_angle = randf() * TAU
		_state = state
	var target := 1.0 if state == "storm" else (FORECAST_HAZE * clampf(1.0 - eta / 2.0, 0.0, 1.0) if state == "forecast" else 0.0)
	_level = move_toward(_level, target, RAMP_PER_SECOND * delta)
	_update_pill(state, eta, storm_left)
	_apply_visuals()
	_sound_age += delta
	if _sound_age > .2:
		_sound_age = 0.0
		MHAudio.weather(_level)

func _apply_visuals() -> void:
	var on := effects_on()
	var env = world.environment
	# Indoors the storm stays outside the walls but shows through the windows:
	# the environment switches to fog that only starts a few metres away, and
	# the dust blows past in a ring well beyond the room.
	var indoors: bool = env != null and (env.inside_habitat or env.cabin_dim or world.builder.is_inside(world.player.global_position))
	var haze_target := _level if on else 0.0
	_haze = move_toward(_haze, haze_target, get_process_delta_time() * (.4 if haze_target > _haze else 1.6))
	if not on: _haze = 0.0
	if env != null: env.storm = _haze
	_update_wall(on)
	if _storm_dust == null: return
	var blowing: bool = on and _level > .05 and not world.builder.build_mode
	if _storm_dust.emitting != blowing: _storm_dust.emitting = blowing
	_set_ring(_storm_dust, indoors, Vector3(9, 3, 9))
	_storm_dust.visible = blowing or _storm_dust.emitting
	_storm_dust.speed_scale = lerpf(.6, 1.4, _level)
	if _billows != null:
		var rolling: bool = on and _level > .35 and not world.builder.build_mode
		if _billows.emitting != rolling: _billows.emitting = rolling
		_billows.visible = rolling or _billows.emitting
		_set_ring(_billows, indoors, Vector3(28, 3, 28))
		_billows.speed_scale = lerpf(.7, 1.3, _level)

## The dust front: a ring of billowing dust on the horizon. While a storm is
## forecast it rises on the storm's side of the sky as it gets closer; once it
## arrives it closes in all round, and it sinks away as the storm clears.
func _update_wall(on: bool) -> void:
	if _wall == null: return
	var simulation := sim()
	var eta := float(simulation.storm_eta_hours)
	var target := 0.0
	if float(simulation.storm_hours_left) > 0.0: target = .85
	elif eta >= 0.0: target = clampf(1.0 - eta / 10.0, .15, 1.0)
	_wall_amount = move_toward(_wall_amount, target if on else 0.0, get_process_delta_time() * .08)
	_wall_ring = move_toward(_wall_ring, 1.0 if float(simulation.storm_hours_left) > 0.0 else 0.0, get_process_delta_time() * .05)
	_wall.visible = _wall_amount > .01 and not world.builder.build_mode
	if not _wall.visible: return
	var camera := world.get_viewport().get_camera_3d()
	if camera != null: _wall.global_position = Vector3(camera.global_position.x, camera.global_position.y - 25.0, camera.global_position.z)
	var material := _wall.material_override as ShaderMaterial
	material.set_shader_parameter("amount", _wall_amount)
	material.set_shader_parameter("from_angle", _wall_angle)
	material.set_shader_parameter("ring", _wall_ring)

## Indoors, particles spawn in a ring outside (9-24 m away) instead of round you.
static func _set_ring(particles: CPUParticles3D, indoors: bool, box: Vector3) -> void:
	if indoors and particles.emission_shape != CPUParticles3D.EMISSION_SHAPE_RING:
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		particles.emission_ring_axis = Vector3.UP
		particles.emission_ring_radius = 24.0
		particles.emission_ring_inner_radius = 9.0
		particles.emission_ring_height = box.y * 2.0
	elif not indoors and particles.emission_shape != CPUParticles3D.EMISSION_SHAPE_BOX:
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		particles.emission_box_extents = box

# ---------- warnings ----------

func _announce(state: String, eta: float, storm_left: float) -> void:
	var cut := roundi((float(sim().solar_cut()) if float(sim().storm_hours_left) > 0.0 else float(MHResources.site(MHGame.site_id).get("storm_solar_cut", .6))) * 100.0)
	match state:
		"forecast":
			MHAudio.sfx("storm_alert")
			MHAudio.voice("storm_forecast")
			_show_toast("DUST STORM FORECAST", "Orbiters see a storm coming: it arrives in about %d hours and will cut solar power by %d%%. Charge the batteries and switch off what you don't need." % [ceili(eta), cut], MHStyle.WARN)
		"storm":
			MHAudio.sfx("storm_alert")
			MHAudio.voice("storm_arrived")
			_show_toast("DUST STORM", "Solar output is down %d%% for about %s. Batteries and any reactor carry the base until it clears." % [cut, _duration(storm_left)], MHStyle.DANGER)
		"calm":
			MHAudio.sfx("all_clear")
			MHAudio.voice("storm_cleared")
			_show_toast("STORM CLEARED", "The sky is clearing and the solar arrays are back to full output.", MHStyle.VALID)

func _duration(hours: float) -> String:
	return "%d hours" % ceili(hours) if hours < 24.0 else "%.1f sols" % (hours / 24.0)

func _update_pill(state: String, eta: float, storm_left: float) -> void:
	var hud = world.explore_hud
	var show: bool = state != "calm" and hud != null and hud.visible and not bool(hud.get("_minimal"))
	_pill.visible = show
	if not show: return
	var tone: Color = MHStyle.DANGER if state == "storm" else MHStyle.WARN
	_pill_label.text = ("DUST STORM · %s LEFT" % _duration(storm_left).to_upper()) if state == "storm" else ("STORM IN %s" % _duration(eta).to_upper())
	_pill_label.add_theme_color_override("font_color", tone)
	_pill.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 14, 1, Vector4(12, 4, 14, 4)))

# ---------- HUD pieces ----------

func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHStyle.theme()
	_layer.add_child(root)
	var band := CenterContainer.new()
	band.anchor_right = 1
	band.offset_top = 148
	band.offset_bottom = 176
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := MHStyle.hbox(6)
	var icon := TextureRect.new()
	icon.texture = MHIcons.texture("wind", 14)
	icon.custom_minimum_size = Vector2(14, 14)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = MHStyle.WARN
	row.add_child(icon)
	_pill_label = MHStyle.mono("", 12, MHStyle.WARN, 700)
	row.add_child(_pill_label)
	_pill.add_child(row)
	_pill.visible = false
	band.add_child(_pill)

## A short toast under the sol clock (also used by GAR-Y).
func toast(title: String, text: String, tone: Color = MHStyle.INFO) -> void:
	_show_toast(title, text, tone)

func _show_toast(title: String, text: String, tone: Color) -> void:
	if _toast != null and is_instance_valid(_toast): _toast.queue_free()
	_toast = PanelContainer.new()
	_toast.anchor_left = .5
	_toast.anchor_right = .5
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 186
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 8, 1, Vector4(18, 12, 18, 14)))
	var col := MHStyle.vbox(4)
	col.add_child(MHStyle.eyebrow(title, tone, 13))
	var body := MHStyle.body(text, 15, MHStyle.TEXT_PRIMARY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 560
	col.add_child(body)
	_toast.add_child(col)
	_layer.get_child(0).add_child(_toast)
	var shown := _toast
	var tween := create_tween()
	shown.modulate.a = 0.0
	tween.tween_property(shown, "modulate:a", 1.0, .3)
	tween.tween_interval(8.0)
	tween.tween_property(shown, "modulate:a", 0.0, .8)
	tween.tween_callback(shown.queue_free)

## Sheets of blowing dust around the camera (outdoors, effects on).
func _build_storm_dust() -> void:
	var head: Node3D = world.player.get_node_or_null("Head")
	if head == null: return
	_storm_dust = CPUParticles3D.new()
	_storm_dust.name = "StormDust"
	_storm_dust.amount = 700
	_storm_dust.lifetime = 1.6
	_storm_dust.local_coords = false
	_storm_dust.emitting = false
	_storm_dust.visible = false
	_storm_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_storm_dust.emission_box_extents = Vector3(9, 3, 9)
	_storm_dust.direction = Vector3(1, .05, .35)
	_storm_dust.spread = 12.0
	_storm_dust.gravity = Vector3(0, -.4, 0)
	_storm_dust.initial_velocity_min = 9.0
	_storm_dust.initial_velocity_max = 15.0
	_storm_dust.scale_amount_min = .6
	_storm_dust.scale_amount_max = 1.8
	_storm_dust.amount = 500
	_storm_dust.color_ramp = _fade_ramp()
	var streak := QuadMesh.new()
	streak.size = Vector2(1.6, .16)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(.86, .64, .46, .32)
	material.albedo_texture = soft_streak()
	streak.material = material
	_storm_dust.mesh = streak
	head.add_child(_storm_dust)

## Big soft clouds of dust rolling past, 5 to 30 m away: what makes a storm
## feel thick rather than just hazy.
func _build_billows() -> void:
	var head: Node3D = world.player.get_node_or_null("Head")
	if head == null: return
	_billows = CPUParticles3D.new()
	_billows.name = "StormBillows"
	_billows.amount = 46
	_billows.lifetime = 7.0
	_billows.local_coords = false
	_billows.emitting = false
	_billows.visible = false
	_billows.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_billows.emission_box_extents = Vector3(28, 3, 28)
	_billows.direction = Vector3(1, .02, .35)
	_billows.spread = 15.0
	_billows.gravity = Vector3.ZERO
	_billows.initial_velocity_min = 5.0
	_billows.initial_velocity_max = 9.0
	_billows.angle_min = -180.0
	_billows.angle_max = 180.0
	_billows.angular_velocity_min = -8.0
	_billows.angular_velocity_max = 8.0
	_billows.scale_amount_min = 7.0
	_billows.scale_amount_max = 15.0
	_billows.color_ramp = _fade_ramp()
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	# A shade darker than the haze, so the billows read against it.
	material.albedo_color = Color(.6, .4, .28, .5)
	material.albedo_texture = billow()
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = 3.0
	quad.material = material
	_billows.mesh = quad
	head.add_child(_billows)

const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float amount = 0.0;
uniform float from_angle = 0.0;
uniform float ring = 0.0;
varying vec3 lpos;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float t = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { t += a * vnoise(p); p *= 2.07; a *= 0.5; } return t; }
void vertex() { lpos = VERTEX; }
void fragment() {
	float angle = atan(lpos.x, lpos.z);
	float h = UV.y;   // 0 at the foot, 1 at the top of the ring
	// Billows rolling and boiling upward along the front.
	vec2 p = vec2(angle * 9.0, (1.0 - h) * 3.0);
	float n = fbm(p + vec2(TIME * 0.02, -TIME * 0.05));
	n = n * 0.7 + fbm(p * 2.3 + vec2(-TIME * 0.04, -TIME * 0.09)) * 0.3;
	// Its side of the sky while forecast; all round once it's here.
	float side = smoothstep(1.6, 0.4, abs(mod(angle - from_angle + 3.14159, 6.28318) - 3.14159));
	float where = mix(side, 1.0, ring);
	// The top of the front climbs as the storm closes in, lumpy with billows.
	float top = mix(0.05, 0.85, amount * where) + (n - 0.5) * 0.3;
	float body = 1.0 - smoothstep(top - 0.12, top + 0.04, h);
	vec3 light = vec3(0.84, 0.62, 0.44);
	vec3 shade = vec3(0.42, 0.28, 0.2);
	// Sunlit billow tops, darker underneath and low down.
	ALBEDO = mix(shade, light, clamp(smoothstep(0.3, 0.75, n) * 0.8 + h * 0.6, 0.0, 1.0));
	ALPHA = clamp(body * where * amount * (0.65 + n * 0.5), 0.0, 1.0);
}
"""

func _build_wall() -> void:
	_wall = MeshInstance3D.new()
	_wall.name = "StormFront"
	# A plain ring, 300 m out and 160 m tall, with UV.y running foot to top.
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var segments := 72
	for i in range(segments):
		for corner in [[i, 0.0], [i + 1, 0.0], [i + 1, 1.0], [i, 0.0], [i + 1, 1.0], [i, 1.0]]:
			var a := float(corner[0]) / segments * TAU
			points.append(Vector3(sin(a) * 300.0, float(corner[1]) * 160.0, cos(a) * 300.0))
			uvs.append(Vector2(float(corner[0]) / segments, float(corner[1])))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-310, -10, -310), Vector3(620, 180, 620))
	_wall.mesh = mesh
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = WALL_SHADER
	_wall.material_override = material
	_wall.visible = false
	world.add_child.call_deferred(_wall)

## Particles fade in and out over their life (no popping).
static func _fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, .2, .75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return ramp

static var _streak_texture: ImageTexture
static var _billow_texture: ImageTexture

## A wisp: soft all round, tapering at both ends.
static func soft_streak() -> ImageTexture:
	if _streak_texture != null: return _streak_texture
	var image := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 16:
			var u := float(x) / 63.0
			var v := (float(y) - 7.5) / 7.5
			var a := sin(u * PI) * exp(-v * v * 3.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	_streak_texture = ImageTexture.create_from_image(image)
	return _streak_texture

## A cloud of dust: lumpy noise inside a soft round edge.
static func billow() -> ImageTexture:
	if _billow_texture != null: return _billow_texture
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = .035
	noise.fractal_octaves = 4
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for x in 128:
		for y in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var n := noise.get_noise_2d(x, y) * .5 + .5
			var a := clampf((1.0 - smoothstep(.35, 1.0, d)) * smoothstep(.25, .7, n) * 1.4, 0.0, 1.0)
			var shade := lerpf(.8, 1.0, n)
			image.set_pixel(x, y, Color(shade, shade, shade, a))
	_billow_texture = ImageTexture.create_from_image(image)
	return _billow_texture
