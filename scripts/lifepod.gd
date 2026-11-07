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
## [kind, nearest, furthest, the ground it wants]
const THREADS := [["iron", 1000.0, 1400.0, "rough"], ["ice_wall", 1000.0, 1500.0, "low"]]
const PLANS := [["hitch", "the sled hitch", "print_hitch_parts", 3.0], ["pick", "an ice pick head", "print_pick_parts", 2.0], ["bladder", "a water bladder", "print_bladder_parts", 2.0]]
const PRINT_SECONDS := 6.0
const JOBS := ["water", "print", "sample", "tow"]
const WALKER_HOUR := 3.0        # the walker moves in the small hours
const GARY_NEAR := 15.0
const SLED_REACH := 16.0        # GAR-Y this close to the lander to melt the sled's ice

var world: Node
var sites := {}                 # kind → scripts/thread_site.gd
var bench: Node3D
var parts := 0
var prints := {}                # plan id → true
var jobs := {}                  # job → true
var sled_kg := 0.0
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

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "Lifepod"
	add_to_group("lifepod")
	parts = int(saved.get("parts", 0))
	for id in saved.get("prints", []): prints[str(id)] = true
	for id in saved.get("jobs", []): jobs[str(id)] = true
	for id in saved.get("studied", []): studied[str(id)] = true
	for key in saved.get("stripped", []): stripped_keys[str(key)] = true
	sled_kg = float(saved.get("sled_kg", 0.0))
	walker_due = bool(saved.get("walker_due", false))
	walker_moved = bool(saved.get("walker_moved", false))
	_photo_nudged = bool(saved.get("photo_nudged", false))
	_place_sites(saved.get("sites", {}))
	_hook_salvage.call_deferred()
	bench = BENCH.new()
	bench.setup(self, world.lander)
	_hook_dispenser.call_deferred()
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
	# The frost hollow round pallet 4 (clear of its canopy): the nearest ice.
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
	for kind in sites:
		var site: Node = sites[kind]
		if not site.seen and you.distance_to(site.global_position) < SITE.SEEN_AT: see(site)
	var notes: Node = world.get("notes")
	var c := core()
	var hour := MHGame.sol_hour
	if notes != null and c != null:
		var sol := int(notes.call("_sol"))
		if not notes.is_settled("water"):
			if float(c.water_l) <= 0.0: notes.think("water", "empty")
			elif (sol >= 2 and hour > 5.0 and hour < 12.0) or float(c.water_sols()) < 1.0:
				notes.think("water", "low", {"where": _ice_hint()})
	# The walker moves in the small hours once you've done enough.
	if _last_hour >= 0.0 and walker_due and not walker_moved and _crossed(_last_hour, hour, WALKER_HOUR): walker_night()
	_last_hour = hour

static func _crossed(from: float, to: float, at: float) -> bool:
	if to >= from: return from < at and to >= at
	return from < at or to >= at

func _ice_hint() -> String:
	var known: Node = world.get("known")
	var field: Node = world.get("drop_field")
	if field != null and field.sites.has("tools") and known != null and known.knows(field.sites.tools.id()):
		return " There was frost in that hollow by pallet 4: ice, just under the dust."
	return " Frost forms in low ground at dawn. Ice under it, maybe."

## You come within sight of a thread: it joins Notes and your record.
func see(site: Node) -> void:
	site.seen = true
	var known: Node = world.get("known")
	if known != null: known.learn(site.id(), "find", region_at(site.global_position), str(SITE.NAMES.get(site.kind, "Find")), "you")
	var notes: Node = world.get("notes")
	if notes == null: return
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
	stripped_keys[str(piece.get_meta("key", ""))] = true
	MHNotices.post("info", "Parts", "%d parts for the lander's printer." % parts, "log")
	var notes: Node = world.get("notes")
	if notes != null: notes.think("salvage")

# ---------- the tiny printer ----------

func _plan_cost(index: int) -> int:
	var spec: Array = PLANS[index]
	return int(n(str(spec[2]), float(spec[3])))

func _open_plans() -> Array:
	var out: Array = []
	for i in PLANS.size():
		if not prints.has(str(PLANS[i][0])): out.append(i)
	return out

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
	if not open.has(plan): plan = int(open[0])
	var cost := _plan_cost(plan)
	var out := {"label": "Tiny printer · %d parts" % parts}
	if parts >= cost: out["primary"] = "Print %s · %d parts" % [str(PLANS[plan][1]), cost]
	else: out["label"] += " · %s needs %d" % [str(PLANS[plan][1]), cost]
	if open.size() > 1: out["info"] = "Next plan"
	return out

static func _plan_name(id: String) -> String:
	for spec in PLANS:
		if str(spec[0]) == id: return str(spec[1])
	return id

func print_now() -> bool:
	if printing != "": return false
	var open := _open_plans()
	if open.is_empty(): return false
	if not open.has(plan): plan = int(open[0])
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
		"hitch": MHNotices.post("valid", "Printed: sled hitch", "GAR-Y can tow ice now. Chip ice with it close by and it goes on the sled.", "log")
		"pick": MHNotices.post("valid", "Printed: ice pick head", "Ice comes away in bigger chunks now.", "log")
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
	if jobs.size() >= int(n("lifepod_jobs_for_walker", 3.0)): walker_due = true

## In the small hours: something big moves out on the flats (3c follows it).
func walker_night() -> void:
	walker_moved = true
	var notes: Node = world.get("notes")
	if notes != null: notes.think("night_sound")

func export_state() -> Dictionary:
	var site_state := {}
	for kind in sites: site_state[kind] = sites[kind].export_state()
	var finds: Array = []
	for find in get_tree().get_nodes_in_group("carried_find"):
		if not (find as Node).is_queued_for_deletion(): finds.append(find.export_state())
	return {"parts": parts, "prints": prints.keys(), "jobs": jobs.keys(), "studied": studied.keys(), "stripped": stripped_keys.keys(),
		"sled_kg": sled_kg, "walker_due": walker_due, "walker_moved": walker_moved, "photo_nudged": _photo_nudged, "sites": site_state, "finds": finds}
