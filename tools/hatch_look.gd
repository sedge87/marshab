extends SceneTree

## Screenshots of the crew lander's hatch, shut: from the cabin looking out
## through the airlock, close up on the door from inside, and from outside, by
## day and at night with the cabin lit. For checking it closes flush.
##   godot --path . --script res://tools/hatch_look.gd -- [out_dir]

var out_dir := "user://hatch_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://hatch_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "hints"; MHGame.colony_name = "Look"
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	await create_timer(1.5).timeout
	world._intro_stage = "done"
	world.day_night.frozen = true
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	var lander: Node3D = world.lander
	lander.set_hatch(false)
	for hour in [11.0, 23.0]:
		world.day_night.set_hour(hour)
		var tag := "day" if hour < 20.0 else "night"
		var start: Dictionary = lander.cabin_start()
		_stand(start.position, lander.to_global(Vector3(0, lander.DECK + 1.5, -4.0)), -2.0)
		await _shot("%s_1_cabin_to_hatch" % tag)
		_stand(lander.to_global(Vector3(0, lander.DECK + .3, -1.6)), lander.to_global(Vector3(0, lander.DECK + 1.4, -4.0)), 0.0)
		await _shot("%s_2_door_inside" % tag)
		var outside := lander.to_global(Vector3(0, 0, -9.0))
		_stand(Vector3(outside.x, MHSiteTerrain_height(outside) + 1.7, outside.z), lander.to_global(Vector3(0, 3.6, -2.0)), 6.0)
		await _shot("%s_3_outside" % tag)
		var side := lander.to_global(Vector3(2.6, 0, -5.0))
		_stand(Vector3(side.x, MHSiteTerrain_height(side) + 2.6, side.z), lander.to_global(Vector3(0, 3.6, -2.4)), 0.0)
		await _shot("%s_4_outside_angle" % tag)
	quit()

func MHSiteTerrain_height(at: Vector3) -> float:
	return preload("res://scripts/site_terrain.gd").height(at.x, at.z)

func _stand(at: Vector3, target: Vector3, pitch: float) -> void:
	var player: Node3D = world.player
	player.global_position = at
	var d := target - at
	player.rotation.y = atan2(-d.x, -d.z)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(pitch)
	player.set_meta("ui_freeze", true)

func _shot(shot_name: String) -> void:
	for i in 10: await process_frame
	root.get_texture().get_image().save_png(out_dir + shot_name + ".png")
	print("shot ", shot_name)
