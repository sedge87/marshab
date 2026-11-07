extends StaticBody3D

## A place you find in the lifepod days but can't use yet (step 3b,
## scripts/lifepod.gd). Each becomes a thread in Notes, and the General
## Module's plans answer it later (3c).
## - "iron": a haematite outcrop, rust-dark rock studded with little grey
##   beads (Opportunity's "blueberries"). Chip a sample with the hammer.
## - "ice_wall": a bank where buried ice shows in tilted, glassy slabs. Too
##   much to dig by hand; chip a chunk with the hammer.
## - "frost": the frost hollow round pallet 4: ice just under the dust. The
##   nearest ice: chip a chunk with the hammer.
## Hold E to chip (needs the rock hammer from pallet 4).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const FIND := preload("res://scripts/carried_find.gd")
const CHIP_SECONDS := 1.5
const SEEN_AT := 35.0
const NAMES := {"iron": "Iron outcrop", "ice_wall": "Ice wall", "frost": "Frost patch"}

var lifepod: Node
var kind := "iron"
var at := Vector3.ZERO
var seen := false
var _holding := false
var _held := 0.0
var _tick := 0

func setup(target_lifepod: Node, site_kind: String, where: Vector3, yaw: float, was_seen: bool) -> void:
	lifepod = target_lifepod
	kind = site_kind
	at = where
	seen = was_seen
	name = "Thread_%s" % kind
	add_to_group("thread_site")
	set_meta("interaction_target", self)
	global_position = where
	rotation.y = yaw
	match kind:
		"iron": _build_outcrop()
		"ice_wall": _build_ice_wall()
		"frost": _build_frost()

func id() -> String:
	return "thread:" + kind

func _ground(local: Vector3) -> Vector3:
	var p := to_global(local)
	return Vector3(local.x, MHSiteTerrain.height(p.x, p.z) - at.y + local.y, local.z)

func _lump(size: Vector3, local: Vector3, tilt: Vector3, what: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = _ground(local)
	mesh.rotation = tilt
	mesh.material_override = FIND.material(what)
	add_child(mesh)
	return mesh

func _collide(size: Vector3, local: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = _ground(local)
	add_child(shape)

## Rust-dark rocks, half sunk, with grey beads weathering out of them and
## lying round about.
func _build_outcrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 6:
		var size := Vector3(rng.randf_range(.8, 1.8), rng.randf_range(.4, 1.0), rng.randf_range(.7, 1.5))
		var local := Vector3(rng.randf_range(-2.5, 2.5), size.y * .3, rng.randf_range(-2.0, 2.0))
		_lump(size, local, Vector3(rng.randf_range(-.25, .25), rng.randf_range(0, TAU), rng.randf_range(-.25, .25)), "rock")
	var bead := SphereMesh.new()
	bead.radius = .025
	bead.height = .05
	bead.radial_segments = 8
	bead.rings = 4
	var beads := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bead
	mm.instance_count = 160
	for i in 160:
		var local := Vector3(rng.randf_range(-4.0, 4.0), .02, rng.randf_range(-3.5, 3.5))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _ground(local)))
	beads.multimesh = mm
	beads.material_override = FIND.material("bead")
	add_child(beads)
	_collide(Vector3(4.5, 1.0, 3.5), Vector3(0, .5, 0))

## A low bank with tilted slabs of glassy ice showing through the dust.
func _build_ice_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for i in 7:
		var size := Vector3(rng.randf_range(1.2, 2.4), rng.randf_range(1.2, 2.4), rng.randf_range(.3, .6))
		var local := Vector3(-5.0 + i * 1.6 + rng.randf_range(-.3, .3), size.y * .35, rng.randf_range(-.4, .4))
		_lump(size, local, Vector3(rng.randf_range(-.5, -.25), rng.randf_range(-.2, .2), rng.randf_range(-.15, .15)), "ice")
	for i in 5:
		var size := Vector3(rng.randf_range(1.5, 2.5), rng.randf_range(.5, .9), rng.randf_range(1.2, 2.0))
		_lump(size, Vector3(-4.5 + i * 2.2, size.y * .2, -1.1), Vector3(rng.randf_range(-.2, .2), rng.randf_range(0, TAU), 0), "rock")
	_collide(Vector3(11.0, 1.6, 1.4), Vector3(0, .8, 0))

## Pale frost on the ground of the hollow, with a few bright chips of ice
## where the dust has blown off.
func _build_frost() -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.2
	cyl.height = .02
	cyl.radial_segments = 24
	disc.mesh = cyl
	disc.position = _ground(Vector3(0, .03, 0))
	disc.material_override = FIND.material("frost")
	add_child(disc)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in 5:
		var size := Vector3(rng.randf_range(.3, .6), rng.randf_range(.08, .16), rng.randf_range(.3, .5))
		_lump(size, Vector3(rng.randf_range(-2.0, 2.0), .03, rng.randf_range(-2.0, 2.0)), Vector3(0, rng.randf_range(0, TAU), 0), "ice")
	_collide(Vector3(4.0, .2, 4.0), Vector3(0, .1, 0))

# ---------- chipping ----------

func _hammer() -> bool:
	return MHChapterOne.has_hammer

func interaction_prompt() -> Dictionary:
	var label := str(NAMES.get(kind, "Rock"))
	if not _hammer(): return {"label": label + " · need something to chip it with"}
	if _holding: return {"label": label, "primary": "Chipping…"}
	return {"label": label, "primary": "Hold to chip a sample" if kind == "iron" else "Hold to chip ice"}

func interact(_player: Node = null) -> bool:
	if not _hammer(): return false
	_holding = true
	_held = 0.0
	_tick = 0
	return true

func _process(delta: float) -> void:
	if not _holding: return
	var player: Node3D = lifepod.world.player
	if not Input.is_key_pressed(KEY_E) or player.global_position.distance_to(global_position) > 8.0:
		_holding = false
		return
	chip_for(delta)

## Hammer blows while E is held; a chunk comes away at the end.
func chip_for(delta: float) -> bool:
	_held += delta
	var blows := floori(_held / CHIP_SECONDS * 4.0)
	while _tick < blows:
		_tick += 1
		MHAudio.sfx_at("place", self, -6.0, .3)
	if _held < CHIP_SECONDS: return false
	_holding = false
	_held = 0.0
	_tick = 0
	lifepod.chipped(self)
	return true

func export_state() -> Dictionary:
	return {"at": [at.x, at.y, at.z], "yaw": rotation.y, "seen": seen}
