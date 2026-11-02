extends Control

## The slate's screen (scripts/pda.gd, docs/pda.md §3): drawn into its
## SubViewport at 1280 x 800. A status bar along the top (time, day or night,
## the resupply countdown, the link), a rail of apps down the left with an
## unread dot on each, and the open app filling the rest. 1–6 switch apps.
##
## Apps arrive one at a time (docs/pda.md §9); the rail shows those built.

const APPS := [
	{"id": "goals", "label": "Goals", "icon": "clipboard-check", "built": false},
	{"id": "map", "label": "Map", "icon": "map-pin", "built": true},
	{"id": "base", "label": "Base", "icon": "gauge", "built": false},
	{"id": "comms", "label": "Comms", "icon": "satellite", "built": false},
	{"id": "site", "label": "Site", "icon": "mountain-snow", "built": false},
	{"id": "log", "label": "Log", "icon": "clock", "built": true},
]
const SIZE := Vector2(1280, 800)

var world: Node
var pda: Node
var app := ""
var _clock: Label
var _link: Label
var _rail: VBoxContainer
var _rail_buttons := {}   # app id -> {button, dot}
var _page: MarginContainer
var _shown_log := -1      # notices on the Log page when it was drawn
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
	if not choice in apps(): choice = "log"
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
