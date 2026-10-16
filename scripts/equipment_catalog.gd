class_name EquipmentCatalog
extends RefCounted

## Shared equipment definitions for the future first-person furnishing system.
## Keeping the data separate means art can be replaced without changing game rules.
const CATALOG_PATH := "res://data/equipment_catalog.json"
static var _entries: Dictionary = {}

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
	return _entries

static func get_entry(id: String) -> Dictionary:
	return entries().get(id, {})

static func exists(id: String) -> bool:
	return not get_entry(id).is_empty()

static func effects(id: String) -> Dictionary:
	return get_entry(id).get("effects", {})
