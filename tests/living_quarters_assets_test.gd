extends SceneTree

# Living Quarters pack: every item loads from its new scene, its rig finds the
# parts it animates, interactions are saved, and lights draw power only when on.
# Run with: godot --headless --path . --script res://tests/living_quarters_assets_test.gd
const ITEMS := ["crew_bunk", "locker", "common_table", "task_light", "privacy_divider", "exercise_station"]
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _rig(holder: Node) -> Node:
	return holder.get_node_or_null("Model")

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	# Let the world join the scene first, so the builder's furniture container
	# (and every rig inside it) is really in the tree.
	await process_frame
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	MHGame.outside_temperature_c = -40.0

	# The pack replaced the room: six items, nothing else offered for Living Quarters.
	var living: Array = []
	for id in EquipmentCatalog.entries():
		if str(EquipmentCatalog.get_entry(id).get("group", "")) == "general": continue # shared items go anywhere
		if (EquipmentCatalog.get_entry(id).get("valid_zones", []) as Array).has("living"): living.append(id)
	living.sort()
	var expected := ITEMS.duplicate()
	expected.sort()
	_check(expected.all(func(id): return living.has(id)), "Living Quarters offers all six pack items (and shared items too): %s" % [living])

	var room := []
	for x in range(-2, 3):
		for z in range(-2, 3): room.append(Vector2i(x, z))
	builder.zones = [{"kind": "living", "cells": room, "door_direction": Vector2i(0, -1), "cost": 1250}]
	builder._rebuild()
	var placed := {}
	var spots := {"crew_bunk": Vector3(-3, 0, -4), "locker": Vector3(3, 0, -4), "common_table": Vector3(0, 0, 0), "task_light": Vector3(-7.42, 1.5, 0), "privacy_divider": Vector3(-3, 0, 4), "exercise_station": Vector3(3, 0, 4)}
	for id in ITEMS:
		var entry := EquipmentCatalog.get_entry(id)
		_check(str(entry.get("asset_scene", "")).contains("mars_living_quarters"), "%s uses the new pack scene" % id)
		_check(not str(entry.get("system_note", "")).is_empty(), "%s has an info card" % id)
		var at: Vector3 = spots[id] + Vector3(0, builder.habitat_base_y, 0)
		# The lamp hangs on the west wall, facing into the room (as the Interior tool places it).
		var wall_normal := Vector3(1, 0, 0) if id == "task_light" else Vector3.UP
		var yaw := atan2(-wall_normal.x, -wall_normal.z) if id == "task_light" else 0.0
		var visual := builder.free_interior_visual(id, at, yaw)
		_check(builder.place_free_interior_equipment(id, at, yaw, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), visual, wall_normal), "%s can be placed" % id)
		await process_frame
		var rig := _rig(visual)
		_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
		placed[id] = {"visual": visual, "rig": rig, "placement_id": str(visual.get_meta("interior_placement_id"))}

	# Every configured action found its parts.
	for id in ITEMS:
		var rig: Node = placed[id].rig
		for index in range((rig.get("_actions") as Array).size()):
			var action: Dictionary = rig.get("_actions")[index]
			var kind := str(action.get("type", ""))
			if kind == "sleep": continue   # no parts: it opens the sleep panel
			if kind in ["light", "inspect"]:
				_check((rig.get("_lights") as Dictionary).has(index), "%s %s found its parts" % [id, kind])
			else:
				_check(not (rig.get("_pivots").get(index, []) as Array).is_empty(), "%s %s found its parts" % [id, kind])

	# Lights draw power only while on, and the switch is saved.
	var power_before := int(builder._systems().draw)
	placed.crew_bunk.rig.interact_secondary()
	placed.task_light.rig.interact_secondary()
	var power_on := int(builder._systems().draw)
	_check(power_on == power_before + 2, "switching two lamps on adds their power draw (%d → %d)" % [power_before, power_on])
	_check(bool(builder.interior_state(placed.crew_bunk.placement_id).get("light", false)), "the bunk's light state is saved")

	# Doors, drawers, curtain and divider move and are saved.
	placed.locker.rig.interact()
	placed.crew_bunk.rig.interact()
	placed.crew_bunk.rig.interact_tertiary()
	placed.privacy_divider.rig.interact()
	for i in 40: await process_frame
	var door_pivot: Node3D = placed.locker.rig.get("_pivots")[0][0].pivot
	_check(absf(door_pivot.rotation.y) > 1.0, "the locker door swings open")
	_check(int(builder.interior_state(placed.crew_bunk.placement_id).get("drawers", 0)) == 1, "the first drawer is open and saved")
	_check(bool(builder.interior_state(placed.locker.placement_id).get("doors", false)), "the locker doors are saved open")

	# The prompt lists the actions plus the info card.
	var prompt: Dictionary = placed.crew_bunk.rig.interaction_prompt()
	_check(prompt.has("primary") and prompt.has("secondary") and prompt.has("tertiary") and prompt.get("info", "") == "About", "the bunk prompt lists E, F, G and I: %s" % prompt)

	# Save and reload: state comes back on the rebuilt items.
	var saved := builder.export_habitat_state()
	builder.restore_habitat_state(saved)
	await process_frame
	await process_frame
	var reopened: Node = null
	for child in builder.furnishing.get_children():
		if str(child.get_meta("equipment_id", "")) == "locker" and not child.is_queued_for_deletion(): reopened = _rig(child)
	_check(reopened != null and absf((reopened.get("_pivots")[0][0].pivot as Node3D).rotation.y) > 1.0, "a reloaded locker comes back with its doors open")
	_check(int(builder._systems().draw) == power_on, "reloaded lamps keep drawing power")


	if failures == 0:
		print("Living Quarters assets test passed: six pack items, rigs, saved interactions, light-linked power and info cards.")
	quit(1 if failures > 0 else 0)
