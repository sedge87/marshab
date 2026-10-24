class_name MHPauseMenu
extends Control

# Pause screen: a short action list on the left; Save & load and Controls
# open in the panel on the right (one at a time), over the last frame blurred
# and dimmed. The Field guide opens over everything. The tree is paused
# while it is open. (Reorganised 25 Oct: the save buttons moved off the main
# list into slot cards that say what's in each slot.)

signal resumed
signal mission_control
signal settings
signal exit_to_menu
signal save_requested(slot: int)
signal load_requested(slot: int)

const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")

var _panels := {}                  # name -> Control (the right-hand panel)
var _panel_buttons := {}           # name -> Button
var _slots: VBoxContainer
var _save_status: Label
# Slot awaiting a second click to confirm overwriting an existing save.
var _confirm_slot := 0
var _guide: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(MHWidgets.BlurScrim.new())
	var list := MHStyle.vbox(12)
	list.anchor_top = 0.5
	list.anchor_bottom = 0.5
	list.offset_top = -330
	list.offset_bottom = 330
	list.offset_left = 120
	list.offset_right = 540
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(list)
	list.add_child(MHStyle.eyebrow(MHGame.colony_name, MHStyle.accent, 16))
	var heading := MHStyle.display("Paused", 72)
	heading.custom_minimum_size.y = 96
	list.add_child(heading)
	var resume := _row(list, "Resume", "primary", "play", "Esc")
	resume.pressed.connect(func() -> void: resumed.emit())
	_panel_buttons["saves"] = _row(list, "Save & load", "secondary", "save")
	_panel_buttons.saves.pressed.connect(_toggle_panel.bind("saves"))
	var guide := _row(list, "Field guide", "secondary", "book-open")
	guide.tooltip_text = "Every How it works card, by section, and the switch for pop-up cards"
	guide.pressed.connect(func() -> void:
		_guide = HOW_IT_WORKS.guide(get_tree())
		add_child(_guide))
	_panel_buttons["controls"] = _row(list, "Controls", "secondary", "keyboard")
	_panel_buttons.controls.pressed.connect(_toggle_panel.bind("controls"))
	_row(list, "Settings", "secondary", "settings").pressed.connect(func() -> void: settings.emit())
	_row(list, "Mission Control", "secondary", "clipboard-check", "M").pressed.connect(func() -> void: mission_control.emit())
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	list.add_child(gap)
	_row(list, "Exit to main menu", "ghost", "log-out").pressed.connect(func() -> void: exit_to_menu.emit())
	var footer := MHStyle.mono("%s · %s" % [MHGame.site_name(), MHGame.GAME_MODES.get(MHGame.game_mode, "Missions")], 13, MHStyle.TEXT_MUTED)
	footer.custom_minimum_size.y = 36
	footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list.add_child(footer)
	_panels["saves"] = _build_saves()
	_panels["controls"] = _build_controls()
	for panel in _panels.values():
		panel.visible = false
		add_child(panel)
	resume.grab_focus.call_deferred()

## A list button; key shows the keycap for its shortcut on the right.
func _row(parent: Control, text: String, variant: String, icon_name: String, key := "") -> Button:
	var b := MHStyle.button(text, variant, icon_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	if not key.is_empty():
		var cap := MHStyle.keycap(key, true)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.anchor_left = 1; cap.anchor_right = 1; cap.anchor_top = .5; cap.anchor_bottom = .5
		cap.offset_left = -64; cap.offset_right = -16; cap.offset_top = -14; cap.offset_bottom = 14
		b.add_child(cap)
	return b

## One right-hand panel at a time; pressing its button again closes it.
func _toggle_panel(name: String) -> void:
	var opening := not (_panels[name] as Control).visible
	for key in _panels:
		(_panels[key] as Control).visible = opening and key == name
		(_panel_buttons[key] as Button).theme_type_variation = "SelectedButton" if opening and key == name else "Button"
	if opening and name == "saves": _build_slots()

func _sheet() -> PanelContainer:
	var sheet := MHStyle.menu_panel(40)
	sheet.anchor_left = 0
	sheet.anchor_right = 1
	sheet.anchor_top = 0
	sheet.anchor_bottom = 1
	sheet.offset_left = 620
	sheet.offset_right = -120
	sheet.offset_top = 120
	sheet.offset_bottom = -120
	return sheet

func _sheet_head(col: VBoxContainer, title: String, note: String) -> void:
	var head := MHStyle.hbox(12)
	head.add_child(MHStyle.title(title, 34, 800))
	head.add_child(MHStyle.spacer())
	var kind := MHStyle.eyebrow(note)
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kind)
	col.add_child(head)

# ---------- save & load ----------

func _build_saves() -> Control:
	var sheet := _sheet()
	var col := MHStyle.vbox(18)
	sheet.add_child(col)
	_sheet_head(col, "Save & load", "%s saves" % MHGame.SAVE_SETS[MHGame.save_set_for_mode(MHGame.game_mode)])
	_slots = MHStyle.vbox(8)
	col.add_child(_slots)
	_save_status = MHStyle.body("", 15, MHStyle.TEXT_MUTED)
	col.add_child(_save_status)
	col.add_child(MHStyle.body("Saving over a slot asks you to click again first. Loading replaces the base you're in now.", 14, MHStyle.TEXT_MUTED))
	return sheet

# A card per slot: what's in it and when it was saved, with Save and Load.
# Rebuilt after every save so a new Load button appears straight away.
func _build_slots() -> void:
	if _slots == null: return
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	for slot in range(1, MHGame.SAVE_SLOT_COUNT + 1):
		var info := MHGame.save_slot_summary(slot)
		var exists := bool(info.get("exists", false))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MHStyle.control_box(10))
		_slots.add_child(card)
		var row := MHStyle.hbox(18)
		card.add_child(row)
		var number := MHStyle.display(str(slot), 32)
		number.custom_minimum_size.x = 44
		number.add_theme_color_override("font_color", MHStyle.accent if exists else MHStyle.TEXT_MUTED)
		row.add_child(number)
		var text := MHStyle.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if exists:
			text.add_child(MHStyle.label(str(info.get("colony_name", "Habitat")), 19, MHStyle.TEXT_PRIMARY, 700))
			text.add_child(MHStyle.body("%s · %s · saved %s" % [info.get("site_name", "Mars"), info.get("mode", ""), _when(str(info.get("saved_at", "")))], 14, MHStyle.TEXT_MUTED))
		else:
			text.add_child(MHStyle.label("Empty slot", 19, MHStyle.TEXT_MUTED, 600))
		row.add_child(text)
		var confirming := slot == _confirm_slot
		var save := MHStyle.button("Overwrite?" if confirming else "Save here", "danger" if confirming else "secondary", "save", 44)
		save.tooltip_text = "Click again to replace slot %d" % slot if confirming else "Save this habitat to slot %d" % slot
		save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		save.pressed.connect(_on_save_pressed.bind(slot, exists))
		row.add_child(save)
		if exists:
			var load := MHStyle.button("Load", "ghost", "rotate-ccw", 44)
			load.tooltip_text = "Load the habitat in slot %d" % slot
			load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			load.pressed.connect(load_requested.emit.bind(slot))
			row.add_child(load)

## "2026-10-25T09:14:03" -> "25 Oct, 09:14".
static func _when(stamp: String) -> String:
	if stamp.length() < 16: return stamp if not stamp.is_empty() else "earlier"
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month := clampi(int(stamp.substr(5, 2)), 1, 12)
	return "%d %s, %s" % [int(stamp.substr(8, 2)), months[month - 1], stamp.substr(11, 5)]

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
	if not (_panels.saves as Control).visible: _toggle_panel("saves")
	_save_status.text = text
	_save_status.add_theme_color_override("font_color", {"valid": MHStyle.VALID, "warn": MHStyle.WARN, "invalid": MHStyle.DANGER}.get(tone, MHStyle.TEXT_MUTED))
	if tone != "warn":
		_build_slots()

# ---------- controls ----------

func _build_controls() -> Control:
	var sheet := _sheet()
	var col := MHStyle.vbox(20)
	sheet.add_child(col)
	_sheet_head(col, "Controls", "Keyboard + mouse")
	# Four slim columns side by side, so every key fits on the sheet.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for group in MHGame.CONTROLS:
		var g := MHStyle.vbox(3)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(MHStyle.eyebrow(group[0], MHStyle.accent, 14))
		for entry in group[1]: g.add_child(MHStyle.control_row(entry[0], entry[1], true))
		grid.add_child(g)
	col.add_child(grid)
	col.add_child(MHStyle.body("Build keys work while a build view is open (B). The rover keys work while you're driving.", 14, MHStyle.TEXT_MUTED))
	return sheet

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Esc backs out of the Field guide first, then an open panel.
		if is_instance_valid(_guide) and not _guide.is_queued_for_deletion():
			_guide.queue_free()
			return
		for key in _panels:
			if (_panels[key] as Control).visible:
				_toggle_panel(key)
				return
		resumed.emit()
