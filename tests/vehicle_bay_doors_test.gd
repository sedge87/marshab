extends SceneTree

# Run with: godot --headless --path . --script res://tests/vehicle_bay_doors_test.gd
# A vehicle bay joins the habitat like any room: a door is added when it's
# placed beside a room (or a room beside it), the doorway is open (no wall
# from either side), an airlock can open straight into it, corridor ends get a
# hatch, a removed door stays removed, and older saves get their door once.
# Every hatch into the bay is interlocked with its hangar door.

var world: Node
var b
var failures := 0

func _check(ok: bool, what: String) -> void:
	if ok: return
	failures += 1
	print("FAIL ", what)

func _place(zone: Dictionary) -> void:
	# As the Site plan does it: add the zone, rebuild, then join it up.
	b.zones.append(zone)
	b._history.append({"type": "zone", "zone": zone})
	b._rebuild()
	b._after_room_placed()

func _room(kind: String, cells: Array, door := Vector2i(0, -1)) -> Dictionary:
	return {"kind": kind, "cells": cells, "door_direction": door, "cost": 0}

func _reset() -> void:
	b.zones = []
	b.interior_doors = []
	b._history = []
	b._rebuild()
	for i in 2: await physics_frame

## Doors near a point (any label), opened, then: is the way through clear?
func _through(a: Vector2, c: Vector2) -> bool:
	var mid := (a + c) * .5
	for door in get_nodes_in_group("airlock_door"):
		if Vector2(door.global_position.x, door.global_position.z).distance_to(mid) < 1.0: door.request_open()
	for i in 150: await physics_frame
	var y: float = b.habitat_base_y + 1.2
	var query := PhysicsRayQueryParameters3D.create(Vector3(a.x, y, a.y), Vector3(c.x, y, c.y))
	# The parked rover isn't a wall.
	if world.crew_rover != null: query.exclude = [world.crew_rover.get_rid()]
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _doors_between(first: Dictionary, second: Dictionary) -> int:
	var count := 0
	for data in b.interior_doors:
		var cell: Vector2i = data.get("cell", data.get("outline_grid_cell", Vector2i(999, 999)))
		var side: Vector2i = data.get("side", data.get("outline_grid_side", Vector2i.ZERO))
		var here: Array = first.get("cells", [])
		var there: Array = second.get("cells", [])
		if (here.has(cell) and there.has(cell + side)) or (there.has(cell) and here.has(cell + side)): count += 1
		elif data.has("outline_grid_cell") and (here.has(cell) or there.has(cell)): count += 1
	return count

func _bay_doors_near(point: Vector2) -> Array:
	return get_nodes_in_group("airlock_door").filter(func(d): return str(d.door_label()) == "BAY" and Vector2(d.global_position.x, d.global_position.z).distance_to(point) < 1.0)

## Every room's light switch is on a wall: something solid that isn't a door
## (or a hangar) within 0.35 m behind it.
func _switches_on_walls(where: String) -> void:
	for i in 2: await physics_frame
	var space := root.get_world_3d().direct_space_state
	for panel in get_nodes_in_group("room_light_panel"):
		var at: Vector3 = panel.global_position
		var on_wall := false
		for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var query := PhysicsRayQueryParameters3D.create(at, at + dir * .35)
			query.exclude = [panel.get_rid()]
			query.hit_from_inside = true   # it sits in the wall's thickness
			var hit := space.intersect_ray(query)
			if hit.is_empty(): continue
			var node: Node = hit.collider
			var in_door := false
			while node != null:
				if node.is_in_group("airlock_door"): in_door = true
				node = node.get_parent()
			if not in_door: on_wall = true
		_check(on_wall, "%s: the %s light switch is on a wall (at %s)" % [where, str(panel.get("room_label")), at])

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.save_directory = "user://test_habitats"; MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	b = world.builder
	world.player.global_position = Vector3(-40, 5, -40)

	# 1. A room, then a vehicle bay beside it (east), hangar facing south.
	await _reset()
	var living := _room("living", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	_place(living)
	var bay := _room("vehicle_bay", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], Vector2i(0, 1))
	_place(bay)
	_check(_doors_between(living, bay) == 1, "room then bay: one door recorded between them (%d)" % _doors_between(living, bay))
	_check(_bay_doors_near(Vector2(4.5, 0)).size() + _bay_doors_near(Vector2(4.5, 3)).size() == 1, "room then bay: one sealed BAY hatch on the shared wall")
	var door_row := 0.0 if not _bay_doors_near(Vector2(4.5, 0)).is_empty() else 3.0
	_check(await _through(Vector2(3.0, door_row), Vector2(6.5, door_row)), "room then bay: the doorway is open, no wall left in it")
	await _switches_on_walls("room then bay")

	# 2. A vehicle bay first, then a room beside it (west).
	await _reset()
	bay = _room("vehicle_bay", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], Vector2i(0, 1))
	_place(bay)
	living = _room("living", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	_place(living)
	_check(_doors_between(living, bay) == 1, "bay then room: one door recorded (%d)" % _doors_between(living, bay))
	door_row = 0.0 if not _bay_doors_near(Vector2(4.5, 0)).is_empty() else 3.0
	_check(not (_bay_doors_near(Vector2(4.5, door_row)).is_empty()), "bay then room: a BAY hatch on the shared wall")
	_check(await _through(Vector2(3.0, door_row), Vector2(6.5, door_row)), "bay then room: the doorway is open")
	await _switches_on_walls("bay then room")

	# 3. An airlock onto the bay's side (west of the bay, outer end west).
	await _reset()
	bay = _room("vehicle_bay", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], Vector2i(0, 1))
	_place(bay)
	b.airlock_direction = Vector2i(-1, 0)
	var airlock_reason: String = b._airlock_invalid_reason([Vector2i(1, 0)])
	_check(airlock_reason.is_empty(), "an airlock may join a vehicle bay (%s)" % airlock_reason)
	_place(_room("airlock", [Vector2i(1, 0)], Vector2i(-1, 0)))
	_check(await _through(Vector2(3.0, 0.0), Vector2(6.5, 0.0)), "airlock into the bay: its inner hatch isn't walled over")
	await _switches_on_walls("airlock into the bay")
	var hangar: Node = get_nodes_in_group("airlock_door").filter(func(d): return str(d.door_label()) == "HANGAR")[0]
	var inner: Node = get_nodes_in_group("airlock_door").filter(func(d): return str(d.door_label()) == "INNER")[0]
	_check(hangar.get("_partners") == null or (hangar.get("_partners") as Array).has(inner) or hangar.call("_habitat_inner_doors_closed") != null, "the airlock's inner hatch is interlocked with the hangar")
	# With the airlock's inner hatch open, the hangar waits for it to close.
	for d in get_nodes_in_group("airlock_door"): d.request_shut()
	for i in 150: await physics_frame
	inner.request_open()
	for i in 150: await physics_frame
	hangar.toggle()
	for i in 150: await physics_frame
	_check(not hangar.is_open() or not inner.is_open(), "interlock: the hangar and the airlock's inner hatch are never open together")

	# 4. A corridor end onto the bay.
	await _reset()
	bay = _room("vehicle_bay", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], Vector2i(0, 1))
	_place(bay)
	_place(_room("corridor", [Vector2i(0, 0), Vector2i(1, 0)]))
	_check(not _bay_doors_near(Vector2(4.5, 0)).is_empty(), "a corridor end meeting the bay gets a BAY hatch")
	_check(await _through(Vector2(1.0, 0.0), Vector2(6.5, 0.0)), "corridor into the bay: open through")
	await _switches_on_walls("corridor into the bay")

	# 5. A bay between two rooms: joined to at least one, and each joined room
	# has an open doorway.
	await _reset()
	var west := _room("galley", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	var east := _room("engineering", [Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)])
	_place(west); _place(east)
	bay = _room("vehicle_bay", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], Vector2i(0, 1))
	_place(bay)
	_check(_doors_between(west, bay) + _doors_between(east, bay) >= 1, "a bay between two rooms is joined to one")
	for room in [west, east]:
		if _doors_between(room, bay) == 0: continue
		var x := 4.5 if room == west else 10.5
		var row := 0.0 if not _bay_doors_near(Vector2(x, 0)).is_empty() else 3.0
		var from := Vector2(x - 2.5, row) if room == west else Vector2(x + 2.5, row)
		var to := Vector2(x + 2.0, row) if room == west else Vector2(x - 2.0, row)
		_check(await _through(from, to), "bay between rooms: open into the %s" % str(room.kind))

	# 6. Remove the bay's door: it stays removed after rebuilding.
	var before: int = b.interior_doors.size()
	b.interior_doors = b.interior_doors.filter(func(d): return _doors_between(bay, {"cells": []}) >= 0 and not ((bay.cells as Array).has(d.get("cell", Vector2i(999, 999))) or (bay.cells as Array).has((d.get("cell", Vector2i(999, 999)) as Vector2i) + (d.get("side", Vector2i.ZERO) as Vector2i))))
	b._rebuild()
	_check(b.interior_doors.size() < before and _doors_between(west, bay) + _doors_between(east, bay) == 0, "a door you remove from the bay stays removed")

	# 7. An older save: a bay with no recorded door gets one, once.
	await _reset()
	b.zones = [_room("living", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]),
		_room("vehicle_bay", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], Vector2i(0, 1))]
	b.interior_doors = []
	b._rebuild()
	_check(b.interior_doors.size() == 1, "an older save's bay gets its door recorded on load (%d)" % b.interior_doors.size())
	b._rebuild()
	_check(b.interior_doors.size() == 1, "and only once")

	# 8. A free-form room beside a bay.
	await _reset()
	var outline := PackedVector2Array([Vector2(-7.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 4.5), Vector2(-4.5, 4.5)])
	var free := {"kind": "science", "cells": b._freeform_cells(outline), "outline": outline, "door_direction": Vector2i(0, -1), "cost": 0}
	_place(free)
	bay = _room("vehicle_bay", [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)], Vector2i(0, 1))
	_place(bay)
	_check(b.interior_doors.size() == 1, "a free-form room beside a bay gets a door (%d)" % b.interior_doors.size())
	var free_row := 0.0 if not _bay_doors_near(Vector2(1.5, 0)).is_empty() else 3.0
	_check(await _through(Vector2(-1.5, free_row), Vector2(4.5, free_row)), "free-form room into the bay: open")
	await _switches_on_walls("free-form room into the bay")

	# 9. A bay south of a room (a horizontal shared wall), hangar facing east.
	await _reset()
	living = _room("living", [Vector2i(0, 0), Vector2i(1, 0)])
	_place(living)
	bay = _room("vehicle_bay", [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)], Vector2i(1, 0))
	_place(bay)
	_check(_doors_between(living, bay) == 1, "bay south of a room: one door (%d)" % _doors_between(living, bay))
	var col := 0.0 if not _bay_doors_near(Vector2(0, 1.5)).is_empty() else 3.0
	_check(not _bay_doors_near(Vector2(col, 1.5)).is_empty(), "bay south of a room: a BAY hatch on the shared wall")
	_check(await _through(Vector2(col, 0.0), Vector2(col, 3.5)), "bay south of a room: the doorway is open")
	await _switches_on_walls("bay south of a room")

	if failures == 0:
		print("Vehicle bay doors test passed: room then bay, bay then room, an airlock into the bay and its interlock, a corridor end, a bay between rooms, removed doors, older saves, a free-form room and a bay south of a room.")
	quit(1 if failures > 0 else 0)
