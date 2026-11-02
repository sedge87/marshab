extends Node

## Mission Control on the radio from Earth: a room of people on a weekly rota,
## each with a story you overhear a piece at a time (the canon is
## docs/mission-control-voice.md; who they are is data/mc_cast.json, what
## they say is data/mc_threads.json). Not alerts (the habitat handles those:
## Earth is too far away to help in the moment) but their own lives, replies
## to what you've done, and small talk.
##
## Earth time: a sol is 39 minutes longer than an Earth day, so the Earth
## clock runs a little faster than the sol and drifts round it. Landing is
## Monday 09:00 Houston. Each Earth day has a day shift (08:00-20:00) and a
## night shift, and the rota says who's on console. A person's story moves on
## one beat at a time, only on their own shifts. At most one beat a shift.
##
## Light takes 3 to 22 minutes to cross between Mars and Earth, depending on
## where the two planets are in their orbits (they line up every 26 months).
## Everything they send takes that long; a reply to something you did takes
## the round trip and a few minutes to write. During a solar conjunction
## blackout (habitat_life.gd) nothing gets through until contact comes back.
##
## You never miss anything: a message that arrives while you're asleep, with
## the game paused, with the rover's radio off, or with the Mission Control
## setting on "Log only" is held, then played at the next good moment (or just
## logged). Everything said is kept in the Messages log (Mission Control's
## screen). Small talk is paced by the setting (Quiet, Normal, Chatty); story
## beats always come. All of it is saved with the colony.

const CAST_FILE := "res://data/mc_cast.json"
const THREADS_FILE := "res://data/mc_threads.json"
const SYNODIC_SOLS := 759.0     # 780 Earth days between closest approaches
const ONE_WAY_MIN := 3.0        # light minutes at the closest
const ONE_WAY_MAX := 22.3       # and the farthest (Sun in between)
const PHASE_SOLS := 120.0       # the colony lands a few months after a close approach
const REPLY_MINUTES := 6.0      # time for someone on Earth to answer
const LIGHT_KM_PER_MIN := 17987547.0
const EARTH_PER_HOUR := 88775.0 / 86400.0   # Earth hours in a game hour (a sol is 24 h 39 m 35 s)
const CHATTER_SOLS := {"quiet": 2.0, "normal": 1.0, "chatty": 0.5}   # sols between bits of small talk
const GAP_SECONDS := 25.0       # real seconds between two messages played
const FAR_DRIVE := 3000.0       # m from home: the rover's first long drive
const NO_SLEEP_HOURS := 30.0
const LEVELS := ["log", "quiet", "normal", "chatty"]

static var _cast: Dictionary = {}
static var _threads: Dictionary = {}

var world: Node
## How many game hours the link has been running (its own clock, so it keeps
## time in Creative too, where the simulation is off).
var hours := 0.0
var said: Dictionary = {}       # one-off events already answered -> true
var events: Dictionary = {}     # event -> game hours it last happened
var progress: Dictionary = {}   # thread id -> {next, shifts}
var chatter_next: Dictionary = {}   # person -> index of their next small talk
var messages: Array = []        # the Messages log: {id, speaker, text, hours, earth, note, heard}
var unread := 0
var _pending: Array = []        # in flight: {line, arrive, one_way}
var _held: Array = []           # arrived, waiting for you to hear them: {line, note, arrived_earth, missed}
var _shift := -1                # the shift whose beats have been counted
var _beat_this_shift := false
var _next_chatter := 18.0
var _gap := 0.0
var _check := 0.0
var _last_sol_hour := -1.0
var _was_storm := false
var _was_blackout := false
var _seen_alerts := 0
var _last_sleep := 0.0
var _outside_trip := false

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("mission_control_link")

static func cast() -> Dictionary:
	if _cast.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAST_FILE))
		if parsed is Dictionary: _cast = parsed
	return _cast

static func threads() -> Dictionary:
	if _threads.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(THREADS_FILE))
		if parsed is Dictionary: _threads = parsed
	return _threads

static func person(id: String) -> Dictionary:
	return (cast().get("people", {}) as Dictionary).get(id, {})

## One-way light time to Earth, in minutes, on a given sol.
static func one_way_minutes(sol: float) -> float:
	var mid := (ONE_WAY_MAX + ONE_WAY_MIN) * .5
	var swing := (ONE_WAY_MAX - ONE_WAY_MIN) * .5
	return mid - swing * cos(TAU * (sol + PHASE_SOLS) / SYNODIC_SOLS)

# ---------- Earth time and the rota ----------

## Hours since the start of landing week (Monday 00:00 Houston) at a given
## game hour of the link.
static func earth_at(game_hours: float) -> float:
	var start: Dictionary = cast().get("earth_start", {})
	return float(start.get("weekday", 0)) * 24.0 + float(start.get("hour", 9.0)) + game_hours * EARTH_PER_HOUR

## The shift running at an Earth time: 0 is landing Monday's day shift, then
## night, then Tuesday's day shift... (negative before Monday 08:00).
static func shift_at(earth: float) -> int:
	return floori((earth - float(cast().get("shifts", {}).get("day_starts", 8.0))) / 12.0)

## Who's on console for a shift.
static func on_console(shift: int) -> String:
	var rota: Dictionary = cast().get("rota", {})
	var day := floori(shift / 2.0)
	var list: Array = rota.get("night" if posmod(shift, 2) == 1 else "day", [])
	return str(list[posmod(day, list.size())]) if not list.is_empty() else ""

func earth() -> float:
	return earth_at(hours)

## "THU 14:20"
static func earth_clock(at: float) -> String:
	var days: Array = cast().get("weekdays", ["Monday"])
	var hour := fmod(at, 24.0)
	return "%s %02d:%02d" % [str(days[posmod(floori(at / 24.0), days.size())]).substr(0, 3).to_upper(), int(hour), int(fmod(hour, 1.0) * 60.0)]

## The rota card: "EARTH THU 14:20 HOUSTON · ON CONSOLE THEO · NEXT NOOR".
func rota_line() -> String:
	var shift := shift_at(earth())
	var now := str(person(on_console(shift)).get("short", "")).to_upper()
	var next := str(person(on_console(shift + 1)).get("short", "")).to_upper()
	return "EARTH %s HOUSTON  ·  ON CONSOLE %s  ·  NEXT %s" % [earth_clock(earth()), now, next]

# ---------- the clock ----------

func _sim() -> RefCounted:
	return world.builder.simulation() if world != null and world.builder != null else null

func _process(delta: float) -> void:
	if get_tree().paused: return
	_gap -= delta
	_release()
	_check -= delta
	if _check > 0.0: return
	_check = 1.0
	_tick_clock()
	_listen()
	_story()
	_chatter()
	_deliver()

## Game hours from the sol clock (so it runs in every mode, and through sleep).
func _tick_clock() -> void:
	var now := MHGame.sol_hour
	if _last_sol_hour >= 0.0: hours += wrapf(now - _last_sol_hour, 0.0, 24.0)
	_last_sol_hour = now

# ---------- what happened ----------

## Something happened (a system telling us, or our own checks below).
## Returns whether it was news (a one-off not already answered, or a repeat
## after its quiet time).
func notify(event: String, again_after_hours := INF) -> bool:
	var last := float(events.get(event, -INF))
	if is_inf(again_after_hours) and said.has(event): return false
	if hours - last < again_after_hours: return false
	events[event] = hours
	said[event] = true
	_react(event)
	return true

func _listen() -> void:
	var s := _sim()
	# An older save, already well under way: don't replay the early news.
	if said.is_empty() and hours > 24.0:
		for id in ["landed", "first_room", "sol_10", "sol_30", "sol_100", "sol_669"]:
			if not id.begins_with("sol_") or floori(hours / 24.0) + 1 >= int(id.trim_prefix("sol_")): said[id] = true
	notify("landed")
	if world.builder != null:
		var zones: Array = world.builder.zones
		if zones.any(func(z): return str(z.kind) == "airlock") and zones.any(func(z): return not str(z.kind) in ["corridor", "airlock", "vehicle_bay"]):
			notify("first_room")
	if s != null and MHGame.simulation_on():
		var storm := float(s.storm_hours_left) > 0.0
		if _was_storm and not storm: notify("storm_after", 0.0)
		_was_storm = storm
		var alerts: Node = world.get("alerts")
		if alerts != null:
			var history: Array = alerts.history
			for i in range(_seen_alerts, history.size()):
				if str(history[i].level) == "critical": notify("critical_after", 48.0)
			_seen_alerts = history.size()
		var food = s.get("food")
		if food != null:
			if not (food.trays as Dictionary).is_empty(): notify("first_planting")
			if not (food.harvested as Dictionary).is_empty(): notify("first_harvest")
	var blackout := _blackout()
	if _was_blackout and not blackout: notify("blackout_after", 0.0)
	_was_blackout = blackout
	var sol := floori(hours / 24.0) + 1
	for milestone in [10, 30, 100, 669]:
		if sol >= milestone: notify("sol_%d" % milestone)
	var rover: Node3D = world.get("crew_rover")
	if rover != null and rover.has_method("_home") and not rover.call("_home").is_empty():
		var home: Vector2 = rover.call("_home").centre
		if Vector2(rover.global_position.x, rover.global_position.z).distance_to(home) > FAR_DRIVE: notify("far_drive")
	var suit: Node = world.get("suit")
	if suit != null and preload("res://scripts/suit.gd").active():
		var outside := str(suit.where) == "outside"
		if outside and not _outside_trip and float(suit.turn_back_hours()) <= 0.0:
			_outside_trip = true
			notify("walkback_breach", 24.0)
		if not outside: _outside_trip = false
	if MHSamples.on() and not MHSamples.found.is_empty(): notify("first_discovery")
	var sleep: Node = world.get("sleep")
	if sleep != null and bool(sleep.asleep): _last_sleep = hours
	if hours - _last_sleep > NO_SLEEP_HOURS: notify("no_sleep", 48.0)

func _blackout() -> bool:
	var s := _sim()
	if s == null or s.get("life") == null or not MHGame.simulation_on(): return false
	return float(s.life.blackout_hours_left) > 0.0

## Whoever's on console answers (lines marked always come first, whoever is on).
func _react(event: String) -> void:
	var lines: Array = (threads().get("reactions", {}) as Dictionary).get(event, [])
	if lines.is_empty(): return
	var here := on_console(shift_at(earth()))
	var chosen: Array = lines.filter(func(l): return bool(l.get("always", false)))
	var theirs: Array = lines.filter(func(l): return not bool(l.get("always", false)) and str(l.speaker) == here)
	if theirs.is_empty(): theirs = lines.filter(func(l): return not bool(l.get("always", false))).slice(0, 1)
	for line in chosen + theirs: send(line, true)

# ---------- stories ----------

## On each shift, the person on console may move their story on one beat.
func _story() -> void:
	var shift := shift_at(earth())
	if shift < 0: return
	var who := on_console(shift)
	if shift != _shift:
		_shift = shift
		_beat_this_shift = false
		var state: Dictionary = progress.get(who, {"next": 0, "shifts": 0})
		state.shifts = int(state.shifts) + 1
		progress[who] = state
	if _beat_this_shift or _blackout(): return
	var beat := next_beat(who)
	if beat.is_empty(): return
	var when: Dictionary = beat.get("when", {})
	var state: Dictionary = progress[who]
	if int(state.shifts) < int(when.get("shifts", 1)): return
	if when.has("event") and not events.has(str(when.event)): return
	if floori(hours / 24.0) + 1 < int(when.get("sol_min", 0)): return
	_beat_this_shift = true
	state.next = int(state.next) + 1
	state.shifts = 0
	send(beat)

## The next beat of a person's story, or {} when they've told it all (so far).
func next_beat(who: String) -> Dictionary:
	var thread: Dictionary = (threads().get("threads", {}) as Dictionary).get(who, {})
	var beats: Array = thread.get("beats", [])
	var i := int((progress.get(who, {}) as Dictionary).get("next", 0))
	return beats[i] if i < beats.size() else {}

# ---------- small talk ----------

## The Mission Control setting: "log", "quiet", "normal" or "chatty".
static func level() -> String:
	var value := str(MHGame.setting("mc_chatter"))
	return value if value in LEVELS else "normal"

func _chatter() -> void:
	if hours < _next_chatter or _blackout(): return
	var level := level()
	_next_chatter = hours + 24.0 * float(CHATTER_SOLS.get(level, 1.0)) * randf_range(.8, 1.25)
	var line := next_chatter(on_console(shift_at(earth())), false)
	if not line.is_empty(): send(line)

## The next bit of a person's small talk (drive: only the rover-radio kind).
func next_chatter(who: String, drive: bool) -> Dictionary:
	var pool: Array = ((threads().get("chatter", {}) as Dictionary).get(who, []) as Array).filter(func(l): return ("drive" in (l.get("tags", []) as Array)) == drive)
	if pool.is_empty(): return {}
	var key := who + ("/drive" if drive else "")
	var i := int(chatter_next.get(key, 0))
	chatter_next[key] = i + 1
	var line: Dictionary = pool[i % pool.size()].duplicate()
	line["speaker"] = who
	return line

# ---------- sending and hearing ----------

## Sent from Earth: it arrives after the light delay (a reply to something
## you did also waits the round trip and the time to write it).
func send(line: Dictionary, reply := false) -> void:
	var one_way := one_way_minutes(hours / 24.0)
	var travel := (one_way * 2.0 + REPLY_MINUTES if reply else one_way) / 60.0 / EARTH_PER_HOUR
	_pending.append({"line": line, "arrive": hours + travel + _pending.size() * .01, "one_way": one_way})

## What's arrived goes to the held list (nothing gets through a blackout).
func _deliver() -> void:
	if _blackout(): return
	for message in _pending.duplicate():
		if float(message.arrive) > hours: continue
		_pending.erase(message)
		var minutes := float(message.one_way)
		_arrive(message.line, "sent %d min ago · Earth is %d million km away" % [roundi(minutes), roundi(minutes * LIGHT_KM_PER_MIN / 1000000.0)])

func _arrive(line: Dictionary, note: String) -> void:
	_held.append({"line": line, "note": note, "arrived_earth": earth(), "missed": not can_hear()})
	messages.append({"id": str(line.id), "speaker": str(line.speaker), "text": str(line.text), "hours": hours, "earth": earth(), "note": note, "heard": false})
	MHNotices.post("info", "Message from %s" % str(person(str(line.speaker)).get("name", "Mission Control")), str(line.text), "comms")
	if level() == "log":
		unread += 1
		messages[messages.size() - 1].heard = true
		_held.pop_back()

## Whether you can hear the radio now: awake, the game running, the voice
## free, the rover's radio on if you're driving, and not "Log only".
func can_hear() -> bool:
	if get_tree().paused or level() == "log": return false
	var sleep: Node = world.get("sleep") if world != null else null
	if sleep != null and bool(sleep.asleep): return false
	var rover: Node = world.get("crew_rover") if world != null else null
	if rover != null and bool(rover.get("driving")) and not bool(rover.get("radio_on")): return false
	return true

## One held message at a time, a little apart, when you can hear it.
func _release() -> void:
	if _held.is_empty() or _gap > 0.0 or not can_hear() or MHAudio.voice_busy(): return
	_play(_held.pop_front())

func _play(held: Dictionary) -> void:
	_gap = GAP_SECONDS
	var line: Dictionary = held.line
	var note := str(held.note)
	if bool(held.get("missed", false)):
		var hour := fmod(float(held.arrived_earth), 24.0)
		note = "left at %02d:%02d Houston while you were away" % [int(hour), int(fmod(hour, 1.0) * 60.0)]
	var who := person(str(line.speaker))
	MHAudio.cast_line(str(line.id), "%s · %s" % [str(who.get("name", "Mission Control")), str(who.get("role", ""))], str(line.text), note)
	if bool(line.get("then_habitat", false)): MHAudio.voice("aside")
	for entry in messages:
		if str(entry.id) == str(line.id) and not bool(entry.heard): entry.heard = true

## The rover radio on a relay pass: anything held comes through now; if
## nothing is, a word from whoever's on console. Returns whether it said
## something (scripts/rover_radio.gd).
func relay_pass(orbiter: String) -> bool:
	if _blackout(): return false
	if _held.is_empty():
		var line := next_chatter(on_console(shift_at(earth())), true)
		if line.is_empty(): return false
		var minutes := one_way_minutes(hours / 24.0)
		_arrive(line, "sent %d min ago · via %s" % [roundi(minutes), orbiter])
	_gap = 0.0
	return true

## Mission Control's screen opened the log: nothing unread.
func mark_read() -> void:
	unread = 0

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"hours": hours, "said": said.duplicate(), "events": events.duplicate(), "progress": progress.duplicate(true), "chatter_next": chatter_next.duplicate(),
		"messages": messages.duplicate(true), "unread": unread, "pending": _pending.duplicate(true), "held": _held.duplicate(true), "shift": _shift, "beat_this_shift": _beat_this_shift,
		"next_chatter": _next_chatter, "last_sleep": _last_sleep}

func restore_state(state: Dictionary) -> void:
	said = (state.get("said", {}) as Dictionary).duplicate()
	if said.has("hello"): said["landed"] = true   # saves from before the cast
	events = (state.get("events", {}) as Dictionary).duplicate()
	progress = (state.get("progress", {}) as Dictionary).duplicate(true)
	chatter_next = (state.get("chatter_next", {}) as Dictionary).duplicate()
	messages = (state.get("messages", []) as Array).duplicate(true)
	unread = int(state.get("unread", 0))
	_held = (state.get("held", []) as Array).duplicate(true)
	_pending = (state.get("pending", []) as Array).filter(func(p): return p.has("line")).duplicate(true)
	_shift = int(state.get("shift", -1))
	_beat_this_shift = bool(state.get("beat_this_shift", false))
	_next_chatter = float(state.get("next_chatter", _next_chatter))
	_last_sleep = float(state.get("last_sleep", 0.0))
	var sim := _sim()
	hours = float(state.get("hours", float(sim.hours_run) if sim != null else 0.0))
