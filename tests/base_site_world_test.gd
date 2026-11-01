extends SceneTree

# Run with: godot --headless --path . --script res://tests/base_site_world_test.gd
# A region game founded at a base site away from the named zones
# (docs/landing-and-base-siting.md §4): Terrain3D's ground over the pad and
# its apron matches MHSiteTerrain.height, and the base site is saved.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

func _initialize() -> void:
	MHGame.site_id = "region_plains"; MHGame.game_mode = "creative"
	MHGame.base_site = {}
	MHSiteTerrain.region_zone()
	var spot := MHBaseSite.nearest_valid(-700.0, 500.0, 400.0)
	MHGame.base_site = MHBaseSite.make(spot.x, spot.y, "Test base")
	MHGame.pending_save_state = {"site_id": "region_plains", "base_site": MHGame.base_site, "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 30: await process_frame
	var terrain: Terrain3D = world.find_children("*", "Terrain3D", true, false)[0]
	var worst := 0.0
	var reach := MHBaseSite.pad_reach(MHSiteTerrain.region_zone())
	for x in range(-int(reach), int(reach) + 1, 8):
		for z in range(-int(reach), int(reach) + 1, 8):
			worst = maxf(worst, absf(terrain.data.get_height(Vector3(x, 0, z)) - MHSiteTerrain.height(x, z)))
	assert(worst < .05, "Terrain3D's pad matches the game's heights (%.3f m off)." % worst)
	assert(absf(terrain.data.get_height(Vector3(10, 0, -20))) < .05, "The pad is at 0 in Terrain3D.")
	var saved: Dictionary = world.current_state()
	assert((saved.get("base_site", {}) as Dictionary).get("dynamic", false), "The base site is saved.")
	MHGame.base_site = {}
	print("Base site world test passed: Terrain3D's pad matches (worst %.3f m), the base site is saved." % worst)
	quit()
