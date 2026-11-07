extends Node3D

## The storm's first drop (docs/systems-and-items.md §14 step 2): the
## parachute on the ridge you see from the cabin window, with pallet 1 (life
## support) in the dust beside it, and a trail of storm debris leading there
## from near the lander. A breadcrumb trail, never a marker.
##
## - The ridge: about 400 m in front of the hatch, the highest ground within
##   about 35 degrees either side, so it stands against the sky from the
##   window and the walk is uphill towards it (the Firewatch rule: start high,
##   walk towards the first thing you can see).
## - The canopy is a Blender model (asset_packs/mars_storm_cargo_v1) whose
##   heights are offsets above the ground; every vertex is laid onto the
##   terrain here, so it drapes over whatever the ridge looks like.
## - Its lines run back to the backshell, on the side facing the lander.
## - The pallet (scripts/cargo_pallet.gd) holds the oxygen cartridge
##   (scripts/o2_cartridge.gd) and the sample kit.
##
## Placed once for a new game and saved: where everything lies, whether the
## pallet is open, where the cartridge is.

const PARACHUTE := preload("res://assets/models/storm_cargo/parachute.glb")
const BACKSHELL := preload("res://assets/models/storm_cargo/backshell.glb")
const DEBRIS := [
	preload("res://assets/models/storm_cargo/debris_strip.glb"),
	preload("res://assets/models/storm_cargo/debris_strap.glb"),
	preload("res://assets/models/storm_cargo/debris_lid.glb"),
	preload("res://assets/models/storm_cargo/debris_foam.glb"),
]
const PALLET := preload("res://scripts/cargo_pallet.gd")
const CARTRIDGE := preload("res://scripts/o2_cartridge.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

const RIDGE_DISTANCE := 400.0
const RIDGE_SPREAD := 35.0            # degrees either side of the hatch
## The canopy is scaled to a real one's size (Mars 2020's was 21.5 m across).
const CANOPY_SCALE := 1.5
const PALLET_LOCAL := Vector3(-13.6, 0, 1.6)   # beside the canopy's hem
const BACKSHELL_LOCAL := Vector3(0.6, 0, 19.5)
const DEBRIS_STOPS := [.14, .26, .38, .5, .6, .7, .8, .88]
const SEEN_FROM := 250.0              # the parachute joins your Map within this
const NEAR_PALLET := 25.0

var world: Node
var ridge := Vector3.INF               # the canopy's crown, world
var yaw := 0.0                         # the parachute's turn: its +Z faces the lander
var pallet: StaticBody3D
var cartridge: StaticBody3D
var _saved := {}
var _check := 0.0

func _ready() -> void:
	name = "StormDrop"
	add_to_group("storm_drop")

## Placed for a new game (or one without a drop yet), or put back as saved.
func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	_saved = saved
	if saved.has("ridge"):
		var at: Array = saved.ridge
		ridge = Vector3(float(at[0]), float(at[1]), float(at[2]))
		yaw = float(saved.get("yaw", 0.0))
	else:
		_choose_ridge()
	_build()
	if not saved.has("ridge"): _first_thoughts()

# ---------- where it lies ----------

## The hatch faces the lander's -Z. The highest walkable ground about 400 m
## out within the spread, a little favouring straight ahead.
func _choose_ridge() -> void:
	var lander: Node3D = world.lander
	var forward := -lander.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var home := lander.global_position
	var best := -INF
	for distance in range(340, 461, 20):
		for step in range(-7, 8):
			var angle := deg_to_rad(step * RIDGE_SPREAD / 7.0)
			var dir := forward.rotated(Vector3.UP, angle)
			var at := home + dir * float(distance)
			var h: float = MHSiteTerrain.height(at.x, at.z)
			var slope := 0.0
			for d in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
				slope = maxf(slope, absf(MHSiteTerrain.height(at.x + d.x, at.z + d.y) - h))
			if slope > 2.5: continue
			var score := h - absf(float(step)) * .35 - absf(distance - RIDGE_DISTANCE) * .01
			if score > best:
				best = score
				ridge = Vector3(at.x, h, at.z)
	if is_inf(ridge.x):
		var at := home + forward * RIDGE_DISTANCE
		ridge = Vector3(at.x, MHSiteTerrain.height(at.x, at.z), at.z)
	var back := home - ridge
	yaw = atan2(back.x, back.z)   # the lines and backshell point home

func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, MHSiteTerrain.height(at.x, at.z), at.z)

## A point in the parachute's own frame (its +Z towards the lander), on the ground.
func local_to_world(local: Vector3) -> Vector3:
	return _ground(ridge + Basis(Vector3.UP, yaw) * local)

# ---------- building it ----------

func _build() -> void:
	# The canopy, laid onto the ground.
	var chute: Node3D = PARACHUTE.instantiate()
	chute.name = "Parachute"
	add_child(chute)
	chute.global_position = ridge
	chute.rotation.y = yaw
	chute.scale = Vector3(CANOPY_SCALE, 1.0, CANOPY_SCALE)
	MHPalette.apply(chute)
	for mesh in chute.find_children("*", "MeshInstance3D", true, false): _drape(mesh as MeshInstance3D)
	# The backshell, at the end of its lines.
	var shell: Node3D = BACKSHELL.instantiate()
	shell.name = "Backshell"
	add_child(shell)
	shell.global_position = local_to_world(BACKSHELL_LOCAL)
	shell.rotation.y = yaw + .5
	MHPalette.apply(shell)
	_collider(shell, Vector3(3.0, 2.0, 3.0), Vector3(0, .8, 0))
	# The debris trail, from near the lander towards the backshell.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(ridge.x), roundi(ridge.z)))
	var home: Vector3 = world.lander.global_position
	var end := local_to_world(BACKSHELL_LOCAL)
	var across := (end - home).cross(Vector3.UP).normalized()
	for i in DEBRIS_STOPS.size():
		var piece: Node3D = DEBRIS[i % DEBRIS.size()].instantiate()
		piece.name = "Debris%d" % i
		add_child(piece)
		var side := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(3.0, 12.0)
		piece.global_position = _ground(home.lerp(end, float(DEBRIS_STOPS[i])) + across * side)
		piece.rotation.y = rng.randf_range(0.0, TAU)
		MHPalette.apply(piece)
		piece.add_to_group("storm_debris")
	# Pallet 1, beside the hem.
	pallet = PALLET.new()
	add_child(pallet)
	pallet.global_position = local_to_world(PALLET_LOCAL) + Vector3(0, -.04, 0)
	pallet.global_basis = _on_ground(pallet.global_position, yaw + .35)
	pallet.setup(self, bool(_saved.get("opened", false)))
	# Its oxygen cartridge: inside, on the ground, carried (put down when
	# saved) or plugged into the cabin.
	cartridge = CARTRIDGE.new()
	add_child(cartridge)
	var where := str(_saved.get("cartridge", "pallet"))
	if where == "plugged":
		cartridge.setup(self, "plugged")
	elif where == "ground" and _saved.has("cartridge_at"):
		var at: Array = _saved.cartridge_at
		cartridge.setup(self, "ground")
		cartridge.global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	else:
		cartridge.setup(self, "pallet")

## A turn of `turn` radians, tilted to lie flat on the ground at `at`.
func _on_ground(at: Vector3, turn: float) -> Basis:
	var dx: float = MHSiteTerrain.height(at.x + .8, at.z) - MHSiteTerrain.height(at.x - .8, at.z)
	var dz: float = MHSiteTerrain.height(at.x, at.z + .8) - MHSiteTerrain.height(at.x, at.z - .8)
	var up := Vector3(-dx / 1.6, 1.0, -dz / 1.6).normalized()
	var forward := Basis(Vector3.UP, turn).z
	var right := up.cross(forward).normalized()
	return Basis(right, up, right.cross(up).normalized())

## Lays each vertex of a mesh made with ground-relative heights onto the terrain.
func _drape(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if source == null: return
	var to_world := mesh_instance.global_transform
	var to_local := to_world.affine_inverse()
	var base_y := ridge.y
	var draped := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in points.size():
			var p := to_world * points[i]
			var lift := p.y - base_y
			p.y = MHSiteTerrain.height(p.x, p.z) + lift
			points[i] = to_local * p
		arrays[Mesh.ARRAY_VERTEX] = points
		draped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draped.surface_set_material(s, mesh_instance.get_active_material(s))
	mesh_instance.mesh = draped
	mesh_instance.extra_cull_margin = 4.0

func _collider(owner_node: Node3D, size: Vector3, offset: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	body.add_child(shape)
	owner_node.add_child(body)

# ---------- what you know about it ----------

## The orbiter's photo and the window: you know roughly where it is.
func _first_thoughts() -> void:
	var known: Node = world.get("known")
	if known != null: known.learn("find:parachute", "find", region_at(ridge), "Parachute", "orbiter")
	var notes: Node = world.get("notes")
	if notes != null: notes.think("parachute", "start", {"dir": direction_word(ridge - world.lander.global_position)})

func region_at(at: Vector3) -> Vector2:
	var known: Node = world.get("known")
	return Vector2(at.x, at.z) + (known.origin as Vector2 if known != null else Vector2.ZERO)

## "north", "north-east"... from a world offset (-Z is north).
static func direction_word(offset: Vector3) -> String:
	var bearing := wrapf(rad_to_deg(atan2(offset.x, -offset.z)), 0.0, 360.0)
	return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][roundi(bearing / 45.0) % 8]

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null: return
	_check = .5
	var you: Vector3 = world.player.global_position
	var known: Node = world.get("known")
	if known != null and you.distance_to(ridge) < SEEN_FROM: known.tell("find:parachute", "you")
	var notes: Node = world.get("notes")
	if notes != null and not pallet.opened and you.distance_to(pallet.global_position) < NEAR_PALLET: notes.think("parachute", "near")

## The pallet's latches are free (scripts/cargo_pallet.gd).
func pallet_opened() -> void:
	MHChapterOne.has_corer = true   # the sample kit: hand corer, scoop and bags (scripts/sample_tools.gd)
	cartridge.reachable(true)
	var known: Node = world.get("known")
	if known != null:
		known.tell("find:parachute", "you")
		known.rename("find:parachute", "Pallet 1")
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("parachute")
	MHNotices.post("valid", "Pallet 1: life support", "Inside: a fresh oxygen cartridge for the cabin, and the sample kit (hand corer, scoop, bags).", "log")
	MHAudio.moment()

func export_state() -> Dictionary:
	var out := {"ridge": [ridge.x, ridge.y, ridge.z], "yaw": yaw, "opened": pallet.opened if pallet != null else false}
	if cartridge != null:
		out["cartridge"] = cartridge.where if cartridge.where != "carried" else "ground"
		var at: Vector3 = cartridge.global_position if cartridge.where != "carried" else _ground(world.player.global_position)
		out["cartridge_at"] = [at.x, at.y, at.z]
	return out
