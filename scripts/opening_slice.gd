extends Node

## The opening, version 3 (22 Nov 2026, docs/opening-slice.md §4a): touchdown
## to the first room, on the real sun, over two sols. It replaces the guided
## chapters (scripts/opening_days.gd, version 2) for new games and speaks the
## same small API the rest of the game asks of "the opening" (guided(),
## hatch_refusal(), night_caution(), bed_led(), open_goals(), ask_next(),
## quarters_built(), nights...), so it sits in the same slot:
## world.opening_days and the "opening_days" group.
##
## It runs as a list of beats. Each beat has a check worked out from the
## world (never a timer), and a call (data/radio/slice/*.txt) rung the first
## time it's reached. Beats can be done out of order: the current beat is the
## first one not yet done, so a player who opens the tools pallet first
## simply skips that bit later.

const VERSION := 3
const RADIO := preload("res://scripts/radio.gd")
const BUILD_RULES := preload("res://scripts/build_rules.gd")
const STORY_DAYS := 2

## The beats, in the order they're usually met. [id, call rung on reaching it]
const BEATS := [
	["wake", "d1_relock"],          # strapped in; Castle re-locks: the assignment
	["slate", "s1_manifest"],       # the slate's in your hands: read the manifest
	["outside", "d1_first_step"],   # helmet, hatch, the first step
	["gary_met", "s1_gary"],        # follow GAR-Y's stakes; free it from the canopy; the meeting
	["pallets", "s1_pallets"],      # the three near pallets opened (any order)
	["hitched", "s1_hitch"],        # the hitch bracket fitted to GAR-Y
	["walker_awake", "s1_walker"],  # the power module plugged into Walker 1
	["walker_fixed", "s1_seal"],    # its wheel seal found and patched
	["walker_home", "s1_dusk"],     # it's knelt by the lander; the evening call
	["slept", "s2_dawn"],           # the first night, in the lander
	["core_down", "s2_down"],       # ridden home, chosen, set down and folded
	["kit_placed", "s2_kit"],       # the fit-out kit placed by hand, the terminal too
	["quarters", "s2_quarters"],    # the first Quarters liner, planned at the terminal
	["helmet_off", "s2_quiet"],     # helmet off in the Quarters; Castle's quiet call
]

var world: Node
var version := VERSION
var nights := 0
var reached: Array = []          # beat ids whose call has been rung
var chapter := 1                 # 1 = sol 1's beats, 2 = sol 2's, 3 = done (callers read this)
var _was_asleep := false
var _check := 0.0
const CHECK_EVERY := .5

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "OpeningSlice"
	add_to_group("opening_days")
	version = int(saved.get("version", VERSION))
	nights = int(saved.get("nights", 0))
	reached = (saved.get("reached", []) as Array).duplicate()
	chapter = int(saved.get("chapter", 1))
	RADIO.opening_set = "slice"

func export_state() -> Dictionary:
	return {"version": version, "nights": nights, "reached": reached.duplicate(), "chapter": chapter}

# ---------- what the rest of the game asks ----------

func v2() -> bool:
	return true   # everything version 2 changed (no lander lock, quiet nights...) still holds

func guided() -> bool:
	return world.get("walker") != null and chapter <= STORY_DAYS

func chapter_done(n: int) -> bool:
	return day_done(n)

func day_done(day: int) -> bool:
	match day:
		1: return done("walker_home")
		2: return done("helmet_off")
	return true

## Sol 1 is lived in the lander; from sol 2 the core is home.
func in_lander_days() -> bool:
	return guided() and nights < 1

func is_night() -> bool:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var hour := MHGame.sol_hour
	return hour >= float(cycle.get("sunset_hour", 19.0)) + .5 or hour < float(cycle.get("sunrise_hour", 5.0))

## Why the lander's hatch won't open for you now, or "" (scripts/crew_lander.gd).
func hatch_refusal() -> String:
	var lander: Node = world.get("lander")
	var me: Node3D = world.get("player")
	if lander == null or me == null or not bool(lander.cabin_contains(me.global_position)): return ""
	if not done("outside") and str(world.get("_intro_stage")) == "inside":
		var pda: Node = world.get("pda")
		if pda != null and not bool(pda.received): return "My slate's in its clip by the seat. I'm not going out there without it."
		var suit: Node = world.get("suit")
		if suit != null and not bool(suit.seal_checked) and not bool(suit.helmet): return "Helmet first. K seals it."
	# Scene 5: the first night, the hatch stays shut. A person's reason, not a rule's.
	if nights < 1 and done("walker_home") and is_night():
		return "No night walks on day one. Humour me. (Castle)"
	return ""

func night_caution() -> String:
	return ""

func bed_led() -> bool:
	return guided() and nights < 1 and done("walker_home")

func quarters_built() -> bool:
	return done("quarters")

func ask_next() -> bool:
	return false   # Castle doesn't hand out next steps: the world and the manifest do

## The slate's Today page: first-person thoughts about what's open now.
func open_goals() -> Array:
	var out := []
	for beat in BEATS:
		var id := str(beat[0])
		if done(id): continue
		var text := str(GOAL_THOUGHTS.get(id, ""))
		if not text.is_empty(): out.append({"text": text, "needs": ""})
		break
	return out

const GOAL_THOUGHTS := {
	"slate": "See what came down near me. The manifest's on my slate.",
	"outside": "Get out there.",
	"gary_met": "GAR-Y's cradle is empty. Where did it go?",
	"pallets": "Open the pallets that came down nearby.",
	"hitched": "GAR-Y could tow the power module if it had its hitch.",
	"walker_awake": "Get power into Walker 1.",
	"walker_fixed": "Something on Walker 1's front axle is leaking.",
	"walker_home": "Bring Walker 1 back to the lander before dark.",
	"slept": "Sleep. Tomorrow it walks.",
	"core_down": "Ride Walker 1 and find the right spot for home.",
	"kit_placed": "Unpack the fit-out kit.",
	"quarters": "Plan a room at the terminal.",
	"helmet_off": "Somewhere to breathe without the helmet.",
}

# ---------- the beats ----------

func done(id: String) -> bool:
	match id:
		"wake":
			var wake: Node = world.get_tree().get_first_node_in_group("wake_up")
			return wake == null or not bool(wake.get("strapped"))
		"slate":
			var pda: Node = world.get("pda")
			return pda == null or bool(pda.received)
		"outside":
			var step: Node = world.get("first_step")
			return step == null or bool(step.done)
		"gary_met":
			return bool(world.get("gary_met"))
		"pallets":
			return _pallets_open()
		"walker_awake", "walker_fixed", "walker_home", "core_down":
			return _walker_past(id)
		"slept":
			return nights >= 1
		"kit_placed":
			return _kit_placed()
		"quarters":
			return _quarters()
		"helmet_off":
			return _quarters() and _helmet_off_in_quarters()
		"hitched":
			var pod: Node = world.get("lifepod")
			return pod != null and (pod.prints as Dictionary).has("hitch")
	return false

func _pallets_open() -> bool:
	var drop: Node = world.get("storm_drop")
	if drop != null and drop.pallet != null and not bool(drop.pallet.opened): return false
	var field: Node = world.get("drop_field")
	if field != null:
		for kind in ["power", "tools"]:
			if field.sites.has(kind) and not bool(field.sites[kind].pallet.opened): return false
	return true

## Walker 1's state machine (scripts/walker.gd) against the beat.
func _walker_past(id: String) -> bool:
	var walker: Node = world.get("walker")
	if walker == null: return true
	var state := str(walker.state)
	var order := ["stalled", "coming", "walking", "ready", "travelling", "parked", "carrying", "lowering", "done"]
	var at := order.find(state)
	match id:
		"walker_awake": return at >= 1
		"walker_fixed": return at >= 2
		"walker_home": return at >= 3
		"core_down": return state == "done"
	return false

func _kit_placed() -> bool:
	return _walker_past("core_down") and BUILD_RULES.kit_left(world.get("builder")).is_empty()

func _quarters() -> bool:
	var builder: Node = world.get("builder")
	if builder == null: return true
	for z in builder.zones:
		if str(z.get("kind", "")) == "living" and str(z.get("base", "w1")) == "w1" and not bool(z.get("arriving", false)): return true
	return false

func _helmet_off_in_quarters() -> bool:
	var suit: Node = world.get("suit")
	return suit != null and not bool(suit.helmet) and str(suit.get("where")) != "outside"

# ---------- the tick ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null or get_tree().paused: return
	_check = CHECK_EVERY
	var sleep: Node = world.get("sleep")
	var asleep: bool = sleep != null and bool(sleep.get("asleep"))
	if asleep:
		_was_asleep = true
		return
	if _was_asleep:
		_was_asleep = false
		var hour := MHGame.sol_hour
		if hour < 12.0: nights += 1
	if not guided(): return
	var radio: Node = world.get("radio")
	for beat in BEATS:
		var id := str(beat[0])
		if reached.has(id): continue
		# A beat's call rings when the beat before it is done (or it's done
		# itself, out of order: then its call is a short catch-up, if any).
		var before := _beat_before(id)
		if before != "" and not done(before) and not done(id): break
		reached.append(id)
		if radio != null and radio.has_method("ring"): radio.ring(str(beat[1]))
		break
	if done("helmet_off"): chapter = STORY_DAYS + 1
	elif done("slept"): chapter = 2

func _beat_before(id: String) -> String:
	for i in BEATS.size():
		if str(BEATS[i][0]) == id: return "" if i == 0 else str(BEATS[i - 1][0])
	return ""

# ---------- the radio ----------

## The radio's up (scripts/mars_world.gd): the slice's facts and cues.
func radio_ready() -> void:
	var radio: Node = world.get("radio")
	if radio == null: return
	radio.facts["has_slate"] = func(_args: Array) -> bool: return done("slate")
	radio.facts["helmet"] = func(_args: Array) -> bool:
		var suit: Node = world.get("suit")
		return suit != null and bool(suit.helmet)
	radio.facts["gary_met"] = func(_args: Array) -> bool: return done("gary_met")
	radio.facts["morning"] = func(_args: Array) -> bool: return MHGame.sol_hour >= 5.0 and MHGame.sol_hour < 11.0
	radio.facts["indoors"] = func(_args: Array) -> bool:
		var suit: Node = world.get("suit")
		return suit != null and str(suit.get("where")) != "outside"
