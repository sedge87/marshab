extends SceneTree

# Run with: godot --headless --path . --script res://tests/radiation_shelter_test.gd
# Mission 7 playtest (25 Oct): shielding on the storm shelter's own room
# protects it, however big the rest of the base is. A full roof over the
# shelter adds 12 points; roofing another room doesn't shield the shelter
# (but eases everyone's background dose); outside wall panels and a shield
# block inside the shelter add their points × 1.5 over its floor.

const MHMissions := preload("res://scripts/mh_missions.gd")

var failures := 0

func _check(ok: bool, what: String) -> void:
	if ok: return
	failures += 1
	print("FAIL ", what)

func _cells(x0: int, z0: int, w: int, h: int) -> Array:
	var out := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): out.append(Vector2i(x, z))
	return out

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.save_directory = "user://test_habitats"; MHGame.game_mode = "survival"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	var b = world.builder
	world.player.global_position = Vector3(-40, 5, -40)
	# A six-square shelter and a big 24-square room beside it.
	var shelter_cells := _cells(4, 0, 3, 2)
	var big_cells := _cells(7, 0, 6, 4)
	b.zones = [{"kind": "living", "cells": shelter_cells, "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "galley", "cells": big_cells, "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var y: float = b.habitat_base_y
	var at := Vector3(14.0, y, 0.0)
	b.place_free_interior_equipment("storm_shelter_locker", at, 0.0, Vector2i(5, 0), b.free_interior_visual("storm_shelter_locker", at, 0.0))
	var bare: float = MHMissions.shelter_points(b)
	_check(absf(bare - 5.5) < .01, "the hull and the locker alone: 5.5 points (%.2f)" % bare)

	# Roof on the big room only: the shelter isn't shielded by it.
	b.place_upgrade("roof", {"cells": big_cells})
	_check(absf(MHMissions.shelter_points(b) - bare) < .01, "roofing another room doesn't shield the shelter (%.2f)" % MHMissions.shelter_points(b))
	var life = b.simulation().life
	var inv: Dictionary = b.simulation().inventory()
	_check(life.dose_factor(life.habitat_shield(inv)) < 1.0, "but it eases everyone's background dose")

	# Roof on the shelter: +12, whatever the size of the rest of the base.
	b.place_upgrade("roof", {"cells": shelter_cells})
	var roofed: float = MHMissions.shelter_points(b)
	_check(absf(roofed - (bare + 12.0)) < .01, "a full roof over the shelter adds 12 points (%.2f)" % roofed)

	# A regolith wall panel on the shelter's outside wall: 8 × 1.5 ÷ 6 = 2.
	var bay := {}
	for candidate in b._hull_bays:
		var inside: Vector2 = (candidate.mid as Vector2) - (candidate.outward as Vector2) * 1.5
		if shelter_cells.has(Vector2i(roundi(inside.x / 3.0), roundi(inside.y / 3.0))): bay = candidate; break
	_check(not bay.is_empty() and b.place_upgrade("regolith", {"mid": bay.mid, "dir": bay.dir, "outward": bay.outward}), "a regolith panel goes on the shelter's outside wall")
	_check(absf(MHMissions.shelter_points(b) - (roofed + 2.0)) < .01, "and adds 2 points to a six-square shelter (%.2f)" % MHMissions.shelter_points(b))

	# A shield block inside: 8 × 1.5 ÷ 6 = 2 more. That's past the 20-point line.
	var before: float = MHMissions.shelter_points(b)
	var block_at := Vector3(18.5, y, 2.0)
	b.place_free_interior_equipment("regolith_shield_block", block_at, 0.0, Vector2i(6, 1), b.free_interior_visual("regolith_shield_block", block_at, 0.0))
	_check(absf(MHMissions.shelter_points(b) - (before + 2.0)) < .01, "a shield block in the shelter adds 2 (%.2f)" % MHMissions.shelter_points(b))
	_check(MHMissions.shelter_points(b) >= 20.0, "a roof, a wall panel and a block shield a small shelter past 20 points (%.2f)" % MHMissions.shelter_points(b))

	if failures == 0:
		print("Radiation shelter test passed: the shelter's own roof (+12), walls and blocks shield it; other rooms ease the background dose.")
	quit(1 if failures > 0 else 0)
