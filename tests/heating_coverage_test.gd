extends SceneTree

# Heating coverage (23 Oct): one habitat temperature, but heat has to reach
# each room. Spot heaters warm their own room and the rooms next door (the
# rest is wasted); the thermal control unit reaches every room and gives
# about three times the heat for its power; rooms left short are cold spots.
# Rooms in a row: Living Quarters - Galley - Science Lab - Hydroponics.
# Run with: godot --headless --path . --script res://tests/heating_coverage_test.gd
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

## The row of rooms, with {room kind: [item id, count]} placed in it.
func _base(kit: Dictionary) -> BuildController:
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	for spec in [["living", 0, 2], ["galley", 2, 1], ["science", 3, 1], ["hydroponics", 4, 2]]:
		b.zones.append({"kind": spec[0], "cells": _block(spec[1], 0, spec[2], 2), "door_direction": Vector2i(0, -1), "cost": 0})
	var n := 0
	for kind in kit:
		var cell := Vector2i.ZERO
		for zone in b.zones:
			if str(zone.kind) == kind: cell = zone.cells[0]
		for k in range(int(kit[kind][1])):
			n += 1
			# Heaters on High.
			b.placed_interior.append({"placement_id": "h%d" % n, "id": kit[kind][0], "position": Vector3(cell.x * 3, 0, cell.y * 3), "zone_cell": cell, "state": {"heat": 2}})
	b.simulation().invalidate()
	b.simulation().habitat_temp = 21.0
	return b

func _run(b: BuildController) -> RefCounted:
	var sim = b.simulation()
	sim.run_hours(6.0, 2.0, .5)   # the cold small hours
	return sim

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.game_mode = "survival"
	MHGame.site_id = "plains"
	MHGame.debug_free_power = true   # heating only: power isn't the question here

	# Lots of heaters in one room: the far room stays cold and heat is wasted.
	var piled = _run(_base({"living": ["wall_cabin_heater", 60]}))
	_check((piled.cold_spots as Array).has("Hydroponics"), "heaters piled in Living Quarters leave Hydroponics a cold spot (%s)" % [piled.cold_spots])
	_check(not (piled.cold_spots as Array).has("Living Quarters"), "but Living Quarters itself is warm")
	_check(float(piled.last.get("heat_wasted_kw", 0.0)) > 0.0, "and some of their heat is wasted (%.1f kW)" % float(piled.last.get("heat_wasted_kw", 0.0)))

	# The same heaters spread out: no cold spots.
	var spread = _run(_base({"living": ["wall_cabin_heater", 15], "galley": ["wall_cabin_heater", 15], "science": ["wall_cabin_heater", 15], "hydroponics": ["wall_cabin_heater", 15]}))
	_check((spread.cold_spots as Array).is_empty(), "the same heaters spread out leave no cold spots (%s)" % [spread.cold_spots])
	_check(float(spread.habitat_temp) > float(piled.habitat_temp), "and the habitat is warmer (%.1f vs %.1f °C)" % [spread.habitat_temp, piled.habitat_temp])

	# A neighbour counts: a heater in the Galley warms Living Quarters and the Lab too.
	var shared = _base({"galley": ["wall_cabin_heater", 40]})
	var sim = shared.simulation()
	var rooms: Array = sim.inventory().rooms
	var galley := -1
	for i in range(rooms.size()):
		if str(rooms[i].kind) == "galley": galley = i
	var next_labels: Array = (rooms[galley].next as Array).map(func(r): return str(rooms[r].label))
	_check(next_labels.has("Living Quarters") and next_labels.has("Science Lab") and not next_labels.has("Hydroponics"), "the Galley's neighbours are Living Quarters and the Lab, not Hydroponics (%s)" % [next_labels])

	# The thermal control unit alone reaches every room.
	var central = _run(_base({"living": ["thermal_control_unit", 2]}))
	_check((central.cold_spots as Array).is_empty(), "a thermal control unit reaches every room (%s)" % [central.cold_spots])
	# ...and it's about three times as efficient: less power for the same warmth.
	var pump_kw := float(central.last.get("heat_pump_kw", 0.0))
	var heater_kw: float = 60 * MHResources.item_value("wall_cabin_heater", "power_kw", .36)
	_check(pump_kw > 0.0 and pump_kw < heater_kw / 2.0, "the heat pump uses far less power than the spread heaters (%.1f vs %.1f kW)" % [pump_kw, heater_kw])

	# Without power, the heaters do nothing.
	MHGame.debug_free_power = false
	var unpowered = _base({"living": ["wall_cabin_heater", 15], "galley": ["wall_cabin_heater", 15], "science": ["wall_cabin_heater", 15], "hydroponics": ["wall_cabin_heater", 15]})
	unpowered.simulation().battery_kwh = 0.0
	var dark = _run(unpowered)
	_check(not (dark.cold_spots as Array).is_empty() or float(dark.habitat_temp) < float(spread.habitat_temp), "no power, no heat")

	if failures == 0:
		print("Heating coverage test passed: piled heaters leave cold spots and waste heat, spread heaters cover the habitat, neighbours share, the heat pump reaches every room for a third of the power.")
	quit(1 if failures > 0 else 0)
