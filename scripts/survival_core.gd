extends RefCounted

## The new survival core (docs/systems-and-items.md §14 step 1): one small
## model of stores and flows for power, heat and air, kept apart from the
## builder. Step 1 runs the lander cabin with it; later steps add the
## habitat's rooms and machines to the same model.
##
## Power + hull (21 Nov, docs/systems-and-items.md §1.3): the core is the
## room's life support. It needs only power and a sound hull. There's no
## oxygen tank, no separate scrubber: one switch (heater_mode, shown as "life
## support": off, low or warm) runs the scrubbing, the oxygen and the heat.
## With no power the cabin air is the buffer: it goes stale and cold over
## hours. A leak (open seams, `leak_pct_per_h`) drains the air; the core
## makes it up while it can, at a cost in battery.
##
## Stores:
## - the battery (kWh);
## - the hull (0–100 %), worn by time, quakes and storms (scripts/module_life.gd);
## - the cabin air: kg of O₂ and CO₂ in its free volume;
## - the cabin temperature (°C), with a heat capacity;
## - the lander's water tank (L): you drink from it wherever you are (the
##   suit's drink bag is filled from it), and melted ice tops it up (step 3b).
##
## Flows, worked out in short sub-steps:
## - the sun charges the battery;
## - each machine that's on draws power, and all of it ends up as heat;
## - the hull loses heat to the outside;
## - people breathe O₂ in, and breathe CO₂ and body heat out;
## - with life support on and powered, CO₂ is scrubbed and O₂ remade;
## - leaks take air out, and the core makes it up (power) while it can.
##
## When the battery is flat, every powered machine stops.
##
## The lander cabin is self-sufficient (the user, 8 Nov: a lifepod, too small
## to be a base; docs/opening-days.md): a small radioisotope unit gives it
## power day and night, and it recycles its water. Only food runs down. The
## General Module has none of that.
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
var air_kg := 18.0
var o2_kg := 0.0
var co2_kg := 0.0
var temp_c := 20.0
var people := 1.0                # breathing in here now
## The life-support switch: "off", "low" (10 °C) or "warm" (20 °C). It runs
## the scrubbing and the oxygen as well as the heat.
var heater_mode := "warm"
var lights_on := true
## Old name kept for older code and saves: the life support is on.
var scrubber_on: bool:
	get: return heater_mode != "off"
	set(value):
		if not value: heater_mode = "off"
		elif heater_mode == "off": heater_mode = "low"
var hull_pct := 100.0            # wear, quakes and storms take it down; patches put it back
var leak_pct_per_h := 0.0        # of the cabin air, through open seams (set by the room)
var last := {}                   # the last sub-step's flows (kW): solar, draw, heater, loss
var vented := false              # open to Mars (the lander's hatch is open): no air to breathe
var pack_kw := 0.0               # pallet 2's solar blanket, laid out by the lander (peak kW)
var pack_kwh := 0.0              # and its battery, added to the cabin's
var water_cap := 7.5             # the lander's water tank (L); a printed bladder adds to it
var water_l := 7.5
var dry_hours := 0.0             # hours with nothing to drink
## With the power out the fans stop, and your own breath pools round you (a
## real ISS hazard): the CO₂ you feel climbs well before the room's average
## does. Docs/hab-supply.md: stale air about half a sol after the power goes.
var still_co2_pct := 0.0
## Which room this core runs (3c): "cabin" (the lander) or "module" (the
## General Module). The module reads its own numbers (module_*, falling back
## to the cabin's), and doesn't drink: the water is the lander's one tank.
var prefix := "cabin"
var room_name := "Cabin"
var drinks := true
## Out on the suit you drink from its bag instead (step 4a, scripts/suit.gd).
var sipping_suit := false
var self_sufficient := false     # the lander: power cell, oxygen remade, water recycled

func _init(room := "cabin") -> void:
	prefix = room
	room_name = "Module" if room == "module" else "Cabin"
	drinks = room == "cabin"
	self_sufficient = room == "cabin" and n("cabin_self_sufficient", 1.0) > 0.0
	battery_cap = m("cabin_battery_kwh", 6.0)
	battery_kwh = battery_cap
	water_cap = maxf(n("cabin_water_l", 7.5), 12.0)
	water_l = n("cabin_water_l", 7.5)
	air_kg = m("cabin_air_m3", 15.0) * AIR_DENSITY
	o2_kg = air_kg * .209 / O2_VOL
	co2_kg = air_kg * .0004 / CO2_VOL

static func n(key: String, fallback: float) -> float:
	return MHResources.revamp(key, fallback)

## A number for this room: module_x for the module, else cabin_x.
func m(key: String, fallback: float) -> float:
	if prefix != "cabin" and key.begins_with("cabin_"):
		return n(prefix + key.trim_prefix("cabin"), n(key, fallback))
	return n(key, fallback)

# ---------- readings ----------

func o2_pct() -> float:
	return 100.0 * o2_kg / air_kg * O2_VOL

func co2_pct() -> float:
	return 100.0 * co2_kg / air_kg * CO2_VOL

## 22 Nov playtest: at dawn the first trickle of sun switched life support
## back on, the heater drained it at once, and "battery flat" came and went
## every step, chiming. Once it's flat it stays off until there's a little
## in hand (FLAT_BACK_KWH).
const FLAT_BACK_KWH := .3
const LOW_RESERVE_KWH := 1.0
var _flat := false
func powered() -> bool:
	return battery_kwh > (FLAT_BACK_KWH if _flat else .0005)

## Life support running: switched on, with power.
func life_on() -> bool:
	return powered() and heater_mode != "off"

## The air at a glance, 0–1: 1 is fresh, 0 is unsafe (stale or thin).
func air_fraction() -> float:
	var stale := clampf((co2_pct() + still_co2_pct) / CO2_LIMITS[1], 0.0, 1.0)
	var thin := clampf((20.9 - o2_pct()) / (20.9 - O2_LIMITS[1]), 0.0, 1.0)
	return 1.0 - maxf(stale, thin)

func leaking() -> bool:
	return leak_pct_per_h > 0.0 and not vented

func battery_pct() -> float:
	return 100.0 * battery_kwh / maxf(.001, battery_cap)

func heater_target() -> float:
	match heater_mode:
		"warm": return m("cabin_warm_c", 20.0)
		"low": return m("cabin_low_c", 10.0)
	return -INF

## What the body feels in here.
func conditions() -> Dictionary:
	if vented: return {"temp_c": temp_c, "o2_pct": 0.0, "co2_pct": 0.0, "powered": powered(), "lit": powered() and lights_on, "vented": true}
	return {"temp_c": temp_c, "o2_pct": o2_pct(), "co2_pct": co2_pct() + still_co2_pct, "powered": powered(), "lit": powered() and lights_on}

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
	# You drink wherever you are: from the tank, or out on the suit from its bag.
	if drinks and not sipping_suit and not self_sufficient:
		water_l = maxf(0.0, water_l - n("water_per_sol_l", 3.0) / 24.0 * dt)
		dry_hours = dry_hours + dt if water_l <= 0.0 else 0.0
	# The lander's recycler gives back what you drink, and tops up what the suit's bag took.
	if self_sufficient: water_l = minf(water_cap, water_l + n("water_per_sol_l", 3.0) * 1.5 / 24.0 * dt)
	var on := powered()
	var draw := 0.0
	var life := on and heater_mode != "off"
	if on:
		draw += m("cabin_avionics_kw", .1)
		if lights_on: draw += m("cabin_lights_kw", .15)
		if life: draw += m("cabin_scrubber_kw", .25)
	# Slow wear on the seams (none on the lander: it's the lifepod).
	if not vented: hull_pct = maxf(0.0, hull_pct - m("cabin_hull_wear_pct_per_h", 0.0) * dt)
	var body := people * n("body_heat_kw", .1)
	var loss := m("cabin_ua_kw_per_c", .012) * (temp_c - outside)
	var heat_cap := m("cabin_heat_kwh_per_c", .2)
	# The heater makes up the loss, and closes the gap to its setting over
	# about half an hour.
	var heater := 0.0
	if life:
		var want := loss - draw - body + (heater_target() - temp_c) * heat_cap / .5
		heater = clampf(want, 0.0, m("cabin_heater_kw", 1.5))
	var solar := (m("cabin_solar_kw", 1.5) + pack_kw) * sun
	if self_sufficient: solar += n("cabin_rtg_kw", .7)   # the power cell, day and night
	# Nearly flat: the heater only spends half what the sun brings in, so the
	# battery climbs back instead of flicking on and off all morning.
	if life and battery_kwh < LOW_RESERVE_KWH: heater = minf(heater, maxf(0.0, solar - draw) * .5)
	draw += heater
	battery_kwh = clampf(battery_kwh + (solar - draw) * dt, 0.0, battery_cap)
	if battery_kwh <= .0005: _flat = true
	elif battery_kwh > FLAT_BACK_KWH: _flat = false
	temp_c += (draw + body - loss) * dt / heat_cap
	# Air (none while the cabin is open to Mars: the suit breathes for you).
	if vented:
		last = {"solar": solar, "draw": draw, "heater": heater, "loss": loss}
		return
	if life or people <= 0.0: still_co2_pct = maxf(0.0, still_co2_pct - n("still_air_clear_pct_per_h", 10.0) * dt)
	else: still_co2_pct = minf(8.0, still_co2_pct + people * n("still_air_co2_pct_per_h", .25) * dt)
	o2_kg = maxf(0.0, o2_kg - people * MHResources.setting("o2_per_person", .84) / 24.0 * dt)
	co2_kg += people * MHResources.setting("co2_per_person", 1.0) / 24.0 * dt
	# A leak takes the air out, O₂ and CO₂ alike.
	if leak_pct_per_h > 0.0:
		var share := clampf(leak_pct_per_h / 100.0 * dt, 0.0, 1.0)
		o2_kg -= o2_kg * share
		co2_kg -= co2_kg * share
	if life:
		co2_kg = maxf(air_kg * .0004 / CO2_VOL, co2_kg - m("cabin_scrub_kg_per_h", .1) * dt)
		# Remake the O₂ (and make up a leak) as fast as it can, paid in power.
		var short := air_kg * .209 / O2_VOL - o2_kg
		if short > 0.0:
			var cost := n("o2_make_kwh_per_kg", 1.5)
			var feed := minf(minf(short, m("cabin_o2_make_kg_per_h", .3) * dt), battery_kwh / cost)
			o2_kg += feed
			battery_kwh = maxf(0.0, battery_kwh - feed * cost)
			draw += feed * cost / maxf(dt, .0001)
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
	temp_c -= m("cabin_vent_heat_c", 4.0)

## The hatch is shut and latched: the airlock's buffer refills the cabin,
## and the core pays for it from the battery when it can (power + hull: no
## tank). Returns the battery it took (kWh).
func repressurise() -> float:
	if not vented: return 0.0
	vented = false
	o2_kg = air_kg * .209 / O2_VOL
	co2_kg = air_kg * .0004 / CO2_VOL
	return take_energy(m("cabin_repress_o2_kg", .03) * n("o2_make_kwh_per_kg", 1.5))

## Pallet 2's power pack is set up: a solar blanket and a battery, which
## arrives part-charged.
func add_power_pack(kw: float, kwh: float, charge := .5) -> void:
	pack_kw += kw
	pack_kwh += kwh
	battery_cap += kwh
	battery_kwh = minf(battery_cap, battery_kwh + kwh * charge)

## The blanket and its battery taken away (3c: carried to the module). The
## battery takes its share of the charge with it; returns that share (0-1).
func remove_power_pack(kw: float, kwh: float) -> float:
	if pack_kwh < kwh - .001: return 0.0
	var share := battery_kwh / maxf(.001, battery_cap)
	pack_kw = maxf(0.0, pack_kw - kw)
	pack_kwh = maxf(0.0, pack_kwh - kwh)
	battery_cap -= kwh
	battery_kwh = minf(battery_cap, battery_kwh - kwh * share)
	return share

## Melted ice (or anything drinkable) into the tank; returns what fitted.
func add_water(litres: float) -> float:
	var got := clampf(litres, 0.0, water_cap - water_l)
	water_l += got
	if got > 0.0: dry_hours = 0.0
	return got

## Sols of drinking left in the tank.
func water_sols() -> float:
	return water_l / maxf(.01, n("water_per_sol_l", 3.0))

## Gone without water long enough to hurt.
func thirsty() -> bool:
	return dry_hours >= n("thirst_after_h", 12.0)

## Up to `kg` of oxygen made for a suit, paid from the battery; nothing
## without power or with the life support off. Returns what it gave.
func take_oxygen(kg: float) -> float:
	if not life_on(): return 0.0
	var cost := n("o2_make_kwh_per_kg", 1.5)
	var got := clampf(kg, 0.0, battery_kwh / cost)
	battery_kwh -= got * cost
	return got

## Seams patched: the hull back up by `pct`, and the leak rate set again by
## the room (scripts/module_life.gd).
func mend_hull(pct: float) -> void:
	hull_pct = clampf(hull_pct + pct, 0.0, 100.0)

func damage_hull(pct: float) -> void:
	hull_pct = clampf(hull_pct - pct, 0.0, 100.0)

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
	var copy = get_script().new(prefix)
	copy.load_state(export_state())
	var out := {"power": -1.0, "air": -1.0, "cold": -1.0, "oxygen": -1.0}
	var hour := start_hour
	var t := 0.0
	while t < horizon:
		copy.advance(.25, hour)
		hour = wrapf(hour + .25, 0.0, 24.0)
		t += .25
		if out.power < 0.0 and not copy.powered(): out.power = t
		if out.air < 0.0 and copy.co2_pct() + copy.still_co2_pct >= CO2_LIMITS[0]: out.air = t
		if out.oxygen < 0.0 and copy.o2_pct() < O2_LIMITS[0]: out.oxygen = t
		if out.cold < 0.0 and copy.temp_c < COLD_LIMITS[0]: out.cold = t
	return out

# ---------- the alerts ----------

## The cabin's alerts, in the alerts engine's shape: {id, level, title, text,
## chain}. `ahead` is a runway() result (optional): it adds the times.
func alerts(ahead: Dictionary = {}) -> Array:
	var out: Array = []
	var life_link := ["wind", "Life support " + (heater_mode if life_on() else ("off" if powered() else "no power")), life_on()]
	var co2 := co2_pct() + still_co2_pct
	if co2 >= CO2_LIMITS[0]:
		out.append({"id": prefix + "_co2", "level": "critical" if co2 >= CO2_LIMITS[1] else "warning", "title": room_name + " air going stale",
			"text": ("CO₂ at %.1f%% round you: with the fans off, your breath pools. Suit up, or get the power back." if still_co2_pct > .3 else "CO₂ at %.1f%%. Life support needs power and switching on.") % co2,
			"chain": [life_link, ["heart-pulse", "You", false]]})
	var o2 := o2_pct()
	if o2 < O2_LIMITS[0]:
		out.append({"id": prefix + "_o2", "level": "critical" if o2 < O2_LIMITS[1] else "warning", "title": room_name + " oxygen low",
			"text": "O₂ at %.1f%%%s." % [o2, ": the leak is beating the life support. Find it and patch it" if leaking() else ""], "chain": [life_link, ["heart-pulse", "You", false]]})
	if leaking():
		out.append({"id": prefix + "_leak", "level": "warning", "title": room_name + " leaking air",
			"text": "Hull at %d%%. Listen for the hiss and look for frost: a patch kit seals it. Until then the life support makes up the air, and it costs power." % roundi(hull_pct),
			"chain": [["triangle-alert", "Leak", false], ["zap", "Battery %d%%" % roundi(battery_pct()), powered()], life_link]})
	if temp_c < COLD_LIMITS[0]:
		out.append({"id": prefix + "_cold", "level": "critical" if temp_c < COLD_LIMITS[1] else "warning", "title": room_name + " cold",
			"text": "%d °C inside. Life support is %s%s." % [roundi(temp_c), heater_mode, "" if powered() else ", with no power"],
			"chain": [["flame", "Life support " + heater_mode, life_on()], ["thermometer", "%d °C" % roundi(temp_c), false]]})
	if not drinks: pass
	elif water_l <= 0.0:
		out.append({"id": "cabin_water", "level": "critical", "title": "No water left",
			"text": "The lander's tank is dry. Ice melts into it.", "chain": [["droplet", "Tank empty", false]]})
	elif water_sols() < 1.0:
		out.append({"id": "cabin_water", "level": "warning", "title": "Water low",
			"text": "%.1f L left: under a sol." % water_l, "chain": [["droplet", "Tank %.1f L" % water_l, false]]})
	if not powered():
		out.append({"id": prefix + "_power", "level": "warning", "title": room_name + " battery flat",
			"text": "Life support and lights are off until the sun charges it. It'll get cold first, then the air goes stale. When it's back, Low on the rack's switch makes it last.", "chain": [["zap", "Battery 0%", false], ["sun", "Waiting for the sun", true]]})
	elif float(ahead.get("power", -1.0)) >= 0.0 and float(ahead.power) <= 4.0:
		out.append({"id": prefix + "_power", "level": "advisory", "title": room_name + " battery runs out at %s" % _clock_after(float(ahead.power)),
			"text": "At this rate. Heating is the biggest load: set life support to Low (the switch on the rack) to save it." + (" The leak adds to it." if leaking() else ""), "chain": [["zap", "Battery %d%%" % roundi(battery_pct()), false], ["flame", "Life support " + heater_mode, true]]})
	return out

static func _clock_after(hours: float) -> String:
	var at := fmod(MHGame.sol_hour + hours, 24.0)
	return "%02d:%02d" % [int(at), int(fmod(at, 1.0) * 60.0)]

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"battery_kwh": battery_kwh, "o2_kg": o2_kg, "co2_kg": co2_kg, "temp_c": temp_c,
		"heater": heater_mode, "lights": lights_on, "people": people, "vented": vented, "pack_kw": pack_kw, "pack_kwh": pack_kwh,
		"water_cap": water_cap, "water_l": water_l, "dry_hours": dry_hours, "still_co2_pct": still_co2_pct,
		"hull_pct": hull_pct, "leak_pct_per_h": leak_pct_per_h}

func load_state(state: Dictionary) -> void:
	if state.is_empty(): return
	pack_kw = float(state.get("pack_kw", 0.0))
	pack_kwh = float(state.get("pack_kwh", 0.0))
	battery_cap = m("cabin_battery_kwh", 6.0) + pack_kwh
	battery_kwh = clampf(float(state.get("battery_kwh", battery_kwh)), 0.0, battery_cap)
	o2_kg = float(state.get("o2_kg", o2_kg))
	co2_kg = float(state.get("co2_kg", co2_kg))
	temp_c = float(state.get("temp_c", temp_c))
	heater_mode = str(state.get("heater", heater_mode)) if HEATER_MODES.has(str(state.get("heater", ""))) else heater_mode
	lights_on = bool(state.get("lights", lights_on))
	# Older saves (before 21 Nov) had the scrubber on its own switch: a
	# scrubber left on with the heater off becomes life support on Low.
	if state.has("scrubber") and bool(state.scrubber) and heater_mode == "off" and not bool(state.get("vented", false)): heater_mode = "low"
	hull_pct = clampf(float(state.get("hull_pct", 100.0)), 0.0, 100.0)
	leak_pct_per_h = maxf(0.0, float(state.get("leak_pct_per_h", 0.0)))
	people = float(state.get("people", people))
	vented = bool(state.get("vented", vented))
	water_cap = maxf(water_cap, float(state.get("water_cap", water_cap)))
	water_l = clampf(float(state.get("water_l", water_l)), 0.0, water_cap)
	dry_hours = float(state.get("dry_hours", 0.0))
	still_co2_pct = float(state.get("still_co2_pct", 0.0))
