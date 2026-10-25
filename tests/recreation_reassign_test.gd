extends SceneTree

# Run with: godot --headless --path . --script res://tests/recreation_reassign_test.gd
# 25 Oct playtest: recreation items for Living Quarters (they load, fit the
# room and count as personal things for "a bit of home"); reassigning a
# room to another type (equipment that doesn't fit comes out, Ctrl+Z turns
# it back); the half-glass partition (placed, changed, saved); and dragging
# partitions only draws along the first panel's line, filling any gap.

const RECREATION := ["lounge_sofa", "bean_bag", "arcade_cabinet", "vr_station", "table_football", "telescope", "music_station", "dartboard", "games_shelf"]

var failures := 0

func _check(ok: bool, what: String) -> void:
	if ok: return
	failures += 1
	print("FAIL ", what)

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 800 * w * h}

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.save_directory = "user://test_habitats"; MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	world.player.global_position = Vector3(-40, 5, -40)
	var living := _room("living", 4, 0, 4, 3)   # x 10.5..22.5, z -1.5..7.5
	b.zones = [living]
	b._history = [{"type": "zone", "zone": living}]
	b._rebuild()
	var y: float = b.habitat_base_y

	# Recreation: every item has a scene that loads, and fits Living Quarters.
	for id in RECREATION:
		var entry := EquipmentCatalog.get_entry(id)
		_check(not entry.is_empty() and ResourceLoader.exists(str(entry.get("asset_scene", ""))), "%s is in the catalogue with a scene" % id)
		_check((entry.get("valid_zones", []) as Array).has("living"), "%s goes in Living Quarters" % id)
	var spots := {"lounge_sofa": Vector3(13.5, y, 0.4), "arcade_cabinet": Vector3(20.5, y, 0.0), "table_football": Vector3(16.5, y, 4.0)}
	for id in spots:
		var reason: String = b.free_interior_invalid_reason(id, spots[id], Vector3.UP, 0.0)
		_check(reason.is_empty(), "%s can be placed in the room (%s)" % [id, reason])
		if reason.is_empty():
			b.place_free_interior_equipment(id, spots[id], 0.0, Vector2i(roundi(spots[id].x / 3), roundi(spots[id].z / 3)), b.free_interior_visual(id, spots[id], 0.0))
	var hazards_text := FileAccess.get_file_as_string("res://data/hazards.json")
	var personal_line := hazards_text.substr(hazards_text.find("\"personal_items\""), 600)
	_check(personal_line.contains("arcade_cabinet") and personal_line.contains("games_shelf"), "games count as personal things for a bit of home")

	# Reassign: Living Quarters becomes a Galley. The arcade and table football
	# fit a galley too; the sofa doesn't, so it comes out.
	b._select_kind("galley")
	_check(b.reassign_reason(living).is_empty(), "a room can be reassigned (%s)" % b.reassign_reason(living))
	_check(b.reassign_room_at(Vector2i(5, 1)), "reassigning works")
	_check(str(living.kind) == "galley", "the room is now a galley")
	var ids: Array = b.placed_interior.map(func(i): return str(i.id))
	_check(not ids.has("lounge_sofa") and ids.has("arcade_cabinet"), "what doesn't fit comes out; what fits stays (%s)" % [ids])
	b._undo()
	_check(str(living.kind) == "living", "Ctrl+Z turns it back into Living Quarters")
	b._select_kind("solar")
	_check(not b.reassign_reason(living).is_empty(), "only a room type can be chosen")

	# The half-glass partition: placed, then a wall panel changed into one; saved.
	var seg := {"a": Vector2(13.5, 3.0), "b": Vector2(15.0, 3.0)}
	_check(b.place_partition(seg, false, false, true), "a half-glass panel goes in (%s)" % b.partition_invalid_reason(seg, false, false, true))
	var panel: Dictionary = b.partitions[b.partition_index(seg)]
	_check(bool(panel.get("half", false)) and not bool(panel.glass), "it's recorded as half glass")
	_check(not b.place_partition(seg, false, false, true), "the same half-glass panel can't go in twice")
	_check(b.place_partition(seg), "it can be changed to a plain wall")
	b._undo()
	_check(bool(b.partitions[b.partition_index(seg)].get("half", false)), "and Ctrl+Z makes it half glass again")
	_check(((b.export_habitat_state().partitions as Array)[0] as Dictionary).get("half", false), "it's saved")
	await process_frame
	_check(root.find_children("Partition_*", "", true, false).size() >= 1, "it's built")

	# Dragging: from one panel, a slow frame that jumps two panels along still
	# draws both, and aiming off the line draws nothing new.
	b.partitions = []
	b._rebuild()
	var ib = world.interior_builder
	var start := {"a": Vector2(12.0, 0.0), "b": Vector2(12.0, 1.5)}   # clear of the furniture
	b.place_partition(start)
	ib._drag_start = start
	ib._drag_step = 0
	ib._drag_partitions(Vector2(12.1, 3.9), false)   # two panels further along the line
	_check(b.partitions.size() == 3, "a jump along the line fills the gap (%d panels)" % b.partitions.size())
	ib._drag_partitions(Vector2(14.6, 3.9), false)   # well off to the side: same step along the line
	_check(b.partitions.size() == 3, "aiming off the line draws nothing new (%d panels)" % b.partitions.size())
	for p in b.partitions: _check(is_equal_approx((p.a as Vector2).x, 12.0) and is_equal_approx((p.b as Vector2).x, 12.0), "every panel is on the first panel's line (%s)" % p)

	if failures == 0:
		print("Recreation and reassign test passed: nine recreation items, reassigning a room and undo, the half-glass partition, and drag drawing along one line.")
	quit(1 if failures > 0 else 0)
