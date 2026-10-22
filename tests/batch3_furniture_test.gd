extends SceneTree

# Backlog batch 3 (23 Oct playtest): desks in every room and a clear desk, the
# kitchenette replacing the small galley pieces, interior doors that open by
# themselves, partition doors that swing away from you (and glass ones), 45°
# partitions, and live wall screens / wayfinding panels.
# Run with: godot --headless --path . --script res://tests/batch3_furniture_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "freedom"; MHGame.pending_save_state = {}
	MHGame.debug_free_power = true

	# Catalogue: retired galley pieces are hidden, their replacement offered.
	var galley := EquipmentCatalog.ids_in_group("galley")
	_check(galley.has("galley_kitchenette") and galley.has("galley_bench_unit"), "the kitchenette and bench unit are in the galley list")
	_check(not galley.has("galley_oven") and not galley.has("galley_rehydration_station") and not galley.has("galley_counter"), "the small galley pieces are retired from the list")
	_check(not EquipmentCatalog.get_entry("galley_oven").is_empty(), "but old saves can still load them")
	for id in ["work_desk", "work_desk_blank", "wall_screen", "wayfinding_panel"]:
		_check((EquipmentCatalog.get_entry(id).get("valid_zones", []) as Array).size() >= 14, "%s fits in every room" % id)
	for id in ["work_desk_blank", "galley_kitchenette", "galley_bench_unit", "wall_screen", "mini_gar_y", "wayfinding_panel"]:
		_check(ResourceLoader.exists(str(EquipmentCatalog.get_entry(id).get("asset_scene", ""))), "%s has a model" % id)

	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await process_frame
	var b = world.builder
	var cells := []
	for x in range(10, 14):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones.append({"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600})
	b.zones.append({"kind": "galley", "cells": [Vector2i(14, 0), Vector2i(15, 0), Vector2i(14, 1), Vector2i(15, 1)], "door_direction": Vector2i(0, -1), "cost": 300})
	b.interior_doors.append(b._canonical_interior_door(Vector2i(13, 0), Vector2i(1, 0)))
	b._rebuild()
	await process_frame

	# 45° partitions: the nearer diagonal of the 1.5 m square.
	var diagonal: Dictionary = b.partition_segment_at(Vector3(33.4, 0, 4.7), true)
	_check((diagonal.a as Vector2).is_equal_approx(Vector2(33, 4.5)) and (diagonal.b as Vector2).is_equal_approx(Vector2(34.5, 6)), "an angled panel runs corner to corner (%s)" % [diagonal])
	_check(b.place_partition(diagonal), "and can be placed in a room")
	# Glass door.
	_check(b.place_partition({"a": Vector2(31.5, 3.0), "b": Vector2(31.5, 4.5)}, true, true), "a glass partition door can be placed")
	_check(bool(b.partitions[-1].door) and bool(b.partitions[-1].glass), "it is stored as a glass door")
	await process_frame
	var leaf_door: Node3D = null
	for node in get_nodes_in_group("partition_door"):
		if not node.is_queued_for_deletion(): leaf_door = node
	_check(leaf_door != null, "the glass door is built")
	# It swings away from whoever opens it.
	var player := get_first_node_in_group("player") as Node3D
	player.global_position = leaf_door.to_global(Vector3(0.7, 0, 1.5))
	leaf_door.interact(player)
	_check(is_equal_approx(float(leaf_door._swing), 95.0), "opened from the +Z side it swings to -Z")
	leaf_door.interact(player)
	player.global_position = leaf_door.to_global(Vector3(0.7, 0, -1.5))
	leaf_door.interact(player)
	_check(is_equal_approx(float(leaf_door._swing), -95.0), "opened from the -Z side it swings to +Z")

	# Interior doors open as you walk up and close behind you.
	var door: AirlockDoor = null
	for node in get_nodes_in_group("airlock_door"):
		if (node as AirlockDoor).door_label() == "INTERIOR" and not node.is_queued_for_deletion(): door = node
	_check(door != null and door.is_automatic(), "the room door is automatic")
	if door != null:
		player.global_position = door.global_position + Vector3(0, 0, 1.0)
		for i in 60: await physics_frame
		_check(door.is_open(), "it opens when you walk up")
		player.global_position = door.global_position + Vector3(0, 0, 8.0)
		for i in 120: await physics_frame
		_check(door.is_closed(), "and closes once you've gone")

	# Screens draw every mode.
	var screen = load("res://scripts/info_screen.gd").new()
	screen.size = Vector2(640, 360)
	root.add_child(screen)
	for mode in ["status", "mars", "earth", "wayfinding", "sign"]:
		screen.mode = mode
		screen.queue_redraw()
		await process_frame
	screen.queue_free()

	if failures == 0:
		print("Batch 3 furniture test passed: catalogue, angled and glass partitions, swing-away doors, automatic doors, screens.")
	quit(1 if failures > 0 else 0)
