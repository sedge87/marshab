class_name MHPauseMenu
extends Control

# Pause screen: a short action list on the left; Save & load and Controls
# open in the panel on the right (one at a time), over the last frame blurred
# and dimmed. The Field guide opens over everything. The tree is paused
# while it is open. (27 Oct: saves are named files, scripts/saves.gd: Save
# updates this base's file, Save a copy makes another, and recent saves load.)

signal resumed
signal mission_control
signal settings
signal exit_to_menu
signal save_requested
signal save_copy_requested(copy_name: String)
signal load_requested(path: String)

const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")
const MHSaves := preload("res://scripts/saves.gd")

var _panels := {}                  # name -> Control (the right-hand panel)
var _panel_buttons := {}           # name -> Button
var _slots: VBoxContainer
var _save_status: Label
var _current_label: Label
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
	var col := MHStyle.vbox(16)
	sheet.add_child(col)
	_sheet_head(col, "Save & load", "Documents/Outpost One/Saves")
	# This base: Save updates its file (the first save makes it).
	var this_base := PanelContainer.new()
	this_base.add_theme_stylebox_override("panel", MHStyle.control_box(14))
	col.add_child(this_base)
	var row := MHStyle.hbox(16)
	this_base.add_child(row)
	var text := MHStyle.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(MHStyle.eyebrow("This base", MHStyle.accent, 12))
	_current_label = MHStyle.label("", 20, MHStyle.TEXT_PRIMARY, 700)
	text.add_child(_current_label)
	row.add_child(text)
	var save := MHStyle.button("Save", "primary", "save", 48)
	save.tooltip_text = "Save this base (Ctrl+S). The last five saves are kept as backups."
	save.custom_minimum_size.x = 170
	save.pressed.connect(func() -> void: save_requested.emit())
	row.add_child(save)
	var cap := MHStyle.keycap("Ctrl+S", true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	# Save a copy: a separate named save (a checkpoint).
	var copy_row := MHStyle.hbox(10)
	var name_box := LineEdit.new()
	name_box.placeholder_text = "Name for a copy, e.g. \"%s, sol 20\"" % MHGame.colony_name
	name_box.max_length = 60
	name_box.custom_minimum_size = Vector2(0, 44)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_row.add_child(name_box)
	var copy := MHStyle.button("Save a copy", "secondary", "package", 44)
	copy.tooltip_text = "Keep a separate save under this name; you carry on with this one"
	copy.pressed.connect(func() -> void: save_copy_requested.emit(name_box.text))
	name_box.text_submitted.connect(func(value: String) -> void: save_copy_requested.emit(value))
	copy_row.add_child(copy)
	col.add_child(copy_row)
	_save_status = MHStyle.body("", 15, MHStyle.TEXT_MUTED)
	col.add_child(_save_status)
	col.add_child(MHStyle.eyebrow("Recent saves", MHStyle.TEXT_MUTED, 12))
	_slots = MHStyle.vbox(8)
	col.add_child(_slots)
	col.add_child(MHStyle.body("Loading replaces the base you're in now. Every save is on the title screen under Load, with pictures, search and Tour.", 14, MHStyle.TEXT_MUTED))
	return sheet

## This base's name, and the newest saves to load (rebuilt after a save).
func _build_slots() -> void:
	if _slots == null: return
	var current := MHSaves.read_header(MHSaves.current_path)
	_current_label.text = "%s · saved %s" % [str(current.get("name", "")), _when(str(current.get("saved_at", "")))] if not current.is_empty() else "%s · not saved yet" % MHGame.colony_name
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	var saves: Array = MHSaves.entries()
	if saves.is_empty():
		_slots.add_child(MHStyle.body("No saves yet.", 15, MHStyle.TEXT_MUTED))
	for info in saves.slice(0, 5):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MHStyle.control_box(10))
		_slots.add_child(card)
		var row := MHStyle.hbox(18)
		card.add_child(row)
		var text := MHStyle.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var here := str(info.path) == MHSaves.current_path
		text.add_child(MHStyle.label(str(info.get("name", "Habitat")) + ("  ·  this base" if here else ""), 18, MHStyle.accent if here else MHStyle.TEXT_PRIMARY, 700))
		text.add_child(MHStyle.body("%s · %s · saved %s" % [info.get("site_name", "Mars"), MHSaves.mode_label(info), _when(str(info.get("saved_at", "")))], 14, MHStyle.TEXT_MUTED))
		row.add_child(text)
		var load := MHStyle.button("Load", "ghost", "rotate-cw", 42)
		load.tooltip_text = "Load this save (the base you're in now is replaced)"
		load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		load.pressed.connect(load_requested.emit.bind(str(info.path)))
		row.add_child(load)

## "2026-10-25T09:14:03" -> "25 Oct, 09:14".
static func _when(stamp: String) -> String:
	if stamp.length() < 16: return stamp if not stamp.is_empty() else "earlier"
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month := clampi(int(stamp.substr(5, 2)), 1, 12)
	return "%d %s, %s" % [int(stamp.substr(8, 2)), months[month - 1], stamp.substr(11, 5)]

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
