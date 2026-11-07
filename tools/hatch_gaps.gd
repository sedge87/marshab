extends SceneTree

## Checks the shut crew-lander hatch for gaps: from several spots inside the
## airlock, with the sky painted magenta, it counts pixels where the sky or
## the ground shows round the door, and says where each crosses the door
## plane (lander space). Saves the views too.
##   godot --path . --script res://tools/hatch_gaps.gd -- [out_dir]

var out_dir := "user://hatch_gaps/"
var world: Node

const VIEWS := [
	# [eye, target (both above the deck), head pitch, name]
	[Vector3(.55, .2, -2.0), Vector3(1.0, 1.6, -2.65), 0.0, "edge_right"],
	[Vector3(-.55, .2, -2.0), Vector3(-1.0, 1.6, -2.65), 0.0, "edge_left"],
	[Vector3(.7, .2, -2.3), Vector3(1.0, .6, -2.75), -30.0, "edge_low"],
	[Vector3(0, .2, -1.7), Vector3(0, 0, -2.7), -40.0, "sill"],
	[Vector3(.4, .2, -2.0), Vector3(.9, 0, -2.7), -45.0, "sill_corner"],
	[Vector3(0, .3, -1.7), Vector3(0, 3.2, -2.6), 35.0, "top"],
	[Vector3(.5, .3, -2.1), Vector3(1.0, 3.2, -2.6), 45.0, "top_corner"],
	[Vector3(0, -1.2, .3), Vector3(0, 0, -4.0), -2.0, "cabin"],
]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://hatch_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "off"; MHGame.colony_name = "Gaps"
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	world.day_night.set_hour(11.0)
	var lander: Node3D = world.lander
	lander.set_hatch(false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.5, .5, .5)
	# No HUD: its orange text would read as ground.
	for layer in root.find_children("*", "CanvasLayer", true, false): (layer as CanvasLayer).visible = false
	var total := 0
	for view in VIEWS:
		var eye: Vector3 = view[0]
		var target: Vector3 = view[1]
		_stand(lander.to_global(eye + Vector3(0, lander.DECK, 0)), lander.to_global(target + Vector3(0, lander.DECK, 0)), view[2])
		for i in 6: await process_frame
		var cam := root.get_viewport().get_camera_3d()
		cam.environment = env
		for i in 6: await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out_dir + str(view[3]) + ".png")
		var scale := Vector2(root.get_visible_rect().size) / Vector2(img.get_size())
		var cells := {}
		var count := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if Vector2(x, y).distance_to(Vector2(img.get_size()) * .5) < 30.0: continue   # the crosshair
				var c := img.get_pixel(x, y)
				var sky := c.r > .8 and c.b > .8 and c.g < .25
				# Only the ground seen past the door (further than the door plane).
				if not sky:
					if not (c.r > .35 and c.g > .15 and c.g < c.r * .72 and c.b < c.g * .9): continue
				var p := Vector2(x, y) * scale
				var o: Vector3 = lander.to_local(cam.project_ray_origin(p))
				var d: Vector3 = lander.global_transform.basis.inverse() * cam.project_ray_normal(p)
				if absf(d.z) < .001: continue
				var t := (-2.6 - o.z) / d.z
				if t <= 0.0: continue
				var cross := o + d * t
				if not sky and (absf(cross.x) > 1.5 or cross.y < 1.8 or cross.y > 6.0): continue
				count += 1
				var q := o + d * t
				var k := "%s x%.2f y%.1f" % ["sky" if sky else "ground", snappedf(q.x, .05), q.y]
				cells[k] = int(cells.get(k, 0)) + 1
		total += count
		var keys := cells.keys()
		keys.sort()
		print("%-12s %5d gap pixels  %s" % [view[3], count, str(keys.slice(0, 24))])
		cam.environment = null
	print("TOTAL gap pixels: ", total)
	quit()

## Is the ground at this pixel beyond the door (so it's seen through a gap)?
func _ground_beyond(lander: Node3D, cam: Camera3D, p: Vector2) -> bool:
	var space := lander.get_world_3d().direct_space_state
	var from := cam.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(p) * 30.0)
	var r := space.intersect_ray(q)
	return not r.is_empty() and lander.to_local(r.position as Vector3).z < -2.9 and r.collider.name.contains("Terrain")

func _stand(at: Vector3, target: Vector3, pitch: float) -> void:
	var player: Node3D = world.player
	player.global_position = at
	var d := target - at
	player.rotation.y = atan2(-d.x, -d.z)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(pitch)
	player.set_meta("ui_freeze", true)
