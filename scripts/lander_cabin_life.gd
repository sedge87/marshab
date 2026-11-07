extends Node

## The lander cabin, run by the new survival core (scripts/survival_core.gd;
## docs/systems-and-items.md §14 step 1). It's the first "base": a small
## battery charged by the lander's panels, a heater, the lights and a CO₂
## scrubber, each on a wall switch, and an oxygen tank behind a regulator.
## Night one is a real choice: the battery can't run the heater, lights and
## scrubber all night.
##
## - The day/night clock calls advance() with the game hours that pass.
## - The cabin's real lights follow the core: they flicker when the battery is
##   nearly flat and go out without power, leaving a dim red emergency glow.
## - A landing seat is where you sleep (Z).
## - The body (scripts/body.gd) reads conditions() while you're in here.

const CORE := preload("res://scripts/survival_core.gd")
const SWITCH := preload("res://scripts/cabin_switch.gd")
## Switch spots on the back wall, left of the console (lander space, above the deck).
## The oxygen port (scripts/cabin_o2_port.gd): on the curved back wall beside
## the switches (the side away from the locker), facing the middle of the cabin.
const PORT_SPOT := Vector3(.12, 1.12, 2.16)
const PORT := preload("res://scripts/cabin_o2_port.gd")
const SWITCH_SPOTS := {"heater": Vector3(-.95, 1.45, 2.06), "lights": Vector3(-.72, 1.45, 2.1), "scrubber": Vector3(-.49, 1.45, 2.13)}

var world: Node
var core: RefCounted
var switches := {}
var port: StaticBody3D         # the oxygen port and its dial
var ahead := {}                  # the latest runway(), refreshed about once a second
var _since_runway := 99.0
var _emergency: OmniLight3D
var _flicker := 0.0
var _seat_hooked := false

func setup(target_world: Node, state: Dictionary = {}) -> void:
	world = target_world
	name = "CabinLife"
	add_to_group("survival_core")
	core = CORE.new()
	core.load_state(state)
	var lander: Node3D = world.lander
	for kind in SWITCH_SPOTS:
		var s: StaticBody3D = SWITCH.new()
		lander.add_child(s)
		s.position = SWITCH_SPOTS[kind] + Vector3(0, lander.DECK, 0)
		s.setup(self, kind)
		switches[kind] = s
	port = PORT.new()
	lander.add_child(port)
	port.position = PORT_SPOT + Vector3(0, lander.DECK, 0)
	port.rotation.y = atan2(-PORT_SPOT.x, -PORT_SPOT.z)
	port.setup(self)
	_emergency = OmniLight3D.new()
	_emergency.name = "CabinEmergencyLight"
	_emergency.light_color = Color("#FF3B2E")
	_emergency.light_energy = .25
	_emergency.omni_range = 3.0
	_emergency.position = Vector3(0, lander.CEILING - .3, .9)
	_emergency.visible = false
	lander.add_child(_emergency)
	_apply_lights(0.0)
	# The hatch (scripts/crew_lander.gd): opening vents the cabin, sealing repressurises it.
	if lander.has_signal("vented"):
		lander.vented.connect(_on_vented)
		lander.sealed.connect(_on_sealed)

func _on_vented() -> void:
	core.vent()
	_since_runway = 99.0

func _on_sealed() -> void:
	core.repressurise()
	_since_runway = 99.0

## Is there air to breathe in the cabin (the hatch shut and sealed)?
func breathable() -> bool:
	return not bool(core.vented)

## Is the cabin running? Only in modes with the simulation, and while the lander stands.
func running() -> bool:
	return MHGame.simulation_on() and world.lander != null and bool(world.lander.present)

## Game hours passing (the day/night clock).
func advance(hours: float, start_hour: float) -> void:
	if not running() or hours <= 0.0: return
	core.people = 1.0 if player_inside() and breathable() else 0.0
	core.advance(hours, start_hour)

## A cartridge plugged into the port: the tank grows by its oxygen, full.
func add_cartridge(oxygen_kg: float) -> void:
	core.tank_cap += oxygen_kg
	core.tank_o2_kg = core.tank_cap
	_since_runway = 99.0

func player_inside() -> bool:
	return world.player != null and bool(world.lander.cabin_contains(world.player.global_position))

func toggle(which: String) -> void:
	match which:
		"heater": core.heater_mode = {"warm": "low", "low": "off", "off": "warm"}[core.heater_mode]
		"lights": core.lights_on = not core.lights_on
		"scrubber": core.scrubber_on = not core.scrubber_on
	MHAudio.sfx("ui_click", -4.0, .05)
	_since_runway = 99.0
	for s in switches.values(): s.refresh()

## What the body feels in here.
func conditions() -> Dictionary:
	return core.conditions()

## The alerts engine's cabin alerts.
func alerts() -> Array:
	if not running(): return []
	return core.alerts(ahead)

func _process(delta: float) -> void:
	if not running(): return
	_since_runway += delta
	if _since_runway > 1.0:
		_since_runway = 0.0
		ahead = core.runway(MHGame.sol_hour)
		for s in switches.values(): s.refresh()
	_apply_lights(delta)
	if not _seat_hooked: _hook_seat()

## The cabin's lamps follow the core: steady, flickering near flat, or out.
func _apply_lights(delta: float) -> void:
	var lander: Node = world.lander
	var lit: bool = core.powered() and core.lights_on
	var level := 1.0 if lit else 0.0
	if lit and core.battery_pct() < 6.0:
		_flicker -= delta
		if _flicker <= 0.0: _flicker = randf_range(.05, .6)
		level = .25 if _flicker < .08 else .8
	for light in lander.cabin_lights: (light as Light3D).light_energy = float(light.get_meta("full_energy", light.light_energy)) * level
	if lander.cabin_glow != null: lander.cabin_glow.emission_energy_multiplier = .9 * level
	_emergency.visible = not core.powered()

## A landing seat is your bed in the cabin: Z sleeps there.
func _hook_seat() -> void:
	var seat: Node = world.lander.get_node_or_null("Cabin_landing_seat_1")
	if seat == null: return
	seat.set_meta("interaction_target", self)
	_seat_hooked = true

func interaction_prompt() -> Dictionary:
	return {"label": "Landing seat", "sleep": "Sleep"}

func interact(_actor: Node = null) -> bool:
	return false

func interact_sleep(_actor: Node = null) -> bool:
	if world.get("sleep") == null: return false
	world.sleep.open()
	return true

func export_state() -> Dictionary:
	return core.export_state()
