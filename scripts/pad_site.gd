extends Node3D

## The planned pad and the Collapse pit (opening slice chunk 2,
## docs/opening-slice.md §4a Scenes 8–11).
##
## The pad was laid by the cargo flights, about 200 m north-west of the
## Collapse pit, on the flattest ground there. From the plain it looks fine.
## Up close: the beacon's mast leans, its ballast foot is sunk on a fresh
## crack, its power lead is torn out of the box, and the pad's sections
## nearest the pit have dropped a hand's width. Nobody says so; you see it.
##
## Scene 9, the quick repair: hold E at the sunk foot to lever it up, then
## clip GAR-Y's hitch cable to the mast and it pulls it upright (by hand,
## slower, if there's no hitch). The box's tilt reading goes to zero. The
## lead stays torn: its connector needs printing.
##
## The pit (Scene 11): rubble on its floor, and its lip crumbles within 3 m
## of the edge (sound, a shudder, stones going over). On the last metre it
## gives way: you fall in, black out, and GAR-Y drags you home.
##
## The void under it all is a buried tube from the pit, under the pad and on
## past it (void_path(); scripts/survey_line.gd reads it). Pallet 6, the
## Print Shop, came down within sight of the pad (chunk 3 opens it).
##
## The model is asset_packs/outpost_chunk1_v1/Landing_Pad_And_Beacon.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk2/landing_pad_and_beacon.glb"
const ROCKS := "res://assets/original_mars/models/decor_rock_0%d.glb"   # 24 Nov: asset_packs/ is .gdignore'd, so the old path never loaded
## The chunk 2 pack (asset_packs/outpost_chunk2_v1): the beacon proper, and
## the dressing for the pad and the pit's lip.
const BEACON := "res://assets/models/chunk2/pad_beacon.glb"
const PARTS := "res://assets/models/chunk2/%s.glb"
const FOOT_AXIS := Vector3(-.5, 0, -.8660254)   # Foot_1's hinge (README: a = 30°)
const FOOT_SINK := 9.0          # Foot_1's own droop as found, degrees
const PIT_DISTANCE := 200.0     # the pad from the pit's centre (m)
const LANDER_CLEAR := 120.0
const LEAN := 17.0              # the mast's lean, degrees
const SINK := 5.0               # the station's tilt on its sunk foot, degrees
const DROP := .1                # the pit-side sections have dropped this much (m)
const SUNK_FOOT := Vector3(.72, .12, -.45)   # station space
const BOX := Vector3(.66, .2, .12)
const MAST_TOP := Vector3(0, 1.45, 0)        # BeaconTilt space: GAR-Y's cable clips on here
const SEEN_REACH := 14.0
const SEEN_SECONDS := 6.0       # up close this long: Castle's seen it on your helmet camera
const LEVER_SECONDS := 2.2
const PUSH_SECONDS := 3.5
const PULL_SECONDS := 3.5
const KEEP_CLEAR := 26.0        # no base on the pad
const CRUMBLE := 3.0            # the lip crumbles this close to the edge
const GIVES := 1.0              # and gives way this close

var world: Node
var centre := Vector3.INF       # the pad's centre (site metres)
var yaw := 0.0
var pit := Vector2.INF          # the pit's centre (site metres)
var pit_edge := 8.0             # the pit's edge, from its centre
var pit_floor := 0.0
var seen := false               # Scene 8: you've been up close
var levered := false            # Scene 9: the sunk foot's levered up
var reseated := false           # Scene 9: the mast's upright
var connector_seen := false
var pit_seen := false
var fell := false               # you went over the pit's lip (once is enough)
var print_placed := false
var pulling := false
var _by_hand := false   # pushed upright by you, not pulled by GAR-Y
var _dwell := 0.0
var _model: Node3D
var _station: Node3D
var _mast: Node3D
var _lenses: Array[StandardMaterial3D] = []
var _screen: Label3D
var _beacon := false            # the pack's Pad_Beacon is in (its mast leans on z, not x)
var _foot: Node3D               # its Foot_1
var _hitch := MAST_TOP          # where the cable clips on, mast space
var _pull_from := Vector3(0, 0, 4.8)   # where GAR-Y stands to pull, station space
var _cable: MeshInstance3D
var _crumble_next := 0.0
var _edge_said := false
var _falling := 0.0

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "PadSite"
	add_to_group("pad_site")
	# 23 Nov playtest: the pad on the compass, always, like the lander
	# (explore_hud.gd _home_markers; Settings > Compass > Lander and airlocks).
	add_to_group("landmark")
	add_to_group("home_landmark")
	set_meta("landmark_label", "PAD")
	seen =bool(saved.get("seen", false))
	levered = bool(saved.get("levered", false))
	reseated = bool(saved.get("reseated", false))
	connector_seen = bool(saved.get("connector_seen", false))
	pit_seen = bool(saved.get("pit_seen", false))
	fell = bool(saved.get("fell", false))
	print_placed = bool(saved.get("print_placed", false))
	_find_pit()
	if saved.has("centre"):
		var c: Array = saved.centre
		centre = Vector3(float(c[0]), float(c[1]), float(c[2]))
		yaw = float(saved.get("yaw", 0.0))
	else:
		_choose_spot()
	_build()

func export_state() -> Dictionary:
	return {"centre": [centre.x, centre.y, centre.z], "yaw": yaw, "seen": seen, "levered": levered, "reseated": reseated,
		"connector_seen": connector_seen, "pit_seen": pit_seen, "fell": fell, "print_placed": print_placed}

func centre_2d() -> Vector2:
	return Vector2(centre.x, centre.z)

func pit_centre() -> Vector2:
	return pit

## The buried void, as a path (site metres): from the pit, under the pad,
## and on past it.
func void_path() -> Array:
	var c := centre_2d()
	var on := (c - pit).normalized() if not is_inf(pit.x) else Vector2(-1, 0)
	return [pit if not is_inf(pit.x) else c + on * -60.0, c, c + on * 35.0]

## The beacon's station, where you work on it (site metres).
func beacon_at() -> Vector3:
	return _station.global_position if _station != null else centre

## Why a base can't be set down here, or "" (scripts/walker.gd).
func keep_clear(at: Vector2) -> String:
	if at.distance_to(centre_2d()) < KEEP_CLEAR: return "That's the landing pad"
	if not is_inf(pit.x) and at.distance_to(pit) < pit_edge + 12.0: return "Too near the pit"
	return ""

# ---------- where ----------

func _find_pit() -> void:
	var zone: Dictionary = MHSiteTerrain.region_zone()
	if zone.is_empty(): return
	var file := FileAccess.open("res://data/region_layout.json", FileAccess.READ)
	if file == null: return
	var layout: Variant = JSON.parse_string(file.get_as_text())
	if not (layout is Dictionary): return
	for form in (layout as Dictionary).get("landforms", []):
		if str(form.get("id", "")) != "collapse_pit": continue
		var c: Array = form.centre
		pit = Vector2(float(c[0]) - float(zone.centre[0]), float(c[1]) - float(zone.centre[1]))
		pit_edge = float(form.get("radius", 7.0)) + 1.0
		pit_floor = MHSiteTerrain.height(pit.x, pit.y)

## The flattest ground about 200 m north-west of the pit, clear of the
## lander and the cargo.
func _choose_spot() -> void:
	var lander: Vector3 = world.lander.global_position if world.get("lander") != null else Vector3.ZERO
	if is_inf(pit.x): pit = Vector2(lander.x, lander.z) + Vector2(440, 140)
	var nominal := pit + Vector2(-1, -1).normalized() * PIT_DISTANCE
	var best := nominal
	var best_score := INF
	for ring in 7:
		var steps := 1 if ring == 0 else 12
		for k in steps:
			var at := nominal + Vector2.from_angle(TAU * k / steps) * ring * 8.0
			var to_pit := at.distance_to(pit)
			if to_pit < 170.0 or to_pit > 240.0: continue
			if at.distance_to(Vector2(lander.x, lander.z)) < LANDER_CLEAR: continue
			if _cargo_near(at, 30.0): continue
			var score := _roughness(at) + at.distance_to(nominal) / 400.0
			if score < best_score:
				best_score = score
				best = at
	var heights := _heights(best)
	var mean := 0.0
	for h in heights: mean += h
	mean /= heights.size()
	centre = Vector3(best.x, mean - .1, best.y)
	# The pad's beacon side (+X) faces the pit: that's where the ground went.
	var to_pit := (pit - best).normalized()
	yaw = atan2(-to_pit.y, to_pit.x)

func _heights(at: Vector2) -> Array:
	var out := []
	for dx in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		for dz in [-9.0, 0.0, 9.0]: out.append(MHSiteTerrain.height(at.x + dx, at.y + dz))
	return out

func _roughness(at: Vector2) -> float:
	var hs := _heights(at)
	return float(hs.max()) - float(hs.min())

func _cargo_near(at: Vector2, reach: float) -> bool:
	var field: Node = world.get("drop_field")
	if field == null: return false
	for kind in field.sites:
		var p: Vector3 = field.sites[kind].at
		if Vector2(p.x, p.z).distance_to(at) < reach: return true
	return false

# ---------- the model ----------

func _build() -> void:
	global_position = centre
	rotation.y = yaw
	var scene: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	if scene != null:
		_model = scene.instantiate() as Node3D
		add_child(_model)
		MHPalette.apply(_model)
		_station = _model.find_child("BeaconStation", true, false) as Node3D
		_mast = _model.find_child("BeaconTilt", true, false) as Node3D
	if _station == null:
		_station = _stand_in_station()
		_mast = _station.get_node("BeaconTilt")
	# The station sits on its own ground, just off the pad.
	var foot := _station.global_position
	_station.position.y += MHSiteTerrain.height(foot.x, foot.z) - centre.y
	# The pad's pit-side sections have dropped.
	for sector in ["Sector_07", "Sector_08"]:
		var node := _model.find_child(sector, true, false) as Node3D if _model != null else null
		if node == null: continue
		node.position.y -= DROP
		node.rotation.z = deg_to_rad(-1.2)
	_solid(_model, ["Sector_", "LandingPad_"])
	_cracks()
	_fit_beacon()
	_lamp_material()
	_screen = Label3D.new()
	_screen.name = "TiltReadout"
	_screen.outline_size = 0
	_screen.modulate = Color("#9FE7B2")
	_screen.no_depth_test = false
	_screen.double_sided = false
	var screen_mesh := _mast.get_node_or_null("TiltScreen") as MeshInstance3D if _beacon else null
	if screen_mesh != null:
		# The pack's blank 16:9 display, front on −Z: the game draws the readout.
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("#0B0F0D")
		dark.roughness = .35
		screen_mesh.material_override = dark
		screen_mesh.add_child(_screen)
		_screen.pixel_size = .00042
		_screen.font_size = 40
		_screen.position = Vector3(0, 0, -.003)
		_screen.rotation.y = PI
	else:
		_screen.pixel_size = .0011
		_screen.font_size = 36
		_station.add_child(_screen)
		_screen.position = BOX + Vector3(.19, .04, 0)
		_screen.rotation.y = PI * .5
	if _beacon:
		var lever := _foot.get_node_or_null("LeverPoint_1") as Node3D
		var hitch := _mast.get_node_or_null("HitchPoint") as Node3D
		var plug := _mast.get_node_or_null("Connector") as Node3D
		if hitch != null: _hitch = hitch.position
		_add_point("foot", _station.to_local(lever.global_position) if lever != null else Vector3(.6, .1, -.35), .3, _station)
		_add_point("lead", plug.position if plug != null else Vector3(-.09, .3, -.26), .22, _mast)
		_add_point("mast", _hitch, .35, _mast)
	else:
		_add_point("foot", SUNK_FOOT, .3, _station)
		_add_point("lead", BOX, .22, _station)
		_add_point("mast", MAST_TOP, .35, _mast)
	_dress_pad()
	_show_state()
	_dress_pit()
	_place_print_shop.call_deferred()

func _stand_in_station() -> Node3D:
	var station := Node3D.new()
	station.name = "BeaconStation"
	add_child(station)
	station.position = Vector3(10.78, 0, 4.85)
	var tilt := Node3D.new()
	tilt.name = "BeaconTilt"
	station.add_child(tilt)
	tilt.position = Vector3(0, .29, 0)
	var mast := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.1, 1.7, .1)
	mast.mesh = box
	var source := StandardMaterial3D.new()
	source.resource_name = "rover_white"
	mast.material_override = MHPalette.material(source)
	mast.position = Vector3(0, .85, 0)
	tilt.add_child(mast)
	return station

## The pack's Pad_Beacon stands where the pad model's own station stood
## (that one's hidden), its front turned to the pad.
func _fit_beacon() -> void:
	var scene: PackedScene = load(BEACON) if ResourceLoader.exists(BEACON) else null
	if scene == null: return
	var model := scene.instantiate() as Node3D
	var root := model.get_node_or_null("LandingBeacon") as Node3D
	var mast := root.get_node_or_null("Mast") as Node3D if root != null else null
	if mast == null:
		model.free()
		return
	var holder := Node3D.new()
	holder.name = "PadBeacon"
	add_child(holder)
	var at := to_local(_station.global_position)
	holder.position = at
	holder.rotation.y = atan2(at.x, at.z)   # −Z (the front) towards the pad's centre
	holder.add_child(model)
	MHPalette.apply(model)
	_station.visible = false
	_station = root
	_mast = mast
	_foot = root.get_node_or_null("Foot_1") as Node3D
	_beacon = true
	_pull_from = Vector3(-4.8, 0, 0)   # its mast leans to +X
	# The lead hangs torn: the whole one's waiting on a printed connector (chunk 3).
	for part in ["Lead", "Connector"]:
		var node := _mast.get_node_or_null(part) as Node3D
		if node != null:
			node.scale = Vector3.ONE
			node.visible = false
	for part in ["LeadLoose", "LeadTorn"]:
		var node := _mast.get_node_or_null(part) as Node3D
		if node != null: node.visible = true

func _lamp_material() -> void:
	if _mast == null: return
	var lenses: Array = []
	var lamp := _mast.get_node_or_null("Lamp")
	if _beacon and lamp != null: lenses = lamp.find_children("*", "MeshInstance3D", true, false)
	else: lenses = _mast.find_children("*lamp_amber*", "MeshInstance3D", true, false)
	for mesh in lenses:
		var m := mesh as MeshInstance3D
		var source := m.get_active_material(0) as StandardMaterial3D
		if source == null: continue
		var lens := source.duplicate() as StandardMaterial3D
		m.material_override = lens
		_lenses.append(lens)
		if not _beacon: return

## How far the station's tipped on its sunk foot, and how far the mast leans
## (degrees): the two models hinge differently.
func _set_sink(degrees: float) -> void:
	if _station == null: return
	if _beacon:
		_station.basis = Basis(FOOT_AXIS, deg_to_rad(degrees))
		if _foot != null: _foot.basis = Basis(FOOT_AXIS, deg_to_rad(FOOT_SINK * degrees / SINK))
	else:
		_station.rotation.z = deg_to_rad(-degrees)

func _set_lean(degrees: float) -> void:
	if _mast == null: return
	if _beacon: _mast.rotation.z = deg_to_rad(-degrees)
	else: _mast.rotation.x = deg_to_rad(-degrees)

func _lean() -> float:
	if _mast == null: return 0.0
	return absf(rad_to_deg(_mast.rotation.z if _beacon else _mast.rotation.x))

## The pad's dressing (Pad_Site): lit corner markers, broken slabs where the
## crack runs off the pad, and fractured edges along the dropped sections.
func _dress_pad() -> void:
	var half := Vector2(9.0, 9.0)
	if _model != null:
		half = Vector2(9.513, 9.5025)   # the pad model's own footprint, less its beacon
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var c: Vector2 = corner
		var at := Vector2(c.x * (half.x + .5), c.y * (half.y + .5))
		_part("pad_corner_marker", at, 0.0, -.12)   # dark: the pad's lost its power
	# Out where the crack leaves the pad for the beacon's foot.
	var beacon := Vector2(to_local(_station.global_position).x, to_local(_station.global_position).z)
	var mid := Vector2(8.4, -3.5).lerp(beacon + Vector2(.7, -.5), .45)
	var run := (beacon - Vector2(8.4, -3.5)).normalized()
	var step := _part("cracked_slab_step", mid, atan2(run.x, run.y), -.02)   # its split runs on Z
	if step != null:
		var lower := step.find_child("Half_B", true, false) as Node3D
		if lower != null: lower.position.y -= .085
	_part("cracked_slab_a", Vector2(10.6, -6.4), .4, -.04, Vector3(0, 0, deg_to_rad(-3)))
	_part("cracked_slab_b", Vector2(7.2, -10.9), -.7, -.05, Vector3(deg_to_rad(2.5), 0, 0))
	# Along the two cracks across the pad: the strips run on Z, fractured face on +X.
	for crack in [[Vector2(.8, -.3), Vector2(8.4, -3.5)], [Vector2(.6, .5), Vector2(3.6, 8.4)]]:
		var a: Vector2 = crack[0]
		var b: Vector2 = crack[1]
		var pieces := maxi(1, floori(a.distance_to(b) / 3.0))
		for i in pieces:
			var p := a.lerp(b, (float(i) + .5) / float(pieces))
			var strip := _part("pad_crack_edge_strip", p, atan2(b.x - a.x, b.y - a.y), 0.0)
			if strip != null: strip.position.y = .17

## One of the pack's pieces, set on the ground at `at` (pad space).
func _part(id: String, at: Vector2, turn: float, sink: float, tilt := Vector3.ZERO) -> Node3D:
	var path := PARTS % id
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene == null: return null
	var part := scene.instantiate() as Node3D
	add_child(part)
	MHPalette.apply(part)
	part.position = Vector3(at.x, 0, at.y)
	var g := to_global(part.position)
	part.position.y = MHSiteTerrain.height(g.x, g.z) - centre.y + sink
	part.rotation = Vector3(tilt.x, turn, tilt.z)
	if id.begins_with("cracked_slab"): _solid(part, [""])
	return part

## Walk-on collision for the pad's sections and the broken slabs (you sank a
## few centimetres into them): each mesh whose name starts with one of
## `prefixes` gets a static trimesh body, so a dropped or tilted section is
## solid where it really sits.
func _solid(root: Node, prefixes: Array) -> void:
	if root == null: return
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := str(mesh.name)
		for prefix in prefixes:
			if mesh_name.begins_with(str(prefix)):
				(mesh as MeshInstance3D).create_trimesh_collision()
				break

## Fresh cracks: across the pad where the sections dropped, and on out to
## the beacon's sunk foot.
func _cracks() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#1B1310")
	material.roughness = 1.0
	var beacon := Vector2(_station.position.x, _station.position.z)
	for run in [[Vector2(.8, -.3), Vector2(8.4, -3.5)], [Vector2(.6, .5), Vector2(3.6, 8.4)], [Vector2(8.4, -3.5), beacon + Vector2(.7, -.5)], [beacon + Vector2(.7, -.5), beacon + Vector2(3.4, -1.6)]]:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(.07, .06, a.distance_to(b))
		mesh.mesh = box
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		var mid := (a + b) * .5
		mesh.position = Vector3(mid.x, .24, mid.y)
		var g := to_global(mesh.position)
		var ground := MHSiteTerrain.height(g.x, g.z) - centre.y
		if mid.length() > 9.0: mesh.position.y = ground + .01
		mesh.rotation.y = atan2(b.x - a.x, b.y - a.y)

func _show_state() -> void:
	if _station == null: return
	_set_sink(0.0 if levered else SINK)
	_set_lean(0.0 if reseated else LEAN)
	for lead in ["BrokenLead", "BrokenMastTail"]:
		var node := _station.find_child(lead, true, false) as Node3D
		if node != null:
			node.scale = Vector3.ONE
			node.visible = true   # the lead stays torn until the connector's printed (chunk 3)
	var mended := _station.find_child("RepairedLead", true, false) as Node3D
	if mended != null: mended.visible = false
	for lens in _lenses: lens.emission_enabled = false
	_screen_text()

func _screen_text() -> void:
	if _screen == null: return
	var tilt := 0.0 if reseated else (LEAN + (0.0 if levered else SINK))
	if _mast != null and pulling: tilt = _lean()
	_screen.text = "TILT  %.1f°\nLEAD  OPEN" % maxf(tilt, .3 if reseated else tilt)

# ---------- the hold-E points ----------

func _add_point(id: String, at: Vector3, radius: float, parent: Node3D) -> void:
	var point := HoldPoint.new()
	point.site = self
	point.id = id
	point.radius = radius
	point.name = "Point_" + id
	parent.add_child(point)
	point.position = at

func prompt_for(id: String, holding: bool) -> Dictionary:
	match id:
		"foot":
			if levered: return {"label": "The foot's back on solid ground", "primary": ""}
			return {"label": "A ballast foot, sunk on a fresh crack", "primary": "Levering it up…" if holding else "Hold to lever it up"}
		"lead":
			return {"label": "The power lead's torn out of the box", "primary": "" if connector_seen else "Look closer"}
		"mast":
			if reseated: return {"label": "The mast's upright", "primary": ""}
			if pulling: return {"label": "Coming upright…" if _by_hand else "GAR-Y's pulling", "primary": ""}
			if not levered: return {"label": "The mast leans %d°" % roundi(LEAN), "primary": "Its foot's sunk: lever that first"}
			if _can_tow(): return {"label": "The mast leans %d°" % roundi(LEAN), "primary": "Clip GAR-Y's cable on"}
			return {"label": "The mast leans %d°" % roundi(LEAN), "primary": "Pushing…" if holding else "Hold to push it upright"}
	return {}

## A tap on a point. Returns whether it did anything; `hold` comes back true
## when the point should be held (HoldPoint times it).
func press(id: String) -> Dictionary:
	match id:
		"foot": return {"ok": not levered, "hold": LEVER_SECONDS if not levered else 0.0}
		"lead":
			if not connector_seen:
				connector_seen = true
				_think("pad_connector")
				MHAudio.sfx("ui_click", -8.0)
			return {"ok": true, "hold": 0.0}
		"mast":
			if reseated or pulling or not levered:
				if not levered and not reseated: MHAudio.sfx("invalid", -8.0)
				return {"ok": false, "hold": 0.0}
			if _can_tow():
				pull()
				return {"ok": true, "hold": 0.0}
			return {"ok": true, "hold": PUSH_SECONDS}
	return {"ok": false, "hold": 0.0}

func held_done(id: String) -> void:
	match id:
		"foot": lever()
		"mast":
			_by_hand = true   # 23 Nov playtest: it said GAR-Y was pulling before you'd met it
			_upright(1.6)

## The sunk foot comes up out of the crack.
func lever() -> void:
	if levered: return
	levered = true
	MHAudio.sfx_at("land", _station, -4.0, .7)
	var t := create_tween()
	t.tween_method(_set_sink, SINK, 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_screen_text)

func _can_tow() -> bool:
	var pod: Node = world.get("lifepod")
	var gary: Node3D = world.get("scout_rover")
	return pod != null and (pod.prints as Dictionary).has("hitch") and gary != null and is_instance_valid(gary) and bool(world.get("gary_met")) and not bool(gary.get("rescuing"))

## GAR-Y backs off on the far side, the cable goes taut, and the mast comes
## upright.
func pull() -> void:
	if pulling or reseated: return
	pulling = true
	var gary: Node3D = world.get("scout_rover")
	var spot := _station.to_global(_pull_from)
	spot.y = MHSiteTerrain.height(spot.x, spot.z)
	if gary != null:
		if not str(gary.task).is_empty(): gary.call("_end_task")
		gary.set("staying", false)
		gary.call("_start", "goto", spot, {"quiet": true})
		gary.set("_ordered", true)
		var waited := 0.0
		while waited < 25.0 and is_instance_valid(gary) and Vector2(gary.global_position.x - spot.x, gary.global_position.z - spot.z).length() > 1.6 and not str(gary.task).is_empty():
			await get_tree().create_timer(.25).timeout
			waited += .25
	_cable = MeshInstance3D.new()
	_cable.name = "TowCable"
	var tube := CylinderMesh.new()
	tube.top_radius = .01
	tube.bottom_radius = .01
	tube.height = 1.0
	_cable.mesh = tube
	var source := StandardMaterial3D.new()
	source.resource_name = "graphite"
	_cable.material_override = MHPalette.material(source)
	world.add_child(_cable)
	MHAudio.sfx("suit_clamp", -6.0)
	if gary != null and is_instance_valid(gary): gary.call("_say", "curious")
	await get_tree().create_timer(.6).timeout
	_upright(PULL_SECONDS)

func _upright(seconds: float) -> void:
	pulling = true
	var gary: Node3D = world.get("scout_rover")
	if gary != null and is_instance_valid(gary) and _cable != null: MHAudio.sfx_at("place", gary, -6.0, 1.4)
	var t := create_tween()
	t.tween_method(_set_lean, _lean(), 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_reseated)

func _reseated() -> void:
	pulling = false
	_by_hand = false
	reseated = true
	if _cable != null and is_instance_valid(_cable): _cable.queue_free()
	_cable = null
	MHAudio.sfx_at("suit_clamp", _station, -4.0, .8)
	var gary: Node3D = world.get("scout_rover")
	if gary != null and is_instance_valid(gary):
		gary.call("_say", "happy")
		if str(gary.task) == "goto": gary.call("_end_task")
	_screen_text()

func _think(id: String) -> void:
	var notes: Node = world.get("notes")
	if notes != null: notes.think(id)

# ---------- the pit ----------

func _dress_pit() -> void:
	if is_inf(pit.x): return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var path := ROCKS % (i % 8)
		var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
		if scene == null: continue
		var rock := scene.instantiate() as Node3D
		world.add_child.call_deferred(rock)
		var r := rng.randf_range(0.0, pit_edge - 2.5) if i < 7 else pit_edge + rng.randf_range(.5, 2.0)
		var at := pit + Vector2.from_angle(rng.randf() * TAU) * r
		rock.position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y) - .1, at.y)
		rock.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		rock.scale = Vector3.ONE * rng.randf_range(.25, .7) * (1.0 if i < 7 else .5)
	# The lip itself (Pit_Lip): an undercut overhang on the side you'd come
	# from the pad, and loose rubble round the rim.
	var toward := (Vector2(centre.x, centre.z) - pit).normalized()
	var undercut := _lip_piece("pit_lip_undercut", pit + toward * (pit_edge + .9), atan2(toward.x, toward.y))
	if undercut != null: undercut.position.y += .02
	for i in 10:
		var a := rng.randf() * TAU
		var at := pit + Vector2.from_angle(a) * (pit_edge + rng.randf_range(.2, 2.4))
		var piece := _lip_piece("pit_lip_rubble_0%d" % (i % 4 + 1), at, rng.randf() * TAU)
		if piece != null: piece.position.y += .04

func _lip_piece(id: String, at: Vector2, turn: float) -> Node3D:
	var path := PARTS % id
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene == null: return null
	var piece := scene.instantiate() as Node3D
	world.add_child.call_deferred(piece)
	MHPalette.apply(piece)
	piece.position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y), at.y)
	piece.rotation.y = turn
	return piece

func _process(delta: float) -> void:
	var player: Node3D = world.get("player")
	if player == null: return
	var suit: Node = world.get("suit")
	var outside: bool = suit == null or str(suit.get("where")) == "outside"
	var you := player.global_position
	# Scene 8: up close, long enough for Castle to see it on your helmet camera.
	if not seen and outside and _station != null and Vector2(you.x - _station.global_position.x, you.z - _station.global_position.z).length() < SEEN_REACH:
		_dwell += delta
		if _dwell > 1.0 and _dwell - delta <= 1.0: _think("pad_wrong")
		if _dwell >= SEEN_SECONDS: seen = true
	if _cable != null and is_instance_valid(_cable): _cable_frame()
	if is_inf(pit.x) or not outside: return
	var r := Vector2(you.x - pit.x, you.z - pit.y).length()
	if not pit_seen and r < pit_edge + 5.0:
		pit_seen = true
		_think("pit_down")
	_lip(player, r, delta)

## Scene 11: the crumbling lip, and the last metre.
func _lip(player: Node3D, r: float, delta: float) -> void:
	if _falling > 0.0:
		_falling += delta
		if _falling > 1.6:
			_falling = 0.0
			var suit: Node = world.get("suit")
			if suit != null and not bool(suit.get("passed_out")) and suit.has_method("pass_out"): suit.pass_out()
		return
	if bool(player.get_meta("driving", false)) or bool(player.get_meta("riding", false)): return
	if r > pit_edge + CRUMBLE or player.global_position.y < pit_floor + 3.0: return
	if not _edge_said:
		_edge_said = true
		_think("pit_edge")
	# The wrist ring flickers while the ground's going (scripts/info_screen.gd
	# reads this): stronger on the last couple of metres.
	player.set_meta("unsteady_until", Time.get_ticks_msec() + 400)
	player.set_meta("unsteady", clampf(1.0 - (r - pit_edge) / CRUMBLE, .3, 1.0))
	_crumble_next -= delta
	if _crumble_next <= 0.0:
		_crumble_next = randf_range(.8, 1.6) * (.5 if r < pit_edge + 1.8 else 1.0)
		_crumble(player)
	if r <= pit_edge + GIVES: _give_way(player)

func _crumble(player: Node3D) -> void:
	MHAudio.sfx_at("land", player, -10.0, randf_range(.45, .6))
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera != null:
		var t := create_tween()
		t.tween_property(camera, "v_offset", randf_range(-.03, -.015), .06)
		t.tween_property(camera, "h_offset", randf_range(-.015, .015), .06)
		t.tween_property(camera, "v_offset", 0.0, .2)
		t.tween_property(camera, "h_offset", 0.0, .1)
	# A few stones go over the edge.
	var you := Vector2(player.global_position.x, player.global_position.z)
	var out := (you - pit).normalized()
	for i in 2:
		var stone := _stone()
		world.add_child(stone)
		var at := pit + out * (pit_edge + randf_range(.1, .6)) + Vector2(-out.y, out.x) * randf_range(-1.2, 1.2)
		stone.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y) + .05, at.y)
		var t := create_tween()
		t.tween_property(stone, "global_position", Vector3(at.x - out.x * 1.2, pit_floor, at.y - out.y * 1.2), randf_range(.9, 1.3)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_callback(stone.queue_free)

## A stone off the lip: the pack's smallest rubble, scaled down to a handful.
func _stone() -> Node3D:
	var path := PARTS % ("pit_lip_rubble_0%d" % randi_range(1, 4))
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene != null:
		var piece := scene.instantiate() as Node3D
		MHPalette.apply(piece)
		piece.scale = Vector3.ONE * randf_range(.18, .35)
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		return piece
	var stone := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * randf_range(.05, .12)
	stone.mesh = box
	var source := StandardMaterial3D.new()
	source.resource_name = "graphite"
	stone.material_override = MHPalette.material(source)
	return stone

## The lip goes: over you go, and down.
func _give_way(player: Node3D) -> void:
	fell = true
	_falling = .01
	var radio: Node = world.get("radio")
	if radio != null: (radio.flags as Dictionary)["fell_in_pit"] = true
	MHAudio.sfx_at("land", player, -2.0, .4)
	var you := Vector2(player.global_position.x, player.global_position.z)
	var inward := (pit - you).normalized()
	var over := pit - inward * (pit_edge - 1.6)
	player.global_position = Vector3(over.x, player.global_position.y + .2, over.y)
	if player is CharacterBody3D: (player as CharacterBody3D).velocity = Vector3(inward.x, -1.0, inward.y) * 2.0

# ---------- the cable ----------

func _cable_frame() -> void:
	var gary: Node3D = world.get("scout_rover")
	if gary == null or not is_instance_valid(gary) or _mast == null: return
	var exit := gary.find_child("CableOut", true, false) as Node3D
	var from := exit.global_position if exit != null else gary.global_position + Vector3(0, .4, 0)
	var to := _mast.to_global(_hitch)
	var length := from.distance_to(to)
	(_cable.mesh as CylinderMesh).height = length
	_cable.global_position = (from + to) * .5
	var dir := (to - from).normalized()
	if absf(dir.dot(Vector3.UP)) < .99:
		_cable.look_at_from_position(_cable.global_position, to, Vector3.UP)
		_cable.rotate_object_local(Vector3.RIGHT, PI * .5)

# ---------- pallet 6 ----------

## The Print Shop's pallet came down within sight of the pad, on the side
## away from the pit.
func _place_print_shop() -> void:
	var field: Node = world.get("drop_field")
	if print_placed or field == null or not field.has_method("_add_print_site"): return
	print_placed = true
	if field.sites.has("print_shop"): return
	var c := centre_2d()
	var away := (c - pit).normalized() if not is_inf(pit.x) else Vector2(-1, 0)
	var best := Vector2.INF
	var best_rough := INF
	for turn in [-70.0, 70.0, -50.0, 50.0]:
		var at := c + away.rotated(deg_to_rad(turn)) * 75.0
		var rough := _roughness(at)
		if rough < best_rough:
			best_rough = rough
			best = at
	var back := c - best
	field._add_print_site({"at": [best.x, MHSiteTerrain.height(best.x, best.y), best.y], "yaw": atan2(back.x, back.y)})

## One place to hold E (or tap it).
class HoldPoint extends StaticBody3D:
	var site: Node
	var id := ""
	var radius := .3
	var _hold := 0.0
	var _held := 0.0

	func _ready() -> void:
		set_meta("interaction_target", self)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		add_child(shape)

	func interaction_prompt() -> Dictionary:
		return site.prompt_for(id, _hold > 0.0)

	func interact(_player: Node = null) -> bool:
		var result: Dictionary = site.press(id)
		_hold = float(result.get("hold", 0.0))
		_held = 0.0
		return bool(result.get("ok", false))

	func _process(delta: float) -> void:
		if _hold <= 0.0: return
		var player: Node3D = site.world.player
		if not Input.is_key_pressed(KEY_E) or player.global_position.distance_to(global_position) > 3.2:
			_hold = 0.0
			return
		hold_for(delta * float(player.get_meta("hands_speed", 1.0)))

	## E held this long (tests call it directly).
	func hold_for(delta: float) -> bool:
		if _hold <= 0.0:
			var result: Dictionary = site.press(id)
			_hold = float(result.get("hold", 0.0))
			if _hold <= 0.0: return false
		_held += delta
		if _held < _hold: return false
		_hold = 0.0
		site.held_done(id)
		return true
