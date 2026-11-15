extends SceneTree

# The radio (scripts/radio.gd, data/radio/*.txt, docs/radio.md):
# - the scripts parse: every section has steps, every spoken line an ID, no
#   ID used twice, every cue and wait is one the game knows;
# - a call plays once, replies set flags, "?" lines follow them, "=>" jumps;
# - calls wait out danger (a blackout) and play after;
# - topics wait for Call orbit;
# - saved and loaded.
# godot --headless --path . --script res://tests/radio_test.gd
const RADIO := preload("res://scripts/radio.gd")
# Every cue a script registers (radio.handlers["x"] anywhere in scripts/),
# read from the source so the list never goes stale.
var CUES: Array = []

func _known_cues() -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("handlers\\[\"([a-z_0-9]+)\"\\]")
	var dir := DirAccess.open("res://scripts")
	for f in dir.get_files():
		if not f.ends_with(".gd"): continue
		var text := FileAccess.get_file_as_string("res://scripts/" + f)
		for m in re.search_all(text):
			if not out.has(m.get_string(1)): out.append(m.get_string(1))
	return out
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

class FakeSuit extends Node:
	var passed_out := false

class FakeWorld extends Node:
	var suit: Node
	func danger_level() -> float: return 0.0

func _all_steps(steps: Array, out: Array) -> void:
	for step in steps:
		out.append(step)
		if str(step.type) == "choice":
			for option in step.options: _all_steps(option.steps, out)

func _initialize() -> void:
	CUES = _known_cues()
	# The files themselves.
	var sections: Dictionary = RADIO.sections()
	for need in ["d1_relock", "d1_pallet1", "d1_ridge", "d1_pallet2", "d1_pallet4", "d1_cargo", "d1_sunset", "d2_wake", "d2_cradle", "d2_found", "d3_wake", "d3_patched", "d3_home", "d3_sent", "d4_arrived", "d4_down", "d4_patched", "d4_quarters", "d4_sunset"]:
		_check(sections.has(need) and not (sections[need] as Array).is_empty(), "the scripts have %s" % need)
	var ids := {}
	for line in RADIO.all_lines():
		_check(not ids.has(line[0]), "line ID %s used once" % line[0])
		ids[line[0]] = true
		_check(str(line[1]) == "Castellanos", "%s is Castellanos's (%s)" % [line[0], line[1]])
	var lines_without_id := 0
	for section in sections:
		var steps: Array = []
		_all_steps(sections[section], steps)
		for step in steps:
			if str(step.type) == "line" and str(step.id).is_empty(): lines_without_id += 1
			if str(step.type) == "do": _check(CUES.has(str(step.args[0])), "%s's cue %s is known" % [section, step.args[0]])
			if str(step.type) == "goto": _check(str(step.to) == "END" or sections.has(str(step.to)), "%s jumps somewhere real" % section)
	_check(lines_without_id == 0, "every spoken line has a voice ID (%d without)" % lines_without_id)
	_check(ids.size() >= 40, "a day's worth of lines (%d)" % ids.size())

	# A small script of its own, run fast.
	var test_text := """
~ t_call
Castellanos: One. [ID:t1]
- First reply
	set picked_first
	Castellanos: You picked one. [ID:t2]
- Second reply
	set picked_second
? picked_first Castellanos: Only if first. [ID:t3]
?! picked_first Castellanos: Only if not. [ID:t4]
do mark here
=> t_next
~ t_next
Castellanos: Next. [ID:t5]
~ t_topic
Castellanos: You called. [ID:t6]
"""
	var parsed := {}
	RADIO.parse_into(parsed, test_text)
	_check(parsed.size() == 3, "three sections parse (%d)" % parsed.size())
	var choice: Dictionary = (parsed.t_call as Array)[1]
	_check(str(choice.type) == "choice" and (choice.options as Array).size() == 2, "the replies parse as one choice")
	_check(((choice.options[0] as Dictionary).steps as Array).size() == 2, "the first reply has its two lines")
	var conditional: Dictionary = (parsed.t_call as Array)[2]
	_check(str(conditional.get("if", "")) == "picked_first" and not bool(conditional.get("not", true)), "a ? line keeps its flag")

	var world := FakeWorld.new()
	world.suit = FakeSuit.new()
	world.add_child(world.suit)
	root.add_child(world)
	var radio: Node = RADIO.new()
	world.add_child(radio)
	radio.setup(world, {})
	radio.fast = true
	for key in parsed: radio._sections[key] = parsed[key]
	var marks: Array = []
	radio.handlers["mark"] = func(args: Array) -> void: marks.append(args)
	radio.ring("t_call")
	radio.ring("t_call")
	_check(radio.queue.size() == 1, "a call is queued once")

	# A blackout holds it.
	world.suit.passed_out = true
	for i in 5: await process_frame
	_check(not radio.on_air() and radio.queue.size() == 1, "no call while you're out cold")
	world.suit.passed_out = false
	for i in 20: await process_frame
	_check(not radio.on_air() and radio.heard.has("t_call") and radio.heard.has("t_next"), "the call played and jumped on")
	_check(radio.flag("picked_first") and not radio.flag("picked_second"), "the reply set its flag")
	_check(marks.size() == 1 and str(marks[0][0]) == "here", "the cue ran with its argument")
	radio.ring("t_call")
	_check(radio.queue.is_empty(), "a heard call doesn't come again")

	# Topics wait for you.
	radio.add_topic("t_topic")
	for i in 5: await process_frame
	_check(not radio.heard.has("t_topic"), "a topic waits for Call orbit")
	_check(radio.call_orbit(), "Call orbit raises it")
	for i in 10: await process_frame
	_check(radio.heard.has("t_topic") and radio.topics.is_empty(), "the topic played")

	# Saved and loaded.
	var saved: Dictionary = radio.export_state()
	var again: Node = RADIO.new()
	world.add_child(again)
	again.setup(world, saved)
	_check(again.flag("picked_first") and again.heard.has("t_call"), "flags and heard calls are saved")

	# Every line's voice file is there (after tools/generate_voice.py).
	var missing := 0
	for id in ids:
		if not ResourceLoader.exists("res://assets/audio/voice/orb_%s.wav" % id): missing += 1
	_check(missing == 0, "every radio line has a voice file (%d missing)" % missing)

	print("radio_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
