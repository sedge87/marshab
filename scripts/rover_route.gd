extends RefCounted

## A way home for the crew rover over real ground (scripts/crew_rover.gd's
## recall): Godot's A* on a 10 m grid laid over the terrain between the
## rover and home, avoiding
## cliffs, big rocks and the habitat itself, and keeping to gentle ground. The
## result is a list of waypoints (site x, z), simplified to where the route
## turns; empty when there's no way through. Steep ground isn't ruled out
## (a crater rim may have no gentle way over it), only made dear: the route
## goes the long way round to keep to gentle slopes when there is one.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CELL := 10.0
const MARGIN := 300.0       # how far beyond the straight line the route may stray
const STEEP := .36          # rise over run, about 20 degrees: past it, ground costs a lot more to cross
const CLIFF := .8           # about 40 degrees: never
const BIG_ROCK := .8        # rock radius (m) the rover can't drive over (0.45 m clearance)

## `blocked`: a Callable(Vector2) -> bool for ground that isn't terrain's
## to judge (the habitat's rooms). `rocks`: Vector4(x, y, z, radius).
static func plan(from: Vector2, to: Vector2, blocked: Callable, rocks: Array = [], margin := MARGIN) -> PackedVector2Array:
	var area := Rect2(from, Vector2.ZERO).expand(to).grow(margin)
	var origin := area.position
	var size := Vector2i(ceili(area.size.x / CELL) + 1, ceili(area.size.y / CELL) + 1)
	# Heights at the grid's points, sampled once.
	var heights := PackedFloat32Array()
	heights.resize(size.x * size.y)
	for gz in size.y:
		for gx in size.x:
			heights[gz * size.x + gx] = MHSiteTerrain.height(origin.x + gx * CELL, origin.y + gz * CELL)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	var rocky := {}
	for rock in rocks:
		if (rock as Vector4).w < BIG_ROCK: continue
		rocky[Vector2i(roundi((rock.x - origin.x) / CELL), roundi((rock.z - origin.y) / CELL))] = true
	var start := _cell(from, origin, size)
	var goal := _cell(to, origin, size)
	for gz in size.y:
		for gx in size.x:
			var here := heights[gz * size.x + gx]
			var grade := 0.0
			if gx + 1 < size.x: grade = maxf(grade, absf(heights[gz * size.x + gx + 1] - here) / CELL)
			if gx > 0: grade = maxf(grade, absf(heights[gz * size.x + gx - 1] - here) / CELL)
			if gz + 1 < size.y: grade = maxf(grade, absf(heights[(gz + 1) * size.x + gx] - here) / CELL)
			if gz > 0: grade = maxf(grade, absf(heights[(gz - 1) * size.x + gx] - here) / CELL)
			var cell := Vector2i(gx, gz)
			# Near either end it may always go: it's sitting there already,
			# and the bay's approach is right beside the habitat.
			var ends := cell.distance_to(start) <= 1.5 or cell.distance_to(goal) <= 1.5
			var point := origin + Vector2(cell) * CELL
			if not ends and (grade > CLIFF or rocky.has(cell) or blocked.call(point)):
				grid.set_point_solid(cell)
			else:
				grid.set_point_weight_scale(cell, 1.0 + 4.0 * minf(grade / STEEP, 1.0) + (40.0 * (grade - STEEP) / STEEP if grade > STEEP else 0.0))
	var path := grid.get_id_path(start, goal)
	if path.is_empty(): return PackedVector2Array()
	# Keep only where it turns, and finish exactly at `to`.
	var route := PackedVector2Array()
	for index in range(1, path.size() - 1):
		if path[index] - path[index - 1] != path[index + 1] - path[index]: route.append(origin + Vector2(path[index]) * CELL)
	route.append(to)
	return route

static func _cell(point: Vector2, origin: Vector2, size: Vector2i) -> Vector2i:
	return Vector2i(clampi(roundi((point.x - origin.x) / CELL), 0, size.x - 1), clampi(roundi((point.y - origin.y) / CELL), 0, size.y - 1))
