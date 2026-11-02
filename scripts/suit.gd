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
## Out of oxygen in Survival you black out and GAR-Y drags you home
## (scripts/gar_y_rescue.gd): hours pass, what you carried lies where you
## fell, the rover drives itself home if it can, and the suit's seals leak
## until you repair them at a suit service panel (or patch them by hand in a sealed space, if the base has no panel).
## Freedom warns but never lets you pass out; Creative and Missions don't run
## the suit.
##
## The suit's dosimeter (docs/survival-systems.md §7) keeps your own radiation
## dose: the full surface rate outside (almost none in a cave), a little less
## in the rover's cab or the lander, and the crew's indoor rate in the habitat.

const WRIST_PAD := preload("res://scripts/wrist_pad.gd")
const RESCUE := preload("res://scripts/gar_y_rescue.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const HABITAT_LIFE := preload("res://scripts/habitat_life.gd")
const HABITAT_CHAINS := preload("res://scripts/habitat_chains.gd")
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
const LEAK := 1.5                # a damaged seal: oxygen goes this much faster
const PATCH_HOURS := 1.0         # patching a seal by hand, with no service panel

var world: Node
## Each store as a share of a full suit (0 to 1).
var o2 := 1.0
var power := 1.0
var scrubber := 1.0
## Where you are: "outside", "habitat", "lander" or "rover".
var where := "habitat"
var passed_out := false
var leak := false                # the seals took a knock (saved)
## Things you dropped when you blacked out: {placement_id, label, position}.
var dropped: Array = []
var _patching := 0.0
var _has_panel := false
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
var dose_msv := 0.0              # your own total (saved)
var today_msv := 0.0             # since local midnight (saved)

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

## Whether the suit is simulated in this game (the Suit oxygen rule).
static func active() -> bool:
	return MHGame.suit_o2_on() and not MHGame.showcase

func _sim() -> RefCounted:
	return world.builder.simulation() if world.builder != null else null

# ---------- each frame ----------

func _process(delta: float) -> void:
	if get_tree().paused: return
	var hour := MHGame.sol_hour
	var hours := wrapf(hour - _last_hour, 0.0, 24.0) if _last_hour >= 0.0 else 0.0
	if _last_hour >= 0.0 and hour < _last_hour: today_msv = 0.0   # past midnight
	_last_hour = hour
	if hours > .5: hours = 0.0   # a clock jump (loading, debug), not time worn
	_check -= delta
	if _check <= 0.0:
		_check = .25
		# The site plan is a camera over the base: your body stays where it
		# was (and the rooms being edited aren't a fair test of "inside"), so
		# you keep breathing whatever you were breathing.
		if world.builder == null or not world.builder.build_mode: where = _where()
		_has_panel = world.builder != null and (world.builder.placed_interior as Array).any(func(item): return str(item.get("id", "")) == "suit_service_panel")
		_prune_dropped()
	if not active():
		o2 = 1.0; power = 1.0; scrubber = 1.0
		_set_visor_visible(false)
		return
	dose(hours)
	if where == "outside":
		if not passed_out: step(hours)
	else:
		_top_up(delta)
		_patch_by_hand(hours)
	if not passed_out:
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
	if hours <= 0.0 or MHGame.debug_suit_never_runs_out: return
	o2 = maxf(0.0, o2 - hours * breathing_rate() * (LEAK if leak else 1.0) / O2_HOURS)
	power = maxf(0.0, power - hours * (NIGHT_POWER if MHGame.sunlight_fraction < .1 else 1.0) / POWER_HOURS)
	scrubber = maxf(0.0, scrubber - hours / SCRUBBER_HOURS)

## Your dose rate where you are, mSv an hour.
func dose_rate() -> float:
	var sim := _sim()
	var life: RefCounted = sim.life if sim != null else null
	var surface := float(HABITAT_LIFE.value("radiation", "surface_msv_per_sol", .6)) / 24.0
	var factor := 1.0
	match where:
		"habitat":
			if life != null: return life.indoor_msv_per_sol(sim.inventory()) / 24.0 + _event_rate(life) * life.event_factor(sim.inventory(), sim.crew_count())
			factor = float(HABITAT_LIFE.value("radiation", "indoors_factor", .8))
		"rover": factor = float(HABITAT_LIFE.value("radiation", "rover_factor", .8))
		"lander": factor = float(HABITAT_LIFE.value("radiation", "lander_factor", .7))
		_:
			if not MHCaves.cave_at(world.player.global_position).is_empty(): factor = float(HABITAT_LIFE.value("radiation", "cave_factor", .05))
	return (surface + (_event_rate(life) if life != null else 0.0)) * factor

func _event_rate(life: RefCounted) -> float:
	if not life.spe_active(): return 0.0
	return float(HABITAT_LIFE.value("radiation", "event_dose_msv", 150.0)) / float(HABITAT_LIFE.value("radiation", "event_hours", 24.0))

## The dosimeter: hours pass wherever you are.
func dose(hours: float) -> void:
	if hours <= 0.0: return
	var got := dose_rate() * hours
	dose_msv += got
	today_msv += got

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

## A suit service panel or suit rack: a full refill from the habitat, now,
## and a leaking seal repaired.
func refill_at_panel() -> void:
	if not active():
		get_tree().call_group("explore_hud", "show_equipment_note", "Suit", "Suit life support only runs in Survival and Freedom.")
		return
	if leak:
		leak = false
		MHAudio.sfx("suit_clamp", -8.0)
		fill(1.0, "habitat")
		_say("suit_seal_repaired")
		return
	if full():
		_say("suit_full")
		return
	MHAudio.sfx("suit_fill", -6.0)
	if fill(1.0, "habitat"):
		_say("suit_full" if full() else "suit_no_supply")
	else:
		_say("suit_no_supply")

## Debug: full, and the seals mended.
func debug_refill() -> void:
	o2 = 1.0; power = 1.0; scrubber = 1.0
	leak = false
	_patching = 0.0
	_said.clear()

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

## No service panel in the base: a leak gets patched by hand, given an hour
## somewhere sealed.
func _patch_by_hand(hours: float) -> void:
	if not leak or _has_panel or passed_out: return
	_patching += hours
	if _patching < PATCH_HOURS: return
	leak = false
	_patching = 0.0
	_say("suit_seal_repaired")
	get_tree().call_group("explore_hud", "show_equipment_note", "Suit seal patched", "With no suit service panel in the base, you patched the leaking seal by hand from the repair kit.")

## Forget dropped things once they've been picked up.
func _prune_dropped() -> void:
	if dropped.is_empty() or world.builder == null: return
	var here := {}
	for item in world.builder.placed_interior: here[str(item.get("placement_id", ""))] = true
	dropped = dropped.filter(func(d): return here.has(str(d.placement_id)))

## Game hours of oxygen left at the current rate.
func o2_hours_left() -> float:
	return o2 * O2_HOURS / (breathing_rate() * (LEAK if leak else 1.0))

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
		"night": MHGame.sunlight_fraction < .1, "leak": leak, "dose_msv": dose_msv, "today_msv": today_msv, "dose_rate": dose_rate(),
		"base_alert": base_alert(), "runway": _runway()}

## The worst warning or critical alert at the base, {title, level} or {}: the
## suit relays it to the wrist pad and the visor while you're out (§12.5).
func base_alert() -> Dictionary:
	var alerts: Node = get_tree().get_first_node_in_group("habitat_alerts") if is_inside_tree() else null
	if alerts == null: return {}
	var worst := {}
	for id in alerts._active:
		var level := str(alerts._active[id].level)
		if not level in ["warning", "critical"]: continue
		if worst.is_empty() or (level == "critical" and str(worst.level) != "critical"): worst = {"title": str(alerts._active[id].title), "level": level}
	return worst

func _runway() -> Dictionary:
	var sim := _sim()
	if sim == null or not MHGame.simulation_on() or where == "outside": return {}
	return HABITAT_CHAINS.runway(sim)

func _say(id: String) -> void:
	MHAudio.suit(id)

## Each warning once a trip, as things run down.
func _warnings() -> void:
	if where != "outside":
		return
	var lines := [
		["suit_sealed", true],
		["suit_leak", leak],
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
	# Trouble at the base: a third light, top centre, slow amber or quick red.
	var trouble := base_alert()
	if not trouble.is_empty() and fmod(_blink, 1.6 if str(trouble.level) == "warning" else .7) < .4:
		var colour := MHStyle.WARN if str(trouble.level) == "warning" else MHStyle.DANGER
		for ring in 5: _visor.draw_circle(Vector2(size.x * .5, size.y * .03), size.y * (.004 + .006 * ring), Color(colour, .3 / (1.0 + ring * 1.4)))
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

## Out of oxygen: you black out and GAR-Y drags you home (or, with no GAR-Y,
## you come round inside).
func pass_out() -> void:
	passed_out = true
	if bool(world.player.get_meta("driving", false)) and world.get("crew_rover") != null: world.crew_rover._get_out()
	var rescue := RESCUE.new()
	rescue.name = "Rescue"
	add_child(rescue)
	rescue.finished.connect(_come_round)
	rescue.start(world, self)

func _come_round(summary: Dictionary) -> void:
	passed_out = false
	o2 = maxf(o2, .1)
	where = _where()
	_said.clear()
	var place := "the lander cabin" if not _has_airlock() else ("the medical bay" if _medical_cot() != null else "the airlock")
	if not bool(summary.rescued):
		get_tree().call_group("explore_hud", "show_equipment_note", "You blacked out", "Your suit ran out of oxygen and you came round in %s, groggy. Watch the turn-back time on your wrist (hold T)." % place)
		return
	leak = true
	_patching = 0.0
	var item: Dictionary = summary.dropped
	if not item.is_empty(): dropped.append(item)
	var hours := float(summary.hours)
	var metres := float(summary.distance)
	var lines := ["Your suit ran out of oxygen %s from home. GAR-Y found you, locked onto your suit's drag handle and hauled you back to %s: %d h %02d min went by." % [
		("%.1f km" % (metres / 1000.0)) if metres >= 1000.0 else "%d m" % roundi(metres), place, int(hours), int(fmod(hours, 1.0) * 60.0)]]
	if not item.is_empty():
		lines.append("You dropped the %s where you fell%s." % [str(item.label).to_lower(), " (it's on the region map, Tab)" if MHSiteTerrain.shape() == "region" else ""])
	lines.append("The suit's seals took a knock: it leaks, so oxygen runs out faster, until you repair it at a suit service panel." if _has_panel else "The suit's seals took a knock: it leaks, so oxygen runs out faster, until you've patched it (an hour somewhere sealed).")
	if world.get("crew_rover") != null and world.crew_rover.global_position.distance_to(world.player.global_position) > 30.0:
		var rover_line: String = world.crew_rover.come_home_after_rescue()
		if rover_line != "": lines.append(rover_line)
	var count := int(summary.rescues)
	var remark := "\"Please don't do that again.\"" if count <= 1 else ("\"Twice now, Commander.\"" if count == 2 else "\"That's %d times now, Commander.\"" % count)
	lines.append("GAR-Y's beeps, roughly: " + remark)
	get_tree().call_group("explore_hud", "show_equipment_note", "GAR-Y brought you home", " ".join(lines))

func _has_airlock() -> bool:
	return world.builder != null and world.builder.zones.any(func(z): return str(z.get("kind", "")) == "airlock")

func _medical_cot() -> Variant:
	if world.builder == null: return null
	for item in world.builder.placed_interior:
		if str(item.get("id", "")) == "medical_exam_cot": return item
	return null

## Where you come round: beside a medical cot, else the first airlock, else
## the lander cabin.
func wake_spot() -> Dictionary:
	var cot: Variant = _medical_cot()
	if cot != null and _has_airlock():
		var at: Vector3 = cot.position
		var yaw := float(cot.get("rotation_y", 0.0))
		var side := Vector3(1.1, 0, 0).rotated(Vector3.UP, yaw)
		return {"position": Vector3(at.x + side.x, world.builder.habitat_base_y + .1, at.z + side.z), "yaw": yaw}
	if _has_airlock():
		for zone in world.builder.zones:
			if str(zone.get("kind", "")) != "airlock": continue
			var centre := Vector2.ZERO
			for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
			centre /= float((zone.cells as Array).size())
			# Facing in, away from the outer door.
			var out := Vector2(zone.get("door_direction", Vector2i(0, -1)))
			return {"position": Vector3(centre.x, world.builder.habitat_base_y + .1, centre.y), "yaw": atan2(out.x, out.y)}
	return world.lander.cabin_start()

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"o2": o2, "power": power, "scrubber": scrubber, "leak": leak, "dose_msv": dose_msv, "today_msv": today_msv,
		"dropped": dropped.map(func(d): return {"placement_id": d.placement_id, "label": d.label, "position": [d.position.x, d.position.y, d.position.z]})}

func restore_state(state: Dictionary) -> void:
	o2 = float(state.get("o2", 1.0))
	power = float(state.get("power", 1.0))
	scrubber = float(state.get("scrubber", 1.0))
	leak = bool(state.get("leak", false))
	dose_msv = float(state.get("dose_msv", 0.0))
	today_msv = float(state.get("today_msv", 0.0))
	dropped = (state.get("dropped", []) as Array).map(func(d): return {"placement_id": str(d.placement_id), "label": str(d.label), "position": Vector3(float(d.position[0]), float(d.position[1]), float(d.position[2]))})
