class_name MHCrewPlan
extends RefCounted

## Earth's crew plan. **7 Nov:** the crew size choice is gone. A new game's
## crew are always the story's five (IN_ORBIT), held in the orbiter until the
## buried heart is explained and the way down is safe: they land only in the
## one ending (docs/master-design.md §7). `held` stops the waves below.
##
## Older saves keep the 2 Nov wave plan (docs/survival-systems.md §12.2):
## you landed alone with a chosen crew size; Earth sent them in waves;
## each is announced with its manifest and lands crew_trip_sols later, and the
## base needs bunks, every chain and stores for them by then.
##
## The crew are unseen for now (visible NPCs are benched): each is a roster
## record {id, name, role, wave, lands_at, landed} that counts in the sim once
## landed, and their names join the crew list (habitat_life.gd). A body for
## each record later is all an NPC needs.
##
## Chapter rules only. `solo` is set in new games; older chapter saves keep
## their bunk-based crew. State is static and saved with chapter one.
const MHResources := preload("res://scripts/mh_resources.gd")
const HABITAT_CHAINS := preload("res://scripts/habitat_chains.gd")
const IN_ORBIT := 5            # the orbiter crew: Castellanos and four others
const WAVES := [3, 6, 9]
const ROSTER_PATH := "res://data/crew_roster.json"

static var final_size := 1 + IN_ORBIT  # you plus the orbiter crew (older saves: their chosen size)
static var held := false        # new games: the crew wait in orbit; no waves (older saves: false)
static var solo := false        # the sim counts you plus the landed crew (false in older chapter saves)
static var roster: Array = []   # everyone announced so far
static var settled_hours := 0.0 # how long the base has carried the crew aboard since the last landing
static var _check := 0.0
static var _pool: Dictionary = {}

static func reset() -> void:
	solo = true
	held = true
	final_size = 1 + IN_ORBIT
	roster = []
	settled_hours = 0.0
	_check = 0.0

static func export_state() -> Dictionary:
	return {"final_size": final_size, "solo": solo, "held": held, "roster": roster.duplicate(true), "settled_hours": settled_hours}

static func load_state(state: Dictionary) -> void:
	final_size = int(state.get("final_size", 6))
	solo = bool(state.get("solo", false))
	held = bool(state.get("held", false))
	roster = (state.get("roster", []) as Array).duplicate(true)
	settled_hours = float(state.get("settled_hours", 0.0))
	_check = 0.0

static func solitary() -> bool:
	return final_size <= 1

static func landed() -> Array:
	return roster.filter(func(p): return bool(p.landed))

static func en_route() -> Array:
	return roster.filter(func(p): return not bool(p.landed))

## The people aboard: you plus the landed crew.
static func aboard() -> int:
	return 1 + landed().size()

## The crew the base gets ready for: aboard plus anyone on the way.
static func planned() -> int:
	return 1 + roster.size()

## Names for the crew list (habitat_life.gd): you first (blank keeps your name), then the landed crew.
static func names() -> Array:
	var out: Array = [""]
	for p in landed(): out.append(str(p.name))
	return out

## The head count after the next wave: the next of WAVES, never past the final size.
static func next_goal() -> int:
	for w in WAVES:
		if int(w) > planned(): return mini(int(w), final_size)
	return final_size

## When the next landing is (game hours), or -1.
static func next_landing() -> float:
	var soonest := -1.0
	for p in en_route():
		if soonest < 0.0 or float(p.lands_at) < soonest: soonest = float(p.lands_at)
	return soonest

## The stores the base should hold by the landing: for everyone planned.
static func stores_needed() -> Dictionary:
	var n := float(planned())
	# Freedom: nobody needs food or drinking water, so neither is stocked.
	var water := MHResources.setting("water_per_person", 10.0) if MHGame.needs_food_water() else 0.0
	return {"food": n * MHResources.setting("crew_store_food_sols", 30.0) * MHGame.food_per_person(),
		"water": n * MHResources.setting("crew_store_water_sols", 7.0) * water,
		"o2": n * MHResources.setting("crew_store_o2_sols", 3.0) * MHResources.setting("o2_per_person", .84)}

## The checklist for the planned crew: {bunks, chains (the most the weakest carries), weakest, food, water, o2, ready}.
static func checklist(sim: RefCounted) -> Dictionary:
	var people := planned()
	var can: Dictionary = HABITAT_CHAINS.supports_all(sim)
	var weakest := "air"
	for id in can:
		if int(can[id]) < int(can[weakest]): weakest = id
	var need := stores_needed()
	var have := {"food": float(sim.food_kg), "water": float(sim.water_l), "o2": float(sim.o2_reserve_kg)}
	var bunks := int(sim.inventory().capacity.berths)
	var stocked: bool = have.food >= need.food and have.water >= need.water and have.o2 >= need.o2
	return {"people": people, "bunks": bunks, "chains": int(can[weakest]), "weakest": weakest, "can": can, "need": need, "have": have,
		"ready": bunks >= people and int(can[weakest]) >= people and stocked}

## Chapter one's clock (chapter_one.gd tick): announcements and landings, checked once a game hour.
static func tick(hours: float, sim: RefCounted, chapter_done: bool, now: float) -> Array:
	var out: Array = []
	if not solo or solitary() or held or not chapter_done: return out
	_check += hours
	if _check < 1.0 and not roster.is_empty(): return out
	var step := _check
	_check = 0.0
	# Landings.
	var arrived: Array = []
	for p in roster:
		if not bool(p.landed) and now >= float(p.lands_at):
			p.landed = true
			arrived.append(p)
	if not arrived.is_empty():
		settled_hours = 0.0
		var life = sim.get("life")
		if life != null and bool(life.crew_on):
			life.ensure_crew(sim.crew_count(), names())
			life.set_names(names())
		var short: bool = not bool(checklist(sim).ready)
		# Each lander brings Print Shop feedstock with its crew.
		var brought := arrived.size() * MHResources.setting("crew_feedstock_kg", 400.0)
		if MHChapterOne.on(): MHChapterOne.feedstock_kg += brought
		var cargo := " Their lander brought %s of feedstock for the Print Shop." % MHStyle.kg(roundi(brought)) if MHChapterOne.on() else ""
		out.append({"id": "crew_landed", "title": "%s landed" % _names(arrived), "text": "Mission Control: welcome them aboard. %d aboard now.%s%s" % [aboard(), cargo, " The base wasn't ready for them: check the Monitor's Chains." if short else ""], "tone": "warn" if short else "valid"})
		if aboard() >= final_size:
			out.append({"id": "crew_full", "title": "Full crew of %d aboard" % aboard(), "text": "Mission Control: that's everyone Earth is sending. Keep them all alive.", "tone": "valid"})
		return out
	if not en_route().is_empty() or planned() >= final_size: return out
	# The next wave: straight after chapter one, then once the crew aboard has settled.
	if not roster.is_empty():
		var rows: Array = HABITAT_CHAINS.chains(sim)
		if rows.any(func(c): return str(c.level) == "bad"): settled_hours = 0.0
		else: settled_hours += step
		if settled_hours < MHResources.setting("crew_settle_sols", 10.0) * 24.0: return out
	var wave := 0
	for p in roster: wave = maxi(wave, int(p.wave))
	var goal := next_goal()
	var lands_at := now + MHResources.setting("crew_trip_sols", 20.0) * 24.0
	var wave_people: Array = []
	for i in goal - planned():
		var person := _draw(roster.size(), wave + 1, lands_at)
		roster.append(person)
		wave_people.append(person)
	out.append({"id": "crew_plan", "title": "%s launch today" % _names(wave_people, true), "text": "Mission Control: they land on sol %d. Get bunks, every chain and stores ready for %d. The Monitor's Chains shows the checklist." % [floori(lands_at / 24.0) + 1, planned()], "tone": "info"})
	return out

static func _names(people: Array, roles := false) -> String:
	var parts: Array = people.map(func(p): return "%s (%s)" % [str(p.name), str(p.role)] if roles else str(p.name))
	if parts.size() <= 1: return "".join(parts)
	return "%s and %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[-1]]

## The i-th person Earth sends: the roster file's order, so it's the same every game and after loading.
static func _draw(i: int, wave: int, lands_at: float) -> Dictionary:
	if _pool.is_empty():
		var file := FileAccess.open(ROSTER_PATH, FileAccess.READ)
		_pool = JSON.parse_string(file.get_as_text()) if file != null else {}
		if not _pool is Dictionary or not _pool.has("crew"): _pool = {"crew": [{"name": "Crew", "role": "engineer"}]}
	var pool: Array = _pool.crew
	var entry: Dictionary = pool[i % pool.size()]
	return {"id": "crew_%d" % i, "name": str(entry.name), "role": str(entry.role), "wave": wave, "lands_at": lands_at, "landed": false}
