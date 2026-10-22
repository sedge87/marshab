extends SceneTree

# How touching rooms join: same purpose merges into one room (any shape),
# different purposes get one automatic, removable door.
# Run with: godot --headless --path . --script res://tests/room_joining_test.gd
var builder: BuildController
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _grid(kind: String, cells: Array) -> Dictionary:
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 50 * cells.size()}

func _angled(kind: String, points: Array) -> Dictionary:
	var outline := PackedVector2Array(points)
	return {"kind": kind, "cells": builder._freeform_cells(outline), "outline": outline, "door_direction": Vector2i(0, -1), "cost": builder._freeform_cost(outline)}

# Place a zone the way the planner does: append, record history, rebuild, join.
func _place(zone: Dictionary) -> void:
	builder.zones.append(zone)
	builder._history.append({"type": "zone", "zone": zone})
	builder._rebuild()
	builder._after_room_placed()

func _count(kind: String) -> int:
	var total := 0
	for zone in builder.zones:
		if str(zone.kind) == kind: total += 1
	return total

func _reset() -> void:
	builder.zones = []
	builder.interior_doors = []
	builder._history = []
	builder._rebuild()

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	builder = BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	var square := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] # x and z from -1.5 to 4.5
	var east_angled := [Vector2(4.5, -1.5), Vector2(7.5, -1.5), Vector2(10.5, 1.5), Vector2(10.5, 4.5), Vector2(4.5, 4.5)]

	# Grid room + angled room of the same purpose become one room.
	_reset()
	_place(_grid("living", square))
	var grid_cost := int(builder.zones[0].cost)
	_place(_angled("living", east_angled))
	_check(_count("living") == 1, "grid + angled Living Quarters merge into one room (%d rooms)" % _count("living"))
	_check(builder.zones[0].has("outline"), "the merged room is one outline")
	_check(builder.zones[0].outline.size() == 5, "merged outline drops the old shared wall corners (%s)" % [builder.zones[0].get("outline")])
	_check(builder.is_inside(Vector3(4.5, builder.habitat_base_y + 1.0, 1.5)), "the old shared wall line is now open floor")
	# Undo the angled placement: the grid room returns as it was.
	builder._undo()
	_check(builder.zones.size() == 1 and not builder.zones[0].has("outline") and (builder.zones[0].cells as Array).size() == 4, "undo returns the grid room to its earlier shape")
	_check(int(builder.zones[0].cost) == grid_cost, "undo refunds the merged-in room's cargo")

	# Two angled rooms of the same purpose merge too.
	_reset()
	_place(_angled("hydroponics", [Vector2(-1.5, -1.5), Vector2(4.5, -1.5), Vector2(4.5, 4.5), Vector2(1.5, 4.5), Vector2(-1.5, 1.5)]))
	_place(_angled("hydroponics", east_angled))
	_check(_count("hydroponics") == 1, "two angled Hydroponics rooms merge")

	# Different purposes stay separate but get one automatic door.
	_reset()
	_place(_grid("living", square))
	_place(_angled("science", east_angled))
	_check(_count("living") == 1 and _count("science") == 1, "different purposes stay separate rooms")
	_check(builder.interior_doors.size() == 1, "grid room + angled room of different purpose get one door (%d)" % builder.interior_doors.size())
	_check(builder._rooms_have_door(builder.zones[0], builder.zones[1]), "the door joins those two rooms")
	var marker_found := false
	for node in builder.root.find_children("DoorPlanMarker*", "MeshInstance3D", true, false):
		if not node.is_queued_for_deletion(): marker_found = true
	_check(marker_found, "the door shows on the site plan")
	# Removing it seals the wall, and it is not added back by later rebuilds.
	var centre := builder._interior_door_centre(builder.interior_doors[0])
	var index := builder.interior_door_index_near(Vector3(centre.x + .2, builder.habitat_base_y + 1.2, centre.y))
	_check(index == 0, "aiming at the door finds it")
	builder.remove_interior_door(index)
	builder._rebuild()
	_check(builder.interior_doors.is_empty(), "a removed door stays removed")

	# Grid + grid of different purposes.
	_reset()
	_place(_grid("living", square))
	_place(_grid("galley", [Vector2i(2, 0), Vector2i(2, 1)]))
	_check(builder.interior_doors.size() == 1 and not builder._should_build_wall(Vector2i(1, 0), Vector2i(1, 0)) != not builder._should_build_wall(Vector2i(1, 1), Vector2i(1, 0)), "grid rooms of different purposes get exactly one door in their shared wall")

	# A new room touching two others gets one door, not one per neighbour.
	_reset()
	_place(_grid("living", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]))
	_place(_grid("galley", [Vector2i(2, 0), Vector2i(3, 0)]))
	var before := builder.interior_doors.size()
	_place(_grid("hygiene", [Vector2i(2, 1), Vector2i(3, 1)]))
	_check(builder.interior_doors.size() == before + 1, "a room next to two others gets one door (%d added)" % (builder.interior_doors.size() - before))

	# Angled + angled of different purposes.
	_reset()
	_place(_angled("living", [Vector2(-1.5, -1.5), Vector2(4.5, -1.5), Vector2(4.5, 4.5), Vector2(1.5, 4.5), Vector2(-1.5, 1.5)]))
	_place(_angled("medical", east_angled))
	_check(builder.interior_doors.size() == 1 and builder.interior_doors[0].has("wall_a"), "angled rooms of different purposes get one door")

	# Corridors keep their own open-end rule (no extra door).
	_reset()
	_place(_grid("living", square))
	_place(_grid("corridor", [Vector2i(2, 0), Vector2i(3, 0)]))
	_check(builder.interior_doors.is_empty(), "corridors connect by their open end, not an added door")

	# Corridor pieces laid end to end become one corridor; undo splits them.
	_reset()
	_place(_grid("corridor", [Vector2i(0, 0)]))
	_place(_grid("corridor", [Vector2i(1, 0), Vector2i(2, 0)]))
	_check(_count("corridor") == 1 and (builder.zones[0].cells as Array).size() == 3, "in-line corridor pieces merge into one corridor")
	builder._undo()
	_check(_count("corridor") == 1 and (builder.zones[0].cells as Array).size() == 1, "undo splits the corridor back")
	_place(_grid("corridor", [Vector2i(0, 1)]))
	_check(_count("corridor") == 1 and (builder.zones[0].cells as Array).size() == 2, "a piece continuing the line merges")
	_place(_grid("corridor", [Vector2i(1, 1)]))
	_check(_count("corridor") == 2, "a piece beside the line (a bend) stays separate")

	# Corridor near an angled room's corner: grid placement is not taken over
	# by the 45° wall tool unless the cursor is right at that wall.
	_reset()
	var big := [Vector2(-7.5, -1.5), Vector2(-1.5, -7.5), Vector2(4.5, -7.5), Vector2(10.5, -1.5), Vector2(10.5, 4.5), Vector2(4.5, 10.5), Vector2(-1.5, 10.5), Vector2(-7.5, 4.5)]
	_place(_angled("living", big))
	builder.kind = "corridor"
	for x in [0.0, 3.0, 4.5, 6.0]:
		_check(builder._angled_outline_mount_at(Vector2(x, -9.0)).is_empty(), "beside the straight wall at x=%s a corridor stays a grid piece" % x)
	_check(not builder._angled_outline_mount_at(Vector2(8.2, -4.8)).is_empty(), "right at the 45° wall the angled corridor is offered")

	if failures == 0:
		print("Room joining test passed: same-purpose merges (any shape, with undo), automatic removable doors, plan markers.")
	quit(1 if failures > 0 else 0)
