extends Control

## What a wall screen or wayfinding panel shows, drawn into its SubViewport
## (equipment_rig.gd "screen" action). Every number comes from the live game:
##   status     · power made and used, battery, air, water, food, warmth, crew
##   mars/earth · a view of the planet (with the light-time to Earth)
##   wayfinding · this room, its lights and temperature, and the way to the
##                nearest airlock
##   sign       · the player's own text
## The viewport only re-renders when this redraws (about once a second).

const MHResources := preload("res://scripts/mh_resources.gd")

var mode := "status"
var sign_text := ""
## The rig (a Node3D on the wall): where the screen is and which way it faces.
var mount: Node3D
var viewport: SubViewport
var _since := 1.0
var _spin := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_since += delta
	_spin += delta
	if _since >= 1.0:
		_since = 0.0
		refresh()

func refresh() -> void:
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
	var builder := _builder()
	if builder != null and not builder.grid_power_online():
		return    # no power: the screen is dark
	match mode:
		"status": _draw_status()
		"mars": _draw_planet(false)
		"earth": _draw_planet(true)
		"wayfinding": _draw_wayfinding()
		"sign": _draw_sign()

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
		["Coldest room", "%d °C" % roundi(float(snap.coldest_c)), Color("#FFB37A"), float(snap.coldest_c) >= 15.0],
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
	# The way to the nearest airlock.
	var best := Vector2.INF
	for z in builder.zones:
		if str(z.kind) != "airlock": continue
		var c := Vector2.ZERO
		for cell in z.cells: c += Vector2(cell.x, cell.y) * BuildController.CELL
		c /= maxf(1.0, float((z.cells as Array).size()))
		if best == Vector2.INF or c.distance_to(Vector2(front.x, front.z)) < best.distance_to(Vector2(front.x, front.z)): best = c
	var box := Rect2(Vector2(24, 156) * u, Vector2(size.x - 48 * u, size.y - 172 * u))
	draw_rect(box, Color(1, 1, 1, .05))
	if best == Vector2.INF:
		_text("NO AIRLOCK YET", box.position + Vector2(20, 80) * u, int(40 * u), MHStyle.WARN, 700)
		return
	var to := best - Vector2(front.x, front.z)
	if str(zone.get("kind", "")) == "airlock" or to.length() < 2.0:
		_text("AIRLOCK HERE", box.position + Vector2(20, 80) * u, int(44 * u), MHStyle.VALID, 800)
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
	draw_colored_polygon(PackedVector2Array([c2 + dir * r, c2 - dir * r * .2 + side * r * .6, c2 - dir * r * .2 - side * r * .6]), MHStyle.VALID)
	draw_line(c2 - dir * r * .9, c2 - dir * r * .1, MHStyle.VALID, r * .32)
	_text("AIRLOCK  %d m" % roundi(to.length()), box.position + Vector2(box.size.y + 30 * u, box.size.y * .5 + 18 * u), int(48 * u), MHStyle.TEXT_PRIMARY, 800)

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
