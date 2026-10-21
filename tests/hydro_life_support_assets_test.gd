extends SceneTree

# Hydroponics + Life Support pack: every item loads its new model, every rig
# action finds its parts, machines start running, and switching a machine off
# removes its output and power draw.
# Run with: godot --headless --path . --script res://tests/hydro_life_support_assets_test.gd
const ROOMS := {
	"hydroponics": ["grow_tray", "seedling_station", "nutrient_mixer", "harvest_cart", "greenhouse_planter"],
	"life_support": ["air_recycler", "water_reclaimer", "thermal_control_unit", "oxygen_reserve_tank", "oxygen_generator"],
}
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

	# Each room offers exactly the pack's items (plus shared items from other groups).
	for room in ROOMS:
		var in_group: Array = []
		for id in EquipmentCatalog.entries():
			if str(EquipmentCatalog.get_entry(id).get("group", "")) == room: in_group.append(id)
		in_group.sort()
		var expected: Array = ROOMS[room].duplicate()
		expected.sort()
		_check(in_group == expected, "%s holds exactly the pack items: %s" % [room, in_group])
	_check(str(EquipmentCatalog.get_entry("greenhouse_planter").get("label", "")) == "Large Planter", "the planter is relabelled Large Planter")

	var rigs := {}
	var x := -9.0
	for room in ROOMS:
		var cells := []
		for cx in range(int(x / 3) - 2, int(x / 3) + 3):
			for cz in range(-2, 3): cells.append(Vector2i(cx, cz + (0 if room == "hydroponics" else 8)))
		builder.zones.append({"kind": room, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 50 * cells.size()})
		x += 15.0
	builder._rebuild()
	var placed := 0
	for room in ROOMS:
		var origin := Vector3(-12.0 if room == "hydroponics" else 3.0, builder.habitat_base_y, -3.0 + (0.0 if room == "hydroponics" else 24.0))
		for id in ROOMS[room]:
			var entry := EquipmentCatalog.get_entry(id)
			_check(str(entry.get("asset_scene", "")).contains("room_refresh_v2") or str(entry.get("asset_scene", "")).contains("oxygen_generator_v1"), "%s uses the new pack scene" % id)
			_check(not str(entry.get("system_note", "")).is_empty(), "%s has an info card" % id)
			var at := origin + Vector3(float(placed % 3) * 2.6, 0, float(placed / 3 % 2) * 3.0)
			var visual := builder.free_interior_visual(id, at, 0.0)
			builder.place_free_interior_equipment(id, at, 0.0, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), visual)
			await process_frame
			var rig: Node = visual.get_node_or_null("Model")
			_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
			if rig == null: continue
			rigs[id] = rig
			placed += 1
			var actions: Array = rig.get("_actions")
			_check(not actions.is_empty(), "%s has interactions" % id)
			for index in range(actions.size()):
				var kind := str(actions[index].get("type", ""))
				var found := not (rig.get("_pivots").get(index, []) as Array).is_empty() or (rig.get("_lights") as Dictionary).has(index) or not (rig.get("_spinners").get(index, []) as Array).is_empty()
				_check(found, "%s action %d (%s) found its parts" % [id, index, kind])

	# Machines start running: the recycler supplies air, the tray grows food.
	var before := builder._equipment_effects()
	_check(int(before.life) == 4 and int(before.food) == 3, "running machines give their effects (life %d, food %d)" % [int(before.life), int(before.food)])
	rigs.air_recycler.interact()
	rigs.grow_tray.interact_secondary()
	var after := builder._equipment_effects()
	_check(int(after.life) == 0 and int(after.food) == 0, "switched-off machines stop (life %d, food %d)" % [int(after.life), int(after.food)])
	_check(int(after.power_draw) == int(before.power_draw) - 5, "and stop drawing power (%d → %d)" % [int(before.power_draw), int(after.power_draw)])

	# Harvest shrinks crops and they regrow; a fan only spins while running.
	rigs.grow_tray.interact()
	await process_frame
	var crop: Node3D = rigs.grow_tray.get("_pivots")[0][0].pivot
	_check(crop.scale.y < .5, "harvesting cuts the crops down")
	var fan: Node3D = rigs.air_recycler.get("_spinners")[0][0].pivot
	var held := fan.transform
	for i in 10: await process_frame
	_check(fan.transform.is_equal_approx(held), "the recycler fan stops when shut down")
	rigs.air_recycler.interact()
	for i in 10: await process_frame
	_check(not fan.transform.is_equal_approx(held), "the fan spins when running")

	# Switch states survive save and reload.
	var saved := builder.export_habitat_state()
	builder.restore_habitat_state(saved)
	await process_frame
	var reloaded := builder._equipment_effects()
	_check(int(reloaded.life) == 4 and int(reloaded.food) == 0, "reloaded: recycler running, grow lights still off (life %d, food %d)" % [int(reloaded.life), int(reloaded.food)])

	if failures == 0:
		print("Hydroponics + Life Support assets test passed: nine pack items, rigs, running machines, harvest and saved switches.")
	quit(1 if failures > 0 else 0)
