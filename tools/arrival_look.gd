extends SceneTree

## Screenshots of the arrival story (docs/master-design.md §2), windowed: the
## menu's Arrive step, the descent with the cameras' safe spots, then in the
## game the Map (clear round the landing, coarse survey beyond) and the
## slate's Cargo manifest.
##   godot --path . --script res://tools/arrival_look.gd -- [out_dir]

var out_dir := "user://arrival_look/"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://arrival_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "hints"; MHGame.colony_name = "Look"
	MHChapterOne.reset()
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 10: await process_frame
	menu._use_region_site()
	menu.show_screen("landing")
	await create_timer(1.5).timeout
	await _shot("0_arrive")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	menu._landing_area = menu.entry_area(rng)
	menu.show_screen("descent")
	var descent: Node = null
	while descent == null:
		await process_frame
		for child in menu.backdrop.get_children(): if child.has_method("_find_safe_spots"): descent = child
	while str(descent.phase) == "entry": await process_frame
	await create_timer(6.0).timeout
	await _shot("1_descent_safe_spots")
	descent.marker = descent._safe[0].at
	await create_timer(3.0).timeout
	await _shot("2_descent_on_safe")
	menu.queue_free()
	await process_frame
	MHGame.pending_save_state = {}
	MHChapterOne.reset()
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	await create_timer(14.0).timeout
	if world.pda.is_open: world.pda.close()
	await create_timer(.5).timeout
	world.pda.open("map")
	await create_timer(1.2).timeout
	await _shot("3_map")
	world.pda.screen.show_app("cargo")
	await create_timer(.8).timeout
	await _shot("4_cargo")
	quit()

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir + shot_name + ".png")
	print("shot ", shot_name)
