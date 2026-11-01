extends RefCounted

## Waste (docs/survival-systems.md §6, phase 5): what the crew throw away,
## sorted into plastics, metals and organics, recycled into the fabricator's
## feedstock, or composted for the nutrient mixer. Owned by the habitat
## simulation (habitat_sim.gd `waste`), which calls step() every step.
##
## - Rubbish comes from ration packaging (so it runs down as the crew eat what
##   they grow: Earth's packaging runs out, §12.4), everyday trash and the
##   toilet's solids. Unsorted, it just piles up (sim.stores.waste_kg).
## - The waste sorter (powered) sorts it. The plastics and metals hoppers turn
##   their share into feedstock (MHChapterOne.feedstock_kg, chapter rules);
##   the compost hopper turns organics (and food that went off) into compost.
## - The nutrient mixer makes nutrients from compost (habitat_food.gd).
const MHResources := preload("res://scripts/mh_resources.gd")

const PACKAGING_PER_KG := .25    # kg of packaging per kg of rations eaten (80 % plastic, 20 % foil)
const TRASH_KG := .3             # everyday trash, per person a sol (half plastic, a tenth metal, the rest organic)
const SOLIDS_KG := .12           # from the toilet, per person a sol (organic)
const SORTER_KG := 12.0          # a sol
const PLASTICS_KG := 2.5         # a plastics hopper melts this much a sol, 90 % of it feedstock
const METALS_KG := 1.0           # a metals hopper, 95 %
const COMPOST_KG := 1.5          # a compost hopper takes this much organics a sol; 40 % comes out as compost
const PILE_ALERT_KG := 40.0

var sim: RefCounted
var unsorted := {"plastic": 0.0, "metal": 0.0, "organic": 0.0}
var recycled_kg := 0.0           # feedstock made in this game (reports)
var last := {}                   # the last step, a sol's worth: {made, sorted, recycled, composted} (habitat_chains.gd)

func _init(owner: RefCounted) -> void:
	sim = owner

func save() -> Dictionary:
	return {"unsorted": unsorted.duplicate(), "recycled_kg": recycled_kg}

func load(state: Dictionary) -> void:
	unsorted = {"plastic": 0.0, "metal": 0.0, "organic": 0.0}
	var saved: Dictionary = state.get("unsorted", {})
	for key in saved:
		if unsorted.has(key): unsorted[key] = float(saved[key])
	recycled_kg = float(state.get("recycled_kg", 0.0))

func _count(inv: Dictionary, id: String, powered: Dictionary = {}) -> int:
	return (inv.items as Array).filter(func(i): return str(i.id) == id and bool(i.on) and (powered.is_empty() or float(i.power) <= 0.0 or bool(powered.get(int(i.tier), true)))).size()

## One step. rations_kg: rations eaten in it (their packaging).
func step(dt: float, inv: Dictionary, powered: Dictionary, crew: int, rations_kg: float) -> void:
	var per_sol := dt / 24.0
	var packaging := rations_kg * PACKAGING_PER_KG
	var trash := crew * TRASH_KG * per_sol
	unsorted.plastic = float(unsorted.plastic) + packaging * .8 + trash * .5
	unsorted.metal = float(unsorted.metal) + packaging * .2 + trash * .1
	unsorted.organic = float(unsorted.organic) + trash * .4 + crew * SOLIDS_KG * per_sol
	var stores: Dictionary = sim.stores
	# The sorter takes the pile in proportion.
	var total := pile()
	var sortable := minf(total, _count(inv, "waste_sorting_unit", powered) * SORTER_KG * per_sol)
	if sortable > 0.0 and total > 0.0:
		var share := sortable / total
		stores.plastics_kg = float(stores.plastics_kg) + float(unsorted.plastic) * share
		stores.metals_kg = float(stores.metals_kg) + float(unsorted.metal) * share
		stores.organics_kg = float(stores.organics_kg) + float(unsorted.organic) * share
		for key in unsorted: unsorted[key] = float(unsorted[key]) * (1.0 - share)
	stores.waste_kg = pile()
	# Recycling into feedstock.
	var plastic := minf(float(stores.plastics_kg), _count(inv, "recycling_hopper_plastics") * PLASTICS_KG * per_sol)
	var metal := minf(float(stores.metals_kg), _count(inv, "recycling_hopper_metals") * METALS_KG * per_sol)
	stores.plastics_kg = float(stores.plastics_kg) - plastic
	stores.metals_kg = float(stores.metals_kg) - metal
	var made := plastic * .9 + metal * .95
	recycled_kg += made
	if MHChapterOne.on(): MHChapterOne.feedstock_kg += made
	# Compost.
	var organic := minf(float(stores.organics_kg), _count(inv, "compost_hopper") * COMPOST_KG * per_sol)
	stores.organics_kg = float(stores.organics_kg) - organic
	stores.compost_kg = float(stores.compost_kg) + organic * .4
	if per_sol > 0.0: last = {"made": (packaging + trash + crew * SOLIDS_KG * per_sol) / per_sol, "sorted": sortable / per_sol, "recycled": made / per_sol, "composted": organic / per_sol}

func pile() -> float:
	return float(unsorted.plastic) + float(unsorted.metal) + float(unsorted.organic)

## Feedstock the base's recycling makes a sol, at the current diet.
func rate(inv: Dictionary, crew: int, rations_per_sol: float) -> float:
	if _count(inv, "waste_sorting_unit") == 0: return 0.0
	var packaging := rations_per_sol * PACKAGING_PER_KG
	var trash := crew * TRASH_KG
	var plastic := minf(packaging * .8 + trash * .5, _count(inv, "recycling_hopper_plastics") * PLASTICS_KG)
	var metal := minf(packaging * .2 + trash * .1, _count(inv, "recycling_hopper_metals") * METALS_KG)
	return plastic * .9 + metal * .95
