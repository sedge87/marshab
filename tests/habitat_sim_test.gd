extends SceneTree

# The life-support simulation (scripts/habitat_sim.gd): a sensible habitat
# survives day and night; missing equipment causes the right problem with the
# right reason; storms shed loads with life support last; Freedom never harms
# the crew; stores save and load; cargo comes from the balance spreadsheet.
# Run with: godot --headless --path . --script res://tests/habitat_sim_test.gd
const MHResources := preload("res://scripts/mh_resources.gd")
var failures := 0
var world: Node3D

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _block(x0: int, z0: int, w: int, d: int) -> Array:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d): cells.append(Vector2i(x, z))
	return cells

## A compact six-crew habitat with the given equipment counts.
func _habitat(site: String, solar: int, items: Dictionary) -> BuildController:
	MHGame.site_id = site
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	var layout := [["living", 0, 0, 3, 3], ["galley", 3, 0, 3, 1], ["hygiene", 3, 1, 2, 1], ["science", 3, 2, 2, 2], ["hydroponics", 0, 3, 3, 2], ["life_support", 3, 4, 2, 2], ["engineering", 5, 1, 1, 3], ["airlock", 6, 1, 1, 2]]
	for spec in layout: b.zones.append({"kind": spec[0], "cells": _block(spec[1], spec[2], spec[3], spec[4]), "door_direction": Vector2i(0, -1), "cost": 0})
	for i in range(solar): b.zones.append({"kind": "solar", "cells": [Vector2i(-2 - i, -2)], "door_direction": Vector2i(0, 1), "cost": 0})
	var n := 0
	for id in items:
		var room: String = items[id][0]
		var cell := Vector2i.ZERO
		for zone in b.zones:
			if str(zone.kind) == room: cell = zone.cells[0]
		for k in range(int(items[id][1])):
			n += 1
			b.placed_interior.append({"placement_id": "t%d" % n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})
	b.simulation().invalidate()
	return b

func _full_kit() -> Dictionary:
	return {"crew_bunk": ["living", 6], "air_recycler": ["life_support", 2], "oxygen_generator": ["life_support", 2], "thermal_control_unit": ["life_support", 2], "oxygen_reserve_tank": ["life_support", 1],
		"water_reclaimer": ["life_support", 1], "grow_tray": ["hydroponics", 6], "battery_bank": ["engineering", 6], "pantry_cabinet": ["galley", 2]}

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.game_mode = "survival"
	MHGame.debug_free_power = false

	# A sensible habitat on the plains keeps everything running for three sols.
	var good := _habitat("plains", 6, _full_kit())
	var sim: RefCounted = good.simulation()
	sim.random_storms = false   # storms are tested on their own below, not left to chance
	_check(int(sim.crew_count()) == 6, "six bunks bring six crew in (got %d)" % sim.crew_count())
	_check(is_equal_approx(float(sim.battery_kwh), 300.0), "new batteries arrive charged")
	_check(float(sim.food_kg) > 0.0, "the lander delivers food when the crew move in")
	var samples: Array = sim.run_hours(72.0, 8.0, 1.0)
	var life_always := samples.all(func(s): return float(s.battery_pct) > 0.0 or bool(s.all_powered))
	_check(life_always, "the batteries carry the habitat through every night")
	_check(float(sim.co2_pct) < .5 and float(sim.o2_pct) > 20.0, "air stays healthy: O2 %.1f%%, CO2 %.2f%%" % [sim.o2_pct, sim.co2_pct])
	_check(float(sim.crew_health) >= 99.0, "the crew stay healthy (%.0f%%)" % sim.crew_health)
	var living := float(sim.room_temperature(good.zones[0]))
	_check(living > 17.0 and living < 24.0, "Living Quarters stays comfortable (%.1f °C)" % living)
	var readiness := good.readiness()
	var air_item: Dictionary = readiness.filter(func(i): return i.id == "life")[0]
	_check(str(air_item.status) == "met", "readiness: air is covered (%s)" % air_item.detail)

	# Save and load keeps every store.
	var saved: Dictionary = sim.save()
	var copy := _habitat("plains", 6, _full_kit())
	copy.simulation().load(saved)
	_check(is_equal_approx(float(copy.simulation().battery_kwh), float(sim.battery_kwh)) and is_equal_approx(float(copy.simulation().food_kg), float(sim.food_kg)), "stores survive save and load")

	# The chain stores (docs/survival-systems.md §9 phase 1).
	_check(float(sim.stores.grey_l) < 20.0 and not (sim.last.vented as Dictionary).has("grey_l"), "with a water processor grey water is cleaned as it's made (%.0f L, no grey water vented)" % sim.stores.grey_l)
	_check(float(sim.stores.co2_kg) > 0.0 and float(sim.stores.h2_kg) > 0.0, "scrubbed CO2 and the oxygen generator's hydrogen are kept (%.1f, %.2f kg)" % [sim.stores.co2_kg, sim.stores.h2_kg])
	_check(is_equal_approx(float(copy.simulation().stores.co2_kg), float(sim.stores.co2_kg)), "the chain stores survive save and load")
	var old_save := saved.duplicate(); old_save.erase("stores")
	var older := _habitat("plains", 6, _full_kit())
	older.simulation().load(old_save)
	_check(float(older.simulation().stores.grey_l) == 0.0 and is_equal_approx(float(older.simulation().water_l), float(sim.water_l)), "an older save loads with empty chain stores")
	var dry_kit := _full_kit(); dry_kit.erase("water_reclaimer")
	var dry := _habitat("plains", 6, dry_kit)
	dry.simulation().random_storms = false
	dry.simulation().run_hours(48.0, 8.0)
	var caps: Dictionary = dry.simulation().store_caps(dry.simulation().inventory().capacity)
	_check(is_equal_approx(float(dry.simulation().stores.grey_l), float(caps.grey_l)) and float((dry.simulation().last.vented as Dictionary).get("grey_l", 0.0)) > 0.0, "with no water processor the grey tank fills, then vents")
	_check(not (dry.simulation().warnings() as Array).filter(func(w): return str(w.text).contains("Grey water venting: no water processor")).is_empty(), "the venting warning names the missing water processor")

	# Phase 2, air: condensate, the Sabatier and methane, the atmosphere processor.
	_check(float(sim.last.condensate) > 5.0, "the air recycler condenses the crew's breath back (%.1f L a sol)" % sim.last.condensate)
	var sab_kit := _full_kit(); sab_kit["sabatier_reactor"] = ["life_support", 1]
	var sab := _habitat("plains", 6, sab_kit)
	sab.simulation().random_storms = false
	sab.simulation().run_hours(48.0, 8.0)
	_check(float(sab.simulation().last.sabatier_water) > .5 and float(sab.simulation().stores.ch4_kg) > 0.0, "the Sabatier turns CO2 and hydrogen into water (%.1f L a sol) and methane (%.2f kg)" % [sab.simulation().last.sabatier_water, sab.simulation().stores.ch4_kg])
	_check(float(sab.simulation().stores.h2_kg) < float(sim.stores.h2_kg), "and uses up the kept hydrogen")
	var air_kit := _full_kit(); air_kit.erase("oxygen_generator")
	var dry_air := _habitat("plains", 6, air_kit)
	var o2_before := float(dry_air.simulation().daily_flows(false).o2_made)
	dry_air.zones.append({"kind": "atmosphere_processor", "at": Vector2(-12, 6), "cells": [], "door_direction": Vector2i(0, 1), "cost": 0, "state": {}})
	dry_air.simulation().invalidate()
	_check(is_equal_approx(float(dry_air.simulation().daily_flows(false).o2_made) - o2_before, 1.2), "an atmosphere processor makes 1.2 kg of oxygen a sol with no water")

	# Phase 3, water: meltwater needs the processor, urine its own, washing.
	sim.run_hours(24.0, 8.0)   # a fourth sol: the urine tank (30 L) is full by now
	_check(float((sim.last.vented as Dictionary).get("urine_l", 0.0)) > 0.0 and not (sim.warnings() as Array).filter(func(w): return str(w.text).contains("no urine processor")).is_empty(), "without a urine processor, urine is stored then vented, and the warning says so")
	var wet_kit := _full_kit(); wet_kit["urine_processor"] = ["life_support", 1]; wet_kit["hygiene_shower"] = ["hygiene", 1]; wet_kit["hygiene_toilet"] = ["hygiene", 1]
	var wet := _habitat("plains", 6, wet_kit)
	wet.simulation().random_storms = false
	wet.simulation().run_hours(72.0, 8.0)
	_check(float(wet.simulation().stores.brine_l) > 0.0 and not (wet.simulation().last.vented as Dictionary).has("urine_l"), "the urine processor turns urine into water and brine (%.1f L brine)" % wet.simulation().stores.brine_l)
	_check(is_equal_approx(float(wet.simulation().crew_water_per_person(wet.simulation().inventory())) - float(sim.crew_water_per_person(sim.inventory())), 3.0), "a shower uses 3 L more a person than sponge baths")
	var hygiene_need := func(b: BuildController) -> float: return float((b.simulation().life.needs(b.simulation().inventory(), {4: true}) as Array).filter(func(n): return str(n.id) == "hygiene")[0].score)
	_check(float(hygiene_need.call(wet)) > .99 and float(hygiene_need.call(good)) < .01, "the toilet and shower meet the washing need")
	var drill_kit := _full_kit(); drill_kit.erase("water_reclaimer")
	var drilling := _habitat("plains", 6, drill_kit)
	drilling.simulation().random_storms = false
	(drilling.simulation().inventory().drills as Array).append(.8)   # a drill on ice (the test plains have none)
	var water_start := float(drilling.simulation().water_l)
	drilling.simulation().run_hours(72.0, 8.0)
	_check(float(drilling.simulation().stores.raw_l) > 0.0 and float(drilling.simulation().water_l) < water_start, "without a water processor the drill's meltwater can't be drunk (raw %.0f L)" % drilling.simulation().stores.raw_l)

	# Phase 4, food: crops over sols, harvests, the cart, spoilage, the diet.
	var first_tray := str((good.simulation().inventory().items as Array).filter(func(i): return str(i.id) == "grow_tray")[0].pid)
	_check(float(sim.food.tray(first_tray).growth) > .3 and float(sim.food.tray(first_tray).growth) < .6 and float(sim.stores.nutrients_kg) > 0.0, "trays grow greens over sols, fed by Earth's nutrients (%.2f grown)" % sim.food.tray(first_tray).growth)
	_check(float(sim.food.fresh_share) < .3, "a few sols of rations only and the crew notice (fresh %.2f)" % sim.food.fresh_share)
	var farm := _habitat("plains", 6, _full_kit())
	farm.simulation().random_storms = false
	farm.simulation().run_hours(9.0 * 24.0, 8.0)
	var farm_sim: RefCounted = farm.simulation()
	var tray_id := str((farm_sim.inventory().items as Array).filter(func(i): return str(i.id) == "grow_tray")[0].pid)
	_check(int(farm_sim.food.summary(farm_sim.inventory()).ripe) == 6 and not (farm_sim.warnings() as Array).filter(func(w): return str(w.text).contains("ripe")).is_empty(), "after 8 sols the greens are ripe and waiting")
	var before_kg := float(farm_sim.food_kg)
	var picked: Dictionary = farm_sim.food.harvest(tray_id)
	_check(not picked.is_empty() and is_equal_approx(float(farm_sim.food_kg) - before_kg, 2.4) and float(farm_sim.stores.produce_kg) >= 2.4, "E harvests a tray: 2.4 kg of fresh greens")
	_check(str(farm_sim.food.cycle_next(tray_id)) == "potatoes" and str(farm_sim.food.tray(tray_id).crop) == "potatoes", "G on a just-harvested tray plants potatoes")
	farm_sim.run_hours(4.0 * 24.0, 8.0)
	_check(int(farm_sim.food.summary(farm_sim.inventory()).ripe) == 0 and float(farm_sim.stores.organics_kg) > 12.0, "ripe crops left 3 sols go over, to the compost pile")
	(farm_sim.food.batches as Array).append({"crop": "greens", "kg": 1.0, "at": float(farm_sim.hours_run) - 11.0 * 24.0})
	var compost_before := float(farm_sim.stores.organics_kg)
	farm_sim.run_hours(1.0, 8.0)
	_check(float(farm_sim.stores.organics_kg) > compost_before + .9, "produce older than 10 sols spoils")
	var cart_kit := _full_kit(); cart_kit["harvest_cart"] = ["hydroponics", 1]
	var carted := _habitat("plains", 6, cart_kit)
	carted.simulation().random_storms = false
	carted.simulation().run_hours(9.0 * 24.0, 8.0)
	_check(int(carted.simulation().food.summary(carted.simulation().inventory()).ripe) == 0 and float(carted.simulation().food.fresh_share) > float(sim.food.fresh_share), "a harvest cart picks ripe trays, and the crew eat fresh")
	var food_save: Dictionary = farm_sim.save()
	var food_copy := _habitat("plains", 6, _full_kit())
	food_copy.simulation().load(food_save)
	_check(str(food_copy.simulation().food.tray(tray_id).next) == "potatoes", "crops survive save and load")

	# Phase 5, waste: packaging and trash pile up unsorted; sorted, they're
	# recycled into feedstock or composted for the nutrient mixer.
	_check(float(farm_sim.stores.waste_kg) > 10.0 and not (farm_sim.warnings() as Array).filter(func(w): return str(w.text).contains("Rubbish piling up")).is_empty(), "without a sorter the rubbish piles up (%.0f kg)" % farm_sim.stores.waste_kg)
	var bin_kit := _full_kit()
	for id in ["waste_sorting_unit", "recycling_hopper_plastics", "recycling_hopper_metals"]: bin_kit[id] = ["engineering", 1]
	bin_kit["compost_hopper"] = ["hydroponics", 1]; bin_kit["nutrient_mixer"] = ["hydroponics", 1]
	var bins := _habitat("plains", 6, bin_kit)
	bins.simulation().random_storms = false
	bins.simulation().food.trays = {}
	bins.simulation().stores.organics_kg = 20.0
	bins.simulation().run_hours(4.0 * 24.0, 8.0)
	var bin_sim: RefCounted = bins.simulation()
	_check(float(bin_sim.waste.recycled_kg) > 5.0 and float(bin_sim.stores.waste_kg) < 1.0, "sorted, the packaging becomes feedstock (%.1f kg in 4 sols)" % bin_sim.waste.recycled_kg)
	_check(float(bin_sim.stores.organics_kg) < 20.0 and float(bin_sim.stores.nutrients_kg) > 20.0 - 4.0 * 6.0 * .02 * 2.4, "the compost hopper and mixer turn organics into nutrients")
	var bin_copy := _habitat("plains", 6, bin_kit)
	bin_copy.simulation().load(bin_sim.save())
	_check(is_equal_approx(float(bin_copy.simulation().waste.recycled_kg), float(bin_sim.waste.recycled_kg)), "waste survives save and load")

	# Phase 6, radiation: an everyday dose under the hull, cut most by
	# shielding where the crew sleep; a career limit; shielding insulates.
	var rad_sim: RefCounted = bins.simulation()
	var rad_inv: Dictionary = rad_sim.inventory()
	var bare: float = rad_sim.life.indoor_msv_per_sol(rad_inv)
	_check(absf(bare - .48) < .02, "bare habitat: about 0.48 mSv a sol (%.2f)" % bare)
	var bedroom := -1
	for index in range((rad_inv.rooms as Array).size()):
		if str(rad_inv.rooms[index].kind) == "living": bedroom = index
	rad_inv.rooms[bedroom].shield_upgrades = 9.0 * 20.0
	var shielded: float = rad_sim.life.indoor_msv_per_sol(rad_inv)
	_check(shielded < bare * .75, "shielding the sleeping quarters cuts the crew's dose (%.2f)" % shielded)
	_check(rad_sim.shield_insulation(rad_inv.rooms[bedroom]) < .5 and is_equal_approx(rad_sim.shield_insulation({"cells": 4, "shield_upgrades": 0.0}), 1.0), "shielding keeps a room's heat in")
	rad_inv.rooms[bedroom].shield_upgrades = 0.0

	# Phase 7, chains: closure, the weak link, the runway and the readouts.
	var CHAINS := preload("res://scripts/habitat_chains.gd")
	var rows: Array = CHAINS.chains(bin_sim)
	var by_id := {}
	for row in rows: by_id[str(row.id)] = row
	_check(rows.size() == 4 and float(by_id.water.closure) > .5 and float(by_id.water.closure) < 1.0, "the water chain is mostly closed with a water processor (%d%%)" % roundi(float(by_id.water.closure) * 100.0))
	_check(str(by_id.water.weak).contains("Ice Extractor") and str(by_id.water.level) == "bad" and (by_id.water.links as Array).any(func(l): return str(l.label) == "Urine Processor" and not bool(l.have)), "a missing core part comes first, and unbuilt parts are listed (%s)" % by_id.water.weak)
	bin_sim.inventory().drills.append(.8)
	_check(str(CHAINS.chain(bin_sim, "water").weak).to_lower().contains("urine processor"), "with ice, the missing link is named (%s)" % CHAINS.chain(bin_sim, "water").weak)
	bin_sim.inventory().drills.pop_back()
	_check(float(by_id.waste.closure) > .3, "sorting and recycling close the waste chain (%d%%)" % roundi(float(by_id.waste.closure) * 100.0))
	_check(float(by_id.air.closure) == 0.0 and str(by_id.air.weak).contains("Sabatier"), "no Sabatier: none of the air's oxygen comes back (%s)" % by_id.air.weak)
	var runway: Dictionary = CHAINS.runway(bin_sim)
	_check(str(runway.text).begins_with("Safe"), "the runway says how long the base runs alone (%s)" % runway.text)
	_check(CHAINS.readout(bin_sim, "water_reclaimer").contains("L/h") and CHAINS.readout(bin_sim, "crew_bunk") == "", "machines have a readout; furniture doesn't")
	_check(is_equal_approx(rad_sim.life.risk_pct(600.0), 3.0) and rad_sim.life.dose_text(60.0).contains("60 of 600"), "the career limit: 3 % added risk at 600 mSv")

	# A dust storm: solar drops, loads are shed, and life support goes last.
	sim.start_storm(3.0)
	var storm: Array = sim.run_hours(48.0, 8.0, 1.0)
	_check(storm.any(func(s): return not bool(s.all_powered)), "a long dust storm forces the habitat to switch things off")
	_check(not (sim.warnings() as Array).filter(func(w): return str(w.text).contains("Dust storm")).is_empty(), "the storm is announced")

	# No air recycler: CO2 builds up within a sol, and the warning says why.
	var kit := _full_kit(); kit.erase("air_recycler")
	var stuffy := _habitat("plains", 6, kit)
	stuffy.simulation().run_hours(72.0, 8.0)
	_check(float(stuffy.simulation().co2_pct) > 1.0, "without an air recycler CO2 becomes dangerous within three sols (%.2f%%)" % stuffy.simulation().co2_pct)
	_check(not (stuffy.simulation().warnings() as Array).filter(func(w): return str(w.text).contains("no air recycler")).is_empty(), "the CO2 warning names the missing air recycler")
	_check(float(stuffy.simulation().crew_health) < 100.0, "in Survival bad air harms the crew")

	# Freedom: the same problem, but the crew are never harmed.
	MHGame.game_mode = "freedom"
	var safe := _habitat("plains", 6, kit)
	safe.simulation().run_hours(72.0, 8.0)
	_check(float(safe.simulation().co2_pct) > 1.0 and is_equal_approx(float(safe.simulation().crew_health), 100.0), "Freedom shows the problem without harming the crew")
	MHGame.game_mode = "survival"

	# No heating on the Ice Fields: rooms go cold, and the reason is given.
	kit = _full_kit(); kit.erase("thermal_control_unit")
	var cold_base := _habitat("ice", 10, kit)
	cold_base.simulation().run_hours(36.0, 8.0)
	var coldest := 99.0
	for room in cold_base.simulation().crewed_rooms(): coldest = minf(coldest, float(cold_base.simulation().room_temp[room.key]))
	_check(coldest < 12.0, "without thermal control the Ice Fields habitat gets cold (%.1f °C)" % coldest)
	_check(not (cold_base.simulation().warnings() as Array).filter(func(w): return str(w.text).contains("no thermal control unit")).is_empty(), "the cold warning names the missing thermal control unit")

	# No generation and no batteries: everything is off.
	var dark := _habitat("plains", 0, {"crew_bunk": ["living", 2]})
	_check(not dark.grid_power_online(), "no generation and no batteries: the grid is off")
	MHGame.game_mode = "creative"
	_check(dark.grid_power_online(), "Creative mode: power is always on")
	MHGame.game_mode = "survival"

	# Cargo comes from the balance spreadsheet.
	_check(good.cell_cost("living") == int(MHResources.room("living").cargo_kg_per_cell), "a Living Quarters cell costs the spreadsheet's cargo")
	_check(good.cell_cost("reactor") == int(MHResources.item_value("surface_reactor", "cargo_kg")), "a reactor costs the spreadsheet's cargo")
	MHGame.site_id = "ridge"
	var ridge_budget := MHGame.mission_cargo_budget()
	MHGame.site_id = "plains"
	_check(ridge_budget > MHGame.mission_cargo_budget(), "a low landing site gives a cargo bonus (%d vs %d kg)" % [ridge_budget, MHGame.mission_cargo_budget()])
	_check(EquipmentCatalog.get_entry("grow_tray").cargo_cost == int(MHResources.item_value("grow_tray", "cargo_kg")), "equipment cargo comes from the spreadsheet")

	if failures == 0:
		print("Habitat simulation test passed: day and night power, air, heating, storms, Freedom, saving and cargo.")
	quit(1 if failures > 0 else 0)
