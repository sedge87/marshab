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
## Thoughts that matter now (playtest 8 Nov): id -> the stages that press
## (empty: all of them), most pressing first. They go first on the page, get
## the notice line's amber edge and jump its queue, and are what
## remind_top() brings back to mind.
const PRESSING := [
	["power", []],
	["water", []],
	["water_low", []],
	["thirsty", []],
	["starving", []],
	["hungry", ["hungry", "starving"]],
	["bed", []],          # the opening days: after anything you need to live
]

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
		if str(thought.stage) == stage:
			(thought.fills as Dictionary).merge(fills, true)   # e.g. the ridge's direction, after a reply made it
			return false
		thought.stage = stage
		(thought.fills as Dictionary).merge(fills, true)
	else:
		open.append({"id": id, "stage": stage, "fills": fills.duplicate(), "sol": _sol()})
		while open.size() > MOST: _drift()   # the oldest drifts out of mind
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

## A thought that passes without an answer (it can come again): off the
## page, no journal line, nothing settled.
func let_go(id: String) -> void:
	var at := _find(id)
	if at < 0: return
	open.remove_at(at)
	changed.emit()

func is_open(id: String) -> bool:
	return _find(id) >= 0

func is_settled(id: String) -> bool:
	return settled.has(id)

func stage(id: String) -> String:
	var at := _find(id)
	return str(open[at].stage) if at >= 0 else ""

## The page: [{id, text, sol, pressing}], the most pressing first, then
## the rest newest first (scripts/pda_screen.gd lists them in this order).
func thoughts() -> Array:
	var out: Array = []
	for thought in ordered():
		out.append({"id": thought.id, "text": text_of(thought), "sol": thought.sol, "pressing": rank(thought) < PRESSING.size()})
	return out

## The open thoughts: what you said you'd do first (scripts/replies.gd),
## then the most pressing, then the rest newest first.
func ordered() -> Array:
	var newest: Array = open.duplicate()
	newest.reverse()
	var out: Array = newest.filter(func(t): return _focused(t))
	newest = newest.filter(func(t): return not _focused(t))
	for r in PRESSING.size():
		for thought in newest:
			if rank(thought) == r: out.append(thought)
	for thought in newest:
		if rank(thought) >= PRESSING.size(): out.append(thought)
	return out

## Where a thought stands in PRESSING (PRESSING.size() when it doesn't press).
func rank(thought: Dictionary) -> int:
	for r in PRESSING.size():
		var stages: Array = PRESSING[r][1]
		if str(thought.id) == str(PRESSING[r][0]) and (stages.is_empty() or str(thought.stage) in stages): return r
	return PRESSING.size()

func _focused(thought: Dictionary) -> bool:
	return bool((thought.fills as Dictionary).get("focus", false))

func is_pressing(id: String) -> bool:
	var at := _find(id)
	return at >= 0 and rank(open[at]) < PRESSING.size()

## Brings the most pressing open thought back to mind, once, on the notice
## line (e.g. as you step out of the lander). False when nothing presses.
func remind_top() -> bool:
	var top: Array = ordered()
	if top.is_empty() or (rank(top[0]) >= PRESSING.size() and not _focused(top[0])): return false
	_post(str(top[0].id))
	return true

## Too much on your mind: the oldest thought that isn't pressing goes.
func _drift() -> void:
	for i in open.size():
		if rank(open[i]) >= PRESSING.size() and not _focused(open[i]):
			open.remove_at(i)
			return
	open.pop_front()

func text_of(thought: Dictionary) -> String:
	var fills: Dictionary = thought.fills
	# Your own words, from a reply (scripts/replies.gd), while it's at that stage.
	if fills.has("said") and str(fills.get("said_stage", "start")) == str(thought.stage): return str(fills.said)
	var stages: Dictionary = _spec(str(thought.id)).get("stages", {})
	return _fill(str(stages.get(str(thought.stage), "")), fills)

## You answered someone and said what you'd do (scripts/replies.gd): the
## thought comes to mind in your own words and goes to the top of Notes.
func take_up(id: String, said := "", stage := "start") -> void:
	if settled.has(id) or _spec(id).is_empty(): return
	if _find(id) < 0 and (_spec(id).get("stages", {}) as Dictionary).has(stage):
		open.append({"id": id, "stage": stage, "fills": {}, "sol": _sol()})   # posted below, once
		while open.size() > MOST: _drift()
	var at := _find(id)
	if at < 0: return
	for thought in open: (thought.fills as Dictionary).erase("focus")
	var fills: Dictionary = open[at].fills
	fills["focus"] = true
	if not said.is_empty():
		fills["said"] = said
		fills["said_stage"] = str(open[at].stage)
	_post(id)
	changed.emit()

func _find(id: String) -> int:
	for i in open.size():
		if str(open[i].id) == id: return i
	return -1

static func _fill(text: String, fills: Dictionary) -> String:
	for key in fills: text = text.replace("{%s}" % key, str(fills[key]))
	return text

## Your own words on the notice line ("You think…", a pencil); a pressing
## thought has the amber edge and goes first. The slate's Notes gets a dot.
func _post(id: String) -> void:
	var at := _find(id)
	if at >= 0: MHNotices.post("info", MHNotices.YOU_THINK, text_of(open[at]), "notes", 1 if rank(open[at]) < PRESSING.size() else 0, true, {"thought": id})

func _sol() -> int:
	var builder: Variant = world.get("builder") if world != null else null
	if builder != null and builder.has_method("simulation"): return floori(float(builder.simulation().hours_run) / 24.0) + 1
	return 1

# ---------- what's watched here ----------

## Seconds after the air is settled before ARDEN raises the night.
const AFTER_AIR := 20.0
var _air_settled_for := 0.0
var _rest_offered := 0      # the sol rest was last offered (once a sol)
var _was_in_lander := false # stepping out brings the top thought back to mind

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null or get_tree().paused: return
	_check = CHECK
	if not _started:
		_started = true
		# A new game in the lander holds "air" for its beat, after the slate
		# (scripts/mars_world.gd _after_slate; opening review, 8 Nov).
		if not bool(world.get("_start_in_lander")): think("air")
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var hour := MHGame.sol_hour
	var outside := not _indoors()
	# Out of the lander's door: what you're out here for, once more.
	var lander: Variant = world.get("lander")
	var in_lander: bool = lander != null and lander.has_method("cabin_contains") and lander.cabin_contains((world.player as Node3D).global_position)
	if _was_in_lander and not in_lander: remind_top()
	_was_in_lander = in_lander
	# The blue sunset: the wish comes as the afternoon goes, not at touchdown.
	if hour >= sunset - 3.0 and hour <= sunset + .25 and not is_open("sunset") and not is_settled("sunset"): think("sunset")
	# The blue sunset: outside as the sun goes down.
	if outside and hour >= sunset - 1.0 and hour <= sunset + .25 and answer("sunset"): MHAudio.moment()
	# Night one's question: dark, then dawn.
	var dark := hour >= sunset + .5 or hour < sunrise
	if dark and is_open("power"): think("power", "night")
	if is_open("power") and stage("power") == "night" and hour >= sunrise and hour < sunrise + 2.0:
		answer("power", {"how": _night_summary()})
	# ARDEN's afternoon warning, once: a little after the air is sorted (a
	# pause, then the next worry), or by mid-afternoon. ARDEN is only the
	# habitat's voice (systems brief §10e+), so it waits until you're inside,
	# even if that's after dark.
	if not is_open("power") and not is_settled("power") and hour >= sunrise + 1.0:
		if is_settled("air"): _air_settled_for += CHECK
		var lander_cell: Node = world.get("cabin_life")
		var no_worry: bool = lander_cell != null and bool(lander_cell.core.self_sufficient)   # the lander's power cell sees out the night
		if not no_worry and not outside and (hour >= sunset - 5.0 or _air_settled_for >= AFTER_AIR):
			MHAudio.voice("cabin_battery_night")
			var replies: Node = world.get("replies")
			if replies != null: replies.offer_voice("cabin_battery_night")
			think("power")
	# A cold cabin while you're in it.
	var cabin: Node = world.get("cabin_life")
	if cabin != null and cabin.running() and not bool(cabin.core.self_sufficient) and is_open("air") and stage("air") == "start" and float(cabin.core.tank_o2_kg) < float(cabin.core.tank_cap) * .3:
		think("air", "low")
	# Rest, offered at a pause and never forced: in the cabin from dusk, once
	# a sol. It passes when you sleep, or with the morning.
	var sleep: Node = world.get("sleep")
	var asleep: bool = sleep != null and bool(sleep.get("asleep"))
	var days: Node = world.get("opening_days")
	var guided: bool = days != null and days.guided()   # the opening days have "bed" instead
	if not guided and cabin != null and cabin.player_inside() and not asleep and (hour >= sunset - 1.0 or hour < sunrise - 1.0) and _rest_offered != _sol():
		_rest_offered = _sol()
		if think("rest") and MHGame.tutorial_mode != "off" and world.get("explore_hud") != null:
			world.explore_hud.show_equipment_note("Rest", "Sleep until dawn? Look at a landing seat and press Z. Or don't: the night is yours too.")
	if is_open("rest") and (asleep or (hour >= sunrise and hour < sunset - 1.0)): let_go("rest")
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
