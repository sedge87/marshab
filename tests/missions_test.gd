extends SceneTree

# Missions campaign, phase 1: mission data and progress, Mission 1's landing
# checks, unlocks and payload budget, the blast zone, the world in a robot
# mission (no crew lander yet; GAR-Y comes with the cargo), the Test (pass, fail with a reason, and
# versions with changes) and saving progress with the base.
# Run with: godot --headless --path . --script res://tests/missions_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "missions"
	MHMissions.reset()
	_check(MHMissions.missions().size() == 6, "six missions in the campaign")
	_check(str(MHMissions.current().id) == "landing_zones", "a new campaign starts with Mission 1, Landing Zones")

	# Mission 1: the landing ellipse must be safe and the base clear of engine blast.
	var target: Vector2 = PICKER.suggested()
	var near := MHMissions.check_landing(target, target + Vector2(5, 0))
	_check(bool(near.landing_safe) and not bool(near.landing_clear), "a base inside the blast zone is refused")
	var base := Vector2.INF
	for x in range(-45, 46, 3):
		for z in range(-45, 46, 3):
			var candidate := Vector2(x, z)
			if is_inf(base.x) and bool(MHMissions.check_landing(target, candidate).passed) and candidate.distance_to(target) < 35.0: base = candidate
	_check(not is_inf(base.x), "there is a safe base site near the landing zone")
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = base
	MHMissions.complete("landing_zones")
	_check(str(MHMissions.current().id) == "cargo_power_water", "completing Mission 1 starts Mission 2")
	_check(MHMissions.cargo_budget() == 12000 and MHGame.cargo_budget() == 12000, "Mission 2's budget is its 12 t payload")
	_check(MHMissions.zone_unlocked("solar") and MHMissions.zone_unlocked("engineering") and not MHMissions.zone_unlocked("living"), "Mission 2 unlocks power and drills, not living quarters")
	_check(MHMissions.item_unlocked("battery_bank") and not MHMissions.item_unlocked("crew_bunk"), "Mission 2 delivers batteries, not bunks")
	_check(MHMissions.in_blast_zone(target) and not MHMissions.in_blast_zone(base), "the landing zone is a no-build blast zone")

	# The world in a robot mission.
	MHGame.pending_save_state = {}
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	_check(not world.lander.present, "no crew lander before the crew arrive")
	_check(world.scout_rover != null, "GAR-Y rolls out with the first cargo to survey for ice")
	# Mission 2 opens with Cargo Lander 1's touchdown; the robot rides in its hold.
	_check(bool(world.arrival_pending) and world.current_cargo_lander != null, "Mission 2 starts with the cargo lander's touchdown")
	world._finish_arrival()
	var cargo: Node3D = world.current_cargo_lander
	_check(cargo.hold_contains(world.player.global_position), "the robot starts inside the cargo lander's hold")
	_check(MHMissions.arrived("cargo_power_water") and MHMissions.cargo_landers().size() == 1, "the arrival is recorded so it plays once")
	var cargo_flat := Vector2(cargo.global_position.x, cargo.global_position.z)
	_check(cargo_flat.distance_to(target) <= 9.5, "the cargo lander touches down inside the landing ellipse")
	# Steps tick themselves off.
	_check(str(MHMissions.current_step().get("id", "")) == "roll_out", "the first step is to roll out")
	cargo.interact()
	world.player.global_position = cargo.to_global(Vector3(0, 1.5, -7.0))
	await process_frame
	MHMissions.update_steps(world.builder, world.mission_flags)
	_check(str(MHMissions.current_step().get("id", "")) == "plan", "rolling out down the ramp ticks the first step")
	_check(world.mission_hud != null and world.explore_hud.chip_prefix == "ROBOT · ", "the mission panel and robot HUD are shown")
	var builder: BuildController = world.builder
	builder.kind = "living"
	var base_cell := Vector2i(roundi(base.x / BuildController.CELL), roundi(base.y / BuildController.CELL))
	_check(str(builder._invalid_reason([base_cell])).begins_with("Not delivered yet"), "locked rooms can't be built")
	builder.kind = "engineering"
	var zone_cell := Vector2i(roundi(target.x / BuildController.CELL), roundi(target.y / BuildController.CELL))
	_check(str(builder._invalid_reason([zone_cell])).begins_with("Inside the landing zone"), "nothing can be built in the landing zone")

	# A weak design fails the Test with a reason; a strong one passes.
	var ice := base_cell
	var richest := 0.0
	for cx in range(-15, 16):
		for cz in range(-15, 16):
			var r: float = builder._ice_richness_at(Vector2i(cx, cz))
			if r > richest and not MHMissions.in_blast_zone(Vector2(cx * 3, cz * 3)): richest = r; ice = Vector2i(cx, cz)
	builder.zones = [{"kind": "engineering", "cells": [base_cell, base_cell + Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "solar", "cells": [base_cell + Vector2i(0, 2)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "ice_extractor", "cells": [ice], "cost": 0}]
	builder.placed_interior = []
	builder.simulation().invalidate()
	world.mission_flags.opened_plan = true
	MHMissions.update_steps(builder, world.mission_flags)
	_check(str(MHMissions.current_step().get("id", "")) == "airlock", "building solar, a P&E room and a drill ticks those steps; next is the airlock: %s" % [MHMissions.steps_done("cargo_power_water")])
	var weak := MHMissions.run_test(builder)
	_check(not bool(weak.passed), "a single solar array and no batteries fails the Test")
	var power_result: Dictionary = (weak.results as Array).filter(func(r): return r.id == "always_powered")[0]
	_check(not bool(power_result.pass) and str(power_result.detail).contains("sol") and str(power_result.detail).contains("power"), "the report says when and why power failed: %s" % power_result.detail)
	for i in range(7): builder.zones.append({"kind": "solar", "cells": [base_cell + Vector2i(2 + i, 2)], "door_direction": Vector2i(0, 1), "cost": 0})
	var second_ice := ice + Vector2i(1, 1)
	builder.zones.append({"kind": "ice_extractor", "cells": [second_ice], "cost": 0})
	for i in range(5): builder.placed_interior.append({"placement_id": "b%d" % i, "id": "battery_bank", "position": Vector3(base_cell.x * 3, 0, base_cell.y * 3), "zone_cell": base_cell, "state": {}})
	builder.simulation().invalidate()
	var strong := MHMissions.run_test(builder)
	_check(bool(strong.passed), "8 arrays, 5 batteries and 2 drills pass the Test: %s" % str((strong.results as Array).map(func(r): return r.detail)))
	_check(MHMissions.versions("cargo_power_water").size() == 2 and str(strong.changes).contains("+7 solar arrays") and str(strong.changes).contains("+5 battery banks"), "versions record what changed: %s" % strong.changes)
	_check((strong.samples as Array).size() == 5 * 48, "the Test samples every half hour for 5 sols")

	# Progress saves with the base.
	var state: Dictionary = world.current_state()
	_check((state.get("missions_progress", {}) as Dictionary).get("current", "") == "cargo_power_water", "campaign progress is saved with the base")
	MHMissions.reset()
	MHMissions.load_state(state.missions_progress)
	_check(MHMissions.versions("cargo_power_water").size() == 2 and MHMissions.landing_target() == target, "loading restores versions and the landing zone")
	world.queue_free()
	MHGame.game_mode = "survival"
	if failures == 0:
		print("Missions test passed: data, landing zones, unlocks, budget, blast zone, robot start, Test reasons, versions and saving.")
	quit(1 if failures > 0 else 0)
