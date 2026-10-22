extends SceneTree

# Furnishing: only 1-9 pick cards (letters never change the selection).
# GAR-Y has its name, ping and info. The debug panel's weather buttons work.
# Run with: godot --headless --path . --script res://tests/build_keys_rover_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	var b: BuildController = world.builder
	var cells := []
	for x in range(0, 4):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones = [{"kind": "galley", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}]
	b._rebuild()
	world.player.global_position = Vector3(6, b.habitat_base_y + .2, 4.5)
	var ib = world.interior_builder
	ib.enter()
	await process_frame
	_check(ib._visible_ids().size() > 20, "This room lists plenty of cards (%d)" % ib._visible_ids().size())
	var chosen: String = ib.selected_id
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_SPACE, KEY_SHIFT, KEY_M]:
		ib._unhandled_input(_key(code))
	_check(ib.selected_id == chosen, "letters and movement keys don't change the selection (%s → %s)" % [chosen, ib.selected_id])
	ib._unhandled_input(_key(KEY_3))
	_check(ib.selected_id == str(ib._visible_ids()[2]), "3 picks the third card")
	ib.exit()

	# GAR-Y.
	var rover = world.scout_rover
	_check(rover != null and str(rover.interaction_prompt().label).begins_with("GAR-Y"), "the rover is GAR-Y")
	_check(rover.interact() and rover.interact_info(), "GAR-Y answers a ping and has an info card")

	# Debug weather.
	var panel = world.DEBUG_PANEL_SCRIPT.new()
	panel.setup(world)
	world.add_child(panel)
	await process_frame
	panel._weather("storm")
	_check(b.simulation().storm_hours_left > 0.0 and is_equal_approx(world.weather._level, 1.0), "debug: dust storm now")
	panel._weather("clear")
	_check(b.simulation().storm_hours_left <= 0.0 and b.simulation().storm_eta_hours < 0.0, "debug: clear sky")
	panel._weather("forecast")
	_check(b.simulation().storm_eta_hours > 0.0, "debug: forecast")
	if failures == 0:
		print("Build keys and rover test passed: 1-9 only, GAR-Y, debug weather.")
	quit(1 if failures > 0 else 0)
