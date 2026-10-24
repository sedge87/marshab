extends SceneTree

# Run with: godot --headless --path . --script res://tests/wall_upgrades_test.gd
# Batch C: wall and roof upgrades. Shielding goes on outside walls (never a
# window bay) and roofs and raises a room's shield points; sound insulation
# goes on shared walls and stops a noisy neighbour; they cost cargo (regolith
# is printable), save, come off again, unlock in Missions 7 and 8, and old
# shield blocks in a save turn into upgrades.
const WALL_UPGRADES := preload("res://scripts/wall_upgrades.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.game_mode = "survival"
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	# Living Quarters (0,0)-(1,0), Engineering next door at (2,0).
	builder.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "cost": 0, "door_direction": Vector2i(0, -1)},
		{"kind": "engineering", "cells": [Vector2i(2, 0)], "cost": 0, "door_direction": Vector2i(0, -1)}]
	builder._rebuild()
	var y := builder.habitat_base_y
	var sim: RefCounted = builder.simulation()
	# Aim at the north outside wall of the living room, from inside.
	var outer: Dictionary = builder.upgrade_target_at("regolith", Vector3(0, y + 1.4, -1.45), Vector3(0, 0, 1))
	assert(not outer.is_empty(), "An outside wall is a target for shielding.")
	assert(builder.upgrade_target_at("acoustic", Vector3(0, y + 1.4, -1.45), Vector3(0, 0, 1)).is_empty(), "But not for sound insulation.")
	var cargo_before: int = builder._total_cargo()
	assert(builder.place_upgrade("regolith", outer), "Regolith shielding placed.")
	assert(builder._total_cargo() - cargo_before == 900, "It costs 900 kg (%d)." % (builder._total_cargo() - cargo_before))
	assert(builder.printable_cargo() >= 900, "And it can be printed from Mars soil.")
	assert(not builder.upgrade_invalid_reason("water", outer).is_empty(), "One upgrade per wall bay.")
	assert(builder.window_invalid_reason(builder.window_target_at(Vector3(0, y + 1.4, -1.45))) == "This wall bay is shielded", "No window in a shielded bay.")
	# The roof: aim at the ceiling, the whole room gets it.
	var roof: Dictionary = builder.upgrade_target_at("roof", Vector3(1.5, y + 2.9, 0), Vector3(0, -1, 0))
	assert((roof.get("cells", []) as Array).size() == 2, "Roof shielding covers the whole room.")
	builder.place_upgrade("roof", roof)
	sim.invalidate()
	var living_index := (sim.inventory().rooms as Array).map(func(r): return str(r.kind)).find("living")
	var rating: float = sim.life.shield_rating(sim.inventory(), living_index)
	assert(is_equal_approx(rating, 5.0 + (8.0 + 16.0) / 2.0), "5 for the hull + (one wall and the roof) ÷ 2 squares = 17 (%.1f)." % rating)
	# Noise: Engineering next door keeps them awake until the shared wall is insulated.
	var sleep_need := func() -> Dictionary: return (sim.life.needs(sim.inventory(), {1: true, 2: true, 3: true, 4: true}) as Array).filter(func(n): return str(n.id) == "sleep")[0]
	assert(str(sleep_need.call().missing).contains("noisy"), "Engineering next door is noisy (%s)." % sleep_need.call().missing)
	var shared: Dictionary = builder.upgrade_target_at("acoustic", Vector3(4.45, y + 1.4, 0), Vector3(-1, 0, 0))
	assert(not shared.is_empty(), "The wall between the rooms takes sound insulation.")
	assert(builder.upgrade_target_at("regolith", Vector3(4.45, y + 1.4, 0), Vector3(-1, 0, 0)).is_empty(), "But not shielding: it isn't an outside wall.")
	builder.place_upgrade("acoustic", shared)
	sim.invalidate()
	assert(not str(sleep_need.call().missing).contains("noisy"), "Insulated: quiet now (%s)." % sleep_need.call().missing)
	# Saved and restored.
	var state: Dictionary = builder.export_habitat_state()
	assert((state.wall_upgrades as Array).size() == 4, "Four records saved: a wall, two roof squares and the insulation.")
	builder.restore_habitat_state(state)
	assert(builder.wall_upgrades.size() == 4, "And restored.")
	# Removing the roof takes it off the whole room.
	var roof_index: int = builder.upgrade_index_near(Vector3(1.5, y + 2.9, 0), Vector3(0, -1, 0))
	assert(roof_index >= 0, "The remove tool finds the roof.")
	builder.remove_upgrade(roof_index)
	assert(builder.wall_upgrades.filter(func(r): return str(r.kind) == "roof").is_empty(), "The whole roof comes off together.")
	# Removing a room drops its upgrades.
	builder.zones = builder.zones.filter(func(z): return str(z.kind) != "engineering")
	builder._rebuild()
	assert(builder.wall_upgrades.filter(func(r): return str(r.kind) == "acoustic").is_empty(), "Insulation goes when the wall stops being shared.")
	# Missions: shielding arrives in Mission 7, insulation in Mission 8.
	MHGame.game_mode = "missions"
	MHMissions.reset()
	MHMissions.progress.current = "self_sufficiency"
	assert(not MHMissions.structure_unlocked("upgrade_regolith"), "No shielding before Mission 7.")
	MHMissions.progress.current = "solar_shelter"
	assert(MHMissions.structure_unlocked("upgrade_regolith") and MHMissions.structure_unlocked("upgrade_roof") and not MHMissions.structure_unlocked("upgrade_acoustic"), "Mission 7 brings shielding, not insulation.")
	MHMissions.progress.current = "crew_people"
	assert(MHMissions.structure_unlocked("upgrade_acoustic"), "Mission 8 brings insulation.")
	assert(MHMissions.structure_unlocked("window"), "Tools no mission names are always there.")
	MHGame.game_mode = "survival"
	# An older save with shield blocks standing in the room.
	builder.wall_upgrades.clear()
	var old := builder.export_habitat_state()
	old.placed_interior = [{"placement_id": "b1", "id": "regolith_shield_block", "position": Vector3(0, y, 0), "zone_cell": Vector2i.ZERO, "rotation_y": 0.0, "state": {}},
		{"placement_id": "b2", "id": "water_wall_panel", "position": Vector3(3, y, 0), "zone_cell": Vector2i(1, 0), "rotation_y": 0.0, "state": {}}]
	builder.restore_habitat_state(old)
	assert(builder.placed_interior.filter(func(i): return str(i.id) in ["regolith_shield_block", "water_wall_panel"]).is_empty(), "The old blocks are gone from the room.")
	assert(builder.wall_upgrades.size() == 2 and builder.wall_upgrades.any(func(r): return str(r.kind) == "water"), "They became a regolith wall and a water wall (%s)." % str(builder.wall_upgrades))
	assert(not builder.free_interior_invalid_reason("regolith_shield_block", Vector3(0, y, 0), Vector3.UP).is_empty(), "Old blocks can't be placed any more.")
	# The roof rail runs round the outside of the whole base only: a free-shape
	# room's outline (not every square inside it), and never between rooms.
	var outline := PackedVector2Array([Vector2(-1.5, -1.5), Vector2(4.5, -1.5), Vector2(4.5, 4.5), Vector2(-1.5, 4.5)])
	builder.zones = [{"kind": "medical", "cells": builder._freeform_cells(outline), "outline": outline, "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "living", "cells": [Vector2i(2, 0)], "door_direction": Vector2i(0, -1), "cost": 0}]
	builder._rebuild()
	var edges: Array = WALL_UPGRADES._outer_edges(builder)
	assert(edges.size() == 7, "A free-shape room's 4 sides (one only partly open) and a square room's 3 open sides (%d)." % edges.size())
	var east: Array = edges.filter(func(e): return absf((e[0] as Vector2).x - 4.5) < .01 and absf((e[1] as Vector2).x - 4.5) < .01)
	assert(east.size() == 1 and absf((east[0][0] as Vector2).distance_to(east[0][1]) - 3.0) < .01, "Where it meets the living room, no rail: only the open half of that side (%s)." % str(east))
	assert(edges.all(func(e): return not builder._is_habitat_zone(builder._zone_at_point(((e[0] as Vector2) + (e[1] as Vector2)) * .5 + (e[2] as Vector2) * .3))), "Every rail edge has open ground beyond it.")
	print("Wall upgrades test passed: shielding on outside walls and roofs, no windows there, cargo, insulation against noise, saving, removing, mission unlocks and old blocks converted.")
	quit(0)
