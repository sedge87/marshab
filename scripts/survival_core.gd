extends RefCounted

## The new survival core (docs/systems-and-items.md §14 step 1): one small
## model of stores and flows for power, heat and air, kept apart from the
## builder. Step 1 runs the lander cabin with it; later steps add the
## habitat's rooms and machines to the same model.
##
## Stores:
## - the battery (kWh);
## - the oxygen tank (kg);
## - the cabin air: kg of O₂ and CO₂ in its free volume;
## - the cabin temperature (°C), with a heat capacity.
##
## Flows, worked out in short sub-steps:
## - the sun charges the battery;
## - each machine that's on draws power, and all of it ends up as heat;
## - the hull loses heat to the outside;
## - people breathe O₂ in, and breathe CO₂ and body heat out;
## - the scrubber takes CO₂ out;
## - the regulator tops O₂ up from the tank (no power needed).
##
## When the battery is flat, every powered machine stops.
##
## The same model gives the alerts (one engine for the icon row, the slate and
## the voices) and the runway: run a copy forward and see when each store
## crosses its limit.
## Numbers: the New numbers sheet of docs/MarsHabitat_Balance.xlsx.

const MHResources := preload("res://scripts/mh_resources.gd")
const DAY_NIGHT := preload("res://scripts/site_day_night.gd")
const SUB_STEP := 0.05           # game hours
const AIR_DENSITY := 1.2         # kg per m³ at cabin pressure
const O2_VOL := 29.0 / 32.0      # mass share → volume share
const CO2_VOL := 29.0 / 44.0
const HEATER_MODES := ["off", "low", "warm"]
## Limits, per cent by volume and °C: [warning, critical].
const CO2_LIMITS := [1.0, 3.0]
const O2_LIMITS := [19.5, 17.0]
const COLD_LIMITS := [12.0, 0.0]

var battery_cap := 6.0
var battery_kwh := 6.0
var tank_cap := 3.0
var tank_o2_kg := 3.0
var air_kg := 18.0
var o2_kg := 0.0
var co2_kg := 0.0
var temp_c := 20.0
var people := 1.0                # breathing in here now
var heater_mode := "warm"
var lights_on := true
var scrubber_on := true
var last := {}                   # the last sub-step's flows (kW): solar, draw, heater, loss
var vented := false              # open to Mars (the lander's hatch is open): no air to breathe

func _init() -> void:
	battery_cap = n("cabin_battery_kwh", 6.0)
	battery_kwh = battery_cap
	tank_cap = n("cabin_o2_tank_kg", 3.0)
	tank_o2_kg = tank_cap
	air_kg = n("cabin_air_m3", 15.0) * AIR_DENSITY
	o2_kg = air_kg * .209 / O2_VOL
	co2_kg = air_kg * .0004 / CO2_VOL

static func n(key: String, fallback: float) -> float:
	return MHResources.revamp(key, fallback)

# ---------- readings ----------

func o2_pct() -> float:
	return 100.0 * o2_kg / air_kg * O2_VOL

func co2_pct() -> float:
	return 100.0 * co2_kg / air_kg * CO2_VOL

func powered() -> bool:
	return battery_kwh > .0005

func battery_pct() -> float:
	return 100.0 * battery_kwh / maxf(.001, battery_cap)

func heater_target() -> float:
	match heater_mode:
		"warm": return n("cabin_warm_c", 20.0)
		"low": return n("cabin_low_c", 10.0)
	return -INF

## What the body feels in here.
func conditions() -> Dictionary:
	if vented: return {"temp_c": temp_c, "o2_pct": 0.0, "co2_pct": 0.0, "powered": powered(), "lit": powered() and lights_on, "vented": true}
	return {"temp_c": temp_c, "o2_pct": o2_pct(), "co2_pct": co2_pct(), "powered": powered(), "lit": powered() and lights_on}

# ---------- the flows ----------

## Game hours passing, starting at `start_hour` on the sol clock.
func advance(hours: float, start_hour: float) -> void:
	var hour := start_hour
	var left := hours
	while left > 0.0:
		var dt := minf(SUB_STEP, left)
		step(dt, outside_at(hour), MHGame.solar_irradiance(hour))
		hour = wrapf(hour + dt, 0.0, 24.0)
		left -= dt

## One sub-step: `outside` °C, `sun` 0–1 of noon sunlight.
func step(dt: float, outside: float, sun: float) -> void:
	var on := powered()
	var draw := 0.0
	if on:
		draw += n("cabin_avionics_kw", .1)
		if lights_on: draw += n("cabin_lights_kw", .15)
		if scrubber_on: draw += n("cabin_scrubber_kw", .25)
	var body := people * n("body_heat_kw", .1)
	var loss := n("cabin_ua_kw_per_c", .012) * (temp_c - outside)
	var heat_cap := n("cabin_heat_kwh_per_c", .2)
	# The heater makes up the loss, and closes the gap to its setting over
	# about half an hour.
	var heater := 0.0
	if on and heater_mode != "off":
		var want := loss - draw - body + (heater_target() - temp_c) * heat_cap / .5
		heater = clampf(want, 0.0, n("cabin_heater_kw", 1.5))
	draw += heater
	var solar := n("cabin_solar_kw", 1.5) * sun
	battery_kwh = clampf(battery_kwh + (solar - draw) * dt, 0.0, battery_cap)
	temp_c += (draw + body - loss) * dt / heat_cap
	# Air (none while the cabin is open to Mars: the suit breathes for you).
	if vented:
		last = {"solar": solar, "draw": draw, "heater": heater, "loss": loss}
		return
	o2_kg = maxf(0.0, o2_kg - people * MHResources.setting("o2_per_person", .84) / 24.0 * dt)
	co2_kg += people * MHResources.setting("co2_per_person", 1.0) / 24.0 * dt
	if on and scrubber_on:
		co2_kg = maxf(air_kg * .0004 / CO2_VOL, co2_kg - n("cabin_scrub_kg_per_h", .1) * dt)
	var short := air_kg * .209 / O2_VOL - o2_kg
	if short > 0.0 and tank_o2_kg > 0.0:
		var feed := minf(minf(short, .3 * dt), tank_o2_kg)
		tank_o2_kg -= feed
		o2_kg += feed
	last = {"solar": solar, "draw": draw, "heater": heater, "loss": loss}

## Outside temperature at an hour of the sol (the day/night clock's own curve).
static func outside_at(hour: float) -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var light := DAY_NIGHT.sunlight_at(hour, cycle)
	return lerpf(float(cycle.get("night_temp_c", -68.0)), float(cycle.get("day_temp_c", -25.0)), light)

## The hatch opened: the cabin's air goes, and some of its warmth with it.
func vent() -> void:
	if vented: return
	vented = true
	temp_c -= n("cabin_vent_heat_c", 4.0)

## The hatch is shut and latched: the regulator refills the cabin from the
## tank (a small cost each time). A tank too low refills it only partly.
## Returns the oxygen it took.
func repressurise() -> float:
	if not vented: return 0.0
	vented = false
	var need := n("cabin_repress_o2_kg", .03)
	var got := take_oxygen(need)
	o2_kg = air_kg * .209 / O2_VOL * (got / need if need > 0.0 else 1.0)
	co2_kg = air_kg * .0004 / CO2_VOL
	return got

## Up to `kg` of oxygen from the tank (filling a suit); returns what it gave.
func take_oxygen(kg: float) -> float:
	var got := clampf(kg, 0.0, tank_o2_kg)
	tank_o2_kg -= got
	return got

## Up to `kwh` from the battery (charging a suit); returns what it gave.
func take_energy(kwh: float) -> float:
	var got := clampf(kwh, 0.0, battery_kwh)
	battery_kwh -= got
	return got

# ---------- the runway ----------

## Run a copy forward (up to `horizon` game hours, as things are set now) and
## note when each store crosses its warning line: game hours from now, or -1
## if it doesn't. {power, air, cold, oxygen}
func runway(start_hour: float, horizon := 24.0) -> Dictionary:
	var copy = get_script().new()
	copy.load_state(export_state())
	var out := {"power": -1.0, "air": -1.0, "cold": -1.0, "oxygen": -1.0}
	var hour := start_hour
	var t := 0.0
	while t < horizon:
		copy.advance(.25, hour)
		hour = wrapf(hour + .25, 0.0, 24.0)
		t += .25
		if out.power < 0.0 and not copy.powered(): out.power = t
		if out.air < 0.0 and copy.co2_pct() >= CO2_LIMITS[0]: out.air = t
		if out.oxygen < 0.0 and copy.o2_pct() < O2_LIMITS[0]: out.oxygen = t
		if out.cold < 0.0 and copy.temp_c < COLD_LIMITS[0]: out.cold = t
	return out

# ---------- the alerts ----------

## The cabin's alerts, in the alerts engine's shape: {id, level, title, text,
## chain}. `ahead` is a runway() result (optional): it adds the times.
func alerts(ahead: Dictionary = {}) -> Array:
	var out: Array = []
	var co2 := co2_pct()
	if co2 >= CO2_LIMITS[0]:
		out.append({"id": "cabin_co2", "level": "critical" if co2 >= CO2_LIMITS[1] else "warning", "title": "Cabin air going stale",
			"text": "CO₂ at %.1f%%. The scrubber needs power and switching on." % co2,
			"chain": [["wind", "Scrubber " + ("on" if scrubber_on and powered() else "off"), scrubber_on and powered()], ["heart-pulse", "You", false]]})
	var o2 := o2_pct()
	if o2 < O2_LIMITS[0]:
		out.append({"id": "cabin_o2", "level": "critical" if o2 < O2_LIMITS[1] else "warning", "title": "Cabin oxygen low",
			"text": "O₂ at %.1f%%." % o2, "chain": [["wind", "Tank %.1f kg" % tank_o2_kg, tank_o2_kg > 0.0], ["heart-pulse", "You", false]]})
	if tank_o2_kg <= 0.0:
		out.append({"id": "cabin_tank", "level": "critical", "title": "Cabin oxygen tank empty",
			"text": "Nothing left to top the cabin air up.", "chain": [["wind", "Tank empty", false]]})
	elif tank_o2_kg < .5 * MHResources.setting("o2_per_person", .84):
		out.append({"id": "cabin_tank", "level": "warning", "title": "Cabin oxygen tank low",
			"text": "%.1f kg left: under half a sol." % tank_o2_kg, "chain": [["wind", "Tank %.1f kg" % tank_o2_kg, false]]})
	if temp_c < COLD_LIMITS[0]:
		out.append({"id": "cabin_cold", "level": "critical" if temp_c < COLD_LIMITS[1] else "warning", "title": "Cabin cold",
			"text": "%d °C inside. The heater is %s%s." % [roundi(temp_c), heater_mode, "" if powered() else ", with no power"],
			"chain": [["flame", "Heater " + heater_mode, heater_mode != "off" and powered()], ["thermometer", "%d °C" % roundi(temp_c), false]]})
	if not powered():
		out.append({"id": "cabin_power", "level": "warning", "title": "Cabin battery flat",
			"text": "Lights, scrubber and heater are off until the sun charges it.", "chain": [["zap", "Battery 0%", false], ["sun", "Waiting for the sun", true]]})
	elif float(ahead.get("power", -1.0)) >= 0.0 and float(ahead.power) <= 4.0:
		out.append({"id": "cabin_power", "level": "advisory", "title": "Cabin battery runs out at %s" % _clock_after(float(ahead.power)),
			"text": "At this rate. The heater is the biggest load.", "chain": [["zap", "Battery %d%%" % roundi(battery_pct()), false], ["flame", "Heater " + heater_mode, true]]})
	return out

static func _clock_after(hours: float) -> String:
	var at := fmod(MHGame.sol_hour + hours, 24.0)
	return "%02d:%02d" % [int(at), int(fmod(at, 1.0) * 60.0)]

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"battery_kwh": battery_kwh, "tank_cap": tank_cap, "tank_o2_kg": tank_o2_kg, "o2_kg": o2_kg, "co2_kg": co2_kg, "temp_c": temp_c,
		"heater": heater_mode, "lights": lights_on, "scrubber": scrubber_on, "people": people, "vented": vented}

func load_state(state: Dictionary) -> void:
	if state.is_empty(): return
	battery_kwh = clampf(float(state.get("battery_kwh", battery_kwh)), 0.0, battery_cap)
	tank_cap = maxf(tank_cap, float(state.get("tank_cap", tank_cap)))   # a cartridge plugged in adds to it
	tank_o2_kg = clampf(float(state.get("tank_o2_kg", tank_o2_kg)), 0.0, tank_cap)
	o2_kg = float(state.get("o2_kg", o2_kg))
	co2_kg = float(state.get("co2_kg", co2_kg))
	temp_c = float(state.get("temp_c", temp_c))
	heater_mode = str(state.get("heater", heater_mode)) if HEATER_MODES.has(str(state.get("heater", ""))) else heater_mode
	lights_on = bool(state.get("lights", lights_on))
	scrubber_on = bool(state.get("scrubber", scrubber_on))
	people = float(state.get("people", people))
	vented = bool(state.get("vented", vented))
