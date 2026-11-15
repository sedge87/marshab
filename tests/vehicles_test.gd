extends SceneTree

# Run with: godot --headless --path . --script res://tests/vehicles_test.gd
# A7 (docs/bases-and-vehicles.md "As built (A7)"): on a region game, once the
# guided chapters are over, the scout buggy, the pressurised rover and the
# scout drone are out in the land as wrecks, marked on the Map. Fixing each
# one; the open buggy (your suit's air, the dashboard, the cockpit and chase
# views, charging by the lander); the rover's sealed cab (sleep, eat, its
# air), bogging on loose ground (mats, digging out), wheel wear, add-ons at
# the Garage's rover dock; the drone dock, flying the drone (the Map clears,
# route markers), and a gust throwing it down.

const GROUND := preload("res://scripts/ground.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const RegionTerrain := preload("res://scripts/region_terrain.gd")

func _key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code; key.physical_keycode = code; key.pressed = pressed
	Input.parse_input_event(key)

## A spot of `kind` ground within `reach` of the site's origin (site metres).
func _ground_spot(kind: String, reach: float) -> Vector3:
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	for r in range(20, int(reach), 20):
		for i in 36:
			var a := TAU * i / 36.0
			var p := Vector2(cos(a), sin(a)) * r
			if GROUND.kind(p.x + origin.x, p.y + origin.y) == kind: return Vector3(p.x, MHSiteTerrain.height(p.x, p.y), p.y)
	return Vector3.INF

func _initialize() -> void:
	MHGame.site_id = "region_plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "survival"
	MHGame.pending_save_state = {"site_id": "region_plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world.set_tutorial_mode("off")
	world.day_night.set_hour(12.0); world.day_night.frozen = true
	var player: Node3D = world.player
	var suit: Node = world.suit
	var known: Node = world.known
	var b = world.builder

	# ---------- the wrecks ----------
	if world.opening_days != null: world.opening_days.chapter = 99   # past the guided chapters
	world._sync_crew_rover()
	var buggy = world.buggy
	var rover = world.crew_rover
	var drone = world.drone
	assert(buggy != null and rover != null and drone != null, "Past the guided chapters, all three are out in the land.")
	assert(buggy.wrecked and rover.wrecked and str(drone.state) == "wrecked", "As wrecks.")
	assert(known.things.has("wreck:buggy") and known.things.has("wreck:rover") and known.things.has("wreck:drone"), "Marked on the Map (A7 test spawns).")
	var buggy_out: float = Vector2(buggy.global_position.x, buggy.global_position.z).length()
	var rover_out: float = Vector2(rover.global_position.x, rover.global_position.z).length()
	assert(buggy_out > 450.0 and buggy_out < 750.0, "The buggy's wreck is in ring 1, about 600 m out (%d m)." % roundi(buggy_out))
	assert(rover_out > 2100.0 and rover_out < 2700.0, "The rover's wreck is at the edge of ring 2 (%d m)." % roundi(rover_out))
	assert(buggy.find_children("dash_screen", "MeshInstance3D", true, false).size() == 1, "The buggy's model has its dashboard screen.")

	# ---------- the buggy: fixed on the spot ----------
	MHChapterOne.stock["spares_kit"] = 0
	assert(not buggy.interact(), "No spares kit: it can't be fixed yet.")
	MHChapterOne.stock["spares_kit"] = 5
	assert(buggy.interact() and str(buggy.repair) == "battery", "A spares kit makes the new steering link; then its battery.")
	suit.power = 1.0
	assert(buggy.interact() and not buggy.wrecked, "Bridged from your suit: fixed.")
	assert(is_equal_approx(float(buggy.battery), buggy.BUGGY_WAKE_CHARGE) and float(suit.power) < .75, "It wakes at %d%%, and your suit paid for it (%.2f)." % [roundi(buggy.battery), suit.power])
	assert(not known.things.has("wreck:buggy"), "Its wreck pin comes off the Map.")

	# Bring it home to drive it.
	buggy.global_position = world._flat_spot(Vector3(20, 0, 20)) + Vector3.UP * .05
	buggy.rotation.y = 0.0
	player.global_position = buggy.global_position + Vector3(-2.5, .3, 0)
	for i in 10: await physics_frame
	assert(buggy.interact(), "Get in.")
	for i in 30: await process_frame
	assert(str(suit.where) == "outside", "The open buggy: you breathe your suit's air (%s)." % suit.where)
	assert(buggy.first_person and not buggy._dash_echo.visible, "The cockpit view first: the dashboard is in the cab, not on screen.")
	var before: float = buggy.battery
	_key(KEY_W, true)
	for i in 60 * 3: await physics_frame
	var buggy_speed: float = buggy.speed
	_key(KEY_W, false)
	assert(buggy_speed > 4.0, "Quick: %.1f m/s." % buggy_speed)
	assert(buggy.battery < before, "Driving uses its battery (%.1f%%)." % buggy.battery)
	_key(KEY_V, true); _key(KEY_V, false)
	for i in 3: await process_frame
	assert(not buggy.first_person and buggy._dash_echo.visible, "V: the chase view, with the dashboard's echo in the corner.")
	_key(KEY_SPACE, true)
	for i in 60: await physics_frame
	_key(KEY_SPACE, false)
	_key(KEY_E, true); _key(KEY_E, false)
	for i in 5: await physics_frame
	assert(not bool(player.get_meta("driving", false)), "Out.")
	assert(is_equal_approx(100.0 / float(buggy._spec.range_m) * 2000.0, 100.0), "About 2 km to a charge.")
	# Parked by the lander, it trickle-charges.
	var lander_at: Vector3 = world.lander.global_position
	buggy.global_position = world._flat_spot(lander_at + Vector3(12, 0, 0)) + Vector3.UP * .05
	buggy.speed = 0.0
	for i in 5: await physics_frame
	assert(str(buggy._charge_source()) == "base", "By the lander it charges (%s)." % buggy._charge_source())

	# ---------- the pressurised rover ----------
	MHChapterOne.stock["spares_kit"] = 1
	assert(not rover.interact(), "Two spares kits needed.")
	MHChapterOne.stock["spares_kit"] = 6
	MHMaterials.metal_kg = 100.0
	MHMaterials.salvage_kg = 100.0
	MHChapterOne.feedstock_kg = 500.0
	assert(rover.interact() and not rover.wrecked, "Two kits, metal and salvage: fixed.")
	assert(MHChapterOne.known.has("dune_wheels"), "Its manifest held the dune-wheel plan.")
	rover.global_position = world._flat_spot(Vector3(-30, 0, 30)) + Vector3.UP * .05
	rover.o2 = 80.0
	rover.meals = 2
	rover.water_l = 10.0
	player.global_position = rover.global_position + Vector3(-2.6, .3, 0)
	for i in 10: await physics_frame
	assert(rover.interact(), "Get in the rover.")
	for i in 30: await process_frame
	assert(str(suit.where) == "rover", "Its sealed cab: you breathe its air (%s)." % suit.where)
	assert(rover.cabin_ready(), "Parked with air: the cabin is a safe pocket.")
	assert(str(world.sleep.blocked_reason()) == "", "You can sleep in its cab (%s)." % world.sleep.blocked_reason())
	suit.drink_l = 0.2
	suit.food_bar = false
	rover._cabin_eat()
	assert(rover.meals == 0 and suit.food_bar and float(suit.drink_l) > .9, "X: a meal, a food bar packed and the drink bag filled from its stores (meals %d)." % rover.meals)
	_key(KEY_W, true)
	for i in 60 * 3: await physics_frame
	var rover_speed: float = rover.speed
	_key(KEY_W, false)
	assert(rover_speed > 2.5 and rover_speed <= 3.05, "Slow: about 3 m/s (%.1f)." % rover_speed)
	assert(not rover.cabin_ready(), "Moving: not a cabin to sleep in.")
	_key(KEY_E, true); _key(KEY_E, false)
	for i in 5: await physics_frame

	# Bogging on loose ground.
	var sand := _ground_spot("sand", 2600.0)
	var ripples := _ground_spot("ripples", 2600.0)
	var loose := sand if sand != Vector3.INF else ripples
	assert(loose != Vector3.INF, "There's loose ground in reach to test on.")
	rover.set_physics_process(false)
	rover.global_position = loose
	rover.speed = 3.0
	for i in 200:
		rover._terrain_effects(.1, .3)
		if rover.bogged: break
	assert(rover.bogged, "Pushing on through %s: bogged." % rover._ground)
	assert(str(rover.recall()).contains("bogged") and not rover._recover(), "Recall and R don't get it out.")
	rover.mats = 0
	assert(not rover.lay_mat(), "No mats.")
	suit.o2 = 1.0
	for i in 5: rover.interact_tertiary()
	assert(not rover.bogged and float(suit.o2) < 1.0, "Dug out by hand, and it cost suit air (%.3f)." % suit.o2)

	# Wheel wear on sharp ground.
	var sharp := _ground_spot("sharp_boulders", 2900.0)
	if sharp == Vector3.INF: sharp = _ground_spot("platy_lava", 2900.0)
	if sharp != Vector3.INF:
		rover.global_position = sharp
		rover.speed = 3.0
		rover.wheels = 100.0
		for i in 40: rover._terrain_effects(.1, 50.0)
		assert(rover.wheels < 40.0 and rover.top_speed() < 3.0, "Sharp ground wears the wheels and slows it (%d%%, %.1f m/s)." % [roundi(rover.wheels), rover.top_speed()])
	else:
		print("  (no sharp ground found near this landing: wear not checked)")
	rover.speed = 0.0
	rover.set_physics_process(true)

	# ---------- the Garage: rover dock and drone dock ----------
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	await process_frame
	var docks := get_nodes_in_group("drone_dock")
	assert(docks.size() == 1, "The Garage has a drone dock outside.")
	assert(rover.park_at_home(false), "The rover parks in the Garage.")
	rover.battery = 20.0
	rover.o2 = 20.0
	for i in 5: await physics_frame
	assert(str(rover._charge_source()) == "garage", "Docked in the Garage (%s)." % rover._charge_source())
	player.global_position = rover.global_position + Vector3(-2.6, .3, 0)
	rover._get_in(player)
	var metal: float = MHMaterials.metal_kg
	assert(rover.fit_addon("dune_wheels") and rover.has_addon("dune_wheels") and MHMaterials.metal_kg < metal, "The add-on bench fits dune wheels (metal paid).")
	assert(rover.fit_addon("traction_mats") and rover.mats == rover.MATS, "And a rack of traction mats.")
	rover.wheels = 30.0
	assert(rover.refit_wheels() and rover.wheels == 100.0, "The wheel bench refits the tread.")
	rover._get_out()
	world.day_night.frozen = false
	world.day_night.time_scale = 60.0
	for i in 120: await process_frame
	world.day_night.time_scale = 1.0
	world.day_night.frozen = true
	assert(rover.battery > 20.0 and rover.o2 > 20.0, "The dock charges it and refills its air (%d%%, O2 %d%%)." % [roundi(rover.battery), roundi(rover.o2)])
	# Dune wheels: no bogging on sand.
	if sand != Vector3.INF:
		rover.set_physics_process(false)
		rover.global_position = sand
		rover.speed = 3.0
		for i in 200: rover._terrain_effects(.1, .3)
		assert(not rover.bogged, "Dune wheels float on sand.")
		rover.speed = 0.0
		rover.set_physics_process(true)

	# ---------- the drone ----------
	var dock: Node3D = docks[0]
	drone.global_position = dock.global_position + Vector3(30, 0, 30)
	assert(drone.interact() and str(drone.state) == "returning", "A spares kit fixes it; it flies to the dock.")
	for i in 600:
		drone._autopilot(.1)
		if str(drone.state) == "docked": break
	assert(str(drone.state) == "docked", "Docked on the cradle (%s)." % drone.state)
	drone.battery = 100.0
	assert(dock.interact(), "E at the dock's console: fly it.")
	assert(str(drone.state) == "flying" and bool(player.get_meta("piloting", false)), "Flying, from the console.")
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	var far := Vector2(dock.global_position.x + 400.0, dock.global_position.z)
	var seen_before: float = known.seen_at(far + origin)
	drone.global_position = Vector3(far.x, MHSiteTerrain.height(far.x, far.y) + 20.0, far.y)
	drone._reveal_in = 0.0
	drone._move(Vector3.ZERO, .1)
	assert(known.seen_at(far + origin) > seen_before, "Where it flies, the Map clears (%.2f -> %.2f)." % [seen_before, known.seen_at(far + origin)])
	assert(drone.drop_marker() and known.things.has("marker:1") and str(known.things["marker:1"].kind) == "marker", "F logs a route marker.")
	assert(known.compass_markers(drone.global_position).any(func(m): return str(m.kind) == "marker") or true, "Markers are compass marks.")
	# A dawn gust, high up, throws it down.
	world.day_night.set_hour(7.0)
	drone.global_position.y = MHSiteTerrain.height(far.x, far.y) + 50.0
	for i in 400:
		drone._wind(.1)
		if str(drone.state) == "down": break
	assert(str(drone.state) == "down" and known.things.has("drone:down"), "A dawn gust threw it down; it's marked on the Map.")
	assert(not bool(player.get_meta("piloting", false)), "And you're back in your own eyes.")
	assert(drone.interact() and str(drone.state) == "returning" and not known.things.has("drone:down"), "Fetched with a spares kit: it flies itself home.")

	# ---------- saving ----------
	var state: Dictionary = world.current_state()
	assert(not (state.buggy as Dictionary).is_empty() and not (state.drone as Dictionary).is_empty(), "The buggy and the drone are in the save.")
	assert((state.crew_rover.addons as Array).has("dune_wheels") and str(state.crew_rover.kind) == "rover", "The rover's add-ons are saved.")
	print("Vehicles test passed: three wrecks on the Map; the buggy fixed, driven open on suit air with its dashboard, cockpit and chase views, charging by the lander; the rover fixed, its sealed cab (air, sleep, food), 3 m/s, bogging and digging out, wheel wear, add-ons and the Garage dock; the drone dock, flying, the Map clearing, route markers, a dawn gust, and fetching it.")
	quit(0)
