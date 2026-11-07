extends RefCounted

## The builder's rules for step 3c (docs/systems-and-items.md §14, "Setting
## it down"), split out of scripts/build_controller.gd so the first lesson
## lives in one place:
## - B does nothing before the General Module is home ("Nothing to build with
##   yet"). Creative stays open.
## - With the walker parked, the Site plan offers only the General Module
##   (its fixed footprint, carried whole) and its Airlock. Rooms go only where
##   you've explored.
## - Once both are placed and the plan is closed, the walker carries the
##   module there and lowers it (scripts/walker.gd).
## - Inside, the Interior view offers only the fit-out kit until it's placed.
## No walker in the world (Creative, older saves, tests): no rules.

const CELL := 3.0
## The module as the walker carries it: 2 × 3 cells (6 × 9 m).
const MODULE_CELLS := Vector2i(2, 3)
## Seen this much on the Map (scripts/known_things.gd seen_at) counts as explored.
const EXPLORED := .5
## The fit-out kit that rides with the module: unfolded where you put it.
const KIT := {"crew_bunk": 1, "general_module_rack": 1, "common_table": 1, "crew_chair": 1, "portable_interior_work_light": 1}

static func walker(builder: Node) -> Node:
	if builder == null or not builder.is_inside_tree(): return null
	return builder.get_tree().get_first_node_in_group("walker")

static func active(builder: Node) -> bool:
	return MHGame.game_mode != "creative" and walker(builder) != null

## "" (no rules, or the module is down), "waiting" (still out there),
## "set_down" (parked: place the module and its airlock), "delivering"
## (carrying it to the spot and lowering it).
static func stage(builder: Node) -> String:
	if not active(builder): return ""
	match str(walker(builder).get("state")):
		"stalled", "walking": return "waiting"
		"parked": return "set_down"
		"carrying", "lowering": return "delivering"
	return ""

## Why B can't open the Site plan now ("" when it can).
static func b_reason(builder: Node) -> String:
	match stage(builder):
		"waiting": return "Nothing to build with yet"
		"delivering": return "The walker is setting the module down"
	return ""

static func b_detail(builder: Node) -> String:
	match stage(builder):
		"waiting": return "The base's first room is still out there on its walker."
		"delivering": return "Watch it come down, then walk over and cycle in."
	return ""

## Whether a part is on the bar right now.
static func offered(builder: Node, kind: String) -> bool:
	if stage(builder) == "set_down": return kind in ["general", "airlock"]
	return true

## The carried module, once placed in the plan (or {}).
static func module_zone(builder: Node) -> Dictionary:
	for zone in builder.get("zones"):
		if bool(zone.get("carried", false)): return zone
	return {}

## The General Module's fixed footprint at `at`, or [] when it isn't fixed.
## R (the airlock arrow) turns it: long side along the arrow.
static func fixed_cells(builder: Node, kind: String, at: Vector2i) -> Array:
	if kind != "general" or stage(builder) != "set_down" or at.x == 999: return []
	var dir: Vector2i = builder.get("airlock_direction")
	var size := MODULE_CELLS if dir.y != 0 else Vector2i(MODULE_CELLS.y, MODULE_CELLS.x)
	var out: Array = []
	var start := at - Vector2i(size.x / 2, size.y / 2)
	for x in size.x:
		for z in size.y: out.append(start + Vector2i(x, z))
	return out

## The cargo a placement costs, or -1 to use the usual cost. The carried
## module came down whole: nothing to pay.
static func cost(builder: Node, kind: String) -> int:
	return 0 if kind == "general" and stage(builder) == "set_down" else -1

## Extra reasons a zone can't go here ("" when it can).
static func zone_reason(builder: Node, kind: String, cells: Array) -> String:
	if not active(builder): return ""
	if stage(builder) == "set_down":
		if not offered(builder, kind): return "Only the General Module and its airlock for now"
		if kind == "general" and not module_zone(builder).is_empty(): return "There's only the one module: undo it to move it"
		if kind == "airlock" and module_zone(builder).is_empty(): return "Set the module down first"
	if kind != "trench":
		for cell in cells:
			if not explored(builder, Vector2(cell.x * CELL, cell.y * CELL)): return "Only where you've explored: walk there first"
	return ""

## Ground you've seen with your own eyes (the Map's clear part).
static func explored(builder: Node, site: Vector2) -> bool:
	var world: Node = builder.get("world")
	var known: Node = world.get("known") if world != null else null
	if known == null: return true
	return float(known.seen_at(site + known.origin)) >= EXPLORED

## A zone just placed: the module is marked as carried (free, one only).
static func placed(builder: Node, zone: Dictionary) -> void:
	if str(zone.kind) == "general" and stage(builder) == "set_down":
		zone["carried"] = true
		zone["cost"] = 0

## The plan closed: with the module and an airlock placed, the walker goes.
static func plan_closed(builder: Node) -> void:
	if stage(builder) != "set_down": return
	var module := module_zone(builder)
	if module.is_empty(): return
	var has_airlock := false
	for zone in builder.get("zones"):
		if str(zone.kind) == "airlock": has_airlock = true
	if not has_airlock: return
	# Set down for good: undo no longer takes the module or its airlock back.
	builder.set("_history", (builder.get("_history") as Array).filter(func(step): return not (str(step.get("type", "")) == "zone" and (bool(step.zone.get("carried", false)) or str(step.zone.get("kind", "")) == "airlock"))))
	walker(builder).deliver(module)

## The fit-out kit still to place: the only things on the Interior bar until
## it's all out of its crate.
static func kit_left(builder: Node) -> Array:
	if not active(builder) or str(walker(builder).get("state")) != "done": return []
	var out: Array = []
	for id in KIT:
		if MHChapterOne.available(str(id), builder) > 0: out.append(str(id))
	return out

## Lowered: the kit's pieces join the stock (placed for free).
static func give_kit() -> void:
	for id in KIT:
		MHChapterOne.stock[id] = int(MHChapterOne.stock.get(id, 0)) + int(KIT[id])
