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

func export_state() -> Dictionary:
	return {"dawn_stage": dawn_stage, "bed_sol": bed_sol, "gary_waited_sol": gary_waited_sol, "arden_morning": arden_morning, "nights": nights}

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
	return world.get("walker") != null and stage() < STAGES.size()

## Living in the lander still: its hatch won't open from inside at night.
func in_lander_days() -> bool:
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
	return "Not in the dark yet. Sleep first."

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
	if bed_sol != day and ((dusk and now > dawn_stage) or late):
		bed_sol = day
		notes.think("bed", "start" if now > dawn_stage else "late", {"home": _home_name()})
	_lead_again -= CHECK_EVERY
	if notes.is_open("bed") and not _at_home() and _lead_again <= 0.0:   # again after the sunset, say
		_lead_again = 30.0
		_lead_home()
	if notes.is_open("bed") and _at_home() and in_lander_days():
		MHNotices.hint("Bed", "Look at a landing seat and press Z to sleep till morning.")
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
