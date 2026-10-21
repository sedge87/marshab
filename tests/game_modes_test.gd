extends SceneTree

# Game modes and debug hooks: sandbox cargo, debug cheats, mode saved with the
# colony, clock control and fly mode.
# Run with: godot --headless --path . --script res://tests/game_modes_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	# Never touch the player's real save slots.
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	var builder: BuildController = world.builder
	var huge_room: Array = []
	for x in range(-19, -2):
		for z in range(-19, -2): huge_room.append(Vector2i(x, z))
	builder.kind = "living"

	# Survival and Freedom: the site's cargo budget applies.
	MHGame.game_mode = "survival"
	_check(MHGame.cargo_budget() == MHGame.mission_cargo_budget(), "survival mode uses the cargo budget")
	_check(builder._invalid_reason(huge_room).contains("cargo"), "survival mode refuses a room bigger than the cargo allows")
	MHGame.game_mode = "freedom"
	_check(builder._invalid_reason(huge_room).contains("cargo"), "freedom mode keeps the cargo limit")
	_check(MHGame.simulation_on() and not MHGame.crew_can_be_harmed(), "freedom runs the simulation without harming the crew")
	# Creative: no limit, no simulation.
	MHGame.game_mode = "creative"
	_check(not builder._invalid_reason(huge_room).contains("cargo"), "creative mode has no cargo limit")
	_check(not MHGame.simulation_on(), "creative mode turns the simulation off")
	# The debug cheat lifts the limit in mission mode too.
	MHGame.game_mode = "survival"
	MHGame.debug_unlimited_cargo = true
	_check(not builder._invalid_reason(huge_room).contains("cargo"), "the unlimited-cargo cheat lifts the limit")
	MHGame.debug_unlimited_cargo = false

	# The mode is saved with the colony and restored on load.
	MHGame.game_mode = "creative"
	var state: Dictionary = world.current_state()
	_check(str(state.get("game_mode", "")) == "creative", "the colony state records its game mode")
	MHGame.game_mode = "survival"
	MHGame.save_habitat(3, state)
	MHGame.prepare_habitat_load(3)
	MHGame.pending_save_state = {}
	_check(MHGame.game_mode == "creative", "loading a creative save returns to creative mode")
	_check(MHGame.normalise_mode("sandbox") == "creative" and MHGame.normalise_mode("mission") == "survival", "old sandbox and mission saves load as creative and survival")
	MHGame.game_mode = "survival"

	# Missions and free play keep separate save slots: the same slot number in
	# each set holds a different habitat, and neither overwrites the other.
	MHGame.game_mode = "survival"
	MHGame.save_habitat(2, {"colony_name": "Free play base", "game_mode": "survival"})
	MHGame.game_mode = "missions"
	MHGame.save_habitat(2, {"colony_name": "Mission base", "game_mode": "missions"})
	_check(str(MHGame.save_slot_summary(2).get("colony_name", "")) == "Mission base", "missions mode reads the mission save in slot 2")
	MHGame.game_mode = "creative"
	_check(str(MHGame.save_slot_summary(2).get("colony_name", "")) == "Free play base", "free-play modes read their own save in slot 2")
	_check(str(MHGame.save_slot_summary(2, "missions").get("colony_name", "")) == "Mission base", "the main menu can list mission saves from any mode")
	# A save from before the split moves into Free play, without overwriting.
	var old_file := FileAccess.open("%s/slot_1.save" % MHGame.save_directory, FileAccess.WRITE)
	old_file.store_var({"version": 1, "saved_at": "old", "state": {"colony_name": "Old base", "game_mode": "mission"}})
	old_file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/free_play/slot_1.save" % MHGame.save_directory))
	_check(str(MHGame.save_slot_summary(1, "free_play").get("colony_name", "")) == "Old base", "an old save moves into the Free play set")
	_check(not FileAccess.file_exists("%s/slot_1.save" % MHGame.save_directory), "the old save file is moved, not copied")
	MHGame.game_mode = "survival"

	# Free power keeps the grid online even with no generation.
	builder.zones = [{"kind": "living", "cells": [Vector2i(0, 0)], "door_direction": Vector2i(0, -1), "cost": 50}]
	MHGame.debug_free_power = true
	_check(builder.grid_power_online(), "free power keeps the grid online")
	MHGame.debug_free_power = false
	_check(not builder.grid_power_online(), "without it, a base with no generation is offline")

	# Clock control.
	var clock: MHSiteDayNight = world.day_night
	clock.set_hour(12.0)
	_check(is_equal_approx(MHGame.sol_hour, 12.0), "setting the hour moves the sol clock")
	clock.frozen = true
	for i in 30: await process_frame
	_check(is_equal_approx(clock.hour, 12.0), "a frozen clock stays put")
	clock.frozen = false

	# Fly mode switches collision off and back on.
	var player: CharacterBody3D = world.player
	player.set_debug_fly(true)
	_check(player.collision_mask == 0, "fly mode turns collision off")
	player.set_debug_fly(false)
	_check(player.collision_mask == 1, "leaving fly mode restores collision")

	if failures == 0:
		print("Game modes test passed: survival, freedom and creative, separate mission saves, debug cargo, saved mode, free power, clock control and fly mode.")
	quit(1 if failures > 0 else 0)
