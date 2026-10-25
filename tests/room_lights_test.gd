extends SceneTree

const MHResources := preload("res://scripts/mh_resources.gd")

# Room lighting: one fill light per room (no light per fixture), on where you
# are (and where the crew are), dim elsewhere, wall-panel overrides that save,
# lighting power that follows the states, and everything off without power.
# Run with: godot --headless --path . --script res://tests/room_lights_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _room(kind: String, x0: int, w: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	var world := Node3D.new(); root.add_child(world)
	await process_frame
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"
	var b := BuildController.new(); b.display_only = true; world.add_child(b)
	await process_frame
	MHGame.debug_free_power = true
	b.zones = [_room("living", 0, 3), _room("galley", 3, 3)]
	b._rebuild()
	b.place_interior_door(Vector2i(2, 1), Vector2i(1, 0))
	await process_frame
	var sim = b.simulation()
	var living: String = sim._room_key(b.zones[0])
	var galley: String = sim._room_key(b.zones[1])

	var fills: Array = world.get_tree().get_nodes_in_group("room_fill")
	_check(fills.size() == 2, "one fill light per (3x3) room: %d" % fills.size())
	# Forward+ (26 Oct): every ceiling fixture has its own downlight.
	var fixtures: Array = b.root.find_children("CeilingLight*", "", true, false)
	var fixture_lights := 0
	for fixture in fixtures: fixture_lights += fixture.find_children("*", "SpotLight3D", true, false).size()
	_check(fixture_lights == fixtures.size() and fixture_lights > 0, "each ceiling fixture has its own downlight (%d of %d)" % [fixture_lights, fixtures.size()])
	_check(world.get_tree().get_nodes_in_group("room_light_panel").size() == 2, "a light panel in each room")

	# You're in the living quarters (no crew yet): it's on, the galley dims.
	sim.player_room = living
	sim.invalidate()
	b.update_room_lights(true)
	for i in 5: await process_frame
	_check(b.room_light_state(living) == "on" and b.room_light_state(galley) == "dim", "your room is on, the empty one dim")
	var living_fill: OmniLight3D = fills.filter(func(l): return l.get_meta("room_key") == living)[0]
	var galley_fill: OmniLight3D = fills.filter(func(l): return l.get_meta("room_key") == galley)[0]
	_check(living_fill.light_energy > .5 and not galley_fill.visible, "only the lit room has its fill light (%.2f / %s)" % [living_fill.light_energy, galley_fill.visible])
	var spots: Array = world.get_tree().get_nodes_in_group("room_fixture_light")
	var living_spots := spots.filter(func(l): return l.get_meta("room_key") == living)
	var galley_spots := spots.filter(func(l): return l.get_meta("room_key") == galley)
	_check(living_spots.all(func(l): return l.light_energy > 2.0) and galley_spots.all(func(l): return l.light_energy < .2), "the lit room's ceiling lights are on, the dim room's are faint night lights")

	# The galley's panel: Auto → On → Dim → Off → Auto.
	var panel: Node = world.get_tree().get_nodes_in_group("room_light_panel").filter(func(p): return p.room_key == galley)[0]
	panel.interact()
	_check(b.room_light_state(galley) == "on", "panel: On")
	panel.interact(); panel.interact()
	_check(b.room_light_state(galley) == "off", "panel: Off")
	var saved: Dictionary = sim.save()
	_check(str((saved.light_overrides as Dictionary).get(galley, "")) == "off", "overrides are saved")
	panel.interact()
	_check(not sim.light_overrides.has(galley) and b.room_light_state(galley) == "dim", "panel: back to Auto")

	# Power: at night, all-on costs more than auto (dim where nobody is).
	var night := 23.0
	sim.light_overrides = {living: "on", galley: "on"}
	var all_on := 0.0
	var auto := 0.0
	for room in sim.inventory().rooms:
		var spec := MHResources.room(str(room.kind))
		all_on += float(room.cells) * float(spec.get("light_kw_per_cell", .05))
	sim.light_overrides = {}
	var states: Dictionary = sim.room_light_states(night)
	for room in sim.inventory().rooms:
		var spec := MHResources.room(str(room.kind))
		auto += float(room.cells) * float(spec.get("light_kw_per_cell", .05)) * float(sim.LIGHT_FACTOR[states[room.key]])
	_check(auto < all_on * .7, "auto lighting uses less power than everything on (%.2f vs %.2f kW)" % [auto, all_on])

	# No power: everything off.
	MHGame.debug_free_power = false
	b.zones.append({"kind": "solar", "cells": [Vector2i(20, 20)], "door_direction": Vector2i(0, 1), "cost": 300})
	MHGame.sol_hour = 23.0
	if not b.grid_power_online():
		_check(b.room_light_state(living) == "off", "no power: lights off")
	if failures == 0:
		print("Room lights test passed: a fill light per room, on where you are, dim elsewhere, panels, saving and power.")
	quit(1 if failures > 0 else 0)
