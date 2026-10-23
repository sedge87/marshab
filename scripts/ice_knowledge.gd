extends RefCounted

## What the colony knows about the buried ice (G3, 24 Oct). From orbit you
## only get a rough idea: radar like SHARAD (Mars Reconnaissance Orbiter) and
## MARSIS (Mars Express) shows broad zones where ice is likely, not exactly
## where it's richest. GAR-Y's surveys fill in the detail: every spot it
## checks is recorded with the ice it measured there, and those are what the
## maps, the site plan's ice overlay and the mission compass show.
## The real deposits stay in data/sites.json (and decide what drills make).

## How much bigger a likely zone is than the deposit inside it, and how far
## off-centre it can sit (as a share of the deposit's radius).
const ZONE_GROWTH := 1.8
const ZONE_SHIFT := .45
## The ground one survey reveals around itself (metres).
const SAMPLE_REACH := 5.0
## Worth flagging and drilling.
const WORTH_DRILLING := .25

## The likely zones from orbit: [{centre: Vector2, radius: float}], the same
## every time for a site.
static func likely_zones(site := {}) -> Array:
	if site.is_empty(): site = MHGame.site()
	var zones: Array = []
	var deposits: Array = site.get("ice_deposits", [])
	for index in range(deposits.size()):
		var deposit: Dictionary = deposits[index]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s/%d" % [str(site.get("id", "site")), index])
		var radius := float(deposit.get("radius", 10.0))
		var shift := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(ZONE_SHIFT * .5, ZONE_SHIFT)
		zones.append({"centre": Vector2(float(deposit.get("x", 0.0)), float(deposit.get("z", 0.0))) + shift, "radius": radius * ZONE_GROWTH})
	return zones

## Every spot GAR-Y has surveyed: [Vector3(x, z, richness)].
static func samples(tree: SceneTree) -> Array:
	var rover := tree.get_first_node_in_group("gar_y")
	return (rover.get("ice_samples") as Array) if rover != null and rover.get("ice_samples") != null else []

## The richest surveyed spot ({at: Vector2, richness}), or {} if none yet.
static func best_found(tree: SceneTree) -> Dictionary:
	var best := {}
	for sample in samples(tree):
		if best.is_empty() or float(sample.z) > float(best.richness): best = {"at": Vector2(sample.x, sample.y), "richness": float(sample.z)}
	return best

## The likely zone nearest a point (for "Find ice"), or {}.
static func nearest_zone(from: Vector2, within := INF) -> Dictionary:
	var nearest := {}
	for zone in likely_zones():
		var gap := (zone.centre as Vector2).distance_to(from)
		if gap <= within and (nearest.is_empty() or gap < (nearest.centre as Vector2).distance_to(from)): nearest = zone
	return nearest

## Survey stops across a likely zone: its middle and a ring round it, in an
## order that makes a short drive from `from`.
static func survey_stops(zone: Dictionary, from: Vector2, ring := 6) -> Array:
	var points: Array = [zone.centre]
	for i in range(ring):
		points.append((zone.centre as Vector2) + Vector2.from_angle(TAU * i / ring) * float(zone.radius) * .5)
	var ordered: Array = []
	var at := from
	while not points.is_empty():
		var next: Vector2 = points[0]
		for p in points:
			if (p as Vector2).distance_to(at) < next.distance_to(at): next = p
		points.erase(next)
		ordered.append(next)
		at = next
	return ordered

## For the site plan's ice overlay (shaders/ice_survey.gdshader): the likely
## zones as a faint wash, and each surveyed spot as a disc of what it measured.
## Each entry is Vector4(x, z, radius, richness).
static func overlay(tree: SceneTree) -> PackedVector4Array:
	var packed := PackedVector4Array()
	for zone in likely_zones():
		packed.append(Vector4(zone.centre.x, zone.centre.y, float(zone.radius), -1.0))   # -1: "likely" (no measurement)
	for sample in samples(tree):
		packed.append(Vector4(sample.x, sample.y, SAMPLE_REACH, sample.z))
	return packed
