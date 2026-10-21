extends SceneTree

# Vehicle Bay / EVA and Storage & Maintenance packs: items load with rigs, every action finds its parts,
# and the observation cards cycle.
# Run with: godot --headless --path . --script res://tests/eva_storage_assets_test.gd
const ITEMS := ["suit_rack", "rover_charger", "eva_tool_station", "tool_bench", "cargo_rack"]
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	var in_group: Array = []
	for id in EquipmentCatalog.entries():
		if str(EquipmentCatalog.get_entry(id).get("group", "")) in ["vehicle_bay", "storage"]: in_group.append(id)
	in_group.sort()
	var expected := ITEMS.duplicate(); expected.sort()
	_check(in_group == expected, "Vehicle bay + storage hold exactly the pack items: %s" % [in_group])
	var cells := []
	for x in range(-2, 3):
		for z in range(-2, 3): cells.append(Vector2i(x, z))
	builder.zones = [{"kind": "storage", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 1250}]
	builder._rebuild()
	var x := -6.0
	var rigs := {}
	for id in ITEMS:
		_check(str(EquipmentCatalog.get_entry(id).get("asset_scene", "")).contains("hailmary"), "%s uses the new pack scene" % id)
		_check(not str(EquipmentCatalog.get_entry(id).get("system_note", "")).is_empty(), "%s has an info card" % id)
		var at := Vector3(x, builder.habitat_base_y, 0)
		var visual := builder.free_interior_visual(id, at, 0.0)
		builder.place_free_interior_equipment(id, at, 0.0, Vector2i(roundi(at.x / 3), 0), visual)
		await process_frame
		var rig: Node = visual.get_node_or_null("Model")
		_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
		rigs[id] = rig
		x += 3.0
		for index in range((rig.get("_actions") as Array).size()):
			var action: Dictionary = rig.get("_actions")[index]
			var found := not (rig.get("_pivots").get(index, []) as Array).is_empty() or (rig.get("_lights") as Dictionary).has(index) or not (action.get("observations", []) as Array).is_empty()
			_check(found, "%s action %d (%s) found its parts" % [id, index, str(action.get("type", ""))])
	# Cupboards and cabinets open onto filled interiors.
	_check(rigs.tool_bench.get("_cavities").has(0) and rigs.eva_tool_station.get("_cavities").has(0), "tool cupboards have interiors")
	if failures == 0:
		print("Vehicle bay + storage assets test passed: five pack items, rigs and cupboard interiors.")
	quit(1 if failures > 0 else 0)
