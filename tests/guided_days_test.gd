extends SceneTree

# The guided days, version 2 (docs/opening-days.md; scripts/opening_days.gd,
# drop_field.gd, radio.gd):
# - a new game plays version 2: no GAR-Y on day 1, its pallet out of sight;
# - from the ridge Castellanos names pallets 2 and 4 (not 3);
# - the first call: the hatch stays shut till you answer Castle;
# - chapters on the real sun: never held; not done by dusk, Castle says
#   tomorrow (d1_dusk) and recaps in the morning (d1_still); done, the
#   sunset call, and the next chapter the morning after;
# - a blackout before GAR-Y: something unseen brings you home, no leak;
# - the landing seat takes Z;
# - day 2's wake call brings GAR-Y out at work past its empty cradle; the
#   cradle rings Castellanos; walk up and GAR-Y meets you; d2_found plays;
# - day 2 holds till GAR-Y's found and the walker's due; then its sunset call;
# - day 4: the module down cold and vented; cartridge and blanket bring the
#   leak; patched, the fit-out, the ice survey; the talk and the owners' notes;
# - saved: the version and the calls.
# godot --headless --path . --script res://tests/guided_days_test.gd
var failures := 0
const BUILD_RULES_ZONE := preload("res://scripts/build_rules.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

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

## The next morning: a sol's gone by.
func _morning(world: Node, radio: Node) -> void:
	world.opening_days.last_morning = world.opening_days._hours_run() - 20.0
	MHGame.sol_hour = 6.5
	await _settle(radio)

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
	player.global_position = lander.cabin_start().position
	MHGame.sol_hour = 9.0
	_check(days.hatch_refusal().contains("answer"), "the hatch stays shut till you answer Castle (%s)" % days.hatch_refusal())
	# The crew's ship behind Mars: once a sol, an hour after sunset, for two hours.
	var window: Vector2 = radio.los_window()
	MHGame.sol_hour = window.x + .5
	_check(not radio.in_contact() and str(radio.link_line()).contains("back at"), "behind Mars after dark: no contact (%s)" % radio.link_line())
	MHGame.sol_hour = 9.0
	_check(radio.in_contact(), "in touch in the morning (%s)" % radio.link_line())
	# A call on air when she goes is finished, not cut off.
	MHGame.sol_hour = window.x + .5
	radio.playing = "d1_sunset"
	_check(radio.in_contact(), "a call on air holds the link past the far side")
	radio.playing = ""
	# The heads-up is dropped once she's gone; the hello, long after she's back.
	_check(radio._stale("los_soon"), "the heads-up is stale once she's gone")
	MHGame.sol_hour = window.x - .2
	_check(not radio._stale("los_soon"), "the heads-up is good just before she goes")
	MHGame.sol_hour = window.y + .3
	_check(not radio._stale("los_back"), "the hello is good just after she's back")
	MHGame.sol_hour = 6.0
	_check(radio._stale("los_back"), "the hello is stale by morning")
	# Waking lets go of last night's calls, but not day 4's sunset talk.
	radio.queue = ["los_back", "d2_dusk", "d1_sunset", "d4_sunset"]
	radio.woke()
	_check(radio.queue == ["d4_sunset"], "waking drops last night's calls (%s)" % str(radio.queue))
	radio.queue.clear()
	# A call cut off by a save plays again.
	var loaded: Node = radio.get_script().new()
	loaded.setup(world, {"heard": {"d2_wake": true}, "playing": "d2_wake"})
	_check(not loaded.heard.has("d2_wake") and loaded.queue == ["d2_wake"], "a call cut off by a save plays again")
	loaded.free()
	MHGame.sol_hour = 9.0
	radio.ring("d1_relock")
	await _settle(radio, .3)
	_check(radio.flag("answered") and days.hatch_refusal() == "", "answered: the hatch opens")
	var hour_was := MHGame.sol_hour
	MHGame.sol_hour = 23.0
	_check(days.hatch_refusal() == "" and not str(days.night_caution()).is_empty(), "no night lock, just a caution")
	MHGame.sol_hour = hour_was
	var seat: Node = lander.get_node_or_null("Cabin_landing_seat_1")
	var seat_ok := seat != null
	if seat != null:
		for body in seat.find_children("*", "StaticBody3D", true, false): seat_ok = seat_ok and body.get_meta("interaction_target", null) == world.cabin_life
	_check(seat_ok, "the landing seat takes Z, all of it")
	_check(radio.heard.has("d1_relock") and notes.is_open("air") and notes.is_open("parachute"), "after the call: the lander and the parachute")
	_check(not notes.is_open("sunset"), "the sunset thought waits for Castellanos too")

	# Day 1: no GAR-Y anywhere.
	_check(not bool(world.gary_met) and world.scout_rover == null, "no GAR-Y on day 1")
	_check(not field.sites.gary.visible, "pallet 3 is out of sight on day 1")
	field.see_from_ridge()
	await _settle(radio, .3)
	_check(known.knows(field.sites.tools.id()) and not known.knows(field.sites.gary.id()), "from the ridge: pallet 4 named, pallet 3 not")
	_check(radio.heard.has("d1_ridge"), "Castellanos calls about the ridge")

	# The real sun: it never waits.
	MHGame.sol_hour = 10.0
	await _settle(radio)
	_check(float(world.day_night.hold_at) < 0.0, "the sun never waits (%.2f)" % world.day_night.hold_at)
	# Not done by dusk: pick it up tomorrow.
	player.global_position = lander.global_position + Vector3(150, 0, 0)
	player.global_position.y = MHSiteTerrain.height(player.global_position.x, player.global_position.z) + 1.0
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d1_dusk") and radio.flag("left_air") and not radio.heard.has("d1_sunset"), "dusk with day 1 undone: Castle says tomorrow")
	await _morning(world, radio)
	_check(radio.heard.has("d1_still") and int(days.chapter) == 1 and not radio.heard.has("d2_wake"), "the next morning: what's left, still chapter 1")
	# Blacking out before GAR-Y: something unseen brings you home.
	MHGame.sol_hour = 10.0
	world.suit.pass_out()
	for i in 80:
		if not bool(world.suit.passed_out): break
		await create_timer(.5).timeout
	await _settle(radio)
	_check(not bool(world.suit.passed_out) and lander.cabin_contains(player.global_position), "you come round in the cabin")
	_check(not bool(world.gary_met) and world.scout_rover == null, "nobody's met: GAR-Y waits for day 2")
	_check(radio.heard.has("d1_blackout") and radio.flag("dragged"), "Castle: something brought you in")
	_check(not bool(world.suit.leak), "no lasting harm in the guided days")
	MHGame.sol_hour = 10.0
	world.storm_drop.pallet.opened = true
	field.sites.power.pallet.opened = true
	field.sites.tools.pallet.opened = true
	await _settle(radio)
	_check(radio.heard.has("d1_pallet1") and radio.heard.has("d1_pallet2") and radio.heard.has("d1_pallet4"), "a call as each pallet opens")
	player.global_position = lander.global_position + lander.global_basis.z * -12.0 + Vector3(0, 1, 0)
	pod.done("tow")
	await _settle(radio)
	_check(radio.heard.has("d1_cargo"), "a call when the cargo's home")
	_check(not is_inf(days.sunset_spot.x) and world.known.things.has("sunset_spot") and radio.flag("cargo_early"), "Castellanos marks a rise, and the rest of the day's yours")
	_check(not radio.heard.has("d1_sunset"), "no sunset call before dusk")
	player.global_position = days.sunset_spot + Vector3(2, 1, 0)
	await _settle(radio)
	_check(bool(days.sunset_reached), "on the rise")
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d1_sunset"), "dusk: the sunset call")
	_check(radio.flag("on_the_rise") and world.known.finished("sunset_spot"), "the rise mark's done")
	print("  the rise: %.0f m from the lander, %.1f m up" % [Vector2(days.sunset_spot.x - lander.global_position.x, days.sunset_spot.z - lander.global_position.z).length(), days.sunset_spot.y - lander.global_position.y])
	player.global_position = lander.cabin_start().position
	_check(notes.is_open("bed"), "it ends in bed")
	_check(float(world.day_night.time_scale) == 1.0, "the clock's at its own pace")

	# Night, then day 2.
	days.nights = 1
	await _morning(world, radio)
	_check(int(days.chapter) == 2, "chapter 2 the morning after")
	_check(radio.heard.has("d2_wake"), "Castellanos wakes you: something's moving")
	_check(bool(field.gary_working) and world.scout_rover != null, "GAR-Y is out at work")
	_check(field.sites.gary.visible and bool(field.sites.gary.pallet.opened), "its cradle is there now, open")
	_check(known.knows("gary_moving"), "the movement is on your Map")
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
	_check(days.day_done(2), "jobs done")
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d2_sunset"), "day 2's sunset call")

	# Day 3: the walker set right crawls home overnight; you mark the spot.
	var walker: Node3D = world.walker
	days.nights = 2
	await _morning(world, radio)
	_check(radio.heard.has("d3_wake"), "day 3's morning call")
	var walker_seen_before := bool(walker.seen)   # (seen already, she has no need to mark the tracks)
	_check(walker_seen_before or (bool(walker.tracks_laid) and known.things.has("walker_tracks_start")), "she marks where the tracks start")
	player.global_position = walker.tracks_start()
	await _settle(radio)
	_check(walker_seen_before or radio.heard.has("d3_tracks"), "at the tracks, she says how to find the rest")
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
	await _morning(world, radio)
	_check(str(walker.state) in ["parked", "carrying"] and walker.global_position.distance_to(walker.home) < 30.0, "dawn: Walker 1 is home (%s)" % walker.state)
	_check(radio.heard.has("d4_wake"), "day 4's morning call")
	_check(days.guided() and not days.in_lander_days(), "day 4: still guided, not the lander")

	# Day 4: down cold and open to Mars; air and power in, a seam won't hold.
	if BUILD_RULES_ZONE.module_zone(world.builder).is_empty():   # the test's mark has no plan behind it
		world.builder.zones.append({"kind": "general", "cells": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5)], "carried": true, "cost": 0})
		world.builder.zones.append({"kind": "airlock", "cells": [Vector2i(3, 6)], "cost": 0})
	if str(walker.state) != "done": walker._finish_set_down()
	await _settle(radio)
	var module: Node = world.module_life
	_check(module != null and bool(module.core.vented) and not bool(module.commissioned) and float(module.core.temp_c) < 0.0, "the module comes down cold and unpressurised")
	_check(radio.heard.has("d4_down"), "Castle: air and power")
	if module != null:
		var cartridge: Node = root.get_tree().get_first_node_in_group("o2_cartridge")
		if cartridge != null:
			cartridge.where = "plugged"
			cartridge.plugged_into = "module"
		module.add_cartridge(1.0)
		_check(module.leak == null, "no leak till the blanket's in too")
		module.blanket(true)
		await _settle(radio)
		_check(module.leak != null and radio.heard.has("d4_leak"), "air and power in: a seam hisses, Castle calls")
		_check(not days.day_done(4), "day 4 waits for the leak")
		field.tools = true
		if module.leak != null: module.leak.interact()
		await _settle(radio)
		_check(not bool(module.core.vented) and bool(module.commissioned) and radio.heard.has("d4_patched"), "patched: it holds")
		_check(not radio.heard.has("d4_home"), "the fit-out isn't done yet")
		var b: Node = world.builder
		var cells: Array = module.zone().get("cells", [])
		var spot: Vector3 = Vector3(cells[0].x * b.CELL, b.habitat_base_y, cells[0].y * b.CELL) if not cells.is_empty() else Vector3.ZERO
		for id in ["crew_bunk", "galley", "desk"]: b.placed_interior.append({"id": id, "position": spot, "placement_id": "t_" + id})
		await _settle(radio)
		_check(radio.heard.has("d4_home") and int(days.survey_from) >= 0, "fitted out: Castle's home call, then the survey ask")
		_check(not days.day_done(4), "day 4 waits for the ice")
		var centre: Vector3 = module._centre()
		MHChapterOne.record_core({"x": centre.x + 40.0, "z": centre.z, "purity": .6, "dry": false, "depth_m": 1.0, "good": true})
		await _settle(radio)
		_check(radio.heard.has("d4_ice") and not is_inf(days.ice_spot.x) and known.things.has("ice_spot"), "good ice near the module: its spot, marked")
		_check(days.day_done(4), "day 4 done: down, patched, fitted, ice")
		# A good core taken by the module before she asked counts: you're ahead of them.
		days.survey_from = -1
		days.ice_spot = Vector3.INF
		(radio.handlers["survey_start"] as Callable).call([])
		_check(radio.flag("cored_already") and not is_inf(days.ice_spot.x) and radio.has_section("d4_cored"), "a core taken before the ask is the module's ice")
		radio.ring("d4_sunset")
		await _settle(radio, 2.0)
		_check(radio.heard.has("goal_humans") and radio.heard.has("d4_sunset_deal"), "the talk goes round the room")
		var texts: Node = world.orbiter_texts
		_check(texts != null and texts.has("d4_note_tupou") and texts.has("d4_note_mwangi") and texts.has("d4_note_rao") and texts.has("d4_note_achterberg"), "each owner sends a note")
		days.nights = 4
		await _morning(world, radio)
		_check(not days.guided(), "the morning after: the guided chapters are over")

	# Saved.
	var state: Dictionary = days.export_state()
	_check(int(state.get("version", 0)) == 2 and int(state.get("sunset_called", 0)) >= 3 and state.has("chapter"), "the version, the chapter and the calls are saved")
	_check((world.radio.export_state().heard as Dictionary).has("d2_found"), "the radio's heard calls are saved")

	print("guided_days_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
