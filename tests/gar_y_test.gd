extends SceneTree

# GAR-Y 2.0: the new model's parts, the torch, moods, ping and spin, a survey
# that flags buried ice, carrying an odds-and-ends item to a legal new spot,
# nudging the plush, napping and docking on a charger, the autonomy switch
# and saving its flags.
# Run with: godot --headless --path . --script res://tests/gar_y_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end: await physics_frame

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame._settings["gary_autonomy"] = true
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.time_scale = 0.0
	world.day_night.set_hour(12.0)
	var b: BuildController = world.builder
	var g = world.scout_rover
	_check(g != null and g is MHCompanionRover, "GAR-Y is in the world")
	_check(g._wheels.size() == 6 and g._arm.size() == 3 and g._eyes.size() == 2 and g._grip != null and g._head != null, "the new model: six wheels, arm, eyes, head, grip")
	_check(bool(g._lamp.get_meta("budget_exempt", false)) and not g._lamp.shadow_enabled, "the torch skips the light cap and casts no shadows")
	await _wait(.5)
	_check(g._lamp.light_energy < .05, "no torch in daylight")

	# Ping, then three quick pings for a spin.
	g.interact()
	_check(g.mood == "happy" or g._mood_override == "happy", "a ping makes it happy")
	g.interact(); g.interact()
	_check(g._pings.is_empty(), "three pings: a spin")

	# Survey on buried ice.
	var spot := Vector2.ZERO
	for x in range(-60, 61, 3):
		for z in range(-60, 61, 3):
			if b._ice_richness_at_point(Vector2(x, z)) > b._ice_richness_at_point(spot): spot = Vector2(x, z)
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.global_position = Vector3(spot.x + 1.5, b._terrain_height(Vector3(spot.x, 0, spot.y)) + 1.0, spot.y + 1.5)
	g.global_position = Vector3(spot.x, b._terrain_height(Vector3(spot.x, 0, spot.y)) + .3, spot.y)
	g._start("survey", g.global_position)
	await _wait(5.0)
	_check(g.ice_found == 1 and g.flags.size() == 1, "a survey on ice plants a flag (richness %.2f, flags %d)" % [b._ice_richness_at_point(spot), g.flags.size()])
	var saved: Dictionary = g.export_state()
	_check((saved.flags as Array).size() == 1 and int(saved.ice_found) == 1, "flags and tallies are saved")

	# Indoors: a living room with a mug on the floor and the plush.
	var cells := []
	for x in range(20, 24):
		for z in range(20, 23): cells.append(Vector2i(x, z))
	b.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}]
	b._rebuild()
	var y := b.habitat_base_y
	var mug_at := Vector3(63.0, y, 63.0)
	b.place_free_interior_equipment("crew_mug", mug_at, 0.0, Vector2i(21, 21), b.free_interior_visual("crew_mug", mug_at, 0.0))
	world.player.global_position = Vector3(66.0, y + .2, 64.0)
	g.global_position = Vector3(65.0, y + .2, 62.0)
	g.velocity = Vector3.ZERO
	await _wait(.3)
	_check(g._clutter_candidates().size() == 1, "the mug on the floor is fair game")
	_check(g.start_fetch(), "GAR-Y sets off for the mug")
	await _wait(12.0)
	var mug: Dictionary = b.placed_interior[0]
	_check(g.task.is_empty() and g._carried == null, "the errand finishes (task '%s')" % g.task)
	_check((mug.position as Vector3).distance_to(mug_at) > 1.0 and b.free_interior_move_reason(str(mug.placement_id), mug.position, float(mug.rotation_y)) == "", "the mug ends up somewhere new and legal (%s)" % [mug.position])
	var visual: Node3D = g._item_visual(str(mug.placement_id))
	_check(visual != null and visual.get_parent() == b.furnishing and visual.global_position.distance_to(mug.position) < .05, "its model is back in the room at the new spot")

	# The plush.
	var plush_at := Vector3(60.5, y, 61.0)
	b.place_free_interior_equipment("zero_g_plush", plush_at, 0.0, Vector2i(20, 20), b.free_interior_visual("zero_g_plush", plush_at, 0.0))
	_check(g.start_plush(), "GAR-Y heads for the plush")
	await _wait(8.0)
	_check(g.task.is_empty(), "and gives it a nudge")

	# Night: docks on a rover charger in its room, or naps.
	g._nap()
	_check(g.napping and g.status_text() == "napping", "naps")
	g.interact()
	_check(not g.napping, "a ping wakes it")

	# Autonomy off: no errands start on their own.
	MHGame._settings["gary_autonomy"] = false
	g._mischief_timer = 0.0; g._plush_timer = 0.0; g._survey_timer = 0.0
	await _wait(1.0)
	_check(g.task.is_empty(), "with autonomy off it stays put")
	MHGame._settings["gary_autonomy"] = true

	# Restore flags.
	g.flags = []
	g.restore_state(saved)
	_check(g.flags.size() == 1 and g.ice_found == 1, "flags come back on load")
	if failures == 0:
		print("GAR-Y test passed: model, torch, ping, survey flags, carrying clutter, plush, naps, autonomy switch and saving.")
	quit(1 if failures > 0 else 0)
