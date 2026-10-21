extends SceneTree

# Interior inventory: catalogue integrity for every item, then the furnishing
# rules players actually use (free placement): room rules, cargo, effects,
# removal and rooms taking their furniture with them.
# (Rewritten 21 Oct: the old one-item-per-cell planner is no longer used.)
# Run with: godot --headless --path . --script res://tests/equipment_inventory_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.game_mode = "survival"
	# Catalogue integrity.
	var group_ids: Array = EquipmentCatalog.groups().map(func(g): return str(g.id))
	group_ids.append("general")
	var entries := EquipmentCatalog.entries()
	_check(entries.size() > 60, "the catalogue has its items (%d)" % entries.size())
	for id in entries:
		var entry := EquipmentCatalog.get_entry(id)
		if str(entry.get("group", "")) in ["outside", "surface"] or (entry.get("valid_zones", []) as Array).is_empty(): continue   # surface gear
		_check(group_ids.has(str(entry.get("group", ""))), "%s has a known group (%s)" % [id, entry.get("group", "")])
		_check(EquipmentCatalog.STATUS_BADGES.has(str(entry.get("status", ""))), "%s has a status" % id)
		_check(int(entry.get("cargo_cost", 0)) > 0, "%s has a cargo cost" % id)
		_check(["floor", "floor_wall", "wall", "ceiling"].has(str(entry.get("placement", ""))), "%s has a known placement" % id)
		for zone_kind in entry.get("valid_zones", []):
			_check(BuildController.ZONE_TYPES.has(zone_kind), "%s lists a real room (%s)" % [id, zone_kind])
		if str(entry.get("status")) != "catalogue":
			_check((entry.get("effects", {}) as Dictionary).is_empty(), "%s is future/cosmetic, so it has no effects" % id)
	_check(EquipmentCatalog.effects_text("grow_tray").contains("food"), "the effects line summarises the grow tray: %s" % EquipmentCatalog.effects_text("grow_tray"))

	# Free placement in rooms.
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	builder.zones = [_zone("hydroponics", [Vector2i(0, 0), Vector2i(1, 0)]), _zone("living", [Vector2i(0, 2), Vector2i(1, 2)])]
	builder._rebuild()
	var y := builder.habitat_base_y
	var in_hydro := Vector3(1.5, y, 0.0)
	var in_living := Vector3(1.5, y, 6.0)
	_check(builder.free_interior_invalid_reason("grow_tray", Vector3(30, y, 30), Vector3.UP).begins_with("Must be placed inside"), "empty ground is not a room")
	_check(builder.free_interior_invalid_reason("grow_tray", in_living, Vector3.UP).begins_with("Fits in"), "the wrong room says where the item fits")
	var cargo_before := builder.used_cargo()
	_check(builder.place_free_interior_equipment("grow_tray", in_hydro, 0.0, Vector2i(0, 0), builder.free_interior_visual("grow_tray", in_hydro, 0.0)), "a grow tray goes in Hydroponics")
	_check(builder.used_cargo() == cargo_before + int(EquipmentCatalog.get_entry("grow_tray").cargo_cost), "furniture uses cargo")
	_check(int(builder._systems().food) > 0, "a placed grow tray grows food")
	_check(builder.free_interior_invalid_reason("seedling_station", in_hydro, Vector3.UP) == "Too close to existing equipment", "items can't overlap")
	_check(builder.place_free_interior_equipment("crew_bunk", in_living, 0.0, Vector2i(0, 2), builder.free_interior_visual("crew_bunk", in_living, 0.0)), "a bunk goes in Living Quarters")
	_check(int(builder._systems().berths) >= 1, "a bunk gives a berth")
	var bunk_id := str((builder.placed_interior.filter(func(i): return i.id == "crew_bunk")[0] as Dictionary).placement_id)
	_check(not builder.remove_free_interior_equipment(bunk_id).is_empty() and int(builder._systems().berths) == 0, "removing the bunk removes its berth")
	# Removing a room takes its furniture, and its cargo comes back.
	builder.zones.remove_at(0)
	builder._rebuild()
	_check(builder.placed_interior.is_empty(), "furniture in a removed room goes with it")
	_check(builder.used_cargo() == int(builder.zones[0].cost), "all furniture cargo is refunded")
	if failures == 0:
		print("Equipment inventory test passed: %d catalogue items, room rules, cargo, effects and removal." % entries.size())
	quit(1 if failures > 0 else 0)

func _zone(kind: String, cells: Array) -> Dictionary:
	return {"kind": kind, "cells": cells, "cost": 800 * cells.size(), "door_direction": Vector2i(0, -1)}
