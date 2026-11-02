extends SceneTree

const MHResources := preload("res://scripts/mh_resources.gd")

# The start and chapter one (docs/start-and-chapter-one.md, core-loop step 4):
# unpacking crates, no tonnes budget, plan gating, a fabricator job, the
# stores and soft net, cores, the four steps, Freedom and Creative, old saves.
# Run with: godot --headless --path . --script res://tests/start_and_chapter_one_test.gd
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

func _builder() -> BuildController:
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	return b

func _add(b: BuildController, id: String, cell := Vector2i(0, 0)) -> void:
	_n += 1
	b.placed_interior.append({"placement_id": "c%d" % _n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})
	b.simulation().invalidate()

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.site_id = "plains"
	MHGame.debug_free_power = true

	# ---- off by default, on for a new Survival game ----
	MHGame.game_mode = "survival"
	_check(not MHChapterOne.on(), "chapter rules stay off until a new game starts")
	MHChapterOne.reset()
	_check(MHChapterOne.on(), "a new Survival game uses chapter-one rules")
	_check(MHGame.cargo_budget() == 0, "no tonnes budget before the shells crate (%d)" % MHGame.cargo_budget())

	# ---- unpacking ----
	var b := _builder()
	b.zones.append({"kind": "general", "cells": _block(0, 0, 3, 3), "door_direction": Vector2i(0, -1), "cost": 0})
	_check(MHChapterOne.item_reason("crew_bunk", b) == "Print the first one at the Print Shop", "a bunk needs stock before the crates are unpacked (%s)" % MHChapterOne.item_reason("crew_bunk", b))
	for crate in MHChapterOne.crates(): _check(MHChapterOne.unpack(str(crate.id)), "unpacks %s" % crate.id)
	_check(not MHChapterOne.unpack("shells"), "a crate unpacks once")
	_check(MHChapterOne.crates_left() == 0, "all crates unpacked")
	_check(MHGame.cargo_budget() == 12000, "the hull kit is the Earth budget (%d)" % MHGame.cargo_budget())
	_check(MHChapterOne.has_corer and is_equal_approx(MHChapterOne.feedstock_kg, 3000.0), "corer and feedstock unpacked")
	_check(MHChapterOne.available("crew_bunk", b) == 2, "two sleep stations ready")
	_check(MHChapterOne.item_reason("crew_bunk", b).is_empty(), "an unpacked bunk can be placed")
	_check(b.earth_cost(100, false) == 0 and b.earth_cost(100, true) == 100, "equipment costs no Earth cargo; printable things still do")
	_add(b, "crew_bunk"); _add(b, "crew_bunk")
	_check(MHChapterOne.available("crew_bunk", b) == 0 and MHChapterOne.item_reason("crew_bunk", b) == "Print the first one at the Print Shop", "both bunks placed: crate copies don't make the plan")
	_check(MHChapterOne.ready_to_place(b).has("fabricator") and not MHChapterOne.ready_to_place(b).has("crew_bunk"), "the Unpacked list follows what's placed")
	_check(MHChapterOne.zone_reason("airlock", b).is_empty() and MHChapterOne.zone_reason("ice_extractor", b).begins_with("Plan:"), "an airlock is unpacked; the ice extractor needs its plan")

	# ---- plans ----
	_check(MHChapterOne.plan_known("crew_bunk") and not MHChapterOne.plan_known("ice_drill") and not MHChapterOne.plan_known("oxygen_generator"), "basics are brought; self-sufficiency plans are earned")
	_check(not MHChapterOne.needs_stock("cargo_rack") and not MHChapterOne.needs_stock("crew_mug"), "printable things and odds and ends need no plan")
	_check(not MHChapterOne.fabricable().has("ice_drill") and MHChapterOne.fabricable().has("crew_bunk"), "the fabricator lists known plans only")

	# ---- a fabricator job ----
	_check(MHChapterOne.job_reason("crew_bunk", b) == "Place the Print Shop first", "no job without a fabricator")
	_add(b, "fabricator", Vector2i(1, 1))
	_check(is_equal_approx(MHChapterOne.fabricator_speed(b), .75), "the General Module runs it at 75 %")
	var cost := MHChapterOne.plan_cost("crew_bunk")
	_check(MHChapterOne.start_job("crew_bunk", b).is_empty(), "a job starts")
	_check(MHChapterOne.start_job("crew_bunk", b) == "Already printing", "a plan prints once at a time")
	var printer := MHChapterOne._printer(b, "")
	_check(MHChapterOne.start_job(MHChapterOne.SPARES_KIT, b).is_empty() and (MHChapterOne.printer_work(printer).queue as Array).size() == 1, "a busy printer queues the next plan, unpaid")
	MHChapterOne.unqueue(printer, 0)
	_check((MHChapterOne.printer_work(printer).queue as Array).is_empty(), "a queued plan comes off for nothing")
	_check(float(cost.hours) <= .5, "a sleep station prints in minutes (%.2f h)" % float(cost.hours))
	_check(is_equal_approx(MHChapterOne.feedstock_kg, 3000.0 - float(cost.feedstock_kg)), "the job takes its feedstock")
	b.simulation().last = {"generation_kw": 5.0, "crew": 0}
	MHChapterOne.tick(float(cost.hours) / .75 + .1, b)
	_check(not MHChapterOne.printing() and MHChapterOne.available("crew_bunk", b) == 1, "the bunk is made and ready to place")
	_check(MHChapterOne.known.has("spare_parts_rack"), "the first job brings a sent plan")
	_check(MHChapterOne.made.has("crew_bunk") and MHChapterOne.job_reason("crew_bunk", b) == "Already made: place it from the build bar", "the first job makes the plan; no second job")
	_check(MHChapterOne.on_build_bar(b).has("crew_bunk"), "a made item stays on the Unpacked tab")

	# ---- copies after the first: paid as they're placed ----
	_add(b, "crew_bunk")
	var before := MHChapterOne.feedstock_kg
	_check(MHChapterOne.available("crew_bunk", b) == 0 and MHChapterOne.item_reason("crew_bunk", b).is_empty(), "with the first one placed, another can still go down")
	_check(is_equal_approx(MHChapterOne.feedstock_kg, before), "placing the free copy costs nothing")
	_check(MHChapterOne.on_build_bar(b).has("crew_bunk") and MHChapterOne.card_line("crew_bunk", b).ends_with("kg"), "the card shows the per-copy cost (%s)" % MHChapterOne.card_line("crew_bunk", b))
	_add(b, "crew_bunk")
	MHChapterOne.settle(b)
	_check(is_equal_approx(MHChapterOne.feedstock_kg, before - float(cost.feedstock_kg)), "an extra copy takes its feedstock")
	b.placed_interior.pop_back()
	MHChapterOne.settle(b)
	_check(is_equal_approx(MHChapterOne.feedstock_kg, before), "removing it gives it back")
	var keep_feed := MHChapterOne.feedstock_kg
	MHChapterOne.feedstock_kg = 1.0
	_check(MHChapterOne.item_reason("crew_bunk", b).begins_with("Needs"), "short of feedstock, it says what's missing (%s)" % MHChapterOne.item_reason("crew_bunk", b))
	MHChapterOne.feedstock_kg = keep_feed
	var old_save := MHChapterOne.export_state()
	old_save.erase("made")
	MHChapterOne.load_state(old_save, true)
	_check(MHChapterOne.made.has("crew_bunk") and not MHChapterOne.made.has("fabricator"), "an older save counts what the fabricator made, not crate copies")
	var parts_save := MHChapterOne.export_state()
	parts_save["earth_parts"] = 12
	MHChapterOne.load_state(parts_save, true)
	_check(is_equal_approx(MHChapterOne.feedstock_kg, keep_feed + MHChapterOne.OLD_SAVE_TOP_UP), "a save from when printing took Earth parts gets the bigger crate's feedstock")
	MHChapterOne.feedstock_kg = keep_feed
	# Feedstock from Mars: a running regolith intake makes it.
	var intake_sim: RefCounted = b.simulation()
	_check(is_equal_approx(intake_sim.feedstock_rate({"intakes": 2}), 120.0) and intake_sim.feedstock_rate({"intakes": 0}) == 0.0, "each running regolith intake makes 60 kg of feedstock a sol")

	# ---- stores ----
	var sim: RefCounted = b.simulation()
	var stores := MHChapterOne.stores_for(MHChapterOne.store_sols())
	_check(is_equal_approx(float(stores.food_kg), 1.0 * 1.8 * 90.0), "Survival stores: 90 sols for you alone (%s)" % stores)
	sim.invalidate(); sim.inventory()
	_check(MHChapterOne.stores_landed and float(sim.food_kg) >= float(stores.food_kg) - .1 and float(sim.water_l) >= float(stores.water_l) - .1, "the landed stores arrive with the crew")
	sim.last = {"crew": 1, "water_out": 10.0, "water_in": 0.0, "o2_in": 0.0, "food_in": 0.0, "generation_kw": 5.0}
	var left := MHChapterOne.sols_left(sim)
	_check(float(left.food) > 80.0 and float(left.food) < 100.0, "food shown as sols left (%s)" % left)
	sim.food_kg = 0.0
	var news := MHChapterOne.tick(.5, b)
	_check(MHChapterOne.reserve_used and float(sim.food_kg) > 15.0 and news.any(func(m): return str(m.id) == "reserve"), "running out opens the contingency reserve")
	_check(MHChapterOne.emergency_eta > 0.0, "and an emergency lander is sent")
	sim.hours_run = MHChapterOne.emergency_eta + 1.0
	news = MHChapterOne.tick(.5, b)
	_check(news.any(func(m): return str(m.id) == "emergency_landed") and MHChapterOne.emergency_eta < 0.0, "the emergency lander brings more stores")

	# ---- cores and the four steps ----
	var dry := MHChapterOne.core_at(Vector2.ZERO, .05)
	var good := MHChapterOne.core_at(Vector2.ZERO, .5)
	_check(bool(dry.dry) and not bool(dry.good), "a thin core comes up dry")
	_check(bool(good.good) and float(good.depth_m) < float(MHChapterOne.core_at(Vector2.ZERO, .3).depth_m), "richer ice is shallower")
	var ice_knowledge := preload("res://scripts/ice_knowledge.gd")
	var readings := [Vector3(40, -40, .2)]
	_check(ice_knowledge.surveyed(readings, Vector2(44, -42)) and not ice_knowledge.surveyed(readings, Vector2(10, 10)) and not ice_knowledge.surveyed([], Vector2(40, -40)), "cores only on ground GAR-Y has surveyed")
	_check(not MHChapterOne.rover_landed(), "the crew rover waits for a later lander")
	MHChapterOne.ice_found(10.0)
	_check(MHChapterOne.made.has("ice_drill") and int(MHChapterOne.stock.get("ice_drill", 0)) == 1, "a plan the story gives arrives printed")
	_check(MHChapterOne.plan_known("ice_drill") and MHChapterOne.rover_landed(), "a good core earns the Ice Extractor plan, and the rover comes")
	# The extractor drills where a core found ice, not anywhere ice happens to be.
	var deposit: Dictionary = MHGame.site().get("ice_deposits", [{}])[0]
	var rich := Vector2(float(deposit.get("x", 0.0)), float(deposit.get("z", 0.0)))
	var cores_before := MHChapterOne.cores.duplicate()
	MHChapterOne.cores.clear()
	_check(b._extractor_ice_reason(rich).begins_with("Drill where a core found ice"), "no extractor without a core there")
	MHChapterOne.record_core(MHChapterOne.core_at(rich + Vector2(4, 0), .5))
	_check(b._extractor_ice_reason(rich).is_empty(), "an extractor beside a core that found ice")
	MHChapterOne.cores = cores_before
	MHChapterOne.stock["ice_drill"] = 1
	b.zones.append({"kind": "ice_extractor", "cells": [Vector2i(10, 10)], "cost": 450})
	sim.last = {"crew": 2, "water_in": 30.0, "raw_in": 30.0, "water_out": 20.0, "o2_in": 0.0, "food_in": 0.0, "generation_kw": 5.0}
	MHChapterOne.tick(MHChapterOne.WATER_TEST_HOURS + 1.0, b)
	_check(MHChapterOne.plan_known("water_reclaimer"), "the extractor's meltwater is tested: Water Processor plan")
	MHChapterOne.stock["water_reclaimer"] = 1
	_add(b, "water_reclaimer")
	MHChapterOne.tick(.5, b)
	_check(MHChapterOne.steps.has("water") and MHChapterOne.plan_known("oxygen_generator"), "water self-sufficient, then the oxygen plan")
	sim.last.o2_in = 2.0
	MHChapterOne.tick(.5, b)
	_check(MHChapterOne.steps.has("oxygen"), "oxygen self-sufficient")
	_check(MHChapterOne.bench_action().is_empty() and not MHChapterOne.bag_soil().is_empty(), "a core after the oxygen step bags regolith")
	sim.water_l = 100.0
	MHChapterOne.bench_use(sim, float(sim.hours_run))
	_check(MHChapterOne.soil == "washed" and is_equal_approx(float(sim.water_l), 100.0 - MHChapterOne.WASH_WATER_L), "the bench washes it with water")
	MHChapterOne.bench_use(sim, float(sim.hours_run))
	MHChapterOne.tick(1.0, b)
	_check(MHChapterOne.soil == "potted" and not MHChapterOne.plan_known("grow_tray"), "a test seed takes a sol")
	sim.hours_run = float(sim.hours_run) + MHChapterOne.SOIL_TEST_HOURS + 1.0
	MHChapterOne.tick(.5, b)
	_check(MHChapterOne.plan_known("grow_tray"), "the seedling comes up: the food plans")
	sim.last.food_in = 4.0
	news = MHChapterOne.tick(.5, b)
	_check(MHChapterOne.finished_at >= 0.0 and news.any(func(m): return str(m.id) == "chapter_one"), "all four steps end chapter one with a report")

	# ---- saving ----
	var saved := MHChapterOne.export_state()
	MHChapterOne.reset()
	MHChapterOne.load_state(saved, true)
	_check(MHChapterOne.finished_at >= 0.0 and MHChapterOne.has_corer and MHChapterOne.unpacked.size() == MHChapterOne.crates().size(), "chapter one saves and loads")
	MHChapterOne.load_state({}, false)
	_check(MHChapterOne.older_rules and not MHChapterOne.on() and MHGame.cargo_budget() > 50000, "a save from before step 4 plays as already supplied")

	# ---- modes ----
	MHChapterOne.reset()
	MHGame.game_mode = "freedom"
	_check(MHChapterOne.on() and MHChapterOne.plan_known("ice_drill") and is_equal_approx(MHChapterOne.store_sols(), 150.0), "Freedom: crates, all plans known, 150 sols of stores")
	MHGame.game_mode = "creative"
	_check(not MHChapterOne.on(), "Creative is unchanged")
	MHGame.game_mode = "survival"
	MHChapterOne.older_rules = true

	print("Start and chapter one test %s." % ("passed: unpacking, no tonnes, plans, a fabricator job, stores and the soft net, cores, the four steps, saving, old saves and the modes" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures > 0 else 0)
