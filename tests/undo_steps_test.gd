extends SceneTree

# Run with: godot --headless --path . --script res://tests/undo_steps_test.gd
# Ctrl+Z in the site plan walks back every kind of step in order, including
# partitions drawn in Interior mode (it used to crash on them), and skips
# steps it can't take back instead of failing.

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
	var cells := []
	for x in range(4, 7):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	var room := {"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 0}
	b.zones.append(room); b._history.append({"type": "zone", "zone": room}); b._rebuild()
	var segment := {"a": Vector2(13.5, 1.5), "b": Vector2(15.0, 1.5)}
	_check(b.place_partition(segment), "a partition goes in the room (%s)" % b.partition_invalid_reason(segment, false, false))
	b._history.append({"type": "mystery"})
	b._undo()
	_check(b.partitions.is_empty(), "Ctrl+Z in the site plan takes the partition back")
	_check(b.zones.has(room), "and leaves the room")
	b._undo()
	_check(not b.zones.has(room), "the next Ctrl+Z takes the room back")
	b._undo()   # nothing left: no crash
	if failures == 0: print("Undo steps test passed: partitions, odd steps skipped, rooms, and an empty history.")
	quit(1 if failures > 0 else 0)
