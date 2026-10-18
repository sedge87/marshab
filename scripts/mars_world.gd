extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const ORIGINAL_ENVIRONMENT_SCRIPT := preload("res://scripts/original_mars_environment.gd")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/build_controller.gd")
const INTERIOR_BUILD_CONTROLLER_SCRIPT := preload("res://scripts/interior_build_controller.gd")
const SURFACE_BUILD_CONTROLLER_SCRIPT := preload("res://scripts/surface_build_controller.gd")
const DAY_NIGHT_SCRIPT := preload("res://scripts/site_day_night.gd")
const SCOUT_ROVER_SCENE_PATH := "res://scenes/mars_scout_rover.tscn"
# Optional companion feature. Set false to remove it without touching player,
# habitat or simulation code.
const SPAWN_SCOUT_ROVER := true

var environment
var builder: BuildController
var player: CharacterBody3D
var explore_hud: MHExploreHUD
var overlay_layer: CanvasLayer
var pause_menu: MHPauseMenu
var mission_control: MHMissionControl
var dust: CPUParticles3D
var scout_rover: Node3D
var interior_builder: MHInteriorBuildController
var surface_builder: MHSurfaceBuildController
var day_night: MHSiteDayNight

func _ready() -> void:
	MHGame.set_accent(MHGame.accent_index)
	_build_landscape()
	_spawn_player()
	_spawn_scout_rover()
	builder = BUILD_CONTROLLER_SCRIPT.new()
	add_child(builder)
	builder.mission_control_requested.connect(_open_mission_control)
	builder.interior_build_requested.connect(_open_interior_build)
	builder.surface_build_requested.connect(_open_surface_build)
	interior_builder = INTERIOR_BUILD_CONTROLLER_SCRIPT.new()
	add_child(interior_builder)
	interior_builder.setup(player, builder)
	surface_builder = SURFACE_BUILD_CONTROLLER_SCRIPT.new()
	add_child(surface_builder)
	surface_builder.setup(player, builder)
	day_night = DAY_NIGHT_SCRIPT.new()
	add_child(day_night)
	day_night.setup(environment, builder)
	_restore_pending_habitat()
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

func _open_interior_build() -> void:
	if pause_menu != null or mission_control != null or interior_builder == null:
		return
	interior_builder.enter()

func _open_surface_build(id: String) -> void:
	if pause_menu != null or mission_control != null or surface_builder == null:
		return
	surface_builder.enter(id)

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

func _spawn_scout_rover() -> void:

	if not SPAWN_SCOUT_ROVER:
		return
	var rover_scene := load(SCOUT_ROVER_SCENE_PATH) as PackedScene
	if rover_scene == null:
		push_warning("Scout rover scene is unavailable; continuing without companion.")
		return
	scout_rover = rover_scene.instantiate() as Node3D
	add_child(scout_rover)
	scout_rover.global_position = player.global_position + player.global_transform.basis.z * 2.4
	scout_rover.call("setup", player)

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
	pause_menu.save_requested.connect(_save_habitat)
	pause_menu.load_requested.connect(_load_habitat)
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

# ---------- three-slot habitat saves ----------
func _save_habitat(slot: int) -> void:
	if builder == null or player == null:
		return
	var state := {
		"site_id": MHGame.site_id,
		"site_name": MHGame.site_name(),
		"colony_name": MHGame.colony_name,
		"mission_statement": MHGame.mission_statement,
		"emblem": MHGame.emblem,
		"accent_index": MHGame.accent_index,
		"builder": builder.export_habitat_state(),
		"player_position": player.global_position,
		"player_rotation_y": player.rotation.y,
		"day_night": day_night.export_state() if day_night != null else {}
	}
	if MHGame.save_habitat(slot, state) == OK:
		builder._flash_notice("valid", "Habitat saved", "Saved to slot %d." % slot)
	else:
		builder._flash_notice("invalid", "Save failed", "The habitat could not be written to slot %d." % slot)

func _load_habitat(slot: int) -> void:
	if not MHGame.prepare_habitat_load(slot):
		return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _restore_pending_habitat() -> void:
	if MHGame.pending_save_state.is_empty():
		return
	var state := MHGame.pending_save_state
	MHGame.pending_save_state = {}
	builder.restore_habitat_state(state.get("builder", {}) as Dictionary)
	player.global_position = state.get("player_position", player.global_position) as Vector3
	player.rotation.y = float(state.get("player_rotation_y", player.rotation.y))
	player.safe_position = player.global_position
	if day_night != null:
		day_night.restore_state(state.get("day_night", {}) as Dictionary)

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
