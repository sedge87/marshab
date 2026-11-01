class_name MHChapterOne
extends RefCounted

## The start and chapter one (core-loop step 4, docs/start-and-chapter-one.md):
## the precursor crates instead of a tonnes budget, plans and the fabricator,
## stores shown as sols left with a soft net, and the four self-sufficiency
## steps (ice, water, oxygen, food) that end chapter one.
##
## Survival and Freedom only. Creative and Missions are unchanged, and a save
## from before step 4 loads "as already supplied" (older_rules).
##
## How the cargo maths stays one system: non-printable equipment (and the
## non-printable site parts, ZONE_STOCK) costs no Earth cargo under these
## rules; it's limited by stock instead (unpacked or made, less what's
## placed, so removing something puts it back). The Earth budget is only the
## hull kit from the shells crate, which printable shells, windows and
## partitions use after any printed material.

const MHResources := preload("res://scripts/mh_resources.gd")
const MANIFEST_PATH := "res://data/precursor_manifest.json"
const PLANS_PATH := "res://data/plans.json"
## Site parts that need stock, by zone kind.
const ZONE_STOCK := {"airlock": "airlock", "solar": "solar_array", "reactor": "surface_reactor", "ice_extractor": "ice_drill", "regolith_intake": "regolith_intake", "atmosphere_processor": "atmosphere_processor"}
const ZONE_STOCK_LABELS := {"airlock": "Airlock", "solar_array": "Solar Array", "surface_reactor": "Compact Reactor", "ice_drill": "Ice Extractor", "regolith_intake": "Regolith Intake", "atmosphere_processor": "Atmosphere Processor"}
const STEPS := ["ice", "water", "oxygen", "food"]
const STEP_LABELS := {"ice": "Ice found", "water": "Water self-sufficient", "oxygen": "Oxygen self-sufficient", "food": "Food self-sufficient"}
## Feedstock a working recycler returns a sol (kg), while anyone lives aboard.
const RECYCLE_KG := {"waste_sorting_unit": 3.0, "recycling_hopper_plastics": 1.5, "recycling_hopper_metals": 1.5}
## A core this rich is a find (the same line GAR-Y flags at).
const GOOD_CORE := .25
## Under this a core comes up dry (the extractor's own limit).
const DRY_CORE := .12
## Hours of clean extractor water before it counts as tested.
const WATER_TEST_HOURS := 12.0
## The food step, by hand: a regolith sample bagged with the corer, washed
## at the Workshop Bench (this much water), then a test seed planted there;
## a seedling after this many hours is the discovery.
const WASH_WATER_L := 20.0
const SOIL_TEST_HOURS := 24.0
const RESERVE_SOLS := 10.0
const EMERGENCY_SOLS := 30.0
const EMERGENCY_HOURS := 72.0

## Off until the menu starts a new game (reset()) or a step-4 save loads, so
## a world started any other way (tests, the menu backdrop) keeps the old rules.
static var older_rules := true
static var unpacked: Dictionary = {}     # crate id -> true
static var stock: Dictionary = {}        # id -> count landed or made (placed ones included)
static var shell_kg := 0
static var feedstock_kg := 0.0
static var earth_parts := 0
static var known: Dictionary = {}        # plan id -> how it came ("sent", "discovered")
static var job: Dictionary = {}          # {id, hours_left, hours}
static var has_corer := false
static var cores: Array = []             # [{x, z, depth_m, purity}]
static var steps: Dictionary = {}        # step -> sim hours it was met
static var finished_at := -1.0
static var stores_landed := false
static var reserve_used := false
static var emergency_eta := -1.0         # sim hours an emergency lander lands, -1: none due
static var said: Dictionary = {}
static var water_hours := 0.0
static var soil := ""                   # the food step: "", "bagged", "washed", "potted"
static var soil_potted_at := -1.0
static var lander_spots: Array = []     # the two cargo landers: [{position, yaw}]
static var _manifest: Dictionary = {}
static var _plans: Dictionary = {}

# ---------- rules ----------

static func on() -> bool:
	return not older_rules and MHGame.game_mode in ["survival", "freedom"] and not MHGame.showcase

## A new game: the crates are all still packed.
static func reset() -> void:
	older_rules = false
	unpacked = {}; stock = {}; shell_kg = 0; feedstock_kg = 0.0; earth_parts = 0
	known = {}; job = {}; has_corer = false; cores = []; steps = {}; finished_at = -1.0
	stores_landed = false; reserve_used = false; emergency_eta = -1.0; said = {}
	water_hours = 0.0; soil = ""; soil_potted_at = -1.0; lander_spots = []
	MHSamples.reset()   # step 5's samples and journal start with the chapter
	MHJournal.reset()

static func export_state() -> Dictionary:
	return {"older_rules": older_rules, "unpacked": unpacked.duplicate(), "stock": stock.duplicate(), "shell_kg": shell_kg,
		"feedstock_kg": feedstock_kg, "earth_parts": earth_parts, "known": known.duplicate(), "job": job.duplicate(),
		"has_corer": has_corer, "cores": cores.duplicate(true), "steps": steps.duplicate(), "finished_at": finished_at,
		"stores_landed": stores_landed, "reserve_used": reserve_used, "emergency_eta": emergency_eta, "said": said.duplicate(),
		"water_hours": water_hours, "soil": soil, "soil_potted_at": soil_potted_at, "lander_spots": lander_spots.duplicate(true)}

## A loaded save. One from before step 4 has no "chapter_one" and plays as
## already supplied: every plan known, no crates, the old cargo budget.
static func load_state(state: Dictionary, has_section: bool) -> void:
	reset()
	if not has_section:
		older_rules = true
		return
	older_rules = bool(state.get("older_rules", false))
	unpacked = (state.get("unpacked", {}) as Dictionary).duplicate()
	for key in (state.get("stock", {}) as Dictionary): stock[str(key)] = int(state.stock[key])
	shell_kg = int(state.get("shell_kg", 0))
	feedstock_kg = float(state.get("feedstock_kg", 0.0))
	earth_parts = int(state.get("earth_parts", 0))
	known = (state.get("known", {}) as Dictionary).duplicate()
	job = (state.get("job", {}) as Dictionary).duplicate()
	has_corer = bool(state.get("has_corer", false))
	cores = (state.get("cores", []) as Array).duplicate(true)
	steps = (state.get("steps", {}) as Dictionary).duplicate()
	finished_at = float(state.get("finished_at", -1.0))
	stores_landed = bool(state.get("stores_landed", false))
	reserve_used = bool(state.get("reserve_used", false))
	emergency_eta = float(state.get("emergency_eta", -1.0))
	said = (state.get("said", {}) as Dictionary).duplicate()
	water_hours = float(state.get("water_hours", 0.0))
	soil = str(state.get("soil", ""))
	soil_potted_at = float(state.get("soil_potted_at", -1.0))
	lander_spots = (state.get("lander_spots", []) as Array).duplicate(true)

# ---------- the crates ----------

static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary: _manifest = parsed
	return _manifest

static func crates() -> Array:
	return manifest().get("crates", [])

static func crate(id: String) -> Dictionary:
	for entry in crates():
		if str(entry.id) == id: return entry
	return {}

## The E-inspect card: a short manifest (the crates carry no lettering).
static func manifest_lines(crate_id: String) -> Array:
	var lines: Array = []
	var contents: Dictionary = crate(crate_id).get("contents", {})
	for key in contents:
		match str(key):
			"_shell_kg": lines.append("Hull kit · %s" % MHStyle.kg(int(contents[key])))
			"_feedstock_kg": lines.append("Feedstock · %s" % MHStyle.kg(int(contents[key])))
			"_earth_parts": lines.append("Earth parts · %d" % int(contents[key]))
			"_hand_corer": lines.append("Sampling kit (corer, scoop, sample case)")
			_: lines.append("%s%s" % [label(str(key)), " ×%d" % int(contents[key]) if int(contents[key]) > 1 else ""])
	return lines

static func unpack(crate_id: String) -> bool:
	if unpacked.has(crate_id) or crate(crate_id).is_empty(): return false
	unpacked[crate_id] = true
	var contents: Dictionary = crate(crate_id).get("contents", {})
	for key in contents:
		match str(key):
			"_shell_kg": shell_kg += int(contents[key])
			"_feedstock_kg": feedstock_kg += float(contents[key])
			"_earth_parts": earth_parts += int(contents[key])
			"_hand_corer": has_corer = true
			_: stock[str(key)] = int(stock.get(str(key), 0)) + int(contents[key])
	return true

static func crates_left() -> int:
	return crates().filter(func(c): return not unpacked.has(str(c.id))).size()

# ---------- stock ----------

static func label(id: String) -> String:
	if ZONE_STOCK_LABELS.has(id): return str(ZONE_STOCK_LABELS[id])
	return str(EquipmentCatalog.get_entry(id).get("label", id.capitalize()))

## Whether placing this needs stock under these rules (printable things and
## the free groups don't).
static func needs_stock(id: String) -> bool:
	if not on(): return false
	if ZONE_STOCK_LABELS.has(id): return true
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty() or bool(entry.get("printable", false)): return false
	return not (plans_data().get("free_groups", []) as Array).has(str(entry.get("group", "")))

static func placed_count(id: String, builder: Object) -> int:
	if builder == null: return 0
	var count := 0
	var kind := ""
	for zone_kind in ZONE_STOCK:
		if ZONE_STOCK[zone_kind] == id: kind = zone_kind
	if not kind.is_empty():
		for zone in builder.get("zones"):
			if str(zone.get("kind", "")) == kind: count += 1
		return count
	for list_name in ["placed_interior", "placed_equipment"]:
		for item in builder.get(list_name):
			if str(item.get("id", "")) == id: count += 1
	return count

static func available(id: String, builder: Object) -> int:
	return maxi(0, int(stock.get(id, 0)) - placed_count(id, builder))

## Everything ready to place, for the Unpacked tab: {id: count}.
static func ready_to_place(builder: Object) -> Dictionary:
	var out := {}
	for id in stock:
		var left := available(str(id), builder)
		if left > 0: out[str(id)] = left
	return out

## Empty when this can be placed; otherwise what to do about it.
static func item_reason(id: String, builder: Object) -> String:
	if not needs_stock(id) or available(id, builder) > 0: return ""
	if not plan_known(id): return plan_hint(id)
	if int(stock.get(id, 0)) > 0: return "All placed: make another at the fabricator"
	return "Make it at the fabricator first"

static func zone_reason(kind: String, builder: Object) -> String:
	if not on() or not ZONE_STOCK.has(kind): return ""
	return item_reason(str(ZONE_STOCK[kind]), builder)

## Build-bar card line: "×2 unpacked", "Plan: find ice", "Fabricator".
static func card_line(id: String, builder: Object) -> String:
	if not needs_stock(id): return ""
	var left := available(id, builder)
	if left > 0: return "×%d ready" % left
	if not plan_known(id): return "NO PLAN"
	return "FABRICATE"

# ---------- plans ----------

static func plans_data() -> Dictionary:
	if _plans.is_empty() and FileAccess.file_exists(PLANS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PLANS_PATH))
		if parsed is Dictionary: _plans = parsed
	return _plans

static func plan(id: String) -> Dictionary:
	return (plans_data().get("plans", {}) as Dictionary).get(id, {})

static func plan_source(id: String) -> String:
	return str(plan(id).get("source", "brought"))

static func plan_known(id: String) -> bool:
	if MHGame.game_mode == "freedom" or plan_source(id) == "brought": return true
	return known.has(id)

## How to get a plan you don't have.
static func plan_hint(id: String) -> String:
	var after := str(plan(id).get("after", ""))
	if plan_source(id) == "discovered":
		return {"ice": "Plan: find ice (GAR-Y's survey, then a core)", "water": "Plan: test the ice extractor's water",
			"oxygen": "Plan: make enough water to split", "food": "Plan: wash regolith of perchlorate"}.get(after, "Plan: a discovery")
	match after:
		"first_walk": return "Plan: Mission Control sends it after your first walk outside"
		"first_job": return "Plan: Mission Control sends it after your first fabricator job"
	if after.begins_with("sol_"): return "Plan: Mission Control sends it on sol %s" % after.trim_prefix("sol_")
	return "Plan: Mission Control will send it"

## Plans that arrive when something happens; returns the ids that just came.
static func learn_after(event: String) -> Array:
	var learned: Array = []
	var all: Dictionary = plans_data().get("plans", {})
	for id in all:
		if str(all[id].get("after", "")) == event and not known.has(id):
			known[id] = str(all[id].get("source", "sent"))
			learned.append(str(id))
	return learned

## {feedstock_kg, earth_parts, hours} for one job.
static func plan_cost(id: String) -> Dictionary:
	var p := plan(id)
	var d: Dictionary = plans_data().get("defaults", {})
	var mass := float(p.get("cargo_kg", EquipmentCatalog.get_entry(id).get("cargo_cost", 50)))
	return {"feedstock_kg": float(p.get("feedstock_kg", roundf(mass * float(d.get("feedstock_per_kg", .6))))),
		"earth_parts": int(p.get("earth_parts", ceili(mass / float(d.get("kg_per_part", 50))))),
		"hours": float(p.get("hours", clampf(roundf(mass / float(d.get("kg_per_hour", 25))), float(d.get("min_hours", 1)), float(d.get("max_hours", 20)))))}

## Everything the fabricator could make now (known plans), in catalogue order.
static func fabricable() -> Array:
	var out: Array = []
	for id in ZONE_STOCK_LABELS:
		if plan_known(id): out.append(id)
	for id in EquipmentCatalog.entries():
		var entry: Dictionary = EquipmentCatalog.get_entry(str(id))
		if bool(entry.get("retired", false)) or not needs_stock(str(id)) or not plan_known(str(id)): continue
		out.append(str(id))
	return out

# ---------- the fabricator ----------

static func fabricators(builder: Object) -> Array:
	if builder == null: return []
	return (builder.get("placed_interior") as Array).filter(func(i): return str(i.get("id", "")) == "fabricator")

## Work speed: the Workshop at full rate, the General Module at 75 % (as other work there).
static func fabricator_speed(builder: Object) -> float:
	var best := 0.0
	for item in fabricators(builder):
		var zone: Dictionary = builder.call("_zone_at_point", Vector2((item.position as Vector3).x, (item.position as Vector3).z)) if item.has("position") else {}
		best = maxf(best, .75 if str(zone.get("kind", "")) == "general" else 1.0)
	return best

static func job_reason(id: String, builder: Object) -> String:
	if fabricators(builder).is_empty(): return "Place the fabricator first"
	if not job.is_empty(): return "The fabricator is busy"
	if not plan_known(id): return plan_hint(id)
	var cost := plan_cost(id)
	if feedstock_kg < float(cost.feedstock_kg): return "Not enough feedstock"
	if earth_parts < int(cost.earth_parts): return "Not enough Earth parts"
	return ""

static func start_job(id: String, builder: Object) -> String:
	var reason := job_reason(id, builder)
	if not reason.is_empty(): return reason
	var cost := plan_cost(id)
	feedstock_kg -= float(cost.feedstock_kg)
	earth_parts -= int(cost.earth_parts)
	job = {"id": id, "hours_left": float(cost.hours), "hours": float(cost.hours)}
	return ""

static func cancel_job() -> void:
	if job.is_empty(): return
	var cost := plan_cost(str(job.id))
	feedstock_kg += float(cost.feedstock_kg)
	earth_parts += int(cost.earth_parts)
	job = {}

# ---------- ice ----------

## What a core at this point shows. Depth and purity both follow the deposit:
## near its middle the ice is shallow and clean, towards its edge deeper and dirtier.
static func core_at(point: Vector2, richness: float) -> Dictionary:
	var dry := richness < DRY_CORE
	return {"x": point.x, "z": point.y, "purity": snappedf(richness, .01), "dry": dry,
		"depth_m": 0.0 if dry else snappedf(lerpf(4.5, .6, clampf(richness / .6, 0.0, 1.0)), .1), "good": richness >= good_core()}

## Richness a core needs to count as the find: GOOD_CORE, or on a site whose
## best ice is poorer (the plains peak at .32), half its peak, so the middle
## of the zone always works.
static func good_core() -> float:
	var peak := 0.0
	for deposit in MHGame.site().get("ice_deposits", []): peak = maxf(peak, float(deposit.get("richness", 0.0)))
	return maxf(DRY_CORE + .01, minf(GOOD_CORE, peak * .5))

static func record_core(core: Dictionary) -> void:
	cores.append(core)
	while cores.size() > 40: cores.pop_front()

# ---------- stores ----------

## Sols the landed stores last (Survival 90, Freedom 150) and for how many crew.
static func store_sols() -> float:
	return MHResources.setting("chapter_store_sols_freedom", 150.0) if MHGame.game_mode == "freedom" else MHResources.setting("chapter_store_sols", 90.0)

static func store_crew() -> float:
	return MHResources.setting("chapter_store_crew", 2.0)

## Landed water and oxygen, as {water_l, o2_kg, food_kg} for `sols` sols.
static func stores_for(sols: float, crew := -1.0) -> Dictionary:
	var people := store_crew() if crew < 0.0 else crew
	return {"water_l": people * MHResources.setting("water_per_person", 10.0) * sols,
		"o2_kg": people * MHResources.setting("o2_per_person", .84) * sols,
		"food_kg": people * MHResources.setting("food_per_person", 1.8) * sols}

## Sols left of water, oxygen and food at today's use, or -1 when not running down.
## Before anyone lives in the habitat nothing is used yet: the full store life.
static func sols_left(sim: Object) -> Dictionary:
	var last: Dictionary = sim.get("last")
	var crew := float(last.get("crew", 0))
	var out := {"water": -1.0, "oxygen": -1.0, "food": -1.0}
	if crew <= 0.0:
		if on(): out = {"water": store_sols(), "oxygen": store_sols(), "food": store_sols()}
		return out
	var water_net := float(last.get("water_out", 0.0)) - float(last.get("water_in", 0.0))
	if water_net > .01: out.water = float(sim.get("water_l")) / water_net
	var o2_net := crew * MHResources.setting("o2_per_person", .84) - float(last.get("o2_in", 0.0))
	if o2_net > .01: out.oxygen = float(sim.get("o2_reserve_kg")) / o2_net
	var food_net := crew * MHResources.setting("food_per_person", 1.8) - float(last.get("food_in", 0.0))
	if food_net > .01: out.food = float(sim.get("food_kg")) / food_net
	return out

static func sols_text(sols: float) -> String:
	if sols < 0.0: return "steady"
	if sols < 1.0: return "under a sol"
	return "%d sol%s" % [floori(sols), "" if floori(sols) == 1 else "s"]

# ---------- each tick ----------

## Called by the world a few times a second of play with the sim hours
## passed. Returns messages to show: [{id, title, text, tone}].
static func tick(hours: float, builder: Object) -> Array:
	var out: Array = []
	if not on() or builder == null or hours <= 0.0: return out
	var sim: Object = builder.call("simulation")
	var last: Dictionary = sim.get("last")
	var crew := int(last.get("crew", 0))
	var now := float(sim.get("hours_run"))
	var powered := float(last.get("generation_kw", 0.0)) > 0.0 or float(sim.get("battery_kwh")) > .5
	# The fabricator's job.
	if not job.is_empty() and powered:
		var speed := fabricator_speed(builder)
		if speed > 0.0:
			job.hours_left = float(job.hours_left) - hours * speed
			if float(job.hours_left) <= 0.0:
				var id := str(job.id)
				stock[id] = int(stock.get(id, 0)) + 1
				job = {}
				out.append({"id": "made", "title": "Fabricator: %s ready" % label(id), "text": "It's on the build bar's Unpacked tab.", "tone": "valid"})
				for learned in learn_after("first_job"): out.append(_plan_message(learned))
	# Recycling tops the feedstock up.
	if crew > 0:
		for item in builder.get("placed_interior"):
			feedstock_kg += float(RECYCLE_KG.get(str(item.get("id", "")), 0.0)) * hours / 24.0
	# Plans Mission Control sends on a given sol.
	var sol := floori(now / 24.0) + 1
	for event in ["sol_10", "sol_30"]:
		if sol >= int(event.trim_prefix("sol_")):
			for learned in learn_after(event): out.append(_plan_message(learned))
	out.append_array(_check_steps(builder, sim, last, hours, now))
	out.append_array(_check_stores(sim, crew, now))
	return out

static func _plan_message(id: String) -> Dictionary:
	return {"id": "plan", "title": "New plan: %s" % label(id), "text": "Mission Control sent the plan. Make it at the fabricator.", "tone": "info"}

static func _count(builder: Object, kind: String) -> int:
	return (builder.get("zones") as Array).filter(func(z): return str(z.get("kind", "")) == kind).size()

static func _check_steps(builder: Object, sim: Object, last: Dictionary, hours: float, now: float) -> Array:
	var out: Array = []
	var crew := float(last.get("crew", 0))
	# 2. Water: the extractor's meltwater is tested once it has run a while.
	if steps.has("ice") and not known.has("water_reclaimer") and _count(builder, "ice_extractor") > 0 and float(last.get("raw_in", 0.0)) > 0.0:
		water_hours += hours
		if water_hours >= WATER_TEST_HOURS:
			learn_after("water")
			out.append({"id": "water_clean", "title": "The meltwater is tested", "text": "Dust and a little perchlorate: nothing a filter can't take out. Plan: Water Processor, to clean the meltwater and send used water round again.", "tone": "valid"})
	var water_steady := crew > 0.0 and float(last.get("water_in", 0.0)) >= float(last.get("water_out", 0.0)) - .01
	if known.has("water_reclaimer") and not steps.has("water") and water_steady and placed_count("water_reclaimer", builder) > 0:
		steps["water"] = now
		out.append({"id": "step", "title": "Water self-sufficient", "text": "The extractor and water processor cover the crew's water. Next: split some into oxygen.", "tone": "valid"})
	# 3. Oxygen: enough water to split.
	if steps.has("water") and not known.has("oxygen_generator"):
		learn_after("oxygen")
		out.append({"id": "plan", "title": "Plan: Oxygen Generator", "text": "There's water to spare now. Electrolysis splits it into oxygen (and hydrogen, vented).", "tone": "info"})
	var o2_need := crew * MHResources.setting("o2_per_person", .84)
	if known.has("oxygen_generator") and not steps.has("oxygen") and crew > 0.0 and float(last.get("o2_in", 0.0)) >= o2_need - .01:
		steps["oxygen"] = now
		out.append({"id": "step", "title": "Oxygen self-sufficient", "text": "The generator covers the crew's breathing. Last: food. Take a core on surveyed ground to bag some regolith, then wash it at the Workshop Bench.", "tone": "valid"})
	# 4. Food: the test seed in washed regolith comes up (see bench_use()).
	if soil == "potted" and not known.has("grow_tray") and now - soil_potted_at >= SOIL_TEST_HOURS:
		learn_after("food")
		out.append({"id": "plan", "title": "The test seed came up", "text": "Washed of its perchlorate, Mars soil grows plants. Plans: grow trays, planters, a seedling station and a nutrient mixer.", "tone": "valid"})
	if known.has("grow_tray") and not steps.has("food") and crew > 0.0 and float(last.get("food_in", 0.0)) >= crew * MHResources.setting("food_per_person", 1.8) - .01:
		steps["food"] = now
		out.append({"id": "step", "title": "Food self-sufficient", "text": "The crew eat what they grow.", "tone": "valid"})
	if finished_at < 0.0 and STEPS.all(func(s): return steps.has(s)):
		finished_at = now
		out.append({"id": "chapter_one", "title": "Self-sufficient", "text": report(), "tone": "valid"})
	return out

## Mission Control's chapter-one report.
static func report() -> String:
	var lines: Array = ["Mission Control: the base makes its own water, oxygen and food."]
	for s in STEPS:
		if steps.has(s): lines.append("%s · sol %d" % [STEP_LABELS[s], floori(float(steps[s]) / 24.0) + 1])
	if finished_at >= 0.0: lines.append("Chapter one took %d sols." % (floori(finished_at / 24.0) + 1))
	return "\n".join(lines)

# ---------- the food step, by hand ----------

static func soil_due() -> bool:
	return on() and steps.has("oxygen") and not known.has("grow_tray")

## A core taken while the food step is due bags its top layer of regolith.
static func bag_soil() -> Array:
	if not soil_due() or not soil.is_empty(): return []
	soil = "bagged"
	return [{"id": "soil", "title": "Regolith sample bagged", "text": "Take it to the Workshop Bench and wash the perchlorate out (E there).", "tone": "info"}]

## What E does at the Workshop Bench for the food step, or "".
static func bench_action() -> String:
	if not on(): return ""
	match soil:
		"bagged": return "Wash the regolith sample"
		"washed": return "Plant a test seed"
	return ""

static func bench_use(sim: Object, now: float) -> Array:
	match soil:
		"bagged":
			if float(sim.get("water_l")) < WASH_WATER_L:
				return [{"id": "soil", "title": "Not enough water to wash it", "text": "Washing needs about %d L." % roundi(WASH_WATER_L), "tone": "warn"}]
			sim.set("water_l", float(sim.get("water_l")) - WASH_WATER_L)
			soil = "washed"
			return [{"id": "soil", "title": "Sample washed", "text": "%d L of water rinsed the perchlorate out. Now plant a test seed in it (E again)." % roundi(WASH_WATER_L), "tone": "valid"}]
		"washed":
			soil = "potted"
			soil_potted_at = now
			return [{"id": "soil", "title": "Test seed planted", "text": "Give it a sol. If it comes up, the soil can grow food.", "tone": "info"}]
	return []

## The crew rover comes with a later lander (question 2): once ice is found,
## so the first trip to the ice is on foot.
static func rover_landed() -> bool:
	return not on() or steps.has("ice")

## The ice step, from a good core (the player's hand corer).
static func ice_found(now: float) -> Array:
	if steps.has("ice"): return []
	steps["ice"] = now
	learn_after("ice")
	return [{"id": "step", "title": "Water ice confirmed", "text": "A good core. Plan: Ice Extractor. Make it at the fabricator and place it where the core was richest.", "tone": "valid"},
		{"id": "rover", "title": "The crew rover is on its way", "text": "Mission Control: it lands with the next cargo and waits in your vehicle bay once you build one.", "tone": "info"}]

## The soft net (question 3): no game over from the stores alone.
static func _check_stores(sim: Object, crew: int, now: float) -> Array:
	var out: Array = []
	if crew <= 0: return out
	if emergency_eta >= 0.0 and now >= emergency_eta:
		emergency_eta = -1.0
		_add_stores(sim, EMERGENCY_SOLS, crew)
		out.append({"id": "emergency_landed", "title": "Emergency lander down", "text": "%d sols of water, oxygen and food are in the stores." % roundi(EMERGENCY_SOLS), "tone": "valid"})
	var left := sols_left(sim)
	for key in ["water", "oxygen", "food"]:
		var s := float(left[key])
		for mark in [["half", store_sols() * .5], ["quarter", store_sols() * .25]]:
			if s >= 0.0 and s < float(mark[1]) and not said.has("%s_%s" % [key, mark[0]]):
				said["%s_%s" % [key, mark[0]]] = true
				out.append({"id": "stores", "title": "Stores: %s for %s" % [key.capitalize(), sols_text(s)], "text": "Mission Control: no rush, but worth planning for.", "tone": "info"})
	var empty := float(sim.get("food_kg")) <= 0.0 or float(sim.get("water_l")) <= 0.0 or (float(sim.get("o2_reserve_kg")) <= 0.0 and float(sim.get("o2_pct")) < MHResources.setting("o2_min_pct", 19.5))
	if empty and emergency_eta < 0.0:
		if not reserve_used:
			reserve_used = true
			_add_stores(sim, RESERVE_SOLS, crew)
			out.append({"id": "reserve", "title": "Contingency reserve opened", "text": "The crew lander's reserve gives %d more sols. Mission Control is sending an emergency lander." % roundi(RESERVE_SOLS), "tone": "warn"})
		else:
			out.append({"id": "emergency_sent", "title": "Emergency lander on its way", "text": "Mission Control has launched more stores. They land in about 3 sols.", "tone": "warn"})
		emergency_eta = now + EMERGENCY_HOURS
	return out

static func _add_stores(sim: Object, sols: float, crew: int) -> void:
	var add := stores_for(sols, crew)
	sim.set("water_l", float(sim.get("water_l")) + float(add.water_l))
	sim.set("o2_reserve_kg", float(sim.get("o2_reserve_kg")) + float(add.o2_kg))
	sim.set("food_kg", float(sim.get("food_kg")) + float(add.food_kg))
	sim.set("extra_store_l", float(sim.get("extra_store_l")) + float(add.water_l))
	sim.set("extra_store_o2", float(sim.get("extra_store_o2")) + float(add.o2_kg))
	sim.call("invalidate")
