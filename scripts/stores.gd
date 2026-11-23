class_name MHStores

## How much the base can hold (23 Nov, the user: "the storage room type
## should allow for this... its size increases the max capacity of each
## resource"). The core holds a little of everything; each Storage cell adds
## more. When a store is full, the machines that fill it by themselves (the
## regolith intake, the recyclers, the smelter) pause and the slate says why.
## What you carry in by hand always goes in, even over the cap: a find is
## never lost. Stock in Storage rooms shows as piles (scripts/storage_piles.gd).

## kind -> kg the core holds with no Storage, and what each Storage cell adds.
const CORE := {"regolith": 500.0, "iron": 100.0, "salvage": 100.0, "ore": 200.0}
const PER_CELL := {"regolith": 500.0, "iron": 100.0, "salvage": 100.0, "ore": 200.0}
const LABEL := {"regolith": "Regolith", "iron": "Iron", "salvage": "Salvage", "ore": "Iron-rich rock"}

## Storage cells across every base: kept up to date by the build controller
## each time the plan changes (scripts/build_controller.gd _rebuild).
static var storage_cells := 0
static var _full_said: Dictionary = {}

static func cap(kind: String) -> float:
	return float(CORE.get(kind, 0.0)) + float(PER_CELL.get(kind, 0.0)) * storage_cells

static func amount(kind: String) -> float:
	match kind:
		"regolith": return MHChapterOne.feedstock_kg
		"iron": return MHMaterials.metal_kg
		"salvage": return MHMaterials.salvage_kg
		"ore": return MHMaterials.ore_kg()
	return 0.0

static func room(kind: String) -> float:
	return maxf(0.0, cap(kind) - amount(kind))

static func is_full(kind: String) -> bool:
	return amount(kind) >= cap(kind) - .01

## A machine wants to add `kg`: returns what fits, and says so once when it
## doesn't (it says it again after the store has had room for a while).
static func fit(kind: String, kg: float) -> float:
	if kg <= 0.0: return kg
	var fits := minf(kg, room(kind))
	if fits < kg: _say_full(kind)
	elif amount(kind) + fits < cap(kind) * .9: _full_said.erase(kind)
	return fits

static func _say_full(kind: String) -> void:
	if _full_said.has(kind): return
	_full_said[kind] = true
	var what: String = LABEL.get(kind, kind)
	var how := "Build Storage to hold more: each cell takes another %s." % MHStyle.kg(roundi(float(PER_CELL.get(kind, 0.0))))
	MHNotices.post("warn", "%s store full" % what, "%s of %s. %s The %s pauses until there's room." % [MHStyle.kg(floori(amount(kind))), MHStyle.kg(roundi(cap(kind))), how, _filler(kind)], "log")

static func _filler(kind: String) -> String:
	match kind:
		"regolith": return "intake"
		"iron": return "smelter"
	return "machine"

## "Regolith 320 / 500 kg" for the slate.
static func line(kind: String) -> String:
	return "%s %s / %s" % [str(LABEL.get(kind, kind)), str(floori(amount(kind))), MHStyle.kg(roundi(cap(kind)))]

static func count_cells(zones: Array) -> int:
	var n := 0
	for zone in zones:
		if str(zone.get("kind", "")) == "storage" and not zone.has("angled_mount"): n += (zone.get("cells", []) as Array).size()
	return n
