extends SceneTree

# Corridors drawn click to click (1 Nov): start on a room, an L to the
# cursor, R flips the bend, each click places a leg of one corridor, a room
# ends it with a hatch, a corridor's side makes a T, and undo takes back one
# leg at a time.
# Run with: godot --headless --path . --script res://tests/corridor_drawing_test.gd
var builder: BuildController
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _room(kind: String, cells: Array) -> Dictionary:
	var zone := {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 50 * cells.size()}
	builder.zones.append(zone)
	builder._rebuild()
	return zone

func _click(cell: Vector2i) -> void:
	builder.hover = cell
	builder._corridor_click()

func _corridors() -> Array:
	return builder.zones.filter(func(z): return str(z.kind) == "corridor")

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	builder = BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	MHGame.debug_free_power = true
	builder.kind = "corridor"

	# ---- room to room, with a bend ----
	var living := _room("living", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	var storage := _room("storage", [Vector2i(8, 4), Vector2i(9, 4), Vector2i(8, 5), Vector2i(9, 5)])
	_click(Vector2i(0, 0))
	_check(builder.corridor_drawing and _corridors().is_empty(), "the first click starts drawing, inside a room")
	var leg := builder._corridor_leg(Vector2i(5, 4))
	_check((leg.cells as Array).size() == 8 and leg.cells[0] == Vector2i(2, 0) and leg.cells.back() == Vector2i(5, 4), "the ghost leaves the room and bends to the cursor (%s)" % [leg.cells])
	builder.corridor_flip = true
	var flipped := builder._corridor_leg(Vector2i(5, 4))
	_check(flipped.cells[0] == Vector2i(0, 2) and flipped.cells.back() == Vector2i(5, 4), "R flips the bend to the other corner (%s)" % [flipped.cells])
	builder.corridor_flip = false
	_click(Vector2i(5, 4))
	_check(_corridors().size() == 1 and builder.corridor_drawing, "a click places the leg and keeps drawing")
	_check(builder.interior_doors.size() == 1 and builder._has_interior_door(Vector2i(2, 0), Vector2i(-1, 0)), "a hatch where it leaves Living Quarters")
	_click(Vector2i(8, 4))
	var corridor: Dictionary = _corridors()[0]
	_check(_corridors().size() == 1 and (corridor.cells as Array).size() == 10, "the next leg grows the same corridor (%d cells)" % (corridor.cells as Array).size())
	_check(not builder.corridor_drawing, "reaching a room finishes it")
	_check(builder.interior_doors.size() == 2 and builder._has_interior_door(Vector2i(7, 4), Vector2i(1, 0)), "and fits a hatch there too")
	_check(builder._should_build_wall(Vector2i(5, 0), Vector2i(1, 0)) and not builder._should_build_wall(Vector2i(5, 0), Vector2i(0, 1)), "the bend is walled on its outside and open along the path")
	_check(builder._should_build_wall(Vector2i(3, 0), Vector2i(0, 1)) and builder._should_build_wall(Vector2i(3, 0), Vector2i(0, -1)), "its sides are solid")
	var inv: Dictionary = builder.simulation().inventory()
	var map: Dictionary = builder.simulation().life.sections(inv)
	var rooms: Array = inv.rooms
	# Lambdas capture locals when made, so the room list is passed in.
	var index_of := func(list: Array, zone: Dictionary) -> int:
		for i in range(list.size()):
			if list[i].zone == zone: return i
		return -1
	_check(map[index_of.call(rooms, living)] != map[index_of.call(rooms, storage)], "the hatches keep the two rooms' air apart (%s)" % [map])

	# ---- undo, a leg at a time ----
	builder._undo()
	_check(_corridors().size() == 1 and (_corridors()[0].cells as Array).size() == 8 and builder.interior_doors.size() == 1, "undo takes back the last leg and its hatch")
	builder._undo()
	_check(_corridors().is_empty() and builder.interior_doors.is_empty(), "and then the first")

	# ---- a T off a corridor's side, and a sealed end ----
	_click(Vector2i(0, 0)); _click(Vector2i(5, 0)); builder._end_corridor_drawing()
	_check(_corridors().size() == 1 and not builder.corridor_drawing, "right-click (or Esc) ends a corridor anywhere")
	_click(Vector2i(4, 0)); _click(Vector2i(4, -3)); builder._end_corridor_drawing()
	_check(_corridors().size() == 2, "a corridor started on another's side is its own corridor")
	_check(builder._corridor_end_connects(Vector2i(4, -1), Vector2i(0, 1)) and not builder._should_build_wall(Vector2i(4, -1), Vector2i(0, 1)), "its end opens into the first corridor's side: a T")
	_check(builder._should_build_wall(Vector2i(4, -3), Vector2i(0, -1)), "the far end is sealed")

	# ---- two legs side by side keep their wall ----
	_click(Vector2i(0, 10)); _click(Vector2i(1, 10)); _click(Vector2i(1, 11)); _click(Vector2i(0, 11)); builder._end_corridor_drawing()
	var hook: Dictionary = _corridors().back()
	_check((hook.cells as Array).size() == 4 and builder._should_build_wall(Vector2i(0, 10), Vector2i(0, 1)), "a U-turn keeps a wall between its legs")
	_click(Vector2i(0, 13)); _click(Vector2i(3, 13)); _click(Vector2i(3, 14)); _click(Vector2i(1, 14)); _click(Vector2i(1, 12))
	_check(builder.corridor_drawing and (_corridors().back().cells as Array).size() == 7, "a leg that would cross the corridor itself isn't placed")
	builder._end_corridor_drawing()

	# ---- an older straight corridor still opens both ends ----
	var old := {"kind": "corridor", "cells": [Vector2i(20, 0), Vector2i(21, 0)], "door_direction": Vector2i(0, -1), "cost": 1200}
	_room("galley", [Vector2i(22, 0)])
	builder.zones.append(old)
	builder._rebuild()
	_check(builder._corridor_end_connects(Vector2i(21, 0), Vector2i(1, 0)) and builder._should_build_wall(Vector2i(20, 0), Vector2i(0, 1)), "a saved straight corridor connects as it did")

	# ---- doors, open walls and windows on a corridor ----
	builder.zones = []; builder.interior_doors = []; builder._history = []
	var lab := _room("science", [Vector2i(4, -5), Vector2i(5, -5), Vector2i(6, -5)])
	_click(Vector2i(2, -6)); _click(Vector2i(8, -6)); builder._end_corridor_drawing()
	_check(not _corridors().is_empty(), "a corridor along the lab (%s)" % builder._invalid_reason([Vector2i(2, -6)]))
	if _corridors().is_empty(): quit(1); return
	var passage: Dictionary = _corridors().back()
	_check(builder.interior_doors.is_empty() and builder._should_build_wall(Vector2i(5, -6), Vector2i(0, 1)), "a corridor running past a room is walled off from it")
	_check(builder.interior_door_invalid_reason(Vector2i(5, -6), Vector2i(0, 1)).is_empty() and builder.place_interior_door(Vector2i(5, -6), Vector2i(0, 1)), "a side doorway into the room it runs past")
	_check(builder.open_wall_invalid_reason({"cell": Vector2i(6, -6), "side": Vector2i(0, 1)}).is_empty() and builder.place_open_wall({"cell": Vector2i(6, -6), "side": Vector2i(0, 1)}), "an open wall beside it")
	_check(not builder._should_build_wall(Vector2i(6, -6), Vector2i(0, 1)) and builder.is_open_wall(Vector2i(6, -6), Vector2i(0, 1)), "the open wall leaves no wall")
	inv = builder.simulation().inventory()
	map = builder.simulation().life.sections(inv)
	rooms = inv.rooms
	_check(map[index_of.call(rooms, lab)] == map[index_of.call(rooms, passage)], "an open wall shares the air (%s)" % [map])
	_check(builder.place_open_wall({"cell": Vector2i(5, -6), "side": Vector2i(0, 1)}) and builder.is_open_wall(Vector2i(5, -6), Vector2i(0, 1)), "the open wall tool takes a door out too")
	_check(builder.place_interior_door(Vector2i(5, -6), Vector2i(0, 1)) and not builder.is_open_wall(Vector2i(5, -6), Vector2i(0, 1)) and builder.interior_doors.size() == 2, "a Room door puts the door back in")
	var bay := builder.window_target_at(Vector3(3.0 * BuildController.CELL, builder.habitat_base_y + 1.4, -6.0 * BuildController.CELL - BuildController.HALF_CELL + .1))
	_check(not bay.is_empty() and builder.window_invalid_reason(bay).is_empty(), "a corridor's outside wall takes a window")

	# ---- 45° legs ----
	builder.zones = []; builder.interior_doors = []; builder._history = []
	var quarters := _room("living", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	var stores := _room("storage", [Vector2i(8, 7), Vector2i(9, 7)])
	_click(Vector2i(0, 0))
	builder.corridor_diagonal = true
	_check(not str(builder._corridor_diagonal_leg(Vector2i(4, 4)).reason).is_empty(), "a 45° leg can't leave a room directly")
	builder.corridor_diagonal = false
	_click(Vector2i(4, 0))
	builder.corridor_diagonal = true
	_check(str(builder._corridor_diagonal_leg(Vector2i(2, 3)).reason).begins_with("Too sharp"), "a 45° leg can't double back")
	var diagonal := builder._corridor_diagonal_leg(Vector2i(8, 3))
	_check(str(diagonal.reason).is_empty() and diagonal.tip == Vector2i(8, 3) and (diagonal.outline as PackedVector2Array).size() == 6, "a 45° leg runs from the next square on to the cursor (%s · %s)" % [diagonal.reason, diagonal.outline])
	_click(Vector2i(8, 3))
	_check(_corridors().size() == 2 and _corridors().back().has("outline") and not builder.corridor_diagonal, "it's placed as a 45° piece; the next leg is straight again")
	_check(builder._corridor_end_connects(Vector2i(4, 0), Vector2i(1, 0)), "the straight leg opens into the 45° piece")
	_check(not str(builder._corridor_leg(Vector2i(5, 3)).reason).is_empty(), "out of a 45° leg the corridor carries straight on")
	_click(Vector2i(8, 7))
	_check(_corridors().size() == 3 and not builder.corridor_drawing, "straight on into the stores, which ends it")
	_check(builder._corridor_end_connects(Vector2i(8, 4), Vector2i(0, -1)) and builder._has_interior_door(Vector2i(8, 6), Vector2i(0, 1)), "joined to the 45° piece, with a hatch at the stores")
	inv = builder.simulation().inventory()
	map = builder.simulation().life.sections(inv)
	rooms = inv.rooms
	var corridor_sections: Array = _corridors().map(func(z): return map[index_of.call(rooms, z)])
	_check(corridor_sections[0] == corridor_sections[1] and corridor_sections[1] == corridor_sections[2], "the three legs share one air (%s)" % [map])
	_check(map[index_of.call(rooms, quarters)] != corridor_sections[0] and map[index_of.call(rooms, stores)] != corridor_sections[0], "the hatches keep both rooms apart")

	if failures == 0:
		print("Corridor drawing test passed: 45° legs, room to room with a bend, R flips it, hatches, walls, air, undo by leg, T's, sealed ends, U-turns, no self-crossing, older saves, side doors, open walls, windows.")
	quit(1 if failures > 0 else 0)
