extends Control

# Live map drawn onto the Mars Survey Board's screen (a SubViewport), from
# real game state only: the site's build area and ice deposits, the
# habitat's rooms, the astronaut and the rover. "mars" mode marks the
# landing site on a schematic latitude/longitude globe.
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SITE_RADIUS := 50.0 # metres from the site centre shown edge to edge (height)

var mode := "site"
var _ground: Image
var _ground_texture: ImageTexture
var _ground_site := ""
var _rover: Node3D
var _since := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_since += delta
	if _since >= .5:
		_since = 0.0
		queue_redraw()

func _font() -> Font:
	return ThemeDB.fallback_font

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10171B"))
	if mode == "mars": _draw_mars()
	else: _draw_site()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#5E8C93"), false, 3.0)

# ---------- site map ----------

func _world_to_map(p: Vector2) -> Vector2:
	var scale := size.y / (SITE_RADIUS * 2.0)
	return size * .5 + p * scale

func _draw_site() -> void:
	# Ground: buildable cells pale, cliffs and mounds dark, cached per site.
	if _ground_site != MHGame.site_id: _build_ground()
	draw_texture_rect(_ground_texture, Rect2(_world_to_map(Vector2(-SITE_RADIUS * size.x / size.y, -SITE_RADIUS)), Vector2(size.x, size.y)), false)
	# Ice deposits.
	for deposit in MHGame.site().get("ice_deposits", []):
		var centre := _world_to_map(Vector2(float(deposit.x), float(deposit.z)))
		var radius := float(deposit.radius) * size.y / (SITE_RADIUS * 2.0)
		draw_circle(centre, radius, Color(.55, .85, 1.0, .18 + .3 * float(deposit.richness)))
		draw_arc(centre, radius, 0, TAU, 32, Color("#8FD8FF"), 1.5)
	# Rooms, in their site-plan colours.
	var builder := get_tree().get_first_node_in_group("habitat_builder") as BuildController
	if builder != null:
		for zone in builder.zones:
			var colour := BuildController.plan_colour(str(zone.get("kind", "")))
			if zone.has("angled_mount"):
				_fill(builder._angled_mount_outline(zone.angled_mount), colour)
				continue
			var outline := builder.zone_outline(zone)
			if not outline.is_empty():
				_fill(outline, colour)
				continue
			for cell in zone.get("cells", []):
				var c := Vector2(cell.x * 3.0, cell.y * 3.0)
				_fill(PackedVector2Array([c + Vector2(-1.5, -1.5), c + Vector2(1.5, -1.5), c + Vector2(1.5, 1.5), c + Vector2(-1.5, 1.5)]), colour)
	# Rover and astronaut.
	if _rover == null or not is_instance_valid(_rover):
		for node in get_tree().current_scene.get_children() if get_tree().current_scene != null else []:
			if node is MHCompanionRover: _rover = node
	if _rover != null:
		var at := _world_to_map(Vector2(_rover.global_position.x, _rover.global_position.z))
		draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color("#D9A441"))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var at := _world_to_map(Vector2(player.global_position.x, player.global_position.z))
		var facing := -player.global_transform.basis.z
		var ahead := Vector2(facing.x, facing.z).normalized()
		var side := Vector2(-ahead.y, ahead.x)
		draw_colored_polygon(PackedVector2Array([at + ahead * 12, at - ahead * 7 + side * 7, at - ahead * 7 - side * 7]), Color("#ED7C35"))
	# Title, north arrow, scale bar and legend.
	var font := _font()
	draw_string(font, Vector2(14, 28), "%s · %s" % [MHGame.site_name(), str(MHGame.site().get("based_on", ""))], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#F2F4F5"))
	draw_string(font, Vector2(14, 50), "Live site map · sol %s" % MHGame.formatted_sol_time(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9AA3A6"))
	var north := Vector2(size.x - 34, 44)
	draw_colored_polygon(PackedVector2Array([north + Vector2(0, -16), north + Vector2(8, 6), north + Vector2(-8, 6)]), Color("#F2F4F5"))
	draw_string(font, north + Vector2(-5, 26), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#F2F4F5"))
	var bar := 10.0 * size.y / (SITE_RADIUS * 2.0)
	draw_line(Vector2(14, size.y - 18), Vector2(14 + bar, size.y - 18), Color("#F2F4F5"), 3.0)
	draw_string(font, Vector2(20 + bar, size.y - 12), "10 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#F2F4F5"))
	var legend := [["You", Color("#ED7C35")], ["GAR-Y", Color("#D9A441")], ["Buried ice", Color("#8FD8FF")], ["Not buildable", Color("#4A2A22")]]
	var x := size.x - 150.0
	var y := size.y - 18.0 * legend.size() - 6.0
	for entry in legend:
		draw_rect(Rect2(Vector2(x, y - 10), Vector2(12, 12)), entry[1])
		draw_string(font, Vector2(x + 18, y), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#F2F4F5"))
		y += 18.0

func _fill(outline: PackedVector2Array, colour: Color) -> void:
	if outline.size() < 3: return
	var points := PackedVector2Array()
	for p in outline: points.append(_world_to_map(p))
	if Geometry2D.triangulate_polygon(points).is_empty(): return
	draw_colored_polygon(points, colour)
	points.append(points[0])
	draw_polyline(points, Color(colour.lightened(.4), .9), 1.5)

func _build_ground() -> void:
	_ground_site = MHGame.site_id
	var cells := 64
	var aspect := size.x / maxf(1.0, size.y)
	var width := int(cells * aspect)
	_ground = Image.create(width, cells, false, Image.FORMAT_RGB8)
	var step := SITE_RADIUS * 2.0 / cells
	for row in range(cells):
		for col in range(width):
			var p := Vector2((col - width * .5 + .5) * step, (row - cells * .5 + .5) * step)
			var buildable := MHSiteTerrain.is_buildable(p)
			var height := MHSiteTerrain.height(p.x, p.y)
			var colour := Color("#7A4A36") if buildable else Color("#4A2A22").lightened(clampf(height / 60.0, 0.0, .35))
			_ground.set_pixel(col, row, colour)
	_ground_texture = ImageTexture.create_from_image(_ground)

# ---------- Mars globe ----------

func _draw_mars() -> void:
	var font := _font()
	draw_string(font, Vector2(14, 28), "Where on Mars?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#F2F4F5"))
	draw_string(font, Vector2(14, 50), "Schematic latitude/longitude grid, not a real map", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9AA3A6"))
	var area := Rect2(Vector2(30, 66), size - Vector2(60, 96))
	draw_rect(area, Color("#5A3122"))
	for lat in range(-60, 61, 30):
		var y := area.position.y + area.size.y * (.5 - lat / 180.0)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(1, 1, 1, .25 if lat != 0 else .55), 1.0)
		draw_string(font, Vector2(area.position.x + 4, y - 3), "%d°" % lat, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, .6))
	for lon in range(-180, 181, 60):
		var x := area.position.x + area.size.x * (lon + 180.0) / 360.0
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(1, 1, 1, .2), 1.0)
	for entry in MHGame.sites():
		var at := _site_point(str(entry.get("coordinates", "")), area)
		if at.x < 0: continue
		var current := str(entry.get("id", "")) == MHGame.site_id
		draw_circle(at, 9.0 if current else 5.0, Color("#ED7C35") if current else Color("#D9DEE0"))
		# The current site is labelled below its dot so close neighbours stay
		# readable; labels near the right edge flip to the left of the dot.
		var label := str(entry.get("based_on", entry.get("name", "")))
		var font_size := 15 if current else 12
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var offset := Vector2(-width * .5, 26) if current else Vector2(10, 5)
		if at.x + offset.x + width > size.x - 8: offset = Vector2(-width * .5, 26) if current else Vector2(-width - 10, -8)
		offset.x = maxf(offset.x, 8 - at.x)
		if at.x + offset.x + width > size.x - 8: offset.x = size.x - 8 - width - at.x
		draw_string(font, at + offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#F2F4F5") if current else Color("#C9CED0"))
	draw_string(font, Vector2(30, size.y - 12), "Orange: this habitat · %s" % str(MHGame.site().get("coordinates", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#F2F4F5"))

## "3.0° N, 154.7° E" -> a point in the grid, or (-1,-1) if unreadable.
func _site_point(coordinates: String, area: Rect2) -> Vector2:
	var parts := coordinates.split(",")
	if parts.size() != 2: return Vector2(-1, -1)
	var lat := parts[0].to_float() * (-1.0 if parts[0].contains("S") else 1.0)
	var lon := parts[1].to_float() * (-1.0 if parts[1].contains("W") else 1.0)
	return Vector2(area.position.x + area.size.x * (lon + 180.0) / 360.0, area.position.y + area.size.y * (.5 - lat / 180.0))
