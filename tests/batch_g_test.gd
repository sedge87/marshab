extends SceneTree

# Run with: godot --headless --path . --script res://tests/batch_g_test.gd
# Batch G (24 Oct): the crew's Contact with Earth needs the station in
# Mission Operations, and a wall-mounted strip can be picked for removal by
# aiming at the wall.
const INTERIOR := preload("res://scripts/interior_build_controller.gd")

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"
	MHGame.game_mode = "survival"
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	builder.zones = [{"kind": "communications", "cells": [Vector2i(0, 0)], "cost": 0, "door_direction": Vector2i(0, -1)},
		{"kind": "living", "cells": [Vector2i(1, 0)], "cost": 0, "door_direction": Vector2i(0, -1)}]
	builder._rebuild()
	var y := builder.habitat_base_y
	var at := Vector3(0, y, 0)
	builder.placed_interior.append({"placement_id": "station_1", "id": "communications_station", "position": at, "zone_cell": Vector2i.ZERO, "rotation_y": 0.0, "state": {}})
	builder.placed_surface.append({"id": "comms_antenna", "position": Vector3(9, 0, 9)})
	# The crew's need: the station must be in Mission Operations.
	builder.placed_interior[0].position = Vector3(3, y, 0)
	builder.placed_interior[0].zone_cell = Vector2i(1, 0)
	builder.simulation().invalidate()
	var sim: RefCounted = builder.simulation()
	var contact: Dictionary = (sim.life.needs(sim.inventory(), {1: true, 2: true, 3: true, 4: true}) as Array).filter(func(n): return str(n.id) == "contact")[0]
	assert(float(contact.score) == 0.0 and str(contact.missing).contains("communications station"), "A station outside Mission Operations doesn't count (%s)." % contact.missing)
	# A thin wall strip: aiming at the wall right there picks it.
	builder.placed_interior.append({"placement_id": "strip_1", "id": "corridor_light_strip", "position": Vector3(0, y + .2, -1.45), "zone_cell": Vector2i.ZERO, "rotation_y": 0.0, "state": {}})
	var interior: Node = INTERIOR.new()
	interior.builder = builder
	assert(interior._wall_item_at(Vector3(.2, y + .25, -1.48)) == "strip_1", "Aiming at the wall beside the strip picks it.")
	assert(interior._wall_item_at(Vector3(0, y + 2.0, -1.48)).is_empty(), "Aiming well away from it doesn't.")
	interior.free()
	print("Batch G test passed: the contact need and wall strips.")
	quit(0)
