extends Control

## The new field vehicles' working screens (Phase 6, 21 Nov), drawn like the
## wrist (info_screen.gd "suit"): shapes first, one number each, dim icons that
## light when they matter. Each sits in its own SubViewport on one of the
## model's blank Display_Surface_* quads (crew_rover.gd _fit_screens).
##   drive · speed arc with its one number, battery ring (the reserve's share
##           in amber), range, and lit icons: lights, cruise, charging, slip
##   home  · Scout 02's Return-to-hab screen: an arrow home, the distance, and
##           your suit's air in minutes beside the minutes the drive home
##           takes. Air short of the drive turns the edge red: the turn-back
##           on a working screen, never a voice
##   nav   · Traverse 06's route home: the breadcrumb trail you drove, north
##           up, with home and you on it
##   cabin · Traverse 06's life support on the rover's own supplies: pressure,
##           cab O2 and warmth as three rings, water and meals as pips; the
##           alarm flashes the screen red (the rover sounds it too)
## Numbers come from the vehicle (crew_rover.gd screen_state()).

const TRACK := Color("#1E262B")
const DIM := Color("#343E44")
const BACK := Color("#0C1316")

var vehicle: Node
var mode := "drive"
var viewport: SubViewport
var _since := 1.0

## A screen on `mesh` showing `screen_mode`, `pixels` big.
static func attach(owner_vehicle: Node, mesh: MeshInstance3D, screen_mode: String, pixels: Vector2i) -> SubViewport:
	var view := SubViewport.new()
	view.size = pixels
	view.disable_3d = true
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var screen = load("res://scripts/vehicle_screens.gd").new()
	screen.vehicle = owner_vehicle
	screen.mode = screen_mode
	screen.viewport = view
	screen.size = Vector2(pixels)
	view.add_child(screen)
	owner_vehicle.add_child(view)
	var material := StandardMaterial3D.new()
	material.resource_name = "dashboard_screen"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = view.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	return view

func _process(delta: float) -> void:
	_since += delta
	if _since < .25: return
	_since = 0.0
	queue_redraw()
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _text(text: String, at: Vector2, font_size: int, colour: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(MHStyle.font(800), at, text, align, width, font_size, colour)

## An arc from one share to another of a sweep starting at `start` radians and
## running `sweep` radians; r the outer edge, w the width, round ends.
func _arc(c: Vector2, r: float, w: float, start: float, sweep: float, from_share: float, to_share: float, colour: Color) -> void:
	to_share = clampf(to_share, 0.0, 1.0)
	from_share = clampf(from_share, 0.0, 1.0)
	if to_share <= from_share: return
	var a0 := start + sweep * from_share
	var a1 := start + sweep * to_share
	draw_arc(c, r - w / 2.0, a0, a1, maxi(6, int(64.0 * (to_share - from_share)) + 2), colour, w, true)
	for a in [a0, a1]: draw_circle(c + Vector2(cos(a), sin(a)) * (r - w / 2.0), w / 2.0, colour)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	if vehicle == null or not vehicle.has_method("screen_state"): return
	var s: Dictionary = vehicle.screen_state()
	if not bool(s.get("on", true)):
		return   # flat: a dark screen
	match mode:
		"drive": _draw_drive(s)
		"home": _draw_home(s)
		"nav": _draw_nav(s)
		"cabin": _draw_cabin(s)

func _flash() -> bool:
	return fmod(Time.get_ticks_msec() / 1000.0, 1.0) < .6

func _distance(metres: float) -> String:
	if metres < 0.0: return "—"
	return ("%.1f km" % (metres / 1000.0)) if metres >= 1000.0 else ("%d m" % roundi(metres))

# ---------- drive ----------

func _draw_drive(s: Dictionary) -> void:
	var u := size.y / 300.0
	var c := Vector2(size.x * .32, size.y * .6)
	var r := 118.0 * u
	# Speed: a 240-degree arc from lower left, over the top, to lower right.
	var start := deg_to_rad(150)
	var sweep := deg_to_rad(240)
	var share := clampf(float(s.speed) / maxf(.1, float(s.top)), 0.0, 1.0)
	_arc(c, r, 18 * u, start, sweep, 0.0, 1.0, TRACK)
	var col := MHStyle.TEXT_PRIMARY
	if bool(s.get("slip", false)) or bool(s.get("bogged", false)): col = MHStyle.WARN
	_arc(c, r, 18 * u, start, sweep, 0.0, share, MHStyle.accent)
	if float(s.get("cruise", 0.0)) > 0.0:
		var a := start + sweep * clampf(float(s.cruise) / maxf(.1, float(s.top)), 0.0, 1.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r + 6 * u), c + d * (r - 24 * u), MHStyle.INFO, 4 * u, true)
	_text("%d" % roundi(float(s.speed) * 3.6), c + Vector2(-110, 18) * u, int(66 * u), col, 220 * u)
	_text("km/h", c + Vector2(-60, 48) * u, int(18 * u), MHStyle.TEXT_SECONDARY, 120 * u)
	# Battery: a ring at the right with the reserve's share in amber.
	var bc := Vector2(size.x * .76, size.y * .44)
	var br := 70.0 * u
	var battery := clampf(float(s.battery) / 100.0, 0.0, 1.0)
	var reserve := clampf(float(s.reserve) / 100.0, 0.0, 1.0)
	var bcol := MHStyle.VALID if battery > .25 else (MHStyle.WARN if battery > .1 else MHStyle.DANGER)
	_arc(bc, br, 14 * u, -PI / 2.0, TAU * .82, 0.0, 1.0, TRACK)
	if battery > 0.0: _arc(bc, br, 14 * u, -PI / 2.0, TAU * .82, 0.0, battery, bcol)
	_arc(bc, br, 14 * u, -PI / 2.0 + TAU * .85, TAU * .13, 0.0, 1.0, TRACK)
	_arc(bc, br, 14 * u, -PI / 2.0 + TAU * .85, TAU * .13, 0.0, reserve, MHStyle.WARN if battery <= 0.0 else Color(MHStyle.WARN, .55))
	_bolt(bc + Vector2(0, -22) * u, u, MHStyle.VALID if bool(s.get("charging", false)) and _flash() else (bcol if battery > 0.0 else MHStyle.WARN))
	_text(_distance(float(s.range_m)), bc + Vector2(-70, 22) * u, int(24 * u), MHStyle.TEXT_PRIMARY, 140 * u)
	# The icon row: headlights, cruise, slipping wheels, worn wheels.
	var y := size.y - 34 * u
	var x := size.x * .58
	_lamp(Vector2(x, y), u, MHStyle.INFO if bool(s.get("lights", false)) else DIM)
	_cruise_icon(Vector2(x + 56 * u, y), u, MHStyle.INFO if float(s.get("cruise", 0.0)) > 0.0 else DIM)
	var slip_col := MHStyle.DANGER if bool(s.get("bogged", false)) else (MHStyle.WARN if bool(s.get("slip", false)) else DIM)
	if bool(s.get("bogged", false)) and not _flash(): slip_col = Color(slip_col, .4)
	_wheel_icon(Vector2(x + 112 * u, y), u, slip_col, true)
	var worn := float(s.get("wheels", 100.0))
	_wheel_icon(Vector2(x + 168 * u, y), u, MHStyle.DANGER if worn < 15.0 else (MHStyle.WARN if worn < 40.0 else DIM), false)
	if battery <= 0.0 and reserve <= 0.0:
		draw_rect(Rect2(Vector2(2, 2) * u, size - Vector2(4, 4) * u), MHStyle.DANGER, false, 4 * u)

func _bolt(b: Vector2, u: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([b + Vector2(-3, -11) * u, b + Vector2(8, -11) * u, b + Vector2(2, -2) * u, b + Vector2(9, -2) * u, b + Vector2(-6, 14) * u, b + Vector2(-2, 3) * u, b + Vector2(-9, 3) * u]), colour)

func _lamp(c: Vector2, u: float, colour: Color) -> void:
	draw_arc(c + Vector2(-6, 0) * u, 10 * u, -PI / 2.0, PI / 2.0, 12, colour, 3 * u, true)
	draw_line(c + Vector2(-6, -10) * u, c + Vector2(-6, 10) * u, colour, 3 * u, true)
	for k in 3: draw_line(c + Vector2(8, -8 + k * 8) * u, c + Vector2(18, -8 + k * 8) * u, colour, 3 * u, true)

func _cruise_icon(c: Vector2, u: float, colour: Color) -> void:
	draw_arc(c, 13 * u, deg_to_rad(150), deg_to_rad(390), 20, colour, 3 * u, true)
	draw_line(c, c + Vector2(7, -9) * u, colour, 3 * u, true)

func _wheel_icon(c: Vector2, u: float, colour: Color, waves: bool) -> void:
	draw_arc(c + Vector2(0, -3) * u, 11 * u, 0, TAU, 20, colour, 3 * u, true)
	draw_circle(c + Vector2(0, -3) * u, 3 * u, colour)
	if waves:
		for k in 2:
			var yy := 12.0 + k * 6.0
			draw_polyline(PackedVector2Array([c + Vector2(-16, yy) * u, c + Vector2(-8, yy - 3) * u, c + Vector2(0, yy) * u, c + Vector2(8, yy - 3) * u, c + Vector2(16, yy) * u]), colour, 2 * u, true)
	else:
		draw_line(c + Vector2(-16, 12) * u, c + Vector2(16, 12) * u, colour, 3 * u, true)

# ---------- home (Scout 02) ----------

func _draw_home(s: Dictionary) -> void:
	var u := size.y / 260.0
	var home: Dictionary = s.get("home", {})
	# The arrow home, from where the buggy faces.
	var ac := Vector2(size.x * .27, size.y * .44)
	draw_arc(ac, 74 * u, 0, TAU, 40, TRACK, 6 * u, true)
	if not home.is_empty():
		var bearing := float(home.bearing)
		var d := Vector2(sin(-bearing), -cos(-bearing))
		var side := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([ac + d * 56 * u, ac - d * 30 * u + side * 32 * u, ac - d * 12 * u, ac - d * 30 * u - side * 32 * u]), MHStyle.accent)
		_house(ac + Vector2(0, -92) * u + Vector2(0, 0), u * .9, MHStyle.TEXT_SECONDARY)
	_text(_distance(float(home.get("metres", -1.0))), Vector2(ac.x - 110 * u, size.y - 22 * u), int(30 * u), MHStyle.TEXT_PRIMARY, 220 * u)
	# Your suit's air in minutes, against the minutes the drive home takes.
	var mc := Vector2(size.x * .72, size.y * .46)
	var mr := 78.0 * u
	var air := float(s.get("suit_minutes", -1.0))
	var drive := float(home.get("minutes", 0.0))
	if air < 0.0:
		_text("∞", mc + Vector2(-80, 20) * u, int(60 * u), MHStyle.TEXT_MUTED, 160 * u)
	else:
		var full := maxf(air, float(s.get("suit_full_minutes", air)))
		var air_share := air / maxf(1.0, full)
		var need_share := clampf(drive / maxf(1.0, full), 0.0, 1.0)
		var short := air <= drive * 1.25 + 5.0
		var col := MHStyle.DANGER if air <= drive + 2.0 else (MHStyle.WARN if short else MHStyle.VALID)
		_arc(mc, mr, 16 * u, -PI / 2.0, TAU, 0.0, 1.0, TRACK)
		_arc(mc, mr, 16 * u, -PI / 2.0, TAU, 0.0, air_share, col)
		# The drive home, marked on the ring like the wrist's notch.
		var a := -PI / 2.0 + TAU * need_share
		var dir := Vector2(cos(a), sin(a))
		draw_line(mc + dir * (mr + 5 * u), mc + dir * (mr - 21 * u), MHStyle.TEXT_PRIMARY, 4 * u, true)
		_text("%d" % roundi(air), mc + Vector2(-80, 16) * u, int(52 * u), col if air > drive + 2.0 or _flash() else Color(col, .45), 160 * u)
		_text("min O₂", mc + Vector2(-60, 42) * u, int(16 * u), MHStyle.TEXT_SECONDARY, 120 * u)
		if air <= drive + 2.0: draw_rect(Rect2(Vector2(2, 2) * u, size - Vector2(4, 4) * u), MHStyle.DANGER, false, 4 * u)
	# The suit lead: a plug, lit while it's charging the suit.
	_plug(Vector2(size.x - 34 * u, size.y - 30 * u), u, MHStyle.VALID if bool(s.get("lead", false)) else DIM)

func _house(h: Vector2, u: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([h + Vector2(-11, 0) * u, h + Vector2(0, -11) * u, h + Vector2(11, 0) * u, h + Vector2(8, 0) * u, h + Vector2(8, 9) * u, h + Vector2(-8, 9) * u, h + Vector2(-8, 0) * u]), colour)

func _plug(c: Vector2, u: float, colour: Color) -> void:
	draw_rect(Rect2(c + Vector2(-9, -6) * u, Vector2(18, 14) * u), colour)
	for x in [-5, 5]: draw_line(c + Vector2(x, -6) * u, c + Vector2(x, -14) * u, colour, 3 * u, true)
	draw_line(c + Vector2(0, 8) * u, c + Vector2(0, 16) * u, colour, 3 * u, true)

# ---------- nav (Traverse 06) ----------

func _draw_nav(s: Dictionary) -> void:
	var u := size.y / 300.0
	var area := Rect2(Vector2(18, 18) * u, size - Vector2(36, 70) * u)
	draw_rect(area, Color("#111B1F"))
	var trail: PackedVector2Array = s.get("trail", PackedVector2Array())
	var here: Vector2 = s.get("here", Vector2.ZERO)
	var home: Dictionary = s.get("home", {})
	var home_at: Vector2 = home.get("at", here)
	# Fit home, the trail and you, north up.
	var lo := Vector2(minf(here.x, home_at.x), minf(here.y, home_at.y))
	var hi := Vector2(maxf(here.x, home_at.x), maxf(here.y, home_at.y))
	for p in trail:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 200.0) * 1.15
	var mid := (lo + hi) * .5
	var scale := minf(area.size.x, area.size.y) / span
	var centre := area.get_center()
	var to_screen := func(p: Vector2) -> Vector2: return centre + (p - mid) * scale
	# A faint grid, one line per 500 m.
	var step := 500.0
	var gx := floorf((mid.x - span) / step) * step
	while gx < mid.x + span:
		var sx: float = (to_screen.call(Vector2(gx, 0)) as Vector2).x
		if sx > area.position.x and sx < area.end.x: draw_line(Vector2(sx, area.position.y), Vector2(sx, area.end.y), TRACK, 1.5 * u)
		gx += step
	var gy := floorf((mid.y - span) / step) * step
	while gy < mid.y + span:
		var sy: float = (to_screen.call(Vector2(0, gy)) as Vector2).y
		if sy > area.position.y and sy < area.end.y: draw_line(Vector2(area.position.x, sy), Vector2(area.end.x, sy), TRACK, 1.5 * u)
		gy += step
	# The breadcrumb route, then the way still to go.
	if trail.size() >= 2:
		var line := PackedVector2Array()
		for p in trail: line.append(to_screen.call(p))
		draw_polyline(line, MHStyle.accent, 4 * u, true)
		for p in line: draw_circle(p, 3 * u, MHStyle.accent)
	if not home.is_empty():
		_house(to_screen.call(home_at), u, MHStyle.TEXT_PRIMARY)
	# You: a triangle facing the way the rover faces.
	var yaw := float(s.get("yaw", 0.0))
	var d := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-d.y, d.x)
	var me: Vector2 = to_screen.call(here)
	draw_colored_polygon(PackedVector2Array([me + d * 14 * u, me - d * 9 * u + side * 9 * u, me - d * 9 * u - side * 9 * u]), MHStyle.VALID)
	# North, and the one number: the way home.
	var n := Vector2(area.end.x - 22 * u, area.position.y + 26 * u)
	draw_colored_polygon(PackedVector2Array([n + Vector2(0, -14) * u, n + Vector2(8, 8) * u, n + Vector2(0, 3) * u, n + Vector2(-8, 8) * u]), MHStyle.TEXT_SECONDARY)
	_house(Vector2(36, size.y - 28) * u, u, MHStyle.TEXT_SECONDARY)
	_text(_distance(float(home.get("metres", -1.0))), Vector2(56 * u, size.y - 16 * u), int(30 * u), MHStyle.TEXT_PRIMARY, -1, HORIZONTAL_ALIGNMENT_LEFT)

# ---------- cabin (Traverse 06) ----------

func _draw_cabin(s: Dictionary) -> void:
	var u := size.y / 280.0
	var alarm := bool(s.get("alarm", false))
	var sealed := bool(s.get("cab_live", false))
	var rings := [
		[float(s.get("hull", 100.0)) / 100.0, MHStyle.DANGER if bool(s.get("leak", false)) else MHStyle.TEXT_SECONDARY, "HULL", "%d%%" % roundi(float(s.get("hull", 100.0)))],
		[float(s.get("cab_o2", 0.0)) / 100.0, MHStyle.TEXT_SECONDARY, "O₂", "%d%%" % roundi(float(s.get("cab_o2", 0.0)))],
		[(float(s.get("temp_c", 0.0)) + 40.0) / 62.0, MHStyle.TEXT_SECONDARY, "°C", "%d" % roundi(float(s.get("temp_c", 0.0)))],
	]
	for i in rings.size():
		var ring: Array = rings[i]
		var share := clampf(float(ring[0]), 0.0, 1.0)
		var c := Vector2(size.x * (.19 + .31 * i), size.y * .42)
		var r := 68.0 * u
		var col := MHStyle.VALID
		if share < .3: col = MHStyle.DANGER
		elif share < .55: col = MHStyle.WARN
		if not sealed: col = DIM
		_arc(c, r, 14 * u, deg_to_rad(135), deg_to_rad(270), 0.0, 1.0, TRACK)
		_arc(c, r, 14 * u, deg_to_rad(135), deg_to_rad(270), 0.0, share if sealed else 1.0, col)
		_text(str(ring[3]) if sealed else "—", c + Vector2(-60, 12) * u, int(32 * u), MHStyle.TEXT_PRIMARY if sealed else MHStyle.TEXT_MUTED, 120 * u)
		_text(str(ring[2]), c + Vector2(-40, 52) * u, int(16 * u), ring[1], 80 * u)
	# Stores: water in litres as a bar, meals as pips.
	var y := size.y - 34 * u
	var water := clampf(float(s.get("water_l", 0.0)) / maxf(1.0, float(s.get("water_full", 1.0))), 0.0, 1.0)
	var drop := Vector2(40, 0) * u + Vector2(0, y)
	draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -14) * u, drop + Vector2(9, 1) * u, drop + Vector2(0, 10) * u, drop + Vector2(-9, 1) * u]), MHStyle.INFO if water > .15 else MHStyle.WARN)
	draw_rect(Rect2(Vector2(60 * u, y - 7 * u), Vector2(150 * u, 14 * u)), TRACK)
	draw_rect(Rect2(Vector2(60 * u, y - 7 * u), Vector2(150 * u * water, 14 * u)), MHStyle.INFO if water > .15 else MHStyle.WARN)
	var meals := int(s.get("meals", 0))
	var full := int(s.get("meals_full", meals))
	for i in full:
		var pip := Rect2(Vector2(240 + i * 22, 0) * u + Vector2(0, y - 8 * u), Vector2(16, 16) * u)
		if i < meals: draw_rect(pip, MHStyle.TEXT_SECONDARY)
		else: draw_rect(pip, DIM, false, 2 * u)
	if alarm:
		var on := _flash()
		draw_rect(Rect2(Vector2(2, 2) * u, size - Vector2(4, 4) * u), MHStyle.DANGER if on else Color(MHStyle.DANGER, .35), false, 6 * u)
		if on:
			var t := Vector2(size.x - 40 * u, size.y - 36 * u)
			draw_colored_polygon(PackedVector2Array([t + Vector2(0, -18) * u, t + Vector2(17, 12) * u, t + Vector2(-17, 12) * u]), MHStyle.DANGER)
			draw_line(t + Vector2(0, -8) * u, t + Vector2(0, 2) * u, BACK, 3 * u)
			draw_circle(t + Vector2(0, 7) * u, 2 * u, BACK)
