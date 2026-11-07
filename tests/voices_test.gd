extends SceneTree

# Who speaks where (docs/systems-and-items.md §10e+): the suit has no voice,
# only a tone and a visor alert; ARDEN is the habitat's voice and says
# nothing out on the ground, but speaks in the lander cabin. Run with:
# godot --headless --path . --script res://tests/voices_test.gd

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
	for i in 10: await process_frame
	world._intro_stage = "done"
	var audio: MHAudio = MHAudio.director()
	audio._hush()
	var cabin_spot: Vector3 = world.player.global_position
	# Outside: the suit alerts without a voice, ARDEN stays quiet.
	world.player.global_position = world.lander.global_position + Vector3(0, 0, 30)
	audio._voice.stream = null
	MHAudio.suit("suit_o2_quarter")
	await process_frame
	await process_frame
	_check(audio._voice.stream == null and not MHAudio.voice_busy(), "the suit never speaks")
	_check(audio._caption != null and is_instance_valid(audio._caption), "a suit warning still shows as a visor alert")
	MHAudio.voice("o2_warning")
	await process_frame
	await process_frame
	_check(audio._voice.stream == null and not MHAudio.voice_busy(), "ARDEN says nothing outside")
	# In the cabin ARDEN speaks.
	world.player.global_position = cabin_spot
	MHAudio.voice("o2_warning")
	await process_frame
	await process_frame
	_check(audio._voice.stream != null and audio._voice.stream.resource_path.contains("o2_warning"), "ARDEN speaks in the cabin")
	if failures == 0:
		print("Voices test passed: the suit alerts with a tone and a visor line but never speaks; ARDEN is silent outside and speaks in the cabin.")
	quit(1 if failures > 0 else 0)
