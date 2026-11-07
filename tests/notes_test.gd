extends SceneTree

# Notes, your inner voice (scripts/notes.gd, data/notes.json; master-design §5):
# - a new game's slate has Notes, not Goals, and the old crates don't land;
# - the first thoughts come to mind: the cabin air, the blue sunset;
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
	_check(notes.is_open("air") and notes.is_open("sunset"), "the first thoughts: the cabin air and the blue sunset (%s)" % str(notes.thoughts()))
	_check(MHNotices.history.any(func(n): return str(n.app) == "notes"), "a new thought shows on the notice line, for the Notes app")

	# The slate: Notes, not Goals.
	var screen = world.pda.screen if world.pda.get("screen") != null else null
	if screen != null:
		_check("notes" in screen.apps() and not "goals" in screen.apps(), "the slate has Notes, not Goals (%s)" % str(screen.apps()))
		var page: Control = screen._notes_page()
		var texts: Array = page.find_children("*", "Label", true, false).map(func(l): return str(l.text))
		_check(texts.any(func(t): return t.begins_with("The dial says")) and not texts.any(func(t): return t.contains("/") or t.contains("✓")), "the page is just your thoughts, no ticks or counts")
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
	notes._air_settled_for = notes.AFTER_AIR
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

	# Saving.
	var state: Dictionary = world.current_state()
	var copy = load("res://scripts/notes.gd").new()
	copy.setup(world, JSON.parse_string(JSON.stringify(state.notes)), false)
	_check(copy.is_open("cargo") and copy.is_settled("parachute") and copy.thoughts().size() == notes.thoughts().size(), "open and settled thoughts are saved")
	copy.free()
	if failures == 0:
		print("Notes test passed: Notes instead of Goals and no old crates in a new game, the first thoughts, fills, thoughts changing out of order, answers into the journal raising the next question, never more than five, ARDEN's afternoon warning, night and dawn, rest offered and passing, the blue sunset, a cold cabin, and saving.")
	quit(1 if failures > 0 else 0)
