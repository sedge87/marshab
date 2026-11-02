extends RefCounted

## Food (docs/survival-systems.md §5, phase 4): crops that grow over sols,
## harvests, produce that spoils, nutrients, and what the crew eat. Owned by
## the habitat simulation (habitat_sim.gd `food`), which calls step() every
## step. sim.food_kg stays all the food; sim.stores.produce_kg is the fresh
## part of it, kept here as batches by harvest time.
##
## - Each grow tray or planter grows one crop. It ripens, waits for a harvest
##   (E, or a harvest cart in the same room does it), and goes over if left
##   RIPE_SOLS. G on the tray picks the next crop.
## - A seedling station anywhere gives each replanting a head start.
## - Earth's nutrients run down as crops grow; with none left trays grow at
##   half speed. The nutrient mixer makes more from compost (habitat_waste.gd).
## - Produce keeps SHELF_SOLS, or FREEZER_SOLS with a powered galley freezer.
## - Eating mostly rations wears on the crew: fresh_share feeds the
##   "Fresh food" wellbeing need (habitat_life.gd).
const MHResources := preload("res://scripts/mh_resources.gd")

const CROPS := {
	"greens": {"label": "greens", "sols": 8.0, "kg": 2.4},
	"potatoes": {"label": "potatoes", "sols": 20.0, "kg": 9.0},
}
const CROP_ORDER := ["greens", "potatoes"]
const GROWERS := {"grow_tray": 1.0, "greenhouse_planter": 1.5}   # yield per crop, x the tray
const RIPE_SOLS := 3.0
const SHELF_SOLS := 10.0
const FREEZER_SOLS := 60.0
const SEEDLING_START := .25      # a transplanted seedling is a quarter grown
const NUTRIENT_PER_KG := .02     # kg of nutrients per kg of crop grown
const MIXER_KG := .25            # nutrients a powered mixer makes a sol, from twice that in compost
const INEDIBLE := {"greens": .25, "potatoes": .6}   # stems, roots and vines, per kg harvested: to the compost
const START_NUTRIENTS_KG := 20.0
const FRESH_TARGET := .25        # a quarter of what's eaten fresh keeps menu fatigue away
const DIET_SOLS := 10.0          # how far back the crew's diet is remembered

var sim: RefCounted
var trays := {}          # placement id -> {crop, next, growth (0-1), ripe_h}
var batches: Array = []  # fresh produce [{crop, kg, at}] (at = hours_run harvested)
var fresh_share := .3    # rolling share of food eaten fresh
var nutrients_delivered := false
var harvested := {}      # crop -> kg harvested in this game (reports)

func _init(owner: RefCounted) -> void:
	sim = owner

func save() -> Dictionary:
	return {"trays": trays.duplicate(true), "batches": batches.duplicate(true), "fresh_share": fresh_share, "nutrients_delivered": nutrients_delivered, "harvested": harvested.duplicate()}

func load(state: Dictionary) -> void:
	trays = (state.get("trays", {}) as Dictionary).duplicate(true)
	batches = (state.get("batches", []) as Array).duplicate(true)
	fresh_share = float(state.get("fresh_share", .3))
	nutrients_delivered = bool(state.get("nutrients_delivered", false))
	harvested = (state.get("harvested", {}) as Dictionary).duplicate()

# ---------- the trays ----------

func _growers(inv: Dictionary) -> Array:
	return (inv.items as Array).filter(func(i): return GROWERS.has(str(i.id)) and not str(i.get("pid", "")).is_empty())

func tray(pid: String) -> Dictionary:
	if not trays.has(pid): trays[pid] = {"crop": "greens", "next": "greens", "growth": 0.0, "ripe_h": 0.0}
	return trays[pid]

func _has(inv: Dictionary, id: String, powered: Dictionary = {}) -> bool:
	return (inv.items as Array).any(func(i): return str(i.id) == id and bool(i.on) and (powered.is_empty() or bool(powered.get(int(i.tier), true)) or float(i.power) <= 0.0))

## Growth speed before the crew's work: nutrients, then discoveries.
func speed(inv: Dictionary, powered: Dictionary) -> float:
	return (1.0 if float(sim.stores.nutrients_kg) > 0.0 else .5) * MHSamples.bonus("food")

## Food the trays make on average, kg a sol (the readiness and the HUD).
func rate(inv: Dictionary, powered: Dictionary = {}, all_on := false) -> float:
	var total := 0.0
	var pace: float = speed(inv, powered) * (1.0 if all_on else sim.life.food_speed())
	for item in _growers(inv):
		if not all_on and not (bool(item.on) and bool(powered.get(int(item.tier), true))): continue
		var crop: Dictionary = CROPS[str(tray(str(item.pid)).crop)]
		total += float(crop.kg) * float(GROWERS[str(item.id)]) / float(crop.sols) * pace
	return total

## One step: crops grow, ripe ones are picked by a cart or go over, produce
## spoils, and the crew eat (fresh first). Returns {eaten, eaten_fresh, harvested_kg}.
func step(dt: float, inv: Dictionary, powered: Dictionary, crew: int) -> Dictionary:
	var per_sol := dt / 24.0
	var growers := _growers(inv)
	if not nutrients_delivered and not growers.is_empty():
		nutrients_delivered = true   # the trays come with Earth's nutrients
		sim.stores.nutrients_kg = float(sim.stores.nutrients_kg) + START_NUTRIENTS_KG
	if _has(inv, "nutrient_mixer", powered):
		var compost := minf(float(sim.stores.compost_kg), MIXER_KG * 2.0 * per_sol)
		sim.stores.compost_kg = float(sim.stores.compost_kg) - compost
		sim.stores.nutrients_kg = float(sim.stores.nutrients_kg) + compost * .5
	var pace: float = speed(inv, powered) * sim.life.food_speed()
	var carts := {}
	for item in inv.items:
		if str(item.id) == "harvest_cart": carts[int(item.room)] = true
	var picked := 0.0
	for item in growers:
		var t := tray(str(item.pid))
		var crop: Dictionary = CROPS[str(t.crop)]
		if float(t.growth) >= 1.0:
			if carts.has(int(item.room)):
				picked += _pick(str(item.pid), float(GROWERS[str(item.id)]))
				continue
			t.ripe_h = float(t.ripe_h) + dt
			if float(t.ripe_h) >= RIPE_SOLS * 24.0:
				# Gone over: to the compost hopper (habitat_waste.gd), and replanted.
				sim.stores.organics_kg = float(sim.stores.organics_kg) + float(crop.kg) * float(GROWERS[str(item.id)])
				_replant(t, inv)
			continue
		if not (bool(item.on) and bool(powered.get(int(item.tier), true))): continue
		var grown := minf(1.0 - float(t.growth), per_sol / float(crop.sols) * pace)
		t.growth = float(t.growth) + grown
		sim.stores.nutrients_kg = maxf(0.0, float(sim.stores.nutrients_kg) - grown * float(crop.kg) * float(GROWERS[str(item.id)]) * NUTRIENT_PER_KG)
	# Trays that were removed.
	var live := {}
	for item in growers: live[str(item.pid)] = true
	for pid in trays.keys():
		if not live.has(pid): trays.erase(pid)
	_spoil(inv, powered)
	# Eating: fresh produce first (oldest first), then rations.
	var want := crew * MHGame.food_per_person() * per_sol
	var fresh := 0.0
	while not batches.is_empty() and fresh < want - .000001:
		var batch: Dictionary = batches[0]
		var bite := minf(float(batch.kg), want - fresh)
		batch.kg = float(batch.kg) - bite
		fresh += bite
		if float(batch.kg) <= .000001: batches.pop_front()
	var eaten := minf(want, float(sim.food_kg))
	fresh = minf(fresh, eaten)
	sim.food_kg = maxf(0.0, float(sim.food_kg) - eaten)
	_sync_produce()
	if want > 0.0: fresh_share += (fresh / want - fresh_share) * minf(1.0, per_sol / DIET_SOLS)
	return {"eaten": eaten, "eaten_fresh": fresh, "harvested_kg": picked}

func _replant(t: Dictionary, inv: Dictionary) -> void:
	t.crop = str(t.get("next", t.crop))
	t.growth = SEEDLING_START if _has(inv, "seedling_station") else 0.0
	t.ripe_h = 0.0

func _pick(pid: String, scale: float) -> float:
	var t := tray(pid)
	var kg := float(CROPS[str(t.crop)].kg) * scale
	batches.append({"crop": str(t.crop), "kg": kg, "at": float(sim.hours_run)})
	harvested[str(t.crop)] = float(harvested.get(str(t.crop), 0.0)) + kg
	sim.stores.organics_kg = float(sim.stores.organics_kg) + kg * float(INEDIBLE.get(str(t.crop), .3))
	sim.food_kg = float(sim.food_kg) + kg
	_sync_produce()
	_replant(t, sim.inventory())
	return kg

func _spoil(inv: Dictionary, powered: Dictionary) -> void:
	var keeps := (FREEZER_SOLS if _has(inv, "galley_freezer", powered) else SHELF_SOLS) * 24.0
	for batch in batches.duplicate():
		if float(sim.hours_run) - float(batch.at) <= keeps: continue
		batches.erase(batch)
		sim.food_kg = maxf(0.0, float(sim.food_kg) - float(batch.kg))
		sim.stores.organics_kg = float(sim.stores.organics_kg) + float(batch.kg)

func _sync_produce() -> void:
	var total := 0.0
	for batch in batches: total += float(batch.kg)
	sim.stores.produce_kg = minf(total, float(sim.food_kg))

# ---------- the tray's own actions (equipment_rig.gd) ----------

## E on a ripe tray: harvest it. Returns {title, text}, or {} if not ripe.
func harvest(pid: String) -> Dictionary:
	var inv: Dictionary = sim.inventory()
	var item: Dictionary = {}
	for each in _growers(inv):
		if str(each.pid) == pid: item = each
	if item.is_empty(): return {}
	var t := tray(pid)
	if float(t.growth) < 1.0: return {}
	var crop := str(t.crop)
	var kg := _pick(pid, float(GROWERS[str(item.id)]))
	return {"title": "Harvested %.1f kg of %s" % [kg, CROPS[crop].label], "text": "Fresh food keeps %d sols (%d in a freezer). %s planted next." % [roundi(SHELF_SOLS), roundi(FREEZER_SOLS), str(CROPS[str(t.crop)].label).capitalize()]}

## G on a tray: the crop it grows next.
func cycle_next(pid: String) -> String:
	var t := tray(pid)
	t.next = CROP_ORDER[(CROP_ORDER.find(str(t.next)) + 1) % CROP_ORDER.size()]
	if float(t.growth) <= 0.0: t.crop = t.next   # nothing in yet: plant it now
	return str(t.next)

## "Greens · 60% grown", "Potatoes ripe: harvest", for the tray's E prompt.
func status(pid: String) -> String:
	var t := tray(pid)
	var crop: Dictionary = CROPS[str(t.crop)]
	if float(t.growth) >= 1.0:
		return "Harvest %s (ripe, %d sols before it goes over)" % [crop.label, maxi(0, ceili(RIPE_SOLS - float(t.ripe_h) / 24.0))]
	return "%s · %d%% grown" % [str(crop.label).capitalize(), floori(float(t.growth) * 100.0)]

func next_label(pid: String) -> String:
	return "Next crop: %s → %s" % [CROPS[str(tray(pid).next)].label, CROPS[CROP_ORDER[(CROP_ORDER.find(str(tray(pid).next)) + 1) % CROP_ORDER.size()]].label]

## Fresh food keeping, and the trays: for the Monitor.
func summary(inv: Dictionary) -> Dictionary:
	var ripe := 0
	var growing := 0
	for item in _growers(inv):
		if float(tray(str(item.pid)).growth) >= 1.0: ripe += 1
		else: growing += 1
	var oldest := -1.0
	if not batches.is_empty(): oldest = float(batches[0].at)
	return {"growing": growing, "ripe": ripe, "fresh_kg": float(sim.stores.produce_kg), "oldest_at": oldest, "nutrients_kg": float(sim.stores.nutrients_kg), "fresh_share": fresh_share}
