extends SceneTree

# The guided days, version 2 (docs/opening-days.md; scripts/opening_days.gd,
# drop_field.gd, radio.gd):
# - a new game plays version 2: no GAR-Y on day 1, its pallet out of sight;
# - from the ridge Castellanos names pallets 2 and 4 (not 3);
# - story time: the sun holds at sunset - 2 h till day 1's done (pallets 1,
#   2, 4 open and the cargo home), then goes; the sunset call ends in bed;
# - day 2's wake call brings GAR-Y out at work past its empty cradle; the
#   cradle rings Castellanos; walk up and GAR-Y meets you; d2_found plays;
# - day 2 holds till GAR-Y's found and the walker's due; then its sunset call;
# - saved: the version and the calls.
# godot --headless --path . --script res://tests/guided_days_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	return world

func _settle(radio: Node, seconds := 1.0) -> void:
	await create_timer(seconds).timeout
	for i in 10: await process_frame

func _initialize() -> void:
	var world = await _new_world()
	var days: Node = world.opening_days
	var field: Node = world.drop_field
	var radio: Node = world.radio
	_check(int(world.opening_version) == 2 and days != null and days.v2(), "a new game plays the guided days, version 2")
	_check(radio != null, "a new game has the radio")
	if days == null or radio == null or field == null:
		quit(1)
		return
	radio.fast = true
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var player: Node3D = world.player
	var lander: Node3D = world.lander
	var notes: Node = world.notes
	var known: Node = world.known
	var pod: Node = world.lifepod

	# Day 1: the first thoughts come out of Castellanos's first call, not before it.
	_check(not notes.is_open("air") and not notes.is_open("parachute") and not notes.is_open("sunset"), "no thoughts about the lander or the parachute before anyone's spoken")
	radio.ring("d1_relock")
	await _settle(radio, .3)
	_check(radio.heard.has("d1_relock") and notes.is_open("air") and notes.is_open("parachute"), "after the call: the lander and the parachute")
	_check(not notes.is_open("sunset"), "the sunset thought waits for Castellanos too")

	# Day 1: no GAR-Y anywhere.
	_check(not bool(world.gary_met) and world.scout_rover == null, "no GAR-Y on day 1")
	_check(not field.sites.gary.visible, "pallet 3 is out of sight on day 1")
	field.see_from_ridge()
	await _settle(radio, .3)
	_check(known.knows(field.sites.tools.id()) and not known.knows(field.sites.gary.id()), "from the ridge: pallet 4 named, pallet 3 not")
	_check(radio.heard.has("d1_ridge"), "Castellanos calls about the ridge")

	# Story time: the sun waits.
	MHGame.sol_hour = 10.0
	await _settle(radio)
	_check(is_equal_approx(float(world.day_night.hold_at), sunset - 2.0), "the sun holds at sunset - 2 h while day 1's undone (%.2f)" % world.day_night.hold_at)
	world.storm_drop.pallet.opened = true
	field.sites.power.pallet.opened = true
	field.sites.tools.pallet.opened = true
	await _settle(radio)
	_check(radio.heard.has("d1_pallet1") and radio.heard.has("d1_pallet2") and radio.heard.has("d1_pallet4"), "a call as each pallet opens")
	_check(float(world.day_night.hold_at) >= 0.0, "still held with the cargo out there")
	player.global_position = lander.global_position + lander.global_basis.z * -12.0 + Vector3(0, 1, 0)
	pod.done("tow")
	await _settle(radio)
	_check(radio.heard.has("d1_cargo"), "a call when the cargo's home")
	_check(not is_inf(days.sunset_spot.x) and world.known.things.has("sunset_spot"), "Castellanos marks a rise to watch from")
	_check(float(world.day_night.hold_at) >= 0.0 and float(world.day_night.time_scale) > 1.0, "the sun goes, a little quicker, then waits for you on the rise")
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(not radio.heard.has("d1_sunset"), "no sunset call till you're there")
	player.global_position = days.sunset_spot + Vector3(2, 1, 0)
	await _settle(radio)
	_check(radio.heard.has("d1_sunset") and bool(days.sunset_reached), "on the rise: the sunset call")
	_check(radio.flag("on_the_rise") and world.known.finished("sunset_spot"), "the rise mark's done")
	print("  the rise: %.0f m from the lander, %.1f m up" % [Vector2(days.sunset_spot.x - lander.global_position.x, days.sunset_spot.z - lander.global_position.z).length(), days.sunset_spot.y - lander.global_position.y])
	player.global_position = lander.cabin_start().position
	_check(notes.is_open("bed"), "it ends in bed")
	_check(float(world.day_night.time_scale) == 1.0, "the clock's back to its pace")

	# Night, then day 2.
	days.nights = 1
	MHGame.sol_hour = 6.5
	await _settle(radio)
	_check(radio.heard.has("d2_wake"), "Castellanos wakes you: something's moving")
	_check(bool(field.gary_working) and world.scout_rover != null, "GAR-Y is out at work")
	_check(field.sites.gary.visible and bool(field.sites.gary.pallet.opened), "its cradle is there now, open")
	_check(known.knows("gary_moving"), "the movement is on your Map")
	_check(is_equal_approx(float(world.day_night.hold_at), sunset - 2.0), "day 2 holds the sun too")
	var gary: Node3D = world.scout_rover
	var work: Vector3 = gary.global_position
	_check(work.distance_to(field.sites.gary.at) > 60.0, "it's working out past its cradle (%.0f m)" % work.distance_to(field.sites.gary.at))

	# The empty cradle.
	player.global_position = field.sites.gary.pallet.global_position + Vector3(4, 1, 0)
	await _settle(radio)
	_check(notes.is_open("cradle_empty") or notes.is_settled("cradle_empty"), "the empty cradle: tracks")
	_check(radio.heard.has("d2_cradle"), "Castellanos on the empty cradle")
	_check(bool(field.gary_working), "GAR-Y's still out there")

	# Found.
	player.global_position = gary.global_position + Vector3(6, 1, 0)
	await _settle(radio, 1.0)
	_check(not bool(field.gary_working) and field.meeting != null, "close up, GAR-Y comes to you")
	for i in 40:
		if field.meeting == null: break
		await create_timer(.5).timeout
	await _settle(radio)
	_check(field.meeting == null, "the meeting finishes")
	_check(radio.heard.has("d2_found"), "Castellanos explains GAR-Y")
	_check(days._gary_found() and not days.day_done(2), "found, but day 2 isn't done till the walker's due")
	pod.walker_due = true
	var crate: Node3D = field.crate
	_check(crate != null and not days.day_done(2), "the spares crate waits to be towed home")
	_check(notes.is_open("salvage"), "Castellanos's call starts the salvage thought")
	pod.prints["hitch"] = true
	gary.global_position = crate.global_position + Vector3(2, 0, 0)
	_check(crate.interact(player) and str(crate.where) == "sled", "hitched to GAR-Y's sled")
	pod.unload_cargo()
	_check(crate.interact(player) and bool(crate.opened), "home and opened")
	await _settle(radio)
	_check(radio.heard.has("d2_crate"), "Castellanos on the crate")
	_check(days.day_done(2) and float(world.day_night.hold_at) < 0.0, "jobs done: the sun goes")
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d2_sunset"), "day 2's sunset call")

	# Day 3: the walker set right crawls home overnight; you mark the spot.
	var walker: Node3D = world.walker
	days.nights = 2
	MHGame.sol_hour = 6.5
	await _settle(radio)
	_check(radio.heard.has("d3_wake"), "day 3's morning call")
	walker.recalibrated()
	await _settle(radio)
	_check(str(walker.state) == "coming" and radio.heard.has("d3_fixed"), "set right, it'll come overnight (%s)" % walker.state)
	_check(not days.day_done(3), "day 3 waits for the spot")
	_check(not pod._open_plans().has(pod.PLANS.size() - 1), "no seal on the printer before the fault's found")
	var cam := Camera3D.new()
	world.add_child(cam)
	var knee: Node3D = walker._knees[3]
	if knee != null:
		cam.global_position = knee.global_position + walker.global_basis.x * 5.0
		cam.look_at(knee.global_position)
		_check(walker.aimed_part(cam) == "knee", "a picture of a knee (%s)" % walker.aimed_part(cam))
		walker.photographed(cam)
		await _settle(radio)
		_check(radio.heard.has("d3_photo_knee") and not bool(walker.fault_found), "Castellanos: the knees are fine")
	var wheel: Vector3 = walker.to_global(Vector3(-7.7, .8, -5.0))
	cam.global_position = wheel + walker.global_basis.x * -5.0 + Vector3(0, 1.0, 0)
	cam.look_at(wheel)
	_check(walker.aimed_part(cam) == "fl_wheel", "a picture of the front-left wheel (%s)" % walker.aimed_part(cam))
	walker.photographed(cam)
	cam.queue_free()
	await _settle(radio)
	_check(bool(walker.fault_found) and radio.heard.has("d3_fault"), "that's the one: the split seal")
	walker.mark({"cells": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5)]})
	await _settle(radio)
	_check(bool(walker.marked) and radio.heard.has("d3_marked") and not days.day_done(3), "the spot's marked; the seal's still wanted")
	_check(pod._open_plans().has(pod.PLANS.size() - 1), "the printer offers the wheel seal")
	pod.printing = "seal"
	pod._printed()
	await _settle(radio)
	_check(radio.heard.has("d3_seal") and days.day_done(3), "seal printed: day 3 done")
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d3_sunset"), "day 3's sunset call")
	_check(days.in_lander_days(), "day 3's night is still in the lander")

	# Day 4: it's home at dawn.
	days.nights = 3
	MHGame.sol_hour = 6.5
	await _settle(radio)
	_check(str(walker.state) in ["parked", "carrying"] and walker.global_position.distance_to(walker.home) < 30.0, "dawn: Walker 1 is home (%s)" % walker.state)
	_check(radio.heard.has("d4_wake"), "day 4's morning call")
	_check(days.guided() and not days.in_lander_days(), "day 4: still guided, not the lander")

	# Saved.
	var state: Dictionary = days.export_state()
	_check(int(state.get("version", 0)) == 2 and int(state.get("sunset_called", 0)) == 3, "the version and the calls are saved")
	_check((world.radio.export_state().heard as Dictionary).has("d2_found"), "the radio's heard calls are saved")

	print("guided_days_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
