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
## - Until that night it waits out of sight, ~2.6 km out, hidden and not on any
##   record (opening review, 8 Nov: part 1 must not show it); the night it
##   moves it comes to where its tracks end.
## - It's lost, not broken (master-design §2): its compass was bent by the
##   Reach's crustal field. Climb its ladder, sit at the front, and set it
##   right on the nav screen (scripts/walker_nav_screen.gd): a sun sight, then
##   your suit's position. Then it walks home with its headlights on, parking
##   by the lander.
## - Then B opens the Site plan with only the module and its airlock
##   (scripts/build_rules.gd). Close the plan and it carries the module there,
##   stands over the spot and lowers it.
## - Down: the fit-out kit is yours to place, the module's plans join your
##   own, and the first night in a real room follows.
## The guided days, version 2 (docs/opening-days.md): set right, it doesn't
## walk home now. It's "coming": it'll crawl home overnight, checking itself
## as it goes. That afternoon B marks where the module goes (a footprint on
## the ground); at dawn it's parked by the lander and sets the module down on
## your mark while you watch.
## Several bases (A4, 14 Nov; docs/bases-and-vehicles.md): each walker's id
## is its base's (base_id, "w1" for Walker 1). Set down, it kneels and folds
## into its core: nothing's left standing. Refolded from the core's panel
## (as often as you like), it stands up again, "ready": mark a spot on the
## Map and it walks there on its own ("travelling", about a sol across the
## Reach), and waits ("parked") for you to come and choose where its core
## goes, as on day 4.

const MODEL := preload("res://assets/companions/walker.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const BUILD_RULES := preload("res://scripts/build_rules.gd")
const ID := "find:walker"
const NAME := "Walker 1"
const SPEED := 3.0              # m/s, one steady pace (near real wheel-on-leg walkers' top speed): ~7 min home
const TURN := .4                # rad/s
const NAV_SCRIPT := preload("res://scripts/walker_nav_screen.gd")
const WAIT_OUT := 2600.0        # metres out, hidden, until the night it moves
const STRANDED_ABOVE := 2.0     # standing on it this high, not riding: you're put down
const SEE_NEAR := 250.0         # you see it this close (A6: it's only ~550 m out, so follow the tracks first)
const SEE_HIGH := 600.0         # ... or this far from ground this much higher
const HIGH_ABOVE := 10.0
const PARK_FROM_LANDER := 48.0
const TRACKS_FROM := 220.0      # the tracks run this far out from the lander ...
const TRACKS_TO := 1150.0       # ... to here at most (then the ground's too hard to show them)
const TRACKS_SHORT := 35.0      # ... and stop this short of the walker
const STALL_NEAR := 500.0       # A6: it stalled this far out from the lander ...
const STALL_FAR := 580.0        # ... to this: inside the bare suit's reach
const PATCH_REACH := 3.5        # this near the front-left wheel to patch its seal
const TRACK_STEP := 1.6
const TRACK_SPAN := 7.7         # the wheels' half-span
const TEXT_DELAY := 75.0        # seconds to the orbiter's next pass
const LOWER_SECONDS := 9.0
const MODULE_BOTTOM := 1.25     # the carried module's floor above the ground
const WHEEL_R := .62
const LADDER := Vector3(0, 1.6, 5.74)   # the ladder up its back, in the model
## Where you ride: seated on the front deck facing forward (your feet; eyes
## about 1.3 m over the deck), so you see where it's going (8 Nov playtest).
const DECK := Vector3(0, 5.36, -3.15)
const NAV_AT := Vector3(0, 6.26, -3.95)  # the nav screen before the seat, in the model
const STEP_OFF := Vector3(0, 0, 7.4)     # the ladder's foot, where you climb down to
const TALK_AFTER := 45.0        # seconds into the walk home: Castellanos's first text
const TALK_AGAIN := 0.5         # ... and again this far along
const LADDER_SCRIPT := preload("res://scripts/walker_ladder.gd")
const LADDER_STOW := [1.9, 3.6]  # how far sections 2 and 3 slide up to pack away
const LADDER_SECONDS := 1.6     # to run the ladder out or pack it away
const WAIT_REACH := 5.0         # stand this near the ladder's foot and it stops for you
const LEAVE_REACH := 12.0       # ... and walks on once you're this far off
const PHOTO_SIZE := Vector2i(480, 300)
const PHOTO_METRES := 70.0

var world: Node
var base_id := "w1"              # its base's id (A4): Walker n seeds base "wn"
var walker_name := NAME
var kit_given := false           # its airlock and fit-out kit joined the stock (once)
var spot := Vector3.INF          # A4: the spot marked on the Map it's walking to
const TRAVEL_SOL := 1.0          # sols to cross the Reach (docs: "about a sol")
const HOME_RING := 1000.0        # A6: in the chapters, Walker 1's home is within this of the lander
var _folded := 0.0               # 0 standing, 1 folded into its core
var state := "stalled"          # stalled, walking, coming (v2: home overnight), parked, carrying, lowering, done; A4: ready, travelling
var marked := false             # v2: the module's spot is marked, waiting for it
var _mark: Node3D
var fault_found := false         # v2, day 3: you photographed the split wheel seal
var shots: Dictionary = {}       # v2, day 3: the parts you've photographed for Castellanos
const FAULT := "fl_wheel"        # the front-left wheel: packed with grit, its seal split
const SHOT_REACH := 9.0          # get this close to a part for her to see it
const SHOT_AIM := 22.0           # degrees off the middle of the picture
var home := Vector3.INF         # where it parks by the lander
var target := Vector3.INF       # the module's spot
var target_yaw := 0.0
var calibrated := false        # its nav set right (the old save field "cleaned")
var nav_sight_done := false     # the nav screen's sun sight, kept if you close it
var _nav: Node
var _out := false               # waiting out of sight before its night
var _headlights: Array = []
var _nav_mat: StandardMaterial3D
var _stranded := 0.0
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
var _gait := 0.0
var _clock := 0.0
var _check := 0.0
var _lowered := 0.0
var _drop := 0.0
var _last_hour := -1.0
var riding := false
var _ride_yaw := 0.0
var _ride_layers := Vector2i.ZERO
var _walk_from := 0.0           # metres to home when it set off
var _talk := 0                  # the walk-home texts sent so far
var _walk_clock := 0.0
var ladder_out := 1.0           # 0 packed away (bottom ~3.9 m up), 1 down to the ground
var _sections: Array = []       # [node, rest y, stow] for Ladder_2 and Ladder_3
var _ladder_shape: CollisionShape3D
var _waiting := false           # stopped with its ladder down because you came up behind it
var _getting_off := false       # running the ladder out so you can climb down
var _clear := false             # you just climbed down: don't stop for you again until you've left

func _ready() -> void:
	name = "Walker"
	add_to_group("walker")
	add_to_group("photo_subject")
	set_meta("photo_id", "walker")
	set_meta("photo_name", NAME)

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	base_id = str(saved.get("base_id", base_id))
	walker_name = str(saved.get("name", walker_name))
	_build()
	state = str(saved.get("state", "stalled"))
	kit_given = bool(saved.get("kit_given", state == "done"))
	spot = _vec(saved.get("spot", []))
	calibrated = bool(saved.get("calibrated", saved.get("cleaned", false)))
	nav_sight_done = bool(saved.get("nav_sight", false))
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
	var pod: Node = world.get("lifepod")
	if base_id != "w1": pass   # the opening's tracks are Walker 1's
	elif bool(saved.get("tracks", false)) or (pod != null and bool(pod.walker_moved)): lay_tracks()
	elif not seen and not calibrated and state == "stalled": _wait_out_of_sight()
	# Saved mid-delivery: it's down.
	marked = bool(saved.get("marked", false))
	fault_found = bool(saved.get("fault_found", false))
	for p in saved.get("shots", []): shots[str(p)] = true
	if marked and state == "coming": _show_mark.call_deferred()
	if state in ["carrying", "lowering"]: _finish_set_down.call_deferred(false)
	elif state == "done": _module.visible = false; _module_shape.disabled = true; _fold(1.0)

static func _vec(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() == 3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF

static func _arr(v: Vector3) -> Array:
	return [] if is_inf(v.x) else [v.x, v.y, v.z]

## About 550 m out on open ground, inside the bare suit's reach (A6,
## docs/opening-days.md), away from the other finds' bearings.
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
	return field.choose("walker", STALL_NEAR, STALL_FAR, "flat", taken, ridge)

## Before its night: far out, unseen and out of reach (parts 1 and 2 of the
## opening know nothing of it).
func _wait_out_of_sight() -> void:
	_out = true
	var lander: Vector3 = world.lander.global_position
	var out := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z)
	if out.length() < WAIT_OUT - 50.0:
		global_position = lander + (out.normalized() if out.length() > 1.0 else Vector3(0, 0, -1)) * WAIT_OUT
		_settle()
	_show(false)

## The night it moves: it comes to where its tracks will end, and shows.
func _come_into_view() -> void:
	_out = false
	global_position = _choose()
	rotation.y = _face_yaw(world.lander.global_position - global_position)
	_settle()
	_show(true)

func hidden() -> bool:
	return _out

func _show(on: bool) -> void:
	visible = on
	for body in find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if on else 0

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
	for i in 2:
		var section := _model.find_child("Ladder_%d" % (i + 2), true, false) as Node3D
		if section != null: _sections.append([section, section.position.y, float(LADDER_STOW[i])])
	_dust = _model.find_child("Dust", true, false)
	if _dust != null: _dust.visible = false   # older models: the dust's gone from the story
	_build_lights()
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
	# Bodies: the six feet, the carried module, and the nav screen.
	var body := StaticBody3D.new()
	add_child(body)
	for i in 6:
		var s := -1.0 if i < 3 else 1.0
		var z: float = [-5.0, 0.0, 5.0][i % 3]
		_shape(body, BoxShape3D.new(), Vector3(1.0, 1.6, 1.4), Vector3(s * 7.7, .8, z))
	_module_shape = _shape(body, BoxShape3D.new(), Vector3(6.0, 3.3, 9.0), Vector3(0, MODULE_BOTTOM + 1.65, 0))
	var nav := StaticBody3D.new()
	nav.name = "NavScreen"
	nav.position = NAV_AT
	add_child(nav)
	_shape(nav, BoxShape3D.new(), Vector3(.6, .4, .2), Vector3.ZERO)
	var ladder: StaticBody3D = LADDER_SCRIPT.new()
	ladder.name = "Ladder"
	ladder.walker = self
	ladder.set_meta("interaction_target", ladder)
	ladder.position = LADDER
	add_child(ladder)
	_ladder_shape = _shape(ladder, BoxShape3D.new(), Vector3(1.0, 3.2, .4), Vector3.ZERO)
	ladder_out = 1.0 if _ladder_wanted() else 0.0
	_place_ladder()

## The nav screen's glow and the two headlamps (lit while it walks).
func _build_lights() -> void:
	_nav_mat = StandardMaterial3D.new()
	_nav_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_nav_mat.albedo_color = Color(.55, .3, .08)
	for mesh in _model.find_children("nav_face*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _nav_mat
	for side in ["L", "R"]:
		var mount := _model.find_child("Headlamp_" + side, true, false) as Node3D
		var light := SpotLight3D.new()
		light.light_color = Color("#FFF1DC")
		light.light_energy = 5.0
		light.spot_range = 60.0
		light.spot_angle = 30.0
		light.spot_attenuation = .8
		light.shadow_enabled = false
		light.rotation_degrees.x = -9.0
		light.visible = false
		if mount != null: mount.add_child(light)
		else:
			light.position = Vector3(2.0 * (-1.0 if side == "L" else 1.0), 5.1, -5.7)
			add_child(light)
		_headlights.append(light)

func headlights_on() -> bool:
	return not _headlights.is_empty() and (_headlights[0] as SpotLight3D).visible

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
	if _out: _come_into_view()
	tracks_laid = true
	_tracks = Node3D.new()
	_tracks.name = "WalkerTracks"
	world.add_child(_tracks)
	var lander: Vector3 = world.lander.global_position
	var flat := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z)
	var along := flat.normalized()
	var side := Vector3(along.z, 0, -along.x)
	# A gentle wander, so they read as walked, not drawn.
	var reach := clampf(flat.length() - TRACKS_SHORT, TRACKS_FROM + 40.0, TRACKS_TO)
	var count := int((reach - TRACKS_FROM) / TRACK_STEP)
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
	while d <= reach:
		var mark := Marker3D.new()
		var p := lander + along * d + side * sin(d / 90.0) * 6.0
		mark.position = Vector3(p.x, MHSiteTerrain.height(p.x, p.z) + .3, p.z)
		mark.add_to_group("photo_subject")
		mark.add_to_group("walker_tracks")
		mark.set_meta("photo_id", "walker_tracks")
		mark.set_meta("photo_name", "Walker tracks")
		_tracks.add_child(mark)
		d += 40.0
	# The leg panel it shed, beside the tracks most of the way out.
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, .05, .7)
	panel.mesh = box
	var at := lander + along * (reach * .7) + side * (TRACK_SPAN + 2.5)
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

## Where the tracks start, nearest the lander (the same line lay_tracks draws).
func tracks_start() -> Vector3:
	var lander: Vector3 = world.lander.global_position
	var along := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z).normalized()
	var side := Vector3(along.z, 0, -along.x)
	var p := lander + along * TRACKS_FROM + side * sin(TRACKS_FROM / 90.0) * 6.0
	return Vector3(p.x, MHSiteTerrain.height(p.x, p.z), p.z)

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

## 21 Nov playtest: it went on the compass from a rise with hills between
## you, before you'd reached its tracks. Seen means a clear line from your
## eyes to its deck over the ground between (and in the near ring only).
func _in_sight(you: Vector3) -> bool:
	var eye := you + Vector3.UP * 1.6
	var deck := global_position + Vector3.UP * 3.5
	var far := Vector2(deck.x - eye.x, deck.z - eye.z).length()
	var steps := maxi(int(far / 6.0), 1)
	for i in range(1, steps):
		var p := eye.lerp(deck, float(i) / float(steps))
		if MHSiteTerrain.height(p.x, p.z) > p.y + .3: return false
	return true

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
	return not _out and not sent and state == "stalled" and not knows() and MHJournal.photographed("walker_tracks")

func send_up() -> bool:
	if not can_send(): return false
	sent = true
	_text_left = TEXT_DELAY
	MHAudio.sfx("suit_beep", -6.0)
	MHNotices.post("info", "Sent to the orbiter", "The picture goes up on the next pass.", "comms", -1, false)
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
	texts.send("walker_photo", "castellanos", "Rao followed your tracks on this pass. They end at a walker, %.1f km %s of you, stopped. That's Walker 1, with the base's core on board. Its fault lamp's on. It's on your Map." % [km, dir], "walker")

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

# ---------- the fault: lost, not broken ----------

func interaction_prompt() -> Dictionary:
	match state:
		"stalled": return {"label": NAME + " · lost: its nav screen's up on the front deck"}
		"walking": return {"label": NAME + " · walking home"}
		"coming":
			if fault_found and _near_fault(): return {"label": NAME + " · its front-left wheel seal, split", "primary": "Patch it"} if _have_patch_kit() else {"label": "Its front-left wheel seal: split. Pallet 3's patch kit would close it."}
			if fault_found: return {"label": NAME + " · its front-left wheel seal's split"}
			return {"label": NAME + " · set right, but locked: something in its running gear"}
		"parked": return {"label": walker_name + " · carrying the core"}
		"carrying", "lowering": return {"label": walker_name + " · setting the module down"}
		"ready": return {"label": walker_name + " · ready: click a spot for it on the Map"}
		"travelling": return {"label": walker_name + " · walking to its spot"}
	return {"label": walker_name}

func interact(_actor: Node = null) -> bool:
	if state == "coming" and fault_found and _near_fault() and _have_patch_kit():
		patch_seal()
		return true
	return false

## The front-left wheel, in the world.
func fault_spot() -> Vector3:
	return to_global(Vector3(-7.7, .8, -5.0))

func _near_fault() -> bool:
	var player: Node3D = world.get("player")
	if player == null: return false
	var at := fault_spot()
	return Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < PATCH_REACH

## Pallet 3's field tools (scripts/drop_field.gd tools): the patch kit's in them.
func _have_patch_kit() -> bool:
	var field: Node = world.get("drop_field")
	return field == null or bool(field.get("tools"))

## A6, chapter 3: the split seal patched on the spot. It walks home now, and
## you can ride its deck.
func patch_seal() -> void:
	if state != "coming": return
	fault_found = true
	MHAudio.sfx("suit_clamp", -4.0)
	MHNotices.post("valid", "The seal's patched", "Walker 1's front-left wheel turns clean. Climb its ladder to ride it home, or walk alongside.", "log")
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d3_patched")
	_wake()

## Seated at the front: the nav screen (scripts/walker_nav_screen.gd).
func open_nav() -> bool:
	if calibrated or state != "stalled" or not riding or (_nav != null and is_instance_valid(_nav)): return false
	_nav = NAV_SCRIPT.new()
	_nav.setup(self)
	world.add_child(_nav)
	MHAudio.sfx("suit_beep", -10.0)
	return true

func nav_closed() -> void:
	_nav = null

## Set right on the nav screen: it knows where it is, and where home is.
func recalibrated() -> void:
	if calibrated: return
	calibrated = true
	if not seen: _see()
	var known_now: Node = world.get("known")
	if known_now != null: known_now.finish(ID)
	if int(world.get("opening_version")) >= 2:
		_coming()
		return
	_wake()

## v2: set right, but it'll walk home tonight, not now. You climb down.
func _coming() -> void:
	state = "coming"
	var lander: Vector3 = world.lander.global_position
	var out := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z).normalized()
	home = lander + out * PARK_FROM_LANDER
	MHAudio.sfx_at("mode_build", self, -4.0, .6)
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("walker_seen")
	MHNotices.post("info", NAME + " knows where it is", "But it won't move. Climb down and photograph it for Castle, one part at a time: Tab for the slate, then Camera.", "", 1)
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d3_fixed")

## v2, day 3: the hunt for the fault. Each photo near the walker (scripts/
## slate_camera.gd) shows Castellanos the part in the middle of it; the
## front-left wheel is the one.
func photographed(eye: Camera3D) -> void:
	if state != "coming" or fault_found or eye == null: return
	var part := aimed_part(eye)
	var radio: Node = world.get("radio")
	if part == FAULT:
		fault_found = true
		if radio != null: radio.ring("d3_fault")
		return
	if global_position.distance_to(eye.global_position) > 40.0 * float(eye.get_meta("zoom", 1.0)): return   # not a picture of the walker at all
	var first := not shots.has(part)
	shots[part] = true
	if radio == null: return
	if first and radio.has_section("d3_photo_" + part): radio.ring("d3_photo_" + part)
	elif part == "none": MHNotices.post("info", "Too far off", "Get close to one part of the walker, and put it in the middle of the picture.", "", 1)
	else: MHNotices.post("info", "Castellanos has seen that one", "Try another part of the walker.", "", 1)

## The part of the walker in the middle of a picture from `eye`: a wheel,
## knee or the fault lamp, close enough to see. "none" if there isn't one.
func aimed_part(eye: Camera3D) -> String:
	var parts: Array = []   # [id, global point]
	for i in 6:
		var s := -1.0 if i < 3 else 1.0
		var z: float = [-5.0, 0.0, 5.0][i % 3]
		var id := FAULT if i == 0 else "wheel"
		parts.append([id, to_global(Vector3(s * 7.7, .8, z))])
		var knee: Node3D = _knees[i] if i < _knees.size() else null
		if knee != null: parts.append(["knee", knee.global_position])
	if _lamp != null: parts.append(["lamp", _lamp.global_position])
	var look := -eye.global_basis.z
	var best := "none"
	var zoom := float(eye.get_meta("zoom", 1.0))   # the slate camera zoomed in: further off, a tighter aim
	var best_angle := SHOT_AIM / zoom
	for p in parts:
		var at: Vector3 = p[1]
		var to := at - eye.global_position
		if to.length() > (SHOT_REACH * 1.8 if str(p[0]) == "lamp" else SHOT_REACH) * zoom: continue
		var angle := rad_to_deg(look.angle_to(to.normalized()))
		if angle < best_angle:
			best_angle = angle
			best = str(p[0])
	return best

## v2, dawn: it walked through the night and parked by the lander. With the
## spot marked, it carries the module straight there.
func arrive_overnight() -> void:
	if state != "coming": return
	var pod: Node = world.get("lifepod")
	if pod != null and not (pod.prints as Dictionary).has("seal"): return   # it can't walk on a split seal
	global_position = home
	rotation.y = _face_yaw(world.lander.global_position - home)
	_settle()
	if riding: _step_off()
	ladder_out = 0.0
	_place_ladder()
	state = "parked"   # (its airlock kit came with "coming", for the mark)
	if not marked:
		MHNotices.post("info", NAME + " is home", "Press B to choose where the core goes.", "", 1)
		return
	# Marked: it waits by the lander till you come out to watch (opening_days day 4).

## v2, day 4: you're out of the lander: it carries the module to your mark.
func deliver_marked() -> void:
	if state != "parked" or not marked: return
	var module: Dictionary = BUILD_RULES.module_zone(world.builder)
	if module.is_empty():   # the module was taken out of the plan after the mark: choose again
		marked = false
		_clear_mark()
		MHNotices.post("info", NAME + " is home", "Press B to choose where the core goes.", "", 1)
		return
	_clear_mark()
	deliver(module)

## v2: the plan closed with the module placed while it's still out there:
## the spot's marked; the rooms wait hidden, a footprint shows where.
func mark(zone: Dictionary) -> void:
	if state != "coming": return
	marked = true
	_hide_base(true)
	_show_mark(zone)
	MHNotices.post("valid", "The module's spot is marked", "Walker 1 will set it down here when it comes in.", "log")
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d3_marked")

## Four corner stakes and a line round the footprint.
func _show_mark(zone: Dictionary = {}) -> void:
	_clear_mark()
	if zone.is_empty(): zone = BUILD_RULES.module_zone(world.builder)
	if zone.is_empty(): return
	var cell := float(world.builder.CELL)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in zone.cells:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x + 1), maxf(hi.y, c.y + 1))
	lo *= cell
	hi *= cell
	_mark = Node3D.new()
	_mark.name = "ModuleMark"
	world.add_child(_mark)
	var stake := StandardMaterial3D.new()
	stake.albedo_color = MHPalette.accent_colour()
	stake.emission_enabled = true
	stake.emission = MHPalette.accent_colour() * .4
	var corners := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = .04
		cyl.bottom_radius = .05
		cyl.height = 1.0
		post.mesh = cyl
		post.material_override = stake
		post.position = Vector3(a.x, MHSiteTerrain.height(a.x, a.y) + .5, a.y)
		_mark.add_child(post)
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		var length := a.distance_to(b)
		box.size = Vector3(.05, .03, length)
		line.mesh = box
		line.material_override = stake
		var mid := (a + b) * .5
		line.position = Vector3(mid.x, MHSiteTerrain.height(mid.x, mid.y) + .05, mid.y)
		line.rotation.y = atan2(b.x - a.x, b.y - a.y)
		_mark.add_child(line)

func _clear_mark() -> void:
	if _mark != null and is_instance_valid(_mark): _mark.queue_free()
	_mark = null

func _wake() -> void:
	state = "walking"
	var lander: Vector3 = world.lander.global_position
	var out := Vector3(global_position.x - lander.x, 0, global_position.z - lander.z).normalized()
	home = lander + out * PARK_FROM_LANDER
	_walk_from = Vector2(home.x - global_position.x, home.z - global_position.z).length()
	_walk_clock = 0.0
	_talk = 0
	MHAudio.sfx_at("mode_build", self, 0.0, .6)
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("walker_seen")
	MHNotices.post("info", NAME + " is walking home", "It knows where it is now. It'll park by the lander, with you aboard or not.", "")

# ---------- the walk ----------

func _process(delta: float) -> void:
	_clock += delta
	# The fault lamp blinks until it's fixed.
	var blink := state == "stalled" and fmod(_clock, 1.2) < .55
	if _lamp != null: _lamp.visible = blink
	if _light != null: _light.visible = blink
	# The nav screen: amber and pulsing while it's lost, steady green after.
	if _nav_mat != null:
		_nav_mat.albedo_color = Color(.35, .95, .6) if calibrated else Color(.95, .55, .12).lerp(Color(1.0, .8, .4), .5 + .5 * sin(_clock * 2.4))
	# Headlights while it walks, carries, or you're aboard.
	var lights := state in ["walking", "carrying", "lowering"] or riding
	for light in _headlights: (light as SpotLight3D).visible = lights
	if _text_left > 0.0:
		_text_left -= delta
		if _text_left <= 0.0: _orbiter_text()
	match state:
		"walking":
			_walk_texts(delta)
			# Asleep or resting, the hours fly and so does the walk.
			var pace := delta
			var sleep: Node = world.get("sleep")
			if sleep != null and bool(sleep.asleep): pace *= float(world.day_night.time_scale)
			_watch_for_you()
			if _can_move() and _drive(home, pace):
				var notes: Node = world.get("notes")
				if notes != null: notes.think("walker_home")
				if int(world.get("opening_version")) >= 2:
					# A6: home by the lander, ready to be sent to the spot you choose.
					state = "ready"
					MHNotices.post("info", NAME + " is home", "Choose where home goes: open the Map and click a spot to check it, then click it again to send Walker 1.", "", 1)
					var radio: Node = world.get("radio")
					if radio != null: radio.ring("d3_home")
				else:
					state = "parked"
					MHChapterOne.stock["airlock"] = int(MHChapterOne.stock.get("airlock", 0)) + 1   # its kit
					MHNotices.post("info", NAME + " is home", "Press B to choose where the core goes.", "", 1)   # what to do next: ahead of the queue
		"travelling":
			_watch_for_you()
			var hours := fposmod(MHGame.sol_hour - _last_hour, 24.0) if _last_hour >= 0.0 else 0.0
			if hours > 2.0: hours = 0.0
			var metres := hours * travel_per_hour()
			if _can_move() and metres > 0.0 and _drive(spot, delta, INF, metres / maxf(delta, .0001)): _arrive()
		"carrying":
			if _can_move() and _drive(target, delta, target_yaw): _start_lowering()
		"lowering": _lower(delta)
	_last_hour = MHGame.sol_hour
	_run_ladder(delta)
	if _getting_off and ladder_out >= 1.0: _step_off()
	if riding: _ride()
	_check -= delta
	if _check <= 0.0:
		_check = .5
		_look()

## Drives towards `goal` (then turns to `yaw` if given). True on arrival.
func _drive(goal: Vector3, delta: float, yaw := INF, speed := SPEED) -> bool:
	var flat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if flat.length() < .6:
		if is_inf(yaw) or absf(angle_difference(rotation.y, yaw)) < .02: return true
		rotation.y = rotate_toward(rotation.y, yaw, TURN * delta)
		_roll(.3 * delta)
		return false
	var want := _face_yaw(flat)
	rotation.y = rotate_toward(rotation.y, want, TURN * delta)
	if absf(angle_difference(rotation.y, want)) < .5:
		var step := minf(speed * delta, flat.length())
		global_position += flat.normalized() * step
		_roll(step)
	_settle()
	return false

# ---------- riding it ----------

func ladder_prompt() -> Dictionary:
	if riding: return {"label": NAME, "primary": "Climb down"}
	if state == "lowering": return {"label": NAME + " · setting the module down"}
	if ladder_out < .95: return {"label": NAME + " · its ladder's packed away"}
	return {"label": NAME + " · a ladder up to its deck", "primary": "Climb aboard"}

# ---------- the telescoping ladder ----------

## Down while it stands still; packed away while it moves, unless it has
## stopped for you to climb on or off.
func _ladder_wanted() -> bool:
	if _getting_off: return true
	if state in ["stalled", "parked", "done", "ready"]: return true
	return _waiting and not riding

func _run_ladder(delta: float) -> void:
	var want := 1.0 if _ladder_wanted() else 0.0
	if is_equal_approx(ladder_out, want): return
	if (ladder_out == 0.0 or ladder_out == 1.0): MHAudio.sfx_at("mode_build", self, -10.0, .2)
	ladder_out = move_toward(ladder_out, want, delta / LADDER_SECONDS)
	_place_ladder()

func _place_ladder() -> void:
	var t := smoothstep(0.0, 1.0, ladder_out)
	for s in _sections:
		(s[0] as Node3D).position.y = float(s[1]) + (1.0 - t) * float(s[2])
	if _ladder_shape != null: _ladder_shape.disabled = ladder_out < .95

## Walking: come up to its ladder's foot and it stops and runs the ladder
## down for you; walk off and it carries on.
func _watch_for_you() -> void:
	var player: Node3D = world.get("player")
	if player == null or riding: return
	var foot := to_global(STEP_OFF)
	var d := Vector2(player.global_position.x - foot.x, player.global_position.z - foot.z).length()
	if d > LEAVE_REACH:
		_waiting = false
		_clear = false
	elif d < WAIT_REACH and not _clear: _waiting = true

## It only moves with the ladder packed away and nobody climbing.
func _can_move() -> bool:
	return ladder_out <= 0.0 and not _getting_off and (riding or not _waiting)

## Up the ladder onto the rear deck: you ride where it walks, free to look
## round and use the slate. E climbs down.
func climb() -> bool:
	var player: CharacterBody3D = world.get("player")
	if player == null or riding or state == "lowering" or ladder_out < .95: return false
	riding = true
	add_to_group("riding_prompt")
	_stranded = 0.0
	_waiting = false
	_ride_yaw = rotation.y
	_ride_layers = Vector2i(player.collision_layer, player.collision_mask)
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_meta("riding", true)
	player.velocity = Vector3.ZERO
	# Seated facing forward, the way it walks.
	player.rotation.y = rotation.y
	MHAudio.sfx_at("step_metal_1", self, -4.0, .1)
	# The seat's suit line: the module's air tops you up while you ride.
	if not has_meta("suit_line_told"):
		set_meta("suit_line_told", true)
		MHNotices.post("valid", "Walker 1", "The seat's suit line clicks onto your pack: the module's air tops you up while you ride.", "log")
	_ride()
	return true

## E on the deck: it stops and runs its ladder down first if it's moving.
func climb_down() -> void:
	if not riding: return
	if ladder_out < 1.0:
		_getting_off = true
		return
	_step_off()

func _step_off() -> void:
	_getting_off = false
	var player: CharacterBody3D = world.get("player")
	if player == null or not riding: return
	riding = false
	remove_from_group("riding_prompt")
	if _nav != null and is_instance_valid(_nav): _nav.close()
	_clear = state in ["walking", "carrying"]
	var spot := to_global(STEP_OFF)
	spot.y = MHSiteTerrain.height(spot.x, spot.z) + .1
	player.global_position = spot
	if "safe_position" in player: player.safe_position = spot
	player.collision_layer = _ride_layers.x
	player.collision_mask = _ride_layers.y
	player.set_meta("riding", false)
	MHAudio.sfx_at("step_metal_2", self, -4.0, .1)

## Keep you on the deck as it walks and turns.
func _ride() -> void:
	var player: CharacterBody3D = world.get("player")
	if player == null: return
	player.global_position = to_global(DECK)
	player.rotation.y += angle_difference(_ride_yaw, rotation.y)
	_ride_yaw = rotation.y
	player.velocity = Vector3.ZERO

## Riding: E on the nav screen opens it; E anywhere else, or Space, climbs
## down. Caught here, ahead of anything else that wants E (8 Nov playtest:
## stuck on the deck).
func _input(event: InputEvent) -> void:
	if not riding or _getting_off or (_nav != null and is_instance_valid(_nav)): return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	var key := (event as InputEventKey).keycode
	if key == KEY_E:
		if not looking_at_nav() or not open_nav(): climb_down()
		get_viewport().set_input_as_handled()
	elif key == KEY_SPACE:
		climb_down()
		get_viewport().set_input_as_handled()

## The line under the crosshair while you ride, wherever you look.
func ride_prompt() -> Dictionary:
	if _getting_off: return {"keys": "", "verb": "Stopping to let you down…"}
	if state == "stalled" and not calibrated and looking_at_nav(): return {"keys": "E", "verb": "Use the nav screen"}
	return {"keys": "E", "verb": "Climb down"}

func looking_at_nav() -> bool:
	var player: Node3D = world.get("player")
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D if player != null else null
	if camera == null or not camera.is_inside_tree(): return false
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 2.5)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and str((hit.collider as Node).name) == "NavScreen"

## Castellanos keeps you company on the walk home: two short texts, the
## second well before it arrives (the talk never outlasts the walk).
func _walk_texts(delta: float) -> void:
	_walk_clock += delta
	var texts: Node = world.get("orbiter_texts")
	if texts == null or _talk >= 2: return
	var left := Vector2(home.x - global_position.x, home.z - global_position.z).length()
	if _talk == 0 and _walk_clock >= TALK_AFTER:
		_talk = 1
		texts.send("walker_walking", "castellanos", "It's moving! Rao has it on the long camera, a little dust plume heading your way. At that pace it's about %d minutes out. Ride it if you can, the view from up there must be something." % maxi(1, roundi(left / SPEED / 60.0)))
	elif _talk == 1 and _walk_from > 0.0 and left < _walk_from * TALK_AGAIN:
		_talk = 2
		texts.send("walker_halfway", "castellanos", "Halfway. When it parks, it'll ask where the core goes. Pick somewhere you'd want to wake up every morning.")

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

func _put_down(player: Node3D) -> void:
	_stranded = 0.0
	var spot := to_global(STEP_OFF)
	spot.y = MHSiteTerrain.height(spot.x, spot.z) + .1
	player.global_position = spot
	if "safe_position" in player: player.safe_position = spot
	if player is CharacterBody3D: (player as CharacterBody3D).velocity = Vector3.ZERO

## You see it close, or its lamp from high ground; the tracks start a thought.
func _look() -> void:
	var player: Node3D = world.get("player")
	if player == null: return
	var you := player.global_position
	if _out: return
	# Up on it without riding (a save made on the deck, a jump): put down at the ladder's foot.
	var local := to_local(you)
	if not riding and absf(local.x) < 5.0 and absf(local.z) < 6.5 and local.y > STRANDED_ABOVE:
		_stranded += .5
		if _stranded >= 1.0: _put_down(player)
	else: _stranded = 0.0
	var far := Vector2(you.x - global_position.x, you.z - global_position.z).length()
	if not seen and (far < SEE_NEAR or (far < SEE_HIGH and you.y > global_position.y + HIGH_ABOVE)) and _in_sight(you): _see()
	if not seen and tracks_laid and near_tracks(you):
		var notes: Node = world.get("notes")
		if notes != null: notes.think("tracks")
		var radio: Node = world.get("radio")
		if radio != null and int(world.get("opening_version")) >= 2: radio.ring("d3_tracks")
		var known: Node = world.get("known")
		if known != null: known.finish("walker_tracks_start")
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

## Its base's pieces (the core and its airlock) wait unbuilt until it's down
## (A4: the other bases stay as they are).
func _hide_base(hidden: bool) -> void:
	var builder: Node = world.builder
	var changed := false
	for zone in builder.zones:
		if str(zone.get("base", "w1")) != base_id and not (hidden and not zone.has("base")): continue
		if hidden and not bool(zone.get("arriving", false)): zone["arriving"] = true; changed = true
		elif not hidden and zone.has("arriving"): zone.erase("arriving"); changed = true
	if changed: builder._rebuild()

func _start_lowering() -> void:
	state = "lowering"
	_lowered = 0.0
	var core: Dictionary = BUILD_RULES.module_zone(world.builder, base_id)
	var floor_y := float(core.get("y", world.builder.habitat_base_y))
	_drop = maxf(.2, global_position.y + MODULE_BOTTOM - floor_y + .35)
	MHAudio.sfx_at("mode_build", self, -2.0, .5)

func _lower(delta: float) -> void:
	_lowered = minf(_drop, _lowered + _drop / LOWER_SECONDS * delta)
	if _module != null: _module.position.y = _module_y0 - _lowered
	_cable_length(_lowered)
	if _lowered >= _drop: _finish_set_down()

## Down: the real core takes over and the walker kneels and folds into it
## (A4: nothing's left standing); the kit and plans are yours.
func _finish_set_down(animate := true) -> void:
	ladder_out = 1.0
	_place_ladder()
	if riding: _step_off()
	state = "done"
	_hide_base(false)
	if _module != null: _module.visible = false
	_module_shape.disabled = true
	_cable_length(0.0)
	if animate and is_inside_tree():
		MHAudio.sfx_at("mode_build", self, -4.0, .4)
		create_tween().tween_method(_fold, 0.0, 1.0, FOLD_SECONDS).set_trans(Tween.TRANS_SINE)
	else: _fold(1.0)
	var refolded := kit_given
	if not kit_given:
		kit_given = true
		BUILD_RULES.give_kit()
	if world.has_method("start_core"): world.start_core(base_id)
	elif world.has_method("start_module_life"): world.start_module_life()
	if refolded:
		MHNotices.post("info", "The core is down", "%s is folded in again: everything you had is in the store, ready to build." % walker_name, "", 1)
		return
	_bring_cargo()
	if not MHChapterOne.known.has("ice_drill"): MHChapterOne.known["ice_drill"] = "module"
	MHChapterOne.learn_after("module_down")
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("walker_home")
		notes.think("module_plans")
		notes.think("module_power")
		var drop: Node = world.get("storm_drop")
		if drop != null and drop.cartridge != null and str(drop.cartridge.where) == "ground": notes.think("module_air", "staged")
	MHNotices.post("info", "The core is down", "It's cold and dark. Plug the air cartridge into its outside socket and lay the solar blanket beside it.", "", 1)
	var radio: Node = world.get("radio")
	if radio != null and int(world.get("opening_version")) >= 2: radio.ring("d4_down")

## A6: it picked up your staged cargo at the lander on its way. If home's
## away from the lander, the air cartridge and power pack come down by the core.
const CARGO_STAGED := 40.0
func _bring_cargo() -> void:
	var lander: Vector3 = world.lander.global_position
	var core := BUILD_RULES.module_zone(world.builder, base_id)
	if core.is_empty(): return
	var module: Node = world.get("module_life")
	var by: Vector3 = module.socket_spot() if module != null and module.has_method("socket_spot") else global_position
	if Vector2(by.x - lander.x, by.z - lander.z).length() < CARGO_STAGED * 1.5: return
	var away := Vector3(by.x - lander.x, 0, by.z - lander.z).normalized()
	var across := away.cross(Vector3.UP)
	var i := 0
	for group in ["o2_cartridge", "power_pack"]:
		for item in get_tree().get_nodes_in_group(group):
			var thing := item as Node3D
			if thing == null or str(thing.get("where")) != "ground": continue
			if Vector2(thing.global_position.x - lander.x, thing.global_position.z - lander.z).length() > CARGO_STAGED: continue
			var p := by + away * 2.5 + across * (1.6 if i == 0 else -1.6)
			thing.global_position = Vector3(p.x, MHSiteTerrain.height(p.x, p.z) + .05, p.z)
			i += 1

## The first night under a real roof: after dark, inside the module.
func _night_check(you: Vector3) -> void:
	var hour := MHGame.sol_hour
	var night := hour >= 21.0 or hour < 5.0
	if night and world.builder.is_inside(you):
		first_night = true
		var notes: Node = world.get("notes")
		if notes != null:
			notes.think("first_room")
			notes.answer("first_room")

# ---------- A4: kneeling, folding, refolding and walking to a spot ----------

const FOLD_SECONDS := 3.5
const KNEEL := 3.2               # metres the body comes down as it kneels

## 0 standing, 1 folded into the core: it kneels, then draws in, then it's
## part of the core (hidden, no collision).
func _fold(t: float) -> void:
	_folded = t
	if _model == null: return
	var kneel := smoothstep(0.0, .5, t)
	var fold := smoothstep(.4, 1.0, t)
	_model.position.y = -KNEEL * kneel
	_model.scale = Vector3(lerpf(1.0, .35, fold), lerpf(1.0, .25, fold), lerpf(1.0, .7, fold))
	var gone := t >= 1.0
	visible = not gone
	for body in find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0 if gone else 1
	if _ladder_shape != null and gone: _ladder_shape.disabled = true

## Refolded (scripts/core_panel.gd): it stands up where its core was, ready.
func refold() -> void:
	if state != "done": return
	var builder: Node = world.builder
	var core: Dictionary = BUILD_RULES.module_zone(builder, base_id)
	if not core.is_empty():
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for c in core.cells:
			lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
			hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
		var centre: Vector2 = (lo + hi) * .5 * float(builder.CELL)
		global_position = Vector3(centre.x, 0, centre.y)
		rotation.y = target_yaw
	var why: String = builder.refold_base(base_id)
	if not why.is_empty():
		MHNotices.post("invalid", "It won't refold", why + ".")
		return
	if world.has_method("fold_core"): world.fold_core(base_id)
	state = "ready"
	spot = Vector3.INF
	if _module != null:
		_module.visible = true
		_module.position.y = _module_y0
	_module_shape.disabled = false
	_settle()
	visible = true
	create_tween().tween_method(_fold, 1.0, 0.0, FOLD_SECONDS).set_trans(Tween.TRANS_SINE)
	ladder_out = 1.0
	_place_ladder()
	MHNotices.post("info", walker_name + " is up", "Its core's folded away with everything in the store. Click a spot for it on the Map.", "", 1)

## Metres an hour: about a sol to cross the Reach.
func travel_per_hour() -> float:
	var half := float(MHSiteTerrain.RegionTerrain.meta().get("half", 4000.0)) if MHSiteTerrain.RegionTerrain != null else 4000.0
	return 2.0 * half / (24.65 * TRAVEL_SOL)

## Why it can't go to a spot (site metres; "" when it can): ground you've
## explored, flat enough, and clear of the other bases.
func spot_reason(at: Vector2) -> String:
	if state != "ready": return "%s isn't free to walk" % walker_name
	var builder: Node = world.builder
	var known: Node = world.get("known")
	if known != null and float(known.seen_at(at + known.origin)) < BUILD_RULES.EXPLORED: return "Only ground you've explored"
	for id in builder.bases:
		if str(id) == base_id: continue
		var c = builder.bases[id].get("centre", Vector2.INF)
		if c is Vector2 and not is_inf((c as Vector2).x) and (c as Vector2).distance_to(at) < MHBases.APART: return "Too close to %s" % MHBases.label_for(str(id))
	# The guided chapters (A6): Walker 1's home stays in ring 1, near the lander.
	var opening: Node = world.get("opening_days")
	if base_id == "w1" and not kit_given and opening != null and bool(opening.call("guided")):
		var lander: Vector3 = world.lander.global_position
		if Vector2(at.x - lander.x, at.y - lander.z).length() > HOME_RING: return "For now, keep home within a kilometre of the lander"
	var origin: Vector2 = known.origin if known != null else Vector2.ZERO
	var ground := MHBaseSite.reason(at.x + origin.x, at.y + origin.y, 24.0)
	if not ground.is_empty(): return "Not there: " + ground
	return ""

## Send it to a spot marked on the Map (scripts/region_map.gd).
func send_to(at: Vector2) -> bool:
	if not spot_reason(at).is_empty(): return false
	world.builder.found_base(base_id, at)
	spot = Vector3(at.x, MHSiteTerrain.height(at.x, at.y), at.y)
	state = "travelling"
	ladder_out = 0.0 if not riding else ladder_out
	_last_hour = MHGame.sol_hour
	MHNotices.post("info", walker_name + " is on its way", "It walks there on its own: about %s. Follow it, or ride it." % _eta(), "")
	var radio: Node = world.get("radio")
	if radio != null and base_id == "w1" and not kit_given: radio.ring("d3_sent")
	return true

func _eta() -> String:
	var metres := Vector2(spot.x - global_position.x, spot.z - global_position.z).length()
	var hours := metres / maxf(1.0, travel_per_hour())
	return "%d hours" % maxi(1, roundi(hours)) if hours >= 1.5 else "an hour"

## There: it parks and waits for you to choose where its core goes.
func _arrive() -> void:
	state = "parked"
	ladder_out = 0.0
	_place_ladder()
	if not kit_given: MHChapterOne.stock["airlock"] = int(MHChapterOne.stock.get("airlock", 0)) + 1   # its airlock
	MHNotices.post("info", walker_name + " is at its spot", "Go there and press B to choose where the core goes.", "", 1)
	var radio: Node = world.get("radio")
	if radio != null and base_id == "w1" and not kit_given: radio.ring("d4_arrived")

func export_state() -> Dictionary:
	return {"base_id": base_id, "name": walker_name, "kit_given": kit_given, "spot": _arr(spot), "state": state, "at": _arr(global_position), "yaw": rotation.y, "home": _arr(home), "target": _arr(target), "target_yaw": target_yaw,
		"marked": marked, "fault_found": fault_found, "shots": shots.keys(), "calibrated": calibrated, "nav_sight": nav_sight_done, "seen": seen, "tracks": tracks_laid, "sent": sent, "text_left": _text_left, "first_night": first_night}
