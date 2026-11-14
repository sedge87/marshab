class_name MHGreenhouse
extends RefCounted

## The Greenhouse's chain (A5, docs/rooms-and-equipment.md "Workflows"):
## regolith washer, then planters, then harvest to the Galley.
##   - Planters grow in washed soil: a new planter waits for a fill (FILL_KG)
##     of it. Grow trays are hydroponic and need none.
##   - The first batch of soil is washed by hand at the washer (E). After
##     that a washer in a Greenhouse keeps a little washed soil in the store
##     by itself, from the intake's regolith and some water, and new planters
##     fill from it.
##   - The first harvest of each crop is by hand (E on the planter); after
##     that a harvest cart in the room picks it.
##   - Chapter one's food step (wash a sample, plant a test seed) can be done
##     at the washer as well as the Workshop Bench.
## Chapter rules only (MHChapterOne.on()); off them everything grows as before.

const FILL_KG := 40.0
const FIRST_BATCH_KG := 40.0
const KEEP_KG := 80.0            # washed soil the washer keeps ready
const WASH_PER_SOL := 60.0       # kg of regolith a washer washes a sol
const WATER_PER_KG := .25        # litres lost per kg washed (most is cleaned and reused)
const WASH_ROOMS := ["hydroponics"]

static var soil_kg := 0.0
static var washed_by_hand := false
static var picked_by_hand: Dictionary = {}   # crop -> true

static func on() -> bool:
	return MHChapterOne.on()

static func reset() -> void:
	soil_kg = 0.0; washed_by_hand = false; picked_by_hand = {}

static func export_state() -> Dictionary:
	return {"soil_kg": soil_kg, "washed_by_hand": washed_by_hand, "picked_by_hand": picked_by_hand.duplicate()}

## `state` is the "greenhouse" section; empty for a save from before A5,
## which keeps growing as it did.
static func load_state(state: Dictionary) -> void:
	reset()
	if state.is_empty():
		washed_by_hand = true
		for crop in ["greens", "potatoes"]: picked_by_hand[crop] = true
		return
	soil_kg = float(state.get("soil_kg", 0.0))
	washed_by_hand = bool(state.get("washed_by_hand", false))
	picked_by_hand = (state.get("picked_by_hand", {}) as Dictionary).duplicate()

## Whether a planter needs washed soil before it grows (chapter rules).
static func needs_soil(id: String) -> bool:
	return on() and id == "greenhouse_planter"

## A cart picks this crop by itself (after the first harvest by hand).
static func cart_picks(crop: String) -> bool:
	return not on() or picked_by_hand.has(crop)

## Takes a planter's fill from the store; true when there was enough.
static func fill_planter() -> bool:
	if soil_kg < FILL_KG - .001: return false
	soil_kg -= FILL_KG
	return true

## What E does at a regolith washer, or "".
static func washer_action(_builder: Object) -> String:
	if not on(): return ""
	var step := MHChapterOne.bench_action()
	if not step.is_empty(): return step
	if not washed_by_hand: return "Wash a first batch of soil"
	return ""

static func washer_use(builder: Object) -> Array:
	if builder == null: return []
	var sim: Object = builder.call("simulation")
	if not MHChapterOne.bench_action().is_empty(): return MHChapterOne.bench_use(sim, float(sim.get("hours_run")))
	if washed_by_hand: return []
	var water := FIRST_BATCH_KG * WATER_PER_KG
	if MHChapterOne.feedstock_kg < FIRST_BATCH_KG: return [{"id": "wash", "title": "Not enough regolith", "text": "The washer needs %s from the intake." % MHStyle.kg(roundi(FIRST_BATCH_KG)), "tone": "warn"}]
	if float(sim.get("water_l")) < water: return [{"id": "wash", "title": "Not enough water", "text": "Washing needs about %d L." % ceili(water), "tone": "warn"}]
	MHChapterOne.feedstock_kg -= FIRST_BATCH_KG
	sim.set("water_l", float(sim.get("water_l")) - water)
	soil_kg += FIRST_BATCH_KG
	washed_by_hand = true
	return [{"id": "wash", "title": "Washed soil: %s" % MHStyle.kg(roundi(FIRST_BATCH_KG)), "text": "Rinsed clean of perchlorate, enough for a planter. From now on the washer keeps some ready by itself.", "tone": "valid"}]

## Each habitat step (habitat_food.gd): a washer in a Greenhouse keeps soil ready.
static func step(dt: float, sim: Object, inv: Dictionary, _powered: Dictionary) -> void:
	if not on() or not washed_by_hand or soil_kg >= KEEP_KG: return
	var washers := 0
	# all_items: the washer has no power balance of its own, so it isn't in items.
	for item in inv.get("all_items", []):
		if str(item.id) != "regolith_washer": continue
		var rooms: Array = inv.get("rooms", [])
		var room := int(item.get("room", -1))
		if room >= 0 and room < rooms.size() and not str(rooms[room].kind) in WASH_ROOMS: continue
		washers += 1
	if washers == 0: return
	var kg := minf(minf(WASH_PER_SOL * washers * dt / 24.0, KEEP_KG - soil_kg), MHChapterOne.feedstock_kg)
	kg = minf(kg, float(sim.get("water_l")) / WATER_PER_KG)
	if kg <= 0.0: return
	MHChapterOne.feedstock_kg -= kg
	sim.set("water_l", float(sim.get("water_l")) - kg * WATER_PER_KG)
	soil_kg += kg
