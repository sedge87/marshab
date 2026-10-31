extends SceneTree

# Your suit's life support (scripts/suit.gd) and the crew rover's air: it
# drains only outside, faster sprinting and (power) at night; it tops up in
# the airlock and at a suit service panel from the habitat's own oxygen and
# batteries, and from the rover's tank and battery; the vehicle bay refills
# the rover from the habitat; you black out with no oxygen in Survival and
# come round in the airlock, never in Freedom; Creative doesn't run it; and
# it's saved.
# Run with: godot --headless --path . --script res://tests/suit_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _world(mode: String, state: Dictionary) -> Node:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = mode
	MHGame.pending_save_state = state
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	world.set_tutorial_mode("off")
	var b = world.builder
	if b.zones.is_empty():
		b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
			{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
			{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
		b._rebuild()
		world._sync_crew_rover()
		# A battery bank and an oxygen tank: they arrive full.
		b.placed_interior.append({"placement_id": "suit_bat", "id": "battery_bank", "position": Vector3(0, 0, 0), "zone_cell": Vector2i(0, 0), "state": {}})
		b.placed_interior.append({"placement_id": "suit_o2", "id": "oxygen_reserve_tank", "position": Vector3(3, 0, 0), "zone_cell": Vector2i(1, 0), "state": {}})
	world.day_night.set_hour(12.0); world.day_night.frozen = true
	var sim = b.simulation()
	sim.invalidate(); sim.inventory()
	sim.o2_pct = 21.0
	for i in 5: await physics_frame
	return world

## Move the player and let the suit see where they are (process_frame comes
## just before nodes process, so two frames).
func _put(world: Node, at: Vector3) -> void:
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.suit._check = 0.0
	await process_frame
	await process_frame

func _initialize() -> void:
	var world: Node = await _world("survival", {"site_id": "plains", "builder": {}})
	var suit = world.suit
	var b = world.builder
	var sim = b.simulation()
	var y: float = b.habitat_base_y
	_check(suit != null and suit.active(), "Survival runs the suit")
	# Inside: nothing drains.
	await _put(world, Vector3(1.5, y + .3, 0))
	await process_frame
	_check(suit.where == "habitat", "in a room you're in the habitat (%s, inside %s, o2 %.1f)" % [suit.where, b.is_inside(world.player.global_position), sim.o2_pct])
	# Outside: two hours of oxygen at a walk, three of power by day.
	await _put(world, Vector3(-30, MHSiteTerrain_height(-30, -30) + 1.0, -30))
	await process_frame
	_check(suit.where == "outside", "out on the ground you're outside (%s)" % suit.where)
	suit.step(1.0)
	_check(absf(suit.o2 - .5) < .01 and absf(suit.power - 2.0 / 3.0) < .01, "an hour outside: half the oxygen, a third of the power (%.2f, %.2f)" % [suit.o2, suit.power])
	_check(suit.turn_back_hours() < suit.o2_hours_left(), "the turn-back time allows for the walk home")
	world.day_night.set_hour(23.0)
	var power_before: float = suit.power
	suit.step(.5)
	_check(absf((power_before - suit.power) - 1.0 / 3.0) < .01, "the heater doubles the power drain at night")
	world.day_night.set_hour(12.0)
	world.player.velocity = Vector3(8, 0, 0)
	_check(is_equal_approx(suit.breathing_rate(), 1.6), "sprinting, you breathe harder")
	world.player.velocity = Vector3.ZERO
	_check(not suit.nearest_refill().is_empty() and str(suit.nearest_refill().label) in ["AIRLOCK", "ROVER", "LANDER"], "the wrist knows the nearest refill")
	# The airlock: tops up from the habitat's reserve and batteries.
	var reserve: float = sim.o2_reserve_kg
	var kwh: float = sim.battery_kwh
	await _put(world, Vector3(0, y + .3, -3))
	await create_timer(3.0).timeout
	_check(suit.where == "habitat" and suit.full(), "in the airlock the suit fills (%s, o2 %.2f, power %.2f)" % [suit.where, suit.o2, suit.power])
	_check(sim.o2_reserve_kg < reserve and sim.battery_kwh < kwh, "from the habitat's oxygen and batteries (%.3f kg, %.2f kWh)" % [reserve - sim.o2_reserve_kg, kwh - sim.battery_kwh])
	# A suit service panel: a full refill at once.
	suit.o2 = .3; suit.power = .3
	await _put(world, Vector3(1.5, y + .3, 0))
	await process_frame
	suit.refill_at_panel()
	_check(suit.full(), "a suit service panel refills it at once")
	var keep := [sim.o2_reserve_kg, sim.battery_kwh]
	sim.o2_reserve_kg = 0.0; sim.battery_kwh = 0.0; sim.o2_pct = 19.6
	suit.o2 = .3
	suit.refill_at_panel()
	_check(suit.o2 < .31, "with nothing to spare in the habitat, there's nothing to refill from")
	sim.o2_reserve_kg = keep[0]; sim.battery_kwh = keep[1]; sim.o2_pct = 21.0
	# The rover: G beside it tops you up from its tank and battery.
	var rover = world.crew_rover
	_check(rover != null and str(rover.interaction_prompt().get("tertiary", "")) == "Top up suit", "the rover offers a suit top-up")
	suit.o2 = .5; suit.power = .5
	var battery: float = rover.battery
	var tank: float = rover.o2
	suit.top_up_from_rover()
	_check(suit.o2 > .99 and suit.power > .99, "topped up from the rover")
	_check(absf((tank - rover.o2) - 100.0 / 12.0) < .1 and absf((battery - rover.battery) - 4.0) < .1, "which drains its tank and battery (%.1f%%, %.1f%%)" % [tank - rover.o2, battery - rover.battery])
	# The bay refills the rover's tank from the habitat.
	rover.o2 = 50.0
	reserve = sim.o2_reserve_kg
	await create_timer(2.0).timeout
	_check(rover._in_bay() and rover.o2 > 55.0 and sim.o2_reserve_kg < reserve, "the bay refills the rover's tank from the habitat (%.1f%%)" % rover.o2)
	# Driving: the sealed cab, which breathes from the tank.
	world.player.global_position = rover.global_position + Vector3(-2.5, .2, 0)
	rover.interact()
	world.suit._check = 0.0
	await process_frame
	await process_frame
	_check(suit.where == "rover", "in the cab you're breathing the rover's air (%s, driving %s)" % [suit.where, world.player.get_meta("driving", false)])
	rover._get_out()
	# No oxygen in Survival: you black out and come round in the airlock.
	await _put(world, Vector3(-30, MHSiteTerrain_height(-30, -30) + 1.0, -30))
	await process_frame
	suit.o2 = 0.0
	for i in 30: await process_frame
	_check(suit.passed_out, "with no oxygen you black out")
	await create_timer(5.0).timeout
	var cell := Vector2i(roundi(world.player.global_position.x / 3.0), roundi(world.player.global_position.z / 3.0))
	_check(not suit.passed_out and cell == Vector2i(0, -1), "and come round in the airlock (%s)" % cell)
	# Saving (in a room, where nothing tops the suit up).
	await _put(world, Vector3(1.5, y + .3, 0))
	await process_frame
	suit.o2 = .42
	var saved: Dictionary = world.current_state()
	_check(is_equal_approx(float(saved.suit.o2), .42) and saved.crew_rover.has("o2"), "the suit and the rover's tank are saved")
	world.queue_free()
	await process_frame
	world = await _world("survival", saved)
	_check(is_equal_approx(world.suit.o2, .42), "and load back (%.2f)" % world.suit.o2)
	# Freedom: warnings, never blacking out.
	MHGame.game_mode = "freedom"
	await _put(world, Vector3(-30, MHSiteTerrain_height(-30, -30) + 1.0, -30))
	await process_frame
	world.suit.o2 = 0.0
	for i in 30: await process_frame
	_check(not world.suit.passed_out, "Freedom never lets you black out")
	# Creative: no suit to run.
	MHGame.game_mode = "creative"
	world.suit.o2 = .2
	for i in 3: await process_frame
	_check(not world.suit.active() and world.suit.o2 == 1.0, "Creative doesn't run the suit")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("Suit test passed: drain outside, sprinting and night, airlock and panel refills from the habitat, rover top-up and bay refill, the sealed cab, blacking out, Freedom and Creative, saving.")
	quit(1 if failures > 0 else 0)

func MHSiteTerrain_height(x: float, z: float) -> float:
	return preload("res://scripts/site_terrain.gd").height(x, z)
