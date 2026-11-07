extends Node

## GAR-Y's first sunset with you (step 3a; the user's idea, 7 Nov). GAR-Y
## starts it: at the first sunset after you've met, if you're both outside,
## it rolls up beside you, chirps and turns towards the sun, and you're
## offered "Watch the sunset with GAR-Y" (E on it). Your choice:
## - yes: your view eases round to the sun, the HUD goes, GAR-Y settles at
##   your side and you sit in the quiet while the sky goes blue round the sun,
##   with its own music moment and a Journal page;
## - walk on (or let the sun go): it watches a moment alone, then follows,
##   and asks again at the next sunset.
## Once shared, it's done for good.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const OFFER_FROM := 1.0        # hours before sunset
const OFFER_UNTIL := .25       # hours after
const NEAR := 30.0             # GAR-Y must be this close to come over
const WALK_OFF := 28.0         # walk this far and the offer passes
const WATCH := 16.0            # seconds of watching

var world: Node
var shared := false
var phase := ""                # "", "offer", "watch"
var _offered_sol := -1
var _t := 0.0
var _check := 0.0
var _head: Node3D
var _from_yaw := 0.0
var _to_yaw := 0.0
var _from_pitch := 0.0
var _huds: Array = []

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "GarySunset"
	shared = bool(saved.get("shared", false))

func gary() -> Node3D:
	var g: Variant = world.get("scout_rover")
	return g as Node3D if g != null and is_instance_valid(g) and g.is_inside_tree() else null

func _sunset_hour() -> float:
	return float((MHGame.site().get("day_cycle", {}) as Dictionary).get("sunset_hour", 19.0))

func _sol() -> int:
	var notes: Node = world.get("notes")
	return int(notes.call("_sol")) if notes != null else 1

func _outside() -> bool:
	var at: Vector3 = world.player.global_position
	var lander: Node = world.get("lander")
	if lander != null and lander.cabin_contains(at): return false
	var builder: Node = world.get("builder")
	if builder != null and builder.is_inside(at): return false
	return not bool(world.player.get_meta("driving", false))

func _process(delta: float) -> void:
	if shared or world == null or world.get("player") == null: return
	match phase:
		"": _wait(delta)
		"offer": _offer(delta)
		"watch": _watch(delta)

func _wait(delta: float) -> void:
	_check -= delta
	if _check > 0.0: return
	_check = .5
	var g := gary()
	if g == null or not bool(world.get("gary_met")): return
	var hour := MHGame.sol_hour
	var sunset := _sunset_hour()
	if hour < sunset - OFFER_FROM or hour > sunset + OFFER_UNTIL: return
	var today := _sol()
	if _offered_sol == today or not _outside(): return
	var you: Vector3 = world.player.global_position
	if g.global_position.distance_to(you) > NEAR or bool(g.get("rescuing")): return
	_offered_sol = today
	offer()

## GAR-Y comes over and asks.
func offer() -> void:
	phase = "offer"
	_t = 0.0
	var g := gary()
	g.set("_escort_until", Time.get_ticks_msec() + 60000)   # sticks close
	g.call("_say", "curious")
	g.set_meta("sunset_offer", true)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.show_equipment_note("GAR-Y", "GAR-Y chirps and turns towards the sun. E on GAR-Y: watch the sunset together.")

func _offer(delta: float) -> void:
	_t += delta
	var g := gary()
	if g == null: return _end_offer()
	var you: Vector3 = world.player.global_position
	if _t > 2.0 and fmod(_t, 7.0) < delta: g.call("_say", "curious")
	if g.global_position.distance_to(you) > WALK_OFF or MHGame.sol_hour > _sunset_hour() + OFFER_UNTIL + .1 or not _outside():
		_end_offer()

func _end_offer() -> void:
	phase = ""
	var g := gary()
	if g != null:
		g.remove_meta("sunset_offer")
		g.call("_say", "sleepy")
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("GAR-Y")

## E on GAR-Y while it's asking (scripts/companion_rover.gd).
func accept() -> void:
	if phase != "offer": return
	var g := gary()
	if g == null: return
	g.remove_meta("sunset_offer")
	phase = "watch"
	_t = 0.0
	var player: Node3D = world.player
	_head = player.get_node("Head")
	player.set_meta("ui_freeze", true)
	player.set("velocity", Vector3.ZERO)
	var to_sun := sun_direction()
	_from_yaw = player.rotation.y
	_to_yaw = _from_yaw + angle_difference(_from_yaw, atan2(-to_sun.x, -to_sun.z))
	_from_pitch = _head.rotation.x
	# GAR-Y beside you, facing the same way, quiet.
	var facing := Basis(Vector3.UP, _to_yaw)
	var spot := player.global_position + facing.x * 1.6 - facing.z * 2.2   # just ahead on your right, in view
	spot.y = MHSiteTerrain.height(spot.x, spot.z) + .15
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(g, "global_position", spot, 2.0)
	tween.parallel().tween_property(g, "rotation:y", g.rotation.y + angle_difference(g.rotation.y, _to_yaw), 2.0)   # its front is -Z, like yours
	var mast: Node3D = g.get("_mast")
	var head: Node3D = g.get("_head")
	if mast != null: tween.parallel().tween_property(mast, "rotation:y", 0.0, 2.0)   # head straight ahead, at the sun
	if head != null: tween.parallel().tween_property(head, "rotation:x", deg_to_rad(6.0), 2.0)
	g.set("staying", true)
	g.set("rescuing", true)   # held still, looking at the sun (its own brain would turn to you)
	var hud: Node = world.get("explore_hud")
	if hud != null:
		hud.hide_equipment_note("GAR-Y")
		if hud.visible:
			hud.visible = false
			_huds.append(hud)
	MHAudio.moment()

func _watch(delta: float) -> void:
	_t += delta
	var player: Node3D = world.player
	var k := ease(clampf(_t / 3.0, 0.0, 1.0), -2.0)
	player.rotation.y = lerpf(_from_yaw, _to_yaw, k)
	_head.rotation.x = lerpf(_from_pitch, deg_to_rad(4.0), k)
	var g := gary()
	if g != null and _t > 6.0 and _t - delta <= 6.0: g.call("_say", "happy")
	if _t >= WATCH: _finish()

func _finish() -> void:
	phase = ""
	shared = true
	world.player.set_meta("ui_freeze", false)
	for hud in _huds: hud.visible = true
	_huds.clear()
	var g := gary()
	if g != null:
		g.set("staying", false)
		g.set("rescuing", false)
		g.set("_escort_until", Time.get_ticks_msec() + 30000)
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("sunset")
		notes.answer("sunset_gary")

## Towards the sun, flat: the sky's sun light shines along its -Z
## (scripts/original_mars_environment.gd).
func sun_direction() -> Vector3:
	var west := Vector3(-1, 0, 0)
	var env: Variant = world.get("environment")
	var sun: DirectionalLight3D = env.get("sun") if env != null else null
	if sun == null: return west
	var dir := sun.global_basis.z
	dir.y = 0.0
	return dir.normalized() if dir.length() > .01 else west

func export_state() -> Dictionary:
	return {"shared": shared}
