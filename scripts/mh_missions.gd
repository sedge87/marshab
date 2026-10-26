extends RefCounted

## Missions campaign (docs/missions-design.md): mission data from
## data/missions.json, the campaign's progress (saved with the base in the
## Missions save set), what each mission unlocks, its cargo budget, and the
## Test: a fast-forward run of the base on a copy of the simulation.
const PATH := "res://data/missions.json"
const HABITAT_SIM := preload("res://scripts/habitat_sim.gd")
const LANDING_PICKER := preload("res://scripts/landing_picker.gd")
const HABITAT_ALERTS := preload("res://scripts/habitat_alerts.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const BLAST_MARGIN := 12.0     # metres from the landing ellipse that engine blast reaches
const CLOSE_BASE := 40.0       # stretch goal: base this close to the landing target
const SAMPLE_HOURS := 0.5

static var _missions: Array = []
static var progress: Dictionary = {}

static func missions() -> Array:
	if _missions.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_missions = (parsed as Dictionary).get("missions", []) if parsed is Dictionary else []
	return _missions

static func get_mission(id: String) -> Dictionary:
	for mission in missions():
		if str(mission.id) == id: return mission
	return {}

static func active() -> bool:
	return MHGame.game_mode == "missions"

## A new campaign: Mission 1 (landing zones) is chosen on the menu's Land step.
static func reset() -> void:
	progress = {"current": "landing_zones", "completed": [], "landing_target": Vector2.INF, "base_site": Vector2.INF, "versions": {}, "briefed": {},
		"player_name": "", "campaign_id": str(int(Time.get_unix_time_from_system()))}

static func ensure() -> void:
	if progress.is_empty(): reset()
	# Saves from before the dossier: give them an id for their pictures.
	if not progress.has("campaign_id"): progress["campaign_id"] = str(int(Time.get_unix_time_from_system()))

static func current() -> Dictionary:
	ensure()
	return get_mission(str(progress.current))

static func next_after(id: String) -> Dictionary:
	var number := int(get_mission(id).get("number", 0))
	for mission in missions():
		if int(mission.number) == number + 1: return mission
	return {}

## Record a passed mission and move on to the next one (if it's ready yet).
static func complete(id: String) -> void:
	ensure()
	if not (progress.completed as Array).has(id): (progress.completed as Array).append(id)
	var next := next_after(id)
	if not next.is_empty() and bool(next.get("available", false)): progress.current = str(next.id)

static func is_complete(id: String) -> bool:
	ensure()
	return (progress.completed as Array).has(id)

static func save_state() -> Dictionary:
	ensure()
	return progress.duplicate(true)

static func load_state(state: Dictionary) -> void:
	if state.is_empty(): reset()
	else: progress = state.duplicate(true)
	# A campaign finished before later missions existed (Mission 6 used to be
	# the last) moves on to the next mission that is available now.
	var guard := 0
	while is_complete(str(progress.current)) and guard < 20:
		guard += 1
		var next := next_after(str(progress.current))
		if next.is_empty() or not bool(next.get("available", false)): break
		progress.current = str(next.id)

# ---------- what this mission allows ----------

## Missions so far (up to and including the current one).
static func _so_far() -> Array:
	var number := int(current().get("number", 1))
	return missions().filter(func(m): return int(m.number) <= number)

## Each payload adds to the base's cargo: the budget is every delivery so far.
static func cargo_budget() -> int:
	var total := 0
	for mission in _so_far(): total += int(mission.get("payload_kg", 0))
	return total

static func zone_unlocked(kind: String) -> bool:
	if not active() or kind == "ladder": return true   # a roof ladder isn't a delivery
	if kind.begins_with("shield_"): return structure_unlocked("upgrade_" + kind.trim_prefix("shield_"))
	for mission in _so_far():
		if (mission.get("unlock_zones", []) as Array).has(kind): return true
	return false

static func item_unlocked(id: String) -> bool:
	if not active(): return true
	# Each mission delivers a small kit (data/missions.json "unlock_items"), so
	# the build bars stay short; this setting opens the whole catalogue.
	if bool(MHGame.setting("mission_full_catalogue")): return true
	var group := str(EquipmentCatalog.get_entry(id).get("group", ""))
	# An item a mission delivers by name arrives only with that mission, even
	# if an earlier mission unlocked the rest of its group.
	var named_later := missions().any(func(m): return (m.get("unlock_items", []) as Array).has(id))
	for mission in _so_far():
		if (mission.get("unlock_items", []) as Array).has(id): return true
		if not named_later and (mission.get("unlock_groups", []) as Array).has(group): return true
	return false

## What meets each requirement, by its check: [rooms and site parts, items].
## The build bars mark these NEEDED in the mission that asks for them.
const CHECK_KIT := {
	"always_powered": [["solar", "reactor"], ["battery_bank", "power_distribution_panel"]],
	"life_support_powered": [["solar", "reactor"], ["battery_bank", "power_distribution_panel"]],
	"water_per_sol": [["ice_extractor"], []],
	"min_temp": [[], ["wall_cabin_heater", "portable_utility_heater", "thermal_control_unit"]],
	"breathable": [["life_support"], ["oxygen_generator", "air_recycler", "oxygen_reserve_tank"]],
	"crew_aboard": [["living"], ["crew_bunk"]],
	"crew_safe": [["life_support", "galley"], ["oxygen_generator", "air_recycler", "water_reclaimer", "potable_water_dispenser", "wall_cabin_heater"]],
	"crew_health_min": [["medical"], ["medical_cabinet"]],
	"food_grown": [["hydroponics"], ["grow_tray", "seedling_station", "nutrient_mixer"]],
	"research": [["science"], ["science_workbench", "microscope_station"]],
	"research_total": [["science"], ["science_workbench", "microscope_station"]],
	"shelter_ready": [[], ["storm_shelter_locker", "wall_cabin_heater"]],
	"dose_max": [[], ["storm_shelter_locker"]],
	"fitness_min": [[], ["exercise_station"]],
	"wellbeing_min": [[], ["lounge_sofa", "table_football", "games_shelf", "music_station", "paper_books", "photo_frame", "guitar", "plant_pot"]],
	"patient_recovered": [["medical"], ["medical_exam_cot", "medical_cabinet"]],
	"pressure_min": [[], ["air_reserve_rack", "hull_patch_kit"]],
	"breach_patched": [[], ["hull_patch_kit"]],
	"breach_restored": [[], ["air_reserve_rack"]],
	"systems_up": [[], ["spare_parts_rack"]],
}

## "needed" (it meets one of this mission's requirements), "new" (this
## mission delivered it) or "": the build bars' badges. Missions only.
static func item_badge(id: String) -> String:
	return _badge(id, 1, "unlock_items")

static func zone_badge(kind: String) -> String:
	return _badge(kind, 0, "unlock_zones")

static func _badge(id: String, slot: int, delivered_key: String) -> String:
	if not active(): return ""
	var mission := current()
	for requirement in mission.get("requirements", []):
		if (CHECK_KIT.get(str(requirement.get("check", "")), [[], []])[slot] as Array).has(id): return "needed"
	if (mission.get(delivered_key, []) as Array).has(id): return "new"
	return ""

## Needed first, then new, then the rest (each keeping its order).
static func badge_order(ids: Array, zones := false) -> Array:
	var ranked := {"needed": [], "new": [], "": []}
	for id in ids: (ranked[zone_badge(str(id)) if zones else item_badge(str(id))] as Array).append(id)
	return ranked["needed"] + ranked["new"] + ranked[""]

## A Structure tool (wall and roof upgrades) delivered by a mission
## ("unlock_structures"); tools no mission names are always there.
static func structure_unlocked(id: String) -> bool:
	if not active(): return true
	if not missions().any(func(m): return (m.get("unlock_structures", []) as Array).has(id)): return true
	return _so_far().any(func(m): return (m.get("unlock_structures", []) as Array).has(id))

## How many crew this mission has aboard (0 for robot missions; free play: no cap).
static func crew_cap() -> int:
	if not active(): return -1
	return int(current().get("crew", 0))

# ---------- steps (the on-screen objective tracker) ----------

## Steps ticked so far in this mission. Once done, a step stays done.
static func steps_done(mission_id: String) -> Array:
	ensure()
	if not progress.has("steps"): progress["steps"] = {}
	if not (progress.steps as Dictionary).has(mission_id): (progress.steps as Dictionary)[mission_id] = []
	return (progress.steps as Dictionary)[mission_id]

## Tick any steps that are now done. `flags` are things only the world knows
## (left_lander, opened_plan). Returns the steps ticked by this call.
static func update_steps(builder: Node, flags: Dictionary) -> Array:
	var mission := current()
	var done := steps_done(str(mission.id))
	var ticked: Array = []
	last_unticked = []
	for step in steps_of(mission):
		if done.has(str(step.id)):
			# Build steps stay live: remove what one needed and it un-ticks
			# (stepping out, opening the plan and testing are one-offs).
			if LIVE_STEPS.has(str(step.get("check", ""))) and not _step_met(step, builder, flags, str(mission.id)):
				done.erase(str(step.id))
				last_unticked.append(step)
			continue
		if _step_met(step, builder, flags, str(mission.id)):
			done.append(str(step.id))
			ticked.append(step)
	return ticked

## A mission's steps. Steps marked tutorial_only (ARDEN's "look around and
## move") are there only when this game has Tutorial: Full.
static func steps_of(mission: Dictionary) -> Array:
	return (mission.get("steps", []) as Array).filter(func(step): return not bool(step.get("tutorial_only", false)) or MHGame.tutorial_mode == "full")

## Steps that need what's built now (zones, items), re-checked as you build.
const LIVE_STEPS := ["zone", "item", "item_any", "food_share", "shelter", "needs", "sections", "redundant", "contact"]
## Steps un-ticked by the last update_steps (something they needed was removed).
static var last_unticked: Array = []

## How far a counted step has got, e.g. "3 of 4" ("" if not counted).
static func step_progress(step: Dictionary, builder: Node) -> String:
	if str(step.get("check", "")) == "counter" and int(step.get("count", 1)) > 1:
		return "%d of %d" % [mini(counter(str(step.key)), int(step.count)), int(step.count)]
	if str(step.get("check", "")) == "food_share":
		return "%d%% of %d%%" % [roundi(food_share(builder, current()) * 100.0), roundi(float(step.get("min", .25)) * 100.0)]
	match str(step.get("check", "")):
		"shelter": return "%d of %d points" % [roundi(shelter_points(builder)), int(step.get("min", 20))]
		"needs": return "%d of 6" % needs_met(builder)
		"contact":
			var mast: bool = builder.placed_surface.any(func(i): return str(i.get("id", "")) == "comms_antenna")
			return "station %s · mast %s" % ["✓" if station_ready(builder) else "missing", "✓" if mast else "missing"]
		"sections": return "biggest %d%%" % roundi(largest_section(builder) * 100.0)
		"redundant":
			var items: Array = step.get("items", [])
			var single: Array = items.filter(func(id): return builder.placed_interior.filter(func(i): return str(i.get("id", "")) == str(id)).size() < 2)
			var names: Array = single.map(func(id): return str(EquipmentCatalog.get_entry(str(id)).get("label", id)).to_lower())
			return "%d of %d doubled%s" % [items.size() - single.size(), items.size(), (" · still need a second " + ", ".join(names)) if not names.is_empty() else ""]
	if str(step.get("check", "")) != "item" or int(step.get("count", 1)) <= 1: return ""
	var have: int = builder.placed_interior.filter(func(i): return str(i.get("id", "")) == str(step.item)).size()
	return "%d of %d" % [have, int(step.count)]

## Contact with Earth is set up: a communications station in Mission
## Operations (the "communications" room), and the Communications Mast outside.
static func contact_ready(builder: Node) -> bool:
	return station_ready(builder) and builder.placed_surface.any(func(i): return str(i.get("id", "")) == "comms_antenna")

static func station_ready(builder: Node) -> bool:
	for item in builder.placed_interior:
		if str(item.get("id", "")) != "communications_station": continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if str(builder._zone_at_point(Vector2(at.x, at.z)).get("kind", "")) == "communications": return true
	return false

## The share of the mission crew's daily food that the placed growers make.
static func food_share(builder: Node, mission: Dictionary) -> float:
	var eaten: float = maxf(1.0, float(mission.get("crew", 0))) * MHResources.setting("food_per_person", 1.8)
	var grown := 0.0
	for item in builder.placed_interior: grown += MHResources.item_value(str(item.get("id", "")), "food_kg")
	return grown / eaten

## The storm shelter's shield points now (0 without a shelter).
static func shelter_points(builder: Node) -> float:
	var sim: RefCounted = builder.simulation()
	return float(sim.life.shelter(sim.inventory()).get("rating", 0.0))

## How many of the crew's six needs are met now (a need counts at 90%).
static func needs_met(builder: Node) -> int:
	var sim: RefCounted = builder.simulation()
	var inv: Dictionary = sim.inventory()
	if sim.life.crew.is_empty(): sim.life.ensure_crew(maxi(1, int(current().get("crew", 6))), progress.get("crew_names", []))
	var tiers: Dictionary = sim.last.get("tiers", {1: true, 2: true, 3: true, 4: true})
	return (sim.life.needs(inv, tiers) as Array).filter(func(n): return float(n.score) >= .9).size()

## The biggest section's share of the habitat (rooms joined without a hatch).
static func largest_section(builder: Node) -> float:
	var sim: RefCounted = builder.simulation()
	var inv: Dictionary = sim.inventory()
	var total := 0.0
	var by_section := {}
	var map: Dictionary = sim.life.sections(inv)
	for index in range((inv.rooms as Array).size()):
		var cells := float(inv.rooms[index].cells)
		total += cells
		by_section[map[index]] = float(by_section.get(map[index], 0.0)) + cells
	if total <= 0.0: return 1.0
	return float(by_section.values().max()) / total

static func set_crew_names(names: Array) -> void:
	ensure()
	progress["crew_names"] = names.duplicate()

## The first step not yet done, or {} when all are done.
static func current_step() -> Dictionary:
	var mission := current()
	var done := steps_done(str(mission.id))
	for step in steps_of(mission):
		if not done.has(str(step.id)): return step
	return {}

static func _step_met(step: Dictionary, builder: Node, flags: Dictionary, mission_id: String) -> bool:
	match str(step.get("check", "")):
		"left_lander", "opened_plan", "inside", "moved": return bool(flags.get(str(step.check), false))
		"zone": return builder.zones.any(func(z): return str(z.kind) == str(step.kind))
		"item": return builder.placed_interior.filter(func(i): return str(i.get("id", "")) == str(step.item)).size() >= int(step.get("count", 1))
		"item_any": return builder.placed_interior.any(func(i): return (step.get("items", []) as Array).has(str(i.get("id", ""))))
		"food_share": return food_share(builder, get_mission(mission_id)) >= float(step.get("min", .25))
		"counter": return counter(str(step.key)) >= int(step.get("count", 1))
		"shelter": return shelter_points(builder) >= float(step.get("min", 20))
		"crew_named": return not (progress.get("crew_names", []) as Array).is_empty()
		"needs": return needs_met(builder) >= int(step.get("min", 4))
		"sections": return largest_section(builder) <= float(step.get("max", .4)) + .001
		"contact": return contact_ready(builder)
		"redundant": return (step.get("items", []) as Array).all(func(id): return builder.placed_interior.filter(func(i): return str(i.get("id", "")) == str(id)).size() >= 2)
		"tested": return not versions(mission_id).is_empty()
		"passed": return versions(mission_id).any(func(v): return bool(v.passed))
	return false

## A mission's supply delivery of food (Mission 6), added once to the base.
static func deliver_mission_food(sim: RefCounted) -> bool:
	var mission := current()
	var sols := float(mission.get("food_delivery_sols", 0))
	if sols <= 0.0: return false
	if not progress.has("food_delivered"): progress["food_delivered"] = {}
	if bool((progress.food_delivered as Dictionary).get(str(mission.id), false)): return false
	(progress.food_delivered as Dictionary)[str(mission.id)] = true
	sim.food_kg += float(mission.get("crew", 0)) * MHResources.setting("food_per_person", 1.8) * sols
	return true

## Has the arrival (the cargo lander's touchdown) been played for this mission?
static func arrived(mission_id: String) -> bool:
	ensure()
	return bool((progress.get("arrived", {}) as Dictionary).get(mission_id, false))

static func set_arrived(mission_id: String) -> void:
	ensure()
	if not progress.has("arrived"): progress["arrived"] = {}
	(progress.arrived as Dictionary)[mission_id] = true

## Cargo landers on site: [{number, position, yaw}], kept between missions.
static func cargo_landers() -> Array:
	ensure()
	if not progress.has("cargo_landers"): progress["cargo_landers"] = []
	return progress.cargo_landers

static func landing_target() -> Vector2:
	ensure()
	return progress.get("landing_target", Vector2.INF)

static func base_site() -> Vector2:
	ensure()
	return progress.get("base_site", Vector2.INF)

## Engine blast: nothing can be built inside the landing ellipse or within
## BLAST_MARGIN of it.
static func in_blast_zone(point: Vector2) -> bool:
	if not active(): return false
	var target := landing_target()
	if is_inf(target.x): return false
	var d := point - target
	var a := LANDING_PICKER.ELLIPSE_A + BLAST_MARGIN
	var b := LANDING_PICKER.ELLIPSE_B + BLAST_MARGIN
	return (d.x * d.x) / (a * a) + (d.y * d.y) / (b * b) <= 1.0

# ---------- Mission 1: landing zones ----------

## Results for a landing target and a base site (Mission 1's checks).
static func check_landing(target: Vector2, base: Vector2) -> Dictionary:
	var verdict := LANDING_PICKER.evaluate(target)
	var safe := str(verdict.level) == "green"
	var d := base - target
	var a := LANDING_PICKER.ELLIPSE_A + BLAST_MARGIN
	var b := LANDING_PICKER.ELLIPSE_B + BLAST_MARGIN
	var clear := not is_inf(base.x) and (d.x * d.x) / (a * a) + (d.y * d.y) / (b * b) > 1.0 and LANDING_PICKER.footprint_safe(base)
	var close := clear and target.distance_to(base) <= CLOSE_BASE
	var clear_text := "Base site is clear of engine blast." if clear else ("Choose a base site: right-click the map." if is_inf(base.x) else ("The base site is too close to the landing ellipse: engine blast reaches 12 m beyond it." if LANDING_PICKER.footprint_safe(base) else "The base site is on rough ground: pick flat, open ground."))
	return {"landing_safe": safe, "landing_clear": clear, "close": close, "landing_text": str(verdict.text), "clear_text": clear_text, "passed": safe and clear}

# ---------- the Test ----------

## Fast-forward the mission on a copy of the base's simulation (the real base
## is never changed). Returns the report: samples for graphs, each
## requirement's result with a reason, stretch goals and a design summary.
static func run_test(builder: Node) -> Dictionary:
	var mission := current()
	var futures := maxi(1, int(mission.get("futures", 1)))
	var runs: Array = []
	for future in range(futures): runs.append(_simulate(builder, mission, future, ""))
	var sols := int(mission.get("sols", 3))
	var start_hour := 8.0
	var first: Dictionary = runs[0]
	var crew: int = int(first.crew)
	var results: Array = []
	for requirement in mission.get("requirements", []):
		var result := {"id": str(requirement.id), "text": str(requirement.text), "pass": true, "detail": "", "tip": ""}
		for run_index in range(runs.size()):
			var run: Dictionary = runs[run_index]
			var one := _judge(requirement, run, sols, start_hour)
			if not bool(one.pass) or run_index == 0:
				result.pass = bool(one.pass); result.detail = str(one.detail); result.tip = str(one.get("tip", ""))
				if futures > 1 and not bool(one.pass): result.detail = "In future %d of %d: %s" % [run_index + 1, futures, result.detail]
			if not bool(one.pass): break
		if bool(result.pass) and futures > 1: result.detail = "All %d futures. %s" % [futures, result.detail]
		results.append(result)
	var stretch: Array = []
	for goal in mission.get("stretch", []):
		var met := not (first.failures as Dictionary).has("stretch:" + str(goal.id))
		match str(goal.check):
			"no_zone": met = builder.zones.filter(func(z): return str(z.kind) == str(goal.kind)).is_empty()
			"no_item": met = not builder.placed_interior.any(func(i): return str(i.get("id", "")) == str(goal.item))
			"payload_spare": met = builder.used_cargo() <= cargo_budget() - int(float(mission.get("payload_kg", 0)) * float(goal.get("fraction", .15)))
			"food_grown": met = float(first.food_in) / maxf(.001, float(crew) * MHResources.setting("food_per_person", 1.8) * sols) >= float(goal.get("min", .4))
			"counter": met = counter(str(goal.key)) >= int(goal.get("count", 1))
			"breach_any":
				# A breach in every room in turn: the habitat must hold its air each time.
				met = true
				var inv: Dictionary = builder.simulation().inventory()
				for room in inv.rooms:
					if str(room.kind) in ["airlock", "vehicle_bay"]: continue
					var trial := _simulate(builder, mission, 0, str(room.key), true)
					if float(trial.min_pressure) < float(goal.get("min", 70)) or not bool((trial.breach as Dictionary).get("patched", false)):
						met = false
						break
			"shelter_bunks":
				var place: Dictionary = first.shelter
				met = not place.is_empty() and (first.inventory.all_items as Array).filter(func(i): return str(i.id) == "crew_bunk" and int(i.room) == int(place.index)).size() >= crew
		stretch.append({"text": str(goal.text), "pass": met})
	var shown: Dictionary = first
	for run in runs:
		if not (run.failures as Dictionary).is_empty():
			shown = run
			break
	var passed := results.all(func(r): return bool(r.pass))
	var report := {"mission": str(mission.id), "samples": shown.samples, "results": results, "stretch": stretch, "passed": passed,
		"storms": shown.storms, "start_hour": start_hour, "sols": sols, "design": design_summary(builder), "alerts": shown.alerts, "futures": futures}
	_record_version(report)
	return report

## One run of the Test (one "future"). breach_room overrides where a breach hits.
static func _simulate(builder: Node, mission: Dictionary, future: int, breach_room: String, breach_only := false) -> Dictionary:
	var sim: RefCounted = HABITAT_SIM.new(builder)
	sim.load(builder.simulation().save())
	sim.crew_cap = int(mission.get("crew", 0))
	sim.run_step = float(mission.get("step_hours", HABITAT_SIM.STEP_HOURS))
	sim.prewarm_rooms()
	sim.random_storms = false
	sim.storm_hours_left = 0.0
	sim.invalidate()
	var life: RefCounted = sim.life
	life.live_kinds = []
	life.crew_on = bool(mission.get("named_crew", false))
	life.breakdowns_on = bool(mission.get("breakdowns", false))
	life.breakdown_scale = float(mission.get("breakdown_scale", 1.0))
	life.rng.seed = 1000 + future * 7919
	# A fresh start for the Test: no leftover breaches, events or broken machines.
	life.breach = {}; life.section_pressure = {}; life.broken = {}; life.repairing = ""; life.spe_eta = -1.0; life.spe_hours_left = 0.0
	life.dose_msv = 0.0; life.event_dose_msv = 0.0; life.worst_event_msv = 0.0; life.worst_down_hours = 0.0; life.down_hours = {}
	life.blackout_hours_left = 0.0; life.research_done = 0.0
	var inventory: Dictionary = sim.inventory()
	sim.battery_kwh = float(inventory.capacity.kwh)   # tests start with full batteries
	life.take_delivery(inventory)
	life.air_reserve_kg = float(life._known.get("air", 0.0))
	life.spares = int(life._known.get("spares", 0))
	if life.crew_on:
		life.ensure_crew(sim.crew_count(), progress.get("crew_names", []))
		for p in life.crew:
			p.fitness = float(life.value("fitness", "start", 100.0)); p.wellbeing = float(life.value("wellbeing", "start", 80.0)); p.injured_h = 0.0
	var shelter_at_start: Dictionary = life.shelter(inventory)
	var sols := int(mission.get("sols", 3))
	var start_hour := 8.0
	var storms: Array = []
	var timed: Array = []   # [hours, type, event]
	for event in mission.get("events", []):
		match str(event.type):
			"storm": storms.append({"start": (_pick(event.sol, future) - 1.0) * 24.0, "hours": float(event.sols) * 24.0, "cut": float(event.get("solar_cut", -1.0)), "load_kw": float(event.get("load_kw", 0.0))})
			_:
				var at := (_pick(event.get("sol", 1), future) - 1.0) * 24.0 + _pick(event.get("hour", start_hour), future) - start_hour
				timed.append([maxf(0.0, at), str(event.type), event])
	var samples: Array = []
	var failures := {}
	var hours := 0.0
	var hour := start_hour
	var step := float(mission.get("sample_hours", SAMPLE_HOURS))
	var food_in := 0.0
	var crew: int = sim.crew_count()
	var alert_rules: Node = HABITAT_ALERTS.new()
	var alerts_seen := {}
	var alerts: Array = []
	var breach_log := {}
	var injured_at := -1.0
	var recovered_at := -1.0
	var min_pressure := 100.0
	var end_hours := sols * 24.0
	# A breach trial only needs the hours around the breach.
	if breach_only:
		for event in timed:
			if str(event[1]) == "breach": end_hours = minf(end_hours, float(event[0]) + 8.0)
	while hours < end_hours - .001:
		for storm in storms:
			if absf(hours - float(storm.start)) < .001: sim.start_storm(float(storm.hours) / 24.0, float(storm.get("cut", -1.0)), float(storm.get("load_kw", 0.0)))
		for event in timed:
			if hours + .0001 < float(event[0]) or hours >= float(event[0]) + step - .0001: continue
			var spec: Dictionary = event[2]
			match str(event[1]):
				"spe": life.forecast_spe(float(spec.get("warning_hours", -1.0)))
				"injury":
					if life.crew_on and life.injure(str(_pick_value(spec.get("role", "engineer"), future))): injured_at = hours
				"breach":
					var room := breach_room if not breach_room.is_empty() else str(spec.get("room", ""))
					if room.is_empty(): room = life.default_breach_room(sim.inventory())
					life.start_breach(sim.inventory(), room)
				"blackout": life.start_blackout(float(spec.get("sols", 14)))
		var chunk: Array = sim.run_hours(step, hour, step)
		hours += step
		hour = fmod(start_hour + hours, 24.0)
		var sample: Dictionary = chunk[-1] if not chunk.is_empty() else sim.snapshot(hour)
		sample["elapsed"] = hours
		sample["water_in"] = float(sim.last.get("water_in", 0.0))
		food_in += float(sim.last.get("food_in", 0.0)) * step / 24.0
		samples.append(sample)
		min_pressure = minf(min_pressure, float(sample.get("pressure_pct", 100.0)))
		if not (life.breach as Dictionary).is_empty(): breach_log = (life.breach as Dictionary).duplicate()
		if injured_at >= 0.0 and recovered_at < 0.0 and (life.injured() as Array).is_empty(): recovered_at = hours
		for alert in alert_rules.evaluate(sim, hour):
			var key := "%s:%s" % [alert.id, alert.level]
			if alerts_seen.has(key): continue
			alerts_seen[key] = true
			alerts.append({"at": hours, "when": _when(hours, start_hour), "level": str(alert.level), "title": str(alert.title)})
		for requirement in mission.get("requirements", []):
			if failures.has(requirement.id): continue
			var why := _sample_failure(str(requirement.check), requirement, sample, sim)
			if not why.is_empty(): failures[requirement.id] = {"at": hours, "why": why, "tip": _tip(str(requirement.check), sample, fmod(start_hour + hours, 24.0), _in_storm(hours, storms), 0, why)}
		for goal in mission.get("stretch", []):
			if failures.has("stretch:" + str(goal.id)): continue
			var why := _sample_failure(str(goal.check), goal, sample, sim)
			if not why.is_empty(): failures["stretch:" + str(goal.id)] = {"at": hours, "why": why}
	alert_rules.free()
	if not breach_log.is_empty(): breach_log["patched"] = float(breach_log.get("patched_at", -1.0)) >= 0.0
	return {"samples": samples, "failures": failures, "food_in": food_in, "crew": crew, "alerts": alerts, "storms": storms, "inventory": inventory,
		"research": float(sim.daily_flows(false).get("research", 0.0)), "research_done": float(life.research_done), "shelter": shelter_at_start,
		"worst_event_msv": float(life.worst_event_msv), "breach": breach_log, "injured_at": injured_at, "recovered_at": recovered_at,
		"min_pressure": min_pressure, "worst_down": float(life.worst_down_hours), "life": life}

## Event values can differ by future: a list gives one per future.
static func _pick(v: Variant, future: int) -> float:
	return float(_pick_value(v, future))

static func _pick_value(v: Variant, future: int) -> Variant:
	if v is Array: return (v as Array)[future % (v as Array).size()]
	return v

## The verdict on one requirement for one run: {pass, detail, tip}.
static func _judge(requirement: Dictionary, run: Dictionary, sols: int, start_hour: float) -> Dictionary:
	var failures: Dictionary = run.failures
	var result := {"pass": true, "detail": "", "tip": ""}
	if failures.has(requirement.id):
		result.pass = false
		result.detail = "Failed %s. %s" % [_when(float(failures[requirement.id].at), start_hour), str(failures[requirement.id].why)]
		result.tip = str(failures[requirement.id].tip)
	var crew := int(run.crew)
	var life: RefCounted = run.life
	match str(requirement.check):
		"always_powered":
			if result.pass: result.detail = "Every system had power for all %d sols." % sols
		"life_support_powered":
			if result.pass: result.detail = "Life support had power the whole time."
		"min_temp":
			if result.pass: result.detail = "The habitat never fell below %d °C." % int(requirement.get("min", 15))
		"breathable":
			if result.pass: result.detail = "Oxygen and carbon dioxide stayed in the safe range."
		"crew_safe":
			if result.pass: result.detail = "Air, water, food and temperature stayed safe for all %d sols." % sols
		"crew_health_min":
			if result.pass: result.detail = "Crew health stayed above %d%%." % int(requirement.get("min", 80))
		"crew_aboard":
			result.pass = crew >= int(requirement.get("min", 1))
			result.detail = "Bunks for %d of %d crew." % [crew, int(requirement.get("min", 1))] + ("" if result.pass else " Add crew bunks in Living Quarters.")
		"food_grown":
			var eaten: float = float(crew) * MHResources.setting("food_per_person", 1.8) * sols
			var share := float(run.food_in) / maxf(.001, eaten)
			result.pass = share >= float(requirement.get("min", .25))
			result.detail = "The base grew %d%% of the food (needs %d%%)." % [roundi(share * 100.0), roundi(float(requirement.get("min", .25)) * 100.0)] + ("" if result.pass else " Add grow trays, and make sure they keep power and water.")
		"research":
			result.pass = float(run.research) >= float(requirement.get("min", 1))
			result.detail = "Research: %s a sol." % str(snappedf(float(run.research), .1)) + ("" if result.pass else " Build a Science Lab and add a workbench.")
		"research_total":
			var per_sol := float(run.research_done) / maxf(1.0, sols)
			result.pass = per_sol >= float(requirement.get("min", 1))
			result.detail = "The crew managed %s research a sol on average (needs %s)." % [str(snappedf(per_sol, .1)), str(requirement.get("min", 1))]
			if not result.pass: result.detail += " Tired, unhappy or injured crew work slower: look after them, and add lab equipment."
		"water_per_sol":
			var total := 0.0
			for sample in run.samples: total += float(sample.water_in)
			var average := total / maxf(1.0, (run.samples as Array).size())
			result.pass = average >= float(requirement.get("min", 60))
			var drills := (run.inventory.drills as Array).size()
			result.detail = "The drills made %d L a sol on average (needs %d)." % [roundi(average), int(requirement.get("min", 60))]
			if not result.pass:
				result.detail += " " + ("There are no ice drills yet." if drills == 0 else "Add another drill, place drills on richer ice (paler blue), or make sure they keep their power.")
		"shelter_ready":
			var place: Dictionary = run.shelter
			var safe := float(life.value("radiation", "safe_points", 20.0))
			if place.is_empty():
				result.pass = false
				result.detail = "There's no storm shelter yet."
				result.tip = "Pick a small room and place a Storm Shelter Locker in it. Then add shielding: regolith shield blocks and water wall panels."
			else:
				var problems: Array = []
				if float(place.rating) < safe: problems.append("its shielding is %d points (needs %d)" % [roundi(float(place.rating)), roundi(safe)])
				if int(place.capacity) < crew: problems.append("it only fits %d of %d crew" % [int(place.capacity), crew])
				if not bool(place.heated): problems.append("it isn't heated")
				elif bool(place.cold): problems.append("it's a cold spot")
				result.pass = problems.is_empty()
				result.detail = "The shelter is %s: %d shield points, room for %d." % [str(place.label), roundi(float(place.rating)), int(place.capacity)]
				if not result.pass:
					result.detail = "The shelter (%s) isn't ready: %s." % [str(place.label), ", ".join(problems)]
					if float(place.rating) < safe: result.tip = "Shielding protects the whole habitat, shared over all its floor: add more regolith or water panels to the outside walls, or shield the roofs."
					else: result.tip = "A shelter needs 1 floor square for every 3 crew, and heating that reaches it."
		"dose_max":
			if result.pass: result.detail = "The event dose was %d mSv (limit %d)." % [roundi(float(run.worst_event_msv)), int(requirement.get("max", 50))]
			else:
				var place: Dictionary = run.shelter
				result.detail = "In the solar particle event the crew got %d mSv of radiation (limit %d)%s." % [roundi(float(run.worst_event_msv)), int(requirement.get("max", 50)),
					": there was no storm shelter" if place.is_empty() else ", sheltering in %s with %d shield points" % [str(place.label), roundi(float(place.rating))]]
		"fitness_min":
			if result.pass: result.detail = "Everyone stayed fit: the lowest was %d%%." % roundi(life.lowest_fitness())
		"wellbeing_min":
			if result.pass: result.detail = "Wellbeing averaged %d%% at the end." % roundi(life.average_wellbeing())
		"patient_recovered":
			var by := float(requirement.get("by_sol", 22)) * 24.0
			if float(run.injured_at) < 0.0:
				result.detail = "Nobody was injured."
			elif float(run.recovered_at) >= 0.0 and float(run.recovered_at) <= by:
				result.detail = "The patient recovered %s." % _when(float(run.recovered_at), start_hour)
			else:
				result.pass = false
				result.detail = "The patient hadn't recovered by sol %d." % int(requirement.get("by_sol", 22))
				result.tip = "Injured crew recover in a Medical Bay with an exam cot and a medical cabinet, with power."
		"pressure_min":
			if result.pass: result.detail = "Air pressure never fell below %d%% (lowest %d%%)." % [int(requirement.get("min", 70)), roundi(float(run.min_pressure))]
		"breach_patched":
			var b: Dictionary = run.breach
			if b.is_empty(): result.detail = "No breach happened."
			elif float(b.get("patched_at", -1.0)) >= 0.0 and float(b.patched_at) <= float(requirement.get("hours", 2)):
				result.detail = "The hole was patched in %s." % _duration(float(b.patched_at))
			else:
				result.pass = false
				result.detail = "The hole wasn't patched within %d hours." % int(requirement.get("hours", 2))
				result.tip = "Keep a hull patch kit in the habitat. The Engineer patches fastest." if not bool(b.get("had_kit", false)) else "The Engineer patches fastest: make sure they're fit and well."
		"breach_restored":
			var b: Dictionary = run.breach
			if b.is_empty(): result.detail = "No breach happened."
			elif float(b.get("restored_at", -1.0)) >= 0.0 and float(b.restored_at) <= float(requirement.get("hours", 6)):
				result.detail = "Full pressure was back in %s." % _duration(float(b.restored_at))
			else:
				result.pass = false
				result.detail = "The air wasn't back to full pressure within %d hours." % int(requirement.get("hours", 6))
				result.tip = "An air reserve rack refills a vented section once the hole is patched. Small sealed sections need less air."
		"systems_up":
			if result.pass: result.detail = "No life-critical system was down for more than %d hours." % int(requirement.get("max", 12))
	return result

static func _duration(hours: float) -> String:
	if hours < 1.0: return "%d minutes" % maxi(1, roundi(hours * 60.0))
	return "%s hours" % str(snappedf(hours, .1))

## Why a sample fails a check, or "" if it's fine (checks that run every sample).
static func _sample_failure(check: String, spec: Dictionary, sample: Dictionary, sim: RefCounted) -> String:
	match check:
		"always_powered":
			if not bool(sample.all_powered): return _first_warning(sim, "power")
		"life_support_powered":
			if not bool(sample.get("life_support", true)): return "Life support lost power. " + _first_warning(sim, "power")
		"min_temp":
			if float(sample.coldest_c) < float(spec.get("min", 15)): return "The habitat fell to %d °C. %s" % [roundi(float(sample.coldest_c)), _heating_reason(sim)]
		"breathable":
			if float(sample.o2_pct) < MHResources.setting("o2_min_pct", 19.5): return "Oxygen fell to %.1f%%. %s" % [float(sample.o2_pct), _first_warning(sim, "air")]
			if float(sample.co2_pct) > MHResources.setting("co2_danger_pct", 1.0): return "Carbon dioxide rose to %.1f%%. %s" % [float(sample.co2_pct), _first_warning(sim, "air")]
		"crew_safe":
			var air := _sample_failure("breathable", spec, sample, sim)
			if not air.is_empty(): return air
			if float(sample.coldest_c) < MHResources.setting("cold_c", 12.0): return "The habitat fell to %d °C. %s" % [roundi(float(sample.coldest_c)), _first_warning(sim, "cold")]
			if float(sample.water_l) <= 0.0: return "The water ran out. " + _first_warning(sim, "water")
			if float(sample.food_kg) <= 0.0: return "The food ran out. " + _first_warning(sim, "food")
		"crew_health_min":
			if float(sample.crew_health) < float(spec.get("min", 80)): return "Crew health fell to %d%%. %s" % [roundi(float(sample.crew_health)), _first_warning(sim, "")]
		"dose_max":
			if float(sample.get("event_dose_msv", 0.0)) > float(spec.get("max", 50)): return "The crew got %d mSv of radiation in the solar particle event (limit %d)." % [roundi(float(sample.event_dose_msv)), int(spec.get("max", 50))]
		"fitness_min":
			if float(sample.get("fitness", 100.0)) < float(spec.get("min", 70)): return "Someone's fitness fell to %d%%." % roundi(float(sample.fitness))
		"wellbeing_min":
			if float(sample.get("wellbeing", 100.0)) < float(spec.get("min", 60)): return "Average wellbeing fell to %d%%." % roundi(float(sample.wellbeing))
		"pressure_min":
			if float(sample.get("pressure_pct", 100.0)) < float(spec.get("min", 70)): return "Air pressure fell to %d%%: the breach vented too much of the habitat." % roundi(float(sample.pressure_pct))
		"systems_up":
			if float(sample.get("down_h", 0.0)) > float(spec.get("max", 12)): return "A life-critical system was down for over %d hours: %s." % [int(spec.get("max", 12)), ", ".join(sim.life.broken_labels())]
	return ""

static func _in_storm(hours: float, storms: Array) -> bool:
	for storm in storms:
		if hours >= float(storm.start) and hours <= float(storm.start) + float(storm.hours): return true
	return false

## A plain-English "try this" for a failed check, from what the base was doing
## at that moment (night or day, storm, battery, which supply ran out).
static func _tip(check: String, sample: Dictionary, hour_of_day: float, storm: bool, depth := 0, why := "") -> String:
	var night := hour_of_day < 6.0 or hour_of_day >= 18.0
	match check:
		"always_powered", "life_support_powered":
			if storm: return "The dust storm cut the solar power. Store more energy in batteries before it arrives, or add a reactor: it doesn't need sunlight."
			if float(sample.get("battery_pct", 0.0)) < 5.0 and night: return "The batteries ran flat in the night. Add more batteries, or more solar panels so they're full by sunset, or a reactor for steady power."
			if float(sample.get("generation_kw", 0.0)) < float(sample.get("load_kw", 0.0)): return "The base used more power than it made, even in daylight. Add solar panels or a reactor, or switch off equipment you don't need."
			return "Too much switched on at once. Add batteries to cover the peaks, or more power generation."
		"min_temp":
			if not why.contains("no thermal control unit") and not bool(sample.get("all_powered", true)): return "The heating lost power, so fix the power first and the rooms will stay warm."
			return "Add heating (a thermal control unit, or a heater anywhere inside) and keep it powered. Fewer windows and a compact layout with less outside wall lose less heat."
		"breathable":
			if float(sample.get("co2_pct", 0.0)) > MHResources.setting("co2_danger_pct", 1.0): return "The crew breathe out carbon dioxide. Add an air recycler to scrub it, and keep it powered."
			return "Add an oxygen generator (it needs power and water) or more plants, and keep them powered."
		"crew_safe":
			if float(sample.get("o2_pct", 21.0)) < MHResources.setting("o2_min_pct", 19.5) or float(sample.get("co2_pct", 0.0)) > MHResources.setting("co2_danger_pct", 1.0):
				return _tip("breathable", sample, hour_of_day, storm, depth, why)
			if float(sample.get("water_l", 1.0)) <= 0.0: return "Make more water: ice drills outside, and a water reclaimer to recycle what the crew use."
			if float(sample.get("food_kg", 1.0)) <= 0.0: return "Grow more food in Hydroponics, or bring more food in your cargo."
			if float(sample.get("coldest_c", 20.0)) < MHResources.setting("cold_c", 12.0): return _tip("min_temp", sample, hour_of_day, storm, depth, why)
			return ""
		"dose_max":
			return "Shelter the crew: a small room with a Storm Shelter Locker and lots of shielding (regolith blocks, water walls). Check its shield points."
		"fitness_min":
			return "Bones and muscles weaken in Mars gravity. Each powered exercise station keeps about 3 crew fit."
		"wellbeing_min":
			return "Open the crew roster in Mission Control: it lists what the crew are missing (sleep, space, meals together, a bit of home, work, contact with Earth)."
		"pressure_min":
			return "Put hatches (interior doors) at corridor ends so a breach only vents one small section. Open-plan bases lose their air."
		"systems_up":
			return "Build two of every life-critical machine (redundancy), and keep spare parts so the Engineer can repair them."
		"crew_health_min":
			if depth == 0: return "Health falls when air, warmth, food or water go wrong, and when the crew lack beds, exercise or privacy. " + _tip("crew_safe", sample, hour_of_day, storm, 1, why)
			return ""
	return ""

## Why rooms are getting cold, in plain words.
static func _heating_reason(sim: RefCounted) -> String:
	var inv: Dictionary = sim.inventory()
	var heaters: Array = (inv.items as Array).filter(func(i): return ["wall_cabin_heater", "portable_utility_heater"].has(str(i.id)))
	if float(inv.capacity.tcu_kw) <= 0.0 and heaters.is_empty(): return "There is no thermal control unit or heater to keep the rooms warm."
	if not bool((sim.last.get("tiers", {}) as Dictionary).get(2, true)): return "The heating lost power."
	return "The heating can't keep up overnight: add heating capacity, or cut heat loss with fewer windows and less outside wall."

static func _first_warning(sim: RefCounted, topic: String) -> String:
	var keys := {"power": "Not enough power", "cold": "Cold", "air": "O", "water": "Water", "food": "Food"}
	for warning in sim.warnings():
		if topic == "power" and str(warning.text).begins_with("Not enough power"): return str(warning.text)
		if topic == "cold" and str(warning.text).to_lower().contains("cold"): return str(warning.text)
		if topic == "air" and (str(warning.text).begins_with("CO₂") or str(warning.text).begins_with("Oxygen")): return str(warning.text)
		if topic in ["water", "food"] and str(warning.text).to_lower().contains(topic): return str(warning.text)
	var all: Array = sim.warnings()
	return str(all[0].text) if not all.is_empty() else ""

static func _when(elapsed: float, start_hour: float) -> String:
	var total := start_hour + elapsed
	var sol := int(floor(total / 24.0)) + 1
	var at := fmod(total, 24.0)
	return "on sol %d at %02d:%02d" % [sol, int(at), int(fmod(at, 1.0) * 60.0)]

## What was built, for versions and comparisons.
static func design_summary(builder: Node) -> Dictionary:
	var counts := {"solar": 0, "reactor": 0, "ice_extractor": 0, "cells": 0, "battery_bank": 0}
	for zone in builder.zones:
		var kind := str(zone.kind)
		if counts.has(kind): counts[kind] += 1
		elif builder._is_habitat_zone(zone): counts.cells += maxi(1, (zone.get("cells", []) as Array).size())
	for item in builder.placed_interior:
		var id := str(item.get("id", ""))
		counts[id] = int(counts.get(id, 0)) + 1
	counts["cargo_kg"] = builder.used_cargo()
	return counts

const SUMMARY_NAMES := {"solar": ["solar array", "solar arrays"], "reactor": ["reactor", "reactors"], "ice_extractor": ["ice drill", "ice drills"],
	"battery_bank": ["battery bank", "battery banks"], "cells": ["room cell", "room cells"]}

## "+2 solar arrays, -1 reactor" between two versions' designs.
static func design_changes(before: Dictionary, after: Dictionary) -> String:
	var parts: Array = []
	for key in SUMMARY_NAMES:
		var change := int(after.get(key, 0)) - int(before.get(key, 0))
		if change != 0: parts.append("%+d %s" % [change, SUMMARY_NAMES[key][0 if absi(change) == 1 else 1]])
	return ", ".join(parts) if not parts.is_empty() else "No change to power, drills or rooms"

## Something that happened in the base, counted for steps and goals
## ("gar_y_surveys", "core_sample").
static func bump(key: String) -> void:
	if not active(): return
	ensure()
	if not progress.has("counters"): progress["counters"] = {}
	progress.counters[key] = int((progress.counters as Dictionary).get(key, 0)) + 1

static func counter(key: String) -> int:
	ensure()
	return int((progress.get("counters", {}) as Dictionary).get(key, 0))

## The player's optional prediction for the next Test ("What do you think will happen?").
static var pending_prediction := ""

## The player's optional note on a version ("What will you change, and why?").
static func set_version_note(mission_id: String, version: int, note: String) -> void:
	for entry in versions(mission_id):
		if int(entry.version) == version: entry["note"] = note.strip_edges()

static func player_name() -> String:
	ensure()
	# Older campaigns saved it as "student_name".
	return str(progress.get("player_name", progress.get("student_name", "")))

static func set_player_name(value: String) -> void:
	ensure()
	progress["player_name"] = value.strip_edges().substr(0, 40)

## Every difference between two designs, in words: "+2 solar arrays, +1 air recycler".
static func design_changes_full(before: Dictionary, after: Dictionary) -> String:
	var parts: Array = []
	var keys: Array = before.keys()
	for key in after.keys():
		if not keys.has(key): keys.append(key)
	for key in keys:
		if str(key) == "cargo_kg": continue
		var change := int(after.get(key, 0)) - int(before.get(key, 0))
		if change == 0: continue
		var name: String
		if SUMMARY_NAMES.has(key): name = str(SUMMARY_NAMES[key][0 if absi(change) == 1 else 1])
		else:
			name = str(EquipmentCatalog.get_entry(str(key)).get("label", str(key).capitalize())).to_lower()
			if absi(change) != 1 and not name.ends_with("s"): name += "s"
		parts.append("%+d %s" % [change, name])
	return ", ".join(parts) if not parts.is_empty() else "no change to the design"

## What fixed each check: for a check that failed and later passed, the first
## passing version and the design changes since the last failing one.
## [{id, text, failed_in, fixed_in, changes}]
static func fixes(mission_id: String) -> Array:
	var out: Array = []
	var list := versions(mission_id)
	var last_fail := {}
	for entry in list:
		for check_id in (entry.results as Dictionary):
			var ok := bool(entry.results[check_id])
			if not ok:
				last_fail[check_id] = entry
			elif last_fail.has(check_id):
				var failed: Dictionary = last_fail[check_id]
				var text := str(check_id)
				for check in entry.get("checks", []):
					if str(check.id) == str(check_id): text = str(check.text)
				out.append({"id": str(check_id), "text": text, "failed_in": int(failed.version), "fixed_in": int(entry.version), "changes": design_changes_full(failed.design, entry.design)})
				last_fail.erase(check_id)
	return out

static func versions(mission_id: String) -> Array:
	ensure()
	return (progress.versions as Dictionary).get(mission_id, [])

## The mission dossier (backlog 27): each Test is kept as a version with what
## the player needs to tell its story later: the design, every check with its
## reason and tip, stretch goals, the alerts, the graphs (downsampled), the
## optional prediction and note, and pictures (scripts/mh_dossier.gd).
const DOSSIER_SAMPLE_KEYS := ["elapsed", "battery_pct", "generation_kw", "load_kw", "o2_pct", "co2_pct", "food_kg", "coldest_c", "crew_health", "fitness", "wellbeing", "pressure_pct", "dose_msv"]
const DOSSIER_POINTS := 240

static func _record_version(report: Dictionary) -> void:
	ensure()
	var list: Array = (progress.versions as Dictionary).get(report.mission, [])
	var results := {}
	for result in report.results: results[result.id] = result.pass
	var checks: Array = []
	for result in report.results: checks.append({"id": str(result.id), "text": str(result.text), "pass": bool(result.pass), "detail": str(result.detail), "tip": str(result.get("tip", ""))})
	var samples: Array = report.get("samples", [])
	var every := maxi(1, ceili(float(samples.size()) / DOSSIER_POINTS))
	var graph: Array = []
	for i in range(0, samples.size(), every):
		var point := {}
		for key in DOSSIER_SAMPLE_KEYS: point[key] = snappedf(float((samples[i] as Dictionary).get(key, 0.0)), .01)
		graph.append(point)
	list.append({"version": list.size() + 1, "time": Time.get_datetime_string_from_system(false, true), "design": report.design, "results": results, "passed": report.passed,
		"checks": checks, "stretch": report.get("stretch", []), "alerts": report.get("alerts", []), "samples": graph, "storms": report.get("storms", []),
		"sols": report.get("sols", 0), "start_hour": report.get("start_hour", 8.0), "prediction": str(pending_prediction), "note": ""})
	pending_prediction = ""
	(progress.versions as Dictionary)[report.mission] = list
	report["version"] = list.size()
	report["changes"] = design_changes(list[-2].design, report.design) if list.size() > 1 else "First test"
