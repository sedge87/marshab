extends Node

## Your suit's own life support (gameplay-loop brief §4). A basic suit: about
## two hours of oxygen, three of battery (half that at night, for the heater)
## and four on its CO2 scrubber cartridge. Nothing drains inside a sealed
## space (the habitat, the lander cabin, the rover's cab); outside, sprinting
## and carrying make you breathe harder, and a flat battery means a cold suit
## that burns oxygen faster.
##
## Nothing comes from nowhere: in a habitat airlock (or at a suit service
## panel or suit rack) the suit tops up from the habitat's oxygen and
## batteries; in the lander cabin, from the lander's tanks; in the rover's
## cab, or with G beside the rover, from the rover's own tank and battery.
##
## You learn how the suit is doing from the suit, not a HUD: hold T to raise
## your wrist pad (scripts/wrist_pad.gd), two soft LEDs at the edge of the
## visor (green, amber, red), the suit's voice and your breathing. A flat
## battery frosts the visor's edge.
##
## Out of oxygen in Survival you black out and come round in the airlock (the
## lander cabin before there's a habitat). Freedom warns but never lets you
## pass out; Creative and Missions don't run the suit.

const WRIST_PAD := preload("res://scripts/wrist_pad.gd")
const O2_HOURS := 2.0            # game hours of oxygen at a walk
const POWER_HOURS := 3.0         # by day; the heater doubles the draw at night
const SCRUBBER_HOURS := 4.0
const SPRINT := 1.6              # breathing harder
const CARRYING := 1.3
const COLD := 1.25               # a flat battery: no heater, more oxygen burned
const STALE := 1.5               # a spent scrubber: CO2 builds up
const NIGHT_POWER := 2.0
const O2_KG_PER_HOUR := 0.035    # what an hour of suit oxygen takes from a tank (0.84 kg a day)
const FULL_KWH := 1.0            # a full suit battery
const FILL_PER_S := 0.5          # share of a full suit an umbilical fills each second
const WALK := 5.0                # m/s, for the walk back
const MARGIN := 1.25             # the walk back, with a little to spare
const LOW := 0.25

var world: Node
## Each store as a share of a full suit (0 to 1).
var o2 := 1.0
var power := 1.0
var scrubber := 1.0
## Where you are: "outside", "habitat", "lander" or "rover".
var where := "habitat"
var passed_out := false
var pad: Node3D
var _last_hour := -1.0
var _said := {}                  # warnings given this trip outside
var _filling := false
var _breath: AudioStreamPlayer
var _breath_in := true
var _breath_wait := 0.0
var _layer: CanvasLayer
var _visor: Control
var _blink := 0.0
var _check := 0.0

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("suit")
	_breath = AudioStreamPlayer.new()
	_breath.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_breath)
	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)
	_visor = Control.new()
	_visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visor.draw.connect(_draw_visor)
	_layer.add_child(_visor)
	var camera := world.player.get_node("Head/Camera3D") as Camera3D
	pad = WRIST_PAD.new()
	pad.suit = self
	camera.add_child(pad)

## Whether the suit is simulated in this game (Survival and Freedom).
static func active() -> bool:
	return MHGame.game_mode in ["survival", "freedom"] and not MHGame.showcase

func _sim() -> RefCounted:
	return world.builder.simulation() if world.builder != null else null

# ---------- each frame ----------

func _process(delta: float) -> void:
	if get_tree().paused: return
	var hour := MHGame.sol_hour
	var hours := wrapf(hour - _last_hour, 0.0, 24.0) if _last_hour >= 0.0 else 0.0
	_last_hour = hour
	if hours > .5: hours = 0.0   # a clock jump (loading, debug), not time worn
	_check -= delta
	if _check <= 0.0:
		_check = .25
		where = _where()
	if not active():
		o2 = 1.0; power = 1.0; scrubber = 1.0
		_set_visor_visible(false)
		return
	if where == "outside": step(hours)
	else: _top_up(delta)
	_warnings()
	_breathing(delta)
	_blink += delta
	_set_visor_visible(where == "outside" and not bool(world.player.get_meta("build_mode_active", false)))
	_visor.queue_redraw()
	if o2 <= 0.0 and where == "outside" and MHGame.crew_can_be_harmed() and not passed_out: pass_out()

## Where you're breathing from. The habitat counts only while its air is fit
## to breathe; the rover's cab only while its tank has oxygen.
func _where() -> String:
	var player: Node3D = world.player
	if bool(player.get_meta("driving", false)):
		var rover: Node = world.get("crew_rover")
		return "rover" if rover != null and float(rover.o2) > 0.0 else "outside"
	if world.lander != null and world.lander.cabin_contains(player.global_position): return "lander"
	if world.builder != null and not world.builder.build_mode and world.builder.is_inside(player.global_position):
		var sim := _sim()
		if sim == null or not MHGame.simulation_on() or float(sim.o2_pct) >= 17.0: return "habitat"
	return "outside"

## A stretch of time outside, in game hours.
func step(hours: float) -> void:
	if hours <= 0.0: return
	o2 = maxf(0.0, o2 - hours * breathing_rate() / O2_HOURS)
	power = maxf(0.0, power - hours * (NIGHT_POWER if MHGame.sunlight_fraction < .1 else 1.0) / POWER_HOURS)
	scrubber = maxf(0.0, scrubber - hours / SCRUBBER_HOURS)

## How hard you're breathing: 1 at a walk.
func breathing_rate() -> float:
	var rate := 1.0
	var player: CharacterBody3D = world.player
	if Vector2(player.velocity.x, player.velocity.z).length() > 5.5: rate *= SPRINT   # faster than a walk
	if world.get("carry") != null and not (world.carry.carrying as Dictionary).is_empty(): rate *= CARRYING
	if power <= 0.0: rate *= COLD
	if scrubber <= 0.0: rate *= STALE
	return rate

# ---------- topping up ----------

func full() -> bool:
	return o2 >= .999 and power >= .999 and scrubber >= .999

## Inside: the suit fills from whatever you're in.
func _top_up(delta: float) -> void:
	var refills := where == "lander" or where == "rover" or (where == "habitat" and _in_airlock())
	var was := _filling
	_filling = refills and not full()
	if _filling: fill(FILL_PER_S * delta, where)
	if _filling and not was:
		MHAudio.sfx("suit_fill", -10.0)
		if o2 < .9: _say("suit_topping_up")
	if was and not _filling and full(): _say("suit_full")
	if full(): _said.clear()

## Up to `share` of a full suit from a source ("habitat", "lander" or
## "rover"), drawing on its stores. Returns false when it had nothing to give.
func fill(share: float, source: String) -> bool:
	var want_o2 := minf(share, 1.0 - o2)
	var want_power := minf(share, 1.0 - power)
	var got_o2 := want_o2
	var got_power := want_power
	match source:
		"habitat":
			var sim := _sim()
			if sim != null and MHGame.simulation_on():
				got_o2 = sim.take_oxygen(want_o2 * O2_HOURS * O2_KG_PER_HOUR) / (O2_HOURS * O2_KG_PER_HOUR)
				got_power = sim.take_energy(want_power * FULL_KWH) / FULL_KWH
		"rover":
			var rover: Node = world.get("crew_rover")
			if rover == null: return false
			var given: Vector2 = rover.supply_suit(want_o2 * O2_HOURS, want_power)
			got_o2 = given.x / O2_HOURS
			got_power = given.y
	o2 = minf(1.0, o2 + got_o2)
	power = minf(1.0, power + got_power)
	# The scrubber bakes out on the umbilical whenever the suit has power.
	if got_power > 0.0 or want_power <= 0.0: scrubber = minf(1.0, scrubber + share)
	return got_o2 > 0.0 or got_power > 0.0 or (want_o2 <= 0.0 and want_power <= 0.0)

## A suit service panel or suit rack: a full refill from the habitat, now.
func refill_at_panel() -> void:
	if not active():
		get_tree().call_group("explore_hud", "show_equipment_note", "Suit", "Suit life support only runs in Survival and Freedom.")
		return
	if full():
		_say("suit_full")
		return
	MHAudio.sfx("suit_fill", -6.0)
	if fill(1.0, "habitat"):
		_say("suit_full" if full() else "suit_no_supply")
	else:
		_say("suit_no_supply")

## G beside the rover: as much as the rover can give.
func top_up_from_rover() -> String:
	if not active(): return "Suit life support only runs in Survival and Freedom."
	if full(): return "Your suit is already full."
	MHAudio.sfx("suit_fill", -6.0)
	var ok := fill(1.0, "rover")
	_say("suit_full" if full() else ("suit_topping_up" if ok else "suit_no_supply"))
	return "Topped up from the rover's tank and battery." if ok else "The rover has nothing left to give."

func _in_airlock() -> bool:
	var player: Node3D = world.player
	var cell := Vector2i(roundi(player.global_position.x / BuildController.CELL), roundi(player.global_position.z / BuildController.CELL))
	for zone in world.builder.zones:
		if str(zone.get("kind", "")) == "airlock" and cell in zone.cells: return true
	return false

# ---------- what the suit tells you ----------

## Game hours of oxygen left at the current rate.
func o2_hours_left() -> float:
	return o2 * O2_HOURS / breathing_rate()

## Game hours left before you must turn back for the nearest refill, with a
## margin (negative: you're already past it).
func turn_back_hours() -> float:
	var refill := nearest_refill()
	if refill.is_empty(): return o2_hours_left()
	return o2_hours_left() - float(refill.distance) / WALK * MARGIN / real_seconds_per_hour()

## Real seconds the clock takes for one game hour now (sols run faster at night).
static func real_seconds_per_hour() -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	if MHGame.sol_hour >= sunrise and MHGame.sol_hour < sunset:
		return maxf(1.0, float(cycle.get("daylight_minutes", 15.0)) * 60.0) / maxf(.1, sunset - sunrise)
	return maxf(1.0, float(cycle.get("night_minutes", 5.0)) * 60.0) / maxf(.1, 24.0 - (sunset - sunrise))

## The nearest place to top up: {position, distance, label}.
func nearest_refill() -> Dictionary:
	var from: Vector3 = world.player.global_position
	var best := {}   # filled in place (a lambda can't reassign it)
	var offer := func(at: Vector3, label: String) -> void:
		var d := Vector2(at.x - from.x, at.z - from.z).length()
		if best.is_empty() or d < float(best.distance): best.merge({"position": at, "distance": d, "label": label}, true)
	if world.builder != null:
		for zone in world.builder.zones:
			if str(zone.get("kind", "")) != "airlock": continue
			var centre := Vector2.ZERO
			for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
			centre /= float((zone.cells as Array).size())
			offer.call(Vector3(centre.x, world.builder.habitat_base_y, centre.y), "AIRLOCK")
	if world.lander != null and world.lander.present: offer.call(world.lander.global_position, "LANDER")
	var rover: Node3D = world.get("crew_rover")
	if rover != null and float(rover.o2) > 0.0: offer.call(rover.global_position, "ROVER")
	return best

## For the wrist pad's screen.
func readout() -> Dictionary:
	var refill := nearest_refill()
	var bearing := 0.0
	if not refill.is_empty():
		var player: Node3D = world.player
		var to: Vector3 = refill.position - player.global_position
		bearing = wrapf(atan2(-to.x, -to.z) - player.rotation.y, -PI, PI)
	return {"o2": o2, "power": power, "scrubber": scrubber, "where": where, "active": active(), "filling": _filling,
		"o2_hours": o2_hours_left(), "turn_back": turn_back_hours(), "refill": refill, "bearing": bearing,
		"night": MHGame.sunlight_fraction < .1}

func _say(id: String) -> void:
	MHAudio.suit(id)

## Each warning once a trip, as things run down.
func _warnings() -> void:
	if where != "outside":
		return
	var lines := [
		["suit_sealed", true],
		["suit_turn_back", turn_back_hours() <= 0.0 and o2 < .9],
		["suit_o2_half", o2 <= .5],
		["suit_o2_quarter", o2 <= LOW],
		["suit_o2_critical", o2 <= .08],
		["suit_power_low", power <= LOW],
		["suit_power_out", power <= 0.0],
		["suit_scrubber", scrubber <= 0.0]]
	for line in lines:
		if line[1] and not _said.has(line[0]):
			_said[line[0]] = true
			if line[0] != "suit_sealed": MHAudio.sfx("suit_alarm" if line[0] in ["suit_o2_critical", "suit_turn_back"] else "suit_beep", -4.0)
			_say(str(line[0]))

## Your own breathing: slow at rest, quick when sprinting or short of air.
func _breathing(delta: float) -> void:
	if where != "outside":
		return
	_breath_wait -= delta
	if _breath_wait > 0.0: return
	var rate := breathing_rate() * (1.6 if o2 < LOW else 1.0)
	var cycle := clampf(4.2 / rate, 1.3, 4.2)
	var stream := MHAudio.director()._stream("sfx/suit_breath_in" if _breath_in else "sfx/suit_breath_out") if MHAudio.director() != null else null
	if stream != null:
		_breath.stream = stream
		_breath.volume_db = -22.0 + 6.0 * clampf(rate - 1.0, 0.0, 1.0)
		_breath.pitch_scale = randf_range(.96, 1.04) * (1.0 + .08 * clampf(rate - 1.0, 0.0, 1.0))
		_breath.play()
	_breath_wait = cycle * (.42 if _breath_in else .58)
	_breath_in = not _breath_in

# ---------- the visor ----------

func _set_visor_visible(on: bool) -> void:
	if _visor.visible != on: _visor.visible = on

func _tone(share: float) -> Color:
	if share <= .1: return Color(1.0, .25, .2)
	if share <= LOW: return Color(1.0, .66, .2)
	return Color(.35, 1.0, .5)

## Two out-of-focus LEDs at the top corners of the visor (oxygen left, power
## right), blinking when critical; frost creeping in from the edges when the
## suit's battery is flat and the heater is off.
func _draw_visor() -> void:
	var size := _visor.size
	for side in [[Vector2(size.x * .045, size.y * .055), o2], [Vector2(size.x * .955, size.y * .055), power]]:
		var share := float(side[1])
		if share <= .1 and fmod(_blink, .8) > .45: continue
		var colour := _tone(share)
		for ring in 6:
			var r := size.y * (.006 + .007 * ring)
			_visor.draw_circle(side[0], r, Color(colour, .3 / (1.0 + ring * 1.4)))
	var frost := clampf(1.0 - power / .08, 0.0, 1.0) if power < .08 else 0.0
	if frost > 0.0:
		var band := size.y * .12 * frost
		for i in 8:
			var a := .07 * frost * (1.0 - i / 8.0)
			var w := band * (1.0 - i / 8.0)
			_visor.draw_rect(Rect2(0, 0, size.x, w), Color(.85, .93, 1.0, a))
			_visor.draw_rect(Rect2(0, size.y - w, size.x, w), Color(.85, .93, 1.0, a))
			_visor.draw_rect(Rect2(0, 0, w, size.y), Color(.85, .93, 1.0, a))
			_visor.draw_rect(Rect2(size.x - w, 0, w, size.y), Color(.85, .93, 1.0, a))

# ---------- blacking out ----------

## Out of oxygen: the screen goes dark and you come round in the airlock (or
## the lander cabin), with what you were carrying put back.
func pass_out() -> void:
	passed_out = true
	var player: CharacterBody3D = world.player
	if bool(player.get_meta("driving", false)) and world.get("crew_rover") != null: world.crew_rover._get_out()
	if world.get("carry") != null: world.carry.put_back()
	player.set_meta("ui_freeze", true)
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	layer.add_child(dark)
	var fade := create_tween()
	fade.tween_property(dark, "color:a", 1.0, 1.6)
	fade.tween_callback(func() -> void:
		var spot := wake_spot()
		player.global_position = spot.position
		player.rotation.y = float(spot.yaw)
		player.safe_position = player.global_position
		player.velocity = Vector3.ZERO
		o2 = .1
		where = _where()
		_said.clear())
	fade.tween_interval(1.4)
	fade.tween_property(dark, "color:a", 0.0, 1.2)
	fade.tween_callback(func() -> void:
		player.set_meta("ui_freeze", false)
		passed_out = false
		layer.queue_free()
		get_tree().call_group("explore_hud", "show_equipment_note", "You blacked out", "Your suit ran out of oxygen and you came round in the %s, groggy. Watch the turn-back time on your wrist (hold T)." % ("airlock" if _has_airlock() else "lander cabin")))

func _has_airlock() -> bool:
	return world.builder != null and world.builder.zones.any(func(z): return str(z.get("kind", "")) == "airlock")

## Where you come round: the first airlock, else the lander cabin.
func wake_spot() -> Dictionary:
	if _has_airlock():
		for zone in world.builder.zones:
			if str(zone.get("kind", "")) != "airlock": continue
			var centre := Vector2.ZERO
			for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
			centre /= float((zone.cells as Array).size())
			return {"position": Vector3(centre.x, world.builder.habitat_base_y + .1, centre.y), "yaw": world.player.rotation.y}
	return world.lander.cabin_start()

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"o2": o2, "power": power, "scrubber": scrubber}

func restore_state(state: Dictionary) -> void:
	o2 = float(state.get("o2", 1.0))
	power = float(state.get("power", 1.0))
	scrubber = float(state.get("scrubber", 1.0))
