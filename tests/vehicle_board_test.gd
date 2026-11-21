extends SceneTree

# Run with: godot --headless --path . --script res://tests/vehicle_board_test.gd
# 21 Nov: getting in and out of the vehicles (scripts/vehicle_cabin.gd,
# scripts/crew_rover.gd). The HabRover: E on the rear hatch cycles you through
# its airlock into the aisle, you're on your feet in its air, a galley drawer
# opens, E on the driver's seat sits you down (the camera moves you there),
# E stands you back up, and the airlock lets you out behind it. Docked to a
# port you walk straight through. The buggy: you climb in over its side step
# and back out. The side hatch is the kit locker.

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)
	else:
		print("ok   ", what)

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "freedom"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	var rover = world.crew_rover
	var player: CharacterBody3D = world.player
	for i in 20: await physics_frame
	var cabin: Node = rover._cabin
	_check(cabin != null, "the HabRover has a walk-in cabin")
	if cabin == null:
		quit(1)
		return
	# Parked out on open ground.
	var far := Vector3(40, 0, 40)
	far.y = b._terrain_height(far)
	rover.set_down_at(far)
	for i in 10: await physics_frame
	_check(cabin.walk and rover._hull.disabled, "parked: the walk-in shell is solid, the box is off")
	_check(not str(rover.interaction_prompt().get("primary", "")).begins_with("Drive"), "no 'Drive' from outside: in by the hatch")
	_check(not rover.interact(player), "E on its side doesn't put you in the seat")
	# The rear hatch.
	player.global_position = rover.ground_behind() + (rover.ground_behind() - rover.global_position).normalized() * .5
	for i in 3: await physics_frame
	_check(str(cabin.spot_prompt("hatch").get("primary", "")) == "Open the hatch and go in", "the rear hatch offers to go in")
	var hatch_rest: Basis = cabin._hatch.transform.basis
	_check(cabin.spot_use("hatch", "primary") and cabin.busy, "E on the hatch starts the airlock cycle")
	await _wait(.7)
	_check(not cabin._hatch.transform.basis.is_equal_approx(hatch_rest), "the hatch swings open")
	_check(bool(player.get_meta("ui_freeze", false)), "your feet are the cycle's while it runs")
	await _wait(3.5)
	_check(not cabin.busy and cabin.player_in and cabin.contains(player.global_position), "in the aisle (%s)" % player.global_position)
	_check(cabin._hatch.transform.basis.is_equal_approx(hatch_rest), "the hatch shut behind you")
	_check(rover.aboard() and str(world.suit.where) == "rover" or str(world.suit._where()) == "rover", "you breathe the cab's air (%s)" % world.suit._where())
	_check(float((player.get_node("CollisionShape3D") as CollisionShape3D).shape.height) < 1.7, "a shorter body under the low ceiling")
	_check(str(rover.recall()).begins_with("You're aboard"), "it can't be recalled with you on your feet inside")
	# Standing: on the floor, not falling through.
	var y0 := player.global_position.y
	for i in 30: await physics_frame
	_check(absf(player.global_position.y - y0) < .3, "standing on the cab floor (%.2f -> %.2f)" % [y0, player.global_position.y])
	# A galley drawer.
	_check(str(cabin.spot_prompt("drawer_water").get("primary", "")) == "Open the water drawer", "the water drawer is a target")
	_check(cabin.spot_use("drawer_water", "primary") and bool(rover._cab_open.get("drawer_water", false)), "it slides open")
	cabin.spot_use("drawer_water", "primary")
	# The driver's seat.
	_check(cabin.spot_use("seat", "primary") and rover.driving and rover._boarding, "E on the seat: the camera carries you down into it")
	await _wait(1.2)
	_check(not rover._boarding and not cabin.player_in and rover.aboard(), "seated and driving")
	_check(not cabin.walk and not rover._hull.disabled, "seated: the rover's own collision again")
	rover._exit_pressed()
	_check(rover._boarding and not rover.driving, "E in the seat stands you up")
	await _wait(1.3)
	for i in 5: await physics_frame
	_check(cabin.player_in and player.visible and not bool(player.get_meta("driving", false)), "on your feet in the aisle again (%s)" % player.global_position)
	# Out by the airlock.
	_check(str(cabin.spot_prompt("gates").get("primary", "")) == "Go out (airlock)", "the inner gates: go out")
	cabin.spot_use("gates", "primary")
	await _wait(4.5)
	_check(not cabin.busy and not cabin.player_in and not cabin.contains(player.global_position), "out behind it (%s)" % player.global_position)
	_check(str(world.suit._where()) == "outside", "on your suit again")
	# The kit locker.
	_check(str(cabin.spot_prompt("locker").get("primary", "")) == "Open the kit locker", "the side hatch is the kit locker")
	var locker_rest: Basis = cabin._locker.transform.basis
	cabin.spot_use("locker", "primary")
	await _wait(.6)
	_check(cabin.locker_open and not cabin._locker.transform.basis.is_equal_approx(locker_rest), "it swings open")
	rover.hull = 40.0
	var field: Node = rover._drop_field()
	if field != null: field.tools = true
	else: print("skip patch: no drop field in this world")
	_check(str(cabin.spot_prompt("locker").get("primary", "")).begins_with("Patch the hull"), "a leak: patch it from the locker")
	cabin.spot_use("locker", "primary")
	if field != null: _check(not rover.leaking(), "patched (%d%%)" % roundi(rover.hull))
	# The buggy: over the side step.
	var buggy: Node = world.get("buggy")
	if buggy == null: buggy = world._spawn_vehicle("buggy", {}, true)
	for i in 5: await process_frame
	if buggy != null and buggy._field:
		buggy.wrecked = false
		var spot := far + Vector3(10, 0, -10)
		spot.y = b._terrain_height(spot)
		buggy.set_down_at(spot)
		player.global_position = spot + Vector3(2.5, .2, 0)
		for i in 5: await physics_frame
		_check(buggy._board != Vector3.INF, "the buggy has a side step")
		_check(buggy.interact(player) and buggy.driving and buggy._boarding, "E: you climb in")
		await _wait(1.1)
		_check(not buggy._boarding, "in its seat")
		buggy._exit_pressed()
		_check(buggy._boarding, "E: you climb out")
		await _wait(1.1)
		_check(not buggy.driving and player.visible, "out beside it (%s)" % player.global_position)
	else:
		print("skip buggy: none with a field model in this world")
	print("Vehicle board test %s." % ("passed" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures > 0 else 0)
