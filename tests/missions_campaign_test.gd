extends SceneTree

# Missions 3–6 are winnable: a sensible base for each mission passes that
# mission's Test, and the rules around them hold (budgets, unlocks, crew).
# Run with: godot --headless --path . --script res://tests/missions_campaign_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
var failures := 0
var verbose := OS.get_cmdline_user_args().has("--verbose")

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _report(report: Dictionary) -> String:
	var lines: Array = []
	for r in report.results: lines.append(("PASS " if r.pass else "FAIL ") + str(r.text) + " :: " + str(r.detail))
	return "\n    ".join(lines)

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "missions"
	MHMissions.reset()
	var target: Vector2 = PICKER.suggested()
	var base := Vector2.INF
	for x in range(-45, 46, 3):
		for z in range(-45, 46, 3):
			var candidate := Vector2(x, z)
			if is_inf(base.x) and bool(MHMissions.check_landing(target, candidate).passed) and candidate.distance_to(target) < 35.0: base = candidate
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = base
	MHMissions.complete("landing_zones")
	_check(MHMissions.missions().all(func(m): return bool(m.get("available", false))), "every mission is available")
	var budgets := []
	for id in ["cargo_power_water", "cargo_habitat", "crew_land", "storm_season", "self_sufficiency"]:
		MHMissions.progress.current = id
		budgets.append(MHMissions.cargo_budget())
	_check(budgets == [12000, 32000, 42000, 48000, 62000], "each landing adds its payload: %s" % str(budgets))

	var world := Node3D.new(); root.add_child(world)
	await process_frame
	var b := BuildController.new(); b.display_only = true; world.add_child(b)
	await process_frame
	var c := Vector2i(roundi(base.x / 3.0), roundi(base.y / 3.0))
	var y := b.habitat_base_y

	# --- Mission 3: the habitat, no crew ---
	MHMissions.progress.current = "cargo_habitat"
	b.simulation().crew_cap = MHMissions.crew_cap()
	_check(MHMissions.crew_cap() == 0, "Mission 3 has no crew aboard")
	_check(MHMissions.zone_unlocked("life_support") and MHMissions.item_unlocked("thermal_control_unit") and not MHMissions.item_unlocked("crew_bunk"), "Mission 3 delivers Life Support, not bunks")
	b.zones = [_room("engineering", c, 0, 0, 2, 2), _room("life_support", c, 2, 0, 2, 2), _room("living", c, 4, 0, 2, 2),
		{"kind": "airlock", "cells": [c + Vector2i(0, 2)], "door_direction": Vector2i(0, 1), "cost": 0}]
	for i in 10: b.zones.append({"kind": "solar", "cells": [c + Vector2i(-2 - (i % 5) * 2, -4 - (i / 5) * 2)], "door_direction": Vector2i(0, 1), "cost": 0})
	b.zones.append({"kind": "ice_extractor", "cells": [_best_ice(b, c)], "cost": 0})
	b.zones.append({"kind": "ice_extractor", "cells": [_best_ice(b, c) + Vector2i(1, 0)], "cost": 0})
	b._rebuild()
	b.placed_interior = []
	_item(b, "battery_bank", c, 0, 0, 6)
	_item(b, "thermal_control_unit", c, 2, 0, 1)
	_item(b, "oxygen_generator", c, 2, 1, 1)
	_item(b, "air_recycler", c, 3, 0, 1)
	_item(b, "water_reclaimer", c, 3, 1, 1)
	b.simulation().invalidate()
	var m3 := MHMissions.run_test(b)
	if verbose or not bool(m3.passed): print("  Mission 3:\n    " + _report(m3))
	_check(bool(m3.passed), "a compact powered habitat passes Mission 3")

	# --- Mission 4: four crew land ---
	MHMissions.progress.current = "crew_land"
	b.simulation().crew_cap = MHMissions.crew_cap()
	_check(MHMissions.item_unlocked("crew_bunk") and MHMissions.item_unlocked("galley_rehydration_station") and not MHMissions.zone_unlocked("hydroponics"), "Mission 4 delivers the crew's furniture, not Hydroponics")
	b.zones.append(_room("galley", c, 6, 0, 2, 2))
	b.zones.append(_room("hygiene", c, 4, 2, 2, 1))
	b._rebuild()
	_item(b, "crew_bunk", c, 4, 0, 4)
	_item(b, "galley_rehydration_station", c, 6, 0, 1)
	_item(b, "hygiene_toilet", c, 4, 2, 1)
	b.simulation().invalidate()
	var m4 := MHMissions.run_test(b)
	if verbose or not bool(m4.passed): print("  Mission 4:\n    " + _report(m4))
	_check(bool(m4.passed), "a furnished habitat keeps four crew safe in Mission 4")

	# --- Mission 5: the storm ---
	MHMissions.progress.current = "storm_season"
	var m5_weak := MHMissions.run_test(b)
	if verbose: print("  Mission 5 (as built):\n    " + _report(m5_weak))
	_check(not bool(m5_weak.passed), "Mission 4's base doesn't simply pass Mission 5's planet-wide storm")
	b.zones.append({"kind": "reactor", "cells": [c + Vector2i(-6, 6)], "cost": 0})
	b._rebuild()
	b.simulation().invalidate()
	var m5 := MHMissions.run_test(b)
	if verbose or not bool(m5.passed): print("  Mission 5 (with a reactor):\n    " + _report(m5))
	_check(bool(m5.passed), "a reactor carries life support through Mission 5's storm")

	# --- Mission 6: six crew, 100 sols ---
	MHMissions.progress.current = "self_sufficiency"
	b.simulation().crew_cap = MHMissions.crew_cap()
	_check(MHMissions.deliver_mission_food(b.simulation()) and not MHMissions.deliver_mission_food(b.simulation()), "Mission 6's supply lander brings food, once")
	_check(MHMissions.crew_cap() == 6 and MHMissions.zone_unlocked("hydroponics"), "Mission 6 brings six crew and Hydroponics")
	b.zones.append(_room("hydroponics", c, 6, 2, 3, 2))
	b.zones.append(_room("science", c, 2, 2, 2, 1))
	b._rebuild()
	_item(b, "crew_bunk", c, 5, 1, 2)
	_item(b, "grow_tray", c, 6, 2, 8)
	_item(b, "oxygen_generator", c, 3, 1, 1)
	_item(b, "air_recycler", c, 3, 1, 1)
	_item(b, "science_workbench", c, 2, 2, 1)
	b.simulation().invalidate()
	var t0 := Time.get_ticks_msec()
	var m6 := MHMissions.run_test(b)
	if verbose or not bool(m6.passed): print("  Mission 6 (%d ms):\n    " % (Time.get_ticks_msec() - t0) + _report(m6))
	_check(bool(m6.passed), "a growing base passes Mission 6")

	# Weak designs fail: the missions have teeth.
	MHMissions.progress.current = "cargo_habitat"
	b.simulation().crew_cap = MHMissions.crew_cap()
	var all_items: Array = b.placed_interior.duplicate()
	b.placed_interior = all_items.filter(func(i): return i.id != "thermal_control_unit")
	b.simulation().invalidate()
	var no_heat := MHMissions.run_test(b)
	if verbose: print("  Mission 3 without heating:
    " + _report(no_heat))
	_check(not bool(no_heat.passed), "Mission 3 fails without a thermal control unit")
	MHMissions.progress.current = "storm_season"
	b.simulation().crew_cap = MHMissions.crew_cap()
	var all_zones: Array = b.zones.duplicate()
	var solar_seen := 0
	b.zones = all_zones.filter(func(z):
		if str(z.kind) == "reactor": return false
		if str(z.kind) == "solar":
			solar_seen += 1
			return solar_seen <= 6
		return true)
	var batteries_seen := 0
	b.placed_interior = all_items.filter(func(i):
		if i.id != "battery_bank": return true
		batteries_seen += 1
		return batteries_seen <= 1)
	b._rebuild()
	b.simulation().invalidate()
	var thin := MHMissions.run_test(b)
	if verbose: print("  Mission 5, little storage:
    " + _report(thin))
	_check(not bool(thin.passed), "Mission 5 fails with little energy storage")

	MHGame.game_mode = "survival"
	if failures == 0:
		print("Missions campaign test passed: budgets, unlocks, crew sizes, and Missions 3–6 winnable.")
	quit(1 if failures > 0 else 0)

func _room(kind: String, c: Vector2i, x: int, z: int, w: int, h: int) -> Dictionary:
	var cells := []
	for dx in range(w):
		for dz in range(h): cells.append(c + Vector2i(x + dx, z + dz))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 0}

## Records straight into the room (bypasses placement rules: this tests the
## simulation's balance, not furnishing).
func _item(b: BuildController, id: String, c: Vector2i, x: int, z: int, count: int) -> void:
	var cell := c + Vector2i(x, z)
	for i in count:
		b.placed_interior.append({"placement_id": "%s_%d_%d" % [id, i, b.placed_interior.size()], "id": id, "position": Vector3(cell.x * 3.0, b.habitat_base_y, cell.y * 3.0), "zone_cell": cell, "rotation_y": 0.0, "state": {}})

func _best_ice(b: BuildController, c: Vector2i) -> Vector2i:
	var best := c + Vector2i(8, 4)
	var richest := 0.0
	for x in range(-15, 16):
		for z in range(-15, 16):
			var r: float = b._ice_richness_at(Vector2i(x, z))
			if r > richest and not MHMissions.in_blast_zone(Vector2(x * 3, z * 3)): richest = r; best = Vector2i(x, z)
	return best
