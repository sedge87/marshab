extends SceneTree

# Run with: godot --headless --path . --script res://tests/region_terrain_test.gd
# The region after the terrain overhaul (docs/terrain-overhaul.md): every
# landing pad is level and its ground sane, the geology and rock maps answer,
# rock placements keep their shape, and every landing zone has a rover route
# to every major destination (checked by the generator, and planned here
# with the game's own route planner).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const ROUTE := preload("res://scripts/rover_route.gd")

func _initialize() -> void:
	for site in ["region_plains", "region_crater", "region_riverbed"]:
		MHGame.site_id = site
		var zone := MHSiteTerrain.region_zone()
		assert(not zone.is_empty(), "%s lands in the region." % site)
		var pad := float(MHSiteTerrain.settings().get("pad_half", 60.0))
		for p in [Vector2.ZERO, Vector2(pad, pad), Vector2(-pad, pad), Vector2(pad, -pad), Vector2(-pad, -pad)]:
			assert(absf(MHSiteTerrain.height(p.x, p.y)) < .05, "%s: the pad is level at %s (%.2f m)." % [site, p, MHSiteTerrain.height(p.x, p.y)])
		for i in 400:
			var x := -2000.0 + (i % 20) * 200.0
			var z := -2000.0 + (i / 20) * 200.0
			var y := MHSiteTerrain.height(x, z)
			assert(is_finite(y) and absf(y) < 800.0, "%s: sane ground at (%d, %d): %.1f." % [site, x, z, y])
		assert(not MHSiteTerrain.geology_unit(0.0, 0.0).is_empty(), "%s: the pad has a geology unit." % site)
		var here: Vector2 = MHSiteTerrain.RegionTerrain.rock_density(float(zone.centre[0]), float(zone.centre[1]))
		assert(here.x < .05, "%s: no rocks scattered on the pad (%.2f)." % [site, here.x])
		for rock in MHSiteTerrain.rock_placements():
			assert(rock.has("position") and rock.position is Vector3 and rock.has("mesh"), "%s: rock placements keep a position and a mesh." % site)
	# Geology across the region: several units, as named in region.json.
	var units := {}
	MHGame.site_id = "region_plains"
	for i in 900:
		units[MHSiteTerrain.geology_unit(-1500.0 + (i % 30) * 120.0, -1500.0 + (i / 30) * 120.0)] = true
	assert(units.size() >= 6, "The geology map has many units (%s)." % ", ".join(units.keys()))
	# The generator's route check: every zone reaches every destination.
	var routes: Array = MHSiteTerrain.RegionTerrain.meta().get("routes", [])
	assert(routes.size() >= 21, "The generator checked the routes (%d)." % routes.size())
	for route in routes:
		assert(bool(route.ok), "A rover can drive from %s to %s." % [route.from, route.to])
	# And the game's planner finds the way up the west mesa's ramp from the plains.
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	var top := Vector2(-2050.0, 1650.0) - origin
	var path := ROUTE.plan(Vector2.ZERO, top, func(_p: Vector2) -> bool: return false, [], 400.0)
	assert(path.size() > 1, "The planner finds a way to the west mesa top.")
	var prev := Vector2.ZERO
	var worst := 0.0
	for point in path:
		for k in range(1, 11):
			var a := prev.lerp(point, (k - 1) / 10.0)
			var b := prev.lerp(point, k / 10.0)
			worst = maxf(worst, absf(MHSiteTerrain.height(b.x, b.y) - MHSiteTerrain.height(a.x, a.y)) / maxf(a.distance_to(b), .01))
		prev = point
	assert(worst < ROUTE.CLIFF, "Its route never meets a cliff (worst grade %.2f)." % worst)
	print("Region terrain test passed: level pads, sane ground, geology (%d units), rocks off the pads, %d rover routes, a planned way up the mesa ramp (worst grade %.2f)." % [units.size(), routes.size(), worst])
	quit(0)
