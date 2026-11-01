extends SceneTree

# Run with: godot --headless --path . --script res://tests/base_site_test.gd
# Founding the base where the lander comes down (docs/landing-and-base-siting.md
# §4): the three named zones pass the siting check, a cliff, a dune, a
# skylight and the region's edge don't, and a base founded at another
# level spot gets a level pad that blends back into the ground.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const WEATHER_WEAR := preload("res://scripts/weather_wear.gd")

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
	# The base's own conditions (docs/landing-and-base-siting.md §10): a base
	# deep between walls loses low sun and has warmer nights than one on the
	# open plain; ice fields get rich ice and heavy frost.
	MHGame.base_site = {}
	MHGame.site_id = "region"
	var walled := MHBaseSite.make(2000.0, 2200.0, "Walled")
	var open := MHBaseSite.make(-1400.0, 1000.0, "Open")
	var icy := MHBaseSite.make(-1819.4, -1195.2, "Icy")
	assert(float(walled.conditions.shelter_c) > float(open.conditions.shelter_c) + 3.0, "Walls make warmer nights.")
	assert(float(MHBaseSite.sunshine(walled.conditions.horizon).share) < float(MHBaseSite.sunshine(open.conditions.horizon).share) - .05, "Walls hide the low sun.")
	assert(float(icy.ice_deposits[0].richness) >= .6 and float(icy.conditions.frost_peak) > .5, "The ice fields: rich ice, heavy frost.")
	var night := float(MHGame.site().day_cycle.night_temp_c)
	MHGame.base_site = walled
	assert(is_equal_approx(float(MHGame.site().day_cycle.night_temp_c), night + float(walled.conditions.shelter_c)), "The founded site's nights are the base's own.")
	var low_sun := 5.6   # just after sunrise: the walls hide it, open ground doesn't
	var hidden := MHGame.solar_irradiance(low_sun)
	assert(is_equal_approx(WEATHER_WEAR.dust_per_sol("region"), float(walled.conditions.dust_per_sol)), "Dust settles at the base's own rate.")
	MHGame.base_site = open
	assert(MHGame.solar_irradiance(low_sun) > hidden, "Power follows the base's skyline.")
	MHGame.base_site = {}
	MHGame.site_id = "region_plains"
	print("Base site test passed: the zones are valid, bad ground isn't, a base at (%d, %d) is level (worst apron step %.2f m per m), and each spot has its own sun, nights, dust and ice." % [roundi(spot.x), roundi(spot.y), step])
	quit()
