extends SceneTree

# Run with: godot --headless --path . --script res://tests/mc_threads_test.gd
# Mission Control's people (scripts/mission_control_link.gd): the Earth clock
# and its rota, a story beat per shift on its own person's shift, the light
# delay, messages held while you sleep and played when you wake, "Log only",
# replies from whoever's on console, and saving everyone's progress.

## Nobody talking: stop the voice and its queue.
func _quiet() -> void:
	var director = MHAudio.director()
	director._voice.stop()
	director._voice_queue.clear()

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var link = world.earth_link
	link.set_process(false)   # the test drives the clock
	link.hours = 0.0
	link.said = {"landed": true}
	link.progress = {}
	link._pending.clear(); link._held.clear(); link.messages.clear()
	link._shift = -1
	# The Earth clock: landing is Monday 09:00 Houston; a sol runs 39 min over a day.
	assert(is_equal_approx(link.earth_at(0.0), 9.0), "Landing at 09:00 Monday.")
	assert(absf(link.earth_at(24.0) - (9.0 + 24.0 * 88775.0 / 86400.0)) < .001, "A sol is 24 h 39 m of Earth time.")
	assert(link.on_console(link.shift_at(9.0)) == "ines", "Monday day: Ines.")
	assert(link.on_console(link.shift_at(21.0)) == "noor", "Monday night: Noor.")
	assert(link.on_console(link.shift_at(3 * 24.0 + 10.0)) == "theo", "Thursday day: Theo.")
	assert(link.on_console(link.shift_at(5 * 24.0 + 10.0)) == "sunny", "Saturday day: Sunny.")
	assert(link.on_console(link.shift_at(7 * 24.0 + 10.0)) == "ines", "And the week starts again.")
	assert(str(link.rota_line()).contains("ON CONSOLE INES") and str(link.rota_line()).contains("MON 09:00"), "The rota card (%s)." % link.rota_line())
	# Ines's first beat goes out on her first shift, once, then the light delay.
	link._story()
	link._story()
	assert(link._pending.size() == 1 and str(link._pending[0].line.id) == "ines_01", "One beat a shift: Ines's first (%s)." % str(link._pending))
	link._deliver()
	assert(link.messages.is_empty(), "Not before the light delay.")
	link.hours += 1.0
	link._deliver()
	assert(link.messages.size() == 1 and link._held.size() == 1, "It arrives after the delay.")
	link._gap = 0.0
	link._release()
	await process_frame
	assert(link._held.is_empty() and bool(link.messages[0].heard), "And it plays.")
	# Night: Noor's turn; you're asleep, so it's held and played when you wake.
	link.hours = 12.0   # Earth 21:20
	link._story()
	assert(str(link._pending.back().line.id) == "noor_01", "Noor's first beat on her night.")
	world.sleep.asleep = true
	_quiet()
	link.hours += 1.0
	link._deliver()
	link._gap = 0.0
	link._release()
	assert(link._held.size() == 1 and bool(link._held[0].missed), "Asleep: held for you.")
	world.sleep.asleep = false
	_quiet()
	link._gap = 0.0
	link._release()
	assert(link._held.is_empty(), "Awake: played.")
	# A reply comes from whoever's on console (Noor, at night).
	link.notify("first_harvest")
	assert(str(link._pending.back().line.speaker) == "noor", "Noor answers the harvest at night.")
	assert(not link.notify("first_harvest"), "A one-off is answered once.")
	# Log only: logged, unread, not spoken.
	MHGame.setting("mc_chatter")
	MHGame._settings["mc_chatter"] = "log"
	link.hours += 1.0
	var before: int = link.messages.size()
	link._deliver()
	assert(link.messages.size() == before + 1 and link._held.is_empty() and link.unread == 1, "Log only: in the log, not on the radio.")
	MHGame._settings["mc_chatter"] = "normal"
	# Small talk is the on-console person's own.
	var talk: Dictionary = link.next_chatter("noor", false)
	assert(str(talk.id).begins_with("ch_noor") and not ("drive" in (talk.get("tags", []) as Array)), "Noor's own small talk.")
	assert("drive" in (link.next_chatter("theo", true).tags as Array), "Drive talk for the rover radio.")
	# Saved and restored.
	var state: Dictionary = link.export_state()
	var again = preload("res://scripts/mission_control_link.gd").new()
	again.setup(world)
	again.restore_state(state)
	assert(again.progress == link.progress and again.messages.size() == link.messages.size() and is_equal_approx(again.hours, link.hours), "Everyone's progress is saved.")
	again.free()
	# The Messages log opens, by everyone and by person, and reads them all.
	world._open_mission_control()
	for i in 5: await process_frame
	var screen = world.mission_control
	assert(screen != null, "Mission Control opens.")
	screen._show_messages()
	await process_frame
	screen._show_messages("noor")
	await process_frame
	assert(link.unread == 0, "Opening the log reads it.")
	# The settings' audio page has the Mission Control choice.
	var settings = preload("res://scripts/settings_panel.gd").new()
	root.add_child(settings)
	await process_frame
	var audio: Control = settings._audio()
	settings.add_child(audio)
	await process_frame
	assert(audio.find_children("*", "Label", true, false).any(func(l): return str(l.text) == "Mission Control"), "Settings has the Mission Control row.")
	settings.queue_free()
	print("Mission Control test passed: the Earth clock and rota, one beat a shift, the light delay, held while asleep, replies from the person on console, Log only, small talk and saving.")
	quit(0)
