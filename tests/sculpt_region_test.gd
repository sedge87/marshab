extends SceneTree

## The sculpt tool (B5 step 6): load the generated land into Terrain3D, raise
## a patch by 3 m, save, and the .landdelta holds +3 m there and nothing far
## off. Written to user://, not data/.

func _init() -> void:
	var tool_node: Node3D = load("res://tools/sculpt_region.gd").new()
	tool_node.sculpt_path = "user://sculpt_test.landdelta"
	if FileAccess.file_exists(tool_node.sculpt_path): DirAccess.remove_absolute(tool_node.sculpt_path)
	root.add_child(tool_node)
	await process_frame
	tool_node.load_land()
	await process_frame
	var terrain: Terrain3D = tool_node.terrain
	var failures: Array[String] = []
	if terrain == null: failures.append("no terrain: " + str(tool_node.status))
	else:
		var p := Vector3(-1200.0, 0.0, 800.0)
		var before := terrain.data.get_height(p)
		var expect := before
		for dz in range(-10, 11, 2):
			for dx in range(-10, 11, 2):
				var q := p + Vector3(dx, 0, dz)
				terrain.data.set_height(q, terrain.data.get_height(q) + 3.0)
		terrain.data.get_regionp(p).set_modified(true)
		tool_node.save_sculpt()
		var d := MHLandDelta.read(tool_node.sculpt_path)
		if d == null: failures.append("nothing saved: " + str(tool_node.status))
		else:
			var at := d.height_at(p.x, p.z)
			if absf(at - 3.0) > .1: failures.append("sculpt at the patch %.2f m, not 3 (terrain had %.2f)" % [at, expect])
			if absf(d.height_at(p.x + 200.0, p.z)) > .05: failures.append("sculpt away from the patch %.2f m" % d.height_at(p.x + 200.0, p.z))
			print("sculpt_region_test: %d tiles saved" % d.tiles.size())
	tool_node.queue_free()
	if failures.is_empty():
		print("sculpt_region_test: PASS")
		quit(0)
	else:
		for f in failures: print("sculpt_region_test: FAIL ", f)
		quit(1)
