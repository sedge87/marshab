class_name EquipmentCatalog
extends RefCounted

## Shared equipment definitions for the Build-mode interior inventory.
## Keeping the data separate means art can be replaced without changing game rules.
const CATALOG_PATH := "res://data/equipment_catalog.json"
const MHResources := preload("res://scripts/mh_resources.gd")
## Badge text and tone for each catalogue status (matches the Interior Kit board).
const STATUS_BADGES := {"catalogue": ["In catalogue", "valid"], "future": ["Future", "info"], "cosmetic": ["Cosmetic", "neutral"]}
static var _entries: Dictionary = {}
static var _groups: Array = []

static func entries() -> Dictionary:
	if not _entries.is_empty():
		return _entries
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_warning("Equipment catalogue is missing: %s" % CATALOG_PATH)
		return _entries
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Equipment catalogue is not valid JSON")
		return _entries
	for entry in (parsed as Dictionary).get("equipment", []):
		if entry is Dictionary and not str(entry.get("id", "")).is_empty():
			# Cargo mass is tuned in the balance spreadsheet (data/resources.json).
			var balance := MHResources.item(str(entry.get("id", "")))
			if balance.has("cargo_kg"): entry["cargo_cost"] = int(balance.cargo_kg)
			_entries[str(entry.get("id", ""))] = entry
	for group in (parsed as Dictionary).get("groups", []):
		if group is Dictionary and not str(group.get("id", "")).is_empty():
			_groups.append(group)
	return _entries

## Inventory sections in display order: [{id, label, icon}].
static func groups() -> Array:
	entries()
	return _groups

## Entry ids in one inventory section, in catalogue order.
static func ids_in_group(group_id: String) -> Array:
	var out: Array = []
	for id in entries():
		if str(entries()[id].get("group", "")) == group_id:
			out.append(id)
	return out

static func get_entry(id: String) -> Dictionary:
	return entries().get(id, {})

const RIGS_PATH := "res://data/equipment_rigs.json"
static var _rigs: Dictionary = {}

## How an item's delivered parts move and toggle (data/equipment_rigs.json).
static func rig(id: String) -> Dictionary:
	if _rigs.is_empty() and FileAccess.file_exists(RIGS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RIGS_PATH))
		if parsed is Dictionary: _rigs = parsed
	return _rigs.get(id, {})

## The switch an item's effects depend on: {key, default, scope} where scope
## "power" gates only its power draw (lamps) and "all" gates every effect
## (machines that stop working when switched off). Empty if always on.
static func effect_gate(id: String) -> Dictionary:
	for action in rig(id).get("actions", []):
		var powered = action.get("powered", false)
		if powered is bool and not powered: continue
		return {"key": str(action.get("state", "")), "default": bool(action.get("default", false)), "scope": "all" if str(powered) == "all" else "power"}
	return {}

## State key of an item's habitat main isolator ("" if it has none). An
## isolator switched off cuts all generation to the habitat grid.
static func grid_isolator_key(id: String) -> String:
	for action in rig(id).get("actions", []):
		if bool(action.get("grid_isolator", false)): return str(action.get("state", ""))
	return ""

## A levelled appliance (heater): {key, power: [draw per level], heat:
## [degrees C per level]} from its rig's levels action and catalogue effects.
static func levels(id: String) -> Dictionary:
	for action in rig(id).get("actions", []):
		if str(action.get("type", "")) == "levels":
			var fx := effects(id)
			return {"key": str(action.get("state", "")), "power": fx.get("power_draw_levels", []), "heat": fx.get("heat_levels_c", [])}
	return {}

static func exists(id: String) -> bool:
	return not get_entry(id).is_empty()

static func effects(id: String) -> Dictionary:
	return get_entry(id).get("effects", {})

## One short line such as "+3 food · +1 happiness · −2 power · −1 water".
static func effects_text(id: String) -> String:
	var parts: Array = []
	var fx := effects(id)
	for key in ["berths", "food", "life", "research", "storage", "happiness"]:
		if int(fx.get(key, 0)) != 0:
			parts.append("+%d %s" % [int(fx[key]), "berth" if key == "berths" and int(fx[key]) == 1 else ("life support" if key == "life" else key)])
	if int(fx.get("power_draw", 0)) > 0: parts.append("−%d power" % int(fx.power_draw))
	var draw_levels: Array = fx.get("power_draw_levels", [])
	if draw_levels.size() > 1: parts.append("−%s power on %s" % [" / ".join(draw_levels.slice(1).map(func(v): return str(int(v)))), "low / high" if draw_levels.size() == 3 else "each setting"])
	var heat_levels: Array = fx.get("heat_levels_c", [])
	if heat_levels.size() > 1: parts.append("+%s °C in its room when there's no climate control" % " / ".join(heat_levels.slice(1).map(func(v): return str(int(v)))))
	if int(fx.get("water_draw", 0)) > 0: parts.append("−%d water" % int(fx.water_draw))
	return " · ".join(parts)
