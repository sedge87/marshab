extends SceneTree

# The guided chapters, version 2 as rewritten in A6 (docs/opening-days.md;
# scripts/opening_days.gd, drop_field.gd, walker.gd, radio.gd):
# - a new game plays version 2: no GAR-Y in chapter 1, its pallet out of sight;
# - the pallets sit inside the bare suit's reach;
# - from the ridge Castellanos names pallets 2 and 3 (not 4);
# - the first call: the hatch stays shut till you answer Castle;
# - chapters aren't days: not done by dusk, Castle says tomorrow (d1_dusk)
#   and recaps in the morning (d1_still); done, the next chapter comes after
#   a breather on the same sol, and never starts too near dusk;
# - a blackout before GAR-Y: something unseen brings you home, no leak;
# - the landing seat takes Z;
# - chapter 2: GAR-Y out at work past its empty cradle; found; the crate;
# - chapter 3: Walker 1's tracks; set right; photographed; its seal patched
#   on the spot; it walks home and is sent to your spot from the Map;
# - chapter 4: at the spot the core goes down, cold; air and power bring it
#   alive (no leak); a Quarters liner with its bunk; the three horizons; the
#   first night after ends the chapters;
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
	_pass_hours(world, 14.0)
	world.opening_days.last_morning = world.opening_days._hours_run() - 20.0
	MHGame.sol_hour = 6.5
	await _settle(radio)

## The sim clock moves on (the test's sun is frozen).
func _pass_hours(world: Node, hours: float) -> void:
	world.builder.simulation().hours_run += hours

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
	_check(not field.sites.gary.visible, "pallet 4 (GAR-Y) is out of sight in chapter 1")
	field.see_from_ridge()
	await _settle(radio, .3)
	_check(known.knows(field.sites.tools.id()) and not known.knows(field.sites.gary.id()), "from the ridge: pallet 3 named, pallet 4 not")
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
	days.dusk_sol = 0   # (the test's frozen clock: the same sol as the dusk call above)
	await _settle(radio)
	_check(radio.heard.has("d1_sunset"), "dusk: the sunset call")
	_check(radio.flag("on_the_rise") and world.known.finished("sunset_spot"), "the rise mark's done")
	print("  the rise: %.0f m from the lander, %.1f m up" % [Vector2(days.sunset_spot.x - lander.global_position.x, days.sunset_spot.z - lander.global_position.z).length(), days.sunset_spot.y - lander.global_position.y])
	player.global_position = lander.cabin_start().position
	_check(notes.is_open("bed"), "it ends in bed")
	_check(float(world.day_night.time_scale) == 1.0, "the clock's at its own pace")

	# A6: the pallets inside the bare suit's reach (it turns you back ~600 m out).
	var home: Vector3 = lander.global_position
	var out := func(p: Vector3) -> float: return Vector2(p.x - home.x, p.z - home.z).length()
	_check(out.call(world.storm_drop.ridge) < 320.0, "pallet 1 about 250 m out (%.0f m)" % out.call(world.storm_drop.ridge))
	for kind in field.sites:
		_check(out.call(field.sites[kind].at) < 560.0, "%s pallet inside the suit's reach (%.0f m)" % [kind, out.call(field.sites[kind].at)])

	# Chapter 1 was done at dusk: chapter 2 waits for the morning, not the clock.
	_pass_hours(world, 2.0)
	await _settle(radio)
	_check(int(days.chapter) == 1, "no new chapter starts at dusk")
	days.nights = 1
	await _morning(world, radio)
	_check(int(days.chapter) == 2, "chapter 2 in the morning")
	_check(radio.heard.has("d2_wake"), "Castellanos: something's moving")
	_check(bool(field.gary_working) and world.scout_rover != null, "GAR-Y is out at work")
	_check(field.sites.gary.visible and bool(field.sites.gary.pallet.opened), "its cradle is there now, open")
	_check(known.knows("gary_moving"), "the movement is on your Map")
	var gary: Node3D = world.scout_rover
	var work: Vector3 = gary.global_position
	_check(work.distance_to(field.sites.gary.at) > 60.0, "it's working out past its cradle (%.0f m)" % work.distance_to(field.sites.gary.at))
	_check(out.call(work) < 700.0, "GAR-Y within reach of a bare suit (%.0f m)" % out.call(work))

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
	var crate: Node3D = field.crate
	_check(crate != null and not days.day_done(2), "the spares crate waits to be towed home")
	_check(notes.is_open("salvage"), "Castellanos's call starts the salvage thought")
	pod.prints["hitch"] = true
	gary.global_position = crate.global_position + Vector3(2, 0, 0)
	_check(crate.interact(player) and str(crate.where) == "sled", "hitched to GAR-Y's sled")
	pod.unload_cargo()
	_check(crate.interact(player) and bool(crate.opened), "home and opened")
	MHGame.sol_hour = 11.0
	await _settle(radio)
	_check(radio.heard.has("d2_crate"), "Castellanos on the crate")
	_check(days.day_done(2) and int(days.chapter) == 2, "chapter 2 done; a breather first")

	# A6: the breather, then chapter 3 the same sol.
	_pass_hours(world, 1.2)
	await _settle(radio)
	_check(int(days.chapter) == 3 and radio.heard.has("d3_wake"), "after the breather, chapter 3 the same sol")
	var walker: Node3D = world.walker
	_check(bool(walker.tracks_laid) and known.things.has("walker_tracks_start"), "she marks where the tracks start")
	_check(out.call(walker.global_position) < 640.0, "Walker 1 stalled inside the suit's reach (%.0f m)" % out.call(walker.global_position))
	player.global_position = walker.tracks_start()
	await _settle(radio)
	_check(radio.heard.has("d3_tracks") or bool(walker.seen), "at the tracks, she says how to find the rest")
	walker.recalibrated()
	await _settle(radio)
	_check(str(walker.state) == "coming" and radio.heard.has("d3_fixed"), "set right, but locked (%s)" % walker.state)
	_check(not days.day_done(3), "chapter 3 isn't done")
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
	var wheel: Vector3 = walker.fault_spot()
	cam.global_position = wheel + walker.global_basis.x * -5.0 + Vector3(0, 1.0, 0)
	cam.look_at(wheel)
	_check(walker.aimed_part(cam) == "fl_wheel", "a picture of the front-left wheel (%s)" % walker.aimed_part(cam))
	walker.photographed(cam)
	cam.queue_free()
	await _settle(radio)
	_check(bool(walker.fault_found) and radio.heard.has("d3_fault"), "that's the one: the split seal")
	_check(not pod._open_plans().has(pod.PLANS.map(func(p): return str(p[0])).find("seal")), "no seal to print: it's patched on the spot")
	player.global_position = wheel + walker.global_basis.x * -1.5
	field.tools = false
	_check(str(walker.interaction_prompt().get("primary", "")) == "", "no patch kit, no patch")
	field.tools = true
	_check(str(walker.interaction_prompt().get("primary", "")) == "Patch it", "by the wheel: patch it (%s)" % walker.interaction_prompt())
	_check(walker.interact(player) and str(walker.state) == "walking", "patched: it walks home")
	await _settle(radio)
	_check(radio.heard.has("d3_patched"), "Castle: ride it or walk with it")
	walker.global_position = walker.home
	player.global_position = lander.cabin_start().position
	for i in 40:
		walker._process(.1)
		if str(walker.state) == "ready": break
	await _settle(radio)
	_check(str(walker.state) == "ready" and radio.heard.has("d3_home"), "home by the lander: choose home on the Map (%s)" % walker.state)
	_check(not walker.spot_reason(Vector2(home.x + 1500.0, home.z)).is_empty(), "home stays in ring 1 during the chapters")
	var spot := Vector2.INF
	for k in 40:
		var at := Vector2(home.x, home.z) + Vector2.from_angle(k * .7) * (60.0 + k * 4.0)
		if walker.spot_reason(at).is_empty():
			spot = at
			break
	_check(not is_inf(spot.x), "there's a spot for home near the lander")
	if is_inf(spot.x): spot = Vector2(home.x + 60.0, home.z)
	_check(walker.send_to(spot) and str(walker.state) == "travelling", "W, W: Walker 1 sets off")
	await _settle(radio)
	_check(radio.heard.has("d3_sent") and days.day_done(3), "sent: chapter 3 done")
	await _settle(radio)
	_check(int(days.chapter) == 4 and days.guided(), "chapter 4 straight on")

	# Chapter 4: at the spot, the core down, cold.
	walker.global_position = Vector3(spot.x, walker.global_position.y, spot.y)
	walker._arrive()
	await _settle(radio)
	_check(str(walker.state) == "parked" and radio.heard.has("d4_arrived"), "at its spot: go and set the core down")
	var b: Node = world.builder
	var c := Vector2i(roundi(spot.x / b.CELL), roundi(spot.y / b.CELL))
	var core_cells := [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1), c + Vector2i(0, 2), c + Vector2i(1, 2)]
	if BUILD_RULES_ZONE.module_zone(b, "w1").is_empty():
		b.zones.append({"kind": "general", "cells": core_cells, "carried": true, "cost": 0, "base": "w1"})
		b.zones.append({"kind": "airlock", "cells": [c + Vector2i(0, 3)], "cost": 0, "base": "w1"})
	walker._finish_set_down()
	await _settle(radio)
	var module: Node = world.module_life
	_check(module != null and bool(module.core.vented) and not bool(module.commissioned) and float(module.core.temp_c) < 0.0, "the core comes down cold and unpressurised")
	_check(radio.heard.has("d4_down"), "Castle: it knelt; now air and power")
	if module != null:
		var cartridge: Node = root.get_tree().get_first_node_in_group("o2_cartridge")
		if cartridge != null:
			cartridge.where = "plugged"
			cartridge.plugged_into = "module"
		module.add_cartridge(1.0)
		_check(not bool(module.commissioned), "not alive till the blanket's in too")
		module.blanket(true)
		await _settle(radio)
		_check(module.leak == null and not bool(module.core.vented) and bool(module.commissioned) and radio.heard.has("d4_patched"), "air and power in: it's alive, no leak")
		_check(not days.day_done(4), "chapter 4 waits for Quarters")
		_check(BUILD_RULES_ZONE.cost(b, "living") == 0, "the first Quarters liner came with Walker 1: no cargo to pay")
		var q := c + Vector2i(2, 0)
		b.zones.append({"kind": "living", "cells": [q, q + Vector2i(1, 0), q + Vector2i(0, 1), q + Vector2i(1, 1)], "cost": 0, "base": "w1"})
		b.placed_interior.append({"id": "crew_bunk", "position": Vector3(q.x * b.CELL, b.habitat_base_y, q.y * b.CELL), "placement_id": "t_bunk"})
		await _settle(radio)
		_check(days.quarters_built() and days.day_done(4) and radio.heard.has("d4_quarters"), "a Quarters liner with its bunk: chapter 4 done")
		_check(days.guided(), "still guided until you sleep")
		MHGame.sol_hour = sunset - .5
		days.dusk_sol = 0
		await _settle(radio, 2.0)
		_check(radio.heard.has("d4_sunset") and radio.heard.has("goal_humans") and radio.heard.has("d4_sunset_deal"), "dusk: the three horizons, round the room")
		var texts: Node = world.orbiter_texts
		_check(texts != null and texts.has("d4_note_tupou") and texts.has("d4_note_mwangi") and texts.has("d4_note_rao") and texts.has("d4_note_achterberg"), "each owner sends a note")
		days._was_asleep = true
		MHGame.sol_hour = 6.5
		await _settle(radio)
		_check(not days.guided(), "the morning after the first night: the guided chapters are over")

	# Saved.
	var state: Dictionary = days.export_state()
	_check(int(state.get("version", 0)) == 2 and int(state.get("sunset_called", 0)) >= 1 and state.has("chapter") and state.has("done_at"), "the version, the chapter and the calls are saved")
	_check((world.radio.export_state().heard as Dictionary).has("d2_found"), "the radio's heard calls are saved")

	print("guided_days_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
