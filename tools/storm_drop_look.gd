extends SceneTree

## Screenshots of the storm's first drop in a new Survival game, windowed:
## the view from the hatch towards the ridge, the parachute and pallet up
## close, the pallet open, the cabin's oxygen port with the cartridge plugged
## in, the Notes app and the Map.
##   godot --path . --script res://tools/storm_drop_look.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://storm_drop_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://storm_drop_look_saves"
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
	world.day_night.set_hour(9.5)
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	var drop: Node = world.storm_drop
	var player: Node3D = world.player
	var head: Node3D = player.get_node("Head")
	# From the foot of the ramp, looking at the ridge.
	_stand(world.lander.beside_ramp() + Vector3(0, .1, 0), drop.ridge, 0.0)
	await _shot("1_from_hatch")
	# Halfway: the debris trail.
	var mid: Vector3 = world.lander.global_position.lerp(drop.ridge, .45)
	_stand(Vector3(mid.x, MHSiteTerrain.height(mid.x, mid.z) + 1.0, mid.z), drop.ridge, -8.0)
	await _shot("2_trail")
	# The canopy and pallet from 25 m.
	var pallet: Node3D = drop.pallet
	var view: Vector3 = drop.local_to_world(Vector3(-6, 0, 32))
	_stand(view + Vector3(0, 22.0, 0), drop.ridge, -32.0)
	await _shot("3_canopy")
	# The pallet, close, then open.
	var close: Vector3 = pallet.global_position + pallet.global_transform.basis.z * 3.0 + pallet.global_transform.basis.x * 1.2
	_stand(Vector3(close.x, MHSiteTerrain.height(close.x, close.z) + 1.0, close.z), pallet.global_position, -25.0)
	await _shot("4_pallet")
	pallet.open(false)
	await create_timer(.5).timeout
	await _shot("5_pallet_open")
	# The cabin: the port, then with the cartridge plugged in.
	var lander: Node3D = world.lander
	var port: Node3D = world.cabin_life.port
	var inside: Vector3 = lander.to_global(Vector3(.3, lander.DECK + .9, -.1))
	_stand(inside, port.global_position, -10.0)
	await _shot("6_port")
	drop.cartridge.pick_up()
	drop.cartridge.claim(port, "interact")
	await create_timer(3.0).timeout
	await _shot("7_port_plugged")
	# The slate: Notes and the Map.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pda: Node = world.pda
	pda.received = true
	pda.open("notes")
	await create_timer(1.0).timeout
	await _shot("8_notes")
	pda.screen.show_app("comms")
	await create_timer(1.0).timeout
	await _shot("8b_comms_photo")
	pda.screen.show_app("map")
	await create_timer(1.0).timeout
	await _shot("9_map")
	pda.close()
	await create_timer(.6).timeout
	# The blue sunset, from the ridge looking west.
	var sunset := float(MHGame.site().get("day_cycle", {}).get("sunset_hour", 19.0))
	world.day_night.set_hour(sunset - .8)
	_stand(drop.ridge + Vector3(0, 1.8, 0), drop.ridge + Vector3(-100, 6, 0), 9.0)
	await create_timer(1.0).timeout
	await _shot("10_blue_sunset")
	quit()

## Puts the player at `at` looking towards `target`, the head pitched by `pitch` degrees.
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
