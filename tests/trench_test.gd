extends SceneTree

# Trenches (cut and cover, scripts/trenches.gd) on a region site: the dig
# rules, the ground in and around a trench, standing in it and walking up its
# ramp, rooms on its floor (and the base staying on one level), earth
# shielding, filling it back in, and saving.
# Run with: godot --headless --path . --script res://tests/trench_test.gd
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const TRENCHES := preload("res://scripts/trenches.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _world(state: Dictionary) -> Node:
	MHGame.site_id = "region_plains"; MHGame.game_mode = "creative"
	MHGame.pending_save_state = state
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	world.set_tutorial_mode("off")
	return world

func _initialize() -> void:
	var world: Node = await _world({"site_id": "region_plains", "builder": {}})
	var b = world.builder
	var p: CharacterBody3D = world.player
	p.global_position = Vector3(40, 1, -30)
	var cells := []
	for x in range(-8, -4):
		for z in range(2, 5): cells.append(Vector2i(x, z))
	# Dig rules.
	b.kind = "trench"; b.airlock_direction = Vector2i(0, 1)
	_check(b._invalid_reason(cells) == "", "a 4 × 3 trench can be dug on the pad (%s)" % b._invalid_reason(cells))
	_check(b._invalid_reason([Vector2i(-8, 2)]) != "", "a one-cell trench is too small")
	_check(TRENCHES.invalid_reason(b, [Vector2i(18, 18), Vector2i(19, 19)], Vector2i(0, 1)) != "", "a trench can't run off the pad")
	b.trenches.append({"cells": cells, "ramp": Vector2i(0, 1)})
	b._rebuild()
	for i in 5: await physics_frame
	var floor := TRENCHES.floor_rect(b.trenches[0])
	var ramp := TRENCHES.ramp_rect(b.trenches[0])
	var c := floor.get_center()
	_check(is_equal_approx(MHSiteTerrain.height(c.x, c.y), -TRENCHES.DEPTH), "the trench floor is %.1f m down" % TRENCHES.DEPTH)
	_check(absf(MHSiteTerrain.height(ramp.get_center().x, ramp.get_center().y) + TRENCHES.DEPTH * .5) < .05, "half way up the ramp is half the depth")
	_check(absf(MHSiteTerrain.height(floor.end.x + 6, c.y)) < .01, "the ground beside it is untouched")
	var terrain = world.get_tree().get_first_node_in_group("region_terrain")
	_check(terrain.data.get_height(Vector3(c.x, 0, c.y)) < -TRENCHES.DEPTH, "the region's ground is sunk below the trench floor")
	# Standing in it, then walking up the ramp.
	p.global_position = Vector3(c.x, 1.5, c.y)
	for i in 90: await physics_frame
	_check(absf(p.global_position.y + TRENCHES.DEPTH) < .1 and p.is_on_floor(), "you can stand on the trench floor (y %.2f)" % p.global_position.y)
	p.global_position = Vector3(ramp.get_center().x, -TRENCHES.DEPTH + .1, floor.end.y - 1.0)
	p.rotation.y = PI
	for i in 10: await physics_frame
	Input.action_press("move_forward")
	for i in 240: await physics_frame
	Input.action_release("move_forward")
	_check(p.global_position.z > ramp.end.y and absf(p.global_position.y) < .2, "you can walk up the ramp to the surface (%s)" % p.global_position.snapped(Vector3.ONE * .1))
	p.global_position = Vector3(40, 1, -30)
	# Rooms: the first in the trench sets the floor; one up top is refused.
	b.kind = "living"
	var room := [Vector2i(-8, 2), Vector2i(-7, 2), Vector2i(-8, 3), Vector2i(-7, 3)]
	_check(b._invalid_reason(room) == "", "a room fits in the trench (%s)" % b._invalid_reason(room))
	b.habitat_base_y = b._proposed_base_y(room)
	b.zones.append({"kind": "living", "cells": room, "door_direction": Vector2i(0, 1), "cost": 0})
	b._rebuild()
	_check(absf(b.habitat_base_y - (-TRENCHES.DEPTH + .35)) < .01, "the base floor is on the trench floor (%.2f)" % b.habitat_base_y)
	_check("trench" in b._invalid_reason([Vector2i(-12, 2)]), "a room up top is refused while the base is in the trench")
	_check("ramp" in b._invalid_reason([Vector2i(-6, 6)]), "nothing can be built on the ramp")
	var rooms: Array = b.simulation().inventory().rooms
	_check(not rooms.is_empty() and is_equal_approx(float(rooms[0].shield_upgrades), 32.0), "earth shields the room's four outside wall bays (%s)" % (rooms[0].shield_upgrades if not rooms.is_empty() else "none"))
	# A trench with rooms in it can't be filled in; saving keeps it.
	b._remove_at(Vector2i(-5, 4))
	_check(b.trenches.size() == 1, "a trench with rooms in it stays")
	var saved: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	world = await _world(saved)
	b = world.builder
	_check(b.trenches.size() == 1 and is_equal_approx(MHSiteTerrain.height(c.x, c.y), -TRENCHES.DEPTH), "a saved trench loads back")
	_check(world.get_tree().get_first_node_in_group("region_terrain").data.get_height(Vector3(c.x, 0, c.y)) < -TRENCHES.DEPTH, "its ground is sunk again after loading")
	# Empty it, then fill it in: the ground comes back.
	b.zones.clear()
	b.habitat_base_y = .35
	b._rebuild()
	b._remove_at(Vector2i(-6, 3))
	for i in 3: await process_frame
	_check(b.trenches.is_empty() and absf(MHSiteTerrain.height(c.x, c.y)) < .01, "an empty trench can be filled in")
	_check(absf(world.get_tree().get_first_node_in_group("region_terrain").data.get_height(Vector3(c.x, 0, c.y))) < .05, "and the ground comes back")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("Trench test passed: dig rules, depth and ramp, standing and walking out, rooms on the floor, one level, earth shielding, saving and filling in.")
	quit(1 if failures > 0 else 0)
