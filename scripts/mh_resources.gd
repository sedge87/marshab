extends RefCounted

## Balance numbers for the habitat simulation, read from data/resources.json.
## That file is generated from docs/MarsHabitat_Balance.xlsx by
## tools/import_balance.py: tune numbers in the spreadsheet, not here.
const PATH := "res://data/resources.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_data = parsed if parsed is Dictionary else {"settings": {}, "rooms": {}, "equipment": {}, "sites": {}}
	return _data

## A habitat-wide number from the Settings sheet.
static func setting(key: String, fallback := 0.0) -> float:
	return float((data().get("settings", {}) as Dictionary).get(key, fallback))

static func room(kind: String) -> Dictionary:
	return (data().get("rooms", {}) as Dictionary).get(kind, {})

static func item(id: String) -> Dictionary:
	return (data().get("equipment", {}) as Dictionary).get(id, {})

static func site(id: String) -> Dictionary:
	return (data().get("sites", {}) as Dictionary).get(id, {})

## One item's number, e.g. item_value("grow_tray", "food_kg").
static func item_value(id: String, key: String, fallback := 0.0) -> float:
	return float(item(id).get(key, fallback))
