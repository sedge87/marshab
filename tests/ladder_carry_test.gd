extends SceneTree

# Run with: godot --headless --path . --script res://tests/ladder_carry_test.gd
# Batch C: a roof ladder takes you up onto a railed roof (which is outside)
# and back down; small things can be picked up, put down elsewhere, put back,
# and are never lost when saving mid-carry.
func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var y: float = b.habitat_base_y
	# A ladder on the south wall of the second cell.
	var target: Dictionary = b.upgrade_target_at("ladder", Vector3(3, y + 1.4, 1.45), Vector3(0, 0, -1))
	assert(b.place_upgrade("ladder", target), "The ladder goes on an outside wall.")
	await process_frame
	var ladders := get_nodes_in_group("roof_ladder")
	assert(ladders.size() == 1, "One ladder to climb.")
	assert(b.root.find_children("*", "StaticBody3D", true, false).filter(func(n): return n.is_in_group("wall_upgrade") and (n as StaticBody3D).collision_layer == 1).size() >= 4, "A solid rail round the roof.")
	var player: Node3D = world.player
	player.global_position = Vector3(3, y + .1, 3.2)
	var ladder: Node = ladders[0]
	assert(str(ladder.interaction_prompt().primary) == "Climb up", "From the ground: climb up.")
	ladder.interact()
	await create_timer(2.0).timeout
	for i in 10: await physics_frame
	assert(player.global_position.y > y + 2.9, "Up on the roof (%.2f)." % player.global_position.y)
	assert(not b.is_inside(player.global_position), "The roof is outside.")
	assert(str(ladder.interaction_prompt().primary) == "Climb down", "On the roof: climb down.")
	ladder.interact()
	await create_timer(2.0).timeout
	for i in 10: await physics_frame
	assert(player.global_position.y < y + 1.0 and (player.global_position - Vector3(3, 0, 1.5)).length() < 3.5, "Back on the ground by the ladder (%s)." % str(player.global_position))
	# Carrying: a plush toy on the floor.
	var carry: Node = world.carry
	var plush_at := Vector3(.5, y, .3)
	assert(b.place_free_interior_equipment("zero_g_plush", plush_at, 0.0, Vector2i.ZERO, b.free_interior_visual("zero_g_plush", plush_at, 0.0)), "A plush toy placed.")
	var pid := str(b.placed_interior[-1].placement_id)
	var visual: Node = b.furnishing.find_children("*", "", true, false).filter(func(n): return n.has_meta("interior_placement_id") and str(n.get_meta("interior_placement_id")) == pid)[0]
	assert(carry.pickable_id(visual) == pid, "Small things can be picked up.")
	assert(carry.pick_up(pid), "Picked up.")
	assert(b.placed_interior.filter(func(i): return str(i.placement_id) == pid).is_empty(), "It's in your hands, not the room.")
	carry._point = Vector3(3.5, y, .4)
	carry._valid = true
	player.rotation.y = 0.0
	assert(carry.put_down(), "Put down somewhere else.")
	var moved: Dictionary = b.placed_interior.filter(func(i): return str(i.id) == "zero_g_plush")[0]
	assert((moved.position as Vector3).distance_to(Vector3(3.5, y, .4)) < .05, "It's where you put it.")
	# Q: back where it was.
	assert(carry.pick_up(str(moved.placement_id)), "Picked up again.")
	carry.put_back()
	var back: Dictionary = b.placed_interior.filter(func(i): return str(i.id) == "zero_g_plush")[0]
	assert((back.position as Vector3).distance_to(Vector3(3.5, y, .4)) < .05, "Put back where it was picked up from.")
	# Saving while carrying puts it back first.
	carry.pick_up(str(back.placement_id))
	var state: Dictionary = world.current_state()
	assert((state.builder.placed_interior as Array).any(func(i): return str(i.id) == "zero_g_plush"), "A save never loses what you're carrying.")
	assert(carry.carrying.is_empty(), "And you're not carrying it any more.")
	# Big furniture isn't carried.
	var bunk_at := Vector3(4, y, -.5)
	b.place_free_interior_equipment("crew_bunk", bunk_at, 0.0, Vector2i(1, 0), b.free_interior_visual("crew_bunk", bunk_at, 0.0))
	var bunk_id := str(b.placed_interior[-1].placement_id)
	var bunk_visual: Node = b.furnishing.find_children("*", "", true, false).filter(func(n): return n.has_meta("interior_placement_id") and str(n.get_meta("interior_placement_id")) == bunk_id)[0]
	assert(carry.pickable_id(bunk_visual).is_empty(), "A bunk can't be picked up.")
	# Ladders go on from outside now: a Structure card on the Site plan, not an
	# interior tool, and in Missions it's always there.
	assert(str(BuildController.ZONE_INFO.ladder.cat) == "structure" and b.cell_cost("ladder") == 60, "A Roof Ladder card on the Site plan's Structure tab.")
	assert(not load("res://scripts/interior_build_controller.gd").STRUCTURE_TOOLS.any(func(t): return str(t.id) == "upgrade_ladder"), "Not an interior tool any more.")
	# Something sitting on a table can be looked at, through the table's box.
	var table_at := Vector3(.4, y, .2)
	b.placed_interior = b.placed_interior.filter(func(i): return str(i.id) != "crew_bunk")
	b._rebuild()
	assert(b.place_free_interior_equipment("common_table", table_at, 0.0, Vector2i.ZERO, b.free_interior_visual("common_table", table_at, 0.0)), "A table.")
	var table_id := str(b.placed_interior[-1].placement_id)
	var on_table := table_at + Vector3(.3, .92, 0)
	var on_reason: String = b.free_interior_invalid_reason("sample_jars", on_table, Vector3.UP, 0.0)
	assert(on_reason.is_empty(), "Sample jars fit on the table (%s)." % on_reason)
	b.place_free_interior_equipment("sample_jars", on_table, 0.0, Vector2i.ZERO, b.free_interior_visual("sample_jars", on_table, 0.0))
	var jars_id := str(b.placed_interior[-1].placement_id)
	await process_frame
	var hud: Node = get_first_node_in_group("explore_hud")
	var eye := on_table + Vector3(1.2, 1.0, 0)
	var picked: Node = hud._item_on_furniture(eye, (on_table + Vector3.UP * .05 - eye).normalized(), eye.distance_to(on_table) + .2, table_id)
	assert(picked != null and carry.pickable_id(picked) == jars_id, "Looking at the table where the jars sit picks the jars.")
	var other_side := table_at + Vector3(-1.6, 1.3, .3)
	assert(hud._item_on_furniture(other_side, (table_at + Vector3(-.7, .9, .3) - other_side).normalized(), 1.2, table_id) == null, "Looking at an empty part of the table doesn't.")
	print("Ladder and carry test passed: the ladder up and down, a railed roof that's outside, picking up, putting down, putting back and saving mid-carry.")
	quit(0)
