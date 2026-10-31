extends Node

## GAR-Y drags you home (gameplay-loop brief §4.3). When your suit runs out of
## oxygen out on the ground in Survival, your view sinks to the ground and
## goes dark. Then GAR-Y trundles up, locks its gripper onto the drag handle
## on your suit's back pack and hauls you home, reversing so it can keep its
## eyes on you and beeping anxiously over the radio.
##
## The clock runs on while you're out, by how far it had to come and drag you:
## a couple of hours from close by, most of a sol from far out. The habitat
## lives through those hours as it does while you sleep. You come round
## inside: beside a medical cot once you have one, else in the airlock (the
## lander cabin before there's a habitat).
##
## What it costs you (scripts/suit.gd keeps these):
## - anything you were carrying is dropped where you fell, marked on the
##   region map, so you can go back for it;
## - the suit's seals take a knock: a leak until you repair it at a suit
##   service panel;
## - the rover stays where you left it;
## - GAR-Y remembers: a count on its card.
##
## Without GAR-Y (some Missions) you just come round inside.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const APPROACH := 7.0          # m: where GAR-Y comes into view
const GRIP := 1.45             # m from you to GAR-Y's centre while it drags you
const EYE := .32               # your eyes, lying on the ground
const DRAG_SPEED := 1.1        # m/s, the bit you see
const CLOCK_SPEED := 160.0     # how fast the clock runs while you're out
const GARY_KMH := 1.5          # how fast it comes for you
const DRAG_KMH := .4           # how fast it drags you home
const SEARCH_HOURS := .75      # finding you
const MIN_HOURS := 1.5
const MAX_HOURS := 20.0
## Each part of the scene, in real seconds.
const FALL := 2.4
const DARK := 1.2
const ARRIVE := 3.4
const HOOK := 1.3
const DRAG := 4.6
const WAKE := 1.6

signal finished(summary: Dictionary)

var world: Node
var suit: Node
var gary: Node3D
var hours := 0.0               # how long you're out, in game hours
var home_distance := 0.0
var dropped := {}              # what you were carrying, left where you fell
var phase := ""
var _t := 0.0
var _player: CharacterBody3D
var _head: Node3D
var _head_was: Transform3D
var _fell := Vector3.ZERO
var _dir := Vector3.FORWARD    # from where you fell toward home
var _wake := {}
var _passed := 0.0
var _last_hour := 0.0
var _beep := 0.0
var _layer: CanvasLayer
var _shade: ColorRect
var _shade_material: ShaderMaterial
var _caption: Label
var _clock: Label
var _status: Label
var _drag_sound: AudioStreamPlayer
var _huds: Array = []          # the HUDs hidden for the scene

func start(target_world: Node, target_suit: Node) -> void:
	world = target_world
	suit = target_suit
	_player = world.player
	_head = _player.get_node("Head")
	_head_was = _head.transform
	_fell = _player.global_position
	gary = world.get("scout_rover") as Node3D
	if gary != null and (not is_instance_valid(gary) or not gary.has_method("begin_rescue")): gary = null
	_wake = suit.wake_spot()
	var home: Vector3 = _wake.position
	home_distance = Vector2(home.x - _fell.x, home.z - _fell.z).length()
	var flat := Vector3(home.x - _fell.x, 0, home.z - _fell.z)
	_dir = flat.normalized() if flat.length() > .5 else -_player.global_transform.basis.z
	_player.set_meta("ui_freeze", true)
	if gary != null:
		# What you were carrying falls where you do.
		if world.get("carry") != null and not (world.carry.carrying as Dictionary).is_empty():
			var label := str(EquipmentCatalog.get_entry(str(world.carry.carrying.id)).get("label", "kit"))
			var spot := _ground(_fell + _dir.rotated(Vector3.UP, 1.3) * .8, 0.0)
			var record: Dictionary = world.carry.drop_at(spot)
			if not record.is_empty(): dropped = {"placement_id": str(record.placement_id), "label": label, "position": spot}
		var gary_from: Vector3 = gary.global_position
		var reach := Vector2(gary_from.x - _fell.x, gary_from.z - _fell.z).length()
		hours = clampf(SEARCH_HOURS + reach / 1000.0 / GARY_KMH + home_distance / 1000.0 / DRAG_KMH, MIN_HOURS, MAX_HOURS)
		gary.begin_rescue()
		gary.visible = false
	elif world.get("carry") != null:
		world.carry.put_back()
	_build_overlay()
	# Nothing on screen but what you'd see: no HUD, and no suit lines still
	# waiting to be said.
	for hud in [world.get("explore_hud"), world.get("mission_hud")]:
		if hud != null and hud.visible:
			hud.visible = false
			_huds.append(hud)
	if MHAudio.director() != null: (MHAudio.director()._voice_queue as Array).clear()
	MHAudio.sfx("suit_alarm", -2.0)
	phase = "fall"

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 45
	add_child(_layer)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	# Tunnel vision closing in from the edges, over a dark wash.
	shader.code = """shader_type canvas_item;
uniform float tunnel = 0.0;
uniform float dark = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.7;
	float edge = smoothstep(0.95 - 0.7 * tunnel, 1.15 - 0.55 * tunnel, length(p) * 1.6);
	COLOR = vec4(0.02, 0.0, 0.0, max(dark, max(edge * tunnel * 1.4, tunnel * 0.22)));
}"""
	_shade_material = ShaderMaterial.new()
	_shade_material.shader = shader
	_shade.material = _shade_material
	_layer.add_child(_shade)
	_caption = MHStyle.mono("", 17, Color(1, 1, 1, .85))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.position.y -= 90.0
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(_caption)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(centre)
	var col := MHStyle.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(col)
	_clock = MHStyle.display("", 72)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock)
	_status = MHStyle.mono("", 15, MHStyle.TEXT_MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)
	_clock.visible = false
	_status.visible = false
	_drag_sound = AudioStreamPlayer.new()
	_drag_sound.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_drag_sound.volume_db = -14.0
	add_child(_drag_sound)

func _shade_to(tunnel: float, dark: float) -> void:
	_shade_material.set_shader_parameter("tunnel", tunnel)
	_shade_material.set_shader_parameter("dark", dark)

## A point on the ground (the region, trenches and all), lifted a little.
func _ground(at: Vector3, lift := .05) -> Vector3:
	return Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + lift, at.z)

## Your view, lying on your back: low, looking along the ground toward home
## (where GAR-Y comes from), tipped up a little and rolled to the side.
func _lie(at: Vector3, pitch: float, roll: float) -> void:
	_player.global_position = _ground(at, 0.0)
	_player.rotation.y = atan2(-_dir.x, -_dir.z)
	_head.position = Vector3(0, EYE, 0)
	_head.rotation = Vector3(pitch, 0, roll)

func _gary_at(at: Vector3, delta: float) -> void:
	var before := gary.global_position
	gary.global_position = _ground(at, .02)
	gary.rotation.y = atan2(_dir.x, _dir.z)   # facing you, back toward home
	gary.rescue_frame(before, delta)

func _process(delta: float) -> void:
	if phase.is_empty(): return
	_t += delta
	match phase:
		"fall":
			# Your knees go; the world tips and closes in.
			var k := clampf(_t / FALL, 0.0, 1.0)
			var sink := ease(k, -2.2)
			_head.position.y = lerpf(_head_was.origin.y, EYE, sink)
			_head.rotation.x = lerpf(_head_was.basis.get_euler().x, deg_to_rad(38.0), sink)
			_head.rotation.z = lerpf(0.0, deg_to_rad(24.0), sink)
			_shade_to(k, maxf(0.0, (k - .7) / .3))
			if _t >= FALL: _next("dark")
		"dark":
			if _t >= DARK:
				if gary == null: _next("out")
				else:
					gary.visible = true
					_lie(_fell, deg_to_rad(8.0), deg_to_rad(14.0))
					_gary_at(_fell + _dir * APPROACH, 0.0)
					gary.call("_say", "worried")
					_next("arrive")
		"arrive":
			# It comes trundling up out of the dust.
			var k := clampf(_t / ARRIVE, 0.0, 1.0)
			_shade_to(.75, lerpf(1.0, .25, clampf(_t / .9, 0.0, 1.0)))
			_gary_at(_fell + _dir * lerpf(APPROACH, GRIP, ease(k, -1.6)), delta)
			_caption.text = "GAR-Y · radio:  ‹frantic beeping›"
			if _t >= ARRIVE:
				gary.call("_set_pose", "reach")
				_next("hook")
		"hook":
			_gary_at(_fell + _dir * GRIP, delta)
			if _t >= .55 and _t - delta < .55:
				MHAudio.sfx_at("suit_clamp", gary, -2.0)
				_head.rotation.x += .04   # the tug
			if _t >= HOOK:
				_drag_sound.stream = MHAudio.director()._stream("sfx/suit_drag") if MHAudio.director() != null else null
				if _drag_sound.stream != null: _drag_sound.play()
				_next("drag")
		"drag":
			# Hauled along on your back, the ground sliding by.
			var along := _fell + _dir * DRAG_SPEED * _t
			_lie(along, deg_to_rad(8.0 + sin(_t * 7.8) * 1.2), deg_to_rad(14.0 + sin(_t * 3.9) * 2.0))
			_gary_at(along + _dir * GRIP, delta)
			_beep -= delta
			if _beep <= 0.0:
				_beep = 1.7
				gary.call("_say", "worried" if randf() < .6 else "curious")
			_caption.text = "GAR-Y · radio:  ‹a long, reproachful whistle›" if _t > DRAG * .5 else "GAR-Y · radio:  ‹frantic beeping›"
			_shade_to(.75 + .25 * clampf(_t / DRAG, 0.0, 1.0), clampf((_t - (DRAG - 1.2)) / 1.2, .25, 1.0))
			if _drag_sound.stream != null and not _drag_sound.playing: _drag_sound.play()
			if _t >= DRAG:
				_drag_sound.stop()
				_next("out")
		"out":
			# The hours pass: the clock runs and the habitat lives through them.
			var hour: float = world.day_night.hour
			_passed += wrapf(hour - _last_hour, 0.0, 24.0)
			_last_hour = hour
			var left := maxf(0.0, hours - _passed)
			_clock.text = "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]
			if gary != null and hours > 0.0:
				var to_go := home_distance * left / hours
				_status.text = "GAR-Y is bringing you home · %s to go" % (("%.1f km" % (to_go / 1000.0)) if to_go >= 1000.0 else "%d m" % roundi(to_go))
			if _passed >= hours or world.day_night.frozen:
				world.day_night.time_scale = 1.0
				_next("wake")
		"wake":
			_shade_to(.5 * (1.0 - _t / WAKE), 1.0 - clampf(_t / WAKE, 0.0, 1.0))
			_clock.modulate.a = 1.0 - clampf(_t * 3.0, 0.0, 1.0)
			_status.modulate.a = _clock.modulate.a
			if _t >= WAKE: _finish()

func _next(next_phase: String) -> void:
	phase = next_phase
	_t = 0.0
	if phase == "out":
		_caption.text = ""
		_shade_to(0.0, .97)
		# You're home while the hours pass (so the suit tops up from the
		# habitat like anyone's would), GAR-Y beside you.
		_head.transform = _head_was
		_player.global_position = _wake.position
		_player.rotation.y = float(_wake.yaw)
		_player.safe_position = _player.global_position
		_player.velocity = Vector3.ZERO
		if gary != null:
			var side: Vector3 = _player.global_transform.basis.x * 1.3
			gary.global_position = _wake.position + side + Vector3(0, -.1, 0)
			gary.rotation.y = _player.rotation.y + PI * .5
			_clock.visible = true
			_status.visible = true
			_last_hour = world.day_night.hour
			world.day_night.time_scale = CLOCK_SPEED

func _finish() -> void:
	phase = ""
	_player.set_meta("ui_freeze", false)
	for hud in _huds: hud.visible = true
	if gary != null: gary.end_rescue()
	var summary := {"rescued": gary != null, "hours": _passed, "distance": home_distance, "dropped": dropped,
		"rescues": int(gary.get("rescues")) if gary != null else 0}
	finished.emit(summary)
	queue_free()
