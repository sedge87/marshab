extends RefCounted

## The habitat's life-support simulation: stores (battery charge, water, food,
## oxygen reserve, cabin air, each room's temperature, crew health) and the
## flows that fill and drain them. It steps through game hours, so real-time
## play and fast-forward tests behave the same. Numbers come from
## data/resources.json (docs/MarsHabitat_Balance.xlsx); docs/resource-model.md
## explains the rules.
const MHResources := preload("res://scripts/mh_resources.gd")

const STEP_HOURS := 0.1
## Shedding order when power runs short: 1 survives longest.
const TIER_LIFE := 1
const TIER_HEAT := 2
const TIER_LIGHT := 3
const TIER_OTHER := 4
const TIER_NAMES := {1: "life support", 2: "heating", 3: "lights", 4: "labs, galley, drills and grow lights"}
const LIFE_ITEMS := ["air_recycler", "oxygen_generator", "water_reclaimer", "thermal_control_unit", "airlock_control_panel", "power_distribution_panel"]
const HEAT_ITEMS := ["wall_cabin_heater", "portable_utility_heater"]
const LIGHT_ITEMS := ["task_light", "corridor_light_strip", "high_light_post"]
## Set true to let each air recycler also make oxygen (used before the Oxygen
## Generator model existed).
const RECYCLER_MAKES_OXYGEN := false
const WORK_ROOMS := ["science", "hydroponics", "engineering", "communications", "life_support", "medical", "storage", "waste_management", "vehicle_bay"]
const AIR_DENSITY := 1.2      # kg per m3 of cabin air
const CELL_VOLUME := 26.1     # m3: 3 x 3 x 2.9 m
const THERMAL_MASS_KWH_PER_C := 0.07  # per cell: air, structure and contents

var builder: Node

# ---- stores (saved) ----
var battery_kwh := 0.0
var water_l := 0.0
var food_kg := 0.0
var o2_reserve_kg := 0.0
var o2_pct := 21.0
var co2_pct := 0.04
## One temperature for the whole habitat (merged from per-room, 23 Oct): like
## Subnautica, everything you monitor is base-wide. room_temp still gives each
## room a reading: heated rooms share habitat_temp; airlocks and the vehicle
## bay are unheated by design and sit between it and outside.
var habitat_temp := 20.0
## Heated rooms the heating can't keep up with (see _heat_coverage).
var cold_spots: Array = []
var room_temp := {}           # room key -> degrees C (derived, see _sync_room_temps)
const UNHEATED := ["airlock", "vehicle_bay"]
var crew_health := 100.0
## Why crew health is falling right now (plain words), for the HUD.
var health_causes: Array = []
## Missions: at most this many crew aboard (0 while robots build; -1 = no cap).
var crew_cap := -1
## Mars-made building material printed so far (kg), by regolith printers fed
## by a running regolith intake. BuildController spends it on printable things.
var printed_kg := 0.0
## The fast-forward Test may take bigger steps for long runs (100 sols).
var run_step := STEP_HOURS
var crew_evacuated := false
var storm_hours_left := 0.0
## How much sunlight this storm blocks (0-1); -1 uses the site's usual storm.
## Mission 5's planet-wide storm blocks far more than a regional one.
var storm_cut := -1.0
## Hours until a forecast storm arrives (-1: none forecast). Orbiters map
## Mars weather every sol, so storms come with a warning.
var storm_eta_hours := -1.0
var hours_run := 0.0
## A core sample in the Science Lab (GAR-Y, Mission 6): research +20% while this lasts.
var research_boost_hours := 0.0
var _known_capacity := {"kwh": 0.0, "water": 0.0, "o2": 0.0}
var _food_delivered := false

# ---- latest step (for the HUD, not saved) ----
var last := {}
var _inventory: Dictionary = {}
var _pending_hours := 0.0
var _stale_power := true
var _rng := RandomNumberGenerator.new()
## Room lighting. Each room is "on", "dim" (night strips) or "off". Auto:
## on where the crew are scheduled to be this hour or where you are, dim
## elsewhere. A wall panel can force a room (saved). Lighting power follows.
var light_overrides := {}      # room key -> "on" | "dim" | "off"
var player_room := ""          # room key you're in (set by the world)
const LIGHT_FACTOR := {"on": 1.0, "dim": .12, "off": 0.0}

func light_state(room: Dictionary, occupants: float) -> String:
	var forced := str(light_overrides.get(room.key, ""))
	if not forced.is_empty(): return forced
	return "on" if occupants > .25 or str(room.key) == player_room else "dim"

## Every room's light state right now: {room key: "on" | "dim" | "off"}.
func room_light_states(hour: float) -> Dictionary:
	var inv := inventory()
	var people := _crew_by_room(inv.rooms, crew_count_for(inv.capacity), hour)
	var states := {}
	for index in range(inv.rooms.size()):
		states[inv.rooms[index].key] = light_state(inv.rooms[index], float(people[index]))
	return states

## Random dust storms in play; Mission tests script their storms instead.
var random_storms := true

func _init(owner: Node = null) -> void:
	builder = owner
	_rng.randomize()

## Call whenever the layout or an item's switch changes.
func invalidate() -> void:
	_inventory = {}
	_stale_power = true

# ---------- saving ----------

func save() -> Dictionary:
	return {"battery_kwh": battery_kwh, "water_l": water_l, "food_kg": food_kg, "o2_reserve_kg": o2_reserve_kg, "o2_pct": o2_pct, "co2_pct": co2_pct,
		"habitat_temp": habitat_temp, "crew_health": crew_health, "crew_evacuated": crew_evacuated, "storm_hours_left": storm_hours_left, "storm_eta_hours": storm_eta_hours,
		"hours_run": hours_run, "known_capacity": _known_capacity.duplicate(), "food_delivered": _food_delivered, "printed_kg": printed_kg, "light_overrides": light_overrides.duplicate(), "research_boost_hours": research_boost_hours}

func load(state: Dictionary) -> void:
	if state.is_empty(): return
	battery_kwh = float(state.get("battery_kwh", 0.0)); water_l = float(state.get("water_l", 0.0)); food_kg = float(state.get("food_kg", 0.0))
	o2_reserve_kg = float(state.get("o2_reserve_kg", 0.0)); o2_pct = float(state.get("o2_pct", 21.0)); co2_pct = float(state.get("co2_pct", 0.04))
	# Older saves kept a temperature per room: the warmest heated one stands in.
	habitat_temp = float(state.get("habitat_temp", -999.0))
	if habitat_temp < -500.0:
		var old: Dictionary = state.get("room_temp", {})
		habitat_temp = float(old.values().max()) if not old.is_empty() else 20.0
	room_temp = {}
	crew_health = float(state.get("crew_health", 100.0)); crew_evacuated = bool(state.get("crew_evacuated", false))
	storm_hours_left = float(state.get("storm_hours_left", 0.0)); storm_eta_hours = float(state.get("storm_eta_hours", -1.0)); hours_run = float(state.get("hours_run", 0.0))
	_known_capacity = (state.get("known_capacity", _known_capacity) as Dictionary).duplicate()
	_food_delivered = bool(state.get("food_delivered", false))
	printed_kg = float(state.get("printed_kg", 0.0))
	light_overrides = (state.get("light_overrides", {}) as Dictionary).duplicate()
	research_boost_hours = float(state.get("research_boost_hours", 0.0))
	invalidate()

# ---------- what is in the habitat ----------

func _room_key(zone: Dictionary) -> String:
	if zone.has("angled_mount"):
		var at: Variant = zone.angled_mount.get("position", zone.angled_mount.get("start", Vector2.ZERO))
		return "%s@%s" % [str(zone.kind), str(at)]
	var cells: Array = zone.get("cells", [])
	return "%s@%s" % [str(zone.kind), str(cells[0]) if not cells.is_empty() else "?"]

## Rooms, items, power sources and drills, rebuilt only when the habitat changes.
func inventory() -> Dictionary:
	# Rebuilt when invalidated, or when the zone or item lists are replaced.
	if not _inventory.is_empty() and is_same(_inventory.get("zones_ref"), builder.zones) and int(_inventory.get("zone_count", -1)) == builder.zones.size() 			and is_same(_inventory.get("items_ref"), builder.placed_interior) and int(_inventory.get("item_count", -1)) == builder.placed_interior.size():
		return _inventory
	_stale_power = true
	var cell_size: float = BuildController.CELL
	var area_per_cell := MHResources.setting("hull_area_per_cell", 27.0)
	var rooms: Array = []
	var room_of_cell := {}
	for zone in builder.zones:
		if not builder._is_habitat_zone(zone): continue
		var kind := str(zone.kind)
		var cells: Array = zone.get("cells", [])
		var count := cells.size()
		var hull := 0.0
		if count == 0:
			count = builder._angled_corridor_bays(float(zone.angled_mount.get("length", cell_size))) if zone.has("angled_mount") and kind == "corridor" else 1
			hull = count * area_per_cell
		else:
			# Roof and floor of every cell, plus each wall facing Mars: compact
			# layouts lose less heat, like real habitats.
			for cell in cells:
				hull += cell_size * cell_size * 2.0
				for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if not builder._is_habitat_zone(builder._zone_across(cell, side)): hull += cell_size * BuildController.ROOM_HEIGHT
		var room := {"key": _room_key(zone), "kind": kind, "label": str(BuildController.ZONE_TYPES.get(kind, {}).get("label", kind)), "cells": count, "hull_m2": hull,
			"windows": 0, "zone": zone, "next": []}
		for cell in cells: room_of_cell[cell] = rooms.size()
		rooms.append(room)
	# Rooms that share a wall: a spot heater also warms the rooms next door.
	for index in range(rooms.size()):
		for cell in rooms[index].zone.get("cells", []):
			for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var other: int = room_of_cell.get(cell + side, -1)
				if other >= 0 and other != index and not (rooms[index].next as Array).has(other): rooms[index].next.append(other)
	for window in builder.hull_windows:
		var inside: Vector2 = Vector2(window.mid) - Vector2(window.dir) * .75
		var cell := Vector2i(roundi(inside.x / cell_size), roundi(inside.y / cell_size))
		if room_of_cell.has(cell): rooms[room_of_cell[cell]].windows += 1
	# Equipment inside rooms.
	var items: Array = []
	for placed in builder.placed_interior:
		var id := str(placed.get("id", ""))
		var balance := MHResources.item(id)
		if balance.is_empty(): continue
		var room_index: int = room_of_cell.get(placed.get("zone_cell", Vector2i(999999, 0)), -1)
		if room_index < 0:
			var at: Vector3 = placed.get("position", Vector3.ZERO)
			room_index = room_of_cell.get(Vector2i(roundi(at.x / cell_size), roundi(at.z / cell_size)), -1)
		items.append(_item_record(id, balance, placed.get("state", {}), room_index))
	# Outdoor grid equipment.
	for placed in builder.placed_surface:
		var id := str(placed.get("id", ""))
		if not id in ["high_light_post", "comms_antenna"]: continue
		items.append(_item_record(id, MHResources.item(id), placed.get("state", {}), -1))
	# Generators and drills.
	var solar: Array = []
	var reactors := 0
	var drills: Array = []
	var intakes := 0
	for zone in builder.zones:
		match str(zone.kind):
			"solar":
				if builder._power_source_connected(zone): solar.append(Vector2(builder._airlock_side(zone)))
			"reactor":
				if builder._power_source_connected(zone) and builder._zone_running(zone): reactors += 1
			"ice_extractor":
				if builder._zone_running(zone): drills.append(builder._ice_richness_at(zone.cells[0]))
			"regolith_intake":
				if builder._zone_running(zone): intakes += 1
	var isolated := false
	for placed in builder.placed_interior:
		var isolator := EquipmentCatalog.grid_isolator_key(str(placed.get("id", "")))
		if not isolator.is_empty() and not bool((placed.get("state", {}) as Dictionary).get(isolator, true)): isolated = true
	var capacity := {"kwh": 0.0, "water": 100.0, "o2": 0.0, "food": 0.0, "tcu_kw": 0.0, "berths": 0}
	for item in items:
		capacity.kwh += item.stores_kwh; capacity.water += item.stores_water; capacity.o2 += item.stores_o2; capacity.food += item.stores_food
		capacity.berths += item.berths
		if item.id == "thermal_control_unit" and item.on: capacity.tcu_kw += item.heat_kw
	_inventory = {"rooms": rooms, "items": items, "solar": solar, "reactors": reactors, "drills": drills, "intakes": intakes, "isolated": isolated, "capacity": capacity,
		"cells": rooms.reduce(func(total, room): return total + int(room.cells), 0),
		"zones_ref": builder.zones, "zone_count": builder.zones.size(), "items_ref": builder.placed_interior, "item_count": builder.placed_interior.size()}
	_take_delivery(capacity)
	return _inventory

func _item_record(id: String, balance: Dictionary, state: Dictionary, room: int) -> Dictionary:
	var hours := float(balance.get("hours_per_sol", 0.0))
	var power := float(balance.get("power_kw", 0.0)) * (hours / 24.0 if hours > 0.0 else 1.0)
	var on := true
	var outputs := 1.0
	var gate := EquipmentCatalog.effect_gate(id)
	if not gate.is_empty() and not bool(state.get(gate.key, gate.default)):
		power = 0.0
		if str(gate.scope) == "all": outputs = 0.0; on = false
	var levels := EquipmentCatalog.levels(id)
	if not levels.is_empty():
		var steps := maxi(1, (levels.power as Array).size() - 1)
		power = float(balance.get("power_kw", 0.0)) * clampi(int(state.get(levels.key, 0)), 0, steps) / steps
	var tier := TIER_OTHER
	if id in LIFE_ITEMS: tier = TIER_LIFE
	elif id in HEAT_ITEMS: tier = TIER_HEAT
	elif id in LIGHT_ITEMS: tier = TIER_LIGHT
	var record := {"id": id, "room": room, "tier": tier, "power": power, "on": on,
		"o2": float(balance.get("o2_kg", 0.0)) * outputs, "co2": float(balance.get("co2_kg", 0.0)) * outputs,
		"water": float(balance.get("water_l", 0.0)) * outputs, "food": float(balance.get("food_kg", 0.0)) * outputs,
		"stores_kwh": float(balance.get("stores_kwh", 0.0)), "stores_water": float(balance.get("stores_water_l", 0.0)),
		"stores_o2": float(balance.get("stores_o2_kg", 0.0)), "stores_food": float(balance.get("stores_food_kg", 0.0)),
		"heat_kw": float(balance.get("heat_kw", 0.0)), "berths": int(balance.get("berths", 0.0))}
	if RECYCLER_MAKES_OXYGEN and id == "air_recycler" and on:
		var generator := MHResources.item("oxygen_generator")
		record.o2 += float(generator.get("o2_kg", 3.0)); record.water += float(generator.get("water_l", -3.4))
		record.power += float(generator.get("power_kw", 1.5))
	if HEAT_ITEMS.has(id): record.heat_kw = power   # a heater turns all its power into heat
	return record

## New batteries, water tanks and oxygen tanks arrive full from Earth.
func _take_delivery(capacity: Dictionary) -> void:
	for key in ["kwh", "water", "o2"]:
		var grown := float(capacity[key]) - float(_known_capacity.get(key, 0.0))
		if grown > 0.0:
			match key:
				"kwh": battery_kwh += grown
				"water": water_l += grown
				"o2": o2_reserve_kg += grown
		_known_capacity[key] = float(capacity[key])
	battery_kwh = minf(battery_kwh, float(capacity.kwh)); water_l = minf(water_l, float(capacity.water)); o2_reserve_kg = minf(o2_reserve_kg, float(capacity.o2))
	if not _food_delivered and crew_count_for(capacity) > 0:
		# The lander brings food for the crew when they move in.
		_food_delivered = true
		food_kg += crew_count_for(capacity) * MHResources.setting("food_per_person", 1.8) * MHResources.setting("start_food_sols", 60.0)

## Crew live in the habitat once there are bunks for them (the rest wait on the lander).
func crew_count_for(capacity: Dictionary) -> int:
	if crew_evacuated: return 0
	var crew := mini(int(MHResources.setting("crew", 6.0)), int(capacity.berths))
	return mini(crew, crew_cap) if crew_cap >= 0 else crew

func crew_count() -> int:
	return crew_count_for(inventory().capacity)

# ---------- time ----------

## Outside temperature at a game hour, matching the sky (site_day_night.gd).
static func outside_temp_at(hour: float) -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var dawn := float(cycle.get("dawn_hour", 4.0)); var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0)); var dusk := float(cycle.get("dusk_hour", 20.0))
	var light := 0.0
	if hour >= dawn and hour < dusk:
		light = smoothstep(dawn, sunrise, hour) if hour < sunrise else (1.0 if hour <= sunset else 1.0 - smoothstep(sunset, dusk, hour))
	return lerpf(float(cycle.get("night_temp_c", -60.0)), float(cycle.get("day_temp_c", -25.0)), light)

## Advance by game hours (real-time play feeds the clock's progress here).
func advance(hours: float, start_hour: float) -> void:
	_pending_hours += hours
	var hour := start_hour
	while _pending_hours >= STEP_HOURS:
		_pending_hours -= STEP_HOURS
		hour = fmod(hour + STEP_HOURS, 24.0)
		step(STEP_HOURS, hour)

## Run whole sols at once (the fast-forward test). Returns hourly samples.
func run_hours(hours: float, start_hour: float, sample_every := 1.0) -> Array:
	var samples: Array = []
	var hour := start_hour
	var since := 0.0
	var elapsed := 0.0
	while elapsed < hours - .0001:
		step(run_step, hour)
		hour = fmod(hour + run_step, 24.0)
		elapsed += run_step
		since += run_step
		if since >= sample_every - .0001:
			since = 0.0
			samples.append(snapshot(hour))
	return samples

func start_storm(sols := -1.0, cut := -1.0) -> void:
	var length := sols if sols > 0.0 else float(MHResources.site(MHGame.site_id).get("storm_sols", 3.0))
	storm_hours_left = length * 24.0
	storm_cut = cut

## The share of sunlight the current storm blocks (0 when there's no storm).
func solar_cut() -> float:
	if storm_hours_left <= 0.0: return 0.0
	return storm_cut if storm_cut >= 0.0 else float(MHResources.site(MHGame.site_id).get("storm_solar_cut", .6))
	storm_eta_hours = -1.0

## Forecasts a storm to arrive in this many hours (the HUD warns until then).
func forecast_storm(hours := -1.0) -> void:
	storm_eta_hours = hours if hours >= 0.0 else MHResources.setting("storm_warning_hours", 10.0)

# ---------- one step ----------

func step(dt: float, hour: float) -> void:
	var inv := inventory()
	var rooms: Array = inv.rooms
	var crew := crew_count_for(inv.capacity)
	var outside := outside_temp_at(hour)
	var u := MHResources.setting("hull_u", 0.25)
	var cop := MHResources.setting("heat_pump_cop", 3.0)
	var site := MHResources.site(MHGame.site_id)
	hours_run += dt
	# Dust storms (random in play; tests can start one).
	if storm_hours_left > 0.0: storm_hours_left = maxf(0.0, storm_hours_left - dt)
	if research_boost_hours > 0.0: research_boost_hours = maxf(0.0, research_boost_hours - dt)
	elif storm_eta_hours >= 0.0:
		storm_eta_hours -= dt
		if storm_eta_hours <= 0.0: start_storm()
	elif random_storms and _rng.randf() < float(site.get("dust_storms_per_100_sols", 1.0)) / 100.0 / 24.0 * dt:
		forecast_storm()
	if room_temp.size() != rooms.size(): _sync_room_temps(rooms, outside)
	# --- people: where the crew are at this hour ---
	var people := _crew_by_room(rooms, crew, hour)
	# --- room loads and heat balance before power (to size the heat pump) ---
	var night := MHGame.solar_irradiance(hour) < .05
	var room_base_kw: Array = []
	for room in rooms:
		var spec := MHResources.room(str(room.kind))
		room_base_kw.append(float(room.cells) * float(spec.get("always_kw_per_cell", .03)))
	var room_light_kw: Array = []
	for index in range(rooms.size()):
		var room: Dictionary = rooms[index]
		var level: float = LIGHT_FACTOR[light_state(room, float(people[index]))]
		room_light_kw.append(float(room.cells) * float(MHResources.room(str(room.kind)).get("light_kw_per_cell", .05)) * level if night else 0.0)
	var loss: Array = []
	var window_u := u * MHResources.setting("window_loss_factor", 6.0) * MHResources.setting("window_area", 3.0)
	for index in range(rooms.size()):
		var room: Dictionary = rooms[index]
		loss.append((float(room.hull_m2) * u + float(room.windows) * window_u) * (habitat_temp - outside) / 1000.0 if _heated(room) else 0.0)
	# Heat reaching each room, assuming everything gets power (sizes the heat pump's draw).
	var heat := _heat_coverage(rooms, inv.items, people, room_base_kw, room_light_kw, {1: true, 2: true, 3: true, 4: true}, loss, float(inv.capacity.tcu_kw))
	# --- power ---
	var tiers := {1: 0.0, 2: heat.electric_kw, 3: 0.0, 4: 0.0}
	for index in range(rooms.size()):
		tiers[TIER_LIFE] += room_base_kw[index]
		tiers[TIER_LIGHT] += room_light_kw[index]
	for item in inv.items: tiers[item.tier] += item.power
	var drill_kw := 0.0
	for richness in inv.drills: drill_kw += MHResources.item_value("ice_drill", "power_kw", 3.0)
	tiers[TIER_OTHER] += drill_kw
	tiers[TIER_OTHER] += int(inv.intakes) * MHResources.item_value("regolith_intake", "power_kw", 1.5)
	var generation := 0.0
	var storm_factor := 1.0 - solar_cut()
	generation += _solar_kw(inv.solar, hour) * storm_factor
	generation += inv.reactors * MHResources.setting("reactor_kw", 10.0)
	if MHGame.debug_free_power: generation = 1.0e6
	if inv.isolated: generation = 0.0
	var powered := _power(dt, generation, tiers, float(inv.capacity.kwh), inv.isolated)
	# --- heat with the power actually available ---
	heat = _heat_coverage(rooms, inv.items, people, room_base_kw, room_light_kw, powered.tiers, loss, float(inv.capacity.tcu_kw))
	# One habitat temperature: the heat that actually reaches the heated rooms
	# (see _heat_coverage) against all the heat they lose through the hull and
	# windows. It relaxes exponentially towards the balance temperature, which
	# is stable for long fast-forward steps.
	var hull_g := 0.0
	var mass := 0.0
	var heat_in := float(heat.useful)
	for index in range(rooms.size()):
		if not _heated(rooms[index]): continue
		hull_g += (float(rooms[index].hull_m2) * u + float(rooms[index].windows) * window_u) / 1000.0   # kW per °C to outside
		mass += float(rooms[index].cells) * THERMAL_MASS_KWH_PER_C
	if mass > 0.0:
		if hull_g <= 0.000001: habitat_temp += heat_in * dt / mass
		else:
			var balance := heat_in / hull_g + outside
			habitat_temp = balance + (habitat_temp - balance) * exp(-hull_g * dt / mass)
	cold_spots = heat.cold_spots
	_sync_room_temps(rooms, outside)
	# --- air, water, food ---
	var per_sol := dt / 24.0
	var air_kg := maxf(1.0, float(inv.cells) * CELL_VOLUME * AIR_DENSITY)
	var o2_made := 0.0
	var co2_removed := 0.0
	var water_made := 0.0
	var water_used := crew * MHResources.setting("water_per_person", 10.0) * per_sol
	var reclaim_capacity := 0.0
	var food_grown := 0.0
	for item in inv.items:
		if not powered.tiers[item.tier] and item.power > 0.0: continue
		o2_made += item.o2 * per_sol
		co2_removed += -minf(0.0, item.co2) * per_sol
		if item.water > 0.0: water_made += item.water * per_sol
		else: water_used += -item.water * per_sol
		food_grown += item.food * per_sol
		if item.id == "water_reclaimer" and item.on: reclaim_capacity += 70.0 * per_sol
	var water_recovered := minf(reclaim_capacity, crew * MHResources.setting("water_per_person", 10.0) * per_sol) * MHResources.setting("reclaim_fraction", .93)
	var drill_water := 0.0
	if powered.tiers[TIER_OTHER]:
		for richness in inv.drills: drill_water += MHResources.setting("ice_drill_l", 120.0) * float(richness) * per_sol
	water_l = clampf(water_l + water_made + water_recovered + drill_water - water_used, 0.0, float(inv.capacity.water))
	food_kg = maxf(0.0, food_kg + food_grown - crew * MHResources.setting("food_per_person", 1.8) * per_sol)
	# Printing: running printers make material while tier 4 has power and an intake feeds them.
	if powered.tiers[TIER_OTHER]: printed_kg += print_rate(inv) * per_sol
	if inv.cells > 0:
		var o2_breathed := crew * MHResources.setting("o2_per_person", .84) * per_sol
		var co2_out := crew * MHResources.setting("co2_per_person", 1.0) * per_sol
		o2_pct += (o2_made - o2_breathed) / 32.0 / (air_kg / 29.0) * 100.0
		# The scrubber can only take out what is there (down to outdoor-air levels on Earth).
		var co2_kg_now := co2_pct / 100.0 * (air_kg / 29.0) * 44.0
		co2_removed = minf(co2_removed, maxf(0.0, co2_kg_now + co2_out - 0.0004 * (air_kg / 29.0) * 44.0))
		co2_pct = maxf(0.0, co2_pct + (co2_out - co2_removed) / 44.0 / (air_kg / 29.0) * 100.0)
		# Reserve tanks top the air up when oxygen falls.
		if o2_pct < 20.5 and o2_reserve_kg > 0.0:
			var needed := (20.9 - o2_pct) / 100.0 * (air_kg / 29.0) * 32.0
			var released := minf(needed, minf(o2_reserve_kg, 2.0 * dt))
			o2_reserve_kg -= released
			o2_pct += released / 32.0 / (air_kg / 29.0) * 100.0
		o2_pct = clampf(o2_pct, 0.0, 30.0)
	# --- crew condition ---
	_crew_condition(dt, crew, rooms, people)
	last = {"hour": hour, "generation_kw": generation, "load_kw": powered.load_kw, "demand_kw": tiers[1] + tiers[2] + tiers[3] + tiers[4],
		"tiers": powered.tiers, "tier_kw": tiers, "battery_rate_kw": powered.battery_kw, "heat_pump_kw": heat.electric_kw, "outside_c": outside, "heat_wasted_kw": heat.wasted,
		"storm": storm_hours_left > 0.0, "storm_hours_left": storm_hours_left, "storm_eta": storm_eta_hours, "crew": crew, "people": people, "water_in": (water_made + water_recovered + drill_water) / per_sol,
		"water_out": water_used / per_sol, "food_in": food_grown / per_sol, "o2_in": o2_made / per_sol, "co2_out": co2_removed / per_sol,
		"heat_capacity_short": heat.short, "night": night, "free_power": MHGame.debug_free_power}

## Solar output at an hour: each array catches most light facing the sun
## (same rule as the build view's "SOLAR % AT NOON" label).
func _solar_kw(facings: Array, hour: float) -> float:
	var sun := MHGame.solar_irradiance(hour)
	if sun <= 0.0: return 0.0
	var heading := MHGame.sun_heading(hour)
	var total := 0.0
	for facing in facings: total += MHResources.setting("solar_peak_kw", 10.0) * (.55 + .45 * (facing as Vector2).dot(heading)) * sun
	return total

## The habitat's comfortable target (heat pump set point).
static func habitat_target() -> float:
	return MHResources.setting("habitat_target_c", 21.0)

static func _heated(room: Dictionary) -> bool:
	return not str(room.kind) in UNHEATED

## Each room's reading: the habitat temperature, or (airlocks and the vehicle
## bay, unheated by design) halfway between it and outside.
func _sync_room_temps(rooms: Array, outside: float) -> void:
	room_temp = {}
	for room in rooms:
		room_temp[room.key] = habitat_temp if _heated(room) else (habitat_temp + outside) * .5

## Crew positions by hour: asleep in Living Quarters at night, in the Galley at
## mealtimes, spread over the work rooms in the day.
func _crew_by_room(rooms: Array, crew: int, hour: float) -> Array:
	var people: Array = []
	for room in rooms: people.append(0.0)
	if crew <= 0 or rooms.is_empty(): return people
	var wanted: Array = ["living"]
	var h := int(hour)
	if h in [7, 12, 18]: wanted = ["galley"]
	elif (h >= 8 and h < 12) or (h >= 13 and h < 17): wanted = WORK_ROOMS
	elif h >= 19 and h < 22: wanted = ["galley", "living"]
	var choices: Array = []
	for index in range(rooms.size()):
		if str(rooms[index].kind) in wanted: choices.append(index)
	if choices.is_empty():
		for index in range(rooms.size()):
			if str(rooms[index].kind) != "corridor" and str(rooms[index].kind) != "airlock": choices.append(index)
	if choices.is_empty(): choices = range(rooms.size())
	var total_cells := 0.0
	for index in choices: total_cells += float(rooms[index].cells)
	for index in choices: people[index] = crew * float(rooms[index].cells) / total_cells
	return people

## How heat reaches the rooms (the coverage rule, 23 Oct):
##   - people, lights and machines warm the room they're in;
##   - a spot heater (wall or portable) warms its own room and the rooms next
##     door, up to what they need; heat beyond that is wasted;
##   - the thermal control unit (a ducted heat pump, about 3 kW of heat per kW
##     of power) tops up every heated room, up to its capacity;
##   - a heated room still short of what it loses is a cold spot.
## A room "needs" what it loses, plus enough to warm up towards the target.
## Returns {useful, electric_kw, short, wasted, cold_spots: [labels]}.
func _heat_coverage(rooms: Array, items: Array, people: Array, base_kw: Array, light_kw: Array, tiers: Dictionary, loss: Array, tcu_kw: float) -> Dictionary:
	var target := habitat_target()
	var need: Array = []
	var have: Array = []
	for index in range(rooms.size()):
		var room: Dictionary = rooms[index]
		var warm_up := maxf(0.0, (target - habitat_temp) * float(room.cells) * THERMAL_MASS_KWH_PER_C)
		need.append(float(loss[index]) + warm_up if _heated(room) else 0.0)
		have.append(float(people[index]) * MHResources.setting("body_heat_kw", .1) + (base_kw[index] if tiers[TIER_LIFE] else 0.0) + (light_kw[index] if tiers[TIER_LIGHT] else 0.0))
	for item in items:
		if item.room < 0 or not tiers[item.tier] or item.id == "thermal_control_unit" or HEAT_ITEMS.has(item.id): continue
		have[item.room] += item.power   # almost all electricity ends up as heat
	# Spot heaters: their room and its neighbours, filling whoever still needs heat.
	var wasted := 0.0
	for item in items:
		if not HEAT_ITEMS.has(item.id) or item.room < 0 or not tiers[item.tier] or float(item.power) <= 0.0: continue
		var kw := float(item.power)
		var reach: Array = [item.room] + (rooms[item.room].next as Array)
		reach = reach.filter(func(r): return _heated(rooms[r]))
		for attempt in 4:
			var open: Array = reach.filter(func(r): return float(have[r]) < float(need[r]) - .001)
			if open.is_empty() or kw <= .001: break
			var each := kw / open.size()
			for r in open:
				var take := minf(each, float(need[r]) - float(have[r]))
				have[r] += take
				kw -= take
		wasted += kw
	# The thermal control unit reaches every heated room.
	var short := 0.0
	for index in range(rooms.size()): short += maxf(0.0, float(need[index]) - float(have[index]))
	var delivered := 0.0
	if tiers[TIER_HEAT] and tcu_kw > 0.0 and short > 0.0:
		delivered = minf(tcu_kw, short)
		var share := delivered / short
		for index in range(rooms.size()): have[index] += maxf(0.0, float(need[index]) - float(have[index])) * share
	var useful := 0.0
	var cold: Array = []
	for index in range(rooms.size()):
		if not _heated(rooms[index]): continue
		useful += minf(float(have[index]), float(need[index]))   # heat beyond what a room needs doesn't warm the others
		if float(loss[index]) > .05 and float(have[index]) < float(loss[index]) * .9: cold.append(str(rooms[index].label))
	# Too warm: the heat pump runs backwards and takes the excess out.
	if tiers[TIER_HEAT] and tcu_kw > 0.0 and habitat_temp > target + 4.0:
		var mass := 0.0
		for index in range(rooms.size()):
			if _heated(rooms[index]): mass += float(rooms[index].cells) * THERMAL_MASS_KWH_PER_C
		var cooling := minf(tcu_kw, (habitat_temp - target - 2.0) * mass)
		useful -= cooling
		delivered += cooling
	return {"useful": useful, "electric_kw": delivered / MHResources.setting("heat_pump_cop", 3.0), "short": short > tcu_kw + .01, "wasted": wasted, "cold_spots": cold}

## Supply the highest tiers the generators and batteries can carry; shed the rest.
func _power(dt: float, generation: float, tiers: Dictionary, capacity_kwh: float, isolated := false) -> Dictionary:
	var banks := capacity_kwh / maxf(1.0, MHResources.setting("battery_kwh", 50.0))
	# The main isolator disconnects the whole grid, batteries included.
	var max_rate := 0.0 if isolated else banks * 10.0
	var can_draw := minf(max_rate, battery_kwh / dt) if battery_kwh > 0.0 else 0.0
	var available := generation + can_draw
	var on := {1: false, 2: false, 3: false, 4: false}
	var load := 0.0
	for tier in [1, 2, 3, 4]:
		if load + float(tiers[tier]) <= available + .0001:
			load += float(tiers[tier])
			on[tier] = true
		else:
			break
	var net := generation - load
	var battery_kw := clampf(net, -max_rate, max_rate)
	battery_kwh = clampf(battery_kwh + battery_kw * dt, 0.0, capacity_kwh)
	return {"tiers": on, "load_kw": load, "battery_kw": battery_kw}

func _crew_condition(dt: float, crew: int, rooms: Array, people: Array) -> void:
	health_causes = []
	if crew <= 0: return
	var harm := 0.0
	if co2_pct > 3.0: harm += 10.0; health_causes.append("CO₂ dangerous")
	elif co2_pct > MHResources.setting("co2_danger_pct", 1.0): harm += 1.0; health_causes.append("CO₂ high")
	if o2_pct < 16.0: harm += 10.0; health_causes.append("oxygen dangerous")
	elif o2_pct < MHResources.setting("o2_min_pct", 19.5): harm += 1.0; health_causes.append("oxygen low")
	for index in range(rooms.size()):
		if float(people[index]) > 0.0 and float(room_temp.get(rooms[index].key, habitat_temp)) < MHResources.setting("danger_cold_c", 5.0): harm += 3.0; health_causes.append("the habitat is freezing"); break
	if water_l <= 0.0: harm += 1.0; health_causes.append("no water")
	if food_kg <= 0.0: harm += .3; health_causes.append("no food")
	if harm > 0.0:
		if MHGame.crew_can_be_harmed():
			crew_health = maxf(0.0, crew_health - harm * dt)
			if crew_health <= 0.0: crew_evacuated = true; invalidate()
	else:
		crew_health = minf(100.0, crew_health + .5 * dt)

# ---------- reading the state ----------

## Is power reaching this tier right now (between steps too, and straight
## after something is built or switched)?
func tier_powered(tier: int, hour: float) -> bool:
	inventory()
	if _stale_power or last.is_empty() or absf(float(last.get("hour", -99.0)) - hour) > .2 or bool(last.get("free_power", false)) != MHGame.debug_free_power:
		var keep := battery_kwh
		step_power_only(hour)
		battery_kwh = keep
		_stale_power = false
	return bool((last.get("tiers", {}) as Dictionary).get(tier, false))

## Power check without moving time (after building something, for example).
func step_power_only(hour: float) -> void:
	var inv := inventory()
	var tiers := {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	var night := MHGame.solar_irradiance(hour) < .05
	var people := _crew_by_room(inv.rooms, crew_count_for(inv.capacity), hour)
	for index in range(inv.rooms.size()):
		var room: Dictionary = inv.rooms[index]
		var spec := MHResources.room(str(room.kind))
		tiers[1] += float(room.cells) * float(spec.get("always_kw_per_cell", .03))
		if night: tiers[3] += float(room.cells) * float(spec.get("light_kw_per_cell", .05)) * float(LIGHT_FACTOR[light_state(room, float(people[index]))])
	for item in inv.items: tiers[item.tier] += item.power
	for richness in inv.drills: tiers[4] += MHResources.item_value("ice_drill", "power_kw", 3.0)
	tiers[4] += int(inv.get("intakes", 0)) * MHResources.item_value("regolith_intake", "power_kw", 1.5)
	var generation := 0.0
	generation += _solar_kw(inv.solar, hour) * (1.0 - solar_cut())
	generation += inv.reactors * MHResources.setting("reactor_kw", 10.0)
	if MHGame.debug_free_power: generation = 1.0e6
	if inv.isolated: generation = 0.0
	var powered := _power(0.001, generation, tiers, float(inv.capacity.kwh), inv.isolated)
	last.merge({"hour": hour, "generation_kw": generation, "load_kw": powered.load_kw, "demand_kw": tiers[1] + tiers[2] + tiers[3] + tiers[4], "tiers": powered.tiers, "tier_kw": tiers, "free_power": MHGame.debug_free_power}, true)

## What the habitat makes and uses in a sol if everything has power: the
## Mars-made material a sol from the printers now (0 without a running intake).
func print_rate(inv: Dictionary) -> float:
	if int(inv.get("intakes", 0)) <= 0: return 0.0
	var printers := (inv.items as Array).filter(func(i): return i.id == "regolith_printer" and i.on).size()
	if printers == 0: return 0.0
	var recycling := (inv.items as Array).any(func(i): return i.id == "recycling_hopper_plastics")
	return printers * MHResources.setting("print_kg_per_sol", 2500.0) * (1.0 + (MHResources.setting("print_recycle_bonus", .25) if recycling else 0.0))

## numbers behind the readiness checklist and the systems panel.
## planned: for the full mission crew (readiness); otherwise for the crew on board now.
func daily_flows(planned := true) -> Dictionary:
	var inv := inventory()
	var crew := float(MHResources.setting("crew", 6.0)) if planned else float(crew_count_for(inv.capacity))
	var out := {"crew": crew, "berths": int(inv.capacity.berths), "o2_made": 0.0, "co2_removed": 0.0, "food_grown": 0.0, "water_made": 0.0, "water_used": crew * MHResources.setting("water_per_person", 10.0),
		"o2_need": crew * MHResources.setting("o2_per_person", .84), "co2_made": crew * MHResources.setting("co2_per_person", 1.0), "food_eaten": crew * MHResources.setting("food_per_person", 1.8), "research": 0.0}
	var reclaimers := 0
	for item in inv.items:
		if not item.on: continue
		out.o2_made += item.o2
		out.co2_removed += -minf(0.0, item.co2)
		out.food_grown += item.food
		if item.water > 0.0: out.water_made += item.water
		else: out.water_used += -item.water
		if item.id == "water_reclaimer": reclaimers += 1
		out.research += MHResources.item_value(item.id, "research")
	out.water_made += minf(reclaimers * 70.0, crew * MHResources.setting("water_per_person", 10.0)) * MHResources.setting("reclaim_fraction", .93)
	for richness in inv.drills: out.water_made += MHResources.setting("ice_drill_l", 120.0) * float(richness)
	if research_boost_hours > 0.0: out.research *= 1.2
	out["printed"] = print_rate(inv)
	return out

## Rooms where the crew live and work (not airlocks, corridors, storage or the bay).
func crewed_rooms() -> Array:
	return (inventory().rooms as Array).filter(func(room): return not str(room.kind) in ["airlock", "corridor", "storage", "vehicle_bay"])

func room_temperature(zone: Dictionary) -> float:
	return float(room_temp.get(_room_key(zone), 20.0))

## Tests start with the heating already having warmed every room (like
## full batteries): what's tested is whether it keeps them warm.
func prewarm_rooms() -> void:
	habitat_temp = maxf(habitat_temp, habitat_target())
	room_temp = {}

## One reading for graphs and test reports.
func snapshot(hour: float) -> Dictionary:
	var inv := inventory()
	# "coldest_c" (kept as the key for saved versions) is now the habitat temperature.
	var coldest := habitat_temp if not crewed_rooms().is_empty() else 99.0
	return {"hours": hours_run, "hour": hour, "battery_pct": 100.0 * battery_kwh / maxf(.001, float(inv.capacity.kwh)) if float(inv.capacity.kwh) > 0.0 else 0.0,
		"battery_kwh": battery_kwh, "generation_kw": float(last.get("generation_kw", 0.0)), "load_kw": float(last.get("load_kw", 0.0)),
		"water_l": water_l, "food_kg": food_kg, "o2_pct": o2_pct, "co2_pct": co2_pct, "coldest_c": coldest if coldest < 98.0 else 0.0,
		"crew_health": crew_health, "storm": storm_hours_left > 0.0, "all_powered": bool((last.get("tiers", {}) as Dictionary).get(4, false)),
		"life_support": bool((last.get("tiers", {}) as Dictionary).get(1, true))}

## Plain-language problems, most serious first: [{level, text}].
func warnings() -> Array:
	var out: Array = []
	if not MHGame.simulation_on(): return out
	var inv := inventory()
	var crew := crew_count_for(inv.capacity)
	if crew_evacuated: out.append({"level": "danger", "text": "The crew were evacuated to the lander. Fix the habitat, then load an earlier save or start again."})
	if inv.cells == 0: return out
	var tiers: Dictionary = last.get("tiers", {})
	if not tiers.is_empty() and not tiers.get(4, true):
		var off: Array = []
		for tier in [4, 3, 2, 1]:
			if not tiers.get(tier, true): off.append(TIER_NAMES[tier])
		var why := "a dust storm is blocking the sun" if storm_hours_left > 0.0 else ("the batteries are empty" if float(inv.capacity.kwh) > 0.0 else "there are no batteries to store power")
		out.append({"level": "danger" if not tiers.get(1, true) else "warn", "text": "Not enough power: %s switched off, because %s." % [", ".join(off), why]})
	if co2_pct > .5:
		var recyclers: Array = (inv.items as Array).filter(func(i): return i.id == "air_recycler")
		var why := "there is no air recycler" if recyclers.is_empty() else ("the air recycler has no power" if not tiers.get(1, true) else "there aren't enough air recyclers for %d crew" % crew)
		out.append({"level": "danger" if co2_pct > MHResources.setting("co2_danger_pct", 1.0) else "warn", "text": "CO₂ is %.1f%% and rising: %s." % [co2_pct, why]})
	if o2_pct < 20.0:
		out.append({"level": "danger" if o2_pct < MHResources.setting("o2_min_pct", 19.5) else "warn", "text": "Oxygen is %.1f%%: %s." % [o2_pct, "the reserve tanks are empty" if o2_reserve_kg <= 0.0 else "the reserve tanks are running down"]})
	# The habitat is cold (one temperature for the whole base).
	if not crewed_rooms().is_empty() and habitat_temp < MHResources.setting("cold_c", 12.0):
		var why := "the heating is still warming it up"
		var heaters_here: Array = (inv.items as Array).filter(func(i): return HEAT_ITEMS.has(i.id) and i.power > 0.0)
		if float(inv.capacity.tcu_kw) <= 0.0 and heaters_here.is_empty(): why = "there is no thermal control unit or heater"
		elif not tiers.get(2, true): why = "there is no power for heating"
		elif bool(last.get("heat_capacity_short", false)): why = "the heating is at full capacity"
		var windows: bool = int((inv.rooms as Array).reduce(func(total, room): return total + int(room.windows), 0)) > 0
		out.append({"level": "danger" if habitat_temp < MHResources.setting("danger_cold_c", 5.0) else "warn",
			"text": "The habitat is cold (%d °C): %s%s." % [roundi(habitat_temp), why, ", and windows lose heat" if windows else ""]})
	# Cold spots: heated rooms the heating doesn't reach well enough.
	elif not crewed_rooms().is_empty() and not cold_spots.is_empty():
		out.append({"level": "warn", "text": "Cold spot%s: %s. Not enough heat reaches %s: add a spot heater in or next to %s, or a thermal control unit (it reaches every room)." % [
			"s" if cold_spots.size() > 1 else "", ", ".join(cold_spots.slice(0, 3)), "them" if cold_spots.size() > 1 else "it", "them" if cold_spots.size() > 1 else "it"]})
	var water_per_sol := float(last.get("water_out", 0.0)) - float(last.get("water_in", 0.0))
	if crew > 0 and water_per_sol > 0.0 and water_l / water_per_sol < 3.0:
		out.append({"level": "danger" if water_l <= 0.0 else "warn", "text": "Water runs out in %.1f sols: using %d L more than is made each sol." % [water_l / water_per_sol, roundi(water_per_sol)]})
	var food_per_sol := crew * MHResources.setting("food_per_person", 1.8) - float(last.get("food_in", 0.0))
	if crew > 0 and food_per_sol > 0.0 and food_kg / food_per_sol < 10.0:
		out.append({"level": "danger" if food_kg <= 0.0 else "warn", "text": "Food runs out in %d sols." % floori(food_kg / food_per_sol)})
	if int(inv.capacity.berths) < int(MHResources.setting("crew", 6.0)):
		out.append({"level": "info", "text": "%d of %d crew have bunks; the rest wait on the lander." % [mini(int(inv.capacity.berths), int(MHResources.setting("crew", 6.0))), int(MHResources.setting("crew", 6.0))]})
	if storm_hours_left > 0.0:
		out.append({"level": "warn", "text": "Dust storm: solar output is down for about %d more sols." % ceili(storm_hours_left / 24.0)})
	elif storm_eta_hours >= 0.0:
		out.append({"level": "warn", "text": "Dust storm forecast in %d hours: charge the batteries and cut what you don't need." % ceili(storm_eta_hours)})
	return out
