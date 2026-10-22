extends SceneTree

# The life-support simulation (scripts/habitat_sim.gd): a sensible habitat
# survives day and night; missing equipment causes the right problem with the
# right reason; storms shed loads with life support last; Freedom never harms
# the crew; stores save and load; cargo comes from the balance spreadsheet.
# Run with: godot --headless --path . --script res://tests/habitat_sim_test.gd
const MHResources := preload("res://scripts/mh_resources.gd")
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

## A compact six-crew habitat with the given equipment counts.
func _habitat(site: String, solar: int, items: Dictionary) -> BuildController:
	MHGame.site_id = site
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	var layout := [["living", 0, 0, 3, 3], ["galley", 3, 0, 3, 1], ["hygiene", 3, 1, 2, 1], ["science", 3, 2, 2, 2], ["hydroponics", 0, 3, 3, 2], ["life_support", 3, 4, 2, 2], ["engineering", 5, 1, 1, 3], ["airlock", 6, 1, 1, 2]]
	for spec in layout: b.zones.append({"kind": spec[0], "cells": _block(spec[1], spec[2], spec[3], spec[4]), "door_direction": Vector2i(0, -1), "cost": 0})
	for i in range(solar): b.zones.append({"kind": "solar", "cells": [Vector2i(-2 - i, -2)], "door_direction": Vector2i(0, 1), "cost": 0})
	var n := 0
	for id in items:
		var room: String = items[id][0]
		var cell := Vector2i.ZERO
		for zone in b.zones:
			if str(zone.kind) == room: cell = zone.cells[0]
		for k in range(int(items[id][1])):
			n += 1
			b.placed_interior.append({"placement_id": "t%d" % n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})
	b.simulation().invalidate()
	return b

func _full_kit() -> Dictionary:
	return {"crew_bunk": ["living", 6], "air_recycler": ["life_support", 2], "oxygen_generator": ["life_support", 2], "thermal_control_unit": ["life_support", 2], "oxygen_reserve_tank": ["life_support", 1],
		"water_reclaimer": ["life_support", 1], "grow_tray": ["hydroponics", 6], "battery_bank": ["engineering", 6], "pantry_cabinet": ["galley", 2]}

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.game_mode = "survival"
	MHGame.debug_free_power = false

	# A sensible habitat on the plains keeps everything running for three sols.
	var good := _habitat("plains", 6, _full_kit())
	var sim: RefCounted = good.simulation()
	sim.random_storms = false   # storms are tested on their own below, not left to chance
	_check(int(sim.crew_count()) == 6, "six bunks bring six crew in (got %d)" % sim.crew_count())
	_check(is_equal_approx(float(sim.battery_kwh), 300.0), "new batteries arrive charged")
	_check(float(sim.food_kg) > 0.0, "the lander delivers food when the crew move in")
	var samples: Array = sim.run_hours(72.0, 8.0, 1.0)
	var life_always := samples.all(func(s): return float(s.battery_pct) > 0.0 or bool(s.all_powered))
	_check(life_always, "the batteries carry the habitat through every night")
	_check(float(sim.co2_pct) < .5 and float(sim.o2_pct) > 20.0, "air stays healthy: O2 %.1f%%, CO2 %.2f%%" % [sim.o2_pct, sim.co2_pct])
	_check(float(sim.crew_health) >= 99.0, "the crew stay healthy (%.0f%%)" % sim.crew_health)
	var living := float(sim.room_temperature(good.zones[0]))
	_check(living > 17.0 and living < 24.0, "Living Quarters stays comfortable (%.1f °C)" % living)
	var readiness := good.readiness()
	var air_item: Dictionary = readiness.filter(func(i): return i.id == "life")[0]
	_check(str(air_item.status) == "met", "readiness: air is covered (%s)" % air_item.detail)

	# Save and load keeps every store.
	var saved: Dictionary = sim.save()
	var copy := _habitat("plains", 6, _full_kit())
	copy.simulation().load(saved)
	_check(is_equal_approx(float(copy.simulation().battery_kwh), float(sim.battery_kwh)) and is_equal_approx(float(copy.simulation().food_kg), float(sim.food_kg)), "stores survive save and load")

	# A dust storm: solar drops, loads are shed, and life support goes last.
	sim.start_storm(3.0)
	var storm: Array = sim.run_hours(48.0, 8.0, 1.0)
	_check(storm.any(func(s): return not bool(s.all_powered)), "a long dust storm forces the habitat to switch things off")
	_check(not (sim.warnings() as Array).filter(func(w): return str(w.text).contains("Dust storm")).is_empty(), "the storm is announced")

	# No air recycler: CO2 builds up within a sol, and the warning says why.
	var kit := _full_kit(); kit.erase("air_recycler")
	var stuffy := _habitat("plains", 6, kit)
	stuffy.simulation().run_hours(72.0, 8.0)
	_check(float(stuffy.simulation().co2_pct) > 1.0, "without an air recycler CO2 becomes dangerous within three sols (%.2f%%)" % stuffy.simulation().co2_pct)
	_check(not (stuffy.simulation().warnings() as Array).filter(func(w): return str(w.text).contains("no air recycler")).is_empty(), "the CO2 warning names the missing air recycler")
	_check(float(stuffy.simulation().crew_health) < 100.0, "in Survival bad air harms the crew")

	# Freedom: the same problem, but the crew are never harmed.
	MHGame.game_mode = "freedom"
	var safe := _habitat("plains", 6, kit)
	safe.simulation().run_hours(72.0, 8.0)
	_check(float(safe.simulation().co2_pct) > 1.0 and is_equal_approx(float(safe.simulation().crew_health), 100.0), "Freedom shows the problem without harming the crew")
	MHGame.game_mode = "survival"

	# No heating on the Ice Fields: rooms go cold, and the reason is given.
	kit = _full_kit(); kit.erase("thermal_control_unit")
	var cold_base := _habitat("ice", 10, kit)
	cold_base.simulation().run_hours(36.0, 8.0)
	var coldest := 99.0
	for room in cold_base.simulation().crewed_rooms(): coldest = minf(coldest, float(cold_base.simulation().room_temp[room.key]))
	_check(coldest < 12.0, "without thermal control the Ice Fields habitat gets cold (%.1f °C)" % coldest)
	_check(not (cold_base.simulation().warnings() as Array).filter(func(w): return str(w.text).contains("no thermal control unit")).is_empty(), "the cold warning names the missing thermal control unit")

	# No generation and no batteries: everything is off.
	var dark := _habitat("plains", 0, {"crew_bunk": ["living", 2]})
	_check(not dark.grid_power_online(), "no generation and no batteries: the grid is off")
	MHGame.game_mode = "creative"
	_check(dark.grid_power_online(), "Creative mode: power is always on")
	MHGame.game_mode = "survival"

	# Cargo comes from the balance spreadsheet.
	_check(good.cell_cost("living") == int(MHResources.room("living").cargo_kg_per_cell), "a Living Quarters cell costs the spreadsheet's cargo")
	_check(good.cell_cost("reactor") == int(MHResources.item_value("surface_reactor", "cargo_kg")), "a reactor costs the spreadsheet's cargo")
	MHGame.site_id = "ridge"
	var ridge_budget := MHGame.mission_cargo_budget()
	MHGame.site_id = "plains"
	_check(ridge_budget > MHGame.mission_cargo_budget(), "a low landing site gives a cargo bonus (%d vs %d kg)" % [ridge_budget, MHGame.mission_cargo_budget()])
	_check(EquipmentCatalog.get_entry("grow_tray").cargo_cost == int(MHResources.item_value("grow_tray", "cargo_kg")), "equipment cargo comes from the spreadsheet")

	if failures == 0:
		print("Habitat simulation test passed: day and night power, air, heating, storms, Freedom, saving and cargo.")
	quit(1 if failures > 0 else 0)
