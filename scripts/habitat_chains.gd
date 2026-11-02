extends RefCounted

## The four chains (docs/survival-systems.md §8, §12.1, phase 7): air, water,
## food and waste, each a loop of parts. One core part keeps the crew alive
## by itself, wastefully; every other part closes some of the leak. This
## reads the habitat simulation (habitat_sim.gd `last`, `stores`) and says,
## per chain, how closed it is, what it holds and which link is missing or
## overloaded. Used by the Monitor's Chains view, the machines' readouts,
## the airlock panel's runway (§12.5) and the Field guide's chain cards.
const MHResources := preload("res://scripts/mh_resources.gd")

## Each chain's parts, in the order the loop runs. core: the part that does
## the whole job alone. gives: what adding it does, for the weak-link line.
## site: counted from the outdoor machines (inventory drills / processors).
const CHAINS := {
	"air": {"label": "Air", "icon": "wind", "links": [
		{"id": "air_recycler", "core": true, "gives": "takes carbon dioxide out of the air"},
		{"id": "oxygen_generator", "core": true, "gives": "splits water into oxygen"},
		{"id": "sabatier_reactor", "gives": "turns kept carbon dioxide back into water, so less water is split for nothing"},
		{"id": "methane_tank", "gives": "keeps the Sabatier's methane (fuel for the trip home)"},
		{"id": "atmosphere_processor", "site": "processors", "gives": "makes oxygen from Mars air, with no water"}]},
	"water": {"label": "Water", "icon": "droplets", "links": [
		{"id": "ice_extractor", "site": "drills", "core": true, "gives": "drills ice for meltwater"},
		{"id": "water_reclaimer", "gives": "cleans meltwater and recovers grey water"},
		{"id": "urine_processor", "gives": "recovers most of the water in urine"}]},
	"food": {"label": "Food", "icon": "sprout", "links": [
		{"id": "rations", "core": true, "label": "Earth's rations", "gives": "feeds the crew until they run out"},
		{"id": "grow_tray", "gives": "grows fresh food over sols"},
		{"id": "harvest_cart", "gives": "harvests ripe trays in its room by itself"},
		{"id": "seedling_station", "gives": "gives every replanting a head start"},
		{"id": "nutrient_mixer", "gives": "makes nutrients from compost, so the trays keep full speed"},
		{"id": "galley_freezer", "gives": "keeps harvests 60 sols instead of 10"}]},
	"waste": {"label": "Waste", "icon": "recycle", "links": [
		{"id": "waste_sorting_unit", "core": true, "gives": "sorts the rubbish so it can be used"},
		{"id": "recycling_hopper_plastics", "gives": "melts plastics into fabricator feedstock"},
		{"id": "recycling_hopper_metals", "gives": "turns metals into feedstock"},
		{"id": "compost_hopper", "gives": "turns food scraps into compost for the nutrient mixer"}]},
}
const ORDER := ["air", "water", "food", "waste"]
## Which chain each wearing machine belongs to.
const CHAIN_OF := {"air_recycler": "air", "oxygen_generator": "air", "sabatier_reactor": "air", "water_reclaimer": "water", "urine_processor": "water", "waste_sorting_unit": "waste"}

static func label(link: Dictionary) -> String:
	if link.has("label"): return str(link.label)
	return str(EquipmentCatalog.get_entry(str(link.id)).get("label", str(link.id).capitalize()))

## How many of a link the base has working.
static func count(inv: Dictionary, link: Dictionary) -> int:
	if str(link.id) == "rations": return 1
	if link.has("site"):
		var site = inv.get(str(link.site), 0)
		return (site as Array).size() if site is Array else int(site)
	return (inv.items as Array).filter(func(i): return str(i.id) == str(link.id) and bool(i.on)).size()

static func _share(part: float, whole: float) -> float:
	return clampf(part / whole, 0.0, 1.0) if whole > .0001 else 0.0

## One chain now: {id, label, icon, closure 0-1 (-1 with nobody aboard),
## stores (text), links [{label, have, core}], weak (text, "" if none), level
## ("ok", "warn", "bad")}.
static func chain(sim: RefCounted, id: String) -> Dictionary:
	var spec: Dictionary = CHAINS[id]
	var inv: Dictionary = sim.inventory()
	var last: Dictionary = sim.last
	var s: Dictionary = sim.stores
	var lost: Dictionary = last.get("vented", {})
	var crew := int(last.get("crew", 0))
	var links: Array = []
	var missing_core := ""
	var next := ""
	for link in spec.links:
		var have := count(inv, link) > 0
		links.append({"label": label(link), "have": have, "core": bool(link.get("core", false))})
		if have: continue
		if bool(link.get("core", false)) and missing_core.is_empty(): missing_core = label(link)
		elif next.is_empty(): next = "Next: %s %s." % [label(link), str(link.gives)]
	var closure := -1.0
	var stores := ""
	var weak := ""
	var level := "ok"
	match id:
		"air":
			# Oxygen breathed that comes back from the crew's own carbon dioxide.
			var breathed := crew * MHResources.setting("o2_per_person", .84)
			closure = _share(float(last.get("co2_back", 0.0)) * 32.0 / 44.0, breathed)
			stores = "O₂ %.1f%% · CO₂ %.2f%% · reserve %d kg · CO₂ kept %.1f kg · H₂ %.1f kg · methane %.1f kg" % [float(sim.o2_pct), float(sim.co2_pct), roundi(float(sim.o2_reserve_kg)), float(s.co2_kg), float(s.h2_kg), float(s.ch4_kg)]
			if float(sim.co2_pct) > MHResources.setting("co2_danger_pct", 1.0) or float(sim.o2_pct) < MHResources.setting("o2_min_pct", 19.5): level = "bad"
			if float(lost.get("ch4_kg", 0.0)) > 0.0: weak = "Methane venting: add a methane tank."
			elif float(lost.get("h2_kg", 0.0)) > .05 and count(inv, CHAINS.air.links[2]) == 0: weak = "Hydrogen and carbon dioxide vented: a Sabatier reactor would turn them back into water."
		"water":
			closure = _share(float(last.get("recovered", 0.0)), float(last.get("water_out", 0.0)))
			var caps: Dictionary = sim.store_caps(inv.capacity)
			stores = "clean %d L · meltwater %d · grey %d of %d · urine %d of %d · brine %.1f L" % [roundi(float(sim.water_l)), roundi(float(s.raw_l)), roundi(float(s.grey_l)), roundi(float(caps.grey_l)), roundi(float(s.urine_l)), roundi(float(caps.urine_l)), float(s.brine_l)]
			if float(sim.water_l) <= 0.0 and crew > 0: level = "bad"
			var reclaimers := count(inv, CHAINS.water.links[1])
			if float(lost.get("grey_l", 0.0)) > .5: weak = "Grey water venting: %s." % ("the water processor can't keep up" if reclaimers > 0 else "no water processor")
			elif float(lost.get("urine_l", 0.0)) > .5: weak = "Urine venting: %s." % ("the urine processor can't keep up" if count(inv, CHAINS.water.links[2]) > 0 else "no urine processor")
			elif float(lost.get("raw_l", 0.0)) > .5: weak = "Meltwater spilling: %s." % ("the water processor can't keep up" if reclaimers > 0 else "no water processor to clean it")
		"food":
			var eaten := crew * MHGame.food_per_person()
			closure = _share(float(last.get("food_in", 0.0)), eaten)
			var crops: Dictionary = sim.food.summary(inv)
			stores = "%d kg (fresh %.1f) · nutrients %.1f kg · %d growing, %d ripe · %d%% of meals fresh" % [roundi(float(sim.food_kg)), float(crops.fresh_kg), float(crops.nutrients_kg), int(crops.growing), int(crops.ripe), roundi(float(crops.fresh_share) * 100.0)]
			if float(sim.food_kg) <= 0.0 and crew > 0: level = "bad"
			if int(crops.ripe) > 0: weak = "%d tray%s ripe: harvest with E, or a harvest cart does it." % [int(crops.ripe), "" if int(crops.ripe) == 1 else "s"]
			elif float(crops.nutrients_kg) <= 0.0 and int(crops.growing) > 0: weak = "No nutrients: the trays grow at half speed. A nutrient mixer makes more from compost."
		"waste":
			var flow: Dictionary = sim.waste.last
			closure = _share(float(flow.get("recycled", 0.0)) + float(flow.get("composted", 0.0)), float(flow.get("made", 0.0)))
			stores = "unsorted %d kg · plastics %d · metals %d · organics %d · compost %.1f kg · %.1f kg feedstock made" % [roundi(float(s.waste_kg)), roundi(float(s.plastics_kg)), roundi(float(s.metals_kg)), roundi(float(s.organics_kg)), float(s.compost_kg), float(sim.waste.recycled_kg)]
			if float(s.waste_kg) >= sim.waste.PILE_ALERT_KG: weak = "Rubbish piling up (%d kg): %s." % [roundi(float(s.waste_kg)), "the sorter can't keep up" if count(inv, CHAINS.waste.links[0]) > 0 else "a waste sorter sorts it"]
	# Wear (habitat_wear.gd): a broken or badly worn part is the weak link.
	for due in sim.wear.rounds(inv):
		if str(CHAIN_OF.get(str(due.id), "")) != id: continue
		if bool(due.broken): weak = "%s broken: the crew repair it with a spares kit." % str(due.label); level = "bad"; break
		if float(due.wear) >= sim.wear.ALERT_FROM and weak.is_empty(): weak = "%s %d%% worn: %s (a spares kit)." % [str(due.label), roundi(float(due.wear) * 100.0), str(due.job).to_lower()]
	if crew <= 0: closure = -1.0
	if not missing_core.is_empty() and id != "waste":
		weak = "No %s: this is the part the chain can't do without." % missing_core
		level = "bad"
	if weak.is_empty(): weak = next
	elif level == "ok": level = "warn"
	# Freedom: nobody needs food, so the food chain is optional.
	if id == "food" and not MHGame.needs_food_water():
		level = "ok"
		closure = -1.0
		weak = "Not needed: nobody needs food in this game."
	return {"id": id, "label": str(spec.label), "icon": str(spec.icon), "closure": closure, "stores": stores, "links": links, "weak": weak, "level": level}

## The most crew each chain could carry, {air, water, food, waste} (Mission
## readiness, §12.2): the largest n up to MAX_CREW whose sol balances.
const MAX_CREW := 12
static func supports_all(sim: RefCounted) -> Dictionary:
	var out := {"air": 0, "water": 0, "food": 0, "waste": 0}
	var inv: Dictionary = sim.inventory()
	var sorters := (inv.items as Array).filter(func(i): return str(i.id) == "waste_sorting_unit" and bool(i.on)).size()
	for n in range(1, MAX_CREW + 1):
		var f: Dictionary = sim.daily_flows(true, n)
		if float(f.o2_made) >= float(f.o2_need) - .001 and float(f.co2_removed) >= float(f.co2_made) - .001: out.air = n
		if float(f.water_made) >= float(f.water_used) - .001: out.water = n
		if float(f.food_grown) >= float(f.food_eaten) - .001 or float(sim.food_kg) >= float(f.food_eaten) * 30.0: out.food = n
		var rations := maxf(0.0, float(f.food_eaten) - float(f.food_grown))
		var rubbish: float = rations * float(sim.waste.PACKAGING_PER_KG) + n * (float(sim.waste.TRASH_KG) + float(sim.waste.SOLIDS_KG))
		if sorters * float(sim.waste.SORTER_KG) >= rubbish: out.waste = n
	return out

static func chains(sim: RefCounted) -> Array:
	return ORDER.map(func(id): return chain(sim, id))

# ---------- the runway (§12.5) ----------

## How long the base runs without you, and what gives out first:
## {sols (INF if nothing runs down), first, text}. From each store's sols
## left at the current rates (wear joins it with step 7's rounds).
static func runway(sim: RefCounted) -> Dictionary:
	var last: Dictionary = sim.last
	var crew := int(last.get("crew", 0))
	var limits: Array = []   # [sols, what, what happens]
	if crew > 0:
		var water_net := float(last.get("water_in", 0.0)) - float(last.get("water_out", 0.0))
		if water_net < -.01: limits.append([float(sim.water_l) / -water_net, "the water", "runs out"])
		var food_net := float(last.get("food_in", 0.0)) - crew * MHGame.food_per_person()
		if food_net < -.01: limits.append([float(sim.food_kg) / -food_net, "the food", "runs out"])
		var o2_net := float(last.get("o2_in", 0.0)) - crew * MHResources.setting("o2_per_person", .84)
		if o2_net < -.01: limits.append([float(sim.o2_reserve_kg) / -o2_net + .3, "the oxygen", "runs out"])
		var co2_net := crew * MHResources.setting("co2_per_person", 1.0) - float(last.get("co2_out", 0.0))
		var cells := int(sim.inventory().cells)
		if co2_net > .05 and cells > 0:
			var air_kg: float = cells * float(sim.CELL_VOLUME) * float(sim.AIR_DENSITY)
			var room: float = maxf(0.0, MHResources.setting("co2_danger_pct", 1.0) - float(sim.co2_pct)) / 100.0 * (air_kg / 29.0) * 44.0
			limits.append([room / co2_net, "the air (carbon dioxide)", "runs out"])
	# Wear: the first machine to break if nobody services it.
	var failure: Array = sim.wear.first_failure(sim.inventory())
	if crew > 0 and not failure.is_empty(): limits.append([float(failure[0]), "the %s" % str(failure[1]), "breaks down"])
	if limits.is_empty(): return {"sols": INF, "first": "", "text": "Safe: nothing is running down." if crew > 0 else "Nobody aboard."}
	limits.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var sols := float(limits[0][0])
	var when := "a month or more" if sols >= 30.0 else ("about %d sols" % roundi(sols) if sols >= 1.5 else ("about a sol" if sols >= .75 else "about %d hours" % maxi(1, roundi(sols * 24.0))))
	var what := str(limits[0][1])
	return {"sols": sols, "first": what, "text": "Safe for %s. %s %s first." % [when, what.substr(0, 1).to_upper() + what.substr(1), str(limits[0][2])]}

# ---------- machine readouts (§8) ----------

## One line for a machine's own screen and its look-at prompt, or "".
static func readout(sim: RefCounted, id: String, pid := "") -> String:
	var line := _readout(sim, id)
	if pid.is_empty() or not sim.wear.MACHINES.has(id) or not sim.wear.on(): return line
	var wear := "BROKEN" if sim.life.broken.has(pid) else "wear %d%%" % roundi(sim.wear.level(pid) * 100.0)
	return wear if line.is_empty() else "%s · %s" % [line, wear]

static func _readout(sim: RefCounted, id: String) -> String:
	var last: Dictionary = sim.last
	var s: Dictionary = sim.stores
	var inv: Dictionary = sim.inventory()
	var lost: Dictionary = last.get("vented", {})
	var units := maxi(1, (inv.items as Array).filter(func(i): return str(i.id) == id and bool(i.on)).size())
	match id:
		"water_reclaimer":
			return "%.1f L/h clean · grey %d L%s" % [float(last.get("processed", 0.0)) / units / 24.0, roundi(float(s.grey_l)), " · overflowing" if float(lost.get("grey_l", 0.0)) > .5 else ""]
		"urine_processor":
			return "%.1f L/h · urine %d L · brine %.1f L" % [float(last.get("urine_done", 0.0)) / units / 24.0, roundi(float(s.urine_l)), float(s.brine_l)]
		"air_recycler":
			return "CO₂ %.2f%% · %.1f kg kept for the Sabatier" % [float(sim.co2_pct), float(s.co2_kg)]
		"oxygen_generator":
			return "O₂ %.1f%% · %.1f kg a sol from water" % [float(sim.o2_pct), float(last.get("electrolysis_o2", 0.0)) / units]
		"sabatier_reactor":
			return "%.1f L water back a sol · CO₂ %.1f kg · H₂ %.1f kg" % [float(last.get("sabatier_water", 0.0)) / units, float(s.co2_kg), float(s.h2_kg)]
		"methane_tank":
			return "Methane %.1f of %d kg" % [float(s.ch4_kg), roundi(float(last.get("methane_cap", 0.0)))]
		"waste_sorting_unit":
			return "%.1f kg sorted a sol · %d kg waiting" % [float(sim.waste.last.get("sorted", 0.0)) / units, roundi(float(s.waste_kg))]
		"recycling_hopper_plastics":
			return "Plastics %.1f kg · feedstock %.1f kg made" % [float(s.plastics_kg), float(sim.waste.recycled_kg)]
		"recycling_hopper_metals":
			return "Metals %.1f kg · feedstock %.1f kg made" % [float(s.metals_kg), float(sim.waste.recycled_kg)]
		"compost_hopper":
			return "Organics %.1f kg · compost %.1f kg" % [float(s.organics_kg), float(s.compost_kg)]
		"nutrient_mixer":
			return "Nutrients %.1f kg · compost %.1f kg" % [float(s.nutrients_kg), float(s.compost_kg)]
		"galley_freezer":
			return "Fresh food %.1f kg · keeps %d sols" % [float(s.produce_kg), roundi(sim.food.FREEZER_SOLS)]
	return ""
