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
	["kit_placed", "s2_kit"],       # the fit-out kit placed with B, the terminal too
	["quarters", "s2_quarters"],    # the first Quarters liner, planned at the terminal
	["helmet_off", "s2_quiet"],     # helmet off in the Quarters; Castle's quiet call
	# Chunk 2, Act 2: the pad (sol 2 afternoon, §4a Scenes 8–12).
	["pad_seen", "s2_pad_seen"],    # up close at the pad: Castle sees it on your helmet camera
	["pad_reseated", "s2_reseat"],  # the foot levered, the mast pulled upright; Tamsin asks for a line
	["pad_line", "s2_pad_line"],    # a line across the pad: a void band past the crack
	["pit_seen", "s2_pit_seen"],    # at the pit's lip, looking down
	["pit_line", "s2_hold"],        # the line at the lip matches; the crew argue; Castle holds
	["sled_plan", "s2_sled"],       # the walk home: Tamsin's sled plan
	["new_job", "s2_job"],          # home at dusk: the new job; pallet 6 pinned
]
const LAST_BEAT := "new_job"
const CHUNK_TWO := ["pad_seen", "pad_reseated", "pad_line", "pit_seen", "pit_line", "sled_plan", "new_job"]
## Chunk 3, Act 3 (docs/opening-slice.md Scenes 13–18, §10c): the free
## stretch after the new job. Beats with calls, checked from the world the
## same way, but none of them guided: no forced sleep, no set sol, no stall
## hints (Ask orbit still answers). "ready" is rung by the ready call itself.
const FREE_BEATS := [
	["sled_home", "s3_sled_home"],  # pallet 6 opened at home: the sled's frame in the store
	["printer_in", "s3_printer"],   # the Print Shop placed in the core; the connector's plan
	["teach", "s3_teach"],          # first use of the printer: Tamsin teaches iron and salvage
	["connector", "s3_connector"],  # the beacon connector taken out of the drawer
	["sled_built", "s3_sled_built"],# the printed fittings bolted to the frame
	["sled_fitted", "s3_sled_out"], # out through the lock with the sled on GAR-Y
	["ready", ""],                  # "Call Castle: I'm ready" (slate or base radio); the bench pinned
]
const FINAL_BEAT := "ready"
## The bench across the Dry channel (data/region_layout.json "channel",
## bench 0.5: its middle reach, the east side), region metres.
const BENCH := Vector2(-905.0, 1200.0)
const CHUNK_THREE := preload("res://scripts/chunk_three.gd")
var chunk3: Node                 # chunk 3: the outcrop, the case, the sled, GAR-Y's fittings
var _chunk3_state := {}
var _bench_pinned := false

var world: Node
var version := VERSION
var nights := 0
var reached: Array = []          # beat ids whose call has been rung
var chapter := 1                 # 1 = sol 1's beats, 2 = sol 2's, 3 = done (callers read this)
var _was_asleep := false
var _bed_said := false           # sol 1's "back to the lander and sleep" thought, once
var _check := 0.0
const CHECK_EVERY := .5
const PAD_SITE := preload("res://scripts/pad_site.gd")
const SURVEY_LINE := preload("res://scripts/survey_line.gd")
var pad: Node3D                  # chunk 2: the planned pad and the pit (scripts/pad_site.gd)
var lines: Node                  # chunk 2: survey lines (scripts/survey_line.gd)
var _pad_state := {}
var _lines_state := {}
var _faint_said := false
var _pinned := false

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "OpeningSlice"
	add_to_group("opening_days")
	version = int(saved.get("version", VERSION))
	nights = int(saved.get("nights", 0))
	reached = (saved.get("reached", []) as Array).duplicate()
	_circled = reached.has("core_down")   # a loaded game past the fold doesn't replay the lap
	chapter = int(saved.get("chapter", 1))
	_bed_said = bool(saved.get("bed_said", false))
	_faint_said = bool(saved.get("faint_said", false))
	_pinned = bool(saved.get("pinned", false))
	_pad_state = saved.get("pad", {}) as Dictionary
	_lines_state = saved.get("lines", {}) as Dictionary
	_chunk3_state = saved.get("chunk3", {}) as Dictionary
	_bench_pinned = bool(saved.get("bench_pinned", false))
	RADIO.opening_set = "slice"
	_build_pad.call_deferred()

## Chunk 2: the pad, the pit and the survey line, once the world's up.
func _build_pad() -> void:
	if pad != null or world == null or world.get("lander") == null: return
	pad = PAD_SITE.new()
	world.add_child(pad)
	pad.setup(world, _pad_state)
	lines = SURVEY_LINE.new()
	add_child(lines)
	lines.setup(world, pad, _lines_state)
	lines.line_done.connect(_line_done)
	chunk3 = CHUNK_THREE.new()
	add_child(chunk3)
	chunk3.setup(world, _chunk3_state)

func export_state() -> Dictionary:
	return {"version": version, "nights": nights, "reached": reached.duplicate(), "chapter": chapter, "bed_said": _bed_said,
		"faint_said": _faint_said, "pinned": _pinned,
		"pad": pad.export_state() if pad != null else _pad_state, "lines": lines.export_state() if lines != null else _lines_state,
		"chunk3": chunk3.export_state() if chunk3 != null else _chunk3_state, "bench_pinned": _bench_pinned}

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
		2: return done(LAST_BEAT)
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

## Scene 5: on sol 1's night, strapping into the landing seat is sleep till
## dawn, no choosing hours (scripts/sleep.gd open).
func straight_to_sleep() -> bool:
	return guided() and nights < 1 and done("walker_home")

func ask_next() -> bool:
	return false   # Castle doesn't hand out next steps: the world and the manifest do

## The slate's Today page: first-person thoughts about what's open now.
func open_goals() -> Array:
	var out := []
	if free_stretch():
		for beat in FREE_BEATS:
			var id := str(beat[0])
			if done(id): continue
			var text := str(GOAL_THOUGHTS.get(id, ""))
			if text.is_empty(): continue
			out.append({"text": text, "needs": ""})
			break
		return out
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
	"walker_awake": "Walker 1's battery's flat. The power module in pallet 2 fits its socket.",
	"walker_fixed": "Something on Walker 1's front axle is leaking.",
	"walker_home": "Bring Walker 1 back to the lander before dark.",
	"slept": "Sleep. Tomorrow it walks.",
	"core_down": "Ride Walker 1 and find the right spot for home.",
	"kit_placed": "Open the fit-out kit box on the core's floor, then B (standing inside) to place the kit.",
	"quarters": "Somewhere to sleep with the helmet off. The Site plan terminal plans rooms: as big as the regolith allows.",
	"helmet_off": "Somewhere to breathe without the helmet.",
	"pad_seen": "The pad's this afternoon. East, past the plain.",
	"pad_reseated": "That mast shouldn't lean. Its foot's in a crack.",
	"pad_line": "Tamsin wants a line across the pad. Stakes are on 4.",
	"pit_seen": "The Collapse pit. Something to hold the pad's line against.",
	"pit_line": "Run the same line at the pit's lip. Close, but not too close.",
	"sled_plan": "Head home.",
	"new_job": "Home. Helmet off. They'll call.",
	# Chunk 3, the free stretch: suggestions, not orders.
	"sled_home": "Pallet 6 is Tamsin's sled. GAR-Y can tow the crate home.",
	"printer_in": "The Print Shop's on B's Unpacked tab. It goes in the core.",
	"connector": "The beacon connector first. A small print.",
	"sled_built": "The sled's fittings. The Print Shop says what's short.",
	"sled_fitted": "Put the sled on GAR-Y's hitch at the EVA station, then go out together.",
	"ready": "When I'm ready, I call Castle. The slate, or the base radio.",
}

## After the new job: the free stretch (chunk 3), a version 3 game.
func free_stretch() -> bool:
	return world != null and world.get("walker") != null and reached.has(LAST_BEAT)

func _free_done(id: String) -> bool:
	match id:
		"sled_home": return MHChapterOne.unpacked.has("radar_sled_frame")
		"printer_in": return not MHChapterOne.fabricators(world.get("builder")).is_empty()
		"teach":
			if not (reached.has("sled_home") and reached.has("printer_in")): return false
			return MHChapterOne.parts.has("beacon_connector") or MHChapterOne.made.has("beacon_connector") or not MHChapterOne.jobs.is_empty()
		"connector": return MHChapterOne.parts.has("beacon_connector")
		"sled_built": return chunk3 != null and bool(chunk3.sled_built)
		"sled_fitted": return chunk3 != null and bool(chunk3.sled_fitted()) and _outside()
		"ready": return reached.has(FINAL_BEAT)
	return false

## The ready call can be made (the slate's button, the base radio).
func ready_call_open() -> bool:
	return free_stretch() and not reached.has(FINAL_BEAT)

## Scene 18: "Call Castle: I'm ready." Without the sled, Castle says so.
func ready_call() -> bool:
	var radio: Node = world.get("radio")
	if radio == null or not ready_call_open() or bool(radio.on_air()): return false
	if chunk3 == null or not bool(chunk3.sled_built):
		(radio.heard as Dictionary).erase("s3_not_ready")
		radio.ring("s3_not_ready")
		return true
	reached.append(FINAL_BEAT)
	radio.ring("s3_ready")
	return true

func _pin_bench() -> void:
	var known: Node = world.get("known")
	if _bench_pinned or known == null: return
	_bench_pinned = true
	known.learn("bench", "find", BENCH, "The bench · across the Dry channel", "you", "castellanos")
	known.track("bench")
	MHNotices.hint("The bench", "Across the Dry channel. It's marked on your Map and your compass.")

## The free stretch's tick: the stock it's owed, the plans the story hands
## over, the case on the plain, and one call at a time.
func _free_tick() -> void:
	var builder: Node = world.get("builder")
	if builder != null:
		BUILD_RULES.catch_up_print_shop(builder)
		BUILD_RULES.catch_up_chunk_three(builder)
	_pin_print_shop()
	MHChapterOne.hand_plan("beacon_connector")
	if MHChapterOne.unpacked.has("radar_sled_frame"): MHChapterOne.hand_plan("radar_sled_fittings")
	if chunk3 != null: chunk3.place_case()
	var radio: Node = world.get("radio")
	if radio == null or bool(radio.on_air()): return
	for beat in FREE_BEATS:
		var id := str(beat[0])
		if str(beat[1]).is_empty() or reached.has(id) or not done(id): continue
		if id == "teach" and _outside(): continue   # at the printer, indoors
		reached.append(id)
		radio.ring(str(beat[1]))
		break

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
			var field: Node = world.get("drop_field")
			return field == null or bool(field.get("gary_greeted"))
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
	for beat in FREE_BEATS:
		if str(beat[0]) == id: return _free_done(id)
	# Chunk 2 waits for the first room: the pad's the afternoon's job.
	if id in CHUNK_TWO:
		if not reached.has("helmet_off") or pad == null: return false
		match id:
			"pad_seen": return bool(pad.seen)
			"pad_reseated": return bool(pad.reseated)
			"pad_line": return lines.has_line("pad")
			"pit_seen": return bool(pad.pit_seen)
			"pit_line": return lines.has_line("pad") and lines.has_line("pit")
			"sled_plan", "new_job": return reached.has("pit_line")
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
		if not _was_asleep and nights < 1 and done("walker_home"): _night_sounds()
		_was_asleep = true
		return
	if _was_asleep:
		_was_asleep = false
		var hour := MHGame.sol_hour
		if hour < 12.0: nights += 1
	if not guided():
		if free_stretch(): _free_tick()
		return
	var radio: Node = world.get("radio")
	# A beat's call rings when the beat's done, one a tick, in order. Done out
	# of order, its call still comes (the calls react, they don't instruct).
	for beat in BEATS:
		var id := str(beat[0])
		if reached.has(id) or not done(id): continue
		# 23 Nov playtest: some calls rang long after they made sense. A call
		# that's overtaken is dropped (counted as heard, nothing said).
		if _overtaken(id):
			reached.append(id)
			continue
		if not _call_ready(id): continue
		reached.append(id)
		if radio != null and radio.has_method("ring"): radio.ring(str(beat[1]))
		break
	_bedtime()
	_ride_lead()
	_kit_lead()
	_tiredness_wins()
	if reached.has("core_down") and not _circled: _gary_circles()
	_gary_to_the_steps()
	_kit_crates()
	_quarters_lead()
	if world.get("builder") != null: BUILD_RULES.catch_up_print_shop(world.builder)   # a save from before the Print Shop moved
	_pin_print_shop()
	# Over once the new job's call has rung (some beats are optional: you
	# can carry the module and never fit the hitch).
	if reached.has(LAST_BEAT): chapter = STORY_DAYS + 1
	elif done("slept"): chapter = 2

## Some calls wait for the right moment as well as the beat.
## A call that would only confuse now: the dawn call about the walker
## frosted on the plain, once you've already ridden it home (you slept
## first somewhere later, 23 Nov playtest).
func _overtaken(id: String) -> bool:
	match id:
		"slept": return done("core_down")
	return false

## Within this far of `at` (site metres, x/z), outside.
func _near(at: Vector2, reach: float) -> bool:
	var me: Node3D = world.get("player")
	if me == null or is_inf(at.x) or not _outside(): return false
	return Vector2(me.global_position.x - at.x, me.global_position.z - at.y).length() <= reach

func _call_ready(id: String) -> bool:
	match id:
		# The pad and pit calls are the crew watching your helmet camera
		# there. Done before the first room (chunk two waits for it), they
		# used to ring wherever you were, back at base (23 Nov playtest);
		# now they wait till you're back at the pad.
		"pad_seen", "pad_reseated", "pad_line":
			return pad == null or _near(pad.centre_2d(), 60.0)
		"pit_seen", "pit_line":
			return pad == null or _near(pad.pit_centre(), 60.0)
		# Scene 5: the evening call, once you're in the cabin with your
		# helmet off, at dusk.
		"walker_home":
			var cycle: Dictionary = MHGame.site().get("day_cycle", {})
			return _in_cabin() and not _helmet_on() and (MHGame.sol_hour >= float(cycle.get("sunset_hour", 19.0)) - 1.5 or is_night())
		# Scene 12: Tamsin's sled plan on the walk home, once the hold's
		# played and you've left the pit behind (or you're already in).
		"sled_plan":
			var radio: Node = world.get("radio")
			if radio == null or not (radio.heard as Dictionary).has("s2_hold") or radio.on_air(): return false
			var me: Node3D = world.get("player")
			var pit: Vector2 = pad.pit_centre()
			return me == null or is_inf(pit.x) or not _outside() or Vector2(me.global_position.x - pit.x, me.global_position.z - pit.y).length() > 60.0
		# Scene 12: the new job, at home in a room with your helmet off, at
		# dusk or after.
		"new_job":
			var radio: Node = world.get("radio")
			if radio == null or not (radio.heard as Dictionary).has("s2_sled"): return false
			var cycle: Dictionary = MHGame.site().get("day_cycle", {})
			return not _outside() and not _helmet_on() and not _in_cabin() and (MHGame.sol_hour >= float(cycle.get("sunset_hour", 19.0)) - 2.5 or is_night())
	return true

func _outside() -> bool:
	var suit: Node = world.get("suit")
	return suit == null or str(suit.get("where")) == "outside"

## Scene 11: a line at the pit that reads mush. Tamsin asks for closer, once.
func _line_done(line: Dictionary) -> void:
	if str(line.kind) != "pit" or str(line.verdict) == "void" or _faint_said: return
	_faint_said = true
	var radio: Node = world.get("radio")
	if radio != null and radio.has_method("ring"): radio.ring("s2_pit_faint")

## Scene 12, the end: pallet 6 on your slate, tracked.
func _pin_print_shop() -> void:
	if _pinned or not reached.has(LAST_BEAT): return
	var field: Node = world.get("drop_field")
	var known: Node = world.get("known")
	if field == null or known == null or not field.sites.has("print_shop"): return
	_pinned = true
	var site: Node3D = field.sites.print_shop
	known.learn("pallet_6", "find", field.region_at(site.at), "Pallet 6 · Survey sled", "you", "castellanos")
	known.track("pallet_6")
	MHNotices.hint("Pallet 6", "The survey sled's pallet is marked on your Map and your compass.")

func _in_cabin() -> bool:
	var lander: Node = world.get("lander")
	var me: Node3D = world.get("player")
	return lander != null and me != null and bool(lander.cabin_contains(me.global_position))

func _helmet_on() -> bool:
	var suit: Node = world.get("suit")
	return suit != null and bool(suit.helmet)

## Scene 7: the fit-out kit, one box in the middle of the core's floor, once
## it's down (23 Nov: one box unlocks B, not a crate a piece).
const KIT_CRATE := preload("res://scripts/kit_crate.gd")
func _kit_crates() -> void:
	if not done("core_down") or not get_tree().get_nodes_in_group("kit_crate").is_empty(): return
	var builder: Node = world.get("builder")
	var life: Node = world.get("module_life")
	if builder == null or life == null: return
	if BUILD_RULES.kit_left(builder).is_empty(): return
	if BUILD_RULES.kit_open(): return   # opened once and packed away (23 Nov)
	var spot := kit_box_spot(life)
	if not spot.is_empty(): KIT_CRATE.new().setup(world, spot.at, spot.facing)

## The middle of the core's floor, the box's long side along the room.
static func kit_box_spot(life: Node) -> Dictionary:
	var cells: Array = life.zone().get("cells", [])
	if cells.is_empty(): return {}
	var cell: float = life.world.builder.CELL
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in cells:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
	var mid := (lo + hi) * .5 * cell
	var along_x := (hi.x - lo.x) >= (hi.y - lo.y)       # the room's long way
	var facing := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)   # the box's local X (its long side) runs along the room
	return {"at": Vector3(mid.x, float(life.call("_floor")), mid.y), "facing": facing}

## Scene 5: once Walker 1's home and you're in, GAR-Y parks by the steps.
var _gary_parked := false
func _gary_to_the_steps() -> void:
	if _gary_parked or nights >= 1 or not done("walker_home") or not _in_cabin(): return
	var gary: Node3D = world.get("scout_rover")
	var lander: Node3D = world.get("lander")
	if gary == null or lander == null or bool(gary.get("rescuing")): return
	_gary_parked = true
	gary.lead_to(lander.ramp_foot(2.5), true)

## Sol 1, after the evening call: the day's done. One thought, one hint.
func _bedtime() -> void:
	if _bed_said or nights >= 1 or not reached.has("walker_home"): return
	var radio: Node = world.get("radio")
	if radio != null and (radio.on_air() or not (radio.queue as Array).is_empty()): return
	_bed_said = true
	var notes: Node = world.get("notes")
	if notes != null: notes.think("bed", "late", {"home": "the lander"})
	MHNotices.hint("Bed", "Look at the landing seat and press Z to sleep till morning.")

## 22 Nov playtest: "got the walker back to base but cant figure out how to
## place it". A thought when it kneels home, and at dawn a thought and one
## hint for the ride; the hint goes once you're up on its deck.
const RIDE_HINT := "Walker 1"
var _home_said := false
var _ride_said := false
func _ride_lead() -> void:
	var walker: Node = world.get("walker")
	if walker == null or done("core_down"):
		if _ride_said: MHNotices.drop(RIDE_HINT)
		return
	var notes: Node = world.get("notes")
	if not _home_said and nights < 1 and done("walker_home"):
		_home_said = true
		if notes != null: notes.think("walker_home", "start")
	if bool(walker.get("riding")):
		if _ride_said: MHNotices.drop(RIDE_HINT)
		return
	if _ride_said or nights < 1 or str(walker.get("state")) != "ready" or _in_cabin(): return
	_ride_said = true
	if notes != null: notes.think("walker_ride", "start")
	MHNotices.hint(RIDE_HINT, "Climb its ladder. Hold W and it walks where you look; the deck screen reads the ground. E sets it down.")

## 23 Nov playtest: it wasn't clear you could build a Quarters at all. Once
## the kit's placed and there's no Quarters, one pointer to the terminal
## (its screen pulses too: scripts/site_plan_terminal_screen.gd).
var _quarters_said := false
func _quarters_lead() -> void:
	if _quarters_said or not done("kit_placed") or _quarters(): return
	_quarters_said = true
	MHNotices.hint("A room of your own", "Rooms are planned at the Site plan terminal: walk up to it and press E. A Quarters costs regolith by the cell, so make it as big as your store allows.")

## Once the core's folded: the kit's in one box on its floor, and B places it.
var _kit_said := false
func _kit_lead() -> void:
	if _kit_said or not done("core_down") or done("kit_placed"): return
	if get_tree().get_nodes_in_group("kit_crate").is_empty(): return
	_kit_said = true
	var notes: Node = world.get("notes")
	if notes != null: notes.think("kit_crates", "start")
	MHNotices.hint("Fit-out kit", "Open the kit box (E). Then B furnishes: the whole kit's on your build list. The Site plan terminal's in it too: place it where you'll pass it, and it plans new rooms.")

## Scene 5: stay up on sol 1's night and, past midnight in the cabin,
## tiredness wins: you nod off where you are and sleep till dawn. Not with a
## critical alert up (scripts/sleep.gd blocked_reason).
const NOD_OFF_AFTER := .5   # 00:30
func _tiredness_wins() -> void:
	if not _bed_said or nights >= 1 or not _in_cabin(): return
	var hour := MHGame.sol_hour
	if hour < NOD_OFF_AFTER or hour >= 12.0: return
	var sleep: Node = world.get("sleep")
	if sleep == null or bool(sleep.asleep) or not str(sleep.blocked_reason()).is_empty(): return
	if bool(world.player.get_meta("ui_freeze", false)): return
	MHNotices.drop("Bed")
	sleep.sleep(sleep._until_sunrise())

## Scene 6: the core's folded and GAR-Y does a slow lap of it, then a happy
## chirp. Not saved: a loaded game past the fold just doesn't replay it.
const CIRCLE_RADIUS := 7.0
var _circled := false
func _gary_circles() -> void:
	_circled = true
	var gary: Node3D = world.get("scout_rover")
	var walker: Node3D = world.get("walker")
	if gary == null or walker == null or bool(gary.get("rescuing")): return
	var centre := walker.global_position
	var start := atan2(gary.global_position.x - centre.x, gary.global_position.z - centre.z)
	for i in range(1, 7):
		var angle := start + TAU * i / 6.0
		var spot := centre + Vector3(sin(angle), 0.0, cos(angle)) * CIRCLE_RADIUS
		gary.lead_to(spot, true)
		var waited := 0.0
		while waited < 8.0 and is_instance_valid(gary) and gary.leading_to(spot):
			await get_tree().create_timer(.25).timeout
			waited += .25
		if not is_instance_valid(gary) or bool(gary.get("rescuing")) or not (gary.task == "" or gary.leading_to(spot)): return   # given other orders
	if is_instance_valid(gary): gary._say("happy")

## Scene 5, the night: as you drift off, Walker 1's servos shift outside and
## GAR-Y chirps once. Real seconds: the clock's racing by now.
func _night_sounds() -> void:
	var walker: Node3D = world.get("walker")
	var gary: Node3D = world.get("scout_rover")
	await get_tree().create_timer(1.6, true, false, true).timeout
	if walker != null and is_instance_valid(walker): MHAudio.sfx_at("mode_build", walker, -10.0, .45)
	await get_tree().create_timer(1.4, true, false, true).timeout
	if gary != null and is_instance_valid(gary): MHAudio.sfx_at("place", gary, -12.0, 1.9)

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
	radio.facts["fell_in_pit"] = func(_args: Array) -> bool: return pad != null and bool(pad.fell)
	radio.facts["hitched"] = func(_args: Array) -> bool: return done("hitched")
	radio.handlers["iron_outcrop"] = func(_args: Array) -> void:
		MHMaterials.told["hematite"] = true
		if chunk3 != null: chunk3.place_outcrop()
		MHNotices.hint("Iron-rich rock", "The dark outcrop is marked on your Map. Key 2 for the hammer: break some off, and it comes home in your suit's bag. E at the Print Shop feeds it into the hopper.")
	radio.handlers["pin_bench"] = func(_args: Array) -> void: _pin_bench()
	radio.handlers["stakes_hint"] = func(_args: Array) -> void:
		MHNotices.hint("Survey stakes", "Key 4 puts the stakes in hand. E plants one where you stand. Walk on and plant the far one, and GAR-Y runs the line between them.")
	radio.facts["indoors"] = func(_args: Array) -> bool:
		var suit: Node = world.get("suit")
		return suit != null and str(suit.get("where")) != "outside"
