extends SceneTree

# Free-form (angled) rooms must connect, light and power like grid rooms.
# Run with: godot --headless --path . --script res://tests/angled_room_connections_test.gd
var builder: BuildController
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
		print("FAIL ", what)

# Octagon with straight walls on cell faces and 45° walls corner to corner.
func _octagon(offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in [Vector2(-4.5, -1.5), Vector2(-1.5, -4.5), Vector2(1.5, -4.5), Vector2(4.5, -1.5), Vector2(4.5, 1.5), Vector2(1.5, 4.5), Vector2(-1.5, 4.5), Vector2(-4.5, 1.5)]:
		points.append(p + offset)
	return points

func _room(outline: PackedVector2Array, kind := "living") -> Dictionary:
	return {"kind": kind, "cells": builder._freeform_cells(outline), "outline": outline, "door_direction": Vector2i(0, -1), "cost": 300}

func _grid(kind: String, cells: Array, door := Vector2i(0, -1)) -> Dictionary:
	return {"kind": kind, "cells": cells, "door_direction": door, "cost": 50 * cells.size()}

# True when no wall piece of zone `zone_index`'s edge covers `along`.
func _edge_open_at(zone_index: int, edge_index: int, along: float) -> bool:
	var zone: Dictionary = builder.zones[zone_index]
	var outline := builder.zone_outline(zone)
	var length := outline[edge_index].distance_to(outline[(edge_index + 1) % outline.size()])
	var gaps := builder._outline_wall_doorways(zone) + builder._outline_wall_owned_elsewhere(zone_index, outline)
	for piece in builder._outline_wall_pieces(length, gaps, edge_index):
		if along > float(piece.start) + .01 and along < float(piece.end) - .01: return false
	return true

func _doors(label: String) -> Array:
	var out: Array = []
	for node in builder.root.find_children("*", "AirlockDoor", true, false):
		if not node.is_queued_for_deletion() and (node as AirlockDoor).door_label() == label: out.append(node)
	return out

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	builder = BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame

	# Corners snap to the 3 m cell-corner lattice only.
	_check(BuildController.snap_to_cell_corner(Vector2(.2, 2.9)) == Vector2(1.5, 1.5), "corner snap rounds to the nearest cell corner")
	_check(BuildController.snap_to_cell_corner(Vector2(5.0, -5.0)) == Vector2(4.5, -4.5), "corner snap works off the origin cell")

	# A grid corridor meeting an angled room's straight wall opens into it.
	builder.zones = [_room(_octagon(Vector2.ZERO)), _grid("corridor", [Vector2i(2, 0), Vector2i(3, 0)], Vector2i(1, 0))]
	builder._rebuild()
	_check(not builder._should_build_wall(Vector2i(2, 0), Vector2i(-1, 0)), "corridor end into an angled room has no grid wall")
	_check(_edge_open_at(0, 3, 1.5), "angled room leaves the corridor end open")
	_check(builder._should_build_wall(Vector2i(2, 0), Vector2i(0, -1)), "corridor long side stays solid")

	# Every outdoor flood light sits outside the room; ceiling lights inside.
	var outline := _octagon(Vector2.ZERO)
	var floods := 0
	for light in builder.root.find_children("*", "OmniLight3D", true, false):
		if light.is_queued_for_deletion() or not is_equal_approx((light as OmniLight3D).light_energy, 2.2): continue
		floods += 1
		# Fixtures are direct children of the habitat root, which sits at the origin.
		var at: Vector3 = (light.get_parent() as Node3D).transform * (light as Node3D).position
		_check(not Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), outline), "exterior light at %s must be outside the room" % at)
	_check(floods > 0, "angled room has exterior lights")
	var ceiling := 0
	for fixture in builder.root.find_children("CeilingLight*", "Node3D", true, false):
		if fixture.is_queued_for_deletion(): continue
		var at := (fixture as Node3D).position
		if Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), outline): ceiling += 1
	_check(ceiling > 0, "angled room has ceiling lights")

	# Two angled rooms may share a straight wall; it is built once and takes a door.
	var second := _octagon(Vector2(9, 0))
	builder.zones = [_room(_octagon(Vector2.ZERO))]
	builder._rebuild()
	_check(builder.freeform_invalid_reason(second) == "", "an angled room can be drawn against another: '%s'" % builder.freeform_invalid_reason(second))
	builder.zones.append(_room(second, "science"))
	builder._rebuild()
	_check(not _edge_open_at(0, 3, 1.5), "the earlier room builds the shared wall")
	_check(_edge_open_at(1, 7, 1.5), "the later room does not double the shared wall")
	var target := builder.interior_door_from_world_point(Vector3(4.5, 1.5, 0.2), Vector3(-1, 0, 0))
	_check(target.has("wall_a") and builder.interior_door_target_invalid_reason(target) == "", "shared angled wall accepts an interior door: %s" % target)
	_check(builder.place_interior_door_target(target), "interior door placed on shared angled wall")
	_check(_edge_open_at(0, 3, 1.5), "door opens the shared wall")
	_check(_doors("INTERIOR").size() == 1, "exactly one interior door is built")

	# An angled corridor runs from one room's 45° wall to another's.
	builder.zones = [_room(_octagon(Vector2.ZERO)), _room(_octagon(Vector2(9, -9)), "science")]
	builder.interior_doors.clear()
	builder._rebuild()
	builder.kind = "corridor"
	# Hovering anywhere on a one-cell 45° wall snaps the doorway to its middle.
	var off_centre := builder._angled_outline_mount_at(Vector2(2.3, -3.9))
	_check(not off_centre.is_empty() and builder._angled_outline_mount_invalid_reason(off_centre) == "", "off-centre hover on a short 45° wall still gives a valid doorway: '%s'" % builder._angled_outline_mount_invalid_reason(off_centre))
	var mount := builder._angled_outline_mount_at(Vector2(3, -3))
	_check(not mount.is_empty(), "45° wall offers an angled corridor mount")
	mount["length"] = builder._angled_corridor_length(mount, Vector2(6, -6))
	_check(is_equal_approx(float(mount.length), BuildController.DIAGONAL_CELL), "angled corridor length snaps to whole diagonal cells")
	_check(builder._angled_outline_mount_invalid_reason(mount) == "", "corridor may end on the other room's 45° wall: '%s'" % builder._angled_outline_mount_invalid_reason(mount))
	var far := builder._angled_far_end_target(mount)
	_check(int(far.get("zone_index", -1)) == 1, "far end lands on the second room")
	builder.zones.append({"kind": "corridor", "cells": [], "angled_mount": mount, "door_direction": Vector2i(0, -1), "cost": 100})
	builder._rebuild()
	_check(_edge_open_at(1, int(far.get("edge_index", -1)), (float(far.opening_start) + float(far.opening_end)) * .5), "second room opens where the corridor arrives")
	var inside := (mount.position as Vector2) + (mount.outward as Vector2) * (float(mount.length) - .5)
	_check(builder.is_inside(Vector3(inside.x, builder.habitat_base_y + 1.0, inside.y)), "the far end of a long angled corridor counts as inside")

	# Deleting an earlier zone must not re-home or lose an angled corridor.
	builder.zones.push_front(_grid("storage", [Vector2i(-10, -10)]))
	builder._rebuild()
	builder.zones.remove_at(0)
	builder._rebuild()
	var corridor_left := false
	for zone in builder.zones:
		if zone.has("angled_mount"): corridor_left = int(zone.angled_mount.host_zone) == 0
	_check(corridor_left, "angled corridor keeps its host room after an earlier zone is removed")

	# A vehicle bay beside an angled room gets its personnel door.
	builder.zones = [_room(_octagon(Vector2.ZERO))]
	builder._rebuild()
	builder.kind = "vehicle_bay"
	builder.airlock_direction = Vector2i(1, 0)
	var bay := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)]
	_check(builder._valid_vehicle_bay(bay), "vehicle bay may attach to an angled room")
	builder.zones.append(_grid("vehicle_bay", bay, Vector2i(1, 0)))
	builder._rebuild()
	_check(_doors("BAY").size() == 1, "vehicle bay builds a door into the angled room")

	# Power fields reach angled rooms at their nearest wall.
	builder.kind = "solar"
	_check(builder._valid_power_source([Vector2i(-11, 0)]), "solar 28.5 m from an angled room's wall powers it")

	# Angled rooms take furniture like grid rooms, and it stays after a
	# rebuild even beside a 45° wall (where its grid cell's centre is outside).
	builder.zones = [_room(_octagon(Vector2.ZERO))]
	builder.placed_interior = []
	builder._rebuild()
	_check(str(builder._zone_at_point(Vector2(0.5, 0.5)).get("kind", "")) == "living", "standing in an angled room finds that room")
	var spot := Vector3(-2.2, builder.habitat_base_y, -1.2)
	var reason := builder.free_interior_invalid_reason("locker", spot, Vector3.UP, 0.0)
	_check(reason == "", "a locker fits beside the 45° wall of an angled room: '%s'" % reason)
	var cell := Vector2i(roundi(spot.x / 3.0), roundi(spot.z / 3.0))
	builder.place_free_interior_equipment("locker", spot, 0.0, cell, Node3D.new())
	builder._rebuild()
	_check(builder.placed_interior.size() == 1, "the locker is still there after a rebuild")

	if failures == 0:
		print("Angled room connections test passed: snapping, corridors, shared walls, doors, angled links, lights, bays and power.")
	quit(1 if failures > 0 else 0)
