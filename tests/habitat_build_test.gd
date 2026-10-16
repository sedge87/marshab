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

	# Separate placements that join edge-to-edge form one internal space. Their
	# shared edge is open; the far perimeter remains a hull wall with overlap.
	builder.zones.append(_zone("science", [Vector2i(3, 0), Vector2i(3, 1)]))
	builder._rebuild()
	builder.zones.append(_zone("science", [Vector2i(3, 2)]))
	assert(not builder._should_build_wall(Vector2i(3, 1), Vector2i(0, 1)), "Joined zones must not place an internal dividing wall.")
	assert(builder._should_build_wall(Vector2i(3, 2), Vector2i(1, 0)), "An exposed zone edge must remain sealed by a hull wall.")
	builder._rebuild()
	await get_tree().physics_frame
	var seam_point := Vector3(4.5, builder.habitat_base_y + 1.45, 3.0)
	var sealed := false
	for wall in get_tree().get_nodes_in_group("habitat_wall"):
		if wall is Node3D and (wall as Node3D).global_position.distance_to(seam_point) < .08:
			sealed = true
	assert(sealed, "The external seam of separately placed zones must have a hull wall.")

	# Pylon-style sources use their radius, not a cable or nearest wall point.
	builder.kind = "solar"
	assert(builder._valid_power_source([Vector2i(13, 2)]), "Solar field should reach a habitat 30 m away.")
	assert(not builder._valid_power_source([Vector2i(14, 2)]), "Solar field must stop beyond 30 m.")
	builder.kind = "reactor"
	assert(builder._valid_power_source([Vector2i(17, 2)]), "Reactor field should reach a habitat 42 m away.")
	assert(not builder._valid_power_source([Vector2i(18, 2)]), "Reactor field must stop beyond 42 m.")

	print("Habitat build integration test passed: airlocks, joined zones, sealed hull and power fields.")
	get_tree().quit(0)

func _zone(kind: String, cells: Array, direction := Vector2i(0, -1)) -> Dictionary:
	return {"kind": kind, "cells": cells, "cost": int(BuildController.ZONE_TYPES[kind].cost) * cells.size(), "door_direction": direction}

func _fail(message: String) -> void:
	push_error("Habitat build integration test failed: " + message)
	get_tree().quit(1)
