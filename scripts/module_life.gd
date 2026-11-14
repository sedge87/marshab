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
const LEAK := preload("res://scripts/module_leak.gd")
const COLD_START_C := -30.0      # version 2: set down cold, open to Mars, dark
## The switches on the rack's front (its local frame), left to right.
const SWITCH_SPOTS := {"heater": Vector3(-.3, 1.45, .36), "lights": Vector3(-.08, 1.45, .36), "scrubber": Vector3(.14, 1.45, .36)}
## The core's upgrade panel, right of the switches (scripts/core_panel.gd).
const PANEL := preload("res://scripts/core_panel.gd")
const PANEL_SPOT := Vector3(.42, 1.45, .36)

var world: Node
var core: RefCounted
var switches := {}
var socket: StaticBody3D
var ahead := {}
var _since_runway := 99.0
var _socket_lamp: StandardMaterial3D
var _rack: Node3D
var _panel: StaticBody3D
## Version 2, day 4: it comes down unpressurised. Cartridge and blanket in,
## it tries to pressurise, a seam won't hold; patched, it's commissioned.
var commissioned := true
var leak_found := false
var leak: Node3D

func setup(target_world: Node, state: Dictionary = {}) -> void:
	world = target_world
	name = "ModuleLife"
	add_to_group("survival_core")
	add_to_group("module_socket")   # pallet 1's air cartridge plugs in here (scripts/o2_cartridge.gd)
	core = CORE.new("module")
	if state.is_empty():
		core.heater_mode = "low"
		core.temp_c = 12.0
		if int(world.get("opening_version")) >= 2:
			commissioned = false
			core.vented = true
			core.temp_c = COLD_START_C
			core.heater_mode = "off"
			core.lights_on = false
	core.load_state(state)
	commissioned = bool(state.get("commissioned", commissioned))
	leak_found = bool(state.get("leak_found", false))
	_build_socket.call_deferred()
	if not commissioned and leak_found: _spawn_leak.call_deferred()

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
	if not running() or not commissioned: return []   # still being brought to life: Castle talks you through it
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
	if on: pressurise_try()
	return share

## Pallet 1's air cartridge on the socket: the module's tank grows by its oxygen, full.
func add_cartridge(oxygen_kg: float) -> void:
	core.tank_cap += oxygen_kg
	core.tank_o2_kg = core.tank_cap
	_since_runway = 99.0
	pressurise_try()

func has_cartridge() -> bool:
	var cartridge := get_tree().get_first_node_in_group("o2_cartridge")
	return cartridge != null and str(cartridge.where) == "plugged" and str(cartridge.plugged_into) == "module"

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
		if _panel != null and is_instance_valid(_panel): _panel.refresh()
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
	if has_cartridge(): words += " · air cartridge in"
	return {"label": "Module socket · " + words}

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
		# The core's upgrades (A3, scripts/room_types.gd): a panel beside the switches.
		if _panel == null or not is_instance_valid(_panel):
			_panel = PANEL.new()
			_rack.add_child(_panel)
			_panel.setup(world)
		_panel.position = PANEL_SPOT
		return

# ---------- commissioning (version 2, day 4) ----------

## Air and power both in: it tries to pressurise, and a seam won't hold.
func pressurise_try() -> void:
	if commissioned or leak_found or not has_cartridge() or not has_blanket(): return
	leak_found = true
	MHAudio.sfx("suit_fill", -6.0)
	_spawn_leak()
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d4_leak")

## The hissing seam: on an inside wall away from the airlock, about 1.2 m up.
func _spawn_leak() -> void:
	if leak != null and is_instance_valid(leak): return
	var spot := leak_spot()
	if spot.is_empty(): return
	leak = LEAK.new()
	leak.setup(self, spot.at, spot.facing)

## {at, facing} for the leak: a wall edge of the carried zone with nothing
## beyond it (not the airlock's side), the furthest from the airlock.
func leak_spot() -> Dictionary:
	var b: Node = world.builder
	var cells: Array = zone().get("cells", [])
	if cells.is_empty(): return {}
	var others := {}
	var away_from := Vector2.ZERO
	var n := 0
	for z in b.zones:
		if bool(z.get("carried", false)): continue
		for c in z.cells:
			others[c] = true
			away_from += Vector2(c.x, c.y)
			n += 1
	if n > 0: away_from /= float(n)
	else: away_from = Vector2(_centre().x, _centre().z) / float(b.CELL)
	var best := {}
	var best_d := -1.0
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var beyond: Vector2i = c + d
			if cells.has(beyond) or others.has(beyond): continue
			var edge := Vector2(c.x, c.y) + Vector2(d.x, d.y) * .5
			var dist := edge.distance_to(away_from)
			if dist > best_d:
				best_d = dist
				var cell := float(b.CELL)
				var at := Vector3(edge.x * cell - d.x * .22, float(b.habitat_base_y) + 1.2, edge.y * cell - d.y * .22)
				best = {"at": at, "facing": Vector3(-d.x, 0, -d.y)}
	return best

## Pallet 4's patch kit on the seam: it holds. Air in, heater up, lights on.
func patched() -> void:
	if commissioned: return
	commissioned = true
	if leak != null and is_instance_valid(leak): leak.queue_free()
	leak = null
	core.repressurise()
	# The fill air comes in through the life support's heat exchanger, so the
	# module's livable at once (playtest 14 Nov: hours of frost after the patch).
	core.temp_c = maxf(float(core.temp_c), 14.0)
	core.heater_mode = "warm"
	core.lights_on = true
	MHAudio.sfx("suit_clamp", -4.0)
	MHAudio.sfx("suit_fill", -8.0)
	_since_runway = 99.0
	for s in switches.values(): s.refresh()
	world.builder.refresh_power_grid()
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d4_patched")

func export_state() -> Dictionary:
	var out: Dictionary = core.export_state()
	out["commissioned"] = commissioned
	out["leak_found"] = leak_found
	return out
