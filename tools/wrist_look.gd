extends SceneTree

## 21 Nov: the wrist pad raised, through your own eyes, at 70 and 90 degrees
## of field of view, plus the view with it down (the dip comes back level).
##   godot --path . --resolution 1280x800 --script res://tools/wrist_look.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "survival"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world.set_tutorial_mode("off")
	world.day_night.set_hour(11.0); world.day_night.frozen = true
	var player: Node3D = world.player
	var at := Vector3(30, 0, 30)
	at.y = world.builder._terrain_height(at) + 1.0
	player.global_position = at
	for i in 20: await physics_frame
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var pad = world.suit.pad
	for fov in [70.0, 90.0]:
		camera.fov = fov
		pad.held = true
		for i in 90: await process_frame
		await _shot(out + "wrist_up_fov%d.png" % int(fov))
		pad.held = false
		for i in 60: await process_frame
	await _shot(out + "wrist_down.png")
	print("camera pitch after lowering: %.4f" % camera.rotation.x)
	quit()

func _shot(path: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(path)
