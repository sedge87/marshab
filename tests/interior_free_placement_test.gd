extends SceneTree

# The free-positioned interior API must share simulation effects/cargo with the
# legacy planner while remaining independent from its one-item-per-cell rule.
func _initialize() -> void:
	for category in BuildController.CATEGORIES:
		assert(str(category[0]) != "equipment", "Exterior builder must not expose the interior catalogue.")
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	builder.zones = [{"kind": "hydroponics", "cells": [Vector2i(0, 0)], "cost": 50, "door_direction": Vector2i(0, -1)}]
	builder._rebuild()
	var point := Vector3(0.0, builder.habitat_base_y, 0.0)
	assert(builder.free_interior_invalid_reason("grow_tray", point, Vector3.UP).is_empty(), "Grow tray should be valid on a hydroponics floor.")
	assert(builder.free_interior_invalid_reason("grow_tray", Vector3(1.25, builder.habitat_base_y, 0.0), Vector3.UP).begins_with("Doesn't fit"), "A large item near the wall must be rejected.")
	var visual := builder.free_interior_visual("grow_tray", point, 0.0)
	assert(builder.place_free_interior_equipment("grow_tray", point, 0.0, Vector2i.ZERO, visual), "Free interior placement should succeed.")
	assert(builder.placed_equipment.is_empty(), "Free placement must not use exterior cell records.")
	assert(builder.placed_interior.size() == 1, "Free placement needs its own record.")
	assert(int(builder._systems().food) == 3, "Free grow tray must contribute the catalogue food effect.")
	assert(builder.equipment_invalid_reason("grow_tray", Vector2i.ZERO).is_empty(), "Grid planner remains independent until it is retired.")
	var placement_id := str((builder.placed_interior[0] as Dictionary).placement_id)
	assert(not builder.remove_free_interior_equipment(placement_id).is_empty(), "Free placement should remove by persistent placement id.")
	assert(int(builder._systems().food) == 0, "Removing free equipment must remove its effects.")
	print("Interior free-placement test passed: separate record, effects, cargo path and removal.")
	quit(0)
