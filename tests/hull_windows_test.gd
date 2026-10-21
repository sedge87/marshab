extends SceneTree

# Hull windows: glazing a Mars-facing wall bay, its cost, heating, undo, save
# and removal when the wall stops facing Mars.
# Run with: godot --headless --path . --script res://tests/hull_windows_test.gd
var builder: BuildController
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _glass_count() -> int:
	var total := 0
	for node in builder.root.find_children("*", "StaticBody3D", true, false):
		if node.is_in_group("hull_window_glass") and not node.is_queued_for_deletion(): total += 1
	return total

func _aim(bay: Dictionary) -> Vector3:
	# A first-person hit on the inside face of that bay, at eye height.
	var mid: Vector2 = bay.mid - (bay.outward as Vector2) * .1
	return Vector3(mid.x, builder.habitat_base_y + 1.5, mid.y)

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	builder = BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	MHGame.site_id = "plains"
	MHGame.outside_temperature_c = -60.0
	var room := {"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "door_direction": Vector2i(0, -1), "cost": 200}
	builder.zones = [room]
	builder._rebuild()
	_check(builder._hull_bays.size() == 8, "a 2×2 room has 8 outside wall bays (%d)" % builder._hull_bays.size())

	# Aim at a bay and glaze it.
	var target := builder.window_target_at(_aim(builder._hull_bays[0]))
	_check(not target.is_empty() and builder.window_invalid_reason(target) == "", "aiming at an outside wall offers a window")
	_check(builder.window_target_at(Vector3(target.mid.x, builder.habitat_base_y + 3.5, target.mid.y)).is_empty(), "aiming above the roof offers nothing")
	var cargo_before := builder._used_cargo()
	var heating_before := int(builder._systems().heating)
	_check(builder.place_window(target), "window placed")
	_check(_glass_count() == 1, "one glazed bay is built")
	_check(builder._used_cargo() == cargo_before + BuildController.window_cargo(), "a window costs %d kg" % BuildController.window_cargo())
	_check(int(builder._systems().heating) > heating_before, "glass adds heating draw (%d → %d)" % [heating_before, int(builder._systems().heating)])
	_check(builder.window_invalid_reason(builder.window_target_at(_aim(target))) != "", "a bay can only take one window")

	# Interior-mode undo, then site-plan undo, both remove it.
	_check(builder.undo_last_structure() and builder.hull_windows.is_empty() and _glass_count() == 0, "Ctrl+Z in Interior removes the window")
	builder.place_window(builder.window_target_at(_aim(builder._hull_bays[2])))
	builder._undo()
	_check(builder.hull_windows.is_empty(), "site-plan undo removes the window too")

	# Remove tool.
	builder.place_window(builder.window_target_at(_aim(builder._hull_bays[3])))
	var index := builder.window_index_near(_aim(builder._hull_bays[3]))
	_check(index == 0, "aiming at a window finds it")
	builder.remove_window(index)
	_check(builder.hull_windows.is_empty() and _glass_count() == 0, "the remove tool takes the window out")

	# Save and restore keep windows.
	builder.place_window(builder.window_target_at(_aim(builder._hull_bays[1])))
	var saved := builder.export_habitat_state()
	builder.hull_windows = []
	builder.restore_habitat_state(saved)
	_check(builder.hull_windows.size() == 1 and _glass_count() == 1, "a saved window comes back on load")

	# A room built against that wall: the bay no longer faces Mars, so the
	# window is removed and refunded.
	var window_bay := builder.window_target_at(_aim(builder._hull_bays[0]))
	var cargo_with_window := builder._used_cargo()
	var glazed: Dictionary = builder.hull_windows[0]
	var beyond: Vector2 = glazed.mid
	for bay in builder._hull_bays:
		if (bay.mid as Vector2).distance_to(glazed.mid) < .1: beyond = (bay.mid as Vector2) + (bay.outward as Vector2) * 1.5
	builder.zones.append({"kind": "storage", "cells": [Vector2i(roundi(beyond.x / 3.0), roundi(beyond.y / 3.0))], "door_direction": Vector2i(0, -1), "cost": 50})
	builder._rebuild()
	_check(builder.hull_windows.is_empty(), "a window on a wall that now faces another room is removed")
	_check(builder._used_cargo() == cargo_with_window + 50 - BuildController.window_cargo(), "its cargo is refunded")

	# Airlock walls stay solid.
	builder.zones = [room, {"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 50}]
	builder.hull_windows = []
	builder._rebuild()
	var airlock_bay := false
	for bay in builder._hull_bays:
		if str(bay.zone_kind) == "airlock": airlock_bay = true
	_check(not airlock_bay, "airlock walls offer no window bays")

	# Angled rooms take windows on their 45° walls.
	var octagon := PackedVector2Array([Vector2(-4.5, -1.5), Vector2(-1.5, -4.5), Vector2(1.5, -4.5), Vector2(4.5, -1.5), Vector2(4.5, 1.5), Vector2(1.5, 4.5), Vector2(-1.5, 4.5), Vector2(-4.5, 1.5)])
	builder.zones = [{"kind": "living", "cells": builder._freeform_cells(octagon), "outline": octagon, "door_direction": Vector2i(0, -1), "cost": 300}]
	builder._rebuild()
	var diagonal := {}
	for bay in builder._hull_bays:
		if absf(absf((bay.tangent as Vector2).x) - absf((bay.tangent as Vector2).y)) < .01: diagonal = bay
	_check(not diagonal.is_empty(), "an angled room has 45° wall bays")
	var diagonal_target := builder.window_target_at(_aim(diagonal))
	var placed := builder.place_window(diagonal_target)
	_check(placed and _glass_count() == 1, "a 45° wall takes a window")

	if failures == 0:
		print("Hull windows test passed: bays, placement, cost, heating, undo, remove, save, pruning, airlocks and 45° walls.")
	quit(1 if failures > 0 else 0)
