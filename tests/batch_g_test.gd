extends SceneTree

# Run with: godot --headless --path . --script res://tests/batch_g_test.gd
# Batch G (Missions playtest, 24 Oct): the Communications Mast arrives in
# Mission 4; Mission 8's contact step needs a station in Mission Operations
# and the mast; the crew's Contact with Earth says which is missing; the
# redundancy step names what still needs a second; Mission 9 tests 4 sols;
# Mission 5 allows one reactor; and a wall-mounted strip can be picked for
# removal by aiming at the wall.
const INTERIOR := preload("res://scripts/interior_build_controller.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"
	MHGame.game_mode = "missions"
	MHMissions.reset()
	MHMissions.progress.current = "cargo_habitat"
	assert(not MHMissions.item_unlocked("comms_antenna"), "No mast in Mission 3.")
	MHMissions.progress.current = "crew_land"
	assert(MHMissions.item_unlocked("comms_antenna"), "The Communications Mast arrives in Mission 4.")
	assert(int(MHMissions.get_mission("storm_season").get("max_reactors", 99)) == 1, "Mission 5 brings one reactor.")
	assert(int(MHMissions.get_mission("hull_breach").sols) == 4, "Mission 9 tests 4 sols.")
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	MHMissions.progress.current = "crew_people"
	builder.zones = [{"kind": "communications", "cells": [Vector2i(0, 0)], "cost": 0, "door_direction": Vector2i(0, -1)},
		{"kind": "living", "cells": [Vector2i(1, 0)], "cost": 0, "door_direction": Vector2i(0, -1)}]
	builder._rebuild()
	var y := builder.habitat_base_y
	assert(not MHMissions.contact_ready(builder), "Nothing set up yet.")
	var at := Vector3(0, y, 0)
	builder.placed_interior.append({"placement_id": "station_1", "id": "communications_station", "position": at, "zone_cell": Vector2i.ZERO, "rotation_y": 0.0, "state": {}})
	assert(MHMissions.station_ready(builder) and not MHMissions.contact_ready(builder), "A station, but no mast yet.")
	var step: Dictionary = (MHMissions.get_mission("crew_people").steps as Array).filter(func(s): return str(s.id) == "comms")[0]
	assert(MHMissions.step_progress(step, builder) == "station ✓ · mast missing", "The step says the mast is missing (%s)." % MHMissions.step_progress(step, builder))
	builder.placed_surface.append({"id": "comms_antenna", "position": Vector3(9, 0, 9)})
	assert(MHMissions.contact_ready(builder), "Station and mast: contact is set up.")
	# The crew's need: the station must be in Mission Operations.
	builder.placed_interior[0].position = Vector3(3, y, 0)
	builder.placed_interior[0].zone_cell = Vector2i(1, 0)
	builder.simulation().invalidate()
	var sim: RefCounted = builder.simulation()
	var contact: Dictionary = (sim.life.needs(sim.inventory(), {1: true, 2: true, 3: true, 4: true}) as Array).filter(func(n): return str(n.id) == "contact")[0]
	assert(float(contact.score) == 0.0 and str(contact.missing).contains("communications station"), "A station outside Mission Operations doesn't count (%s)." % contact.missing)
	# Redundancy names what still needs a second.
	var redundancy: Dictionary = (MHMissions.get_mission("long_silence").steps as Array).filter(func(s): return str(s.id) == "redundancy")[0]
	var said := MHMissions.step_progress(redundancy, builder)
	assert(said.begins_with("0 of") and said.contains("still need a second"), "It names the machines still single (%s)." % said)
	# A thin wall strip: aiming at the wall right there picks it.
	builder.placed_interior.append({"placement_id": "strip_1", "id": "corridor_light_strip", "position": Vector3(0, y + .2, -1.45), "zone_cell": Vector2i.ZERO, "rotation_y": 0.0, "state": {}})
	var interior: Node = INTERIOR.new()
	interior.builder = builder
	assert(interior._wall_item_at(Vector3(.2, y + .25, -1.48)) == "strip_1", "Aiming at the wall beside the strip picks it.")
	assert(interior._wall_item_at(Vector3(0, y + 2.0, -1.48)).is_empty(), "Aiming well away from it doesn't.")
	interior.free()
	print("Batch G test passed: the mast in Mission 4, Mission 8's contact step and need, redundancy names, Mission 9's length, one reactor in Mission 5 and wall strips.")
	quit(0)
