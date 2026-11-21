extends SceneTree

# Run with: godot --headless --path . --script res://tests/dock_wreck_test.gd
# 21 Nov: the HabRover's sealed dock and vehicles that break
# (docs/bases-and-vehicles.md). A docking port on a room's outside wall
# becomes its home: it backs on, E on the port walks you aboard, E in the cab
# walks you back into the room. A hard hit wrecks it where it lies: pinned,
# a beacon, fixed with spares; or recalled, GAR-Y tows it home over hours
# and won't survey meanwhile. Its cabin stays a shelter.

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "creative"
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
	for i in 20: await physics_frame
	_check(rover != null and rover._docks_outside(), "the HabRover arrives")
	_check(not rover._home().has("port"), "no port yet: home is the Garage pad")
	# A docking port against the living room's south wall, its back outward.
	var port: Node3D = (load("res://assets/equipment/mars_docking_port_v1/docking_port.tscn") as PackedScene).instantiate()
	world.add_child(port)
	port.global_position = Vector3(0, b._terrain_height(Vector3(0, 0, 1.3)), 1.3)
	port.rotation.y = 0.0
	for i in 5: await process_frame
	_check(port.is_in_group("docking_port") and port.port_outside(), "the port is on an outside wall (out %s)" % port.port_out())
	_check(port._collar != null, "its collar shows outside")
	var home: Dictionary = rover._home()
	_check(home.get("port") == port, "the port is now the HabRover's home")
	rover.park_at_home(false)
	for i in 10: await physics_frame
	_check(rover.docked_at(port), "backed on to the port (%s)" % rover.global_position)
	_check(not rover._umbilical.visible, "no umbilical at a port: it's its own seal")
	var player: Node3D = world.player
	player.global_position = port.global_position - port.port_out() * 1.2 + Vector3.UP * .1
	_check(port.interact(player), "E on the port")
	for i in 3: await physics_frame
	_check(bool(player.get_meta("driving", false)) and rover.driving, "through the hatch into the cab")
	rover._get_out()
	for i in 3: await physics_frame
	_check(not rover.driving and b.is_inside(player.global_position + Vector3.UP), "out the back: into the room (%s)" % player.global_position)
	# Off on a drive: it's wrecked in a hard hit, the cabin still a shelter.
	MHGame.game_mode = "freedom"
	MHChapterOne.stock["spares_kit"] = 0
	var far := Vector3(60, 0, 60)
	far.y = b._terrain_height(far)
	rover.global_position = far
	rover._get_in(player)
	rover._safe = far
	rover._wreck_here("hit")
	_check(rover.wrecked and rover.repair == "crash" and rover.driving, "wrecked in a hit; the HabRover keeps you aboard")
	for i in 5: await physics_frame
	_check(rover.driving and rover.speed == 0.0, "aboard a wreck it doesn't move")
	_check(world.known == null or world.known.things.has("wreck:rover"), "the wreck is pinned on the Map")
	rover._get_out()
	var prompt: Dictionary = rover.interaction_prompt()
	_check(str(prompt.get("primary", "")).begins_with("Fix it"), "a fix prompt (%s)" % str(prompt))
	_check(not rover._work_on_wreck(), "no spares: can't fix")
	MHChapterOne.stock["spares_kit"] = 2
	_check(rover._work_on_wreck() and not rover.wrecked and MHChapterOne.stock.spares_kit == 0, "two spares kits fix it")
	# Wrecked again; recalled: GAR-Y tows it home.
	rover._wreck_here("roll")
	var line: String = rover.recall()
	_check(not rover.tow.is_empty() and float(rover.tow.hours_left) >= 2.0, "recall a wreck: a tow (%s)" % line)
	var gary = world.get("scout_rover")
	if gary != null and gary.has_method("order"):
		_check(str(gary.order("survey", far + Vector3(5, 0, 0))).begins_with("GAR-Y can't"), "GAR-Y won't survey while towing")
	var hours := float(rover.tow.hours_left)
	rover._tow_hour = 0.0
	var passed := 0.0
	while passed < hours + 1.0:
		passed += 10.0
		MHGame.sol_hour = fmod(passed, 24.0)
		rover._tick_tow()
	_check(rover.tow.is_empty() and rover._in_bay() and rover.wrecked, "towed home, still to fix (%s)" % rover.global_position)
	var state: Dictionary = rover.export_state()
	_check(state.get("crash", "") == "roll", "the crash is saved")
	print("Dock and wreck test %s." % ("passed" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures > 0 else 0)
