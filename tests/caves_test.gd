extends SceneTree

# Run with: godot --headless --path . --script res://tests/caves_test.gd
# Caves and the lava tube (docs/terrain-overhaul.md §3): every cave has a
# floor at its mouth and inside, floor_at() answers inside and is NAN
# outside (and on the ground over a cave), the tube's ramp pit is under 20
# degrees, it's dark deep in and light under a skylight, and the tunnel
# meshes build.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

func _initialize() -> void:
	MHGame.site_id = "region_plains"
	var caves := MHCaves.caves()
	assert(caves.size() == 3, "The region has the lava tube and two caves (%d)." % caves.size())
	var tube: Dictionary = caves.filter(func(c): return c.kind == "lava_tube")[0]
	for cave in caves:
		var points: PackedVector3Array = cave.points
		for k in [1, points.size() / 2, points.size() - 2]:
			var inside := points[k] + Vector3.UP * 1.0
			var floor_y := MHCaves.floor_at(inside)
			assert(not is_nan(floor_y) and absf(floor_y - points[k].y) < float(cave.height[k]), "%s: a floor inside at point %d (%.1f)." % [cave.id, k, floor_y])
			# Over the cave, on the ground: not inside it.
			var over := Vector3(points[k].x, MHSiteTerrain.height(points[k].x, points[k].z) + 1.0, points[k].z)
			if over.y > points[k].y + float(cave.height[k]) + 2.0:
				assert(is_nan(MHCaves.floor_at(over)), "%s: the ground over point %d isn't in the cave." % [cave.id, k])
		# The mouth: the ground just outside is level with the floor (you can walk in).
		var out := points[0] + Vector3(points[0].x - points[2].x, 0, points[0].z - points[2].z).normalized() * 3.0
		assert(absf(MHSiteTerrain.height(out.x, out.z) - points[0].y) < .8, "%s: the ground at the mouth meets the floor (%.2f vs %.2f)." % [cave.id, MHSiteTerrain.height(out.x, out.z), points[0].y])
		assert(is_nan(MHCaves.floor_at(points[0] + Vector3(40.0, 0, 40.0))), "%s: NAN outside." % cave.id)
		assert(MHCaves.darkness(points[points.size() - 2] + Vector3.UP) > .9, "%s: dark at the back." % cave.id)
		var built := MHCaves.new()
		var faces := (built._tunnel(cave) as SurfaceTool).commit().get_faces().size() / 3
		built.free()
		assert(faces > points.size() * 20, "%s: the tunnel builds (%d triangles)." % [cave.id, faces])
	# The ramp pit: under 20 degrees all the way down, measured across 4 m.
	var points: PackedVector3Array = tube.points
	var axis := Vector2(points[1].x - points[0].x, points[1].z - points[0].z).normalized()
	var worst := 0.0
	for i in 64:
		var a := Vector2(points[0].x, points[0].z) - axis * (2.0 + i * 2.0)
		var b := a - axis * 4.0
		worst = maxf(worst, absf(MHSiteTerrain.height(b.x, b.y) - MHSiteTerrain.height(a.x, a.y)) / 4.0)
	assert(worst < tan(deg_to_rad(20.0)), "The tube's ramp is under 20 degrees (worst %.1f)." % rad_to_deg(atan(worst)))
	# A skylight lets the light in.
	for sky in tube.skylights:
		var floor_here := MHCaves._floor(tube, sky.centre, MHCaves._locate(tube, sky.centre))
		assert(MHCaves.darkness(Vector3(sky.centre.x, floor_here + 1.5, sky.centre.y)) < .2, "Light under a skylight.")
	print("Caves test passed: %d caves with floors, mouths and dark backs; tube ramp worst %.1f degrees; tunnels build." % [caves.size(), rad_to_deg(atan(worst))])
	quit(0)
