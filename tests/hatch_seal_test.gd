extends SceneTree

# The lander hatch's seal (scripts/crew_lander.gd, survival_core.gd,
# lander_cabin_life.gd, suit.gd; docs/systems-and-items.md §14 step 2):
# - a new game starts shut and sealed, with the seal lamp green;
# - opening vents the cabin at once: no air to breathe, a little colder, the
#   lamp red, and the suit doesn't refill (it drains as outside);
# - closing swings shut, latches, repressurises (taking tank oxygen) and only
#   then seals: the lamp green, the suit refilling again;
# - reopening part-way cancels the seal; you can't sleep with it open;
# - the hatch and the vent are saved. Run with:
# godot --headless --path . --script res://tests/hatch_seal_test.gd

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	var lander = world.lander
	var cabin = world.cabin_life
	var suit = world.suit
	var player: Node3D = world.player
	player.global_position = lander.to_global(Vector3(0, lander.DECK + .9, .3))
	for i in 3: await process_frame

	# A new game starts shut and sealed.
	_check(not lander.hatch_open() and lander.sealed_cabin() and cabin.breathable(), "a new game's hatch is shut and sealed")
	_check(suit._where() == "lander", "sealed, the cabin is where you breathe (%s)" % suit._where())

	# Opening vents the cabin.
	var warm: float = cabin.core.temp_c
	lander.interact()
	_check(lander.hatch_open() and lander.seal_state == "open" and not lander.sealed_cabin(), "opening unseals it at once")
	_check(cabin.core.vented and float(cabin.conditions().o2_pct) == 0.0, "the cabin is open to Mars: no air to breathe")
	_check(cabin.core.temp_c < warm, "and it loses some warmth (%.1f → %.1f °C)" % [warm, cabin.core.temp_c])
	_check(world.body.surroundings().is_empty(), "the body is on the suit, not the cabin air")
	_check(suit._where() == "outside", "in the open cabin the suit is on its own")
	suit.o2 = .5
	var before: float = suit.o2
	suit.where = suit._where()
	suit._top_up(.2)
	_check(suit.o2 <= before, "the open cabin doesn't refill the suit (%.3f → %.3f)" % [before, suit.o2])
	_check(world.sleep.blocked_reason() != "", "no sleeping with the hatch open")

	# Closing: swing, latch, repressurise, sealed.
	suit.o2 = 1.0; suit.power = 1.0   # full, so nothing else draws on the tank
	var tank: float = cabin.core.tank_o2_kg
	lander.interact()
	_check(lander.seal_state == "closing" and not lander.sealed_cabin() and cabin.core.vented, "closing: not sealed yet")
	_check(str(lander.interaction_prompt().label).contains("sealing"), "the prompt says it's sealing")
	await _wait(2.8)
	_check(lander.seal_state == "latching", "the latches clamp after the swing (%s)" % lander.seal_state)
	await _wait(1.3)
	_check(lander.seal_state == "pressurising" and cabin.core.vented, "then it repressurises (%s)" % lander.seal_state)
	await _wait(3.2)
	_check(lander.sealed_cabin() and not cabin.core.vented, "then it's sealed")
	var cost: float = tank - cabin.core.tank_o2_kg
	_check(is_equal_approx(cost, load("res://scripts/mh_resources.gd").revamp("cabin_repress_o2_kg", .03)), "repressurising took the tank's oxygen (%.3f kg)" % cost)
	_check(float(cabin.conditions().o2_pct) > 20.0, "the cabin air is breathable again (%.1f%%)" % float(cabin.conditions().o2_pct))
	_check(suit._where() == "lander", "and the suit draws on the cabin again")
	suit.o2 = .5
	before = suit.o2
	suit.where = suit._where()
	suit._top_up(.2)
	_check(suit.o2 > before, "sealed, the cabin refills the suit (%.3f → %.3f)" % [before, suit.o2])

	# Reopening part-way cancels the seal.
	lander.interact()
	lander.interact()
	await _wait(1.0)
	lander.interact()
	await _wait(6.0)
	_check(lander.hatch_open() and lander.seal_state == "open" and cabin.core.vented, "reopening during the close cancels the seal (%s)" % lander.seal_state)

	# Saving.
	var state: Dictionary = world.current_state()
	_check(bool(state.lander.get("hatch_open", false)) and bool(state.cabin.get("vented", false)), "the open hatch and the vented cabin are saved")
	var copy = load("res://scripts/survival_core.gd").new()
	copy.load_state(state.cabin)
	_check(copy.vented, "and load back")

	if failures == 0:
		print("Hatch seal test passed: shut and sealed at the start; opening vents the cabin (no air, colder, no suit refill, no sleep); closing swings, latches, repressurises from the tank and seals; reopening cancels it; saved.")
	quit(1 if failures > 0 else 0)
