extends SceneTree

## Screenshots of step 3a's pallets in a new Survival game, windowed: the view
## from the Parachute ridge towards pallets 2 and 3, each site close up, the
## power pack in its pallet, the solar blanket laid out by the lander, GAR-Y
## waking, and the sunset with GAR-Y.
##   godot --path . --script res://tools/drop_field_look.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://drop_field_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://drop_field_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
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
	var field: Node = world.drop_field
	var ridge: Vector3 = world.storm_drop.ridge
	# From the ridge, towards each of the next two parachutes.
	for kind in ["power", "gary"]:
		_stand(ridge + Vector3(0, 1.8, 0), field.sites[kind].at, -1.0)
		await _shot("1_ridge_to_" + kind)
	# Each site from the air and up close.
	for kind in ["power", "gary", "tools"]:
		var site: Node = field.sites[kind]
		var high: Vector3 = site.local_to_world(Vector3(-4, 0, 34))
		_stand(high + Vector3(0, 20.0, 0), site.at, -30.0)
		await _shot("2_%s_site" % kind)
		var pallet: Node3D = site.pallet
		var close: Vector3 = pallet.global_position + pallet.global_transform.basis.z * 3.0 + pallet.global_transform.basis.x * 1.2
		_stand(Vector3(close.x, MHSiteTerrain.height(close.x, close.z) + 1.0, close.z), pallet.global_position, -25.0)
		pallet.open(false)
		await create_timer(.6).timeout
		await _shot("3_%s_open" % kind)
	# GAR-Y awake by its pallet (you're at the tools pallet now, so stand by it).
	var gary: Node3D = world.scout_rover
	if gary != null:
		var gp: Node3D = field.sites.gary.pallet
		_stand(gp.global_position + Vector3(4, 1.2, 4), gp.global_position, -12.0)
		gary.global_position = gp.global_position + Vector3(1.8, .2, 1.0)
		await _shot("4_gary_awake")
	# The power pack laid out by the lander.
	var pack: Node = field.sites.power.pack
	pack.lay_out()
	await create_timer(2.0).timeout
	var lander: Node3D = world.lander
	var eye := lander.to_global(Vector3(12.0, 0, 9.0))
	_stand(Vector3(eye.x, MHSiteTerrain.height(eye.x, eye.z) + 3.0, eye.z), lander.to_global(Vector3(5.0, 0, 1.0)), -18.0)
	await _shot("5_blanket")
	# Sunset with GAR-Y.
	var sunset_hour := float((MHGame.site().get("day_cycle", {}) as Dictionary).get("sunset_hour", 19.0))
	world.day_night.set_hour(sunset_hour - .2)
	MHGame.sol_hour = sunset_hour - .2
	var spot := lander.to_global(Vector3(-14.0, 0, -18.0))
	spot.y = MHSiteTerrain.height(spot.x, spot.z) + 1.0
	world.player.set_meta("ui_freeze", false)
	world.player.global_position = spot
	if gary != null: gary.global_position = spot + Vector3(3, -.8, 0)
	if world.get("pda") != null: world.pda.close()
	await create_timer(1.2).timeout
	await _shot("6_gary_asks")
	if gary != null and gary.has_meta("sunset_offer"):
		gary.interact(world.player)
		await create_timer(4.0).timeout
		await _shot("7_sunset_together")
	quit()

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
