extends RefCounted

## The builder's rules for step 3c (docs/systems-and-items.md §14, "Setting
## it down"), split out of scripts/build_controller.gd so the first lesson
## lives in one place. Since 14 Nov (A3) the carried module is the walker's
## core (zone kind "general"): airlock, life support and the power hub on its
## rack, and a poor bunk. "Module" below means the core.
## - B does nothing before the General Module is home ("Nothing to build with
##   yet"). Creative stays open.
## - With the walker parked, the Site plan offers only the General Module
##   (its fixed footprint, carried whole) and its Airlock. Rooms go only where
##   you've explored.
## - Once both are placed and the plan is closed, the walker carries the
##   module there and lowers it (scripts/walker.gd).
## - Inside, the Interior view offers only the fit-out kit until it's placed.
## No walker in the world (Creative, older saves, tests): no rules.
## Several bases (A4): each walker seeds its own base (its id is the base's).
## These rules are about the base the Site plan is on (builder.active_base):
## its walker, its core.

const CELL := 3.0
## The module as the walker carries it: 2 × 3 cells (6 × 9 m).
const MODULE_CELLS := Vector2i(2, 3)
## Seen this much on the Map (scripts/known_things.gd seen_at) counts as explored.
const EXPLORED := .5
## The fit-out kit that rides with the module: unfolded where you put it.
const KIT := {"crew_bunk": 1, "general_module_rack": 1, "common_table": 1, "crew_chair": 1, "portable_interior_work_light": 1}

## The walker of the base the plan is on, or null.
static func walker(builder: Node) -> Node:
	if builder == null or not builder.is_inside_tree(): return null
	var base := str(builder.get("active_base"))
	for node in builder.get_tree().get_nodes_in_group("walker"):
		if str(node.get("base_id")) == base: return node
	return null

## A version 3 game (the opening slice, docs/opening-slice.md).
static func slice(builder: Node) -> bool:
	var world: Node = builder.get("world") if builder != null else null
	return world != null and int(world.get("opening_version")) >= 3

## The kit's pieces, by game: version 3 adds the Site plan terminal.
static func kit(builder: Node) -> Dictionary:
	var out := KIT.duplicate()
	if slice(builder): out[TERMINAL] = 1
	return out
const TERMINAL := "site_plan_terminal"

## Any walker in the world: the core comes only on one.
static func active(builder: Node) -> bool:
	return MHGame.game_mode != "creative" and builder != null and builder.is_inside_tree() and builder.get_tree().get_first_node_in_group("walker") != null

## "" (no rules, or the module is down), "waiting" (still out there),
## "set_down" (parked: place the module and its airlock), "delivering"
## (carrying it to the spot and lowering it).
static func stage(builder: Node) -> String:
	if not active(builder) or walker(builder) == null: return ""
	match str(walker(builder).get("state")):
		"stalled", "walking", "ready", "travelling": return "waiting"
		"parked": return "set_down"
		"coming": return "delivering" if bool(walker(builder).get("marked")) else "set_down"   # v2: mark the spot while it crawls home
		"carrying", "lowering": return "delivering"
	return ""

## Why B can't open the Site plan now ("" when it can).
static func b_reason(builder: Node, at_terminal := false) -> String:
	# The opening slice's rule: rooms are planned at a Site plan terminal. B
	# inside a room furnishes it (22 Nov playtest: "bring it back... i never
	# meant for us to remove it": snap, turn and remove all live there).
	# 23 Nov: B furnishes inside a room and places outdoor props outside;
	# it works once the fit-out kit's box is open. Rooms stay at the terminal.
	match stage(builder):
		"waiting": return "Nothing to build with yet" if str(walker(builder).get("state")) != "travelling" else "The walker is still on its way"
		"delivering":
			if str(walker(builder).get("state")) == "coming": return "The module's spot is marked"
			return "The walker is setting the module down"
	if not at_terminal and slice(builder) and not kit_open() and not kit_left(builder).is_empty(): return "Open the fit-out kit first"
	return ""

static func b_detail(builder: Node) -> String:
	if slice(builder) and stage(builder) in ["", "set_down"]:
		if not kit_open() and not kit_left(builder).is_empty(): return "The kit box is on the General Module's floor. Open it (E), then B furnishes."
		return "B furnishes the room you're in, or places outdoor gear outside. New rooms are planned at a Site plan terminal."
	match stage(builder):
		"waiting": return "The base's first room is still out there on its walker."
		"delivering":
			if str(walker(builder).get("state")) == "coming": return "Walker 1 brings it in overnight and sets it down on your mark."
			return "Watch it come down, then walk over and cycle in."
	return ""

## Whether a part is on the bar right now.
static func offered(builder: Node, kind: String) -> bool:
	if stage(builder) == "set_down": return kind in ["general", "airlock"]
	# The core comes only on a walker (one walker, one base; A3, 14 Nov):
	# never drawn by hand once there's a walker in the world. Creative still can.
	if kind == "general" and active(builder): return false
	# The story game: the crew's pad goes where you've proven the ground
	# (the new job, docs/opening-slice.md Scene 12), not straight off the
	# bar (23 Nov playtest). Until that's built, it isn't offered.
	if kind == "landing_pad" and slice(builder): return false
	return true

## A base's carried core, once placed in the plan (or {}): the plan's base
## unless one's named.
static func module_zone(builder: Node, base := "") -> Dictionary:
	if base.is_empty(): base = str(builder.get("active_base"))
	for zone in builder.get("zones"):
		if bool(zone.get("carried", false)) and str(zone.get("base", "w1")) == base: return zone
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
	if kind == "general" and stage(builder) == "set_down": return 0
	# 23 Nov playtest: the first Quarters is paid like any room, as big as
	# the regolith allows (the Print Shop's sack and the starter bin).
	if first_quarters(builder, kind) and not slice(builder): return 0
	return -1

## A6: the guided chapters' first Quarters liner came with Walker 1 (nothing
## printed yet to pay for a shell), at its base, while none stands.
static func first_quarters(builder: Node, kind: String) -> bool:
	if kind != "living" or not active(builder) or module_zone(builder).is_empty(): return false
	var world: Node = builder.get("world")
	var days: Node = world.get("opening_days") if world != null else null
	if days == null or not days.has_method("guided") or not bool(days.guided()): return false
	for zone in builder.get("zones"):
		if str(zone.get("kind", "")) == "living": return false
	return true

## Walker 1's free Quarters liner: up to this many cells (a 6 × 6 m room).
const FREE_QUARTERS_CELLS := 4

## Extra reasons a zone can't go here ("" when it can).
static func zone_reason(builder: Node, kind: String, cells: Array) -> String:
	if not active(builder): return ""
	if first_quarters(builder, kind) and not slice(builder) and cells.size() > FREE_QUARTERS_CELLS: return "Walker 1's Quarters liner covers up to %d cells" % FREE_QUARTERS_CELLS
	if stage(builder) == "set_down":
		if not offered(builder, kind): return "Only the core and its airlock for now"
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
	elif first_quarters(builder, str(zone.kind)) and not slice(builder):
		zone["kit"] = true   # A6: the first Quarters liner came in Walker 1's kit (not the story game, 23 Nov)
		zone["cost"] = 0

## The plan closed: with the module and an airlock placed, the walker goes.
static func plan_closed(builder: Node) -> void:
	# The crew's pad, once the plan closes on it, is down for good (A4).
	for zone in builder.get("zones"):
		if str(zone.get("kind", "")) == "landing_pad" and not bool(zone.get("down", false)):
			zone["down"] = true
			builder.set("_history", (builder.get("_history") as Array).filter(func(step): return not (str(step.get("type", "")) == "zone" and is_same(step.zone, zone))))
			MHNotices.post("valid", "The landing pad is down", "%s is the main base now: the crew will land here." % MHBases.label_for(str(zone.get("base", "w1"))), "log")
	if stage(builder) != "set_down": return
	var module := module_zone(builder)
	if module.is_empty(): return
	var has_airlock := false
	for zone in builder.get("zones"):
		if str(zone.kind) == "airlock" and str(zone.get("base", "w1")) == str(builder.get("active_base")): has_airlock = true
	if not has_airlock: return
	module = module_zone(builder)
	# Set down for good: undo no longer takes the module or its airlock back.
	builder.set("_history", (builder.get("_history") as Array).filter(func(step): return not (str(step.get("type", "")) == "zone" and (bool(step.zone.get("carried", false)) or str(step.zone.get("kind", "")) == "airlock"))))
	if str(walker(builder).get("state")) == "coming": walker(builder).mark(module)
	else: walker(builder).deliver(module)

## The fit-out kit still to place: the only things on the Interior bar until
## it's all out of its crate.
static func kit_left(builder: Node) -> Array:
	if not active(builder) or str(walker(builder).get("state")) != "done": return []
	var out: Array = []
	for id in kit(builder):
		if MHChapterOne.available(str(id), builder) > 0: out.append(str(id))
	return out

## Lowered: the kit's pieces join the stock (placed for free).
static func give_kit(builder: Node = null) -> void:
	var pieces: Dictionary = kit(builder) if builder != null else KIT
	for id in pieces:
		MHChapterOne.stock[id] = int(MHChapterOne.stock.get(id, 0)) + int(pieces[id])
	# 22 Nov playtest: something to work with. Walker 1 carries a starter bin
	# of feedstock (a sol's intake), so the first prints don't wait.
	if builder != null and slice(builder) and not MHChapterOne.unpacked.has("starter_feedstock"):
		MHChapterOne.unpacked["starter_feedstock"] = true
		MHChapterOne.feedstock_kg += STARTER_FEEDSTOCK_KG
const STARTER_FEEDSTOCK_KG := 150.0

## 23 Nov playtest: in the story game the Print Shop comes packed in the
## fit-out kit box, with its regolith intake and a sack of regolith (it was
## pallet 6's crate; pallet 6 now carries the survey sled). Once only.
const PRINT_SHOP_FEEDSTOCK_KG := 250.0
static func unpack_print_shop() -> bool:
	if MHChapterOne.unpacked.has("print_shop"): return false
	MHChapterOne.unpacked["print_shop"] = true
	for id in ["fabricator", "regolith_intake"]:
		MHChapterOne.stock[id] = int(MHChapterOne.stock.get(id, 0)) + 1
	MHChapterOne.feedstock_kg += PRINT_SHOP_FEEDSTOCK_KG
	unpack_chunk_three()
	return true

## Chunk 3 (24 Nov, docs/assets-chunk3-review.md): the EVA station, the base
## radio and the salvage tub come in the same kit box. Extra stock, not KIT
## pieces, so a save past the kit isn't told it has pieces left to place.
const CHUNK_THREE_KIT := ["eva_station", "base_radio", "salvage_tub"]
static func unpack_chunk_three() -> bool:
	if MHChapterOne.unpacked.has("eva_station"): return false
	MHChapterOne.unpacked["eva_station"] = true
	for id in CHUNK_THREE_KIT:
		MHChapterOne.stock[id] = int(MHChapterOne.stock.get(id, 0)) + 1
	return true

## A save whose kit box was opened before chunk 3: give them once.
static func catch_up_chunk_three(builder: Node) -> void:
	if MHChapterOne.unpacked.has("eva_station") or not MHChapterOne.unpacked.has("print_shop") or not slice(builder): return
	unpack_chunk_three()

## A save from before the move: its kit box was opened without the Print
## Shop in it. Give it once, unless it already came off pallet 6.
static func catch_up_print_shop(builder: Node) -> void:
	if MHChapterOne.unpacked.has("print_shop") or not slice(builder) or not kit_open(): return
	if int(MHChapterOne.stock.get("fabricator", 0)) > 0 or MHChapterOne.placed_count("fabricator", builder) > 0:
		MHChapterOne.unpacked["print_shop"] = true
		return
	unpack_print_shop()

## Version 3: the whole kit goes on the build list once its box is open
## (scripts/kit_crate.gd), and nothing before.
static func unpacked_kit(builder: Node) -> Array:
	var left := kit_left(builder)
	if not slice(builder) or kit_open(): return left
	return []

## The fit-out kit box is open (23 Nov: one box unlocks B). A save from the
## crate-a-piece days counts as open once any crate was.
static func kit_open() -> bool:
	if MHChapterOne.unpacked.has("kit_box"): return true
	for key in MHChapterOne.unpacked:
		if str(key).begins_with("kit:"): return true
	return false
