extends SceneTree

## Phase 6: the MC-01 through its hand-worked stages (hand_corer.gd's rig):
## planted, mid-stroke and half down, head open with the liner drawn and the
## core showing, capped. Plain floor; the floor is the ground line.
##   godot --path . --resolution 1280x800 --script res://tools/corer_look.gd -- <out_dir>

const CORER := preload("res://scripts/hand_corer.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#c9a58a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b89a86")
	env.environment.ambient_light_energy = .7
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(35), 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(10, 10)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#9a5a3a")
	plane.material = fm; floor.mesh = plane
	root.add_child(floor)
	var model: Node3D = (load(CORER.MC01) as PackedScene).instantiate()
	root.add_child(model)
	MHPalette.apply(model)
	await process_frame
	var rig = CORER.MC01Rig.new(model)
	print("lift %.3f" % rig.lift)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(1.3, 1.0, 1.6), Vector3(0, .45, 0))
	rig.reset(false)
	model.position.y = -rig.lift
	await _shot(out + "corer_planted.png")
	rig.shoe(true)
	model.position.y = -rig.lift - CORER.SINK_M * .5
	rig.stroke()
	for i in 4: await process_frame
	await _shot(out + "corer_stroke_ice_shoe.png")
	model.position.y = -rig.lift - CORER.SINK_M
	rig.head(1.0)
	rig.sleeve(1.0)
	rig.show_core(true, true)
	await _shot(out + "corer_drawn.png")
	rig.cap(true)
	await _shot(out + "corer_capped.png")
	quit()

func _shot(path: String) -> void:
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(path)
