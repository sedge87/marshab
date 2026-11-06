extends SceneTree


# Room changes (docs/room-changes.md, 31 Oct): the General Module (basic kit
# only, two bunks, noisy, slower work, half space), the renamed rooms and
# their kit, Waste Management saves turning into Storage & Recycling, old
# kit staying put, the crew's day and the roof fittings.
# Run with: godot --headless --path . --script res://tests/room_changes_test.gd
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

var _n := 0
func _add(b: BuildController, id: String, kind: String, count := 1) -> void:
	var cell := Vector2i.ZERO
	for zone in b.zones:
		if str(zone.kind) == kind: cell = zone.cells[0]
	for k in range(count):
		_n += 1
		b.placed_interior.append({"placement_id": "p%d" % _n, "id": id, "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {}})

func _builder(zone_list: Array) -> BuildController:
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	for zone in zone_list: b.zones.append(zone)
	return b

func _room(kind: String, cells: Array) -> Dictionary:
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 0}

func _need(b: BuildController, id: String) -> Dictionary:
	b.simulation().invalidate()
	return (b.simulation().life.needs(b.simulation().inventory(), {4: true}) as Array).filter(func(n): return str(n.id) == id)[0]

func _fits(id: String, kind: String) -> bool:
	return (EquipmentCatalog.get_entry(id).get("valid_zones", []) as Array).has(kind)

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.game_mode = "freedom"
	MHGame.site_id = "plains"
	MHGame.debug_free_power = true

	# ---- names and kit ----
	_check(str(BuildController.ZONE_TYPES.living.label) == "Sleeping Quarters" and str(BuildController.ZONE_TYPES.galley.label) == "Day Room", "Living Quarters is Sleeping Quarters, the Galley the Day Room")
	_check(str(BuildController.ZONE_TYPES.engineering.label) == "Power & Engineering" and str(BuildController.ZONE_TYPES.storage.label) == "Storage & Recycling", "Power & Engineering, and Storage & Recycling")
	_check(not BuildController.zone_offered("waste_management"), "Waste Management is off the build menu")
	_check(BuildController.zone_offered("general"), "the General Module is on it")
	for id in ["crew_bunk", "galley_kitchenette", "hygiene_toilet", "air_recycler", "oxygen_generator", "tool_bench", "communications_station", "grow_tray", "battery_bank"]:
		_check(_fits(id, "general"), "the General Module takes %s" % id)
	for id in ["microscope_station", "medical_exam_cot", "hygiene_shower", "galley_oven", "regolith_printer", "rover_charger", "greenhouse_planter"]:
		_check(not _fits(id, "general"), "but not the advanced %s" % id)
	_check(not _fits("lounge_sofa", "living") and _fits("lounge_sofa", "galley") and _fits("exercise_station", "galley"), "sofas and the exercise station moved to the Day Room")
	_check(_fits("waste_sorting_unit", "storage") and _fits("compost_hopper", "storage"), "the waste sorter and compost go in Storage & Recycling")
	_check(BuildController.ROOF_ACCESSORY_SCENES.has("general") and BuildController.ROOF_ACCESSORY_SCENES.has("storage"), "the General Module and Storage & Recycling have roof fittings")

	# ---- the General Module ----
	var g := _builder([_room("general", _block(0, 0, 3, 3))])
	g.simulation().life.crew_on = true
	g.simulation().life.ensure_crew(2)
	_add(g, "crew_bunk", "general", 2)
	var sleep := _need(g, "sleep")
	_check(is_equal_approx(float(sleep.score), .5) and str(sleep.missing).contains("Sleeping Quarters"), "bunks in a General Module sleep at half (%.2f)" % float(sleep.score))
	g._rebuild()
	_check(g.free_interior_invalid_reason("crew_bunk", Vector3(3, 0, 3), Vector3.UP).contains("takes 2 bunks"), "a third bunk doesn't fit")
	var work := _need(g, "work")
	_check(float(work.score) >= .99, "everyone has somewhere to work")
	_check(is_equal_approx(float(g.simulation().life.room_speed.get("commander", 1.0)), .75), "but at 75 %")
	# Six crew need 12 squares: 9 of General Module count as 4.5.
	var big_g := _builder([_room("general", _block(0, 0, 3, 3))])
	big_g.simulation().life.ensure_crew(6)
	var cramped := float(_need(big_g, "space").score)
	var big_s := _builder([_room("living", _block(0, 0, 3, 3))])
	big_s.simulation().life.ensure_crew(6)
	_check(is_equal_approx(float(_need(big_s, "space").score), cramped * 2.0), "a General Module counts half towards space (%.2f against %.2f)" % [cramped, float(_need(big_s, "space").score)])
	var s := _builder([_room("living", _block(0, 0, 3, 3))])
	s.simulation().life.ensure_crew(2)
	_add(s, "crew_bunk", "living", 2)
	_check(float(_need(s, "sleep").score) >= .99, "Sleeping Quarters on their own sleep well")

	# ---- noise ----
	var noisy := _builder([_room("living", _block(0, 0, 2, 2)), _room("vehicle_bay", _block(2, 0, 2, 2))])
	noisy.simulation().life.ensure_crew(2)
	_add(noisy, "crew_bunk", "living", 2)
	noisy._rebuild()
	_check(float(_need(noisy, "sleep").score) < .99, "Sleeping Quarters next to the Vehicle Bay sleep badly")

	# ---- the crew's day ----
	var day := _builder([_room("general", _block(0, 0, 2, 2)), _room("science", _block(2, 0, 2, 2))])
	day._rebuild()
	var rooms: Array = day.simulation().inventory().rooms
	var at_night: Array = day.simulation()._crew_by_room(rooms, 2, 2.0)
	var general_index := rooms.find(rooms.filter(func(r): return str(r.kind) == "general")[0])
	_check(float(at_night[general_index]) >= 2.0, "with no Sleeping Quarters the crew sleep in the General Module")

	# ---- old saves ----
	var old := _builder([])
	var state := {"zones": [_room("waste_management", _block(0, 0, 2, 2)), _room("living", _block(2, 0, 2, 2))], "placed_interior": []}
	old.restore_habitat_state(state)
	_check(old.zones.any(func(z): return str(z.kind) == "storage") and not old.zones.any(func(z): return str(z.kind) == "waste_management"), "a Waste Management room loads as Storage & Recycling")
	var sofa_save := {"zones": [_room("living", _block(0, 0, 3, 2))], "placed_interior": [{"placement_id": "s1", "id": "lounge_sofa", "position": Vector3(3, 0, 1.5), "zone_cell": Vector2i(1, 0), "state": {}}]}
	old.restore_habitat_state(sofa_save)
	_check(old.placed_interior.size() == 1 and bool(old.placed_interior[0].get("legacy", false)), "a sofa an old save left in Sleeping Quarters loads, marked as old kit")
	old._prune_equipment()
	_check(old.placed_interior.size() == 1, "and stays there")
	_check(not BuildController.still_fits("lounge_sofa", "living") and not _fits("lounge_sofa", "living"), "but no new sofa goes in, and none is carried in by a reassign")
	_check(not BuildController.still_fits("microscope_station", "living", true), "kit that never fitted still doesn't")

	if failures == 0: print("Room changes test passed: the General Module, renamed rooms and their kit, noise, the crew's day, old saves and roof fittings.")
	quit(1 if failures > 0 else 0)
