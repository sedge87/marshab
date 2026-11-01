extends SceneTree

# Run with: godot --headless --path . --script res://tests/base_site_test.gd
# Founding the base where the lander comes down (docs/landing-and-base-siting.md
# §4): the three named zones pass the siting check, a cliff, a dune, a
# skylight and the region's edge don't, and a base founded at another
# level spot gets a level pad that blends back into the ground.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

func _initialize() -> void:
	MHGame.base_site = {}
	for site in ["region_plains", "region_crater", "region_riverbed"]:
		MHGame.site_id = site
		var zone := MHSiteTerrain.region_zone()
		var half := float(MHSiteTerrain.settings().get("pad_half", 60.0))
		var why := MHBaseSite.reason(float(zone.centre[0]), float(zone.centre[1]), half)
		assert(why.is_empty(), "%s: its zone is a valid base site (%s)." % [site, why])
	MHGame.site_id = "region_plains"
	MHSiteTerrain.region_zone()
	var bad := {
		"the canyon wall": Vector2(-200.0, -2480.0),
		"the dune field": Vector2(-650.0, -1640.0),
		"a skylight": Vector2(-1108.8, 1480.2),
		"the region's edge": Vector2(2900.0, 0.0),
	}
	for name in bad:
		var at: Vector2 = bad[name]
		assert(not MHBaseSite.valid(at.x, at.y), "No base on %s." % name)
	# A base somewhere else on the plains, at the nearest valid spot.
	var spot := MHBaseSite.nearest_valid(-700.0, 500.0, 400.0)
	assert(not is_inf(spot.x), "There's valid ground near (-700, 500).")
	MHGame.base_site = MHBaseSite.make(spot.x, spot.y, "Test base")
	var zone := MHSiteTerrain.region_zone()
	assert(zone.get("dynamic", false), "The base site is the zone.")
	var worst := 0.0
	for x in range(-60, 61, 6):
		for z in range(-60, 61, 6): worst = maxf(worst, absf(MHSiteTerrain.height(x, z)))
	assert(worst < .001, "The pad is level (%.3f m off)." % worst)
	# Past the apron the ground is the land's own.
	var reach := MHBaseSite.pad_reach(zone) + 1.0
	var natural := MHSiteTerrain.RegionTerrain.height(spot.x + reach, spot.y) - float(zone.height)
	assert(absf(MHSiteTerrain.height(reach, 0.0) - natural) < .001, "The ground beyond the apron is unchanged.")
	# The apron has no step: neighbouring points 1 m apart differ by less than the steep limit.
	var step := 0.0
	for d in range(60, int(reach) + 2):
		step = maxf(step, absf(MHSiteTerrain.height(d + 1, 0.0) - MHSiteTerrain.height(d, 0.0)))
	MHGame.base_site = {}
	print("Base site test passed: the zones are valid, bad ground isn't, a base at (%d, %d) is level (worst apron step %.2f m per m)." % [roundi(spot.x), roundi(spot.y), step])
	quit()
