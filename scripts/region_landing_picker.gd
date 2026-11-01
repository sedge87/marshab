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
## Mission Control's word on each suggested zone, from orbit.
const HINTS := {"plains": "Open ground, strong sun", "crater": "Layered outcrop nearby", "riverbed": "Old river deposits"}

signal area_changed(centre: Vector2, verdict: Dictionary)

var centre := Vector2.INF
var verdict := {}
var _map: Texture2D
var _detail: Texture2D
var _half := 3072.0
var _zoomed := true
var _view := Rect2()   # the part of the region shown (region metres)
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var RT := MHSiteTerrain.RegionTerrain
	MHSiteTerrain.region_zone()   # loads the region
	_half = float(RT.meta().get("half", 3072.0))
	_map = load(RT.DIRECTORY + str(RT.meta().get("id", "")) + "/map.png") as Texture2D
	_detail = load(RT.DIRECTORY + str(RT.meta().get("id", "")) + "/map_detail.jpg") as Texture2D
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
	# The suggested zones: known-good ground, with Mission Control's hint.
	var zones: Dictionary = MHSiteTerrain.RegionTerrain.meta().get("zones", {})
	for zone_id in zones:
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

func _text(font: Font, text: String, at: Vector2, font_size: int, colour: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, .8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
