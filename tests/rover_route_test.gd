extends SceneTree

# Run with: godot --headless --path . --script res://tests/rover_route_test.gd
# A recalled crew rover finds its way home over the region (scripts/rover_route.gd):
# a route around ground it's told to avoid, ending outside the hangar; far from
# you it runs along it without physics, paying for the drive, and parks itself.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const ROUTE := preload("res://scripts/rover_route.gd")

func _initialize() -> void:
	MHGame.site_id = "region_crater"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "survival"
	MHGame.pending_save_state = {"site_id": "region_crater", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	var rover = world.crew_rover
	for i in 20: await physics_frame
	# The planner goes round a square it's told to keep out of.
	var wall := Rect2(-200, -260, 400, 60)
	var route: PackedVector2Array = ROUTE.plan(Vector2(0, -500), Vector2(0, 0), func(p: Vector2) -> bool: return wall.has_point(p))
	assert(route.size() > 1 and route[route.size() - 1] == Vector2.ZERO, "A route home, ending where it was asked to (%d points)." % route.size())
	var prev := Vector2(0, -500)
	for point in route:
		for k in 20:
			assert(not wall.has_point(prev.lerp(point, k / 20.0)), "It keeps out of the blocked square.")
		prev = point
	# Recalled from 1.1 km out on the crater rim, with you at the base: a
	# route, then the drive home off-screen.
	rover.global_position = Vector3(900, MHSiteTerrain.height(900, 700) + .3, 700)
	world.player.global_position = Vector3(0, b.habitat_base_y + .3, 0)
	assert(str(rover.recall()).begins_with("Recalled"), "It sets off.")
	assert(rover._route.size() > 3, "On a route over the ground, not a straight line (%d points)." % rover._route.size())
	var steps := 0
	while rover.recalling and rover.global_position.distance_to(world.player.global_position) > 150.0 and steps < 4000:
		rover._ghost_drive(.5)
		steps += 1
	assert(rover.battery < 100.0, "The drive is paid for (%.0f%%)." % rover.battery)
	# The last 150 m are driven for real, in view (a minute and a half at most).
	for i in 5400:
		await physics_frame
		if not rover.recalling: break
		if i % 600 == 0: print("  driving home: %d m to go, stage %s, waypoint %d of %d" % [roundi(rover.global_position.distance_to(world.player.global_position)), rover._recall_stage, rover._route_i, rover._route.size()])
	assert(rover._in_bay() and not rover.recalling, "And it's home in the bay (%s)." % rover.global_position)
	print("Rover route test passed: a route round blocked ground, recalled from the crater rim, driven home off-screen and parked in the bay.")
	quit(0)
