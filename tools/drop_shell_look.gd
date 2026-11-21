extends SceneTree

## Screenshots of R3's staged drop (docs/intro-rework.md §2), windowed: the
## buggy's split shell, the drone's capsule and the HabRover's heavy lander,
## each from two sides, and the lander's glint from home at a low sun.
##   godot --path . --script res://tools/drop_shell_look.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://drop_shell_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://drop_shell_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "hints"; MHGame.colony_name = "Look"
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	await create_timer(12.0).timeout
	if world.get("pda") != null: world.pda.close()
	world._intro_stage = "done"
	world.day_night.frozen = true
	world.day_night.set_hour(10.0)
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	world.debug_vehicles_now = true
	world._sync_region_vehicles()
	await create_timer(1.0).timeout
	for kind in ["buggy", "drone", "rover"]:
		var shell: Node3D = world.drop_shells.get(kind)
		if shell == null: print("no shell ", kind); continue
		var at: Vector3 = shell.spot
		var r := 26.0 if kind == "rover" else 16.0
		for side in [0, 1]:
			var a: float = .7 + side * 2.3
			var eye := at + Vector3(cos(a), 0, sin(a)) * r
			eye.y = MHSiteTerrain.height(eye.x, eye.z) + (5.0 if kind == "rover" else 3.0)
			_stand(eye, at, -16.0)
			await _shot("%s_%d" % [kind, side])
	# The glint from home, at a low morning sun.
	var lander_shell: Node3D = world.drop_shells.get("rover")
	if lander_shell != null:
		var sunrise := float((MHGame.site().get("day_cycle", {}) as Dictionary).get("sunrise_hour", 6.0))
		for h in [sunrise + .6, 10.0]:
			world.day_night.set_hour(h)
			MHGame.sol_hour = h
			var home: Vector3 = world.lander.global_position + Vector3(0, 0, 0)
			var target: Vector3 = lander_shell.spot
			var d := (target - home); d.y = 0
			var eye := home + d.normalized() * 8.0
			eye.y = MHSiteTerrain.height(eye.x, eye.z) + 1.8
			_stand(eye, target, 0.0)
			world.player.rotation.y += .05   # the glint just off the crosshair
			await create_timer(.5).timeout
			print("glint at %.1f h: %.2f, %d m" % [h, lander_shell.glint_strength(eye), int(eye.distance_to(target))])
			await _shot("glint_%02d" % int(h))
			print("glint learned: ", world.known.knows("glint:habrover"))
			var top: Vector3 = lander_shell.glint.global_position
			var e2 := eye + Vector3.UP * 1.6
			var worst := -INF; var worst_at := 0.0
			for i in range(1, 200):
				var p := e2.lerp(top, i / 200.0)
				var over := MHSiteTerrain.height(p.x, p.z) - p.y
				if over > worst: worst = over; worst_at = e2.distance_to(p)
			print("eye y %.1f, glint y %.1f, worst block %.1f m above the line at %d m" % [e2.y, top.y, worst, int(worst_at)])
			# Best nearby spot for the shot: walk round home looking for a clear line.
			for r in [30.0, 60.0, 120.0, 200.0]:
				for k in 12:
					var a2: float = k * TAU / 12.0
					var s: Vector3 = home + Vector3(cos(a2), 0, sin(a2)) * r
					s.y = MHSiteTerrain.height(s.x, s.z) + 1.6
					var clear := true
					for i in range(1, 200):
						var p: Vector3 = s.lerp(top, i / 200.0)
						if MHSiteTerrain.height(p.x, p.z) > p.y + .3: clear = false; break
					if clear: print("clear from r=%d k=%d" % [int(r), k])
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
