extends Node

## Habitat alerts (backlog item 26, docs/designs-batches-4-6.md): the habitat
## speaks up when something starts going wrong. It has a name (MHGame.habitat_name,
## "ARDEN" by default) and talks in the first person, warm and a little dry,
## saying what to do (data/voice_lines.json, a few variants of each line, with
## captions). Numbers stay on screen. When all is well it makes the odd remark:
## at sunrise and sunset, and now and then when nothing's wrong.
##
## Every half second (real time) it reads the live simulation and works out
## each alert's level: advisory (blue), warning (amber) or critical (red: its
## icon pulses, the screen edge glows red, a soft chime each minute). A new or
## escalated alert doesn't interrupt (playtest feedback, 25 Oct): like
## Stellaris's notifications, it adds an icon to a row at the top of the
## screen, coloured by level, with a soft chime. Click one (or press N for
## the most serious) to open it: ARDEN says what's wrong, and the card shows
## what to do and its cause chain, the linked systems from the cause to what
## it threatens ("Power: none at night → Oxygen generator: off → O₂ 19.6% ↓
## → Crew health"); the first time, why it matters too. Right-click hides an
## icon until the alert gets worse. Only a new critical alert speaks up by
## itself (once). When an alert clears, its icon flashes green. Everything is
## kept in `history` for Mission Control's alert log. Dust storms stay with
## weather.gd, which announces them (with the same voice). Coming in through
## an airlock: "Welcome home" ("Welcome aboard" the first time).
const MHResources := preload("res://scripts/mh_resources.gd")

const LEVEL_RANK := {"": 0, "advisory": 1, "warning": 2, "critical": 3}
const LEVEL_COLOUR := {"advisory": Color("#5DC8F9"), "warning": Color("#F5C542"), "critical": Color("#E5484D"), "resolved": Color("#3EE58A")}
const LEVEL_SOUND := {"advisory": "ui_confirm", "warning": "storm_alert", "critical": "warn", "resolved": "all_clear"}
## Each alert's icon in the notification row.
const ICONS := {"life_support_power": "zap", "power": "zap", "battery_sunset": "moon", "o2": "wind", "co2": "recycle",
	"cold": "flame", "cold_spot": "flame", "water": "droplets", "food": "utensils", "health": "heart-pulse",
	"radiation": "radiation", "breach": "shield", "repress": "gauge", "breakdown": "wrench", "blackout": "satellite",
	"injury": "syringe", "fitness": "dumbbell", "wellbeing": "smile"}
## A critical alert still active chimes (softly, no voice) this often.
const CRITICAL_CHIME := 60.0

var world: Node
## Every alert raised, escalated or cleared: {time, sol_hour, id, level, title, text}.
var history: Array = []
var _active: Dictionary = {}     # id -> {level, since, said}
var _previous: Dictionary = {}   # value readings from the last check, for "rising"/"falling"
var _check_in := 0.0
var _layer: CanvasLayer
var _detail: PanelContainer        # the open alert card
var _detail_id := ""
var _icons: HBoxContainer          # the notification row
var _dismissed: Dictionary = {}    # id -> the level it was hidden at
var _mouse_before := -1            # the mouse mode before a card freed the cursor
var _icons_key := ""               # what the row shows now
var _shown_words := ""             # what the open card says now
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
var _remark_wait := 300.0
var _remarked := {}   # "dawn"/"dusk" -> the sol it was last said

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("habitat_alerts")
	_build_hud()

func sim() -> RefCounted:
	return world.builder.simulation()

func _process(delta: float) -> void:
	_clock += delta
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
	_remark()
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

## The habitat's small talk, only indoors and only when no alert is up:
## sunrise and sunset once a sol, otherwise a remark every 7 to 14 minutes.
func _remark() -> void:
	_remark_wait -= .5
	if not _active.is_empty() or not _was_inside: return
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var hour := MHGame.sol_hour
	var sol := floori(float(sim().hours_run) / 24.0)
	for moment: String in ["dawn", "dusk"]:
		var at := sunrise if moment == "dawn" else sunset
		if hour >= at and hour < at + .75 and int(_remarked.get(moment, -1)) != sol:
			_remarked[moment] = sol
			MHAudio.voice("remark_" + moment)
			return
	if _remark_wait > 0.0: return
	_remark_wait = randf_range(420.0, 840.0)
	MHAudio.voice("remark_night" if hour >= sunset + 1.0 or hour < sunrise - .5 else "remark_calm")

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
	_life_alerts(s, inv, out)
	return out

## Act 2: radiation, breaches, breakdowns and the crew as people (habitat_life.gd).
func _life_alerts(s: RefCounted, inv: Dictionary, out: Array) -> void:
	var life: RefCounted = s.life
	if life == null or s.crew_count() <= 0: return
	var place: Dictionary = life.shelter(inv)
	if float(life.spe_eta) >= 0.0:
		var where := "No storm shelter: the crew stay where they are" if place.is_empty() else "Shelter: %s, %d shield points" % [str(place.label), roundi(float(place.rating))]
		out.append({"id": "radiation", "level": "critical", "title": "Solar particle event: all crew to the shelter",
			"text": "Radiation from a solar flare arrives in %s." % _hours(maxf(0.0, float(life.spe_eta))),
			"chain": [["sun", "Solar flare", true], ["radiation", where, place.is_empty()], ["users", "Crew dose", false]]})
	elif life.spe_active():
		out.append({"id": "radiation", "level": "warning", "title": "Radiation storm: crew sheltering",
			"text": "Dose so far %d mSv (limit 50). About %s to go." % [roundi(float(life.event_dose_msv)), _hours(float(life.spe_hours_left))],
			"chain": [["sun", "Solar particle event", false], ["radiation", "%s: %d points" % [str(place.get("label", "No shelter")), roundi(float(place.get("rating", 5.0)))], place.is_empty()], ["users", "%d mSv" % roundi(float(life.event_dose_msv)), false]]})
	var pressure: float = life.pressure_pct(inv)
	if not (life.breach as Dictionary).is_empty() and float(life.breach.get("patched_at", -1.0)) < 0.0:
		var vented: Array = life.section_rooms(inv, _room_index(inv, str(life.breach.room))).map(func(i): return str(inv.rooms[i].label))
		var kit: bool = (inv.all_items as Array).any(func(i): return str(i.id) == "hull_patch_kit")
		out.append({"id": "breach", "level": "critical", "title": "Hull breach: %s" % str(life.breach.get("label", "")),
			"text": "Hatches sealed. Losing air from: %s. Air pressure %d%%." % [", ".join(vented.slice(0, 3)), roundi(pressure)],
			"chain": [["triangle-alert", "Hole in the hull", false], ["gauge", "Pressure %d%% %s" % [roundi(pressure), _trend("pressure", pressure)], false], ["wrench", "Patch kit ready" if kit else "No patch kit!", not kit]]})
	elif pressure < 99.5:
		out.append({"id": "repress", "level": "advisory", "title": "Repressurising",
			"text": "Air pressure %d%%. %s" % [roundi(pressure), "Refilling from the air reserve." if float(life.air_reserve_kg) > 0.0 else "The air reserve is empty: those rooms stay empty."],
			"chain": [["gauge", "Pressure %d%%" % roundi(pressure), false], ["wind", "Air reserve %d kg" % roundi(float(life.air_reserve_kg)), float(life.air_reserve_kg) <= 0.0]]})
	if not (life.broken as Dictionary).is_empty():
		var names: Array = life.broken_labels()
		var down: bool = not (life.down_hours as Dictionary).is_empty()
		out.append({"id": "breakdown", "level": "critical" if down else "warning", "title": "%s broken" % str(names[0]) + (" (+%d more)" % (names.size() - 1) if names.size() > 1 else ""),
			"text": ("Being repaired: %s left." % _hours(float(life.repair_left)) if not str(life.repairing).is_empty() else "No spare parts to repair it!") + (" A whole system is down." if down else " A second unit is keeping things going."),
			"chain": [["wrench", "%d broken" % names.size(), false], ["package", "%d spares left" % int(life.spares), int(life.spares) == 0], ["heart-pulse", "Crew" if down else "Redundancy", down]]})
	if float(life.blackout_hours_left) > 0.0:
		out.append({"id": "blackout", "level": "advisory", "title": "No contact with Earth",
			"text": "The Sun is between Mars and Earth: %s until contact returns." % _sols(float(life.blackout_hours_left) / 24.0),
			"chain": [["sun", "Solar conjunction", true], ["satellite", "Comms blackout", false], ["smile", "Wellbeing", true]]})
	if not life.crew_on or (life.crew as Array).is_empty(): return
	for p in life.injured():
		var ready: bool = life.medical_ready(inv, s.last.get("tiers", {4: true}))
		out.append({"id": "injury", "level": "warning" if not ready else "advisory", "title": "%s is injured" % str(p.name),
			"text": "Recovering in the Medical Bay: %s left." % _sols(float(p.injured_h) / 24.0) if ready else "They can't recover without a Medical Bay with an exam cot and a medical cabinet.",
			"chain": [["heart-pulse", "%s (%s)" % [str(p.name), str(life.role(str(p.role)).get("label", ""))], false], ["heart-pulse", "Medical Bay ready" if ready else "No Medical Bay", not ready]]})
		break
	var fitness: float = life.lowest_fitness()
	if fitness < 78.0:
		out.append({"id": "fitness", "level": "critical" if fitness < 70.0 else "warning", "title": "Crew fitness falling",
			"text": "Lowest fitness %d%%. Mars gravity weakens bones and muscles without exercise." % roundi(fitness),
			"chain": [["orbit", "38% gravity", true], ["dumbbell", "%d exercise station%s" % [int(life._stations_cache), "" if int(life._stations_cache) == 1 else "s"], int(life._stations_cache) == 0], ["users", "Fitness %d%% %s" % [roundi(fitness), _trend("fitness", fitness)], false]]})
	var wellbeing: float = life.average_wellbeing()
	if wellbeing < 66.0:
		var missing: Array = (life._needs_cache as Array).filter(func(n): return float(n.score) < .9).map(func(n): return str(n.label))
		out.append({"id": "wellbeing", "level": "critical" if wellbeing < 60.0 else "warning", "title": "Crew wellbeing low",
			"text": "Wellbeing %d%%. Missing: %s. The Crew screen in Mission Control has details." % [roundi(wellbeing), ", ".join(missing.slice(0, 3)) if not missing.is_empty() else "nothing, so it will recover"],
			"chain": [["smile", "Wellbeing %d%% %s" % [roundi(wellbeing), _trend("wellbeing", wellbeing)], false], ["users", "Slower work", true]]})

func _room_index(inv: Dictionary, key: String) -> int:
	for i in range((inv.rooms as Array).size()):
		if str(inv.rooms[i].key) == key: return i
	return -1

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
	"radiation": "Mars has no magnetic field and thin air, so radiation from solar flares reaches the ground. A small, well-shielded storm shelter protects the crew for the day it lasts.",
	"breach": "Hatches seal automatically, so only the rooms joined to the breached one without a hatch lose their air. Then a patch kit seals the hole.",
	"repress": "Once the hole is patched, stored air from the air reserve racks refills the empty rooms.",
	"breakdown": "Machines wear out. Each repair uses a spare part. Having two of every life-critical machine (redundancy) keeps the crew safe while one is fixed.",
	"blackout": "Every two years Mars passes behind the Sun from Earth, and for about two weeks no messages get through. Crews have to manage on their own.",
	"injury": "With Earth up to 24 minutes away by message, the crew's doctor treats injuries here, in the Medical Bay.",
	"fitness": "In 38% gravity bones and muscles slowly weaken. Each powered exercise station keeps about three crew fit.",
	"wellbeing": "Wellbeing depends on six needs: sleep, space, meals together, a bit of home, meaningful work and contact with Earth.",
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
	alerts.sort_custom(func(a, b): return LEVEL_RANK[str(a.level)] > LEVEL_RANK[str(b.level)])
	var chimed := false
	for alert in alerts:
		var id := str(alert.id)
		seen[id] = true
		var level := str(alert.level)
		var known: Dictionary = _active.get(id, {})
		var was := str(known.get("level", ""))
		if known.is_empty() or LEVEL_RANK[level] > LEVEL_RANK[was]:
			_active[id] = {"level": level, "since": now, "said": now, "title": alert.title, "alert": alert, "new": true}
			# The first time this kind of alert comes up, its card says why it matters.
			if EXPLAIN.has(id) and not _explained.has(id):
				_explained[id] = true
				_active[id]["why"] = true
			_dismissed.erase(id)   # worse than when it was hidden: it's back
			_record(alert, level)
			# One soft chime for the most serious new one; a new critical
			# alert also speaks up, once.
			if not chimed:
				MHAudio.sfx(str(LEVEL_SOUND[level]), -9.0, 0.0)
				if level == "critical": MHAudio.voice(voice_line(id, level))
				chimed = true
			if level != "advisory": preload("res://scripts/feature_hints.gd").first(get_tree(), "alerts")
		else:
			known.level = level
			known.title = alert.title
			known.alert = alert
			if level == "critical" and now - float(known.said) >= CRITICAL_CHIME and not chimed:
				known.said = now
				MHAudio.sfx("warn", -14.0, 0.0)
				chimed = true
	for id in _active.keys():
		if seen.has(id): continue
		var gone: Dictionary = _active[id]
		_active.erase(id)
		_dismissed.erase(id)
		if LEVEL_RANK[str(gone.level)] >= LEVEL_RANK["warning"]:
			_record({"id": id, "title": "%s: back to normal" % str(gone.title).trim_suffix(" falling").trim_suffix(" rising").trim_suffix(" running out").trim_suffix(" running low"), "text": "", "chain": []}, "resolved")
			MHAudio.sfx("all_clear", -12.0, 0.0)
			_flash_cleared(id)
		if _detail_id == id: _close_detail()
	_refresh_icons()
	# An open card follows its alert as it changes (only when its words do).
	if not _detail_id.is_empty() and _active.has(_detail_id) and _detail_words(_detail_id) != _shown_words: _fill_detail(_detail_id)

func _detail_words(id: String) -> String:
	var alert: Dictionary = _active[id].get("alert", {})
	return "%s|%s|%s|%s" % [_active[id].level, alert.get("title", ""), alert.get("text", ""), alert.get("chain", [])]

func _record(alert: Dictionary, level: String) -> void:
	var sol := floori(float(sim().hours_run) / 24.0) + 1 if world != null else 1
	history.append({"time": Time.get_datetime_string_from_system(false, true), "sol": sol, "sol_hour": MHGame.sol_hour, "id": alert.id, "level": level, "title": alert.title, "text": alert.text, "chain": alert.get("chain", [])})

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
	# The notification row: top middle, under the compass.
	_icons = MHStyle.hbox(8)
	_icons.anchor_left = .5
	_icons.anchor_right = .5
	_icons.offset_left = -400
	_icons.offset_right = 400
	_icons.offset_top = 112   # under the compass and its landmark labels
	_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_icons)

## One icon per active alert (not hidden), most serious first. A new one
## pops in; critical ones pulse.
func _refresh_icons() -> void:
	var order := _active.keys().filter(func(id): return not _dismissed.has(id))
	order.sort_custom(func(a, b): return LEVEL_RANK[str(_active[a].level)] > LEVEL_RANK[str(_active[b].level)])
	# Rebuilt only when something changed, so hovering and pulses aren't reset.
	var key := "%s|%s" % [_detail_id, ",".join(order.map(func(id): return "%s:%s:%s" % [id, _active[id].level, _active[id].title]))]
	if key == _icons_key: return
	_icons_key = key
	for child in _icons.get_children():
		if not child.has_meta("cleared"): child.queue_free()
	for id in order:
		var entry: Dictionary = _active[id]
		var level := str(entry.level)
		var tone: Color = LEVEL_COLOUR[level]
		var button := Button.new()
		button.custom_minimum_size = Vector2(52, 52)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "%s\nClick: what's wrong · Right-click: hide" % str(entry.title)
		var style := MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 10, 3 if id == _detail_id else 2)
		for state in ["normal", "pressed", "focus"]: button.add_theme_stylebox_override(state, style)
		button.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.tint(tone, .25), tone, 10, 3))
		button.icon = MHIcons.texture(str(ICONS.get(id, "triangle-alert")), 26)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]: button.add_theme_color_override(state, tone)
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT: dismiss(str(id))
				elif event.button_index == MOUSE_BUTTON_LEFT: open_alert(str(id)))
		_icons.add_child(button)
		if bool(entry.get("new", false)):
			entry.new = false
			button.pivot_offset = Vector2(26, 26)
			button.scale = Vector2(.2, .2)
			button.create_tween().tween_property(button, "scale", Vector2.ONE, .25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if level == "critical":
			var pulse := button.create_tween().set_loops()
			pulse.tween_property(button, "modulate", Color(1.3, 1.1, 1.1), .6)
			pulse.tween_property(button, "modulate", Color.WHITE, .6)

## A cleared alert: a green tick in the row for a moment.
func _flash_cleared(id: String) -> void:
	var tick := PanelContainer.new()
	tick.set_meta("cleared", true)
	tick.custom_minimum_size = Vector2(52, 52)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, LEVEL_COLOUR.resolved, 10, 2))
	var icon := MHStyle.icon(str(ICONS.get(id, "circle-check")), 26, LEVEL_COLOUR.resolved)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.add_child(icon)
	_icons.add_child(tick)
	var fade := tick.create_tween()
	fade.tween_interval(2.5)
	fade.tween_property(tick, "modulate:a", 0.0, .6)
	fade.tween_callback(tick.queue_free)

## Hide an alert's icon until it gets worse (Mission Control's log keeps it).
func dismiss(id: String) -> void:
	if not _active.has(id): return
	_dismissed[id] = str(_active[id].level)
	if _detail_id == id: _close_detail()
	MHAudio.sfx("ui_click", -8.0)
	_refresh_icons()

## Open an alert: ARDEN says it, and the card shows what to do. Opening the
## open one closes it.
func open_alert(id: String) -> void:
	if not _active.has(id): return
	if _detail_id == id:
		_close_detail()
		return
	_detail_id = id
	MHAudio.voice(voice_line(id, str(_active[id].level)))
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_before = Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill_detail(id)
	_refresh_icons()

func _close_detail() -> void:
	if _detail != null and is_instance_valid(_detail): _detail.queue_free()
	_detail = null
	_detail_id = ""
	if _mouse_before == Input.MOUSE_MODE_CAPTURED and not get_tree().paused: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_before = -1
	_refresh_icons()

## N: open the most serious alert showing, or close the open one.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N) or event.ctrl_pressed: return
	if get_tree().paused: return
	if not _detail_id.is_empty():
		_close_detail()
	else:
		var order := _active.keys().filter(func(id): return not _dismissed.has(id))
		if order.is_empty(): return
		order.sort_custom(func(a, b): return LEVEL_RANK[str(_active[a].level)] > LEVEL_RANK[str(_active[b].level)])
		open_alert(str(order[0]))
	get_viewport().set_input_as_handled()

## The open alert's card, under the row: what's wrong, why it matters (the
## first time), what's linked to it, and how to close or hide it.
func _fill_detail(id: String) -> void:
	var entry: Dictionary = _active[id]
	var alert: Dictionary = entry.get("alert", {"title": entry.title, "text": "", "chain": []})
	var level := str(entry.level)
	var tone: Color = LEVEL_COLOUR[level]
	_shown_words = _detail_words(id)
	if _detail != null and is_instance_valid(_detail): _detail.queue_free()
	_detail = PanelContainer.new()
	_detail.anchor_left = .5
	_detail.anchor_right = .5
	_detail.offset_left = -380
	_detail.offset_right = 380
	_detail.offset_top = 176
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 8, 2, Vector4(18, 12, 18, 14)))
	var column := MHStyle.vbox(6)
	var head := MHStyle.hbox(10)
	head.add_child(MHStyle.icon(str(ICONS.get(id, "triangle-alert")), 20, tone))
	var names := {"advisory": "ADVISORY", "warning": "WARNING", "critical": "CRITICAL"}
	head.add_child(MHStyle.eyebrow("%s · %s" % [str(names.get(level, "")), MHGame.habitat_name], tone, 13))
	var title := MHStyle.title(str(alert.title), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.icon = MHIcons.texture("x", 18)
	close.tooltip_text = "Close (N)"
	close.pressed.connect(_close_detail)
	head.add_child(close)
	column.add_child(head)
	if not str(alert.get("text", "")).is_empty():
		var body := MHStyle.body(str(alert.text), 14, MHStyle.TEXT_SECONDARY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 720
		column.add_child(body)
	if bool(entry.get("why", false)):
		var why := MHStyle.body("Why it matters: " + str(EXPLAIN[id]), 14, MHStyle.TEXT_PRIMARY)
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
	column.add_child(MHStyle.mono("N CLOSE  ·  RIGHT-CLICK THE ICON TO HIDE IT  ·  M ALERT LOG", 11, MHStyle.TEXT_MUTED))
	_detail.add_child(column)
	_layer.get_child(0).add_child(_detail)
