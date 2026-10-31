extends RefCounted

## Trenches: cut and cover (gameplay loop prototype, docs/gameplay-loop-brief.md
## §9a). A trench is dug into a region site's build pad: a rectangle of cells
## 3.4 m deep with retaining walls, a paved rim and a ramp up one side (R turns
## it while placing). Rooms built in it stand on its floor, and the base stays
## on one level: the builder's usual "ground too high / drops away" rules keep
## every room in the trench, or every room on top. Earth behind a trench
## room's outside wall shields it like regolith panels (habitat_sim.gd); Roof
## Shielding buries the roof.
##
## The ground under a trench is sunk below its floor and the trench is built
## from meshes with collision; MHSiteTerrain.height() reads the trench
## too, so building, GAR-Y and the rover all see it.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const DEPTH := 3.4        # floor below the pad: a room's floor and roof, roof level with the ground
const RAMP_LENGTH := 9.0  # about 21°, gentle enough for the rover
const RAMP_CELLS := 2     # ramp width in cells (or the trench's width, if narrower)
const RIM := 4.6          # graded apron round the top, over the sunken ground's slope
const SINK := 2.5         # ground sunk this far beyond the walls (the terrain's points are 2 m apart)
const WALL := .3          # retaining wall thickness
const CELL := 3.0
const MIN_CELLS := 2
const MAX_CELLS := 10

static var _cuts: Dictionary = {}   # Terrain3D point -> its height before the dig
static var _cuts_key := ""

# ---------- shape ----------

## The floor (world metres, x/z).
static func floor_rect(trench: Dictionary) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cell in trench.cells:
		lo = lo.min(Vector2(cell) * CELL)
		hi = hi.max(Vector2(cell) * CELL)
	return Rect2(lo - Vector2.ONE * CELL * .5, hi - lo + Vector2.ONE * CELL)

static func ramp_dir(trench: Dictionary) -> Vector2i:
	return trench.get("ramp", Vector2i(0, 1)) as Vector2i

## The ramp, from the floor's edge up to the surface.
static func ramp_rect(trench: Dictionary) -> Rect2:
	var r := floor_rect(trench)
	var d := ramp_dir(trench)
	var width := minf(r.size.x if d.x == 0 else r.size.y, RAMP_CELLS * CELL)
	var c := r.get_center()
	match d:
		Vector2i(0, 1): return Rect2(c.x - width * .5, r.end.y, width, RAMP_LENGTH)
		Vector2i(0, -1): return Rect2(c.x - width * .5, r.position.y - RAMP_LENGTH, width, RAMP_LENGTH)
		Vector2i(1, 0): return Rect2(r.end.x, c.y - width * .5, RAMP_LENGTH, width)
	return Rect2(r.position.x - RAMP_LENGTH, c.y - width * .5, RAMP_LENGTH, width)

## What MHSiteTerrain.height() needs for every trench.
static func areas(trenches: Array) -> Array:
	return trenches.map(func(t): return {"floor": floor_rect(t), "ramp": ramp_rect(t), "dir": ramp_dir(t), "depth": DEPTH})

## Cells a trench's ramp covers (nothing can be built on them).
static func ramp_cells(trench: Dictionary) -> Array:
	var ramp := ramp_rect(trench)
	var out: Array = []
	for x in range(floori(ramp.position.x / CELL) - 1, ceili(ramp.end.x / CELL) + 2):
		for z in range(floori(ramp.position.y / CELL) - 1, ceili(ramp.end.y / CELL) + 2):
			var square := Rect2(Vector2(x, z) * CELL - Vector2.ONE * CELL * .5, Vector2.ONE * CELL)
			if square.intersects(ramp) and square.intersection(ramp).get_area() > .5: out.append(Vector2i(x, z))
	return out

static func in_trench(trenches: Array, cell: Vector2i) -> bool:
	return trenches.any(func(t): return (t.cells as Array).has(cell))

## Outside wall bays of a trench room cell with earth behind them.
static func earth_sides(trenches: Array, cell: Vector2i) -> int:
	if not in_trench(trenches, cell): return 0
	var count := 0
	for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = cell + side
		if in_trench(trenches, next): continue
		if trenches.any(func(t): return ramp_cells(t).has(next)): continue
		count += 1
	return count

# ---------- placing ----------

## Empty when a trench can be dug over these cells with its ramp this way.
static func invalid_reason(builder: Node, cells: Array, dir: Vector2i) -> String:
	if MHSiteTerrain.shape() != "region": return "Trenches can only be dug on a region site for now"
	if cells.is_empty(): return "Drag out an area"
	var trench := {"cells": cells, "ramp": dir}
	var r := floor_rect(trench)
	var span := Vector2i(roundi(r.size.x / CELL), roundi(r.size.y / CELL))
	if span.x < MIN_CELLS or span.y < MIN_CELLS: return "At least %d × %d cells" % [MIN_CELLS, MIN_CELLS]
	if span.x > MAX_CELLS or span.y > MAX_CELLS: return "At most %d × %d cells" % [MAX_CELLS, MAX_CELLS]
	var ramp := ramp_rect(trench)
	var dig := r.merge(ramp).grow(RIM)
	# The whole dig, rim included, on the level pad.
	var x := dig.position.x
	while x <= dig.end.x + .01:
		var z := dig.position.y
		while z <= dig.end.y + .01:
			var why := MHSiteTerrain.unbuildable_reason(Vector2(x, z))
			if not why.is_empty(): return "Too close to the edge of the build area"
			if builder.lander != null and builder.lander.keeps_clear(Vector2(x, z)): return "Too close to the lander"
			z += 1.5
		x += 1.5
	for zone in builder.zones:
		for cell in zone.get("cells", []):
			var square := Rect2(Vector2(cell) * CELL - Vector2.ONE * CELL * .5, Vector2.ONE * CELL)
			if square.grow(-.1).intersects(dig): return "Overlaps the habitat"
		if zone.has("at") and dig.has_point(zone.at as Vector2): return "Overlaps the %s" % str(BuildController.ZONE_TYPES.get(str(zone.kind), {}).get("label", "equipment"))
	for other in builder.trenches:
		if floor_rect(other).merge(ramp_rect(other)).grow(RIM).intersects(r.merge(ramp)): return "Overlaps another trench"
	return ""

# ---------- building ----------

## The trenches' walls, floor, ramp and rim, and the dig in the ground.
static func build(builder: Node, parent: Node3D) -> void:
	MHSiteTerrain.trench_areas = areas(builder.trenches)
	for trench in builder.trenches: _build_one(trench, parent)
	_update_cuts(builder)

static func _build_one(trench: Dictionary, parent: Node3D) -> void:
	var holder := StaticBody3D.new()
	holder.name = "Trench"
	holder.collision_layer = 1
	holder.collision_mask = 0
	parent.add_child(holder)
	var r := floor_rect(trench)
	var ramp := ramp_rect(trench)
	var d := ramp_dir(trench)
	var floor_mat := _ground_material("gravel")
	var wall_mat := _material("frame_retaining_wall", Color("#8796A0"), .5)
	var rim_mat := _ground_material("dust")
	var edge_mat := _material("amber_edge", Color("#F2C35A"), .5)
	# Floor.
	_box(holder, Vector3(r.get_center().x, -DEPTH - .1, r.get_center().y), Vector3(r.size.x + WALL, .2, r.size.y + WALL), floor_mat)
	# Retaining walls round the floor, open where the ramp meets it, and along the ramp's sides.
	var low := -DEPTH - .25
	var top := .1
	var wall_h := top - low
	var wall_y := (top + low) * .5
	var gap := Vector2(ramp.position.x, ramp.end.x) if d.x == 0 else Vector2(ramp.position.y, ramp.end.y)
	for side in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var along_x: bool = side.y != 0
		var fixed: float = (r.position.y if side.y < 0 else r.end.y) if along_x else (r.position.x if side.x < 0 else r.end.x)
		var outward: float = (side.y if along_x else side.x) * WALL * .5
		var span := Vector2(r.position.x - WALL, r.end.x + WALL) if along_x else Vector2(r.position.y - WALL, r.end.y + WALL)
		var pieces: Array = [span]
		if side == d: pieces = [Vector2(span.x, gap.x), Vector2(gap.y, span.y)]
		for piece in pieces:
			if piece.y - piece.x < .05: continue
			var mid: float = (piece.x + piece.y) * .5
			var length: float = piece.y - piece.x
			if along_x: _box(holder, Vector3(mid, wall_y, fixed + outward), Vector3(length, wall_h, WALL), wall_mat)
			else: _box(holder, Vector3(fixed + outward, wall_y, mid), Vector3(WALL, wall_h, length), wall_mat)
	if d.x == 0:
		for x in [ramp.position.x - WALL * .5, ramp.end.x + WALL * .5]:
			_box(holder, Vector3(x, wall_y, ramp.get_center().y), Vector3(WALL, wall_h, ramp.size.y), wall_mat)
	else:
		for z in [ramp.position.y - WALL * .5, ramp.end.y + WALL * .5]:
			_box(holder, Vector3(ramp.get_center().x, wall_y, z), Vector3(ramp.size.x, wall_h, WALL), wall_mat)
	# The ramp: a slab from the floor's edge up to the surface.
	var angle := atan2(DEPTH, RAMP_LENGTH)
	var slab := Vector3(ramp.size.x, .3, sqrt(RAMP_LENGTH * RAMP_LENGTH + DEPTH * DEPTH)) if d.x == 0 else Vector3(sqrt(RAMP_LENGTH * RAMP_LENGTH + DEPTH * DEPTH), .3, ramp.size.y)
	var basis := Basis()
	match d:
		Vector2i(0, 1): basis = Basis(Vector3.RIGHT, -angle)
		Vector2i(0, -1): basis = Basis(Vector3.RIGHT, angle)
		Vector2i(1, 0): basis = Basis(Vector3.BACK, angle)
		_: basis = Basis(Vector3.BACK, -angle)
	var centre := Vector3(ramp.get_center().x, -DEPTH * .5, ramp.get_center().y) - basis.y * .15
	_box(holder, centre, slab, rim_mat, basis)
	# The paved rim: everything round the top except the opening itself.
	var outer := r.merge(ramp).grow(RIM)
	var openings := [r.grow(WALL), ramp.grow_individual(WALL if d.x == 0 else 0.0, WALL if d.x != 0 else 0.0, WALL if d.x == 0 else 0.0, WALL if d.x != 0 else 0.0)]
	for piece in _subtract(outer, openings):
		_box(holder, Vector3(piece.get_center().x, -.04, piece.get_center().y), Vector3(piece.size.x, .12, piece.size.y), rim_mat)
	# A caution stripe along the drop.
	for side in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if side == d: continue
		var along_x: bool = side.y != 0
		var fixed: float = (r.position.y - WALL * 1.6 if side.y < 0 else r.end.y + WALL * 1.6) if along_x else (r.position.x - WALL * 1.6 if side.x < 0 else r.end.x + WALL * 1.6)
		if along_x: _visual_box(holder, Vector3(r.get_center().x, .035, fixed), Vector3(r.size.x + WALL * 2.0, .02, .14), edge_mat)
		else: _visual_box(holder, Vector3(fixed, .035, r.get_center().y), Vector3(.14, .02, r.size.y + WALL * 2.0), edge_mat)

## outer minus the openings, as rectangles (a grid split on every edge).
static func _subtract(outer: Rect2, openings: Array) -> Array:
	var xs := [outer.position.x, outer.end.x]
	var zs := [outer.position.y, outer.end.y]
	for o in openings:
		for v in [o.position.x, o.end.x]: if v > outer.position.x and v < outer.end.x: xs.append(v)
		for v in [o.position.y, o.end.y]: if v > outer.position.y and v < outer.end.y: zs.append(v)
	xs.sort(); zs.sort()
	var out: Array = []
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var piece := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			if piece.get_area() < .01: continue
			if openings.any(func(o): return (o as Rect2).has_point(piece.get_center())): continue
			out.append(piece)
	return out

static func _box(body: StaticBody3D, at: Vector3, size: Vector3, material: Material, basis := Basis()) -> void:
	_visual_box(body, at, size, material, basis)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(basis, at)
	body.add_child(collision)

static func _visual_box(body: Node3D, at: Vector3, size: Vector3, material: Material, basis := Basis()) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = Transform3D(basis, at)
	body.add_child(instance)

## The region's own ground texture, laid in world space, so the apron, ramp
## and floor read as graded ground rather than slabs.
static var _ground: Dictionary = {}
static func _ground_material(texture_name: String) -> Material:
	if _ground.has(texture_name): return _ground[texture_name]
	var folder := MHSiteTerrain.RegionTerrain.DIRECTORY + str(MHSiteTerrain.settings().get("region", "")) + "/ground_" + texture_name
	var material := StandardMaterial3D.new()
	material.resource_name = "regolith_" + texture_name
	material.albedo_texture = load(folder + "_albedo_height.png") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(folder + "_normal_roughness.png") as Texture2D
	material.albedo_color = Color(.93, .9, .88)
	material.roughness = .95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * .44   # matches the ground: Terrain3D scales per 2 m point
	_ground[texture_name] = material
	return material

static func _material(material_name: String, colour: Color, roughness: float) -> Material:
	var source := StandardMaterial3D.new()
	source.resource_name = material_name
	source.albedo_color = colour
	source.roughness = roughness
	return MHPalette.material(source)

## Sink the region's ground under every trench to just below its floor (and
## put old cuts back). Not Terrain3D holes: Godot's default physics can't
## take the holes' missing heights in collision. The trench floor, ramp and
## rim hide the sunken ground.
static func _update_cuts(builder: Node) -> void:
	var terrain := builder.get_tree().get_first_node_in_group("region_terrain") if builder.is_inside_tree() else null
	if terrain == null or terrain.get("data") == null: return
	var key := str(terrain.get_instance_id()) + str(builder.trenches.map(func(t): return [floor_rect(t), ramp_dir(t)]))
	if key == _cuts_key: return
	var data = terrain.data
	var spacing: float = terrain.vertex_spacing
	# Put the last dig back (only on the same terrain: a loaded game has a fresh one).
	if _cuts_key.begins_with(str(terrain.get_instance_id())):
		for point in _cuts: data.set_height(point, float(_cuts[point]))
	_cuts.clear()
	for trench in builder.trenches:
		# Far enough out that the slope back up to the surface starts outside the
		# walls, and ends under the apron.
		var cut := [floor_rect(trench).grow(SINK), ramp_rect(trench).grow(SINK)]
		var bounds: Rect2 = cut[0].merge(cut[1])
		for gx in range(floori(bounds.position.x / spacing), ceili(bounds.end.x / spacing) + 1):
			for gz in range(floori(bounds.position.y / spacing), ceili(bounds.end.y / spacing) + 1):
				var p := Vector2(gx * spacing, gz * spacing)
				if not cut.any(func(c): return (c as Rect2).has_point(p)): continue
				var point := Vector3(p.x, 0, p.y)
				if not _cuts.has(point): _cuts[point] = data.get_height(point)
				data.set_height(point, -DEPTH - .6)
	data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	terrain.collision.build()
	_cuts_key = key
