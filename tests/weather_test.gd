extends SceneTree

# Dust storms: forecast then storm then clear in the simulation (saved), the
# weather node's warning pill, haze and sound level, the Weather effects
# switch, plus the guitar and plush sounds and the pause menu's closed
# Controls sheet.
# Run with: godot --headless --path . --script res://tests/weather_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.explore_hud.set_minimal(false)
	world.day_night.frozen = true
	var sim = world.builder.simulation()
	sim.random_storms = false
	var weather = world.weather
	_check(weather != null, "the world has a weather node")

	# The simulation: a forecast counts down, then the storm arrives and ends.
	sim.forecast_storm(2.0)
	for i in 3: await process_frame
	_check(weather._state == "forecast" and weather._pill.visible and weather._pill_label.text.begins_with("STORM IN"), "a forecast shows the warning pill (%s)" % weather._pill_label.text)
	_check(weather._toast != null and is_instance_valid(weather._toast), "and a toast")
	var saved: Dictionary = sim.save()
	_check(is_equal_approx(float(saved.storm_eta_hours), sim.storm_eta_hours), "the forecast is saved")
	sim.run_hours(3.0, 12.0)
	_check(sim.storm_hours_left > 0.0 and sim.storm_eta_hours < 0.0, "the storm arrives when the forecast runs out")
	for i in 3: await process_frame
	_check(weather._state == "storm" and weather._pill_label.text.begins_with("DUST STORM"), "the pill switches to the storm")
	weather._level = .9
	weather._haze = .9
	for i in 3: await process_frame
	_check(world.environment.storm > .5, "the sky hazes over (%.2f)" % world.environment.storm)
	# Indoors the storm still fills the windows, but the room itself stays clear:
	# the fog only starts a few metres out, past the walls.
	var cells := []
	for x in range(30, 33):
		for z in range(30, 33): cells.append(Vector2i(x, z))
	world.builder.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}]
	world.builder._rebuild()
	var outside_at: Vector3 = world.player.global_position
	world.player.global_position = Vector3(93, world.builder.habitat_base_y + .2, 93)
	for i in 90: await process_frame
	var env: Environment = world.environment.world_environment.environment
	_check(world.environment.storm > .5, "the storm shows through the windows (%.2f)" % world.environment.storm)
	_check(env.fog_mode == Environment.FOG_MODE_DEPTH and env.fog_depth_begin >= 5.0, "no haze inside the room itself")
	world.player.global_position = outside_at
	weather._level = .9
	weather._haze = .9
	MHGame._settings["weather"] = false
	for i in 3: await process_frame
	_check(is_zero_approx(world.environment.storm) and not weather._storm_dust.emitting, "Weather effects off: no haze or blowing dust")
	MHGame._settings["weather"] = true
	sim.storm_hours_left = 0.0
	for i in 3: await process_frame
	_check(weather._state == "calm" and not weather._pill.visible, "the storm clears and the pill goes")
	_check(MHGame.PRESETS.low.weather == false and MHGame.PRESETS.high.weather == true, "Low turns weather effects off")

	# Guitar and plush make their sounds.
	var b: BuildController = world.builder
	for id in ["guitar", "zero_g_plush"]:
		var v := b.free_interior_visual(id, Vector3(30, 0, 30), 0.0)
		world.add_child(v)
		await process_frame
		var rig: Node = v.get_node("Model")
		_check(str(rig.interaction_prompt().get("primary", "")) in ["Strum a chord", "Give it a squeeze"], "%s has its play action" % id)
		_check(rig.interact(), "%s plays" % id)
		var sound := "sfx/guitar_strum_0" if id == "guitar" else "sfx/plush_squeak_0"
		_check(ResourceLoader.exists("res://assets/audio/%s.wav" % sound), "%s sound exists" % id)

	# The pause menu opens with the Controls sheet closed.
	var pause := MHPauseMenu.new()
	root.add_child(pause)
	await process_frame
	_check(not pause._panels.controls.visible and not pause._panels.saves.visible, "pause opens with its side panels closed")
	pause._toggle_panel("controls")
	_check(pause._panels.controls.visible, "the Controls button opens it")
	pause._toggle_panel("saves")
	_check(pause._panels.saves.visible and not pause._panels.controls.visible, "Save & load replaces it: one panel at a time")
	_check(pause._slots.get_child_count() == MHGame.SAVE_SLOT_COUNT, "a card for every save slot")
	pause.queue_free()
	if failures == 0:
		print("Weather test passed: forecast, storm, haze, effects switch, guitar, plush and the pause menu.")
	quit(1 if failures > 0 else 0)
