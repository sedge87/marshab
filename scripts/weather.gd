extends Node

const MHMissions := preload("res://scripts/mh_missions.gd")
const MHResources := preload("res://scripts/mh_resources.gd")

## Dust storms as the player experiences them. The habitat simulation decides
## when a storm is forecast, arrives and clears (it cuts solar either way);
## this node turns that into a warning pill under the sol clock, a toast and a
## chime at each change, the storm's sound, and, when Settings → Weather
## effects is on, a dusty sky, thick haze and blowing dust.

const FORECAST_HAZE := .2      # the sky starts to thicken in the last hours before it hits
const RAMP_PER_SECOND := .12   # how fast the haze builds and clears (real seconds)

var world: Node
var _level := 0.0
var _state := ""               # "", "calm", "forecast" or "storm"
var _sound_age := 0.0
var _layer: CanvasLayer
var _pill: PanelContainer
var _pill_label: Label
var _toast: PanelContainer
var _storm_dust: CPUParticles3D

func setup(target_world: Node) -> void:
	world = target_world
	# Missions teach with their own scripted storms in the Test, so the live
	# base only gets random storms in free play.
	if MHMissions.active(): sim().random_storms = false
	_build_hud()
	_build_storm_dust()

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
	if env != null: env.storm = _level if on else 0.0
	if _storm_dust == null: return
	var indoors: bool = env != null and (env.inside_habitat or env.cabin_dim)
	var blowing: bool = on and _level > .05 and not indoors and not world.builder.build_mode
	if _storm_dust.emitting != blowing: _storm_dust.emitting = blowing
	_storm_dust.visible = blowing or _storm_dust.emitting
	_storm_dust.speed_scale = lerpf(.6, 1.4, _level)

# ---------- warnings ----------

func _announce(state: String, eta: float, storm_left: float) -> void:
	var cut := roundi(float(MHResources.site(MHGame.site_id).get("storm_solar_cut", .6)) * 100.0)
	match state:
		"forecast":
			MHAudio.sfx("storm_alert")
			_show_toast("DUST STORM FORECAST", "Orbiters see a storm coming: it arrives in about %d hours and will cut solar power by %d%%. Charge the batteries and switch off what you don't need." % [ceili(eta), cut], MHStyle.WARN)
		"storm":
			MHAudio.sfx("storm_alert")
			_show_toast("DUST STORM", "Solar output is down %d%% for about %s. Batteries and any reactor carry the base until it clears." % [cut, _duration(storm_left)], MHStyle.DANGER)
		"calm":
			MHAudio.sfx("all_clear")
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
	var streak := QuadMesh.new()
	streak.size = Vector2(1.3, .07)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(MHStyle.DUST_200, .28)
	streak.material = material
	_storm_dust.mesh = streak
	head.add_child(_storm_dust)
