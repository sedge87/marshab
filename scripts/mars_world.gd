extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const ORIGINAL_ENVIRONMENT_SCRIPT := preload("res://scripts/original_mars_environment.gd")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/build_controller.gd")

var environment
var builder: BuildController
var player: CharacterBody3D
var explore_hud: MHExploreHUD
var overlay_layer: CanvasLayer
var pause_menu: MHPauseMenu
var mission_control: MHMissionControl
var dust: CPUParticles3D

func _ready() -> void:
	MHGame.set_accent(MHGame.accent_index)
	_build_landscape()
	_spawn_player()
	builder = BUILD_CONTROLLER_SCRIPT.new()
	add_child(builder)
	builder.mission_control_requested.connect(_open_mission_control)
	_build_hud()
	_apply_settings()
	_play_intro()
	MHAudio.music("surface")
	MHAudio.ambience("outside")
	MHAudio.build_layer(false)
	MHAudio.muffle(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu == null: _show_pause()
		else: _resume()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_open_mission_control()

# Wind outside, life-support hum once the player is inside a habitat zone.
var _space_check := 0.0
func _process(delta: float) -> void:
	_space_check -= delta
	if _space_check > 0.0: return
	_space_check = .3
	MHAudio.ambience("inside" if not builder.build_mode and builder.is_inside(player.global_position) else "outside")

func _build_landscape() -> void:
	environment = ORIGINAL_ENVIRONMENT_SCRIPT.new()
	environment.build()
	add_child(environment)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(6.0, 1.2, 10.0)
	player.safe_position = player.position
	player.rotation.y = deg_to_rad(-46.0)
	add_child(player)
	var camera := player.get_node("Head/Camera3D") as Camera3D
	camera.set_meta("first_person", true)
	# Dust motes drawn only near the camera (cheap on school laptops).
	dust = CPUParticles3D.new()
	dust.name = "NearDust"
	dust.amount = 140
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(10, 3, 10)
	dust.direction = Vector3(1, .1, .3)
	dust.spread = 25.0
	dust.gravity = Vector3(0, -.02, 0)
	dust.initial_velocity_min = .15
	dust.initial_velocity_max = .5
	var mote := QuadMesh.new()
	mote.size = Vector2(.018, .018)
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.albedo_color = Color(MHStyle.DUST_200, .3)
	mote.material = mote_material
	dust.mesh = mote
	player.get_node("Head").add_child(dust)

func _build_hud() -> void:
	explore_hud = MHExploreHUD.new()
	explore_hud.setup(player, builder)
	add_child(explore_hud)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

func _apply_settings() -> void:
	MHGame.apply_settings(get_viewport(), environment.world_environment.environment, environment.sun, [player.get_node("Head/Camera3D")])
	dust.emitting = bool(MHGame.setting("dust"))
	dust.visible = dust.emitting

# ---------- overlays ----------
func _open_mission_control() -> void:
	if mission_control != null: return
	if pause_menu != null: _close_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	MHAudio.muffle(true)
	mission_control = MHMissionControl.new().setup(builder)
	mission_control.closed.connect(func() -> void:
		mission_control = null
		_unpause())
	overlay_layer.add_child(mission_control)

func _show_pause() -> void:
	if mission_control != null: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	MHAudio.muffle(true)
	MHAudio.sfx("ui_back", 0.0, 0.0)
	pause_menu = MHPauseMenu.new()
	pause_menu.resumed.connect(_resume)
	pause_menu.mission_control.connect(_open_mission_control)
	pause_menu.settings.connect(_open_settings)
	pause_menu.exit_to_menu.connect(_return_menu)
	overlay_layer.add_child(pause_menu)

func _open_settings() -> void:
	var panel := MHSettingsPanel.new()
	panel.applied.connect(_apply_settings)
	pause_menu.add_child(panel)

func _close_pause() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null

func _resume() -> void:
	_close_pause()
	_unpause()

func _unpause() -> void:
	get_tree().paused = false
	MHAudio.muffle(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if builder.build_mode else Input.MOUSE_MODE_CAPTURED

func _return_menu() -> void:
	get_tree().paused = false
	MHAudio.muffle(false)
	MHAudio.build_layer(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

# Letterbox bars from the landing screen animate away into first person (360 ms).
func _play_intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var bars := []
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = MHStyle.INK_950
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1
		if top:
			bar.offset_bottom = 104
		else:
			bar.anchor_top = 1
			bar.anchor_bottom = 1
			bar.offset_top = -150
		layer.add_child(bar)
		bars.append(bar)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bars[0], "position:y", -110.0, .36).set_delay(.35)
	tween.tween_property(bars[1], "position:y", get_viewport().get_visible_rect().size.y + 10.0, .36).set_delay(.35)
	tween.chain().tween_callback(layer.queue_free)
