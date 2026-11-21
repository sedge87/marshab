extends Control

## The slate's screen (scripts/pda.gd, docs/pda.md §3): drawn into its
## SubViewport at 1280 x 800. A status bar along the top (time, day or night,
## the resupply countdown, the link), a row of page tabs with an unread dot on
## each, and the open page filling the rest. 1–5 (or LB/RB) switch pages.
##
## 21 Nov playtest: nine apps were too many, and nobody could tell what each
## was for. Now four pages, each saying what it's for, with the old apps as
## tabs inside them; and the Camera, a tool rather than a page, at the end.
## Everything is drawn 25% larger (SCALE): the text was too small to read.

const APPS := [
	{"id": "today", "label": "Today", "icon": "pencil", "built": true, "what": "What's on your mind, and what's next."},
	{"id": "map", "label": "Map", "icon": "map-pin", "built": true, "what": "Where you are, where things are, and the ground here."},
	{"id": "base", "label": "Base", "icon": "gauge", "built": true, "what": "Power, heat and air at each base, and the cargo you've found."},
	{"id": "radio", "label": "Radio", "icon": "satellite", "built": true, "what": "Messages, discoveries, and everything you've been told."},
	{"id": "camera", "label": "Camera", "icon": "camera", "built": true, "what": "Photos for the journal."},
]
## The old app names, still used by callers and notices: [page, tab].
const ALIASES := {"notes": ["today", ""], "goals": ["today", ""], "site": ["map", "site"], "cargo": ["base", "cargo"], "comms": ["radio", "messages"], "log": ["radio", "log"], "discoveries": ["radio", "discoveries"]}
## Which notice channels (MHNotices.unread) light each page's dot.
const DOTS := {"today": ["notes", "goals"], "map": ["map", "site"], "base": ["base", "cargo"], "radio": ["comms", "log"], "camera": ["camera"]}
const SCALE := 1.25
const PIXELS := Vector2(1280, 800)
const SIZE := PIXELS / SCALE      # the page's own size, drawn SCALE times larger
const GUIDE := preload("res://scripts/guide_overlay.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var world: Node
var pda: Node
var app := ""
var _tab := {"map": "map", "base": "base", "radio": "messages"}   # each page's open tab
var _clock: Label
var _link: Label
var _keys: Control       # the keys along the bottom, the first few times (pda.gd show_keys)
var _rail: VBoxContainer
var _rail_buttons := {}   # app id -> {button, dot}
var _page: MarginContainer
var _shown_log := -1      # notices on the Log page when it was drawn
var _shown_goals := ""    # what the Goals page showed (redrawn when it changes)
var _shown_notes := ""    # what the Notes page showed
var _map_you: Label
var _shown_base := ""     # what the Base page showed
var _shown_comms := ""    # what the Comms page showed
var _shown_site := ""     # what the Site page showed
var _comms_tab := "messages"
var _comms_only := ""     # one person's messages, or everyone's
const SYSTEMS := [["battery", "Battery", "zap"], ["water", "Water", "droplets"], ["food", "Food", "wheat"], ["air", "Air", "wind"], ["crew", "Crew health", "heart-pulse"]]
var _map_cursor: Label
const MAP_FIT := 360.0    # the map square on the screen, px (drawn SCALE larger)
var _tick := 0.0

func _ready() -> void:
	size = SIZE
	scale = Vector2(SCALE, SCALE)
	theme = MHStyle.theme()
	var back := ColorRect.new()
	back.color = MHStyle.INK_950
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	# Kept clear of the edges: the bezel's raised lip hides a sliver of each side.
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: safe.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]: safe.add_theme_constant_override("margin_" + side, 22)
	add_child(safe)
	var column := MHStyle.vbox(0)
	safe.add_child(column)
	column.add_child(_status_bar())
	column.add_child(_build_rail())
	_page = MarginContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: _page.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]: _page.add_theme_constant_override("margin_" + side, 14)
	column.add_child(_page)
	# The keys, along the bottom, the first few times the slate is up.
	_keys = PanelContainer.new()
	_keys.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(0, 0, 0, 0), 0, 0, Vector4(24, 10, 24, 10)))
	var keys_row := MHStyle.hbox(18)
	keys_row.alignment = BoxContainer.ALIGNMENT_CENTER
	keys_row.add_child(MHStyle.mono("TAB  LOWER THE SLATE", 18, MHStyle.accent, 700))
	keys_row.add_child(MHStyle.mono("·", 18, MHStyle.TEXT_MUTED, 700))
	keys_row.add_child(MHStyle.mono("TAB AGAIN TO RAISE IT", 18, MHStyle.TEXT_SECONDARY, 700))
	keys_row.add_child(MHStyle.mono("·", 18, MHStyle.TEXT_MUTED, 700))
	keys_row.add_child(MHStyle.mono("1–5 OR CLICK A TAB FOR A PAGE", 18, MHStyle.TEXT_SECONDARY, 700))
	_keys.add_child(keys_row)
	_keys.visible = false
	column.add_child(_keys)

func _status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(0, 0, 0, 0), 0, 0, Vector4(24, 12, 24, 12)))
	var row := MHStyle.hbox(18)
	row.add_child(MHStyle.icon("tablet", 22, MHStyle.accent))
	row.add_child(MHStyle.label("SLATE", 18, MHStyle.TEXT_PRIMARY, 700, false, 2))
	row.add_child(MHStyle.spacer())
	_clock = MHStyle.mono("", 18, MHStyle.INFO, 700)
	row.add_child(_clock)
	_link = MHStyle.mono("", 16, MHStyle.TEXT_MUTED, 700)
	row.add_child(_link)
	bar.add_child(row)
	return bar

## The page tabs, in a row under the status bar.
var _rail_row: HBoxContainer
func _build_rail() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(0, 0, 0, 0), 0, 0, Vector4(8, 8, 8, 8)))
	_rail_row = MHStyle.hbox(8)
	panel.add_child(_rail_row)
	_rail = MHStyle.vbox(0)   # (kept for older callers; the tabs are in _rail_row)
	_fill_rail()
	return panel

## The rail's buttons, one per app in apps() (rebuilt if that changes, e.g.
## Notes for Goals once the world is known).
func _fill_rail() -> void:
	for child in _rail_row.get_children(): child.free()
	_rail_buttons = {}
	var n := 0
	for entry in APPS:
		if not str(entry.id) in apps(): continue
		n += 1
		var tool := str(entry.id) == "camera"
		if tool: _rail_row.add_child(MHStyle.spacer())
		var button := MHStyle.button(("%d" % n) if tool else ("%d  %s" % [n, entry.label]), "ghost", str(entry.icon), 48)
		button.focus_mode = Control.FOCUS_NONE
		if not tool: button.custom_minimum_size.x = 150
		button.tooltip_text = str(entry.what)
		button.pressed.connect(show_app.bind(str(entry.id)))
		var dot := ColorRect.new()
		dot.color = MHStyle.accent
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size = Vector2(9, 9)
		dot.position = Vector2(8, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(dot)
		_rail_row.add_child(button)
		_rail_buttons[str(entry.id)] = {"button": button, "dot": dot}

## The pages, in tab order (the Camera only once there's a camera).
func apps() -> Array:
	var shoots: bool = world != null and world.get("slate_camera") != null
	return APPS.filter(func(entry): return bool(entry.built) and (shoots or str(entry.id) != "camera")).map(func(entry): return str(entry.id))

## The tabs a page has: [id, label, icon].
func tabs(page: String) -> Array:
	match page:
		"map": return [["map", "Map", "map"], ["site", "Here", "mountain-snow"]]
		"base":
			var cargo: bool = world != null and world.get("storm_drop") != null
			return [["base", "Base", "gauge"]] + ([["cargo", "Cargo", "package"]] if cargo else [])
		"radio": return [["messages", "Messages", "satellite"], ["discoveries", "Discoveries", "sparkles"], ["log", "Log", "clock"]]
	return []

## A page's header: its tabs on the left, what it's for on the right.
func _page_head(page: String) -> Control:
	var row := MHStyle.hbox(8)
	for tab in tabs(page):
		var id := str(tab[0])
		var button := MHStyle.button(str(tab[1]), "primary" if str(_tab.get(page, "")) == id else "secondary", str(tab[2]), 40)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			_tab[page] = id
			_rebuild())
		row.add_child(button)
	row.add_child(MHStyle.spacer())
	for entry in APPS:
		if str(entry.id) == page:
			var what := MHStyle.body(str(entry.what), 15, MHStyle.TEXT_MUTED)
			what.autowrap_mode = TextServer.AUTOWRAP_OFF
			what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(what)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return row

## The open page, drawn again from scratch.
func _rebuild() -> void:
	_lend_map(false)
	for child in _page.get_children(): child.queue_free()
	var holder := MHStyle.vbox(12)
	if not tabs(app).is_empty(): holder.add_child(_page_head(app))
	var body: Control
	var tab := str(_tab.get(app, ""))
	match app:
		"today": body = _notes_page() if world == null or world.get("tutorial") == null else _goals_page()
		"map": body = _map_page() if tab == "map" else _site_page()
		"base": body = _cargo_page() if tab == "cargo" else _base_page()
		"radio":
			if tab == "log":
				body = _log_page()
				MHNotices.seen("log")
			else:
				_comms_tab = "discoveries" if tab == "discoveries" else "messages"
				body = _comms_page()
		"camera": body = _camera_page()
		_: body = _notes_page()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if (app == "base" and tab == "base") or (app == "today" and world != null and world.get("tutorial") == null):   # taller than the screen (several bases; notes and open goals): it scrolls
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		body = scroll
	holder.add_child(body)
	_page.add_child(holder)
	for channel in DOTS.get(app, []): MHNotices.seen(str(channel))

## The slate was raised (pda.gd): on this app, or the last one used.
func opened(wanted := "") -> void:
	if _rail_buttons.keys() != apps(): _fill_rail()
	var choice := wanted if (wanted in apps() or ALIASES.has(wanted)) else str(MHGame.setting("slate_app"))
	if not (choice in apps() or ALIASES.has(choice)): choice = str(apps()[0])
	app = ""
	show_app(choice)
	_update_status()
	_keys.visible = pda != null and bool(pda.show_keys())

## The next or last page along the rail (the gamepad's RB / LB).
func step_app(by: int) -> void:
	var list := apps()
	if list.is_empty(): return
	var at := maxi(0, list.find(app))
	show_app(str(list[wrapi(at + by, 0, list.size())]))

func show_app(id: String) -> void:
	# An old app name opens its page, on its tab.
	if ALIASES.has(id):
		var where: Array = ALIASES[id]
		if not str(where[1]).is_empty(): _tab[str(where[0])] = str(where[1])
		if world != null and world.get("guide_flags") != null: world.guide_flags["slate_" + id] = true
		id = str(where[0])
		if id == app: _rebuild()
	elif tabs(id).any(func(t): return str(t[0]) == id):
		_tab[id] = id   # "map" or "base" by name: its main tab
		if id == app: _rebuild()
	if not id in apps(): id = str(apps()[0])
	if id == app and _page.get_child_count() > 0: return
	if app == "camera" and id != "camera": _camera_off()
	app = id
	MHNotices.seen(id)
	if world != null and world.get("guide_flags") != null: world.guide_flags["slate_" + id] = true
	var values := MHGame.settings()
	if str(values.get("slate_app", "")) != id:
		values["slate_app"] = id
		MHGame.save_settings(values)
	_rebuild()
	for key in _rail_buttons:
		(_rail_buttons[key].button as Button).theme_type_variation = "SelectedButton" if key == id else "GhostButton"
	MHAudio.sfx("ui_click", -10.0)

## Typing into a box on the screen (so Tab and Esc don't lower the slate).
func typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if app == "map" and _region() != null and _region().slate_key((event as InputEventKey).keycode):
		get_viewport().set_input_as_handled()
		return
	if app == "camera" and (event as InputEventKey).keycode in [KEY_E, KEY_SPACE]:
		shutter()
		get_viewport().set_input_as_handled()
		return
	var index := (event as InputEventKey).keycode - KEY_1   # 1–5: the pages
	var list := apps()
	if index >= 0 and index < list.size():
		show_app(str(list[index]))
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if pda == null or not pda.is_open: return
	_tick -= delta
	if _tick > 0.0: return
	_tick = .5
	_update_status()
	var tab := str(_tab.get(app, ""))
	if app == "map" and tab == "map" and _map_you != null and _region() != null:
		var lines: Array = _region().readouts()
		_map_you.text = str(lines[0])
		_map_cursor.text = str(lines[1])
	if app == "camera": _camera_words()
	var stale := false
	match app:
		"radio": stale = (MHNotices.history.size() != _shown_log) if tab == "log" else (_comms_signature() != _shown_comms)
		"map": stale = tab == "site" and _site_signature() != _shown_site
		"base": stale = (_cargo_signature() != _shown_cargo) if tab == "cargo" else (_base_signature() != _shown_base)
		"today": stale = (_notes_signature() != _shown_notes) if world.get("tutorial") == null else (_goals_signature() != _shown_goals)
	if stale: _rebuild()

func _update_status() -> void:
	var daytime := MHGame.sunlight_fraction > .08
	var text := "%s · %s" % [MHGame.formatted_sol_time(), "DAY" if daytime else "NIGHT"]
	var builder: Node = world.builder if world != null else null
	if MHGame.resupplies_on() and builder != null:
		var due := MHGame.resupply_due_in_hours(builder.simulation().hours_run)
		text += "  ·  RESUPPLY %s" % ("%d H" % ceili(due) if due < 24.0 else "%.1f SOLS" % (due / 24.0))
	_clock.text = text
	_clock.add_theme_color_override("font_color", MHStyle.INFO if daytime else MHStyle.TEXT_MUTED)
	var linked := _linked()
	var radio: Node = world.get("radio") if world != null else null
	var orbit_gone: bool = linked and radio != null and radio.has_method("in_contact") and not bool(radio.in_contact())
	_link.text = ("ORBIT BACK %s" % radio.clock(radio.los_window().y)) if orbit_gone else ("LINK" if linked else "NO LINK")
	_link.add_theme_color_override("font_color", MHStyle.WARN if orbit_gone or not linked else MHStyle.VALID)
	for key in _rail_buttons:
		var waiting := 0
		for channel in DOTS.get(key, [key]): waiting += int(MHNotices.unread.get(str(channel), 0))
		(_rail_buttons[key].dot as Control).visible = key != app and waiting > 0

## In a cave the slate has no link (docs/terrain-overhaul.md: no link underground).
func _linked() -> bool:
	if world == null or world.player == null: return true
	return MHCaves.cave_at(world.player.global_position).is_empty()

# ---------- apps ----------

func _heading(title: String, note := "") -> VBoxContainer:
	var top := MHStyle.vbox(4)
	top.add_child(MHStyle.title(title, 30))
	if not note.is_empty(): top.add_child(MHStyle.body(note, 17, MHStyle.TEXT_MUTED))
	return top

## Log: every notice, newest first (MHNotices).
func _log_page() -> Control:
	_shown_log = MHNotices.history.size()
	var page := MHStyle.vbox(16)
	page.add_child(MHStyle.body("Everything you've been told, newest first.", 16, MHStyle.TEXT_MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := MHStyle.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if MHNotices.history.is_empty():
		list.add_child(MHStyle.body("Nothing yet. News lands here as it happens.", 18, MHStyle.TEXT_MUTED))
	for i in range(MHNotices.history.size() - 1, -1, -1):
		list.add_child(_log_row(MHNotices.history[i]))
	return page

func _log_row(entry: Dictionary) -> Control:
	var tone := str(entry.tone)
	var colour := MHStyle.tone_colour(tone)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(colour, .3), MHStyle.RADIUS_MD, 1, Vector4(16, 12, 16, 12)))
	var line := MHStyle.hbox(14)
	var glyph: String = {"invalid": "circle-x", "danger": "circle-x", "warn": "triangle-alert", "valid": "circle-check"}.get(tone, "info")
	var mark := MHStyle.icon(glyph, 22, colour)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(mark)
	var words := MHStyle.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(MHStyle.label(str(entry.heading), 19, MHStyle.TEXT_PRIMARY, 700))
	if not str(entry.text).is_empty():
		var body := MHStyle.body(str(entry.text), 17)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(body)
	line.add_child(words)
	var time := MHStyle.mono(str(entry.time), 15, MHStyle.TEXT_MUTED)
	time.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(time)
	row.add_child(line)
	return row

## Notes: a notebook page of your own thoughts, newest at the top. No ticks,
## counts or markers; an answered thought leaves for the journal.
func _notes_page() -> Control:
	_shown_notes = _notes_signature()
	var notes: Node = world.get("notes") if world != null else null
	var page := MHStyle.vbox(0)
	var sheet := PanelContainer.new()
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_theme_stylebox_override("panel", MHStyle.box(Color("#1d1a17"), Color(1, 1, 1, .06), MHStyle.RADIUS_MD, 1, Vector4(40, 30, 40, 30)))
	page.add_child(sheet)
	var column := MHStyle.vbox(0)
	sheet.add_child(column)
	column.add_child(MHStyle.eyebrow("NOTES", Color("#c9b99a"), 13))
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	column.add_child(gap)
	var list: Array = notes.thoughts() if notes != null else []
	if list.is_empty():
		column.add_child(_note_line("Nothing on my mind just now. Odd feeling, on Mars.", true))
	for i in list.size():
		column.add_child(_note_line(str(list[i].text), i > 0))
	# 21 Nov: after sol 1, the opening's open goals, any order, each with what
	# it still needs, and Castle's "what I'd do next" when you want it.
	var days: Node = world.get("opening_days") if world != null else null
	var goals: Array = days.open_goals() if days != null and days.has_method("open_goals") else []
	if not goals.is_empty():
		var space := Control.new()
		space.custom_minimum_size.y = 18
		column.add_child(space)
		column.add_child(MHStyle.eyebrow("THINGS I COULD DO, ANY ORDER", Color("#c9b99a"), 13))
		var gap2 := Control.new()
		gap2.custom_minimum_size.y = 10
		column.add_child(gap2)
		for goal in goals:
			var text := "·  " + str(goal.text)
			if not str(goal.needs).is_empty(): text += "\n    first: " + str(goal.needs)
			column.add_child(_note_line(text, false))
		var ask := MHStyle.button("Ask Castle what's next", "secondary", "satellite", 44)
		ask.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ask.pressed.connect(func() -> void:
			if bool(days.ask_next()): ask.text = "She's calling…"
			else: ask.text = "Castle's busy or out of contact"
			ask.disabled = true)
		column.add_child(ask)
	return page

## One thought on ruled paper: the newest in ink, older ones a little faded.
func _note_line(text: String, older: bool) -> Control:
	var box := MHStyle.vbox(0)
	var line := MHStyle.body(text, 22, Color("#efe3cc") if not older else Color("#b9ad97"))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.y = 40
	box.add_child(line)
	var rule := ColorRect.new()
	rule.color = Color("#6f8fa8", .25)
	rule.custom_minimum_size.y = 1
	box.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	box.add_child(gap)
	return box

func _notes_signature() -> String:
	var notes: Node = world.get("notes") if world != null else null
	var days: Node = world.get("opening_days") if world != null else null
	var goals: Array = days.open_goals() if days != null and days.has_method("open_goals") else []
	return (str(notes.thoughts()) if notes != null else "") + str(goals)

## Goals: the getting-started goals down the left, the current one's tasks
## with the next one's how-to, keys and Show me, and what the base still
## needs (the readiness list). Replaces the on-screen checklist (docs/pda.md §3).
func _goals_page() -> Control:
	_shown_goals = _goals_signature()
	var tutorial: Node = world.get("tutorial") if world != null else null
	var page := MHStyle.hbox(28)
	var side := MHStyle.vbox(10)
	side.custom_minimum_size.x = 260
	page.add_child(side)
	var main := MHStyle.vbox(14)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(main)
	page.add_child(scroll)
	if tutorial == null or bool(tutorial.finished):
		side.add_child(_heading("Goals"))
		side.add_child(MHStyle.body("The getting-started checklist is done." if tutorial != null else "Hints only: no checklist this game.", 17, MHStyle.TEXT_MUTED))
		_needs(main)
		return page
	# The goals, in order.
	side.add_child(MHStyle.eyebrow("GOALS", MHStyle.TEXT_MUTED, 13))
	var goal: String = tutorial.current_goal()
	var used: Array = tutorial.goals().filter(func(g): return not (tutorial.goal_steps(str(g.id)) as Array).is_empty())
	var past := true
	for g in used:
		var tasks: Array = tutorial.goal_steps(str(g.id))
		var ticked := tasks.filter(func(s): return tutorial.done.has(str(s.id))).size()
		var is_current := str(g.id) == goal
		if is_current: past = false
		var row := MHStyle.hbox(10)
		row.add_child(MHStyle.icon("circle-check" if past else ("circle-arrow-right" if is_current else "circle-dashed"), 20, MHStyle.VALID if past else (MHStyle.accent if is_current else MHStyle.TEXT_MUTED)))
		var name_label := MHStyle.label(str(g.title), 18, MHStyle.TEXT_PRIMARY if is_current else MHStyle.TEXT_SECONDARY, 700 if is_current else 500)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(MHStyle.mono("%d/%d" % [ticked, tasks.size()], 14, MHStyle.TEXT_MUTED))
		side.add_child(row)
	# The current goal's tasks.
	var tasks: Array = tutorial.goal_steps(goal)
	var step: Dictionary = tutorial.current()
	var ticked := tasks.filter(func(s): return tutorial.done.has(str(s.id))).size()
	main.add_child(MHStyle.eyebrow("%s · GOAL %d OF %d · %d OF %d DONE" % [MHGame.habitat_name.to_upper(), used.map(func(g): return str(g.id)).find(goal) + 1, used.size(), ticked, tasks.size()], MHStyle.accent, 13))
	main.add_child(MHStyle.title(str(tutorial._goal_title(goal)), 30))
	for task in tasks:
		var is_done: bool = tutorial.done.has(str(task.id))
		var is_next := str(task.id) == str(step.get("id", ""))
		var row := MHStyle.hbox(12)
		row.add_child(MHStyle.icon("circle-check" if is_done else ("circle-arrow-right" if is_next else "circle-dashed"), 22, MHStyle.VALID if is_done else (MHStyle.accent if is_next else MHStyle.TEXT_MUTED)))
		row.add_child(MHStyle.label(str(task.text), 20, MHStyle.TEXT_MUTED if is_done else (MHStyle.TEXT_PRIMARY if is_next else MHStyle.TEXT_SECONDARY), 700 if is_next else 500))
		main.add_child(row)
		if is_next: main.add_child(_next_task(task, tutorial))
	_needs(main)
	return page

## The next task, opened out: how to do it, its keys, Show me, and "Done
## reading" for a step you only have to read.
func _next_task(task: Dictionary, tutorial: Node) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(MHStyle.accent, .35), MHStyle.RADIUS_MD, 1, Vector4(20, 16, 20, 16)))
	var column := MHStyle.vbox(12)
	box.add_child(column)
	var how := MHStyle.body(str(task.get("how", "")), 18)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(how)
	if not (task.get("keys", []) as Array).is_empty(): column.add_child(GUIDE.keys_box(task.keys))
	var buttons := MHStyle.hbox(12)
	if GUIDE.has_clip(str(task.get("clip", ""))):
		var show := MHStyle.button("Show me", "secondary", "play", 48)
		show.focus_mode = Control.FOCUS_NONE
		show.pressed.connect(func() -> void:
			pda.close()
			tutorial.guide.show_clip(str(task.clip), str(task.text), task.get("keys", [])))
		buttons.add_child(show)
	if str((task.get("check", {}) as Dictionary).get("type", "")) == "read":
		var read := MHStyle.button("Done reading", "primary", "check", 48)
		read.focus_mode = Control.FOCUS_NONE
		read.pressed.connect(func() -> void:
			tutorial._read_pressed = true
			tutorial._check_in = 0.0)
		buttons.add_child(read)
	if buttons.get_child_count() > 0: column.add_child(buttons)
	return box

## What the base still needs: the readiness list, unmet items first.
func _needs(column: VBoxContainer) -> void:
	var builder: Node = world.builder if world != null else null
	if builder == null: return
	var items: Array = builder.readiness()
	if items.is_empty(): return
	var met: int = builder.readiness_met()
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)
	column.add_child(MHStyle.eyebrow("THE BASE · %d OF %d READY" % [met, items.size()], MHStyle.TEXT_MUTED, 13))
	if met == items.size():
		column.add_child(MHStyle.body("Everything the crew needs is in place.", 17, MHStyle.VALID))
		return
	for item in items:
		if str(item.status) != "met": column.add_child(MHStyle.readiness_item(item))

## Changes when the Goals page would look different.
func _goals_signature() -> String:
	var tutorial: Node = world.get("tutorial") if world != null else null
	var builder: Node = world.builder if world != null else null
	return "%s|%s|%s" % [str(tutorial.done) if tutorial != null else "", str(tutorial.finished) if tutorial != null else "", str(builder.readiness()) if builder != null else ""]

## Base: the habitat's battery, water, food, air and crew health with their
## trends (the systems panel's rows), the active alerts as cards (what's
## wrong and why) and the alert history, newest first.
func _base_page() -> Control:
	_shown_base = _base_signature()
	var hud: Node = world.get("explore_hud") if world != null else null
	var rows: Dictionary = hud.system_rows() if hud != null else {}
	var page := MHStyle.hbox(32)
	var left := MHStyle.vbox(18)
	left.custom_minimum_size.x = 440
	page.add_child(left)
	var builder: Node = world.builder
	var sim: RefCounted = builder.simulation() if builder != null else null
	var cabin: Node = world.get("cabin_life")
	var module: Node = _shown_core()
	# Several bases (A4): a switcher, the one you're at first.
	var switcher := _base_switcher()
	if switcher != null: left.add_child(switcher)
	# Three readings per base (docs/hab-supply.md): power, heat and air. The
	# base's core (the General Module) first, the lander as the backup.
	if module != null and module.running() and bool(module.commissioned):
		left.add_child(_heading(_base_title(), "Power, heat and air, and how long each lasts as things are set. With no power it gets cold first, then the air goes stale."))
		for entry in READINGS: left.add_child(_gauge(str(entry[1]), str(entry[2]), _cabin_rows(module)[entry[0]]))
		if cabin != null and cabin.running():
			left.add_child(_heading("Lander", "Your lifepod: it looks after itself."))
			for entry in READINGS: left.add_child(_gauge(str(entry[1]), str(entry[2]), _cabin_rows(cabin)[entry[0]]))
		rows = {}
	elif rows.is_empty() and cabin != null and cabin.running():
		left.add_child(_heading("Lander cabin", "Your first base: its power, heat and air, and how long each lasts as things are set."))
		for entry in READINGS: left.add_child(_gauge(str(entry[1]), str(entry[2]), _cabin_rows(cabin)[entry[0]]))
		rows = {}
	elif rows.is_empty():
		left.add_child(_heading("Base", "No habitat yet: its systems show here once the first module stands." if MHGame.simulation_on() else "Creative mode: no simulation to watch."))
		return page
	if not rows.is_empty(): left.add_child(_heading("Base", "%d crew%s" % [sim.crew_count(), " · dust storm" if bool(sim.last.get("storm", false)) else ""]))
	for entry in SYSTEMS if not rows.is_empty() else []:
		var row: Dictionary = rows.get(entry[0], {})
		if row.is_empty(): continue
		left.add_child(_gauge(str(entry[1]), str(entry[2]), row))
	if MHChapterOne.on() and sim != null and not rows.is_empty():
		left.add_child(_feedstock_block(sim))
	var right := MHStyle.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(right)
	page.add_child(scroll)
	var alerts: Node = world.get("alerts")
	var active: Array = alerts.active_alerts() if alerts != null else []
	right.add_child(MHStyle.eyebrow("ALERTS · %d" % active.size(), MHStyle.TEXT_MUTED, 13))
	if active.is_empty(): right.add_child(MHStyle.body("All systems normal.", 17, MHStyle.VALID))
	for alert in active: right.add_child(_alert_card(alert))
	var history: Array = alerts.history if alerts != null else []
	if not history.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		right.add_child(gap)
		right.add_child(MHStyle.eyebrow("HISTORY", MHStyle.TEXT_MUTED, 13))
		for i in range(history.size() - 1, maxi(-1, history.size() - 13), -1):
			var entry: Dictionary = history[i]
			var line := MHStyle.hbox(10)
			line.add_child(MHStyle.mono("SOL %d %02d:%02d" % [int(entry.sol), floori(float(entry.sol_hour)), floori(fmod(float(entry.sol_hour), 1.0) * 60.0)], 14, MHStyle.TEXT_MUTED))
			var words := MHStyle.label(str(entry.title), 16, alerts.LEVEL_COLOUR.get(str(entry.level), MHStyle.TEXT_SECONDARY), 500)
			words.clip_text = true
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(words)
			right.add_child(line)
	return page

## The Print Shops' feedstock: what's in the crate, what the regolith intakes
## make a sol, and what recycling makes from the crew's waste.
func _feedstock_block(sim: RefCounted) -> Control:
	var box := MHStyle.vbox(4)
	var top := MHStyle.hbox(10)
	top.add_child(MHStyle.icon("package", 22, MHStyle.INFO))
	top.add_child(MHStyle.label("Feedstock", 19, MHStyle.TEXT_PRIMARY, 700))
	box.add_child(top)
	box.add_child(MHStyle.body(_feedstock_words(sim), 17, MHStyle.TEXT_SECONDARY))
	# A5: the other materials, and each room's chain at this base.
	var more := "Metal %s · salvage %s" % [MHStyle.kg(floori(MHMaterials.metal_kg)), MHStyle.kg(floori(MHMaterials.salvage_kg))]
	if MHMaterials.ore_kg() > 0.0: more += " · iron-rich rock %s for the smelter" % MHStyle.kg(floori(MHMaterials.ore_kg()))
	if MHMaterials.carried_kg() > 0.0: more += " · %s in the suit" % MHStyle.kg(floori(MHMaterials.carried_kg()))
	box.add_child(MHStyle.body(more, 17, MHStyle.TEXT_SECONDARY))
	var chains := _chains_words()
	if not chains.is_empty():
		var words := MHStyle.body(chains, 15, MHStyle.TEXT_MUTED)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(words)
	return box

## Each room's chain at the shown base, A5: "Lab: Rock Saw ✓ → Microscope ·".
const ROOM_CHAINS := [
	["science", "Lab", ["rock_saw", "microscope_station", "spectrometer"]],
	["engineering", "Workshop", ["smelter", "fabricator", "tool_bench"]],
	["hydroponics", "Greenhouse", ["regolith_washer", "greenhouse_planter", "harvest_cart"]],
]

func _chains_words() -> String:
	var builder: Node = world.builder if world != null else null
	if builder == null: return ""
	var base := _base_choice()
	var have := {}
	for item in builder.placed_interior:
		var cell := Vector2i(item.get("zone_cell", Vector2i.ZERO))
		for zone in builder.zones:
			if (zone.get("cells", []) as Array).has(cell) and MHBases.base_of(zone) == base:
				have["%s:%s" % [str(zone.kind), str(item.id)]] = true
	var lines: Array = []
	for chain in ROOM_CHAINS:
		if not builder.zones.any(func(z): return str(z.kind) == str(chain[0]) and MHBases.base_of(z) == base): continue
		var bits: Array = (chain[2] as Array).map(func(id): return "%s %s" % [str(EquipmentCatalog.get_entry(str(id)).get("label", id)), "✓" if have.has("%s:%s" % [str(chain[0]), str(id)]) else "·"])
		lines.append("%s: %s" % [str(chain[1]), " → ".join(bits)])
	return "
".join(lines)

func _feedstock_words(sim: RefCounted) -> String:
	var intakes := int(sim.inventory().get("intakes", 0))
	var intake := float(sim.feedstock_rate(sim.inventory()))
	var recycled := float((sim.waste.last as Dictionary).get("recycled", 0.0))
	var made := "%s kg a sol from %d regolith intake%s" % [str(snappedf(intake, .1)), intakes, "" if intakes == 1 else "s"] if intakes > 0 else "no regolith intake yet"
	return "%s in store
%s
%s kg a sol recycled from waste" % [MHStyle.kg(floori(MHChapterOne.feedstock_kg)), made, str(snappedf(recycled, .1))]

## One system: its name, a bar and the words (charge, trend, sols left).
func _gauge(title: String, glyph: String, row: Dictionary) -> Control:
	var tone: Color = row.tone
	var box := MHStyle.vbox(6)
	var top := MHStyle.hbox(10)
	top.add_child(MHStyle.icon(glyph, 22, tone))
	top.add_child(MHStyle.label(title, 19, MHStyle.TEXT_PRIMARY, 700))
	box.add_child(top)
	var track := ColorRect.new()
	track.color = MHStyle.INK_800
	track.custom_minimum_size = Vector2(440, 8)
	var fill := ColorRect.new()
	fill.color = tone
	fill.size = Vector2(440.0 * float(row.fraction), 8)
	track.add_child(fill)
	box.add_child(track)
	var words := MHStyle.body(str(row.text), 17, MHStyle.TEXT_SECONDARY if tone == MHStyle.VALID else tone)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(words)
	return box

## An active alert: its level's colour, what's wrong and why.
func _alert_card(alert: Dictionary) -> Control:
	var colour: Color = world.alerts.LEVEL_COLOUR.get(str(alert.level), MHStyle.WARN)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(colour, .5), MHStyle.RADIUS_MD, 1, Vector4(16, 12, 16, 12)))
	var column := MHStyle.vbox(4)
	var top := MHStyle.hbox(10)
	top.add_child(MHStyle.icon("triangle-alert" if str(alert.level) != "advisory" else "info", 20, colour))
	var title := MHStyle.label(str(alert.title), 18, MHStyle.TEXT_PRIMARY, 700)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(MHStyle.mono(str(alert.level).to_upper(), 13, colour, 700))
	column.add_child(top)
	if not str(alert.get("text", "")).is_empty():
		var body := MHStyle.body(str(alert.text), 16)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(body)
	card.add_child(column)
	return card

# ---------- A4: several bases ----------

## The base the page shows: picked on the switcher, else the one you're at.
var _base_pick := ""

## The bases with a core down (or on its way): [id, ...], the first base first.
func _bases_listed() -> Array:
	var builder: Node = world.builder if world != null else null
	if builder == null: return []
	var ids: Array = (builder.bases as Dictionary).keys().filter(func(id): return not MHBases.zones_of(builder, str(id)).is_empty())
	ids.sort()
	return ids

func _base_choice() -> String:
	var ids := _bases_listed()
	if ids.has(_base_pick): return _base_pick
	var here := str(world.builder.active_base) if world != null and world.builder != null else MHBases.FIRST
	return here if ids.has(here) or ids.is_empty() else str(ids[0])

func _shown_core() -> Node:
	var cores: Dictionary = world.get("cores") if world != null and world.get("cores") != null else {}
	var life: Node = cores.get(_base_choice())
	if life != null and is_instance_valid(life): return life
	return world.get("module_life") if world != null and _bases_listed().size() <= 1 else null

func _base_title() -> String:
	var id := _base_choice()
	var builder: Node = world.builder
	var name := str((builder.bases as Dictionary).get(id, {}).get("name", MHBases.label_for(id)))
	if str(builder.main_base) == id: name += " · main base"
	return name if _bases_listed().size() > 1 or str(builder.main_base) == id else "Base"

## One chip per base, the shown one lit; nothing with only one base.
func _base_switcher() -> Control:
	var ids := _bases_listed()
	if ids.size() < 2: return null
	var row := MHStyle.hbox(8)
	var builder: Node = world.builder
	for id in ids:
		var label := str((builder.bases as Dictionary)[id].get("name", MHBases.label_for(str(id))))
		if str(builder.main_base) == str(id): label += " ★"
		if str(builder.active_base) == str(id): label += " · here"
		var chip := Button.new()
		chip.text = label
		chip.toggle_mode = true
		chip.button_pressed = str(id) == _base_choice()
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(func() -> void:
			_base_pick = str(id)
			_shown_base = ""
			for child in _page.get_children(): child.queue_free()
			_page.add_child(_base_page()))
		row.add_child(chip)
	return row

## Changes when the Base page would look different.
## The cabin's three gauges: {battery, warmth, air} → {tone, fraction, text}.
const READINGS := [["battery", "Power", "zap"], ["warmth", "Heat", "thermometer"], ["air", "Air", "wind"]]

func _cabin_rows(cabin: Node) -> Dictionary:
	var core: RefCounted = cabin.core
	var ahead: Dictionary = cabin.ahead
	var when := func(key: String, ok: String) -> String:
		var h := float(ahead.get(key, -1.0))
		return ok if h < 0.0 else "until %s" % core._clock_after(h)
	var charging: bool = float(core.last.get("solar", 0.0)) > float(core.last.get("draw", 0.0))
	var battery_text := "%d%% · %s · life support %s" % [roundi(core.battery_pct()), "charging" if charging else when.call("power", "lasts the day"), core.heater_mode]
	var co2: float = core.co2_pct() + float(core.still_co2_pct)
	var air_text := "CO₂ %.1f%% · hull %d%%%s · %s" % [co2, roundi(core.hull_pct), " leaking" if core.leaking() else "", "fresh " + when.call("air", "all day") if co2 < 1.0 else "stale"]
	var warm_text := "%d °C · %s" % [roundi(core.temp_c), "warm " + when.call("cold", "all day") if core.temp_c >= 12.0 else "cold"]
	var tone := func(bad: bool, worse: bool) -> Color: return MHStyle.DANGER if worse else (MHStyle.WARN if bad else MHStyle.VALID)
	return {"battery": {"tone": tone.call(core.battery_pct() < 25.0, not core.powered()), "fraction": core.battery_pct() / 100.0, "text": battery_text},
		"warmth": {"tone": tone.call(core.temp_c < 12.0, core.temp_c < 0.0), "fraction": clampf((core.temp_c + 10.0) / 32.0, 0.0, 1.0), "text": warm_text},
		"air": {"tone": tone.call(co2 >= 1.0 or core.leaking() or core.o2_pct() < 19.5, co2 >= 3.0 or core.o2_pct() < 17.0), "fraction": clampf(core.air_fraction(), 0.0, 1.0), "text": air_text}}

func _base_signature() -> String:
	var hud: Node = world.get("explore_hud") if world != null else null
	var alerts: Node = world.get("alerts") if world != null else null
	var rows: Dictionary = hud.system_rows() if hud != null else {}
	var words: Array = rows.values().map(func(r): return str(r.text))
	var sim: RefCounted = world.builder.simulation() if world != null and world.builder != null else null
	var stock := _feedstock_words(sim) if MHChapterOne.on() and sim != null else ""
	var cabin: Node = world.get("cabin_life") if world != null else null
	if cabin != null and cabin.running() and rows.is_empty(): stock += str(_cabin_rows(cabin).values().map(func(r): return str(r.text)))
	var module: Node = _shown_core() if world != null else null
	if module != null and module.running() and bool(module.commissioned): stock += str(_cabin_rows(module).values().map(func(r): return str(r.text)))
	stock += "|%s|%s|%s" % [_base_choice(), str(_bases_listed()), MHMaterials.store_line()]
	return "%s|%s|%s|%d" % [str(words), stock, str(alerts.active_alerts().map(func(a): return "%s%s" % [a.id, a.level])) if alerts != null else "", alerts.history.size() if alerts != null else 0]

## Redraws the open app in place.
func _redraw() -> void:
	_rebuild()

## Comms: messages from Earth by person, newest first, each with Play; and
## the Discoveries (what's been found, leads, and what might be out there).
## One-way: no replies (docs/mission-control-voice.md).
func _comms_page() -> Control:
	_shown_comms = _comms_signature()
	var link: Node = get_tree().get_first_node_in_group("mission_control_link") if is_inside_tree() else null
	var page := MHStyle.vbox(14)
	var top := MHStyle.hbox(10)
	top.add_child(MHStyle.spacer())
	if link != null: top.add_child(MHStyle.mono(str(link.rota_line()), 15, MHStyle.INFO))
	page.add_child(top)
	if not _linked(): page.add_child(MHStyle.body("No link down here: new messages wait until you're back under the sky.", 16, MHStyle.WARN))
	var radio: Node = world.get("radio") if world != null else null
	if radio != null and radio.has_method("link_line"):
		page.add_child(MHStyle.mono(str(radio.link_line()), 15, MHStyle.INFO if bool(radio.in_contact()) else MHStyle.WARN))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := MHStyle.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if _comms_tab != "discoveries": _orbiter(list)
	if _comms_tab == "discoveries": _discoveries(list)
	elif link == null: list.add_child(MHStyle.body("No Mission Control link in this game.", 17, MHStyle.TEXT_MUTED))
	else: _messages(list, link)
	return page

## The orbiter crew's texts (scripts/orbiter_texts.gd), newest first, with
## their photos: grainy and soft, as from orbit.
func _orbiter(list: VBoxContainer) -> void:
	var texts: Node = get_tree().get_first_node_in_group("orbiter_texts") if is_inside_tree() else null
	if texts == null or (texts.messages as Array).is_empty(): return
	list.add_child(MHStyle.eyebrow("FROM ORBIT · TEXT ONLY", MHStyle.INFO, 13))
	var shown: Array = (texts.messages as Array).duplicate()
	shown.reverse()
	for message in shown:
		var person: Dictionary = texts.person_of(str(message.who))
		var row := MHStyle.hbox(14)
		var when := MHStyle.vbox(2)
		when.custom_minimum_size.x = 120
		when.add_child(MHStyle.mono("SOL %d" % int(message.get("sol", 1)), 15, MHStyle.TEXT_MUTED))
		when.add_child(MHStyle.mono("%02d:%02d" % [floori(float(message.get("hour", 0.0))), floori(fmod(float(message.get("hour", 0.0)), 1.0) * 60.0)], 13, MHStyle.TEXT_MUTED))
		row.add_child(when)
		var words := MHStyle.vbox(8)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(MHStyle.label("%s · %s" % [str(person.get("name", message.who)), str(person.get("role", ""))], 17, MHStyle.INFO, 700))
		var body := MHStyle.body(str(message.text), 17, MHStyle.TEXT_PRIMARY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(body)
		var picture: Texture2D = texts.photo(str(message.get("photo", "")))
		if not str(message.get("photo", "")).is_empty():
			words.add_child(_orbit_photo(picture))
		row.add_child(words)
		list.add_child(row)
	list.add_child(HSeparator.new())

const ORBIT_PHOTO_SHADER := """
shader_type canvas_item;
uniform float grain = 0.16;
void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float grey = dot(colour.rgb, vec3(0.3, 0.59, 0.11));
	colour.rgb = mix(colour.rgb, vec3(grey), 0.45);
	vec2 cell = floor(UV * vec2(240.0, 150.0));
	float noise = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	colour.rgb += (noise - 0.5) * grain;
	float edge = smoothstep(0.75, 0.2, length(UV - vec2(0.5)));
	colour.rgb *= mix(0.72, 1.0, edge);
	COLOR = vec4(colour.rgb, 1.0);
}
"""

## A photo from orbit, or a grey frame saying it's still coming down the link.
func _orbit_photo(picture: Texture2D) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", MHStyle.box(Color(0, 0, 0, .6), MHStyle.BORDER_STRONG, 6, 1, Vector4(4, 4, 4, 4)))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if picture == null:
		var waiting := MHStyle.mono("PHOTO · RECEIVING", 13, MHStyle.TEXT_MUTED)
		waiting.custom_minimum_size = Vector2(480, 300)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(waiting)
		return frame
	var image := TextureRect.new()
	image.texture = picture
	image.custom_minimum_size = Vector2(480, 300)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = ORBIT_PHOTO_SHADER
	image.material = material
	frame.add_child(image)
	return frame

func _messages(list: VBoxContainer, link: Node) -> void:
	link.mark_read()
	var cast: Dictionary = link.cast().get("people", {})
	var spoken := {}
	for message in link.messages: spoken[str(message.speaker)] = true
	if spoken.size() > 1:
		var people := HFlowContainer.new()
		people.add_theme_constant_override("h_separation", 8)
		people.add_theme_constant_override("v_separation", 8)
		var choices: Array = [["", "Everyone"]]
		for id in cast:
			if spoken.has(id): choices.append([str(id), "%s · %s" % [str(cast[id].short), str(cast[id].role)]])
		for choice in choices:
			var chip := MHStyle.button(str(choice[1]), "primary" if _comms_only == choice[0] else "ghost", "", 40)
			chip.focus_mode = Control.FOCUS_NONE
			var who := str(choice[0])
			chip.pressed.connect(func() -> void:
				_comms_only = who
				_redraw())
			people.add_child(chip)
		list.add_child(people)
	var shown: Array = (link.messages as Array).filter(func(m): return _comms_only.is_empty() or str(m.speaker) == _comms_only)
	shown.reverse()
	if shown.is_empty():
		list.add_child(MHStyle.body("Nothing from Earth yet. Messages take minutes to cross; they'll be here.", 17, MHStyle.TEXT_MUTED))
	for message in shown:
		var who: Dictionary = cast.get(str(message.speaker), {})
		var row := MHStyle.hbox(14)
		var when := MHStyle.vbox(2)
		when.custom_minimum_size.x = 120
		when.add_child(MHStyle.mono("SOL %d" % (floori(float(message.hours) / 24.0) + 1), 15, MHStyle.TEXT_MUTED))
		when.add_child(MHStyle.mono(str(link.earth_clock(float(message.earth))), 13, MHStyle.TEXT_MUTED))
		row.add_child(when)
		var words := MHStyle.vbox(4)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(MHStyle.label("%s · %s" % [str(who.get("name", message.speaker)), str(who.get("role", ""))], 17, MHStyle.INFO, 700))
		var body := MHStyle.body(str(message.text), 17, MHStyle.TEXT_PRIMARY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(body)
		row.add_child(words)
		var play := MHStyle.button("Play", "ghost", "play", 44)
		play.focus_mode = Control.FOCUS_NONE
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var entry: Dictionary = message
		play.pressed.connect(func() -> void: MHAudio.cast_line(str(entry.id), "%s · %s" % [str(who.get("name", "")), str(who.get("role", ""))], str(entry.text), "replayed"))
		row.add_child(play)
		list.add_child(row)

func _discoveries(list: VBoxContainer) -> void:
	list.add_child(MHStyle.eyebrow("DISCOVERIES · %d OF %d" % [MHSamples.found.size(), MHSamples.discoveries().size()], MHStyle.accent, 13))
	var counts := MHSamples.section_counts()
	for section in ["life", "climate", "geology", "humans"]:
		var tally: Array = counts.get(section, [0, 0])
		var title := MHStyle.hbox(8)
		title.add_child(MHStyle.icon(str((MHSamples.data().get("sections", {}) as Dictionary).get(section, {}).get("icon", "flask-conical")), 20, MHStyle.accent))
		title.add_child(MHStyle.label("%s  %d / %d" % [MHSamples.section_label(section), int(tally[0]), int(tally[1])], 19, MHStyle.TEXT_PRIMARY, 700))
		list.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for entry in MHSamples.discoveries():
			if str(entry.section) != section: continue
			var card := MHMissionControl._discovery_card(entry)
			card.custom_minimum_size.x = 440
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
		list.add_child(grid)

## Site: where you are (room or outside, the ground, the grid), the air
## outside, radiation, how much sun the arrays get, and the storm forecast
## (the old site telemetry, zone chip and storm pill).
func _site_page() -> Control:
	var facts := _site_facts()
	_shown_site = str(facts)
	var page := MHStyle.vbox(18)
	page.add_child(_heading("Site", str(facts.where)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for tile in facts.tiles: grid.add_child(_site_tile(tile[0], tile[1], tile[2], tile[3]))
	page.add_child(grid)
	var storm := PanelContainer.new()
	var tone: Color = facts.storm_tone
	storm.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(tone, .45), MHStyle.RADIUS_MD, 1, Vector4(20, 14, 20, 14)))
	var row := MHStyle.hbox(14)
	row.add_child(MHStyle.icon("wind", 26, tone))
	var words := MHStyle.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(MHStyle.label(str(facts.storm), 20, MHStyle.TEXT_PRIMARY, 700))
	var detail := MHStyle.body(str(facts.storm_detail), 16)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(detail)
	row.add_child(words)
	storm.add_child(row)
	page.add_child(storm)
	return page

func _site_tile(caption: String, glyph: String, value: String, colour: Color) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(300, 0)
	tile.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(16, 12, 16, 12)))
	var column := MHStyle.vbox(6)
	var top := MHStyle.hbox(8)
	top.add_child(MHStyle.icon(glyph, 18, MHStyle.TEXT_MUTED))
	top.add_child(MHStyle.eyebrow(caption, MHStyle.TEXT_MUTED, 13))
	column.add_child(top)
	var big := MHStyle.label(value, 24, colour, 700)
	big.clip_text = true
	column.add_child(big)
	tile.add_child(column)
	return tile

## What the Site page shows, worked out once (also its signature).
func _site_facts() -> Dictionary:
	var player: Node3D = world.player
	var builder: Node = world.builder
	var telemetry: Dictionary = MHGame.site().get("telemetry", {})
	var climate: Dictionary = builder.climate_at(player.global_position) if builder != null else {}
	var cave := MHCaves.cave_at(player.global_position)
	var unit := MHSiteTerrain.geology_unit(player.global_position.x, player.global_position.z) if str(climate.get("state", "outside")) == "outside" else ""
	var where := str(climate.get("context", "Outside"))
	if not cave.is_empty(): where = "In a cave · no link"
	elif not unit.is_empty(): where += " · on %s" % MHSamples.unit_label(unit)
	var region: Node = world.get("region_map")
	if region != null: where += " · " + str(region._coordinates(region._you()))
	var solar := MHGame.solar_irradiance(MHGame.sol_hour)
	var sim: RefCounted = builder.simulation() if builder != null else null
	var storm_left := float(sim.storm_hours_left) if sim != null else 0.0
	var eta := float(sim.storm_eta_hours) if sim != null else -1.0
	if storm_left > 0.0: solar *= 1.0 - float(sim.solar_cut())
	var radiation := str(climate.get("radiation", telemetry.get("radiation", "—")))
	var storm := "Clear skies"
	var storm_detail := "No dust storm forecast. Storms are forecast hours ahead and cut the sun on the arrays."
	var storm_tone := MHStyle.VALID
	if storm_left > 0.0:
		storm = "Dust storm"
		storm_detail = "About %s left. The arrays get a fraction of the sun; the batteries carry the base." % _hours_text(storm_left)
		storm_tone = MHStyle.DANGER
	elif eta >= 0.0:
		storm = "Storm in %s" % _hours_text(eta)
		storm_detail = "Charge the batteries and finish outside work before it arrives."
		storm_tone = MHStyle.WARN
	return {"where": where, "storm": storm, "storm_detail": storm_detail, "storm_tone": storm_tone, "tiles": [
		["TEMPERATURE", "flame", "%d °C" % roundi(float(climate.get("temperature", telemetry.get("outside_temp_c", -30.0)))), MHStyle.INFO],
		["ELEVATION", "mountain-snow", str(telemetry.get("elevation", "—")), MHStyle.TEXT_PRIMARY],
		["RADIATION", "radiation", radiation, MHStyle.WARN if radiation == "High" else MHStyle.VALID],
		["SOLAR", "sun", "%d%%" % roundi(solar * 100.0), MHStyle.VALID if solar > .1 else MHStyle.TEXT_MUTED],
		["TIME", "clock", MHGame.formatted_sol_time(), MHStyle.TEXT_PRIMARY],
		["DAYLIGHT", "moon" if MHGame.sunlight_fraction <= .08 else "sun", "Night" if MHGame.sunlight_fraction <= .08 else "Day", MHStyle.TEXT_PRIMARY],
	]}

## "5 hours", "1.5 sols".
static func _hours_text(hours: float) -> String:
	return "%d hours" % ceili(hours) if hours < 24.0 else "%.1f sols" % (hours / 24.0)

func _site_signature() -> String:
	return str(_site_facts())

## Changes when the Comms page would look different.
func _comms_signature() -> String:
	var link: Node = get_tree().get_first_node_in_group("mission_control_link") if is_inside_tree() else null
	var texts: Node = get_tree().get_first_node_in_group("orbiter_texts") if is_inside_tree() else null
	var photo_in: bool = texts != null and not texts.latest_photo().is_empty() and texts.photo(str(texts.latest_photo().photo)) != null
	var radio: Node = world.get("radio") if world != null else null
	var contact: bool = radio == null or not radio.has_method("in_contact") or bool(radio.in_contact())
	return "%s|%d|%d|%d|%s|%d|%s" % [contact, (link.messages as Array).size() if link != null else 0, MHSamples.found.size(), MHSamples.leads.size(), _linked(), int(texts.version) + (texts.messages as Array).size() if texts != null else 0, photo_in]

## Map: the region map itself, lent to the screen (region_map.gd embed):
## wheel zoom, drag, Z, Space, L for the ice survey and G to send GAR-Y.
func _map_page() -> Control:
	var region := _region()
	if region == null:
		var empty := MHStyle.vbox(12)
		empty.add_child(_heading("Map", "No region map at this site."))
		return empty
	var page := MHStyle.hbox(24)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(MAP_FIT, MAP_FIT)
	holder.clip_contents = true
	page.add_child(holder)
	var side := MHStyle.vbox(12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(side)
	side.add_child(MHStyle.eyebrow("REGION MAP · %s" % str(MHGame.site().get("name", "")).to_upper(), MHStyle.accent, 13))
	_map_you = MHStyle.body("", 16, MHStyle.TEXT_SECONDARY)
	_map_you.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_map_you)
	_map_cursor = MHStyle.body("", 16, MHStyle.TEXT_MUTED)
	_map_cursor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_map_cursor)
	side.add_child(GUIDE.keys_box([[["Wheel"], "Zoom"], [["Drag"], "Move"], [["Z"], "Region / 1 km"], [["Space"], "You"], [["Click"], "Drop a pin · or, with a walker free, its spot"], [["T"], "Track the mark nearest"], [["L"], "Ice survey"], [["G"], "GAR-Y: survey the zone"]]))
	holder.ready.connect(func() -> void: region.embed.call_deferred(holder, MAP_FIT), CONNECT_ONE_SHOT)
	return page

func _region() -> Node:
	return world.get("region_map") if world != null else null

## Gives the map square back before the page goes (or the slate is lowered).
func _lend_map(_on: bool) -> void:
	var region := _region()
	if region != null and bool(region.embedded): region.unembed()
	_map_you = null
	_map_cursor = null

## The slate was lowered.
func closed() -> void:
	_lend_map(false)
	if app == "camera": _camera_off()

# ---------- Cargo: the mission's manifest (data/cargo_manifest.json) ----------

const MANIFEST_PATH := "res://data/cargo_manifest.json"
var _manifest := {}
var _shown_cargo := ""

func _manifest_data() -> Dictionary:
	if _manifest.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary: _manifest = parsed
	return _manifest

## "recovered", "seen", "glimpsed" (a glint far out) or "missing" for a manifest line.
func cargo_state(entry: Dictionary) -> String:
	var source := str(entry.get("source", ""))
	var known: Node = world.get("known") if world != null else null
	if source == "storm_drop":
		var drop: Node = world.get("storm_drop")
		if drop != null and drop.pallet != null and bool(drop.pallet.opened): return "recovered"
		if known != null and (known.knows("find:parachute") or known.knows("find:parachute", "orbiter")): return "seen"
	elif source == "walker":
		var walker: Node = world.get("walker")
		if walker != null and str(walker.state) != "stalled": return "recovered"
		if walker != null and walker.knows(): return "seen"
	elif source.begins_with("wreck:"):
		# 21 Nov (R3): a vehicle's container. Recovered once it's fixed; seen
		# once you've found it; the HabRover can first be a glint far out.
		var kind := source.trim_prefix("wreck:")
		var vehicle: Node = world.get({"buggy": "buggy", "rover": "crew_rover", "drone": "drone"}.get(kind, kind))
		if vehicle != null and not (str(vehicle.get("state")) == "wrecked" if kind == "drone" else bool(vehicle.get("wrecked"))): return "recovered"
		if known != null and known.knows("wreck:" + kind): return "seen"
		if known != null and kind == "rover" and known.knows("glint:habrover"): return "glimpsed"
	elif source.begins_with("drop_field:"):
		var field: Node = world.get("drop_field")
		var kind := source.trim_prefix("drop_field:")
		if field != null and field.sites.has(kind):
			var site: Node = field.sites[kind]
			# GAR-Y's pallet: recovered once you've met it, not when it let itself
			# out in the storm (playtest 14 Nov: "recovered" on day 1).
			if kind == "gary":
				if bool(world.get("gary_met")): return "recovered"
			elif (site.pallet != null and bool(site.pallet.opened)) or bool(site.get("empty")): return "recovered"
			if known != null and (known.knows(site.id()) or known.knows(site.id(), "orbiter")): return "seen"
	return "missing"

func _cargo_signature() -> String:
	var data := _manifest_data()
	return ",".join(((data.get("pallets", []) as Array) + (data.get("walkers", []) as Array)).map(func(e): return cargo_state(e)))

func _cargo_page() -> Control:
	_shown_cargo = _cargo_signature()
	var data := _manifest_data()
	var page := MHStyle.vbox(14)
	var pallets: Array = data.get("pallets", [])
	var found := pallets.filter(func(e): return cargo_state(e) == "recovered").size()
	page.add_child(_heading("Cargo manifest", "Landed ahead of you, scattered by the storm. %d of %d pallets recovered." % [found, pallets.size()]))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := MHStyle.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in pallets: list.add_child(_cargo_row(entry, cargo_state(entry)))
	list.add_child(MHStyle.eyebrow("WALKING CARRIERS", MHStyle.TEXT_MUTED, 13))
	for entry in data.get("walkers", []): list.add_child(_cargo_row(entry, cargo_state(entry)))
	return page

func _cargo_row(entry: Dictionary, state: String) -> Control:
	var colour: Color = {"recovered": MHStyle.VALID, "seen": MHStyle.WARN, "glimpsed": MHStyle.INFO}.get(state, MHStyle.TEXT_MUTED)
	var row := MHStyle.hbox(14)
	row.add_child(MHStyle.icon({"recovered": "circle-check", "seen": "eye", "glimpsed": "eye"}.get(state, "circle-dashed"), 20, colour))
	var words := MHStyle.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# No spoilers (playtest 14 Nov): what a pallet holds shows once it's
	# found; until it's seen, only its number.
	var title := str(entry.name) if not state in ["missing", "glimpsed"] else str(entry.name).get_slice(" · ", 0)
	var what := str(entry.holds) if state == "recovered" else (str(entry.get("seen_text", "Seen, not opened yet.")) if state == "seen" else (str(entry.get("glimpsed_text", "Glimpsed.")) if state == "glimpsed" else "No signal yet."))
	words.add_child(MHStyle.label(title, 18, MHStyle.TEXT_PRIMARY if state != "missing" else MHStyle.TEXT_SECONDARY, 700))
	var holds := MHStyle.body(what, 15, MHStyle.TEXT_SECONDARY if state != "missing" else MHStyle.TEXT_MUTED)
	holds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(holds)
	row.add_child(words)
	row.add_child(MHStyle.mono({"recovered": "RECOVERED", "seen": "SEEN", "glimpsed": "GLINT"}.get(state, "NO SIGNAL"), 13, colour, 700))
	return row

# ---------- Camera: photos for the journal (scripts/slate_camera.gd) ----------

var _camera_hint: Label

func _camera() -> Node:
	return world.get("slate_camera") if world != null else null

func _camera_page() -> Control:
	var page := MHStyle.vbox(14)
	var camera := _camera()
	if camera == null:
		page.add_child(_heading("Camera", "No camera on this slate."))
		return page
	var view := TextureRect.new()
	view.texture = camera.viewfinder()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(880, 495)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(view)
	# The reticle: corner brackets and a centre mark, green when it's on something.
	_reticle = Control.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	view.add_child(_reticle)
	var row := MHStyle.hbox(16)
	_camera_hint = MHStyle.body("", 17, MHStyle.TEXT_SECONDARY)
	_camera_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_camera_hint)
	var take := MHStyle.button("Take picture  E", "primary", "camera", 48)
	take.focus_mode = Control.FOCUS_NONE
	take.pressed.connect(shutter)
	row.add_child(take)
	page.add_child(row)
	# 3c: a picture of the walker's tracks can go up to the orbiter.
	var walker: Node = world.get("walker") if world != null else null
	if walker != null and walker.can_send():
		var send := MHStyle.button("Send the tracks photo to the orbiter", "secondary", "radio", 44)
		send.focus_mode = Control.FOCUS_NONE
		send.pressed.connect(func() -> void:
			if walker.send_up(): send.disabled = true; send.text = "Sent: it goes up on the next pass")
		page.add_child(send)
	# The last few shots, so you can see they took.
	_roll = MHStyle.hbox(10)
	page.add_child(_roll)
	_shown_roll = -1
	_camera_words()
	if pda != null: pda.camera_mode(true)
	return page

var _reticle: Control
var _roll: HBoxContainer
var _shown_roll := -1
var _aimed := false

func _draw_reticle() -> void:
	var size := _reticle.size
	var mid := size * .5
	var colour := MHStyle.VALID if _aimed else Color(1, 1, 1, .8)
	var arm := 22.0
	_reticle.draw_line(mid - Vector2(arm, 0), mid - Vector2(6, 0), colour, 2.0)
	_reticle.draw_line(mid + Vector2(6, 0), mid + Vector2(arm, 0), colour, 2.0)
	_reticle.draw_line(mid - Vector2(0, arm), mid - Vector2(0, 6), colour, 2.0)
	_reticle.draw_line(mid + Vector2(0, 6), mid + Vector2(0, arm), colour, 2.0)
	var box := Vector2(size.y * .28, size.y * .28)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c: Vector2 = mid + box * corner
		_reticle.draw_line(c, c - Vector2(corner.x * 18.0, 0), colour, 2.0)
		_reticle.draw_line(c, c - Vector2(0, corner.y * 18.0), colour, 2.0)

func _camera_words() -> void:
	var camera := _camera()
	if _camera_hint == null or camera == null: return
	var found: Array = camera.subjects()
	var on: Dictionary = camera.aimed(found)
	var zoom := "  ·  zoom %.1f×" % float(camera.zoom) if float(camera.zoom) > 1.01 else ""
	if not on.is_empty(): _camera_hint.text = "On: %s%s" % [str(on.name), zoom]
	elif not found.is_empty(): _camera_hint.text = "In frame: %s%s" % [", ".join(found.map(func(s): return str(s.name))), zoom]
	else: _camera_hint.text = "Aim the reticle at something. Wheel to zoom.%s" % zoom
	if _reticle != null and is_instance_valid(_reticle):
		_aimed = not on.is_empty()
		_reticle.queue_redraw()
	if _roll != null and is_instance_valid(_roll) and _shown_roll != int(camera.shots):
		_shown_roll = int(camera.shots)
		for child in _roll.get_children(): child.queue_free()
		for shot in camera.roll:
			var thumb := TextureRect.new()
			thumb.texture = shot.texture
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.custom_minimum_size = Vector2(200, 112)
			thumb.tooltip_text = str(shot.caption)
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_roll.add_child(thumb)
		if not camera.roll.is_empty(): _roll.add_child(MHStyle.body("Also in your journal: J, indoors.", 15, MHStyle.TEXT_SECONDARY))

func shutter() -> void:
	var camera := _camera()
	if camera == null or not camera.can_take(): return
	camera.take()

func _camera_off() -> void:
	var camera := _camera()
	if camera != null: camera.stop_viewfinder()
	_camera_hint = null
	if pda != null: pda.camera_mode(false)
