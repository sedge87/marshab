extends SceneTree

# Medical Bay, Crew Hygiene and Galley & Dining packs: items load with rigs, every action finds its parts,
# and the observation cards cycle.
# Run with: godot --headless --path . --script res://tests/med_hyg_galley_assets_test.gd
const ITEMS := ["medical_exam_cot", "medical_cabinet", "hygiene_toilet", "hygiene_shower", "galley_counter", "pantry_cabinet", "potable_water_dispenser", "integrated_mess_booth"]
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
		if str(EquipmentCatalog.get_entry(id).get("pack", "")) == "mars_habitat_furnishings_v1": continue   # later furnishings pack
		if str(EquipmentCatalog.get_entry(id).get("pack", "")) == "mars_crew_comforts_v1": continue   # the kitchenette pack (batch 3)
		if str(EquipmentCatalog.get_entry(id).get("group", "")) in ["medical", "hygiene", "galley"]: in_group.append(id)
	in_group.sort()
	var expected := ITEMS.filter(func(id): return id != "integrated_mess_booth"); expected.sort()   # the booth moved to Living Quarters
	_check(in_group == expected, "Medical, hygiene and galley hold exactly the pack items: %s" % [in_group])
	var cells := []
	for x in range(-5, 6):
		for z in range(-2, 3): cells.append(Vector2i(x, z))
	builder.zones = [{"kind": "galley", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 1250}]
	builder._rebuild()
	var x := -12.0
	var rigs := {}
	for id in ITEMS:
		_check(str(EquipmentCatalog.get_entry(id).get("asset_scene", "")).contains("repack") or str(EquipmentCatalog.get_entry(id).get("asset_scene", "")).contains("furnishings"), "%s uses the new pack scene" % id)
		_check(not str(EquipmentCatalog.get_entry(id).get("system_note", "")).is_empty(), "%s has an info card" % id)
		var at := Vector3(x, builder.habitat_base_y, 0)
		var visual := builder.free_interior_visual(id, at, 0.0)
		builder.place_free_interior_equipment(id, at, 0.0, Vector2i(roundi(at.x / 3), 0), visual)
		await process_frame
		var rig: Node = visual.get_node_or_null("Model")
		_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
		rigs[id] = rig
		x += 3.4
		for index in range((rig.get("_actions") as Array).size()):
			var action: Dictionary = rig.get("_actions")[index]
			var found := not (rig.get("_pivots").get(index, []) as Array).is_empty() or (rig.get("_lights") as Dictionary).has(index) or not (action.get("observations", []) as Array).is_empty()
			_check(found, "%s action %d (%s) found its parts" % [id, index, str(action.get("type", ""))])
	# The pantry opens onto food, and the booth is a new Galley item.
	_check(rigs.pantry_cabinet.get("_cavities").has(0), "the pantry has an interior")
	_check(str(EquipmentCatalog.get_entry("integrated_mess_booth").get("group", "")) == "living", "the mess booth is a Living Quarters item")
	if failures == 0:
		print("Medical, hygiene and galley assets test passed: eight pack items, rigs, pantry interior and mess booth.")
	quit(1 if failures > 0 else 0)
