extends SceneTree

# GAR-Y orders (backlog 29-30): Stay, Fetch (brings it to you), Patrol, Go home
# without a dock, Survey there and Core sample outside (with the research
# boost in the Science Lab), the airlock rule, the radial menu's sectors and
# the mission counters behind Mission 2's survey step and Mission 6's goal.
# Run with: godot --headless --path . --script res://tests/gar_y_orders_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end: await physics_frame

func _wait_until(seconds: float, done: Callable) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not done.call(): await physics_frame

func _room(kind: String, x0: int, w: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame._settings["gary_autonomy"] = false
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.time_scale = 0.0
	world.day_night.set_hour(12.0)
	var b: BuildController = world.builder
	b.zones = [_room("living", 0, 3), _room("science", 3, 3), {"kind": "airlock", "cells": [Vector2i(1, 3)], "door_direction": Vector2i(0, 1), "cost": 1500}]
	b._rebuild()
	b.place_interior_door(Vector2i(2, 1), Vector2i(1, 0))
	for i in 5: await process_frame
	var y := b.habitat_base_y
	var g = world.scout_rover
	var p: CharacterBody3D = world.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(0.0, y + .2, 1.5)
	g.global_position = Vector3(3.0, y + .2, 3.0)
	g.velocity = Vector3.ZERO

	# The menu: inside orders, and its sectors.
	_check(g.available_orders() == ["come", "stay", "home", "fetch", "patrol"], "inside: come, stay, home, fetch, patrol")
	var menu = world.gar_y_orders
	menu._orders = g.available_orders()
	_check(menu._sector(Vector2(0, -100)) == 0 and menu._sector(Vector2(100, 0)) == 1 and menu._sector(Vector2(0, 10)) == -1, "pointing up picks the first order, right the second, the centre none")

	# Stay.
	_check(g.order("stay").is_empty() and g.staying and g.status_text().begins_with("staying"), "Stay: it waits")
	var held: Vector3 = g.global_position
	await _wait(2.0)
	_check(g.global_position.distance_to(held) < .5, "and doesn't wander off")

	# Fetch: the sample jars from the lab, brought to you.
	var jars_at := Vector3(14.0, y, 2.0)
	b.place_free_interior_equipment("sample_jars", jars_at, 0.0, Vector2i(5, 1), b.free_interior_visual("sample_jars", jars_at, 0.0))
	_check(g.order("fetch").is_empty() and g.task == "fetch", "Fetch: it goes for the sample jars")
	await _wait_until(30.0, func(): return g.task.is_empty())
	var jars: Array = b.placed_interior.filter(func(i): return str(i.id) == "sample_jars")
	var near := not jars.is_empty() and Vector2((jars[0].position as Vector3).x - p.global_position.x, (jars[0].position as Vector3).z - p.global_position.z).length() < 2.6
	_check(near, "and puts them down by you (%s)" % [jars[0].position if not jars.is_empty() else "none"])

	# Patrol: every room, then a report.
	_check(g.order("patrol").is_empty() and g.task == "patrol", "Patrol starts")
	await _wait_until(40.0, func(): return g.task.is_empty())
	_check(g.task.is_empty(), "and finishes")

	# Go home without a dock: a reason.
	_check(g.order("home").contains("Dock"), "Go home with no dock says to build one")

	# The airlock rule: from inside, no survey outside.
	var outside := Vector3(4.0, 0, 18.0)
	outside.y = b._terrain_height(outside)
	_check(g.order("survey", outside).contains("airlock"), "it won't go through the airlock on its own")

	# Outside: survey and core sample.
	g.global_position = Vector3(4.0, b._terrain_height(Vector3(4.0, 0, 14.0)) + .3, 14.0)
	g.velocity = Vector3.ZERO
	p.global_position = Vector3(6.0, b._terrain_height(Vector3(6.0, 0, 14.0)) + 1.0, 14.0)
	await _wait(.5)
	_check(g.available_orders() == ["come", "stay", "home", "survey", "core"], "outside: come, stay, home, survey, core")
	_check(not g.order("survey", Vector3(1.5, y, 1.5)).is_empty(), "surveys are for outside")
	_check(g.order("survey", outside).is_empty(), "Survey there starts")
	await _wait_until(30.0, func(): return g.task.is_empty())
	_check(g.surveys_ordered == 1, "and is counted (%d)" % g.surveys_ordered)
	_check(g.order("core", outside + Vector3(2, 0, 0)).is_empty(), "Core sample starts")
	await _wait_until(30.0, func(): return g.task.is_empty())
	_check(g.has_core, "it has a core sample")
	# Brought inside, it takes the core to the Science Lab.
	g.global_position = Vector3(3.0, y + .2, 3.0)
	g.velocity = Vector3.ZERO
	await _wait_until(40.0, func(): return not g.has_core)
	_check(not g.has_core and float(b.simulation().research_boost_hours) > 200.0, "and delivers it to the lab: a research boost (%.0f h)" % float(b.simulation().research_boost_hours))
	var base := float(b.simulation().daily_flows(false).research)
	b.simulation().research_boost_hours = 0.0
	_check(base >= float(b.simulation().daily_flows(false).research), "the boost raises research")
	_check(g.export_state().has("has_core"), "the core sample is saved")

	# Mission counters (Mission 2's survey step, Mission 6's stretch goal).
	MHGame.game_mode = "missions"
	MHMissions.reset()
	var survey_step: Dictionary = (MHMissions.get_mission("cargo_power_water").steps as Array).filter(func(s): return str(s.id) == "survey")[0]
	MHMissions.bump("gar_y_surveys")
	_check(not MHMissions._step_met(survey_step, b, {}, "cargo_power_water") and MHMissions.step_progress(survey_step, b) == "1 of 2", "one survey: 1 of 2")
	MHMissions.bump("gar_y_surveys")
	_check(MHMissions._step_met(survey_step, b, {}, "cargo_power_water"), "two surveys tick Mission 2's step")
	_check(bool(MHMissions.get_mission("cargo_power_water").rover), "GAR-Y comes on Mission 2")
	_check((MHMissions.get_mission("self_sufficiency").stretch as Array).any(func(s): return str(s.get("key", "")) == "core_sample"), "Mission 6 has the core sample stretch goal")
	MHGame.game_mode = "creative"

	if failures == 0:
		print("GAR-Y orders test passed: stay, fetch, patrol, home, airlock rule, survey, core sample and lab boost, menu, mission counters.")
	quit(1 if failures > 0 else 0)
