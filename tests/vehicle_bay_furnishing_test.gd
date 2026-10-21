extends SceneTree

# Bay, airlock and corridor equipment must place inside those zones. They are
# defined by cells, not outlines, so the footprint check has to read cells.
# Run with: godot --headless --path . --script res://tests/vehicle_bay_furnishing_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.game_mode = "creative"
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	await process_frame
	var room := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var bay := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)]
	var corridor := [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]
	b.zones = [
		{"kind": "living", "cells": room, "cost": 0, "door_direction": Vector2i(0, -1)},
		{"kind": "vehicle_bay", "cells": bay, "cost": 0, "door_direction": Vector2i(1, 0)},
		{"kind": "corridor", "cells": corridor, "cost": 0, "door_direction": Vector2i(0, -1)},
	]
	b._rebuild()
	await process_frame
	var y := b.habitat_base_y
	var cell := BuildController.CELL
	var bay_centre := Vector3(2.5 * cell, y, .5 * cell)
	for id in ["suit_rack", "rover_charger", "eva_tool_station", "cargo_rack", "tool_bench", "battery_bank", "supply_crate_small"]:
		var reason := b.free_interior_invalid_reason(id, bay_centre, Vector3.UP, 0.0)
		_check(reason.is_empty(), "%s places in the vehicle bay: %s" % [id, reason])
	var in_corridor := b.free_interior_invalid_reason("dust_grate", Vector3(2 * cell, y, 3 * cell), Vector3.UP, 0.0)
	_check(in_corridor.is_empty(), "a dust grate places in a corridor: %s" % in_corridor)
	# Bay-only items still stay out of rooms.
	var in_room := b.free_interior_invalid_reason("rover_charger", Vector3(.5 * cell, y, .5 * cell), Vector3.UP, 0.0)
	_check(not in_room.is_empty(), "a rover charger is refused in Living Quarters")
	if failures == 0:
		print("Vehicle bay furnishing test passed: bay, corridor and room rules.")
	quit(1 if failures > 0 else 0)
