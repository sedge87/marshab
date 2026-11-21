extends SceneTree

# A4, several bases (docs/bases-and-vehicles.md; scripts/bases.gd,
# scripts/base_pieces.gd, scripts/walker.gd):
# - levels: rooms that touch share a floor; a room touching two levels is
#   refused; a corridor between two levels climbs (a ramp, or a ship's ladder
#   when short), straight only, a storey at most; you're inside it at the
#   height of its floor;
# - a second walker: a spot on unexplored ground is refused; marked, it walks
#   there on game time; there, the plan offers its core and airlock on its
#   own base; set down, it kneels and folds in, and its core runs its own
#   life support; you build only near the core;
# - upgrades are per base; the store is shared;
# - refolding: the base packs away, traces stay, the walker stands up ready,
#   its upgrades kept; it can go again;
# - the landing pad: one only, it makes the main base, and that base won't
#   refold;
# - saved and loaded; an older save loads as one base.
# godot --headless --path . --script res://tests/bases_test.gd
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const RULES := preload("res://scripts/build_rules.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	return world

func _place(builder: Node, cells: Array, extra := {}) -> Dictionary:
	var zone := {"kind": builder.kind, "cells": cells, "door_direction": builder.airlock_direction, "cost": builder._zone_cost(cells)}
	zone.merge(extra, true)
	RULES.placed(builder, zone)
	builder.zones.append(zone)
	builder._history.append({"type": "zone", "zone": zone})
	builder._rebuild()
	return zone

## Runs a walker on (its clock with it) until `done` holds.
func _run(walker: Node, seconds: float, done: Callable, hours_per_step := .05) -> bool:
	var t := 0.0
	while t < seconds:
		MHGame.sol_hour = fmod(MHGame.sol_hour + hours_per_step, 24.0)
		walker._process(.5)
		t += .5
		if done.call(): return true
	return false

## The core and its airlock set down on the plan's base (the player's there).
func _set_down(world: Node, walker: Node, at: Vector3) -> bool:
	var builder: Node = world.builder
	var player: Node3D = world.player
	player.global_position = at + Vector3(14.0, 2.0, 14.0)
	builder.refresh_here()
	if RULES.stage(builder) != "set_down": return false
	builder.kind = "general"
	var cells: Array = []
	for r in [0.0, 6.0, 12.0, 18.0]:
		for k in 8:
			var p: Vector3 = at + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * r
			var c := Vector2i(roundi(p.x / builder.CELL), roundi(p.z / builder.CELL))
			var try: Array = builder._cells(c, c)
			if builder._invalid_reason(try).is_empty(): cells = try
			if not cells.is_empty(): break
		if not cells.is_empty(): break
	if cells.is_empty():
		print("  no core spot: ", builder._invalid_reason(builder._cells(Vector2i(roundi(at.x / 3.0), roundi(at.z / 3.0)), Vector2i(roundi(at.x / 3.0), roundi(at.z / 3.0)))))
		return false
	_place(builder, cells)
	builder.kind = "airlock"
	var lock: Array = []
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not lock.is_empty(): break
			builder.airlock_direction = d
			if builder._invalid_reason([c + d]).is_empty(): lock = [c + d]
	if lock.is_empty(): return false
	_place(builder, lock)
	builder._toggle()
	builder._toggle()
	return _run(walker, 900.0, func(): return walker.state == "done")

func _initialize() -> void:
	var world = await _new_world()
	var builder: Node = world.builder
	var B := MHBases
	builder.refresh_here()
	_check(builder.bases.has("w1") and bool(builder.bases.w1.landing), "a new game has the first base, on the landing pad's area")

	# ---------- levels ----------
	var y0 := float(builder._proposed_base_y([Vector2i(10, 0)]))
	builder.kind = "living"
	var room_a := _place(builder, [Vector2i(10, 0), Vector2i(11, 0)])
	_check(absf(B.zone_y(builder, room_a) - y0) < .01 and str(room_a.base) == "w1", "a room gets its base and its floor (%.2f)" % B.zone_y(builder, room_a))
	var next := B.level_for(builder, [Vector2i(12, 0)], "living")
	_check(absf(float(next.y) - y0) < .01, "a room touching it shares its floor")
	# Two rooms on different floors, by hand (the pad is flat), and pieces between.
	builder.zones.append({"kind": "storage", "cells": [Vector2i(10, 4), Vector2i(11, 4)], "door_direction": Vector2i(0, -1), "cost": 0, "base": "w1", "y": y0 + 2.4})
	var between := B.level_for(builder, [Vector2i(10, 1), Vector2i(10, 2), Vector2i(10, 3)], "living")
	_check(str(between.reason).contains("different levels"), "a room touching two levels is refused: %s" % between.reason)
	var climb := B.corridor_levels(builder, [Vector2i(10, 1), Vector2i(10, 2), Vector2i(10, 3)])
	_check((climb.rise as Array).size() == 2 and absf(float(climb.rise[0]) - y0) < .01 and absf(float(climb.rise[1]) - y0 - 2.4) < .01, "a corridor between them climbs from one floor to the other")
	var bent := B.corridor_levels(builder, [Vector2i(10, 1), Vector2i(10, 2), Vector2i(11, 2), Vector2i(11, 3)])
	_check(str(bent.reason).contains("straight"), "a corridor that climbs runs straight")
	builder.zones[builder.zones.size() - 1]["y"] = y0 + 4.0
	var too_far := B.corridor_levels(builder, [Vector2i(10, 1), Vector2i(10, 2), Vector2i(10, 3)])
	_check(str(too_far.reason).contains("storey"), "more than a storey is refused")
	builder.zones[builder.zones.size() - 1]["y"] = y0 + 2.4
	var ramp_zone := {"kind": "corridor", "cells": [Vector2i(10, 1), Vector2i(10, 2), Vector2i(10, 3)], "door_direction": Vector2i(0, 1), "cost": 0, "base": "w1", "y": y0, "rise": [y0, y0 + 2.4]}
	_check(B.is_ramp(ramp_zone), "2.4 m over three cells is a ramp")
	_check(not B.is_ramp({"cells": [Vector2i(0, 0)], "rise": [0.0, 2.4]}), "over one cell it's a ship's ladder")
	builder.zones.append(ramp_zone)
	builder._rebuild()
	var mid_y := B.corridor_point_y(builder, ramp_zone, Vector2(30.0, 6.0))
	_check(mid_y > y0 + .8 and mid_y < y0 + 1.6, "half way up, the floor's half way up (%.2f)" % (mid_y - y0))
	_check(builder.is_inside(Vector3(30.0, mid_y + 1.0, 6.0)) and not builder.is_inside(Vector3(30.0, y0 + 2.4 + 3.2, 6.0)), "inside the ramp at its floor's height, not above its roof")
	_check(builder.is_inside(Vector3(31.5, y0 + 2.4 + 1.0, 12.0)) and not builder.is_inside(Vector3(31.5, y0 + 1.0, 12.0)), "the upper room is inside at its own floor")
	var ramp_bodies: Array = builder.root.find_children("*", "StaticBody3D", true, false).filter(func(n): return n.get_child_count() > 0 and n.get_child(0) is MeshInstance3D and (n.get_child(0) as MeshInstance3D).mesh is ArrayMesh)
	_check(ramp_bodies.size() >= 4, "the climbing corridor is built (%d pieces)" % ramp_bodies.size())
	# Clear the test rooms.
	builder.zones.clear()
	builder._history.clear()
	builder._rebuild()

	# ---------- a second walker ----------
	var lander: Vector3 = world.lander.global_position
	var known: Node = world.known
	var region: Vector2 = Vector2(lander.x + 420.0, lander.z) + known.origin
	var ok_spot: Vector2 = MHBaseSite.nearest_valid(region.x, region.y, 300.0, 24.0)
	_check(not is_inf(ok_spot.x), "there's a spot a few hundred metres out")
	var spot: Vector2 = ok_spot - known.origin
	var w2: Node3D = world.add_walker("w2", lander + Vector3(30.0, 0, 30.0))
	_check(w2 != null and w2.state == "ready" and w2.base_id == "w2", "a second walker, ready")
	_check(w2.spot_reason(spot).begins_with("Only ground you've explored"), "not to ground you haven't explored")
	known.reveal(spot + known.origin, 200.0)
	_check(w2.spot_reason(Vector2(lander.x + 40.0, lander.z)).contains("Too close"), "not on top of another base")
	_check(w2.spot_reason(spot) == "", "explored and flat enough: %s" % w2.spot_reason(spot))
	_check(world.region_map.mark_walker_spot(world.region_map._region_to_map(spot + known.origin)) != "sent", "W on the Map checks the spot first")
	_check(world.region_map.mark_walker_spot(world.region_map._region_to_map(spot + known.origin)) == "sent" and w2.state == "travelling", "W again sends it")
	_check(builder.bases.has("w2") and (builder.bases.w2.centre as Vector2).distance_to(spot) < 1.0, "its base is founded at the spot")
	var there := _run(w2, 3000.0, func(): return w2.state == "parked", .05)
	_check(there and Vector2(w2.global_position.x - spot.x, w2.global_position.z - spot.y).length() < 2.0, "it walks there on its own and parks")
	var target := Vector3(spot.x, MHSiteTerrain.height(spot.x, spot.y), spot.y)
	_check(_set_down(world, w2, target), "there, its core and airlock go down on its own base")
	var core2: Dictionary = RULES.module_zone(builder, "w2")
	_check(not core2.is_empty() and str(core2.base) == "w2" and absf(float(core2.y) - B.base_y(builder, "w2")) < .01, "the core sets the base's height (%.1f m)" % B.base_y(builder, "w2"))
	await create_timer(4.0).timeout
	_check(not w2.visible, "folded into its core: nothing left standing")
	_check(world.cores.has("w2") and world.cores.w2.running() and bool(world.cores.w2.commissioned), "its core runs its own life support, commissioned")
	_check(world.cores.has("w2") and not is_same(world.cores.w2, world.module_life), "apart from Walker 1's")
	# ---------- the hull (power + hull, 21 Nov) ----------
	var life2: Node = world.cores.w2
	_check(not life2.wall_spots().is_empty(), "the core has outer walls a leak can open on")
	life2.core.hull_pct = 65.0
	life2.advance(.1, 12.0)
	_check(life2.hull_leaks.size() == 1 and str(life2.hull_leaks[0].kind) == "seam" and life2.core.leaking(), "worn below 70%, a seam creaks open and leaks")
	seed(1)
	for i in 8: life2.hull_event("quake")
	var cracks: int = life2.hull_leaks.filter(func(l): return str(l.kind) == "crack").size()
	_check(cracks >= 1 and float(life2.core.hull_pct) < 65.0, "quakes knock the hull and crack panels (%d cracks, hull %d%%)" % [cracks, roundi(life2.core.hull_pct)])
	var saved: Dictionary = life2.export_state()
	_check((saved.hull_leaks as Array).size() == life2.hull_leaks.size(), "open leaks are saved")
	world.drop_field.tools = true
	var leak_node: Node = life2._leak_nodes[0]
	_check(str(leak_node.interaction_prompt().get("primary", "")) == "Patch it", "with the patch kit, E patches it (%s)" % str(leak_node.interaction_prompt()))
	var hull_before := float(life2.core.hull_pct)
	while not life2._leak_nodes.is_empty(): (life2._leak_nodes[0] as Node).interact()
	_check(life2.hull_leaks.is_empty() and not life2.core.leaking() and float(life2.core.hull_pct) > hull_before, "every leak patched: sealed, hull mended (%d%%)" % roundi(life2.core.hull_pct))
	builder.active_base = "w2"
	_check(B.cell_reason(builder, Vector2i(roundi((spot.x + 90.0) / 3.0), roundi(spot.y / 3.0))).begins_with("Too far"), "you build only near the core")
	_check(B.cell_reason(builder, Vector2i(roundi((spot.x + 20.0) / 3.0), roundi(spot.y / 3.0))) == "", "near it you can")
	# Upgrades are per base; the store is one.
	MHRoomTypes.fitted["w2"] = {"water_loop": true}
	_check(MHRoomTypes.is_fitted("water_loop", "w2") and not MHRoomTypes.is_fitted("water_loop", "w1"), "upgrades are fitted per base")

	# ---------- refolding ----------
	var before: int = builder.zones.size()
	MHRoomTypes.here = "w2"
	w2.refold()
	_check(RULES.module_zone(builder, "w2").is_empty() and builder.zones.size() < before, "refolded: its pieces pack away")
	_check(builder.traces.size() >= 1, "the printed footprints stay behind")
	_check(w2.state == "ready" and not world.cores.has("w2"), "the walker stands up, ready; its core's life support packs with it")
	_check(MHRoomTypes.is_fitted("water_loop", "w2"), "its upgrades go with it")
	var spot2: Vector2 = spot + Vector2(0, 200.0)
	var valid2: Vector2 = MHBaseSite.nearest_valid(spot2.x + known.origin.x, spot2.y + known.origin.y, 300.0, 24.0) - known.origin
	known.reveal(valid2 + known.origin, 200.0)
	_check(w2.send_to(valid2), "it can go again: %s" % w2.spot_reason(valid2))
	_check(_run(w2, 3000.0, func(): return w2.state == "parked", .05), "and walks to the new spot")
	_check(_set_down(world, w2, Vector3(valid2.x, MHSiteTerrain.height(valid2.x, valid2.y), valid2.y)), "and sets down there")

	# ---------- the landing pad ----------
	builder.refresh_here()
	builder.active_base = "w2"
	builder.kind = "landing_pad"
	builder.simulation().printed_kg += 2000.0   # printed regolith to pay for it
	var pad_cells: Array = []
	for r in [24.0, 33.0, 42.0]:
		for k in 8:
			var p: Vector2 = valid2 + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * r
			var try: Array = builder._cells(Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0)), Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0)))
			if pad_cells.is_empty() and builder._invalid_reason(try).is_empty(): pad_cells = try
	_check(pad_cells.size() == 36, "the landing pad is 6 × 6 cells and fits near the core")
	if pad_cells.size() == 36:
		_place(builder, pad_cells)
		_check(builder.main_base == "w2", "where it goes is the main base")
		RULES.plan_closed(builder)
		_check(not builder.refold_reason("w2").is_empty(), "the main base won't refold")
		builder.active_base = "w1"
		_check(BASE_PIECES_reason(builder).begins_with("There's one landing pad"), "one pad only")

	# ---------- saved and loaded ----------
	var state: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	var again = await _new_world(state)
	var b2: Node = again.builder
	_check(b2.bases.has("w2") and (b2.bases.w2.centre as Vector2).distance_to(valid2) < 1.0, "the bases are kept")
	_check(not RULES.module_zone(b2, "w2").is_empty() and absf(float(RULES.module_zone(b2, "w2").y) - B.base_y(b2, "w2")) < .01, "its core and floor are kept")
	_check(again.walkers.has("w2") and again.walkers.w2.state == "done" and not again.walkers.w2.visible, "the second walker's kept, folded in")
	_check(again.cores.has("w2"), "its core's life support is kept")
	_check(b2.main_base == "w2" and b2.traces.size() >= 1, "the main base and the traces are kept")
	# An older save: one base, every room at the one floor.
	var old: Dictionary = b2.export_habitat_state()
	old.erase("bases")
	old.erase("main_base")
	old["habitat_base_y"] = .9
	var zones_old: Array = []
	for z in old.zones:
		var plain: Dictionary = (z as Dictionary).duplicate(true)
		plain.erase("base"); plain.erase("y"); plain.erase("rise")
		zones_old.append(plain)
	old["zones"] = zones_old
	b2.restore_habitat_state(old)
	_check(b2.bases.size() == 1 and b2.zones.all(func(z): return str(z.base) == "w1" and absf(float(z.y) - .9) < .01), "an older save loads as one base at its one floor")
	again.queue_free()
	await process_frame
	if failures == 0:
		print("Bases test passed: levels (shared floors, a refused double join, a climbing corridor as ramp or ship's ladder, straight, a storey at most, inside at its floor); a second walker marked on the Map, walking there, set down on its own base, folded in, its own life support, building near its core; upgrades per base; refolded with traces and upgrades kept, sent again; the landing pad makes the main base, one only, and it won't refold; saved and loaded; an older save as one base.")
	quit(1 if failures > 0 else 0)

func BASE_PIECES_reason(builder: Node) -> String:
	return preload("res://scripts/base_pieces.gd").pad_reason(builder, "landing_pad", [Vector2i(0, 0)])
