extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const ORIGINAL_ENVIRONMENT_SCRIPT := preload("res://scripts/original_mars_environment.gd")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/build_controller.gd")

var pause_panel: PanelContainer
var environment

func _ready() -> void:
	_build_landscape()
	_spawn_player()
	_build_hud()
	var builder := BUILD_CONTROLLER_SCRIPT.new()
	add_child(builder)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_panel == null:
			_show_pause()
		else:
			_resume()

func _material(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _mesh_instance(mesh: Mesh, material: Material, position: Vector3, scale_value := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.scale = scale_value
	add_child(instance)
	return instance

func _build_landscape() -> void:
	environment = ORIGINAL_ENVIRONMENT_SCRIPT.new()
	environment.build()
	add_child(environment)

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(6.0, 1.2, 10.0)
	player.safe_position = player.position
	player.rotation.y = deg_to_rad(-46.0)
	add_child(player)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ExploreHUD"
	add_child(canvas)
	var label := Label.new()
	label.text = "MARS: HABITAT  //  OPEN PLAINS\nWASD move • Mouse look • Shift sprint • Esc pause"
	label.position = Vector2(24, 22)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#fff0df"))
	canvas.add_child(label)

func _show_pause() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-190, -150)
	pause_panel.size = Vector2(380, 300)
	add_child(pause_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(box)
	var title := Label.new()
	title.text = "MISSION PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	for data in [["RESUME", _resume], ["CONTROLS", _pause_controls], ["RETURN TO MENU", _return_menu]]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size.y = 45
		button.pressed.connect(data[1])
		box.add_child(button)

func _resume() -> void:
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _pause_controls() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Controls"
	dialog.dialog_text = "WASD — Move / Build camera pan\nMouse — Look / place zones in Build Mode\nShift — Sprint\nSpace — Jump\nB — Build / Explore\nBuild: wheel zoom, Q/E orbit\nR — Rotate airlock door\nE — Use airlock doors\nEscape — Release mouse / pause"
	add_child(dialog)
	dialog.popup_centered()

func _return_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

