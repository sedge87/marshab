extends SceneTree

# General Habitat equipment and Mission Operations packs: items load with rigs, every action finds its parts,
# and the observation cards cycle.
# Run with: godot --headless --path . --script res://tests/general_ops_assets_test.gd
const ITEMS := ["fire_safety_station", "emergency_supply_lockbox", "first_aid_kit", "portable_interior_work_light", "supply_crate_small", "supply_crate_medium", "supply_crate_large", "mission_planning_console", "mars_survey_board", "communications_station"]
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
		if id in ["wall_cabin_heater", "portable_utility_heater", "first_aid_kit_wall"]: continue # heater pack; wall variant of the kit
		if str(EquipmentCatalog.get_entry(id).get("pack", "")) == "mars_habitat_furnishings_v1": continue   # later furnishings pack
		if str(EquipmentCatalog.get_entry(id).get("group", "")) in ["general", "communications"]: in_group.append(id)
	in_group.sort()
	var expected := ITEMS.duplicate(); expected.sort()
	_check(in_group == expected, "General and Mission Operations hold exactly the pack items: %s" % [in_group])
	var cells := []
	for x in range(-5, 6):
		for z in range(-2, 3): cells.append(Vector2i(x, z))
	builder.zones = [{"kind": "communications", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 1250}]
	builder._rebuild()
	var x := -15.0
	var rigs := {}
	for id in ITEMS:
		_check(str(EquipmentCatalog.get_entry(id).get("asset_scene", "")).contains("repack"), "%s uses the new pack scene" % id)
		_check(not str(EquipmentCatalog.get_entry(id).get("system_note", "")).is_empty(), "%s has an info card" % id)
		var at := Vector3(x, builder.habitat_base_y, 0)
		var visual := builder.free_interior_visual(id, at, 0.0)
		builder.place_free_interior_equipment(id, at, 0.0, Vector2i(roundi(at.x / 3), 0), visual)
		await process_frame
		var rig: Node = visual.get_node_or_null("Model")
		_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
		rigs[id] = rig
		x += 3.2
		for index in range((rig.get("_actions") as Array).size()):
			var action: Dictionary = rig.get("_actions")[index]
			var found := not (rig.get("_pivots").get(index, []) as Array).is_empty() or (rig.get("_lights") as Dictionary).has(index) or not (action.get("observations", []) as Array).is_empty()
			_check(found, "%s action %d (%s) found its parts" % [id, index, str(action.get("type", ""))])
	# The survey board draws a live map; crates and kits reveal contents.
	_check(not (rigs.mars_survey_board.get("_maps") as Dictionary).is_empty(), "the survey board has a live map")
	_check(rigs.supply_crate_large.get("_cavities").has(0), "crates show contents when opened")
	rigs.mars_survey_board.interact()
	_check(str(rigs.mars_survey_board.get("_maps")[0].mode) == "mars", "the selector switches to the Mars globe")
	_check(EquipmentCatalog.get_entry("first_aid_kit").get("valid_zones", []).has("galley"), "general items go in any room")
	if failures == 0:
		print("General + Mission Operations assets test passed: ten pack items, rigs, live map and crate contents.")
	quit(1 if failures > 0 else 0)
