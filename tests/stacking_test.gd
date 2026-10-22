extends SceneTree

# Small items (first aid kit, crates, plant pot) sit on tables, desks, counters
# and crates; big items stay on the floor; clearing a table takes its load too.
# Run with: godot --headless --path . --script res://tests/stacking_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"
	var world := Node3D.new(); root.add_child(world)
	await process_frame
	var b := BuildController.new(); b.display_only = true; world.add_child(b)
	await process_frame
	var cells := []
	for x in range(0, 4):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}]
	b._rebuild()
	var y := b.habitat_base_y
	var table_at := Vector3(4.5, y, 3.0)
	b.place_free_interior_equipment("common_table", table_at, 0.0, Vector2i(1, 1), b.free_interior_visual("common_table", table_at, 0.0))
	var top := y + .92
	_check(b.free_interior_invalid_reason("first_aid_kit", Vector3(4.2, top, 3.0), Vector3.UP, 0.0) == "", "a first aid kit sits on the table (%s)" % b.free_interior_invalid_reason("first_aid_kit", Vector3(4.2, top, 3.0), Vector3.UP, 0.0))
	_check(b.free_interior_invalid_reason("first_aid_kit", Vector3(4.2, top + .6, 3.0), Vector3.UP, 0.0) != "", "but not floating above it")
	_check(b.free_interior_invalid_reason("first_aid_kit", Vector3(4.2, y, 3.0), Vector3.UP, 0.0) != "", "and not inside it on the floor")
	_check(b.free_interior_invalid_reason("crew_bunk", Vector3(4.5, top, 3.0), Vector3.UP, 0.0) == "Place this on the floor", "a bunk can't go on a table")
	_check(b.free_interior_invalid_reason("supply_crate_large", Vector3(5.3, top, 3.0), Vector3.UP, 0.0) != "", "a crate hanging off the edge doesn't fit")
	var kit_at := Vector3(4.0, top, 3.0)
	b.place_free_interior_equipment("first_aid_kit", kit_at, 0.0, Vector2i(1, 1), b.free_interior_visual("first_aid_kit", kit_at, 0.0))
	_check(b.free_interior_invalid_reason("supply_crate_small", Vector3(4.1, top, 3.0), Vector3.UP, 0.0) == "Too close to existing equipment", "two things can't share one spot on the table")
	_check(b.free_interior_invalid_reason("supply_crate_small", Vector3(5.0, top, 3.0), Vector3.UP, 0.0) == "", "a crate fits beside the kit")
	# Crates stack on crates.
	var crate_at := Vector3(7.5, y, 3.0)
	b.place_free_interior_equipment("supply_crate_large", crate_at, 0.0, Vector2i(2, 1), b.free_interior_visual("supply_crate_large", crate_at, 0.0))
	_check(b.free_interior_invalid_reason("supply_crate_medium", Vector3(7.5, y + .59, 3.0), Vector3.UP, 0.0) == "", "a medium crate stacks on a large one")
	# Removing the table takes the kit with it.
	var table_id := str(b.placed_interior[0].placement_id)
	b.remove_free_interior_equipment(table_id)
	_check(b.placed_interior.size() == 1 and str(b.placed_interior[0].id) == "supply_crate_large", "clearing the table removes what was on it")
	if failures == 0:
		print("Stacking test passed: small items on tables and crates, big items on the floor, removal clears the top.")
	quit(1 if failures > 0 else 0)
