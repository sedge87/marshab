extends SceneTree

# Power & Engineering pack, the main isolator, and furnishings facing the
# player when first placed.
# Run with: godot --headless --path . --script res://tests/power_engineering_assets_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "plains"
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	var builder: BuildController = world.builder

	var in_group: Array = []
	for id in EquipmentCatalog.entries():
		if str(EquipmentCatalog.get_entry(id).get("group", "")) == "power": in_group.append(id)
	in_group.sort()
	_check(in_group == ["battery_bank", "power_distribution_panel"], "Power holds exactly the pack items: %s" % [in_group])

	var cells := []
	for x in range(-9, -5):
		for z in range(-6, -3): cells.append(Vector2i(x, z))
	builder.zones = [{"kind": "engineering", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}, {"kind": "solar", "cells": [Vector2i(-7, -9)], "door_direction": Vector2i(0, 1), "cost": 50}]
	builder._rebuild()
	MHGame.sol_hour = 12.0
	var y := builder.habitat_base_y
	var rigs := {}
	for spec in [["power_distribution_panel", Vector3(-24, y, -15)], ["battery_bank", Vector3(-20, y, -15)]]:
		var id: String = spec[0]
		_check(str(EquipmentCatalog.get_entry(id).get("placement", "")) == "floor", "%s stands on the floor" % id)
		var visual := builder.free_interior_visual(id, spec[1], 0.0)
		builder.place_free_interior_equipment(id, spec[1], 0.0, Vector2i(roundi(spec[1].x / 3), roundi(spec[1].z / 3)), visual)
		await process_frame
		var rig: Node = visual.get_node_or_null("Model")
		_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
		rigs[id] = rig
		for index in range((rig.get("_actions") as Array).size()):
			var found := not (rig.get("_pivots").get(index, []) as Array).is_empty() or (rig.get("_lights") as Dictionary).has(index)
			_check(found, "%s action %d found its parts" % [id, index])

	# The main isolator cuts generation and restores it.
	var before := int(builder._systems().generation)
	_check(before > 0, "the solar array generates at noon (%d)" % before)
	rigs.power_distribution_panel.interact()
	_check(int(builder._systems().generation) == 0 and bool(builder._systems().isolated), "isolator off: no power reaches the habitat")
	_check(not builder.grid_power_online(), "isolator off: the grid is offline")
	rigs.power_distribution_panel.interact()
	_check(int(builder._systems().generation) == before, "isolator on: power restored")

	# Placing a floor item: its front (model -Z) faces back towards the player.
	var interior = world.interior_builder
	interior.selected_id = "battery_bank"
	interior.rotation_offset = 0.0
	var yaw: float = interior._placement_yaw(Vector3.UP)
	var front := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var looking: Vector3 = (world.player as Node3D).global_transform.basis * Vector3(0, 0, -1)
	_check(front.dot(looking) < -.99, "a newly placed item faces the player (dot %.2f)" % front.dot(looking))

	if failures == 0:
		print("Power & Engineering assets test passed: pack items, rigs, main isolator and placement facing.")
	quit(1 if failures > 0 else 0)
