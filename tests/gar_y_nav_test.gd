extends SceneTree

# GAR-Y gets about on its own: routes room to room through an interior door
# (opening it, closing it behind), never opens an airlock, stays inside when
# you go out, and comes with you after a ping.
# Run with: godot --headless --path . --script res://tests/gar_y_nav_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end: await physics_frame

func _room(kind: String, x0: int, w: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame._settings["gary_autonomy"] = false   # no errands: just getting about
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.time_scale = 0.0
	world.day_night.set_hour(12.0)
	var b: BuildController = world.builder
	b.zones = [_room("living", 0, 3), _room("galley", 3, 3), {"kind": "airlock", "cells": [Vector2i(1, 3)], "door_direction": Vector2i(0, 1), "cost": 1500}]
	b._rebuild()
	_check(b.place_interior_door(Vector2i(2, 1), Vector2i(1, 0)), "an interior door between the living quarters and the galley")
	for i in 5: await process_frame
	var y := b.habitat_base_y
	var g = world.scout_rover
	var p: CharacterBody3D = world.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(1.5, y + .2, 4.5)   # in the airlock chamber, out of the way
	g.global_position = Vector3(0.0, y + .2, 3.0)
	g.velocity = Vector3.ZERO

	# Room to room through the interior door.
	var galley_spot := Vector3(15.0, y, 3.0)
	var route: Array = g._plan_route(galley_spot)
	_check(route.size() == 3, "a route through the door (%d points)" % route.size())
	g._roam_goal = galley_spot
	g._linger = 99.0
	await _wait(10.0)
	_check(g.global_position.distance_to(galley_spot) < 1.6, "GAR-Y drives through to the galley (%s)" % [g.global_position])
	var interior: Array = world.get_tree().get_nodes_in_group("airlock_door").filter(func(d): return d.door_label() == "INTERIOR")
	# 21 Nov: room hatches stand open on their hold-backs (it leaves them be).
	_check(not interior.is_empty() and interior.all(func(d): return d.is_open()), "the room hatch stands open on its hold-back")

	# Never opens an airlock door.
	for door in world.get_tree().get_nodes_in_group("airlock_door"):
		if door.door_label() in ["INNER", "OUTER"]:
			g.global_position = door.global_position + Vector3(0, .2, -1.0)
			g.look_at(door.global_position, Vector3.UP)
			g.velocity = (door.global_position - g.global_position).normalized()
			g._manage_doors()
			await _wait(.6)
			_check(not door.is_open(), "it won't open the %s airlock door" % door.door_label().to_lower())
	_check(not g._door_links().any(func(l): return not (l.door.door_label() in ["INTERIOR", "BAY"])), "its routes only use interior and bay doors")

	# You go outside: it stays in.
	g.global_position = Vector3(3.0, y + .2, 3.0)
	g.velocity = Vector3.ZERO
	p.global_position = Vector3(3.0, b._terrain_height(Vector3(3.0, 0, 30.0)) + 1.0, 30.0)
	await _wait(4.0)
	_check(b.is_inside(g.global_position), "with you outside, GAR-Y stays in the habitat")

	# A ping: it comes with you (follows closely).
	p.global_position = Vector3(12.0, y + .2, 3.0)
	g.interact()
	_check(g._escorting() and g.status_text() == "coming with you", "a ping: come with me")
	await _wait(5.0)
	_check(g.global_position.distance_to(p.global_position) < 3.0, "and it follows you closely (%.1f m)" % g.global_position.distance_to(p.global_position))
	# 21 Nov: GAR-Y cycles an empty airlock by itself: with autonomy on, it goes
	# out to join you, and comes home, one hatch at a time.
	MHGame._settings["gary_autonomy"] = true
	g._escort_until = 0
	g.global_position = Vector3(3.0, y + .2, 3.0)
	p.global_position = Vector3(3.0, b._terrain_height(Vector3(3.0, 0, 16.0)) + 1.0, 16.0)
	await _wait(.5)
	g._apart = 999.0
	var used_airlock := false
	for i in 30:
		await _wait(1.0)
		if g.in_airlock_trip(): used_airlock = true
		if not b.is_inside(g.global_position) and not g.in_airlock_trip(): break
	_check(used_airlock and not b.is_inside(g.global_position), "it cycles the airlock to join you outside (%s)" % g.global_position)
	var hatches: Array = world.get_tree().get_nodes_in_group("airlock_door").filter(func(d): return d.door_label() in ["INNER", "OUTER"])
	await _wait(1.5)
	_check(hatches.all(func(d): return d.is_closed()), "and shuts both airlock hatches behind it")
	p.global_position = Vector3(12.0, y + .2, 3.0)
	await _wait(.5)
	g._apart = 999.0
	for i in 30:
		await _wait(1.0)
		if b.is_inside(g.global_position) and not g.in_airlock_trip(): break
	_check(b.is_inside(g.global_position), "and cycles back in when you're inside (%s)" % g.global_position)
	MHGame._settings["gary_autonomy"] = false
	# Room culling: furniture in another room is only drawn through an open door.
	g.queue_free()
	var desk_at := Vector3(15.0, y, 4.5)
	b.place_free_interior_equipment("work_desk", desk_at, 0.0, Vector2i(5, 1), b.free_interior_visual("work_desk", desk_at, 0.0))
	var desk: Node3D = b.furnishing.get_child(b.furnishing.get_child_count() - 1)
	var door = interior[0]
	if door.is_open(): door.toggle()
	await _wait(1.0)
	b.update_furniture_visibility(Vector3(1.0, y + 1.6, 3.0))
	_check(not desk.visible, "a desk in the galley isn't drawn from the living quarters with the door shut")
	door.toggle()
	await _wait(1.5)
	b.update_furniture_visibility(Vector3(1.0, y + 1.6, 3.0))
	_check(desk.visible, "it is through the open door")
	b.update_furniture_visibility(Vector3(15.0, y + 1.6, 60.0))
	_check(not desk.visible, "and not from far outside")
	if failures == 0:
		print("GAR-Y navigation test passed: rooms via doors, room hatches held open, no airlocks on its routes, stays in, comes with you, cycles an empty airlock by itself both ways, and room culling.")
	quit(1 if failures > 0 else 0)
