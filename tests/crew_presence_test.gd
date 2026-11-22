extends SceneTree

# The crew around you in the slice (scripts/crew_presence.gd; docs/opening-slice.md
# "How and when the crew talk"): every hinted step has its hint, the reactive
# calls and the six open-channel snippets load, every new line has its
# recording, replies can hide behind a flag, and names show on the first two
# lines from each person. Run with:
# godot --headless --path . --script res://tests/crew_presence_test.gd

const RADIO := preload("res://scripts/radio.gd")
const PRESENCE := preload("res://scripts/crew_presence.gd")

func _initialize() -> void:
	RADIO.opening_set = "slice"
	var sections: Dictionary = RADIO.sections()
	var wanted: Array = ["s1_manifest", "s1_ask", "s1_stores", "s1_ate", "s2_ride", "ask_nothing_1", "ask_nothing_2", "ask_nothing_3"]
	for step in PRESENCE.HINTED: wanted.append("hint_" + str(step))
	for n in range(1, 7): wanted.append("oc_%d" % n)
	for section in wanted:
		if not sections.has(section): return _fail("no section " + str(section))
	var lines: Array = []
	for section in wanted + ["s1_seal", "s1_dusk"]: RADIO._collect(sections[section], lines)
	for line in lines:
		if not ResourceLoader.exists("res://assets/audio/voice/orb_%s.wav" % line[0]): return _fail("no recording for orb_" + str(line[0]))
	# The lander's menu: a topic hides once it's asked.
	var ask: Dictionary = (sections.s1_ask as Array)[0]
	if str(ask.type) != "choice" or ask.options.size() != 4: return _fail("the lander's menu should offer four replies")
	if str(ask.options[0].get("if", "")) != "ask_look" or not bool(ask.options[0].get("not", false)): return _fail("a topic reply isn't hidden by its flag")
	if str(ask.options[0].text) != "What do I look for out there?": return _fail("the flag was left in the reply's words")
	# Open channel lines say so, and don't beep.
	if not RADIO.overheard("oc_3") or RADIO.overheard("s1_stores"): return _fail("open-channel sections misread")
	# Names on voices: full name and role twice, then the short name.
	MHAudio.named = {}
	var first := MHAudio.crew_caption("Rao")
	var second := MHAudio.crew_caption("Rao")
	var third := MHAudio.crew_caption("Rao")
	if first != "Devan Rao · Pilot" or second != first or third != "Rao": return _fail("names on voices: %s / %s / %s" % [first, second, third])
	if MHAudio.crew_caption("Someone") != "Someone": return _fail("a name outside the crew was changed")
	MHAudio.named = {}
	print("crew presence test passed")
	quit(0)

func _fail(message: String) -> void:
	push_error("crew presence test failed: " + message)
	quit(1)
