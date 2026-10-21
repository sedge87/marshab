extends Node3D

# Integration checks for the authored floor-plan. Run with:
# godot --headless --path . --scene res://tests/habitat_build_test.tscn

func _ready() -> void:
	var builder := BuildController.new()
	builder.display_only = true
	add_child(builder)
	await get_tree().process_frame

	# Build order must not matter: the corridor is present before the airlock,
	# and the airlock still owns its shared inner threshold after a rebuild.
	builder.zones = [
		_zone("corridor", [Vector2i(0, 1)]),
		_zone("airlock", [Vector2i(0, 0)], Vector2i(0, -1)),
		_zone("living", [Vector2i(0, 2)])
	]
	assert(builder._corridor_touches_airlock([Vector2i(0, 1)]), "Corridor next to an airlock must use the open shell.")
	assert(not builder._should_build_wall(Vector2i(0, 1), Vector2i(0, -1)), "Corridor must not build a wall across an airlock inner door.")
	builder._rebuild()
	await get_tree().physics_frame
	var threshold := Vector3(0, builder.habitat_base_y + 1.45, 1.5)
	for wall in get_tree().get_nodes_in_group("habitat_wall"):
		if wall is Node3D and (wall as Node3D).global_position.distance_to(threshold) < .05:
			_fail("A habitat wall was generated across the airlock inner threshold.")
			return

	# Separate rooms of different kinds remain sealed at their shared edge (rooms
	# of the same kind merge into one volume). A deliberate interior-door
	# placement removes that single shared wall instead.
	builder.zones.append(_zone("science", [Vector2i(3, 0), Vector2i(3, 1)]))
	builder._rebuild()
	builder.zones.append(_zone("storage", [Vector2i(3, 2)]))
	assert(builder._should_build_wall(Vector2i(3, 1), Vector2i(0, 1)), "Adjacent room volumes must remain sealed until a door is placed.")
	assert(builder._should_build_wall(Vector2i(3, 2), Vector2i(1, 0)), "An exposed zone edge must remain sealed by a hull wall.")
	assert(builder.place_interior_door(Vector2i(3, 1), Vector2i(0, 1)), "A shared wall should accept an explicit interior door.")
	assert(not builder._should_build_wall(Vector2i(3, 1), Vector2i(0, 1)), "An installed interior door must own the shared opening.")
	# Both physical faces of a thick shared wall must resolve to the same
	# canonical doorway; otherwise the hologram only works from one room.
	var from_first := builder.interior_door_from_world_point(Vector3(9.0, 1.7, 4.42), Vector3(0, 0, -1))
	var from_second := builder.interior_door_from_world_point(Vector3(9.0, 1.7, 4.58), Vector3(0, 0, 1))
	assert(from_first == from_second and from_first.get("cell") == Vector2i(3, 1), "Both faces of a shared wall must identify the same doorway.")
	builder._rebuild()
	await get_tree().physics_frame

	# Vehicle bays use specialised rendering, but an explicit door must still
	# replace their bay wall with the interlocked personnel hatch.
	builder.zones = [
		_zone("living", [Vector2i(0, 0)]),
		_zone("vehicle_bay", [Vector2i(1, 0), Vector2i(1, 1)], Vector2i(1, 0))
	]
	builder.interior_doors.clear()
	assert(builder.place_interior_door(Vector2i(0, 0), Vector2i(1, 0)), "A vehicle bay boundary should accept an explicit personnel door.")
	var bay_hatch := false
	for child in builder.root.get_children():
		if child is AirlockDoor and (child as AirlockDoor).door_label() == "BAY":
			bay_hatch = true
	assert(bay_hatch, "A vehicle bay interior door must create the bay personnel hatch, not leave a wall behind.")

	# Pylon-style sources use their radius, measured to the nearest habitat cell
	# (here the storage room at cell (3, 2)), not a cable.
	builder.zones = [_zone("science", [Vector2i(3, 0), Vector2i(3, 1)]), _zone("storage", [Vector2i(3, 2)])]
	builder.kind = "solar"
	assert(builder._valid_power_source([Vector2i(13, 2)]), "Solar field should reach a habitat 30 m away.")
	assert(builder._valid_power_source([Vector2i(14, 2)]), "Power is cabled: a solar array connects at any distance.")
	builder.kind = "reactor"
	assert(builder._valid_power_source([Vector2i(17, 2)]), "Reactor field should reach a habitat 42 m away.")
	assert(builder._valid_power_source([Vector2i(30, 2)]), "Power is cabled: a reactor connects at any distance.")

	print("Habitat build integration test passed: airlocks, sealed rooms, interior doors and power fields.")
	get_tree().quit(0)

func _zone(kind: String, cells: Array, direction := Vector2i(0, -1)) -> Dictionary:
	return {"kind": kind, "cells": cells, "cost": int(BuildController.ZONE_TYPES[kind].cost) * cells.size(), "door_direction": direction}

func _fail(message: String) -> void:
	push_error("Habitat build integration test failed: " + message)
	get_tree().quit(1)
