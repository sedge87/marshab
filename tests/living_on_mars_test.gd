extends SceneTree

# Act 2 (Missions 7-10): radiation shelters, the crew as people (fitness,
# wellbeing, injuries), hull breaches and sections, breakdowns and spares.
# docs/missions-7-10-design.md section 7.
# A small base in a row: Living Quarters - corridor - Galley - Science Lab.
# Run with: godot --headless --path . --script res://tests/living_on_mars_test.gd
var failures := 0
var world: Node3D

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _block(x0: int, z0: int, w: int, d: int) -> Array:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d): cells.append(Vector2i(x, z))
	return cells

var _n := 0
func _add(b: BuildController, id: String, kind: String, count := 1) -> void:
	var cell := Vector2i.ZERO
	for zone in b.zones:
		if str(zone.kind) == kind: cell = zone.cells[0]
	for k in range(count):
		_n += 1
		b.placed_interior.append({"placement_id": "p%d" % _n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})

func _base(door := false) -> BuildController:
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	b.zones.append({"kind": "living", "cells": _block(0, 0, 2, 2), "door_direction": Vector2i(0, -1), "cost": 0})
	b.zones.append({"kind": "corridor", "cells": [Vector2i(2, 0), Vector2i(3, 0)], "door_direction": Vector2i(1, 0), "cost": 0})
	b.zones.append({"kind": "galley", "cells": _block(4, 0, 2, 2), "door_direction": Vector2i(0, -1), "cost": 0})
	b.zones.append({"kind": "science", "cells": _block(6, 0, 2, 1), "door_direction": Vector2i(0, -1), "cost": 0})
	if door: b.interior_doors.append({"cell": Vector2i(1, 0), "side": Vector2i(1, 0)})
	_add(b, "crew_bunk", "living", 6)
	_add(b, "thermal_control_unit", "galley", 2)
	_add(b, "oxygen_generator", "galley", 2)
	_add(b, "air_recycler", "galley", 2)
	b.simulation().invalidate()
	return b

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	# Freedom: shortages can't harm the crew, so the long runs aren't cut
	# short by an evacuation (this test has no water supply).
	MHGame.game_mode = "freedom"
	MHGame.site_id = "plains"
	MHGame.debug_free_power = true

	# ---- sections ----
	var open := _base()
	var sim = open.simulation()
	var inv: Dictionary = sim.inventory()
	var map: Dictionary = sim.life.sections(inv)
	_check(map[0] == map[1] and map[1] == map[2], "an open corridor joins Living Quarters, the corridor and the Galley into one section (%s)" % [map])
	_check(map[3] != map[2], "the Science Lab, behind a wall, is its own section")
	var hatched := _base(true)
	var map2: Dictionary = hatched.simulation().life.sections(hatched.simulation().inventory())
	_check(map2[0] != map2[1], "a hatch at the corridor end seals Living Quarters off (%s)" % [map2])

	# ---- breach ----
	sim.life.start_breach(inv, sim.life.default_breach_room(inv))
	sim.run_hours(3.0, 2.0, 1.0)
	_check(sim.life.pressure_pct(sim.inventory()) < 70.0, "open plan, no patch kit: a breach vents most of the air (%.0f%%)" % sim.life.pressure_pct(sim.inventory()))
	_add(hatched, "hull_patch_kit", "living")
	_add(hatched, "air_reserve_rack", "galley", 2)
	var hsim = hatched.simulation()
	hsim.invalidate()
	var hinv: Dictionary = hsim.inventory()
	hsim.life.take_delivery(hinv)
	_check(hsim.life.air_reserve_kg >= 119.0, "air reserve racks arrive full (%.0f kg)" % hsim.life.air_reserve_kg)
	hsim.life.start_breach(hinv, hsim.life.default_breach_room(hinv))
	var lowest := 100.0
	for i in range(80):
		hsim.run_hours(.1, 2.0, .1)
		lowest = minf(lowest, hsim.life.pressure_pct(hsim.inventory()))
	_check(lowest > 70.0, "a sealed section and a patch kit keep pressure above 70%% (lowest %.0f%%)" % lowest)
	_check(hsim.life.pressure_pct(hsim.inventory()) > 99.0, "and the air reserve refills it (%.0f%%)" % hsim.life.pressure_pct(hsim.inventory()))

	# ---- radiation shelter ----
	var shelter := _base(true)
	var ssim = shelter.simulation()
	_check(ssim.life.shelter(ssim.inventory()).is_empty(), "no locker, no shelter")
	_add(shelter, "storm_shelter_locker", "science")
	ssim.invalidate()
	var weak: Dictionary = ssim.life.shelter(ssim.inventory())
	_check(not weak.is_empty() and float(weak.rating) < 20.0 and not bool(weak.ok), "a locker alone makes a shelter, but a weak one (%s)" % [weak.get("rating")])
	_add(shelter, "regolith_shield_block", "science", 4)
	ssim.invalidate()
	var strong: Dictionary = ssim.life.shelter(ssim.inventory())
	_check(float(strong.rating) >= 20.0 and int(strong.capacity) >= 6, "four shield walls in a 2-square lab: %d points, room for %d" % [roundi(float(strong.rating)), int(strong.capacity)])
	ssim.life.forecast_spe(0.0)
	ssim.run_hours(26.0, 8.0, 1.0)
	_check(ssim.life.worst_event_msv < 50.0, "sheltered crew get under 50 mSv (%.0f)" % ssim.life.worst_event_msv)
	var exposed := _base()
	var esim = exposed.simulation()
	esim.life.forecast_spe(0.0)
	esim.run_hours(26.0, 8.0, 1.0)
	_check(esim.life.worst_event_msv > 100.0, "without a shelter they get far more (%.0f)" % esim.life.worst_event_msv)

	# ---- the crew as people ----
	var lazy := _base(true)
	var lsim = lazy.simulation()
	lsim.life.crew_on = true
	lsim.run_step = .5
	lsim.run_hours(30.0 * 24.0, 8.0, 24.0)
	_check(lsim.life.crew.size() == 6, "six named crew (%d)" % lsim.life.crew.size())
	_check(lsim.life.lowest_fitness() < 70.0, "30 sols without exercise: fitness falls below 70 (%.0f)" % lsim.life.lowest_fitness())
	var fit := _base(true)
	_add(fit, "exercise_station", "living", 2)
	var fsim = fit.simulation()
	fsim.invalidate()
	fsim.life.crew_on = true
	fsim.run_step = .5
	fsim.run_hours(30.0 * 24.0, 8.0, 24.0)
	_check(fsim.life.lowest_fitness() >= 70.0, "two exercise stations keep six crew fit (%.0f)" % fsim.life.lowest_fitness())
	var bare_needs: Array = lsim.life.needs(lsim.inventory(), {4: true})
	_check(bare_needs.size() == 6, "six needs")
	_add(fit, "common_table", "living", 2)
	_add(fit, "galley_oven", "galley")
	_add(fit, "plant_pot", "living")
	_add(fit, "photo_frame", "living", 3)
	fsim.invalidate()
	var met := (fsim.life.needs(fsim.inventory(), {4: true}) as Array).filter(func(n): return float(n.score) >= .9).size()
	var met_before := bare_needs.filter(func(n): return float(n.score) >= .9).size()
	_check(met > met_before, "tables, an oven, plants and photos meet more needs (%d -> %d)" % [met_before, met])
	var target_low: float = lsim.life.wellbeing_target(bare_needs, lsim.life.crew[0], lsim.inventory())
	var target_high: float = fsim.life.wellbeing_target(fsim.life.needs(fsim.inventory(), {4: true}), fsim.life.crew[0], fsim.inventory())
	_check(target_high > target_low, "and raise wellbeing (%.0f -> %.0f)" % [target_low, target_high])
	# Injury: recovers only with a Medical Bay.
	fsim.life.injure("engineer")
	fsim.run_hours(10.0 * 24.0, 8.0, 24.0)
	_check(not fsim.life.injured().is_empty(), "no Medical Bay: the Engineer doesn't recover")
	fit.zones.append({"kind": "medical", "cells": _block(0, 2, 2, 1), "door_direction": Vector2i(0, 1), "cost": 0})
	_add(fit, "medical_exam_cot", "medical")
	_add(fit, "medical_cabinet", "medical")
	fsim.invalidate()
	fsim.run_hours(9.0 * 24.0, 8.0, 24.0)
	_check(fsim.life.injured().is_empty(), "with an exam cot and a cabinet, they recover in 8 sols")

	# ---- breakdowns and spares ----
	var fragile := _base(true)
	var bsim = fragile.simulation()
	bsim.life.breakdowns_on = true
	bsim.life.breakdown_scale = 3000.0
	bsim.life.rng.seed = 3
	bsim.run_hours(12.0, 8.0, 1.0)
	_check(bsim.life.broken.size() > 0, "machines break (%d broken)" % bsim.life.broken.size())
	_check(bsim.life.worst_down_hours > 0.0, "with no spares, a whole system goes down")
	var spared := _base(true)
	_add(spared, "spare_parts_rack", "galley", 2)
	var rsim = spared.simulation()
	rsim.invalidate()
	rsim.life.take_delivery(rsim.inventory())
	_check(rsim.life.spares == 16, "two racks: 16 spares (%d)" % rsim.life.spares)
	rsim.life.breakdowns_on = true
	rsim.life.breakdown_scale = 200.0
	rsim.life.rng.seed = 7
	rsim.run_hours(48.0, 8.0, 1.0)
	_check(rsim.life.spares < 16, "repairs use spares (%d left)" % rsim.life.spares)

	# ---- saving ----
	var saved: Dictionary = fsim.save()
	var again = load("res://scripts/habitat_sim.gd").new(fit)
	again.load(saved)
	_check(again.life.crew.size() == 6 and str(again.life.crew[0].name) == str(fsim.life.crew[0].name), "the crew are saved by name")

	if failures == 0:
		print("Living on Mars test passed: sections and breaches, shelters and radiation, fitness, wellbeing, injuries, breakdowns, spares and saving.")
	quit(1 if failures > 0 else 0)
