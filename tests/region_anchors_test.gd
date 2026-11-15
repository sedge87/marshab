extends SceneTree

# Run with: godot --headless --path . --script res://tests/region_anchors_test.gd
# Named anchors (docs/terrain-design.md §13): region.json "anchors" are read by
# MHRegion.anchor(); known ids resolve, sit on the ground, carry the right ring,
# and an unknown id gives nothing.

const RegionTerrain := preload("res://scripts/region_terrain.gd")

func _initialize() -> void:
	assert(RegionTerrain.use("test_region"), "The test region loads.")
	var ids := MHRegion.anchors()
	assert(ids.size() > 60, "The region has its anchors (%d)." % ids.size())
	for id in ["far_mesa.top", "far_mesa.ramp_foot", "east_front.pass_2", "north_scarp.pass_1", "glacier.toe", "glacier.alcove",
			"channel.crossing_1", "tube.mouth", "tube.skylight_3", "main_fissure.bridge", "home.centre", "zone.plains", "ice_cave.mouth"]:
		assert(MHRegion.has_anchor(id), "Anchor %s exists." % id)
	var home: Dictionary = RegionTerrain.meta().home
	var rings: Array = RegionTerrain.meta().rings
	for id in ids:
		var a := MHRegion.anchor(id)
		var p := MHRegion.anchor_position(id)
		var ground := RegionTerrain.height(p.x, p.y)
		assert(absf(ground - float(a.height)) < .5, "%s sits on the ground (%.2f vs %.2f)." % [id, float(a.height), ground])
		var d := p.distance_to(Vector2(float(home.centre[0]), float(home.centre[1])))
		var ring := 0
		for k in rings.size():
			if d < float(rings[k]):
				ring = k + 1
				break
		assert(int(a.ring) == ring, "%s is in ring %d (%d)." % [id, ring, int(a.ring)])
		assert(not str(a.get("landform", "")).is_empty(), "%s names its landform." % id)
	assert(MHRegion.anchor_point("far_mesa.top").y > MHRegion.anchor_point("far_mesa.ramp_foot").y + 20.0, "The far mesa's top stands over its ramp's foot.")
	assert(MHRegion.anchor("no_such.anchor").is_empty() and MHRegion.anchor_position("no_such.anchor") == Vector2.INF, "An unknown anchor gives nothing.")
	assert(MHRegion.anchors("far_mesa").size() >= 3, "Anchors can be listed by landform.")
	print("region_anchors_test: PASS (%d anchors)" % ids.size())
	quit()
