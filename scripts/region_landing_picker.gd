extends Control

## The Land step on a region site (docs/landing-and-base-siting.md §5.1): the
## region map with the suggested landing zones marked, zoomed to 2.4 km
## round the oval (the mouse wheel shows the whole region). Click or drag to
## place the landing oval:
## the reach of the descent. It shows where in it a base could go, and its
## verdict. The precursor cargo came down at the oval's centre.
## Everything here is in region metres.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CLOSE := 2400.0                 # metres across, zoomed in
const OVAL := Vector2(400.0, 250.0)   # half axes, metres: long east-west (the approach)
const SAMPLE := 70.0                  # metres between the points checked for base ground
## Rocks that formed in or were changed by water (data/discoveries.json rock types).
const WATER_ROCKS := ["hematite", "gypsum", "conglomerate", "sandstone", "mudstone", "clay", "sulfur", "perchlorate_crust"]
## Mission Control's word on each suggested zone, from orbit.
## Only the plains are a landing site now (A6, docs/opening-days.md): the
## crater floor and the riverbed went; their zones stay in region.json until
## the next region rebuild, but aren't shown.
const HINTS := {"plains": "Open ground, strong sun"}

signal area_changed(centre: Vector2, verdict: Dictionary)

var centre := Vector2.INF
var verdict := {}
var _map: Texture2D
var _detail: Texture2D
var _half := 3072.0
var _zoomed := true
var _view := Rect2()   # the part of the region shown (region metres)
var _dragging := false
## The story game's Arrive step (A6): a fixed view of the home area, the
## circle you can steer the descent in, and its landmarks. Nothing moves.
var _home_radius := 0.0

## Show the home area round centre, radius metres, for looking at only.
## Call before adding it to the tree.
func home_view(at: Vector2, radius: float) -> void:
	_home_radius = radius
	centre = at

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var RT := MHSiteTerrain.RegionTerrain
	MHSiteTerrain.region_zone()   # loads the region
	_half = float(RT.meta().get("half", 3072.0))
	_map = load(RT.DIRECTORY + str(RT.meta().get("id", "")) + "/map.png") as Texture2D
	_detail = load(RT.DIRECTORY + str(RT.meta().get("id", "")) + "/map_detail.jpg") as Texture2D
	if _home_radius > 0.0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view = Rect2(centre - Vector2.ONE * _home_radius * 1.3, Vector2.ONE * _home_radius * 2.6)
		queue_redraw()
		return
	var zone := RT.zone(str(MHSiteTerrain.settings().get("zone", "")))
	var start := Vector2(float(zone.centre[0]), float(zone.centre[1])) if not zone.is_empty() else Vector2.ZERO
	_look_at(start)
	set_area(start)

## Zoomed: the CLOSE metres round point (kept inside the region); else the whole region.
func _look_at(point: Vector2) -> void:
	if not _zoomed:
		_view = Rect2(-_half, -_half, _half * 2.0, _half * 2.0)
	else:
		var corner := (point - Vector2(CLOSE, CLOSE) * .5).clamp(Vector2(-_half, -_half), Vector2(_half - CLOSE, _half - CLOSE))
		_view = Rect2(corner, Vector2(CLOSE, CLOSE))
	queue_redraw()

func set_area(point: Vector2) -> void:
	var keep := _half - MHBaseSite.EDGE_CLEAR
	centre = point.clamp(Vector2(-keep, -keep), Vector2(keep, keep))
	verdict = evaluate(centre)
	queue_redraw()
	area_changed.emit(centre, verdict)

## The base ground inside an oval round centre: {level (green, orange or
## red), text, spots (the valid points, nearest the centre first), best}.
static func evaluate(at: Vector2) -> Dictionary:
	var spots: Array = []
	var total := 0
	for i in range(-ceili(OVAL.x / SAMPLE), ceili(OVAL.x / SAMPLE) + 1):
		for j in range(-ceili(OVAL.y / SAMPLE), ceili(OVAL.y / SAMPLE) + 1):
			var offset := Vector2(i, j) * SAMPLE
			if pow(offset.x / OVAL.x, 2) + pow(offset.y / OVAL.y, 2) > 1.0: continue
			total += 1
			if MHBaseSite.valid(at.x + offset.x, at.y + offset.y): spots.append(at + offset)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(at) < b.distance_to(at))
	var share := float(spots.size()) / maxf(total, 1)
	if spots.is_empty():
		return {"level": "red", "spots": spots, "best": Vector2.INF, "text": "No ground for a base here: too steep, rough or sandy everywhere in reach. Move the oval."}
	if share >= .25:
		return {"level": "green", "spots": spots, "best": spots[0], "text": "Plenty of ground for a base: %d%% of the oval is level and open." % roundi(share * 100.0)}
	return {"level": "orange", "spots": spots, "best": spots[0], "text": "Some ground for a base (%d%% of the oval). You'll steer for it on the way down." % roundi(share * 100.0)}

## Mission Control's orbital report on a base at spot (region metres):
## what the ground there means for living on it (MHBaseSite.conditions).
## Rows of [icon, what, text, level (green, orange or red)].
static func report(spot: Vector2) -> Array:
	if is_inf(spot.x): return []
	var local := MHBaseSite.conditions(spot.x, spot.y)
	var rows: Array = []
	# Water: the richest buried ice within reach.
	var best := {}
	for deposit in MHBaseSite.ice_deposits(spot.x, spot.y):
		if best.is_empty() or float(deposit.richness) > float(best.richness): best = deposit
	var far := Vector2(float(best.x), float(best.z)).length()
	var where := "right by the pad" if far < 40.0 else "%d m away" % roundi(far)
	var rich := float(best.richness)
	if rich >= .6: rows.append(["droplets", "Water", "Rich buried ice %s." % where, "green"])
	elif rich >= .4: rows.append(["droplets", "Water", "Some buried ice %s." % where, "orange"])
	else: rows.append(["droplets", "Water", "Only a thin layer of ground ice: water comes slowly at first.", "red"])
	# Sun: how much the skyline hides; frost on the panels at dawn.
	var sun := MHBaseSite.sunshine(local.horizon)
	var share := float(sun.share)
	var frost := " Heavy dawn frost on the panels." if float(local.frost_peak) >= .5 else ""
	var hidden := "Hills hide the low sun for %s a sol: %d%% less solar power." % [_hours(float(sun.hidden_hours)), roundi((1.0 - share) * 100.0)]
	if share >= .97: rows.append(["sun", "Sun", "Open sky: full sun all day." + frost, "green" if frost.is_empty() else "orange"])
	elif share >= .93: rows.append(["sun", "Sun", hidden + frost, "orange"])
	else: rows.append(["sun", "Sun", hidden.replace("Hills", "High walls") + frost, "red"])
	# Nights: walls give back the day's heat.
	var warmer := roundi(float(local.shelter_c))
	if warmer >= 4: rows.append(["moon", "Nights", "Sheltered by the walls: nights about %d °C warmer." % warmer, "green"])
	elif warmer >= 2: rows.append(["moon", "Nights", "A little shelter: nights about %d °C warmer." % warmer, "orange"])
	else: rows.append(["moon", "Nights", "Exposed: the coldest nights in the region.", "orange"])
	# Dust: dunes upwind, and open ground.
	var dust := float(local.dust_per_sol)
	if dust <= .015: rows.append(["wind", "Dust", "Little dust settles on the panels.", "green"])
	elif dust <= .021: rows.append(["wind", "Dust", "Some dust: brush the panels now and then.", "orange"])
	else: rows.append(["wind", "Dust", "Dunes upwind: the panels dust over fast.", "red"])
	# Room: open, gentle ground round the pad.
	var room := float(local.room)
	if room >= .9: rows.append(["house", "Room", "Open ground all round: room to grow.", "green"])
	elif room >= .78: rows.append(["house", "Room", "Some room: steep or sandy ground nearby.", "orange"])
	else: rows.append(["house", "Room", "Cramped: little level ground round the pad.", "red"])
	# Science: the kinds of rock within a walk, and a cave within a drive.
	var study := MHBaseSite.science(spot.x, spot.y)
	var kinds := (study.rocks as Array).size()
	# Rocks laid down or changed by water are what the science teams want most.
	var watery := (study.rocks as Array).filter(func(rock): return WATER_ROCKS.has(rock)).size()
	var cave := ", and the %s %s away" % [str(study.cave).to_lower(), MHSamples._distance(float(study.cave_m))] if float(study.cave_m) < MHBaseSite.CAVE_REACH else ""
	var level := "green" if watery >= 4 or (watery >= 2 and not cave.is_empty()) else ("orange" if watery >= 1 or not cave.is_empty() else "red")
	var words: String = {"green": "Rich ground for science", "orange": "Some science nearby", "red": "Little to study: mostly volcanic rock"}[level]
	rows.append(["flask-conical", "Science", "%s: %d kinds of rock within a walk, %d laid down by water%s." % [words, kinds, watery, cave], level])
	return rows

static func _hours(hours: float) -> String:
	if hours < .75: return "%d min" % maxi(10, roundi(hours * 6.0) * 10)
	return "about %s h" % (str(roundi(hours)) if absf(hours - roundi(hours)) < .25 else "%.1f" % hours)

## The best spot for the base: where the autopilot sets down when the
## descent is skipped (the nearest valid ground to the centre).
func touchdown() -> Vector2:
	var near := MHBaseSite.nearest_valid(centre.x, centre.y, minf(OVAL.x, OVAL.y))
	return near if not is_inf(near.x) else verdict.get("best", Vector2.INF)

# ---------- drawing and input ----------

func _square() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * .5, Vector2(side, side))

func _to_map(region: Vector2) -> Vector2:
	var square := _square()
	return square.position + (region - _view.position) / _view.size.x * square.size.x

func _to_region(at: Vector2) -> Vector2:
	var square := _square()
	return _view.position + (at - square.position) / square.size.x * _view.size.x

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoomed = event.button_index == MOUSE_BUTTON_WHEEL_UP
		_look_at(_to_region(event.position) if _zoomed else centre)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		set_area(_to_region(event.position))
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		# While dragging only the oval moves; the verdict follows on release.
		var keep := _half - MHBaseSite.EDGE_CLEAR
		centre = _to_region(event.position).clamp(Vector2(-keep, -keep), Vector2(keep, keep))
		verdict = {"level": "", "spots": []}
		queue_redraw()
		accept_event()

func _draw() -> void:
	var square := _square()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10171B"))
	var image := _detail if _zoomed and _detail != null else _map
	if image != null:
		var per_metre := image.get_width() / (_half * 2.0)
		draw_texture_rect_region(image, square, Rect2((_view.position + Vector2(_half, _half)) * per_metre, _view.size * per_metre))
	var font := ThemeDB.fallback_font
	var scale := square.size.x / _view.size.x
	if _home_radius > 0.0:
		_draw_home(font, scale)
		return
	# The suggested zones: known-good ground, with Mission Control's hint.
	var zones: Dictionary = MHSiteTerrain.RegionTerrain.meta().get("zones", {})
	for zone_id in zones:
		if not HINTS.has(zone_id): continue
		var zone: Dictionary = zones[zone_id]
		var at := _to_map(Vector2(float(zone.centre[0]), float(zone.centre[1])))
		if not square.grow(-8.0).has_point(at): continue
		draw_arc(at, 9.0, 0.0, TAU, 24, Color("#F2F4F5"), 2.0)
		draw_circle(at, 3.0, Color("#F2F4F5"))
		var title := "Suggested: %s" % str(zone.get("label", zone_id))
		_text(font, title, at + Vector2(14, -2), 13, Color("#F2F4F5"))
		_text(font, str(HINTS.get(zone_id, "")), at + Vector2(14, 14), 11, Color("#C9D2D6"))
	if is_inf(centre.x): return
	# The oval: where the descent can reach.
	var colour: Color = {"green": MHStyle.VALID, "orange": MHStyle.WARN, "red": MHStyle.DANGER}.get(str(verdict.get("level", "")), Color("#F2F4F5"))
	var points := PackedVector2Array()
	for i in 65:
		var a := TAU * i / 64.0
		points.append(_to_map(centre + Vector2(cos(a) * OVAL.x, sin(a) * OVAL.y)))
	draw_colored_polygon(points, Color(colour, .14))
	draw_polyline(points, colour, 2.5)
	# Where a base could go.
	for spot in verdict.get("spots", []):
		draw_circle(_to_map(spot), maxf(2.0, SAMPLE * scale * .3), Color(MHStyle.VALID, .9))
	# The precursor cargo, at the centre.
	var at := _to_map(centre)
	draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), MHStyle.accent)
	draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color.WHITE, false, 1.5)
	_text(font, "Cargo", at + Vector2(-16, 22), 12, Color.WHITE)
	# North arrow and a 1 km scale bar.
	var north := square.position + Vector2(square.size.x - 26, 30)
	draw_colored_polygon(PackedVector2Array([north + Vector2(0, -14), north + Vector2(7, 6), north + Vector2(-7, 6)]), Color("#F2F4F5"))
	_text(font, "N", north + Vector2(-5, 24), 14, Color("#F2F4F5"))
	var metres := 500.0 if _zoomed else 1000.0
	var bar := metres * scale
	var foot := square.position + Vector2(16, square.size.y - 18)
	draw_line(foot, foot + Vector2(bar, 0), Color("#F2F4F5"), 3.0)
	_text(font, "%d m" % roundi(metres) if metres < 1000.0 else "1 km", foot + Vector2(bar + 6, 5), 13, Color("#F2F4F5"))
	_text(font, "Scroll to zoom %s" % ("out" if _zoomed else "in"), square.position + Vector2(square.size.x - 130, square.size.y - 13), 12, Color("#C9D2D6"))

## The home area: the steering circle, home, and ring 1's landmarks
## (region.json "home_ground").
func _draw_home(font: Font, scale: float) -> void:
	var white := Color("#F2F4F5")
	var soft := Color("#C9D2D6")
	var ground: Dictionary = MHSiteTerrain.RegionTerrain.meta().get("home_ground", {})
	var channel: Array = ground.get("channel", [])
	if channel.size() > 1:
		var line := PackedVector2Array()
		for p in channel: line.append(_to_map(Vector2(float(p[0]), float(p[1]))))
		draw_polyline(line, Color("#7FB3D5", .8), 2.0)
		var mid: Array = channel[channel.size() / 2]
		_text(font, "Dry channel", _to_map(Vector2(float(mid[0]), float(mid[1]))) + Vector2(8, 0), 12, soft)
	for c in ground.get("crossings", []):
		draw_circle(_to_map(Vector2(float(c[0]), float(c[1]))), 4.0, Color("#7FB3D5"))
	for item in [["frost_hollow", "Frost hollow: shallow ice", Color("#BFE3F2")], ["sand_sheet", "Sand sheet", Color("#D9B38C")]]:
		var spec: Array = ground.get(str(item[0]), [])
		if spec.size() < 3: continue
		var at := _to_map(Vector2(float(spec[0]), float(spec[1])))
		draw_arc(at, float(spec[2]) * scale, 0.0, TAU, 32, item[2], 1.5)
		_text(font, str(item[1]), at + Vector2(float(spec[2]) * scale + 6, 4), 12, item[2])
	var points := PackedVector2Array()
	for i in 65:
		var a := TAU * i / 64.0
		points.append(_to_map(centre + Vector2(cos(a), sin(a)) * _home_radius))
	draw_colored_polygon(points, Color(MHStyle.VALID, .10))
	draw_polyline(points, MHStyle.VALID, 2.5)
	var at := _to_map(centre)
	draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), MHStyle.accent)
	draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color.WHITE, false, 1.5)
	_text(font, "The cargo's target", at + Vector2(-50, 22), 12, white)
	_text(font, "You can steer anywhere in the circle", _to_map(centre + Vector2(-_home_radius * .8, _home_radius * 1.15)), 13, white)
	var square := _square()
	var north := square.position + Vector2(square.size.x - 26, 30)
	draw_colored_polygon(PackedVector2Array([north + Vector2(0, -14), north + Vector2(7, 6), north + Vector2(-7, 6)]), white)
	_text(font, "N", north + Vector2(-5, 24), 14, white)
	var foot := square.position + Vector2(16, square.size.y - 18)
	draw_line(foot, foot + Vector2(500.0 * scale, 0), white, 3.0)
	_text(font, "500 m", foot + Vector2(500.0 * scale + 6, 5), 13, white)

func _text(font: Font, text: String, at: Vector2, font_size: int, colour: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, .8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
