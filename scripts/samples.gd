class_name MHSamples
extends RefCounted

## Samples, the lab and discoveries (core-loop step 5, docs/samples-lab-journal.md).
## You take regolith, rock and ice-core samples outside into a six-slot case,
## unload them at base, and analyse them at a Science Workbench (lab only: a
## workshop bench would contaminate them). A first result is a lead; matching
## results from different spots confirm a discovery. Earth replies after the
## light delay, and the reply brings the unlock.
##
## Runs with chapter one's rules (MHChapterOne.on()); otherwise everything here
## is inert and bonus() is 1.

const MHResources := preload("res://scripts/mh_resources.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const DATA_PATH := "res://data/discoveries.json"
const CASE_SLOTS := 6
## Evidence only counts from a new spot this far from the earlier ones (m).
const SPREAD_M := 20.0
## Game hours an analysis takes, by kind (a Microscope Station in the lab
## makes rock and regolith this much faster).
const ANALYSIS_HOURS := {"regolith": 3.0, "rock": 4.0, "ice_core": 6.0}
const MICROSCOPE_SPEED := 1.0 / .6
## Earth's reply arrives this many game hours after a discovery (light delay
## plus a team reading it).
const REPLY_HOURS := .5
const KIND_LABELS := {"regolith": "regolith", "rock": "rock", "ice_core": "ice core"}
## The Lab's chain (A5, docs/rooms-and-equipment.md "Workflows"): a find
## goes saw, then microscope, then spectrometer, in the workbench's room.
## Each discovery needs the stations it lists ("stations" in discoveries.json,
## else STATION_NEEDS by kind); with fewer you get a partial read, and the
## first one short of a station brings Tupou's plan for it.
const CHAIN := ["rock_saw", "microscope_station", "spectrometer"]
const STATION_NEEDS := {"rock": ["rock_saw", "microscope_station"], "regolith": ["microscope_station"], "ice_core": ["rock_saw", "microscope_station"]}
## The steps a sample of each kind goes through by hand.
const KIND_STEPS := {"rock": ["rock_saw", "microscope_station", "spectrometer"], "regolith": ["microscope_station", "spectrometer"], "ice_core": ["rock_saw", "microscope_station", "spectrometer"]}
const STEP_WORDS := {
	"rock_saw": {"prompt": "Cut the sample", "title": "Cut open", "text": "The saw takes the weathered skin off: a clean, fresh face."},
	"microscope_station": {"prompt": "Look at the grains", "title": "Under the microscope", "text": "The grains up close: their shape, their size, what's holding them together."},
	"spectrometer": {"prompt": "Read the spectrum", "title": "The spectrum", "text": "The peaks come up one by one. Each mineral has its own."},
}

static var case_items: Array = []        # samples carried: records (see _record)
static var store: Array = []             # samples at base, analysed or not
static var next_id := 1
static var jobs: Dictionary = {}         # bench placement id -> {sample, hours_left, hours}
static var evidence: Dictionary = {}     # discovery id -> [{x, z, sample}]
static var leads: Dictionary = {}        # discovery id -> sim hours first seen
static var found: Dictionary = {}        # discovery id -> {hours, sol, sample, replied}
static var replies: Array = []           # [{id, due}]
static var chipped: Dictionary = {}      # "x,z" of rocks already chipped -> true
static var readings: Dictionary = {}     # reading discovery id -> {"day": true, "night": true}
## A5: kinds of find done by hand once (hands_key -> true): after that the
## workbench runs them by itself. `hand` is the sample being walked round
## the stations now: {sample, bench, done: [station ids]}.
static var learned: Dictionary = {}
static var hand: Dictionary = {}
## Science for the four goals starts once you're settled into building: the
## General Module down and one thing of your own built (mars_world latches
## it; playtest 8 Nov). Before that, no readings and no discoveries.
static var science_open := false
static var _data: Dictionary = {}

static func on() -> bool:
	return MHChapterOne.new_rules()

static func reset() -> void:
	case_items = []; store = []; next_id = 1; jobs = {}; evidence = {}; leads = {}
	found = {}; replies = []; chipped = {}; readings = {}; science_open = false
	learned = {}; hand = {}

static func export_state() -> Dictionary:
	return {"case": case_items.duplicate(true), "store": store.duplicate(true), "next_id": next_id, "jobs": jobs.duplicate(true),
		"evidence": evidence.duplicate(true), "leads": leads.duplicate(), "found": found.duplicate(true), "replies": replies.duplicate(true),
		"chipped": chipped.duplicate(), "readings": readings.duplicate(true), "science_open": science_open,
		"learned": learned.duplicate(), "hand": hand.duplicate(true)}

static func load_state(state: Dictionary) -> void:
	reset()
	case_items = (state.get("case", []) as Array).duplicate(true)
	store = (state.get("store", []) as Array).duplicate(true)
	next_id = int(state.get("next_id", 1))
	jobs = (state.get("jobs", {}) as Dictionary).duplicate(true)
	evidence = (state.get("evidence", {}) as Dictionary).duplicate(true)
	leads = (state.get("leads", {}) as Dictionary).duplicate()
	found = (state.get("found", {}) as Dictionary).duplicate(true)
	replies = (state.get("replies", []) as Array).duplicate(true)
	chipped = (state.get("chipped", {}) as Dictionary).duplicate()
	readings = (state.get("readings", {}) as Dictionary).duplicate(true)
	# Older saves that already have science keep it.
	science_open = bool(state.get("science_open", not found.is_empty() or not leads.is_empty()))
	# Saved before A5's chain: every kind they've analysed counts as learned.
	learned = (state.get("learned", {}) as Dictionary).duplicate()
	if not state.has("learned"):
		for record in store:
			if bool(record.get("analysed", false)): learned[hands_key(record)] = true
	hand = (state.get("hand", {}) as Dictionary).duplicate(true)

# ---------- data ----------

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data = parsed
	return _data

static func discoveries() -> Array:
	return data().get("discoveries", [])

static func discovery(id: String) -> Dictionary:
	for entry in discoveries():
		if str(entry.id) == id: return entry
	return {}

static func section_label(section: String) -> String:
	return str((data().get("sections", {}) as Dictionary).get(section, {}).get("label", section.capitalize()))

static func rock_label(rock: String) -> String:
	return str((data().get("rock_types", {}) as Dictionary).get(rock, {}).get("label", rock.capitalize()))

## What the ground is at a position (site metres): the cave's kind inside a
## cave (lava_tube, cave, ice_cave), else the region's geology unit there
## (MHSiteTerrain.geology_unit); empty off region sites.
static func unit_at(position: Vector3) -> String:
	var cave := MHCaves.cave_at(position)
	if not cave.is_empty(): return str(cave.kind)
	return MHSiteTerrain.geology_unit(position.x, position.z)

## The cave find within find_reach of a position inside a cave ("" if none):
## region.json's caves[].finds, e.g. "mineral_crust".
static func find_near(position: Vector3) -> String:
	var cave := MHCaves.cave_at(position)
	if cave.is_empty(): return ""
	var reach := float(data().get("find_reach", 15.0))
	var points: PackedVector3Array = cave.points
	for find in cave.finds:
		var at := points[clampi(int(find.point), 0, points.size() - 1)]
		if Vector2(at.x, at.z).distance_to(Vector2(position.x, position.z)) < reach: return str(find.id)
	return ""

## The rock type of a rock at a position: a cave find's own rock near its
## spot, else weighted by the ground it sits on (unit_rocks), or by the site
## on the old single-site maps. The same rock always gives the same answer.
static func rock_at(position: Vector3) -> String:
	var find := find_near(position)
	if (data().get("rock_types", {}) as Dictionary).has(find): return find
	var by_unit: Dictionary = data().get("unit_rocks", {})
	var by_site: Dictionary = data().get("site_rocks", {})
	var weights: Dictionary = by_unit.get(unit_at(position), by_site.get(MHGame.site_id, by_site.get("plains", {"basalt": 1})))
	var total := 0.0
	for key in weights: total += float(weights[key])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [MHGame.site_id, roundi(position.x * 2.0), roundi(position.z * 2.0)])
	var pick := rng.randf() * total
	for key in weights:
		pick -= float(weights[key])
		if pick <= 0.0: return str(key)
	return str(weights.keys().back())

## Where a unit is, in words ("the delta").
static func unit_label(unit: String) -> String:
	return str((data().get("unit_labels", {}) as Dictionary).get(unit, "the site" if unit.is_empty() else unit.replace("_", " ")))

## "Sol 3 · the delta · 420 m north-east of the base"
static func where_line(record: Dictionary) -> String:
	var zone := MHSiteTerrain.region_zone()
	var at := Vector2(float(record.get("x", 0.0)), float(record.get("z", 0.0)))
	if record.has("rx") and not zone.is_empty(): at = Vector2(float(record.rx) - float(zone.centre[0]), float(record.rz) - float(zone.centre[1]))
	var place := "at the base" if at.length() < 60.0 else "%s %s of the base" % [_distance(at.length()), _compass(at)]
	return "Sol %d · %s · %s" % [int(record.get("sol", 1)), unit_label(str(record.get("unit", ""))), place]

static func _distance(metres: float) -> String:
	return "%d m" % (roundi(metres / 10.0) * 10) if metres < 1000.0 else "%.1f km" % (metres / 1000.0)

## Compass words for a site offset (x east, z south).
static func _compass(offset: Vector2) -> String:
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(offset.angle() / (TAU / 8.0)), 8)]

static func rock_key(point: Vector2) -> String:
	return "%d,%d" % [roundi(point.x * 2.0), roundi(point.y * 2.0)]

# ---------- taking and carrying ----------

static func case_full() -> bool:
	return case_items.size() >= CASE_SLOTS

## Bag a sample into the case. Returns a message (and the record under "sample").
static func take(kind: String, point: Vector2, hours: float, extra := {}) -> Dictionary:
	if case_full(): return {"id": "case_full", "title": "The sample case is full", "text": "Head home and unload it, or hold I to leave one behind.", "tone": "warn"}
	var record := _record(kind, point, hours, extra)
	case_items.append(record)
	var what := sample_label(record)
	return {"id": "sample", "title": "Sample bagged: %s" % what, "text": "Labelled with its place and sol. %s" % case_line(), "tone": "info", "sample": record}

## A sample's record: {id, kind, site, x, z (site metres), rx, rz (region
## metres, so it stays put whichever base it's seen from), unit (the ground
## it came from, unit_at), in_cave, sol, hours, analysed, findings} plus extra
## (rock, depth_m, purity, name, and unit and in_cave from a cave).
static func _record(kind: String, point: Vector2, hours: float, extra: Dictionary) -> Dictionary:
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1])) if not zone.is_empty() else Vector2.ZERO
	var record := {"id": next_id, "kind": kind, "site": MHGame.site_id, "x": snappedf(point.x, .1), "z": snappedf(point.y, .1),
		"rx": snappedf(point.x + origin.x, .1), "rz": snappedf(point.y + origin.y, .1),
		"unit": MHSiteTerrain.geology_unit(point.x, point.y), "in_cave": false,
		"sol": floori(hours / 24.0) + 1, "hours": hours, "analysed": false, "findings": []}
	record.merge(extra, true)
	next_id += 1
	return record

static func sample_label(record: Dictionary) -> String:
	match str(record.kind):
		"rock": return rock_label(str(record.get("rock", "basalt"))) if bool(record.get("analysed", false)) else "rock chip"
		"ice_core": return "ice core, %.1f m" % float(record.get("depth_m", 0.0))
	return "regolith"

## "Case: 2 regolith, 1 rock · 3 free"
static func case_line() -> String:
	var counts := {}
	for record in case_items: counts[str(record.kind)] = int(counts.get(str(record.kind), 0)) + 1
	var bits: Array = []
	for kind in ["regolith", "rock", "ice_core"]:
		if counts.has(kind): bits.append("%d %s" % [counts[kind], KIND_LABELS[kind] + ("s" if int(counts[kind]) > 1 and kind != "regolith" else "")])
	var free := CASE_SLOTS - case_items.size()
	return "Case: %s · %d free" % [", ".join(bits) if not bits.is_empty() else "empty", free]

## Leave the last sample behind (it's lost).
static func drop_last() -> Dictionary:
	if case_items.is_empty(): return {}
	var record: Dictionary = case_items.pop_back()
	return {"id": "dropped", "title": "Left behind: %s" % sample_label(record), "text": case_line(), "tone": "info"}

## Empty the case into the base's store. Returns how many.
static func unload() -> int:
	var count := case_items.size()
	store.append_array(case_items)
	case_items = []
	return count

## Something GAR-Y brings in goes straight to the store.
static func add_to_store(kind: String, point: Vector2, hours: float, extra := {}) -> Dictionary:
	var record := _record(kind, point, hours, extra)
	record["by"] = "gar_y"
	store.append(record)
	return record

## Samples to analyse: not yet, or only partly read (they can go again).
static func waiting() -> Array:
	return store.filter(func(r): return (not bool(r.get("analysed", false)) or is_partial(r)) and not _in_job(int(r.id)) and int(hand.get("sample", -1)) != int(r.id))

static func archive() -> Array:
	return store.filter(func(r): return bool(r.get("analysed", false)))

static func is_partial(record: Dictionary) -> bool:
	return not (record.get("partial", []) as Array).is_empty()

static func sample(id: int) -> Dictionary:
	for record in store:
		if int(record.id) == id: return record
	return {}

static func _in_job(id: int) -> bool:
	for key in jobs:
		if int(jobs[key].sample) == id: return true
	return false

# ---------- the lab ----------

static func analysis_hours(kind: String, microscope: bool) -> float:
	var hours := float(ANALYSIS_HOURS.get(kind, 4.0))
	if microscope and kind != "ice_core": hours /= MICROSCOPE_SPEED
	if str(MHGame.rule("lab")) == "fast": hours *= .5
	return hours

static func start_job(bench: String, sample_id: int, microscope: bool) -> String:
	if jobs.has(bench): return "This bench is busy."
	var record := sample(sample_id)
	if record.is_empty() or (bool(record.get("analysed", false)) and not is_partial(record)): return "Pick a sample to analyse."
	if needs_hands(record): return "A new kind of sample: do this one by hand first."
	var hours := analysis_hours(str(record.kind), microscope)
	jobs[bench] = {"sample": sample_id, "hours_left": hours, "hours": hours}
	return ""

static func cancel_job(bench: String) -> void:
	jobs.erase(bench)

## The lab's benches: Science Workbenches placed, with the chain's stations
## in their room. [{key, microscope, stations: [ids in chain order]}]
static func benches(builder: Object) -> Array:
	var out: Array = []
	var placed: Array = builder.get("placed_interior")
	for item in placed:
		if str(item.get("id", "")) != "science_workbench": continue
		var room := Vector2i(item.get("zone_cell", Vector2i.ZERO))
		var here := {}
		for other in placed:
			var id := str(other.get("id", ""))
			if id in CHAIN and _same_room(builder, room, Vector2i(other.get("zone_cell", Vector2i.ZERO))): here[id] = true
		out.append({"key": str(item.placement_id), "microscope": here.has("microscope_station"), "stations": CHAIN.filter(func(s): return here.has(s))})
	return out

static func bench_stations(builder: Object, bench: String) -> Array:
	for entry in benches(builder):
		if str(entry.key) == bench: return entry.stations
	return []

static func station_label(id: String) -> String:
	return str(EquipmentCatalog.get_entry(id).get("label", id.capitalize()))

# ---------- the chain, and hands-on the first time ----------

## Which kind of find a sample is, for "done by hand once": its kind, and
## its rock for rocks (and cave ice apart from ground ice).
static func hands_key(record: Dictionary) -> String:
	match str(record.get("kind", "")):
		"rock": return "rock:" + str(record.get("rock", "basalt"))
		"ice_core": return "ice_core:cave" if bool(record.get("in_cave", false)) else "ice_core"
	return str(record.get("kind", ""))

static func needs_hands(record: Dictionary) -> bool:
	return on() and not learned.has(hands_key(record))

## The stations a discovery needs.
static func needs_for(id: String) -> Array:
	var entry := discovery(id)
	if entry.has("stations"): return entry.stations
	var ways: Array = entry.get("match", [entry])
	return STATION_NEEDS.get(str((ways[0] as Dictionary).get("kind", entry.get("kind", "rock"))), [])

## What the stations `have` show of a sample: {findings, missing}. A find
## needing a station that isn't there is a partial read, with what it needed.
static func read(record: Dictionary, have: Array) -> Dictionary:
	var shown: Array = []
	var missing: Array = []
	for id in findings_for(record):
		var short: Array = needs_for(str(id)).filter(func(s): return not have.has(s))
		if short.is_empty(): shown.append(id)
		for s in short:
			if not missing.has(s): missing.append(s)
	missing.sort_custom(func(a, b): return CHAIN.find(a) < CHAIN.find(b))
	return {"findings": shown, "missing": missing}

## Start walking a sample round the stations (from the Lab screen).
static func start_hand(bench: String, sample_id: int) -> String:
	if not hand.is_empty(): return "You're already working one by hand."
	var record := sample(sample_id)
	if record.is_empty(): return "Pick a sample."
	hand = {"sample": sample_id, "bench": bench, "done": []}
	return ""

static func hand_record() -> Dictionary:
	return sample(int(hand.get("sample", -1))) if not hand.is_empty() else {}

## The steps this sample goes through by hand, in order.
static func hand_steps() -> Array:
	return KIND_STEPS.get(str(hand_record().get("kind", "rock")), [])

## What E does at a chain station now ("" for nothing).
static func step_action(station: String) -> String:
	if hand.is_empty() or not hand_steps().has(station): return ""
	if (hand.done as Array).has(station): return "Done: %s" % str(STEP_WORDS[station].title).to_lower()
	# In chain order: an earlier step still waiting (at a station that's there) comes first.
	return str(STEP_WORDS[station].prompt)

## E at a chain station with the sample in hand. `have` is what's in the
## bench's room. Returns messages.
static func do_step(station: String, have: Array) -> Array:
	if step_action(station).is_empty() or (hand.done as Array).has(station): return []
	for earlier in hand_steps():
		if earlier == station: break
		if have.has(earlier) and not (hand.done as Array).has(earlier):
			return [{"id": "step", "title": "%s first" % station_label(earlier), "text": "The chain runs saw, then microscope, then spectrometer.", "tone": "warn"}]
	(hand.done as Array).append(station)
	var words: Dictionary = STEP_WORDS[station]
	var left: Array = hand_steps().filter(func(s): return have.has(s) and not (hand.done as Array).has(s))
	var next := ("Next: %s." % station_label(str(left[0]))) if not left.is_empty() else "Back to the workbench to put it together."
	return [{"id": "step", "title": str(words.title), "text": "%s %s" % [str(words.text), next], "tone": "info"}]

## E at the workbench with the sample in hand: the read, at once.
static func finish_hand(now: float) -> Array:
	var record := hand_record()
	var done: Array = hand.get("done", [])
	hand = {}
	if record.is_empty(): return []
	learned[hands_key(record)] = true
	var out := finish_analysis(record, now, done)
	out.append({"id": "learned", "title": "Done by hand once", "text": "Next time a sample like this comes in, the workbench runs it through the stations by itself.", "tone": "info"})
	return out

static func drop_hand() -> void:
	hand = {}

static func _same_room(builder: Object, a: Vector2i, b: Vector2i) -> bool:
	for zone in builder.get("zones"):
		var cells: Array = zone.get("cells", [])
		if cells.has(a): return cells.has(b)
	return a == b

# ---------- findings and evidence ----------

## What an analysis shows: discovery ids.
static func findings_for(record: Dictionary) -> Array:
	var out: Array = []
	for entry in discoveries():
		if entry.has("field") or str(entry.get("kind", "")) == "reading": continue
		var ways: Array = entry.get("match", [entry])
		if not ways.any(func(way: Dictionary) -> bool: return _matches(way, record)): continue
		if str(entry.id) == "soil_water" and not _bound_water(record): continue
		out.append(str(entry.id))
	return out

## Whether a sample fits one way of showing a discovery: its kind, and its
## rock, unit, in_cave and depth where the way names them.
static func _matches(way: Dictionary, record: Dictionary) -> bool:
	if str(way.get("kind", "")) != str(record.kind): return false
	if way.has("rock") and str(way.rock) != str(record.get("rock", "")): return false
	if way.has("unit") and str(way.unit) != str(record.get("unit", "")): return false
	if way.has("in_cave") and bool(way.in_cave) != bool(record.get("in_cave", false)): return false
	if way.has("min_depth") and float(record.get("depth_m", 0.0)) < float(way.min_depth): return false
	return true

## Whether a regolith sample's ground holds bound water (unit_regolith; the
## old maps by site).
static func _bound_water(record: Dictionary) -> bool:
	var by_unit: Array = (data().get("unit_regolith", {}) as Dictionary).get(str(record.get("unit", "")), [])
	var by_site: Array = (data().get("site_regolith", {}) as Dictionary).get(str(record.get("site", "")), [])
	return by_unit.has("soil_water") or by_site.has("soil_water")

## The suit logs its readings at a cave's reading spot (cave_climate), or out
## in the open air (mars_air): one by day and one by night confirm it. Returns messages.
static func log_reading(id: String, daylight: bool, hours: float) -> Array:
	if not science_open or found.has(id) or discovery(id).is_empty(): return []
	var seen: Dictionary = readings.get(id, {})
	var when := "day" if daylight else "night"
	if seen.has(when): return []
	seen[when] = true
	readings[id] = seen
	var entry := discovery(id)
	if seen.size() >= int(entry.get("need", 2)): return discover(id, hours)
	leads[id] = hours
	var text := str(entry.get("reading_text", "The suit logged the temperature and radiation here. Come back at %s to compare."))
	return [{"id": "lead", "title": "Lead: %s" % str(entry.get("lead", entry.label)), "text": text % ("night" if daylight else "midday"), "tone": "info"}]

## A finished analysis with the stations `have` (null: every station):
## findings onto the record, then evidence; a partial read names what it
## needed, and the first time short of a station brings its plan. Messages.
static func finish_analysis(record: Dictionary, hours: float, have = null) -> Array:
	var out: Array = []
	var before: Array = record.get("findings", []) if bool(record.get("analysed", false)) else []
	var result := read(record, CHAIN if have == null else have)
	record.analysed = true
	record.findings = result.findings
	record.partial = result.missing
	var names: Array = []
	for id in record.findings:
		if not before.has(id): names.append(str(discovery(id).get("label", id)))
	var text := ("Found: %s." % ", ".join(names)) if not names.is_empty() else "Nothing new in this one."
	if not (result.missing as Array).is_empty():
		var need: Array = (result.missing as Array).map(func(s): return station_label(str(s)).to_lower())
		text += " And something more: it's there, but I can't tell what. It needs a %s." % " and a ".join(need)
	out.append({"id": "partial" if not (result.missing as Array).is_empty() else "analysed", "title": ("Partial read: %s" if not (result.missing as Array).is_empty() else "Analysed: %s") % sample_label(record), "text": text, "tone": "info"})
	for id in record.findings:
		if not before.has(id): out.append_array(_add_evidence(str(id), record, hours))
	for s in result.missing:
		for plan in MHChapterOne.learn_after("partial:" + str(s)): out.append(MHChapterOne._plan_message(str(plan)))
	return out

static func _add_evidence(id: String, record: Dictionary, hours: float) -> Array:
	if found.has(id): return []
	var entry := discovery(id)
	var points: Array = evidence.get(id, [])
	var here := Vector2(float(record.x), float(record.z))
	for point in points:
		if Vector2(float(point.x), float(point.z)).distance_to(here) < SPREAD_M:
			return [{"id": "same_spot", "title": "%s: it agrees" % str(entry.get("lead", entry.label)), "text": "But it's from the same spot as before. A sample from somewhere else would confirm it.", "tone": "info"}]
	points.append({"x": here.x, "z": here.y, "sample": int(record.id)})
	evidence[id] = points
	var need := int(entry.get("need", 1))
	if points.size() >= need: return discover(id, hours, int(record.id))
	if points.size() == 1:
		leads[id] = hours
		return [{"id": "lead", "title": "Lead: %s" % str(entry.get("lead", entry.label)), "text": "%d more matching sample%s from other spots would confirm it." % [need - 1, "" if need - 1 == 1 else "s"], "tone": "info"}]
	return [{"id": "evidence", "title": "More evidence: %s" % str(entry.get("lead", entry.label)), "text": "%d of %d samples agree. One more from another spot." % [points.size(), need], "tone": "info"}]

static func discover(id: String, hours: float, sample_id := -1) -> Array:
	if found.has(id): return []
	var entry := discovery(id)
	if entry.is_empty(): return []
	found[id] = {"hours": hours, "sol": floori(hours / 24.0) + 1, "sample": sample_id, "replied": false}
	leads.erase(id)
	replies.append({"id": id, "due": hours + REPLY_HOURS})
	return [{"id": "discovery", "title": "Discovery: %s" % str(entry.label), "text": "%s Logged under %s on the terminal." % [str(entry.get("text", "")), section_label(str(entry.section))], "tone": "valid", "discovery": id}]

# ---------- each tick ----------

## Called by the world with the sim hours passed. Returns messages.
static func tick(hours: float, builder: Object) -> Array:
	var out: Array = []
	if not on() or builder == null: return out
	var sim: Object = builder.call("simulation")
	var now := float(sim.get("hours_run"))
	# Chapter one's steps are field discoveries (once science is open).
	for entry in (discoveries() if science_open else []):
		if entry.has("field") and MHChapterOne.steps.has(str(entry.field)) and not found.has(str(entry.id)):
			out.append_array(discover(str(entry.id), now))
	# The lab's jobs run on power.
	var last: Dictionary = sim.get("last")
	var powered := MHGame.debug_free_power or float(last.get("generation_kw", 0.0)) > 0.0 or float(sim.get("battery_kwh")) > .5
	if powered and hours > 0.0:
		var live := {}
		for bench in benches(builder): live[str(bench.key)] = true
		for key in jobs.keys():
			if not live.has(key): continue   # its bench was removed: the job waits
			jobs[key].hours_left = float(jobs[key].hours_left) - hours
			if float(jobs[key].hours_left) <= 0.0:
				var record := sample(int(jobs[key].sample))
				jobs.erase(key)
				if not record.is_empty(): out.append_array(finish_analysis(record, now, bench_stations(builder, str(key))))
	# Earth's replies.
	for reply in replies.duplicate():
		if now < float(reply.due): continue
		replies.erase(reply)
		var id := str(reply.id)
		if found.has(id): found[id].replied = true
		var entry := discovery(id)
		var plans: Array = MHChapterOne.learn_after("discovery:" + id)
		var unlocked: Array = []
		if entry.has("unlock_text"): unlocked.append(str(entry.unlock_text))
		for plan in plans: unlocked.append("Plan: %s" % MHChapterOne.label(str(plan)))
		var team := section_label(str(entry.get("section", "")))
		out.append({"id": "reply", "title": "Mission Control · %s team" % team, "text": str(entry.get("reply", "Noted.")) + ("  (%s)" % "; ".join(unlocked) if not unlocked.is_empty() else ""), "tone": "valid" if not unlocked.is_empty() else "info"})
	return out

## A sim multiplier from discoveries Earth has replied to (1 when none).
static func bonus(key: String) -> float:
	if not on(): return 1.0
	var value := 1.0
	for id in found:
		if not bool(found[id].get("replied", false)): continue
		value *= float((discovery(str(id)).get("bonus", {}) as Dictionary).get(key, 1.0))
	return value

## Counts for the terminal: {section: [found, total]}.
static func section_counts() -> Dictionary:
	var out := {}
	for entry in discoveries():
		var key := str(entry.section)
		if not out.has(key): out[key] = [0, 0]
		out[key][1] += 1
		if found.has(str(entry.id)): out[key][0] += 1
	return out
