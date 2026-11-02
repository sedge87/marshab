extends SceneTree

# Run with: godot --headless --path . --script res://tests/survey_stakes_test.gd
# Chapter one's survey stakes (scripts/survey_stakes.gd): a stake per GAR-Y
# reading, cored state from the cores taken, the compass mark, the ping, the
# Tab map's survey layer and G order, and the corer's "not surveyed" hint.

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region_plains"; MHGame.game_mode = "survival"
	MHGame.base_site = {}
	MHGame.pending_save_state = {}
	MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 30: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var stakes = world.survey_stakes
	_check(stakes != null, "chapter one has survey stakes")
	var gary = world.get_tree().get_first_node_in_group("gar_y")
	_check(gary != null, "GAR-Y is here")
	if stakes == null or gary == null:
		quit(1)
		return
	_check(not stakes.ping(), "no ping with no stakes")
	gary.ice_samples = [Vector3(80, 80, .5), Vector3(95, 80, .2), Vector3(110, 80, .05)]
	stakes._refresh()
	_check(stakes._stakes.size() == 3, "a stake per reading (%d)" % stakes._stakes.size())
	_check(stakes._compass.is_in_group("landmark") and str(stakes._compass.get_meta("landmark_label")) == "STRONG SIGNAL", "the strongest uncored reading is on the compass")
	var marks: Array = world.explore_hud.compass_markers() if world.get("explore_hud") != null else []
	if world.get("explore_hud") != null: _check(marks.any(func(m): return str(m.label) == "STRONG SIGNAL"), "and the compass lists it")
	MHChapterOne.record_core({"x": 82.0, "z": 81.0, "dry": false, "good": true, "purity": .5, "depth_m": 1.0})
	MHChapterOne.record_core({"x": 110.0, "z": 79.0, "dry": true, "good": false, "purity": .05, "depth_m": 0.0})
	stakes._refresh()
	var cored: Array = stakes.readings().map(func(r): return str(r.cored))
	_check(cored == ["ice", "", "dry"], "cores mark their stakes (%s)" % str(cored))
	_check(str(stakes._compass.get_meta("landmark_label")) == "FAINT SIGNAL", "the compass moves to the strongest still to core")
	_check(stakes.ping() and stakes._ping_left > 0.0, "T + F pings the stakes")
	stakes._process(.016)
	await process_frame
	# The corer: off surveyed ground it says where the nearest stake is.
	MHChapterOne.has_corer = true
	var player = world.player
	player.global_position = Vector3(80, player.global_position.y, 140)
	player.rotation = Vector3.ZERO
	var why: String = world.hand_corer.why_not()
	_check(why.begins_with("Not surveyed here · nearest stake") and why.ends_with(" N"), "the corer points to the nearest stake (%s)" % why)
	player.global_position = Vector3(80, player.global_position.y, 81.2)
	_check(world.hand_corer.why_not() == "", "no hint on surveyed ground")
	# The Tab map: the layer draws, and G sends GAR-Y to a zone.
	var map = world.region_map
	map._open()
	map._markers.queue_redraw()
	await process_frame
	var zones := preload("res://scripts/ice_knowledge.gd").likely_zones()
	_check(not zones.is_empty(), "the site has likely ice zones")
	if not zones.is_empty():
		var zone: Dictionary = zones[0]
		gary.global_position = Vector3(zone.centre.x + 20.0, gary.global_position.y, zone.centre.y)
		var why_order: String = gary.order("find_ice_at", Vector3(zone.centre.x, 0, zone.centre.y))
		_check(why_order == "" and gary.task == "survey" and gary.task_data.has("hunt"), "G on the map starts a zone survey (%s)" % why_order)
		map._markers.queue_redraw()
		await process_frame
		gary.global_position = Vector3(zone.centre.x + 900.0, gary.global_position.y, zone.centre.y)
		_check(str(gary.order("find_ice_at", Vector3(zone.centre.x, 0, zone.centre.y))).contains("too far"), "too far is refused")
	map.survey_layer = false
	map._markers.queue_redraw()
	await process_frame
	map._close()
	print("survey_stakes_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)
