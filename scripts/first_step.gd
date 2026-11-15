extends CanvasLayer

## The first step on Mars (16 Nov playtest; docs/opening-days.md, "After the
## 15 Nov playtest, part 2"). Armed for a new story game. The hatch's first
## opening whites the view out into daylight. Then, the first time your boot
## is on the regolith (outside, on the ground, off the ramp), you stop: the
## HUD goes (compass too, for this moment only), the view eases down to your
## boot print and lifts slowly across the land to the sun, the music swells,
## and "I'm standing on Mars." Control comes back, a few seconds of quiet,
## then Castle (d1_first_step). The print stays, marked "First step" on the Map.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const LOOK_DOWN := 1.8         # seconds easing down to the boot
const PAN := 5.4               # seconds lifting and panning across the land
const PAN_DEG := 70.0
const HUD_BACK := .8           # after the pan
const CASTLE_AFTER := 3.0      # seconds of quiet before she speaks
const GROUND_REACH := .3       # feet this close to the ground: on the regolith

var world: Node
var armed := false
var done := false
var at := Vector3.INF          # the boot print
var _t := -1.0
var _from_yaw := 0.0
var _to_yaw := 0.0
var _from_pitch := 0.0
var _hidden: Array = []
var _white: ColorRect
var _words: Label
var _castle_in := -1.0

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "FirstStep"
	layer = 5
	add_to_group("first_step")
	armed = bool(saved.get("armed", false))
	done = bool(saved.get("done", false))
	var p: Array = saved.get("at", [])
	if p.size() == 3: at = Vector3(float(p[0]), float(p[1]), float(p[2]))

func _ready() -> void:
	_white = ColorRect.new()
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.color = Color(1, .96, .9, 0)
	add_child(_white)
	_words = Label.new()
	_words.set_anchors_preset(Control.PRESET_CENTER)
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_words.grow_vertical = Control.GROW_DIRECTION_BOTH
	_words.add_theme_font_size_override("font_size", 30)
	_words.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .6))
	_words.add_theme_constant_override("shadow_offset_y", 2)
	_words.text = "I'm standing on Mars."
	_words.modulate.a = 0.0
	add_child(_words)
	if not is_inf(at.x): _press_print()
	var lander: Node = world.get("lander")
	if armed and lander != null and lander.has_signal("vented"): lander.vented.connect(_into_daylight, CONNECT_ONE_SHOT)

## A new story game: the moment waits for your first step.
func arm() -> void:
	armed = true
	done = false
	var lander: Node = world.get("lander")
	if lander != null and lander.has_signal("vented") and not lander.vented.is_connected(_into_daylight): lander.vented.connect(_into_daylight, CONNECT_ONE_SHOT)

## The ramp swings down: the cabin's dimness gives way to Mars's daylight.
func _into_daylight() -> void:
	if done: return
	_white.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_white, "color:a", .85, .9).set_delay(1.2)
	tween.tween_property(_white, "color:a", 0.0, 1.8)

func _process(delta: float) -> void:
	if world == null: return
	if _castle_in >= 0.0:
		_castle_in -= delta
		if _castle_in < 0.0:
			var radio: Node = world.get("radio")
			if radio != null: radio.ring("d1_first_step")
	if _t >= 0.0:
		_play(delta)
		return
	if not armed or done: return
	if _on_the_regolith(): _begin()

func _on_the_regolith() -> bool:
	var player: CharacterBody3D = world.get("player") as CharacterBody3D
	var suit: Node = world.get("suit")
	var lander: Node = world.get("lander")
	if player == null or suit == null or str(suit.get("where")) != "outside" or not player.is_on_floor(): return false
	if lander != null and bool(lander.cabin_contains(player.global_position)): return false
	if player.has_method("_on_deck") and bool(player._on_deck()): return false
	var p := player.global_position
	return absf(p.y - MHSiteTerrain.height(p.x, p.z)) < GROUND_REACH

func _begin() -> void:
	done = true
	var player: Node3D = world.player
	player.set_meta("first_step", true)
	(player as CharacterBody3D).velocity = Vector3.ZERO
	at = Vector3(player.global_position.x, MHSiteTerrain.height(player.global_position.x, player.global_position.z), player.global_position.z)
	_press_print()
	_from_yaw = player.rotation.y
	_from_pitch = (player.head as Node3D).rotation.x
	_to_yaw = _pan_target()
	# Everything off the screen but the land, for this moment only.
	_hidden.clear()
	for layer_node in world.find_children("*", "CanvasLayer", true, false):
		if layer_node == self or not (layer_node as CanvasLayer).visible: continue
		(layer_node as CanvasLayer).visible = false
		_hidden.append(layer_node)
	MHAudio.sfx("suit_breath_in", -10.0)
	MHAudio.moment()
	var known: Node = world.get("known")
	var field: Node = world.get("drop_field")
	if known != null:
		var region: Vector2 = field.region_at(at) if field != null else Vector2(at.x, at.z)
		known.learn("first_step", "place", region, "First step", "you")
		known.finish("first_step")
	_t = 0.0   # (the Journal's "first_walk" page is written as you step out: scripts/mars_world.gd)

## Pan towards the sun if it's up, else towards pallet 1's ridge (no more
## than 110° round); with neither, PAN_DEG to the right.
func _pan_target() -> float:
	var player: Node3D = world.player
	var target := Vector3.INF
	var drop: Node = world.get("storm_drop")
	if drop != null and drop.get("ridge") != null: target = drop.ridge
	var field: Node = world.get("drop_field")
	if field != null and field.get("sunset") != null and field.sunset.has_method("sun_direction") and MHGame.sunlight_fraction > .2:
		target = player.global_position + (field.sunset.sun_direction() as Vector3) * 100.0
	if is_inf(target.x): return player.rotation.y - deg_to_rad(PAN_DEG)
	var to := target - player.global_position
	var turn := angle_difference(player.rotation.y, atan2(-to.x, -to.z))
	if absf(turn) < deg_to_rad(25.0): turn = deg_to_rad(PAN_DEG) * (1.0 if turn >= 0.0 else -1.0)   # already facing it: still a slow look round
	return player.rotation.y + clampf(turn, -deg_to_rad(110.0), deg_to_rad(110.0))

func _play(delta: float) -> void:
	_t += delta
	var player: Node3D = world.player
	var head: Node3D = player.head
	if _t < LOOK_DOWN:
		var k := smoothstep(0.0, 1.0, _t / LOOK_DOWN)
		head.rotation.x = lerpf(_from_pitch, deg_to_rad(-62.0), k)
	elif _t < LOOK_DOWN + PAN:
		var k := smoothstep(0.0, 1.0, (_t - LOOK_DOWN) / PAN)
		head.rotation.x = lerpf(deg_to_rad(-62.0), deg_to_rad(4.0), smoothstep(0.0, .6, k))
		player.rotation.y = lerp_angle(_from_yaw, _to_yaw, k)
		var words := (_t - LOOK_DOWN) / PAN
		_words.modulate.a = clampf(minf((words - .3) / .2, (1.0 - words) / .15), 0.0, 1.0)
		if absf(_t - (LOOK_DOWN + PAN * .5)) < delta: MHAudio.sfx("suit_breath_out", -12.0)
	elif _t < LOOK_DOWN + PAN + HUD_BACK:
		_words.modulate.a = 0.0
	else:
		_finish()

func _finish() -> void:
	_t = -1.0
	_words.modulate.a = 0.0
	var player: Node3D = world.player
	if player.has_meta("first_step"): player.remove_meta("first_step")
	for layer_node in _hidden:
		if is_instance_valid(layer_node): (layer_node as CanvasLayer).visible = true
	_hidden.clear()
	_castle_in = CASTLE_AFTER

## The boot print in the dust: a decal, dark on the regolith, no lettering.
func _press_print() -> void:
	if world.get_node_or_null("FirstBootPrint") != null: return
	var decal := Decal.new()
	decal.name = "FirstBootPrint"
	decal.size = Vector3(.16, .5, .34)
	decal.texture_albedo = _print_texture()
	decal.modulate = Color(.42, .24, .15, .8)
	decal.cull_mask = 1
	world.add_child(decal)
	var player: Node3D = world.get("player")
	var yaw := player.rotation.y if player != null else 0.0
	decal.global_position = at + Vector3(0, .1, 0)
	decal.rotation.y = yaw

static func _print_texture() -> ImageTexture:
	var w := 48
	var h := 104
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var u := (float(x) + .5) / float(w) * 2.0 - 1.0
			var v := (float(y) + .5) / float(h)
			# A sole: wide at the ball, narrow at the arch, round at the heel.
			var half := .95 if v < .45 else (.62 if v < .7 else .8)
			var inside := absf(u) < half * (1.0 - pow(absf(v - .45) * 2.05, 6.0) * .5)
			if v < .03 or v > .97 or not inside: continue
			var tread := 1.0 if (int(v * 26.0) % 2 == 0) else .45
			img.set_pixel(x, y, Color(1, 1, 1, tread))
	return ImageTexture.create_from_image(img)

func export_state() -> Dictionary:
	return {"armed": armed, "done": done, "at": [] if is_inf(at.x) else [at.x, at.y, at.z]}
