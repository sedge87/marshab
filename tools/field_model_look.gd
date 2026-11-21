extends SceneTree

## Phase 6: photographs one of the field models (assets/models/field/) on a
## plain Mars floor from four sides plus any named close-ups, and prints its
## named parts (where the game hangs things) in Godot space. Palette applied.
##   godot --path . --script res://tools/field_model_look.gd -- <out_dir> <model> [part ...]

const MHPalette := preload("res://scripts/mh_palette.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0].trim_suffix("/") + "/"
	var model_name: String = args[1]
	var close: Array = args.slice(2)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#c9a58a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b89a86")
	env.environment.ambient_light_energy = .6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(35), 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(40, 40)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#9a5a3a"); fm.roughness = 1.0
	plane.material = fm; floor.mesh = plane
	root.add_child(floor)
	var model: Node3D = (load("res://assets/models/field/%s.glb" % model_name) as PackedScene).instantiate()
	root.add_child(model)
	MHPalette.apply(model)
	await process_frame
	# Its size and named parts.
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	print("AABB pos %s size %s" % [box.position, box.size])
	for n in model.find_children("*", "Node3D", true, false):
		if not (n is MeshInstance3D):
			print("PART %-34s %s" % [n.name, (n as Node3D).global_position.snapped(Vector3.ONE * .01)])
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var centre := box.get_center()
	var reach := box.size.length() * 1.5
	for i in 4:
		var a := i * TAU / 4.0 + .6
		cam.look_at_from_position(centre + Vector3(cos(a) * reach, reach * .45, sin(a) * reach), centre)
		await _shot(out + "%s_%d.png" % [model_name, i])
	for part in close:
		var p: Node3D = model.find_child(str(part), true, false)
		if p == null: continue
		cam.fov = 55
		var at := p.global_position
		cam.look_at_from_position(at + Vector3(.0, .25, 1.0) * (reach * .25), at)
		await _shot(out + "%s_%s.png" % [model_name, part])
	quit()

func _shot(path: String) -> void:
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(path)
