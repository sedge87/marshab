extends Control

const WORLD_SCENE := "res://scenes/mars_world.tscn"

var panel: VBoxContainer
var controls_panel: PanelContainer

func _ready() -> void:
	_build_background()
	_build_menu()

func _build_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#160d16")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var glow := ColorRect.new()
	glow.color = Color(0.60, 0.14, 0.06, 0.28)
	glow.position = Vector2(0, 0)
	glow.size = Vector2(1280, 250)
	backdrop.add_child(glow)

func _build_menu() -> void:
	panel = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -220)
	panel.size = Vector2(460, 440)
	panel.add_theme_constant_override("separation", 16)
	add_child(panel)
	var title := Label.new()
	title.text = "MARS: HABITAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#ffd5b8"))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Mission training simulation  •  Foundation build"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("#d79972"))
	panel.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36
	panel.add_child(spacer)
	_add_button("PLAY", _play)
	_add_button("CONTROLS", _show_controls)
	_add_button("QUIT", _quit)
	var footer := Label.new()
	footer.text = "A Year 9 Mission to Mars project"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("#9d7b70"))
	panel.add_child(footer)

func _add_button(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	panel.add_child(button)

func _play() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)

func _show_controls() -> void:
	if controls_panel != null:
		return
	controls_panel = PanelContainer.new()
	controls_panel.set_anchors_preset(Control.PRESET_CENTER)
	controls_panel.position = Vector2(-245, -150)
	controls_panel.size = Vector2(490, 300)
	add_child(controls_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	controls_panel.add_child(box)
	var info := Label.new()
	info.text = "CONTROLS\n\nWASD  Move across the Mars surface\nMouse  Look around\nShift  Sprint\nEscape  Release mouse and open pause menu"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 18)
	box.add_child(info)
	var close := Button.new()
	close.text = "BACK"
	close.pressed.connect(func() -> void: controls_panel.queue_free(); controls_panel = null)
	box.add_child(close)

func _quit() -> void:
	get_tree().quit()

