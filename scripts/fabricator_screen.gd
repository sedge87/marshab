extends Control

## The Print Shop's screen (E on the Print Shop; docs/start-and-chapter-one.md §4).
## "Needed now" at the top (the plans the chapter just unlocked, and spares
## kits when a machine is worn), then the known plans as cards in tabs by
## purpose, with a search box. Pick a card to see its feedstock, Earth parts,
## time and power, and print it. Each Print Shop runs its own job, with a
## queue of up to five (§13.5); this screen is the one you pressed E on. The first job makes the
## plan: the item goes onto the build bar's Unpacked tab for good, and later
## copies are paid for from the stores as they're placed. The game keeps
## running while this is open.

signal closed

## Tabs by purpose, in order. Items not listed here fall back on their
## catalogue group (GROUP_TABS), then "Work".
const TABS := ["All", "Water", "Air", "Food", "Power", "Outside", "Crew", "Safety", "Work", "Upkeep", "Decor"]
const TAB_ICONS := {"All": "layout-grid", "Water": "droplets", "Air": "wind", "Food": "sprout", "Power": "zap", "Outside": "mountain-snow", "Crew": "bed-double", "Safety": "heart-pulse", "Work": "flask-conical", "Upkeep": "wrench", "Decor": "sparkles"}
const ITEM_TABS := {
	"ice_drill": "Water", "water_reclaimer": "Water", "urine_processor": "Water",
	"oxygen_generator": "Air", "sabatier_reactor": "Air", "methane_tank": "Air", "atmosphere_processor": "Air",
	"solar_array": "Power", "surface_reactor": "Power",
	"airlock": "Outside", "regolith_intake": "Outside", "regolith_printer": "Outside", "regolith_shield_block": "Outside", "water_wall_panel": "Outside", "eva_tool_station": "Outside",
	"fire_safety_station": "Safety", "emergency_supply_lockbox": "Safety", "first_aid_kit": "Safety", "first_aid_kit_wall": "Safety", "storm_shelter_locker": "Safety", "hull_patch_kit": "Safety",
	"crew_chair": "Crew", "wall_cabin_heater": "Crew", "portable_utility_heater": "Crew",
	"spares_kit": "Upkeep", "spare_parts_rack": "Upkeep", "supply_crate_small": "Upkeep", "supply_crate_medium": "Upkeep", "supply_crate_large": "Upkeep", "open_shelving": "Upkeep", "toolbox": "Upkeep",
	"sample_jars": "Work", "plant_pot": "Decor", "retro_mars_poster": "Decor",
}
const GROUP_TABS := {
	"hydroponics": "Food", "galley": "Food", "life_support": "Air", "power": "Power",
	"exterior": "Outside", "vehicle_bay": "Outside", "airlock": "Outside", "corridor": "Outside",
	"living": "Crew", "recreation": "Crew", "hygiene": "Crew", "medical": "Safety",
	"science": "Work", "communications": "Work", "general": "Work",
	"waste_management": "Upkeep", "storage": "Upkeep", "odds_and_ends": "Decor",
}
const CARD_SIZE := Vector2(212, 154)

var world: Node
var _selected := ""
var _tab := "All"
var _search := ""
var _tabs_row: HFlowContainer
var _needed: HBoxContainer
var _grid_box: VBoxContainer
var _detail: VBoxContainer
var _stock: Label
var _job: Label
var _job_bar: ProgressBar
var _refresh := 0.0
var _shown_state := ""
var printer := ""   # this Print Shop's placement id

func setup(target_world: Node, which := "") -> Control:
	world = target_world
	printer = which
	return self

## What this printer is doing: {current, queue}.
func _work() -> Dictionary:
	return MHChapterOne.printer_work(printer)

## "8 min", "1 h 15 min".
static func duration(hours: float) -> String:
	var minutes := maxi(1, ceili(hours * 60.0))
	if minutes < 60: return "%d min" % minutes
	return "%d h" % (minutes / 60) if minutes % 60 == 0 else "%d h %d min" % [minutes / 60, minutes % 60]

func _signature() -> String:
	var work := _work()
	return "%s|%s|%d|%d|%d" % [str((work.current as Dictionary).get("id", "")), str(work.queue), roundi(MHChapterOne.feedstock_kg), MHChapterOne.earth_parts, MHChapterOne.made.size()]

func _builder() -> BuildController:
	return world.builder

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	printer = MHChapterOne._printer(_builder(), printer)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Its own layer, above the checklist, notices, captions and build HUD (6-25),
	# so nothing covers the cards or the Print button.
	var layer := CanvasLayer.new()
	layer.layer = 28
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var back := ColorRect.new()
	back.color = Color(.03, .05, .06, .98)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	root.add_child(margin)
	var column := MHStyle.vbox(16)
	margin.add_child(column)
	# Head: the name, the stock, the job, close.
	var head := MHStyle.hbox(24)
	var titles := MHStyle.vbox(4)
	titles.add_child(MHStyle.eyebrow("PRINT SHOP", MHStyle.accent))
	titles.add_child(MHStyle.title("Print equipment from plans", 30))
	head.add_child(titles)
	var status := MHStyle.vbox(6)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stock = MHStyle.mono("", 15, MHStyle.TEXT_SECONDARY, 600)
	status.add_child(_stock)
	_job = MHStyle.mono("", 14, MHStyle.accent, 600)
	_job.clip_text = true
	status.add_child(_job)
	_job_bar = ProgressBar.new()
	_job_bar.show_percentage = false
	_job_bar.custom_minimum_size = Vector2(360, 6)
	_job_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status.add_child(_job_bar)
	head.add_child(status)
	var close := MHStyle.button("Close  Esc", "secondary", "x", 44)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	head.add_child(close)
	column.add_child(head)
	# Search, and what's needed now beside it; the tabs below.
	var bar := MHStyle.hbox(24)
	var search := LineEdit.new()
	search.placeholder_text = "Search plans"
	search.right_icon = MHIcons.texture("search", 18)
	search.custom_minimum_size = Vector2(280, 44)
	search.clear_button_enabled = true
	search.text_changed.connect(func(text: String) -> void:
		_search = text.strip_edges().to_lower()
		_render())
	bar.add_child(search)
	_needed = MHStyle.hbox(10)
	_needed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_needed)
	column.add_child(bar)
	_tabs_row = HFlowContainer.new()
	_tabs_row.add_theme_constant_override("h_separation", 6)
	_tabs_row.add_theme_constant_override("v_separation", 6)
	column.add_child(_tabs_row)
	# Cards on the left, the picked plan on the right.
	var body := MHStyle.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.9
	body.add_child(scroll)
	_grid_box = MHStyle.vbox(18)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_box)
	var detail_panel := MHStyle.hud_panel(24, false, true)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(detail_panel)
	_detail = MHStyle.vbox(12)
	detail_panel.add_child(_detail)
	_render()
	search.grab_focus.call_deferred()

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = .5
	_update_status()
	# Redraw when something the cards show changes (a job ends, stock arrives).
	if _signature() != _shown_state: _render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E and not get_viewport().gui_get_focus_owner() is LineEdit):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _update_status() -> void:
	_stock.text = "FEEDSTOCK %s   ·   EARTH PARTS %d" % [MHStyle.kg(roundi(MHChapterOne.feedstock_kg)), MHChapterOne.earth_parts]
	var work := _work()
	var job: Dictionary = work.current
	var waiting := (work.queue as Array).size()
	_job_bar.visible = not job.is_empty()
	if job.is_empty():
		_job.text = "Waiting for feedstock to start the next print" if waiting > 0 else "Idle. Pick a plan and print it; it runs on the habitat's power."
		return
	var done := 1.0 - float(job.hours_left) / maxf(.01, float(job.hours))
	var speed := MHChapterOne.fabricator_speed(_builder(), printer)
	_job.text = "PRINTING %s · %d%% · %s left%s%s" % [MHChapterOne.label(str(job.id)).to_upper(), roundi(done * 100.0), duration(float(job.hours_left) / maxf(.01, speed)).to_upper(), "  ·  %d QUEUED" % waiting if waiting > 0 else "", "  (General Module: 75 % speed)" if speed < 1.0 else ""]
	_job_bar.value = done * 100.0

# ---------- what goes where ----------

static func tab_of(id: String) -> String:
	if ITEM_TABS.has(id): return str(ITEM_TABS[id])
	return str(GROUP_TABS.get(str(EquipmentCatalog.get_entry(id).get("group", "")), "Work"))

## The plans to print next: ones the chapter's steps just unlocked and not
## made yet, then spares kits while a machine is worn, broken or there are none.
func needed_now(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if MHChapterOne.made.has(id) or id == MHChapterOne.SPARES_KIT: continue
		if str(MHChapterOne.plan(str(id)).get("after", "")) in MHChapterOne.STEPS: out.append(id)
	var builder := _builder()
	if builder != null and builder.simulation() != null:
		var sim: RefCounted = builder.simulation()
		var due: Array = sim.wear.rounds(sim.inventory())
		if not due.is_empty() and int(sim.life.spares) < due.size(): out.append(MHChapterOne.SPARES_KIT)
	return out

func _label(id: String) -> String:
	return "Spares kit" if id == MHChapterOne.SPARES_KIT else MHChapterOne.label(id)

func _icon(id: String) -> String:
	if id == MHChapterOne.SPARES_KIT: return "package"
	var icon := str(EquipmentCatalog.get_entry(id).get("icon", ""))
	return icon if MHIcons.SVG.has(icon) else str(TAB_ICONS.get(tab_of(id), "package"))

# ---------- drawing ----------

func _render() -> void:
	_shown_state = _signature()
	var ids := MHChapterOne.fabricable()
	var needed := needed_now(ids)
	if _selected.is_empty() or not ids.has(_selected):
		_selected = str(needed[0]) if not needed.is_empty() else (str(ids[0]) if not ids.is_empty() else "")
	# Needed now.
	for child in _needed.get_children(): child.queue_free()
	_needed.visible = not needed.is_empty()
	if not needed.is_empty():
		var tag := MHStyle.eyebrow("NEEDED NOW", MHStyle.accent, 13)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_needed.add_child(tag)
		for id in needed: _needed.add_child(_chip(str(id)))
	# Tabs: only those with plans in them.
	var by_tab := {}
	for id in ids:
		if not _search.is_empty() and not _label(str(id)).to_lower().contains(_search): continue
		var t := tab_of(str(id))
		if not by_tab.has(t): by_tab[t] = []
		(by_tab[t] as Array).append(id)
	if _tab != "All" and not by_tab.has(_tab): _tab = "All"
	for child in _tabs_row.get_children(): child.queue_free()
	for t in TABS:
		if t != "All" and not by_tab.has(t): continue
		var count: int = ids.size() if t == "All" and _search.is_empty() else (by_tab.values().reduce(func(n, a): return n + (a as Array).size(), 0) if t == "All" else (by_tab[t] as Array).size())
		var b := Button.new()
		b.text = "%s  %d" % [t, count]
		b.icon = MHIcons.texture(str(TAB_ICONS[t]), 16)
		b.add_theme_constant_override("icon_max_width", 16)
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size.y = 36
		b.theme_type_variation = "SelectedButton" if t == _tab else "Button"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void: _tab = t; _render())
		_tabs_row.add_child(b)
	# Cards, in sections when showing All.
	for child in _grid_box.get_children(): child.queue_free()
	if by_tab.is_empty():
		_grid_box.add_child(MHStyle.body("No plans match \"%s\"." % _search if not _search.is_empty() else "No plans yet.", 16, MHStyle.TEXT_MUTED))
	for t in TABS:
		if not by_tab.has(t) or (_tab != "All" and t != _tab): continue
		if _tab == "All":
			var section := MHStyle.hbox(8)
			section.add_child(MHStyle.icon(str(TAB_ICONS[t]), 16, MHStyle.TEXT_MUTED))
			section.add_child(MHStyle.eyebrow(t.to_upper(), MHStyle.TEXT_MUTED, 13))
			_grid_box.add_child(section)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		for id in by_tab[t]: flow.add_child(_card(str(id), needed.has(id)))
		_grid_box.add_child(flow)
	_render_detail()
	_update_status()

## What a card says about a plan: [text, colour].
func _state(id: String) -> Array:
	var work := _work()
	if str((work.current as Dictionary).get("id", "")) == id: return ["Printing…", MHStyle.accent]
	if (work.queue as Array).has(id): return ["Queued", MHStyle.accent]
	if MHChapterOne.made.has(id) and id != MHChapterOne.SPARES_KIT: return ["Printed · on the build bar", MHStyle.VALID]
	var reason := MHChapterOne.job_reason(id, _builder(), printer)
	if reason.is_empty(): return ["Ready to print", MHStyle.TEXT_PRIMARY]
	if reason.begins_with("Not enough"): return [reason.replace("Not enough", "Short of"), MHStyle.WARN]
	return [reason, MHStyle.TEXT_MUTED]

func _card(id: String, needed: bool) -> Control:
	var picked := id == _selected
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.tooltip_text = _label(id)
	var border := MHStyle.accent if picked or needed else MHStyle.BORDER_SUBTLE
	card.add_theme_stylebox_override("normal", MHStyle.box(MHStyle.tint(MHStyle.accent, .18) if picked else MHStyle.SURFACE_CONTROL, border, 8, 2 if picked else 1, Vector4(14, 12, 14, 12)))
	card.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG if not picked else MHStyle.accent, 8, 2 if picked else 1, Vector4(14, 12, 14, 12)))
	card.add_theme_stylebox_override("pressed", card.get_theme_stylebox("hover"))
	card.pressed.connect(func() -> void: _selected = id; _render())
	var col := MHStyle.vbox(6)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14; col.offset_top = 12; col.offset_right = -14; col.offset_bottom = -12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := MHStyle.hbox(10)
	top.add_child(MHStyle.icon(_icon(id), 26, MHStyle.accent if picked or needed else MHStyle.STRUCTURAL_WHITE))
	if needed:
		var flag := MHStyle.eyebrow("NEEDED", MHStyle.accent, 11)
		flag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(flag)
	col.add_child(top)
	var name_label := MHStyle.label(_label(id), 17, MHStyle.TEXT_PRIMARY, 700, false, 1)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.y = 44
	name_label.max_lines_visible = 2
	col.add_child(name_label)
	var cost := MHChapterOne.plan_cost(id)
	col.add_child(MHStyle.mono("%s · %d parts · %s" % [MHStyle.kg(roundi(float(cost.feedstock_kg))), int(cost.earth_parts), duration(float(cost.hours))], 12, MHStyle.TEXT_SECONDARY))
	var state := _state(id)
	var state_label := MHStyle.mono(str(state[0]), 12, state[1])
	state_label.clip_text = true
	col.add_child(state_label)
	for child in col.get_children(): _ignore_mouse(child)
	card.add_child(col)
	return card

func _chip(id: String) -> Control:
	var b := Button.new()
	b.text = _label(id)
	b.icon = MHIcons.texture(_icon(id), 16)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size.y = 36
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.theme_type_variation = "SelectedButton" if id == _selected else "Button"
	b.pressed.connect(func() -> void: _selected = id; _tab = "All"; _render())
	return b

func _ignore_mouse(control: Node) -> void:
	if control is Control: (control as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children(): _ignore_mouse(child)

func _render_detail() -> void:
	for child in _detail.get_children(): child.queue_free()
	if _selected.is_empty():
		_detail.add_child(MHStyle.body("No plans yet.", 16))
		return
	var entry := EquipmentCatalog.get_entry(_selected)
	if _selected == MHChapterOne.SPARES_KIT:
		var builder := _builder()
		var have := int(builder.simulation().life.spares) if builder != null else 0
		entry = {"description": "Filter beds, brine bags, seals and fittings, printed from feedstock. One kit services a worn machine or repairs a broken one. You have %d." % have}
	var cost := MHChapterOne.plan_cost(_selected)
	_detail.add_child(MHStyle.eyebrow({"brought": "PLAN · BROUGHT FROM EARTH", "sent": "PLAN · SENT BY MISSION CONTROL", "discovered": "PLAN · FROM A DISCOVERY"}.get(MHChapterOne.plan_source(_selected), "PLAN") + "  ·  " + tab_of(_selected).to_upper()))
	var head := MHStyle.hbox(14)
	head.add_child(MHStyle.icon_tile(_icon(_selected), 52, 30, MHStyle.accent, MHStyle.TEXT_ON_ACCENT, MHStyle.RADIUS_MD))
	var name_label := MHStyle.title(_label(_selected), 26)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	_detail.add_child(head)
	var about := MHStyle.body(str(entry.get("description", "")), 16)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(about)
	var rows := MHStyle.vbox(6)
	for row in [["layers", "Feedstock", MHStyle.kg(roundi(float(cost.feedstock_kg))), MHChapterOne.feedstock_kg >= float(cost.feedstock_kg)], ["cpu", "Earth parts", str(int(cost.earth_parts)), MHChapterOne.earth_parts >= int(cost.earth_parts)], ["clock", "Time", duration(float(cost.hours)) + " (game time)", true], ["zap", "Power", "1.2 kW while it prints", true]]:
		var line := MHStyle.hbox(10)
		line.add_child(MHStyle.icon(str(row[0]), 16, MHStyle.TEXT_SECONDARY if bool(row[3]) else MHStyle.WARN))
		var what := MHStyle.mono(str(row[1]), 13, MHStyle.TEXT_MUTED)
		what.custom_minimum_size.x = 120
		line.add_child(what)
		line.add_child(MHStyle.mono(str(row[2]), 14, MHStyle.TEXT_PRIMARY if bool(row[3]) else MHStyle.WARN, 600))
		rows.add_child(line)
	_detail.add_child(rows)
	var on_bar := "On the build bar: each extra one takes this feedstock and these parts as you place it" if MHChapterOne.made.has(_selected) else "Not printed yet: the first job puts it on the build bar for good"
	if _selected == MHChapterOne.SPARES_KIT: on_bar = "Print them as you need them: worn machines lose output, then break"
	var bar_note := MHStyle.body(on_bar, 14, MHStyle.TEXT_MUTED)
	bar_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(bar_note)
	var reason := MHChapterOne.job_reason(_selected, _builder(), printer)
	var busy := not (_work().current as Dictionary).is_empty()
	var verb := "Add to the queue" if busy else ("Print %d" % MHChapterOne.KITS_PER_JOB if _selected == MHChapterOne.SPARES_KIT else "Print the first one")
	var start := MHStyle.button(verb if reason.is_empty() else reason, "primary" if reason.is_empty() else "secondary", "plus" if busy else "play", 48)
	start.disabled = not reason.is_empty()
	start.pressed.connect(func() -> void:
		if MHChapterOne.start_job(_selected, _builder(), printer).is_empty():
			MHAudio.sfx("ui_click")
			_render())
	_detail.add_child(start)
	if busy:
		var cancel := MHStyle.button("Cancel the print (stock returned)", "secondary", "x", 44)
		cancel.pressed.connect(func() -> void: MHChapterOne.cancel_job(_builder(), printer); _render())
		_detail.add_child(cancel)
	_detail.add_child(_queue_list())

## This printer's queue: each waiting plan with a button to take it off
## (nothing is paid until it starts).
func _queue_list() -> Control:
	var box := MHStyle.vbox(6)
	var queue: Array = _work().queue
	box.add_child(MHStyle.eyebrow("QUEUE  %d / %d" % [queue.size(), MHChapterOne.QUEUE_MAX], MHStyle.TEXT_MUTED, 12))
	if queue.is_empty():
		box.add_child(MHStyle.body("Nothing waiting. While it prints, add plans here and it works through them in order.", 14, MHStyle.TEXT_MUTED))
	for index in queue.size():
		var row := MHStyle.hbox(8)
		row.add_child(MHStyle.icon(_icon(str(queue[index])), 16, MHStyle.TEXT_SECONDARY))
		var name_label := MHStyle.label("%d. %s" % [index + 1, _label(str(queue[index]))], 15, MHStyle.TEXT_PRIMARY, 600)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(MHStyle.mono(duration(float(MHChapterOne.plan_cost(str(queue[index])).hours)), 13, MHStyle.TEXT_MUTED))
		var drop := MHStyle.button("", "ghost", "x", 32)
		drop.tooltip_text = "Take it off the queue"
		drop.pressed.connect(func() -> void: MHChapterOne.unqueue(printer, index); _render())
		row.add_child(drop)
		box.add_child(row)
	return box
