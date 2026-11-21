extends SceneTree

## The opening slice (version 3, docs/opening-slice.md) boots and its first
## beats ring: a new story game runs scripts/opening_slice.gd, the radio
## loads data/radio/slice/ instead of the old days, the assignment plays,
## and the slate, helmet and hatch move it on. Grows as chunk 1 is built.
## godot --headless --path . --script res://tests/opening_slice_test.gd

var world: Node
var failures: Array = []

func check(ok: bool, what: String) -> void:
	if not ok: failures.append(what)

func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += root.get_process_delta_time()

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHGame.start_new_challenge()
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	Engine.time_scale = 8.0
	var days: Node = world.opening_days
	var radio: Node = world.radio
	check(int(world.opening_version) == 3, "a new game is on opening version %d, not 3" % int(world.opening_version))
	check(days != null and days.get_script() == load("res://scripts/opening_slice.gd"), "the opening isn't the slice")
	check(radio != null and (radio.sections() as Dictionary).has("s1_manifest"), "the slice's calls didn't load")
	check(radio != null and not (radio.sections() as Dictionary).has("d2_wake"), "the old days' calls loaded too")
	radio.fast = true
	await wait(30.0)
	check((radio.heard as Dictionary).has("d1_relock"), "the assignment call didn't play")
	for node in world.get_children():
		if node.get_script() == world.WAKE_UP and bool(node.get("strapped")): node.unbuckle()
	await wait(2.0)
	check(days.hatch_refusal() != "", "the hatch opens before the slate and helmet")
	if world.slate_cradle != null and is_instance_valid(world.slate_cradle):
		world.slate_cradle.interact()
		await wait(4.0)
		world.pda.close()
	check(days.done("slate"), "taking the slate didn't count")
	await wait(4.0)
	check((days.reached as Array).has("slate"), "the slate beat wasn't reached")
	if world.suit != null and not bool(world.suit.helmet): world.suit.suit_up()
	await wait(2.0)
	check(days.hatch_refusal() == "", "the hatch still refuses: %s" % days.hatch_refusal())
	Engine.time_scale = 1.0
	if failures.is_empty(): print("Opening slice test passed: version 3 boots, the slice's calls load (not the old days), the assignment plays, the slate and helmet open the hatch.")
	else:
		for f in failures: print("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)
