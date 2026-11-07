extends SceneTree

# The descent's radio (scripts/descent.gd, data/orbiter_crew.json "radio"):
# every line has its recording; beats play in order as their phase comes,
# one at a time; a phase that ends early drops its unplayed beats; the
# touchdown call cuts in over anyone talking. Run with:
# godot --headless --path . --script res://tests/descent_radio_test.gd

const DESCENT := preload("res://scripts/descent.gd")

func _initialize() -> void:
	var descent: Node = DESCENT.new()   # not in the tree: only its radio is used
	descent._load_radio()
	var all: Array = descent._beats + descent._events.values()
	if all.size() < 8: return _fail("expected the descent's beats and events, got %d" % all.size())
	for line in all:
		if not descent._crew.has(str(line.speaker)): return _fail("%s: no crew member %s" % [line.id, line.speaker])
		if not ResourceLoader.exists("res://assets/audio/voice/orb_%s.wav" % line.id): return _fail("no recording for orb_%s" % line.id)
	MHAudio.director()
	await process_frame
	await process_frame
	var audio: MHAudio = MHAudio.director()
	# Entry: the first beat waits for its time, then plays.
	descent.phase = "entry"
	descent._t = 0.1
	descent._radio()
	if MHAudio.voice_busy(): return _fail("a beat played before its time")
	descent._t = 0.4
	descent._radio()
	if not MHAudio.voice_busy() or not _playing(audio, "orb_descent_entry"): return _fail("the entry beat did not play")
	# One at a time: powered's first beat waits for the voice to be free.
	descent.phase = "powered"
	descent._t = 1.0
	var waiting: int = descent._beats.size()
	descent._radio()
	if descent._beats.size() != waiting: return _fail("a beat talked over another")
	audio._hush()
	descent._radio()
	if descent._beats.size() != waiting - 1: return _fail("the engines beat did not follow")
	# Confirming early: powered's other beats are dropped once the final starts.
	audio._hush()
	descent.phase = "final"
	descent._t = 0.0
	descent._radio()
	if str(descent._beats[0].phase) != "final": return _fail("powered beats lingered into the final")
	# Touchdown cuts in over anyone talking and clears the queue.
	descent._t = 4.0
	descent._radio()
	MHAudio.cast_line("x", "Someone", "Waiting in the queue.")
	descent._call("contact", true)
	await process_frame
	if not audio._voice_queue.is_empty(): return _fail("the touchdown call left lines queued")
	if not _playing(audio, "orb_descent_contact"): return _fail("the touchdown call did not cut in")
	descent.free()
	print("descent radio test passed")
	quit(0)

func _fail(message: String) -> void:
	push_error("descent radio test failed: " + message)
	quit(1)

func _playing(audio: MHAudio, file: String) -> bool:
	return audio._voice.stream != null and audio._voice.stream.resource_path.ends_with(file + ".wav")
