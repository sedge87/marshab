class_name MHCaves
extends Node3D

## Caves and the lava tube on a region site (docs/terrain-overhaul.md §3).
## Each cave in region.json "caves" is a centreline with a floor height
## (made by tools/generate_region.py, which also cut the ramp pit, the
## skylights and the notches in front of the mouths). A heightmap can't
## overhang and Terrain3D's holes don't work with Godot's default physics,
## so here each cave is built as its own mesh: the tunnel (floor, walls and
## roof, roughened, open under its skylights), a rock portal round its mouth,
## and the ground over it. Terrain3D's ground is sunk under the whole cave
## and a copy of it, read from Terrain3D before the sinking and drawn with
## its own textures, is laid back over the top, so the seam can't show.
## Everything has collision. Region metres in the file; site metres here.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const FLOOR_POINTS := 10      # across a cross-section's floor
const ARCH_POINTS := 18       # round its arch
const SINK := 3.0             # Terrain3D's ground goes this far under a cave's floor
const LID_GAP := .9           # the ground over a cave stays this far over its roof
const MARGIN := 1.5           # ground sunk this far past a cave's walls

static var _caves: Array = []
static var _key := ""

## The caves of this site, in site metres: each {id, name, kind, points
## (x, floor, z), half (half width at each point), height (at each point),
## skylights [{centre, radius, mound (centre), mound_radius, mound_height}],
## finds, bounds, length, noise}. Empty off region sites.
static func caves() -> Array:
	var zone := MHSiteTerrain.region_zone()
	if zone.is_empty(): return []
	var key := str(MHSiteTerrain.RegionTerrain.meta().get("id", "")) + str(zone.centre)
	if key == _key: return _caves
	_key = key
	_caves = []
	var origin := Vector3(float(zone.centre[0]), float(zone.height), float(zone.centre[1]))
	for data in MHSiteTerrain.RegionTerrain.meta().get("caves", []):
		var noise := FastNoiseLite.new()
		noise.seed = int(data.get("seed", 1))
		noise.frequency = .09
		var points := PackedVector3Array()
		for p in data.points: points.append(Vector3(float(p[0]), float(p[2]), float(p[1])) - origin)
		var half := PackedFloat32Array()
		var heights := PackedFloat32Array()
		var lava := str(data.kind) == "lava_tube"
		for k in points.size():
			var ease_in := smoothstep(0.0, 6.0, float(k))   # the mouth keeps its size, for the portal
			half.append(float(data.half_width) * (1.0 + (.14 if lava else .2) * noise.get_noise_1d(k * 3.0) * ease_in))
			heights.append(float(data.height) * (1.0 + .1 * noise.get_noise_1d(k * 3.0 + 500.0) * ease_in))
		var bounds := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
		for p in points: bounds = bounds.expand(Vector2(p.x, p.z))
		var cave := {"id": str(data.id), "name": str(data.name), "kind": str(data.kind), "points": points,
			"half": half, "height": heights, "finds": data.get("finds", []), "noise": noise,
			"bounds": bounds.grow(float(data.half_width) * 1.4 + MARGIN + 4.0),
			"length": (points.size() - 1) * Vector2(points[1].x - points[0].x, points[1].z - points[0].z).length() if points.size() > 1 else 0.0,
			"skylights": []}
		for sky in data.get("skylights", []):
			var centre := Vector2(float(sky.position[0]) - origin.x, float(sky.position[1]) - origin.z)
			var radius := float(sky.radius)
			# The fallen roof: a rubble mound off to one side, leaving a lane.
			var at := _locate(cave, centre)
			var normal := _normal(cave, int(at.k))
			cave.skylights.append({"centre": centre, "radius": radius,
				"mound": centre + normal * float(sky.rubble_side) * float(data.half_width) * .38,
				"mound_radius": radius * 1.15, "mound_height": radius * .42})
		_caves.append(cave)
	return _caves

## The floor of the cave you're in (site metres), or NAN when the position
## isn't inside one. Anything that needs the ground inside a cave (dropped
## items, GAR-Y, the corer) asks this before MHSiteTerrain.height().
static func floor_at(position: Vector3) -> float:
	var cave := cave_at(position)
	if cave.is_empty(): return NAN
	return _floor(cave, Vector2(position.x, position.z), _locate(cave, Vector2(position.x, position.z)))

## The ground under a position: a cave's floor inside one, else the land.
static func ground_y(position: Vector3) -> float:
	var y := floor_at(position)
	return y if not is_nan(y) else MHSiteTerrain.height(position.x, position.z)

## The cave a position is inside ({} if none).
static func cave_at(position: Vector3) -> Dictionary:
	var p := Vector2(position.x, position.z)
	for cave in caves():
		if not (cave.bounds as Rect2).has_point(p): continue
		var at := _locate(cave, p)
		if at.along < -.5 or at.along > float(cave.length) + .5: continue
		var k := clampi(int(at.k), 0, (cave.half as PackedFloat32Array).size() - 1)
		if absf(at.lateral) > float(cave.half[k]) + .4: continue
		var floor_y := _floor(cave, p, at)
		if position.y < floor_y - 2.5 or position.y > floor_y + float(cave.height[k]) + .5: continue
		return cave
	return {}

## How dark it is here from being underground: 0 outside or at a mouth or a
## skylight, 1 more than about 12 m in.
static func darkness(position: Vector3) -> float:
	var cave := cave_at(position)
	if cave.is_empty(): return 0.0
	var p := Vector2(position.x, position.z)
	var dark := smoothstep(1.5, 12.0, float(_locate(cave, p).along))
	for sky in cave.skylights:
		dark = minf(dark, smoothstep(float(sky.radius) - 1.0, float(sky.radius) + 10.0, p.distance_to(sky.centre)))
	return dark

## Where along a cave's centreline a point is: k (index, fractional), along
## (metres from the mouth; negative in front of it, past the end beyond the
## last point) and lateral (metres to the side, signed).
## With a hint (a point index), only the segments near it are searched.
static func _locate(cave: Dictionary, p: Vector2, hint := -1) -> Dictionary:
	var points: PackedVector3Array = cave.points
	var best := {"k": 0.0, "along": -INF, "lateral": INF}
	var best_d := INF
	var step := float(cave.length) / maxf(points.size() - 1, 1)
	var first := 0 if hint < 0 else maxi(hint - 6, 0)
	var last := points.size() - 1 if hint < 0 else mini(hint + 6, points.size() - 1)
	for i in range(first, last):
		var a := Vector2(points[i].x, points[i].z)
		var b := Vector2(points[i + 1].x, points[i + 1].z)
		var ab := b - a
		var t := (p - a).dot(ab) / ab.length_squared()
		if i > 0: t = maxf(t, 0.0)
		if i < points.size() - 2: t = minf(t, 1.0)
		var on := a + ab * t
		var d := p.distance_to(on)
		if d < best_d:
			best_d = d
			var side := Vector2(-ab.y, ab.x).normalized()
			best = {"k": i + t, "along": (i + t) * step, "lateral": (p - on).dot(side)}
	return best

static func _normal(cave: Dictionary, k: int) -> Vector2:
	var points: PackedVector3Array = cave.points
	var a := points[clampi(k - 1, 0, points.size() - 1)]
	var b := points[clampi(k + 1, 0, points.size() - 1)]
	var tangent := Vector2(b.x - a.x, b.z - a.z).normalized()
	return Vector2(-tangent.y, tangent.x)

static func _floor(cave: Dictionary, p: Vector2, at: Dictionary) -> float:
	var points: PackedVector3Array = cave.points
	var k := clampf(float(at.k), 0.0, points.size() - 1.001)
	var y := lerpf(points[int(k)].y, points[int(k) + 1].y, k - int(k))
	return y + _mound(cave, p)

static func _mound(cave: Dictionary, p: Vector2) -> float:
	var rise := 0.0
	for sky in cave.skylights:
		var d := p.distance_to(sky.mound) / float(sky.mound_radius)
		if d < 1.0: rise += float(sky.mound_height) * pow(1.0 - d * d, 1.5)
	return rise

## The roof's height over a point of the centreline (the ground over a cave
## stays above it).
static func _roof(cave: Dictionary, k: int) -> float:
	return (cave.points as PackedVector3Array)[k].y + float(cave.height[k]) + LID_GAP

# ---------- building ----------

var _faces := PackedVector3Array()   # collision for everything built here
var _terrain: Terrain3D

## Builds every cave, sinks Terrain3D's ground under them and lays the copy
## over them. Call once the terrain's heights are imported, before its
## collision is built. `environment` lends the rock models and material.
func build(terrain: Terrain3D, environment: Node) -> void:
	name = "Caves"
	_terrain = terrain
	var rock := ShaderMaterial.new()
	rock.shader = preload("res://shaders/cave_rock.gdshader")
	var ground := _ground_material(terrain)
	var sunk := {}
	for cave in caves():
		var material := rock.duplicate() as ShaderMaterial
		material.set_shader_parameter("strata", 1.0 if cave.kind == "cave" else 0.0)
		material.set_shader_parameter("ice", 1.0 if cave.kind == "ice_cave" else 0.0)
		_add_mesh(_tunnel(cave), material)
		_add_mesh(_portal(cave, terrain), material)
		_add_mesh(_lid(cave, terrain, sunk), ground, false)
		_add_rubble(cave, environment)
	if sunk.is_empty(): return
	# A little into each vertex's cell: exactly on it, Terrain3D can round to the next one.
	for point in sunk: terrain.data.set_height(point, float(sunk[point]))
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	var body := StaticBody3D.new()
	body.name = "CaveCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_faces)
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	add_child(body)

func _add_mesh(surface: SurfaceTool, material: Material, shadows := true) -> void:
	if surface == null: return
	surface.index()
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh.get_surface_count() == 0: return
	_faces.append_array(mesh.get_faces())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	# The ground's copy throws no shadow of its own (Terrain3D's shadow of
	# the same ground already falls round it, and the two together streak).
	if not shadows: instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## One cross-section of the tunnel at point k: the floor across (left to
## right), then the arch from the right wall over to the left, roughened.
func _ring(cave: Dictionary, k: int) -> PackedVector3Array:
	var points: PackedVector3Array = cave.points
	var centre := points[k]
	var normal := _normal(cave, k)
	var half := float(cave.half[k])
	var tall := float(cave.height[k])
	var noise: FastNoiseLite = cave.noise
	var rough := .55 if cave.kind == "lava_tube" else .3
	var ring := PackedVector3Array()
	for j in FLOOR_POINTS + 1:
		var lateral := lerpf(-half, half, float(j) / FLOOR_POINTS) * .97
		var p := Vector2(centre.x, centre.z) + normal * lateral
		ring.append(Vector3(p.x, centre.y + _mound(cave, p) + .06 * noise.get_noise_2d(p.x * 4.0, p.y * 4.0), p.y))
	for j in range(1, ARCH_POINTS):
		var angle := PI * j / ARCH_POINTS
		var lateral := half * cos(angle)
		var up := tall * pow(sin(angle), .55)
		# A lava tube's walls step in at the old flow line: a low bench each side.
		if cave.kind == "lava_tube" and up < 1.6: lateral *= .9
		var out := Vector2(lateral, up - tall * .35).normalized()
		var p := Vector2(centre.x, centre.z) + normal * lateral
		var bump := rough * noise.get_noise_3d(p.x, centre.y + up, p.y) * smoothstep(0.0, .6, up)
		ring.append(Vector3(p.x + normal.x * out.x * bump, centre.y + up + out.y * bump, p.y + normal.y * out.x * bump))
	return ring

func _tunnel(cave: Dictionary) -> SurfaceTool:
	var points: PackedVector3Array = cave.points
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := _ring(cave, 0)
	for k in range(1, points.size()):
		var ring := _ring(cave, k)
		# Red: how far in, for the shader (the ice cave's ice thickens towards the back).
		var depth := [Color(float(k - 1) / (points.size() - 1), 0, 0), Color(float(k) / (points.size() - 1), 0, 0)]
		for j in ring.size():
			var a := last[j]
			var b := last[(j + 1) % ring.size()]
			var c := ring[(j + 1) % ring.size()]
			var d := ring[j]
			if _under_skylight(cave, (a + b + c + d) * .25, k): continue
			_quad(surface, a, b, c, d, [depth[0], depth[0], depth[1], depth[1]])
		last = ring
	# The far end: closed.
	var middle := Vector3.ZERO
	for p in last: middle += p
	middle /= last.size()
	surface.set_color(Color(1, 0, 0))
	for j in last.size(): _triangle(surface, last[j], last[(j + 1) % last.size()], middle)
	surface.set_color(Color(0, 0, 0))
	# Round each skylight: the cut edge of the roof, up to the ground over it.
	for sky in cave.skylights:
		var steps := 32
		var previous := []
		for i in steps + 1:
			var angle := TAU * i / steps
			var p: Vector2 = sky.centre + Vector2(cos(angle), sin(angle)) * float(sky.radius)
			var at := _locate(cave, p)
			var k := clampi(roundi(float(at.k)), 0, points.size() - 1)
			var half := float(cave.half[k])
			var floor_y := _floor(cave, p, at) - _mound(cave, p)
			var bottom := floor_y + float(cave.height[k]) * pow(sin(acos(clampf(float(at.lateral) / half, -1.0, 1.0))), .55) - .5
			# Up to the pit's floor, then a flat rim over the hole's ragged edge.
			var shelf := maxf(_ground(p), _roof(cave, k)) + .05
			var rim: Vector2 = sky.centre + Vector2(cos(angle), sin(angle)) * (float(sky.radius) + 3.0)
			var rim_y := maxf(_ground(rim), _roof(cave, k)) + .05
			var edge := [Vector3(p.x, bottom, p.y), Vector3(p.x, shelf, p.y), Vector3(rim.x, rim_y, rim.y)]
			if not previous.is_empty():
				_quad(surface, previous[0], edge[0], edge[1], previous[1])
				_quad(surface, previous[1], edge[1], edge[2], previous[2])
			previous = edge
	return surface

## The ground's height before it's sunk (from the terrain when there is one).
func _ground(p: Vector2) -> float:
	return _terrain.data.get_height(Vector3(p.x, 0, p.y)) if _terrain != null else MHSiteTerrain.height(p.x, p.y)

func _under_skylight(cave: Dictionary, p: Vector3, k: int) -> bool:
	if p.y < (cave.points as PackedVector3Array)[k].y + float(cave.height[k]) * .45: return false
	for sky in cave.skylights:
		if Vector2(p.x, p.z).distance_to(sky.centre) < float(sky.radius): return true
	return false

## The mouth: a rough rock face from the tunnel's arch out to the ground
## round it and up to the ground over it (the front edge of the ground laid
## over the cave), and an apron on the floor in front (Terrain3D's ground
## dips where it's sunk).
func _portal(cave: Dictionary, terrain: Terrain3D) -> SurfaceTool:
	var points: PackedVector3Array = cave.points
	var ring := _ring(cave, 0)
	var normal := _normal(cave, 0)
	var forward := Vector2(normal.y, -normal.x)   # into the cave
	var origin := Vector2(points[0].x, points[0].z)
	var floor_y := points[0].y
	var wide := float(cave.half[0]) + 3.0
	var noise: FastNoiseLite = cave.noise
	# The face's outline (lateral, height): up the right side, along the
	# ground over the mouth, down the left.
	var outline: Array = [Vector2(wide, floor_y - .4)]
	for i in 15:
		var lateral := lerpf(wide, -wide, i / 14.0)
		var top := _roof(cave, 0)
		for along: float in [0.0, 1.0, 2.0]:
			var p := origin + normal * lateral + forward * along
			top = maxf(top, terrain.data.get_height(Vector3(p.x, 0, p.y)))
		outline.append(Vector2(lateral, top + .3))
	outline.append(Vector2(-wide, floor_y - .4))
	# The arch the same way round, (lateral, height): right floor corner, over, left floor corner.
	var arch: Array = []
	for j in [FLOOR_POINTS] + range(FLOOR_POINTS + 1, ring.size()) + [0]:
		arch.append(Vector2((Vector2(ring[j].x, ring[j].z) - origin).dot(normal), ring[j].y))
	var arch_at := _fractions(arch)
	var outline_at := _fractions(outline)
	var rows := 5
	var grid: Array = []
	for j in arch.size():
		var outer := _along(outline, outline_at, arch_at[j])
		var row: Array[Vector3] = []
		for r in rows + 1:
			var t := float(r) / rows
			var q: Vector2 = (arch[j] as Vector2).lerp(outer, t)
			var p := origin + normal * q.x
			var push := sin(t * PI) * .9 * noise.get_noise_2d(q.x * 2.0 + 40.0, q.y * 2.0)   # in and out of the face
			row.append(Vector3(p.x + forward.x * push, q.y, p.y + forward.y * push))
		grid.append(row)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(Color.BLACK)   # the mouth: no ice
	for j in grid.size() - 1:
		for r in rows:
			_quad(surface, grid[j][r], grid[j + 1][r], grid[j + 1][r + 1], grid[j][r + 1])
	var back := origin - forward * 2.6
	var front := origin + forward * .4
	var y := floor_y + .08
	_quad(surface, Vector3(back.x - normal.x * wide, y, back.y - normal.y * wide), Vector3(back.x + normal.x * wide, y, back.y + normal.y * wide),
		Vector3(front.x + normal.x * wide, y, front.y + normal.y * wide), Vector3(front.x - normal.x * wide, y, front.y - normal.y * wide))
	return surface

## How far along a line of Vector2s (0 to 1) each of its points is.
static func _fractions(line: Array) -> PackedFloat32Array:
	var at := PackedFloat32Array([0.0])
	for i in range(1, line.size()): at.append(at[i - 1] + (line[i] as Vector2).distance_to(line[i - 1]))
	for i in at.size(): at[i] /= maxf(at[at.size() - 1], .001)
	return at

## The point a fraction of the way along a line.
static func _along(line: Array, at: PackedFloat32Array, f: float) -> Vector2:
	for i in range(1, line.size()):
		if at[i] >= f: return (line[i - 1] as Vector2).lerp(line[i], inverse_lerp(at[i - 1], at[i], f) if at[i] > at[i - 1] else 1.0)
	return line[line.size() - 1]

## The ground over a cave: Terrain3D's own vertices round it, read before
## they're sunk, kept over the roof, open at the skylights. Marks the
## vertices to sink in `sunk` (position -> new height).
func _lid(cave: Dictionary, terrain: Terrain3D, sunk: Dictionary) -> SurfaceTool:
	var spacing := terrain.vertex_spacing
	var points: PackedVector3Array = cave.points
	# The vertices near the centreline, each placed against the nearest few
	# points: 1 sunk, -1 in front of the mouth, 0 outside.
	var flags := {}
	var heights := {}
	for k in points.size():
		var reach := float(cave.half[k]) + MARGIN + spacing * 2.0
		var centre := Vector2(points[k].x, points[k].z)
		for gz in range(floori((centre.y - reach) / spacing), ceili((centre.y + reach) / spacing) + 1):
			for gx in range(floori((centre.x - reach) / spacing), ceili((centre.x + reach) / spacing) + 1):
				var key := Vector2i(gx, gz)
				if flags.has(key): continue
				var p := Vector2(gx, gz) * spacing
				var at := _locate(cave, p, k)
				var near := clampi(roundi(float(at.k)), 0, points.size() - 1)
				var flag := 0
				if absf(at.lateral) <= float(cave.half[near]) + MARGIN and at.along <= float(cave.length) + MARGIN:
					flag = 1 if at.along >= 0.0 else -1
				var y := terrain.data.get_height(Vector3(p.x, 0, p.y))
				if flag == 1:
					sunk[Vector3(p.x, 0, p.y)] = minf(float(sunk.get(Vector3(p.x, 0, p.y), INF)), points[near].y - SINK)
					y = maxf(y, _roof(cave, near)) + .03
				flags[key] = flag
				heights[key] = y
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for key in flags:
		var corners := [key, key + Vector2i(1, 0), key + Vector2i(1, 1), key + Vector2i(0, 1)]
		var marks := corners.map(func(c): return int(flags.get(c, 0)))
		if marks.has(1):
			if marks.has(-1): continue   # across the mouth: the portal and apron cover it
		# Two cells past the sunk ground too, at its own height: Terrain3D
		# shades each point from the heights beside it, so the ground next
		# to the sunk strip would show dark.
		elif not _near_sunk(flags, key): continue
		# A cell with a corner over a skylight's hole is left open (the rim covers the ragged edge).
		if cave.skylights.any(func(sky): return corners.any(func(c): return (Vector2(c) * spacing).distance_to(sky.centre) < float(sky.radius))): continue
		var v := corners.map(func(c): return Vector3(c.x * spacing, float(heights[c]) if heights.has(c) else terrain.data.get_height(Vector3(c.x * spacing, 0, c.y * spacing)), c.y * spacing))
		_quad(surface, v[0], v[1], v[2], v[3])
	return surface

static func _near_sunk(flags: Dictionary, key: Vector2i) -> bool:
	for dz in range(-2, 4):
		for dx in range(-2, 4):
			if int(flags.get(key + Vector2i(dx, dz), 0)) == 1: return true
	return false

## Breakdown on the skylights' mounds and loose blocks along the walls.
func _add_rubble(cave: Dictionary, environment: Node) -> void:
	var meshes: Array = []
	for model_name in MHSiteTerrain.ROCK_MODELS:
		var mesh: Mesh = environment.call("_load_model_mesh", str(model_name))
		if mesh != null: meshes.append(mesh)
	if meshes.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cave.id)
	var placed: Array = []
	for i in meshes.size(): placed.append([])
	var points: PackedVector3Array = cave.points
	for sky in cave.skylights:
		for i in 14:
			var p: Vector2 = sky.mound + Vector2.from_angle(rng.randf() * TAU) * float(sky.mound_radius) * sqrt(rng.randf()) * .9
			var at := _locate(cave, p)
			placed[rng.randi() % meshes.size()].append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-.4, .4), rng.randf() * TAU, rng.randf_range(-.4, .4))).scaled(Vector3.ONE * rng.randf_range(.6, 1.8)), Vector3(p.x, _floor(cave, p, at) - .2, p.y)))
	for k in range(3, points.size() - 1, 3):
		if rng.randf() > .55: continue
		var side := 1.0 if rng.randf() < .5 else -1.0
		var p := Vector2(points[k].x, points[k].z) + _normal(cave, k) * side * float(cave.half[k]) * rng.randf_range(.72, .9)
		var size := rng.randf_range(.25, .7) * (1.6 if cave.kind == "lava_tube" else 1.0)
		placed[rng.randi() % meshes.size()].append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-.4, .4), rng.randf() * TAU, 0)).scaled(Vector3.ONE * size), Vector3(p.x, points[k].y - .1, p.y)))
	var material: Material = environment.call("_rock_material")
	for i in meshes.size():
		if (placed[i] as Array).is_empty(): continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[i]
		multimesh.instance_count = (placed[i] as Array).size()
		for j in multimesh.instance_count: multimesh.set_instance_transform(j, placed[i][j])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		add_child(instance)

## Terrain3D's look on a plain mesh: its texture arrays, the region's control
## and colour maps (cropped to the caves), the same projection.
func _ground_material(terrain: Terrain3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/cave_ground.gdshader")
	var bounds := Rect2()
	for cave in caves(): bounds = cave.bounds if bounds.size == Vector2.ZERO else bounds.merge(cave.bounds)
	if bounds.size == Vector2.ZERO: return material
	var zone := MHSiteTerrain.region_zone()
	var RT := MHSiteTerrain.RegionTerrain
	var spacing := float(RT.meta().get("spacing", 2.0))
	var half := float(RT.meta().get("half", 3072.0))
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	# Crops of the control and colour maps round the caves only, one texel per
	# heightmap point (the whole maps are 3072 px).
	var corner := Vector2i(((bounds.position + origin + Vector2(half, half)) / spacing).floor())
	var size := Vector2i((bounds.size / spacing).ceil()) + Vector2i(2, 2)
	var control := RT.control_image()
	var colour := RT.colour_image()
	var crop := Rect2i(corner, size).intersection(Rect2i(Vector2i.ZERO, control.get_size()))
	material.set_shader_parameter("control_map", ImageTexture.create_from_image(control.get_region(crop)))
	material.set_shader_parameter("colour_map", ImageTexture.create_from_image(colour.get_region(crop)))
	material.set_shader_parameter("corner", Vector2(crop.position) * spacing - Vector2(half, half) - origin)
	material.set_shader_parameter("spacing", spacing)
	material.set_shader_parameter("crop_size", Vector2(crop.size))
	var scales := PackedFloat32Array()
	for index in 32: scales.append(terrain.assets.get_texture_asset(index).uv_scale if index < terrain.assets.get_texture_count() else .22)
	material.set_shader_parameter("uv_scales", scales)
	RenderingServer.material_set_param(material.get_rid(), "albedo_array", terrain.assets.get_albedo_array_rid())
	RenderingServer.material_set_param(material.get_rid(), "normal_array", terrain.assets.get_normal_array_rid())
	return material

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colours := []) -> void:
	if colours.is_empty():
		_triangle(surface, a, b, c)
		_triangle(surface, a, c, d)
		return
	var corners := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:
		surface.set_color(colours[i])
		surface.add_vertex(corners[i])

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
