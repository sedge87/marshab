extends SceneTree

## Screenshots of the region's landforms from fixed viewpoints (terrain
## overhaul, docs/terrain-overhaul.md), for checking the ground by eye.
##   godot --path . --script res://tools/terrain_views.gd -- [out_dir] [site=<id>] [hud=off] [view names...]
## walk_01 to walk_28 are a walk through the lava tube and the deep, mouth to heart.
## Also "rover_ground" (the debug overlay from above the pad's edge), "map"
## and "map_zoom" (the region map, with the Rover ground layer).
## base=x,z founds the base there (region metres) instead of the site's zone.
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
	# A base founded away from the named zones (run with base=-715,442).
	"base_pad": [-640.0, 380.0, -130.0, -14.0, 14.0],
	# The reshaped region (B2, docs/terrain-design.md).
	"home": [-1400.0, 1000.0, 45.0, -2.0, 2.0],
	"outcrop": [-1165.0, 745.0, 125.0, 0.0, 1.8],
	"pit": [-1065.0, 1355.0, 45.0, -25.0, 1.8],
	"sliver": [-1400.0, 185.0, 0.0, -12.0, 2.5],
	"frost_hollow": [-1400.0, 470.0, 0.0, -6.0, 2.0],
	"channel": [-905.0, 1260.0, 330.0, -10.0, 2.0],
	"mesa_gully": [-930.0, 575.0, 48.0, 8.0, 2.0],
	"north_scarp": [-1700.0, 20.0, 0.0, 2.0, 2.0],
	"east_front": [-480.0, 1300.0, 90.0, 2.0, 2.0],
	"ledges": [-1900.0, 1100.0, 200.0, -4.0, 2.0],
	"yardangs": [-900.0, -150.0, 80.0, 0.0, 2.0],
	"yardang_corridor": [-450.0, -250.0, 76.0, 2.0, 1.8],
	"raised_riverbed": [-250.0, 1650.0, 90.0, -3.0, 2.0],
	"riverbed_top": [-20.0, 1640.0, 0.0, -6.0, 2.0],
	"far_mesa_cliff": [120.0, 1500.0, 90.0, 8.0, 2.0],
	"fresh_crater": [-225.0, 2180.0, 270.0, -12.0, 2.0],
	"glacier": [-1700.0, -1000.0, 270.0, -3.0, 2.0],
	"lava_front": [1150.0, 1500.0, 90.0, 0.0, 2.0],
	"platy": [1450.0, 1400.0, 90.0, -8.0, 2.0],
	"lava_plain": [2000.0, 1300.0, 60.0, -3.0, 2.0],
	"fissure": [2350.0, 345.0, 350.0, -18.0, 2.0],
	"fissure_end": [1350.0, 660.0, 72.0, -8.0, 2.0],
	"chaos": [2300.0, 2100.0, 90.0, 0.0, 2.0],
	"ripples": [2500.0, -900.0, 90.0, -5.0, 2.0],
	"canyon_chute": [-800.0, -1960.0, 0.0, -15.0, 2.0],
	# Caves; "cave" stands on a cave's floor (the eye is the player's, about 1.6 m
	# up), with the suit lamp on. The lava tube's own views are worked out from
	# region.json (see _tube_views): tube_mouth, tube_inside, skylight_below,
	# skylight_above, cold_trap, pitch_top, pitch_foot, lower_level, heart.
	"canyon_cave": [-1200.0, -2309.0, 180.0, 2.0, 1.7],
	"canyon_inside": [-1200.0, -2282.0, 180.0, 0.0, 0.0, "cave"],
	"ice_cave": [-1571.3, -1297.0, 167.0, 2.0, 1.7],
	"ice_inside": [-1564.4, -1268.0, 167.0, -5.0, 0.0, "cave"],
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := "user://terrain_views/"
	if not args.is_empty() and not str(args[0]).contains("="): out_dir = str(args[0]).trim_suffix("/") + "/"
	var site := "region_plains"
	var base: PackedStringArray = []   # base=x,z: found the base there (region metres)
	var wanted: Array = []
	for arg in args.slice(1):
		if str(arg).begins_with("site="): site = str(arg).trim_prefix("site=")
		elif str(arg).begins_with("base="): base = str(arg).trim_prefix("base=").split(",")
		elif str(arg) == "hud=off": pass
		else: wanted.append(str(arg))
	var views := VIEWS.duplicate()
	MHGame.site_id = site
	MHSiteTerrain.region_zone()
	views.merge(_tube_views())
	if wanted.is_empty(): wanted = views.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	MHGame.site_id = site; MHGame.game_mode = "creative"; MHGame.base_site = {}
	if base.size() == 2:
		MHSiteTerrain.region_zone()
		MHGame.base_site = MHBaseSite.make(float(base[0]), float(base[1]), "View base")
	MHGame.pending_save_state = {"site_id": site, "base_site": MHGame.base_site, "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world.set_tutorial_mode("off")
	if args.has("hud=off") and world.get("explore_hud") != null: world.explore_hud.visible = false
	world.day_night.set_hour(15.5); world.day_night.frozen = true
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	var p: Node3D = world.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	for view in wanted:
		if view == "rover_ground" or view == "map" or view == "map_zoom":
			await _special(world, str(view), out_dir)
			continue
		if not views.has(view): continue
		var v: Array = views[view]
		var x := float(v[0]) - origin.x
		var z := float(v[1]) - origin.y
		var ground := MHSiteTerrain.height(x, z)
		var in_cave: bool = v.size() > 5 and v[5] == "cave"
		if in_cave:
			for cave in MHCaves.caves():
				var at := MHCaves._locate(cave, Vector2(x, z))
				if absf(at.lateral) < float(cave.half[clampi(roundi(float(at.k)), 0, (cave.half as PackedFloat32Array).size() - 1)]) + 2.0 and at.along >= 0.0:
					# Near the middle, where a player walks (the walls wander).
					var keep := clampf(float(at.lateral), -.3 * float(cave.half[0]), .3 * float(cave.half[0]))
					if v.size() > 6: keep = float(at.lateral)   # "exact": stand just where the view says
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

## The lava tube's views, from where region.json says it runs (region metres).
func _tube_views() -> Dictionary:
	var out := {}
	for data in MHSiteTerrain.RegionTerrain.meta().get("caves", []):
		if str(data.kind) != "lava_tube": continue
		var points: Array = data.points
		var at := func(k: int) -> Vector2: return Vector2(float(points[clampi(k, 0, points.size() - 1)][0]), float(points[clampi(k, 0, points.size() - 1)][1]))
		var yaw := func(k: int) -> float:
			var d: Vector2 = at.call(k + 5) - at.call(k)
			return rad_to_deg(atan2(d.x, -d.y))
		var forward := func(k: int) -> Vector2: return (at.call(k + 5) - at.call(k)).normalized()
		var mouth: Vector2 = at.call(0) - forward.call(0) * 14.0
		out["tube_mouth"] = [mouth.x, mouth.y, yaw.call(0), -4.0, 1.8]
		out["tube_inside"] = [at.call(40).x, at.call(40).y, yaw.call(40), 0.0, 0.0, "cave"]
		var deep: Dictionary = data.get("deep", {})
		var upper := int(deep.get("from", points.size()))
		var skies: Array = data.get("skylights", [])
		if skies.size() > 2:
			var k := int(float(upper) * .47)
			var sky := Vector2(float(skies[2].position[0]), float(skies[2].position[1]))
			var below: Vector2 = sky - forward.call(k) * 16.0
			out["skylight_below"] = [below.x, below.y, yaw.call(k), 28.0, 0.0, "cave"]
			var above: Vector2 = sky - forward.call(k) * 26.0
			out["skylight_above"] = [above.x, above.y, yaw.call(k), -30.0, 1.8]
		if deep.is_empty(): continue
		out["cold_trap"] = [at.call(upper - 24).x, at.call(upper - 24).y, yaw.call(upper - 24), 0.0, 0.0, "cave"]
		var pitches: Array = deep.get("pitches", [])
		if not pitches.is_empty():
			var top := int(pitches[0].top) - 7
			out["pitch_top"] = [at.call(top).x, at.call(top).y, yaw.call(top), -22.0, 0.0, "cave"]
			var foot := int(pitches[0].foot) + 9
			out["pitch_foot"] = [at.call(foot).x, at.call(foot).y, yaw.call(foot) + 180.0, 28.0, 0.0, "cave"]
			var low := int(pitches[pitches.size() - 1].foot) + 40
			out["lower_level"] = [at.call(low).x, at.call(low).y, yaw.call(low), 0.0, 0.0, "cave"]
		# A walk through the whole cave, mouth to heart: [point, pitch (degrees), look back?, how far
		# across (-1 the left wall, 1 the right)]. Points past the upper tube are counted from the mouth too.
		var profile: Array = data.get("profile", [])
		var number := 1
		for stop: Array in [[20, 0.0, false, 0.0], [176, 0.0, false, 0.0], [214, 0.0, false, -0.5], [234, -8.0, false, 0.55], [370, 6.0, false, 0.0], [399, 22.0, false, -0.5],
				[606, 0.0, false, 0.0], [648, -6.0, false, 0.04], [655, 0.0, false, -0.65], [800, 0.0, false, 0.0], [843, 0.0, false, 0.0],
				[866, -24.0, false, 0.0], [888, 30.0, true, 0.0], [890, 0.0, false, 0.0], [905, 0.0, false, 0.05], [916, -6.0, false, -0.62],
				[951, -24.0, false, 0.0], [969, 30.0, true, 0.0], [972, 0.0, false, -0.45], [991, -10.0, false, 0.6], [1031, -24.0, false, 0.0], [1050, 30.0, true, 0.0],
				[1094, 0.0, false, 0.0], [1125, -6.0, false, 0.65], [1146, 0.0, false, 0.0], [1172, 0.0, false, -0.65], [1226, 4.0, false, 0.0], [1262, 8.0, true, 0.0]]:
			var k := int(stop[0])
			var f: Vector2 = forward.call(k)
			var wide := float(profile[k][0]) if k < profile.size() else float(data.half_width)
			var spot: Vector2 = at.call(k) + Vector2(-f.y, f.x) * float(stop[3]) * wide
			out["walk_%02d" % number] = [spot.x, spot.y, yaw.call(k) + (180.0 if stop[2] else 0.0), float(stop[1]), 0.0, "cave", "exact"]
			number += 1
		var heart := int(deep.get("heart", {}).get("point", points.size() - 10)) - 22
		out["heart"] = [at.call(heart).x, at.call(heart).y, yaw.call(heart), 4.0, 0.0, "cave"]
	return out

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
