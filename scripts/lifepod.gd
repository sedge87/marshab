extends Node3D

## The lifepod days (step 3b of docs/systems-and-items.md §14; master-design
## §10): after night one, building waits. You live out of the lander and get
## to know the land round it.
## - Water: the lander's tank (scripts/survival_core.gd) runs low by the dawn
##   of sol 2. Chip ice with the rock hammer at the frost hollow or the ice
##   wall, carry it home and melt it in the lander's melter.
## - Threads you can't use yet (scripts/thread_site.gd): an iron outcrop and a
##   wall of buried ice, placed round your landing like the pallets. Each one
##   joins Notes; the General Module's plans answer them later (3c).
## - Salvage (scripts/salvage_piece.gd): the storm debris strips for parts.
## - The tiny printer on the lander's bench (scripts/lifepod_bench.gd) turns
##   parts into a sled hitch (GAR-Y tows ice), an ice pick head (bigger
##   chunks) and a water bladder (more water kept).
## - Samples looked at closely on the bench become Journal pages.
## - GAR-Y's sled: with the hitch, ice you chip near it goes on its sled, and
##   at the lander it's all melted at once.
## Once you've done most of these (water, print, sample, tow), the walker
## moves in the night: the hook into 3c.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const SITE := preload("res://scripts/thread_site.gd")
const FIND := preload("res://scripts/carried_find.gd")
const SALVAGE := preload("res://scripts/salvage_piece.gd")
const BENCH := preload("res://scripts/lifepod_bench.gd")
const RATION_CRATE := preload("res://scripts/ration_crate.gd")
const START_RATIONS := 2        # from the descent: a sol's food (step 4a)
const PALLET_RATIONS := 10      # pallet 1's: about five sols, two a sol
## [kind, nearest, furthest, the ground it wants]
const THREADS := [["iron", 1000.0, 1400.0, "rough"], ["ice_wall", 1000.0, 1500.0, "low"]]
const PLANS := [["hitch", "the sled hitch", "print_hitch_parts", 3.0], ["pick", "an ice pick head", "print_pick_parts", 2.0], ["bladder", "a water bladder", "print_bladder_parts", 2.0], ["seal", "a wheel seal for Walker 1", "print_seal_parts", 3.0], ["battery", "a spare suit battery", "print_battery_parts", 3.0], ["heater", "a suit heater pack", "print_heater_parts", 3.0], ["air_pack", "a bigger air pack", "print_air_pack_parts", 4.0]]
## Suit add-ons (scripts/suit.gd): printable once you hold the plan's
## cartridge (docs/pillars.md: plans are things you find).
const ADDON_PLANS := ["battery", "heater", "air_pack"]
## Plans that need their cartridge found first (15 Nov playtest: the printer
## offered all of these on day 1, with no reason to want them yet).
const FOUND_PLANS := ["pick", "bladder", "battery", "heater", "air_pack"]
const PRINT_SECONDS := 6.0
## GAR-Y's day (docs/opening-days.md): the hitch printed, the module's cargo
## staged by the lander, a survey or core by GAR-Y, a sample on the bench.
const JOBS := ["print", "tow", "scout", "sample"]
const STAGE_REACH := 30.0       # cargo this near the lander is staged for the module
const WALKER_HOUR := 3.0        # the walker moves in the small hours
const GARY_NEAR := 15.0
const SLED_REACH := 16.0        # GAR-Y this close to the lander to melt the sled's ice

var world: Node
var sites := {}                 # kind → scripts/thread_site.gd
var bench: Node3D
var parts := 0
var prints := {}                # plan id → true
var cartridges := {}            # plan cartridges found: plan id → true (saved)
var jobs := {}                  # job → true
var sled_kg := 0.0
var sled_cargo: Array = []      # the module's cargo riding GAR-Y's sled (saved where it lies)
var walker_due := false
var walker_moved := false
var studied := {}               # source → true (a Journal page each)
var stripped_keys := {}         # debris path → true
var plan := 0
var printing := ""
var _print_left := 0.0
var _check := 0.0
var _last_hour := -1.0
var _photo_nudged := false
var gary_reported := false     # sol 2's dawn: GAR-Y's night out (playtest 8 Nov)
var rations := START_RATIONS    # packs in the cabin's ration crate (scripts/ration_crate.gd)
var rations_carried := 0        # pallet 1's, in your pockets until you're back in the cabin

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "Lifepod"
	add_to_group("lifepod")
	parts = int(saved.get("parts", 0))
	for id in saved.get("prints", []): prints[str(id)] = true
	for id in saved.get("cartridges", []): cartridges[str(id)] = true
	for id in saved.get("jobs", []): jobs[str(id)] = true
	for id in saved.get("studied", []): studied[str(id)] = true
	for key in saved.get("stripped", []): stripped_keys[str(key)] = true
	sled_kg = float(saved.get("sled_kg", 0.0))
	walker_due = bool(saved.get("walker_due", false))
	walker_moved = bool(saved.get("walker_moved", false))
	_photo_nudged = bool(saved.get("photo_nudged", false))
	gary_reported = bool(saved.get("gary_reported", false))
	rations = int(saved.get("rations", START_RATIONS))
	rations_carried = int(saved.get("rations_carried", 0))
	# A save from before step 4a with pallet 1 already open: its rations are home.
	var drop: Node = world.get("storm_drop")
	if not saved.has("rations") and drop != null and drop.pallet != null and bool(drop.pallet.opened): rations += PALLET_RATIONS
	_place_sites(saved.get("sites", {}))
	_hook_salvage.call_deferred()
	bench = BENCH.new()
	bench.setup(self, world.lander)
	_hook_dispenser.call_deferred()
	_hook_ration_crate.call_deferred()
	for find in saved.get("finds", []):
		var p: Array = find.at
		_spawn_find(str(find.kind), float(find.kg), str(find.source), Vector3(float(p[0]), float(p[1]), float(p[2])))
	if prints.has("bladder"): _apply_bladder(false)

func n(key: String, fallback: float) -> float:
	return MHResources.revamp(key, fallback)

func core() -> RefCounted:
	var cabin: Node = world.get("cabin_life")
	return cabin.core if cabin != null else null

func water_l() -> float:
	return float(core().water_l) if core() != null else 0.0

func water_cap() -> float:
	return float(core().water_cap) if core() != null else 0.0

# ---------- the places ----------

func _place_sites(saved: Dictionary) -> void:
	var field: Node = world.get("drop_field")
	var ridge: Vector3 = world.storm_drop.ridge if world.get("storm_drop") != null else Vector3.INF
	var taken: Array = []
	if field != null:
		if not is_inf(ridge.x): taken.append(field._bearing(ridge))
		for kind in field.sites: taken.append(field._bearing(field.sites[kind].at))
	for spec in THREADS:
		var kind := str(spec[0])
		var state: Dictionary = saved.get(kind, {})
		var where := Vector3.INF
		var yaw := 0.0
		if state.has("at"):
			var p: Array = state.at
			where = Vector3(float(p[0]), float(p[1]), float(p[2]))
			yaw = float(state.get("yaw", 0.0))
		elif field != null:
			where = field.choose(kind, float(spec[1]), float(spec[2]), str(spec[3]), taken, ridge)
			var back: Vector3 = world.lander.global_position - where
			yaw = atan2(back.x, back.z)
		if is_inf(where.x): continue
		if field != null: taken.append(field._bearing(where))
		_add_site(kind, where, yaw, bool(state.get("seen", false)))
	# The frost hollow round pallet 3 (clear of its canopy): the nearest ice.
	if field != null and field.sites.has("tools"):
		var tools: Node = field.sites.tools
		var state: Dictionary = saved.get("frost", {})
		var where: Vector3 = tools.local_to_world(tools.PALLET_LOCAL + Vector3(-6.0, 0, 3.0))
		where.y = MHSiteTerrain.height(where.x, where.z)
		_add_site("frost", where, 0.0, bool(state.get("seen", false)))

func _add_site(kind: String, where: Vector3, yaw: float, seen: bool) -> void:
	var site: StaticBody3D = SITE.new()
	add_child(site)
	site.setup(self, kind, where, yaw, seen)
	sites[kind] = site

func region_at(p: Vector3) -> Vector2:
	var known: Node = world.get("known")
	return Vector2(p.x, p.z) + (known.origin as Vector2 if known != null else Vector2.ZERO)

## Every piece of storm debris strips for parts (not the boulders).
func _hook_salvage() -> void:
	for group in ["storm_debris", "drop_debris"]:
		for piece in get_tree().get_nodes_in_group(group):
			if not str((piece as Node).scene_file_path).contains("debris_"): continue
			if (piece as Node).get_node_or_null("Salvage") != null: continue
			var key := str(world.get_path_to(piece))
			var handle: StaticBody3D = SALVAGE.new()
			(piece as Node).add_child(handle)
			handle.setup(self, 0, stripped_keys.has(key))
			handle.set_meta("key", key)

## The cabin's water dispenser reads the tank.
func _hook_dispenser() -> void:
	for child in world.lander.get_children():
		if str(child.name).begins_with("Cabin_potable_water_dispenser"):
			child.set_meta("interaction_target", self)
			for body in child.find_children("*", "StaticBody3D", true, false): body.set_meta("interaction_target", self)

## The small supply crate by the airlock holds the rations (step 4a).
func _hook_ration_crate() -> void:
	for child in world.lander.get_children():
		if str(child.name).begins_with("Cabin_supply_crate_small"):
			var crate: Node = RATION_CRATE.new()
			crate.setup(self, child)
			return

## E at the ration crate: one pack eaten, hunger gone (scripts/body.gd).
func eat_ration() -> bool:
	if rations <= 0 or not MHGame.needs_food_water(): return false
	rations -= 1
	var body: Node = world.get("body")
	if body != null: body.eat()
	MHAudio.sfx("ration_eat", -4.0, .06)
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("first_meal")
		if rations <= 2 and rations_carried <= 0: notes.think("rations_low")
		elif notes.is_open("rations_low"): notes.let_go("rations_low")
	MHNotices.post("valid", "Ate a ration", "%d pack%s left in the crate." % [rations, "" if rations == 1 else "s"], "log")
	return true

## Takes one pack for the suit's food bar; false when the crate's empty.
func take_ration() -> bool:
	if rations <= 0: return false
	rations -= 1
	return true

## Pallet 1's rations (scripts/storm_drop.gd): in your pockets until you're home.
func pocket_rations(count: int) -> void:
	rations_carried += count

func _stow_rations() -> void:
	if rations_carried <= 0 or not bool(world.lander.cabin_contains(world.player.global_position)): return
	rations += rations_carried
	MHNotices.post("valid", "Rations stowed", "Pallet 1's %d ration packs are in the cabin crate: %d in all." % [rations_carried, rations], "log")
	MHAudio.sfx("place", -6.0)
	rations_carried = 0
	var notes: Node = world.get("notes")
	if notes != null and notes.is_open("rations_low"): notes.let_go("rations_low")

func interaction_prompt() -> Dictionary:
	var c := core()
	if c == null: return {"label": "Cabin water"}
	var sols: float = c.water_sols()
	return {"label": "Cabin water · %.1f L · %s" % [float(c.water_l), "dry" if float(c.water_l) <= 0.0 else ("about %.1f sols" % sols)]}

func interact(_actor: Node = null) -> bool:
	return false

# ---------- finding, chipping, carrying ----------

func _process(delta: float) -> void:
	if printing != "":
		_print_left -= delta
		if _print_left <= 0.0: _printed()
	_check -= delta
	if _check > 0.0 or world.get("player") == null: return
	_check = .5
	var you: Vector3 = world.player.global_position
	_stow_rations()
	_check_staging()
	for kind in sites:
		var site: Node = sites[kind]
		if not site.seen and you.distance_to(site.global_position) < SITE.SEEN_AT: see(site)
	var notes: Node = world.get("notes")
	var c := core()
	var hour := MHGame.sol_hour
	if notes != null and c != null:
		var sol := int(notes.call("_sol"))
		if not notes.is_settled("water") and not bool(c.self_sufficient):
			if float(c.water_l) <= 0.0: notes.think("water", "empty")
			elif (sol >= 2 and hour > 5.0 and hour < 12.0) or float(c.water_sols()) < 1.0:
				notes.think("water", "low", {"where": _ice_hint()})
	# The walker moves in the small hours once you've done enough.
	# (The guided chapters, version 2: Rao's pass finds its tracks by day instead, A6.)
	if _last_hour >= 0.0 and walker_due and not walker_moved and int(world.get("opening_version")) < 2 and _crossed(_last_hour, hour, WALKER_HOUR): walker_night()
	_last_hour = hour

static func _crossed(from: float, to: float, at: float) -> bool:
	if to >= from: return from < at and to >= at
	return from < at or to >= at

func _ice_hint() -> String:
	var known: Node = world.get("known")
	var field: Node = world.get("drop_field")
	if field != null and field.sites.has("tools") and known != null and known.knows(field.sites.tools.id()):
		return " There was frost in that hollow by pallet 3: ice, just under the dust."
	return " Frost forms in low ground at dawn. Ice under it, maybe."

# ---------- GAR-Y's night out (sol 2's dawn) ----------

## What GAR-Y calls a find before you've seen it.
const GARY_NAMES := {"frost": "GAR-Y · frost", "ice_wall": "GAR-Y · something big and cold", "iron": "GAR-Y · something metal"}

## Sol 2's morning, before it's told you: GAR-Y has finds to show.
func gary_report_ready() -> bool:
	if gary_reported or get_tree().get_first_node_in_group("gar_y") == null: return false
	if not world.has_method("opening_part") or int(world.opening_part()) != 2: return false
	return MHGame.sol_hour > 5.0 and MHGame.sol_hour < 18.0 and not _unseen().is_empty()

## "What did you find?": its night's scouting goes on your map and compass.
func gary_report() -> void:
	gary_reported = true
	var known: Node = world.get("known")
	for site in _unseen():
		if known != null: known.learn(site.id(), "find", region_at(site.global_position), str(GARY_NAMES.get(site.kind, "GAR-Y · a find")), "you", "gary")
	var notes: Node = world.get("notes")
	if notes != null: notes.think("gary_scouted")

func _unseen() -> Array:
	var out: Array = []
	for kind in ["frost", "ice_wall", "iron"]:
		if sites.has(kind) and not sites[kind].seen: out.append(sites[kind])
	return out

## "Show me": the nearest find GAR-Y marked that you haven't been to, or null.
func gary_mark_to_show(from: Vector3) -> Node:
	if not gary_reported: return null
	var best: Node = null
	for site in _unseen():
		if best == null or from.distance_to(site.global_position) < from.distance_to(best.global_position): best = site
	return best

## You come within sight of a thread: it joins Notes and your record.
func see(site: Node) -> void:
	site.seen = true
	var known: Node = world.get("known")
	if known != null:
		known.learn(site.id(), "find", region_at(site.global_position), str(SITE.NAMES.get(site.kind, "Find")), "you")
		known.rename(site.id(), str(SITE.NAMES.get(site.kind, "Find")))
	var notes: Node = world.get("notes")
	if notes == null: return
	if gary_reported and _unseen().is_empty() and notes.is_open("gary_scouted"): notes.answer("gary_scouted")
	match str(site.kind):
		"iron": notes.think("iron", "seen")
		"ice_wall": notes.think("ice_wall", "seen")
	if not _photo_nudged and site.kind != "frost":
		_photo_nudged = true
		notes.think("photo")

## A chunk came away (scripts/thread_site.gd): into your hands, or onto
## GAR-Y's sled if it's hitched up and close.
func chipped(site: Node) -> void:
	var kind := "rock" if str(site.kind) == "iron" else "ice"
	var kg := 2.0 if kind == "rock" else (n("ice_chunk_big_kg", 12.0) if prints.has("pick") else n("ice_chunk_kg", 8.0))
	var you: Node3D = world.player
	var gary: Node3D = world.get("scout_rover")
	if kind == "ice" and prints.has("hitch") and gary != null and is_instance_valid(gary) and gary.global_position.distance_to(you.global_position) < GARY_NEAR and sled_kg + kg <= n("sled_ice_kg", 48.0):
		sled_kg += kg
		gary.call("_say", "happy")
		MHNotices.post("info", "GAR-Y's sled", "%d kg of ice on GAR-Y's sled. At the lander, E on GAR-Y melts it." % roundi(sled_kg), "log")
		return
	var find := _spawn_find(kind, kg, str(site.kind), you.global_position)
	find.pick_up()

func _spawn_find(kind: String, kg: float, source: String, where: Vector3) -> Node:
	var find: StaticBody3D = FIND.new()
	add_child(find)
	find.setup(self, kind, kg, source)
	find.global_position = Vector3(where.x, MHSiteTerrain.height(where.x, where.z), where.z) if not world.lander.cabin_contains(where) else where
	return find

## E on the melter with ice: into the lander's tank.
func melt(find: Node) -> bool:
	var c := core()
	if c == null: return false
	var got: float = c.add_water(float(find.kg) * n("ice_melt_l_per_kg", .9))
	find.used_up()
	MHAudio.sfx("suit_fill", -6.0)
	MHNotices.post("valid", "Ice melted", "%.1f L into the lander's tank (now %.1f L)." % [got, float(c.water_l)], "log")
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("water")
	done("water")
	return true

## E on GAR-Y by the lander with ice on its sled (scripts/companion_rover.gd).
func unload_sled() -> bool:
	var c := core()
	if c == null or sled_kg <= 0.0: return false
	var got: float = c.add_water(sled_kg * n("ice_melt_l_per_kg", .9))
	sled_kg = 0.0
	MHAudio.sfx("suit_fill", -6.0)
	MHNotices.post("valid", "GAR-Y's ice melted", "%.1f L into the lander's tank (now %.1f L)." % [got, float(c.water_l)], "log")
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("water")
	done("water")
	done("tow")
	return true

func sled_ready(gary: Node3D) -> bool:
	return sled_kg > 0.0 and gary != null and gary.global_position.distance_to(world.lander.global_position) < SLED_REACH

## E on the bench with a sample: a closer look, and a Journal page.
func study(find: Node) -> bool:
	var source := str(find.source)
	var kind := str(find.kind)
	var notes: Node = world.get("notes")
	var sol := int(notes.call("_sol")) if notes != null else 1
	if not studied.has(source):
		studied[source] = true
		MHJournal.note(sol, _study_line(source))
		if notes != null:
			match source:
				"iron": notes.answer("iron")
				"ice_wall": notes.answer("ice_wall")
	bench.shelve(kind, source)
	find.used_up()
	MHAudio.sfx("place", -8.0)
	MHNotices.post("valid", "Under the lens", _study_line(source), "log")
	done("sample")
	return true

static func _study_line(source: String) -> String:
	match source:
		"iron": return "Under the lens the grey beads are haematite: iron oxide, grown in water that once soaked this ground. Iron for the taking, if I had anything to smelt it with."
		"ice_wall": return "The ice wall's chip is clear, with fine bands of dust, layer on layer: snow from another climate. There are tonnes of it out there."
		"frost": return "The hollow's ice is dusty and fine-grained: ground ice, frozen into the soil. Drinkable once it's melted and settled."
	return "Looked at it closely under the lens."

## Debris stripped (scripts/salvage_piece.gd).
func stripped(piece: Node) -> void:
	parts += int(n("salvage_per_piece", 2.0))
	MHMaterials.add_salvage(MHMaterials.SALVAGE_PER_DEBRIS)   # A5: and salvage for the Print Shop
	stripped_keys[str(piece.get_meta("key", ""))] = true
	MHNotices.post("info", "Parts", "%d parts for the lander's printer." % parts, "log")
	var notes: Node = world.get("notes")
	if notes != null and _salvage_told(): notes.think("salvage")

## Version 2: the thought about the printer waits for Castellanos to raise
## it (day 2, the spares crate: data/radio/day2.txt d2_found).
func _salvage_told() -> bool:
	if int(world.get("opening_version")) < 2: return true
	var radio: Node = world.get("radio")
	return radio == null or (radio.heard as Dictionary).has("d2_found") or radio.flag("scrap_told")

# ---------- the tiny printer ----------

## A plan cartridge found (a pallet, a wreck): its plan comes up on the printer.
func learn_cartridge(id: String) -> void:
	if cartridges.has(id): return
	cartridges[id] = true
	MHNotices.post("info", "Plan cartridge", "The lander's printer can make %s now, from parts." % _plan_name(id), "log")

func _plan_cost(index: int) -> int:
	var spec: Array = PLANS[index]
	return int(n(str(spec[2]), float(spec[3])))

func _open_plans() -> Array:
	var out: Array = []
	for i in PLANS.size():
		if prints.has(str(PLANS[i][0])): continue
		if str(PLANS[i][0]) == "hitch" and not _gary_found(): continue   # nothing to hitch it to yet
		if str(PLANS[i][0]) == "seal" and not _seal_wanted(): continue
		if FOUND_PLANS.has(str(PLANS[i][0])) and not cartridges.has(str(PLANS[i][0])): continue
		if ADDON_PLANS.has(str(PLANS[i][0])):
			# The suit already has it, or one's waiting to go on.
			var suit: Node = world.get("suit")
			if suit != null and (suit.addons.has(str(PLANS[i][0])) or suit.waiting.has(str(PLANS[i][0]))): continue
		out.append(i)
	return out

## Day 3 of version 2: Walker 1's split wheel seal, before it can walk home.
## The A6 rewrite (15 Nov) fixes Walker 1's wheel seal on the spot with the
## patch kit (scripts/walker.gd patch_seal), so the printed seal is never wanted.
func _seal_wanted() -> bool:
	return false

## GAR-Y met for real (not still out at work, waiting to be found on day 2).
func _gary_found() -> bool:
	if not bool(world.get("gary_met")): return false
	var field: Node = world.get("drop_field")
	return field == null or not bool(field.get("gary_working"))

## A plan Castellanos has just asked for (the hitch, the seal) comes up
## first on the printer, once; Next plan still cycles after that.
var _brought_up := {}
func _bring_up(open: Array) -> void:
	for id in ["hitch", "seal"]:
		if _brought_up.has(id): continue
		for i in open:
			if str(PLANS[int(i)][0]) == id:
				_brought_up[id] = true
				plan = int(i)
				return

func next_plan() -> void:
	var open := _open_plans()
	if open.is_empty(): return
	var at := open.find(plan)
	plan = int(open[(at + 1) % open.size()])
	MHAudio.sfx("ui_click", -6.0, .05)

func printer_prompt() -> Dictionary:
	var open := _open_plans()
	if printing != "": return {"label": "Tiny printer · printing %s" % _plan_name(printing)}
	if open.is_empty(): return {"label": "Tiny printer · %d parts · nothing left to print" % parts}
	_bring_up(open)
	if not open.has(plan): plan = int(open[0])
	var cost := _plan_cost(plan)
	# E opens its screen (playtest 14 Nov); "plan" is what's first on it.
	var out := {"label": "Tiny printer · %d parts" % parts, "primary": "Choose what to print"}
	out["plan"] = ("Print %s · %d parts" % [str(PLANS[plan][1]), cost]) if parts >= cost else ""
	return out

static func _plan_name(id: String) -> String:
	for spec in PLANS:
		if str(spec[0]) == id: return str(spec[1])
	return id

func print_now() -> bool:
	if printing != "": return false
	var open := _open_plans()
	if open.is_empty(): return false
	_bring_up(open)
	if not open.has(plan): plan = int(open[0])
	return print_plan(str(PLANS[plan][0]))

## The printer's screen (scripts/tiny_printer_screen.gd): what it can make.
## Each: {id, name, cost, state}: "ready", "short" (not enough parts),
## "locked" (a suit add-on whose cartridge you haven't found) or "printing".
func printer_rows() -> Array:
	var out: Array = []
	var open := _open_plans()
	_bring_up(open)
	for i in open: out.append({"id": str(PLANS[i][0]), "name": str(PLANS[i][1]), "cost": _plan_cost(i), "state": "printing" if printing == str(PLANS[i][0]) else ("ready" if parts >= _plan_cost(i) else "short")})
	var suit: Node = world.get("suit")
	for id in ADDON_PLANS:
		if cartridges.has(id) or prints.has(id): continue
		if suit != null and (suit.addons.has(id) or suit.waiting.has(id) or (suit.get("stowed") as Array).has(id)): continue
		var i := PLANS.map(func(spec): return str(spec[0])).find(id)
		out.append({"id": id, "name": str(PLANS[i][1]), "cost": _plan_cost(i), "state": "locked"})
	return out

## Print one plan by id, if it's open and there are parts for it.
func print_plan(id: String) -> bool:
	if printing != "": return false
	var index := PLANS.map(func(spec): return str(spec[0])).find(id)
	if index < 0 or not _open_plans().has(index): return false
	plan = index
	var cost := _plan_cost(plan)
	if parts < cost: return false
	parts -= cost
	printing = str(PLANS[plan][0])
	_print_left = PRINT_SECONDS
	bench.printing(true)
	MHAudio.sfx("mode_build", -10.0)
	return true

func _printed() -> void:
	var id := printing
	printing = ""
	prints[id] = true
	bench.printing(false)
	MHAudio.sfx("all_clear", -10.0)
	match id:
		"hitch":
			MHNotices.post("valid", "Printed: sled hitch", "GAR-Y can tow now. Anything too heavy to carry: bring GAR-Y close and E on it. Ice you chip with it close by goes on too.", "log")
			var thinking: Node = world.get("notes")
			if thinking != null and not (staged(_cartridge()) and staged(_pack())): thinking.think("staging")
		"pick": MHNotices.post("valid", "Printed: ice pick head", "Ice comes away in bigger chunks now.", "log")
		"seal":
			MHNotices.post("valid", "Printed: wheel seal", "GAR-Y will run it out to Walker 1 tonight. The walker fits it itself.", "log")
			var gary: Node3D = world.get("scout_rover")
			if gary != null and is_instance_valid(gary): gary.call("_say", "happy")
			var radio: Node = world.get("radio")
			if radio != null: radio.ring("d3_seal")
		"battery", "heater", "air_pack":
			var suit: Node = world.get("suit")
			if suit != null: suit.give_addon(id)
		"bladder":
			_apply_bladder(true)
			MHNotices.post("valid", "Printed: water bladder", "The lander keeps %d L more water." % roundi(n("water_bladder_l", 6.0)), "log")
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("salvage")
	done("print")

func _apply_bladder(fresh: bool) -> void:
	var c := core()
	if c == null: return
	var want := maxf(n("cabin_water_l", 7.5), 12.0) + n("water_bladder_l", 6.0)
	if fresh or float(c.water_cap) < want: c.water_cap = want

# ---------- the gate into 3c ----------

func done(job: String) -> void:
	if jobs.has(job): return
	jobs[job] = true
	var counted := 0
	for id in JOBS: if jobs.has(id): counted += 1
	if counted >= int(n("lifepod_jobs_for_walker", 3.0)): walker_due = true

# ---------- the module's cargo, staged by the lander ----------

func _cartridge() -> Node3D:
	var drop: Node = world.get("storm_drop")
	return drop.cartridge if drop != null else null

func _pack() -> Node3D:
	var field: Node = world.get("drop_field")
	return field.sites.power.pack if field != null and field.sites.has("power") else null

## Waiting by the lander (or already in the module).
func staged(item: Node3D) -> bool:
	if item == null: return true
	var where := str(item.where)
	if where in ["plugged", "laid"]: return true
	if where != "ground": return false
	var home: Vector3 = world.lander.global_position
	return Vector2(item.global_position.x - home.x, item.global_position.z - home.z).length() < STAGE_REACH

func _check_staging() -> void:
	if jobs.has("tow"): return
	var notes: Node = world.get("notes")
	var cart := _cartridge()
	if notes != null and cart != null and staged(cart) and notes.is_open("module_air"): notes.think("module_air", "staged")
	if staged(cart) and staged(_pack()):
		done("tow")
		if notes != null:
			notes.answer("staging")
			notes.answer("power_pallet")   # the power's home: that thought's done
		MHNotices.post("valid", "Cargo staged", "The module's air cartridge and power pack are waiting by the lander.", "log")

## Carrying cargo, E on a hitched GAR-Y: onto its sled (scripts/o2_cartridge.gd, power_pack.gd).
func sled_takes(target: Node) -> bool:
	return target != null and target.is_in_group("gar_y") and prints.has("hitch") and sled_cargo.size() < 2

func load_on_sled(item: Node3D, gary: Node3D) -> void:
	world.player.set_meta("load_speed", 1.0)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")
	item.where = "sled"
	item.reachable(false)
	item.get_parent().remove_child(item)
	gary.add_child(item)
	item.position = Vector3(0, .32, .85 + .55 * sled_cargo.size())   # behind it (its front is -Z)
	item.rotation = Vector3(0, PI * .5, 0)
	sled_cargo.append(item)
	MHAudio.sfx("suit_clamp", -6.0)
	gary.call("_say", "happy")
	if gary.has_method("order"): gary.order("come")
	MHNotices.post("info", "On GAR-Y's sled", "GAR-Y tows it now. At the lander, E on GAR-Y unloads it.", "log")

func cargo_ready(gary: Node3D) -> bool:
	return not sled_cargo.is_empty() and gary != null and gary.global_position.distance_to(world.lander.global_position) < SLED_REACH

## E on GAR-Y by the lander: the cargo comes off, set down side by side.
func unload_cargo() -> void:
	var i := 0
	for item in sled_cargo:
		if item == null or not is_instance_valid(item): continue
		var home: Node = item.get("drop") if item.get("drop") != null else item.get("site")
		item.get_parent().remove_child(item)
		home.add_child(item)
		var at: Vector3 = world.lander.to_global(Vector3(-3.4 - 1.6 * i, 0, -6.6))
		item.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.z), at.z)
		item.rotation = Vector3(0, world.lander.rotation.y, 0)
		item.where = "ground"
		item.reachable(true)
		i += 1
	sled_cargo.clear()
	MHAudio.sfx("place", -6.0)
	_check_staging()

## In the small hours: something big moves out on the flats (3c follows it).
func walker_night() -> void:
	walker_moved = true
	var notes: Node = world.get("notes")
	if notes != null: notes.think("night_sound")
	var walker: Node = world.get("walker")
	if walker != null: walker.lay_tracks()   # 3c: it came close, then wandered off

func export_state() -> Dictionary:
	var site_state := {}
	for kind in sites: site_state[kind] = sites[kind].export_state()
	var finds: Array = []
	for find in get_tree().get_nodes_in_group("carried_find"):
		if not (find as Node).is_queued_for_deletion(): finds.append(find.export_state())
	return {"parts": parts, "prints": prints.keys(), "cartridges": cartridges.keys(), "jobs": jobs.keys(), "studied": studied.keys(), "stripped": stripped_keys.keys(),
		"sled_kg": sled_kg, "walker_due": walker_due, "walker_moved": walker_moved, "photo_nudged": _photo_nudged, "gary_reported": gary_reported, "rations": rations, "rations_carried": rations_carried, "sites": site_state, "finds": finds}
