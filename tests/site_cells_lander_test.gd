extends SceneTree

# Run with: godot --headless --path . --script res://tests/site_cells_lander_test.gd
# Solar arrays, reactors and ice drills sit one to a cell, turned in quarter
# turns (the regolith intake still goes anywhere); and the crew lander's legs,
# footpads and hull are solid.

var failures := 0

func _check(ok: bool, what: String) -> void:
	if ok: return
	failures += 1
	print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.save_directory = "user://test_habitats"; MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	world.player.global_position = Vector3(-40, 5, -40)

	for id in ["solar", "reactor", "ice_extractor"]:
		b._select_kind(id)
		_check(b._site_spot(Vector2(4.2, 7.9)) == Vector2(3, 9), "%s snaps to the cell's centre (%s)" % [id, b._site_spot(Vector2(4.2, 7.9))])
		for turn in 5:
			b._turn_free_site(PI / 12.0)
			var steps: float = b.free_yaw / (PI * .5)
			_check(absf(steps - roundf(steps)) < .001, "%s turns a quarter at a time (%.3f)" % [id, b.free_yaw])
	b._select_kind("regolith_intake")
	_check(b._site_spot(Vector2(4.2, 7.9)) == Vector2(4.2, 7.9), "the regolith intake still goes anywhere")

	# One machine to a cell.
	b._select_kind("reactor")
	b.zones = [{"kind": "solar", "cells": [Vector2i(5, 5)], "at": Vector2(15, 15), "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var reason: String = b._free_site_reason({"at": Vector2(15, 15), "roof": false})
	_check(not reason.is_empty(), "a reactor can't share a cell with a solar array")
	b.zones = []
	b._rebuild()

	# The lander's legs: a ray through each footpad and each strut hits it.
	var lander: Node3D = b.lander
	_check(lander != null, "there's a lander")
	for i in 2: await physics_frame
	var space := root.get_world_3d().direct_space_state
	# From outside, low down along each leg's diagonal: the ray stops at the
	# leg (footpad, then strut), not at the hull behind it.
	for pad in lander.PAD_OFFSETS:
		var reach := Vector2(pad).length()
		for height in [.3, .9]:
			var dir := Vector3(pad.x, 0, pad.y).normalized()
			var query := PhysicsRayQueryParameters3D.create(lander.to_global(dir * (reach + 3.0) + Vector3.UP * height), lander.to_global(Vector3.UP * height))
			var hit := space.intersect_ray(query)
			var gap := 99.0 if hit.is_empty() else Vector2(lander.to_local(hit.position).x, lander.to_local(hit.position).z).length()
			_check(gap > reach - 1.4, "the lander's leg at %s, %.1f m up, is solid (hit %.2f m out)" % [pad, height, gap])
	_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(lander.to_global(Vector3(7, 4, 0)), lander.to_global(Vector3(0, 4, 0)))).is_empty(), "the hull is solid")

	if failures == 0:
		print("Site cells and lander test passed: solar, reactors and drills on cells, quarter turns, one to a cell, the intake free, and solid lander legs.")
	quit(1 if failures > 0 else 0)
