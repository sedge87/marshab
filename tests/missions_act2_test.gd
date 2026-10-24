extends SceneTree

const WALL_UPGRADES := preload("res://scripts/wall_upgrades.gd")

# Missions 7-10 are winnable, and have teeth: each mission's new idea is
# needed to pass. Builds the same base as missions_campaign_test.gd through
# Mission 6, then improves it mission by mission.
# Run with: godot --headless --path . --script res://tests/missions_act2_test.gd [-- --verbose]
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
var failures := 0
var verbose := OS.get_cmdline_user_args().has("--verbose")

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _report(report: Dictionary) -> String:
	var lines: Array = []
	for r in report.results: lines.append(("PASS " if r.pass else "FAIL ") + str(r.text) + " :: " + str(r.detail))
	return "\n    ".join(lines)

func _test(b: BuildController, label: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	b.simulation().invalidate()
	var report := MHMissions.run_test(b)
	if verbose: print("  %s (%d ms):\n    %s" % [label, Time.get_ticks_msec() - t0, _report(report)])
	return report

func _failed(report: Dictionary, id: String) -> bool:
	for r in report.results:
		if str(r.id) == id: return not bool(r.pass)
	return false

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "missions"
	MHMissions.reset()
	var target: Vector2 = PICKER.suggested()
	var base := Vector2.INF
	for x in range(-45, 46, 3):
		for z in range(-45, 46, 3):
			var candidate := Vector2(x, z)
			if is_inf(base.x) and bool(MHMissions.check_landing(target, candidate).passed) and candidate.distance_to(target) < 35.0: base = candidate
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = base
	MHMissions.complete("landing_zones")
	_check(MHMissions.missions().size() == 10, "ten missions")
	MHMissions.progress.current = "long_silence"
	_check(MHMissions.cargo_budget() == 99000, "the cargo budget grows with every landing (%d)" % MHMissions.cargo_budget())

	var world := Node3D.new(); root.add_child(world)
	await process_frame
	var b := BuildController.new(); b.display_only = true; world.add_child(b)
	await process_frame
	var c := Vector2i(roundi(base.x / 3.0), roundi(base.y / 3.0))

	# --- The Mission 6 base (as in missions_campaign_test.gd) ---
	b.zones = [_room("engineering", c, 0, 0, 2, 2), _room("life_support", c, 2, 0, 2, 2), _room("living", c, 4, 0, 2, 2),
		{"kind": "airlock", "cells": [c + Vector2i(0, 2)], "door_direction": Vector2i(0, 1), "cost": 0},
		_room("galley", c, 6, 0, 2, 2), _room("hygiene", c, 4, 2, 2, 1), _room("hydroponics", c, 6, 2, 3, 2), _room("science", c, 2, 2, 2, 1)]
	for i in 10: b.zones.append({"kind": "solar", "cells": [c + Vector2i(-2 - (i % 5) * 2, -4 - (i / 5) * 2)], "door_direction": Vector2i(0, 1), "cost": 0})
	b.zones.append({"kind": "ice_extractor", "cells": [_best_ice(b, c)], "cost": 0})
	b.zones.append({"kind": "ice_extractor", "cells": [_best_ice(b, c) + Vector2i(1, 0)], "cost": 0})
	b.zones.append({"kind": "reactor", "cells": [c + Vector2i(-6, 6)], "cost": 0})
	b._rebuild()
	b.placed_interior = []
	_item(b, "battery_bank", c, 0, 0, 6)
	_item(b, "thermal_control_unit", c, 2, 0, 1)
	_item(b, "oxygen_generator", c, 2, 1, 2)
	_item(b, "air_recycler", c, 3, 0, 2)
	_item(b, "water_reclaimer", c, 3, 1, 1)
	_item(b, "crew_bunk", c, 4, 0, 6)
	_item(b, "galley_rehydration_station", c, 6, 0, 1)
	_item(b, "hygiene_toilet", c, 4, 2, 1)
	_item(b, "grow_tray", c, 6, 2, 8)
	_item(b, "science_workbench", c, 2, 2, 1)
	MHMissions.progress.current = "self_sufficiency"
	b.simulation().crew_cap = 6
	MHMissions.deliver_mission_food(b.simulation())

	# --- Mission 7: the storm shelter ---
	MHMissions.progress.current = "solar_shelter"
	_check(MHMissions.item_unlocked("storm_shelter_locker") and MHMissions.structure_unlocked("upgrade_regolith") and MHMissions.structure_unlocked("upgrade_roof"), "Mission 7 delivers the shelter locker and wall and roof shielding")
	_check(not MHMissions.item_unlocked("hull_patch_kit"), "but not Mission 9's patch kit")
	MHMissions.deliver_mission_food(b.simulation())
	var m7_none := _test(b, "Mission 7, no shelter")
	_check(not bool(m7_none.passed) and _failed(m7_none, "dose"), "no shelter: the crew get too much radiation")
	_item(b, "storm_shelter_locker", c, 2, 2, 1)
	var m7_weak := _test(b, "Mission 7, locker only")
	_check(_failed(m7_weak, "shelter") and _failed(m7_weak, "dose"), "a locker without shielding isn't enough")
	# Shielding protects the whole habitat: roofs and outside walls all round.
	for zone in b.zones.filter(func(z): return b._is_habitat_zone(z)): WALL_UPGRADES.shield_room(b, zone)
	b._rebuild()
	var m7 := _test(b, "Mission 7, shielded habitat")
	_check(bool(m7.passed), "a shielded habitat with a shelter passes Mission 7:\n    " + _report(m7))

	# --- Mission 8: the crew as people ---
	MHMissions.progress.current = "crew_people"
	MHMissions.set_crew_names(["Ada", "Tom", "Mei", "Priya", "Jonas", "Sam"])
	MHMissions.deliver_mission_food(b.simulation())
	var m8_weak := _test(b, "Mission 8, as built")
	_check(not bool(m8_weak.passed) and _failed(m8_weak, "fit") and _failed(m8_weak, "patient"), "Mission 7's base fails Mission 8: no exercise, no Medical Bay")
	b.zones.append(_room("medical", c, 0, 3, 2, 1))
	b.zones.append(_room("communications", c, 6, 4, 2, 1))
	b._rebuild()
	_item(b, "exercise_station", c, 5, 1, 2)
	_item(b, "medical_exam_cot", c, 0, 3, 1)
	_item(b, "medical_cabinet", c, 0, 3, 1)
	_item(b, "microscope_station", c, 3, 2, 1)
	_item(b, "common_table", c, 5, 0, 2)
	_item(b, "galley_oven", c, 6, 0, 1)
	_item(b, "photo_frame", c, 4, 1, 2)
	_item(b, "paper_books", c, 4, 1, 1)
	_item(b, "guitar", c, 4, 1, 1)
	_item(b, "plant_pot", c, 6, 1, 1)
	b.placed_surface.append({"placement_id": "antenna", "id": "comms_antenna", "position": Vector3((c.x - 3) * 3.0, 0, (c.y + 6) * 3.0), "rotation_y": 0.0, "state": {}})
	var m8 := _test(b, "Mission 8, looked after")
	_check(bool(m8.passed), "exercise, a Medical Bay and a homely base pass Mission 8:\n    " + _report(m8))

	# --- Mission 9: hull breach ---
	MHMissions.progress.current = "hull_breach"
	MHMissions.deliver_mission_food(b.simulation())
	var m9_weak := _test(b, "Mission 9, no patch kit")
	_check(not bool(m9_weak.passed) and _failed(m9_weak, "patched"), "no patch kit: the hole stays open")
	_item(b, "hull_patch_kit", c, 4, 0, 1)
	_item(b, "air_reserve_rack", c, 2, 0, 2)
	var m9 := _test(b, "Mission 9, kit and air reserve")
	_check(bool(m9.passed), "a patch kit, air reserve and sealed rooms pass Mission 9:\n    " + _report(m9))
	_check(MHMissions.largest_section(b) <= .4, "rooms joined only by walls are separate sections (%.0f%%)" % (MHMissions.largest_section(b) * 100.0))

	# --- Mission 10: the long silence ---
	MHMissions.progress.current = "long_silence"
	MHMissions.deliver_mission_food(b.simulation())
	var m10_weak := _test(b, "Mission 10, no spares")
	_check(not bool(m10_weak.passed), "Mission 9's base doesn't survive 200 sols of breakdowns without spares")
	_item(b, "spare_parts_rack", c, 0, 1, 2)
	_item(b, "thermal_control_unit", c, 2, 1, 1)
	_item(b, "water_reclaimer", c, 3, 1, 1)
	_item(b, "grow_tray", c, 7, 2, 10)
	for k in range(2): b.zones.append({"kind": "reactor", "cells": [c + Vector2i(-8 - k * 2, 6)], "cost": 0})
	b._rebuild()
	var t0 := Time.get_ticks_msec()
	var m10 := _test(b, "Mission 10, robust")
	var took := Time.get_ticks_msec() - t0
	if verbose:
		var cuts := (m10.samples as Array).filter(func(x): return not bool(x.all_powered)).size()
		print("    power cuts in %d of %d samples; fitness at sol 10/20/30: %s" % [cuts, (m10.samples as Array).size(), [m10.samples[60].get("fitness"), m10.samples[120].get("fitness"), m10.samples[180].get("fitness")]])
	_check(bool(m10.passed), "spares, redundancy and grown food pass all three futures of Mission 10:\n    " + _report(m10))
	_check(took < 20000, "three 200-sol futures run in under 20 s (%d ms)" % took)

	MHGame.game_mode = "survival"
	if failures == 0:
		print("Missions Act 2 test passed: Missions 7-10 winnable, and each one's new idea is needed.")
	quit(1 if failures > 0 else 0)

func _room(kind: String, c: Vector2i, x: int, z: int, w: int, h: int) -> Dictionary:
	var cells := []
	for dx in range(w):
		for dz in range(h): cells.append(c + Vector2i(x + dx, z + dz))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 0}

func _item(b: BuildController, id: String, c: Vector2i, x: int, z: int, count: int) -> void:
	var cell := c + Vector2i(x, z)
	for i in count:
		b.placed_interior.append({"placement_id": "%s_%d_%d" % [id, i, b.placed_interior.size()], "id": id, "position": Vector3(cell.x * 3.0, b.habitat_base_y, cell.y * 3.0), "zone_cell": cell, "rotation_y": 0.0, "state": {}})

func _best_ice(b: BuildController, c: Vector2i) -> Vector2i:
	var best := c + Vector2i(8, 4)
	var richest := 0.0
	for x in range(-15, 16):
		for z in range(-15, 16):
			var r: float = b._ice_richness_at(Vector2i(x, z))
			if r > richest and not MHMissions.in_blast_zone(Vector2(x * 3, z * 3)): richest = r; best = Vector2i(x, z)
	return best
