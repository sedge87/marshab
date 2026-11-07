extends SceneTree

# Step 3b, the lifepod days (scripts/lifepod.gd and friends; systems-and-items
# §14 step 3b):
# - the lander's water runs down, reads low by the dawn of sol 2, and going
#   dry long enough hurts;
# - the iron outcrop and ice wall are placed round the landing, the frost
#   patch by pallet 4; coming close puts them in Notes and your record;
# - chipping needs the rock hammer; ice is carried home and melted;
# - storm debris strips for parts; the tiny printer makes the hitch, the pick
#   head and the bladder, each doing its job;
# - a sample studied on the bench is a Journal page;
# - with the hitch, ice goes on GAR-Y's sled and is melted at the lander;
# - three jobs done, the walker moves at 03:00 (Notes "night_sound");
# - all of it is saved and loaded.
# godot --headless --path . --script res://tests/lifepod_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	return world

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _carried(pod: Node) -> Node:
	for find in pod.get_tree().get_nodes_in_group("carried_find"):
		if str(find.where) == "carried" and not find.is_queued_for_deletion(): return find
	return null

func _initialize() -> void:
	var world = await _new_world()
	var pod: Node = world.lifepod
	_check(pod != null, "a new game has the lifepod days")
	if pod == null:
		quit(1)
		return
	var core: RefCounted = world.cabin_life.core
	var lander: Node3D = world.lander
	var player: Node3D = world.player
	var field: Node = world.drop_field

	# Water.
	_check(absf(float(core.water_l) - 7.5) < .05, "the lander starts with 7.5 L of water (%.1f)" % float(core.water_l))
	core.water_l = 3.0
	world.builder.simulation().hours_run = 31.0
	MHGame.sol_hour = 7.0
	await create_timer(.6).timeout
	_check(world.notes.is_open("water") and str(world.notes.stage("water")) == "low", "the dawn of sol 2: water's low, in Notes")
	core.water_l = 0.0
	core.dry_hours = 13.0
	_check(core.thirsty(), "dry for 13 hours: thirsty")
	core.dry_hours = 0.0
	core.water_l = 3.0

	# The threads.
	_check(pod.sites.has("iron") and pod.sites.has("ice_wall") and pod.sites.has("frost"), "iron outcrop, ice wall and frost patch are placed")
	var iron: Node = pod.sites.iron
	var wall: Node = pod.sites.ice_wall
	var frost: Node = pod.sites.frost
	var d_iron := _flat(iron.global_position, lander.global_position)
	var d_wall := _flat(wall.global_position, lander.global_position)
	_check(d_iron >= 990.0 and d_iron <= 1410.0, "the iron is 1.0-1.4 km out (%.0f m)" % d_iron)
	_check(d_wall >= 990.0 and d_wall <= 1510.0, "the ice wall is 1.0-1.5 km out (%.0f m)" % d_wall)
	_check(absf(angle_difference(field._bearing(iron.global_position), field._bearing(wall.global_position))) >= deg_to_rad(49.0), "they lie in different directions")
	_check(_flat(frost.global_position, field.sites.tools.at) < 20.0, "the frost patch is by pallet 4")
	player.global_position = iron.global_position + Vector3(0, 1.5, 20.0)
	await create_timer(.7).timeout
	_check(iron.seen and world.known.knows(iron.id()) and world.notes.is_open("iron"), "close to the outcrop: seen, known, in Notes")
	_check(world.notes.is_open("photo"), "and a nudge to take a picture")

	# A photo with the slate: the outcrop in frame, into the journal.
	var head: Node3D = player.get_node("Head")
	head.rotation.x = 0.0
	player.look_at(Vector3(iron.global_position.x, player.global_position.y, iron.global_position.z), Vector3.UP)
	await process_frame
	var cam: Node = world.slate_camera
	_check(cam != null and world.pda.screen.apps().has("camera"), "the slate has a Camera app")
	var found: Array = cam.subjects()
	_check(found.any(func(s): return str(s.id) == iron.id()), "the outcrop is in frame")
	var photo: Dictionary = await cam.take()
	_check(not photo.is_empty() and str(photo.caption).contains("Iron outcrop") and (photo.subjects as Array).has(iron.id()), "the photo's caption names it (%s)" % str(photo.get("caption", "")))
	_check(MHJournal.photographed(iron.id()) and world.notes.is_settled("photo"), "the journal knows you photographed it")
	var today: int = MHJournal.today(2)
	MHJournal.set_own(today, "Beads everywhere. Like ball bearings.")
	MHJournal.set_caption(today, 0, "The iron, from the south")
	var book: Control = load("res://scripts/journal_book.gd").new()
	root.add_child(book)
	await process_frame
	var note_box := book.find_child("OwnNote", true, false) as TextEdit
	_check(note_box != null and note_box.text.begins_with("Beads"), "the book shows your own note")
	book.queue_free()

	# Chipping needs the hammer.
	MHChapterOne.has_hammer = false
	_check(not iron.interact(player) and str(iron.interaction_prompt().label).contains("need"), "no hammer: nothing to chip with")
	MHChapterOne.has_hammer = true
	_check(iron.interact(player), "with the hammer you can chip")
	iron._holding = false
	iron.chip_for(2.0)
	var sample: Node = _carried(pod)
	_check(sample != null and sample.kind == "rock" and sample.source == "iron", "a rock sample in your hands")

	# Studied on the bench.
	var study: Node = pod.bench.stations.study
	_check(sample != null and sample.claim_label(study) == "Look closer", "the bench offers a closer look")
	if sample != null: sample.claim(study, "interact")
	await process_frame
	_check(pod.jobs.has("sample") and world.notes.is_settled("iron") and pod.bench._shelf.get_child_count() == 1, "studied: a job done, Notes answered, the sample on the shelf")

	# Ice from the frost patch, melted.
	player.global_position = frost.global_position + Vector3(0, 1.5, 3.0)
	await create_timer(.6).timeout
	frost.chip_for(2.0)
	var ice: Node = _carried(pod)
	_check(ice != null and ice.kind == "ice" and is_equal_approx(float(ice.kg), 8.0), "an 8 kg ice chunk")
	_check(float(player.get_meta("load_speed", 1.0)) < 1.0, "carrying it slows you")
	var melter: Node = pod.bench.stations.melter
	_check(ice != null and ice.claim_label(melter) == "Melt the ice" and ice.claim_label(pod.bench.stations.printer) == "", "the melter takes ice; the printer doesn't")
	var before: float = float(core.water_l)
	if ice != null: ice.claim(melter, "interact")
	await process_frame
	_check(absf(float(core.water_l) - before - 7.2) < .01, "8 kg melts to 7.2 L (%.2f)" % (float(core.water_l) - before))
	_check(world.notes.is_settled("water") and pod.jobs.has("water"), "water: answered, a job done")
	_check(str(pod.interaction_prompt().label).contains("L"), "the dispenser reads the tank")

	# Salvage and printing.
	var handles: Array = world.get_tree().get_nodes_in_group("salvage_piece")
	_check(handles.size() >= 8, "storm debris strips for parts (%d pieces)" % handles.size())
	_check(handles.all(func(h): return not str(h.get_parent().scene_file_path).contains("boulder")), "no boulders among them")
	for i in 4: handles[i].interact(player)
	_check(pod.parts == 8 and handles[0].stripped and not handles[0].interact(player), "four pieces: 8 parts; each once")
	_check(world.notes.is_open("salvage"), "salvage in Notes")
	var printer: Node = pod.bench.stations.printer
	_check(str(printer.interaction_prompt().get("primary", "")).contains("hitch"), "the printer offers the hitch first")
	printer.interact(player)
	_check(pod.printing == "hitch" and pod.parts == 5, "printing the hitch: 3 parts")
	pod._print_left = 0.0
	await process_frame
	await process_frame
	_check(pod.prints.has("hitch") and pod.jobs.has("print"), "the hitch is printed")
	_check(pod.walker_due, "three jobs done: the walker is due")
	printer.interact_info(player)
	var plan_name: String = str(printer.interaction_prompt().get("primary", ""))
	printer.interact(player)
	pod._print_left = 0.0
	await process_frame
	await process_frame
	printer.interact(player)
	pod._print_left = 0.0
	await process_frame
	await process_frame
	_check(pod.prints.has("pick") and pod.prints.has("bladder") and pod.parts == 1, "pick head and bladder printed too (%s; %d parts left)" % [plan_name, pod.parts])
	_check(is_equal_approx(float(core.water_cap), 18.0), "the bladder: 18 L kept (%.1f)" % float(core.water_cap))
	_check(not printer.interaction_prompt().has("primary"), "nothing left to print")

	# GAR-Y's sled.
	var gary: Node3D = world.meet_gary(frost.global_position + Vector3(3.0, .3, 0))
	frost.chip_for(2.0)
	_check(_carried(pod) == null and is_equal_approx(float(pod.sled_kg), 12.0), "with the hitch and the pick: 12 kg onto GAR-Y's sled")
	_check(not pod.sled_ready(gary), "out at the hollow, the sled can't be melted")
	gary.global_position = lander.ramp_foot(3.0)
	_check(str(gary.interaction_prompt().get("primary", "")) == "Melt the sled's ice", "by the lander GAR-Y offers its ice")
	before = float(core.water_l)
	gary.interact(player)
	_check(float(core.water_l) > before and pod.sled_kg == 0.0 and pod.jobs.has("tow"), "the sled's ice melts into the tank")

	# The night the walker moves.
	MHGame.sol_hour = 2.5
	await create_timer(.6).timeout
	MHGame.sol_hour = 3.2
	await create_timer(.6).timeout
	_check(pod.walker_moved and world.notes.is_open("night_sound"), "at 03:00 something big moves out on the flats")

	# Saved and loaded.
	player.global_position = iron.global_position + Vector3(0, 1.5, 20.0)
	iron.chip_for(2.0)
	var spots := {}
	for kind in pod.sites: spots[kind] = pod.sites[kind].global_position
	var water_was: float = float(core.water_l)
	var state: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	var again = await _new_world(state)
	var pod2: Node = again.lifepod
	_check(pod2 != null and spots.keys().all(func(k): return pod2.sites[k].global_position.distance_to(spots[k]) < .1), "the threads are where they were")
	_check(pod2 != null and pod2.sites.iron.seen and pod2.parts == 1 and pod2.prints.size() == 3 and pod2.walker_moved, "parts, prints and the walker are kept")
	_check(absf(float(again.cabin_life.core.water_l) - water_was) < .5 and is_equal_approx(float(again.cabin_life.core.water_cap), 18.0), "the water and the bladder are kept")
	await process_frame
	var stripped := again.get_tree().get_nodes_in_group("salvage_piece").filter(func(h): return h.stripped)
	_check(stripped.size() == 4, "the stripped debris stays stripped (%d)" % stripped.size())
	_check(again.get_tree().get_nodes_in_group("carried_find").size() == 1, "the sample you held is still about")
	_check(MHJournal.photographed(pod2.sites.iron.id()), "the photo is kept")
	var kept := MHJournal.entries.filter(func(e): return str(e.get("own", "")).begins_with("Beads"))
	_check(kept.size() == 1 and str((kept[0].photos as Array)[0].caption) == "The iron, from the south", "your note and caption are kept")
	again.queue_free()
	await process_frame
	if failures == 0:
		print("Lifepod test passed: water drains, reads low by sol 2's dawn and hurts when dry; the iron, ice wall and frost placed and seen; chipping needs the hammer; ice melted; samples studied into the journal; salvage and the tiny printer's three prints; GAR-Y's sled; the walker moves at 03:00; a slate photo with its subjects, your own note and caption; saved and loaded.")
	quit(1 if failures > 0 else 0)
