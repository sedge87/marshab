class_name MHRoomTypes
extends RefCounted

## The room model of 14 Nov (docs/rooms-and-equipment.md; build plan A3):
## plan by type, place freely.
## - Each room type has a key piece. It arrives with the room, in a sensible
##   spot you can change (remove it and it waits on the Unpacked tab), and the
##   room's bonus works while one is inside.
## - The walker's core (zone kind "general", once the General Module) opens
##   room types through upgrades: a plan, then feedstock, fitted at the core's
##   rack. No limit: every upgrade can go on.
## - Rooms only ever help: no noise or cramped penalties.
## The ids stay from before, so saves keep working; only the names changed.
##
## The upgrades and the key pieces only apply under chapter one's rules
## (MHChapterOne.on(): a new Survival or Freedom game). Creative and older
## saves have every room type open from the start.

const ROOMS := {
	# "bonus" is what the build bar says it does now; "" where the bonus
	# comes with a later phase (A5 station chains, A7 vehicles).
	"engineering": {"key": "fabricator", "bonus": "Its Print Shop prints faster", "owner": "Achterberg"},
	"science": {"key": "science_workbench", "bonus": "Finds are analysed here", "owner": "Tupou"},
	"living": {"key": "crew_bunk", "bonus": "A full night's sleep: rested for longer", "owner": "Mwangi"},
	"galley": {"key": "galley_kitchenette", "bonus": "", "owner": "Mwangi"},
	"hydroponics": {"key": "greenhouse_planter", "bonus": "Grows food", "owner": "Tupou"},
	"storage": {"key": "cargo_rack", "bonus": "", "owner": ""},
	"vehicle_bay": {"key": "rover_charger", "bonus": "", "owner": "Castle"},
	"medical": {"key": "crew_bunk", "bonus": "Twice the hull's shielding", "owner": "Rao"},
}

## Core upgrades: plan id (data/plans.json) and the room types each opens.
## Costs are feedstock, paid as it's fitted.
const UPGRADES := {
	"water_loop": {"label": "Water loop", "plan": "core_water_loop", "opens": ["galley", "hydroponics"], "icon": "droplets",
		"says": "Plumbs the core's water through to new rooms: a Galley and a Greenhouse."},
	"heavy_power": {"label": "Heavy power", "plan": "core_heavy_power", "opens": ["engineering"], "icon": "zap",
		"says": "A heavier bus from the power hub, enough for a Workshop and big outside machines."},
	"lab_services": {"label": "Lab services", "plan": "core_lab_services", "opens": ["science"], "icon": "flask-conical",
		"says": "Clean air, filtered power and a fume line for a Lab."},
	"vehicle_charging": {"label": "Vehicle charging", "plan": "core_vehicle_charging", "opens": ["vehicle_bay"], "icon": "plug-zap",
		"says": "A fast-charge line out to a Garage."},
	"shielding": {"label": "Shielding", "plan": "core_shielding", "opens": ["medical"], "icon": "shield",
		"says": "The layout and water jacket for a Shelter, the most shielded room."},
}
## Quarters sleep: rested this much longer than a night anywhere else.
const QUARTERS_REST := 1.5
## The Workshop's Print Shop prints this much faster.
const WORKSHOP_PRINT := 1.5

## Upgrades fitted, by base: the walker's id ("w1" is Walker 1), so they go
## with the core when it's refolded (A4). Before A4 there was one, "main".
static var fitted: Dictionary = {}
## The base you're at (the builder keeps it): "" below means this one.
static var here := "w1"

static func reset() -> void:
	fitted = {}
	here = "w1"

static func _base(base: String) -> String:
	return here if base.is_empty() else base

static func export_state() -> Dictionary:
	return {"fitted": fitted.duplicate(true)}

static func load_state(state: Dictionary) -> void:
	fitted = (state.get("fitted", {}) as Dictionary).duplicate(true)
	if fitted.has("main"):
		fitted["w1"] = fitted["main"]
		fitted.erase("main")

## Every upgrade on (a save from before the upgrades existed).
static func fit_all(base := "w1") -> void:
	fitted[base] = {}
	for id in UPGRADES: fitted[base][id] = true

static func gated() -> bool:
	return MHChapterOne.on()

static func label(kind: String) -> String:
	return str(BuildController.ZONE_TYPES.get(kind, {}).get("label", kind))

static func key_of(kind: String) -> String:
	return str(ROOMS.get(kind, {}).get("key", ""))

static func key_label(kind: String) -> String:
	var id := key_of(kind)
	return "" if id.is_empty() else MHChapterOne.label(id)

# ---------- upgrades ----------

## The upgrade that opens a room type ("" when none is needed).
static func upgrade_for(kind: String) -> String:
	for id in UPGRADES:
		if (UPGRADES[id].opens as Array).has(kind): return str(id)
	return ""

static func is_fitted(id: String, base := "") -> bool:
	return bool((fitted.get(_base(base), {}) as Dictionary).get(id, false))

static func plan_known(id: String) -> bool:
	return MHChapterOne.plan_known(str(UPGRADES[id].plan))

static func cost(id: String) -> float:
	return float(MHChapterOne.plan(str(UPGRADES[id].plan)).get("feedstock_kg", 100.0))

## Everything fitting it takes: {feedstock_kg, metal_kg, salvage_kg} (A5).
static func full_cost(id: String) -> Dictionary:
	var out := MHMaterials.plan_mix(str(UPGRADES[id].plan))
	out["feedstock_kg"] = cost(id)
	return out

## Whether this room type is open at the base ("" if it is, or why not).
static func locked_reason(kind: String, base := "") -> String:
	if not gated(): return ""
	var up := upgrade_for(kind)
	if up.is_empty() or is_fitted(up, base): return ""
	if not plan_known(up): return "Needs the core's %s upgrade: no plan yet" % str(UPGRADES[up].label).to_lower()
	return "Needs the core's %s upgrade: fit it at the core's rack" % str(UPGRADES[up].label).to_lower()

## Why an upgrade can't be fitted now ("" when it can).
static func fit_reason(id: String, base := "") -> String:
	if is_fitted(id, base): return "Fitted"
	if not plan_known(id): return "No plan yet"
	return MHMaterials.short_of(full_cost(id))

## Fit an upgrade at the core: pays its feedstock. True when it went on.
static func fit(id: String, base := "") -> bool:
	if not fit_reason(id, base).is_empty(): return false
	base = _base(base)
	MHChapterOne.feedstock_kg = maxf(0.0, MHChapterOne.feedstock_kg - cost(id))
	MHMaterials.pay(full_cost(id))
	if not fitted.has(base): fitted[base] = {}
	fitted[base][id] = true
	return true

## "Galley and Greenhouse".
static func opens_text(id: String) -> String:
	var names: Array = (UPGRADES[id].opens as Array).map(func(k): return label(str(k)))
	return " and ".join(names)

# ---------- key pieces ----------

## Free key pieces the rooms brought (zones placed with "key_piece"), by id.
static func key_grants(id: String, builder: Object) -> int:
	if builder == null: return 0
	var count := 0
	for zone in builder.get("zones"):
		if bool(zone.get("key_piece", false)) and key_of(str(zone.get("kind", ""))) == id: count += 1
	return count

## Whether the room's key piece is inside it: its bonus works.
static func key_inside(builder: Object, zone: Dictionary) -> bool:
	var id := key_of(str(zone.get("kind", "")))
	if id.is_empty() or builder == null: return false
	for item in builder.get("placed_interior"):
		if str(item.get("id", "")) != id: continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if is_same(builder.call("_zone_at_point", Vector2(at.x, at.z)), zone): return true
	return false

## The room the player is in has its bonus working: the kind, or "".
static func bonus_room_at(builder: Object, point: Vector3) -> String:
	if builder == null or not bool(builder.call("is_inside", point)): return ""
	var zone: Dictionary = builder.call("_zone_at_point", Vector2(point.x, point.z))
	if zone.is_empty() or not ROOMS.has(str(zone.get("kind", ""))): return ""
	return str(zone.kind) if key_inside(builder, zone) else ""
