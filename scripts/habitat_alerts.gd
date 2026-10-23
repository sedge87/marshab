extends Node

## Habitat alerts (backlog item 26, docs/designs-batches-4-6.md): the habitat
## computer speaks up when something starts going wrong, like Subnautica's
## PDA and seabase: no name, one calm voice, short fixed lines
## (assets/audio/voice, tools/generate_voice.py), numbers on screen.
##
## Every half second (real time) it reads the live simulation and works out
## each alert's level: advisory (blue, once), warning (amber, repeats every
## 90 s) or critical (red, repeats every 30 s, red edge pulse). A new or
## escalated alert shows a banner at the top of the screen with a chime and
## its cause chain: the linked systems from the cause to what it threatens
## ("Power: none at night → Oxygen generator: off → O₂ 19.6% ↓ → Crew
## health"). The first time each kind of alert appears, the banner also
## says why it matters and stays up longer. When it clears: "back to normal".
## While alerts are active, small pills stay under the clock. Everything is
## kept in `history` for Mission Control's alert log. Dust storms stay with
## weather.gd, which announces them (with the same voice). Coming in through
## an airlock: "Welcome home" ("Welcome aboard" the first time).
const MHResources := preload("res://scripts/mh_resources.gd")

const REPEAT := {"warning": 90.0, "critical": 30.0}
const LEVEL_RANK := {"": 0, "advisory": 1, "warning": 2, "critical": 3}
const LEVEL_COLOUR := {"advisory": Color("#5DC8F9"), "warning": Color("#F5C542"), "critical": Color("#E5484D"), "resolved": Color("#3EE58A")}
const LEVEL_SOUND := {"advisory": "ui_confirm", "warning": "storm_alert", "critical": "warn", "resolved": "all_clear"}
const BANNER_SECONDS := 7.0

var world: Node
## Every alert raised, escalated or cleared: {time, sol_hour, id, level, title, text}.
var history: Array = []
var _active: Dictionary = {}     # id -> {level, since, said}
var _previous: Dictionary = {}   # value readings from the last check, for "rising"/"falling"
var _check_in := 0.0
var _layer: CanvasLayer
var _banner: PanelContainer
var _banner_left := 0.0
var _pills: HBoxContainer
var _edge: ColorRect
var _clock := 0.0
var _explained: Dictionary = {}   # alert ids already explained this session
## The last sol of power made, power used and battery charge, every quarter
## hour, for the monitoring station's strip (habitat_monitor.gd). Not saved.
var day: Array = []
var _last_sample := -1.0
var _was_inside := true
var _welcomed := false
var _welcome_wait := 0.0

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("habitat_alerts")
	_build_hud()

func sim() -> RefCounted:
	return world.builder.simulation()

func _process(delta: float) -> void:
	_clock += delta
	if _banner != null and is_instance_valid(_banner):
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.queue_free()
			_banner = null
			_pills.visible = true
	# Critical: a slow red pulse round the screen edge.
	var critical := _active.values().any(func(a): return str(a.level) == "critical")
	_edge.visible = critical
	if critical: (_edge.material as ShaderMaterial).set_shader_parameter("strength", .16 + .1 * sin(_clock * 3.0))
	_check_in -= delta
	if _check_in > 0.0: return
	_check_in = .5
	if get_tree().paused: return
	_welcome()
	if not MHGame.simulation_on(): return
	_record_day()
	var found := evaluate()
	if not bool(MHGame.setting("alert_advisories")): found = found.filter(func(a): return str(a.level) != "advisory")
	_update(found)

func _record_day() -> void:
	var s = sim()
	var now := float(s.hours_run)
	if _last_sample >= 0.0 and now - _last_sample < .25: return
	_last_sample = now
	var snap: Dictionary = s.snapshot(MHGame.sol_hour)
	day.append({"t": now, "made": float(snap.generation_kw), "used": float(snap.load_kw), "battery": float(snap.battery_pct)})
	while not day.is_empty() and now - float(day[0].t) > 24.0: day.pop_front()

## Coming in from outside: the habitat greets you (not more than once a minute).
func _welcome() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or world.builder == null: return
	var inside: bool = world.builder.is_inside(player.global_position)
	_welcome_wait -= .5
	if inside and not _was_inside and _welcome_wait <= 0.0:
		MHAudio.voice("welcome_home" if _welcomed else "welcome_aboard")
		_welcomed = true
		_welcome_wait = 60.0
	_was_inside = inside

# ---------- what is wrong right now ----------

## Every alert that applies now: [{id, level, title, text, chain: [[icon, text, ok]]}].
## The Test passes its own simulation copy and hour to replay the same rules.
func evaluate(test_sim: RefCounted = null, test_hour := -1.0) -> Array:
	var s = test_sim if test_sim != null else sim()
	var sol_hour: float = test_hour if test_hour >= 0.0 else MHGame.sol_hour
	var out: Array = []
	var inv: Dictionary = s.inventory()
	if int(inv.cells) == 0: return out
	var snap: Dictionary = s.snapshot(sol_hour)
	var tiers: Dictionary = s.last.get("tiers", {})
	var crew: int = s.crew_count_for(inv.capacity)
	var night := sol_hour < 6.0 or sol_hour >= 18.0
	var power_link := _power_link(snap, inv, night, s)
	var items: Array = inv.items

	# Power.
	if not tiers.is_empty() and not bool(tiers.get(1, true)):
		out.append({"id": "life_support_power", "level": "critical", "title": "Life support has no power",
			"text": "Air, water and heating machines are off. The crew can't stay safe without them.",
			"chain": [power_link, ["wind", "Life support: off", false], ["heart-pulse", "Crew", false]]})
	elif not tiers.is_empty() and not bool(tiers.get(4, true)):
		var off: Array = []
		for tier in [4, 3, 2]:
			if not bool(tiers.get(tier, true)): off.append(str(s.TIER_NAMES[tier]))
		out.append({"id": "power", "level": "warning", "title": "Not enough power",
			"text": "Switched off to save power: %s." % ", ".join(off),
			"chain": [power_link, ["triangle-alert", "Off: " + str(off[0]), false]]})
	# Batteries low with the night coming.
	var hours_to_dark := 18.0 - sol_hour
	if float(inv.capacity.kwh) > 0.0 and hours_to_dark > 0.0 and hours_to_dark <= 3.0 and float(snap.battery_pct) < 40.0:
		out.append({"id": "battery_sunset", "level": "advisory", "title": "Batteries low before sunset",
			"text": "%d%% charged with %s until dark. Overnight everything runs on the batteries." % [roundi(float(snap.battery_pct)), _hours(hours_to_dark)],
			"chain": [["sun", "Sunset in " + _hours(hours_to_dark), true], ["zap", "Battery %d%%" % roundi(float(snap.battery_pct)), false], ["lightbulb", "Night load", true]]})
	# Oxygen.
	var o2 := float(snap.o2_pct)
	var o2_level := "critical" if o2 < MHResources.setting("o2_min_pct", 19.5) else ("warning" if o2 < 20.0 else "")
	if not o2_level.is_empty():
		var generators: Array = items.filter(func(i): return str(i.id) == "oxygen_generator")
		var gen_text := "No oxygen generator" if generators.is_empty() else ("Oxygen generator: no power" if not bool(tiers.get(1, true)) else "%d oxygen generator%s: not enough" % [generators.size(), "" if generators.size() == 1 else "s"])
		var chain: Array = []
		if not bool(tiers.get(1, true)): chain.append(power_link)
		chain.append(["wind", gen_text, false])
		chain.append(["wind", "O₂ %.1f%% %s" % [o2, _trend("o2", o2)], false])
		chain.append(["heart-pulse", "Crew health", true])
		out.append({"id": "o2", "level": o2_level, "title": "Oxygen falling", "text": "Oxygen is %.1f%%. Below 19.5%% the crew get headaches and can't think clearly." % o2, "chain": chain})
	# Carbon dioxide.
	var co2 := float(snap.co2_pct)
	var co2_level := "critical" if co2 > MHResources.setting("co2_danger_pct", 1.0) else ("warning" if co2 > .5 else "")
	if not co2_level.is_empty():
		var recyclers: Array = items.filter(func(i): return str(i.id) == "air_recycler")
		var why := "No air recycler" if recyclers.is_empty() else ("Air recycler: no power" if not bool(tiers.get(1, true)) else "Too few air recyclers for %d crew" % crew)
		var chain: Array = []
		if not bool(tiers.get(1, true)): chain.append(power_link)
		chain.append_array([["wind", why, false], ["wind", "CO₂ %.2f%% %s" % [co2, _trend("co2", co2)], false], ["heart-pulse", "Crew health", true]])
		out.append({"id": "co2", "level": co2_level, "title": "Carbon dioxide rising", "text": "Every breath adds CO₂ to the air. An air recycler scrubs it out.", "chain": chain})
	# Cold rooms.
	var coldest := float(s.habitat_temp)
	if not (s.crewed_rooms() as Array).is_empty() and coldest < MHResources.setting("cold_c", 12.0):
		var heaters: Array = items.filter(func(i): return s.HEAT_ITEMS.has(str(i.id)) and float(i.power) > 0.0)
		var why := "No heating" if float(inv.capacity.tcu_kw) <= 0.0 and heaters.is_empty() else ("Heating: no power" if not bool(tiers.get(2, true)) else "Heating at full stretch")
		var chain: Array = []
		if not bool(tiers.get(2, true)): chain.append(power_link)
		chain.append_array([["flame", why, false], ["flame", "Habitat %d °C %s" % [roundi(coldest), _trend("cold", coldest)], false], ["heart-pulse", "Crew health", true]])
		out.append({"id": "cold", "level": "critical" if coldest < MHResources.setting("danger_cold_c", 5.0) else "warning", "title": "The habitat is cold",
			"text": "Mars nights fall below -70 °C. Heat leaks out through the walls and windows all the time.", "chain": chain})
	# Cold spots: rooms the heating doesn't reach (the habitat as a whole may be fine).
	if not (s.crewed_rooms() as Array).is_empty() and coldest >= MHResources.setting("cold_c", 12.0) and not (s.cold_spots as Array).is_empty():
		var spots: Array = s.cold_spots
		out.append({"id": "cold_spot", "level": "warning", "title": "Cold spot: %s" % ", ".join(spots.slice(0, 2)),
			"text": "Not enough heat reaches %s. Spot heaters only warm their own room and the rooms next door." % ("these rooms" if spots.size() > 1 else str(spots[0])),
			"chain": [["flame", "Heaters too far away", false], ["flame", "%s cold" % str(spots[0]), false], ["heart-pulse", "Crew comfort", true]]})
	# Water and food.
	var water_net := float(s.last.get("water_out", 0.0)) - float(s.last.get("water_in", 0.0))
	if crew > 0 and water_net > 0.0 and float(snap.water_l) / water_net < 3.0:
		out.append({"id": "water", "level": "critical" if float(snap.water_l) <= 0.0 else "warning", "title": "Water running out",
			"text": "Using %d L more than is made each sol: %s left." % [roundi(water_net), _sols(float(snap.water_l) / water_net)],
			"chain": [["droplets", "Made %d L a sol" % roundi(float(s.last.get("water_in", 0.0))), false], ["droplets", "Used %d L a sol" % roundi(float(s.last.get("water_out", 0.0))), true], ["heart-pulse", "Crew", true]]})
	var food_net := crew * MHResources.setting("food_per_person", 1.8) - float(s.last.get("food_in", 0.0))
	if crew > 0 and food_net > 0.0 and float(snap.food_kg) / food_net < 10.0:
		out.append({"id": "food", "level": "critical" if float(snap.food_kg) <= 0.0 else "warning", "title": "Food running low",
			"text": "%s of food left for %d crew." % [_sols(float(snap.food_kg) / food_net), crew],
			"chain": [["wheat", "Grown %.1f kg a sol" % float(s.last.get("food_in", 0.0)), false], ["wheat", "Eaten %.1f kg a sol" % (crew * MHResources.setting("food_per_person", 1.8)), true], ["heart-pulse", "Crew", true]]})
	# Crew health, with its causes.
	var health := float(snap.crew_health)
	if crew > 0 and MHGame.crew_can_be_harmed() and health < 80.0 and not (s.health_causes as Array).is_empty():
		out.append({"id": "health", "level": "critical" if health < 50.0 else "warning", "title": "Crew health falling",
			"text": "Crew health %d%%. Fix the cause and they recover." % roundi(health),
			"chain": [["triangle-alert", ", ".join(s.health_causes), false], ["heart-pulse", "Health %d%% %s" % [roundi(health), _trend("health", health)], false]]})
	return out

## Why each kind of alert matters, shown the first time it appears.
const EXPLAIN := {
	"life_support_power": "Life support is the first thing to get power and the last to lose it. If it goes, the air, water and heat all start to fail at once.",
	"power": "When there isn't enough power, the habitat sheds load in order: labs and galley first, then lights, then heating, and life support last.",
	"battery_sunset": "Solar panels stop at sunset. Everything overnight runs on what the batteries stored during the day.",
	"o2": "People breathe in oxygen and breathe out carbon dioxide. On Mars the oxygen generator makes more by splitting water, and it needs power to do it.",
	"co2": "Each crew member breathes out about 1 kg of CO₂ a day. Above 1% it causes headaches and poor thinking. Air recyclers scrub it out.",
	"cold": "The habitat loses heat to Mars all the time, faster through windows and outside walls. Heaters need power to keep up, especially at night.",
	"cold_spot": "A spot heater warms the room it's in and the rooms next door, nothing further. A thermal control unit is ducted to every room, and gives about three times the heat for the same power.",
	"water": "Water is drunk, washed with, fed to plants and split into oxygen. Ice drills mine it, and the water reclaimer recycles most of what's used.",
	"food": "Six people eat about 11 kg of food a sol. Supply landers bring freeze-dried food; growing your own makes the base last.",
	"health": "Crew health falls when the air, warmth, water or food go wrong, and recovers once they're fixed.",
}
## The voice line for an alert at a level (see tools/generate_voice.py).
static func voice_line(id: String, level: String) -> String:
	return "resolved_" + id if level == "resolved" else "%s_%s" % [id, level]

## The first link of most chains: where the power is (or isn't) coming from.
func _power_link(snap: Dictionary, inv: Dictionary, night: bool, s: RefCounted) -> Array:
	if float(s.storm_hours_left) > 0.0: return ["sun", "Dust storm: solar cut", false]
	if float(inv.capacity.kwh) > 0.0 and float(snap.battery_pct) < 5.0: return ["zap", "Batteries flat" + (" at night" if night else ""), false]
	if float(inv.capacity.kwh) <= 0.0 and night: return ["zap", "Night, and no batteries", false]
	return ["zap", "Power: %.1f kW made, %.1f kW needed" % [float(snap.generation_kw), float(s.last.get("demand_kw", snap.load_kw))], false]

func _trend(key: String, value: float) -> String:
	var before := float(_previous.get(key, value))
	_previous[key] = value
	if absf(value - before) < .001: return ""
	return "↑" if value > before else "↓"

func _hours(h: float) -> String:
	return "%d h %02d m" % [int(h), int(fmod(h, 1.0) * 60.0)] if h >= 1.0 else "%d minutes" % int(h * 60.0)

func _sols(n: float) -> String:
	return "about %d sol%s" % [maxi(0, floori(n)), "" if floori(n) == 1 else "s"] if n >= 1.0 else "less than a sol"

# ---------- raising, repeating, clearing ----------

func _update(alerts: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var seen := {}
	# Several at once: the most serious is announced; the rest join the pills.
	alerts.sort_custom(func(a, b): return LEVEL_RANK[str(a.level)] > LEVEL_RANK[str(b.level)])
	var announced := false
	for alert in alerts:
		var id := str(alert.id)
		seen[id] = true
		var level := str(alert.level)
		var known: Dictionary = _active.get(id, {})
		var was := str(known.get("level", ""))
		if known.is_empty() or LEVEL_RANK[level] > LEVEL_RANK[was]:
			_active[id] = {"level": level, "since": now, "said": now, "title": alert.title}
			if not announced: _announce(alert, level)
			else: _record(alert, level)
			announced = true
		else:
			known.level = level
			known.title = alert.title
			if REPEAT.has(level) and now - float(known.said) >= float(REPEAT[level]) and not announced:
				known.said = now
				_announce(alert, level, true)
				announced = true
	for id in _active.keys():
		if seen.has(id): continue
		var gone: Dictionary = _active[id]
		_active.erase(id)
		if LEVEL_RANK[str(gone.level)] >= LEVEL_RANK["warning"]:
			_announce({"id": id, "title": "%s: back to normal" % str(gone.title).trim_suffix(" falling").trim_suffix(" rising").trim_suffix(" running out").trim_suffix(" running low"), "text": "", "chain": []}, "resolved")
	_refresh_pills()

func _record(alert: Dictionary, level: String) -> void:
	var sol := floori(float(sim().hours_run) / 24.0) + 1 if world != null else 1
	history.append({"time": Time.get_datetime_string_from_system(false, true), "sol": sol, "sol_hour": MHGame.sol_hour, "id": alert.id, "level": level, "title": alert.title, "text": alert.text, "chain": alert.get("chain", [])})

func _announce(alert: Dictionary, level: String, reminder := false) -> void:
	_record(alert, level)
	MHAudio.sfx(str(LEVEL_SOUND[level]), -8.0 if reminder else -3.0, 0.0)
	# Speak it when it starts, escalates or clears; critical alerts again on each reminder.
	if not reminder or level == "critical": MHAudio.voice(voice_line(str(alert.id), level))
	var first := level != "resolved" and not _explained.has(str(alert.id)) and EXPLAIN.has(str(alert.id))
	if first:
		_explained[str(alert.id)] = true
		alert = alert.duplicate()
		alert["why"] = EXPLAIN[str(alert.id)]
	_show_banner(alert, level, reminder)
	if first: _banner_left = BANNER_SECONDS * 2.0

# ---------- on screen ----------

func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHStyle.theme()
	_layer.add_child(root)
	_edge = ColorRect.new()
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float strength = 0.4;\nvoid fragment() {\n\tvec2 d = min(UV, 1.0 - UV);\n\tfloat edge = 1.0 - smoothstep(0.0, 0.05, min(d.x * 0.6, d.y));\n\tCOLOR = vec4(0.9, 0.2, 0.2, edge * strength);\n}\n"
	var material := ShaderMaterial.new(); material.shader = shader
	_edge.material = material
	_edge.visible = false
	root.add_child(_edge)
	_pills = MHStyle.hbox(8)
	_pills.anchor_left = .5
	_pills.anchor_right = .5
	_pills.offset_left = -400
	_pills.offset_right = 400
	_pills.offset_top = 150
	_pills.alignment = BoxContainer.ALIGNMENT_CENTER
	_pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pills)

func _show_banner(alert: Dictionary, level: String, reminder: bool) -> void:
	if _banner != null and is_instance_valid(_banner): _banner.queue_free()
	var tone: Color = LEVEL_COLOUR[level]
	_banner = PanelContainer.new()
	_banner.anchor_left = .5
	_banner.anchor_right = .5
	_banner.offset_left = -380
	_banner.offset_right = 380
	_banner.offset_top = 150
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 8, 2, Vector4(18, 12, 18, 14)))
	var column := MHStyle.vbox(6)
	var head := MHStyle.hbox(10)
	head.add_child(MHStyle.icon("circle-check" if level == "resolved" else "triangle-alert", 20, tone))
	var names := {"advisory": "ADVISORY", "warning": "WARNING", "critical": "CRITICAL", "resolved": "ALL CLEAR"}
	head.add_child(MHStyle.eyebrow(str(names[level]) + (" · STILL ACTIVE" if reminder else ""), tone, 13))
	head.add_child(MHStyle.title(str(alert.title), 18))
	column.add_child(head)
	if not str(alert.text).is_empty():
		var body := MHStyle.body(str(alert.text), 14, MHStyle.TEXT_SECONDARY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 720
		column.add_child(body)
	if alert.has("why"):
		var why := MHStyle.body("Why it matters: " + str(alert.why), 14, MHStyle.TEXT_PRIMARY)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = 720
		column.add_child(why)
	var chain: Array = alert.get("chain", [])
	if not chain.is_empty():
		var row := MHStyle.hbox(6)
		for i in range(chain.size()):
			var link: Array = chain[i]
			if i > 0: row.add_child(MHStyle.icon("chevron-right", 14, MHStyle.TEXT_MUTED))
			var chip := PanelContainer.new()
			var ok := bool(link[2])
			chip.add_theme_stylebox_override("panel", MHStyle.box(Color(1, 1, 1, .06), MHStyle.BORDER_SUBTLE if ok else Color(tone, .7), 6, 1, Vector4(8, 4, 8, 4)))
			var inner := MHStyle.hbox(5)
			inner.add_child(MHStyle.icon(str(link[0]), 14, MHStyle.TEXT_SECONDARY if ok else tone))
			var words := MHStyle.body(str(link[1]), 13, MHStyle.TEXT_PRIMARY if not ok else MHStyle.TEXT_SECONDARY)
			words.autowrap_mode = TextServer.AUTOWRAP_OFF
			inner.add_child(words)
			chip.add_child(inner)
			row.add_child(chip)
		column.add_child(row)
	_banner.add_child(column)
	_layer.get_child(0).add_child(_banner)
	_banner_left = BANNER_SECONDS * (.5 if reminder else 1.0)
	_pills.visible = false

func _refresh_pills() -> void:
	for child in _pills.get_children(): child.queue_free()
	var order := _active.keys()
	order.sort_custom(func(a, b): return LEVEL_RANK[str(_active[a].level)] > LEVEL_RANK[str(_active[b].level)])
	for id in order:
		var tone: Color = LEVEL_COLOUR[str(_active[id].level)]
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 12, 1, Vector4(10, 4, 12, 4)))
		var row := MHStyle.hbox(6)
		row.add_child(MHStyle.icon("triangle-alert", 13, tone))
		var words := MHStyle.body(str(_active[id].title), 12, MHStyle.TEXT_PRIMARY)
		words.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(words)
		pill.add_child(row)
		_pills.add_child(pill)
