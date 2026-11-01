extends SceneTree

## Screenshots of the region's landforms from fixed viewpoints (terrain
## overhaul, docs/terrain-overhaul.md), for checking the ground by eye.
##   godot --path . --script res://tools/terrain_views.gd -- [out_dir] [site=<id>] [view names...]
## Run windowed. Viewpoints are in region metres, so any region site works.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# name: [region x, region z, yaw (degrees, 0 looks north), pitch (degrees), metres above ground]
const VIEWS := {
	"crater_wall": [1500.0, -250.0, 135.0, 4.0, 2.0],
	"crater_rim": [700.0, 300.0, 40.0, -6.0, 3.0],
	"canyon": [-300.0, -2400.0, 180.0, 10.0, 2.0],
	"canyon_ramp": [-250.0, -1500.0, 0.0, -8.0, 3.0],
	"mesa": [-1600.0, 1650.0, 90.0, 4.0, 2.0],
	"ridge_pass": [-1300.0, 1550.0, 80.0, 0.0, 2.0],
	"dunes": [-1100.0, -1600.0, -75.0, -6.0, 2.5],
	"ice": [-1500.0, -1000.0, 20.0, -10.0, 2.0],
	"valleys": [900.0, 1300.0, 160.0, -12.0, 6.0],
	"boulders": [-2150.0, 1950.0, 90.0, -8.0, 2.0],
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := "user://terrain_views/"
	if not args.is_empty() and not str(args[0]).contains("="): out_dir = str(args[0]).trim_suffix("/") + "/"
	var site := "region_plains"
	var wanted: Array = []
	for arg in args.slice(1):
		if str(arg).begins_with("site="): site = str(arg).trim_prefix("site=")
		else: wanted.append(str(arg))
	if wanted.is_empty(): wanted = VIEWS.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	MHGame.site_id = site; MHGame.game_mode = "creative"; MHGame.pending_save_state = {"site_id": site, "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	world.set_tutorial_mode("off")
	world.day_night.set_hour(15.5); world.day_night.frozen = true
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	var p: Node3D = world.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	for view in wanted:
		if not VIEWS.has(view): continue
		var v: Array = VIEWS[view]
		var x := float(v[0]) - origin.x
		var z := float(v[1]) - origin.y
		p.global_position = Vector3(x, MHSiteTerrain.height(x, z) + float(v[4]), z)
		p.rotation.y = deg_to_rad(-float(v[2]))
		(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(float(v[3]))
		for i in 90: await process_frame   # let the terrain and rocks round the new spot load
		root.get_texture().get_image().save_png(out_dir + "%s.png" % view)
		print("VIEW %s at (%d, %d): %s" % [view, roundi(v[0]), roundi(v[1]), MHSiteTerrain.geology_unit(x, z)])
	quit()
