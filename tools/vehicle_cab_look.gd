extends SceneTree

## Phase 6: the field vehicles as the game builds them (crew_rover.gd), on a
## plain floor: the cockpit view (the live screens), a look at the cab parts
## you click, and from outside.
##   godot --path . --resolution 1280x800 --script res://tools/vehicle_cab_look.gd -- <out_dir>

const ROVER := preload("res://scripts/crew_rover.gd")

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	MHGame.game_mode = "survival"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#c9a58a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b89a86")
	env.environment.ambient_light_energy = .7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(150), 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(80, .2, 80)
	shape.shape = box; shape.position.y = -.1
	floor.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(80, 80)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#9a5a3a"); fm.roughness = 1.0
	plane.material = fm; mesh.mesh = plane
	floor.add_child(mesh)
	root.add_child(floor)
	for kind in ["buggy", "rover"]:
		var v = ROVER.new()
		v.kind = kind
		root.add_child(v)
		v.battery = 64.0
		v.trail = PackedVector2Array([Vector2(0, 0), Vector2(30, -40), Vector2(80, -60), Vector2(140, -120), Vector2(160, -200)])
		v.o2 = 15.0 if kind == "rover" else 0.0
		v.lights_on = true
		for i in 10: await physics_frame
		v.set_physics_process(false)
		v._cam.current = true
		v.first_person = true
		for look in [[0.0, -0.25, "ahead"], [-0.5, -0.45, "screens"], [0.9, -0.5, "side"], [2.6, -0.4, "back"]]:
			v._look = Vector2(look[0], look[1])
			v._place_camera(1.0)
			v._aim_cab()
			await _shot(out + "%s_cab_%s.png" % [kind, look[2]])
			print("%s %s aimed=%s" % [kind, look[2], v._aimed])
		# Look straight at each part you can click, then open it.
		for what in v._cab:
			var eye: Vector3 = v._cam.global_position
			var dir: Vector3 = ((v._cab[what] as Node3D).global_position - eye).normalized()
			v._look = Vector2(wrapf(atan2(-dir.x, -dir.z) - v.rotation.y, -PI, PI), asin(dir.y))
			v._place_camera(1.0)
			v._aim_cab()
			print("%s look at %s: aimed=%s (%.2f m)" % [kind, what, v._aimed, eye.distance_to((v._cab[what] as Node3D).global_position)])
			v._cab_move(what, true)
			for i in 30: await process_frame
			await _shot(out + "%s_open_%s.png" % [kind, what])
		v._cam.global_position = v.global_position + Vector3(7, 3.5, -8)
		v._cam.look_at(v.global_position + Vector3.UP * 1.2)
		await _shot(out + "%s_outside.png" % kind)
		v.queue_free()
		await process_frame
	quit()

func _shot(path: String) -> void:
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(path)
