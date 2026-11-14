class_name MHBases
extends RefCounted

## Several bases (A4, 14 Nov 2026; docs/bases-and-vehicles.md "Bases").
## One walker, one base. Each base is a record on the builder
## (builder.bases, id -> record), keyed by its walker's id ("w1" is Walker 1),
## so a core keeps its id, and its fitted upgrades (MHRoomTypes.fitted), when
## it's refolded and walked somewhere new.
## - Every zone belongs to one base ("base") and stands at its own floor
##   height ("y"). The first piece of a base (its core) sets the base's
##   height; the rest follow the ground.
## - Rooms that touch share a level: they share a wall. A step of up to one
##   storey goes through a straight corridor, which ramps ("rise": its two
##   ends' floors) or, when it's short for the climb, is a steep ship's
##   ladder you walk up.
## - You build within REACH of a base's centre. Walker 1's base, by the
##   lander, keeps the landing pad's surveyed area (MHSiteTerrain).
## - Everything is kept in one shared store (MHChapterOne.stock and its
##   feedstock), so a base never has its own materials.
## - The main base is the one with the crew's landing pad (builder.main_base).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const FIRST := "w1"
const CELL := 3.0
const REACH := 60.0          # metres each way from a base's centre you can build
const APART := 150.0         # metres between bases' centres, so their areas never meet
const STOREY := 3.0          # a room sits at most this far above or below the room it joins
const RAMP_RISE := 1.1       # metres a 3 m corridor cell climbs as a ramp; more is a ship's ladder
const SAME := .05            # floors this close are one level
const ABOVE := .12           # the ground may rise this far above a floor (under its skirt) ...
const BELOW := 1.85          # ... or fall this far below it (supports bridge the gap)
const MACHINES := ["solar", "reactor", "ice_extractor", "regolith_intake", "atmosphere_processor"]

static func record(id: String, label: String, centre: Vector2, y: float) -> Dictionary:
	return {"id": id, "name": label, "centre": centre, "y": y, "landing": centre.length() < 1.0}

## Walker n's base is "Base n".
static func label_for(id: String) -> String:
	return "Base %s" % id.trim_prefix("w") if id.begins_with("w") else id.capitalize()

## The first base, by the lander, is always there (Creative, older saves).
static func ensure(builder: Object) -> void:
	var all: Dictionary = builder.get("bases")
	if not all.has(FIRST): all[FIRST] = record(FIRST, label_for(FIRST), Vector2.ZERO, float(builder.get("habitat_base_y")))

static func base_of(zone: Dictionary) -> String:
	return str(zone.get("base", FIRST))

static func centre(builder: Object, id: String) -> Vector2:
	return (builder.get("bases") as Dictionary).get(id, {}).get("centre", Vector2.ZERO)

static func base_y(builder: Object, id: String) -> float:
	return float((builder.get("bases") as Dictionary).get(id, {}).get("y", .35))

## A zone's floor (the lower end, for a corridor that climbs).
static func zone_y(builder: Object, zone: Dictionary) -> float:
	if zone.has("y"): return float(zone.y)
	return base_y(builder, base_of(zone))

static func is_room(zone: Dictionary) -> bool:
	return not zone.is_empty() and not str(zone.get("kind", "")) in MACHINES and str(zone.get("kind", "")) != "landing_pad"

## A base's zones (rooms only, unless machines too).
static func zones_of(builder: Object, id: String, machines := false) -> Array:
	return (builder.get("zones") as Array).filter(func(z): return base_of(z) == id and (machines or is_room(z)))

## Whether a point (site metres) is in a base's build area.
static func in_area(builder: Object, id: String, point: Vector2) -> bool:
	var base: Dictionary = (builder.get("bases") as Dictionary).get(id, {})
	if base.is_empty() or not (base.get("centre", Vector2.INF) is Vector2) or is_inf((base.centre as Vector2).x): return false
	if bool(base.get("landing", false)): return MHSiteTerrain.is_buildable(point)
	var off: Vector2 = point - (base.centre as Vector2)
	return absf(off.x) <= REACH + .01 and absf(off.y) <= REACH + .01

## The base whose build area holds the point, or "".
static func at(builder: Object, point: Vector2) -> String:
	for id in builder.get("bases"):
		if in_area(builder, str(id), point): return str(id)
	return ""

## The base nearest a point (its centre), or FIRST.
static func nearest(builder: Object, point: Vector2) -> String:
	var best := FIRST
	var best_d := INF
	for id in builder.get("bases"):
		var c = (builder.get("bases") as Dictionary)[id].get("centre", Vector2.INF)
		if not (c is Vector2) or is_inf((c as Vector2).x): continue
		var d := point.distance_to(c)
		if d < best_d: best_d = d; best = str(id)
	return best

## Why a cell can't carry habitat ("" when it can): inside the active base's
## build area, on ground the region allows.
static func cell_reason(builder: Object, cell: Vector2i) -> String:
	var id := str(builder.get("active_base"))
	var half := CELL * .5
	for offset in [Vector2.ZERO, Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]:
		var p: Vector2 = Vector2(cell.x * CELL, cell.y * CELL) + offset
		if in_area(builder, id, p): continue
		var base: Dictionary = (builder.get("bases") as Dictionary).get(id, {})
		if bool(base.get("landing", false)):
			var site := MHSiteTerrain.unbuildable_reason(p)
			return site if not site.is_empty() else "Outside the surveyed build area"
		return "Too far from the base's core: build within %d m of it" % roundi(REACH)
	return ""

## Where you are: the floor of the room at a point, else the nearest base's.
static func floor_at(builder: Object, point: Vector2) -> float:
	var zone: Dictionary = builder.call("_zone_at_point", point)
	if is_room(zone):
		if zone.has("rise"): return corridor_point_y(builder, zone, point)
		return zone_y(builder, zone)
	return base_y(builder, nearest(builder, point))

# ---------- levels ----------

## The ground under a cell against a floor: "" or why it doesn't fit.
static func ground_reason(builder: Object, cell: Vector2i, y: float) -> String:
	var terrain := float(builder.call("_cell_highest_terrain", cell))
	if terrain > y + ABOVE: return "Ground is too high here"
	if terrain < y - BELOW: return "Ground drops away too far"
	return ""

## The rooms that share an edge with these cells (same base), with the floor
## at the shared face: [[zone, y], ...].
static func touching(builder: Object, cells: Array, skip: Dictionary = {}) -> Array:
	var out: Array = []
	for zone in builder.get("zones"):
		if is_same(zone, skip) or not is_room(zone) or zone.has("outline") or zone.has("angled_mount") or bool(zone.get("roof", false)): continue
		for cell in cells:
			var hit := false
			for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if (zone.get("cells", []) as Array).has(cell + side):
					out.append([zone, corridor_cell_y(builder, zone, cell + side) if zone.has("rise") else zone_y(builder, zone)])
					hit = true
					break
			if hit: break
	return out

## The floor a new room on these cells stands at: {"y": float, "reason": ""}.
## Touching rooms decide it; a base's first piece takes its own ground; a room
## on its own takes the nearest existing level the ground allows, or its own.
static func level_for(builder: Object, cells: Array, kind: String, skip: Dictionary = {}) -> Dictionary:
	if cells.is_empty(): return {"y": float(builder.get("habitat_base_y")), "reason": ""}
	var own := float(builder.call("_proposed_base_y", cells))
	if kind in MACHINES or kind == "landing_pad": return {"y": own, "reason": ""}
	if kind == "corridor": return corridor_levels(builder, cells, skip)
	var levels: Array = []
	for hit in touching(builder, cells, skip):
		var y := float(hit[1])
		if not levels.any(func(l): return absf(float(l) - y) < SAME): levels.append(y)
	if levels.size() > 1: return {"y": own, "reason": "That would join rooms on different levels: link them with a corridor"}
	if levels.size() == 1:
		return {"y": float(levels[0]), "reason": _ground(builder, cells, float(levels[0]))}
	var id := base_for_cells(builder, cells)
	var mine := zones_of(builder, id).filter(func(z): return not is_same(z, skip))
	if mine.is_empty(): return {"y": own, "reason": _ground(builder, cells, own)}
	# Line up with a level already in the base where the ground lets it.
	var known: Array = []
	for zone in mine:
		var y := zone_y(builder, zone)
		if not known.any(func(l): return absf(float(l) - y) < SAME): known.append(y)
	known.sort_custom(func(a, b): return absf(float(a) - own) < absf(float(b) - own))
	for y in known:
		if absf(float(y) - own) <= STOREY and _ground(builder, cells, float(y)).is_empty(): return {"y": float(y), "reason": ""}
	return {"y": own, "reason": _ground(builder, cells, own)}

static func _ground(builder: Object, cells: Array, y: float) -> String:
	for cell in cells:
		var why := ground_reason(builder, cell, y)
		if not why.is_empty(): return why
	return ""

## The base a set of cells is in (the active one when it's ambiguous).
static func base_for_cells(builder: Object, cells: Array) -> String:
	if cells.is_empty(): return str(builder.get("active_base"))
	var id := at(builder, Vector2(cells[0].x * CELL, cells[0].y * CELL))
	return id if not id.is_empty() else str(builder.get("active_base"))

## A corridor's floors: flat at the level of whatever it meets, or, joining
## two rooms on different levels, climbing from one to the other:
## {"y": lower end, "rise": [first cell's end, last cell's end] or [], "reason"}.
## Cells are in path order (the corridor tool draws them so).
static func corridor_levels(builder: Object, cells: Array, skip: Dictionary = {}) -> Dictionary:
	var own := float(builder.call("_proposed_base_y", cells))
	var first := touching(builder, [cells[0]], skip)
	var last := touching(builder, [cells[cells.size() - 1]], skip) if cells.size() > 1 else []
	var a := float(first[0][1]) if not first.is_empty() else INF
	var b := float(last[0][1]) if not last.is_empty() else INF
	# A one-cell corridor between two rooms: one on each side.
	if cells.size() == 1 and first.size() > 1:
		b = float(first[1][1])
		for hit in first:
			if absf(float(hit[1]) - a) > SAME: b = float(hit[1])
	if is_inf(a) and is_inf(b):
		var flat := level_for(builder, cells, "room", skip)
		return {"y": float(flat.y), "rise": [], "reason": str(flat.reason)}
	if is_inf(a): a = b
	if is_inf(b): b = a
	if absf(a - b) < SAME: return {"y": a, "rise": [], "reason": _ground(builder, cells, a)}
	if absf(a - b) > STOREY + SAME: return {"y": minf(a, b), "rise": [a, b], "reason": "More than a storey between them: a corridor climbs %d m at most" % roundi(STOREY)}
	if not _straight(cells): return {"y": minf(a, b), "rise": [a, b], "reason": "A corridor that climbs runs straight"}
	var zone := {"cells": cells, "rise": [a, b], "y": minf(a, b)}
	for cell in cells:
		var why := ground_reason(builder, cell, corridor_cell_y(builder, zone, cell))
		if not why.is_empty(): return {"y": minf(a, b), "rise": [a, b], "reason": why}
	return {"y": minf(a, b), "rise": [a, b], "reason": ""}

static func _straight(cells: Array) -> bool:
	if cells.size() < 2: return true
	var xs := cells.all(func(c): return c.x == cells[0].x)
	var zs := cells.all(func(c): return c.y == cells[0].y)
	return xs or zs

## Whether a climbing corridor is a ramp (gentle enough) or a ship's ladder.
static func is_ramp(zone: Dictionary) -> bool:
	var rise: Array = zone.get("rise", [])
	if rise.size() != 2: return true
	return absf(float(rise[1]) - float(rise[0])) / maxf(1.0, float((zone.get("cells", []) as Array).size())) <= RAMP_RISE

## The floor at a climbing corridor's cell centre (its ends are the rooms').
static func corridor_cell_y(builder: Object, zone: Dictionary, cell: Vector2i) -> float:
	var rise: Array = zone.get("rise", [])
	if rise.size() != 2: return zone_y(builder, zone)
	var cells: Array = zone.get("cells", [])
	var n := cells.size()
	var i := cells.find(cell)
	if i < 0 or n == 0: return zone_y(builder, zone)
	# The end cells meet their rooms at the rooms' floor.
	if i == 0: return float(rise[0])
	if i == n - 1: return float(rise[1])
	return lerpf(float(rise[0]), float(rise[1]), (float(i) + .5) / float(n))

## The floor at a point along a climbing corridor (where you stand on it).
static func corridor_point_y(_builder: Object, zone: Dictionary, point: Vector2) -> float:
	var ends := corridor_ends(zone)
	var rise: Array = zone.rise
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var t := clampf((point - a).dot(b - a) / maxf(.001, a.distance_squared_to(b)), 0.0, 1.0)
	return lerpf(float(rise[0]), float(rise[1]), t)

## The two end faces of a straight corridor, site metres (first cell's, last's).
static func corridor_ends(zone: Dictionary) -> Array:
	var cells: Array = zone.get("cells", [])
	var a := Vector2(cells[0].x, cells[0].y) * CELL
	var b := Vector2(cells[cells.size() - 1].x, cells[cells.size() - 1].y) * CELL
	var along := (b - a).normalized() if cells.size() > 1 else Vector2(zone.get("door_direction", Vector2i(0, -1))).normalized()
	if along.length() < .5: along = Vector2(0, -1)
	return [a - along * CELL * .5, b + along * CELL * .5]

## Every zone gets its base and floor: older saves, and pieces just placed.
static func settle(builder: Object) -> void:
	ensure(builder)
	for zone in builder.get("zones"):
		if not zone.has("base"):
			var p := _zone_point(builder, zone)
			var id := at(builder, p) if not is_inf(p.x) else ""
			zone["base"] = id if not id.is_empty() else str(builder.get("active_base"))
		if zone.has("y") or not is_room(zone): continue
		if zone.has("angled_mount"):
			var mount: Dictionary = zone.angled_mount
			var host: Dictionary = builder.call("_zone_at_point", (mount.get("position", Vector2.ZERO) as Vector2) - (mount.get("outward", Vector2.UP) as Vector2) * .6)
			zone["y"] = zone_y(builder, host) if not host.is_empty() else base_y(builder, base_of(zone))
			continue
		var level := level_for(builder, zone.get("cells", []), str(zone.kind), zone)
		zone["y"] = float(level.y)
		if (level.get("rise", []) as Array).size() == 2: zone["rise"] = level.rise
	# Each base stands at its core's height (its first room's, without one).
	for id in builder.get("bases"):
		var mine := zones_of(builder, str(id))
		if mine.is_empty(): continue
		var core := mine.filter(func(z): return bool(z.get("carried", false)) or str(z.kind) == "general")
		(builder.get("bases") as Dictionary)[id]["y"] = zone_y(builder, core[0] if not core.is_empty() else mine[0])

static func _zone_point(builder: Object, zone: Dictionary) -> Vector2:
	if zone.has("at"): return zone.at
	if zone.has("angled_mount"): return (zone.angled_mount as Dictionary).get("position", Vector2.ZERO)
	var cells: Array = zone.get("cells", [])
	if cells.is_empty():
		var outline: PackedVector2Array = builder.call("zone_outline", zone)
		return outline[0] if not outline.is_empty() else Vector2.INF
	return Vector2(cells[0].x * CELL, cells[0].y * CELL)

## The floor range a zone's space covers (for "inside"): [low, high].
static func span(builder: Object, zone: Dictionary) -> Vector2:
	var rise: Array = zone.get("rise", [])
	if rise.size() == 2: return Vector2(minf(float(rise[0]), float(rise[1])), maxf(float(rise[0]), float(rise[1])))
	var y := zone_y(builder, zone)
	return Vector2(y, y)

# ---------- saves ----------

static func export_state(builder: Object) -> Dictionary:
	var out := {}
	var all: Dictionary = builder.get("bases")
	for id in all:
		var b: Dictionary = (all[id] as Dictionary).duplicate(true)
		var c = b.get("centre", Vector2.INF)
		b["centre"] = [] if not (c is Vector2) or is_inf((c as Vector2).x) else [(c as Vector2).x, (c as Vector2).y]
		out[id] = b
	return out

static func load_state(builder: Object, saved: Dictionary) -> void:
	var all: Dictionary = builder.get("bases")
	all.clear()
	for id in saved:
		var b: Dictionary = (saved[id] as Dictionary).duplicate(true)
		var c: Array = b.get("centre", [])
		b["centre"] = Vector2(float(c[0]), float(c[1])) if c.size() == 2 else Vector2.INF
		all[id] = b
	ensure(builder)
