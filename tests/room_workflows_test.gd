extends SceneTree

# A5, room workflows and the four materials (docs/rooms-and-equipment.md
# "As built (A5)"; scripts/materials.gd, scripts/greenhouse.gd, samples.gd):
# - materials: a new game's metal and salvage, plans that need them, what's
#   short, paid when placed and given back; an older save gets a full store;
# - the Lab's chain: a new kind of find goes round the stations by hand
#   (saw, then microscope, then spectrometer), in order; short of a station
#   it's a partial read, and that brings Tupou's plan for it; after that the
#   workbench runs the kind by itself, and a partial read can go again;
# - iron-rich rock: only once the Lab has named it, three break-offs a rock,
#   30 kg in the suit, into the store at base; the smelter's plan after the
#   find, the first batch by hand, then it smelts by itself (and regolith
#   when there's plenty);
# - the Greenhouse: planters wait for washed soil, the washer's first batch
#   by hand, then it keeps some ready; the first harvest of a crop by hand,
#   then the cart; the food step also at the washer;
# - the repair bench: a kind of machine serviced by hand once, then the
#   bench in a Workshop sees to it;
# - saved and loaded.
# godot --headless --path . --script res://tests/room_workflows_test.gd
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
	b.placed_interior.append({"placement_id": "w%d" % _n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})
	b.simulation().invalidate()
	return "w%d" % _n

func _run(b: BuildController, hours: float) -> Array:
	var out: Array = []
	var sim := b.simulation()
	var done := 0.0
	while done < hours:
		sim.hours_run += .5
		out.append_array(MHSamples.tick(.5, b))
		out.append_array(MHChapterOne.tick(.5, b))
		done += .5
	return out

func _ids(messages: Array) -> Array:
	return messages.map(func(m): return str(m.get("id", "")))

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.site_id = "region"
	MHGame.base_site = MHBaseSite.make(-1400.0, 1000.0, "Workflows test")
	MHGame.debug_free_power = true
	MHGame.game_mode = "survival"
	MHChapterOne.reset()
	MHSamples.science_open = true
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)

	# ---------- materials ----------
	_check(is_equal_approx(MHMaterials.metal_kg, MHMaterials.START_METAL) and is_equal_approx(MHMaterials.salvage_kg, MHMaterials.START_SALVAGE), "a new game starts with some metal and salvage")
	var cost := MHChapterOne.plan_cost("ice_drill")
	_check(float(cost.metal_kg) > 0.0 and float(cost.salvage_kg) > 0.0, "the ice extractor needs metal and salvage (%s)" % cost)
	_check(MHMaterials.cost_line(cost).contains("metal"), "its card says so (%s)" % MHMaterials.cost_line(cost))
	MHChapterOne.feedstock_kg = 5000.0
	MHMaterials.metal_kg = 5.0
	_check(MHMaterials.short_of(cost).contains("metal"), "short of metal, it says so (%s)" % MHMaterials.short_of(cost))
	MHMaterials.metal_kg = 500.0; MHMaterials.salvage_kg = 500.0
	b.zones.append({"kind": "engineering", "cells": _block(0, 10, 3, 3), "door_direction": Vector2i(0, -1), "cost": 0, "base": "w1", "y": 0.0})
	var shop := _add(b, "fabricator", Vector2i(0, 10))
	MHChapterOne.known["ice_drill"] = "discovered"
	_check(MHChapterOne.start_job("ice_drill", b, shop).is_empty(), "with enough of each, it prints")
	_check(is_equal_approx(MHMaterials.metal_kg, 500.0 - float(cost.metal_kg)), "the job takes its metal")
	MHChapterOne.cancel_job(b, shop)
	_check(is_equal_approx(MHMaterials.metal_kg, 500.0) and is_equal_approx(MHMaterials.salvage_kg, 500.0), "cancelled, it gives it back")
	var old_state := MHChapterOne.export_state()
	old_state.erase("materials")
	old_state.erase("greenhouse")
	MHChapterOne.load_state(old_state, true)
	_check(is_equal_approx(MHMaterials.metal_kg, MHMaterials.OLD_SAVE_KG) and MHChapterOne.known.has("microscope_station") and MHGreenhouse.washed_by_hand, "a save from before A5 gets a full store, the Lab's plans and its greenhouse as it was")
	MHChapterOne.reset()
	MHSamples.science_open = true
	MHChapterOne.feedstock_kg = 5000.0
	MHMaterials.metal_kg = 500.0; MHMaterials.salvage_kg = 500.0

	# ---------- the Lab's chain ----------
	b.zones.append({"kind": "science", "cells": _block(0, 0, 3, 3), "door_direction": Vector2i(0, -1), "cost": 0, "base": "w1", "y": 0.0})
	var bench := _add(b, "science_workbench")
	_add(b, "rock_saw", Vector2i(1, 0))
	_check(MHSamples.bench_stations(b, bench) == ["rock_saw"], "the Lab starts with the saw (%s)" % [MHSamples.bench_stations(b, bench)])
	_check(not MHChapterOne.plan_known("microscope_station") and not MHChapterOne.plan_known("spectrometer"), "no microscope or spectrometer plan yet")
	MHSamples.take("rock", Vector2(100.0, 0.0), 1.0, {"rock": "hematite"})
	MHSamples.unload()
	var rock := int(MHSamples.waiting()[0].id)
	_check(MHSamples.needs_hands(MHSamples.sample(rock)) and not MHSamples.start_job(bench, rock, false).is_empty(), "a new kind of find won't go on the bench by itself")
	_check(MHSamples.start_hand(bench, rock).is_empty() and MHSamples.waiting().is_empty(), "you take it in hand")
	var have := MHSamples.bench_stations(b, bench)
	_check(MHSamples.step_action("rock_saw") == "Cut the sample", "E at the saw cuts it")
	_check(_ids(MHSamples.do_step("rock_saw", have)).has("step") and (MHSamples.hand.done as Array).has("rock_saw"), "cut")
	var said := MHSamples.finish_hand(1.0)
	var record := MHSamples.sample(rock)
	_check(_ids(said).has("partial") and MHSamples.is_partial(record) and (record.partial as Array).has("microscope_station"), "short of a microscope: a partial read (%s)" % [_ids(said)])
	_check(MHChapterOne.known.has("microscope_station") and MHChapterOne.known.has("spectrometer"), "Tupou's plans for both come with it")
	_check(MHChapterOne.available("microscope_station", b) == 1, "the first microscope arrives printed")
	_check(not MHSamples.needs_hands(record) and MHSamples.waiting().size() == 1, "done by hand once; the partial read waits to go again")
	_add(b, "spectrometer", Vector2i(2, 0))
	_add(b, "microscope_station", Vector2i(1, 1))
	_check(MHSamples.bench_stations(b, bench) == MHSamples.CHAIN, "the chain in order (%s)" % [MHSamples.bench_stations(b, bench)])
	# A second hematite sample from elsewhere: the bench runs it by itself now.
	MHSamples.take("rock", Vector2(300.0, 0.0), 2.0, {"rock": "hematite"})
	MHSamples.unload()
	_check(MHSamples.start_job(bench, rock, false).is_empty(), "the partial one goes again on the bench")
	said = _run(b, 6.0)
	_check(not MHSamples.is_partial(MHSamples.sample(rock)) and (MHSamples.sample(rock).findings as Array).has("hematite"), "with every station, the full read (%s)" % [MHSamples.sample(rock).get("findings")])
	var second := int(MHSamples.waiting()[0].id)
	_check(MHSamples.start_job(bench, second, false).is_empty(), "a known kind goes straight on the bench")
	said = _run(b, 6.0)
	_check(MHSamples.found.has("hematite"), "two spots confirm the hematite")
	_run(b, 1.0)
	_check(MHChapterOne.known.has("smelter"), "Achterberg's smelter plan follows the find")
	# By hand, the order matters.
	MHSamples.take("rock", Vector2(500.0, 0.0), 3.0, {"rock": "gypsum"})
	MHSamples.unload()
	MHSamples.start_hand(bench, int(MHSamples.waiting()[0].id))
	_check(str(MHSamples.do_step("spectrometer", MHSamples.CHAIN)[0].title).contains("first"), "the spectrometer waits for the saw and the microscope")
	MHSamples.do_step("rock_saw", MHSamples.CHAIN); MHSamples.do_step("microscope_station", MHSamples.CHAIN); MHSamples.do_step("spectrometer", MHSamples.CHAIN)
	said = MHSamples.finish_hand(4.0)
	_check(_ids(said).has("analysed") and _ids(said).has("learned"), "all three by hand: a full read, and the kind is learned")

	# ---------- iron-rich rock and the smelter ----------
	_check(MHMaterials.known_rock("hematite") and MHMaterials.pull_reason("hematite", "r1").is_empty(), "hematite the Lab has named can be broken off")
	_check(MHMaterials.pull_reason("meteorite", "r2") == "not_ore", "not before the Lab has named it")
	for i in 3: MHMaterials.pull("hematite", "r1")
	_check(not MHMaterials.pull_reason("hematite", "r1").is_empty() and is_equal_approx(MHMaterials.carried_kg(), 30.0), "three break-offs a rock, 30 kg in the suit")
	_check(MHMaterials.pull_reason("hematite", "r3").contains("carry"), "the suit is full")
	_check(_ids(MHMaterials.unload()).has("ore_in") and is_equal_approx(MHMaterials.ore_kg(), 30.0) and MHMaterials.carried.is_empty(), "inside, it goes into the store")
	_add(b, "smelter", Vector2i(1, 11))
	_check(MHMaterials.smelters(b).size() == 1 and MHMaterials.smelter_action() == "Smelt the first batch", "a smelter in the Workshop: the first batch by hand")
	var metal := MHMaterials.metal_kg
	MHMaterials.tick(24.0, b, true)
	_check(is_equal_approx(MHMaterials.metal_kg, metal), "not by itself before that")
	_check(str(MHMaterials.smelt_by_hand().id) == "smelt" and is_equal_approx(MHMaterials.metal_kg, metal + 5.0), "10 kg of hematite makes 5 kg of metal")
	MHMaterials.tick(12.0, b, true)
	_check(MHMaterials.ore_kg() < 20.0 - 1.0 and MHMaterials.metal_kg > metal + 5.0, "then it works through the store by itself")
	MHMaterials.tick(48.0, b, true)
	var feed := MHChapterOne.feedstock_kg
	MHMaterials.tick(24.0, b, true)
	_check(is_equal_approx(MHMaterials.ore_kg(), 0.0) and MHChapterOne.feedstock_kg < feed, "with the rock used up, it smelts regolith")
	MHChapterOne.feedstock_kg = 200.0
	MHMaterials.tick(24.0, b, true)
	_check(is_equal_approx(MHChapterOne.feedstock_kg, 200.0), "but never the printers' last few hundred kilos")
	MHChapterOne.feedstock_kg = 5000.0

	# ---------- the Greenhouse ----------
	var sim := b.simulation()
	sim.water_l = 500.0
	b.zones.append({"kind": "hydroponics", "cells": _block(0, 20, 3, 3), "door_direction": Vector2i(0, -1), "cost": 0, "base": "w1", "y": 0.0})
	var planter := _add(b, "greenhouse_planter", Vector2i(0, 20))
	var inv: Dictionary = sim.inventory()
	sim.food.step(24.0, inv, {}, 0)
	_check(is_equal_approx(float(sim.food.tray(planter).growth), 0.0) and sim.food.status(planter).contains("washed soil"), "a planter waits for washed soil (%s)" % sim.food.status(planter))
	_add(b, "regolith_washer", Vector2i(1, 21))
	_check(MHGreenhouse.washer_action(b) == "Wash a first batch of soil", "the washer's first batch, by hand")
	_check(_ids(MHGreenhouse.washer_use(b)).has("wash") and is_equal_approx(MHGreenhouse.soil_kg, MHGreenhouse.FIRST_BATCH_KG), "washed: a planter's worth")
	inv = sim.inventory()
	sim.food.step(24.0, inv, {}, 0)
	_check(float(sim.food.tray(planter).growth) > 0.0, "the planter takes it and grows")
	_check(MHGreenhouse.soil_kg > 0.0, "and the washer keeps some ready by itself (%.1f kg)" % MHGreenhouse.soil_kg)
	_add(b, "harvest_cart", Vector2i(2, 20))
	sim.food.tray(planter).growth = 1.0
	inv = sim.inventory()
	sim.food.step(1.0, inv, {}, 0)
	_check(float(sim.food.tray(planter).growth) >= 1.0, "the cart leaves a crop you haven't picked by hand")
	_check(str(sim.food.harvest(planter).title).begins_with("First"), "the first harvest, by hand")
	sim.food.tray(planter).growth = 1.0
	sim.food.step(1.0, inv, {}, 0)
	_check(float(sim.food.tray(planter).growth) < 1.0, "after that the cart picks it")
	MHChapterOne.steps["oxygen"] = 1.0
	MHChapterOne.soil = "bagged"
	_check(MHGreenhouse.washer_action(b) == "Wash the regolith sample", "chapter one's food step works at the washer too")

	# ---------- the repair bench ----------
	b.zones.append({"kind": "life_support", "cells": _block(0, 30, 2, 2), "door_direction": Vector2i(0, -1), "cost": 0, "base": "w1", "y": 0.0})
	var reclaimer := _add(b, "water_reclaimer", Vector2i(0, 30))
	sim.life.spares = 5
	sim.wear.wear[reclaimer] = .8
	_check(not str(sim.wear.service(reclaimer, "water_reclaimer").text).is_empty() and sim.wear.by_hand.has("water_reclaimer"), "serviced by hand once")
	sim.wear.wear[reclaimer] = .8
	inv = sim.inventory()
	sim.wear.step(.1, inv, {})
	_check(sim.wear.level(reclaimer) > .7, "with no repair bench, it waits")
	_add(b, "tool_bench", Vector2i(2, 12))
	inv = sim.inventory()
	sim.wear.step(.01, inv, {})   # the first step also lands Earth's kits
	sim.wear.wear[reclaimer] = .8
	var kits := int(sim.life.spares)
	sim.wear.step(.01, inv, {})
	_check(sim.wear.level(reclaimer) < .1 and int(sim.life.spares) == kits - 1, "a repair bench in the Workshop services it, with a kit")

	# ---------- saved and loaded ----------
	var saved: Dictionary = JSON.parse_string(JSON.stringify(MHChapterOne.export_state()))
	var samples: Dictionary = JSON.parse_string(JSON.stringify(MHSamples.export_state()))
	var metal_now := MHMaterials.metal_kg
	var soil_now := MHGreenhouse.soil_kg
	MHChapterOne.reset()
	MHChapterOne.load_state(saved, true)
	MHSamples.load_state(samples)
	_check(is_equal_approx(MHMaterials.metal_kg, metal_now) and MHMaterials.smelted_by_hand and is_equal_approx(MHGreenhouse.soil_kg, soil_now) and MHGreenhouse.picked_by_hand.has("greens"), "materials and the greenhouse save and load")
	_check(MHSamples.learned.has("rock:hematite") and not MHSamples.needs_hands({"kind": "rock", "rock": "gypsum"}), "what's been done by hand is kept")

	MHGame.base_site = {}
	MHGame.debug_free_power = false
	if failures == 0: print("Room workflows test passed: metal and salvage in the plans, short, paid and refunded, old saves; the Lab by hand station by station, partial reads and Tupou's plans, then the bench by itself; iron-rich rock carried home and the smelter (by hand, then itself, regolith with a reserve); planters on washed soil, the washer and the first harvest by hand, then the cart; the repair bench; saving.")
	else: print("Room workflows test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
