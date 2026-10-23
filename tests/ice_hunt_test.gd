extends SceneTree

# Run with: godot --headless --path . --script res://tests/ice_hunt_test.gd
# G3: orbit only shows where ice is likely (broad, a little off-centre); GAR-Y's
# "Find ice" plans its own survey loop across the nearest likely zone and
# reports the best spot; every survey is recorded, saved, and shown on the
# site plan's overlay and the compass. C opens the Crew screen.
const ICE := preload("res://scripts/ice_knowledge.gd")

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	# Likely zones: bigger than the deposit, a little off-centre, the same every time.
	var zones := ICE.likely_zones()
	var deposit: Dictionary = MHGame.site().ice_deposits[0]
	var real := Vector2(float(deposit.x), float(deposit.z))
	assert(zones.size() == 1 and float(zones[0].radius) > float(deposit.radius) * 1.5, "A broad likely zone.")
	var shift := (zones[0].centre as Vector2).distance_to(real)
	assert(shift > 1.0 and shift < float(deposit.radius) * .5, "Near the deposit, but not on it (%.1f m off)." % shift)
	assert(ICE.likely_zones()[0].centre == zones[0].centre, "The same every time.")
	var stops := ICE.survey_stops(zones[0], Vector2.ZERO)
	assert(stops.size() == 7, "Seven survey stops: the middle and a ring.")
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var gary: Node = world.scout_rover
	# Indoors it won't go; outside near the zone it plans a loop.
	gary.global_position = Vector3(30, gary.global_position.y, -30)
	await process_frame
	var why: String = gary.order("find_ice")
	assert(why.is_empty(), "Find ice is accepted outside (%s)." % why)
	assert(gary.task == "survey" and (gary.task_data.hunt as Array).size() == 6, "It sets off on a 7-stop loop.")
	assert(str(gary.status_text()).begins_with("finding ice: stop 1 of 7"), "And says so (%s)." % gary.status_text())
	# Run the loop's bookkeeping: six more stops, the best one rich.
	for i in 6:
		gary._hunt_next(Vector2(i, i), .1 if i != 3 else .6)
	gary._hunt_next(Vector2(9, 9), .05)
	assert(gary.task.is_empty(), "After the last stop it reports and stops.")
	# Surveys are recorded, saved and shown.
	gary.ice_samples = [Vector3(40, -40, .31), Vector3(20, -20, .02)]
	var best := ICE.best_found(get_root().get_tree())
	assert(is_equal_approx(float(best.richness), .31) and best.at == Vector2(40, -40), "The best find is known.")
	var overlay := ICE.overlay(get_root().get_tree())
	assert(overlay.size() == 3 and overlay[0].w < 0.0 and is_equal_approx(overlay[1].w, .31), "The overlay has the likely zone and both measurements.")
	var state: Dictionary = gary.export_state()
	gary.ice_samples = []
	gary.restore_state(state)
	assert(gary.ice_samples.size() == 2, "Surveys are saved with GAR-Y.")
	# C: straight to the Crew screen.
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.pressed = true
	world._unhandled_input(key)
	await process_frame
	await process_frame
	assert(world.mission_control != null, "C opens Mission Control on the Crew screen.")
	print("Ice hunt test passed: likely zones from orbit, GAR-Y's Find ice loop and report, recorded surveys, the overlay and C for Crew.")
	quit(0)
