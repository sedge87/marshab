extends Node

## Mission Control on the radio from Earth. Not alerts (the habitat handles
## those: Earth is too far away to help in the moment) but replies, praise and
## tips, each arriving after the real light delay.
##
## Light takes 3 to 22 minutes to cross between Mars and Earth, depending on
## where the two planets are in their orbits (they line up every 26 months).
## So when something happens here, Earth hears about it a few minutes later,
## takes a few minutes to reply, and the reply takes the same time to come
## back. The caption says how long ago it was sent and how far away Earth is.
## During a solar conjunction blackout (habitat_life.gd) messages wait until
## contact comes back. What's been said is saved with the colony, so the
## welcome isn't repeated after a load.

const SYNODIC_SOLS := 759.0     # 780 Earth days between closest approaches
const ONE_WAY_MIN := 3.0        # light minutes at the closest
const ONE_WAY_MAX := 22.3       # and the farthest (Sun in between)
const PHASE_SOLS := 120.0       # the colony lands a few months after a close approach
const REPLY_MINUTES := 6.0      # time for someone on Earth to answer
const LIGHT_KM_PER_MIN := 17987547.0
const TIP_EVERY_HOURS := 72.0

var world: Node
var said: Dictionary = {}       # message id -> true (one-off messages)
var _pending: Array = []        # {id, arrive (sim hours), one_way (minutes)}
var _check := 0.0
var _was_storm := false
var _was_blackout := false
var _seen_alerts := 0
var _last_critical_reply := -999.0
var _next_tip := TIP_EVERY_HOURS

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("mission_control_link")

## One-way light time to Earth, in minutes, on a given sol.
static func one_way_minutes(sol: float) -> float:
	var mid := (ONE_WAY_MAX + ONE_WAY_MIN) * .5
	var swing := (ONE_WAY_MAX - ONE_WAY_MIN) * .5
	return mid - swing * cos(TAU * (sol + PHASE_SOLS) / SYNODIC_SOLS)

func _sim() -> RefCounted:
	return world.builder.simulation() if world != null and world.builder != null else null

func _hours() -> float:
	var s := _sim()
	return float(s.hours_run) if s != null else 0.0

## Something happened: Earth hears it after the delay, replies, and the reply
## takes the same time back.
func send(id: String) -> void:
	var one_way := one_way_minutes(_hours() / 24.0)
	_pending.append({"id": id, "arrive": _hours() + (one_way * 2.0 + REPLY_MINUTES) / 60.0, "one_way": one_way})

func _once(id: String) -> void:
	if said.has(id): return
	said[id] = true
	send(id)

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0: return
	_check = 1.0
	var s := _sim()
	if s == null or get_tree().paused or not MHGame.simulation_on(): return
	_listen(s)
	_deliver(s)

## What Earth would want to answer.
func _listen(s: RefCounted) -> void:
	var now := float(s.hours_run)
	# An older save, already well under way: don't replay the early messages.
	if said.is_empty() and now > 24.0:
		for id in ["hello", "first_room", "sol_10", "sol_30", "sol_100", "sol_669"]:
			if not id.begins_with("sol_") or floori(now / 24.0) + 1 >= int(id.trim_prefix("sol_")): said[id] = true
	_once("hello")
	var zones: Array = world.builder.zones
	if zones.any(func(z): return str(z.kind) == "airlock") and zones.any(func(z): return not str(z.kind) in ["corridor", "airlock", "vehicle_bay"]):
		_once("first_room")
	var storm := float(s.storm_hours_left) > 0.0
	if _was_storm and not storm: send("storm_after")
	_was_storm = storm
	var blackout := float(s.life.blackout_hours_left) > 0.0 if s.get("life") != null else false
	if _was_blackout and not blackout: send("blackout_after")
	_was_blackout = blackout
	# A critical alert: one reply at most every two sols.
	var alerts: Node = world.get("alerts")
	if alerts != null:
		var history: Array = alerts.history
		for i in range(_seen_alerts, history.size()):
			if str(history[i].level) == "critical" and now - _last_critical_reply > 48.0:
				_last_critical_reply = now
				send("critical_after")
		_seen_alerts = history.size()
	var sol := floori(now / 24.0) + 1
	for milestone in [10, 30, 100, 669]:
		if sol >= milestone: _once("sol_%d" % milestone)
	if now >= _next_tip:
		_next_tip = now + TIP_EVERY_HOURS * randf_range(.8, 1.3)
		send("tip")

## Messages whose time has come, unless the Sun is in the way.
func _deliver(s: RefCounted) -> void:
	if _was_blackout or _pending.is_empty(): return
	var now := float(s.hours_run)
	for message in _pending.duplicate():
		if float(message.arrive) > now: continue
		_pending.erase(message)
		var minutes := float(message.one_way)
		MHAudio.radio(str(message.id), "sent %d min ago · Earth is %d million km away" % [roundi(minutes), roundi(minutes * LIGHT_KM_PER_MIN / 1000000.0)])
		return   # one at a time; the next waits for the next check

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"said": said.duplicate(), "pending": _pending.duplicate(true), "next_tip": _next_tip}

func restore_state(state: Dictionary) -> void:
	said = (state.get("said", {}) as Dictionary).duplicate()
	_pending = (state.get("pending", []) as Array).duplicate(true)
	_next_tip = float(state.get("next_tip", _next_tip))
