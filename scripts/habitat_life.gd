extends RefCounted

## Act 2 (Missions 7-10): the crew as people, and the hazards of living on
## Mars. Owned by the habitat simulation (habitat_sim.gd `life`), which calls
## pre_step and post_step every step. Everything you monitor stays whole-habitat
## (one radiation dose, one air pressure); rooms add properties (a shield
## rating, a section) and events (a breach here). Numbers: data/hazards.json.
## Rules: docs/missions-7-10-design.md section 7.
const PATH := "res://data/hazards.json"
const MHResources := preload("res://scripts/mh_resources.gd")

static var _data := {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _data = parsed
	return _data

static func value(section: String, key: String, fallback: Variant = 0.0) -> Variant:
	return (data().get(section, {}) as Dictionary).get(key, fallback)

static func role(role_id: String) -> Dictionary:
	for each in (data().crew.roles as Array):
		if str(each.id) == role_id: return each
	return {}

var sim: RefCounted

# ---- switches (set by the world or the mission Test, not saved) ----
## Named crew with fitness and wellbeing (Mission 8 on, and free play).
var crew_on := false
## Breakdowns can happen (Mission 10 Tests; rarely in live play).
var breakdowns_on := false
var breakdown_scale := 1.0
## Hazards that can happen on their own in normal play: "spe", "breach", "breakdowns".
var live_kinds: Array = []
var rng := RandomNumberGenerator.new()

# ---- state (saved) ----
## [{name, role, fitness, wellbeing, injured_h, recovered_h, favourite}]
var crew: Array = []
var dose_msv := 0.0
## Dose during the most recent solar particle event, and the worst one so far.
var event_dose_msv := 0.0
var worst_event_msv := 0.0
var spe_eta := -1.0
var spe_hours_left := 0.0
## Rooms that have lost air: room key -> pressure (0-1). Missing means full.
var section_pressure := {}
## {room, hours, patched_at, restored_at} while a breach is being dealt with.
var breach := {}
var air_reserve_kg := 0.0
var spares := 0
var spare_progress := 0.0
var _known := {"air": 0.0, "spares": 0}
## Broken machines: placement id -> {"id", "hours"}.
var broken := {}
var repair_left := 0.0
var repairing := ""
## Life-critical systems with every unit broken: machine id -> hours down now.
var down_hours := {}
var worst_down_hours := 0.0
var blackout_hours_left := 0.0
var research_done := 0.0
var injuries_recovered := 0
# Wellbeing needs change slowly: worked out about once a game hour.
var _needs_cache: Array = []
var _needs_age := 99.0
var _needs_inv: Dictionary = {}
var _stations_cache := 0
var _medical_cache := false

func _init(owner: RefCounted = null) -> void:
	sim = owner
	rng.randomize()

func save() -> Dictionary:
	return {"crew": crew.duplicate(true), "dose_msv": dose_msv, "event_dose_msv": event_dose_msv, "worst_event_msv": worst_event_msv,
		"spe_eta": spe_eta, "spe_hours_left": spe_hours_left, "section_pressure": section_pressure.duplicate(), "breach": breach.duplicate(),
		"air_reserve_kg": air_reserve_kg, "spares": spares, "spare_progress": spare_progress, "known": _known.duplicate(),
		"broken": broken.duplicate(true), "repair_left": repair_left, "repairing": repairing, "blackout_hours_left": blackout_hours_left,
		"research_done": research_done}

func load(state: Dictionary) -> void:
	crew = (state.get("crew", []) as Array).duplicate(true)
	dose_msv = float(state.get("dose_msv", 0.0)); event_dose_msv = float(state.get("event_dose_msv", 0.0)); worst_event_msv = float(state.get("worst_event_msv", 0.0))
	spe_eta = float(state.get("spe_eta", -1.0)); spe_hours_left = float(state.get("spe_hours_left", 0.0))
	section_pressure = (state.get("section_pressure", {}) as Dictionary).duplicate(); breach = (state.get("breach", {}) as Dictionary).duplicate()
	air_reserve_kg = float(state.get("air_reserve_kg", 0.0)); spares = int(state.get("spares", 0)); spare_progress = float(state.get("spare_progress", 0.0))
	_known = (state.get("known", {"air": 0.0, "spares": 0}) as Dictionary).duplicate()
	broken = (state.get("broken", {}) as Dictionary).duplicate(true); repair_left = float(state.get("repair_left", 0.0)); repairing = str(state.get("repairing", ""))
	blackout_hours_left = float(state.get("blackout_hours_left", 0.0)); research_done = float(state.get("research_done", 0.0))

# ---------- the crew ----------

## Make sure there's a person for each crew member aboard (names kept).
func ensure_crew(count: int, names: Array = []) -> void:
	var roles: Array = data().crew.roles
	var defaults: Array = data().crew.default_names
	var favourites: Array = data().crew.favourites
	while crew.size() < count and crew.size() < roles.size():
		var i := crew.size()
		var person_name := str(names[i]) if i < names.size() and not str(names[i]).strip_edges().is_empty() else str(defaults[i])
		crew.append({"name": person_name, "role": str(roles[i].id), "fitness": float(value("fitness", "start", 100.0)),
			"wellbeing": float(value("wellbeing", "start", 80.0)), "injured_h": 0.0, "recovered_h": 0.0, "favourite": str(favourites[i % favourites.size()])})
	if crew.size() > count: crew.resize(count)

func set_names(names: Array) -> void:
	for i in range(mini(names.size(), crew.size())):
		if not str(names[i]).strip_edges().is_empty(): crew[i].name = str(names[i]).strip_edges()

func person(role_id: String) -> Dictionary:
	for each in crew:
		if str(each.role) == role_id: return each
	return {}

func _able(role_id: String) -> bool:
	var who := person(role_id)
	return not who.is_empty() and float(who.injured_h) <= 0.0

func injure(role_id: String) -> bool:
	for each in crew:
		if str(each.role) == role_id:
			each.injured_h = float(value("injury", "recovery_sols", 8.0)) * 24.0
			each.recovered_h = 0.0
			return true
	return false

func injured() -> Array:
	return crew.filter(func(p): return float(p.injured_h) > 0.0)

## How fast a person works (0.4 slowest, 1 full speed; 0 while injured).
func work_speed(p: Dictionary) -> float:
	if float(p.injured_h) > 0.0: return 0.0
	var full := float(value("work", "full_speed_at", 70.0))
	return clampf(minf(float(p.fitness), float(p.wellbeing)) / full, float(value("work", "slowest", .4)), 1.0)

## The team's work speed (research): 1 when the crew system is off.
func team_speed() -> float:
	if not crew_on or crew.is_empty(): return 1.0
	var total := 0.0
	for p in crew: total += work_speed(p)
	return total / crew.size()

## Food grown depends partly on the botanist.
func food_speed() -> float:
	if not crew_on or crew.is_empty(): return 1.0
	var botanist := person("botanist")
	return .5 + .5 * (work_speed(botanist) if not botanist.is_empty() else team_speed())

func lowest_fitness() -> float:
	var low := 100.0
	for p in crew: low = minf(low, float(p.fitness))
	return low

func average_wellbeing() -> float:
	if crew.is_empty(): return 100.0
	var total := 0.0
	for p in crew: total += float(p.wellbeing)
	return total / crew.size()

# ---------- what's in each room (all placed items, not just balanced ones) ----------

func _ids_in(inv: Dictionary, room_index: int) -> Array:
	return (inv.all_items as Array).filter(func(i): return int(i.room) == room_index).map(func(i): return str(i.id))

func _count(inv: Dictionary, ids: Array) -> int:
	return (inv.all_items as Array).filter(func(i): return ids.has(str(i.id))).size()

func _has(inv: Dictionary, id: String) -> bool:
	return (inv.all_items as Array).any(func(i): return str(i.id) == id)

## Shield points for the whole habitat: the hull, plus every shielding panel on
## its outside walls and roof, shared over all its floor (a bigger base needs
## more panels). coverage_factor tunes how far a panel goes.
func habitat_shield(inv: Dictionary) -> float:
	var hull := float(value("radiation", "hull_points", 5.0))
	var squares := 0.0
	for room in inv.rooms: squares += float(room.cells)
	return hull + float(inv.get("shield_upgrades", 0.0)) * float(value("radiation", "coverage_factor", 1.5)) / maxf(1.0, squares)

## Shield points in a room: the habitat's, plus what's stored in the room
## (lockers, cabinets) spread over its floor.
func shield_rating(inv: Dictionary, room_index: int) -> float:
	var rating := habitat_shield(inv)
	if room_index < 0 or room_index >= (inv.rooms as Array).size(): return rating
	var points: Dictionary = value("radiation", "shield_points", {})
	var extra := 0.0
	for id in _ids_in(inv, room_index): extra += float(points.get(id, 0.0))
	return rating + extra / maxf(1.0, float(inv.rooms[room_index].cells))

## The storm shelter: the best-shielded room with a storm shelter locker.
## {} when there's none, else {index, key, label, rating, capacity, heated, cold, ok}.
func shelter(inv: Dictionary) -> Dictionary:
	var best := {}
	for index in range((inv.rooms as Array).size()):
		if not _ids_in(inv, index).has("storm_shelter_locker"): continue
		var rating := shield_rating(inv, index)
		if not best.is_empty() and rating <= float(best.rating): continue
		var room: Dictionary = inv.rooms[index]
		best = {"index": index, "key": str(room.key), "label": str(room.label), "rating": rating,
			"capacity": int(floor(float(room.cells) * float(value("radiation", "crew_per_shelter_cell", 3.0)))),
			"heated": not str(room.kind) in ["airlock", "vehicle_bay"], "cold": (sim.cold_spots as Array).has(str(room.label))}
	if not best.is_empty():
		best["ok"] = float(best.rating) >= float(value("radiation", "safe_points", 20.0)) and int(best.capacity) >= sim.crew_count() and bool(best.heated) and not bool(best.cold)
	return best

## How much of an event's radiation gets through this many shield points.
static func dose_factor(points: float) -> float:
	var hull := float(value("radiation", "hull_points", 5.0))
	return exp(-maxf(0.0, points - hull) / float(value("radiation", "falloff_points", 12.0)))

## The radiation the crew get in the event, given the shelter now (mSv).
func expected_event_dose(inv: Dictionary) -> float:
	var total := float(value("radiation", "event_dose_msv", 150.0))
	var crew_n := maxi(1, sim.crew_count())
	var place := shelter(inv)
	if place.is_empty(): return total
	var inside := minf(1.0, float(place.capacity) / crew_n)
	return total * (inside * dose_factor(float(place.rating)) + (1.0 - inside))

# ---------- wellbeing needs ----------

## The six needs, each {id, label, score 0-1, missing (plain words)}.
func needs(inv: Dictionary, tiers: Dictionary) -> Array:
	var c: Dictionary = data().crew
	var n := maxi(1, crew.size() if not crew.is_empty() else sim.crew_count())
	var rooms: Array = inv.rooms
	var out: Array = []
	# 1. Sleep: a bunk each, and quiet.
	var bunks := int(inv.capacity.berths)
	var noisy := false
	for index in range(rooms.size()):
		if str(rooms[index].kind) != "living": continue
		for other in rooms[index].next:
			# Sound insulation on every shared wall keeps a noisy neighbour out.
			if (rooms[index].get("quiet_from", []) as Array).has(other): continue
			var kind := str(rooms[other].kind)
			if (c.noisy_rooms as Array).has(kind) or _ids_in(inv, other).any(func(id): return (c.noisy_items as Array).has(id)):
				noisy = true
		# A noisy machine in the room itself: insulation can't help.
		if _ids_in(inv, index).any(func(id): return (c.noisy_items as Array).has(id)): noisy = true
	var sleep := minf(1.0, float(bunks) / n) * (.5 if noisy else 1.0)
	out.append({"id": "sleep", "label": "Sleep and privacy", "score": sleep,
		"missing": "" if sleep >= .99 else ("Living Quarters is next to a noisy room: add a sound insulation panel to the wall between them" if noisy else "Not everyone has a bunk")})
	# 2. Space.
	var living_cells := 0.0
	for room in rooms:
		if not str(room.kind) in ["corridor", "airlock", "storage", "vehicle_bay"]: living_cells += float(room.cells)
	var space := minf(1.0, living_cells / (n * float(c.living_cells_per_person)))
	out.append({"id": "space", "label": "Space", "score": space, "missing": "" if space >= .99 else "Crowded: about %d more floor squares of rooms needed" % ceili(n * float(c.living_cells_per_person) - living_cells)})
	# 3. Together.
	var seats := 0
	for id in c.table_items: seats += _count(inv, [id]) * int(c.table_items[id])
	var galley := (c.galley_items as Array).any(func(id): return _has(inv, id))
	var together := minf(1.0, float(seats) / n) * .6 + (.4 if galley else 0.0)
	out.append({"id": "together", "label": "Meals together", "score": together,
		"missing": "" if together >= .99 else ("Not enough table seats for everyone" if seats < n else "No galley oven or kitchenette for real meals")})
	# 4. A bit of home.
	var plants := (c.plant_items as Array).any(func(id): return _has(inv, id)) or rooms.any(func(r): return str(r.kind) == "hydroponics")
	var windows := rooms.any(func(r): return int(r.windows) > 0)
	var personal := minf(1.0, float(_count(inv, c.personal_items)) / ceilf(n / 2.0))
	var home := (.25 if plants else 0.0) + (.25 if windows else 0.0) + .5 * personal
	var lacking: Array = []
	if not plants: lacking.append("plants")
	if not windows: lacking.append("a window")
	if personal < .99: lacking.append("personal things (photos, books, games)")
	out.append({"id": "home", "label": "A bit of home", "score": home, "missing": "" if lacking.is_empty() else "Missing " + ", ".join(lacking)})
	# 5. Meaningful work.
	var have_room := 0
	var no_room: Array = []
	for i in range(n):
		var r := role(str(crew[i].role)) if i < crew.size() else (data().crew.roles[i] as Dictionary)
		if rooms.any(func(room): return str(room.kind) == str(r.room)): have_room += 1
		else: no_room.append("%s (%s)" % [str(r.label), str(BuildController.ZONE_TYPES.get(str(r.room), {}).get("label", r.room))])
	var work := float(have_room) / n
	out.append({"id": "work", "label": "Meaningful work", "score": work, "missing": "" if no_room.is_empty() else "No work room for: " + ", ".join(no_room)})
	# 6. Contact with Earth: the mast outside and a communications station in
	# Mission Operations (the "communications" room), both powered.
	var antenna := (inv.items as Array).any(func(i): return str(i.id) == "comms_antenna") and bool(tiers.get(4, false))
	var station := false
	for index in range(rooms.size()):
		if str(rooms[index].kind) == "communications" and _ids_in(inv, index).has("communications_station"): station = true
	var contact := 1.0 if antenna and station and blackout_hours_left <= 0.0 else 0.0
	var why := "Blackout: the Sun is between Mars and Earth"
	if not antenna: why = "No powered Communications Mast outside"
	elif not station: why = "No communications station in Mission Operations"
	out.append({"id": "contact", "label": "Contact with Earth", "score": contact, "missing": "" if contact > 0.0 else why})
	return out

func wellbeing_target(need_list: Array, p: Dictionary, inv: Dictionary) -> float:
	var total := 0.0
	for each in need_list: total += float(each.score)
	var floor_value := float(value("wellbeing", "floor", 30.0))
	var target := floor_value + (100.0 - floor_value) * total / maxf(1.0, need_list.size())
	if _has(inv, str(p.get("favourite", ""))): target += float(value("wellbeing", "favourite_bonus", 6.0))
	if float(p.injured_h) > 0.0: target -= float(value("wellbeing", "injured_penalty", 15.0))
	return clampf(target, 0.0, 100.0)

## A Medical Bay that can treat someone: a powered exam cot and a medical cabinet.
func medical_ready(inv: Dictionary, tiers: Dictionary) -> bool:
	for index in range((inv.rooms as Array).size()):
		if str(inv.rooms[index].kind) != "medical": continue
		var ids := _ids_in(inv, index)
		if ids.has("medical_exam_cot") and ids.has("medical_cabinet") and bool(tiers.get(4, false)): return true
	return false

## What keeps the crew fit, each about as well as one exercise station.
const FITNESS_ITEMS := ["exercise_station", "climbing_wall"]

func exercise_stations(inv: Dictionary, tiers: Dictionary) -> int:
	if not bool(tiers.get(4, false)): return 0
	return (inv.items as Array).filter(func(i): return FITNESS_ITEMS.has(str(i.id)) and not is_broken(i)).size()

# ---------- sections and air pressure ----------

## Rooms joined without a hatch share their air: {room index: section number}.
func sections(inv: Dictionary) -> Dictionary:
	if inv.has("sections"): return inv.sections
	var builder: Node = sim.builder
	var rooms: Array = inv.rooms
	var parent: Array = range(rooms.size())
	var room_of_cell := {}
	for index in range(rooms.size()):
		for cell in rooms[index].zone.get("cells", []): room_of_cell[cell] = index
	var find := func(x: int) -> int:
		while parent[x] != x: x = parent[x]
		return x
	for cell in room_of_cell:
		for side in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: int = room_of_cell.get(cell + side, -1)
			var mine: int = room_of_cell[cell]
			if other < 0 or other == mine: continue
			if builder._has_interior_door(cell, side) or builder._is_airlock_inner_doorway(cell, side) or builder._is_airlock_inner_doorway(cell + side, -side): continue
			if builder._should_build_wall(cell, side) or builder._should_build_wall(cell + side, -side): continue
			var a: int = find.call(mine)
			var b: int = find.call(other)
			if a != b: parent[a] = b
	var out := {}
	for index in range(rooms.size()): out[index] = find.call(index)
	inv["sections"] = out
	return out

## The rooms sharing air with this one.
func section_rooms(inv: Dictionary, room_index: int) -> Array:
	var map := sections(inv)
	var mine: int = map.get(room_index, room_index)
	return range((inv.rooms as Array).size()).filter(func(i): return int(map.get(i, i)) == mine)

## The habitat's air pressure: the pressurised share of its volume (%).
func pressure_pct(inv: Dictionary) -> float:
	var total := 0.0
	var held := 0.0
	for room in inv.rooms:
		total += float(room.cells)
		held += float(room.cells) * float(section_pressure.get(str(room.key), 1.0))
	return 100.0 * held / maxf(1.0, total)

func start_breach(inv: Dictionary, room_key: String) -> bool:
	for room in inv.rooms:
		if str(room.key) == room_key:
			breach = {"room": room_key, "label": str(room.label), "hours": 0.0, "patched_at": -1.0, "restored_at": -1.0, "had_kit": _has(inv, "hull_patch_kit")}
			return true
	return false

## Where a breach would hit by default: Living Quarters, else the biggest room.
static func default_breach_room(inv: Dictionary) -> String:
	var best := {}
	for room in inv.rooms:
		if str(room.kind) in ["airlock", "corridor", "vehicle_bay"]: continue
		if str(room.kind) == "living": return str(room.key)
		if best.is_empty() or int(room.cells) > int(best.cells): best = room
	return str(best.get("key", ""))

func _breach_step(dt: float, inv: Dictionary) -> void:
	if breach.is_empty(): return
	var b: Dictionary = data().breach
	breach.hours = float(breach.hours) + dt
	var index := -1
	for i in range((inv.rooms as Array).size()):
		if str(inv.rooms[i].key) == str(breach.room): index = i
	if index < 0: breach = {}; return
	var section := section_rooms(inv, index)
	var cells := 0.0
	for i in section: cells += float(inv.rooms[i].cells)
	# Venting until patched: pressure halves every (cells x 0.25) hours.
	if float(breach.patched_at) < 0.0:
		var half := maxf(.05, cells * float(b.half_life_hours_per_cell))
		for i in section:
			var key := str(inv.rooms[i].key)
			section_pressure[key] = float(section_pressure.get(key, 1.0)) * pow(.5, dt / half)
		var patch_time := float(b.patch_hours) if _able("engineer") or not crew_on else float(b.patch_hours_no_engineer)
		if _has(inv, "hull_patch_kit") and float(breach.hours) >= patch_time: breach.patched_at = float(breach.hours)
		return
	# Patched: refill from the air reserve.
	var missing := 0.0
	for i in section: missing += float(inv.rooms[i].cells) * float(b.air_kg_per_cell) * (1.0 - float(section_pressure.get(str(inv.rooms[i].key), 1.0)))
	if missing <= .01:
		for i in section: section_pressure.erase(str(inv.rooms[i].key))
		if float(breach.restored_at) < 0.0: breach.restored_at = float(breach.hours)
		breach = {} if float(breach.hours) > float(breach.restored_at) + 1.0 else breach
		return
	var refill := minf(minf(missing, air_reserve_kg), float(b.repress_kg_per_hour) * dt)
	if refill <= 0.0: return
	air_reserve_kg -= refill
	var share := refill / missing
	for i in section:
		var key := str(inv.rooms[i].key)
		var p := float(section_pressure.get(key, 1.0))
		section_pressure[key] = minf(1.0, p + (1.0 - p) * share)

# ---------- breakdowns and spares ----------

func is_broken(item: Dictionary) -> bool:
	return broken.has(str(item.get("pid", "")))

func _breakdown_step(dt: float, inv: Dictionary) -> void:
	var b: Dictionary = data().breakdowns
	var machines: Array = b.machines
	if breakdowns_on or live_kinds.has("breakdowns"):
		var scale := breakdown_scale if breakdowns_on else float(value("live", "breakdown_scale", .3))
		var chance := dt / (float(b.mean_sols_between) * 24.0) * scale
		for item in inv.items:
			if not machines.has(str(item.id)) or is_broken(item) or str(item.get("pid", "")).is_empty(): continue
			if rng.randf() < chance: broken[str(item.pid)] = {"id": str(item.id), "hours": 0.0}
	if broken.is_empty() and down_hours.is_empty():
		_print_spares(dt, inv)
		return
	for key in broken: broken[key].hours = float(broken[key].hours) + dt
	# Repairs: one at a time, each needs a spare part.
	if repairing.is_empty() or not broken.has(repairing):
		repairing = ""
		for key in broken:
			if spares > 0:
				spares -= 1
				repairing = str(key)
				repair_left = float(b.repair_hours) if _able("engineer") or not crew_on else float(b.repair_hours_no_engineer)
				break
	if not repairing.is_empty():
		repair_left -= dt
		if repair_left <= 0.0:
			broken.erase(repairing)
			repairing = ""
	_print_spares(dt, inv)
	# Systems down: every unit of a life-critical machine broken.
	for id in machines:
		var units: Array = (inv.items as Array).filter(func(i): return str(i.id) == str(id))
		if not units.is_empty() and units.all(func(i): return is_broken(i)):
			down_hours[id] = float(down_hours.get(id, 0.0)) + dt
			worst_down_hours = maxf(worst_down_hours, float(down_hours[id]))
		else:
			down_hours.erase(id)

## A running regolith printer slowly makes spare parts.
func _print_spares(dt: float, inv: Dictionary) -> void:
	if int(inv.get("intakes", 0)) <= 0 or sim.print_rate(inv) <= 0.0: return
	spare_progress += dt / (float(data().breakdowns.printer_sols_per_spare) * 24.0)
	if spare_progress >= 1.0:
		spare_progress -= 1.0
		if spares < int(_known.get("spares", 0)) + 4: spares += 1

## New spare racks and air reserve racks arrive full.
func take_delivery(inv: Dictionary) -> void:
	var air := 0.0
	var air_caps: Dictionary = data().breach.reserve_air_kg
	var spare_caps: Dictionary = data().breakdowns.spares_per_rack
	var spare_cap := 0
	for item in inv.all_items:
		air += float(air_caps.get(str(item.id), 0.0))
		spare_cap += int(spare_caps.get(str(item.id), 0))
	if air > float(_known.get("air", 0.0)): air_reserve_kg += air - float(_known.get("air", 0.0))
	if spare_cap > int(_known.get("spares", 0)): spares += spare_cap - int(_known.get("spares", 0))
	_known = {"air": air, "spares": spare_cap}
	air_reserve_kg = minf(air_reserve_kg, air)
	spares = mini(spares, spare_cap + 4)

func broken_labels() -> Array:
	var out: Array = []
	for key in broken: out.append(str(EquipmentCatalog.get_entry(str(broken[key].id)).get("label", broken[key].id)))
	return out

# ---------- events ----------

## A solar particle event: a short warning, then a day of high radiation.
func forecast_spe(warning := -1.0) -> void:
	spe_eta = warning if warning >= 0.0 else float(value("radiation", "warning_hours", .5))

func start_blackout(sols: float) -> void:
	blackout_hours_left = sols * 24.0

func spe_active() -> bool:
	return spe_hours_left > 0.0

## Everyone in the shelter during an event (for where the crew are).
func shelter_index(inv: Dictionary) -> int:
	if not spe_active(): return -1
	var place := shelter(inv)
	return int(place.get("index", -1))

# ---------- each step ----------

var _delivered_inv: Dictionary = {}

func pre_step(dt: float, _hour: float, inv: Dictionary) -> void:
	if not is_same(_delivered_inv, inv):
		take_delivery(inv)
		_delivered_inv = inv
	if blackout_hours_left > 0.0: blackout_hours_left = maxf(0.0, blackout_hours_left - dt)
	if spe_eta >= 0.0:
		spe_eta -= dt
		if spe_eta <= 0.0:
			spe_eta = -1.0
			spe_hours_left = float(value("radiation", "event_hours", 24.0))
			event_dose_msv = 0.0
	if not live_kinds.is_empty() and sim.crew_count() > 0:
		if live_kinds.has("spe") and spe_eta < 0.0 and not spe_active() and rng.randf() < float(value("live", "spe_per_100_sols", 1.0)) / 100.0 / 24.0 * dt: forecast_spe()
		if live_kinds.has("breach") and breach.is_empty() and rng.randf() < float(value("live", "breach_per_100_sols", .5)) / 100.0 / 24.0 * dt:
			var candidates: Array = (inv.rooms as Array).filter(func(r): return not str(r.kind) in ["airlock", "vehicle_bay"])
			if not candidates.is_empty(): start_breach(inv, str(candidates[rng.randi() % candidates.size()].key))
	_breach_step(dt, inv)
	_breakdown_step(dt, inv)

## After the habitat step: radiation, fitness, wellbeing, injuries, work.
## Returns {harm, causes} for crew health.
func post_step(dt: float, inv: Dictionary, tiers: Dictionary, crew_n: int, research_per_sol: float) -> Dictionary:
	var per_sol := dt / 24.0
	var out := {"harm": 0.0, "causes": []}
	if crew_n <= 0: return out
	# Radiation (one crew dose).
	var background := float(value("radiation", "background_msv_per_sol", .3)) * per_sol
	dose_msv += background
	if spe_active():
		var hours := float(value("radiation", "event_hours", 24.0))
		var event := float(value("radiation", "event_dose_msv", 150.0)) * minf(dt, spe_hours_left) / hours
		var place := shelter(inv)
		var factor := 1.0
		if not place.is_empty():
			var inside := minf(1.0, float(place.capacity) / maxf(1.0, crew_n))
			factor = inside * dose_factor(float(place.rating)) + (1.0 - inside)
		dose_msv += event * factor
		event_dose_msv += event * factor
		worst_event_msv = maxf(worst_event_msv, event_dose_msv)
		spe_hours_left = maxf(0.0, spe_hours_left - dt)
	# Air pressure.
	if pressure_pct(inv) < float(data().breach.danger_pct):
		out.harm = 5.0
		(out.causes as Array).append("air pressure low")
	# Work done (research), at the team's speed.
	research_done += research_per_sol * team_speed() * per_sol
	if not crew_on: return out
	ensure_crew(crew_n)
	var f: Dictionary = data().fitness
	_needs_age += dt
	if _needs_age >= 1.0 or not is_same(_needs_inv, inv) or _needs_cache.is_empty():
		_needs_cache = needs(inv, tiers)
		_stations_cache = (inv.items as Array).filter(func(i): return FITNESS_ITEMS.has(str(i.id)) and not is_broken(i)).size()
		_medical_cache = medical_ready(inv, {4: true})
		_needs_age = 0.0
		_needs_inv = inv
	# Exercise and treatment need power (labs and galley tier) at the time.
	var powered := bool(tiers.get(4, false))
	var stations := _stations_cache if powered else 0
	var healthy := crew.filter(func(p): return float(p.injured_h) <= 0.0).size()
	var coverage := minf(1.0, stations * float(f.crew_per_station) / maxf(1.0, healthy))
	var medical := _medical_cache and powered
	var need_list := _needs_cache
	var drift := per_sol / maxf(.1, float(value("wellbeing", "drift_sols", 5.0)))
	for p in crew:
		var hurt := float(p.injured_h) > 0.0
		var change := -float(f.loss_per_sol) + (0.0 if hurt else float(f.exercise_gain_per_sol) * coverage)
		p.fitness = clampf(float(p.fitness) + change * per_sol, 0.0, 100.0)
		var target := wellbeing_target(need_list, p, inv)
		p.wellbeing = clampf(float(p.wellbeing) + (target - float(p.wellbeing)) * minf(1.0, drift), 0.0, 100.0)
		if hurt and medical:
			p.injured_h = maxf(0.0, float(p.injured_h) - dt)
			if float(p.injured_h) <= 0.0: injuries_recovered += 1
	return out

## One reading for graphs and Test checks.
func sample(inv: Dictionary) -> Dictionary:
	return {"dose_msv": dose_msv, "event_dose_msv": event_dose_msv, "pressure_pct": pressure_pct(inv), "fitness": lowest_fitness() if crew_on and not crew.is_empty() else 100.0,
		"wellbeing": average_wellbeing() if crew_on and not crew.is_empty() else 100.0, "down_h": worst_down_hours, "broken": broken.size(), "spares": spares,
		"spe": spe_active(), "breach": not breach.is_empty() and float(breach.patched_at) < 0.0, "blackout": blackout_hours_left > 0.0, "injured": injured().size()}
