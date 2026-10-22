extends Control

## The habitat monitoring station (backlog item 28, docs/designs-batches-4-6.md):
## the whole base working in real time, built from the simulation, not
## cameras. The game keeps running underneath (you stand still), so it's
## live.
##   left:   the habitat map, each room tinted by its state (green fine,
##           amber warning, red critical) with its temperature, lights and
##           crew; outside, the solar arrays and drills. Click a room.
##   right:  the room's machines (on, powered, and what each is doing), then
##           whole-base flows (power, air, water, food, crew) and alerts.
##   bottom: the last sol of power made, power used and battery charge.
## Opened from Mission Control (Monitor) or the Mission Planning Console in
## the base. Esc or M closes it.

const MHResources := preload("res://scripts/mh_resources.gd")
const STATE_COLOURS := {"ok": Color("#3EE58A"), "warn": Color("#F5C542"), "danger": Color("#E5484D"), "idle": Color("#8796A0")}

signal closed

var world: Node
var selected := -1          # index into the sim's rooms
var _refresh := 0.0
var _map: MonitorMap
var _strip: DayStrip
var _room_panel: VBoxContainer
var _flows_panel: VBoxContainer
var _clock: Label
var _previous := {}

func setup(target_world: Node) -> Control:
	world = target_world
	return self

func builder() -> BuildController:
	return world.builder

func sim() -> RefCounted:
	return world.builder.simulation()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(.03, .05, .06, 1.0)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var column := MHStyle.vbox(14)
	margin.add_child(column)
	var head := MHStyle.hbox(14)
	var titles := MHStyle.vbox(4)
	titles.add_child(MHStyle.eyebrow("%s · Habitat monitor" % MHGame.colony_name, MHStyle.accent, 14))
	titles.add_child(MHStyle.display("Live systems", 40))
	head.add_child(titles)
	head.add_child(MHStyle.spacer())
	var live := MHStyle.hbox(8)
	live.add_child(MHStyle.icon("circle-check", 16, MHStyle.VALID))
	_clock = MHStyle.mono("", 15, MHStyle.TEXT_SECONDARY, 700)
	live.add_child(_clock)
	live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(live)
	var close := MHStyle.button("Close", "secondary", "x")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	head.add_child(close)
	column.add_child(head)
	var body := MHStyle.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_map = MonitorMap.new()
	_map.monitor = self
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_map)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 470
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side_scroll)
	var side := MHStyle.vbox(16)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side)
	_room_panel = MHStyle.vbox(6)
	side.add_child(_room_panel)
	_flows_panel = MHStyle.vbox(6)
	side.add_child(_flows_panel)
	_strip = DayStrip.new()
	_strip.monitor = self
	_strip.custom_minimum_size = Vector2(0, 150)
	column.add_child(_strip)
	_update()

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = .5
	_update()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _update() -> void:
	if world == null: return
	_clock.text = "LIVE · %02d:%02d %s" % [int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60.0), "DAY" if MHGame.sunlight_fraction > .2 else "NIGHT"]
	_map.queue_redraw()
	_strip.queue_redraw()
	_fill_room()
	_fill_flows()

# ---------- what each room is doing ----------

## Each room's live reading: {state, temp, lights, crew, problems: [text]}.
func room_reading(index: int) -> Dictionary:
	var s = sim()
	var inv: Dictionary = s.inventory()
	var room: Dictionary = inv.rooms[index]
	var temp := float(s.room_temp.get(room.key, 20.0))
	var tiers: Dictionary = s.last.get("tiers", {})
	var online: bool = builder().grid_power_online()
	var people: Array = s._crew_by_room(inv.rooms, s.crew_count_for(inv.capacity), MHGame.sol_hour)
	var problems: Array = []
	var state := "ok"
	var crewed := not str(room.kind) in ["airlock", "corridor", "storage", "vehicle_bay"]
	if crewed and temp < MHResources.setting("danger_cold_c", 5.0):
		state = "danger"
		problems.append("Dangerously cold")
	elif crewed and temp < MHResources.setting("cold_c", 12.0):
		state = "warn"
		problems.append("Cold")
	for item in inv.items:
		if int(item.room) != index or not bool(item.on) or float(item.power) <= 0.0: continue
		if not online or not bool(tiers.get(int(item.tier), true)):
			var life := int(item.tier) == 1
			if life: state = "danger"
			elif state == "ok": state = "warn"
			problems.append("%s has no power" % _label(str(item.id)))
	return {"state": state, "temp": temp, "lights": builder().room_light_state(str(room.key)) if MHGame.simulation_on() else "on",
		"crew": int(people[index]) if index < people.size() else 0, "problems": problems}

func _label(id: String) -> String:
	return str(EquipmentCatalog.get_entry(id).get("label", id.capitalize()))

## What a machine is doing, in a few words: everything it makes or removes.
static func doing(item: Dictionary, powered: bool, count := 1) -> String:
	if not bool(item.on): return "switched off"
	if float(item.power) > 0.0 and not powered: return "no power"
	var parts: Array = []
	if float(item.food) > 0.0: parts.append("growing %.1f kg food" % (float(item.food) * count))
	if float(item.o2) > 0.0: parts.append("making %.1f kg O₂" % (float(item.o2) * count))
	if float(item.co2) < 0.0: parts.append("scrubbing %.1f kg CO₂" % (-float(item.co2) * count))
	if float(item.water) > 0.0: parts.append("making %d L water" % roundi(float(item.water) * count))
	if not parts.is_empty(): return ", ".join(parts) + " a sol"
	if float(item.heat_kw) > 0.0: return "heating, %.1f kW" % (float(item.heat_kw) * count)
	if float(item.stores_kwh) > 0.0: return "stores up to %d kWh" % roundi(float(item.stores_kwh) * count)
	if int(item.berths) > 0: return "%d bunk%s" % [int(item.berths) * count, "" if int(item.berths) * count == 1 else "s"]
	if float(item.power) > 0.0: return "using %.2f kW" % (float(item.power) * count)
	return "no power needed"

func _fill_room() -> void:
	for child in _room_panel.get_children(): child.queue_free()
	var inv: Dictionary = sim().inventory()
	if selected < 0 or selected >= (inv.rooms as Array).size():
		_room_panel.add_child(MHStyle.eyebrow("Rooms", MHStyle.accent, 13))
		_room_panel.add_child(_line("Click a room on the map to see its machines and what each is doing.", MHStyle.TEXT_MUTED))
		return
	var room: Dictionary = inv.rooms[selected]
	var reading := room_reading(selected)
	var tone: Color = STATE_COLOURS[reading.state]
	_room_panel.add_child(MHStyle.eyebrow(str(room.label), tone, 14))
	_room_panel.add_child(_line("%d °C (aim %d °C) · lights %s · %d crew here" % [roundi(float(reading.temp)), roundi(float(room.target)), str(reading.lights), int(reading.crew)], MHStyle.TEXT_PRIMARY, 15))
	for problem in reading.problems: _room_panel.add_child(_line("⚠ " + str(problem), tone))
	var tiers: Dictionary = sim().last.get("tiers", {})
	var online: bool = builder().grid_power_online()
	var groups := {}
	for item in inv.items:
		if int(item.room) != selected: continue
		var key := "%s|%s" % [item.id, item.on]
		if not groups.has(key): groups[key] = {"item": item, "count": 0}
		groups[key].count += 1
	if groups.is_empty():
		_room_panel.add_child(_line("No machines or furniture yet.", MHStyle.TEXT_MUTED))
	for key in groups:
		var item: Dictionary = groups[key].item
		var count: int = groups[key].count
		var powered := online and bool(tiers.get(int(item.tier), true))
		var what := doing(item, powered, count)
		var colour := MHStyle.DANGER if what == "no power" else (MHStyle.TEXT_MUTED if what in ["switched off", "no power needed"] else MHStyle.TEXT_SECONDARY)
		_room_panel.add_child(_line("%s%s: %s" % [_label(str(item.id)), " ×%d" % count if count > 1 else "", what], colour))

# ---------- the whole base ----------

func _fill_flows() -> void:
	for child in _flows_panel.get_children(): child.queue_free()
	var s = sim()
	var snap: Dictionary = s.snapshot(MHGame.sol_hour)
	var flows: Dictionary = s.daily_flows(false)
	var inv: Dictionary = s.inventory()
	_flows_panel.add_child(MHStyle.eyebrow("Whole base", MHStyle.accent, 14))
	var made := float(snap.generation_kw)
	var used := float(snap.load_kw)
	var power := "Power: %.1f kW made, %.1f kW used · battery %d%%" % [made, used, roundi(float(snap.battery_pct))]
	if used > made and float(s.battery_kwh) > 0.0: power += " · empty in %s" % _hours(float(s.battery_kwh) / (used - made))
	_flows_panel.add_child(_line(power, MHStyle.TEXT_PRIMARY if made >= used or float(snap.battery_pct) > 20.0 else MHStyle.WARN, 15))
	_flows_panel.add_child(_line("Air: O₂ %.1f%% %s · CO₂ %.2f%% %s" % [float(snap.o2_pct), _trend("o2", float(snap.o2_pct)), float(snap.co2_pct), _trend("co2", float(snap.co2_pct))],
		MHStyle.TEXT_PRIMARY if float(snap.o2_pct) >= 19.5 and float(snap.co2_pct) <= 1.0 else MHStyle.DANGER, 15))
	var crew := int(flows.crew)
	var water_net := float(flows.water_made) - float(flows.water_used)
	_flows_panel.add_child(_line("Water: %d L · makes %d, uses %d L a sol%s" % [roundi(float(snap.water_l)), roundi(float(flows.water_made)), roundi(float(flows.water_used)),
		" · %s left" % _sols(float(snap.water_l) / -water_net) if water_net < 0.0 and crew > 0 else ""], MHStyle.TEXT_PRIMARY, 15))
	var food_net := float(flows.food_grown) - float(flows.food_eaten)
	_flows_panel.add_child(_line("Food: %d kg · grows %.1f, eats %.1f kg a sol%s" % [roundi(float(snap.food_kg)), float(flows.food_grown), float(flows.food_eaten),
		" · %s left" % _sols(float(snap.food_kg) / -food_net) if food_net < 0.0 and crew > 0 else ""], MHStyle.TEXT_PRIMARY, 15))
	_flows_panel.add_child(_line("Crew: %d aboard of %d bunks · health %d%%" % [crew, int(inv.capacity.berths), roundi(float(snap.crew_health))], MHStyle.TEXT_PRIMARY, 15))
	if float(flows.research) > 0.0 or float(s.research_boost_hours) > 0.0:
		_flows_panel.add_child(_line("Research: %.1f a sol%s" % [float(flows.research), " (core sample +20%%, %s left)" % _hours(float(s.research_boost_hours)) if float(s.research_boost_hours) > 0.0 else ""], MHStyle.TEXT_PRIMARY, 15))
	if float(s.storm_hours_left) > 0.0: _flows_panel.add_child(_line("Dust storm: solar cut for %s" % _hours(float(s.storm_hours_left)), MHStyle.WARN, 15))
	var alerts = world.alerts
	_flows_panel.add_child(MHStyle.eyebrow("Alerts", MHStyle.accent, 13))
	if alerts == null or (alerts._active as Dictionary).is_empty():
		_flows_panel.add_child(_line("All quiet.", MHStyle.VALID))
	else:
		for id in alerts._active:
			var level := str(alerts._active[id].level)
			_flows_panel.add_child(_line("%s · %s" % [level.to_upper(), str(alerts._active[id].title)], alerts.LEVEL_COLOUR.get(level, MHStyle.WARN)))

func _trend(key: String, value: float) -> String:
	var before := float(_previous.get(key, value))
	_previous[key] = value
	return "" if absf(value - before) < .0005 else ("↑" if value > before else "↓")

func _hours(h: float) -> String:
	return "%d h %02d m" % [int(h), int(fmod(h, 1.0) * 60.0)] if h < 48.0 else "%d sols" % floori(h / 24.0)

func _sols(n: float) -> String:
	return "%.1f sols" % n if n < 10.0 else "%d sols" % roundi(n)

func _line(text: String, colour := MHStyle.TEXT_SECONDARY, size := 14) -> Label:
	var label := MHStyle.body(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

# ---------- the live map ----------

class MonitorMap extends Control:
	var monitor
	var _origin := Vector2.ZERO
	var _unit := 1.0

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var at := ((event as InputEventMouseButton).position - _origin) / _unit
			var cell := Vector2i(roundi(at.x), roundi(at.y))
			var rooms: Array = monitor.sim().inventory().rooms
			monitor.selected = -1
			for index in range(rooms.size()):
				if (rooms[index].zone.get("cells", []) as Array).has(cell): monitor.selected = index
			monitor._update()
			accept_event()

	func _draw() -> void:
		draw_style_box(MHStyle.box(MHStyle.BLUEPRINT, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_SM), Rect2(Vector2.ZERO, size))
		var b: BuildController = monitor.builder()
		if b.zones.is_empty(): return
		var low := Vector2i(999, 999)
		var high := Vector2i(-999, -999)
		for zone in b.zones:
			for cell in zone.get("cells", []):
				low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
				high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		var span := Vector2(high - low) + Vector2(3, 3)
		_unit = minf(size.x / span.x, size.y / span.y)
		_origin = (size - span * _unit) * .5 + Vector2(_unit, _unit) * 1.5 - Vector2(low) * _unit
		var font := MHStyle.font(700, true, 1)
		var small := MHStyle.font(500)
		var rooms: Array = monitor.sim().inventory().rooms
		# Outside: solar arrays, drills, reactors, greyed when not running.
		for zone in b.zones:
			var kind := str(zone.kind)
			if b._is_habitat_zone(zone): continue
			var running: bool = b._zone_running(zone) if b.has_method("_zone_running") else true
			for cell in zone.get("cells", []):
				var r := Rect2(_origin + (Vector2(cell) - Vector2(.5, .5)) * _unit, Vector2(_unit, _unit)).grow(-2)
				draw_rect(r, Color(MHStyle.BEACON_YELLOW if kind == "solar" else MHStyle.INFO, .25 if running else .08))
			var first: Vector2i = (zone.get("cells", [Vector2i.ZERO]) as Array)[0]
			var label: String = {"solar": "SOLAR", "ice_extractor": "DRILL", "reactor": "REACTOR", "regolith_intake": "INTAKE"}.get(kind, kind.to_upper())
			draw_string(small, _origin + (Vector2(first) + Vector2(-.42, .1)) * _unit, label + ("" if running else " · OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MHStyle.TEXT_MUTED)
		# Rooms, tinted by state.
		for index in range(rooms.size()):
			var room: Dictionary = rooms[index]
			var reading: Dictionary = monitor.room_reading(index)
			var tone: Color = monitor.STATE_COLOURS[reading.state]
			var cells: Array = room.zone.get("cells", [])
			if cells.is_empty(): continue
			var centre := Vector2.ZERO
			for cell in cells:
				var r := Rect2(_origin + (Vector2(cell) - Vector2(.5, .5)) * _unit, Vector2(_unit, _unit))
				draw_rect(r.grow(-1), Color(tone, .22))
				centre += r.get_center()
				for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if cells.has(cell + side): continue
					var a := r.get_center() + Vector2(side) * _unit * .5 + Vector2(side.y, side.x) * _unit * .5
					var bb := r.get_center() + Vector2(side) * _unit * .5 - Vector2(side.y, side.x) * _unit * .5
					draw_line(a, bb, tone if index != monitor.selected else MHStyle.TEXT_PRIMARY, 3.0 if index == monitor.selected else 2.0)
			centre /= cells.size()
			var title := str(room.label).to_upper()
			var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, centre + Vector2(-tw * .5, -8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MHStyle.INK_100)
			var detail := "%d °C · %s%s" % [roundi(float(reading.temp)), str(reading.lights).to_upper(), " · %d crew" % int(reading.crew) if int(reading.crew) > 0 else ""]
			var dw := small.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(small, centre + Vector2(-dw * .5, 12), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tone)
		# Legend.
		var x := 14.0
		for entry in [["Fine", "ok"], ["Warning", "warn"], ["Critical", "danger"]]:
			draw_rect(Rect2(Vector2(x, size.y - 22), Vector2(12, 12)), monitor.STATE_COLOURS[entry[1]])
			draw_string(small, Vector2(x + 18, size.y - 11), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MHStyle.TEXT_SECONDARY)
			x += 96.0

# ---------- the last sol ----------

class DayStrip extends Control:
	var monitor

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .35))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(12, 18), "THE LAST SOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .6))
		var day: Array = monitor.world.alerts.day if monitor.world.alerts != null else []
		if day.size() < 2:
			draw_string(font, Vector2(12, 60), "Recording: the graph fills in as the sol goes by.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, .5))
			return
		var left := 50.0
		var right := size.x - 20.0
		var top := 30.0
		var bottom := size.y - 22.0
		var end := float(day[-1].t)
		var start := end - 24.0
		var top_kw := 1.0
		for s in day: top_kw = maxf(top_kw, maxf(float(s.made), float(s.used)))
		var lines := {"battery": PackedVector2Array(), "made": PackedVector2Array(), "used": PackedVector2Array()}
		for s in day:
			var x := left + (right - left) * clampf((float(s.t) - start) / 24.0, 0.0, 1.0)
			lines.battery.append(Vector2(x, bottom - (bottom - top) * float(s.battery) / 100.0))
			lines.made.append(Vector2(x, bottom - (bottom - top) * float(s.made) / top_kw))
			lines.used.append(Vector2(x, bottom - (bottom - top) * float(s.used) / top_kw))
		draw_polyline(lines.made, Color("#F2C14E"), 2.0)
		draw_polyline(lines.used, Color(1, 1, 1, .75), 1.5)
		draw_polyline(lines.battery, MHStyle.VALID, 2.5)
		draw_line(Vector2(left, bottom), Vector2(right, bottom), Color(1, 1, 1, .3), 1.0)
		draw_string(font, Vector2(right - 40, bottom + 16), "now", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .6))
		draw_string(font, Vector2(left, bottom + 16), "24 h ago", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .6))
		var x0 := 140.0
		for entry in [["Battery %", MHStyle.VALID], ["Power made (kW)", Color("#F2C14E")], ["Power used (kW)", Color(1, 1, 1, .75)]]:
			draw_rect(Rect2(Vector2(x0, 12), Vector2(12, 4)), entry[1])
			draw_string(font, Vector2(x0 + 16, 18), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .8))
			x0 += font.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 40.0
		draw_string(font, Vector2(6, top + 6), "%d kW" % roundi(top_kw), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#F2C14E"))
