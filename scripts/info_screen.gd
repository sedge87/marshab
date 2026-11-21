extends Control

## What a wall screen or wayfinding panel shows, drawn into its SubViewport
## (equipment_rig.gd "screen" action). Every number comes from the live game:
##   status     · power made and used, battery, air, water, food, warmth, crew
##   mars/earth · a view of the planet (with the light-time to Earth)
##   wayfinding · this room, its lights and temperature, and the way to the
##                nearest airlock; in a solar particle event, the way to the
##                storm shelter (any wayfinding panel, even one showing a sign).
##                The arrow follows the route through doorways.
##   sign       · the player's own text
##   camera     · the outside camera masts, a new picture each second (cycles
##                masts every 8 s when there are several)
##   suit       · the wrist pad (wrist_pad.gd), drawn not written: a ring of
##                air with a notch for the air home, power, the sky, the way
##                to the nearest refill and status icons (21 Nov). It runs on
##                the suit's battery, so no grid needed.
## The viewport only re-renders when this redraws (about once a second).

const MHResources := preload("res://scripts/mh_resources.gd")

var mode := "status"
var sign_text := ""
var suit: Node   # scripts/suit.gd, for the wrist pad
var cabin: Node  # scripts/lander_cabin_life.gd, for the lander's panel ("cabin")
var pod: Node    # scripts/lifepod.gd: the ration crate
## The rig (a Node3D on the wall): where the screen is and which way it faces.
var mount: Node3D
var viewport: SubViewport
var _since := 1.0
var _cam_port: SubViewport
var _cam: Camera3D
var _cam_index := 0
var _cam_clock := 0.0
var _spin := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_since += delta
	_spin += delta
	# The wrist redraws four times a second, so a leak can flash.
	if _since >= (.25 if mode == "suit" else 1.0):
		_since = 0.0
		refresh()

func refresh() -> void:
	if mode == "camera": _aim_camera()
	queue_redraw()
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _builder() -> BuildController:
	return get_tree().get_first_node_in_group("habitat_builder") as BuildController

func _font(weight := 600) -> Font:
	return MHStyle.font(weight)

func _text(text: String, at: Vector2, font_size: int, colour: Color, weight := 600, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font(weight), at, text, align, width, font_size, colour)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0C1316"))
	if mode == "suit":
		_draw_suit()
		return
	if mode == "cabin":
		_draw_cabin()
		return
	var builder := _builder()
	if builder != null and not builder.grid_power_online():
		return    # no power: the screen is dark
	match mode:
		"status": _draw_status()
		"mars": _draw_planet(false)
		"earth": _draw_planet(true)
		"wayfinding": _draw_wayfinding()
		"sign": _draw_wayfinding() if _emergency() else _draw_sign()
		"camera": _draw_camera()

# ---------- habitat status ----------

func _draw_status() -> void:
	var builder := _builder()
	var u := size.y / 360.0
	_text("HABITAT STATUS", Vector2(24, 40) * u, int(22 * u), MHStyle.accent, 700)
	_text("%02d:%02d LOCAL" % [int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60.0)], Vector2(size.x - 24 * u, 40 * u), int(18 * u), MHStyle.TEXT_SECONDARY, 500, HORIZONTAL_ALIGNMENT_RIGHT, -1)
	if builder == null or not MHGame.simulation_on():
		_text("Systems offline", Vector2(24, 120) * u, int(28 * u), MHStyle.TEXT_MUTED)
		return
	var sim = builder.simulation()
	var snap: Dictionary = sim.snapshot(MHGame.sol_hour)
	var rows := [
		["Power made", "%.1f kW" % float(snap.generation_kw), MHStyle.BEACON_YELLOW, float(snap.generation_kw) >= float(snap.load_kw)],
		["Power used", "%.1f kW" % float(snap.load_kw), MHStyle.INK_100, true],
		["Battery", "%d%%" % roundi(float(snap.battery_pct)), MHStyle.VALID, float(snap.battery_pct) > 20.0],
		["Oxygen", "%.1f%%" % float(snap.o2_pct), Color("#7FD6FF"), float(snap.o2_pct) >= MHResources.setting("o2_min_pct", 19.5)],
		["Carbon dioxide", "%.2f%%" % float(snap.co2_pct), Color("#C9A8FF"), float(snap.co2_pct) <= MHResources.setting("co2_danger_pct", 1.0)],
		["Water", "%d L" % roundi(float(snap.water_l)), Color("#6FB8FF"), float(snap.water_l) > 0.0],
		["Food", "%d kg" % roundi(float(snap.food_kg)), Color("#9AE07A"), float(snap.food_kg) > 0.0],
		["Temperature", "%d °C" % roundi(float(snap.coldest_c)), Color("#FFB37A"), float(snap.coldest_c) >= 15.0],
		["Crew health", "%d%%" % roundi(float(snap.crew_health)), Color("#FF8A8A"), float(snap.crew_health) >= 50.0]]
	var columns := 3
	var cell_w := (size.x - 48 * u) / columns
	for i in range(rows.size()):
		var row: Array = rows[i]
		var at := Vector2(24 * u + (i % columns) * cell_w, 96 * u + (i / columns) * 88 * u)
		draw_circle(at + Vector2(8, -9) * u, 7 * u, row[2] if row[3] else MHStyle.DANGER)
		_text(str(row[0]).to_upper(), at + Vector2(22 * u, 0), int(18 * u), MHStyle.TEXT_SECONDARY, 600)
		_text(str(row[1]), at + Vector2(22 * u, 40 * u), int(38 * u), MHStyle.TEXT_PRIMARY if row[3] else MHStyle.DANGER, 700)
	if bool(snap.storm): _text("DUST STORM · SOLAR POWER REDUCED", Vector2(24, size.y / u - 18) * u, int(15 * u), Color(1, .7, .45), 700)

# ---------- the lander cabin (scripts/lander_panel.gd) ----------

## Five tiles, read at a glance: an icon, a tall bar and one big number each.
## Green is fine, amber low, red urgent. Dark when the cabin has no power.
func _draw_cabin() -> void:
	if cabin == null or cabin.get("core") == null: return
	var core: RefCounted = cabin.core
	if not core.powered(): return
	var u := size.y / 400.0
	var o2_hours := float(core.tank_o2_kg) / .035
	var water_days := float(core.water_sols())
	var solar := float((core.last as Dictionary).get("solar", 0.0))
	var rations := int(pod.get("rations")) if pod != null and pod.get("rations") != null else -1
	var temp := float(core.temp_c)
	var tiles := [
		["wind", "AIR", "%d h" % roundi(o2_hours) if o2_hours < 48.0 else "%d sol" % floori(o2_hours / 24.0), float(core.tank_o2_kg) / maxf(.01, float(core.tank_cap)), _level(o2_hours, 12.0, 4.0)],
		["droplets", "WATER", "%.1f L" % float(core.water_l), float(core.water_l) / maxf(.01, float(core.water_cap)), _level(water_days, 1.0, .4)],
		["zap", "POWER", "%d%%" % roundi(float(core.battery_pct())), float(core.battery_pct()) / 100.0, _level(float(core.battery_pct()), 35.0, 15.0)],
		["thermometer", "HEAT", "%d°" % roundi(temp), clampf((temp + 10.0) / 35.0, 0.0, 1.0), _level(temp, 12.0, 5.0)],
		["utensils", "FOOD", str(rations) if rations >= 0 else "–", clampf(float(rations) / 12.0, 0.0, 1.0), _level(float(rations), 4.0, 1.0)]]
	var gap := 14.0 * u
	var w := (size.x - gap * 6.0) / 5.0
	for i in tiles.size():
		var t: Array = tiles[i]
		var colour: Color = [MHStyle.VALID, MHStyle.WARN, MHStyle.DANGER][int(t[4])]
		var x := gap + i * (w + gap)
		var tile := Rect2(Vector2(x, 18 * u), Vector2(w, size.y - 36 * u))
		draw_rect(tile, Color(1, 1, 1, .04))
		if int(t[4]) > 0: draw_rect(tile, Color(colour, .9), false, 3.0 * u)
		var icon_size := int(44 * u)
		draw_texture_rect(MHIcons.texture(str(t[0]), icon_size), Rect2(Vector2(x + (w - icon_size) / 2.0, 34 * u), Vector2(icon_size, icon_size)), false, colour)
		_text(str(t[1]), Vector2(x, 114 * u), int(22 * u), MHStyle.TEXT_SECONDARY, 700, HORIZONTAL_ALIGNMENT_CENTER, w)
		# The tall bar.
		var bar := Rect2(Vector2(x + w * .3, 130 * u), Vector2(w * .4, 170 * u))
		draw_rect(bar, Color(1, 1, 1, .08))
		var share := clampf(float(t[3]), 0.0, 1.0)
		draw_rect(Rect2(Vector2(bar.position.x, bar.end.y - bar.size.y * share), Vector2(bar.size.x, bar.size.y * share)), colour)
		_text(str(t[2]), Vector2(x, 350 * u), int(34 * u), MHStyle.TEXT_PRIMARY if int(t[4]) == 0 else colour, 700, HORIZONTAL_ALIGNMENT_CENTER, w)
	# Sun on the blanket: a small glyph and the kilowatts coming in now.
	if solar > .02:
		var at := Vector2(gap + 2.0 * (w + gap), 18 * u)
		draw_texture_rect(MHIcons.texture("sun", int(20 * u)), Rect2(at + Vector2(6, 6) * u, Vector2(20, 20) * u), false, MHStyle.BEACON_YELLOW)
		_text("%.1f kW" % solar, at + Vector2(30, 22) * u, int(15 * u), MHStyle.BEACON_YELLOW, 600)

## 0 fine, 1 low, 2 urgent: `value` against its low and urgent marks.
static func _level(value: float, low: float, urgent: float) -> int:
	return 2 if value <= urgent else (1 if value <= low else 0)

# ---------- the wrist pad ----------

func _clock(hours: float) -> String:
	var minutes := maxi(0, floori(hours * 60.0))
	return "%d:%02d" % [minutes / 60, minutes % 60]

func _bar(at: Vector2, width: float, share: float, colour: Color, u: float) -> void:
	draw_rect(Rect2(at, Vector2(width, 10 * u)), Color(1, 1, 1, .08))
	draw_rect(Rect2(at, Vector2(width * clampf(share, 0.0, 1.0), 10 * u)), colour)

# 21 Nov: the wrist pad, drawn not written (deliverables/Wrist_Review_01/
# wrist_screen_mockup.png). One ring of air that empties, with a notch for the
# air you need to get home: turning back is the edge reaching the notch. The
# only number is air time. Power is the thin blue arc outside. Right: the sun
# (or Phobos and Deimos at night), the way to air, and small icons that stay
# dim until they matter. No base alerts here.
const WRIST_TRACK := Color("#1E262B")
const WRIST_DIM := Color("#343E44")

## An arc from one share of the circle to another, from the top, clockwise,
## r the outer edge, w its width; round ends unless it's the whole ring.
func _wrist_arc(c: Vector2, r: float, w: float, from_share: float, to_share: float, colour: Color) -> void:
	to_share = minf(to_share, 1.0)
	if to_share <= from_share: return
	var a0 := -PI / 2.0 + TAU * from_share
	var a1 := -PI / 2.0 + TAU * to_share
	draw_arc(c, r - w / 2.0, a0, a1, maxi(6, int(96.0 * (to_share - from_share)) + 2), colour, w, true)
	if to_share - from_share < .999:
		for a in [a0, a1]: draw_circle(c + Vector2(cos(a), sin(a)) * (r - w / 2.0), w / 2.0, colour)

func _draw_suit() -> void:
	var u := size.y / 320.0
	if suit == null: return
	var r: Dictionary = suit.readout()
	var active := bool(r.active)
	var outside := str(r.where) == "outside"
	var o2 := clampf(float(r.o2), 0.0, 1.0)
	var power := clampf(float(r.power), 0.0, 1.0)
	var turn_back := float(r.turn_back)
	var on_reserve := active and outside and o2 <= 0.0
	var leak := bool(r.get("leak", false))
	var flash := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < .6
	# The air's colour: green, amber as the edge nears the notch, red past it.
	var col := MHStyle.VALID
	if active and outside:
		if on_reserve or turn_back <= 0.0: col = MHStyle.DANGER
		elif turn_back < .5 or o2 <= .25: col = MHStyle.WARN
	elif active and o2 <= .1: col = MHStyle.DANGER
	if not active: col = MHStyle.TEXT_MUTED
	var c := Vector2(150, 160) * u
	var ring := 112.0 * u
	var thick := 22.0 * u
	# Power: the thin arc round the outside, with its bolt at the top.
	var power_col := MHStyle.INFO if power > .25 else (MHStyle.WARN if power > .1 else MHStyle.DANGER)
	_wrist_arc(c, ring + 19 * u, 6 * u, 0.0, 1.0, WRIST_DIM)
	if active: _wrist_arc(c, ring + 19 * u, 6 * u, 0.0, power, power_col)
	var b := c + Vector2(8, -ring / u - 30) * u
	draw_colored_polygon(PackedVector2Array([b + Vector2(-2, -7) * u, b + Vector2(5, -7) * u, b + Vector2(1, -1) * u, b + Vector2(6, -1) * u, b + Vector2(-4, 9) * u, b + Vector2(-1, 2) * u, b + Vector2(-6, 2) * u]), power_col if active else WRIST_DIM)
	# Air: the track, the reserve you need to get home, the air itself.
	_wrist_arc(c, ring, thick, 0.0, 1.0, WRIST_TRACK)
	var home := 0.0
	if active and outside:
		var hours := float(r.o2_hours)
		home = clampf(o2 * (hours - turn_back) / hours, 0.0, 1.0) if hours > 0.0 else o2
		_wrist_arc(c, ring, thick, 0.0, home, Color(MHStyle.WARN, .22))
	_wrist_arc(c, ring, thick, 0.0, o2 if active else 1.0, col if active else WRIST_DIM)
	if active and outside:
		# The notch, and a small house beside it.
		var a := -PI / 2.0 + TAU * home
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (ring + 4 * u), c + dir * (ring - thick - 4 * u), MHStyle.TEXT_PRIMARY, 4 * u, true)
		var h := c + dir * (ring + 30 * u)
		draw_colored_polygon(PackedVector2Array([h + Vector2(-7, 0) * u, h + Vector2(0, -7) * u, h + Vector2(7, 0) * u, h + Vector2(5, 0) * u, h + Vector2(5, 6) * u, h + Vector2(-5, 6) * u, h + Vector2(-5, 0) * u]), MHStyle.TEXT_PRIMARY)
	elif active and bool(r.filling) and o2 < .999:
		# Topping up: a bright bead on the air's leading edge.
		var e := -PI / 2.0 + TAU * o2
		draw_circle(c + Vector2(cos(e), sin(e)) * (ring - thick / 2.0), 5 * u, MHStyle.TEXT_PRIMARY)
	# The one number: air time (on the reserve, the reserve's time).
	var number := "∞" if not active else _clock(float(r.get("reserve_hours", 0.0)) if on_reserve else float(r.o2_hours))
	_text(number, Vector2(c.x - 100 * u, c.y + 14 * u), int(56 * u), col if not on_reserve or flash else Color(col, .45), 800, HORIZONTAL_ALIGNMENT_CENTER, 200 * u)
	_text("O₂", Vector2(c.x - 40 * u, c.y + 40 * u), int(17 * u), MHStyle.TEXT_SECONDARY, 800, HORIZONTAL_ALIGNMENT_CENTER, 80 * u)
	_wrist_sky(Vector2(395, 58) * u, 44 * u, u)
	# The way to air, or the lock when you're sealed in.
	var ax := Vector2(395, 140) * u
	if not outside:
		draw_rect(Rect2(ax + Vector2(-18, -6) * u, Vector2(36, 30) * u), MHStyle.VALID)
		draw_arc(ax + Vector2(0, -12) * u, 12 * u, PI, TAU, 16, MHStyle.VALID, 5 * u, true)
	else:
		var refill: Dictionary = r.refill
		var bearing := float(r.bearing)
		var d := Vector2(sin(-bearing), -cos(-bearing))
		var s := Vector2(-d.y, d.x)
		var arrow_col := MHStyle.accent if not refill.is_empty() else WRIST_DIM
		draw_colored_polygon(PackedVector2Array([ax + d * 30 * u, ax - d * 18 * u + s * 20 * u, ax - d * 6 * u, ax - d * 18 * u - s * 20 * u]), arrow_col)
		var metres := float(refill.get("distance", 0.0))
		var far := "—" if refill.is_empty() else (("%.1f km" % (metres / 1000.0)) if metres >= 1000.0 else ("%d m" % roundi(metres)))
		_text(far, Vector2(ax.x - 80 * u, ax.y + 59 * u), int(26 * u), MHStyle.TEXT_PRIMARY, 800, HORIZONTAL_ALIGNMENT_CENTER, 160 * u)
	# One short line, only while it's needed: learning the wrist, or why the air is going fast.
	var hint := ""
	var hint_col := MHStyle.INFO
	if bool(r.get("seal_banner", false)): hint = "SEAL OK · HOLD ALT TO RAISE"; hint_col = MHStyle.VALID
	elif bool(r.get("wrist_keys", false)): hint = "LET GO OF ALT TO LOWER"
	elif outside and not (r.get("drains", {}).get("air", []) as Array).is_empty():
		hint = "AIR FAST: %s" % ", ".join(r.drains.air).to_upper(); hint_col = MHStyle.WARN
	if not hint.is_empty():
		draw_multiline_string(_font(800), Vector2(310, 220) * u, hint, HORIZONTAL_ALIGNMENT_CENTER, 170 * u, int(13 * u), 2, hint_col)
	_wrist_icons(r, u, flash)
	# The whole screen's edge goes red when you're past the notch or leaking.
	if active and outside and (turn_back <= 0.0 or on_reserve or (leak and flash)):
		draw_rect(Rect2(Vector2(2, 2) * u, size - Vector2(4, 4) * u), MHStyle.DANGER, false, 4 * u)

## Top right: the sun along its arc by day; Phobos (larger) and Deimos at night.
func _wrist_sky(c: Vector2, radius: float, u: float) -> void:
	draw_line(c + Vector2(-radius - 8 * u, 0), c + Vector2(radius + 8 * u, 0), MHStyle.TEXT_MUTED, 2 * u, true)
	draw_arc(c, radius, PI, TAU, 32, WRIST_DIM, 2 * u, true)
	var day := MHGame.daylight_progress(MHGame.sol_hour)
	if day >= 0.0:
		draw_circle(c + Vector2(-cos(day * PI), -sin(day * PI)) * radius, 7 * u, MHStyle.WARN)
		return
	# Phobos crosses in about 11 hours, rising in the west; Deimos drifts slowly the other way.
	var phobos := 1.0 - fmod(MHGame.sol_hour / 11.1, 1.0)
	var deimos := fmod(MHGame.sol_hour / 60.0 + .3, 1.0)
	for moon in [[phobos, 5.0], [deimos, 3.0]]:
		var a: float = float(moon[0]) * PI
		draw_circle(c + Vector2(-cos(a), -sin(a)) * radius, float(moon[1]) * u, MHStyle.TEXT_SECONDARY)

## Bottom right: drink and food, the sample case, radiation and a leak.
func _wrist_icons(r: Dictionary, u: float, flash: bool) -> void:
	var y := 262.0 * u
	if bool(r.get("needs", false)):
		var drink := clampf(float(r.get("drink", 1.0)), 0.0, 1.0)
		var dc := MHStyle.WARN if drink < .25 else MHStyle.TEXT_SECONDARY
		var x := 300.0 * u
		var drop := PackedVector2Array([Vector2(x, y - 16 * u), Vector2(x + 10 * u, y), Vector2(x + 8 * u, y + 8 * u), Vector2(x, y + 12 * u), Vector2(x - 8 * u, y + 8 * u), Vector2(x - 10 * u, y)])
		var level := y + 12 * u - 28 * u * drink
		var below := PackedVector2Array([Vector2(x - 20 * u, level), Vector2(x + 20 * u, level), Vector2(x + 20 * u, y + 20 * u), Vector2(x - 20 * u, y + 20 * u)])
		for part in Geometry2D.intersect_polygons(drop, below): draw_colored_polygon(part, dc)
		draw_polyline(drop + PackedVector2Array([drop[0]]), dc, 2 * u, true)
		var bar := Rect2(Vector2(326, y / u - 6) * u, Vector2(28, 12) * u)
		draw_rect(bar, MHStyle.VALID if bool(r.get("food_bar", false)) else WRIST_DIM)
	if MHSamples.on() and MHChapterOne.has_corer:
		for i in MHSamples.CASE_SLOTS:
			var pip := Rect2(Vector2(373 + i * 13, y / u - 5) * u, Vector2(10, 10) * u)
			if i < MHSamples.case_items.size(): draw_rect(pip, MHStyle.TEXT_SECONDARY)
			else: draw_rect(pip, WRIST_DIM, false, 2 * u)
	# Radiation: lit only when the dose rate is high.
	var y2 := 296.0 * u
	var rc := MHStyle.DANGER if float(r.get("dose_rate", 0.0)) * 24.0 > 2.0 else WRIST_DIM
	var rad_c := Vector2(300 * u, y2)
	for k in 3:
		var mid := deg_to_rad(k * 120.0 - 90.0)
		var blade := PackedVector2Array([rad_c])
		for j in 7: blade.append(rad_c + Vector2.from_angle(mid - .52 + .52 * j / 3.0) * 11 * u)
		draw_colored_polygon(blade, rc)
	draw_circle(rad_c, 4 * u, Color("#0C1316"))
	draw_circle(rad_c, 2 * u, rc)
	# A leak: a helmet with a crack, flashing red.
	var leak := bool(r.get("leak", false))
	var lc := MHStyle.DANGER if leak and flash else (Color(MHStyle.DANGER, .4) if leak else WRIST_DIM)
	var hc := Vector2(340 * u, y2)
	draw_arc(hc, 11 * u, 0, TAU, 24, lc, 2 * u, true)
	draw_line(hc + Vector2(-11, 2) * u, hc + Vector2(11, 2) * u, lc, 2 * u, true)
	if leak: draw_polyline(PackedVector2Array([hc + Vector2(2, -11) * u, hc + Vector2(-2, -5) * u, hc + Vector2(3, -1) * u, hc + Vector2(-1, 2) * u]), lc, 2 * u, true)

# ---------- planets ----------

func _draw_planet(earth: bool) -> void:
	var u := size.y / 360.0
	var centre := Vector2(size.x * .38, size.y * .52)
	var radius := size.y * .38
	# A few fixed stars.
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 60: draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(.6, 1.6) * u, Color(1, 1, 1, rng.randf_range(.2, .7)))
	var base := Color("#2C6FD6") if earth else Color("#B4532A")
	draw_circle(centre, radius, base)
	# Surface patches drift round with the planet's spin.
	rng.seed = 3 if earth else 11
	var turn := fmod(_spin * .02, 1.0)
	for i in 26:
		var lon := fmod(rng.randf() + turn, 1.0) * TAU
		var lat := rng.randf_range(-1.2, 1.2)
		var x := sin(lon) * cos(lat)
		if cos(lon) < 0.0: continue    # on the far side
		var p := centre + Vector2(x, sin(lat)) * radius * .92
		var r := rng.randf_range(.08, .2) * radius * (0.55 + 0.45 * cos(lon))
		var colour := (Color("#3E8C47") if rng.randf() < .7 else Color("#C9B27A")) if earth else (Color("#7E3519") if rng.randf() < .6 else Color("#D98A55"))
		draw_circle(p, r, colour)
	if earth:
		for i in 14:
			var lon := fmod(rng.randf() + turn * 1.3, 1.0) * TAU
			if cos(lon) < 0.0: continue
			var p := centre + Vector2(sin(lon) * cos(rng.randf_range(-1, 1)), rng.randf_range(-.9, .9)) * radius * .9
			draw_circle(p, rng.randf_range(.04, .1) * radius, Color(1, 1, 1, .55))
	else:
		draw_circle(centre + Vector2(0, -radius * .9), radius * .18, Color(.95, .95, .95, .8))   # polar cap
	# Night side: the disc's right edge back along the terminator (an ellipse).
	var night := PackedVector2Array()
	for k in 33:
		var a := -PI * .5 + PI * float(k) / 32.0
		night.append(centre + Vector2(cos(a), sin(a)) * radius)
	for k in 33:
		var a := PI * .5 - PI * float(k) / 32.0
		night.append(centre + Vector2(cos(a) * .35, sin(a)) * radius)
	draw_colored_polygon(night, Color(0, 0, 0, .55))
	draw_arc(centre, radius, 0, TAU, 96, Color(1, 1, 1, .25) if earth else Color(1, .7, .5, .25), 2.0 * u)
	var x0 := size.x * .66
	_text("EARTH" if earth else "MARS", Vector2(x0, size.y * .3), int(34 * u), MHStyle.TEXT_PRIMARY, 700)
	var lines: Array = ["Home: 8 billion people.", "Messages take 4 to 24", "minutes each way."] if earth else ["Your base: %s." % MHGame.site_name(), "A sol lasts 24 h 39 m.", "Gravity: 38% of Earth's."]
	for i in range(lines.size()):
		_text(str(lines[i]), Vector2(x0, size.y * .3 + (44 + i * 30) * u), int(19 * u), MHStyle.TEXT_SECONDARY, 500)

# ---------- wayfinding ----------

func _draw_wayfinding() -> void:
	var u := size.y / 360.0
	var builder := _builder()
	if builder == null or mount == null:
		return
	# The room the panel hangs in: just in front of it.
	var front := mount.global_position - mount.global_transform.basis.z * .4
	var zone: Dictionary = builder._zone_at_point(Vector2(front.x, front.z))
	var room := str(BuildController.ZONE_TYPES.get(str(zone.get("kind", "")), {}).get("label", "Habitat")) if not zone.is_empty() else "Habitat"
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 74 * u)), Color(MHStyle.accent, .9))
	_text(room.to_upper(), Vector2(24 * u, 52 * u), int(44 * u), Color("#0C1316"), 800)
	var climate: Dictionary = builder.climate_at(front)
	var lights := "—"
	if not zone.is_empty() and MHGame.simulation_on():
		lights = builder.room_light_state(builder.simulation()._room_key(zone)).to_upper()
	_text("LIGHTS %s  ·  %d °C" % [lights, roundi(float(climate.get("temperature", 20.0)))], Vector2(24, 128) * u, int(30 * u), MHStyle.TEXT_PRIMARY, 700)
	# Where to: the nearest airlock, or the storm shelter in a solar particle event.
	var targets: Array = []
	var dest := "AIRLOCK"
	var tone := MHStyle.VALID
	if _emergency():
		var sim: RefCounted = builder.simulation()
		var place: Dictionary = sim.life.shelter(sim.inventory())
		dest = "SHELTER"
		tone = MHStyle.WARN
		if not place.is_empty(): targets = [sim.inventory().rooms[int(place.index)].zone]
	else:
		targets = builder.zones.filter(func(z): return str(z.kind) == "airlock")
	var box := Rect2(Vector2(24, 156) * u, Vector2(size.x - 48 * u, size.y - 172 * u))
	draw_rect(box, Color(tone, .12) if dest == "SHELTER" else Color(1, 1, 1, .05))
	if targets.is_empty():
		_text("NO %s YET" % dest, box.position + Vector2(20, 80) * u, int(40 * u), MHStyle.WARN, 700)
		return
	var here := Vector2(front.x, front.z)
	if targets.has(zone):
		_text("%s HERE" % dest, box.position + Vector2(20, 80) * u, int(44 * u), tone, 800)
		return
	# Follow the route through doorways when there is one; otherwise point straight.
	var route := _route(builder, here, targets)
	var best := Vector2.INF
	var length := 0.0
	if route.size() >= 2:
		best = route[mini(route.size() - 1, _first_turn(route))]
		for i in range(route.size() - 1): length += (route[i] as Vector2).distance_to(route[i + 1])
	else:
		for z in targets:
			var c := _zone_centre(z)
			if best == Vector2.INF or c.distance_to(here) < best.distance_to(here): best = c
		length = best.distance_to(here)
	var to := best - here
	if to.length() < .5:
		_text("%s HERE" % dest, box.position + Vector2(20, 80) * u, int(44 * u), tone, 800)
		return
	# Screen up = straight on from the viewer (into the wall), screen right = the viewer's right.
	var basis := mount.global_transform.basis
	var right := Vector2(-basis.x.x, -basis.x.z)
	var ahead := Vector2(basis.z.x, basis.z.z)
	var angle := atan2(to.normalized().dot(right), to.normalized().dot(ahead))
	var c2 := box.position + Vector2(box.size.y * .5 + 10 * u, box.size.y * .5)
	var r := box.size.y * .36
	var dir := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c2 + dir * r, c2 - dir * r * .2 + side * r * .6, c2 - dir * r * .2 - side * r * .6]), tone)
	draw_line(c2 - dir * r * .9, c2 - dir * r * .1, tone, r * .32)
	_text("%s  %d m" % [dest, roundi(length)], box.position + Vector2(box.size.y + 30 * u, box.size.y * .5 + 18 * u), int(48 * u), MHStyle.TEXT_PRIMARY, 800)

## A solar particle event is coming or under way: panels point to the shelter.
func _emergency() -> bool:
	var builder := _builder()
	if builder == null: return false
	var life: RefCounted = builder.simulation().life
	return float(life.spe_eta) >= 0.0 or life.spe_active()

func _zone_centre(z: Dictionary) -> Vector2:
	if z.has("outline"):
		var c := Vector2.ZERO
		for point in z.outline: c += point
		return c / maxf(1.0, (z.outline as Array).size())
	var c := Vector2.ZERO
	for cell in z.cells: c += Vector2(cell.x, cell.y) * BuildController.CELL
	return c / maxf(1.0, float((z.cells as Array).size()))

## The walking route (cell centres) from a point to any of the target zones,
## through openings and doors only (no walls). [] when there's no grid route.
func _route(builder: BuildController, from: Vector2, targets: Array) -> Array:
	var start := Vector2i(roundi(from.x / BuildController.CELL), roundi(from.y / BuildController.CELL))
	if builder._zone_at(start).is_empty(): return []
	var goal := {}
	for z in targets:
		for cell in z.get("cells", []): goal[cell] = true
	if goal.is_empty(): return []
	var came := {start: start}
	var queue: Array = [start]
	var found := Vector2i(999999, 0)
	while not queue.is_empty() and came.size() < 4000:
		var cell: Vector2i = queue.pop_front()
		if goal.has(cell):
			found = cell
			break
		for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + side
			if came.has(next) or builder._zone_at(next).is_empty(): continue
			if builder._should_build_wall(cell, side) or builder._should_build_wall(next, -side): continue
			came[next] = cell
			queue.append(next)
	if found.x == 999999: return []
	var path: Array = []
	var at := found
	while at != start:
		path.push_front(Vector2(at.x, at.y) * BuildController.CELL)
		at = came[at]
	path.push_front(from)
	return path

## How far along the route before it first changes direction.
func _first_turn(route: Array) -> int:
	if route.size() < 3: return route.size() - 1
	var heading := ((route[2] as Vector2) - (route[1] as Vector2)).normalized()
	for i in range(2, route.size() - 1):
		if ((route[i + 1] as Vector2) - (route[i] as Vector2)).normalized().dot(heading) < .9: return i
	return route.size() - 1

# ---------- outside camera ----------

func _masts() -> Array:
	return get_tree().get_nodes_in_group("camera_mast").filter(func(m): return is_instance_valid(m) and m.is_inside_tree())

func _aim_camera() -> void:
	var masts := _masts()
	if masts.is_empty(): return
	if _cam_port == null:
		_cam_port = SubViewport.new()
		_cam_port.size = Vector2i(640, 360)
		_cam_port.world_3d = get_tree().root.find_world_3d()
		_cam = Camera3D.new()
		_cam.current = true
		_cam.far = 900.0
		_cam_port.add_child(_cam)
		add_child(_cam_port)
	_cam_clock += 1.0
	if _cam_clock >= 8.0:
		_cam_clock = 0.0
		_cam_index += 1
	var mast: Node = masts[_cam_index % masts.size()]
	_cam.global_transform = mast.camera_view()
	_cam.fov = float(mast.camera_setting("cam_fov", 60.0))
	_cam_port.render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw_camera() -> void:
	var u := size.y / 360.0
	var masts := _masts()
	if masts.is_empty() or _cam_port == null:
		_text("NO CAMERA MASTS", Vector2(24, size.y * .5 / u) * u, int(28 * u), MHStyle.TEXT_MUTED, 700)
		_text("Build one outside: site plan, Outdoor, Camera Mast.", Vector2(24, size.y * .5 / u + 34) * u, int(16 * u), MHStyle.TEXT_MUTED, 500)
		return
	draw_texture_rect(_cam_port.get_texture(), Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2(10, 10) * u, Vector2(190, 30) * u), Color(0, 0, 0, .55))
	draw_circle(Vector2(26, 25) * u, 6 * u, Color(1, .25, .2))
	_text("MAST %d · LIVE" % (_cam_index % masts.size() + 1), Vector2(40, 31) * u, int(16 * u), MHStyle.TEXT_PRIMARY, 700)

# ---------- the player's sign ----------

func _draw_sign() -> void:
	var u := size.y / 360.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 14 * u)), MHStyle.accent)
	var text := sign_text if not sign_text.strip_edges().is_empty() else "Press F to write a sign"
	var font_size := int(clampf(size.x / maxf(4.0, float(text.length())) * 1.5, 22 * u, 72 * u))
	var font := _font(800)
	var lines := []
	var line := ""
	for word in text.split(" "):
		var trial := (line + " " + word).strip_edges()
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 48 * u and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = trial
	lines.append(line)
	var top := size.y * .5 - lines.size() * font_size * .6 + font_size * .8
	for i in range(lines.size()):
		_text(str(lines[i]), Vector2(0, top + i * font_size * 1.2), font_size, MHStyle.TEXT_PRIMARY if not sign_text.is_empty() else MHStyle.TEXT_MUTED, 800, HORIZONTAL_ALIGNMENT_CENTER, size.x)
