extends Control

## The crew journal as a book (J, or E on the notebook by your bunk; docs/
## samples-lab-journal.md §7): one sol a spread, the day's lines on the left
## and its sketches on the right, drawn in pencil (shaders/pencil_sketch.
## gdshader). Arrow keys or the buttons turn the pages; J or Esc closes.

signal closed

const PENCIL := preload("res://shaders/pencil_sketch.gdshader")
const PAPER := Color("#EDE6D6")
const INK := Color("#2E2A26")
const FAINT := Color("#8A8174")

var page := -1   # entries index; -1 opens on the newest
var _spread: HBoxContainer
var _turn: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(.02, .02, .03, .82)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := MHStyle.vbox(12)
	centre.add_child(column)
	var cover := PanelContainer.new()
	cover.add_theme_stylebox_override("panel", MHStyle.box(Color("#3B2E26"), Color("#2A201A"), 14, 2, Vector4(18, 18, 18, 18)))
	column.add_child(cover)
	_spread = MHStyle.hbox(6)
	cover.add_child(_spread)
	var bar := MHStyle.hbox(12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var previous := MHStyle.button("Earlier", "secondary", "chevron-left", 40)
	previous.pressed.connect(_turn_page.bind(-1))
	bar.add_child(previous)
	_turn = MHStyle.mono("", 14, MHStyle.TEXT_SECONDARY)
	bar.add_child(_turn)
	var later := MHStyle.button("Later", "secondary", "chevron-right", 40)
	later.pressed.connect(_turn_page.bind(1))
	bar.add_child(later)
	var close := MHStyle.button("Close  J", "secondary", "x", 40)
	close.pressed.connect(_close)
	bar.add_child(close)
	column.add_child(bar)
	page = MHJournal.entries.size() - 1 if page < 0 else page
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	var key := (event as InputEventKey).keycode
	if event.is_action_pressed("ui_cancel") or key == KEY_J: _close()
	elif key == KEY_LEFT or key == KEY_A: _turn_page(-1)
	elif key == KEY_RIGHT or key == KEY_D: _turn_page(1)
	else: return
	get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()

func _turn_page(by: int) -> void:
	page = clampi(page + by, 0, maxi(0, MHJournal.entries.size() - 1))
	_render()

func _sheet() -> VBoxContainer:
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(560, 640)
	sheet.add_theme_stylebox_override("panel", MHStyle.box(PAPER, Color("#D8CEB8"), 4, 1, Vector4(40, 36, 40, 36)))
	_spread.add_child(sheet)
	var col := MHStyle.vbox(14)
	sheet.add_child(col)
	return col

func _ink(text: String, size: int, colour := INK) -> Label:
	var label := MHStyle.body(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 480
	return label

func _render() -> void:
	for child in _spread.get_children(): child.queue_free()
	var left := _sheet()
	var right := _sheet()
	if MHJournal.entries.is_empty():
		left.add_child(_ink(MHGame.colony_name, 30))
		left.add_child(_ink("Nothing written yet. The journal fills in as the days go by.", 18, FAINT))
		_turn.text = ""
		return
	var entry: Dictionary = MHJournal.entries[page]
	_turn.text = "Sol %d · page %d of %d" % [int(entry.sol), page + 1, MHJournal.entries.size()]
	left.add_child(_ink("Sol %d" % int(entry.sol), 30))
	for line in entry.lines: left.add_child(_ink(str(line), 18))
	var sketches: Array = entry.get("sketches", [])
	if sketches.is_empty():
		right.add_child(_ink("No sketch today.", 16, FAINT))
		return
	for sketch in sketches:
		var texture := _load(str(sketch.path))
		if texture == null: continue
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(480, 270 if sketches.size() > 1 else 400)
		var material := ShaderMaterial.new()
		material.shader = PENCIL
		picture.material = material
		right.add_child(picture)
		right.add_child(_ink(str(sketch.caption), 15, FAINT))

func _load(path: String) -> Texture2D:
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
