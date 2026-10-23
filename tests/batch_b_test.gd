extends SceneTree

# Run with: godot --headless --path . --script res://tests/batch_b_test.gd
# Batch B (24 Oct): galley benches snap flush side by side, small things rest
# on a bunk, GAR-Y names the rocks it finds (Gerald first) and keeps them,
# every spoken line has its recordings, and Mission Control's replies take
# the real light delay to arrive.
const INTERIOR := preload("res://scripts/interior_build_controller.gd")
const ROVER := preload("res://scripts/companion_rover.gd")
const LINK := preload("res://scripts/mission_control_link.gd")

func _initialize() -> void:
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	var y := builder.habitat_base_y
	# Benches: the second snaps flush against the first's end, same facing.
	builder.zones = [{"kind": "galley", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "cost": 0, "door_direction": Vector2i(0, -1)}]
	builder._rebuild()
	var first := Vector3(1.5, y, 1.5)
	assert(builder.place_free_interior_equipment("galley_bench_unit", first, 0.0, Vector2i.ZERO, builder.free_interior_visual("galley_bench_unit", first, 0.0)), "First bench placed.")
	var interior: Node = INTERIOR.new()
	interior.builder = builder
	interior.selected_id = "galley_bench_unit"
	var snap: Dictionary = interior._side_by_side(Vector3(2.6, y, 1.7))
	assert(not snap.is_empty(), "Aiming near the end of a bench snaps to it.")
	assert(is_equal_approx(float(snap.yaw), 0.0), "The snapped bench faces the same way.")
	var width: float = builder._free_interior_size(EquipmentCatalog.get_entry("galley_bench_unit")).x + .025
	assert(absf((snap.point as Vector3).x - (first.x + width)) < .01 and absf((snap.point as Vector3).z - first.z) < .01, "It sits flush against the first one's end (%s)." % str(snap.point))
	assert(interior._side_by_side(Vector3(1.5, y, 2.6)).is_empty(), "Aiming in front of a bench doesn't snap.")
	interior.free()
	# The bunk: a plush toy rests on the mattress.
	builder.placed_interior.clear()
	builder.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "cost": 0, "door_direction": Vector2i(0, -1)}]
	builder._rebuild()
	var bunk := Vector3(1.5, y, 1.0)
	assert(builder.place_free_interior_equipment("crew_bunk", bunk, 0.0, Vector2i.ZERO, builder.free_interior_visual("crew_bunk", bunk, 0.0)), "Bunk placed.")
	var reason := builder.free_interior_invalid_reason("zero_g_plush", bunk + Vector3(.3, .9, 0), Vector3.UP, 0.0)
	assert(reason.is_empty(), "A plush toy can sit on the bunk (%s)." % reason)
	# GAR-Y's rocks: Gerald first, every one different, then no more.
	var rover: Node = ROVER.new()
	assert(int(rover._find_rock()) == 0, "The first special rock is Gerald.")
	for i in 200: rover._find_rock()
	assert(rover.rocks.size() == ROVER.ROCKS.size(), "Eventually it finds every rock.")
	var unique := {}
	for r in rover.rocks: unique[int(r)] = true
	assert(unique.size() == ROVER.ROCKS.size(), "No rock twice.")
	assert(int(rover._find_rock()) == -1, "Nothing left to find.")
	var state: Dictionary = rover.export_state()
	var again: Node = ROVER.new()
	again.restore_state(state)
	assert(again.rocks == rover.rocks, "The collection is saved.")
	rover.free()
	again.free()
	# Every line has every recording.
	var lines: Dictionary = MHAudio.lines()
	var missing: Array = []
	for speaker in ["habitat", "mission_control"]:
		for id in lines[speaker]:
			for n in range((lines[speaker][id] as Array).size()):
				var path := "res://assets/audio/voice/%s%s_%d.wav" % ["mc_" if speaker == "mission_control" else "", id, n]
				if not FileAccess.file_exists(path): missing.append(path)
	assert(missing.is_empty(), "Missing recordings: %s" % str(missing))
	for level_id in ["o2_warning", "o2_critical", "resolved_o2", "welcome_home", "storm_arrived", "seismic_activity", "remark_calm", "remark_dawn"]:
		assert(lines.habitat.has(level_id), "The habitat has a line for %s." % level_id)
	# The light delay: 3 to 22 minutes one way, and a reply takes the round trip.
	var shortest := INF
	var longest := 0.0
	for sol in range(0, 760, 5):
		shortest = minf(shortest, LINK.one_way_minutes(sol))
		longest = maxf(longest, LINK.one_way_minutes(sol))
	assert(shortest > 2.9 and shortest < 3.2 and longest > 22.0 and longest < 22.4, "Light delay runs 3 to 22 minutes (%.1f to %.1f)." % [shortest, longest])
	print("Batch B test passed: bench snapping, items on bunks, GAR-Y's rocks, every voice recording and the light delay.")
	quit(0)
