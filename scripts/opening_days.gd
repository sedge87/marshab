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
## out. While you live in the lander (opening parts 1-2), its hatch won't
## open from inside at night: the day ends when you sleep. Once the module's
## fitted out, nights are yours again (docs/master-design.md §2).

## The guided days, version 2 (docs/opening-days.md, 8 Nov redesign), for
## new games: story time holds the sun until the day's beats are done, then
## brings dusk and Castellanos's sunset call (data/radio/day1.txt, day2.txt).
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
const HOLD_BEFORE_SUNSET := 2.0 # the sun waits here till the day's done
const CALL_BEFORE_SUNSET := .6  # Castellanos's sunset call
const DUSK_SPEED := 8.0         # the clock's pace to dusk once the day's done

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
const SPOT_REACH := 18.0         # this close to the rise and you're there
const PHOTO_WAIT := 50.0         # seconds Castellanos waits for the picture
var survey_from := -1            # day 4: cores taken from here on (MHChapterOne.cores) count for the module's ice
var ice_spot := Vector3.INF      # day 4: the module's ice, found
const ICE_REACH := 400.0         # this near the module, a core's the module's ice
const THIN_AFTER := 3            # cores with no good ice: the best of them will do
const BUNK_BY_DOOR := 4.5        # metres from the airlock: the bunk's "by the door"
## Day 4's notes from the crew, each from the goal's owner (data/orbiter_crew.json).
const OWNER_NOTES := [
	["d4_note_tupou", "tupou", "Life's mine, then. If you see anything at all that looks odd, layered, crusty, a funny colour, photograph it before you touch it. Please. I'll explain why later. At length."],
	["d4_note_rao", "rao", "Climate. Every pass, I'm looking at your sky as well as for walkers. Tell me when the dust is up and when the frost is down. That's half my data, from you."],
	["d4_note_achterberg", "achterberg", "Geology, and building with it. Your printer eats regolith. Find me good dirt and I'll find you things to make out of it. Also: well done on the seam."],
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
	var ice: Array = saved.get("ice_spot", [])
	if ice.size() == 3: ice_spot = Vector3(float(ice[0]), float(ice[1]), float(ice[2]))

func export_state() -> Dictionary:
	return {"dawn_stage": dawn_stage, "bed_sol": bed_sol, "gary_waited_sol": gary_waited_sol, "arden_morning": arden_morning, "nights": nights, "version": version, "sunset_called": sunset_called, "sunset_reached": sunset_reached, "sunset_spot": [] if is_inf(sunset_spot.x) else [sunset_spot.x, sunset_spot.y, sunset_spot.z],
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
	if v2(): return nights < STORY_DAYS
	return stage() < STAGES.size()

## Living in the lander still: its hatch won't open from inside at night.
func in_lander_days() -> bool:
	if v2(): return guided() and nights <= 2 and int(world.opening_part()) <= 3
	return guided() and world.has_method("opening_part") and int(world.opening_part()) <= 2

func _cycle() -> Dictionary:
	return MHGame.site().get("day_cycle", {})

func is_night() -> bool:
	var hour := MHGame.sol_hour
	return hour >= float(_cycle().get("sunset_hour", 19.0)) + .5 or hour < float(_cycle().get("sunrise_hour", 5.0))

## Why the lander's hatch won't open for you now, or "" (scripts/crew_lander.gd).
func hatch_refusal() -> String:
	if not in_lander_days() or not is_night(): return ""
	var lander: Node = world.get("lander")
	var player: Node3D = world.get("player")
	if lander == null or player == null or not bool(lander.cabin_contains(player.global_position)): return ""
	return "Not out there in the dark. Sleep first, and go at sunrise."

## Home tonight: the lander, or the module once it's down.
func _home_name() -> String:
	return "the lander" if int(world.opening_part()) <= 3 else "the module"

func _home_spot() -> Vector3:
	var lander: Node = world.get("lander")
	if int(world.opening_part()) <= 3 and lander != null: return lander.ramp_foot(3.0)
	var gary := _gary()
	return gary._airlock_waiting_spot() if gary != null else Vector3.INF

func _gary() -> Node:
	return get_tree().get_first_node_in_group("gar_y")

# ---------- the day ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null or get_tree().paused: return
	_check = CHECK_EVERY
	if not guided(): return
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
	# Dusk: the day's done (or it's too late to finish it). Bed.
	var dusk := hour >= sunset - DUSK_EARLY and hour < sunset + 6.0
	var late := hour >= sunset or hour < sunrise
	var day := maxi(sol, nights + 1)
	if v2() and day <= STORY_DAYS:
		_story_day(day, hour, sunrise, sunset)
		var radio := _radio()
		var sunset_due: bool = radio != null and (radio.on_air() or (radio.queue as Array).has("d%d_sunset" % day))
		if late and bed_sol != day and not sunset_due:
			bed_sol = day
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
	radio.handlers["parachute"] = func(_args: Array) -> void:
		var drop: Node = world.get("storm_drop")
		if drop != null: drop.parachute_thought()
	radio.handlers["survey_start"] = func(_args: Array) -> void:
		if survey_from < 0: survey_from = MHChapterOne.cores.size()
	radio.handlers["ice_spot"] = func(_args: Array) -> void: _mark_ice_spot()
	radio.handlers["owner_notes"] = func(_args: Array) -> void:
		var texts: Node = world.get("orbiter_texts")
		if texts == null: return
		for note in OWNER_NOTES: texts.send(str(note[0]), str(note[1]), str(note[2]))
	radio.handlers["think"] = func(args: Array) -> void:
		var notes: Node = world.get("notes")
		if notes != null and not args.is_empty(): notes.think(str(args[0]))

## The day's beats are done and the call's over: time for bed.
func _bed_now() -> void:
	var notes: Node = world.get("notes")
	if notes == null: return
	bed_sol = maxi(int(notes.call("_sol")), nights + 1)
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
			var walker: Node = world.get("walker")
			if walker != null and str(walker.state) == "coming" and pod != null and not (pod.prints as Dictionary).has("seal"): return false
			return walker == null or bool(walker.marked) or str(walker.state) in ["parked", "carrying", "lowering", "done"]
		4: return _done("module") and _commissioned() and _done("fit_out") and not is_inf(ice_spot.x)
	return true

## Day 4: the module's leak patched and it's holding (scripts/module_life.gd).
func _commissioned() -> bool:
	var module: Node = world.get("module_life")
	return module != null and bool(module.commissioned)

func _story_day(day: int, hour: float, sunrise: float, sunset: float) -> void:
	var radio := _radio()
	_day_calls(day, hour, sunrise)
	if not day_done(day):
		# The sun waits for you; if it's already past the hold (an old save), let it go.
		_story_clock(sunset - HOLD_BEFORE_SUNSET if hour >= sunrise - 1.0 and hour <= sunset - HOLD_BEFORE_SUNSET + .01 else -1.0, false)
		return
	var call_at := sunset - CALL_BEFORE_SUNSET
	if _waiting_at_spot(day):
		_story_clock(call_at - .05, true)   # the sun waits for you to reach the rise
		return
	if hour >= sunrise - 1.0 and hour < call_at:
		_story_clock(-1.0, true)   # done: the sun goes down a little quicker
		return
	_story_clock(-1.0, false)
	if sunset_called < day and radio != null and hour >= call_at and hour < sunset + 3.0:
		sunset_called = day
		radio.ring("d%d_sunset" % day)

## The calls that come as the day goes.
func _day_calls(day: int, hour: float, sunrise: float) -> void:
	var radio := _radio()
	if radio == null: return
	var field: Node = world.get("drop_field")
	var drop: Node = world.get("storm_drop")
	var pod: Node = world.get("lifepod")
	if day == 1:
		if drop != null and drop.pallet != null and bool(drop.pallet.opened): radio.ring("d1_pallet1")
		if field != null and field.sites.has("power") and bool(field.sites.power.pallet.opened): radio.ring("d1_pallet2")
		if field != null and field.sites.has("tools") and bool(field.sites.tools.pallet.opened): radio.ring("d1_pallet4")
		if pod != null and (pod.jobs as Dictionary).has("tow"): radio.ring("d1_cargo")
	elif day == 2 and hour >= sunrise - 1.0 and not bool(world.get("gary_met")):
		radio.ring("d2_wake")
	elif day == 3 and hour >= sunrise - 1.0:
		radio.ring("d3_wake")
	elif day == 4 and hour >= sunrise - 1.0:
		var walker: Node = world.get("walker")
		if walker != null and str(walker.state) == "coming": walker.arrive_overnight()
		if walker != null and str(walker.state) == "parked" and bool(walker.marked) and not _in_cabin(): walker.deliver_marked()
		radio.ring("d4_wake")
		if _done("module"): radio.ring("d4_down")
		if _done("module") and _commissioned() and _done("fit_out") and not (radio.heard as Dictionary).has("d4_home"):
			_bunk_flags(radio)
			radio.ring("d4_home")
		if survey_from >= 0 and is_inf(ice_spot.x): _look_for_ice(radio)

## Day 1, the cargo home: a rise towards the sun, near enough to walk to
## and back before dark, marked on your compass (data/radio/day1.txt).
func _mark_sunset_spot() -> void:
	if not is_inf(sunset_spot.x): return
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

## Day 1 only: the sun holds just short of the call till you're on the rise
## (or you've gone in: then the call comes anyway).
func _waiting_at_spot(day: int) -> bool:
	if day != 1 or sunset_reached or sunset_called >= day: return false
	if is_inf(sunset_spot.x):
		var radio := _radio()
		return radio != null and (radio.playing == "d1_cargo" or (radio.queue as Array).has("d1_cargo"))   # it's being marked now
	var you: Vector3 = (world.player as Node3D).global_position
	if Vector2(you.x - sunset_spot.x, you.z - sunset_spot.z).length() < SPOT_REACH:
		sunset_reached = true
		var radio := _radio()
		if radio != null: radio.flags["on_the_rise"] = true
		var known: Node = world.get("known")
		if known != null: known.finish("sunset_spot")
		return false
	return not _in_cabin()

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
