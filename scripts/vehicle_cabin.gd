extends Node3D

## The HabRover's walk-in cabin (21 Nov). Parked, you walk in through the rear
## airlock (E on the hatch: it swings open, you step up into the lock, it
## shuts, a short hiss, the inner gates slide open into the aisle), move about
## the cabin on your own feet, open the galley drawers, lie on the bunk and sit
## in the driver's seat (E) to drive. Out the same way. Docked to a base's
## port, the rear airlock is mated: you walk straight through, no air cycle.
## You're only ever on your feet in here while it's parked; sitting in the
## driver's seat is the only way to drive (scripts/crew_rover.gd).
##
## Outside, on its side, the service hatch is the kit locker: the patch kit,
## spares and traction mats ride there, and the field fixes are done from it.
##
## Built from the Traverse 06 model's own empties: Airlock_Hatch_Pivot,
## Inner_Airlock_Gate_L/R (closed at local x -/+0.292), Airlock_Entry,
## Airlock_Inside, Driver_Seat, Galley_Drawer_01-03, Service_Hatch_Pivot.

const HATCH_SWING := deg_to_rad(100.0)
const LOCKER_SWING := deg_to_rad(105.0)
const GATE_CLOSED_X := .292
const CAB_EYES := .2           # how much lower your eyes sit under the cab's ceiling

## An E target in or on the cabin: hands its actions to the cabin.
class Spot extends StaticBody3D:
	var cabin: Node
	var what := ""
	func interaction_prompt() -> Dictionary: return cabin.spot_prompt(what)
	func interact(_actor: Node = null) -> bool: return cabin.spot_use(what, "primary")
	func interact_secondary(_actor: Node = null) -> bool: return cabin.spot_use(what, "secondary")
	func interact_tertiary(_actor: Node = null) -> bool: return cabin.spot_use(what, "tertiary")
	func interact_sleep(_actor: Node = null) -> bool: return cabin.spot_use(what, "sleep")
	func interact_info(_actor: Node = null) -> bool: return cabin.spot_use(what, "info")

var rover: Node   # scripts/crew_rover.gd
var busy := false              # mid-cycle: the hatch, the gates or you are moving
var player_in := false         # on your feet in the cabin (or its airlock)
var locker_open := false
var walk := false              # the walk-in collision is live (parked)

var _hatch: Node3D
var _hatch_rest: Basis
var _hatch_open: Basis
var _locker: Node3D
var _locker_rest: Basis
var _locker_open_basis: Basis
var _gates: Array[Node3D] = []
var _gate_open_x: Array[float] = []
var _entry: Node3D
var _inside: Node3D
var _seat: Node3D
var _bodies: Array[CollisionObject3D] = []   # the shell, the hatch, the gates and the spots
var _shell: Spot
var _floor_y := 1.12           # the cab floor, body space
var _front_z := -1.0           # body space: the dash end of the cab...
var _back_z := 3.0             # ...and the outer hatch

func setup(owner_rover: Node, visual: Node3D) -> void:
	rover = owner_rover
	_hatch = visual.find_child("Airlock_Hatch_Pivot", true, false) as Node3D
	_locker = visual.find_child("Service_Hatch_Pivot", true, false) as Node3D
	_entry = visual.find_child("Airlock_Entry", true, false) as Node3D
	_inside = visual.find_child("Airlock_Inside", true, false) as Node3D
	_seat = visual.find_child("Driver_Seat", true, false) as Node3D
	for side in ["L", "R"]:
		var gate := visual.find_child("Inner_Airlock_Gate_" + side, true, false) as Node3D
		if gate == null: continue
		_gates.append(gate)
		_gate_open_x.append(gate.position.x)
		gate.position.x = signf(gate.position.x) * GATE_CLOSED_X   # shut while nobody's passing
	if _inside != null: _floor_y = rover._body_point(_inside).y
	if _seat != null: _front_z = rover._body_point(_seat).z - .9
	if _entry != null: _back_z = rover._body_point(_entry).z
	if _hatch != null:
		_hatch_rest = _hatch.transform.basis
		_hatch_open = _swing(_hatch, HATCH_SWING, func(far: Vector3) -> float: return far.z)   # out the back
	if _locker != null:
		_locker_rest = _locker.transform.basis
		_locker_open_basis = _swing(_locker, LOCKER_SWING, func(far: Vector3) -> float: return absf(far.x))   # out to the side
	# Collision you can walk in: the cabin shell as built, the hatch and gates
	# (they swing and slide with their meshes).
	_shell = _slabs(visual)
	if _hatch != null:
		for mesh in _hatch.find_children("*", "MeshInstance3D", true, false): _solid(mesh as MeshInstance3D, "hatch")
	for gate in _gates:
		for mesh in ([gate] if gate is MeshInstance3D else []) + gate.find_children("*", "MeshInstance3D", true, false): _solid(mesh as MeshInstance3D, "gates")
	if _locker != null:
		for mesh in _locker.find_children("*", "MeshInstance3D", true, false): _solid(mesh as MeshInstance3D, "locker")
	# Things to use: the driver's seat, the galley drawers, the bunk.
	if _seat != null: _box(_seat, "seat", Vector3(.55, .5, .55), Vector3(0, .35, 0))
	for drawer_name in rover.CAB_PARTS.get("rover", {}):
		var drawer := visual.find_child(str(drawer_name), true, false) as Node3D
		if drawer != null: _box(drawer, str(rover.CAB_PARTS.rover[drawer_name]), Vector3(.5, .45, .5), Vector3.ZERO, true)
	# The bunk is part of the shell (on the far side from the galley): a target over its mattress.
	var bunk := Node3D.new()
	add_child(bunk)
	var galley_x := -.655
	var first: Node3D = visual.find_child("Galley_Drawer_02", true, false)
	if first != null: galley_x = rover._body_point(first).x
	bunk.position = Vector3(-signf(galley_x) * .95, _floor_y + .45, (_front_z + .9 + _back_z) * .5 - .6)
	_box(bunk, "bunk", Vector3(.6, .35, 1.6))
	set_walk(false)

## The basis that swings `pivot` open by `angle` about the body's up axis, the
## way that takes its far edge outward (`outward` scores a body-space point).
func _swing(pivot: Node3D, angle: float, outward: Callable) -> Basis:
	var up: Vector3 = rover._in_parent(pivot, Vector3.UP)
	var centre := Vector3.ZERO
	var meshes := pivot.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes: centre += pivot.global_transform.affine_inverse() * (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb().get_center()
	if not meshes.is_empty(): centre /= meshes.size()
	var best := Basis.IDENTITY
	var score := -INF
	for sign in [1.0, -1.0]:
		var basis: Basis = Basis(up, angle * sign) * pivot.transform.basis
		var far := pivot.get_parent_node_3d().global_transform * Transform3D(basis, pivot.position) * centre
		var s: float = outward.call(rover._model.global_transform.affine_inverse() * far)
		if s > score:
			score = s
			best = basis
	return best

## The cabin as a dozen boxes, in the model's own space (metres; +Z is the
## front, -Z the rear airlock, +X the galley side): the floor, roof, sides,
## the nose and dash, the rear wall round the airlock, the galley, the bunk
## and the seats. Measured off Traverse 06. (The model's own mesh, 157,000
## triangles, made walking in it crawl: 21 Nov playtest.)
const SLABS := [
	[Vector3(-1.9, .41, -3.56), Vector3(1.9, 1.11, 3.18)],      # underbody, its top the cab floor
	[Vector3(-1.9, 2.92, -3.56), Vector3(1.9, 3.83, 3.18)],     # roof
	[Vector3(1.32, 1.11, -3.56), Vector3(1.9, 2.92, 3.18)],     # galley-side wall
	[Vector3(-1.9, 1.11, -3.56), Vector3(-1.32, 2.92, 3.18)],   # bunk-side wall
	[Vector3(-1.32, 1.11, 1.25), Vector3(1.32, 2.92, 3.18)],    # nose and dash
	[Vector3(.58, 1.11, -3.56), Vector3(1.32, 2.92, -2.43)],    # the airlock's sides...
	[Vector3(-1.32, 1.11, -3.56), Vector3(-.58, 2.92, -2.43)],
	[Vector3(-.58, 2.85, -3.56), Vector3(.58, 2.92, -2.43)],    # ...and its lintel
	[Vector3(.53, 1.11, -2.43), Vector3(1.32, 2.92, -.49)],     # galley
	[Vector3(-1.32, 1.11, -2.43), Vector3(-.58, 2.92, 0.0)],    # bunk
	[Vector3(.35, 1.11, -.35), Vector3(1.0, 1.95, .45)],        # passenger seat
	[Vector3(-1.0, 1.11, -.35), Vector3(-.35, 1.95, .45)],      # driver's seat
	[Vector3(-.35, 1.11, .3), Vector3(.35, 2.92, 1.25)],        # between the seats (too low to stand)
]

func _slabs(visual: Node3D) -> Spot:
	var body := Spot.new()
	body.cabin = self
	body.what = "shell"
	for slab in SLABS:
		var lo: Vector3 = slab[0]
		var hi: Vector3 = slab[1]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = hi - lo
		shape.shape = box
		shape.position = (lo + hi) * .5
		body.add_child(shape)
	visual.add_child(body)
	_bodies.append(body)
	return body

func _solid(mesh: MeshInstance3D, what: String) -> Spot:
	if mesh == null or mesh.mesh == null: return null
	var body := Spot.new()
	body.cabin = self
	body.what = what
	var shape := CollisionShape3D.new()
	var trimesh := mesh.mesh.create_trimesh_shape()
	trimesh.backface_collision = true   # the model's floor faces point down in places
	shape.shape = trimesh
	body.add_child(shape)
	mesh.add_child(body)
	_bodies.append(body)
	return body

func _box(at: Node3D, what: String, size: Vector3, offset := Vector3.ZERO, fit_mesh := false) -> Spot:
	var body := Spot.new()
	body.cabin = self
	body.what = what
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.position = offset
	if fit_mesh:
		var meshes := ([at] if at is MeshInstance3D else []) + at.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			var aabb := (meshes[0] as MeshInstance3D).get_aabb()
			box.size = aabb.size.max(Vector3.ONE * .05)
			shape.position = aabb.get_center()
			at = meshes[0]
	shape.shape = box
	body.add_child(shape)
	at.add_child(body)
	_bodies.append(body)
	return body

## Walk-in collision on (parked) or off (driving, recalled, wrecked, towed):
## then the rover's own box is its collision, as before.
func set_walk(on: bool) -> void:
	walk = on
	for body in _bodies:
		body.collision_layer = 1 if on else 0
		body.collision_mask = 0
	if rover._hull != null: rover._hull.disabled = on
	if not on and player_in and not busy: _put_out_quietly()

## Is `at` (world) inside the cabin or its airlock?
func contains(at: Vector3) -> bool:
	var p: Vector3 = rover._model.global_transform.affine_inverse() * at
	return absf(p.x) < 1.35 and p.y > _floor_y - .4 and p.y < _floor_y + 2.0 and p.z > _front_z - .3 and p.z < _back_z - .25

func _process(_delta: float) -> void:
	var player := _player()
	if player == null or busy: return
	var inside := walk and not bool(player.get_meta("driving", false)) and contains(player.global_position)
	if inside != player_in: _mark_inside(player, inside)

func _mark_inside(player: Node, inside: bool) -> void:
	player_in = inside
	if inside:
		player.set_meta("in_cab", rover)
		player.set_meta("cab_ceiling", true)
	else:
		if player.has_meta("in_cab"): player.remove_meta("in_cab")
		player.set_meta("cab_ceiling", false)

func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D

func _world(local: Vector3) -> Vector3:
	return rover._model.global_transform * local

# ---------- prompts and actions ----------

func spot_prompt(what: String) -> Dictionary:
	if busy: return {}
	match what:
		"shell":
			if player_in: return {"label": "%s cabin · air %d%% · hull %d%%" % [rover.label(), roundi(rover.o2), roundi(rover.hull)]}
			return rover.outside_prompt()
		"hatch":
			if player_in: return {"label": "Outer hatch"}
			if rover.docked_port() != null: return {"label": "Rear airlock · mated to the base's docking port"}
			return {"label": rover.outside_prompt().get("label", rover.label()), "primary": "Open the hatch and go in", "secondary": rover.outside_prompt().get("secondary", ""), "info": "About"}
		"gates":
			if not player_in: return {"label": "Inner airlock gates"}
			return {"label": "Inner airlock gates", "primary": "Through to the base" if rover.docked_port() != null else "Go out (airlock)"}
		"seat":
			return {"label": "Driver's seat · battery %d%%" % roundi(rover.battery), "primary": "Sit and drive", "info": "About"}
		"bunk":
			return {"label": "Bunk", "primary": "Lie down", "sleep": "Sleep"}
		"locker":
			if not locker_open: return {"label": "Kit locker", "primary": "Open the kit locker", "info": "About"}
			return {"label": "Kit locker · " + _locker_contents(), "primary": _locker_job(), "secondary": "Close it", "info": "About"}
	if what.begins_with("drawer"):
		return {"label": "Galley", "primary": rover._cab_label(what)}
	return {}

func spot_use(what: String, how: String) -> bool:
	if busy: return false
	if how == "info":
		if what == "locker":
			rover._note("Kit locker", "A shallow locker on the outside of the hull: the patch kit for the cab, spares kits for the wheels and the traction-mat rack ride here, so field fixes are done from outside without bringing dust in.")
			return true
		return rover.interact_info()
	match what:
		"shell":
			if player_in: return false
			match how:
				"secondary": return rover.interact_secondary()
				"tertiary": return rover.interact_tertiary()
			return false
		"hatch":
			if player_in or rover.docked_port() != null: return false
			if how == "secondary": return rover.interact_secondary()
			if how == "primary": return go_in()
		"gates":
			if how == "primary" and player_in: return go_out()
		"seat":
			if how == "primary": return rover.sit_down(_player())
		"bunk":
			if how == "primary" or how == "sleep":
				rover._cabin_sleep()
				return true
		"locker":
			if how == "secondary" and locker_open: return _set_locker(false)
			if how == "primary": return _set_locker(true) if not locker_open else _locker_do()
	if what.begins_with("drawer") and how == "primary": return rover.use_cab_part(what)
	return false

# ---------- the airlock ----------

## E on the outer hatch: open, step up into the lock, shut, a short hiss,
## and the inner gates open into the aisle. About 3 s.
func go_in() -> bool:
	var player := _player()
	if player == null or busy or not walk: return false
	if rover.has_method("_refuse") and not rover.sealed(): return false
	busy = true
	player.set_meta("ui_freeze", true)
	player.set_meta("cab_ceiling", true)
	var face: float = rover.rotation.y   # toward the front, down the aisle
	var step := _world(Vector3(0, _floor_y, _back_z))
	var lock := _world(rover._body_point(_inside)) if _inside != null else step
	var aisle := _world(Vector3(0, _floor_y, (_back_z + _front_z) * .5 + .4))
	var t := create_tween()
	t.tween_callback(func() -> void: MHAudio.sfx_at("suit_clamp", _hatch, -6.0, 0.0))
	t.tween_property(_hatch, "transform:basis", _hatch_open, .5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(func(a: float) -> void: player.rotation.y = lerp_angle(player.rotation.y, face, a), 0.0, 1.0, .5)
	t.tween_property(player, "global_position", step, .45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "global_position", lock, .4)
	t.tween_callback(func() -> void: MHAudio.sfx_at("door_close", _hatch, -6.0, 0.0))
	t.tween_property(_hatch, "transform:basis", _hatch_rest, .45).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: MHAudio.sfx("suit_fill", -8.0))
	t.tween_interval(.7)
	_gates_tween(t, true)
	t.tween_property(player, "global_position", aisle, .5)
	_gates_tween(t, false)
	t.tween_callback(func() -> void: _arrive(player, true))
	return true

## E on the inner gates: back into the lock, gates shut, the hiss, the hatch
## opens and you step down outside, facing away. Docked: straight through the
## mated hatch into the base.
func go_out() -> bool:
	var player := _player()
	if player == null or busy: return false
	var port: Node3D = rover.docked_port()
	busy = true
	player.set_meta("ui_freeze", true)
	var lock := _world(rover._body_point(_inside)) if _inside != null else player.global_position
	var away: float = rover.rotation.y + PI
	var t := create_tween()
	t.tween_method(func(a: float) -> void: player.rotation.y = lerp_angle(player.rotation.y, away, a), 0.0, 1.0, .35)
	_gates_tween(t, true)
	t.tween_property(player, "global_position", lock, .45)
	if port != null:
		var room: Vector3 = rover._port_exit()
		t.tween_callback(func() -> void: MHAudio.sfx_at("door_open", _hatch, -6.0, 0.0))
		t.tween_property(_hatch, "transform:basis", _hatch_open, .4).set_trans(Tween.TRANS_SINE)
		t.tween_property(player, "global_position", room, .7)
		t.tween_property(_hatch, "transform:basis", _hatch_rest, .35)
		_gates_tween(t, false)
		t.tween_callback(func() -> void: _arrive(player, false, room))
		return true
	_gates_tween(t, false)
	t.tween_callback(func() -> void: MHAudio.sfx("suit_fill", -10.0, .02))
	t.tween_interval(.6)
	var step := _world(Vector3(0, _floor_y, _back_z))
	var ground: Vector3 = rover.ground_behind()
	t.tween_callback(func() -> void: MHAudio.sfx_at("door_open", _hatch, -6.0, 0.0))
	t.tween_property(_hatch, "transform:basis", _hatch_open, .5).set_trans(Tween.TRANS_SINE)
	t.tween_property(player, "global_position", step, .35)
	t.tween_property(player, "global_position", ground, .45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_hatch, "transform:basis", _hatch_rest, .45).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: _arrive(player, false, ground))
	return true

## From the base, through a mated docking port: up into the aisle, no cycle.
func through_from_port(player: CharacterBody3D) -> void:
	if busy: return
	busy = true
	player.set_meta("ui_freeze", true)
	player.set_meta("cab_ceiling", true)
	var lock := _world(rover._body_point(_inside)) if _inside != null else player.global_position
	var aisle := _world(Vector3(0, _floor_y, (_back_z + _front_z) * .5 + .4))
	var t := create_tween()
	t.tween_method(func(a: float) -> void: player.rotation.y = lerp_angle(player.rotation.y, rover.rotation.y, a), 0.0, 1.0, .3)
	t.tween_callback(func() -> void: MHAudio.sfx_at("door_open", _hatch, -6.0, 0.0))
	t.tween_property(_hatch, "transform:basis", _hatch_open, .4).set_trans(Tween.TRANS_SINE)
	t.tween_property(player, "global_position", lock, .6)
	t.tween_property(_hatch, "transform:basis", _hatch_rest, .35)
	_gates_tween(t, true)
	t.tween_property(player, "global_position", aisle, .45)
	_gates_tween(t, false)
	t.tween_callback(func() -> void: _arrive(player, true))

func _gates_tween(t: Tween, open: bool) -> void:
	for i in _gates.size():
		var gate := _gates[i]
		var x := _gate_open_x[i] if open else signf(_gate_open_x[i]) * GATE_CLOSED_X
		if i == 0: t.tween_property(gate, "position:x", x, .35).set_trans(Tween.TRANS_SINE)
		else: t.parallel().tween_property(gate, "position:x", x, .35).set_trans(Tween.TRANS_SINE)

func _arrive(player: CharacterBody3D, inside: bool, at := Vector3.INF) -> void:
	busy = false
	player.set_meta("ui_freeze", false)
	player.velocity = Vector3.ZERO
	if at != Vector3.INF and "safe_position" in player: player.safe_position = at
	_mark_inside(player, inside)

## Lost the walk-in collision with you still inside (it's being recalled or
## towed): set you down behind it.
func _put_out_quietly() -> void:
	var player := _player()
	if player == null: return
	player.global_position = rover.ground_behind()
	_mark_inside(player, false)

# ---------- the kit locker ----------

func _set_locker(open: bool) -> bool:
	if _locker == null: return false
	locker_open = open
	MHAudio.sfx_at("door_open" if open else "door_close", _locker, -8.0, 0.0)
	create_tween().tween_property(_locker, "transform:basis", _locker_open_basis if open else _locker_rest, .45).set_trans(Tween.TRANS_SINE)
	return true

func _locker_contents() -> String:
	var bits: Array = []
	var field: Node = rover._drop_field()
	bits.append("patch kit" if field != null and bool(field.get("tools")) else "no patch kit")
	bits.append("%d spares kits" % int(MHChapterOne.stock.get("spares_kit", 0)))
	if rover.has_addon("traction_mats"): bits.append("%d mats" % rover.mats)
	return ", ".join(bits)

## The one job the open locker offers: seal a leak first, then the wheels.
func _locker_job() -> String:
	if rover.leaking(): return "Patch the hull (patch kit, hull %d%%)" % roundi(rover.hull)
	if rover.wheels < 99.0 and int(MHChapterOne.stock.get("spares_kit", 0)) > 0: return "Fix the wheels (spares kit, %d%%)" % roundi(rover.wheels)
	return "Close it"

func _locker_do() -> bool:
	if rover.leaking(): return rover.patch_hull()
	if rover.wheels < 99.0 and int(MHChapterOne.stock.get("spares_kit", 0)) > 0: return rover.fix_wheels()
	return _set_locker(false)
