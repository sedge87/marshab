extends SceneTree

## Screenshots of the region's landforms from fixed viewpoints (terrain
## overhaul, docs/terrain-overhaul.md), for checking the ground by eye.
##   godot --path . --script res://tools/terrain_views.gd -- [out_dir] [site=<id>] [view names...]
## Also "rover_ground" (the debug overlay from above the pad's edge), "map"
## and "map_zoom" (the region map, with the Rover ground layer).
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
	"mound": [1180.0, -260.0, -39.0, 6.0, 2.0],
	# Caves (stage 5); "cave" stands on a cave's floor (the eye is the player's, about
	# 1.6 m up), with the suit lamp on.
	"tube_mouth": [-1200.5, 1252.0, 160.0, -4.0, 1.8],
	"tube_inside": [-1178.0, 1312.0, 160.0, 0.0, 0.0, "cave"],
	"skylight_below": [-1113.0, 1469.0, 160.0, 28.0, 0.0, "cave"],
	"skylight_above": [-1132.0, 1470.0, 112.0, -30.0, 1.8],
	"tube_across": [-1085.0, 1555.0, 70.0, -22.0, 1.8],
	"tube_top": [-1150.0, 1470.0, 90.0, -60.0, 45.0],
	"tube_ground": [-1075.0, 1560.0, 160.0, -12.0, 2.0],
	"canyon_cave": [-1200.0, -2309.0, 180.0, 2.0, 1.7],
	"canyon_inside": [-1200.0, -2282.0, 180.0, 0.0, 0.0, "cave"],
	"ice_cave": [-1571.3, -1297.0, 167.0, 2.0, 1.7],
	"ice_inside": [-1564.4, -1268.0, 167.0, -5.0, 0.0, "cave"],
	"tube_deep": [-1031.0, 1683.0, 160.0, 0.0, 0.0, "cave"],
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
		if view == "rover_ground" or view == "map" or view == "map_zoom":
			await _special(world, str(view), out_dir)
			continue
		if not VIEWS.has(view): continue
		var v: Array = VIEWS[view]
		var x := float(v[0]) - origin.x
		var z := float(v[1]) - origin.y
		var ground := MHSiteTerrain.height(x, z)
		var in_cave: bool = v.size() > 5 and v[5] == "cave"
		if in_cave:
			for cave in MHCaves.caves():
				var at := MHCaves._locate(cave, Vector2(x, z))
				if absf(at.lateral) < float(cave.half[0]) and at.along >= 0.0:
					# Near the middle, where a player walks (the walls wander).
					var keep := clampf(float(at.lateral), -.3 * float(cave.half[0]), .3 * float(cave.half[0]))
					var moved := Vector2(x, z) - MHCaves._normal(cave, roundi(float(at.k))) * (float(at.lateral) - keep)
					x = moved.x; z = moved.y
					ground = MHCaves._floor(cave, moved, MHCaves._locate(cave, moved))
		p.global_position = Vector3(x, ground + float(v[4]), z)
		p.set_flashlight_enabled(in_cave)
		p.rotation.y = deg_to_rad(-float(v[2]))
		(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(float(v[3]))
		for i in 90: await process_frame   # let the terrain and rocks round the new spot load
		root.get_texture().get_image().save_png(out_dir + "%s.png" % view)
		print("VIEW %s at (%d, %d): %s" % [view, roundi(v[0]), roundi(v[1]), MHSiteTerrain.geology_unit(x, z)])
	quit()

func _special(world: Node, view: String, out_dir: String) -> void:
	var p: Node3D = world.player
	if view == "rover_ground":
		world.debug_panel._set_rover_ground(true) if world.get("debug_panel") != null else _rover_ground(world)
		p.global_position = Vector3(110.0, MHSiteTerrain.height(110.0, 60.0) + 25.0, 60.0)
		p.rotation.y = deg_to_rad(-60.0)
		(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(-35.0)
	else:
		var map: Node = world.get_children().filter(func(n): return n.get_script() == preload("res://scripts/region_map.gd"))[0]
		map.visible = true
		map._zoomed = view == "map_zoom"
		map._set_view()
	for i in 60: await process_frame
	root.get_texture().get_image().save_png(out_dir + "%s.png" % view)
	print("VIEW %s" % view)

func _rover_ground(world: Node) -> void:
	var overlay := preload("res://scripts/traversability.gd").new()
	preload("res://scripts/traversability.gd").on = true
	overlay.setup(world)
	world.add_child(overlay)
