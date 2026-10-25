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

	# 1. Look and move: a few metres and a turn.
	var player: Node3D = world.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var start := player.global_position
	for i in 20:
		player.global_position = start + Vector3(.2 * i, 0, 0)
		player.rotation.y += .08
		await process_frame
	await _settle()
	_check(_step() == "outside", "moving ticks the first step (%s)" % _step())

	# 2. Out of the lander: the hatch open and you outside the cabin.
	world.lander.set_hatch(true)
	player.global_position = world.lander.to_global(Vector3(0, 1, -9.0))
	await _settle()
	_check(_step() == "plan", "stepping outside ticks it (%s)" % _step())

	# 3. The site plan; then the highlight finds the Living Quarters card.
	b._toggle()
	await _settle()
	_check(_step() == "living", "opening the site plan ticks it (%s)" % _step())
	b.category = "rooms"; b._refresh_catalogue()
	for i in 3: await process_frame
	_check(GUIDE.find_target(self, "part:living") != null, "the Living Quarters card can be found for the highlight")
	_check(GUIDE.find_target(self, "tab:structure") != null, "and the Structure tab")

	# 4–8. Building: each step ticks; the Life Support room built ahead of
	# the solar array is skipped when it comes up.
	b.zones = [_room("living", 4, 0, 2, 2)]; b._rebuild()
	await _settle()
	_check(_step() == "airlock", "a Living Quarters room ticks it (%s)" % _step())
	b.zones.append(_room("life_support", 6, 0, 2, 2))
	b.zones.append({"kind": "airlock", "cells": [Vector2i(5, 2)], "door_direction": Vector2i(0, 1), "cost": 0})
	b._rebuild()
	await _settle()
	_check(_step() == "solar", "the airlock ticks it; Life Support waits its turn (%s)" % _step())
	b.zones.append({"kind": "solar", "cells": [Vector2i(2, 4)], "door_direction": Vector2i(0, 1), "cost": 0})
	b.zones.append({"kind": "ice_extractor", "cells": [Vector2i(-6, 8)], "door_direction": Vector2i(0, 1), "cost": 0})
	b._rebuild()
	await _settle()
	_check(_step() == "go_in", "solar and the drill tick, and Life Support (built ahead) is skipped (%s)" % _step())

	# 9. Inside (not while building).
	player.global_position = Vector3(13.5, b.habitat_base_y + .2, 1.5)
	await _settle()
	_check(_step() == "go_in", "not while the site plan is open")
	b._toggle()
	await _settle()
	_check(_step() == "bunk", "walking into the habitat ticks it (%s)" % _step())

	# 10–11. Furnishing.
	var y: float = b.habitat_base_y
	for item in [["crew_bunk", Vector3(13.0, y, 1.0)], ["oxygen_generator", Vector3(19.0, y, 1.0)], ["thermal_control_unit", Vector3(20.5, y, 3.5)]]:
		var visual: Node3D = b.free_interior_visual(item[0], item[1], 0.0)
		b.place_free_interior_equipment(item[0], item[1], 0.0, Vector2i(roundi(item[1].x / 3), roundi(item[1].z / 3)), visual, Vector3.UP)
	await _settle()
	_check(_step() == "systems", "the bunk, then the oxygen generator and heater, tick (%s)" % _step())

	# 12. The systems panel: Enter when read.
	_check(GUIDE.find_target(self, "systems") != null, "the systems panel can be found for the highlight")
	_key(KEY_ENTER)
	await _settle()
	_check(_step() == "crew", "Enter ticks the read-only step (%s)" % _step())

	# 13. The crew screen (C), then 14. saving.
	world.guide_flags["crew_screen"] = true
	await _settle()
	_check(_step() == "save", "the crew screen ticks it (%s)" % _step())
	var state: Dictionary = world.current_state()
	_check(str(state.tutorial.mode) == "full" and (state.tutorial.done as Array).size() == 13, "the save records the tutorial and its 13 done steps (%s)" % [state.tutorial])
	world._save_habitat(6)
	await _settle()
	_check(bool(t.finished), "saving finishes the tutorial")
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
		print("Tutorial test passed: all 14 steps tick from play, built-ahead steps are skipped, highlights find their buttons, it saves and resumes, Missions get ARDEN's guidance, and every clip exists.")
	quit(1 if failures > 0 else 0)
