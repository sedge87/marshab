extends SceneTree

# The opening's first days (scripts/opening_days.gd; playtest 8 Nov):
# - sol 1's pallets done, then dusk: "bed" in Notes, GAR-Y leads you home;
# - the lander's hatch won't open from inside at night, and does at dawn;
# - sol 2's dawn: GAR-Y waits at the ramp; "What did you find?" puts three
#   finds on your map, and "Show me" leads you to the nearest;
# - ARDEN's morning check offers replies; "Ice first" takes up water;
# - a slow day: night falls with jobs left, "bed" (late), they carry over;
# - saved and loaded; once the module's lived in, the guided days end.
# godot --headless --path . --script res://tests/opening_days_test.gd
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

func _open_pallets(world: Node) -> void:
	world.storm_drop.pallet.opened = true
	for kind in world.drop_field.sites:
		var site: Node = world.drop_field.sites[kind]
		if site.pallet != null: site.pallet.opened = true

func _until_shown(r: Node) -> bool:
	for i in 400:
		MHAudio.hush()
		if MHNotices._line != null: MHNotices._line._queue.clear()
		r._gap = 0.0
		r._process(.1)
		if r.showing(): return true
	return false

func _initialize() -> void:
	load("res://scripts/opening_days.gd").new_games_version = 1   # the first opening (version 2: tests/guided_days_test.gd)
	var world = await _new_world()
	var days: Node = world.opening_days
	_check(days != null, "a new game has the opening days")
	if days == null:
		quit(1)
		return
	var notes: Node = world.notes
	var lander: Node3D = world.lander
	var player: Node3D = world.player
	var gary: Node = null
	var pod: Node = world.lifepod
	_check(days.guided() and days.stage() == 0, "it starts on the pallets' day")

	# Sol 1, the day's done, dusk: bed, and GAR-Y leads you home.
	MHGame.sol_hour = 10.0
	await create_timer(.7).timeout
	_open_pallets(world)
	player.global_position = lander.global_position + Vector3(0, 1.5, -120.0)
	gary = world.meet_gary(player.global_position + Vector3(2, 0, 0))
	await create_timer(.3).timeout
	MHGame.sol_hour = 17.8
	await create_timer(.7).timeout
	_check(days.stage() == 1, "pallets open: on to the lifepod jobs (%d)" % days.stage())
	_check(notes.is_open("bed") and notes.stage("bed") == "start", "dusk with the day done: bed")
	_check(gary != null and gary.leading_to(lander.ramp_foot(3.0)), "GAR-Y leads you home (task %s, sunset %s, lift %s)" % [gary.task, world.drop_field.sunset.phase if world.drop_field.sunset != null else "-", gary.has_meta("lift_out")])

	# Night in the cabin: the hatch won't open from inside.
	player.global_position = lander.cabin_start().position
	lander.set_hatch(false)
	MHGame.sol_hour = 21.0
	await create_timer(.3).timeout
	_check(days.is_night() and days.in_lander_days(), "night in the lander days")
	_check(not str(days.hatch_refusal()).is_empty(), "the hatch won't open from inside at night")
	lander.interact()
	_check(not lander.hatch_open(), "pressing E at night leaves it shut")
	_check(str(lander.interaction_prompt().primary).begins_with("Not in the dark"), "and its prompt says why")
	player.global_position = lander.ramp_foot(4.0) + Vector3(0, 1.0, 0)
	_check(str(days.hatch_refusal()).is_empty(), "from outside it lets you in")
	player.global_position = lander.cabin_start().position

	# Sleep: the day ends; dawn of sol 2.
	world.sleep.set_process(false)   # its screen isn't up: just the flag
	world.sleep.asleep = true
	await create_timer(.7).timeout
	_check(not notes.is_open("bed"), "asleep: bed passes")
	world.sleep.asleep = false
	world.builder.simulation().hours_run = 30.0
	MHGame.sol_hour = 6.0
	await create_timer(.8).timeout
	_check(str(days.hatch_refusal()).is_empty(), "the hatch opens at dawn")
	_check(int(world.opening_part()) == 2, "sol 2: the lifepod days")
	_check(gary != null and bool(gary.staying) and gary.global_position.distance_to(lander.ramp_foot(2.0)) < 1.5, "GAR-Y's back, waiting at the ramp")
	_check(days.arden_morning, "ARDEN's morning check is said in the cabin")
	var r: Node = world.replies
	_check(r.has_replies("cabin_morning_check"), "and has replies")
	var shown_id := ""
	for i in 4:
		if not _until_shown(r): break
		shown_id = str(r._shown.get("id", ""))
		if shown_id == "cabin_morning_check": break
		r.choose(-1)   # earlier ones, left unanswered
	if shown_id == "cabin_morning_check":
		r.choose(0)
		_check(notes.is_open("salvage"), "\"Parts, then.\" takes up the salvage (shown %s, settled %s)" % [shown_id, notes.is_settled("salvage")])
	else:
		_check(false, "the morning check's replies show")

	# GAR-Y's night out.
	_check(pod.gary_report_ready(), "GAR-Y has finds to show")
	_check(str(gary.interaction_prompt().primary) == "What did you find?", "its prompt asks what it found")
	gary.interact()
	var marks := 0
	for kind in ["frost", "ice_wall", "iron"]:
		if world.known.knows(pod.sites[kind].id()): marks += 1
	_check(marks == 3, "three finds on your map (%d)" % marks)
	_check(str(world.known.thing(pod.sites.iron.id()).name).contains("metal"), "the iron's \"something metal\" for now")
	_check(notes.is_open("gary_scouted"), "and the thought that GAR-Y's been out all night")
	_check(not pod.gary_report_ready(), "it tells you once")
	player.global_position = lander.ramp_foot(4.0) + Vector3(0, 1.0, 0)
	gary.global_position = lander.ramp_foot(2.0)
	_check("show" in gary.available_orders(), "\"Show me\" is an order outside")
	var nearest: Node = pod.gary_mark_to_show(gary.global_position)
	var said: String = gary.order("show")
	_check(said == "" and gary.task == "goto" and Vector2(gary.task_goal.x - nearest.global_position.x, gary.task_goal.z - nearest.global_position.z).length() < 12.0, "Show me leads to the nearest find (%s, %s)" % [said, gary.task])
	player.global_position = nearest.global_position + Vector3(0, 1.5, 10.0)
	await create_timer(.7).timeout
	_check(str(world.known.thing(nearest.id()).name) == str(nearest.NAMES[nearest.kind]), "seen: it gets its real name")
	_check(pod.gary_mark_to_show(gary.global_position) != nearest, "and Show me moves on to the next")

	# The module's cargo: the hitch, then GAR-Y's sled brings it to the lander.
	var cart: Node3D = world.storm_drop.cartridge
	var pack: Node3D = world.drop_field.sites.power.pack
	_check(not pod.staged(cart) and not pod.staged(pack), "the cargo starts out at its pallets")
	_check(not pack.near_lander(), "the self-sufficient lander has no use for the power pack")
	pod.prints["hitch"] = true
	player.global_position = cart.global_position + Vector3(0, 1.0, 1.0)
	cart.pick_up()
	_check(notes.is_open("module_air"), "picking up the cartridge: it's the module's air")
	gary.global_position = player.global_position + Vector3(2, 0, 0)
	_check(cart.claim_label(gary) == "Load it on GAR-Y's sled", "carrying it, E on a hitched GAR-Y offers its sled")
	cart.claim(gary, "interact")
	_check(cart.where == "sled" and pod.sled_cargo.size() == 1, "the cartridge rides on GAR-Y's sled")
	player.global_position = pack.global_position + Vector3(0, 1.0, 1.0)
	pack.pick_up()
	pack.claim(gary, "interact")
	_check(pack.where == "sled" and pod.sled_cargo.size() == 2, "and the power pack too")
	gary.global_position = lander.ramp_foot(5.0)
	_check(str(gary.interaction_prompt().primary) == "Unload the cargo", "at the lander GAR-Y offers to unload")
	gary.interact()
	_check(pod.staged(cart) and pod.staged(pack) and pod.sled_cargo.is_empty(), "unloaded by the lander: staged")
	_check(pod.jobs.has("tow"), "staging the cargo is a job done")

	# The lander looks after you: a day and a night, and nothing runs down.
	var core: RefCounted = world.cabin_life.core
	var o2_before: float = core.tank_o2_kg
	core.advance(24.0, 12.0)
	_check(core.tank_o2_kg >= o2_before - .05, "the lander remakes its oxygen (%.2f to %.2f kg)" % [o2_before, core.tank_o2_kg])
	_check(core.battery_pct() > 20.0 and core.temp_c > 15.0, "its power cell keeps it warm through the night (%d%%, %.0f C)" % [roundi(core.battery_pct()), core.temp_c])
	_check(core.water_l >= 7.0, "and recycles its water (%.1f L)" % core.water_l)

	# A slow day: night falls with jobs left. Bed, late; they carry over.
	player.global_position = lander.cabin_start().position
	MHGame.sol_hour = 20.0
	await create_timer(.7).timeout
	_check(notes.is_open("bed") and notes.stage("bed") == "late", "night with jobs left: bed, late")
	_check(days.stage() == 1, "the lifepod jobs carry over")

	# Saved and loaded.
	var state: Dictionary = world.current_state()
	var bed_sol: int = days.bed_sol
	world.queue_free()
	await process_frame
	var again = await _new_world(state)
	_check(again.opening_days.arden_morning and again.opening_days.bed_sol == bed_sol, "saved and loaded")
	_check(again.lifepod.gary_reported, "GAR-Y's report is saved")

	# The module lived in: the guided days end.
	again.walker.state = "done"
	for i in 3: again.builder.placed_interior.append({"id": "crew_chair"})
	_check(not again.opening_days.guided(), "the module fitted out: nights are yours")
	for i in 3: again.builder.placed_interior.pop_back()

	# The ice extractor opens science, and the four goals arrive from orbit.
	MHSamples.science_open = false
	again.builder.zones.append({"kind": "ice_extractor", "cells": [Vector2i(40, 40)]})
	again._tick_chapter_one()
	_check(MHSamples.science_open, "the ice extractor opens science")
	_check(again.orbiter_texts.has("science_open"), "and Castellanos's text names the four goals")
	again.builder.zones.pop_back()

	print("opening_days_test: PASS" if failures == 0 else "opening_days_test: %d FAILED" % failures)
	quit(1 if failures > 0 else 0)
