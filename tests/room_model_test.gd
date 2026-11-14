extends SceneTree

# A3, the room model (docs/rooms-and-equipment.md; scripts/room_types.gd):
# the eight renamed rooms, the cut room types and their kit, the walker core,
# key pieces (free, and where they go), the bonuses, and core upgrades.
# Run with: godot --headless --path . --script res://tests/room_model_test.gd
var failures := 0
var world: Node3D

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _block(x0: int, z0: int, w: int, d: int) -> Array:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d): cells.append(Vector2i(x, z))
	return cells

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	MHGame.site_id = "plains"
	MHGame.debug_free_power = true
	MHGame.game_mode = "survival"

	# ---- names and cut rooms ----
	var names := {"engineering": "Workshop", "science": "Lab", "living": "Quarters", "galley": "Galley", "hydroponics": "Greenhouse",
		"storage": "Storage", "vehicle_bay": "Garage", "medical": "Shelter", "general": "Walker Core"}
	for id in names: _check(str(BuildController.ZONE_TYPES[id].label) == names[id], "%s is called %s (%s)" % [id, names[id], BuildController.ZONE_TYPES[id].label])
	for id in ["life_support", "hygiene", "communications", "waste_management"]:
		_check(not BuildController.zone_offered(id), "%s is no longer offered" % id)
	for id in EquipmentCatalog.entries():
		var zones: Array = EquipmentCatalog.get_entry(str(id)).get("valid_zones", [])
		for cut in ["life_support", "hygiene", "communications", "waste_management"]:
			_check(not zones.has(cut), "%s no longer lists %s" % [id, cut])
	for id in ["air_recycler", "water_reclaimer", "oxygen_generator", "battery_bank", "power_distribution_panel"]:
		_check((EquipmentCatalog.get_entry(id).valid_zones as Array).has("general"), "%s fits the core" % id)
	_check((EquipmentCatalog.get_entry("hygiene_shower").valid_zones as Array).has("living"), "the shower moved to Quarters")
	_check((EquipmentCatalog.get_entry("communications_station").valid_zones as Array).has("science"), "the comms station moved to the Lab")
	for kind in MHRoomTypes.ROOMS:
		var key := MHRoomTypes.key_of(str(kind))
		_check(BuildController.still_fits(key, str(kind)), "%s's key piece %s fits it" % [kind, key])

	# ---- a new Survival game: core upgrades gate room types ----
	MHChapterOne.reset()
	_check(MHRoomTypes.gated(), "a new Survival game gates room types")
	_check(MHRoomTypes.locked_reason("living").is_empty() and MHRoomTypes.locked_reason("storage").is_empty(), "Quarters and Storage are open from the start")
	for kind in ["galley", "hydroponics", "engineering", "science", "vehicle_bay", "medical"]:
		_check(not MHRoomTypes.locked_reason(kind).is_empty(), "%s waits for a core upgrade" % kind)
	_check(MHRoomTypes.locked_reason("galley").contains("no plan"), "without its plan it says so (%s)" % MHRoomTypes.locked_reason("galley"))
	var learned := MHChapterOne.learn_after("water")
	_check(learned.has("core_water_loop") and MHRoomTypes.plan_known("water_loop"), "the water step sends the water-loop plan (%s)" % str(learned))
	_check(MHChapterOne._plan_message("core_water_loop").title.begins_with("New core upgrade"), "its message talks about the core")
	MHChapterOne.feedstock_kg = 50.0
	_check(not MHRoomTypes.fit_reason("water_loop").is_empty() and not MHRoomTypes.fit("water_loop"), "not enough feedstock: it won't fit")
	MHChapterOne.feedstock_kg = 1000.0
	_check(MHRoomTypes.fit("water_loop"), "the water loop fits")
	_check(is_equal_approx(MHChapterOne.feedstock_kg, 1000.0 - MHRoomTypes.cost("water_loop")), "it took its feedstock")
	_check(MHRoomTypes.locked_reason("galley").is_empty() and MHRoomTypes.locked_reason("hydroponics").is_empty() and not MHRoomTypes.locked_reason("science").is_empty(), "Galley and Greenhouse open; the Lab still waits")
	_check(not MHRoomTypes.fit("water_loop"), "an upgrade fits once")
	# Saved and loaded.
	var saved := MHChapterOne.export_state()
	MHChapterOne.reset()
	_check(not MHRoomTypes.is_fitted("water_loop"), "a new game starts with none fitted")
	MHChapterOne.load_state(saved, true)
	_check(MHRoomTypes.is_fitted("water_loop") and not MHRoomTypes.is_fitted("shielding"), "fitted upgrades load")
	var older := saved.duplicate(true); older.erase("rooms")
	MHChapterOne.load_state(older, true)
	_check(MHRoomTypes.is_fitted("shielding") and MHRoomTypes.is_fitted("lab_services"), "a save from before the upgrades has every room open")
	MHChapterOne.reset()

	# ---- key pieces: free, worked out from the rooms ----
	var b := BuildController.new()
	b.display_only = true
	world.add_child(b)
	await process_frame
	b.zones.append({"kind": "general", "cells": _block(0, 0, 2, 3), "door_direction": Vector2i(0, -1), "cost": 0, "carried": true})
	var quarters := {"kind": "living", "cells": _block(2, 0, 2, 2), "door_direction": Vector2i(0, -1), "cost": 0, "key_piece": true}
	b.zones.append(quarters)
	_check(MHChapterOne.available("crew_bunk", b) == 1, "a new Quarters brings a free bunk (%d)" % MHChapterOne.available("crew_bunk", b))
	_check(MHChapterOne.ready_to_place(b).has("crew_bunk"), "it waits on the Unpacked tab until it's placed")
	_check(MHChapterOne.item_reason("crew_bunk", b).is_empty(), "so it can be placed")
	b.placed_interior.append({"placement_id": "k1", "id": "crew_bunk", "position": Vector3(2 * 3 + 1.5, b.habitat_base_y, 1.5), "zone_cell": Vector2i(2, 0)})
	_check(MHChapterOne.available("crew_bunk", b) == 0, "placed, it's used")
	_check(MHRoomTypes.key_inside(b, quarters), "the bunk is inside: the bonus works")
	_check(MHRoomTypes.bonus_room_at(b, Vector3(7.5, b.habitat_base_y + 1.0, 1.5)) == "living", "standing in Quarters with its bunk")
	b.placed_interior.clear()
	_check(not MHRoomTypes.key_inside(b, quarters) and MHRoomTypes.bonus_room_at(b, Vector3(7.5, b.habitat_base_y + 1.0, 1.5)) == "", "no bunk, no bonus")
	b.zones.erase(quarters)
	_check(MHChapterOne.available("crew_bunk", b) == 0, "removing the room takes its free bunk back")

	# ---- bonuses only: the core prints at full speed, a Workshop faster ----
	b.placed_interior.append({"placement_id": "f1", "id": "fabricator", "position": Vector3(1.5, 0, 1.5), "zone_cell": Vector2i(0, 0)})
	_check(is_equal_approx(MHChapterOne.fabricator_speed(b), 1.0), "the core's Print Shop runs at full speed (%.2f)" % MHChapterOne.fabricator_speed(b))
	b.zones.append({"kind": "engineering", "cells": _block(6, 0, 2, 2), "door_direction": Vector2i(0, -1), "cost": 0})
	b.placed_interior[0].position = Vector3(6 * 3 + 1.5, 0, 1.5)
	_check(is_equal_approx(MHChapterOne.fabricator_speed(b), MHRoomTypes.WORKSHOP_PRINT), "a Workshop's prints faster (%.2f)" % MHChapterOne.fabricator_speed(b))
	var hazards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hazards.json"))
	_check((hazards.crew.noisy_rooms as Array).is_empty() and (hazards.crew.noisy_items as Array).is_empty(), "no noise penalties")

	# ---- the core: only from the walker ----
	var rules := preload("res://scripts/build_rules.gd")
	_check(rules.offered(b, "general"), "no walker (Creative, tests): the core can be drawn")

	# ---- older saves: cut rooms convert ----
	var state := {"zones": [{"kind": "life_support", "cells": _block(20, 20, 2, 2), "door_direction": Vector2i(0, -1)},
		{"kind": "communications", "cells": _block(24, 20, 2, 2), "door_direction": Vector2i(0, -1)},
		{"kind": "hygiene", "cells": _block(28, 20, 1, 2), "door_direction": Vector2i(0, -1)}]}
	b.restore_habitat_state(state)
	var kinds: Array = b.zones.map(func(z): return str(z.kind))
	_check(kinds == ["engineering", "science", "living"], "cut rooms load as the Workshop, Lab and Quarters (%s)" % str(kinds))

	print("room_model_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
