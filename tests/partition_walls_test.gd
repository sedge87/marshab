extends SceneTree

# Interior partition walls: 1.5 m panels inside a room (not on its outer
# walls), drawn as runs, turned into doors that open with E, blocked by
# furniture, costing cargo, undone, saved, and removed with their room.
# Run with: godot --headless --path . --script res://tests/partition_walls_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.game_mode = "survival"
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	await process_frame
	# A 9 x 6 m Living Quarters (cells x -1..1, z 0..1): x from -4.5 to 4.5, z from -1.5 to 4.5.
	var cells := []
	for x in range(-1, 2):
		for z in range(0, 2): cells.append(Vector2i(x, z))
	b.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var y := b.habitat_base_y
	# Snapping: a floor point picks the nearest 1.5 m grid line.
	var segment: Dictionary = b.partition_segment_at(Vector3(-1.45, y, 2.2))
	_check(segment.a == Vector2(-1.5, 1.5) and segment.b == Vector2(-1.5, 3.0), "a floor point snaps to the nearest panel line: %s" % str(segment))
	_check(b.partition_invalid_reason(segment).is_empty(), "a panel inside the room is allowed: %s" % b.partition_invalid_reason(segment))
	var outer: Dictionary = b.partition_segment_at(Vector3(-4.45, y, 2.2))
	_check(not b.partition_invalid_reason(outer).is_empty(), "a panel along the outer wall is refused")
	var cargo_before := b.used_cargo()
	# Draw a wall across the room (x = -1.5 from z = -1.5 to 4.5: four panels).
	for z in [-1.5, 0.0, 1.5, 3.0]:
		_check(b.place_partition({"a": Vector2(-1.5, z), "b": Vector2(-1.5, z + 1.5)}), "panel at z %.1f placed" % z)
	_check(b.partitions.size() == 4 and b.used_cargo() - cargo_before == 4 * BuildController.partition_cargo(), "four panels cost four panels of cargo")
	_check(not b.partition_invalid_reason({"a": Vector2(-1.5, 0.0), "b": Vector2(-1.5, 1.5)}).is_empty(), "the same panel can't be placed twice")
	# Turn one into a door.
	_check(b.place_partition({"a": Vector2(-1.5, 1.5), "b": Vector2(-1.5, 3.0)}, true), "a wall panel becomes a door")
	_check(b.partitions.size() == 4 and b.partitions.filter(func(p): return p.door).size() == 1, "the door replaces the panel (still four segments)")
	await process_frame
	var doors := b.root.find_children("*", "Node3D", true, false).filter(func(n): return n.has_method("interaction_prompt") and n.get_script() == BuildController.PARTITION_DOOR_SCRIPT)
	_check(doors.size() == 1, "the door is built")
	if doors.size() == 1:
		doors[0].interact()
		_check(bool(doors[0].open) and str(doors[0].interaction_prompt().primary) == "Close door", "E opens the door")
	_check(b.root.find_children("*", "StaticBody3D", true, false).any(func(body): return body.has_meta("partition_index")), "partitions have collision")
	# Undo turns the door back into a wall.
	_check(b.undo_last_structure() and b.partitions.filter(func(p): return p.door).is_empty(), "Ctrl+Z undoes the door")
	# A panel can be glazed, and Ctrl+Z turns it back into a wall.
	_check(b.place_partition({"a": Vector2(-1.5, 0.0), "b": Vector2(-1.5, 1.5)}, false, true) and bool(b.partitions[b.partition_index({"a": Vector2(-1.5, 0.0), "b": Vector2(-1.5, 1.5)})].glass), "a wall panel becomes glass")
	_check(b.undo_last_structure() and not bool(b.partitions[b.partition_index({"a": Vector2(-1.5, 0.0), "b": Vector2(-1.5, 1.5)})].get("glass", false)), "Ctrl+Z turns the glass back into a wall")
	# Furniture blocks a panel through it.
	b.placed_interior.append({"placement_id": "t1", "id": "crew_bunk", "position": Vector3(1.5, y, 0.75), "zone_cell": Vector2i(0, 0), "state": {}})
	_check(b.partition_invalid_reason({"a": Vector2(1.5, 0.0), "b": Vector2(1.5, 1.5)}).begins_with("Blocked by"), "furniture blocks a panel")
	# ...and a panel blocks furniture placed through it (its whole footprint, at any angle).
	var through := b.free_interior_invalid_reason("crew_bunk", Vector3(-1.5, y, 0.75), Vector3.UP, 0.0)
	_check(through == "Blocked by a partition wall", "furniture can't be placed through a partition: %s" % through)
	var turned := b.free_interior_invalid_reason("crew_bunk", Vector3(-1.5, y, 0.75), Vector3.UP, deg_to_rad(30.0))
	_check(turned == "Blocked by a partition wall", "a turned item can't be placed through a partition: %s" % turned)
	var beside := b.free_interior_invalid_reason("crew_bunk", Vector3(-0.2, y, 3.5), Vector3.UP, PI * .5)
	_check(beside != "Blocked by a partition wall", "an item clear of the partition is allowed: %s" % beside)
	# Saved and restored.
	var state := b.export_habitat_state()
	var copy := BuildController.new(); copy.display_only = true; world.add_child(copy)
	await process_frame
	copy.restore_habitat_state(state)
	_check(copy.partitions.size() == 4, "partitions are saved and loaded (b %d, saved %d, copy %d)" % [b.partitions.size(), (state.get("partitions", []) as Array).size(), copy.partitions.size()])
	# Removing a panel refunds it; removing the room removes its partitions.
	var kit_at := Vector3(-1.45, y + 1.25, -0.75)
	var kit_reason := b.free_interior_invalid_reason("first_aid_kit_wall", kit_at, Vector3.RIGHT, -PI * .5)
	_check(kit_reason.is_empty(), "a wall first aid kit hangs on a partition: %s" % kit_reason)
	b.place_free_interior_equipment("first_aid_kit_wall", kit_at, -PI * .5, Vector2i(0, 0), b.free_interior_visual("first_aid_kit_wall", kit_at, -PI * .5), Vector3.RIGHT)
	var kits_before := b.placed_interior.filter(func(i): return i.id == "first_aid_kit_wall").size()
	b.remove_partition(0)
	_check(b.partitions.size() == 3, "a panel can be removed")
	_check(kits_before == 1 and b.placed_interior.filter(func(i): return i.id == "first_aid_kit_wall").is_empty(), "removing a panel takes down what hangs on it")
	b.zones = []
	b._rebuild()
	_check(b.partitions.is_empty(), "removing the room removes its partitions")
	if failures == 0:
		print("Partition walls test passed: snapping, inside-only, runs, doors, E to open, collision, undo, furniture, saving and pruning.")
	quit(1 if failures > 0 else 0)
