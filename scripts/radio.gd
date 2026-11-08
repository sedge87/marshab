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
##
## Calls queue and never interrupt danger: they wait while your suit's in
## trouble, you're out cold or a storm is on you. Each section plays once,
## unless it's a topic you raise yourself (Call orbit on the slate).
## Your replies are written, never spoken (scripts/replies.gd shows them).

signal call_finished(section: String)
signal cue(name: String, args: Array)

const FOLDER := "res://data/radio/"
const WHO := "Castellanos"
const REPLY_SECONDS := 20.0
const GAP_AFTER_LINE := .5

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
	if not cut.is_empty() and not queue.has(cut): queue.push_front(cut)   # a call cut off by a save plays again
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
			steps.append(choice)
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
			for option in step.options: _collect(option.steps, out)

# ---------- calls ----------

func has_section(section: String) -> bool:
	return _sections.has(section)

## Castellanos calls about `section` (once only).
func ring(section: String) -> void:
	if not _sections.has(section) or heard.has(section) or queue.has(section) or playing == section: return
	queue.append(section)

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

func flag(f: String) -> bool:
	return flags.has(f)

func _process(_delta: float) -> void:
	if not playing.is_empty() or queue.is_empty() or not _safe(): return
	var section := str(queue.pop_front())
	if heard.has(section): return
	_play(section)

## Never over danger, a blackout, another voice or a pause.
func _safe() -> bool:
	if world == null or world.get_tree().paused: return false
	if not fast and MHAudio.voice_busy(): return false
	var suit: Node = world.get("suit")
	if suit != null and bool(suit.get("passed_out")): return false
	if world.has_method("danger_level") and float(world.danger_level()) >= .3: return false
	var sleep: Node = world.get("sleep")
	return sleep == null or not bool(sleep.get("asleep"))

func _play(section: String) -> void:
	playing = section
	heard[section] = true
	topics.erase(section)
	if not fast: MHAudio.sfx("suit_beep", -12.0)
	await _run(_sections.get(section, []))
	playing = ""
	call_finished.emit(section)

func _run(steps: Array) -> void:
	for step in steps:
		if step.has("if") and flags.has(str(step["if"])) == bool(step.get("not", false)): continue
		match str(step.type):
			"line": await _say(step)
			"set": flags[str(step.flag)] = true
			"do":
				var args: Array = step.args
				var cue_name := str(args[0])
				var rest := args.slice(1)
				if handlers.has(cue_name): (handlers[cue_name] as Callable).call(rest)
				cue.emit(cue_name, rest)
			"wait":
				var args: Array = step.args
				var check: Callable = checks.get(str(args[0]), Callable())
				while check.is_valid() and not bool(check.call(args.slice(1))):
					await get_tree().create_timer(.25).timeout
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
		await get_tree().create_timer(2.0 + str(step.text).length() * .055).timeout
	while MHAudio.voice_busy(): await get_tree().create_timer(.1).timeout
	await get_tree().create_timer(GAP_AFTER_LINE).timeout

func _ask(step: Dictionary) -> void:
	var options: Array = step.options
	var texts: Array = []
	for option in options: texts.append(str(option.text))
	_choice = -2
	var replies: Node = world.get("replies")
	if fast or replies == null or not replies.has_method("ask"):
		_choice = 0   # tests and a missing panel: the first reply
	else:
		replies.ask(WHO, texts, REPLY_SECONDS, func(index: int) -> void: _choice = index)
		while _choice == -2: await get_tree().create_timer(.1).timeout
		# Your words stay up a moment: the next line waits till they've gone.
		while replies.has_method("saying") and replies.saying(): await get_tree().create_timer(.1).timeout
	if _choice >= 0 and _choice < options.size(): await _run(options[_choice].steps)

## Tests: pick a reply for the choice on screen.
func choose(index: int) -> void:
	_choice = index
