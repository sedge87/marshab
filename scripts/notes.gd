extends Node

## Notes: your inner voice (docs/master-design.md §5, "Steer, don't tell").
## The slate's Notes app is a notebook page of your own thoughts: three to
## five at a time, first person and hedged, never a quest list (no ticks,
## counts or markers). A thought changes when you act, even out of order, and
## an answered one leaves the page and becomes a line in your journal, often
## raising the next question. Written, never spoken.
##
## The words live in data/notes.json. The game moves thoughts with think()
## and settles them with answer(); a few are watched here (the blue sunset,
## night and dawn, a cold cabin).

const DATA_PATH := "res://data/notes.json"
const MOST := 5            # open thoughts on the page at once
const CHECK := 1.0         # seconds between looks round

signal changed

var world: Node
## Open thoughts, oldest first: [{id, stage, fills, sol}].
var open: Array = []
## Settled thoughts: id -> sol.
var settled: Dictionary = {}
var _data: Dictionary = {}
var _check := 0.0
var _started := false

func _ready() -> void:
	add_to_group("notes")

func setup(target_world: Node, state: Dictionary, new_game: bool) -> void:
	world = target_world
	load_state(state)
	_started = not new_game

func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data = parsed
	return _data

func _spec(id: String) -> Dictionary:
	return (data().get("thoughts", {}) as Dictionary).get(id, {})

# ---------- thinking ----------

## A thought comes to mind, or an open one moves on to `stage`. Once settled,
## a thought doesn't come back. True when the page changed.
func think(id: String, stage := "start", fills := {}) -> bool:
	if settled.has(id) or _spec(id).is_empty(): return false
	if not ((_spec(id).get("stages", {}) as Dictionary).has(stage)): return false
	var at := _find(id)
	if at >= 0:
		var thought: Dictionary = open[at]
		if str(thought.stage) == stage: return false
		thought.stage = stage
		(thought.fills as Dictionary).merge(fills, true)
	else:
		open.append({"id": id, "stage": stage, "fills": fills.duplicate(), "sol": _sol()})
		while open.size() > MOST: open.pop_front()   # the oldest drifts out of mind
	_post(id)
	changed.emit()
	return true

## A thought is answered: off the page and into the journal, and its next
## questions come to mind. Works even if it was never open (out of order).
func answer(id: String, fills := {}) -> bool:
	if settled.has(id) or _spec(id).is_empty(): return false
	var at := _find(id)
	var all_fills := fills.duplicate()
	if at >= 0:
		all_fills.merge(open[at].fills)
		open.remove_at(at)
	settled[id] = _sol()
	var line := _fill(str(_spec(id).get("journal", "")), all_fills)
	if not line.is_empty(): MHJournal.note(_sol(), line)
	for next in _spec(id).get("next", []): think(str(next))
	changed.emit()
	return true

func is_open(id: String) -> bool:
	return _find(id) >= 0

func is_settled(id: String) -> bool:
	return settled.has(id)

func stage(id: String) -> String:
	var at := _find(id)
	return str(open[at].stage) if at >= 0 else ""

## The page: [{id, text, sol}], newest first.
func thoughts() -> Array:
	var out: Array = []
	for thought in open:
		out.push_front({"id": thought.id, "text": text_of(thought), "sol": thought.sol})
	return out

func text_of(thought: Dictionary) -> String:
	var stages: Dictionary = _spec(str(thought.id)).get("stages", {})
	return _fill(str(stages.get(str(thought.stage), "")), thought.fills)

func _find(id: String) -> int:
	for i in open.size():
		if str(open[i].id) == id: return i
	return -1

static func _fill(text: String, fills: Dictionary) -> String:
	for key in fills: text = text.replace("{%s}" % key, str(fills[key]))
	return text

## One line under the compass, in your own words; the slate's Notes gets a dot.
func _post(id: String) -> void:
	var at := _find(id)
	if at >= 0: MHNotices.post("info", "Notes", text_of(open[at]), "notes")

func _sol() -> int:
	var builder: Variant = world.get("builder") if world != null else null
	if builder != null and builder.has_method("simulation"): return floori(float(builder.simulation().hours_run) / 24.0) + 1
	return 1

# ---------- what's watched here ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null or get_tree().paused: return
	_check = CHECK
	if not _started:
		_started = true
		think("air")
		think("sunset")
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var hour := MHGame.sol_hour
	var outside := not _indoors()
	# The blue sunset: outside as the sun goes down.
	if outside and hour >= sunset - .6 and hour <= sunset + .25: answer("sunset")
	# Night one's question: dark, then dawn.
	var dark := hour >= sunset + .5 or hour < sunrise
	if dark and is_open("power"): think("power", "night")
	if is_open("power") and stage("power") == "night" and hour >= sunrise and hour < sunrise + 2.0:
		answer("power", {"how": _night_summary()})
	# A cold cabin while you're in it.
	var cabin: Node = world.get("cabin_life")
	if cabin != null and cabin.running() and is_open("air") and stage("air") == "start" and float(cabin.core.tank_o2_kg) < float(cabin.core.tank_cap) * .3:
		think("air", "low")
	if cabin != null and cabin.running() and cabin.player_inside():
		var temp := float(cabin.core.temp_c)
		if temp < 10.0: think("cold")
		elif temp > 15.0 and is_open("cold"): answer("cold")

func _indoors() -> bool:
	var at: Vector3 = (world.player as Node3D).global_position
	var builder: Variant = world.get("builder")
	if builder != null and builder.is_inside(at): return true
	var lander: Variant = world.get("lander")
	if lander != null and lander.has_method("cabin_contains") and lander.cabin_contains(at): return true
	var rover: Variant = world.get("crew_rover")
	if rover != null and rover.has_method("cabin_contains") and rover.cabin_contains(at): return true
	return false

func _night_summary() -> String:
	var cabin: Node = world.get("cabin_life")
	if cabin == null: return ""
	var temp := float(cabin.core.temp_c)
	if not cabin.core.powered(): return "The battery gave out in the small hours. Cold, but here."
	if temp < 8.0: return "Kept the battery, lost the warmth. %d degrees in the cabin at dawn." % roundi(temp)
	return "Warm enough, and the battery held."

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"open": open.duplicate(true), "settled": settled.duplicate()}

func load_state(state: Dictionary) -> void:
	open = []
	for thought in state.get("open", []):
		open.append({"id": str(thought.id), "stage": str(thought.get("stage", "start")), "fills": (thought.get("fills", {}) as Dictionary).duplicate(), "sol": int(thought.get("sol", 1))})
	settled = {}
	for id in (state.get("settled", {}) as Dictionary): settled[str(id)] = int(state.settled[id])
