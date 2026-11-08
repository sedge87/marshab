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
	pod.done("tow")
	await _settle(radio)
	_check(radio.heard.has("d1_cargo"), "a call when the cargo's home")
	_check(float(world.day_night.hold_at) < 0.0 and float(world.day_night.time_scale) > 1.0, "day 1 done: the sun goes, a little quicker")
	player.global_position = lander.cabin_start().position
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d1_sunset"), "the sunset call")
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
	await _settle(radio)
	_check(days.day_done(2) and float(world.day_night.hold_at) < 0.0, "jobs done: the sun goes")
	MHGame.sol_hour = sunset - .5
	await _settle(radio)
	_check(radio.heard.has("d2_sunset"), "day 2's sunset call")

	# Saved.
	var state: Dictionary = days.export_state()
	_check(int(state.get("version", 0)) == 2 and int(state.get("sunset_called", 0)) == 2, "the version and the calls are saved")
	_check((world.radio.export_state().heard as Dictionary).has("d2_found"), "the radio's heard calls are saved")

	print("guided_days_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
