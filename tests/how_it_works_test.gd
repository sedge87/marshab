extends SceneTree

# How it works cards (23 Oct): simple tutorial cards for each system, shown
# in mission briefs, on K, the first time a key machine is placed, on failed
# test checks and in Mission Control's Field guide.
# Run with: godot --headless --path . --script res://tests/how_it_works_test.gd
const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	await process_frame
	# Leave the player's own seen-cards file as it was.
	var saved_seen := FileAccess.get_file_as_string(HOW_IT_WORKS.SEEN_PATH)
	var cards: Array = HOW_IT_WORKS.cards()
	_check(cards.size() >= 11, "the cards load (%d)" % cards.size())
	var mission_ids: Array = MHMissions.missions().map(func(m): return str(m.id))
	for c in cards:
		var lines: Array = c.get("lines", [])
		_check(lines.size() >= 3 and lines.size() <= 4, "%s has 3 or 4 lines" % c.id)
		for line in lines:
			_check(str(line).split(" ").size() <= 32, "%s: a line is short and simple (%s)" % [c.id, line])
		_check(not str(c.get("remember", "")).is_empty(), "%s has a Remember line" % c.id)
		var check: Dictionary = c.get("check", {})
		_check((check.get("options", []) as Array).size() == 3 and int(check.get("answer", -1)) == 0, "%s has a 3-option check, answer first" % c.id)
		for m in c.get("missions", []):
			_check(mission_ids.has(m), "%s names a real mission (%s)" % [c.id, m])

	# Every mission explains its systems.
	for m in mission_ids:
		_check(not HOW_IT_WORKS.for_mission(m).is_empty(), "mission %s has How it works cards" % m)
	_check(HOW_IT_WORKS.for_mission("cargo_habitat").has("heating"), "Mission 3 explains heating")

	# Placing a key machine finds its card.
	_check(HOW_IT_WORKS.for_trigger("thermal_control_unit") == "heating", "a thermal control unit -> heating")
	_check(HOW_IT_WORKS.for_trigger("grow_tray") == "food", "a grow tray -> food")
	_check(HOW_IT_WORKS.for_trigger("chair") == "", "a chair has no card")

	# Steps find their card.
	_check(HOW_IT_WORKS.for_step({"item": "solar"}) == "power", "a solar step -> power")
	_check(HOW_IT_WORKS.for_step({"check": "tested"}) == "testing", "a test step -> testing")
	_check(HOW_IT_WORKS.for_step({"check": "counter", "key": "gar_y_surveys"}) == "gar_y", "a survey step -> GAR-Y")
	for mission in MHMissions.missions():
		for step in mission.get("steps", []):
			var id := HOW_IT_WORKS.for_step(step)
			_check(id.is_empty() or not HOW_IT_WORKS.card(id).is_empty(), "step %s maps to a real card (%s)" % [step.get("id", "?"), id])

	# Failed checks have a card.
	for key in HOW_IT_WORKS.CHECK_CARDS:
		_check(not HOW_IT_WORKS.card(str(HOW_IT_WORKS.CHECK_CARDS[key])).is_empty(), "check %s explains with a real card" % key)

	# Free play unlocks every card.
	_check(HOW_IT_WORKS.unlocked().size() == cards.size(), "free play: every card in the Field guide")

	# Seen once.
	HOW_IT_WORKS.mark_seen(["storms"])
	_check(HOW_IT_WORKS.seen("storms"), "a shown card is remembered")
	# Never pops up in tests or Showcase.
	_check(not HOW_IT_WORKS.enabled(), "no first-time pop-ups when headless")

	# The viewer opens on the cards, pauses, steps and closes back.
	paused = false
	var viewer = HOW_IT_WORKS.show(self, ["heating", "air"])
	await process_frame
	_check(paused, "the viewer pauses the game")
	_check(viewer.index == 0, "it opens on the first card")
	viewer._go(1)
	_check(viewer.index == 1, "Next goes to the second card")
	viewer._go(1)
	await process_frame
	await process_frame
	_check(not paused, "Got it on the last card closes and unpauses")
	_check(get_nodes_in_group("how_it_works_viewer").is_empty(), "and the viewer is gone")
	# Opening twice keeps only one.
	HOW_IT_WORKS.show(self, ["power"])
	await process_frame
	var again = HOW_IT_WORKS.show(self, ["water"])
	await process_frame
	await process_frame
	_check(get_nodes_in_group("how_it_works_viewer").size() == 1, "only one viewer at a time")
	again._close()
	await process_frame

	if saved_seen.is_empty(): DirAccess.remove_absolute(HOW_IT_WORKS.SEEN_PATH)
	else: FileAccess.open(HOW_IT_WORKS.SEEN_PATH, FileAccess.WRITE).store_string(saved_seen)
	if failures == 0:
		print("How it works test passed: %d simple cards, every mission and failed check explained, viewer pauses and closes cleanly." % cards.size())
	quit(1 if failures > 0 else 0)
