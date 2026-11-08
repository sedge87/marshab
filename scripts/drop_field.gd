extends Node3D

## The storm's near pallets after the first (step 3a of
## docs/systems-and-items.md §14). The map follows your landing (§9.3): each
## kind goes on the best real spot of its kind near where you touched down,
## clear of the first parachute and of each other.
## - Pallet 2, power: about 0.6 km out, off to one side of the ridge, on flat
##   open ground.
## - Pallet 3, GAR-Y: about 0.8 km, the roughest walkable ground (a boulder
##   field is laid round it).
## - Pallet 4, field tools: about 1 km, a low hollow.
## From the Parachute ridge you can see pallets 2 and 3; waking GAR-Y points
## you to pallet 4. The rest of the near ring comes later.
##
## It also keeps what they gave you: the field tools, and GAR-Y's first
## sunset with you (scripts/gary_sunset.gd).
##
## The guided days, version 2 (docs/opening-days.md): GAR-Y woke itself in
## the storm and has been out working. Day 1 you see pallets 2 and 4 from the
## ridge (Castellanos names them); pallet 3 stays out of sight. Day 2's call
## brings it out: its cradle open and empty, and GAR-Y at work past it. Walk
## up to it and it meets you ("field").

const SITE := preload("res://scripts/drop_site.gd")
const SUNSET := preload("res://scripts/gary_sunset.gd")
const MEETING := preload("res://scripts/gary_meeting.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const RIDGE_VIEW := 45.0          # this close to the first canopy, you see the next two

## [kind, nearest, furthest, the ground it wants]
const KINDS := [["power", 520.0, 680.0, "flat"], ["gary", 720.0, 900.0, "rough"], ["tools", 900.0, 1150.0, "low"]]
const APART_DEG := 50.0           # bearings at least this far apart, from the lander
const DOOR_WAIT := 3.0            # GAR-Y waits this far out from the ramp's foot
const DOOR_REACH := 4.2           # step out this close and it introduces itself
const TAP_EVERY := 7.0            # seconds between its taps on the hull

var world: Node
var sites := {}                   # kind → scripts/drop_site.gd
var tools := false                # pallet 4 opened: hammer, headlamp, patch kit
var chutes_seen := false
var sunset: Node
## It found you before you found it, and waits at the ramp to say hello
## (scripts/gary_meeting.gd "door").
var intro_pending := false
## Pallet 3 is open and GAR-Y lies folded in it, waiting to be lifted out.
var gary_in_cradle := false
var _cradled := false
var meeting: Node
var _holding := false
var _tap := 2.0
var _check := 0.0
var gary_working := false        # version 2, day 2: GAR-Y out at work, waiting to be found
var crate: Node3D                # version 2, day 2: the spares crate GAR-Y was circling (scripts/spares_crate.gd)
const CRATE := preload("res://scripts/spares_crate.gd")
const FIND_REACH := 9.0          # this close and it notices you
const WORK_OUT := 140.0          # how far past its cradle it's working

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "DropField"
	add_to_group("drop_field")
	tools = bool(saved.get("tools", false))
	chutes_seen = bool(saved.get("chutes_seen", false))
	intro_pending = bool(saved.get("intro_pending", false))
	gary_in_cradle = bool(saved.get("gary_in_cradle", false))
	var saved_sites: Dictionary = saved.get("sites", {})
	var taken: Array = []
	var ridge: Vector3 = world.storm_drop.ridge if world.get("storm_drop") != null else Vector3.INF
	if not is_inf(ridge.x): taken.append(_bearing(ridge))
	for spec in KINDS:
		var kind := str(spec[0])
		var where := Vector3.INF
		var yaw := 0.0
		var state: Dictionary = saved_sites.get(kind, {})
		if state.has("at"):
			var p: Array = state.at
			where = Vector3(float(p[0]), float(p[1]), float(p[2]))
			yaw = float(state.get("yaw", 0.0))
			# Older saves could strand an unopened pallet on a mesa top: move it.
			if not bool(state.get("opened", false)) and not reachable(where):
				where = Vector3.INF
				state = {}
		if is_inf(where.x):
			where = choose(kind, float(spec[1]), float(spec[2]), str(spec[3]), taken, ridge)
			var back: Vector3 = world.lander.global_position - where
			yaw = atan2(back.x, back.z)
		taken.append(_bearing(where))
		var site: Node3D = SITE.new()
		add_child(site)
		site.setup(self, kind, where, yaw, state)
		sites[kind] = site
	if tools: _apply_tools()
	sunset = SUNSET.new()
	add_child(sunset)
	sunset.setup(world, saved.get("sunset", {}))
	gary_working = bool(saved.get("gary_working", false))
	if v2() and sites.has("gary"):
		sites.gary.empty = true   # it let itself out in the storm
		_show_cradle(gary_working or bool(world.get("gary_met")) or bool(sites.gary.pallet.opened))
	if gary_working: _keep_working.call_deferred()
	var crate_state: Dictionary = saved.get("crate", {})
	if crate_state.has("at"):
		var c: Array = crate_state.at
		_add_crate(Vector3(float(c[0]), float(c[1]), float(c[2])), crate_state)

func v2() -> bool:
	return int(world.get("opening_version")) >= 2

## Pallet 3 out of sight (day 1 of version 2) or there to be found.
func _show_cradle(on: bool) -> void:
	var site: Node3D = sites.get("gary")
	if site == null: return
	site.visible = on
	site.set_process(on)
	for body in site.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

## Day 2's call (data/radio/day2.txt "do gary_out"): its cradle shows, open
## and empty, and GAR-Y is at work past it. Castellanos marks the movement.
func gary_out() -> void:
	if bool(world.get("gary_met")) or not sites.has("gary"): return
	_show_cradle(true)
	var site: Node = sites.gary
	if not site.pallet.opened: site.pallet.open(false)
	gary_working = true
	_keep_working()
	if crate == null:
		var spot := work_spot()
		var side: Vector3 = (spot - world.lander.global_position).normalized().cross(Vector3.UP) * 3.5
		_add_crate(spot + side, {})
	var known: Node = world.get("known")
	var gary: Node3D = world.get("scout_rover")
	if known != null and gary != null: known.learn("gary_moving", "find", region_at(gary.global_position), "Something moving", "you", "castellanos")

func _add_crate(at: Vector3, state: Dictionary) -> void:
	crate = CRATE.new()
	add_child(crate)
	crate.setup(world, self, at, state)

## Where GAR-Y's working: past its cradle, away from the lander, on ground you can reach.
func work_spot() -> Vector3:
	var site: Node = sites.gary
	var away: Vector3 = site.at - world.lander.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > .1 else Vector3.FORWARD
	for turn in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0]:
		var p: Vector3 = site.at + away.rotated(Vector3.UP, deg_to_rad(turn)) * WORK_OUT
		p = site._ground(p)
		if reachable(p): return p
	return site._ground(site.at + away * 20.0)

## GAR-Y, held at its work, head down to the ground, till you come.
func _keep_working() -> void:
	if not gary_working: return
	var gary: Node3D = world.get("scout_rover")
	if gary == null or not is_instance_valid(gary):
		gary = world.meet_gary(work_spot())
		if gary == null: return
	elif gary.global_position.distance_to(work_spot()) > 30.0: gary.global_position = work_spot()
	gary.call("begin_rescue")   # held still
	gary.set("staying", true)
	var head: Node3D = gary.get("_head")
	if head != null: head.rotation.x = deg_to_rad(-25.0)

func _bearing(p: Vector3) -> float:
	var home: Vector3 = world.lander.global_position
	return atan2(p.x - home.x, p.z - home.z)

## The best spot for a kind of pallet, round the lander.
func choose(kind: String, nearest: float, furthest: float, ground: String, taken: Array, ridge: Vector3) -> Vector3:
	var home: Vector3 = world.lander.global_position
	var best := -INF
	var out := Vector3.INF
	for distance in range(int(nearest), int(furthest) + 1, 40):
		for step in 24:
			var bearing := step * TAU / 24.0
			if taken.any(func(b): return absf(angle_difference(float(b), bearing)) < deg_to_rad(APART_DEG)): continue
			var p := home + Vector3(sin(bearing), 0, cos(bearing)) * float(distance)
			if not is_inf(ridge.x) and Vector2(p.x - ridge.x, p.z - ridge.z).length() < 250.0: continue
			var h: float = MHSiteTerrain.height(p.x, p.z)
			var slope := _slope(p, 6.0)
			if slope > 2.5: continue
			var score := 0.0
			match ground:
				"flat": score = h * .1 - _roughness(p) * 4.0 - slope * 2.0 - absf(distance - 600.0) * .01
				"rough": score = _roughness(p) * 2.0 - slope - absf(distance - 800.0) * .01
				"low": score = (_ring_mean(p, 60.0) - h) * 1.5 - slope - absf(distance - 1000.0) * .01
			if score > best and reachable(p):
				best = score
				out = Vector3(p.x, h, p.z)
	if is_inf(out.x):
		var p := home + Vector3(0, 0, -(nearest + furthest) * .5)
		out = Vector3(p.x, MHSiteTerrain.height(p.x, p.z), p.z)
	return out

## Can you walk there from the lander? Marches the straight line in 2 m
## steps; a cliff (two steps in a row steeper than 45°) rules the spot out,
## so nothing lands on a mesa top or a crater floor you can't climb from.
## Conservative: a spot with a ramp round the side may be refused too.
func reachable(p: Vector3) -> bool:
	var home: Vector3 = world.lander.global_position
	return MHSiteTerrain.reachable_on_foot(Vector2(home.x, home.z), Vector2(p.x, p.z))

func _slope(p: Vector3, reach: float) -> float:
	var h: float = MHSiteTerrain.height(p.x, p.z)
	var most := 0.0
	for d in [Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach)]:
		most = maxf(most, absf(MHSiteTerrain.height(p.x + d.x, p.z + d.y) - h))
	return most

## How broken the ground is round a spot: how far the heights on rings 8,
## 16 and 24 m out stray from the plane of the slope (so an even hillside
## counts as smooth, and humps and hollows as rough).
func _roughness(p: Vector3) -> float:
	var total := 0.0
	var count := 0
	for reach in [8.0, 16.0, 24.0]:
		var heights: Array = []
		var mean := 0.0
		var a := 0.0
		var b := 0.0
		for i in 12:
			var angle := i * TAU / 12.0
			var h: float = MHSiteTerrain.height(p.x + cos(angle) * reach, p.z + sin(angle) * reach)
			heights.append(h)
			mean += h / 12.0
			a += h * cos(angle) / 6.0
			b += h * sin(angle) / 6.0
		for i in 12:
			var angle := i * TAU / 12.0
			total += absf(float(heights[i]) - (mean + a * cos(angle) + b * sin(angle)))
			count += 1
	return total / count

func _ring_mean(p: Vector3, reach: float) -> float:
	var total := 0.0
	for i in 12:
		var d := Vector2(reach, 0).rotated(i * TAU / 12.0)
		total += MHSiteTerrain.height(p.x + d.x, p.z + d.y)
	return total / 12.0

func region_at(p: Vector3) -> Vector2:
	var known: Node = world.get("known")
	return Vector2(p.x, p.z) + (known.origin as Vector2 if known != null else Vector2.ZERO)

static func direction_word(offset: Vector3) -> String:
	var bearing := wrapf(rad_to_deg(atan2(offset.x, -offset.z)), 0.0, 360.0)
	return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][roundi(bearing / 45.0) % 8]

# ---------- what you find out ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null: return
	_check = .5
	var you: Vector3 = world.player.global_position
	var drop: Node = world.get("storm_drop")
	if not chutes_seen and drop != null and you.distance_to(drop.ridge) < RIDGE_VIEW: see_from_ridge()
	_door_intro(delta + .5)
	_keep_in_cradle()
	_found_at_work()
	var notes: Node = world.get("notes")
	var second: String = "tools" if v2() else "gary"
	if notes != null and notes.is_open("chutes") and sites.power.pallet.opened and sites[second].pallet.opened: notes.answer("chutes")

## Day 2: close enough, GAR-Y looks up and comes to you.
func _found_at_work() -> void:
	if not gary_working or meeting != null: return
	var gary: Node3D = world.get("scout_rover")
	if gary == null or not is_instance_valid(gary): return
	if (world.player as Node3D).global_position.distance_to(gary.global_position) > FIND_REACH: return
	gary_working = false
	_meet(gary, "field", gary.global_position)

## Up on the Parachute ridge: two more canopies in sight.
func see_from_ridge() -> void:
	chutes_seen = true
	var known: Node = world.get("known")
	var second: String = "tools" if v2() else "gary"
	for kind in ["power", second]:
		if known != null: known.learn(sites[kind].id(), "find", region_at(sites[kind].at), "Parachute", "you", "castellanos" if v2() else "")
	var notes: Node = world.get("notes")
	var from: Vector3 = world.storm_drop.ridge
	if notes != null: notes.think("chutes", "start", {"a": direction_word(sites.power.at - from), "b": direction_word(sites[second].at - from)})
	var radio: Node = world.get("radio")
	if v2() and radio != null: radio.ring("d1_ridge")

func pallet_opened(_site: Node) -> void:
	pass

# ---------- GAR-Y ----------

## Pallet 3 opened: GAR-Y lies folded in its cradle, dark. You lift it out
## (E on it), and it wakes and unfolds while you watch (scripts/gary_meeting.gd
## "pallet").
func wake_gary(_site: Node) -> void:
	var gary: Node3D = world.meet_gary(cradle_spot())
	if gary == null: return
	gary_in_cradle = true
	_cradled = false
	_keep_in_cradle()

func cradle_spot() -> Vector3:
	var site: Node = sites.get("gary")
	return site.pallet.inside_point() + Vector3(0, -.04, 0) if site != null else Vector3.ZERO

func _keep_in_cradle() -> void:
	if not gary_in_cradle or _cradled or meeting != null: return
	var gary: Node3D = world.get("scout_rover")
	if gary == null or not is_instance_valid(gary) or not gary.is_inside_tree(): return
	_cradled = true
	gary.call("begin_rescue")   # held still
	gary.set("staying", true)
	gary.set_meta("lift_out", true)
	var pallet: Node3D = sites.gary.pallet
	gary.global_position = cradle_spot()
	gary.global_basis = pallet.global_basis
	gary.call("set_fold", 1.0, 1.0, 1.0)
	var material: StandardMaterial3D = gary.get("_eye_material")
	if material != null: material.albedo_color = Color.BLACK
	var head: Node3D = gary.get("_head")
	if head != null: head.rotation.x = deg_to_rad(-35.0)

## E on GAR-Y in its cradle: you lift it out, and it wakes.
func lift_gary() -> void:
	var gary: Node3D = world.get("scout_rover")
	if not gary_in_cradle or gary == null or meeting != null: return
	gary.remove_meta("lift_out")
	gary_in_cradle = false
	_meet(gary, "pallet", gary.global_position)

func _meet(gary: Node3D, mode: String, from: Vector3) -> void:
	meeting = MEETING.new()
	add_child(meeting)
	meeting.finished.connect(_met_scene)
	meeting.start(world, gary, mode, from)

func _met_scene(mode: String) -> void:
	meeting = null
	if mode == "pallet":
		MHNotices.post("valid", "Pallet 3: GAR-Y", "GAR-Y is awake. It follows you, tows on its sled, and (hold G) takes orders.", "log")
		_met("Woke GAR-Y in the boulder field. It looked at me for a long second, then beeped as if it had been waiting all along.")
	elif mode == "field":
		var known_now: Node = world.get("known")
		if known_now != null: known_now.finish("gary_moving")
		MHNotices.post("valid", "GAR-Y", "The scout rover from pallet 3. It follows you, and (hold G) takes orders.", "log")
		_met("Found the thing that was moving: GAR-Y, the scout rover, out on its own since the storm, still doing its job. It came and bumped my boot like it had been expecting me.")
		var radio: Node = world.get("radio")
		if radio != null: radio.ring("d2_found")
	else:
		if v2(): _show_cradle(true)
		intro_pending = false
		_holding = false
		var notes: Node = world.get("notes")
		if notes != null: notes.answer("tapping")
		MHNotices.post("valid", "GAR-Y", "GAR-Y found you and dragged you home. It follows you, tows on its sled, and (hold G) takes orders.", "log")
		_met("GAR-Y found me out cold in the dust and dragged me home. It's been out here looking for the lander since the storm, and it waited at the ramp all the while I was out.")

## You blacked out before finding it: GAR-Y comes from its pallet to find
## you (scripts/suit.gd, before the rescue starts), drags you home, and waits
## at the ramp to say hello once you've come round.
func gary_finds_you() -> void:
	var site: Node = sites.get("gary")
	if site == null or world.gary_met: return
	site.empty = true
	world.meet_gary(site.pallet_spot() + Vector3(0, .2, 0))
	intro_pending = true
	_holding = false

## Waiting at the foot of the ramp: it taps on the hull now and then while
## you're inside, and says hello when you step out to it.
func _door_intro(delta: float) -> void:
	if not intro_pending or meeting != null: return
	var gary: Node3D = world.get("scout_rover")
	var lander: Node3D = world.get("lander")
	if gary == null or not is_instance_valid(gary) or lander == null: return
	var player: Node3D = world.player
	if not _holding:
		if bool(gary.get("rescuing")): return   # still dragging you home
		gary.call("begin_rescue")
		gary.set("staying", true)
		_holding = true
	var foot: Vector3 = lander.ramp_foot(DOOR_WAIT)
	gary.global_position = foot
	var to_hatch: Vector3 = lander.to_global(Vector3(0, 0, -2.7)) - foot
	gary.rotation.y = atan2(-to_hatch.x, -to_hatch.z)
	if bool(player.get_meta("ui_freeze", false)): return   # coming round
	var inside: bool = lander.cabin_contains(player.global_position) and not lander.hatch_open()
	if inside:
		_tap -= delta
		if _tap <= 0.0:
			_tap = TAP_EVERY
			MHAudio.sfx("place", -12.0, .15)
			if randf() < .5: MHAudio.sfx_at("gary_curious", gary, -14.0, .8)
			var notes: Node = world.get("notes")
			if notes != null and not notes.is_settled("tapping"): notes.think("tapping")
	elif lander.hatch_open() and player.global_position.distance_to(gary.global_position) < DOOR_REACH:
		_meet(gary, "door", gary.global_position)

func _met(how: String) -> void:
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("gary", {"how": how})
		var tools_site: Node = sites.get("tools")
		if tools_site != null and not tools_site.pallet.opened and not v2():
			notes.think("tools", "start", {"dir": direction_word(tools_site.at - world.lander.global_position)})
			var known: Node = world.get("known")
			if known != null: known.learn(tools_site.id(), "find", region_at(tools_site.at), "Beacon", "you")
	var known_now: Node = world.get("known")
	if known_now != null and sites.has("gary"): known_now.rename(sites.gary.id(), "Pallet 3 · GAR-Y's cradle")

# ---------- the field tools ----------

func got_tools() -> void:
	tools = true
	MHChapterOne.has_hammer = true
	_apply_tools()

## The headlamp: a wider, brighter, longer beam than the suit lamp.
func _apply_tools() -> void:
	MHChapterOne.has_hammer = true
	var player: Node = world.get("player")
	var lamp: SpotLight3D = player.get("flashlight") if player != null else null
	if lamp == null or lamp.has_meta("headlamp"): return
	lamp.set_meta("headlamp", true)
	lamp.light_energy *= 1.4
	lamp.spot_range *= 1.8
	lamp.spot_angle = minf(lamp.spot_angle + 10.0, 60.0)

func export_state() -> Dictionary:
	var out := {"gary_working": gary_working, "tools": tools, "chutes_seen": chutes_seen, "intro_pending": intro_pending, "gary_in_cradle": gary_in_cradle, "sites": {}, "sunset": sunset.export_state() if sunset != null else {}, "crate": crate.export_state() if crate != null and is_instance_valid(crate) else {}}
	for kind in sites: out.sites[kind] = sites[kind].export_state()
	return out
