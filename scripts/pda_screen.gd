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
	{"id": "base", "label": "Base", "icon": "gauge", "built": false},
	{"id": "comms", "label": "Comms", "icon": "satellite", "built": false},
	{"id": "site", "label": "Site", "icon": "mountain-snow", "built": false},
	{"id": "log", "label": "Log", "icon": "clock", "built": true},
]
const SIZE := Vector2(1280, 800)
const GUIDE := preload("res://scripts/guide_overlay.gd")

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
	app = id
	MHNotices.seen(id)
	var values := MHGame.settings()
	if str(values.get("slate_app", "")) != id:
		values["slate_app"] = id
		MHGame.save_settings(values)
	for child in _page.get_children(): child.queue_free()
	match id:
		"map": _page.add_child(_map_page())
		"goals": _page.add_child(_goals_page())
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

## Map: for now the region map opens over the view (it moves onto the
## slate's screen next, docs/pda.md §9).
func _map_page() -> Control:
	var page := MHStyle.vbox(20)
	var region: Node = world.get("region_map") if world != null else null
	if region == null:
		page.add_child(_heading("Map", "No region map at this site."))
		return page
	page.add_child(_heading("Map", "The region: places, your base, GAR-Y and its survey stakes, your trail. L shows the ice survey; G sends GAR-Y."))
	var open := MHStyle.button("Open the map", "primary", "map-pin", 64)
	open.custom_minimum_size.x = 320
	open.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	open.focus_mode = Control.FOCUS_NONE
	open.pressed.connect(_open_region_map)
	page.add_child(open)
	return page

func _open_region_map() -> void:
	pda.close()
	world.region_map.call_deferred("open_from_slate")
