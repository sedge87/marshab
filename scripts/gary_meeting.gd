extends Node

## Meeting GAR-Y (master-design "Meeting GAR-Y", decided 7 Nov): the moment
## you learn you're not alone on Mars. Through your own eyes, held: the HUD
## fades, you can't walk, and your view is drawn gently to GAR-Y.
## - "pallet": you've freed pallet 3's latches. A folded, dusty shape in the
##   cradle; a lamp flickers; the mast lifts and it unfolds; the head scans the
##   dunes, finds you and stops; a questioning chirp; it hops out, loops in
##   front of you, does a happy spin and parks at your side. The music swells,
##   "GAR-Y" fades up, and the thought "I'm not alone out here." (~24 s)
## - "door": it found you out cold before you'd found it and dragged you
##   home. It waited at the foot of the ramp, tapping, while you came round;
##   you open the hatch and step out, and it looks up at you, rolls close,
##   nudges you, loops, spins and parks. (~18 s)
## GAR-Y is held still (rescuing) while this runs; scripts/drop_field.gd
## starts it and is told when it's over.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const PALLET_SECONDS := 24.0
const DOOR_SECONDS := 18.5
const FOLD_SCALE := .6         # the body squashed down in its cradle
const FOLD_PITCH := -40.0      # the head tucked down

signal finished(mode: String)

var world: Node
var gary: Node3D
var mode := ""
var _t := 0.0
var _last := 0.0
var _player: Node3D
var _head: Node3D
var _huds: Array = []
var _layer: CanvasLayer
var _title: Control
var _from := Vector3.ZERO      # where it starts (in the cradle, or at the ramp foot)
var _out := Vector3.ZERO       # where it lands, hopping out
var _dir := Vector3.FORWARD    # from you, towards where it is
var _loop_dir := Vector3.FORWARD  # where its happy loop goes: open ground, clear of the pallet or the lander
var _park := Vector3.ZERO
var _visual_scale := Vector3.ONE
var _mast_y := 0.0
var _scan_from := 0.0
var _done_cues := {}

func start(target_world: Node, target_gary: Node3D, scene_mode: String, from: Vector3) -> void:
	world = target_world
	gary = target_gary
	mode = scene_mode
	name = "GaryMeeting"
	_player = world.player
	_head = _player.get_node("Head")
	_player.set_meta("ui_freeze", true)
	_player.set("velocity", Vector3.ZERO)
	gary.call("begin_rescue")   # held still: its own brain stays out of it
	gary.set("staying", true)
	_from = from
	var you := _player.global_position
	var flat := Vector3(from.x - you.x, 0, from.z - you.z)
	_dir = flat.normalized() if flat.length() > .3 else -_player.global_transform.basis.z
	if mode == "pallet":
		_out = _ground(you + _dir * maxf(1.6, flat.length() - 1.6))
		_loop_dir = _dir.cross(Vector3.UP).normalized()   # off to your right, beside the pallet
	else:
		_out = _ground(you + _dir * .95)
		var lander: Node3D = world.get("lander")
		var away := Vector3(from.x - lander.global_position.x, 0, from.z - lander.global_position.z) if lander != null else _dir
		_loop_dir = away.normalized() if away.length() > .3 else _dir
	var right := _loop_dir.cross(Vector3.UP).normalized()
	_park = _ground(you + right * 1.3 + _loop_dir * 1.1)
	var visual: Node3D = gary.get("_visual")
	if visual != null: _visual_scale = visual.scale
	var mast: Node3D = gary.get("_mast")
	if mast != null: _mast_y = mast.position.y
	gary.global_position = from
	_face(gary, you - from)
	if mode == "pallet": _fold(1.0)
	else: _eyes(Color("#7FE6FF"), 1.0)
	var hud: Node = world.get("explore_hud")
	if hud != null and hud.visible:
		hud.visible = false
		_huds.append(hud)
	if MHAudio.director() != null: (MHAudio.director()._voice_queue as Array).clear()
	_build_title()

func _ground(at: Vector3, lift := .02) -> Vector3:
	return Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + lift, at.z)

## Its front is −Z, like yours.
static func _yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)

func _face(node: Node3D, d: Vector3) -> void:
	node.rotation.y = _yaw_to(d)

func _eyes(colour: Color, level: float, open := 1.0) -> void:
	var material: StandardMaterial3D = gary.get("_eye_material")
	if material != null: material.albedo_color = colour * level
	for eye in gary.get("_eyes"): (eye as Node3D).scale.y = open

## 1: folded in its cradle, dark; 0: standing tall.
func _fold(amount: float) -> void:
	var visual: Node3D = gary.get("_visual")
	if visual != null: visual.scale = Vector3(_visual_scale.x, _visual_scale.y * lerpf(1.0, FOLD_SCALE, amount), _visual_scale.z)
	var head: Node3D = gary.get("_head")
	if head != null: head.rotation.x = deg_to_rad(FOLD_PITCH * amount)
	if amount >= 1.0: _eyes(Color.BLACK, 0.0, .3)

func _pan(angle: float, tilt_deg: float, rate: float, delta: float) -> void:
	var mast: Node3D = gary.get("_mast")
	var head: Node3D = gary.get("_head")
	var k := minf(1.0, rate * delta)
	if mast != null: mast.rotation.y = lerp_angle(mast.rotation.y, angle, k)
	if head != null: head.rotation.x = lerp_angle(head.rotation.x, deg_to_rad(tilt_deg), k)

## The mast's pan that looks at you.
func _pan_to_you() -> float:
	var local := gary.global_transform.affine_inverse() * _player.global_position
	return clampf(atan2(-local.x, -local.z), -1.4, 1.4)

func _move(to: Vector3) -> void:
	var before := gary.global_position
	gary.global_position = to
	var moved := Vector2(to.x - before.x, to.z - before.z).length()
	var radius := float(gary.get("wheel_radius")) if gary.get("wheel_radius") != null else .2
	var back := 1.0 if (to - before).dot(-gary.global_transform.basis.z) >= 0.0 else -1.0
	for wheel in gary.get("_wheels"): (wheel as Node3D).rotate_object_local(Vector3.RIGHT, -moved / radius * back)

func _cue(id: String, at: float) -> bool:
	if _t < at or _done_cues.has(id): return false
	_done_cues[id] = true
	return true

## Your eyes drift to GAR-Y's head.
func _look(delta: float, rate := 2.2) -> void:
	var head: Node3D = gary.get("_head")
	var target := head.global_position if head != null else gary.global_position + Vector3(0, .8, 0)
	var eye := (_player.get_node("Head/Camera3D") as Node3D).global_position if _player.has_node("Head/Camera3D") else _head.global_position
	var d := target - eye
	var k := minf(1.0, rate * delta)
	_player.rotation.y = lerp_angle(_player.rotation.y, _yaw_to(d), k)
	_head.rotation.x = lerp_angle(_head.rotation.x, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.0, .6), k)

func _process(delta: float) -> void:
	if mode.is_empty() or gary == null or not is_instance_valid(gary): return
	_last = _t
	_t += delta
	_look(delta)
	if mode == "pallet": _pallet(delta)
	else: _door(delta)

# ---------- in the cradle ----------

func _pallet(delta: float) -> void:
	var t := _t
	if t < 1.5:
		return
	if t < 3.0:
		# A lamp flickers: on, off, on.
		if _cue("wake", 1.5): gary.call("_say", "sleepy")
		var on := fmod(t * 9.0, 1.0) < (.25 + .5 * (t - 1.5) / 1.5)
		_eyes(Color("#5A7DFF"), .9 if on else .05, .4)
		return
	if t < 5.0:
		# The mast lifts and it unfolds.
		if _cue("unfold", 3.0): MHAudio.sfx_at("suit_clamp", gary, -6.0, .9)
		var k := ease(clampf((t - 3.0) / 2.0, 0.0, 1.0), -2.0)
		_fold(1.0 - k)
		_eyes(Color("#5A7DFF").lerp(Color("#7FE6FF"), k), lerpf(.6, 1.0, k), lerpf(.4, 1.0, k))
		gary.global_position = _from + Vector3(0, .12 * k, 0)
		return
	if t < 8.0:
		# It looks out over the dunes, one way, then the other.
		if _cue("scan", 5.0):
			gary.call("_say", "curious")
			var mast: Node3D = gary.get("_mast")
			_scan_from = mast.rotation.y if mast != null else 0.0
		var sweep := sin((t - 5.0) / 3.0 * PI * 1.5) * deg_to_rad(55.0)
		_pan(_scan_from + sweep, 4.0, 3.0, delta)
		return
	if t < 10.0:
		# It finds you, and stops. Eyes wide. Then the question.
		_pan(_pan_to_you(), 12.0, 7.0, delta)
		_eyes(Color("#7FE6FF"), 1.15, 1.25)
		if _cue("ask", 9.4): gary.call("_say", "curious")
		return
	if t < 11.4:
		# It hops out of the cradle.
		var k := ease(clampf((t - 10.0) / 1.4, 0.0, 1.0), -1.6)
		var at := _from.lerp(_out, k)
		at.y = lerpf(_from.y + .12, _out.y, k) + sin(k * PI) * .35
		_move(at)
		_face(gary, _player.global_position - at)
		_pan(0.0, 8.0, 5.0, delta)
		if _cue("land", 11.3): MHAudio.sfx_at("place", gary, -6.0)
		return
	_together(delta, 11.4)

# ---------- at the ramp ----------

func _door(delta: float) -> void:
	var t := _t
	if t < 1.5:
		_pan(_pan_to_you(), 14.0, 4.0, delta)
		return
	if t < 3.0:
		# Head on one side: is that you?
		if _cue("ask", 1.5): gary.call("_say", "curious")
		var head: Node3D = gary.get("_head")
		if head != null: head.rotation.z = lerp_angle(head.rotation.z, deg_to_rad(16.0), minf(1.0, delta * 4.0))
		_eyes(Color("#7FE6FF"), 1.15, 1.2)
		return
	if t < 4.4:
		var head: Node3D = gary.get("_head")
		if head != null: head.rotation.z = lerp_angle(head.rotation.z, 0.0, minf(1.0, delta * 4.0))
		var k := ease(clampf((t - 3.0) / 1.4, 0.0, 1.0), -1.6)
		_move(_ground(_from.lerp(_out, k)))
		_face(gary, _player.global_position - gary.global_position)
		_pan(_pan_to_you(), 16.0, 5.0, delta)
		return
	if t < 5.4:
		# A nudge against your leg.
		var k := clampf((t - 4.4) / 1.0, 0.0, 1.0)
		var bump := sin(k * PI) * .22
		_move(_ground(_out - _dir * bump))
		if _cue("nudge", 4.7):
			MHAudio.sfx("place", -8.0)
			_head.rotation.z = deg_to_rad(2.5)
			create_tween().tween_property(_head, "rotation:z", 0.0, .5)
		return
	if _cue("happy", 5.4): gary.call("_say", "happy")
	if t < 6.0: return
	_together(delta, 6.0)

# ---------- the rest, both ways ----------

## From `begin` on: a happy loop in front of you, a spin, then it parks at
## your side; the music swells, its name, and the thought.
func _together(delta: float, begin: float) -> void:
	var t := _t - begin
	var you := _player.global_position
	var centre := you + _loop_dir * 2.8
	var radius := 1.2
	var loop_start := centre - _loop_dir * radius
	if t < .8:
		var k := ease(clampf(t / .8, 0.0, 1.0), -1.4)
		var at := _out.lerp(loop_start, k)
		_move(_ground(at))
		_face(gary, loop_start - _out if (loop_start - _out).length() > .05 else _loop_dir)
	elif t < 4.6:
		# Round once: start nearest you, go out and back.
		var k := (t - .8) / 3.8
		var a := -PI * .5 + k * TAU
		var side := _loop_dir.cross(Vector3.UP).normalized()
		var at := centre + (_loop_dir * sin(a) + side * cos(a)) * radius
		var ahead := (_loop_dir * cos(a) - side * sin(a))
		_move(_ground(at))
		_face(gary, ahead)
		_pan(0.0, 6.0, 4.0, delta)
		_eyes(Color("#8CF5A0"), 1.2, .65)
	elif t < 5.8:
		# A happy spin.
		if _cue("tada", 4.6 + begin): gary.call("_say", "tada")
		gary.rotation.y += TAU / 1.2 * delta
	elif t < 7.4:
		var k := ease(clampf((t - 5.8) / 1.6, 0.0, 1.0), -1.6)
		var from := _ground(centre - _loop_dir * radius)
		_move(_ground(from.lerp(_park, k)))
		gary.rotation.y = lerp_angle(gary.rotation.y, _yaw_to(you - gary.global_position), minf(1.0, delta * 5.0))
		_pan(_pan_to_you(), 12.0, 4.0, delta)
	else:
		_pan(_pan_to_you(), 12.0, 3.0, delta)
		_eyes(Color("#8CF5A0"), 1.1, .7)
	if _cue("swell", begin + 5.8): MHAudio.moment()
	if _cue("title", begin + 6.4): _show_title()
	if _cue("thought", begin + 7.6):
		var notes: Node = world.get("notes")
		if notes != null: notes.think("not_alone")
	var length := PALLET_SECONDS if mode == "pallet" else DOOR_SECONDS
	if _t >= length: _finish()

# ---------- its name ----------

func _build_title() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 44
	add_child(_layer)
	# High on the screen, over the sky, clear of GAR-Y.
	var col := MHStyle.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.position.y = 120.0
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(col)
	var title := MHStyle.display("GAR-Y", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := MHStyle.mono(str(gary.get("FULL_NAME")) if gary.get("FULL_NAME") != null else "Geological Analysis Rover, Y-Class", 15, MHStyle.TEXT_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_title = col
	_title.modulate.a = 0.0

func _show_title() -> void:
	if _title == null: return
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 1.2)
	tween.tween_interval(3.2)
	tween.tween_property(_title, "modulate:a", 0.0, 1.4)

func _finish() -> void:
	var finished_mode := mode
	mode = ""
	_fold(0.0)
	var visual: Node3D = gary.get("_visual")
	if visual != null: visual.scale = _visual_scale
	var mast: Node3D = gary.get("_mast")
	if mast != null: mast.position.y = _mast_y
	gary.set("staying", false)
	gary.set("rescuing", false)
	gary.set("_met", true)
	gary.set("_escort_until", Time.get_ticks_msec() + 60000)
	_player.set_meta("ui_freeze", false)
	for hud in _huds: hud.visible = true
	_huds.clear()
	finished.emit(finished_mode)
	queue_free()
