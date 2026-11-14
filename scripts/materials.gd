class_name MHMaterials
extends RefCounted

## The four materials (docs/pillars.md, master-design §4; built in A5, 15 Nov):
##   - regolith: MHChapterOne.feedstock_kg, from the intake: bulk print stock;
##   - water ice: the habitat's water, from the extractor and the melter;
##   - metal: smelted at a Workshop's smelter from iron-rich rock you bring
##     home (hematite, meteorite), or slowly from regolith;
##   - salvage: Earth-made parts stripped from storm debris and the pallets
##     (and wrecks, C1).
## One shared store for every base (A4). Plans list the metal and salvage
## they need beside their feedstock (data/plans.json "metal_kg",
## "salvage_kg"). Chapter rules only (MHChapterOne.on()).

## What a new game starts with: the cargo's own stock (the old crates game's
## Print stock crate carries the same again).
const START_METAL := 60.0
const START_SALVAGE := 60.0
## Saves from before A5 get this much of each, so nothing they had is blocked.
const OLD_SAVE_KG := 400.0
## Iron-rich rock: what a suit carries, one break-off, and break-offs per rock.
const CARRY_KG := 30.0
const PULL_KG := 10.0
const PULLS_PER_ROCK := 3
const PULL_SECONDS := 1.8
## Metal per kg of rock smelted.
const ORE_YIELD := {"hematite": .5, "meteorite": .8}
const REGOLITH_YIELD := .08
## A smelter's pace (kg a sol it melts) and the regolith it leaves the printers.
const SMELT_ORE_PER_SOL := 40.0
const SMELT_REGOLITH_PER_SOL := 80.0
const REGOLITH_RESERVE := 300.0
## The first batch, smelted by hand at the smelter (E).
const FIRST_BATCH_ORE := 10.0
const FIRST_BATCH_REGOLITH := 60.0
const SALVAGE_PER_DEBRIS := 6.0
const SALVAGE_PER_PALLET := 25.0
const SMELTERS := ["smelter"]
const SMELT_ROOMS := ["engineering"]

static var metal_kg := 0.0
static var salvage_kg := 0.0
static var ore: Dictionary = {}      # rock type -> kg at base, waiting for a smelter
static var carried: Dictionary = {}  # rock type -> kg in the suit
static var pulled: Dictionary = {}   # rock key -> break-offs taken
static var smelted_by_hand := false

static func on() -> bool:
	return MHChapterOne.on()

static func reset() -> void:
	metal_kg = START_METAL; salvage_kg = START_SALVAGE; ore = {}; carried = {}; pulled = {}; smelted_by_hand = false

static func export_state() -> Dictionary:
	return {"metal_kg": metal_kg, "salvage_kg": salvage_kg, "ore": ore.duplicate(), "carried": carried.duplicate(), "pulled": pulled.duplicate(), "smelted_by_hand": smelted_by_hand}

## `state` is the "materials" section; empty for a save from before A5.
static func load_state(state: Dictionary) -> void:
	reset()
	if state.is_empty():
		metal_kg = OLD_SAVE_KG; salvage_kg = OLD_SAVE_KG
		return
	metal_kg = float(state.get("metal_kg", 0.0))
	salvage_kg = float(state.get("salvage_kg", 0.0))
	ore = (state.get("ore", {}) as Dictionary).duplicate()
	carried = (state.get("carried", {}) as Dictionary).duplicate()
	pulled = (state.get("pulled", {}) as Dictionary).duplicate()
	smelted_by_hand = bool(state.get("smelted_by_hand", false))

# ---------- costs ----------

## {metal_kg, salvage_kg} a plan needs (beside its feedstock).
static func plan_mix(id: String) -> Dictionary:
	var p: Dictionary = MHChapterOne.plan(id)
	return {"metal_kg": float(p.get("metal_kg", 0.0)), "salvage_kg": float(p.get("salvage_kg", 0.0))}

## What's short for a cost with feedstock_kg, metal_kg and salvage_kg, or "".
static func short_of(cost: Dictionary) -> String:
	var bits: Array = []
	if MHChapterOne.feedstock_kg < float(cost.get("feedstock_kg", 0.0)) - .001: bits.append("%s feedstock (you have %s)" % [MHStyle.kg(roundi(float(cost.feedstock_kg))), MHStyle.kg(floori(MHChapterOne.feedstock_kg))])
	if metal_kg < float(cost.get("metal_kg", 0.0)) - .001: bits.append("%s metal (you have %s)" % [MHStyle.kg(roundi(float(cost.metal_kg))), MHStyle.kg(floori(metal_kg))])
	if salvage_kg < float(cost.get("salvage_kg", 0.0)) - .001: bits.append("%s salvage (you have %s)" % [MHStyle.kg(roundi(float(cost.salvage_kg))), MHStyle.kg(floori(salvage_kg))])
	return "" if bits.is_empty() else "Needs " + " and ".join(bits)

## Takes (times = 1) or gives back (times = -1) a cost's metal and salvage.
static func pay(cost: Dictionary, times := 1.0) -> void:
	metal_kg = maxf(0.0, metal_kg - float(cost.get("metal_kg", 0.0)) * times)
	salvage_kg = maxf(0.0, salvage_kg - float(cost.get("salvage_kg", 0.0)) * times)

## "40 kg · 8 kg metal · 5 kg salvage" for a card.
static func cost_line(cost: Dictionary) -> String:
	var bits: Array = [MHStyle.kg(roundi(float(cost.get("feedstock_kg", 0.0))))]
	if float(cost.get("metal_kg", 0.0)) > 0.0: bits.append("%s metal" % MHStyle.kg(roundi(float(cost.metal_kg))))
	if float(cost.get("salvage_kg", 0.0)) > 0.0: bits.append("%s salvage" % MHStyle.kg(roundi(float(cost.salvage_kg))))
	return " · ".join(bits)

## "Feedstock 2.4 t · metal 60 kg · salvage 60 kg · iron-rich rock 20 kg"
static func store_line() -> String:
	var line := "Feedstock %s · metal %s · salvage %s" % [MHStyle.kg(floori(MHChapterOne.feedstock_kg)), MHStyle.kg(floori(metal_kg)), MHStyle.kg(floori(salvage_kg))]
	if ore_kg() > 0.0: line += " · iron-rich rock %s" % MHStyle.kg(floori(ore_kg()))
	return line

# ---------- iron-rich rock ----------

static func ore_kg() -> float:
	var total := 0.0
	for key in ore: total += float(ore[key])
	return total

static func carried_kg() -> float:
	var total := 0.0
	for key in carried: total += float(carried[key])
	return total

static func iron_rich(rock: String) -> bool:
	return ORE_YIELD.has(rock)

## Whether the Lab has named this rock type: a full read of a sample of it.
static func known_rock(rock: String) -> bool:
	for record in MHSamples.archive():
		if str(record.get("rock", "")) == rock and (record.get("partial", []) as Array).is_empty(): return true
	return false

## Why you can't break iron-rich rock off this rock now, or "" if you can.
static func pull_reason(rock: String, key: String) -> String:
	if not on() or not iron_rich(rock) or not known_rock(rock): return "not_ore"
	if int(pulled.get(key, 0)) >= PULLS_PER_ROCK: return "Nothing more worth breaking off this one"
	if carried_kg() + PULL_KG > CARRY_KG + .001: return "The suit can't carry more rock (%s): take it home" % MHStyle.kg(roundi(carried_kg()))
	return ""

static func pull(rock: String, key: String) -> Dictionary:
	var why := pull_reason(rock, key)
	if not why.is_empty(): return {"id": "ore", "title": "Can't take more", "text": why + ".", "tone": "warn"}
	pulled[key] = int(pulled.get(key, 0)) + 1
	carried[rock] = float(carried.get(rock, 0.0)) + PULL_KG
	return {"id": "ore", "title": "Iron-rich rock: %s" % MHSamples.rock_label(rock).to_lower(), "text": "%s in the suit's bag (%s of %s). It goes into the store when you're back inside a base." % [MHStyle.kg(roundi(PULL_KG)), MHStyle.kg(roundi(carried_kg())), MHStyle.kg(roundi(CARRY_KG))], "tone": "info"}

## Inside a base: the suit's rock goes into the shared store.
static func unload() -> Array:
	if carried.is_empty(): return []
	var kg := carried_kg()
	for rock in carried: ore[rock] = float(ore.get(rock, 0.0)) + float(carried[rock])
	carried = {}
	return [{"id": "ore_in", "title": "Iron-rich rock stored", "text": "%s for the smelter. %s" % [MHStyle.kg(roundi(kg)), "A smelter in the Workshop turns it into metal." if not smelted_by_hand else "The smelter will get to it."], "tone": "valid"}]

# ---------- salvage ----------

static func add_salvage(kg: float) -> void:
	if on(): salvage_kg += kg

# ---------- the smelter ----------

## Smelters placed in a Workshop: [placement id].
static func smelters(builder: Object) -> Array:
	var out: Array = []
	if builder == null: return out
	for item in builder.get("placed_interior"):
		if not str(item.get("id", "")) in SMELTERS: continue
		if room_kind(builder, Vector2i(item.get("zone_cell", Vector2i.ZERO))) in SMELT_ROOMS: out.append(str(item.get("placement_id", "")))
	return out

## The kind of room holding a cell ("" outside any).
static func room_kind(builder: Object, cell: Vector2i) -> String:
	for zone in builder.get("zones"):
		if (zone.get("cells", []) as Array).has(cell): return str(zone.get("kind", ""))
	return ""

## What E does at a smelter, or "".
static func smelter_action() -> String:
	if not on() or smelted_by_hand: return ""
	return "Smelt the first batch"

## The first batch, by hand: some rock, or regolith if there's none.
static func smelt_by_hand() -> Dictionary:
	if smelted_by_hand: return {}
	var made := 0.0
	if ore_kg() > 0.0:
		made = _melt_ore(FIRST_BATCH_ORE)
	elif MHChapterOne.feedstock_kg >= FIRST_BATCH_REGOLITH:
		MHChapterOne.feedstock_kg -= FIRST_BATCH_REGOLITH
		made = FIRST_BATCH_REGOLITH * REGOLITH_YIELD
	else:
		return {"id": "smelt", "title": "Nothing to smelt", "text": "Bring home iron-rich rock, or let the intake gather %s of regolith." % MHStyle.kg(roundi(FIRST_BATCH_REGOLITH)), "tone": "warn"}
	metal_kg += made
	smelted_by_hand = true
	return {"id": "smelt", "title": "First metal: %s" % MHStyle.kg(roundi(made)), "text": "Poured and cooling. From now on the smelter works through the store's rock by itself, and regolith when there's plenty.", "tone": "valid"}

## Melts up to `kg` of stored rock, richest first; returns the metal made.
static func _melt_ore(kg: float) -> float:
	var left := kg
	var made := 0.0
	var kinds: Array = ore.keys()
	kinds.sort_custom(func(a, b): return float(ORE_YIELD.get(a, 0.0)) > float(ORE_YIELD.get(b, 0.0)))
	for rock in kinds:
		if left <= 0.0: break
		var take := minf(left, float(ore[rock]))
		ore[rock] = float(ore[rock]) - take
		if float(ore[rock]) <= .001: ore.erase(rock)
		left -= take
		made += take * float(ORE_YIELD.get(rock, .3))
	return made

## Each tick, with power: every smelter works the store (after the first batch).
static func tick(hours: float, builder: Object, powered: bool) -> Array:
	if not on() or not smelted_by_hand or not powered or hours <= 0.0: return []
	var count := smelters(builder).size()
	if count == 0: return []
	var sols := hours / 24.0 * count
	if ore_kg() > 0.0:
		metal_kg += _melt_ore(SMELT_ORE_PER_SOL * sols)
	elif MHChapterOne.feedstock_kg > REGOLITH_RESERVE:
		var take := minf(SMELT_REGOLITH_PER_SOL * sols, MHChapterOne.feedstock_kg - REGOLITH_RESERVE)
		MHChapterOne.feedstock_kg -= take
		metal_kg += take * REGOLITH_YIELD
	return []
