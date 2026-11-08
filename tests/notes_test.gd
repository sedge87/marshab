extends SceneTree

# Notes, your inner voice (scripts/notes.gd, data/notes.json; master-design §5):
# - a new game's slate has Notes, not Goals, and the old crates don't land;
# - touchdown is quiet; the first thoughts come in beats once the slate's
#   down (the air, then the parachute; mars_world._after_slate), and the
#   blue sunset waits for the afternoon;
# - the notice line: wraps, holds, waits for the slate, pressing first, Log-only chatter;
# - the most pressing thought first on the page, and remind_top();
# - thoughts change as you act, even out of order, and stay few;
# - an answered thought leaves the page for the journal and raises the next;
# - what's watched: the blue sunset outside, a cold cabin, night then dawn;
# - the page is plain thoughts (no ticks or counts); saving.
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHChapterOne.reset()   # as the menu does for a new game
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	_check(MHGame.tutorial_mode == "hints" and world.tutorial == null, "a new game has no step-by-step checklist")
	_check(world.cargo_landers.is_empty() and world.get_tree().get_nodes_in_group("precursor_crate").is_empty(), "the old chapter-one crates don't land")
	var notes = world.notes
	notes._check = 0.0
	for i in 3: await process_frame
	_check(not notes.is_open("air") and not notes.is_open("sunset") and not notes.is_open("parachute"), "touchdown is quiet: no thoughts piled up (%s)" % str(notes.thoughts()))
	# The beats after the slate (timers in the game; straight through here).
	notes.think("air")
	world.storm_drop.parachute_thought()
	_check(notes.is_open("air") and notes.is_open("parachute") and not notes.is_open("sunset"), "then the cabin air and the parachute; the sunset waits (%s)" % str(notes.thoughts()))
	var touchdown_hour := MHGame.sol_hour
	var inside_at: Vector3 = world.player.global_position
	world.player.global_position = world.lander.global_position + Vector3(0, 0, 20)   # outside: ARDEN's not heard
	MHGame.sol_hour = float(MHGame.site().get("day_cycle", {}).get("sunset_hour", 19.0)) - 2.0
	notes._check = 0.0
	await process_frame
	await process_frame
	_check(notes.is_open("sunset"), "late afternoon: the blue sunset wish")
	MHGame.sol_hour = touchdown_hour
	world.player.global_position = inside_at
	_check(MHNotices.history.any(func(n): return str(n.app) == "notes"), "a new thought shows on the notice line, for the Notes app")

	# The slate: Notes, not Goals.
	var screen = world.pda.screen if world.pda.get("screen") != null else null
	if screen != null:
		_check("notes" in screen.apps() and not "goals" in screen.apps(), "the slate has Notes, not Goals (%s)" % str(screen.apps()))
		var page: Control = screen._notes_page()
		var texts: Array = page.find_children("*", "Label", true, false).map(func(l): return str(l.text))
		_check(texts.any(func(t): return t.begins_with("Cabin air's good")) and not texts.any(func(t): return t.contains("/") or t.contains("✓")), "the page is just your thoughts, no ticks or counts")
		page.free()

	# Out of order: you find the pallet without ever thinking about it.
	_check(notes.is_open("parachute") and notes.text_of(notes.open[notes._find("parachute")]).contains(" of the hatch") and not notes.text_of(notes.open[notes._find("parachute")]).contains("{"), "a thought takes its fills (the ridge's direction)")
	notes.think("parachute", "open")
	_check(notes.stage("parachute") == "open", "a thought changes when you act")
	var sol: int = notes._sol()
	notes.answer("parachute")
	_check(not notes.is_open("parachute") and notes.is_settled("parachute"), "answered, it leaves the page")
	var lines: Array = MHJournal.entries.back().lines if not MHJournal.entries.is_empty() else []
	_check(lines.any(func(l): return str(l).begins_with("Found the first pallet")), "and becomes a journal line (%s)" % str(lines))
	_check(notes.is_open("cargo"), "an answer raises the next question")
	_check(not notes.think("parachute"), "a settled thought doesn't come back")
	notes.answer("air")   # never thought this stage: answering works out of order
	_check(notes.is_settled("air"), "a thought can be answered from any stage")

	# ARDEN raises the night a little after the air is settled.
	_check(not notes.is_open("power"), "no night worry straight away")
	var cabin_spot: Vector3 = world.player.global_position
	world.player.global_position = world.lander.global_position + Vector3(0, 0, 20)
	notes._air_settled_for = notes.AFTER_AIR
	notes._check = 0.0
	await process_frame
	await process_frame
	_check(not notes.is_open("power"), "ARDEN is only the habitat's voice: the warning waits while you're outside")
	world.player.global_position = cabin_spot
	notes._check = 0.0
	await process_frame
	await process_frame
	_check(notes.is_open("power") and notes.stage("power") == "start", "after the air is sorted, ARDEN warns about the night and it becomes a thought")

	# Few at a time.
	for id in ["cold"]: notes.think(id)
	_check(notes.open.size() <= notes.MOST, "never more than %d open thoughts" % notes.MOST)

	# What's watched: night then dawn for the power thought.
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	world.day_night.set_hour(sunset + 1.0)
	notes._check = 0.0
	for i in 3: await process_frame
	_check(notes.stage("power") == "night", "after dark the power thought turns to the night ahead")
	_check(not world.cabin_life.player_inside() or notes.is_open("rest"), "in the cabin after dark, rest is offered")
	world.day_night.set_hour(sunrise + .5)
	notes._check = 0.0
	for i in 3: await process_frame
	_check(notes.is_settled("power") and MHJournal.entries.back().lines.any(func(l): return str(l).begins_with("Made it to morning.")), "dawn settles it, with how the night went")
	_check(not notes.is_open("rest") and not notes.is_settled("rest"), "the offer passes with the morning, and can come again")

	# The blue sunset, seen from outside.
	world.player.global_position = world.lander.global_position + Vector3(0, 0, 20)
	world.day_night.set_hour(sunset - .3)
	notes._check = 0.0
	for i in 3: await process_frame
	_check(notes.is_settled("sunset"), "being outside at sunset answers the sunset thought")

	# A cold cabin.
	var cabin = world.cabin_life
	world.player.global_position = world.lander.to_global(Vector3(0, world.lander.DECK + .9, .3))
	world.day_night.set_hour(12.0)
	cabin.core.temp_c = 6.0
	notes.settled.erase("cold"); notes.open = notes.open.filter(func(t): return str(t.id) != "cold")
	notes._check = 0.0
	for i in 3: await process_frame
	_check(notes.is_open("cold"), "a cold cabin comes to mind while you're in it")
	cabin.core.temp_c = 18.0
	notes._check = 0.0
	for i in 3: await process_frame
	_check(notes.is_settled("cold"), "warm again settles it")

	# The notice line (playtest 8 Nov): readable, waits for the slate, what matters first.
	var line: MHNotices = MHNotices._line
	line._queue.clear()
	if line._shown != null: line._fade_out()
	MHNotices.post("info", "Pallet 1: life support", "Inside: a fresh oxygen cartridge for the cabin, ten ration packs (you pocket them), and the sample kit (hand corer, scoop, bags). All of it is in the slate's Log too, with the rest of the day's news.", "log")
	await process_frame
	var body: Label = line._shown.find_child("Body", true, false) if line._shown != null else null
	_check(body != null and body.autowrap_mode != TextServer.AUTOWRAP_OFF and not body.clip_text and body.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "a long notice wraps, never clipped or cut off with …")
	_check(MHNotices.hold_for(line._shown_entry) >= MHNotices.HOLD_MIN + 3.0, "and stays up long enough to read (%.1f s)" % MHNotices.hold_for(line._shown_entry))
	MHNotices.post("info", "Ice melted", "2.0 L into the lander's tank.", "log")
	line._age = 2.6
	await process_frame
	_check(str(line._shown_entry.get("heading", "")) == "Pallet 1: life support", "another waiting doesn't hurry it off")
	MHNotices.hidden = true
	MHNotices.post("info", "Parts", "3 parts for the lander's printer.", "log")
	MHNotices.post("warn", "Dust storm", "A storm front by evening.", "site")
	for i in 3: await process_frame
	_check(line._shown == null and line._queue.size() >= 3, "with the slate up the queue waits instead of clearing (%d waiting)" % line._queue.size())
	_check(bool(line._queue[0].pressing) and str(line._queue[0].heading) == "Dust storm", "a pressing notice jumps the queue")
	MHNotices.post("info", "Sent to the orbiter", "The picture goes up on the next pass.", "comms", -1, false)
	_check(str(MHNotices.history.back().heading) == "Sent to the orbiter" and not line._queue.any(func(e): return str(e.heading) == "Sent to the orbiter"), "chatter can go to the Log alone")
	MHNotices.hidden = false
	await process_frame
	_check(line._shown != null and str(line._shown_entry.heading) == "Dust storm", "the slate down, the pressing one shows first")
	_check(MHNotices.glyph_for({"heading": MHNotices.YOU_THINK}) == "pencil" and MHNotices.glyph_for({"heading": "Castellanos, from orbit"}) == "satellite" and MHNotices.glyph_for({"heading": MHGame.habitat_name}) == "volume-2", "who's talking: a heading and an icon")
	line._queue.clear()
	line._fade_out()

	# What matters first on the page, and brought back to mind.
	notes.settled.erase("water")
	notes.think("photo")
	notes.think("water", "low", {"where": ""})
	notes.think("tired")
	_check(str(notes.ordered()[0].id) == "water" and bool(notes.thoughts()[0].pressing), "the most pressing thought is first on the page (%s)" % str(notes.ordered().map(func(t): return t.id)))
	_check(str(MHNotices.history.back().heading) == MHNotices.YOU_THINK, "a thought on the notice line is headed as your own")
	_check(notes.is_open("water") and notes.text_of(notes.open[notes._find("water")]).contains("ice to melt"), "it says what to do and why")
	var before: int = MHNotices.history.size()
	_check(notes.remind_top() and MHNotices.history.size() == before + 1 and bool(MHNotices.history.back().pressing) and str(MHNotices.history.back().text).begins_with("Cabin water's"), "remind_top brings the most pressing thought back, amber-edged")
	for id in ["iron", "ice_wall", "salvage", "rations_low", "dozed"]: notes.think(id, "seen" if id in ["iron", "ice_wall"] else "start")
	_check(notes.is_open("water"), "a pressing thought doesn't drift out of mind when the page is full")
	line._queue.clear()

	# Saving.
	var state: Dictionary = world.current_state()
	var copy = load("res://scripts/notes.gd").new()
	copy.setup(world, JSON.parse_string(JSON.stringify(state.notes)), false)
	_check(copy.is_open("water") and copy.is_settled("parachute") and copy.thoughts().size() == notes.thoughts().size(), "open and settled thoughts are saved")
	copy.free()
	if failures == 0:
		print("Notes test passed: the notice line (wrapping, holding, waiting for the slate, pressing first, Log-only chatter, who is talking), pressing thoughts first and remind_top, Notes instead of Goals and no old crates in a new game, the first thoughts, fills, thoughts changing out of order, answers into the journal raising the next question, never more than five, ARDEN's afternoon warning, night and dawn, rest offered and passing, the blue sunset, a cold cabin, and saving.")
	quit(1 if failures > 0 else 0)
