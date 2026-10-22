extends SceneTree

# More cargo over time: starting budgets per mode, Mars-made (printed)
# material paying for printable things first, the regolith printer in the
# simulation, and resupply landers (switched off; still work when switched on).
# Run with: godot --headless --path . --script res://tests/cargo_supply_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": cells.size() * 800}

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"
	# Budgets per mode.
	MHGame.resupply_kg = 0; MHGame.resupply_count = 0
	MHGame.game_mode = "survival"
	_check(MHGame.cargo_budget() == 100000, "Survival starts with 100 t (%d)" % MHGame.cargo_budget())
	MHGame.game_mode = "freedom"
	_check(MHGame.cargo_budget() == 140000, "Freedom starts with 140 t (%d)" % MHGame.cargo_budget())
	MHGame.resupply_kg = 20000
	_check(MHGame.cargo_budget() == 160000, "resupplies add to the budget")
	MHGame.resupply_kg = 0
	MHGame.game_mode = "survival"
	_check(not MHGame.resupplies_on(), "Earth resupply is switched off: the printer grows the base")
	_check(is_equal_approx(MHGame.resupply_interval_sols(), 3.0) and MHGame.resupply_size_kg() == 15000, "Survival: 15 t every 3 sols")

	# Mars-made material pays for printable things first.
	var world := Node3D.new(); root.add_child(world)
	await process_frame
	var b := BuildController.new(); b.display_only = true; world.add_child(b)
	await process_frame
	b.zones = [_room("storage", 0, 0, 2, 2), _room("engineering", 2, 0, 2, 2), {"kind": "airlock", "cells": [Vector2i(0, 2)], "door_direction": Vector2i(0, 1), "cost": 1500}]
	b._rebuild()
	var total := b._total_cargo()
	_check(b.used_cargo() == total, "with nothing printed, Earth cargo pays for everything")
	_check(b.printable_cargo() == 6400, "rooms are printable, the airlock isn't (%d)" % b.printable_cargo())
	b.simulation().printed_kg = 4000.0
	_check(b.used_cargo() == total - 4000 and b.mars_made_left() == 0, "printed material pays for room shells first")
	b.simulation().printed_kg = 9000.0
	_check(b.used_cargo() == total - 6400 and b.mars_made_left() == 2600, "only printable things can use it; the rest stays in stock")
	_check(b.earth_cost(800, true) == 0 and b.earth_cost(3000, true) == 400 and b.earth_cost(800, false) == 800, "new printable things use the stock first")
	_check(b.item_printable("open_shelving") and not b.item_printable("battery_bank"), "shelving can be printed, batteries can't")
	_check(b.zone_printable("living") and not b.zone_printable("airlock") and not b.zone_printable("regolith_intake"), "room shells print; airlocks and machines don't")

	# The printer in the simulation: needs power, its switch on, and an intake.
	b.simulation().printed_kg = 0.0
	b.placed_interior = [{"placement_id": "p1", "id": "regolith_printer", "position": Vector3(1.5, b.habitat_base_y, 1.5), "zone_cell": Vector2i(0, 0), "rotation_y": 0.0, "state": {}},
		{"placement_id": "p2", "id": "battery_bank", "position": Vector3(7.5, b.habitat_base_y, 1.5), "zone_cell": Vector2i(2, 0), "rotation_y": 0.0, "state": {}}]
	MHGame.debug_free_power = true
	b.simulation().invalidate()
	b.simulation().run_hours(24.0, 8.0)
	_check(is_zero_approx(b.simulation().printed_kg), "no intake, no printing")
	b.zones.append({"kind": "regolith_intake", "cells": [Vector2i(8, 8)], "cost": 900})
	b._rebuild()
	b.simulation().invalidate()
	b.simulation().run_hours(24.0, 8.0)
	_check(absf(b.simulation().printed_kg - 2500.0) < 40.0, "a powered printer with an intake prints about 2,500 kg a sol (%d)" % roundi(b.simulation().printed_kg))
	b.placed_interior[0].state = {"print": false}
	b.simulation().invalidate()
	var before: float = b.simulation().printed_kg
	b.simulation().run_hours(24.0, 8.0)
	_check(is_equal_approx(b.simulation().printed_kg, before), "a switched-off printer prints nothing")
	b.placed_interior[0].state = {}
	b.placed_interior.append({"placement_id": "p3", "id": "recycling_hopper_plastics", "position": Vector3(1.5, b.habitat_base_y, 4.5), "zone_cell": Vector2i(0, 1), "rotation_y": 0.0, "state": {}})
	b.simulation().invalidate()
	_check(is_equal_approx(b.simulation().print_rate(b.simulation().inventory()), 3125.0), "a plastics recycling hopper speeds printing up by 25%")
	var saved: Dictionary = b.simulation().save()
	_check(is_equal_approx(float(saved.printed_kg), b.simulation().printed_kg), "printed material is saved")
	MHGame.debug_free_power = false
	world.queue_free()
	await process_frame

	# Resupply landers in the real world: none while switched off...
	MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var mars: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(mars)
	for i in 5: await process_frame
	mars._intro_stage = "done"
	var budget := MHGame.cargo_budget()
	mars.builder.simulation().hours_run = 3.0 * 24.0 + 1.0
	mars._check_resupply()
	_check(MHGame.resupply_count == 0, "no resupply lands while switched off")
	# ...and they still work when the balance sheet switches them on.
	MHResources.data().settings["resupply_enabled"] = 1.0
	mars.builder.simulation().hours_run = 0.0
	mars._check_resupply()
	_check(MHGame.resupply_count == 0, "nothing lands before the launch window")
	mars.builder.simulation().hours_run = 3.0 * 24.0 + 1.0
	mars._check_resupply()
	_check(MHGame.resupply_count == 1 and MHGame.cargo_budget() == budget + 15000, "a resupply lands on time and adds 15 t")
	_check(mars.resupply_landers.size() == 1 and mars.find_children("ResupplyLander*", "", true, false).size() == 1, "the resupply lander stays on site")
	var landed: Vector3 = mars.resupply_landers[0].position
	_check(not mars.builder.is_inside(landed) and Vector2(landed.x, landed.z).distance_to(Vector2(mars.lander.global_position.x, mars.lander.global_position.z)) > 15.0, "it lands clear of the habitat and the crew lander")
	mars._check_resupply()
	_check(MHGame.resupply_count == 1, "one lander per window")
	var state: Dictionary = mars.current_state()
	_check(int(state.resupply.count) == 1 and int(state.resupply.kg) == 15000 and (state.resupply.landers as Array).size() == 1, "resupplies are saved with the base")
	mars.queue_free()
	await process_frame
	MHGame.pending_save_state = state
	mars = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(mars)
	for i in 5: await process_frame
	_check(MHGame.resupply_count == 1 and MHGame.resupply_kg == 15000 and mars.resupply_landers.size() == 1, "and loaded back, lander and all")
	mars.queue_free()
	await process_frame
	MHGame.pending_save_state = {}
	mars = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(mars)
	for i in 3: await process_frame
	_check(MHGame.resupply_count == 0 and MHGame.resupply_kg == 0, "a new game starts with no resupplies")
	mars.queue_free()

	# Missions: the printer and intake arrive in Mission 6.
	MHGame.game_mode = "missions"
	MHMissions.reset()
	MHMissions.progress.current = "storm_season"
	_check(not MHMissions.item_unlocked("regolith_printer") and not MHMissions.zone_unlocked("regolith_intake"), "no printer before Mission 6")
	MHMissions.progress.current = "self_sufficiency"
	_check(MHMissions.item_unlocked("regolith_printer") and MHMissions.zone_unlocked("regolith_intake"), "Mission 6 delivers the printer and intake")
	MHGame.game_mode = "survival"
	MHResources.data().settings["resupply_enabled"] = 0.0
	if failures == 0:
		print("Cargo supply test passed: budgets, Mars-made material, the printer, switchable resupply landers, saving and Mission 6.")
	quit(1 if failures > 0 else 0)
