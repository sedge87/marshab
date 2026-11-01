class_name MHBaseSite
extends RefCounted

## Where the main base can be founded (docs/landing-and-base-siting.md §4).
## The base is founded where the lander touches down: the game writes a
## zone for that spot (make) in the shape of region.json's zones, with
## "dynamic" set, and MHSiteTerrain.region_zone() returns it. The pad is
## levelled round it at load: MHSiteTerrain's heights through pad_height,
## Terrain3D's through the same function.
## Everything here is in region metres (as generated), not site metres.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const ROUTE := preload("res://scripts/rover_route.gd")
const GRID := 10.0          # metres between the points checked (the route planner's cell)
const FOOTPRINT := 2.0      # slopes measured across this, as the Rover ground view does
const MAX_ROUGH := .1       # of the points: steeper than STEEP (the pad levels small bumps)
const MAX_TILT := .16       # the ground's overall slope across the pad (about 9 degrees)
const MAX_BUMP := 5.0       # metres the ground rises or dips from that slope
const CAVE_CLEAR := 20.0    # metres between the pad and any cave or skylight
const EDGE_CLEAR := 400.0   # metres inside the region's edge
const APRON := .6           # the pad blends back to the ground over this × its half width
const ICE_REACH := 450.0    # metres round the base its ice deposits are looked for

const HORIZON_SIDES := 16      # compass directions the skyline is measured in
const HORIZON_REACH := 2000.0  # metres out the skyline is looked for
const SHELTER_PER_DEGREE := .45   # °C warmer nights per degree of skyline (walls give back the day's heat)
const SHELTER_MAX := 8.0
const DUNE_REACH := 800.0      # metres round the base dunes blow sand from
const ROOM_REACH := 200.0      # metres round the base counted as room to grow

## A zone for a base founded at (rx, rz): the pad's level is the mean ground
## height over it.
static func make(rx: float, rz: float, label: String, half := 60.0) -> Dictionary:
	return {"centre": [rx, rz], "height": _mean_height(rx, rz, half), "pad_half": half, "label": label, "dynamic": true,
		"ice_deposits": ice_deposits(rx, rz), "conditions": conditions(rx, rz)}

## What living at (rx, rz) is like, from the ground round it
## (docs/landing-and-base-siting.md §10): the trade-offs of the landing spot.
##   horizon: the skyline's height in degrees, HORIZON_SIDES directions from
##     east through south (+Z), as MHGame.sun_heading; walls hide a low sun.
##   shelter_c: how much warmer the nights are between walls.
##   dunes: the share of the ground within DUNE_REACH that's dune sand.
##   dust_per_sol: how fast dust settles on solar panels.
##   ice: the share of the ground within ICE_REACH that's ice mantle.
##   frost_peak: how thick the dawn frost gets (0–1).
##   room: the share of the ground within ROOM_REACH that's open and gentle.
static func conditions(rx: float, rz: float) -> Dictionary:
	var RT = MHSiteTerrain.RegionTerrain
	var eye: float = RT.height(rx, rz) + 2.0
	var horizon: Array = []
	for k in HORIZON_SIDES:
		var heading := Vector2.from_angle(TAU * k / HORIZON_SIDES)
		var highest := 0.0
		var d := 40.0
		while d <= HORIZON_REACH:
			highest = maxf(highest, rad_to_deg(atan2(RT.height(rx + heading.x * d, rz + heading.y * d) - eye, d)))
			d *= 1.12
		horizon.append(snappedf(highest, .1))
	var skyline := 0.0
	for angle in horizon: skyline += float(angle)
	skyline /= HORIZON_SIDES
	var dunes := _share(rx, rz, DUNE_REACH, 50.0, func(x: float, z: float) -> bool: return RT.geology(x, z) == "dune_sand")
	var ice := _share(rx, rz, ICE_REACH, 30.0, func(x: float, z: float) -> bool: return RT.geology(x, z) == "ice_mantle")
	var room := _share(rx, rz, ROOM_REACH, 20.0, func(x: float, z: float) -> bool:
		return _grade(x, z) < ROUTE.STEEP and RT.geology(x, z) != "dune_sand")
	# Open ground takes the wind's dust; dunes upwind take more.
	var dust := .012 + dunes * .06 + clampf(1.0 - skyline / 6.0, 0.0, 1.0) * .008
	# Frost forms where there's ice in the ground, and lasts in the shade.
	var frost := clampf(.1 + ice * .9 + clampf(skyline / 20.0, 0.0, 1.0) * .2, 0.0, 1.0)
	return {"horizon": horizon, "skyline": snappedf(skyline, .1), "shelter_c": snappedf(minf(SHELTER_MAX, skyline * SHELTER_PER_DEGREE), .1),
		"dunes": snappedf(dunes, .01), "dust_per_sol": snappedf(dust, .001), "ice": snappedf(ice, .01), "frost_peak": snappedf(frost, .01), "room": snappedf(room, .01)}

const SCIENCE_REACH := 800.0   # metres round the base its rocks are counted (a walk)
const CAVE_REACH := 1500.0     # metres to a cave mouth that counts as nearby (a drive)

## What there is to study round a base at (rx, rz) (step 5): the kinds of
## rock within SCIENCE_REACH, from the geology units there and
## data/discoveries.json's unit_rocks, and the nearest cave mouth.
## {rocks: [rock types], units: [units], cave: name, cave_m: metres (INF if none)}
static func science(rx: float, rz: float) -> Dictionary:
	var RT = MHSiteTerrain.RegionTerrain
	var by_unit: Dictionary = MHSamples.data().get("unit_rocks", {})
	var units := {}
	var rocks := {}
	var step := 60.0
	for i in range(-roundi(SCIENCE_REACH / step), roundi(SCIENCE_REACH / step) + 1):
		for j in range(-roundi(SCIENCE_REACH / step), roundi(SCIENCE_REACH / step) + 1):
			if Vector2(i, j).length() * step > SCIENCE_REACH: continue
			var unit: String = RT.geology(rx + i * step, rz + j * step)
			if unit.is_empty() or units.has(unit): continue
			units[unit] = true
			var weights: Dictionary = by_unit.get(unit, {})
			for rock in weights:
				if float(weights[rock]) >= 1.0: rocks[rock] = true
	var cave := ""
	var cave_m := INF
	for entry in RT.meta().get("caves", []):
		var mouth: Array = entry.points[0]
		var gap := Vector2(float(mouth[0]) - rx, float(mouth[1]) - rz).length()
		if gap < cave_m: cave_m = gap; cave = str(entry.get("name", "a cave"))
	return {"rocks": rocks.keys(), "units": units.keys(), "cave": cave, "cave_m": cave_m}

## The skyline's height (degrees) towards heading, from a conditions horizon.
static func skyline_towards(horizon: Array, heading: Vector2) -> float:
	var at := fposmod(heading.angle(), TAU) / TAU * horizon.size()
	var k := floori(at)
	return lerpf(float(horizon[k % horizon.size()]), float(horizon[(k + 1) % horizon.size()]), at - k)

## How much of a sol's sunshine reaches a base under this skyline (the same
## sun as MHGame.solar_irradiance): {share (of open ground's), hidden_hours
## (game hours of daylight the sun is behind the skyline)}.
static func sunshine(horizon: Array) -> Dictionary:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var open := 0.0
	var seen := 0.0
	var hidden := 0
	for i in 96:
		var hour := lerpf(sunrise, sunset, (i + .5) / 96.0)
		var altitude := MHGame.sun_altitude(hour)
		var skyline := deg_to_rad(skyline_towards(horizon, MHGame.sun_heading(hour)))
		open += sin(altitude)
		seen += sin(altitude) * smoothstep(skyline, skyline + deg_to_rad(6.0), altitude)
		if altitude < skyline: hidden += 1
	return {"share": seen / maxf(.0001, open), "hidden_hours": hidden * (sunset - sunrise) / 96.0}

## The share of grid points within reach of (rx, rz) where test holds.
static func _share(rx: float, rz: float, reach: float, step: float, test: Callable) -> float:
	var hits := 0
	var count := 0
	for i in range(-roundi(reach / step), roundi(reach / step) + 1):
		for j in range(-roundi(reach / step), roundi(reach / step) + 1):
			var at := Vector2(i, j) * step
			if at.length() > reach: continue
			count += 1
			if test.call(rx + at.x, rz + at.y): hits += 1
	return float(hits) / maxf(1.0, count)

## Buried ice round a base founded at (rx, rz), in the shape of
## data/sites.json's ice_deposits (site metres): up to three deposits within
## ICE_REACH, at least 60 m apart, nearest first. Rich in the region's ice
## mantle; some in the old lake and river sediments, whose pores hold ice;
## otherwise one thin deposit near the pad (there's a little ground ice
## almost everywhere at these latitudes).
const ICE_UNITS := {"ice_mantle": [.45, .92], "crater_lakebed": [.36, .55], "delta_clays": [.36, .55], "valley_conglomerate": [.34, .5]}

static func ice_deposits(rx: float, rz: float) -> Array:
	var RT = MHSiteTerrain.RegionTerrain
	var cells: Array = []   # [offset, unit]
	var step := 30.0
	for i in range(-roundi(ICE_REACH / step), roundi(ICE_REACH / step) + 1):
		for j in range(-roundi(ICE_REACH / step), roundi(ICE_REACH / step) + 1):
			var at := Vector2(i, j) * step
			if at.length() > ICE_REACH: continue
			var unit: String = RT.geology(rx + at.x, rz + at.y)
			if ICE_UNITS.has(unit): cells.append([at, unit])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).length() < (b[0] as Vector2).length())
	var deposits: Array = []
	for cell: Array in cells:
		var at: Vector2 = cell[0]
		if deposits.any(func(d): return Vector2(float(d.x), float(d.z)).distance_to(at) < 60.0): continue
		# Richer where more of the ground round it is the same.
		var around := cells.filter(func(c: Array) -> bool: return c[1] == cell[1] and (c[0] as Vector2).distance_to(at) < 50.0).size()
		var span: Array = ICE_UNITS[cell[1]]
		deposits.append({"x": roundf(at.x), "z": roundf(at.y), "radius": 20, "richness": snappedf(clampf(float(span[0]) + around * .05, span[0], span[1]), .01)})
		if deposits.size() == 3: break
	if deposits.is_empty(): deposits.append({"x": 45, "z": -42, "radius": 13, "richness": .25})
	return deposits

## Whether a base can be founded at (rx, rz).
static func valid(rx: float, rz: float, half := 60.0) -> bool:
	return reason(rx, rz, half).is_empty()

## Empty when a base can be founded at (rx, rz); otherwise why not, in a
## word or two ("too steep", "too rough", "boulders", "dune sand", "a cave",
## "too uneven", "the region's edge").
static func reason(rx: float, rz: float, half := 60.0) -> String:
	var RT = MHSiteTerrain.RegionTerrain
	var region_half := float(RT.meta().get("half", 0.0))
	if absf(rx) > region_half - EDGE_CLEAR or absf(rz) > region_half - EDGE_CLEAR: return "the region's edge"
	if _near_cave(rx, rz, half): return "a cave"
	# The pad levels the ground under it, so what counts is the ground as a
	# whole: no cliff, a gentle overall slope, not too many steep patches,
	# and no big hump or hollow on that slope.
	var level := _mean_height(rx, rz, half)
	var rough := 0
	var count := 0
	var slope := Vector2.ZERO   # least-squares tilt of the ground across the pad
	var spread := 0.0
	var samples: Array[Vector3] = []
	var steps := ceili(half / GRID)
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			var dx := clampf(i * GRID, -half, half)
			var dz := clampf(j * GRID, -half, half)
			var x := rx + dx
			var z := rz + dz
			count += 1
			if RT.geology(x, z) == "dune_sand": return "dune sand"
			var rocks: Vector2 = RT.rock_density(x, z)
			if rocks.x > .65 and rocks.y > .6: return "boulders"
			var grade := _grade(x, z)
			if grade > ROUTE.CLIFF: return "too steep"
			if grade > ROUTE.STEEP: rough += 1
			var h: float = RT.height(x, z) - level
			samples.append(Vector3(dx, h, dz))
			slope += Vector2(dx, dz) * h
			spread += dx * dx
	var tilt := slope / spread if spread > 0.0 else Vector2.ZERO
	if tilt.length() > MAX_TILT: return "too steep"
	for at in samples:
		if absf(at.y - tilt.dot(Vector2(at.x, at.z))) > MAX_BUMP: return "too uneven"
	if rough > count * MAX_ROUGH: return "too rough"
	return ""

## The nearest point to (rx, rz), within reach metres, where a base can be
## founded (a spiral out on the grid); INF when there's none.
static func nearest_valid(rx: float, rz: float, reach := 300.0, half := 60.0) -> Vector2:
	if valid(rx, rz, half): return Vector2(rx, rz)
	var best := Vector2.INF
	var ring := GRID
	while ring <= reach:
		var around := maxi(8, roundi(TAU * ring / GRID))
		for k in around:
			var p := Vector2(rx, rz) + Vector2.from_angle(TAU * k / around) * ring
			if valid(p.x, p.y, half) and (is_inf(best.x) or p.distance_to(Vector2(rx, rz)) < best.distance_to(Vector2(rx, rz))): best = p
		if not is_inf(best.x): return best
		ring += GRID
	return best

## The ground round a dynamic zone's pad (site metres, relative to its
## level): level on the pad, blending back to the natural ground over the
## apron. natural is the ground there before levelling, relative to the pad.
static func pad_height(zone: Dictionary, p: Vector2, natural: float) -> float:
	var half := float(zone.get("pad_half", 60.0)) + MHSiteTerrain.PAD_MARGIN
	var outside := Vector2(maxf(0.0, absf(p.x) - half), maxf(0.0, absf(p.y) - half)).length()
	var apron := half * APRON
	if outside >= apron: return natural
	return natural * smoothstep(0.0, 1.0, outside / apron)

## How far the pad's levelling reaches from its centre (site metres).
static func pad_reach(zone: Dictionary) -> float:
	return (float(zone.get("pad_half", 60.0)) + MHSiteTerrain.PAD_MARGIN) * (1.0 + APRON)

static func _mean_height(rx: float, rz: float, half: float) -> float:
	var RT = MHSiteTerrain.RegionTerrain
	var total := 0.0
	var count := 0
	var steps := ceili(half / GRID)
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			total += RT.height(rx + clampf(i * GRID, -half, half), rz + clampf(j * GRID, -half, half))
			count += 1
	return total / count

static func _grade(x: float, z: float) -> float:
	var RT = MHSiteTerrain.RegionTerrain
	var e := FOOTPRINT
	return maxf(absf(RT.height(x + e, z) - RT.height(x - e, z)), absf(RT.height(x, z + e) - RT.height(x, z - e))) / (2.0 * e)

## Whether the pad (a square of half width half round (rx, rz)) comes within
## CAVE_CLEAR of a cave's tunnel or skylight.
static func _near_cave(rx: float, rz: float, half: float) -> bool:
	for cave in MHSiteTerrain.RegionTerrain.meta().get("caves", []):
		var reach := half + CAVE_CLEAR + float(cave.get("half_width", 3.0))
		for p in cave.get("points", []):
			if absf(float(p[0]) - rx) < reach and absf(float(p[1]) - rz) < reach: return true
		for sky in cave.get("skylights", []):
			var at: Array = sky.position
			if absf(float(at[0]) - rx) < half + CAVE_CLEAR + float(sky.radius) and absf(float(at[1]) - rz) < half + CAVE_CLEAR + float(sky.radius): return true
	return false
