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
const INNER_STEP_PLAINS := 2.0   # finer ground for the realistic Open Plains (craters, ledges)
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

# ---------- Open Plains (realistic pass, 24 Oct) ----------
# Modelled on Elysium Planitia (InSight's landing site): gently rolling lava
# plains peppered with impact craters, low wrinkle ridges, and eroded mesas
# with broken cliffs, ledges and slopes of fallen rock at their feet. Real
# noise (FastNoiseLite) instead of layered sines; distant hills close the
# horizon so the edge of the map never shows.

static var _plains_noise: FastNoiseLite
static var _plains_ridges: FastNoiseLite
static var _plains_detail: FastNoiseLite
static var _plains_craters: Array = []

static func _plains_setup() -> void:
	if _plains_noise != null: return
	_plains_noise = FastNoiseLite.new()
	_plains_noise.seed = 7; _plains_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_plains_noise.frequency = 1.0 / 170.0; _plains_noise.fractal_type = FastNoiseLite.FRACTAL_FBM; _plains_noise.fractal_octaves = 4
	_plains_ridges = FastNoiseLite.new()
	_plains_ridges.seed = 19; _plains_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_plains_ridges.frequency = 1.0 / 260.0; _plains_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED; _plains_ridges.fractal_octaves = 3
	_plains_detail = FastNoiseLite.new()
	_plains_detail.seed = 31; _plains_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_plains_detail.frequency = 1.0 / 23.0; _plains_detail.fractal_type = FastNoiseLite.FRACTAL_FBM; _plains_detail.fractal_octaves = 3
	# Craters: many small, few large (as on real Mars), never on the build pad.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var half := float(settings().get("pad_half", 60.0))
	var tries := 0
	while _plains_craters.size() < 70 and tries < 4000:
		tries += 1
		var radius := 3.5 * pow(rng.randf(), -0.55)
		radius = minf(radius, 34.0)
		var centre := Vector2(rng.randf_range(-420.0, 420.0), rng.randf_range(-420.0, 420.0))
		var gap := Vector2(maxf(0.0, absf(centre.x) - half), maxf(0.0, absf(centre.y) - half)).length()
		if gap < radius * 1.6 + 10.0: continue
		var on_mesa := false
		for mesa in settings().get("mesas", []):
			if centre.distance_to(Vector2(float(mesa[0]), float(mesa[1]))) < float(mesa[2]) + radius + 14.0: on_mesa = true
		if on_mesa: continue
		_plains_craters.append([centre, radius, rng.randf_range(.16, .22)])
	# One big, old crater in view of the base.
	_plains_craters.append([Vector2(-138.0, 46.0), 30.0, .14])

## Fresh-looking crater: a bowl, a raised rim and a fading ejecta apron.
static func _crater_profile(d: float, radius: float, depth_ratio: float) -> float:
	var x := d / radius
	if x >= 2.6: return 0.0
	var depth := radius * depth_ratio
	var rim := radius * .07
	if x < 1.0:
		return -depth * (1.0 - x * x) + rim * smoothstep(.55, 1.0, x)
	return rim * exp(-pow((x - 1.0) / .38, 2.0))

## 0-1: how much of a crater's floor (dark sand gathers there) or rim and
## ejecta (pale, rocky) a point is on: Vector2(floor, ejecta).
static func plains_crater_marks(p: Vector2) -> Vector2:
	_plains_setup()
	var floor_mark := 0.0
	var ejecta := 0.0
	for crater in _plains_craters:
		var d: float = p.distance_to(crater[0])
		var radius: float = crater[1]
		if d > radius * 2.6: continue
		var x := d / radius
		floor_mark = maxf(floor_mark, 1.0 - smoothstep(.45, .85, x))
		ejecta = maxf(ejecta, smoothstep(.75, 1.0, x) * (1.0 - smoothstep(1.0, 2.4, x)))
	return Vector2(floor_mark, ejecta)

## An eroded mesa: a wobbly outline, a cliff with one ledge, and a talus apron.
static func _mesa_height(p: Vector2, centre: Vector2, radius: float, top: float, seed_offset: int) -> float:
	var to := p - centre
	var d := to.length()
	if d > radius + 40.0: return 0.0
	var angle := atan2(to.y, to.x)
	# Bays and spurs along the edge, like a real eroded escarpment.
	var edge := radius * (1.0 + .16 * sin(angle * 3.0 + seed_offset) + .08 * sin(angle * 5.0 + seed_offset * 2.1))
	var over := d - edge
	var h := 0.0
	if over <= 0.0:
		h = top + _plains_detail.get_noise_2d(p.x, p.y) * .8
	else:
		# Cliff (steep) down to a ledge at 60%, a second cliff, then fallen rock.
		var ledge_w := 4.0 + 3.0 * (sin(angle * 2.0 + seed_offset) * .5 + .5)
		var ledge_top := top * .6
		# Cliffs span three mesh cells, so their edges stay clean (no saw teeth).
		if over < 6.0: h = lerpf(top, ledge_top, smoothstep(0.0, 6.0, over))
		elif over < 6.0 + ledge_w: h = ledge_top - (over - 6.0) * .3
		elif over < 11.0 + ledge_w: h = lerpf(ledge_top - ledge_w * .3, top * .28, smoothstep(6.0 + ledge_w, 11.0 + ledge_w, over))
		else:
			var talus := over - (11.0 + ledge_w)
			h = top * .3 * (1.0 - smoothstep(0.0, 22.0, talus)) + _plains_detail.get_noise_2d(p.x * 2.0, p.y * 2.0) * .6 * (1.0 - smoothstep(0.0, 22.0, talus))
	return maxf(h, 0.0)

static func _plains_height(p: Vector2) -> float:
	_plains_setup()
	var outside := _rise(p, PAD_MARGIN, 40.0)
	if outside <= 0.0: return 0.0
	# Gently rolling ground, low wrinkle ridges and small bumps.
	var h := 2.2 + _plains_noise.get_noise_2d(p.x, p.y) * 6.0
	h += pow(maxf(0.0, _plains_ridges.get_noise_2d(p.x, p.y)), 2.0) * 7.0
	h += _plains_detail.get_noise_2d(p.x, p.y) * .7
	for crater in _plains_craters:
		var d: float = p.distance_to(crater[0])
		if d < float(crater[1]) * 2.6: h += _crater_profile(d, crater[1], crater[2])
	# Hills close the horizon (beyond where you can walk).
	var r := p.length()
	h += smoothstep(190.0, 620.0, r) * (34.0 + _plains_noise.get_noise_2d(p.x * .4 + 300.0, p.y * .4) * 30.0) + smoothstep(480.0, 720.0, r) * 45.0
	h *= outside
	for index in range((settings().get("mesas", []) as Array).size()):
		var mesa: Array = settings().mesas[index]
		h = maxf(h, _mesa_height(p, Vector2(float(mesa[0]), float(mesa[1])), float(mesa[2]), float(mesa[3]), index * 7 + 3))
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

# ---------- Ice Fields: "the ice frontier" (realistic pass, 24 Oct) ----------
# Real places, combined: a cliff of exposed, banded water ice under a thin
# dusty cap (the mid-latitude ice scarps HiRISE found in 2018); mesas wrapped
# in debris-covered glaciers (Deuteronilus Mensae); small fresh craters that
# dug up bright ice, with dark blast halos (Arcadia Planitia), placed just
# outside the build area beside the richest buried ice; and on the eastern
# horizon a crater filled with a dome of ice (Korolev). Polygon ground in
# between, as at Utopia Planitia and the Phoenix landing site.

const ICE_CLIFF_X := -104.0
const ICE_CLIFF_TOP := 26.0
const KOROLEV := Vector3(330.0, -150.0, 120.0)   # x, z, radius
static var _ice_craters: Array = []
static var _ice_mesas: Array = [[Vector2(-20.0, -158.0), 16.0, 18.0], [Vector2(70.0, 168.0), 14.0, 15.0]]

static func _ice_setup() -> void:
	_plains_setup()
	if not _ice_craters.is_empty(): return
	# Beside each buried ice deposit, just outside the build area.
	var half := float(settings().get("pad_half", 70.0)) + PAD_MARGIN
	for deposit in MHGame.site().get("ice_deposits", []):
		var at := Vector2(float(deposit.x), float(deposit.z))
		var out := at.normalized() if at.length() > 1.0 else Vector2.RIGHT
		var edge := half / maxf(absf(out.x), absf(out.y))
		_ice_craters.append([at + out * (edge - at.length() + 16.0), 5.5 + float(deposit.richness) * 3.0, .22])
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	while _ice_craters.size() < 9:
		var c := Vector2(rng.randf_range(-118.0, 118.0), rng.randf_range(-118.0, 118.0))
		if absf(c.x) < half + 10.0 and absf(c.y) < half + 10.0: continue
		if c.x < ICE_CLIFF_X + 20.0: continue
		_ice_craters.append([c, rng.randf_range(3.0, 6.0), .2])

## Where the ice cliff's foot runs (scalloped, as sublimation carves alcoves).
static func _ice_cliff_line(z: float) -> float:
	return ICE_CLIFF_X + 7.0 * sin(z * .035) + 4.0 * sin(z * .09 + 1.0)

## Masks for the ground shader: Vector3(exposed ice face, bright ice, glacier rubble).
static func ground_masks(p: Vector2, h: float) -> Vector3:
	if shape() != "ice": return Vector3.ZERO
	_ice_setup()
	var face := 0.0
	var d := _ice_cliff_line(p.y) - p.x
	if d > -1.0 and d < 7.0 and h > 3.0 and h < ICE_CLIFF_TOP - 1.5: face = 1.0
	var bright := 0.0
	for crater in _ice_craters:
		var x: float = p.distance_to(crater[0]) / float(crater[1])
		bright = maxf(bright, 1.0 - smoothstep(.3, .55, x))
	var k := p.distance_to(Vector2(KOROLEV.x, KOROLEV.y)) / KOROLEV.z
	bright = maxf(bright, 1.0 - smoothstep(.7, .85, k))
	var rubble := 0.0
	for mesa in _ice_mesas:
		var md := p.distance_to(mesa[0])
		rubble = maxf(rubble, smoothstep(float(mesa[1]) - 2.0, float(mesa[1]) + 2.0, md) * (1.0 - smoothstep(float(mesa[1]) + 38.0, float(mesa[1]) + 48.0, md)))
	return Vector3(face, bright, rubble)

static func _ice_height(p: Vector2) -> float:
	_ice_setup()
	var outside := _rise(p, PAD_MARGIN, 45.0)
	var h := 0.0
	if outside > 0.0:
		# Gentle swells; polygon troughs only shallow, as on the real plains.
		h = 1.2 + _plains_noise.get_noise_2d(p.x + 500.0, p.y) * 2.6 + _plains_detail.get_noise_2d(p.x, p.y) * .4
		h -= (1.0 - smoothstep(.0, .9, _polygon_edge_distance(p))) * .35
		for crater in _ice_craters:
			var d: float = p.distance_to(crater[0])
			if d < float(crater[1]) * 2.6: h += _crater_profile(d, crater[1], crater[2])
		# Hills close the horizon.
		var r := p.length()
		h += smoothstep(200.0, 620.0, r) * (22.0 + _plains_noise.get_noise_2d(p.x * .4, p.y * .4 + 200.0) * 22.0) + smoothstep(480.0, 720.0, r) * 40.0
		h *= outside
	# The ice cliff: a talus of fallen blocks, a steep face of exposed ice, a dusty plateau.
	var d := _ice_cliff_line(p.y) - p.x
	if d > -14.0:
		var top := ICE_CLIFF_TOP + _plains_noise.get_noise_2d(p.x * 2.0, p.y * 2.0) * 3.0
		var cliff := 0.0
		if d < 0.0: cliff = 5.0 * smoothstep(-14.0, 0.0, d) + _plains_detail.get_noise_2d(p.x * 3.0, p.y * 3.0) * .8 * smoothstep(-14.0, -2.0, d)
		elif d < 5.0: cliff = lerpf(5.0, top, smoothstep(0.0, 5.0, d))
		else: cliff = top + smoothstep(5.0, 60.0, d) * 6.0
		h = maxf(h, cliff)
	# Mesas wrapped in debris-covered glaciers: lobes with ridges and pits.
	for index in range(_ice_mesas.size()):
		var mesa: Array = _ice_mesas[index]
		var md := p.distance_to(mesa[0])
		if md > float(mesa[1]) + 52.0: continue
		var apron_end := float(mesa[1]) + 42.0 + 6.0 * sin(atan2(p.y - mesa[0].y, p.x - mesa[0].x) * 4.0 + index)
		var lobe := pow(maxf(0.0, 1.0 - smoothstep(float(mesa[1]), apron_end, md)), .55) * 8.0
		if lobe > 0.0:
			lobe += sin(md * 1.1) * .35 * (1.0 - smoothstep(apron_end - 8.0, apron_end, md))   # flow ridges
			lobe -= maxf(0.0, _plains_detail.get_noise_2d(p.x * 2.5, p.y * 2.5) - .25) * 1.6   # sublimation pits
		h = maxf(h, maxf(lobe, _mesa_height(p, mesa[0], float(mesa[1]), float(mesa[2]), index * 5 + 11)))
	# Korolev on the horizon: a raised rim round a dome of ice.
	var kd := p.distance_to(Vector2(KOROLEV.x, KOROLEV.y)) / KOROLEV.z
	if kd < 2.2:
		var rim := 46.0 * exp(-pow((kd - 1.0) / .22, 2.0))
		var dome := 62.0 * maxf(0.0, 1.0 - kd * kd / (.85 * .85))
		# Keep the horizon hills low round it, so it stands clear.
		h = lerpf(minf(h, 12.0), h, smoothstep(1.4, 2.2, kd))
		h = maxf(h, maxf(rim, dome))
	return h

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
			# Patterned ground: each frozen polygon its own shade, with slightly
			# darker troughs (subtle, as in the Phoenix lander's photos).
			colour = base.darkened(.04 + .06 * _polygon_shade(p)).lerp(Color("#6E5548"), (1.0 - smoothstep(.4, 1.6, _polygon_edge_distance(p))) * .18)
			_ice_setup()
			# Dark blast halos round the fresh ice craters.
			for crater in _ice_craters:
				var x: float = p.distance_to(crater[0]) / float(crater[1])
				if x < 7.0: colour = colour.darkened(.22 * smoothstep(1.0, 1.4, x) * (1.0 - smoothstep(2.5, 7.0, x)))
			var masks := ground_masks(p, h)
			colour = colour.lerp(Color("#C9D0D3"), masks.y * .8)
			colour = colour.lerp(Color("#7A6A60"), masks.z * .55)
			# The plateau's dusty cap above the ice cliff.
			if _ice_cliff_line(p.y) - p.x > 4.0 and h > ICE_CLIFF_TOP - 2.0: colour = colour.darkened(.12)
		_:
			# Open Plains: butterscotch dust, darker basaltic sand in crater
			# floors and hollows, paler ejecta round crater rims, and layered
			# rock on the mesas.
			var marks := plains_crater_marks(p)
			colour = colour.lerp(Color("#5E4537"), marks.x * .55)
			colour = colour.lerp(Color("#B9967A"), marks.y * .35)
			if h > 5.0 and slope > .25: colour = colour.darkened(.05).lerp(Color("#8A6550"), .4)
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
## Generated ground meshes are the same every time for a site, so they're
## cached in user://terrain_cache (about 0.6 s off every load). The key
## includes this script's own text and the site's settings, so any change to
## the terrain makes a fresh cache.
const CACHE_DIR := "user://terrain_cache"

static func _cache_key(tag: String) -> String:
	var source := FileAccess.get_file_as_string("res://scripts/site_terrain.gd")
	if source.is_empty(): return ""   # exported build without sources: just generate
	return "%s/%s_%s_%d.res" % [CACHE_DIR, str(MHGame.site().get("id", "site")), tag, hash([source, settings(), MHGame.site().get("ice_deposits", [])])]

static func _cached(tag: String, make: Callable) -> Resource:
	var path := _cache_key(tag)
	if not path.is_empty() and FileAccess.file_exists(path):
		var cached := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if cached != null: return cached
	var made: Resource = make.call()
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
		ResourceSaver.save(made, path)
	return made

static func build_ground(body: StaticBody3D) -> void:
	var step := INNER_STEP_PLAINS if shape() in ["plains", "ice"] else INNER_STEP
	var mesh: ArrayMesh = _cached("ground", func() -> ArrayMesh: return _grid_mesh(-INNER_EXTENT, INNER_EXTENT, step, -1.0))
	var visual := MeshInstance3D.new()
	visual.name = "SiteGround"
	visual.mesh = mesh
	visual.material_override = _ground_material()
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "SiteGround_collision"
	collision.shape = _cached("ground_shape", func() -> Shape3D: return mesh.create_trimesh_shape())
	body.add_child(collision)

## Coarse horizon beyond the walkable ground (no collision; past the boundary).
static func build_horizon() -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = "SiteHorizon"
	visual.mesh = _cached("horizon", func() -> ArrayMesh: return _grid_mesh(-OUTER_EXTENT, OUTER_EXTENT, OUTER_STEP, INNER_EXTENT))
	visual.material_override = _ground_material()
	return visual

## Vertex colours (the site's own shading) plus procedural grit, ripples and
## rock layers from shaders/mars_ground.gdshader.
static func _ground_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("style", 1 if shape() == "ice" else (2 if shape() == "plains" else 0))   # 1: frost; 2: realistic plains
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
	var masks := PackedVector3Array()
	normals.resize(side * side)
	colours.resize(side * side)
	masks.resize(side * side)
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
			masks[zi * side + xi] = ground_masks(Vector2(x, z), heights[zi * side + xi])
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
					surface.set_uv(Vector2(masks[index].x, masks[index].y))
					surface.set_uv2(Vector2(masks[index].z, 0.0))
					surface.set_normal(normals[index])
					surface.add_vertex(Vector3(from + gx * step, heights[index], from + gz * step))
	return surface.commit()

# ---------- rocks ----------

## Open Plains rocks: many small, few big (a power law, like real boulder
## fields), gathered round crater rims and at the feet of the mesas, part
## buried and tilted to the ground. Off the build pad. Each placement may carry
## "tilt" (radians, x and z) and "stretch" (a non-uniform scale).
static func _plains_rocks() -> Array:
	_plains_setup()
	var hotspots: Array = []
	for crater in _plains_craters:
		if (crater[0] as Vector2).length() < 150.0: hotspots.append([crater[0], float(crater[1]) * 1.1, float(crater[1]) * .5])
	for mesa in settings().get("mesas", []):
		hotspots.append([Vector2(float(mesa[0]), float(mesa[1])), float(mesa[2]) + 12.0, 9.0])
	return _scatter_rocks(hotspots, 2024)

## Many small rocks and few big ones, about half gathered round hotspots
## ([centre, ring radius, spread]), part buried and leaning with the ground.
static func _scatter_rocks(hotspots: Array, seed_value: int) -> Array:
	var s := settings()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placements: Array = []
	var wanted := int(s.get("rock_count", 240))
	var attempts := 0
	while placements.size() < wanted and attempts < wanted * 40:
		attempts += 1
		var p: Vector2
		if rng.randf() < .55 and not hotspots.is_empty():
			var spot: Array = hotspots[rng.randi() % hotspots.size()]
			var angle := rng.randf() * TAU
			p = (spot[0] as Vector2) + Vector2.from_angle(angle) * (float(spot[1]) + rng.randf_range(-1.0, 1.0) * float(spot[2]))
		else:
			p = Vector2(rng.randf_range(-122.0, 122.0), rng.randf_range(-122.0, 122.0))
		if p.length() > 124.0 or _pad_distance(p) < 3.0: continue
		var size := clampf(.35 * pow(rng.randf(), -0.45), .3, 2.2) * float(s.get("rock_scale", 1.0))
		var ground := height(p.x, p.y)
		# Sit into the ground and lean with the slope.
		var e := 1.0
		var tilt := Vector2(atan2(height(p.x, p.y + e) - ground, e), -atan2(height(p.x + e, p.y) - ground, e))
		tilt += Vector2(rng.randf_range(-.12, .12), rng.randf_range(-.12, .12))
		placements.append({"mesh": ROCK_MODELS[rng.randi() % ROCK_MODELS.size()], "position": Vector3(p.x, ground - .12 * size, p.y), "scale": size, "yaw": rng.randf_range(0.0, 360.0),
			"tilt": tilt, "stretch": Vector3(rng.randf_range(.85, 1.2), rng.randf_range(.7, 1.1), rng.randf_range(.85, 1.2))})
	return placements

## Ice Fields rocks: a rock-strewn plain (Viking 2), fallen blocks at the
## foot of the ice cliff, and rubble along the glacier fronts.
static func _ice_rocks() -> Array:
	_ice_setup()
	var hotspots: Array = []
	for z in range(-120, 121, 12):
		hotspots.append([Vector2(_ice_cliff_line(float(z)) + 7.0, float(z)), 0.0, 6.0])
	for mesa in _ice_mesas:
		hotspots.append([mesa[0], float(mesa[1]) + 42.0, 5.0])
	for crater in _ice_craters:
		hotspots.append([crater[0], float(crater[1]) * 1.2, float(crater[1]) * .5])
	return _scatter_rocks(hotspots, 2031)

## Small stones near you (no collision): [Transform3D]. Open Plains and Ice Fields.
static func pebble_transforms(count := 3500) -> Array:
	if not shape() in ["plains", "ice"]: return []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out: Array = []
	var attempts := 0
	while out.size() < count and attempts < count * 4:
		attempts += 1
		var p := Vector2(rng.randf_range(-118.0, 118.0), rng.randf_range(-118.0, 118.0))
		if p.length() > 120.0 or _pad_distance(p) < 1.5: continue
		# More stones on rims and ejecta, fewer in sand-filled hollows.
		var marks := plains_crater_marks(p) if shape() == "plains" else Vector2.ZERO
		if rng.randf() < marks.x * .7: continue
		var size := rng.randf_range(.07, .3) * (1.0 + marks.y)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-.4, .4), rng.randf_range(0.0, TAU), rng.randf_range(-.4, .4))).scaled(Vector3(size, size * rng.randf_range(.5, .9), size * rng.randf_range(.8, 1.2)))
		out.append(Transform3D(basis, Vector3(p.x, height(p.x, p.y) - size * .25, p.y)))
	return out

## Deterministic rock scatter for the site, kept off the build pad:
## [{mesh, position: Vector3, scale, yaw}].
static func rock_placements() -> Array:
	if shape() == "plains": return _plains_rocks()
	if shape() == "ice": return _ice_rocks()
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
