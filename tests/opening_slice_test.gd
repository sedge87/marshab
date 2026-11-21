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

func _ground(p: Vector3) -> Vector3:
	var terrain := preload("res://scripts/site_terrain.gd")
	return Vector3(p.x, terrain.height(p.x, p.z) + 1.0, p.z)

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
	# Out: the first step.
	var lander: Node3D = world.lander
	var player: Node3D = world.player
	lander.interact(player)
	await wait(5.0)
	world._update_lander_intro()
	await wait(6.0)
	player.global_position = _ground(lander.ramp_foot(4.0))
	await wait(8.0)
	check(days.done("outside"), "the first step didn't count")
	# Scene 2: the cradle near, GAR-Y snagged past its stakes.
	var field: Node = world.drop_field
	var cradle_d: float = lander.global_position.distance_to(field.sites.gary.at)
	check(cradle_d > 100.0 and cradle_d < 200.0, "GAR-Y's cradle is %.0f m out, not ~150" % cradle_d)
	var gary: Node3D = world.scout_rover
	check(gary != null and field.snag != null, "GAR-Y isn't out there snagged")
	if gary != null:
		check((gary.ice_samples as Array).size() >= 5, "only %d stakes lead to GAR-Y" % (gary.ice_samples as Array).size())
		check(not days.done("gary_met"), "met GAR-Y before freeing it")
		player.global_position = _ground(gary.global_position + Vector3(2, 0, 0))
		await wait(1.0)
		for point in (field.snag.left as Array).duplicate(): point.free_for(5.0)
		await wait(30.0)
		check(days.done("gary_met"), "freeing GAR-Y didn't lead to the meeting")
		check(str(gary.get("task")) == "goto", "GAR-Y isn't leading to a pallet (task '%s')" % str(gary.get("task")))
	Engine.time_scale = 1.0
	if failures.is_empty(): print("Opening slice test passed: version 3 boots, the slice's calls load (not the old days), the assignment plays, the slate and helmet open the hatch, GAR-Y's cradle is near and it's snagged past its stakes, freeing it runs the meeting, and it leads to a pallet.")
	else:
		for f in failures: print("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)
