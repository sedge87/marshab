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

## A zone for a base founded at (rx, rz): the pad's level is the mean ground
## height over it.
static func make(rx: float, rz: float, label: String, half := 60.0) -> Dictionary:
	return {"centre": [rx, rz], "height": _mean_height(rx, rz, half), "pad_half": half, "label": label, "dynamic": true}

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
