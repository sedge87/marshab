extends Control

## The slate's screen (scripts/pda.gd, docs/pda.md §3): drawn into its
## SubViewport at 1280 x 800. A status bar along the top (time, day or night,
## the resupply countdown, the link), a rail of apps down the left with an
## unread dot on each, and the open app filling the rest. 1–6 switch apps.
##
## Apps arrive one at a time (docs/pda.md §9); the rail shows those built.

const APPS := [
	{"id": "goals", "label": "Goals", "icon": "clipboard-check", "built": true},
	{"id": "map", "label": "Map", "icon": "map-pin", "built": true},
	{"id": "base", "label": "Base", "icon": "gauge", "built": true},
	{"id": "comms", "label": "Comms", "icon": "satellite", "built": true},
	{"id": "site", "label": "Site", "icon": "mountain-snow", "built": true},
	{"id": "log", "label": "Log", "icon": "clock", "built": true},
]
const SIZE := Vector2(1280, 800)
const GUIDE := preload("res://scripts/guide_overlay.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var world: Node
var pda: Node
var app := ""
var _clock: Label
var _link: Label
var _rail: VBoxContainer
var _rail_buttons := {}   # app id -> {button, dot}
var _page: MarginContainer
var _shown_log := -1      # notices on the Log page when it was drawn
var _shown_goals := ""    # what the Goals page showed (redrawn when it changes)
var _map_you: Label
var _shown_base := ""     # what the Base page showed
var _shown_comms := ""    # what the Comms page showed
var _shown_site := ""     # what the Site page showed
var _comms_tab := "messages"
var _comms_only := ""     # one person's messages, or everyone's
const SYSTEMS := [["battery", "Battery", "zap"], ["water", "Water", "droplets"], ["food", "Food", "wheat"], ["air", "Air", "wind"], ["crew", "Crew health", "heart-pulse"]]
var _map_cursor: Label
const MAP_FIT := 600.0    # the map square on the screen, px
var _tick := 0.0

func _ready() -> void:
	size = SIZE
	theme = MHStyle.theme()
	var back := ColorRect.new()
	back.color = MHStyle.INK_950
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	# Kept clear of the edges: the bezel's raised lip hides a sliver of each side.
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: safe.add_theme_constant_override("margin_" + side, 44)
	for side in ["top", "bottom"]: safe.add_theme_constant_override("margin_" + side, 28)
	add_child(safe)
	var column := MHStyle.vbox(0)
	safe.add_child(column)
	column.add_child(_status_bar())
	var body := MHStyle.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_rail())
	_page = MarginContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: _page.add_theme_constant_override("margin_" + side, 28)
	body.add_child(_page)

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

func _build_rail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 200
	panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_900, Color(0, 0, 0, 0), 0, 0, Vector4(12, 16, 12, 16)))
	_rail = MHStyle.vbox(8)
	panel.add_child(_rail)
	var n := 0
	for entry in APPS:
		if not bool(entry.built): continue
		n += 1
		var button := MHStyle.button("%d  %s" % [n, entry.label], "ghost", str(entry.icon), 56)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(show_app.bind(str(entry.id)))
		var dot := ColorRect.new()
		dot.color = MHStyle.accent
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size = Vector2(10, 10)
		dot.position = Vector2(166, 23)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(dot)
		_rail.add_child(button)
		_rail_buttons[str(entry.id)] = {"button": button, "dot": dot}
	return panel

## Built apps, in rail order.
func apps() -> Array:
	return APPS.filter(func(entry): return bool(entry.built)).map(func(entry): return str(entry.id))

## The slate was raised (pda.gd): on this app, or the last one used.
func opened(wanted := "") -> void:
	var choice := wanted if wanted in apps() else str(MHGame.setting("slate_app"))
	if not choice in apps(): choice = "goals"
	app = ""
	show_app(choice)
	_update_status()

func show_app(id: String) -> void:
	if id == app and _page.get_child_count() > 0: return
	_lend_map(false)
	app = id
	MHNotices.seen(id)
	if world != null and world.get("guide_flags") != null: world.guide_flags["slate_" + id] = true
	var values := MHGame.settings()
	if str(values.get("slate_app", "")) != id:
		values["slate_app"] = id
		MHGame.save_settings(values)
	for child in _page.get_children(): child.queue_free()
	match id:
		"map": _page.add_child(_map_page())
		"goals": _page.add_child(_goals_page())
		"base": _page.add_child(_base_page())
		"comms": _page.add_child(_comms_page())
		"site": _page.add_child(_site_page())
		_: _page.add_child(_log_page())
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
	var index := (event as InputEventKey).keycode - KEY_1
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
	if app == "log" and MHNotices.history.size() != _shown_log:
		for child in _page.get_children(): child.queue_free()
		_page.add_child(_log_page())
		MHNotices.seen("log")
	if app == "map" and _map_you != null and _region() != null:
		var lines: Array = _region().readouts()
		_map_you.text = str(lines[0])
		_map_cursor.text = str(lines[1])
	if app == "comms" and _comms_signature() != _shown_comms: _redraw()
	if app == "site" and _site_signature() != _shown_site: _redraw()
	if app == "base" and _base_signature() != _shown_base:
		for child in _page.get_children(): child.queue_free()
		_page.add_child(_base_page())
		MHNotices.seen("base")
	if app == "goals" and _goals_signature() != _shown_goals:
		for child in _page.get_children(): child.queue_free()
		_page.add_child(_goals_page())
		MHNotices.seen("goals")

func _update_status() -> void:
	var daytime := MHGame.sunlight_fraction > .08
	var text := "%s · %s" % [MHGame.formatted_sol_time(), "DAY" if daytime else "NIGHT"]
	var builder: Node = world.builder if world != null else null
	if MHGame.resupplies_on() and MHGame.game_mode != "missions" and builder != null:
		var due := MHGame.resupply_due_in_hours(builder.simulation().hours_run)
		text += "  ·  RESUPPLY %s" % ("%d H" % ceili(due) if due < 24.0 else "%.1f SOLS" % (due / 24.0))
	_clock.text = text
	_clock.add_theme_color_override("font_color", MHStyle.INFO if daytime else MHStyle.TEXT_MUTED)
	var linked := _linked()
	_link.text = "LINK" if linked else "NO LINK"
	_link.add_theme_color_override("font_color", MHStyle.VALID if linked else MHStyle.WARN)
	for key in _rail_buttons:
		(_rail_buttons[key].dot as Control).visible = key != app and int(MHNotices.unread.get(key, 0)) > 0

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
	page.add_child(_heading("Log", "Everything you've been told, newest first."))
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
	if builder == null or MHGame.game_mode == "missions": return
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
	return "%s|%s|%s" % [str(tutorial.done) if tutorial != null else "", str(tutorial.finished) if tutorial != null else "", str(builder.readiness()) if builder != null and MHGame.game_mode != "missions" else ""]

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
	if rows.is_empty():
		left.add_child(_heading("Base", "No habitat yet: its systems show here once the first module stands." if MHGame.simulation_on() else "Creative mode: no simulation to watch."))
		return page
	left.add_child(_heading("Base", "%d crew%s" % [sim.crew_count(), " · dust storm" if bool(sim.last.get("storm", false)) else ""]))
	for entry in SYSTEMS:
		var row: Dictionary = rows.get(entry[0], {})
		if row.is_empty(): continue
		left.add_child(_gauge(str(entry[1]), str(entry[2]), row))
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

## Changes when the Base page would look different.
func _base_signature() -> String:
	var hud: Node = world.get("explore_hud") if world != null else null
	var alerts: Node = world.get("alerts") if world != null else null
	var rows: Dictionary = hud.system_rows() if hud != null else {}
	var words: Array = rows.values().map(func(r): return str(r.text))
	return "%s|%s|%d" % [str(words), str(alerts.active_alerts().map(func(a): return "%s%s" % [a.id, a.level])) if alerts != null else "", alerts.history.size() if alerts != null else 0]

## Redraws the open app in place.
func _redraw() -> void:
	for child in _page.get_children(): child.queue_free()
	match app:
		"comms": _page.add_child(_comms_page())
		"site": _page.add_child(_site_page())
	MHNotices.seen(app)

## Comms: messages from Earth by person, newest first, each with Play; and
## the Discoveries (what's been found, leads, and what might be out there).
## One-way: no replies (docs/mission-control-voice.md).
func _comms_page() -> Control:
	_shown_comms = _comms_signature()
	var link: Node = get_tree().get_first_node_in_group("mission_control_link") if is_inside_tree() else null
	var page := MHStyle.vbox(14)
	var top := MHStyle.hbox(10)
	for tab in [["messages", "Messages", "satellite"], ["discoveries", "Discoveries", "sparkles"]]:
		var button := MHStyle.button(str(tab[1]), "primary" if _comms_tab == tab[0] else "secondary", str(tab[2]), 48)
		button.focus_mode = Control.FOCUS_NONE
		var id := str(tab[0])
		button.pressed.connect(func() -> void:
			_comms_tab = id
			_redraw())
		top.add_child(button)
	top.add_child(MHStyle.spacer())
	if link != null: top.add_child(MHStyle.mono(str(link.rota_line()), 15, MHStyle.INFO))
	page.add_child(top)
	if not _linked(): page.add_child(MHStyle.body("No link down here: new messages wait until you're back under the sky.", 16, MHStyle.WARN))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := MHStyle.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if _comms_tab == "discoveries": _discoveries(list)
	elif link == null: list.add_child(MHStyle.body("No Mission Control link in this game.", 17, MHStyle.TEXT_MUTED))
	else: _messages(list, link)
	return page

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
	return "%d|%d|%d|%s" % [(link.messages as Array).size() if link != null else 0, MHSamples.found.size(), MHSamples.leads.size(), _linked()]

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
	side.add_child(GUIDE.keys_box([[["Wheel"], "Zoom"], [["Drag"], "Move"], [["Z"], "Region / 1 km"], [["Space"], "You"], [["L"], "Ice survey"], [["G"], "GAR-Y: survey the zone"]]))
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
