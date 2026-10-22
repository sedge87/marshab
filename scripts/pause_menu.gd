class_name MHPauseMenu
extends Control

# Pause screen (shot 1k): action list on the left, Controls sheet on the right
# (closed until the Controls button opens it),
# over the last frame blurred and dimmed. The tree is paused while it is open.

signal resumed
signal mission_control
signal settings
signal exit_to_menu
signal save_requested(slot: int)
signal load_requested(slot: int)

var _controls_sheet: Control
var _controls_button: Button
var _slots: HBoxContainer
var _save_status: Label
# Slot awaiting a second click to confirm overwriting an existing save.
var _confirm_slot := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(MHWidgets.BlurScrim.new())
	var list := MHStyle.vbox(12)
	list.position = Vector2(120, 0)
	list.anchor_top = 0.5
	list.anchor_bottom = 0.5
	list.offset_top = -330
	list.offset_bottom = 330
	list.offset_left = 120
	list.offset_right = 580
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(list)
	list.add_child(MHStyle.eyebrow(MHGame.colony_name, MHStyle.accent, 16))
	var heading := MHStyle.display("Paused", 72)
	heading.custom_minimum_size.y = 96
	list.add_child(heading)
	var resume := _row(list, "Resume", "primary", "play")
	resume.pressed.connect(func() -> void: resumed.emit())
	_row(list, "Mission Control", "secondary", "clipboard-check").pressed.connect(func() -> void: mission_control.emit())
	_controls_button = _row(list, "Controls", "secondary", "keyboard")
	_controls_button.pressed.connect(_toggle_controls)
	_row(list, "Settings", "secondary", "settings").pressed.connect(func() -> void: settings.emit())
	list.add_child(MHStyle.eyebrow("%s saves" % MHGame.SAVE_SETS[MHGame.save_set_for_mode(MHGame.game_mode)], MHStyle.accent, 13))
	_slots = MHStyle.hbox(6)
	list.add_child(_slots)
	_save_status = MHStyle.body("", 14, MHStyle.TEXT_MUTED)
	list.add_child(_save_status)
	_build_slots()
	_row(list, "Exit to main menu", "ghost", "log-out").pressed.connect(func() -> void: exit_to_menu.emit())
	var footer := MHStyle.mono("Offline build · %s" % MHGame.site_name(), 13, MHStyle.TEXT_MUTED)
	footer.custom_minimum_size.y = 40
	footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list.add_child(footer)
	_controls_sheet = _build_controls()
	_controls_sheet.visible = false
	add_child(_controls_sheet)
	resume.grab_focus.call_deferred()

# Rebuilt after every save so a new Load button appears straight away.
func _build_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	for slot in range(1, MHGame.SAVE_SLOT_COUNT + 1):
		var exists := bool(MHGame.save_slot_summary(slot).get("exists", false))
		var confirming := slot == _confirm_slot
		var save := MHStyle.button("Overwrite %d?" % slot if confirming else "Save %d" % slot, "danger" if confirming else "ghost", "save")
		save.tooltip_text = "Click again to replace slot %d" % slot if confirming else "Save this habitat to slot %d" % slot
		save.pressed.connect(_on_save_pressed.bind(slot, exists))
		_slots.add_child(save)
		if exists:
			var load := MHStyle.button("Load %d" % slot, "ghost", "rotate-ccw")
			load.tooltip_text = "Load the habitat in slot %d" % slot
			load.pressed.connect(load_requested.emit.bind(slot))
			_slots.add_child(load)

func _on_save_pressed(slot: int, exists: bool) -> void:
	# An existing save needs a second click, so a stray click can't lose work.
	if exists and _confirm_slot != slot:
		_confirm_slot = slot
		show_save_status("warn", "Slot %d already has a save. Click Overwrite to replace it." % slot)
		_build_slots()
		return
	_confirm_slot = 0
	save_requested.emit(slot)

## Called by the world after a save attempt; tone is "valid", "warn" or "invalid".
func show_save_status(tone: String, text: String) -> void:
	_save_status.text = text
	_save_status.add_theme_color_override("font_color", {"valid": MHStyle.VALID, "warn": MHStyle.WARN, "invalid": MHStyle.DANGER}.get(tone, MHStyle.TEXT_MUTED))
	if tone != "warn":
		_build_slots()

func _row(parent: Control, text: String, variant: String, icon_name: String) -> Button:
	var b := MHStyle.button(text, variant, icon_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	return b

func _toggle_controls() -> void:
	_controls_sheet.visible = not _controls_sheet.visible
	_controls_button.theme_type_variation = "SelectedButton" if _controls_sheet.visible else "Button"

func _build_controls() -> Control:
	var sheet := MHStyle.menu_panel(40)
	sheet.anchor_left = 0
	sheet.anchor_right = 1
	sheet.anchor_top = 0
	sheet.anchor_bottom = 1
	sheet.offset_left = 660
	sheet.offset_right = -120
	sheet.offset_top = 120
	sheet.offset_bottom = -120
	var col := MHStyle.vbox(24)
	sheet.add_child(col)
	var head := MHStyle.hbox(12)
	head.add_child(MHStyle.title("Controls", 34, 800))
	head.add_child(MHStyle.spacer())
	var kind := MHStyle.eyebrow("Keyboard + mouse")
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kind)
	col.add_child(head)
	var groups := MHStyle.hbox(24)
	groups.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for group in MHGame.CONTROLS:
		var g := MHStyle.vbox(4)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(MHStyle.eyebrow(group[0], MHStyle.accent, 14))
		for entry in group[1]: g.add_child(MHStyle.control_row(entry[0], entry[1]))
		groups.add_child(g)
	col.add_child(groups)
	col.add_child(MHStyle.body("Build-mode keys only work while the blueprint view is open (press B).", 15, MHStyle.TEXT_MUTED))
	return sheet

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resumed.emit()
