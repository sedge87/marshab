extends RefCounted

# Loaded with preload() by the scripts that use it (const MHSiteTerrain), not
# registered as a global class, so it works even before the editor rescans.

# Generated ground for each build site. One height function per site shape
# gives the walkable mesh, its collision, the rock scatter and the build-area
# mask, so what the player sees, walks on and may build on always agree.
#
# Every site has a perfectly level build pad at y = 0. The habitat floor is set
# from the first room, so a level pad means building can continue anywhere in
# it; outside the pad the ground rises into that site's own landscape.
# Shape parameters live in data/sites.json under "terrain".

const GROUND_SHADER := preload("res://shaders/mars_ground.gdshader")
const INNER_EXTENT := 168.0 # walkable mesh with collision, ±m
const INNER_STEP := 3.0
const OUTER_EXTENT := 720.0 # coarse horizon mesh, visual only
const OUTER_STEP := 24.0
# Ground stays exactly level this far beyond the pad, so cells on its edge
# sample flat ground.
const PAD_MARGIN := 2.5
const ROCK_MODELS := ["decor_rock_00", "decor_rock_01", "decor_rock_02", "decor_rock_03", "decor_rock_04", "decor_rock_05", "decor_rock_06", "decor_rock_07"]

static func settings() -> Dictionary:
	var terrain: Dictionary = MHGame.site().get("terrain", {})
	return terrain if not terrain.is_empty() else {"shape": "plains", "pad_half": 60.0}

static func shape() -> String:
	return str(settings().get("shape", "plains"))

# ---------- build area ----------

## Empty when a point may carry habitat; otherwise why not.
static func unbuildable_reason(point: Vector2) -> String:
	var s := settings()
	match shape():
		"canyon":
			if absf(point.y) > float(s.get("pad_length_half", 60.0)) + .01: return "Outside the surveyed build area"
			if absf(point.x) > float(s.get("pad_half_width", 22.5)) + .01: return "Against the canyon wall"
		"crater":
			if point.length() > float(s.get("pad_radius", 45.0)) + .01: return "Against the crater wall"
			if _mound_distance(point) < float(s.get("mound_clear", 12.0)): return "On the central mound"
		_:
			var half := float(s.get("pad_half", 60.0)) + .01
			if absf(point.x) > half or absf(point.y) > half: return "Outside the surveyed build area"
	return ""

## Short description of the build area for the site screen.
static func describe_build_area() -> String:
	var s := settings()
	match shape():
		"canyon": return "%d × %d m canyon floor" % [roundi(float(s.get("pad_half_width", 22.5)) * 2.0), roundi(float(s.get("pad_length_half", 60.0)) * 2.0)]
		"crater": return "%d m crater floor" % roundi(float(s.get("pad_radius", 45.0)) * 2.0)
		"ice":
			var ice_side := roundi(float(s.get("pad_half", 70.0)) * 2.0)
			return "%d × %d m frozen plain" % [ice_side, ice_side]
	var side := roundi(float(s.get("pad_half", 60.0)) * 2.0)
	return "%d × %d m level plain" % [side, side]

static func is_buildable(point: Vector2) -> bool:
	return unbuildable_reason(point).is_empty()

## A 3 m grid cell is buildable only when its centre and all four corners are.
static func cell_unbuildable_reason(cell: Vector2i, cell_size := 3.0) -> String:
	var centre := Vector2(cell.x * cell_size, cell.y * cell_size)
	var half := cell_size * .5
	for offset in [Vector2.ZERO, Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]:
		var reason := unbuildable_reason(centre + offset)
		if not reason.is_empty(): return reason
	return ""

## Distance outside the build pad (0 inside), used to raise the surroundings.
static func _pad_distance(point: Vector2) -> float:
	var s := settings()
	match shape():
		"canyon":
			return maxf(0.0, absf(point.x) - float(s.get("pad_half_width", 22.5)))
		"crater":
			return maxf(0.0, point.length() - float(s.get("pad_radius", 45.0)))
		_:
			var half := float(s.get("pad_half", 60.0))
			return Vector2(maxf(0.0, absf(point.x) - half), maxf(0.0, absf(point.y) - half)).length()

static func _mound_distance(point: Vector2) -> float:
	var s := settings()
	var centre: Array = s.get("mound_centre", [-14.0, -12.0])
	return point.distance_to(Vector2(float(centre[0]), float(centre[1])))

# ---------- height ----------

static func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	match shape():
		"canyon": return _canyon_height(p)
		"crater": return _crater_height(p)
		"ice": return _ice_height(p)
	return _plains_height(p)

static func _noise(p: Vector2, scale: float) -> float:
	# Cheap smooth value noise from layered sines: deterministic, no resources.
	return (sin(p.x * .061 * scale + 1.3) * cos(p.y * .047 * scale - .7) + .6 * sin((p.x + p.y) * .113 * scale + 2.1) + .35 * cos((p.x - p.y) * .171 * scale)) / 1.95

static func _rise(p: Vector2, start: float, width: float) -> float:
	return smoothstep(start, start + width, _pad_distance(p))

static func _plains_height(p: Vector2) -> float:
	var outside := _rise(p, PAD_MARGIN, 36.0)
	var h := outside * (2.6 + _noise(p, 1.0) * 1.4)
	# Flat-topped mesas on the horizon: a recognisable open-plains skyline.
	for mesa in settings().get("mesas", []):
		var centre := Vector2(float(mesa[0]), float(mesa[1]))
		var top := float(mesa[3]) * (1.0 - smoothstep(float(mesa[2]), float(mesa[2]) + 9.0, p.distance_to(centre)))
		h = maxf(h, top)
	return h

static func _canyon_height(p: Vector2) -> float:
	var s := settings()
	var wall_height := float(s.get("wall_height", 38.0))
	# The wall foot wanders a little along the canyon but never onto the pad.
	var foot := float(s.get("pad_half_width", 22.5)) + PAD_MARGIN + 2.0 + 2.5 * (1.0 + sin(p.y * .045)) + 1.5 * (1.0 + sin(p.y * .11 + 1.0))
	var across := clampf((absf(p.x) - foot) / 18.0, 0.0, 1.0)
	# Terraced walls: four broad ledges joined by steep risers.
	var steps := 4.0
	var layer := across * steps
	var ledge := floorf(layer)
	var climb := (ledge + smoothstep(.55, 1.0, layer - ledge)) / steps
	if across >= 1.0: climb = 1.0
	var h := climb * wall_height
	if across >= 1.0: h += _noise(p, .7) * 3.0
	# Beyond the surveyed stretch the floor carries a shallow dry channel.
	var beyond := smoothstep(float(s.get("pad_length_half", 60.0)) + 4.0, float(s.get("pad_length_half", 60.0)) + 12.0, absf(p.y))
	if beyond > 0.0 and absf(p.x) < foot:
		var channel := 1.0 - smoothstep(1.5, 4.5, absf(p.x - 6.0 * sin(p.y * .05)))
		h += beyond * (_noise(p, 2.0) * .5 - channel * .9)
	return h

static func _crater_height(p: Vector2) -> float:
	var s := settings()
	var r := p.length()
	var angle := atan2(p.y, p.x)
	var wobble := 3.0 * sin(angle * 3.0 + .6) + 1.8 * sin(angle * 7.0)
	var floor_edge := float(s.get("pad_radius", 45.0)) + PAD_MARGIN + 1.0
	var crest := float(s.get("rim_radius", 76.0)) + wobble
	var rim_height := float(s.get("rim_height", 22.0)) + wobble * .8
	var h := 0.0
	if r <= crest:
		h = pow(smoothstep(floor_edge, crest, r), 1.6) * rim_height
	else:
		# Outer flank falls away to the surrounding plain.
		h = lerpf(rim_height, 5.0, smoothstep(crest, crest + 40.0, r)) + _noise(p, .8) * 1.5 * smoothstep(crest, crest + 20.0, r)
	# The central mound: a low peak the habitat has to build around.
	var mound := 1.0 - smoothstep(0.0, float(s.get("mound_radius", 11.0)), _mound_distance(p))
	h = maxf(h, pow(mound, 1.4) * float(s.get("mound_height", 8.0)))
	return h

static func _ice_height(p: Vector2) -> float:
	var outside := _rise(p, PAD_MARGIN, 60.0)
	# Polygonal ground: the crack troughs only cut in outside the build pad.
	var trough := (1.0 - smoothstep(.0, .9, _polygon_edge_distance(p))) * .5
	var pits := maxf(0.0, _noise(p, 1.6) - .45) * 3.0
	return outside * (5.5 + _noise(p, .6) * 1.5 - trough - pits)

## 0–1 shade picked per frozen polygon (by its nearest jittered centre).
static func _polygon_shade(p: Vector2) -> float:
	var size := 9.0
	var cell := Vector2(floorf(p.x / size), floorf(p.y / size))
	var best := INF
	var shade := 0.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := cell + Vector2(dx, dz)
			var jitter := Vector2(fposmod(sin(c.x * 12.99 + c.y * 78.23) * 437.5, 1.0), fposmod(sin(c.x * 39.35 + c.y * 11.13) * 921.7, 1.0))
			var d := p.distance_to((c + jitter * .8 + Vector2(.1, .1)) * size)
			if d < best:
				best = d
				shade = fposmod(sin(c.x * 7.13 + c.y * 3.71) * 158.3, 1.0)
	return shade

## Distance to the nearest crack of the ~9 m polygon pattern of frozen ground.
static func _polygon_edge_distance(p: Vector2) -> float:
	var size := 9.0
	var cell := Vector2(floorf(p.x / size), floorf(p.y / size))
	var nearest := INF
	var second := INF
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := cell + Vector2(dx, dz)
			var jitter := Vector2(fposmod(sin(c.x * 12.99 + c.y * 78.23) * 437.5, 1.0), fposmod(sin(c.x * 39.35 + c.y * 11.13) * 921.7, 1.0))
			var d := p.distance_to((c + jitter * .8 + Vector2(.1, .1)) * size)
			if d < nearest:
				second = nearest
				nearest = d
			elif d < second:
				second = d
	return (second - nearest) * .5

# ---------- colour ----------

static func ground_colour(p: Vector2, h: float, slope: float) -> Color:
	var s := settings()
	var base := Color(str(s.get("ground", "#A9603E")))
	var colour := base
	match shape():
		"canyon":
			# Layered strata: horizontal bands that read as an eroded canyon wall.
			var bands := [Color("#9A5338"), Color("#B87149"), Color("#7E4430"), Color("#C88A5E"), Color("#8C4B33")]
			if h > .6:
				colour = bands[posmod(int(floorf(h / 4.2)), bands.size())]
		"crater":
			if h > .6: colour = base.darkened(.12).lerp(Color("#C08458"), smoothstep(10.0, 22.0, h))
		"ice":
			# Patterned ground: each frozen polygon its own shade, with darker
			# troughs only where they are wide enough for the mesh to draw.
			colour = base.darkened(.05 + .09 * _polygon_shade(p)).lerp(Color("#6E5548"), (1.0 - smoothstep(.4, 1.6, _polygon_edge_distance(p))) * .3)
		_:
			if h > 6.0: colour = base.lightened(.08).lerp(Color("#C9875C"), smoothstep(10.0, 20.0, h))
	# Gentle mottling so level ground never reads as one flat sheet.
	colour = colour.darkened(.035 * (_noise(p, 3.1) + 1.0))
	# Steep faces are darker, so landforms read clearly in flat site light.
	colour = colour.darkened(clampf(slope * .55, 0.0, .35))
	# Frost marks buried ice on every site: the pale ground is where extractors pay off.
	var richness := 0.0
	for deposit in MHGame.site().get("ice_deposits", []):
		var falloff := clampf(1.0 - p.distance_to(Vector2(float(deposit.x), float(deposit.z))) / maxf(1.0, float(deposit.radius)), 0.0, 1.0)
		richness = maxf(richness, float(deposit.richness) * falloff)
	return colour.lerp(Color("#E3D8CF"), clampf(richness * .75, 0.0, .6))

# ---------- meshes ----------

## Walkable ground mesh with matching trimesh collision, as children of `body`.
static func build_ground(body: StaticBody3D) -> void:
	var mesh := _grid_mesh(-INNER_EXTENT, INNER_EXTENT, INNER_STEP, -1.0)
	var visual := MeshInstance3D.new()
	visual.name = "SiteGround"
	visual.mesh = mesh
	visual.material_override = _ground_material()
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "SiteGround_collision"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)

## Coarse horizon beyond the walkable ground (no collision; past the boundary).
static func build_horizon() -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = "SiteHorizon"
	visual.mesh = _grid_mesh(-OUTER_EXTENT, OUTER_EXTENT, OUTER_STEP, INNER_EXTENT)
	visual.material_override = _ground_material()
	return visual

## Vertex colours (the site's own shading) plus procedural grit, ripples and
## rock layers from shaders/mars_ground.gdshader.
static func _ground_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("style", 1 if shape() == "ice" else 0)   # frost and frozen polygons
	return material

## Smooth-shaded grid: each vertex gets a normal from the height field and
## its own colour, so the ground rolls instead of showing 3 m facets. Quads
## entirely inside ±skip_inside are left out (the finer walkable mesh covers them).
static func _grid_mesh(from: float, to: float, step: float, skip_inside: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := roundi((to - from) / step)
	var side := count + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for zi in range(side):
		for xi in range(side):
			heights[zi * side + xi] = height(from + xi * step, from + zi * step)
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	normals.resize(side * side)
	colours.resize(side * side)
	for zi in range(side):
		for xi in range(side):
			var x := from + xi * step
			var z := from + zi * step
			var left := heights[zi * side + maxi(xi - 1, 0)]
			var right := heights[zi * side + mini(xi + 1, count)]
			var back := heights[maxi(zi - 1, 0) * side + xi]
			var front := heights[mini(zi + 1, count) * side + xi]
			var normal := Vector3(left - right, 2.0 * step, back - front).normalized()
			normals[zi * side + xi] = normal
			colours[zi * side + xi] = ground_colour(Vector2(x, z), heights[zi * side + xi], 1.0 - absf(normal.y))
	for zi in range(count):
		for xi in range(count):
			var x0 := from + xi * step
			var z0 := from + zi * step
			if skip_inside > 0.0 and x0 >= -skip_inside and x0 + step <= skip_inside and z0 >= -skip_inside and z0 + step <= skip_inside:
				continue
			var corners := [zi * side + xi, zi * side + xi + 1, (zi + 1) * side + xi, (zi + 1) * side + xi + 1]
			for triangle in [[0, 1, 3], [0, 3, 2]]:
				for corner in triangle:
					var index: int = corners[corner]
					var gx := index % side
					var gz := index / side
					surface.set_color(colours[index])
					surface.set_normal(normals[index])
					surface.add_vertex(Vector3(from + gx * step, heights[index], from + gz * step))
	return surface.commit()

# ---------- rocks ----------

## Deterministic rock scatter for the site, kept off the build pad:
## [{mesh, position: Vector3, scale, yaw}].
static func rock_placements() -> Array:
	var s := settings()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(MHGame.site().get("id", "plains")))
	var placements: Array = []
	var wanted := int(s.get("rock_count", 70))
	var attempts := 0
	while placements.size() < wanted and attempts < wanted * 30:
		attempts += 1
		var p := Vector2(rng.randf_range(-118.0, 118.0), rng.randf_range(-118.0, 118.0))
		if p.length() > 120.0: continue
		if shape() == "crater":
			# Crater floor stays clear except on the mound itself.
			if p.length() < float(s.get("pad_radius", 45.0)) + 4.0 and _mound_distance(p) > float(s.get("mound_radius", 11.0)): continue
		elif _pad_distance(p) < 4.0: continue
		# Canyon rubble gathers at the foot of the walls.
		if shape() == "canyon" and rng.randf() < .6 and absf(p.x) > 48.0: continue
		var scale := rng.randf_range(.7, 1.6) * float(s.get("rock_scale", 1.0))
		if rng.randf() < .12: scale *= 1.8
		placements.append({"mesh": ROCK_MODELS[rng.randi() % ROCK_MODELS.size()], "position": Vector3(p.x, height(p.x, p.y) - .15 * scale, p.y), "scale": scale, "yaw": rng.randf_range(0.0, 360.0)})
	return placements
