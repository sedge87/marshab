extends SceneTree

## Screenshots of the lifepod days (scripts/lifepod.gd), windowed: the
## lifepod bench in the cabin, the iron outcrop, the ice wall, the frost
## patch, carrying an ice chunk, the slate's Camera app, and the journal page
## with a photo and your own note.
##   godot --path . --script res://tools/lifepod_look.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://lifepod_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://lifepod_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "hints"; MHGame.colony_name = "Look"
	MHChapterOne.reset()
	MHChapterOne.has_hammer = true
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	await create_timer(12.0).timeout
	if world.get("pda") != null: world.pda.close()
	world._intro_stage = "done"
	world.day_night.frozen = true
	world.day_night.set_hour(10.0)
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	var pod: Node = world.lifepod
	var player: Node3D = world.player
	var head: Node3D = player.get_node("Head")
	# The bench, from the cabin's middle.
	var bench: Node3D = pod.bench
	var stand: Vector3 = bench.global_position - bench.global_transform.basis.z * 1.3
	player.global_position = stand + Vector3(0, .1, 0)
	_face(bench.global_position)
	head.rotation.x = deg_to_rad(-22.0)
	await create_timer(.8).timeout
	await _shot("0_bench")
	# Each thread, from 9 m.
	for kind in ["iron", "ice_wall", "frost"]:
		var site: Node3D = pod.sites[kind]
		var from: Vector3 = site.global_position + Vector3(6.5, 0, 6.5)
		player.global_position = Vector3(from.x, MHSiteTerrain.height(from.x, from.z) + .1, from.z)
		_face(site.global_position)
		head.rotation.x = deg_to_rad(-18.0)
		await create_timer(1.2).timeout
		await _shot("1_" + kind)
	# Chip and carry ice at the frost patch.
	var frost: Node3D = pod.sites.frost
	frost.chip_for(2.0)
	await create_timer(.6).timeout
	await _shot("2_carrying_ice")
	# The Camera app, aimed at the ice wall.
	var wall: Node3D = pod.sites.ice_wall
	var at: Vector3 = wall.global_position + Vector3(10, 0, 10)
	player.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + .1, at.z)
	_face(wall.global_position)
	head.rotation.x = deg_to_rad(-8.0)
	await create_timer(1.0).timeout
	world.pda.open("camera")
	await create_timer(1.0).timeout
	await _shot("3_camera_app")
	await world.slate_camera.take()
	await create_timer(.6).timeout
	world.pda.close()
	await create_timer(.6).timeout
	# The journal page.
	MHJournal.set_own(MHJournal.today(1), "The ice wall is bigger than it looked from the ridge. Slabs like dirty glass. GAR-Y kept rolling up to it and backing off.")
	var book: Control = load("res://scripts/journal_book.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	layer.add_child(book)
	await create_timer(.6).timeout
	await _shot("4_journal")
	quit()

func _face(target: Vector3) -> void:
	var d: Vector3 = target - world.player.global_position
	world.player.rotation.y = atan2(-d.x, -d.z)

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir + shot_name + ".png")
	print("shot ", shot_name)
