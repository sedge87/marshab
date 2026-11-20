extends Node

## The radio: Castellanos and you (docs/radio.md). Calls are written in plain
## text in data/radio/*.txt, one file per guided day plus radio.txt, so the
## lines can be edited without touching code:
##
##   # a comment
##   ~ section_name                       a call (or part of one) starts here
##   Castellanos: What they say. [ID:d1_x] a spoken line; the ID names its voice file,
##                                        res://assets/audio/voice/orb_<ID>.wav
##   - What you could say                 2-3 replies in a row; the lines indented
##   	Castellanos: Their answer. [ID:..]  under one play only if you pick it
##   do cue_name arg arg                  a cue in code (scripts/opening_days.gd
##                                        registers them: move GAR-Y, the sun...)
##   wait cue_name arg                    wait until a check in code is true
##   set flag_name                        remember something about you
##   ? flag_name Castellanos: ...         a line that plays only if the flag is set
##   ?! flag_name Castellanos: ...        ... or only if it isn't
##   => other_section                     jump on to another section
##   => END                               the call ends
##   hold                                 the next replies wait for you, no timer;
##   nudge Castellanos: ... [ID:x]        and while you're quiet, these are said
##                                        (one every NUDGE_EVERY seconds)
##
## Calls queue and never interrupt danger: they wait while your suit's in
## trouble, you're out cold or a storm is on you. They also wait while the
## crew's ship is behind Mars (its one-sol orbit takes it round the far side
## at the same hour every sol: in_contact()), or you're down a cave. Each section plays once,
## unless it's a topic you raise yourself (Call orbit on the slate).
## Your replies are written, never spoken (scripts/replies.gd shows them).

signal call_finished(section: String)
signal cue(name: String, args: Array)

const FOLDER := "res://data/radio/"
const WHO := "Castellanos"
const REPLY_SECONDS := 8.0       # 21 Nov: 20 s kept her on air too long
const GAP_AFTER_LINE := .5
const NUDGE_EVERY := 18.0

var world: Node
var flags: Dictionary = {}       # flag -> true
var heard: Dictionary = {}       # section -> true
var topics: Array = []           # sections you can raise with Call orbit
var queue: Array = []            # sections waiting to play
var playing := ""                # the section on air now
var fast := false                # tests: no waiting on voices
var checks: Dictionary = {}      # wait name -> Callable(args) -> bool
var handlers: Dictionary = {}    # cue name -> Callable(args)
var _sections: Dictionary = {}   # name -> Array of steps
var _choice := -2                # the reply picked (-1 silence, -2 waiting)

static var _parsed: Dictionary = {}

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "Radio"
	add_to_group("radio")
	for key in (saved.get("flags", {}) as Dictionary): flags[str(key)] = true
	for key in (saved.get("heard", {}) as Dictionary): heard[str(key)] = true
	for t in saved.get("topics", []): topics.append(str(t))
	for q in saved.get("queue", []): queue.append(str(q))
	var cut := str(saved.get("playing", ""))
	if not cut.is_empty():   # a call cut off by a save plays again, from the top (its cues are safe to run twice)
		heard.erase(cut)
		if not queue.has(cut): queue.push_front(cut)
	_sections = sections()

func export_state() -> Dictionary:
	return {"flags": flags.duplicate(), "heard": heard.duplicate(), "topics": topics.duplicate(), "queue": queue.duplicate(), "playing": playing}

# ---------- the scripts ----------

## Every section in every file under data/radio/.
static func sections() -> Dictionary:
	if not _parsed.is_empty(): return _parsed
	var dir := DirAccess.open(FOLDER)
	if dir == null: return _parsed
	var files: Array = []
	for f in dir.get_files():
		var file := str(f).trim_suffix(".remap")
		if file.ends_with(".txt") and not files.has(file): files.append(file)
	files.sort()
	for file in files: parse_into(_parsed, FileAccess.get_file_as_string(FOLDER + str(file)))
	return _parsed

## Parses one script's text into `out` (section name -> steps).
static func parse_into(out: Dictionary, text: String) -> void:
	var rows: Array = []   # [indent, text]
	for raw in text.split("\n"):
		var line := str(raw).replace("\r", "")
		var body := line.strip_edges()
		if body.is_empty() or body.begins_with("#"): continue
		var indent := 0
		for ch in line:
			if ch == "\t": indent += 4
			elif ch == " ": indent += 1
			else: break
		rows.append([indent, body])
	var i := 0
	while i < rows.size():
		var body := str(rows[i][1])
		if body.begins_with("~"):
			var section := body.substr(1).strip_edges()
			i += 1
			var start := i
			while i < rows.size() and not str(rows[i][1]).begins_with("~"): i += 1
			out[section] = _steps(rows.slice(start, i))
		else: i += 1

static func _steps(rows: Array) -> Array:
	var steps: Array = []
	if rows.is_empty(): return steps
	var base := int(rows[0][0])
	var i := 0
	var hold := false
	var nudges: Array = []
	while i < rows.size():
		var indent := int(rows[i][0])
		var body := str(rows[i][1])
		if indent > base:
			i += 1   # stray indentation: skip it
			continue
		if body.begins_with("- "):
			var choice := {"type": "choice", "options": []}
			while i < rows.size() and int(rows[i][0]) == base and str(rows[i][1]).begins_with("- "):
				var option := {"text": str(rows[i][1]).substr(2).strip_edges(), "steps": []}
				i += 1
				var start := i
				while i < rows.size() and int(rows[i][0]) > base: i += 1
				option.steps = _steps(rows.slice(start, i))
				choice.options.append(option)
			if hold:
				choice["hold"] = true
				choice["nudges"] = nudges
				hold = false
				nudges = []
			steps.append(choice)
			continue
		if body == "hold":
			hold = true
			i += 1
			continue
		if body.begins_with("nudge "):
			nudges.append(_step(body.substr(6).strip_edges()))
			i += 1
			continue
		steps.append(_step(body))
		i += 1
	return steps

static func _step(body: String) -> Dictionary:
	var cond := ""
	var negate := false
	if body.begins_with("?"):
		negate = body.begins_with("?!")
		var rest := body.substr(2 if negate else 1).strip_edges()
		var space := rest.find(" ")
		cond = rest.substr(0, space) if space > 0 else rest
		body = rest.substr(space + 1).strip_edges() if space > 0 else ""
	var step := {}
	if body.begins_with("=>"): step = {"type": "goto", "to": body.substr(2).strip_edges()}
	elif body.begins_with("do "): step = {"type": "do", "args": Array(body.substr(3).strip_edges().split(" ", false))}
	elif body.begins_with("wait "): step = {"type": "wait", "args": Array(body.substr(5).strip_edges().split(" ", false))}
	elif body.begins_with("set "): step = {"type": "set", "flag": body.substr(4).strip_edges()}
	else:
		var colon := body.find(":")
		var who := body.substr(0, colon).strip_edges() if colon > 0 else WHO
		var said := body.substr(colon + 1).strip_edges() if colon > 0 else body
		var id := ""
		var tag := said.rfind("[ID:")
		if tag >= 0:
			id = said.substr(tag + 4).trim_suffix("]").strip_edges()
			said = said.substr(0, tag).strip_edges()
		step = {"type": "line", "who": who, "text": said, "id": id}
	if not cond.is_empty():
		step["if"] = cond
		step["not"] = negate
	return step

## Every spoken line's [ID, who, text], for the voice generator and tests.
static func all_lines() -> Array:
	var out: Array = []
	for section in sections(): _collect(sections()[section], out)
	return out

static func _collect(steps: Array, out: Array) -> void:
	for step in steps:
		if str(step.type) == "line" and not str(step.id).is_empty(): out.append([str(step.id), str(step.who), str(step.text)])
		elif str(step.type) == "choice":
			_collect(step.get("nudges", []), out)
			for option in step.options: _collect(option.steps, out)

# ---------- calls ----------

func has_section(section: String) -> bool:
	return _sections.has(section)

## Castellanos calls about `section` (once only).
func ring(section: String) -> void:
	if not _sections.has(section) or heard.has(section) or queue.has(section) or playing == section: return
	queue.append(section)

## A call about your safety (Castle watching your air): it comes even when
## you're in danger, first in line, and can come again.
var _urgent := {}
func ring_urgent(section: String) -> void:
	if not _sections.has(section) or playing == section: return
	heard.erase(section)
	queue.erase(section)
	queue.push_front(section)
	_urgent[section] = true

## Something new you could raise yourself with Call orbit.
func add_topic(section: String) -> void:
	if _sections.has(section) and not heard.has(section) and not topics.has(section): topics.append(section)

## Call orbit: raise the oldest topic waiting.
func call_orbit() -> bool:
	if topics.is_empty() or not playing.is_empty(): return false
	var section := str(topics.pop_front())
	queue.push_front(section)
	return true

func on_air() -> bool:
	return not playing.is_empty()

# ---------- the link: the crew's ship goes behind Mars once a sol ----------

const LOS_AFTER_SUNSET := 1.0   # hours after sunset it goes behind the planet
const LOS_HOURS := 2.0          # and is gone this long
const LOS_WARN := .4            # Castle's heads-up, this long before, if you're out
var _warned_sol := -1
var _was_out := false           # behind the planet last frame
var _out_when_lost := false     # you were outside when she went

## The hours (start, end) the ship is behind Mars, every sol.
static func los_window() -> Vector2:
	var start := float(MHGame.site().get("day_cycle", {}).get("sunset_hour", 19.0)) + LOS_AFTER_SUNSET
	return Vector2(start, start + LOS_HOURS)

static func behind_mars() -> bool:
	var w := los_window()
	var hour := fmod(MHGame.sol_hour, 24.0)
	return hour >= w.x and hour < w.y

static func clock(hour: float) -> String:
	var h := fmod(hour, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]

## Gone behind Mars, as far as you can tell. A call already on air is never
## cut off: calls only start in contact, so she finishes what she's saying
## and the link drops when the call's over.
func gone() -> bool:
	return behind_mars() and playing.is_empty()

## Can Castle hear you, and you her?
func in_contact() -> bool:
	if gone(): return false
	var player: Node3D = world.get("player") if world != null else null
	return player == null or MHCaves.cave_at(player.global_position).is_empty()

## For the slate: when she's gone, or when she'll go.
func link_line() -> String:
	var w := los_window()
	if gone(): return "Orbit behind Mars · back at %s" % clock(w.y)
	if not in_contact(): return "No link underground"
	return "Orbit in touch · behind Mars %s–%s" % [clock(w.x), clock(w.y)]

func _outside() -> bool:
	var player: Node3D = world.get("player")
	if player == null: return false
	var at := player.global_position
	var lander: Node = world.get("lander")
	if lander != null and lander.has_method("cabin_contains") and bool(lander.cabin_contains(at)): return false
	var builder: Node = world.get("builder")
	if builder != null and builder.has_method("is_inside") and bool(builder.is_inside(at)): return false
	return not bool(player.get_meta("driving", false))

func _sol() -> int:
	var builder: Node = world.get("builder")
	return floori(float(builder.simulation().hours_run) / 24.0) if builder != null and builder.has_method("simulation") else 0

## The heads-up before she goes, and the hello when she's back.
func _watch_link() -> void:
	if world == null or fast: return
	var out := gone()
	var hour := fmod(MHGame.sol_hour, 24.0)
	var w := los_window()
	if not out and hour >= w.x - LOS_WARN and hour < w.x and _warned_sol != _sol() and _outside():
		_warned_sol = _sol()
		ring_urgent("los_soon")
	if out and not _was_out: _out_when_lost = _outside()
	if not out and _was_out and (_out_when_lost or _outside()): ring_urgent("los_back")
	_was_out = out

func flag(f: String) -> bool:
	return flags.has(f)

func _process(_delta: float) -> void:
	_watch_link()
	_watch_sleep()
	if not playing.is_empty() or queue.is_empty() or not _safe(_urgent.has(str(queue[0]))): return
	var section := str(queue.pop_front())
	_urgent.erase(section)
	if heard.has(section) or _stale(section): return
	_play(section)

## The heads-up after she's already gone, or the hello long after she's back.
func _stale(section: String) -> bool:
	var hour := fmod(MHGame.sol_hour, 24.0)
	var w := los_window()
	match section:
		"los_soon": return fposmod(w.x - hour, 24.0) > LOS_WARN + .1
		"los_back": return fposmod(hour - w.y, 24.0) > 1.0
	return false

## Awake again: last night's calls that never got through are let go (the
## far-side notes, "pick it up tomorrow", a goodnight chat). Day 4's sunset
## talk is kept: it carries the goals.
var _slept := false
func _watch_sleep() -> void:
	var sleep: Node = world.get("sleep") if world != null else null
	var asleep: bool = sleep != null and bool(sleep.get("asleep"))
	if _slept and not asleep: woke()
	_slept = asleep

func woke() -> void:
	for section in queue.duplicate():
		var s := str(section)
		if s in ["los_soon", "los_back"] or s.ends_with("_dusk") or (s.ends_with("_sunset") and s != "d4_sunset"):
			queue.erase(section)
			_urgent.erase(s)

## Never over danger, a blackout, another voice or a pause.
func _safe(urgent := false) -> bool:
	if world == null or world.get_tree().paused: return false
	if not fast and not in_contact(): return false
	if not fast and MHAudio.voice_busy(): return false
	var suit: Node = world.get("suit")
	if suit != null and bool(suit.get("passed_out")): return false
	if not urgent and world.has_method("danger_level") and float(world.danger_level()) >= .3: return false
	var sleep: Node = world.get("sleep")
	return sleep == null or not bool(sleep.get("asleep"))

## 21 Nov playtest: you shouldn't stand about on your air waiting for her to
## finish before you know where to go. Cues that put a place on your Map or a
## thought in Notes run the moment the call starts, not after its last line.
const EARLY_CUES := ["parachute", "gary_out", "walker_tracks", "pallet6", "sunset_spot", "ice_spot", "think"]
var _ran_early: Array = []

func _play(section: String) -> void:
	playing = section
	heard[section] = true
	topics.erase(section)
	if not fast: MHAudio.sfx("suit_beep", -12.0)
	var steps: Array = _sections.get(section, [])
	_ran_early = []
	for step in steps:
		if str(step.type) == "do" and not step.has("if") and str(step.args[0]) in EARLY_CUES:
			_cue(step)
			_ran_early.append(step)
	await _run(steps)
	_ran_early = []
	playing = ""
	call_finished.emit(section)

func _cue(step: Dictionary) -> void:
	var args: Array = step.args
	var cue_name := str(args[0])
	var rest := args.slice(1)
	if handlers.has(cue_name): (handlers[cue_name] as Callable).call(rest)
	cue.emit(cue_name, rest)

func _run(steps: Array) -> void:
	for step in steps:
		if step.has("if") and flags.has(str(step["if"])) == bool(step.get("not", false)): continue
		if _ran_early.has(step): continue
		match str(step.type):
			"line": await _say(step)
			"set": flags[str(step.flag)] = true
			"do": _cue(step)
			"wait":
				var args: Array = step.args
				var check: Callable = checks.get(str(args[0]), Callable())
				while check.is_valid() and not bool(check.call(args.slice(1))):
					await get_tree().create_timer(.25, false).timeout
			"choice": await _ask(step)
			"goto":
				var to := str(step.to)
				if to == "END": return
				heard[to] = true
				await _run(_sections.get(to, []))
				return

func _say(step: Dictionary) -> void:
	var id := str(step.id)
	if fast: return
	MHAudio.orbiter_line(id, str(step.who), str(step.text), "from orbit")
	await get_tree().process_frame
	var file := "res://assets/audio/voice/orb_%s.wav" % id
	if id.is_empty() or not ResourceLoader.exists(file):
		await get_tree().create_timer(2.0 + str(step.text).length() * .055, false).timeout
	while MHAudio.voice_busy(): await get_tree().create_timer(.1, false).timeout
	await get_tree().create_timer(GAP_AFTER_LINE, false).timeout

func _ask(step: Dictionary) -> void:
	var options: Array = step.options
	var texts: Array = []
	for option in options: texts.append(str(option.text))
	_choice = -2
	var replies: Node = world.get("replies")
	if fast or replies == null or not replies.has_method("ask"):
		_choice = 0   # tests and a missing panel: the first reply
	else:
		var hold := bool(step.get("hold", false))
		replies.ask(WHO, texts, 0.0 if hold else REPLY_SECONDS, func(index: int) -> void: _choice = index)
		var nudges: Array = step.get("nudges", [])
		var quiet := 0.0
		var said := 0
		while _choice == -2:
			await get_tree().create_timer(.1, false).timeout
			quiet += .1
			# Held: they keep calling till you answer.
			if hold and not nudges.is_empty() and quiet >= NUDGE_EVERY and not MHAudio.voice_busy():
				quiet = 0.0
				await _say(nudges[mini(said, nudges.size() - 1)] if said < nudges.size() else nudges[said % nudges.size()])
				said += 1
		# Your words stay up a moment: the next line waits till they've gone.
		while replies.has_method("saying") and replies.saying(): await get_tree().create_timer(.1, false).timeout
	if _choice >= 0 and _choice < options.size(): await _run(options[_choice].steps)

## Tests: pick a reply for the choice on screen.
func choose(index: int) -> void:
	_choice = index
