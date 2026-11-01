extends RefCounted

## Wear and the daily rounds (core-loop step 7; docs/survival-systems.md
## §12.4). Owned by the habitat simulation (habitat_sim.gd `wear`), which
## calls step() every step. Chapter rules only (older saves and Missions keep
## the old random breakdowns alone).
##
## - Each chain machine wears as it runs, from 0 to 1 over its SOLS (times
##   the new-game Wear pace, MHGame.challenge.wear).
## - Past SLOW_FROM its output falls, down to WORST at fully worn
##   (factor(), read by the sim and the waste sorter).
## - Left fully worn for FAIL_SOLS it breaks: it joins the life module's
##   broken list, and the crew repair it with a spares kit and hours of work.
## - Servicing it by hand (E, or its filter or hatch: equipment_rig.gd)
##   takes one spares kit (habitat_life.gd `spares`) and makes it as new.
## - Spares kits come from the fabricator, from feedstock (chapter_one.gd).
const MACHINES := {
	"air_recycler": {"sols": 6.0, "job": "Swap the filter"},
	"water_reclaimer": {"sols": 6.0, "job": "Swap the filter bed"},
	"urine_processor": {"sols": 8.0, "job": "Swap the brine bag"},
	"waste_sorting_unit": {"sols": 10.0, "job": "Clear and service the sorter"},
	"oxygen_generator": {"sols": 12.0, "job": "Service the cell stack"},
	"sabatier_reactor": {"sols": 30.0, "job": "Change the catalyst"},
}
const SLOW_FROM := .7       # output starts to fall
const WORST := .5           # output share when fully worn
const FAIL_SOLS := 2.0      # fully worn this long, it breaks
const SERVICE_FROM := .25   # servicing earlier than this would waste a kit
const ROUND_FROM := .5      # on today's rounds
const ALERT_FROM := .85
const START_KITS := 8       # landed with the precursor cargo

var sim: RefCounted
var wear := {}              # placement id -> 0-1
var worn_h := {}            # placement id -> hours spent fully worn
var kits_landed := false

func _init(owner: RefCounted) -> void:
	sim = owner

func save() -> Dictionary:
	return {"wear": wear.duplicate(), "worn_h": worn_h.duplicate(), "kits_landed": kits_landed}

func load(state: Dictionary) -> void:
	wear = (state.get("wear", {}) as Dictionary).duplicate()
	worn_h = (state.get("worn_h", {}) as Dictionary).duplicate()
	kits_landed = bool(state.get("kits_landed", false))

static func on() -> bool:
	return MHChapterOne.on()

## The new-game Wear pace: 1 is a service every few sols per machine.
static func pace() -> float:
	return clampf(float(MHGame.challenge.get("wear", 1.0)), .25, 4.0)

func level(pid: String) -> float:
	return float(wear.get(pid, 0.0))

## The share of its output a machine gives at its wear.
func factor(item: Dictionary) -> float:
	if not on() or not MACHINES.has(str(item.get("id", ""))): return 1.0
	var w := level(str(item.get("pid", "")))
	if w <= SLOW_FROM: return 1.0
	return lerpf(1.0, WORST, (w - SLOW_FROM) / (1.0 - SLOW_FROM))

func step(dt: float, inv: Dictionary, powered: Dictionary) -> void:
	if not on(): return
	if not kits_landed:
		kits_landed = true
		sim.life.spares = int(sim.life.spares) + START_KITS
	var live := {}
	for item in inv.items:
		var id := str(item.id)
		var pid := str(item.get("pid", ""))
		if not MACHINES.has(id) or pid.is_empty(): continue
		live[pid] = true
		if not bool(item.on) or sim.life.is_broken(item): continue
		if float(item.power) > 0.0 and not bool(powered.get(int(item.tier), true)): continue
		var w := minf(1.0, level(pid) + dt / (float(MACHINES[id].sols) * 24.0) * pace())
		wear[pid] = w
		if w < 1.0: continue
		worn_h[pid] = float(worn_h.get(pid, 0.0)) + dt
		if float(worn_h[pid]) >= FAIL_SOLS * 24.0:
			sim.life.broken[pid] = {"id": id, "hours": 0.0, "worn": true}
			worn_h.erase(pid)
	for pid in wear.keys():
		if not live.has(pid): wear.erase(pid); worn_h.erase(pid)

## E on the machine (or its filter or hatch): a spares kit makes it as new.
## Returns {title, text}.
func service(pid: String, id: String) -> Dictionary:
	if not MACHINES.has(id): return {}
	var name := str(EquipmentCatalog.get_entry(id).get("label", id))
	if sim.life.broken.has(pid): return {"title": "%s is broken" % name, "text": "The crew repair it with a spares kit and a few hours' work."}
	var w := level(pid)
	if w < SERVICE_FROM: return {"title": "%s: no need yet" % name, "text": "Wear %d %%. Service it from about %d %%, or a spares kit is wasted." % [roundi(w * 100.0), roundi(ROUND_FROM * 100.0)]}
	if int(sim.life.spares) <= 0: return {"title": "No spares kit", "text": "The fabricator makes spares kits from feedstock."}
	sim.life.spares = int(sim.life.spares) - 1
	wear[pid] = 0.0
	worn_h.erase(pid)
	return {"title": "%s: %s" % [name, str(MACHINES[id].job).to_lower()], "text": "As new. %d spares kit%s left." % [int(sim.life.spares), "" if int(sim.life.spares) == 1 else "s"]}

## A repair (habitat_life.gd) leaves the machine as new.
func repaired(pid: String) -> void:
	wear[pid] = 0.0
	worn_h.erase(pid)

## The machines due a service, most worn first: [{pid, id, label, wear, job, broken}].
func rounds(inv: Dictionary) -> Array:
	var out: Array = []
	if not on(): return out
	for item in inv.items:
		var id := str(item.id)
		var pid := str(item.get("pid", ""))
		if not MACHINES.has(id) or pid.is_empty(): continue
		var broken: bool = sim.life.broken.has(pid)
		if level(pid) < ROUND_FROM and not broken: continue
		out.append({"pid": pid, "id": id, "label": str(EquipmentCatalog.get_entry(id).get("label", id)), "wear": level(pid), "job": str(MACHINES[id].job), "broken": broken})
	out.sort_custom(func(a, b): return float(a.wear) > float(b.wear))
	return out

## The first machine to break if nobody services anything: [sols, label], or [].
func first_failure(inv: Dictionary) -> Array:
	if not on(): return []
	var best: Array = []
	for item in inv.items:
		var id := str(item.id)
		var pid := str(item.get("pid", ""))
		if not MACHINES.has(id) or pid.is_empty() or not bool(item.on) or sim.life.broken.has(pid): continue
		var hours := (1.0 - level(pid)) * float(MACHINES[id].sols) * 24.0 / pace() + FAIL_SOLS * 24.0 - float(worn_h.get(pid, 0.0))
		if best.is_empty() or hours / 24.0 < float(best[0]): best = [hours / 24.0, str(EquipmentCatalog.get_entry(id).get("label", id))]
	return best
