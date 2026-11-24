extends Node

## The crew's presence in the opening (22 Nov, docs/opening-slice.md "How and
## when the crew talk"). A playtester found the slice lonely; this keeps the
## orbiter crew around without lectures:
## - reactive calls: each of the four rings once when the thing happens
##   (Kai at the stores pallet, Joseph at your first meal, Devan on the dawn
##   ride; Tamsin's is the seal call the slice already rings);
## - stall hints: if a step hasn't moved in STALL_AFTER seconds, whoever would
##   notice says what they've noticed, once (data/radio/slice/hints.txt);
## - Ask orbit (the slate's Today page): that hint whenever you want it;
## - the open channel: the crew overheard talking to each other, now and then
##   (data/radio/slice/open_channel.txt; Settings → Audio turns it off).
## Everything rides the radio (scripts/radio.gd): its queue, its danger and
## link rules, and its saved "heard" record, so nothing here needs saving.
## Only for the slice (scripts/opening_slice.gd), and only while it's guiding.

const STALL_AFTER := 180.0       # seconds a step can sit still before its hint
const AFTER_CALL := 60.0         # seconds of quiet after any call before a hint or the open channel
const REACT_AFTER := 15.0        # a reaction comes sooner: it's about what you're doing now
const STORES_NEAR := 30.0        # metres from the stores pallet for Kai's look at the kit
const OPEN_EVERY := 240.0        # seconds between open-channel snippets
## The steps with a hint, in hints.txt as hint_<id>.
const HINTED := ["gary_met", "pallets", "hitched", "walker_awake", "walker_fixed", "walker_home", "core_down", "kit_placed", "quarters",
	"sled_home", "printer_in", "connector", "sled_built", "sled_fitted", "ready"]   # chunk 3: Ask only, no stall hints (the free stretch)
## Steps where the hint only makes sense out on the surface.
const OUTDOOR := ["gary_met", "pallets", "hitched", "walker_awake", "walker_fixed", "walker_home", "core_down"]

var world: Node
var radio: Node
var opening: Node
var _since_call := AFTER_CALL    # counts up once the radio's quiet
var _since_open := 0.0           # the first snippet waits a full gap too
var _step := ""                  # the step the hint clock is on
var _stalled := 0.0
var _meals_at_start := 0
var _nothing := 0                # which "nothing from us" Ask orbit says next
var _check := 0.0

func setup(target_world: Node) -> void:
	world = target_world
	name = "CrewPresence"
	add_to_group("crew_presence")
	radio = world.get("radio")
	opening = world.get("opening_days")
	var body: Node = world.get("body")
	_meals_at_start = int(body.get("meals")) if body != null else 0
	if radio != null:
		radio.facts["ate"] = func(_args: Array) -> bool: return _ate()

func _live() -> bool:
	return radio != null and opening != null and is_instance_valid(opening) and bool(opening.guided())

## Chunk 3's free stretch: Ask orbit still answers, nothing else runs.
func _free() -> bool:
	return radio != null and opening != null and is_instance_valid(opening) and opening.has_method("free_stretch") and bool(opening.free_stretch())

func _ate() -> bool:
	var body: Node = world.get("body")
	return body != null and int(body.get("meals")) > _meals_at_start

# ---------- the tick ----------

func _process(delta: float) -> void:
	if world == null or get_tree().paused or not _live(): return
	if bool(radio.on_air()) or not (radio.queue as Array).is_empty(): _since_call = 0.0
	else: _since_call += delta
	_since_open += delta
	_stall_clock(delta)
	_check -= delta
	if _check > 0.0: return
	_check = .5
	_reactions()
	_stall_hint()
	_open_channel()

## Free to speak: nothing on air or queued, and `gap` seconds since the last call.
func _quiet(gap := AFTER_CALL) -> bool:
	return _since_call >= gap and bool(radio.in_contact()) and not _asleep()

func _asleep() -> bool:
	var sleep: Node = world.get("sleep")
	return sleep != null and bool(sleep.get("asleep"))

# ---------- reactive calls ----------

func _reactions() -> void:
	if not _quiet(REACT_AFTER): return
	var drop: Node = world.get("storm_drop")
	if drop != null and drop.get("pallet") != null and bool(drop.pallet.opened) and _near(drop.pallet, STORES_NEAR): _react("s1_stores")
	if _ate() and int(opening.get("nights")) < 2: _react("s1_ate")
	var walker: Node = world.get("walker")
	if walker != null and bool(walker.get("riding")) and int(opening.get("nights")) >= 1 and not bool(opening.done("core_down")): _react("s2_ride")

func _react(section: String) -> void:
	if (radio.heard as Dictionary).has(section) or not bool(radio.has_section(section)): return
	radio.ring(section)
	_since_call = 0.0

# ---------- stall hints ----------

## The step you're on: the first hinted beat not yet done, or "".
func current_step() -> String:
	var beats: Array = opening.BEATS
	if opening.has_method("free_stretch") and bool(opening.free_stretch()): beats = opening.FREE_BEATS
	for beat in beats:
		var id := str(beat[0])
		if bool(opening.done(id)): continue
		return id if HINTED.has(id) else ""
	return ""

func _stall_clock(delta: float) -> void:
	var step := current_step()
	if step != _step:
		_step = step
		_stalled = 0.0
	if step.is_empty() or _asleep() or not bool(radio.in_contact()): return
	if OUTDOOR.has(step) and not _outside(): return
	_stalled += delta

func _stall_hint() -> void:
	if _step.is_empty() or _stalled < STALL_AFTER or not _quiet() or not _hint_fits(_step): return
	var section := "hint_" + _step
	if (radio.heard as Dictionary).has(section): return
	radio.ring(section)
	_since_call = 0.0

## Daylight for the outdoor ones; "bring it home" only late in the day.
func _hint_fits(step: String) -> bool:
	if OUTDOOR.has(step) and MHGame.sunlight_fraction < .1: return false
	if step == "walker_home":
		var cycle: Dictionary = MHGame.site().get("day_cycle", {})
		return MHGame.sol_hour >= float(cycle.get("sunset_hour", 19.0)) - 3.0
	return true

# ---------- Ask orbit ----------

## The slate's Ask orbit: the hint for where you are (again, if you've had
## it), or a "nothing from us". False if nobody can answer now.
func ask() -> bool:
	if radio == null or bool(radio.on_air()) or not bool(radio.in_contact()): return false
	var step := current_step() if _live() or _free() else ""
	var section := "hint_" + step
	if step.is_empty() or not bool(radio.has_section(section)):
		_nothing += 1
		section = "ask_nothing_%d" % (1 + (_nothing - 1) % 3)
	(radio.heard as Dictionary).erase(section)   # asked for: it can come again
	(radio.queue as Array).erase(section)
	(radio.queue as Array).push_front(section)
	_since_call = 0.0
	return true

# ---------- the open channel ----------

func _open_channel() -> void:
	if not bool(MHGame.setting("open_channel")): return
	if _since_open < OPEN_EVERY or not _quiet(): return
	if not (_outside() or _in_cabin()): return
	for n in range(1, 7):
		var section := "oc_%d" % n
		if (radio.heard as Dictionary).has(section): continue
		match _open_fits(n):
			"now":
				radio.ring(section)
				_since_open = 0.0
				_since_call = 0.0
			"missed":
				radio.heard[section] = true   # its moment's gone: let it go
				continue
		return

## "now", "wait" or "missed" for snippet n.
func _open_fits(n: int) -> String:
	var nights := int(opening.get("nights"))
	var hour := MHGame.sol_hour
	match n:
		1, 2: return ("now" if bool(opening.done("gary_met")) else "wait") if nights < 1 else "missed"
		3: return ("now" if hour >= 12.0 and not bool(opening.done("walker_home")) else "wait") if nights < 1 else "missed"
		4: return ("now" if _in_cabin() and bool(opening.done("walker_home")) else "wait") if nights < 1 else "missed"
		5: return "wait" if nights < 1 else ("now" if hour < 12.0 else "missed")
		6: return "now" if nights >= 1 else "wait"
	return "missed"

func _outside() -> bool:
	var suit: Node = world.get("suit")
	return suit != null and str(suit.get("where")) == "outside"

func _in_cabin() -> bool:
	var lander: Node = world.get("lander")
	var me: Node3D = world.get("player")
	return lander != null and me != null and bool(lander.cabin_contains(me.global_position))

func _near(thing: Variant, metres: float) -> bool:
	var me: Node3D = world.get("player")
	if me == null or not (thing is Node3D) or not is_instance_valid(thing) or not (thing as Node3D).is_inside_tree(): return false
	var at: Vector3 = (thing as Node3D).global_position
	return Vector2(at.x - me.global_position.x, at.z - me.global_position.z).length() <= metres
