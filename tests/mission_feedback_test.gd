extends SceneTree

# Playtest fixes for the missions: build steps un-tick (with a warning) when
# what they needed is removed, the next mission waits to be started after
# "keep improving", the test report shows life support for crewed missions,
# Mission 5's storm is planet-wide, and crew health says why it's falling.
# Run with: godot --headless --path . --script res://tests/mission_feedback_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "missions"; MHGame.pending_save_state = {}
	MHMissions.reset()
	var target: Vector2 = PICKER.suggested()
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = target + Vector2(30, 0)
	for id in ["landing_zones", "cargo_power_water", "cargo_habitat", "crew_land"]: (MHMissions.progress.completed as Array).append(id)
	for id in ["cargo_power_water", "cargo_habitat", "crew_land", "storm_season"]: MHMissions.set_arrived(id)
	MHMissions.progress.current = "crew_land"
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await process_frame
	var b = world.builder

	# A counted build step un-ticks when you remove one.
	var cells := []
	for x in range(10, 14):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones.append({"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600})
	b._rebuild()
	for i in 4:
		var at := Vector3(31.0 + i * 1.6, b.habitat_base_y, 3.0)
		b.place_free_interior_equipment("crew_bunk", at, 0.0, Vector2i(10 + i, 1), b.free_interior_visual("crew_bunk", at, 0.0))
	MHMissions.update_steps(b, world.mission_flags)
	var bunk_step: Dictionary = (MHMissions.current().steps as Array).filter(func(s): return str(s.get("item", "")) == "crew_bunk")[0]
	_check(MHMissions.steps_done("crew_land").has(str(bunk_step.id)), "four bunks tick the bunk step")
	b.remove_free_interior_equipment(str(b.placed_interior[-1].placement_id))
	MHMissions.update_steps(b, world.mission_flags)
	_check(not MHMissions.steps_done("crew_land").has(str(bunk_step.id)) and MHMissions.last_unticked.size() == 1, "removing one un-ticks it")
	_check(MHMissions.step_progress(bunk_step, b) == "3 of 4", "and says how far it's got (%s)" % MHMissions.step_progress(bunk_step, b))

	# The test report: life support strips for a crewed mission.
	var report: Dictionary = MHMissions.run_test(b)
	var life = world.mission_hud.LifeGraph.new()
	life.report = report
	life.size = Vector2(1100, 250)
	root.add_child(life)
	await process_frame
	_check(not (report.samples as Array).is_empty() and (report.samples[0] as Dictionary).has("o2_pct") and (report.samples[0] as Dictionary).has("food_kg"), "the report has the air and food the strips draw")
	life.queue_free()

	# Mission 5's storm blocks 90% of the sunlight.
	var sim = b.simulation()
	sim.start_storm(1.0, .9)
	_check(is_equal_approx(sim.solar_cut(), .9), "a planet-wide storm blocks 90%")
	sim.storm_hours_left = 0.0
	_check(is_zero_approx(sim.solar_cut()), "and nothing once it's over")

	# Crew health says why it's falling.
	sim.co2_pct = 1.5
	sim._crew_condition(1.0, 4, [], [])
	_check(sim.health_causes.has("CO₂ high"), "crew health names the cause (%s)" % [sim.health_causes])

	# Complete the mission but keep building: the next one waits for J.
	MHMissions.complete("crew_land")
	_check(world.mission_hud._next_mission_waiting(), "after completing, Mission 5 waits to be started")
	world.mission_hud._refresh_panel()
	await process_frame
	var panel_text := ""
	for label in world.mission_hud._panel_body.find_children("*", "Label", true, false): panel_text += label.text + " "
	_check(panel_text.contains("Mission 5 is ready") and panel_text.contains("START MISSION 5"), "the panel says Mission 5 is ready (%s)" % panel_text.strip_edges())
	if failures == 0:
		print("Mission feedback test passed: steps un-tick, next mission waits, life support strips, planet-wide storm, health causes.")
	quit(1 if failures > 0 else 0)
