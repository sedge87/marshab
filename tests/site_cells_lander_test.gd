extends SceneTree

# Run with: godot --headless --path . --script res://tests/site_cells_lander_test.gd
# Solar arrays, reactors and ice drills sit one to a cell, turned in quarter
# turns (the regolith intake still goes anywhere); and the crew lander's legs,
# footpads and engine pods are solid.

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
	for pad in lander.PAD_OFFSETS:
		for local in [Vector3(pad.x, .4, pad.y), Vector3(pad.x * .8, .85, pad.y * .7)]:
			var at: Vector3 = lander.to_global(local)
			var outward: Vector3 = (at - lander.global_position) * Vector3(1, 0, 1)
			var query := PhysicsRayQueryParameters3D.create(at + outward.normalized() * 2.0, at)
			var hit := space.intersect_ray(query)
			_check(not hit.is_empty(), "the lander's leg at %s is solid" % local)
	var pod: Vector3 = lander.to_global(Vector3(3.3, 1.1, 0))
	_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(pod + lander.global_transform.basis.x * 2.0, pod)).is_empty(), "the engine pods are solid")

	if failures == 0:
		print("Site cells and lander test passed: solar, reactors and drills on cells, quarter turns, one to a cell, the intake free, and solid lander legs.")
	quit(1 if failures > 0 else 0)
