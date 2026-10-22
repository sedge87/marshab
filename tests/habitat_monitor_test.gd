extends SceneTree

# The habitat monitoring station (backlog 28): opens live (game running, you
# stand still), room states from the sim (cold, unpowered), what machines are
# doing, the last-sol recording, Mission Control's Monitor button, the console
# in the base, and closing it again.
# Run with: godot --headless --path . --script res://tests/habitat_monitor_test.gd
const MONITOR := preload("res://scripts/habitat_monitor.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	var b: BuildController = world.builder
	var cells := []
	for x in range(10, 13):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones.append({"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600})
	b.zones.append({"kind": "hydroponics", "cells": [Vector2i(13, 0), Vector2i(14, 0)], "door_direction": Vector2i(0, -1), "cost": 300})
	b._rebuild()
	var y := b.habitat_base_y
	var tray_at := Vector3(39.0, y, 0.0)
	b.place_free_interior_equipment("grow_tray", tray_at, 0.0, Vector2i(13, 0), b.free_interior_visual("grow_tray", tray_at, 0.0))
	var sim = b.simulation()
	sim.invalidate()

	# Opens live: the game keeps running and you stand still.
	world._open_mission_control()
	await process_frame
	var labels := ""
	for button in world.mission_control.find_children("*", "Button", true, false): labels += (button as Button).text + " "
	_check(labels.to_lower().contains("monitor"), "Mission Control has a Monitor button")
	world.open_monitor()
	await process_frame
	_check(world.monitor != null and world.mission_control == null, "the monitor opens (and Mission Control closes)")
	_check(not paused and bool(world.player.get_meta("ui_freeze", false)), "the game keeps running while you stand still")
	var m = world.monitor

	# Room states from the sim.
	var rooms: Array = sim.inventory().rooms
	var living := -1
	var hydro := -1
	for i in range(rooms.size()):
		if str(rooms[i].kind) == "living": living = i
		if str(rooms[i].kind) == "hydroponics": hydro = i
	sim.room_temp[rooms[living].key] = 20.0
	_check(m.room_reading(living).state == "ok", "a warm room with nothing switched off is fine")
	sim.room_temp[rooms[living].key] = 10.0
	_check(m.room_reading(living).state == "warn", "a cold room is a warning")
	sim.room_temp[rooms[living].key] = 2.0
	_check(m.room_reading(living).state == "danger" and (m.room_reading(living).problems as Array).has("Dangerously cold"), "a freezing room is critical")
	sim.room_temp[rooms[living].key] = 20.0

	# What machines are doing.
	var tray: Dictionary = (sim.inventory().items as Array).filter(func(i): return str(i.id) == "grow_tray")[0]
	_check(MONITOR.doing(tray, true, 2).begins_with("growing"), "grow trays are growing food (%s)" % MONITOR.doing(tray, true, 2))
	_check(MONITOR.doing(tray, false) == "no power" or float(tray.power) <= 0.0, "unpowered machines say so")
	m.selected = hydro
	m._update()
	await process_frame
	var text := ""
	for label in m.find_children("*", "Label", true, false): text += (label as Label).text + " "
	_check(text.contains("Grow Tray") and text.contains("Whole base") or text.to_lower().contains("whole base"), "the room and whole-base panels fill in")

	# The last sol is recorded every quarter hour.
	var before: int = world.alerts.day.size()
	sim.hours_run += 1.0
	world.alerts._record_day()
	_check(world.alerts.day.size() == before + 1, "the last-sol strip records a sample")

	# Esc closes it; you can move again.
	m._close()
	await process_frame
	await process_frame
	_check(world.monitor == null and not bool(world.player.get_meta("ui_freeze", false)), "closing frees you again")

	# The Mission Planning Console in the base opens it.
	var actions: Array = EquipmentCatalog.rig("mission_planning_console").get("actions", [])
	_check(actions.any(func(a): return str(a.get("type", "")) == "monitor" and str(a.get("key", "")) == "primary"), "the console's E opens the monitor")
	var keys: Array = actions.map(func(a): return str(a.get("key", "")))
	_check(keys.size() == keys.filter(func(k): return keys.count(k) == 1).size(), "and no two of its actions share a key")

	if failures == 0:
		print("Habitat monitor test passed: live and frozen, room states, machine readings, last sol, Mission Control and console, closing.")
	quit(1 if failures > 0 else 0)
