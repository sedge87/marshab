extends SceneTree

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# Samples, the lab and discoveries (docs/samples-lab-journal.md, core-loop
# step 5): rocks typed by the ground and the caves, the six-slot case,
# unloading, lab-only analysis on power with a microscope, leads confirmed by
# different spots, Earth's reply and its unlock, cave readings, research
# points gone under chapter rules, saving, and Creative.
# Run with: godot --headless --path . --script res://tests/samples_lab_test.gd
var failures := 0
var world: Node3D
var _n := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _block(x0: int, z0: int, w: int, d: int) -> Array:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d): cells.append(Vector2i(x, z))
	return cells

func _add(b: BuildController, id: String, cell := Vector2i(0, 0)) -> String:
	_n += 1
	b.placed_interior.append({"placement_id": "s%d" % _n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})
	b.simulation().invalidate()
	return "s%d" % _n

## Run the lab for this many sim hours.
func _run(b: BuildController, hours: float) -> Array:
	var out: Array = []
	var sim := b.simulation()
	var step := .5
	var done := 0.0
	while done < hours:
		sim.hours_run += step
		out.append_array(MHSamples.tick(step, b))
		done += step
	return out

func _ids(messages: Array) -> Array:
	return messages.map(func(m): return str(m.get("id", "")))

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.site_id = "region"
	MHGame.base_site = MHBaseSite.make(-1400.0, 1000.0, "Lab test")
	MHGame.debug_free_power = true
	MHGame.game_mode = "survival"
	MHChapterOne.reset()
	_check(MHSamples.on(), "samples run under chapter rules")

	# ---- rocks come from the ground ----
	var plains := MHSamples.rock_at(Vector3(10.0, 0.0, 10.0))
	_check(["basalt", "vesicular", "dusty", "olivine", "perchlorate_crust", "meteorite"].has(plains), "a plains rock is a plains rock (%s)" % plains)
	_check(MHSamples.rock_at(Vector3(10.0, 0.0, 10.0)) == plains, "the same rock always gives the same answer")
	var finds := {}
	for cave in MHCaves.caves():
		for find in cave.finds:
			var at: Vector3 = (cave.points as PackedVector3Array)[int(find.point)] + Vector3(0, 1.5, 0)
			finds[str(find.id)] = MHSamples.rock_at(at)
	_check(finds.get("mineral_crust", "") == "mineral_crust" and finds.get("fresh_basalt", "") == "fresh_basalt" and finds.get("layered_sediments", "") == "layered_sediments", "cave finds give their own rocks (%s)" % finds)

	# ---- the case ----
	for i in 6: _check(str(MHSamples.take("regolith", Vector2(30.0 * i, 0.0), 1.0).id) == "sample", "bags sample %d" % (i + 1))
	_check(str(MHSamples.take("regolith", Vector2(200.0, 0.0), 1.0).id) == "case_full", "a seventh sample doesn't fit")
	_check(str(MHSamples.drop_last().id) == "dropped" and MHSamples.case_items.size() == 5, "holding I leaves one behind")
	_check(str(MHSamples.case_items[0].unit) == "plains_basalt" and MHSamples.case_items[0].has("rx"), "a record keeps its ground and region position")
	_check(MHSamples.unload() == 5 and MHSamples.case_items.is_empty() and MHSamples.waiting().size() == 5, "unloading empties the case into the store")

	# ---- the lab ----
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	b.zones.append({"kind": "science", "cells": _block(0, 0, 3, 3), "door_direction": Vector2i(0, -1), "cost": 0})
	_check(MHSamples.benches(b).is_empty(), "no lab without a Science Workbench")
	var bench := _add(b, "science_workbench")
	_check(MHSamples.benches(b).size() == 1 and not bool(MHSamples.benches(b)[0].microscope), "a workbench is a bench")
	_add(b, "microscope_station", Vector2i(1, 1))
	_check(bool(MHSamples.benches(b)[0].microscope), "a microscope in the same room helps")
	_check(MHSamples.analysis_hours("regolith", true) < MHSamples.analysis_hours("regolith", false), "the microscope speeds up soil")
	var first := int(MHSamples.waiting()[0].id)
	_check(MHSamples.start_job(bench, first, true).is_empty(), "an analysis starts")
	_check(not MHSamples.start_job(bench, int(MHSamples.waiting()[0].id), true).is_empty(), "one job per bench")
	var said := _run(b, 3.0)
	_check(_ids(said).has("analysed") and _ids(said).has("lead"), "the first perchlorate result is a lead (%s)" % [_ids(said)])
	_check(MHSamples.leads.has("perchlorate_soil"), "the lead is on the terminal")
	# A second from the same spot only agrees; others from new spots confirm.
	MHSamples.take("regolith", Vector2(1.0, 1.0), 4.0)
	MHSamples.unload()
	var same := int(MHSamples.waiting().back().id)
	MHSamples.start_job(bench, same, true)
	_check(_ids(_run(b, 3.0)).has("same_spot"), "a sample from the same spot doesn't confirm")
	for i in 2:
		MHSamples.start_job(bench, int(MHSamples.waiting()[0].id), true)
		said = _run(b, 3.0)
	_check(MHSamples.found.has("perchlorate_soil") and MHSamples.found.has("iron_dust"), "three spots confirm perchlorate and the dust (%s)" % [MHSamples.found.keys()])
	_check(not MHSamples.found.has("soil_water"), "plains soil holds no bound water")
	_check(is_equal_approx(MHSamples.bonus("food"), 1.1) and is_equal_approx(MHSamples.bonus("dust"), .8), "Earth's replies brought the improvements")
	# A discovery's improvement waits for Earth's reply (the light delay).
	MHSamples.discover("basalt", float(b.simulation().hours_run))
	_check(MHSamples.bonus("print") == 1.0, "no improvement before Earth replies")
	said = _run(b, 1.0)
	_check(_ids(said).has("reply") and is_equal_approx(MHSamples.bonus("print"), 1.2), "Earth's reply brings the improvement")
	_check(MHChapterOne.known.has("regolith_shield_block"), "and the plan it unlocks")

	# ---- the old research points are gone under chapter rules ----
	_check(float(b.simulation().daily_flows(false).get("research", 0.0)) == 0.0, "no passive research points under chapter rules")

	# ---- caves and the ground's own finds ----
	var ice := {"id": 900, "kind": "ice_core", "in_cave": true, "depth_m": 0.0, "unit": "ice_cave"}
	_check(MHSamples.findings_for(ice).has("cave_ice"), "cave ice shows in a cave's ice")
	_check(MHSamples.findings_for({"id": 901, "kind": "regolith", "unit": "delta_clays"}).has("soil_water"), "delta soil holds bound water")
	_check(MHSamples.findings_for({"id": 902, "kind": "rock", "rock": "sandstone", "unit": "canyon_layers"}).has("layered_sediments"), "canyon sandstone is evidence for the layers")
	_check(_ids(MHSamples.log_reading("cave_climate", true, 50.0)).has("lead") and MHSamples.log_reading("cave_climate", true, 51.0).is_empty(), "one daytime reading is a lead")
	_check(_ids(MHSamples.log_reading("cave_climate", false, 60.0)).has("discovery"), "a night reading confirms the cave's climate")
	var air_lead: Array = MHSamples.log_reading("mars_air", false, 62.0)
	_check(_ids(air_lead).has("lead") and str(air_lead[0].text).contains("midday"), "a night reading of the open air is a lead, asking for midday")
	MHSamples.log_reading("mars_air", true, 70.0)
	_check(MHSamples.found.has("mars_air") and (MHChapterOne.known.has("atmosphere_processor") or MHChapterOne.learn_after("discovery:mars_air").has("atmosphere_processor")), "day and night air readings bring the atmosphere processor's plan (with Earth's reply)")

	# ---- saving ----
	var saved := MHSamples.export_state()
	var found_before := MHSamples.found.size()
	MHSamples.reset()
	MHSamples.load_state(JSON.parse_string(JSON.stringify(saved)))
	_check(MHSamples.found.size() == found_before and MHSamples.readings.has("cave_climate") and MHSamples.archive().size() == saved.store.size() - MHSamples.waiting().size(), "samples, discoveries and readings save and load")

	# ---- the journal ----
	MHJournal.reset()
	MHJournal.write("landed", 1, {"where": "the basalt plains"})
	MHJournal.write("landed", 1, {"where": "the basalt plains"})
	MHJournal.from_messages([MHSamples.take("rock", Vector2(5.0, 5.0), 30.0, {"rock": "basalt"})], 2)
	MHJournal.from_messages([{"id": "discovery", "title": "Discovery: Basalt bedrock"}, {"id": "lead", "title": "Lead: The bedrock looks volcanic"}], 2)
	_check(MHJournal.entries.size() == 2 and (MHJournal.entries[0].lines as Array).size() == 1, "a once-a-sol line is written once (%s)" % [MHJournal.entries])
	_check((MHJournal.entries[1].lines as Array).size() == 3 and str(MHJournal.entries[1].lines[0]).contains("basalt plains"), "samples, a discovery and a lead are the next sol's lines (%s)" % [MHJournal.entries[1].lines])
	_check(not MHJournal.wants_sketch.is_empty(), "new ground asks for a sketch")
	MHJournal.add_sketch(2, "user://journal/test/none.png", "The basalt plains")
	var journal: Dictionary = JSON.parse_string(JSON.stringify(MHJournal.export_state()))
	MHJournal.reset()
	MHJournal.load_state(journal)
	_check(MHJournal.entries.size() == 2 and (MHJournal.entries[1].sketches as Array).size() == 1, "the journal saves and loads")
	var book: Control = load("res://scripts/journal_book.gd").new()
	root.add_child(book)
	await process_frame
	_check(book.page == 1 and book._turn.text.contains("Sol 2"), "the book opens on the newest sol (%s)" % book._turn.text)
	book.queue_free()

	# ---- Creative keeps samples, so the story still runs (docs/game-modes.md) ----
	MHGame.game_mode = "creative"
	MHChapterOne.reset()
	_check(MHSamples.on() and not MHChapterOne.on() and MHSamples.bonus("food") == 1.0, "Creative keeps samples and the Discoveries, without the crates")

	MHGame.base_site = {}
	MHGame.debug_free_power = false
	if failures == 0: print("Samples and lab test passed: rocks by ground and cave, the case, the lab and microscope, leads and confirmation, Earth's reply, cave readings, no research points, saving and Creative.")
	else: print("Samples and lab test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
