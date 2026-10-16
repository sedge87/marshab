extends SceneTree

# Interior inventory: catalogue integrity, placement rules, refunds and undo.
# Run with: godot --headless --path . --script res://tests/equipment_inventory_test.gd
func _initialize() -> void:
	var entries := EquipmentCatalog.entries()
	assert(entries.size() >= 46, "Every Interior Kit room item should be in the catalogue.")
	var group_ids: Array = []
	for group in EquipmentCatalog.groups(): group_ids.append(str(group.id))
	for id in entries:
		var entry: Dictionary = entries[id]
		assert(group_ids.has(str(entry.get("group", ""))), "%s needs a known inventory group." % id)
		assert(EquipmentCatalog.STATUS_BADGES.has(str(entry.get("status", ""))), "%s needs a catalogue status." % id)
		assert(int(entry.get("cargo_cost", 0)) > 0, "%s needs a cargo cost." % id)
		assert(["floor", "floor_wall", "wall", "ceiling"].has(str(entry.get("placement", ""))), "%s has an unknown placement." % id)
		var valid_zones: Array = entry.get("valid_zones", [])
		assert(not valid_zones.is_empty(), "%s must fit at least one zone." % id)
		for zone_kind in valid_zones:
			assert(BuildController.ZONE_TYPES.has(zone_kind), "%s lists unknown zone %s." % [id, zone_kind])
		if str(entry.get("status")) != "catalogue":
			assert((entry.get("effects", {}) as Dictionary).is_empty(), "%s is future/cosmetic so must not change resources yet." % id)
	assert(EquipmentCatalog.effects_text("grow_tray") == "+3 food · +1 happiness · −2 power · −1 water", "Effects line should summarise the grow tray.")

	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	world.add_child(builder)
	await process_frame
	builder.zones = [
		_zone("hydroponics", [Vector2i(0, 0), Vector2i(1, 0)]),
		_zone("living", [Vector2i(0, 1)])
	]
	builder._rebuild()
	var cargo_before := builder.used_cargo()
	assert(builder.equipment_invalid_reason("grow_tray", Vector2i(5, 5)) == "Point at a room", "Empty ground is not a room.")
	assert(builder.equipment_invalid_reason("grow_tray", Vector2i(0, 1)).begins_with("Fits in Hydroponics"), "Wrong zone should say where it fits.")
	assert(builder.place_equipment("grow_tray", Vector2i(0, 0)), "A grow tray fits in Hydroponics.")
	assert(builder.equipment_invalid_reason("seedling_station", Vector2i(0, 0)) == "This cell is already furnished", "One item per cell.")
	assert(int(builder._systems().food) == 3, "A placed grow tray produces food.")
	assert(builder.used_cargo() == cargo_before + 120, "Equipment uses cargo.")
	assert(int(builder.cargo_by_category().equipment) == 120, "Mission Control shows equipment cargo.")

	# UI path: greybox visual, history and undo.
	builder.equipment_id = "harvest_cart"
	builder._place_selected_equipment(Vector2i(1, 0))
	assert(builder.furnishing.get_child_count() == 1, "Placing from the inventory adds a greybox.")
	assert(int(builder._systems().food) == 3, "Cosmetic items have no resource effect.")
	builder._undo()
	assert(builder.equipment_at(Vector2i(1, 0)).is_empty(), "Undo removes the last placed item.")

	# Removing a room takes its furniture with it and refunds both.
	builder.equipment_id = "crew_bunk"
	builder._place_selected_equipment(Vector2i(0, 1))
	assert(int(builder._systems().berths) == 1, "A bunk gives a berth.")
	builder._remove_at(Vector2i(0, 1)) # first click: the bunk
	assert(builder.equipment_at(Vector2i(0, 1)).is_empty() and builder.counts_of("living") == 1, "Remove takes furniture before the room.")
	# Undo of a zone also takes the furniture placed inside it.
	builder._history.clear()
	builder._undo() # living (last zone) — empty now
	assert(builder.counts_of("living") == 0, "Undo falls back to the last zone without history.")
	builder.equipment_id = "seedling_station"
	builder._place_selected_equipment(Vector2i(1, 0))
	builder.zones.remove_at(0) # room removed by other means
	builder._prune_equipment()
	assert(builder.placed_equipment.is_empty(), "Equipment in a removed room is removed too.")
	builder.zones = [_zone("living", [Vector2i(0, 1)])]
	assert(builder.used_cargo() == int(builder.zones[0].cost), "All equipment cargo is refunded (%d vs %d, %s)." % [builder.used_cargo(), int(builder.zones[0].cost), builder.placed_equipment])

	print("Equipment inventory test passed: %d items, placement rules, refunds and undo." % entries.size())
	quit(0)

func _zone(kind: String, cells: Array) -> Dictionary:
	return {"kind": kind, "cells": cells, "cost": int(BuildController.ZONE_TYPES[kind].cost) * cells.size(), "door_direction": Vector2i(0, -1)}
