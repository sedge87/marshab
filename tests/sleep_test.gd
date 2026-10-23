extends SceneTree

# Run with: godot --headless --path . --script res://tests/sleep_test.gd
# Batch E: sleep at a bunk. Only inside, never with a critical alert up; the
# clock runs fast until the time's up; a critical alert or an arriving dust
# storm wakes you; Esc-style early waking works; and the summary says what
# changed. The bunk offers Z Sleep.
func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "survival"
	MHGame.debug_free_power = true
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var bunk := Vector3(1.5, b.habitat_base_y, 1.0)
	b.place_free_interior_equipment("crew_bunk", bunk, 0.0, Vector2i.ZERO, b.free_interior_visual("crew_bunk", bunk, 0.0))
	await process_frame
	var rig: Node = null
	for node in world.find_children("*", "", true, false):
		if node.has_method("interact_sleep"): rig = node
	assert(rig != null and str(rig.interaction_prompt().get("sleep", "")) == "Sleep", "A bunk offers Z Sleep.")
	var sleep: Node = world.sleep
	var player: Node3D = world.player
	# Outside: no.
	player.global_position = Vector3(30, 0, 30)
	assert(not sleep.blocked_reason().is_empty(), "You can't sleep outside.")
	player.global_position = Vector3(3.5, b.habitat_base_y + .1, -.5)
	assert(sleep.blocked_reason().is_empty(), "You can sleep in a room (%s)." % sleep.blocked_reason())
	# Two hours pass, then you wake rested.
	world.day_night.set_hour(10.0)
	sleep.sleep(2.0)
	assert(sleep.asleep, "Asleep.")
	for i in 600:
		await process_frame
		if not sleep.asleep: break
	assert(not sleep.asleep and sleep.woke_for == "rested", "You wake up when the time's up (woke for %s)." % sleep.woke_for)
	assert(MHGame.sol_hour >= 12.0 and MHGame.sol_hour < 12.6, "About two hours passed (%.2f)." % MHGame.sol_hour)
	assert(is_equal_approx(world.day_night.time_scale, 1.0), "The clock is back to normal.")
	assert(not bool(player.get_meta("ui_freeze", false)), "You can move again.")
	assert(str(sleep.summary()).contains("alert"), "A summary of what happened (%s)." % sleep.summary())
	# A dust storm arriving wakes you.
	sleep.sleep(8.0)
	for i in 80: await process_frame
	b.simulation().start_storm(1.0)
	for i in 10: await process_frame
	assert(not sleep.asleep and sleep.woke_for == "storm", "The storm woke you (%s)." % sleep.woke_for)
	b.simulation().storm_hours_left = 0.0
	# A critical alert wakes you, and stops you going back to sleep.
	sleep.sleep(8.0)
	for i in 30: await process_frame
	# The power goes: life support stops, a critical alert.
	MHGame.debug_free_power = false
	b.simulation().battery_kwh = 0.0
	b.simulation().invalidate()
	for i in 60:
		await process_frame
		if not sleep.asleep: break
	assert(not sleep.asleep and sleep.woke_for == "alert", "A critical alert woke you (%s)." % sleep.woke_for)
	assert(not sleep.blocked_reason().is_empty(), "No sleeping with a critical alert up.")
	MHGame.debug_free_power = true
	for i in 30:
		await process_frame
		if sleep.blocked_reason().is_empty(): break
	# Waking early.
	sleep.sleep(8.0)
	for i in 20: await process_frame
	sleep.wake("early")
	assert(not sleep.asleep and sleep._slept < 8.0, "Esc wakes you early.")
	print("Sleep test passed: bunks, where and when, the fast clock, waking for storms and critical alerts, waking early and the summary.")
	quit(0)
