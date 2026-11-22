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

## The ice wall is the land itself (B5, docs/terrain-design.md §14): a small
## ice scarp near home, its pale banded face made by the region generator.
## The site sits at the foot of the face (local +Z looks out from it), and
## adds only a thin, invisible plate lying on the face so you can chip it.
const ICE_FACE_DEG := 55.0
func _build_ice_wall() -> void:
	var shape := CollisionShape3D.new()
	var plate := BoxShape3D.new()
	plate.size = Vector3(8.0, 5.0, .4)
	shape.shape = plate
	var lean := deg_to_rad(90.0 - ICE_FACE_DEG)   # the plate leans back with the face
	shape.basis = Basis(Vector3.RIGHT, -lean)
	var up := 2.0
	shape.position = Vector3(0, MHSiteTerrain.height(at.x, at.z) - at.y + up, -up / tan(deg_to_rad(ICE_FACE_DEG)) - 2.5)
	add_child(shape)

## Frost in the hollow, part of the ground itself: a decal (it lies on the
## real slope like paint, no disc) of thin patchy hoarfrost, thickest in the
## cracks between polygons as on the Phoenix site, fading out raggedly at its
## edge. A few chips of clean ice show half-buried where the dust has blown
## off. The chip spot is the middle, as before.
const FROST_REACH := 4.5            # metres from the middle to the frost's ragged edge
const FROST_PIXELS := 256
static var _frost_texture: ImageTexture
func _build_frost() -> void:
	var decal := Decal.new()
	decal.name = "Frost"
	decal.size = Vector3(FROST_REACH * 2.0, 3.0, FROST_REACH * 2.0)
	decal.position = _ground(Vector3.ZERO)
	decal.texture_albedo = _frost_image()
	decal.albedo_mix = 1.0
	decal.normal_fade = .35          # not up the sides of rocks
	decal.upper_fade = .4
	decal.lower_fade = .4
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 120.0
	decal.distance_fade_length = 40.0
	add_child(decal)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var chip := _ice_chip_material()
	for i in 7:
		var model := "decor_rock_%02d" % rng.randi_range(0, 7)
		var path := "res://assets/original_mars/models/%s.glb" % model
		if not ResourceLoader.exists(path): continue
		var root: Node3D = (load(path) as PackedScene).instantiate()
		for mesh in root.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = chip
		var size := rng.randf_range(.18, .42)
		var local := Vector3(rng.randf_range(-2.4, 2.4), 0.0, rng.randf_range(-2.4, 2.4))
		root.scale = Vector3(size, size * rng.randf_range(.5, .8), size)
		root.rotation = Vector3(rng.randf_range(-.4, .4), rng.randf_range(0, TAU), rng.randf_range(-.4, .4))
		root.position = _ground(local) - Vector3(0, size * .35, 0)   # half sunk in the dust
		add_child(root)
	_collide(Vector3(4.0, .2, 4.0), Vector3(0, .1, 0))

## Clean ice: pale and faintly glassy, never blue (docs/house-style.md), with
## a little dust caught on it.
static func _ice_chip_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "ice_chip_clean"
	mat.albedo_color = Color("#D8D9D6")
	mat.roughness = .28
	mat.metallic_specular = .8
	mat.rim_enabled = true
	mat.rim = .3
	mat.rim_tint = .5
	return mat

## Drawn once: polygon cracks (the gaps between jittered cells) hold the most
## frost; a patchy thin coat between them; the edge ragged with noise; a few
## clearer, greyer glints where it's thickest.
static func _frost_image() -> ImageTexture:
	if _frost_texture != null: return _frost_texture
	var n := FROST_PIXELS
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var patch := FastNoiseLite.new()
	patch.seed = 7
	patch.frequency = .018
	patch.fractal_octaves = 4
	var edge := FastNoiseLite.new()
	edge.seed = 11
	edge.frequency = .03
	var grain := FastNoiseLite.new()
	grain.seed = 5
	grain.frequency = .2
	var cells := 9                     # polygons across the patch (about 1 m each)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var seeds: Array[Vector2] = []
	for j in cells:
		for i in cells:
			seeds.append(Vector2((i + rng.randf_range(.15, .85)) / cells, (j + rng.randf_range(.15, .85)) / cells))
	var frost := Color("#E4E1DB")
	var glint := Color("#C7CCCE")
	for y in n:
		for x in n:
			var uv := Vector2((x + .5) / n, (y + .5) / n)
			var r := (uv - Vector2(.5, .5)).length() * 2.0
			var fade := 1.0 - smoothstep(.45, .95, r + edge.get_noise_2d(x, y) * .3)
			if fade <= 0.0:
				img.set_pixel(x, y, Color(frost, 0.0))
				continue
			var cx := clampi(int(uv.x * cells), 0, cells - 1)
			var cy := clampi(int(uv.y * cells), 0, cells - 1)
			var f1 := INF
			var f2 := INF
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var gx := cx + dx
					var gy := cy + dy
					if gx < 0 or gy < 0 or gx >= cells or gy >= cells: continue
					var d := uv.distance_to(seeds[gy * cells + gx])
					if d < f1:
						f2 = f1
						f1 = d
					elif d < f2: f2 = d
			# Cracks are thin and come and go; the coat between is patchy and grainy.
			var crack := (1.0 - smoothstep(.002, .016, f2 - f1)) * smoothstep(-.35, .25, edge.get_noise_2d(x * 1.7 + 300.0, y * 1.7))
			var coat := smoothstep(-.1, .5, patch.get_noise_2d(x, y)) * (.55 + .45 * grain.get_noise_2d(x, y))
			var a := clampf(crack * .8 + coat * .6, 0.0, .9) * fade
			var c := frost.lerp(glint, smoothstep(.6, .9, coat) * .6)
			img.set_pixel(x, y, Color(c, a))
	img.generate_mipmaps()
	_frost_texture = ImageTexture.create_from_image(img)
	return _frost_texture

# ---------- chipping ----------

func _hammer() -> bool:
	return MHChapterOne.has_hammer and preload("res://scripts/field_kit.gd").holding_in(lifepod.world, "hammer")

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
	chip_for(delta * float(player.get_meta("hands_speed", 1.0)))   # slower hungry or tired (scripts/body.gd)

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
