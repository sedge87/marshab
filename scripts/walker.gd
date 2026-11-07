extends Node3D

## Walker 1, carrying the General Module (step 3c, docs/systems-and-items.md
## §14; the model is asset_packs/walker_v1/source/build_walker.py).
## - It stalled about 2 km out after the storm: one wheel packed with dust,
##   its fault lamp blinking.
## - The night it moves (scripts/lifepod.gd walker_night) it leaves tracks
##   across the near ring, and a leg panel it shed. Photograph the tracks and
##   send the picture up from the slate: on the next pass Castellanos texts
##   Rao's photo of where it stopped. Or follow them, or spot its lamp from
##   high ground.
## - Dig the dust out (hold E at leg 4's wheel) and it walks home, parking by
##   the lander.
## - Then B opens the Site plan with only the module and its airlock
##   (scripts/build_rules.gd). Close the plan and it carries the module there,
##   stands over the spot and lowers it.
## - Down: the fit-out kit is yours to place, the module's plans join your
##   own, and the first night in a real room follows.

const MODEL := preload("res://assets/companions/walker.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const BUILD_RULES := preload("res://scripts/build_rules.gd")
const ID := "find:walker"
const NAME := "Walker 1"
const SPEED := 2.0              # m/s: about 2 km in a quarter of a sol
const TURN := .4                # rad/s
const CLEAN_SECONDS := 4.0
const SEE_NEAR := 700.0         # you see it this close
const SEE_HIGH := 1500.0        # ... or this far from ground this much higher
const HIGH_ABOVE := 10.0
const PARK_FROM_LANDER := 48.0
const TRACKS_FROM := 220.0      # the tracks run this far out from the lander ...
const TRACKS_TO := 1150.0       # ... to here (then the ground's too hard to show them)
const TRACK_STEP := 1.6
const TRACK_SPAN := 7.7         # the wheels' half-span
const TEXT_DELAY := 75.0        # seconds to the orbiter's next pass
const LOWER_SECONDS := 9.0
const MODULE_BOTTOM := 1.25     # the carried module's floor above the ground
const WHEEL_R := .62
const FORK := Vector3(7.7, 1.17, -5.0)   # leg 4's wheel fork, in the model
const PHOTO_SIZE := Vector2i(480, 300)
const PHOTO_METRES := 70.0

var world: Node
var state := "stalled"          # stalled, walking, parked, carrying, lowering, done
var home := Vector3.INF         # where it parks by the lander
var target := Vector3.INF       # the module's spot
var target_yaw := 0.0
var cleaned := false
var seen := false
var tracks_laid := false
var sent := false
var first_night := false
var photo: Texture2D
var _text_left := -1.0
var _model: Node3D
var _body: Node3D
var _module: Node3D
var _lamp: Node3D
var _light: OmniLight3D
var _dust: Node3D
var _wheels: Array = []
var _knees: Array = []
var _cables: Array = []
var _module_shape: CollisionShape3D
var _module_y0 := 0.0
var _tracks: Node3D
var _holding := false
var _held := 0.0
var _tick := 0
var _gait := 0.0
var _clock := 0.0
var _check := 0.0
var _lowered := 0.0
var _drop := 0.0
var _last_hour := -1.0

func _ready() -> void:
	name = "Walker"
	add_to_group("walker")
	add_to_group("photo_subject")
	set_meta("photo_id", "walker")
	set_meta("photo_name", NAME)

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	_build()
	state = str(saved.get("state", "stalled"))
	cleaned = bool(saved.get("cleaned", false))
	seen = bool(saved.get("seen", false))
	sent = bool(saved.get("sent", false))
	first_night = bool(saved.get("first_night", false))
	_text_left = float(saved.get("text_left", -1.0))
	home = _vec(saved.get("home", []))
	target = _vec(saved.get("target", []))
	target_yaw = float(saved.get("target_yaw", 0.0))
	var at := _vec(saved.get("at", []))
	if is_inf(at.x): at = _choose()
	global_position = at
	rotation.y = float(saved.get("yaw", _face_yaw(world.lander.global_position - at)))
	_settle()
	if cleaned: _dust.visible = false
	var pod: Node = world.get("lifepod")
	if bool(saved.get("tracks", false)) or (pod != null and bool(pod.walker_moved)): lay_tracks()
	# Saved mid-delivery: it's down.
	if state in ["carrying", "lowering"]: _finish_set_down.call_deferred()
	elif state == "done": _module.visible = false; _module_shape.disabled = true

static func _vec(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() == 3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF

static func _arr(v: Vector3) -> Array:
	return [] if is_inf(v.x) else [v.x, v.y, v.z]

## About 2 km out on open ground, away from the other finds' bearings.
func _choose() -> Vector3:
	var field: Node = world.get("drop_field")
	var lander: Vector3 = world.lander.global_position
	if field == null: return lander + Vector3(0, 0, -2000.0)
	var ridge: Vector3 = world.storm_drop.ridge if world.get("storm_drop") != null else Vector3.INF
	var taken: Array = []
	if not is_inf(ridge.x): taken.append(field._bearing(ridge))
	for kind in field.sites: taken.append(field._bearing(field.sites[kind].at))
	var pod: Node = world.get("lifepod")
	if pod != null:
		for kind in pod.sites: taken.append(field._bearing(pod.sites[kind].global_position))
	return field.choose("walker", 1850.0, 2200.0, "flat", taken, ridge)

func _face_yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)   # the model's front is -Z

# ---------- the model ----------

func _build() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	MHPalette.apply(_model)
	_body = _model.find_child("Body", true, false)
	_module = _model.find_child("Module", true, false)
	_lamp = _model.find_child("Lamp", true, false)
	_dust = _model.find_child("Dust", true, false)
	if _module != null: _module_y0 = _module.position.y
	for i in range(1, 7):
		_wheels.append(_model.find_child("Wheel_%d" % i, true, false))
		_knees.append(_model.find_child("Knee_%d" % i, true, false))
	for i in range(1, 5): _cables.append(_model.find_child("Cable_%d" % i, true, false))
	_cable_length(0.0)
	_light = OmniLight3D.new()
	_light.light_color = Color("#FFA640")
	_light.light_energy = 2.5
	_light.omni_range = 14.0
	if _lamp != null: _lamp.add_child(_light)
	# Bodies: the six feet, the carried module, and the jammed wheel (E).
	var body := StaticBody3D.new()
	add_child(body)
	for i in 6:
		var s := -1.0 if i < 3 else 1.0
		var z: float = [-5.0, 0.0, 5.0][i % 3]
		_shape(body, BoxShape3D.new(), Vector3(1.0, 1.6, 1.4), Vector3(s * 7.7, .8, z))
	_module_shape = _shape(body, BoxShape3D.new(), Vector3(6.0, 3.3, 9.0), Vector3(0, MODULE_BOTTOM + 1.65, 0))
	var fault := StaticBody3D.new()
	fault.name = "FaultWheel"
	fault.set_meta("interaction_target", self)
	fault.position = FORK
	add_child(fault)
	var sphere := SphereShape3D.new()
	sphere.radius = .9
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	fault.add_child(shape)

func _shape(body: StaticBody3D, box: BoxShape3D, size: Vector3, at: Vector3) -> CollisionShape3D:
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	return shape

## Cables a little longer than the gap, plus however far the module's down.
func _cable_length(down: float) -> void:
	for cable in _cables:
		if cable != null: (cable as Node3D).scale = Vector3(1, maxf(.05, .12 + down), 1)

func _settle() -> void:
	var p := global_position
	var heights := 0.0
	for offset in [Vector3.ZERO, global_basis.x * 7.0, -global_basis.x * 7.0, global_basis.z * 5.0, -global_basis.z * 5.0]:
		heights += MHSiteTerrain.height(p.x + offset.x, p.z + offset.z)
	global_position.y = heights / 5.0

# ---------- the tracks it left ----------

## Wheel prints from the near ring out towards where it stopped, a shed leg
## panel by them, and photo marks along the way.
func lay_tracks() -> void:
	if tracks_laid: return
	tracks_laid = true
	_tracks = Node3D.new()
	_tracks.name = "WalkerTracks"
	world.add_child(_tracks)
	var lander: Vector3 = world.lander.global_position
	var flat := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z)
	var along := flat.normalized()
	var side := Vector3(along.z, 0, -along.x)
	# A gentle wander, so they read as walked, not drawn.
	var count := int((TRACKS_TO - TRACKS_FROM) / TRACK_STEP)
	var print_mesh := BoxMesh.new()
	print_mesh.size = Vector3(.55, .04, 1.1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = print_mesh
	mm.instance_count = count * 2
	var yaw := atan2(along.x, along.z)
	for i in count:
		var d := TRACKS_FROM + i * TRACK_STEP
		var wander := side * sin(d / 90.0) * 6.0
		for k in 2:
			var p := lander + along * d + wander + side * TRACK_SPAN * (-1.0 if k == 0 else 1.0)
			p.y = MHSiteTerrain.height(p.x, p.z) + .03
			mm.set_instance_transform(i * 2 + k, Transform3D(Basis(Vector3.UP, yaw), p))
	var prints := MultiMeshInstance3D.new()
	prints.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3B2116")
	mat.roughness = 1.0
	mat.resource_name = "regolith_track"
	prints.material_override = mat
	prints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tracks.add_child(prints)
	# Marks for the camera and for Notes, every 40 m.
	var d := TRACKS_FROM
	while d <= TRACKS_TO:
		var mark := Marker3D.new()
		var p := lander + along * d + side * sin(d / 90.0) * 6.0
		mark.position = Vector3(p.x, MHSiteTerrain.height(p.x, p.z) + .3, p.z)
		mark.add_to_group("photo_subject")
		mark.add_to_group("walker_tracks")
		mark.set_meta("photo_id", "walker_tracks")
		mark.set_meta("photo_name", "Walker tracks")
		_tracks.add_child(mark)
		d += 40.0
	# The leg panel it shed, beside the tracks about 400 m out.
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, .05, .7)
	panel.mesh = box
	var at := lander + along * 410.0 + side * (TRACK_SPAN + 2.5)
	panel.position = Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + .05, at.z)
	panel.rotation = Vector3(.12, 1.1, -.08)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#E6E4DD")
	white.resource_name = "panel_white"
	panel.material_override = white
	panel.add_to_group("photo_subject")
	panel.set_meta("photo_id", "walker_tracks")
	panel.set_meta("photo_name", "A shed leg panel")
	_tracks.add_child(panel)
	MHPalette.apply(_tracks)

func near_tracks(at: Vector3, reach := 25.0) -> bool:
	if _tracks == null: return false
	for mark in get_tree().get_nodes_in_group("walker_tracks"):
		if (mark as Node3D).global_position.distance_to(at) < reach: return true
	return false

# ---------- found ----------

func knows() -> bool:
	var known: Node = world.get("known")
	return known != null and (known.knows(ID) or known.knows(ID, "orbiter"))

func _region() -> Vector2:
	var known: Node = world.get("known")
	return Vector2(global_position.x, global_position.z) + (known.origin as Vector2 if known != null else Vector2.ZERO)

func _see() -> void:
	seen = true
	var known: Node = world.get("known")
	if known != null: known.learn(ID, "find", _region(), NAME, "you")
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("tracks")
		notes.answer("night_sound")
		notes.think("walker_seen")

## The slate's Camera app: a picture of the tracks can go up to the orbiter.
func can_send() -> bool:
	return not sent and state == "stalled" and not knows() and MHJournal.photographed("walker_tracks")

func send_up() -> bool:
	if not can_send(): return false
	sent = true
	_text_left = TEXT_DELAY
	MHAudio.sfx("suit_beep", -6.0)
	MHNotices.post("info", "Sent to the orbiter", "The picture goes up on the next pass.", "comms")
	return true

func _orbiter_text() -> void:
	_text_left = -1.0
	var known: Node = world.get("known")
	if known != null: known.learn(ID, "find", _region(), NAME, "orbiter")
	take_photo()
	var texts: Node = world.get("orbiter_texts")
	if texts == null: return
	var lander: Vector3 = world.lander.global_position
	var offset := global_position - lander
	var km := Vector2(offset.x, offset.z).length() / 1000.0
	var dir: String = preload("res://scripts/storm_drop.gd").direction_word(offset)
	texts.send("walker_photo", "castellanos", "Rao followed your tracks on this pass. They end at a walker, %.1f km %s of you, stopped. That's Walker 1, with the General Module on board. Its fault lamp's on. It's on your Map." % [km, dir], "walker")

## Straight down from orbit, soft, like the parachute's (scripts/storm_drop.gd).
func take_photo() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree(): return
	var viewport := SubViewport.new()
	viewport.size = PHOTO_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = PHOTO_METRES
	camera.far = 900.0
	viewport.add_child(camera)
	add_child(viewport)
	camera.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), global_position + Vector3(0, 300.0, 0))
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty(): return
	image.resize(PHOTO_SIZE.x / 4, PHOTO_SIZE.y / 4, Image.INTERPOLATE_BILINEAR)
	image.resize(PHOTO_SIZE.x, PHOTO_SIZE.y, Image.INTERPOLATE_CUBIC)
	photo = ImageTexture.create_from_image(image)

# ---------- the fault ----------

func interaction_prompt() -> Dictionary:
	match state:
		"stalled":
			if _holding: return {"label": NAME, "primary": "Digging the dust out…"}
			return {"label": NAME + " · this wheel's packed solid with dust", "primary": "Hold to dig it out"}
		"walking": return {"label": NAME + " · walking home"}
		"parked": return {"label": NAME + " · carrying the General Module"}
		"carrying", "lowering": return {"label": NAME + " · setting the module down"}
	return {"label": NAME}

func interact(_actor: Node = null) -> bool:
	if state != "stalled": return false
	_holding = true
	_held = 0.0
	_tick = 0
	return true

func dig_for(delta: float) -> bool:
	_held += delta
	var scoops := floori(_held / CLEAN_SECONDS * 6.0)
	while _tick < scoops:
		_tick += 1
		MHAudio.sfx_at("place", self, -8.0, .4)
	if _held < CLEAN_SECONDS: return false
	_holding = false
	cleaned = true
	_dust.visible = false
	if not seen: _see()
	_wake()
	return true

func _wake() -> void:
	state = "walking"
	var lander: Vector3 = world.lander.global_position
	var out := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z).normalized()
	home = lander + out * PARK_FROM_LANDER
	MHAudio.sfx_at("mode_build", self, 0.0, .6)
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("walker_seen")
	MHNotices.post("info", NAME + " is walking home", "GAR-Y's pinging it the way. It'll park by the lander.", "")

# ---------- the walk ----------

func _process(delta: float) -> void:
	_clock += delta
	# The fault lamp blinks until it's fixed.
	var blink := state == "stalled" and fmod(_clock, 1.2) < .55
	if _lamp != null: _lamp.visible = blink
	if _light != null: _light.visible = blink
	if _holding:
		var player: Node3D = world.get("player")
		if player == null or not Input.is_key_pressed(KEY_E) or player.global_position.distance_to(to_global(FORK)) > 4.0: _holding = false
		else: dig_for(delta)
	if _text_left > 0.0:
		_text_left -= delta
		if _text_left <= 0.0: _orbiter_text()
	match state:
		"walking":
			if _drive(home, delta):
				state = "parked"
				MHChapterOne.stock["airlock"] = int(MHChapterOne.stock.get("airlock", 0)) + 1   # its kit
				var notes: Node = world.get("notes")
				if notes != null: notes.think("walker_home")
				MHNotices.post("info", NAME + " is home", "Press B to choose where the General Module goes.", "")
		"carrying":
			if _drive(target, delta, target_yaw): _start_lowering()
		"lowering": _lower(delta)
	_check -= delta
	if _check <= 0.0:
		_check = .5
		_look()

## Drives towards `goal` (then turns to `yaw` if given). True on arrival.
func _drive(goal: Vector3, delta: float, yaw := INF) -> bool:
	var flat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if flat.length() < .6:
		if is_inf(yaw) or absf(angle_difference(rotation.y, yaw)) < .02: return true
		rotation.y = rotate_toward(rotation.y, yaw, TURN * delta)
		_roll(.3 * delta)
		return false
	var want := _face_yaw(flat)
	rotation.y = rotate_toward(rotation.y, want, TURN * delta)
	if absf(angle_difference(rotation.y, want)) < .5:
		var step := minf(SPEED * delta, flat.length())
		global_position += flat.normalized() * step
		_roll(step)
	_settle()
	return false

## Wheels turn with the ground covered; a tripod gait lifts alternate legs.
func _roll(metres: float) -> void:
	for wheel in _wheels:
		if wheel != null: (wheel as Node3D).rotation.x -= metres / WHEEL_R
	_gait += metres * 1.4
	for i in _knees.size():
		var knee := _knees[i] as Node3D
		if knee == null: continue
		var s := -1.0 if i < 3 else 1.0
		var lift := maxf(0.0, sin(_gait + (PI if i % 2 == 1 else 0.0))) * .09
		knee.rotation.z = s * lift

## You see it close, or its lamp from high ground; the tracks start a thought.
func _look() -> void:
	var player: Node3D = world.get("player")
	if player == null: return
	var you := player.global_position
	var far := Vector2(you.x - global_position.x, you.z - global_position.z).length()
	if not seen and (far < SEE_NEAR or (far < SEE_HIGH and you.y > global_position.y + HIGH_ABOVE)): _see()
	if not seen and tracks_laid and near_tracks(you):
		var notes: Node = world.get("notes")
		if notes != null: notes.think("tracks")
	if state == "done" and not first_night: _night_check(you)

# ---------- setting it down ----------

## The plan's closed with the module and its airlock placed
## (scripts/build_rules.gd): walk there and stand over it.
func deliver(zone: Dictionary) -> void:
	if state != "parked": return
	var builder: Node = world.builder
	var cells: Array = zone.cells
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in cells:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
	var centre: Vector2 = (lo + hi) * .5 * float(builder.CELL)
	target = Vector3(centre.x, MHSiteTerrain.height(centre.x, centre.y), centre.y)
	# Its long side along the walker's length (Z).
	target_yaw = 0.0 if (hi.y - lo.y) >= (hi.x - lo.x) else PI * .5
	state = "carrying"
	_hide_base(true)

## The real rooms wait out of sight (and out of reach) until it's down.
func _hide_base(hidden: bool) -> void:
	var root: Node3D = world.builder.root
	root.visible = not hidden
	root.position.y = 500.0 if hidden else 0.0

func _start_lowering() -> void:
	state = "lowering"
	_lowered = 0.0
	_drop = maxf(.2, global_position.y + MODULE_BOTTOM - float(world.builder.habitat_base_y) + .35)
	MHAudio.sfx_at("mode_build", self, -2.0, .5)

func _lower(delta: float) -> void:
	_lowered = minf(_drop, _lowered + _drop / LOWER_SECONDS * delta)
	if _module != null: _module.position.y = _module_y0 - _lowered
	_cable_length(_lowered)
	if _lowered >= _drop: _finish_set_down()

## Down: the real module takes over, the kit and plans are yours.
func _finish_set_down() -> void:
	state = "done"
	_hide_base(false)
	if _module != null: _module.visible = false
	_module_shape.disabled = true
	_cable_length(0.0)
	# Out of the way: a few metres on past it.
	global_position += -global_basis.z * 20.0
	_settle()
	BUILD_RULES.give_kit()
	if world.has_method("start_module_life"): world.start_module_life()
	if not MHChapterOne.known.has("ice_drill"): MHChapterOne.known["ice_drill"] = "module"
	MHChapterOne.learn_after("module_down")
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("walker_home")
		notes.think("module_plans")
		notes.think("module_power")
	MHNotices.post("info", "The General Module is down", "Walk over and cycle in. Inside, B unpacks its fit-out kit.", "")

## The first night under a real roof: after dark, inside the module.
func _night_check(you: Vector3) -> void:
	var hour := MHGame.sol_hour
	var night := hour >= 21.0 or hour < 5.0
	if night and world.builder.is_inside(you):
		first_night = true
		var notes: Node = world.get("notes")
		if notes != null:
			notes.answer("module_plans")
			notes.think("first_room")
			notes.answer("first_room")

func export_state() -> Dictionary:
	return {"state": state, "at": _arr(global_position), "yaw": rotation.y, "home": _arr(home), "target": _arr(target), "target_yaw": target_yaw,
		"cleaned": cleaned, "seen": seen, "tracks": tracks_laid, "sent": sent, "text_left": _text_left, "first_night": first_night}
