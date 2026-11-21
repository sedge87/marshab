extends Node

## The opening's first days (playtest 8 Nov): "baby steps", the game at a
## small scale. Each day has its jobs, and each ends with sleep:
## - Sol 1, the pallets: air, power, GAR-Y, tools.
## - Sol 2, the lifepod jobs (scripts/lifepod.gd): enough of water, parts,
##   a sample, the sled tow. GAR-Y scouted all night and shows you round.
## - Then Walker 1: find it, set it right, walk it home.
## - Then the module: choose its ground, lower it, and fit it out.
## The days aren't fixed to the calendar: what you don't finish carries over
## to tomorrow, and the clock never stops.
##
## At dusk Notes says it's time for bed, and GAR-Y leads you home if you're
## out. Version 2 never locks the hatch at night (10 Nov): going out in the
## dark just gets a word of caution (night_caution). Version 1 kept it shut
## from inside at night while you lived in the lander.

## The guided chapters, version 2, as rewritten in A6 (15 Nov,
## docs/opening-days.md): chapters aren't days. A chapter's beats done, the
## next one's first call comes after a short breather (BREATHER), on the same
## sol if there's light. At dusk Castle calls from wherever the story is, and a
## morning recaps only what's left. Nothing waits for the dark:
##   1: pallets 1-3 for the bare suit, the cargo home.
##   2: Rao sees something moving; GAR-Y found at work; his jobs; the crate.
##   3: Walker 1's tracks; its nav set right; its wheel seal patched on the
##      spot; ride it home; choose home on the Map (W, W).
##   4: it walks there, kneels and folds into the core; air and power in; the
##      first Quarters liner; the three horizons; the first night in Quarters
##      ends the chapters.
## (Below, the 8 Nov notes on the first v2, kept for the history.)
## The guided days, version 2 (docs/opening-days.md, 8 Nov redesign), for
## new games: four chapters on the real sun (9 Nov). The sun never waits.
## A chapter's beats done, its sunset call comes at dusk, and the next
## chapter starts the morning after. Not done by dusk: Castle says pick it
## up tomorrow, and that morning she recaps what's left (dN_dusk, dN_still).
## The nights carry the story (GAR-Y's night out, Walker 1 crawling home).
##   Day 1: pallets 1, 2 and 4 and the module's cargo carried home. No GAR-Y.
##   Day 2: something moving out there; GAR-Y's empty cradle, then GAR-Y at
##          work; its jobs (scripts/lifepod.gd) till the walker's due.
##   Day 3: Walker 1 set right; it crawls home overnight; B marks the
##          module's spot (scripts/walker.gd "coming").
##   Day 4: at dawn it's parked and sets the module down on your mark,
##          cold and open to Mars. Air and power in, a seam won't hold: find
##          the hiss and patch it (scripts/module_leak.gd). The kit's placed;
##          then GAR-Y finds its ice. The sunset talk: tomorrow, this season,
##          the mission (each goal from its owner up there, and their notes).
##          The first night in the module. Then day 5 is yours.
## Version 1 (the first opening) stays for older saves and older tests.
static var new_games_version := 2
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const STORY_DAYS := 4           # days run on story time; day 5 opens the game
## Chapter 5 (15 Nov, docs/opening-days.md "Chapter 5"): the Print Shop.
## Lighter than 1-4: no forced bed, and guided() is already false, so the
## night and the rest of the game are yours. It ends with the ice extractor
## set down; then chapter is 6 and Castle's morning calls say what's next.
const PRINT_CHAPTER := 5
const CALL_BEFORE_SUNSET := .6  # Castellanos's sunset call
const DAY1_SUN_EARLIER := .7    # day 1's photo call: about 1.3 h before sunset, before the hills take the sun
const DUSK_SPEED := 8.0         # (no longer used: the sun runs freely)
const MORNING_GAP := 14.0       # sim hours between mornings (a chapter turns over at most once a sol)
const EARLY_HOURS := 2.5        # done with this much light left: "the rest of the day's yours"
## A6: game hours between a chapter's beats done and the next chapter's first
## call (index: the chapter just done). Back in the cabin it comes sooner.
const LATE_START := 3.0         # no new chapter starts this close to sunset (about 5 real minutes of light): it waits for morning

const STAGES := ["pallets", "lifepod", "walker", "module", "fit_out"]
const FIT_OUT_PIECES := 3       # kit pieces placed: the module's lived in
const LEAD_FROM := 30.0         # further than this from home at dusk: GAR-Y leads you in
const DUSK_EARLY := 1.5         # hours before sunset: bed, if the day's done
const CHECK_EVERY := .5

var world: Node
var dawn_stage := -1            # the stage you woke into
var bed_sol := 0                # the sol "bed" last came
var gary_waited_sol := 0        # the sol GAR-Y last waited at the ramp
var arden_morning := false      # sol 2's morning check, said
var nights := 0                 # nights slept: a new day starts when you wake (the sol rolls over at 06:00)
var version := 1
var sunset_called := 0          # the last day whose sunset call came
var sunset_spot := Vector3.INF   # day 1: the rise Castellanos sends you to, to watch the sun go down
var sunset_reached := false
var _photo_wait := 0.0           # the sunset call's "take a picture" wait
var _photos_before := 0
const TRACKS_CALL_NEAR := 150.0  # R4: the walker-tracks call waits till you're this near the lander
const SPOT_REACH := 18.0         # this close to the rise and you're there
const PHOTO_WAIT := 50.0         # seconds Castellanos waits for the picture
var chapter := 1                 # version 2: the first chapter not yet over (1-5); 6 once they all are
## 21 Nov playtest ("more freeform"): sol 1 stays guided; from sol 2 the
## chapters run side by side as open goals, each with only its real needs
## (OPENS). started: chapters whose first call has come; finished: chapters
## that are over (4 ends with the first night in Quarters, 5 with the
## extractor set down).
var started := [1]
var finished := []
var last_morning := UNSET        # sim hours at the last morning
const UNSET := -1.0e9
var dusk_sol := 0                # the sol whose "pick it up tomorrow" call came
var done_told := 0               # the last chapter whose "the rest of the day's yours" came
var done_at := UNSET             # A6: sim hours when this chapter's beats were done
var survey_from := -1            # day 4: cores taken from here on (MHChapterOne.cores) count for the module's ice
var ice_spot := Vector3.INF      # day 4: the module's ice, found
const ICE_REACH := 400.0         # this near the module, a core's the module's ice
const THIN_AFTER := 3            # cores with no good ice: the best of them will do
const BUNK_BY_DOOR := 4.5        # metres from the airlock: the bunk's "by the door"
## Day 4's notes from the crew, each from the goal's owner (data/orbiter_crew.json).
const OWNER_NOTES := [
	["d4_note_tupou", "tupou", "Life's mine, then. If you see anything at all that looks odd, layered, crusty, a funny colour, photograph it before you touch it. Please. I'll explain why later. At length."],
	["d4_note_rao", "rao", "Climate. Every pass, I'm looking at your sky as well as for walkers. Tell me when the dust is up and when the frost is down. That's half my data, from you."],
	["d4_note_achterberg", "achterberg", "Geology, and building with it. Your printer eats regolith. Find me good dirt and I'll find you things to make out of it. Also: well done on Walker 1's wheel."],
	["d4_note_mwangi", "mwangi", "Humans, which means you. Eat, drink, sleep, in that order, and tell me honestly how you're feeling. I'd rather hear 'lonely' than 'fine'."],
]
var _fast := false
var _was_asleep := false
var _lead_again := 0.0
var _check := 0.0

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "OpeningDays"
	add_to_group("opening_days")
	dawn_stage = int(saved.get("dawn_stage", -1))
	bed_sol = int(saved.get("bed_sol", 0))
	gary_waited_sol = int(saved.get("gary_waited_sol", 0))
	arden_morning = bool(saved.get("arden_morning", false))
	nights = int(saved.get("nights", 0))
	version = int(saved.get("version", world.get("opening_version") if world.get("opening_version") != null else 1))
	sunset_called = int(saved.get("sunset_called", 0))
	var spot: Array = saved.get("sunset_spot", [])
	if spot.size() == 3: sunset_spot = Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
	sunset_reached = bool(saved.get("sunset_reached", false))
	survey_from = int(saved.get("survey_from", -1))
	chapter = int(saved.get("chapter", mini(nights + 1, STORY_DAYS + 1)))
	last_morning = float(saved.get("last_morning", UNSET))
	dusk_sol = int(saved.get("dusk_sol", 0))
	done_told = int(saved.get("done_told", 0))
	done_at = float(saved.get("done_at", UNSET))
	# Older saves kept one chapter at a time: everything before it is over.
	started = (saved.get("started", range(1, chapter + 1)) as Array).map(func(n): return int(n))
	finished = (saved.get("finished", range(1, chapter)) as Array).map(func(n): return int(n))
	var ice: Array = saved.get("ice_spot", [])
	if ice.size() == 3: ice_spot = Vector3(float(ice[0]), float(ice[1]), float(ice[2]))

func export_state() -> Dictionary:
	return {"dawn_stage": dawn_stage, "bed_sol": bed_sol, "gary_waited_sol": gary_waited_sol, "arden_morning": arden_morning, "nights": nights, "version": version, "sunset_called": sunset_called, "sunset_reached": sunset_reached, "sunset_spot": [] if is_inf(sunset_spot.x) else [sunset_spot.x, sunset_spot.y, sunset_spot.z],
		"chapter": chapter, "last_morning": last_morning, "dusk_sol": dusk_sol, "done_told": done_told, "done_at": done_at, "started": started, "finished": finished,
		"survey_from": survey_from, "ice_spot": [] if is_inf(ice_spot.x) else [ice_spot.x, ice_spot.y, ice_spot.z]}

# ---------- where the days are ----------

## The first unfinished day's stage (0-4), or 5 once the module's lived in.
func stage() -> int:
	# From the latest back: a later step done means the earlier days are over.
	for i in range(STAGES.size() - 1, -1, -1):
		if _done(STAGES[i]) and (i < 3 or _done("module")): return i + 1
	return 0

func _done(what: String) -> bool:
	var walker: Node = world.get("walker")
	var walker_state := str(walker.state) if walker != null else "done"
	match what:
		"pallets":
			var drop: Node = world.get("storm_drop")
			var field: Node = world.get("drop_field")
			if drop != null and drop.pallet != null and not bool(drop.pallet.opened): return false
			if field != null:
				for kind in field.sites:
					if kind == "print_shop": continue   # chapter 5's
					var site: Node = field.sites[kind]
					if site.pallet != null and not bool(site.pallet.opened): return false
			return true
		"lifepod":
			var pod: Node = world.get("lifepod")
			return pod == null or bool(pod.walker_due) or bool(pod.walker_moved)
		"walker": return walker_state in ["parked", "carrying", "lowering", "done"]
		"module": return walker_state == "done"
		"fit_out":
			var builder: Node = world.get("builder")
			return builder == null or (builder.placed_interior as Array).size() >= FIT_OUT_PIECES
	return true

## Still in the opening's guided days.
func guided() -> bool:
	if world.get("walker") == null: return false
	if v2(): return chapter <= STORY_DAYS
	return stage() < STAGES.size()

## Version 2: a chapter's beats done (the same as its day's).
func chapter_done(n: int) -> bool:
	return day_done(n)

## Living in the lander still (chapters 1-3): bed is a landing seat.
func in_lander_days() -> bool:
	if v2(): return guided() and chapter <= 3 and int(world.opening_part()) <= 3
	return guided() and world.has_method("opening_part") and int(world.opening_part()) <= 2

func _cycle() -> Dictionary:
	return MHGame.site().get("day_cycle", {})

func is_night() -> bool:
	var hour := MHGame.sol_hour
	return hour >= float(_cycle().get("sunset_hour", 19.0)) + .5 or hour < float(_cycle().get("sunrise_hour", 5.0))

## Why the lander's hatch won't open for you now, or "" (scripts/crew_lander.gd).
func hatch_refusal() -> String:
	# 16 Nov playtest: the first time out, only what you need: the slate and a
	# sealed helmet. Nothing waits on Castle's talking.
	if v2() and int(chapter) <= 1 and str(world.get("_intro_stage")) == "inside":
		var in_lander: Node = world.get("lander")
		var me: Node3D = world.get("player")
		if in_lander != null and me != null and bool(in_lander.cabin_contains(me.global_position)):
			var pda: Node = world.get("pda")
			if pda != null and not bool(pda.received): return "My slate's on the console. I'm not going out there without it."
			var suit: Node = world.get("suit")
			if suit != null and not bool(suit.seal_checked) and not bool(suit.helmet): return "Helmet first. K seals it."
	if v2() or not in_lander_days() or not is_night(): return ""   # version 1 (old saves) still locks it
	var lander: Node = world.get("lander")
	var player: Node3D = world.get("player")
	if lander == null or player == null or not bool(lander.cabin_contains(player.global_position)): return ""
	return "Not out there in the dark. Sleep first, and go at sunrise."

## Opening the hatch at night in the lander days: no lock (playtest 10 Nov,
## "I thought we weren't locking the player in"), just a word of caution.
func night_caution() -> String:
	if not v2() or not in_lander_days() or not is_night(): return ""
	return "It's dark and very cold out there. Keep it short, mind your air, and get some sleep: the day starts at sunrise."

## Home tonight: the lander, or the module once it's down.
func _home_name() -> String:
	return "the lander" if _lander_home() else "the module"

## Still the lander tonight: before the module's down, or while it won't hold air.
func _lander_home() -> bool:
	return int(world.opening_part()) <= 3 or (v2() and not _commissioned())

func _home_spot() -> Vector3:
	var lander: Node = world.get("lander")
	if _lander_home() and lander != null: return lander.ramp_foot(3.0)
	var gary := _gary()
	return gary._airlock_waiting_spot() if gary != null else Vector3.INF

func _gary() -> Node:
	return get_tree().get_first_node_in_group("gar_y")

# ---------- the day ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null or get_tree().paused: return
	_check = CHECK_EVERY
	if not guided():
		_after_chapters()
		return
	var notes: Node = world.get("notes")
	if notes == null: return
	var sol := int(notes.call("_sol"))
	var hour := MHGame.sol_hour
	var sunrise := float(_cycle().get("sunrise_hour", 5.0))
	var sunset := float(_cycle().get("sunset_hour", 19.0))
	var sleep: Node = world.get("sleep")
	var asleep: bool = sleep != null and bool(sleep.get("asleep"))
	var now := stage()
	if dawn_stage < 0: dawn_stage = now
	# Asleep: the day's over. Tomorrow starts with what's left.
	if asleep:
		if notes.is_open("bed"): notes.let_go("bed")
		MHNotices.drop("Bed")
		dawn_stage = now
		_was_asleep = true
		return
	if _was_asleep:
		_was_asleep = false
		if hour >= sunrise - 2.0 and hour < 12.0: nights += 1
		# A6: the first night after chapter 4's done (in Quarters) ends the chapters.
		if v2() and started.has(STORY_DAYS) and not finished.has(STORY_DAYS) and chapter_done(STORY_DAYS):
			var radio_now := _radio()
			if radio_now != null and not (radio_now.heard as Dictionary).has("d4_sunset_deal") and radio_now.handlers.has("owner_notes"):
				(radio_now.handlers["owner_notes"] as Callable).call([])   # the talk was missed: the notes still come
			_finish(STORY_DAYS)
			return
	# Dusk: the day's done (or it's too late to finish it). Bed.
	var dusk := hour >= sunset - DUSK_EARLY and hour < sunset + 6.0
	var late := hour >= sunset or hour < sunrise
	var day := maxi(sol, nights + 1)
	if v2():
		_chapter_tick(sol, hour, sunrise, sunset)
		if not guided(): return
		var radio := _radio()
		var call_due: bool = radio != null and (radio.on_air() or not (radio.queue as Array).is_empty())
		if late and bed_sol != sol and not call_due and bed_led():
			bed_sol = sol
			notes.think("bed", "late", {"home": _home_name()})
	else:
		_story_clock(-1.0, false)
		if bed_sol != day and ((dusk and now > dawn_stage) or late):
			bed_sol = day
			notes.think("bed", "start" if now > dawn_stage else "late", {"home": _home_name()})
	_lead_again -= CHECK_EVERY
	if notes.is_open("bed") and not _at_home() and _lead_again <= 0.0:   # again after the sunset, say
		_lead_again = 30.0
		_lead_home()
	if notes.is_open("bed") and _at_home() and in_lander_days():
		MHNotices.hint("Bed", "Look at a landing seat and press Z to sleep till morning.")
	if v2(): return
	# Sol 2's morning: GAR-Y's back from its night out, waiting at the ramp.
	if nights >= 1 and gary_waited_sol < nights and hour >= sunrise - 1.0 and hour < sunset - 3.0:
		var pod: Node = world.get("lifepod")
		if pod != null and pod.gary_report_ready() and _in_cabin():
			gary_waited_sol = nights
			var gary := _gary()
			if gary != null: gary.wait_at(world.lander.ramp_foot(2.0), world.lander.global_position)
	# ARDEN's morning check, in the cabin.
	if not arden_morning and int(world.opening_part()) == 2 and hour >= sunrise and hour < 12.0 and _in_cabin():
		arden_morning = true
		MHAudio.voice("cabin_morning_check")
		var replies: Node = world.get("replies")
		if replies != null: replies.offer_voice("cabin_morning_check")

# ---------- version 2: story time and the radio ----------

func v2() -> bool:
	return version >= 2

func _radio() -> Node:
	return world.get("radio")

## The radio's up (scripts/mars_world.gd): the cues its scripts call.
func radio_ready() -> void:
	var radio := _radio()
	if radio == null: return
	radio.handlers["bed"] = func(_args: Array) -> void: _bed_now()
	# Places lines can be bound to (`@ near:gary:30`, scripts/radio.gd).
	radio.places["gary"] = func() -> Variant: return world.get("scout_rover")
	radio.places["crate"] = func() -> Variant: return field_crate()
	radio.places["pallet1"] = func() -> Variant:
		var drop: Node = world.get("storm_drop")
		return drop.pallet if drop != null else null
	radio.places["lander"] = func() -> Variant: return world.get("lander")
	radio.places["walker"] = func() -> Variant: return world.get("walker")
	radio.places["gary_pallet"] = func() -> Variant: return _site_pallet("gary")
	_radio_facts(radio)
	radio.handlers["gary_out"] = func(_args: Array) -> void:
		var field: Node = world.get("drop_field")
		if field != null: field.gary_out()
	radio.handlers["sunset_view"] = func(_args: Array) -> void: MHAudio.moment()
	radio.handlers["sunset_spot"] = func(_args: Array) -> void: _mark_sunset_spot()
	radio.handlers["photo_ask"] = func(_args: Array) -> void:
		_photo_wait = 0.0
		_photos_before = MHJournal.photos_on(int(world.notes.call("_sol"))) if world.get("notes") != null else 0
		var notes: Node = world.get("notes")
		if notes != null: notes.think("photo")
		MHNotices.post("info", "The slate's camera", "Tab for the slate, then Camera. E takes the picture.", "", 1)
	radio.checks["photo"] = func(_args: Array) -> bool:
		_photo_wait += .25
		var notes: Node = world.get("notes")
		var taken: bool = notes != null and MHJournal.photos_on(int(notes.call("_sol"))) > _photos_before
		if taken: radio.flags["sunset_photo"] = true
		return taken or _photo_wait >= PHOTO_WAIT or radio.fast
	radio.handlers["slate_light"] = func(_args: Array) -> void:
		if world.has_method("_slate_lights_up"): world._slate_lights_up()
	radio.handlers["parachute"] = func(_args: Array) -> void:
		var drop: Node = world.get("storm_drop")
		if drop != null: drop.parachute_thought()
	radio.handlers["survey_start"] = func(_args: Array) -> void:
		if survey_from >= 0: return
		survey_from = MHChapterOne.cores.size()
		# Cored good ice by the module before she asked? That's the module's ice.
		var module: Node = world.get("module_life")
		if not is_inf(ice_spot.x) or module == null or (module.zone() as Dictionary).is_empty(): return
		var centre: Vector3 = module._centre()
		for core in MHChapterOne.cores:
			if bool(core.get("good", false)) and Vector2(float(core.x) - centre.x, float(core.z) - centre.z).length() <= ICE_REACH:
				ice_spot = Vector3(float(core.x), MHSiteTerrain.height(float(core.x), float(core.z)), float(core.z))
				radio.flags["cored_already"] = true
				break
	radio.handlers["ice_spot"] = func(_args: Array) -> void: _mark_ice_spot()
	radio.handlers["walker_tracks"] = func(_args: Array) -> void: _mark_tracks()
	radio.handlers["owner_notes"] = func(_args: Array) -> void:
		var texts: Node = world.get("orbiter_texts")
		if texts == null: return
		for note in OWNER_NOTES: texts.send(str(note[0]), str(note[1]), str(note[2]))
	radio.handlers["pallet6"] = func(_args: Array) -> void: _drop_pallet6()
	radio.handlers["think"] = func(args: Array) -> void:
		var notes: Node = world.get("notes")
		if notes != null and not args.is_empty(): notes.think(str(args[0]))

## Sol 1 only (21 Nov): the first night is guided to bed; after that
## the nights are yours, and the cabin just offers rest (scripts/notes.gd).
func bed_led() -> bool:
	return guided() and (not v2() or nights < 1)

## The day's beats are done and the call's over: time for bed.
func _bed_now() -> void:
	var notes: Node = world.get("notes")
	if notes == null or not bed_led(): return
	bed_sol = int(notes.call("_sol")) if v2() else maxi(int(notes.call("_sol")), nights + 1)
	notes.think("bed", "start", {"home": _home_name()})

## What has to happen before the sun may go down.
func day_done(day: int) -> bool:
	var pod: Node = world.get("lifepod")
	match day:
		1:
			var drop: Node = world.get("storm_drop")
			var field: Node = world.get("drop_field")
			if drop != null and drop.pallet != null and not bool(drop.pallet.opened): return false
			if field != null:
				for kind in ["power", "tools"]:
					if field.sites.has(kind) and not bool(field.sites[kind].pallet.opened): return false
			return pod == null or (pod.jobs as Dictionary).has("tow")
		2:
			if not _gary_found(): return false
			var crate: Node = field_crate()
			if crate != null: return bool(crate.opened)   # the spares crate, towed home and opened
			return pod == null or bool(pod.walker_due) or bool(pod.walker_moved)
		3:
			# A6: set right, patched, ridden home and sent to the spot you chose.
			var walker: Node = world.get("walker")
			return walker == null or str(walker.state) in ["travelling", "parked", "carrying", "lowering", "done"]
		4: return _done("module") and _commissioned() and quarters_built()
	return true

## A6, chapter 4: a Quarters liner with its bunk inside, at Walker 1's base.
func quarters_built() -> bool:
	var builder: Node = world.get("builder")
	if builder == null: return true
	for z in builder.zones:
		if str(z.get("kind", "")) != "living" or str(z.get("base", "w1")) != "w1" or bool(z.get("arriving", false)): continue
		for item in builder.placed_interior:
			if str(item.get("id", "")) != "crew_bunk": continue
			var at: Vector3 = item.get("position", Vector3.ZERO)
			var cell := Vector2i(roundi(at.x / builder.CELL), roundi(at.z / builder.CELL))
			if (z.cells as Array).has(cell): return true
	return false

## Day 4: the core holds air and has power (scripts/module_life.gd).
func _commissioned() -> bool:
	var module: Node = world.get("module_life")
	return module != null and bool(module.commissioned)

## Version 2: the chapter, on the real sun.
func _chapter_tick(sol: int, hour: float, sunrise: float, sunset: float) -> void:
	var radio := _radio()
	_story_clock(-1.0, false)   # the sun never waits (and an old save's hold lets go)
	if radio != null and started.has(3) and not radio.flag("surveyed") and _surveyed_near_home(): radio.flags["surveyed"] = true
	# Chapters 2 and 3 side by side: what she can say about GAR-Y (data/radio/day3.txt).
	if radio != null:
		var met := _gary_found()
		if met: radio.flags["gary_met"] = true
		else: radio.flags.erase("gary_met")
		if met and not radio.flag("surveyed"): radio.flags["ask_gary"] = true
		else: radio.flags.erase("ask_gary")
	var run := _hours_run()
	if last_morning <= UNSET: last_morning = run
	var busy: bool = radio != null and (radio.on_air() or not (radio.queue as Array).is_empty())
	_open_chapters(sol, hour, sunrise, sunset, busy)
	if _idle_from <= UNSET: _idle_from = run
	var done := chapter_done(chapter)
	# Morning: one next step, offered on the slate (Ask Castle), not pushed.
	# She raises it herself only after a long while with nothing moving.
	if hour >= sunrise - 1.5 and hour < 12.0 and run - last_morning >= MORNING_GAP and not busy:
		last_morning = run
		_idle_from = run
		if not done and chapter == 1 and radio != null: _offer_next(radio)   # sol 1 is still guided
	if radio != null and not busy and run - _idle_from >= IDLE_HOURS and hour >= sunrise and hour < sunset - 1.0 and _open_now() > 0:
		_idle_from = run
		_offer_next(radio)
	for n in started:
		if not finished.has(int(n)): _day_calls(int(n), hour, sunrise)
	if started.has(PRINT_CHAPTER) and not finished.has(PRINT_CHAPTER) and radio != null:
		_chapter_five(radio, hour, sunrise, sunset, busy, false)
	# Day 1: on Rao's rise.
	if not sunset_reached and not is_inf(sunset_spot.x):
		var you: Vector3 = (world.player as Node3D).global_position
		if Vector2(you.x - sunset_spot.x, you.z - sunset_spot.z).length() < SPOT_REACH:
			sunset_reached = true
			if radio != null: radio.flags["on_the_rise"] = true
			var known: Node = world.get("known")
			if known != null: known.finish("sunset_spot")
	if radio == null: return
	# Day 1 asks for a photo of the sun going down: call while it's still above
	# the hills (playtest 14 Nov: it had gone behind them by the time she asked).
	# Dusk, once a sol (A6): the first sunset talk once the cargo's home; the
	# three horizons once chapter 4's done; else a short good night from
	# wherever the story is.
	var first_sunset := not (radio.heard as Dictionary).has("d1_sunset")
	var call_at := sunset - (CALL_BEFORE_SUNSET + DAY1_SUN_EARLIER if first_sunset else CALL_BEFORE_SUNSET)
	if dusk_sol != sol and hour >= call_at and hour < sunset + 3.0 and not busy:
		dusk_sol = sol
		if started.has(STORY_DAYS) and not finished.has(STORY_DAYS) and day_done(STORY_DAYS):   # the finale's talk first, even on a first sunset
			sunset_called = STORY_DAYS
			radio.ring("d4_sunset")
		elif first_sunset and chapter_done(1):
			sunset_called = maxi(sunset_called, 1)
			# Entirely optional: a talk wherever you are; a picture only if you're out.
			if _in_cabin(): radio.flags["indoors"] = true
			elif not is_inf(sunset_spot.x) and not sunset_reached: radio.flags["missed_rise"] = true
			radio.ring("d1_sunset")
		else:
			_leftover_flags(radio)
			radio.heard.erase("d%d_dusk" % chapter)
			radio.ring("d%d_dusk" % chapter)

## 21 Nov: game hours with no chapter opened or finished before Castle
## offers the next step herself (about five real minutes).
const IDLE_HOURS := 4.0
var _idle_from := UNSET

## What each chapter needs before its first call. Sol 1 is guided; then the
## rest open as soon as what they truly need is there, side by side.
func _may_open(n: int, sol: int) -> bool:
	match n:
		2, 3: return finished.has(1) and (nights >= 1 or sol >= 2)
		4: return finished.has(3)
		5: return day_done(4) and _gary_found()   # a base to put it in, and GAR-Y to tow its crate
	return false

## Chapters done open and close; one new chapter's first call at a time.
func _open_chapters(sol: int, hour: float, sunrise: float, sunset: float, busy: bool) -> void:
	var radio := _radio()
	for n in [1, 2, 3]:
		if not started.has(n) or finished.has(n) or not chapter_done(n): continue
		# Chapter 1 closes with its "proper day's work" call (_day_calls).
		if n == 1 and radio != null and not (radio.heard.has("d1_cargo") or radio.playing == "d1_cargo" or (radio.queue as Array).has("d1_cargo")): continue
		_finish(n)
	if not busy and hour >= sunrise - 1.0 and hour < sunset - LATE_START:
		for n in range(2, PRINT_CHAPTER + 1):
			if not started.has(n) and _may_open(n, sol):
				started.append(n)
				_idle_from = _hours_run()
				if n == PRINT_CHAPTER and finished.has(STORY_DAYS) and radio != null: radio.flags["real_bed"] = true
				break   # the next one waits for this one's call to end
	_recount()

func _finish(n: int) -> void:
	if not finished.has(n): finished.append(n)
	_idle_from = _hours_run()
	_recount()

func _recount() -> void:
	chapter = 1
	while finished.has(chapter): chapter += 1

## The first chapter that's open and not over, or 0.
func _open_now() -> int:
	for n in range(1, PRINT_CHAPTER + 1):
		if started.has(n) and not finished.has(n): return n
	return 0

## Castle's "what I'd do next": the first open chapter's recap.
func _offer_next(radio: Node) -> void:
	var n := _open_now()
	if n <= 0: return
	var keep := chapter
	chapter = n
	_leftover_flags(radio)
	chapter = keep
	if n == PRINT_CHAPTER:
		for key in (radio.flags as Dictionary).keys():
			if str(key).begins_with("left_"): radio.flags.erase(key)
		radio.flags[_chapter_five_left()] = true
	# 21 Nov playtest: "Morning, sleep okay?" at 1:30 pm on sol 1. Only a real
	# morning, after a night's sleep, opens with "morning".
	var hour := MHGame.sol_hour
	var sunrise := float(_cycle().get("sunrise_hour", 5.0))
	if hour >= sunrise - 1.5 and hour < sunrise + 3.0 and nights >= 1: radio.flags["morning"] = true
	else: radio.flags.erase("morning")
	var id := "d%d_still" % n
	radio.heard.erase(id)
	radio.ring(id)

## The slate's Ask Castle (Today page): true if she'll call.
func ask_next() -> bool:
	var radio := _radio()
	if radio == null or radio.on_air() or not (radio.queue as Array).is_empty() or _open_now() <= 0: return false
	if radio.has_method("in_contact") and not bool(radio.in_contact()): return false
	_idle_from = _hours_run()
	_offer_next(radio)
	return true

## The open goals for the slate's Today page: what I could do now, in any
## order, and what each still needs. First person: these are my thoughts.
func open_goals() -> Array:
	if not v2() or world.get("walker") == null: return []
	var out := []
	var pod: Node = world.get("lifepod")
	var walker: Node = world.get("walker")
	var state := str(walker.state) if walker != null else "done"
	if started.has(2) and not finished.has(2):
		var crate: Node = field_crate()
		if not _gary_found(): out.append({"text": "Find whatever Rao saw moving, out by the boulders past the pallets.", "needs": ""})
		elif crate != null and not bool(crate.opened):
			var hitch: bool = pod != null and (pod.prints as Dictionary).has("hitch")
			out.append({"text": "Get the spares crate home behind GAR-Y.", "needs": "" if hitch else "a hitch for GAR-Y: scrap into the lander's printer"})
	if started.has(3) and not finished.has(3):
		match state:
			"stalled": out.append({"text": "Follow the walker tracks and get its nav working.", "needs": ""})
			"coming": out.append({"text": "Find what's wrong in Walker 1's running gear, and patch it.", "needs": "photos for Castle, one part at a time"})
			"walking": out.append({"text": "Ride Walker 1 home.", "needs": ""})
			"ready": out.append({"text": "Choose where home goes, on the Map.", "needs": ""})
	if started.has(4) and not finished.has(4):
		if state == "travelling": out.append({"text": "Meet Walker 1 at the spot I chose.", "needs": ""})
		elif not _done("module"): out.append({"text": "See the module set down.", "needs": ""})
		elif not _commissioned(): out.append({"text": "Get air and power into the module.", "needs": ""})
		elif not quarters_built(): out.append({"text": "A Quarters liner with a bunk in it.", "needs": ""})
		else: out.append({"text": "A first night in a real bed.", "needs": ""})
	if not started.has(PRINT_CHAPTER) and started.has(3):
		var needs := []
		if not day_done(4): needs.append("a base with air and a bunk")
		if not _gary_found(): needs.append("GAR-Y, to tow")
		out.append({"text": "Something that makes things: the Print Shop.", "needs": ", ".join(needs) if not needs.is_empty() else "Castle's next drop"})
	if started.has(PRINT_CHAPTER) and not finished.has(PRINT_CHAPTER) and (world.get("radio") == null or (world.radio.heard as Dictionary).has("d5_wake")):
		var words := {"left_pallet": "Open pallet 6.", "left_tow": "Tow the Print Shop crate home behind GAR-Y.", "left_place": "Set the Print Shop and its intake down in the base.", "left_extractor": "Print the ice extractor and set it down.", "left_print": "Print the ice extractor and set it down."}
		out.append({"text": str(words.get(_chapter_five_left(), "")), "needs": ""})
	return out

func _hours_run() -> float:
	var builder: Node = world.get("builder")
	return float(builder.simulation().hours_run) if builder != null and builder.has_method("simulation") else 0.0

## R2 (docs/intro-rework.md §3): the facts the day scripts test, worked out
## as each line plays rather than when its call was rung. They stand in for
## the old flags of the same names (a fact wins over a flag).
const LEFT_FACTS := ["left_air", "left_power", "left_tools", "left_cargo", "left_gary", "left_hitch", "left_crate", "left_walker", "left_photo", "left_patch", "left_ride", "left_home", "left_walk", "left_down", "left_quarters", "left_pallet", "left_tow", "left_place", "left_print", "left_extractor"]
func _radio_facts(radio: Node) -> void:
	for key in LEFT_FACTS:
		var k: String = key
		radio.facts[k] = func(_args: Array) -> bool: return _left_for_call().has(k)
	# A real morning, after a night's sleep (21 Nov playtest: "Morning" at 1:30 pm).
	radio.facts["morning"] = func(_args: Array) -> bool:
		var sunrise := float(_cycle().get("sunrise_hour", 5.0))
		return nights >= 1 and MHGame.sol_hour >= sunrise - 1.5 and MHGame.sol_hour < sunrise + 3.0
	# Rao's pass "at dawn" only if it's still early.
	radio.facts["dawn"] = func(_args: Array) -> bool: return MHGame.sol_hour < float(_cycle().get("sunrise_hour", 5.0)) + 2.0
	radio.facts["indoors"] = func(_args: Array) -> bool: return not bool(radio.call("_outside"))
	radio.facts["on_the_rise"] = func(_args: Array) -> bool: return not is_inf(sunset_spot.x) and _player_within(sunset_spot, SPOT_REACH * 1.5)
	radio.facts["missed_rise"] = func(_args: Array) -> bool: return not is_inf(sunset_spot.x) and not _player_within(sunset_spot, SPOT_REACH * 1.5) and bool(radio.call("_outside"))
	radio.facts["has_scrap"] = func(_args: Array) -> bool:
		var pod: Node = world.get("lifepod")
		return pod != null and int(pod.parts) > 0
	radio.facts["cargo_early"] = func(_args: Array) -> bool: return _light_left() > 4.0
	radio.facts["late_cargo"] = func(_args: Array) -> bool: return _light_left() < 1.2
	radio.facts["cargo_mid"] = func(_args: Array) -> bool: return _light_left() >= 1.2 and _light_left() <= 4.0
	radio.facts["has_slate"] = func(_args: Array) -> bool:
		var slate: Node = world.get("pda")
		return slate != null and bool(slate.received)
	radio.facts["helmet"] = func(_args: Array) -> bool:
		var suit: Node = world.get("suit")
		return suit != null and bool(suit.get("helmet"))
	# The air cartridge already down by the lander (or plugged in).
	radio.facts["cartridge_home"] = func(_args: Array) -> bool:
		var cartridge: Node3D = get_tree().get_first_node_in_group("o2_cartridge")
		var lander: Node3D = world.get("lander")
		if cartridge == null or lander == null: return false
		if str(cartridge.get("where")) == "plugged": return true
		return str(cartridge.get("where")) == "ground" and cartridge.global_position.distance_to(lander.global_position) < 40.0
	radio.facts["core_air"] = func(_args: Array) -> bool:
		var module: Node = world.get("module_life")
		return module != null and bool(module.has_cartridge())
	radio.facts["core_power"] = func(_args: Array) -> bool:
		var module: Node = world.get("module_life")
		return module != null and bool(module.has_blanket())
	radio.facts["knows"] = func(args: Array) -> bool:
		var known: Node = world.get("known")
		return known != null and not args.is_empty() and bool(known.knows(":".join(args)))

func _light_left() -> float:
	return float(_cycle().get("sunset_hour", 19.0)) - MHGame.sol_hour

func _player_within(at: Vector3, metres: float) -> bool:
	var you: Vector3 = (world.player as Node3D).global_position
	return Vector2(you.x - at.x, you.z - at.z).length() < metres

func _site_pallet(kind: String) -> Variant:
	var field: Node = world.get("drop_field")
	return field.sites[kind].pallet if field != null and field.sites.has(kind) else null

## What's left of the chapter the call on air belongs to (d3_still: chapter 3).
func _left_for_call() -> Array:
	var radio := _radio()
	var n := chapter
	var playing := str(radio.playing) if radio != null else ""
	if playing.length() > 2 and playing[0] == "d" and playing[1].is_valid_int(): n = int(playing[1])
	if n == PRINT_CHAPTER: return [_chapter_five_left()]
	return _left_now(n)

## What's still to do in this chapter, for Castle's recap (left_* flags).
func _leftover_flags(radio: Node) -> void:
	for key in (radio.flags as Dictionary).keys():
		if str(key).begins_with("left_"): radio.flags.erase(key)
	for f in _left_now(chapter): radio.flags[f] = true

func _left_now(n: int) -> Array:
	var field: Node = world.get("drop_field")
	var drop: Node = world.get("storm_drop")
	var pod: Node = world.get("lifepod")
	var walker: Node = world.get("walker")
	var left := []
	match n:
		1:
			if drop != null and drop.pallet != null and not bool(drop.pallet.opened): left.append("left_air")
			if field != null and field.sites.has("power") and not bool(field.sites.power.pallet.opened): left.append("left_power")
			if field != null and field.sites.has("tools") and not bool(field.sites.tools.pallet.opened): left.append("left_tools")
			if left.is_empty(): left.append("left_cargo")
		2:
			var crate: Node = field_crate()
			if not _gary_found(): left.append("left_gary")
			elif crate != null and not bool(crate.opened):
				left.append("left_crate" if pod != null and (pod.prints as Dictionary).has("hitch") else "left_hitch")
		3:
			var state := str(walker.state) if walker != null else "done"
			if state == "stalled": left.append("left_walker")
			elif state == "coming": left.append("left_patch" if bool(walker.get("fault_found")) else "left_photo")
			elif state == "walking": left.append("left_ride")
			elif state == "ready": left.append("left_home")
		4:
			var state := str(walker.state) if walker != null else "done"
			if state == "travelling": left.append("left_walk")
			elif not _done("module"): left.append("left_down")
			elif not _commissioned(): left.append("left_power")
			elif not quarters_built(): left.append("left_quarters")
	return left

## The calls that come as the day goes.
func _day_calls(day: int, hour: float, sunrise: float) -> void:
	var radio := _radio()
	if radio == null: return
	var field: Node = world.get("drop_field")
	var drop: Node = world.get("storm_drop")
	var pod: Node = world.get("lifepod")
	if day == 1:
		# The slate's in your hands after the first call: Castle talks you out
		# (also mends an older save with the slate taken and no d1_slate yet).
		var slate: Node = world.get("pda")
		if (radio.heard as Dictionary).has("d1_relock") and radio.playing != "d1_relock" and slate != null and bool(slate.received) and not bool(slate.get("is_open")) and not (radio.heard as Dictionary).has("d1_slate"):
			var cabin: Node = world.get("lander")
			var me: Node3D = world.get("player")
			if cabin != null and me != null and bool(cabin.cabin_contains(me.global_position)): radio.ring("d1_slate")
			else: radio.heard["d1_slate"] = true   # already outside (an older save): nothing to talk you out of
		if drop != null and drop.pallet != null and bool(drop.pallet.opened):
			# 15 Nov playtest: she notices if you've stripped scrap already.
			if pod != null and int(pod.parts) > 0: radio.flags["has_scrap"] = true
			radio.ring("d1_pallet1")
		if field != null and field.sites.has("power") and bool(field.sites.power.pallet.opened): radio.ring("d1_pallet2")
		if field != null and field.sites.has("tools") and bool(field.sites.tools.pallet.opened): radio.ring("d1_pallet4")
		# "A proper day's work" only once pallet 4's been opened too (playtest 14 Nov).
		if pod != null and (pod.jobs as Dictionary).has("tow") and day_done(1): radio.ring("d1_cargo")
	# A6: each chapter's first call comes when it starts, by day (the next
	# chapter never starts after dark: see _chapter_tick).
	elif day == 2 and hour >= sunrise - 1.0 and not bool(world.get("gary_met")):
		radio.ring("d2_wake")
	elif day == 3 and hour >= sunrise - 1.0:
		# R4 (docs/intro-rework.md §4): Rao's tracks report comes once you're
		# back by the lander, or once GAR-Y's call is over, whichever is first;
		# never on top of the GAR-Y morning call.
		var lander: Node3D = world.get("lander")
		var by_home := lander != null and _player_within(lander.global_position, TRACKS_CALL_NEAR)
		var after_gary: bool = (radio.heard as Dictionary).has("d2_found") and radio.playing != "d2_found"
		var gary_call: bool = radio.playing in ["d2_wake", "d2_found"] or (radio.queue as Array).has("d2_wake") or (radio.queue as Array).has("d2_found")
		if (by_home or after_gary) and not gary_call: radio.ring("d3_wake")
	elif day == 4:
		# Walker 1 walks to your spot (scripts/walker.gd rings d4_arrived and
		# d4_down); the core alive rings d4_patched (scripts/module_life.gd).
		if _done("module") and _commissioned() and quarters_built() and not (radio.heard as Dictionary).has("d4_quarters"):
			_bunk_flags(radio)
			radio.ring("d4_quarters")

# ---------- chapter 5 and after ----------

## Chapter 5's beats and, after it, the morning "what's next" (not guided:
## the night is free).
func _after_chapters() -> void:
	if not v2() or chapter < PRINT_CHAPTER or world.get("walker") == null: return
	var radio := _radio()
	var notes: Node = world.get("notes")
	if radio == null or notes == null: return
	var hour := MHGame.sol_hour
	var sunrise := float(_cycle().get("sunrise_hour", 5.0))
	var sunset := float(_cycle().get("sunset_hour", 19.0))
	var busy: bool = radio.on_air() or not (radio.queue as Array).is_empty()
	var run := _hours_run()
	if last_morning <= UNSET: last_morning = run
	var morning: bool = hour >= sunrise - 1.5 and hour < 12.0 and run - last_morning >= MORNING_GAP and not busy
	if morning: last_morning = run
	_next_thoughts(notes)
	if chapter == PRINT_CHAPTER:
		if not started.has(PRINT_CHAPTER): started.append(PRINT_CHAPTER)
		_chapter_five(radio, hour, sunrise, sunset, busy, morning)
	elif morning:
		_morning_next(radio)

func _print_shop_placed() -> bool:
	return not MHChapterOne.fabricators(world.get("builder")).is_empty()

func _zone_placed(kind: String) -> bool:
	var builder: Node = world.get("builder")
	if builder == null: return false
	for z in builder.zones:
		if str(z.get("kind", "")) == kind and not bool(z.get("arriving", false)): return true
	return false

func _chapter_five(radio: Node, hour: float, sunrise: float, sunset: float, busy: bool, morning: bool) -> void:
	var heard: Dictionary = radio.heard
	# An older save that had a Print Shop already: nothing to find.
	if not heard.has("d5_wake") and _print_shop_placed():
		_finish(PRINT_CHAPTER)
		return
	if not heard.has("d5_wake"):
		if not busy and hour >= sunrise - 1.0 and hour < sunset - LATE_START: radio.ring("d5_wake")
		return
	if _zone_placed("ice_extractor"):
		if not heard.has("d5_water"): radio.ring("d5_water")
		_finish(PRINT_CHAPTER)
		return
	if _print_shop_placed() and _zone_placed("regolith_intake"): radio.ring("d5_printing")
	if MHChapterOne.available("ice_drill", world.get("builder")) > 0: radio.ring("d5_extractor")
	if morning:
		for key in (radio.flags as Dictionary).keys():
			if str(key).begins_with("left_"): radio.flags.erase(key)
		radio.flags[_chapter_five_left()] = true
		_offer_next(radio)

## What's left of chapter 5, for the morning recap.
func _chapter_five_left() -> String:
	var field: Node = world.get("drop_field")
	var site: Node = field.sites.get("print_shop") if field != null else null
	if site != null and not bool(site.pallet.opened): return "left_pallet"
	var crate: Node = field.get("print_crate") if field != null else null
	if crate != null and is_instance_valid(crate) and not bool(crate.opened): return "left_tow"
	if not (_print_shop_placed() and _zone_placed("regolith_intake")): return "left_place"
	if MHChapterOne.available("ice_drill", world.get("builder")) > 0: return "left_extractor"
	return "left_print"

## Castle's d5_wake: pallet 6 comes down on Rao's pass, on the map.
func _drop_pallet6() -> void:
	var field: Node = world.get("drop_field")
	if field == null or not field.has_method("add_print_shop"): return
	var site: Node = field.add_print_shop()
	var known: Node = world.get("known")
	if known != null and site != null: known.learn(site.id(), "find", field.region_at(site.at), "Pallet 6", "you", "castellanos")

## After the chapters: one short "what I'd do next" each morning, the first
## that fits and hasn't been said (each is said once, so it never nags).
func _morning_next(radio: Node) -> void:
	for id in _next_steps():
		if not (radio.heard as Dictionary).has(id):
			radio.ring(id)
			return

## The next steps that fit the base now, most useful first.
func _next_steps() -> Array:
	var out: Array = []
	if not MHRoomTypes.is_fitted("water_loop"):
		out.append("next_water_loop" if MHRoomTypes.plan_known("water_loop") else "next_water_wait")
	if MHRoomTypes.plan_known("heavy_power") and not MHRoomTypes.is_fitted("heavy_power"): out.append("next_heavy_power")
	if MHMaterials.metal_kg < 30.0 and not MHChapterOne.plan_known("smelter"): out.append("next_metal")
	if MHChapterOne.feedstock_kg < 60.0: out.append("next_feedstock")
	if out.is_empty(): out.append("next_explore")
	return out

## The inner voice on what the base is short of (data/notes.json next_*):
## each a thought while it's true, answered once it isn't.
const NEXT_THOUGHTS := {
	"next_feedstock": "_short_feedstock",
	"next_metal": "_short_metal",
	"next_rack": "_upgrade_waiting",
}
func _next_thoughts(notes: Node) -> void:
	if chapter < PRINT_CHAPTER: return
	var builder: Node = world.get("builder")
	if builder == null or not _print_shop_placed(): return
	for id in NEXT_THOUGHTS:
		var now: bool = call(str(NEXT_THOUGHTS[id]))
		if now and not notes.is_open(id): notes.think(id)
		elif not now and notes.is_open(id): notes.answer(id)

func _short_feedstock() -> bool:
	return MHChapterOne.feedstock_kg < 30.0 and not MHChapterOne.printing()

func _short_metal() -> bool:
	return MHMaterials.metal_kg < 15.0

func _upgrade_waiting() -> bool:
	for up in MHRoomTypes.UPGRADES:
		if MHRoomTypes.plan_known(str(up)) and not MHRoomTypes.is_fitted(str(up)) and MHRoomTypes.fit_reason(str(up)).is_empty(): return true
	return false

## GAR-Y's ice stakes out round the lander (chapter 3: find the water, then
## choose where the module goes).
const SURVEY_NEAR := 600.0
func _surveyed_near_home() -> bool:
	var stakes: Node = world.get("survey_stakes")
	if stakes == null or world.get("lander") == null: return false
	var home: Vector3 = world.lander.global_position
	for stake in stakes.get("_stakes"):
		var at: Vector3 = stake.at
		if Vector2(at.x - home.x, at.z - home.z).length() < SURVEY_NEAR: return true
	return false

## Day 1, the cargo home: a rise towards the sun, near enough to walk to
## and back before dark, marked on your compass (data/radio/day1.txt).
func _mark_sunset_spot() -> void:
	if not is_inf(sunset_spot.x): return
	var radio := _radio()
	var light_left := float(_cycle().get("sunset_hour", 19.0)) - MHGame.sol_hour
	if radio != null:
		for f in ["cargo_early", "cargo_mid", "late_cargo"]: radio.flags.erase(f)
		radio.flags["cargo_early" if light_left > 4.0 else ("late_cargo" if light_left < 1.2 else "cargo_mid")] = true
	if light_left < 1.2: return   # no time to walk to the rise: watch it from the ramp
	var home: Vector3 = world.lander.global_position
	var field: Node = world.get("drop_field")
	var toward := Vector3(-1, 0, 0)
	if field != null and field.get("sunset") != null: toward = field.sunset.sun_direction()
	var best := -INF
	for distance in range(70, 241, 20):
		for turn in range(-40, 41, 10):
			var d := toward.rotated(Vector3.UP, deg_to_rad(float(turn)))
			var p := home + d * float(distance)
			var h: float = MHSiteTerrain.height(p.x, p.z)
			var score := h - float(distance) * .02 - absf(float(turn)) * .02
			if score > best and MHSiteTerrain.reachable_on_foot(Vector2(home.x, home.z), Vector2(p.x, p.z)):
				best = score
				sunset_spot = Vector3(p.x, h, p.z)
	if is_inf(sunset_spot.x): sunset_spot = home + toward * 40.0
	var known: Node = world.get("known")
	if known != null and field != null: known.learn("sunset_spot", "place", field.region_at(sunset_spot), "Sunset view", "you", "castellanos")

## Day 4: where you put the bunk, for Castle's say on it.
func _bunk_flags(radio: Node) -> void:
	var builder: Node = world.get("builder")
	if builder == null: return
	var doors: Array = []
	for z in builder.zones:
		if str(z.get("kind", "")) == "airlock":
			for c in z.cells: doors.append(Vector3(c.x * builder.CELL, 0, c.y * builder.CELL))
	for item in builder.placed_interior:
		if str(item.get("id", "")) != "crew_bunk" or doors.is_empty(): continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var near := INF
		for d in doors: near = minf(near, Vector2(at.x - d.x, at.z - d.z).length())
		radio.flags["bunk_by_door" if near < BUNK_BY_DOOR else "bunk_quiet"] = true
		return

## Day 4: a good core near the module since Castle asked (or, after a few
## dry ones, the best of them) is its ice.
func _look_for_ice(radio: Node) -> void:
	var module: Node = world.get("module_life")
	if module == null or (module.zone() as Dictionary).is_empty(): return
	var centre: Vector3 = module._centre()
	var tried: Array = []
	for i in range(clampi(survey_from, 0, MHChapterOne.cores.size()), MHChapterOne.cores.size()):
		var core: Dictionary = MHChapterOne.cores[i]
		if Vector2(float(core.x) - centre.x, float(core.z) - centre.z).length() > ICE_REACH: continue
		if bool(core.get("good", false)):
			ice_spot = Vector3(float(core.x), 0, float(core.z))
			break
		tried.append(core)
	if is_inf(ice_spot.x) and tried.size() >= THIN_AFTER:
		var best: Dictionary = tried[0]
		for core in tried:
			if float(core.purity) > float(best.purity): best = core
		ice_spot = Vector3(float(best.x), 0, float(best.z))
		radio.flags["thin_ice"] = true
	if not is_inf(ice_spot.x):
		ice_spot.y = MHSiteTerrain.height(ice_spot.x, ice_spot.z)
		radio.ring("d4_ice")

func _mark_ice_spot() -> void:
	var known: Node = world.get("known")
	var field: Node = world.get("drop_field")
	if known != null and field != null and not is_inf(ice_spot.x): known.learn("ice_spot", "place", field.region_at(ice_spot), "Ice extractor spot", "you", "castellanos")

## Day 3: where Walker 1's tracks start, on the Map and compass (Rao's dawn pass).
func _mark_tracks() -> void:
	var walker: Node = world.get("walker")
	var known: Node = world.get("known")
	var field: Node = world.get("drop_field")
	if walker == null or known == null or field == null or bool(walker.get("seen")): return
	walker.lay_tracks()
	var pod: Node = world.get("lifepod")
	if pod != null: pod.walker_moved = true   # the opening's part 3 (mars_world.opening_part)
	known.learn("walker_tracks_start", "find", field.region_at(walker.tracks_start()), "Fresh tracks", "you", "castellanos")

func field_crate() -> Node:
	var field: Node = world.get("drop_field")
	var crate: Variant = field.get("crate") if field != null else null
	return crate if crate != null and is_instance_valid(crate) else null

## GAR-Y met for real (not just out at work, waiting to be found).
func _gary_found() -> bool:
	var field: Node = world.get("drop_field")
	return bool(world.get("gary_met")) and (field == null or not bool(field.gary_working))

func _story_clock(hold: float, fast: bool) -> void:
	var clock: Node = world.get("day_night")
	if clock == null: return
	clock.hold_at = hold
	if fast != _fast:
		_fast = fast
		clock.time_scale = DUSK_SPEED if fast else 1.0

## GAR-Y comes and leads you home, at your pace (scripts/companion_rover.gd).
func _lead_home() -> void:
	var player: Node3D = world.player
	var spot := _home_spot()
	if spot == Vector3.INF or _at_home() or player.global_position.distance_to(spot) < LEAD_FROM: return
	var gary := _gary()
	if gary == null or gary.has_meta("lift_out"): return
	var field: Node = world.get("drop_field")
	if field != null and field.get("sunset") != null and str(field.sunset.get("phase")) != "": return   # watching the sun first
	if not gary.leading_to(spot): gary.lead_to(spot, true)

func _in_cabin() -> bool:
	var lander: Node = world.get("lander")
	return lander != null and bool(lander.cabin_contains((world.player as Node3D).global_position))

func _at_home() -> bool:
	if _in_cabin(): return true
	var builder: Node = world.get("builder")
	return builder != null and int(world.opening_part()) >= 4 and builder.is_inside((world.player as Node3D).global_position)
