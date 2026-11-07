extends Node

## The General Module's own life support (step 3c, "Keeping it alive",
## docs/systems-and-items.md §14): built into its walls, run by the same
## survival core as the lander cabin (scripts/survival_core.gd, prefix
## "module"). A CO₂ scrubber, a heater, lights and an Earth-filled oxygen
## tank, on a battery with a strip of roof solar: enough for the days, not a
## heated night. Pallet 2's solar blanket and battery, rolled up from beside
## the lander and laid out at the module's outside socket
## (scripts/power_pack.gd), keep it going through the night. The power kit
## carrier (Walker 3) is the real fix, later. The lander stays the backup.
##
## - The day/night clock calls advance() (the "survival_core" group).
## - Its switches sit on the General Module rack once you've placed it.
## - The body and the suit read conditions() while you're inside.

const CORE := preload("res://scripts/survival_core.gd")
const SWITCH := preload("res://scripts/cabin_switch.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const SOCKET_REACH := 16.0       # the blanket lays out this near the socket
const RACK := "general_module_rack"
## The switches on the rack's front (its local frame), left to right.
const SWITCH_SPOTS := {"heater": Vector3(-.3, 1.45, .36), "lights": Vector3(-.08, 1.45, .36), "scrubber": Vector3(.14, 1.45, .36)}

var world: Node
var core: RefCounted
var switches := {}
var socket: StaticBody3D
var ahead := {}
var _since_runway := 99.0
var _socket_lamp: StandardMaterial3D
var _rack: Node3D

func setup(target_world: Node, state: Dictionary = {}) -> void:
	world = target_world
	name = "ModuleLife"
	add_to_group("survival_core")
	core = CORE.new("module")
	if state.is_empty():
		core.heater_mode = "low"
		core.temp_c = 12.0
	core.load_state(state)
	_build_socket.call_deferred()

## The carried zone (scripts/build_rules.gd), or {}.
func zone() -> Dictionary:
	for z in world.builder.zones:
		if bool(z.get("carried", false)): return z
	return {}

func running() -> bool:
	return MHGame.simulation_on() and not zone().is_empty()

func breathable() -> bool:
	return not bool(core.vented)

func player_inside() -> bool:
	var player: Node3D = world.get("player")
	if player == null or world.builder.build_mode: return false
	if not world.builder.is_inside(player.global_position): return false
	var cell := Vector2i(roundi(player.global_position.x / world.builder.CELL), roundi(player.global_position.z / world.builder.CELL))
	return (zone().get("cells", []) as Array).has(cell)

## Lights on and powered: the builder's lamps follow this (grid_power_online).
func lit() -> bool:
	return bool(core.powered()) and bool(core.lights_on)

func advance(hours: float, start_hour: float) -> void:
	if not running() or hours <= 0.0: return
	core.people = 1.0 if player_inside() else 0.0
	core.advance(hours, start_hour)

func toggle(which: String) -> void:
	match which:
		"heater": core.heater_mode = {"warm": "low", "low": "off", "off": "warm"}[core.heater_mode]
		"lights": core.lights_on = not core.lights_on
		"scrubber": core.scrubber_on = not core.scrubber_on
	MHAudio.sfx("ui_click", -4.0, .05)
	_since_runway = 99.0
	for s in switches.values(): s.refresh()
	world.builder.refresh_power_grid()

func conditions() -> Dictionary:
	return core.conditions()

func alerts() -> Array:
	if not running(): return []
	return core.alerts(ahead)

## Pallet 2's blanket laid out here, or taken away again.
func blanket(on: bool, charge := .5) -> float:
	var kw := MHResources.revamp("power_pack_kw", 1.5)
	var kwh := MHResources.revamp("power_pack_kwh", 10.0)
	var share := charge
	if on: core.add_power_pack(kw, kwh, charge)
	else: share = core.remove_power_pack(kw, kwh)
	_since_runway = 99.0
	_refresh_socket()
	world.builder.refresh_power_grid()
	var notes: Node = world.get("notes")
	if on and notes != null: notes.answer("module_power")
	return share

func has_blanket() -> bool:
	return float(core.pack_kwh) > 0.0

func _process(delta: float) -> void:
	if not running(): return
	_since_runway += delta
	if _since_runway > 1.0:
		_since_runway = 0.0
		var was_lit := lit()
		ahead = core.runway(MHGame.sol_hour)
		for s in switches.values(): s.refresh()
		_refresh_socket()
		if was_lit != lit() or randf() < .1: world.builder.refresh_power_grid()
		if _rack == null or not is_instance_valid(_rack): _hook_rack()

# ---------- the outside socket ----------

## Where the blanket's cable plugs in: on the module's wall nearest the
## lander, at waist height. A plate and a lamp (amber: on its own battery;
## green: the blanket's in). No lettering.
func _build_socket() -> void:
	var z := zone()
	if z.is_empty() or socket != null: return
	var at := socket_spot()
	socket = StaticBody3D.new()
	socket.name = "ModuleSocket"
	socket.set_meta("interaction_target", self)
	world.add_child(socket)
	socket.global_position = at
	var lander: Vector3 = world.lander.global_position
	var outward := Vector3(at.x - _centre().x, 0, at.z - _centre().z).normalized()
	socket.rotation.y = atan2(outward.x, outward.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.4, .4, .2)
	shape.shape = box
	socket.add_child(shape)
	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.34, .34, .08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3A3F45")
	mat.resource_name = "graphite_socket"
	mesh.material = mat
	plate.mesh = mesh
	socket.add_child(plate)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = .03
	bulb.height = .06
	_socket_lamp = StandardMaterial3D.new()
	_socket_lamp.emission_enabled = true
	_socket_lamp.resource_name = "socket_lamp"
	bulb.material = _socket_lamp
	lamp.mesh = bulb
	lamp.position = Vector3(.1, .1, .05)
	socket.add_child(lamp)
	_refresh_socket()

func _centre() -> Vector3:
	var cells: Array = zone().get("cells", [])
	var sum := Vector2.ZERO
	for c in cells: sum += Vector2(c.x, c.y)
	sum = sum / maxf(1.0, cells.size()) * float(world.builder.CELL)
	return Vector3(sum.x, float(world.builder.habitat_base_y), sum.y)

## The middle of the module's wall facing the lander, just outside it.
func socket_spot() -> Vector3:
	var b: Node = world.builder
	var cells: Array = zone().get("cells", [])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in cells:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
	var half := float(b.CELL) * .5
	var mn := lo * float(b.CELL) - Vector2(half, half)
	var mx := hi * float(b.CELL) + Vector2(half, half)
	var lander: Vector3 = world.lander.global_position
	var mid := (mn + mx) * .5
	var to := Vector2(lander.x, lander.z) - mid
	var spot := mid
	# The wall facing the lander, a hand's width out from it.
	if absf(to.x) / maxf(.01, mx.x - mn.x) > absf(to.y) / maxf(.01, mx.y - mn.y):
		spot.x = (mx.x + .25) if to.x > 0.0 else (mn.x - .25)
	else:
		spot.y = (mx.y + .25) if to.y > 0.0 else (mn.y - .25)
	return Vector3(spot.x, float(b.habitat_base_y) + 1.0, spot.y)

func near_socket(at: Vector3) -> bool:
	if zone().is_empty(): return false
	var spot := socket_spot()
	return Vector2(at.x - spot.x, at.z - spot.z).length() < SOCKET_REACH

func _refresh_socket() -> void:
	if _socket_lamp == null: return
	var colour := Color("#5BE38A") if has_blanket() else Color("#F2B544")
	_socket_lamp.albedo_color = colour.darkened(.3)
	_socket_lamp.emission = colour
	_socket_lamp.emission_energy_multiplier = 2.0 if core.powered() else .3

func interaction_prompt() -> Dictionary:
	var words := "the solar blanket's plugged in" if has_blanket() else "on its own battery, %d%%" % roundi(core.battery_pct())
	return {"label": "Module power socket · " + words}

func interact(_actor: Node = null) -> bool:
	return false

# ---------- the switches, on the rack ----------

func _hook_rack() -> void:
	for node in world.builder.root.find_children("Interior_*", "Node3D", true, false):
		if str(node.get_meta("equipment_id", "")) != RACK: continue
		_rack = node
		for kind in SWITCH_SPOTS:
			var s: StaticBody3D = switches.get(kind)
			if s == null or not is_instance_valid(s):
				s = SWITCH.new()
				_rack.add_child(s)
				s.setup(self, kind)
				switches[kind] = s
			s.position = SWITCH_SPOTS[kind]
		return

func export_state() -> Dictionary:
	return core.export_state()
