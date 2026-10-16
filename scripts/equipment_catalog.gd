class_name EquipmentCatalog
extends RefCounted

## Shared equipment definitions for the Build-mode interior inventory.
## Keeping the data separate means art can be replaced without changing game rules.
const CATALOG_PATH := "res://data/equipment_catalog.json"
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
	if int(fx.get("water_draw", 0)) > 0: parts.append("−%d water" % int(fx.water_draw))
	return " · ".join(parts)
