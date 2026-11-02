extends Node3D

## Chapter one: GAR-Y's radar readings, out on the ground (playtest, 2 Nov).
## Every reading leaves a survey stake: a thin pole with a beacon whose colour
## is the signal (grey weak, amber faint, ice blue strong). Near a stake, a
## ring on the ground marks the 7 m you can take a core in. Once a core has
## been taken there the beacon stops blinking (steady for ice, dark for dry)
## for a few seconds, then the stake is pulled up: it's done its job. The Tab
## map's survey layer keeps a tick or cross where it stood.
## Holding T (the wrist pad) and pressing F sends a survey ping: every stake
## within PING_RANGE flashes and shows through the terrain with its distance
## for a few seconds. The strongest stake not yet cored is on the compass.
## Nothing new is saved: stakes come from GAR-Y's readings (ice_samples) and
## the cores taken (MHChapterOne.cores).

const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
const PING_RANGE := 400.0
const PING_SECONDS := 6.0
const RING_NEAR := 30.0     # rings show within this of you (m)
const FAINT := .15
const STRONG := .35
const WEAK_COLOUR := Color("#9AA3A8")
const FAINT_COLOUR := Color("#F2B84B")
const STRONG_COLOUR := Color("#7FE6FF")
const GONE_AFTER := 4.0     # seconds a cored stake stays before it's pulled up
const RING_HEIGHT := 1.0    # the ring's decal: thin, so it stays on the ground

var world: Node
var _signature := ""
var _check := 0.0
var _ping_left := 0.0
var _stakes: Array = []      # [{node, ring, at: Vector3, reading, cored: "" | "ice" | "dry"}]
var _beacons := {}           # colour key -> blinking material
var _pole_material: StandardMaterial3D
var _ring_texture: Texture2D
var _compass: Node3D
var _overlay: Control
## Cored readings (str of their spot) -> when this session first saw them
## cored (msec), or -1 for ones cored before the game was loaded.
var _cored_seen := {}
var _loaded := false

func setup(target_world: Node) -> Node:
	world = target_world
	return self

func _ready() -> void:
	name = "SurveyStakes"
	add_to_group("survey_stakes")
	_pole_material = StandardMaterial3D.new()
	_pole_material.albedo_color = Color("#C9CFD2")
	_pole_material.roughness = .6
	for key in ["weak", "faint", "strong"]:
		var material := StandardMaterial3D.new()
		material.albedo_color = colour_for(key)
		material.emission_enabled = true
		material.emission = colour_for(key)
		_beacons[key] = material
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#4A4F52")
	_beacons["dry"] = dark
	var steady := StandardMaterial3D.new()
	steady.albedo_color = STRONG_COLOUR
	steady.emission_enabled = true
	steady.emission = STRONG_COLOUR
	steady.emission_energy_multiplier = 1.6
	_beacons["ice"] = steady
	_ring_texture = _make_ring()
	_compass = Node3D.new()
	_compass.name = "SurveyCompass"
	add_child(_compass)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_ping)
	if world.get("overlay_layer") != null: world.overlay_layer.add_child(_overlay)

static func colour_for(key: String) -> Color:
	match key:
		"strong": return STRONG_COLOUR
		"faint": return FAINT_COLOUR
	return WEAK_COLOUR

static func strength(reading: float) -> String:
	return "strong" if reading >= STRONG else ("faint" if reading >= FAINT else "weak")

## Every stake as {at: Vector2 (world x, z), reading, cored} (the Tab map's survey layer).
func readings() -> Array:
	var out: Array = []
	for sample in ICE_KNOWLEDGE.samples(get_tree()):
		var at := Vector2(float(sample.x), float(sample.y))
		out.append({"at": at, "reading": float(sample.z), "cored": cored_at(at)})
	return out

## "ice", "dry" or "" (no core within reach of this reading yet).
static func cored_at(at: Vector2) -> String:
	var found := ""
	for core in MHChapterOne.cores:
		if Vector2(float(core.x), float(core.z)).distance_to(at) <= ICE_KNOWLEDGE.CORE_REACH:
			if not bool(core.get("dry", false)): return "ice"
			found = "dry"
	return found

## The nearest stake still standing (not yet cored) to a point:
## {at: Vector2, distance} or {}.
func nearest(point: Vector2) -> Dictionary:
	var best := {}
	for sample in ICE_KNOWLEDGE.samples(get_tree()):
		var at := Vector2(float(sample.x), float(sample.y))
		if _cored_seen.has(str(at)) or not cored_at(at).is_empty(): continue
		var gap := at.distance_to(point)
		if best.is_empty() or gap < float(best.distance): best = {"at": at, "distance": gap}
	return best

## The survey ping (T + F): the stakes flash and show through the ground.
func ping() -> bool:
	if _stakes.is_empty(): return false
	_ping_left = PING_SECONDS
	MHAudio.sfx("suit_beep", -10.0)
	return true

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = .5
		_refresh()
	var player: Node3D = world.get("player")
	if player == null: return
	# Uncored beacons blink slowly; the ping makes them all flare.
	var pulse := .5 + .5 * sin(Time.get_ticks_msec() * .004)
	var energy := lerpf(.3, 1.8, pulse)
	if _ping_left > 0.0:
		_ping_left -= delta
		energy = 4.0 * (.6 + .4 * sin(Time.get_ticks_msec() * .02))
	for key in ["weak", "faint", "strong"]: (_beacons[key] as StandardMaterial3D).emission_energy_multiplier = energy
	# Rings only outside: indoors they'd show on the floor.
	var builder: Node = world.get("builder")
	var outside: bool = builder == null or not builder.is_inside(player.global_position)
	var now := Time.get_ticks_msec()
	for stake in _stakes:
		(stake.ring as Node3D).visible = outside and (stake.at as Vector3).distance_to(player.global_position) < RING_NEAR
		# A cored stake is pulled up after a few seconds.
		if int(stake.get("gone_at", 0)) > 0 and now >= int(stake.gone_at) and not stake.has("going"):
			stake["going"] = true
			var going := (stake.node as Node3D).create_tween()
			going.tween_property(stake.node, "scale", Vector3(1, .01, 1), .5)
			going.tween_callback(func(): _signature = "")
	_overlay.visible = _ping_left > 0.0
	if _overlay.visible: _overlay.queue_redraw()

## Rebuilds the stakes when the readings or the cores change.
func _refresh() -> void:
	var list := readings()
	var signature := str(list.size()) + ":" + str(MHChapterOne.cores.size())
	if not list.is_empty(): signature += ":" + str(list[-1].at)
	if signature == _signature: return
	_signature = signature
	for stake in _stakes: (stake.node as Node).queue_free()
	_stakes.clear()
	var best := {}
	var now := Time.get_ticks_msec()
	for entry in list:
		var at := Vector2(entry.at)
		# Cored: shown for a few seconds, then gone. Cored before this game
		# was loaded: already gone.
		var gone_at := 0
		if not str(entry.cored).is_empty():
			if not _cored_seen.has(str(at)): _cored_seen[str(at)] = now if _loaded else -1
			var seen := int(_cored_seen[str(at)])
			if seen < 0 or now >= seen + int(GONE_AFTER * 1000.0) + 600: continue
			gone_at = seen + int(GONE_AFTER * 1000.0)
		var ground := MHCaves.ground_y(Vector3(at.x, 0.0, at.y))
		var spot := Vector3(at.x, ground, at.y)
		var key := strength(float(entry.reading))
		var cored := str(entry.cored)
		var node := _stake(spot, _beacons[cored if not cored.is_empty() else key])
		var ring := Decal.new()
		ring.size = Vector3(ICE_KNOWLEDGE.CORE_REACH * 2.0, RING_HEIGHT, ICE_KNOWLEDGE.CORE_REACH * 2.0)
		ring.normal_fade = .5   # flat ground only, not walls
		ring.texture_albedo = _ring_texture
		ring.modulate = colour_for(key) if cored.is_empty() else Color(1, 1, 1, .35)
		ring.albedo_mix = .85
		ring.upper_fade = .2
		ring.lower_fade = .2
		ring.visible = false
		node.add_child(ring)
		add_child(node)
		_stakes.append({"node": node, "ring": ring, "at": spot, "reading": float(entry.reading), "cored": cored, "key": key, "gone_at": gone_at})
		if cored.is_empty() and float(entry.reading) >= FAINT and (best.is_empty() or float(entry.reading) > float(best.reading)):
			best = {"at": spot, "reading": float(entry.reading)}
	_loaded = true
	# The compass: the strongest reading still to core.
	if best.is_empty():
		if _compass.is_in_group("landmark"): _compass.remove_from_group("landmark")
	else:
		_compass.global_position = best.at
		_compass.set_meta("landmark_label", "STRONG SIGNAL" if float(best.reading) >= STRONG else "FAINT SIGNAL")
		if not _compass.is_in_group("landmark"): _compass.add_to_group("landmark")

## A stake: a thin pole a little over a metre tall with a beacon on top.
func _stake(spot: Vector3, beacon: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "SurveyStake"
	root.position = spot
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = .012; pole_mesh.bottom_radius = .018; pole_mesh.height = 1.1
	pole.mesh = pole_mesh
	pole.material_override = _pole_material
	pole.position.y = .55
	root.add_child(pole)
	var foot := MeshInstance3D.new()
	var foot_mesh := CylinderMesh.new()
	foot_mesh.top_radius = .05; foot_mesh.bottom_radius = .07; foot_mesh.height = .08
	foot.mesh = foot_mesh
	foot.material_override = _pole_material
	foot.position.y = .04
	root.add_child(foot)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = .045; cap_mesh.height = .09
	cap.mesh = cap_mesh
	cap.material_override = beacon
	cap.position.y = 1.14
	root.add_child(cap)
	return root

## A soft ring for the decal: the edge of the ground you can core.
static func _make_ring() -> Texture2D:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := Vector2(size, size) * .5
	for y in size:
		for x in size:
			var r := Vector2(x + .5, y + .5).distance_to(middle) / (size * .5)
			var a := clampf(1.0 - absf(r - .95) / .035, 0.0, 1.0) * .9
			# a faint dashed inner wash so the area reads, not just its edge
			if r < .93: a = maxf(a, .06)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)

## The ping: a marker over every stake in range, through the ground, with its distance.
func _draw_ping() -> void:
	var camera := get_viewport().get_camera_3d()
	var player: Node3D = world.get("player")
	if camera == null or player == null: return
	var font := ThemeDB.fallback_font
	var fade := clampf(_ping_left / 1.5, 0.0, 1.0)
	for stake in _stakes:
		var top: Vector3 = (stake.at as Vector3) + Vector3.UP * 1.2
		var gap := top.distance_to(player.global_position)
		if gap > PING_RANGE or camera.is_position_behind(top): continue
		var at := camera.unproject_position(top)
		var colour: Color = colour_for(str(stake.key)) if str(stake.cored).is_empty() else (STRONG_COLOUR if stake.cored == "ice" else WEAK_COLOUR)
		colour.a = fade
		var d := 7.0
		_overlay.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)]), colour)
		var text := "%d m" % roundi(gap)
		if stake.cored == "ice": text += " · cored, ice"
		elif stake.cored == "dry": text += " · cored, dry"
		_overlay.draw_string_outline(font, at + Vector2(11, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, .8 * fade))
		_overlay.draw_string(font, at + Vector2(11, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
