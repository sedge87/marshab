extends SceneTree

# A corridor whose end meets a vehicle bay must get a bay bulkhead there, not
# a blank wall, and every bay door must be interlocked with the hangar.
# Run with: godot --headless --path . --script res://tests/vehicle_bay_corridor_door_test.gd
func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	# Room on the bay's west side; the bay's hangar faces east (+x).
	var room := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var bay := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)]
	# Corridor runs south from the bay's side; its north end touches bay cell (2, 1).
	var corridor := [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]
	builder.zones = [
		{"kind": "living", "cells": room, "cost": 200, "door_direction": Vector2i(0, -1)},
		{"kind": "vehicle_bay", "cells": bay, "cost": 200, "door_direction": Vector2i(1, 0)},
		{"kind": "corridor", "cells": corridor, "cost": 150, "door_direction": Vector2i(0, -1)},
	]
	builder._rebuild()
	await process_frame
	var corridor_door_position := Vector3(2 * BuildController.CELL, 0, 1.5 * BuildController.CELL)
	var room_door_found := false
	var corridor_door: AirlockDoor
	var hangar: AirlockDoor
	for node in builder.root.find_children("*", "AirlockDoor", true, false):
		var door := node as AirlockDoor
		if door.door_label() == "HANGAR": hangar = door
		elif door.door_label() == "BAY":
			var flat := Vector3(door.position.x, 0, door.position.z)
			if flat.distance_to(corridor_door_position) < .1: corridor_door = door
			elif is_equal_approx(door.position.x, 1.5 * BuildController.CELL): room_door_found = true
	assert(corridor_door != null, "The corridor end meeting the bay must get a bay door, not a wall.")
	assert(room_door_found, "The bay should keep its existing door into the attached room.")
	assert(hangar != null and hangar._partners.size() == 2, "The hangar must be interlocked with both bay doors.")
	assert(corridor_door._partners.has(hangar), "The corridor's bay door must be interlocked with the hangar.")
	print("Vehicle bay corridor door test passed: corridor end gets an interlocked bay door.")
	quit(0)
