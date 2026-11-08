extends SceneTree

# Short replies (scripts/replies.gd, data/replies.json; systems-and-items §10e):
# - ARDEN's lander brief offers replies once it's spoken; saying you'll go
#   takes up the air thought in your own words, first in Notes;
# - Castellanos's parachute text waits until you've had the slate up, then
#   offers replies; asking a question brings her answer on the next pass;
# - silence is an answer: the thought still comes, in its usual words;
# - keys 1-3 pick; what's answered is saved.
# godot --headless --path . --script res://tests/replies_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world.day_night.frozen = true
	return world

func _until_shown(r: Node) -> bool:
	for i in 400:
		MHAudio.hush()
		if MHNotices._line != null: MHNotices._line._queue.clear()   # the line before it has been read
		r._process(.1)
		if r.showing(): return true
	return false

func _initialize() -> void:
	var world = await _new_world()
	var r: Node = world.replies
	var notes: Node = world.notes
	_check(r != null, "the world has replies")
	# The parachute text is waiting from touchdown: not until you've seen it.
	_check(world.orbiter_texts.has("parachute_photo") and r._queue.any(func(q): return str(q.id) == "parachute_photo"), "the parachute text wants an answer")
	MHAudio.hush()
	r._process(.1)
	_check(not r.showing(), "not before you've had the slate up")
	r.slate_lowered()
	_check(_until_shown(r) and str(r._shown.id) == "parachute_photo", "slate down: the replies come up")
	_check(r._rows[0].visible and str(r._rows[0].text).begins_with("1"), "numbered, keys 1-3")
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	r._input(key)
	_check(int(r.answered.get("parachute_photo", -9)) == 1 and r._you.visible and str(r._you.text).begins_with("You:"), "2 picks the second; your line shows, written")
	_check(notes.is_open("parachute") and str(notes.thoughts()[0].id) == "parachute", "the parachute thought comes first in Notes")
	r._process(r.ANSWER_AFTER + 1.0)
	_check(world.orbiter_texts.has("parachute_photo_answer"), "Castellanos answers on the next pass")

	# ARDEN's brief: you say you'll go.
	r._said_left = 0.0
	r._gap = 0.0
	r._panel.visible = false
	r.offer_voice("lander_brief")
	_check(_until_shown(r) and str(r._shown.who) == "ARDEN", "ARDEN's brief offers replies once it's spoken")
	r.choose(0)
	var top: Dictionary = notes.thoughts()[0]
	_check(str(top.id) == "air" and str(top.text).begins_with("ARDEN says"), "saying you'll go: the air thought, in your words, first")

	# Silence is an answer.
	r._said_left = 0.0
	r._gap = 0.0
	r.offer_voice("cabin_battery_night")
	_check(_until_shown(r), "ARDEN's power warning offers replies")
	r._process(r.SHOW_SECONDS + .5)
	_check(int(r.answered.get("cabin_battery_night", -9)) == -1 and notes.is_open("power") and not r.showing(), "saying nothing: it fades, and the thought comes anyway")
	r.offer_voice("cabin_battery_night")
	_check(not r._queue.any(func(q): return str(q.id) == "cabin_battery_night"), "asked once")

	# Saved and loaded.
	var state: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	var again = await _new_world(state)
	_check(again.replies.answered.has("parachute_photo") and again.replies.answered.has("lander_brief"), "what you answered is saved")
	var said: Array = again.notes.thoughts().filter(func(t): return str(t.id) == "air")
	_check(not said.is_empty() and str(said[0].text).begins_with("ARDEN says"), "and your words stay in Notes")
	again.queue_free()
	await process_frame
	print("replies_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
