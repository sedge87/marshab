extends Node

## The crew rover's radio: something to listen to on a long drive across an
## empty region, without filling every minute. It only talks while you're
## driving outside the vehicle bay, and its clock only runs while the rover
## is moving: the first call comes a minute or so out, then one every few
## minutes of driving (one or two a charge).
##
## What comes over it:
## - An orbiter's relay pass: the orbiter rises, Mission Control's messages
##   from Earth come through it (with the light delay, and not during a solar
##   conjunction blackout), and the pass ends.
## - Bulletins from orbit: the weather (the storm, if there is one) or dust
##   devils in the afternoon.
## - The habitat, at most once a trip each: when you're a long way out, and
##   when sunset is coming with you a drive from home.
##
## The lines are in data/voice_lines.json ("relay", Mission Control's "drive",
## the habitat's "rover_*"), spoken by tools/generate_voice.py.

const MISSION_CONTROL_LINK := preload("res://scripts/mission_control_link.gd")
const FIRST_AFTER := Vector2(40.0, 75.0)   # s of driving out before the first call
const EVERY := Vector2(110.0, 210.0)       # s of driving between calls after that
const FAR := 2000.0                        # m from the bay: "a long way out"
const SUNSET_SOON := .86                   # of the day gone (MHGame.daylight_progress)
const PASS_LENGTH := 26.0                  # s from a pass starting to its end call
const ORBITERS := ["Mars Reconnaissance Orbiter", "Mars Odyssey", "MAVEN", "Trace Gas Orbiter", "Mars Express"]

var rover: Node
var _wait := -1.0       # s of driving until the next call
var _said := {}         # this trip's once-only calls
var _pass_left := -1.0  # s until the current relay pass ends
var _orbiter := ""

func _process(delta: float) -> void:
	if rover == null or get_tree().paused: return
	if rover._in_bay():
		_said.clear()
		_wait = -1.0
		return
	if not bool(rover.driving): return
	if _pass_left > 0.0:
		_pass_left -= delta
		if _pass_left <= 0.0: MHAudio.relay("pass_end", _orbiter)
	if _wait < 0.0: _wait = randf_range(FIRST_AFTER.x, FIRST_AFTER.y)
	if absf(float(rover.speed)) > 1.0: _wait -= delta
	if _wait > 0.0 or _pass_left > 0.0: return
	_wait = randf_range(EVERY.x, EVERY.y)
	_call()

func _call() -> void:
	var at := Vector2(rover.global_position.x, rover.global_position.z)
	var home: Dictionary = rover._home()
	var out := at.distance_to(home.centre) if not home.is_empty() else at.length()
	var day := MHGame.daylight_progress(MHGame.sol_hour)
	if day > SUNSET_SOON and out > 600.0 and not _said.has("sunset"):
		_said["sunset"] = true
		MHAudio.voice("rover_sunset", "on the rover radio")
		return
	if out > FAR and not _said.has("far"):
		_said["far"] = true
		MHAudio.voice("rover_far", "on the rover radio")
		return
	var sim = rover.builder.simulation() if rover.builder != null else null
	var storm := sim != null and float(sim.storm_hours_left) > 0.0
	var roll := randf()
	if roll < .55 and _earth_in_contact(sim): _relay_pass(sim)
	elif storm: MHAudio.relay("storm", _pick_orbiter())
	elif roll < .8 and day > .4 and day < .8: MHAudio.relay("dust_devil", _pick_orbiter())
	else: MHAudio.relay("weather", _pick_orbiter())

## An orbiter comes over: its pass begins, Earth's message comes through it,
## and in a little while it ends.
func _relay_pass(sim) -> void:
	_pick_orbiter()
	MHAudio.relay("pass_start", "%s · pass of %d min" % [_orbiter, randi_range(8, 14)])
	var one_way := MISSION_CONTROL_LINK.one_way_minutes(float(sim.hours_run) / 24.0 if sim != null else 0.0)
	MHAudio.radio("drive", "sent %d min ago · via %s" % [roundi(one_way), _orbiter])
	_pass_left = PASS_LENGTH

func _pick_orbiter() -> String:
	_orbiter = ORBITERS[randi() % ORBITERS.size()]
	return _orbiter

## No messages from Earth while the Sun is between us (scripts/mission_control_link.gd).
func _earth_in_contact(sim) -> bool:
	if sim == null or sim.get("life") == null: return true
	return float(sim.life.blackout_hours_left) <= 0.0
