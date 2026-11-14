extends Control

## A small working screen in the middle of the view: the lander's tiny
## printer, the suit rack (14 Nov playtest: "it'd be better if it had a
## menu"). A head (eyebrow, title, Close), a body that subclasses fill in
## _fill(), and a redraw whenever _signature() changes. The game keeps
## running while it's open; Esc or E closes it.

signal closed

var world: Node
var _body: VBoxContainer
var _shown := ""
var _refresh := 0.0

func setup(target_world: Node) -> Control:
	world = target_world
	return self

## Subclasses: the eyebrow and title, what the body shows, and when it changes.
func _eyebrow() -> String: return ""
func _title() -> String: return ""
func _fill(_into: VBoxContainer) -> void: pass
func _signature() -> String: return ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var layer := CanvasLayer.new()
	layer.layer = 28   # above notices, captions and the HUD, like the Print Shop
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(.02, .03, .04, .55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := MHStyle.hud_panel(28, true, true)
	panel.custom_minimum_size = Vector2(760, 0)
	centre.add_child(panel)
	var column := MHStyle.vbox(18)
	panel.add_child(column)
	var head := MHStyle.hbox(16)
	var titles := MHStyle.vbox(4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(MHStyle.eyebrow(_eyebrow(), MHStyle.accent))
	titles.add_child(MHStyle.title(_title(), 28))
	head.add_child(titles)
	var close := MHStyle.button("Close  Esc", "secondary", "x", 44)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	head.add_child(close)
	column.add_child(head)
	_body = MHStyle.vbox(10)
	column.add_child(_body)
	_render()

func _render() -> void:
	_shown = _signature()
	for child in _body.get_children(): child.queue_free()
	_fill(_body)

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = .25
	if _signature() != _shown: _render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

## One row: an icon, a name and a line under it, a tag, and a button.
func row(icon_name: String, name_text: String, sub: String, tag: String, tag_colour: Color, action := "", on_press := Callable(), primary := false, enabled := true) -> Control:
	var line := MHStyle.hbox(14)
	line.add_child(MHStyle.icon(icon_name, 22, MHStyle.TEXT_PRIMARY if enabled else MHStyle.TEXT_MUTED))
	var words := MHStyle.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(MHStyle.label(name_text, 18, MHStyle.TEXT_PRIMARY if enabled else MHStyle.TEXT_SECONDARY, 700))
	var under := MHStyle.body(sub, 15, MHStyle.TEXT_SECONDARY if enabled else MHStyle.TEXT_MUTED)
	under.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(under)
	line.add_child(words)
	if tag != "":
		var chip := MHStyle.mono(tag, 13, tag_colour, 700)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(chip)
	if action != "":
		var press := MHStyle.button(action, "primary" if primary else "secondary", "", 40)
		press.custom_minimum_size.x = 150
		press.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		press.disabled = not enabled
		press.focus_mode = Control.FOCUS_NONE
		if on_press.is_valid(): press.pressed.connect(func() -> void:
			on_press.call()
			_render())
		line.add_child(press)
	return line
