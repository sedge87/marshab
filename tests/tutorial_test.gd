extends SceneTree

# Run with: godot --headless --path . --script res://tests/tutorial_test.gd
# ARDEN's getting-started tutorial: a new game with Tutorial: Full gets it,
# each step ticks itself off from what the player does (moving, the hatch,
# the site plan, rooms, machines, going inside, furnishing, the systems panel,
# the crew screen, saving), steps already done are skipped, it's saved with
# the game, and older saves don't get it. Missions: ARDEN's "look and move"
# step only with Tutorial: Full; every step's keys, highlight and clip; the
# build bar's buttons can be found for highlighting; every clip exists.

const MHMissions := preload("res://scripts/mh_missions.gd")
const GUIDE := preload("res://scripts/guide_overlay.gd")
const HINTS := preload("res://scripts/feature_hints.gd")
const TUTORIAL := preload("res://scripts/tutorial.gd")

var failures := 0
var world: Node
var b
var t

func _check(ok: bool, what: String) -> void:
	if ok: return
	failures += 1
	print("FAIL ", what)

func _settle() -> void:
	for i in 3: await process_frame
	t._check_in = 0.0
	for i in 3: await process_frame

func _step() -> String:
	return str(t.current().get("id", ""))

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code; key.physical_keycode = code; key.pressed = pressed
		Input.parse_input_event(key)

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.save_directory = "user://test_habitats"; MHGame.game_mode = "survival"
	MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = "full"
	MHChapterOne.reset()   # as the menu does for a new game
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	b = world.builder
	t = world.tutorial
	_check(t != null, "a new game with Tutorial: Full has the tutorial")
	if t == null:
		quit(1)
		return
	if world.scout_rover: world.scout_rover.queue_free()
	await _settle()
	_check(_step() == "move", "it starts with looking around (%s)" % _step())

	# 0. The lander start: the slate isn't yours until ARDEN hands it over, and the hand-over doesn't tick "Raise your slate".
	_check(not world.pda.received and not world.pda.can_open(), "in the lander the slate isn't received yet")
	world.pda.hand_over()
	_check(world.pda.received and world.pda.is_open and not world.guide_flags.has("slate"), "ARDEN hands it over: it's up on Goals and the task isn't ticked")
	world.pda.close()
	await _settle()
	_check(_step() == "move", "the hand-over leaves the first task alone (%s)" % _step())

	# 1. Look and move: a few metres and a turn.
	var player: Node3D = world.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var start := player.global_position
	for i in 20:
		player.global_position = start + Vector3(.2 * i, 0, 0)
		player.rotation.y += .08
		await process_frame
	await _settle()
	_check(_step() == "slate", "moving ticks the first step (%s)" % _step())

	# 1b. Raise the slate (Tab).
	world.pda.open()
	await _settle()
	world.pda.close()
	_check(_step() == "outside", "raising the slate ticks it (%s)" % _step())

	# 2. Out of the lander: the hatch open and you outside the cabin.
	world.lander.set_hatch(true)
	player.global_position = world.lander.to_global(Vector3(0, 1, -9.0))
	await _settle()
	_check(_step() == "unpack", "stepping outside ticks it (%s)" % _step())

	# 3. Chapter one: the precursor crates by the two cargo landers, unpacked with E.
	var crates: Array = world.get_children().filter(func(n): return str(n.name).begins_with("Crate_"))
	_check(MHChapterOne.on() and world.cargo_landers.size() == 2 and crates.size() == MHChapterOne.crates().size(), "a new Survival game lands two cargo landers and %d crates (%d)" % [MHChapterOne.crates().size(), crates.size()])
	for crate in crates: crate.interact(player)
	await _settle()
	_check(_step() == "plan", "unpacking every crate ticks it (%s)" % _step())

	# 3. The site plan; then the highlight finds the General Module card.
	b._toggle()
	await _settle()
	_check(_step() == "living", "opening the site plan ticks it (%s)" % _step())
	b.category = "rooms"; b._refresh_catalogue()
	for i in 3: await process_frame
	_check(GUIDE.find_target(self, "part:general") != null, "the General Module card can be found for the highlight")
	_check(GUIDE.find_target(self, "tab:structure") != null, "and the Structure tab")

	# 4–7. Building: each step ticks; the solar array built ahead with the
	# airlock is skipped when it comes up. No drill or Life Support yet under
	# chapter-one rules: the ice extractor's plan is earned.
	_check(not TUTORIAL.steps().any(func(s): return str(s.id) in ["drill", "life_support", "air"]), "chapter one leaves out the drill, Life Support and air steps")
	b.zones = [_room("general", 4, 0, 3, 3)]; b._rebuild()
	await _settle()
	_check(_step() == "airlock", "a General Module ticks it (%s)" % _step())
	b.zones.append({"kind": "airlock", "cells": [Vector2i(5, 3)], "door_direction": Vector2i(0, 1), "cost": 0})
	b.zones.append({"kind": "solar", "cells": [Vector2i(2, 5)], "door_direction": Vector2i(0, 1), "cost": 0})
	b._rebuild()
	await _settle()
	_check(_step() == "go_in", "the airlock ticks it, and the solar array (built ahead) is skipped (%s)" % _step())

	# 9. Inside (not while building).
	player.global_position = Vector3(13.5, b.habitat_base_y + .2, 1.5)
	await _settle()
	_check(_step() == "go_in", "not while the site plan is open")
	b._toggle()
	await _settle()
	_check(_step() == "heat", "walking into the habitat ticks it (%s)" % _step())

	# Heat first: the Thermal Control Unit came in a crate.
	var y: float = b.habitat_base_y
	var tcu_at := Vector3(15.0, y, 3.0)
	_check(b.free_interior_invalid_reason("thermal_control_unit", tcu_at, Vector3.UP).is_empty(), "the TCU can be placed from the crates (%s)" % b.free_interior_invalid_reason("thermal_control_unit", tcu_at, Vector3.UP))
	b.place_free_interior_equipment("thermal_control_unit", tcu_at, 0.0, Vector2i(5, 1), b.free_interior_visual("thermal_control_unit", tcu_at, 0.0), Vector3.UP)
	await _settle()
	_check(_step() == "bunk", "placing the TCU ticks it (%s)" % _step())

	# 9–11. Furnishing from the Unpacked tab: a bunk, the fabricator, one job.
	for item in [["crew_bunk", Vector3(13.0, y, 1.0)], ["fabricator", Vector3(17.0, y, 5.0)]]:
		_check(b.free_interior_invalid_reason(item[0], item[1], Vector3.UP).is_empty(), "%s can be placed from the crates (%s)" % [item[0], b.free_interior_invalid_reason(item[0], item[1], Vector3.UP)])
		var visual: Node3D = b.free_interior_visual(item[0], item[1], 0.0)
		b.place_free_interior_equipment(item[0], item[1], 0.0, Vector2i(roundi(item[1].x / 3), roundi(item[1].z / 3)), visual, Vector3.UP)
	await _settle()
	_check(_step() == "fab_job", "the bunk, then the fabricator, tick (%s)" % _step())
	_check(MHChapterOne.start_job("crew_bunk", b).is_empty(), "a fabricator job starts")
	await _settle()
	_check(_step() == "intake", "starting a job ticks it (%s)" % _step())
	MHChapterOne.steps["feedstock"] = 0.0   # stands in for the first intake running
	await _settle()
	_check(_step() == "systems", "a running regolith intake ticks the feedstock step (%s)" % _step())

	# 12. The base on the slate: its Base app.
	world.pda.open("base")
	await _settle()
	world.pda.close()
	_check(_step() == "crew", "opening the slate's Base app ticks it (%s)" % _step())

	# 13. The crew screen (C), then 14. saving.
	world.guide_flags["crew_screen"] = true
	await _settle()
	_check(_step() == "save", "the crew screen ticks it (%s)" % _step())
	var state: Dictionary = world.current_state()
	_check(str(state.tutorial.mode) == "full" and (state.tutorial.done as Array).size() == 16, "the save records the tutorial and its 16 done steps (%s)" % [state.tutorial])
	world._save_habitat(6)
	await _settle()
	_check(_step() == "ice" and not bool(t.finished) and t.current_goal() == "self_sufficient", "saving finishes Learn the ropes; chapter one's Self-sufficient goal comes next (%s)" % _step())

	# The checklist hides: H cycles full, folded, hidden (remembered in settings).
	var keep_view := str(MHGame.setting("checklist"))
	var keep_hud := str(MHGame.setting("hud"))
	var hud_values := MHGame.settings(); hud_values["hud"] = "classic"; MHGame.save_settings(hud_values)   # H is a Classic HUD key
	for want in ["folded", "hidden", "full"]:
		_key(KEY_H)
		await _settle()
		_check(TUTORIAL.view() == want, "H turns the checklist %s (%s)" % [want, TUTORIAL.view()])
		if want == "hidden": _check(not t._panel.visible, "hidden, the checklist is off the screen")
	var view_values := MHGame.settings(); view_values["checklist"] = keep_view; view_values["hud"] = keep_hud; MHGame.save_settings(view_values)

	# Self-sufficient: chapter one's steps tick in any order.
	MHChapterOne.steps["food"] = 500.0
	await _settle()
	_check(t.done.has("food") and _step() == "ice", "a later task ticks first; the next is still the ice (%s)" % _step())
	for s in ["ice", "water", "oxygen"]: MHChapterOne.steps[s] = 600.0
	await _settle()
	_check(bool(t.finished), "chapter one's steps finish the checklist")
	_check(bool(MHGame.setting("tutorial_finished")) and MHGame.default_tutorial_mode() == "hints", "and the next new game offers Hints only")
	var values := MHGame.settings(); values["tutorial_finished"] = false; MHGame.save_settings(values)

	# A game loaded from that save carries on where it was; older saves have no tutorial.
	var restored := TUTORIAL.new()
	restored.setup(world, state.tutorial)
	_check(str(restored.current().get("id", "")) == "save", "a loaded game resumes at the same step")
	restored.free()

	# Missions: ARDEN's look-and-move step only with Tutorial: Full.
	var mission := MHMissions.get_mission("cargo_power_water")
	MHGame.tutorial_mode = "full"
	_check(str(MHMissions.steps_of(mission)[0].id) == "look", "Missions with Tutorial: Full start with looking around")
	MHGame.tutorial_mode = "hints"
	_check(str(MHMissions.steps_of(mission)[0].id) == "roll_out", "but not with Hints only")
	var extras := GUIDE.step_extras({"check": "zone", "kind": "solar"})
	_check((extras.highlight as Array).has("part:solar") and (extras.highlight as Array).has("tab:power") and str(extras.clip) == "solar", "a mission step to place solar points at its card and clip (%s)" % extras)
	extras = GUIDE.step_extras({"check": "item", "item": "battery_bank"})
	_check((extras.highlight as Array).has("item:battery_bank") and not (extras.keys as Array).is_empty(), "a furnishing step points at its item")

	# Every clip named anywhere exists.
	MHGame.game_mode = "creative"
	_check(not TUTORIAL.steps().any(func(s): return str(s.id) == "systems"), "Creative (no simulation) skips the systems panel step")
	MHGame.game_mode = "survival"
	var named: Array = []
	for step in TUTORIAL.steps(): if not str(step.get("clip", "")).is_empty(): named.append(str(step.clip))
	for hint in HINTS.hints().values(): if not str(hint.get("clip", "")).is_empty(): named.append(str(hint.clip))
	for m in ["cargo_power_water", "cargo_habitat", "crew_land"]:
		for step in MHMissions.get_mission(m).get("steps", []):
			var clip := str(GUIDE.step_extras(step).clip)
			if not clip.is_empty() and not ["test", "gar_y"].has(clip): named.append(clip)
	var unique: Array = []
	for clip in named: if not unique.has(clip): unique.append(clip)
	for clip in unique: _check(GUIDE.has_clip(clip), "the %s clip exists" % clip)

	if failures == 0:
		print("Tutorial test passed: the goal checklist (17 chapter-one steps, then Self-sufficient in any order) ticks from play, H hides it, crates unpack, built-ahead steps are skipped, highlights find their buttons, it saves and resumes, Missions get ARDEN's guidance, and every clip exists.")
	quit(1 if failures > 0 else 0)
