extends SceneTree

## Screenshots of meeting GAR-Y (scripts/gary_meeting.gd), windowed: in its
## cradle at pallet 3 (folded, the lamp, the scan, finding you, the loop,
## parked with its name), then a fresh game where it finds you first: coming
## round in the cabin (lying, sitting up), and saying hello at the ramp.
##   godot --path . --script res://tools/gary_meeting_look.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://gary_meeting_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://gary_meeting_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await _new_world()
	var field: Node = world.drop_field
	var pallet: Node3D = field.sites.gary.pallet
	var stand: Vector3 = pallet.global_position + pallet.global_transform.basis.z * 2.6
	world.player.global_position = Vector3(stand.x, MHSiteTerrain.height(stand.x, stand.z) + .1, stand.z)
	var d: Vector3 = pallet.global_position - stand
	world.player.rotation.y = atan2(-d.x, -d.z)
	await create_timer(.5).timeout
	pallet.open(false)
	var times := [[.6, "1_folded"], [2.2, "2_lamp"], [4.2, "3_unfolding"], [6.5, "4_scan"], [9.3, "5_found_you"], [10.8, "6_hop"], [14.0, "7_loop"], [17.5, "8_spin"], [19.6, "9_parked_title"]]
	var started := Time.get_ticks_msec()
	for cue in times:
		while field.meeting != null and float(field.meeting._t) < float(cue[0]): await process_frame
		await _shot(str(cue[1]))
	while field.meeting != null: await process_frame
	await _shot("10_after")
	print("pallet scene took %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	# It finds you first.
	world.queue_free()
	await process_frame
	await _new_world()
	field = world.drop_field
	var lander: Node3D = world.lander
	lander.set_hatch(true, false)
	world.player.global_position = lander.ramp_foot(30.0) + Vector3(0, 1.0, 0)
	world.suit.pass_out()
	var rescue: Node = world.suit.get_node_or_null("Rescue")
	var shots := {"arrive": [1.5, "11_rescue_arrive"], "wake": [[3.0, "12_wake_blur"], [6.2, "13_sitting_up"], [7.95, "14_awake"]]}
	while is_instance_valid(rescue) and str(rescue.phase) != "arrive": await process_frame
	await create_timer(1.5).timeout
	await _shot("11_rescue_arrive")
	while is_instance_valid(rescue) and str(rescue.phase) != "wake": await process_frame
	for cue in shots.wake:
		while is_instance_valid(rescue) and float(rescue._t) < float(cue[0]): await process_frame
		await _shot(str(cue[1]))
		print("  y ", world.player.global_position.y - lander.global_position.y, " hatch open ", lander.hatch_open(), " seal ", lander.seal_state, " head ", (world.player.get_node("Head") as Node3D).position)
	await create_timer(1.5).timeout
	# From the ramp's top, GAR-Y waiting below.
	lander.set_hatch(true, false)
	await create_timer(.5).timeout
	var gary: Node3D = world.scout_rover
	var top: Vector3 = lander.to_global(Vector3(0, 2.0, -3.4))
	world.player.global_position = top
	var g: Vector3 = gary.global_position - world.player.global_position
	world.player.rotation.y = atan2(-g.x, -g.z)
	(world.player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-15.0)
	await create_timer(.6).timeout
	await _shot("15_waiting_at_ramp")
	var step: Vector3 = gary.global_position + (lander.global_position - gary.global_position).normalized() * 3.6
	world.player.global_position = Vector3(step.x, MHSiteTerrain.height(step.x, step.z) + .1, step.z)
	while field.meeting == null: await process_frame
	for cue in [[2.2, "16_head_tilt"], [4.8, "17_nudge"], [9.0, "18_loop"], [13.6, "19_parked_title"]]:
		while field.meeting != null and float(field.meeting._t) < float(cue[0]): await process_frame
		await _shot(str(cue[1]))
	quit()

func _new_world() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "hints"; MHGame.colony_name = "Look"
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	await create_timer(12.0).timeout   # past the slate's hand-over
	if world.get("pda") != null: world.pda.close()
	world._intro_stage = "done"
	world.day_night.frozen = true
	world.day_night.set_hour(10.0)
	for card in get_nodes_in_group("feature_hint"): card.queue_free()

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir + shot_name + ".png")
	print("shot ", shot_name)
