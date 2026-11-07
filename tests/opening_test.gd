extends SceneTree

# The first minutes of a new Survival game, in order (docs/systems-and-items.md
# §14 step 2): you wake in the lander cabin; ARDEN says the high-gain antenna
# has lost lock; Castellanos's text with Rao's parachute photo is already waiting; ARDEN
# hands you the slate and it opens on Comms with that photo at the top; Notes
# already holds the first thoughts (the air, the sunset, the parachute); no
# old crates, no checklist, no "design your habitat" note. Run with:
# godot --headless --path . --script res://tests/opening_test.gd

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(world.lander.cabin_contains(world.player.global_position), "you start in the lander cabin")
	_check(str(world._intro_stage) == "inside" and not world.pda.received, "the slate isn't in your hands yet")
	_check(world.get("tutorial") == null and world.cargo_landers.is_empty(), "no checklist and no old crates")
	_check(world.orbiter_texts.has("parachute_photo"), "the orbiter's photo text is already waiting")
	# ARDEN's line about the link, a second or so in.
	var audio: MHAudio = MHAudio.director()
	var heard := false
	for i in 120:
		await process_frame
		if audio._voice.stream != null and audio._voice.stream.resource_path.contains("link_lost"): heard = true
		if heard: break
	await create_timer(1.5).timeout
	heard = heard or (audio._voice.stream != null and audio._voice.stream.resource_path.contains("link_lost"))
	_check(heard, "ARDEN says the high-gain antenna has lost lock")
	# The hand-over (about nine seconds in, once the mouse is captured, which a
	# headless run can't do): straight to the photo on Comms.
	world.pda.hand_over()
	await create_timer(1.0).timeout
	_check(world.pda.received and world.pda.is_open, "ARDEN hands you the slate")
	_check(str(world.pda.screen.app) == "comms", "it opens on Comms (%s)" % str(world.pda.screen.app))
	var labels: Array = world.pda.screen.find_children("*", "Label", true, false).map(func(l): return str(l.text))
	_check(labels.any(func(t): return t.begins_with("FROM ORBIT")) and labels.any(func(t): return t.begins_with("Rao caught it on this pass")), "with the orbiter's text at the top")
	var notes: Node = world.notes
	_check(notes.is_open("air") and notes.is_open("sunset") and notes.is_open("parachute"), "Notes holds the first thoughts: the air, the sunset, the parachute")
	_check(not notes.is_open("power"), "the night worry waits for the afternoon")
	if failures == 0:
		print("Opening test passed: the cabin, ARDEN's lost-lock line, the orbiter's photo text waiting, the slate handed over on Comms with the photo, the first thoughts, and nothing from the old opening.")
	quit(1 if failures > 0 else 0)
