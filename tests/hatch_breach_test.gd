extends SceneTree

# Run with: godot --headless --path . --script res://tests/hatch_breach_test.gd
# 21 Nov: the bulkhead hatches hold the air. A room hatch standing open
# shares two rooms' air; shut, it keeps them apart. A breach slams the room
# hatches, so only the holed room vents; open the hatch again and the air
# evens out between the two.
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end: await physics_frame

func _room(kind: String, x0: int, w: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame._settings["gary_autonomy"] = false
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	var b: BuildController = world.builder
	b.zones = [_room("living", 0, 3), _room("galley", 3, 3), {"kind": "airlock", "cells": [Vector2i(1, 3)], "door_direction": Vector2i(0, 1), "cost": 1500}]
	b._rebuild()
	_check(b.place_interior_door(Vector2i(2, 1), Vector2i(1, 0)), "a hatch between the living quarters and the galley")
	for i in 10: await process_frame
	var hatch: AirlockDoor
	for d in get_nodes_in_group("airlock_door"):
		if d.door_label() == "INTERIOR": hatch = d
	var sim = b.simulation()
	var life = sim.life
	var inv: Dictionary = sim.inventory()
	var living := -1
	var galley := -1
	for i in (inv.rooms as Array).size():
		if str(inv.rooms[i].kind) == "living": living = i
		if str(inv.rooms[i].kind) == "galley": galley = i
	var map: Dictionary = life.sections(inv)
	_check(hatch != null and hatch.is_open() and map[living] == map[galley], "the hatch stands open: one section of air (%s)" % [map])
	# A breach in the living quarters: the alarm slams the hatch.
	life.start_breach(inv, str(inv.rooms[living].key))
	call_group("airlock_door", "on_habitat_alert", "breach", "critical")
	await _wait(1.5)
	_check(hatch.is_closed(), "the breach alarm shuts the hatch")
	map = life.sections(sim.inventory())
	_check(map[living] != map[galley], "shut, it keeps the air apart (%s)" % [map])
	sim.run_hours(1.0, 2.0, .25)
	var p_living := float(life.section_pressure.get(str(inv.rooms[living].key), 1.0))
	var p_galley := float(life.section_pressure.get(str(inv.rooms[galley].key), 1.0))
	_check(p_living < .9 and p_galley > .999, "only the holed room vents (living %.2f, galley %.2f)" % [p_living, p_galley])
	hatch.request_open()
	await _wait(1.0)
	_check(hatch.is_closed(), "GAR-Y can't reopen a hatch the alarm shut")
	hatch.toggle()
	await _wait(1.5)
	sim.run_hours(.05, 2.0, .05)
	p_living = float(life.section_pressure.get(str(inv.rooms[living].key), 1.0))
	p_galley = float(life.section_pressure.get(str(inv.rooms[galley].key), 1.0))
	_check(p_galley < .999 and absf(p_living - p_galley) < .02, "opened by hand, the air evens out and both rooms vent (living %.2f, galley %.2f)" % [p_living, p_galley])
	print("Hatch breach test %s." % ("passed" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures > 0 else 0)
