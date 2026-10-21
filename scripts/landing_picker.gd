extends Control

## Top-down site map for choosing where the crew lander comes down. Click (or
## drag) to set the target; the landing ellipse shows everywhere the lander
## might touch down, coloured by how safe that ground is.
## Survival (and Missions) land somewhere inside the ellipse; Freedom and
## Creative land exactly on target (see touchdown()).
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CREW_LANDER := preload("res://scripts/crew_lander.gd")
const ELLIPSE_A := 9.0     # metres east-west (the approach direction)
const ELLIPSE_B := 6.0     # metres north-south
const FOOTPRINT := 4.5     # the lander's legs reach this far from its centre
const VIEW_RADIUS := 55.0  # metres from the site centre to the map's top edge

signal target_changed(target: Vector2, verdict: Dictionary)

var target := Vector2.INF
var verdict := {}
## Missions (Mission 1): right-click places the base site, and the engine-blast
## zone around the ellipse is drawn.
var base_mode := false
var base_site := Vector2.INF
const BLAST_MARGIN := 12.0
var _ground: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void: _ground = null; queue_redraw())
	set_target(_suggested())

## A suggested target: the closest spot to the usual landing distance (about
## 18 m from the site centre) where the whole ellipse is safe, or failing
## that, the least risky one.
static func suggested() -> Vector2:
	var best := Vector2.INF
	var best_score := INF
	for x in range(-45, 46, 3):
		for z in range(-45, 46, 3):
			var point := Vector2(x, z)
			var verdict := evaluate(point)
			if str(verdict.level) == "red": continue
			var score := absf(point.length() - 18.0) + (0.0 if str(verdict.level) == "green" else 1000.0 + float(verdict.get("risk", 1.0)) * 100.0)
			if score < best_score:
				best_score = score
				best = point
	if is_inf(best.x):
		var spot: Dictionary = CREW_LANDER.find_spot()
		best = Vector2((spot.position as Vector3).x, (spot.position as Vector3).z)
	return best

func _suggested() -> Vector2:
	return suggested()

func set_target(point: Vector2) -> void:
	target = point
	verdict = evaluate(point)
	queue_redraw()
	target_changed.emit(target, verdict)

func use_suggested() -> void:
	set_target(_suggested())

# ---------- the safety check ----------

## Is the ground under a lander at this point usable? Every leg needs
## buildable, fairly level ground.
static func footprint_safe(point: Vector2) -> bool:
	var centre_height := MHSiteTerrain.height(point.x, point.y)
	for angle in range(0, 360, 45):
		var at := point + Vector2.from_angle(deg_to_rad(angle)) * FOOTPRINT
		if not MHSiteTerrain.is_buildable(at) or absf(MHSiteTerrain.height(at.x, at.y) - centre_height) > .8: return false
	return MHSiteTerrain.is_buildable(point)

## green: anywhere in the ellipse is safe; orange: some of the ellipse is
## risky (the lander may come down beside the target); red: the target itself
## is unsafe. Includes a plain-language reason.
static func evaluate(point: Vector2) -> Dictionary:
	if not footprint_safe(point):
		return {"level": "red", "text": "Too rough to land on: the lander's legs need flat, open ground."}
	var risky := 0
	var total := 0
	for x in range(-int(ELLIPSE_A), int(ELLIPSE_A) + 1, 2):
		for y in range(-int(ELLIPSE_B), int(ELLIPSE_B) + 1, 2):
			if (x * x) / (ELLIPSE_A * ELLIPSE_A) + (y * y) / (ELLIPSE_B * ELLIPSE_B) > 1.0: continue
			total += 1
			if not footprint_safe(point + Vector2(x, y)): risky += 1
	if risky == 0:
		return {"level": "green", "text": "Safe: the whole landing ellipse is flat, open ground."}
	return {"level": "orange", "risk": float(risky) / total, "text": "Risky: %d%% of the ellipse is near cliffs, mounds or rough ground. The lander may come down beside your target." % roundi(100.0 * risky / total)}

## Where the lander actually comes down. Survival and Missions: a random point
## inside the ellipse (moved back towards the target if that ground is unsafe);
## Freedom and Creative: exactly on target.
static func touchdown(point: Vector2, mode: String, rng: RandomNumberGenerator) -> Vector2:
	if mode == "freedom" or mode == "creative": return point
	var angle := rng.randf() * TAU
	var distance := sqrt(rng.randf())
	var landed := point + Vector2(cos(angle) * ELLIPSE_A, sin(angle) * ELLIPSE_B) * distance
	for step in range(10):
		if footprint_safe(landed): return landed
		landed = landed.lerp(point, .3)
	return point

# ---------- drawing ----------

func _metres_per_pixel() -> float:
	return VIEW_RADIUS * 2.0 / maxf(1.0, size.y)

func _to_map(point: Vector2) -> Vector2:
	return size * .5 + point / _metres_per_pixel()

func _to_world(at: Vector2) -> Vector2:
	return (at - size * .5) * _metres_per_pixel()

func set_base(point: Vector2) -> void:
	base_site = point
	queue_redraw()
	target_changed.emit(target, verdict)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and base_mode:
		set_base(_to_world(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_target(_to_world(event.position))
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		set_target(_to_world(event.position))
		accept_event()

func _build_ground() -> void:
	var rows := 96
	var cols := int(rows * size.x / maxf(1.0, size.y))
	var image := Image.create(maxi(cols, 1), rows, false, Image.FORMAT_RGB8)
	var step := VIEW_RADIUS * 2.0 / rows
	for row in range(rows):
		for col in range(cols):
			var p := Vector2((col - cols * .5 + .5) * step, (row - rows * .5 + .5) * step)
			var height := MHSiteTerrain.height(p.x, p.y)
			var colour := Color("#8A5236") if MHSiteTerrain.is_buildable(p) else Color("#4A2A22").lightened(clampf(height / 50.0, 0.0, .35))
			image.set_pixel(col, row, colour.lightened(clampf(height / 120.0, -.1, .1)))
	_ground = ImageTexture.create_from_image(image)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10171B"))
	if _ground == null: _build_ground()
	draw_texture_rect(_ground, Rect2(Vector2.ZERO, size), false)
	# Buried ice.
	for deposit in MHGame.site().get("ice_deposits", []):
		var centre := _to_map(Vector2(float(deposit.x), float(deposit.z)))
		var radius := float(deposit.radius) / _metres_per_pixel()
		draw_circle(centre, radius, Color(.55, .85, 1.0, .12 + .25 * float(deposit.richness)))
		draw_arc(centre, radius, 0, TAU, 40, Color("#8FD8FF"), 1.5)
	# The site centre, where most bases are built.
	var middle := _to_map(Vector2.ZERO)
	draw_line(middle - Vector2(8, 0), middle + Vector2(8, 0), Color(1, 1, 1, .35), 1.5)
	draw_line(middle - Vector2(0, 8), middle + Vector2(0, 8), Color(1, 1, 1, .35), 1.5)
	# Landing ellipse and target.
	if not is_inf(target.x):
		var colour: Color = {"green": MHStyle.VALID, "orange": MHStyle.WARN, "red": MHStyle.DANGER}.get(str(verdict.get("level", "red")), MHStyle.DANGER)
		var points := PackedVector2Array()
		for i in range(49):
			var a := TAU * i / 48.0
			points.append(_to_map(target + Vector2(cos(a) * ELLIPSE_A, sin(a) * ELLIPSE_B)))
		draw_colored_polygon(points, Color(colour, .22))
		draw_polyline(points, colour, 2.5)
		if base_mode:
			# Engine blast reaches BLAST_MARGIN beyond the ellipse: dashed ring.
			var blast := PackedVector2Array()
			for i in range(73):
				var a := TAU * i / 72.0
				blast.append(_to_map(target + Vector2(cos(a) * (ELLIPSE_A + BLAST_MARGIN), sin(a) * (ELLIPSE_B + BLAST_MARGIN))))
			for i in range(0, 72, 2): draw_line(blast[i], blast[i + 1], Color(1, .55, .25, .85), 1.5)
		var at := _to_map(target)
		draw_circle(at, FOOTPRINT / _metres_per_pixel(), Color(colour, .35))
		draw_line(at - Vector2(10, 0), at + Vector2(10, 0), Color.WHITE, 2.0)
		draw_line(at - Vector2(0, 10), at + Vector2(0, 10), Color.WHITE, 2.0)
	if base_mode and not is_inf(base_site.x):
		var base_at := _to_map(base_site)
		var half := 9.0 / _metres_per_pixel()
		draw_rect(Rect2(base_at - Vector2(half, half), Vector2(half, half) * 2.0), Color(.35, .6, 1.0, .25))
		draw_rect(Rect2(base_at - Vector2(half, half), Vector2(half, half) * 2.0), Color("#6FA8FF"), false, 2.0)
		draw_string(ThemeDB.fallback_font, base_at + Vector2(-16, half + 16), "BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#CFE0FF"))
	# North arrow, scale bar and legend.
	var font := ThemeDB.fallback_font
	var north := Vector2(size.x - 30, 34)
	draw_colored_polygon(PackedVector2Array([north + Vector2(0, -14), north + Vector2(7, 6), north + Vector2(-7, 6)]), Color("#F2F4F5"))
	draw_string(font, north + Vector2(-5, 24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#F2F4F5"))
	var bar := 10.0 / _metres_per_pixel()
	draw_line(Vector2(16, size.y - 18), Vector2(16 + bar, size.y - 18), Color("#F2F4F5"), 3.0)
	draw_string(font, Vector2(22 + bar, size.y - 12), "10 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#F2F4F5"))
	var y := size.y - 66.0
	for entry in [["Open ground", Color("#8A5236")], ["Cliffs, mounds, rough", Color("#4A2A22")], ["Buried ice", Color("#8FD8FF")]]:
		draw_rect(Rect2(Vector2(size.x - 170, y - 10), Vector2(12, 12)), entry[1])
		draw_string(font, Vector2(size.x - 152, y), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#F2F4F5"))
		y += 18.0
