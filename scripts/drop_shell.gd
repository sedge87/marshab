extends Node3D

## What a vehicle came down in (docs/intro-rework.md §2, R3): nothing lies on
## the plain without a story. Set out round a vehicle's wreck by
## scripts/mars_world.gd, and it stays after the vehicle's fixed, as a trace.
## - "buggy" (pallet 5): its cargo shell split in two on impact, one half
##   rocked open beside the buggy, the other thrown dome up; the parachute
##   downwind; a crater where it hit and a skid gouge to where it stopped.
## - "drone" (pallet 8): a small capsule on its side, hatch sprung, a small
##   chute, a little crater.
## - "rover" (pallets 9-10, the HabRover): a heavy lander, no chute: it came
##   down on rockets, so a scorched ring, and it lies tipped on a crumpled leg
##   with the rover rolled off beside it. Its tanks catch a low sun: a glint on
##   the horizon you can see from home, which puts it on the manifest.
## Models: assets/models/storm_cargo (asset_packs/mars_storm_cargo_v2).

const TROUGH := preload("res://assets/models/storm_cargo/shell_trough.glb")
const DOME := preload("res://assets/models/storm_cargo/shell_dome.glb")
const CAPSULE := preload("res://assets/models/storm_cargo/drone_capsule.glb")
const LANDER := preload("res://assets/models/storm_cargo/heavy_lander.glb")
const PARACHUTE := preload("res://assets/models/storm_cargo/parachute.glb")
const DEBRIS := [
	preload("res://assets/models/storm_cargo/debris_strip.glb"),
	preload("res://assets/models/storm_cargo/debris_strap.glb"),
	preload("res://assets/models/storm_cargo/debris_lid.glb"),
	preload("res://assets/models/storm_cargo/debris_foam.glb"),
]
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SCAR := Color(.16, .085, .05)        # churned dark regolith
const SCORCH := Color(.07, .06, .055)      # rocket-blasted ground
## The glint: seen from at least this far (closer, you see the lander itself),
## with the sun this low (radians), and it twinkles.
const GLINT_FROM := 300.0
const GLINT_SUN := deg_to_rad(25.0)

var world: Node
var kind := ""
var spot := Vector3.ZERO     # the vehicle's wreck
var skid := Vector3.FORWARD  # the way it slid in (ground plane)
var glint: Sprite3D
var _glint_check := 0.0

func setup(target_world: Node, vehicle_kind: String, at: Vector3) -> void:
	world = target_world
	kind = vehicle_kind
	spot = at
	name = "DropShell_" + kind
	add_to_group("drop_shell")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(at.x), roundi(at.z))) + kind.length()
	skid = Vector3.FORWARD.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
	var across := skid.cross(Vector3.UP)
	match kind:
		"buggy":
			_scar(spot - skid * 22.0, 4.5, SCAR, .8)
			_strip(spot - skid * 19.0, spot - skid * 3.0, 2.2, SCAR, .6)
			_place(TROUGH, spot - skid * 1.0 + across * 2.6, atan2(skid.x, skid.z) + .2, true, Vector3(4.4, 1.6, 2.6))
			_place(DOME, spot + skid * 7.0 - across * 5.5, atan2(skid.x, skid.z) - .9, true, Vector3(4.4, 1.4, 2.6))
			_chute(spot + skid * 15.0 + across * 6.0, atan2(skid.x, skid.z) + .5, 1.0)
			_debris(rng, spot - skid * 14.0, across, 5)
		"drone":
			_scar(spot - skid * 5.0, 1.8, SCAR, .7)
			_place(CAPSULE, spot - skid * 2.5 + across * 1.6, rng.randf_range(0.0, TAU), true, Vector3(1.2, 1.1, 1.6))
			_chute(spot + skid * 7.0, atan2(skid.x, skid.z), .38)
			_debris(rng, spot - skid * 4.0, across, 2)
		"rover":
			var lander_at := spot - skid * 7.0 + across * 3.0
			_scar(lander_at, 9.0, SCORCH, .85)
			_place(LANDER, lander_at, atan2(skid.x, skid.z), true, Vector3(6.0, 2.0, 4.4))
			_debris(rng, lander_at + across * 6.0, skid, 3)
			_add_glint(lander_at)

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, MHSiteTerrain.height(p.x, p.z), p.z)

func _place(model: PackedScene, at: Vector3, yaw: float, solid: bool, size: Vector3) -> Node3D:
	var piece: Node3D = model.instantiate()
	add_child(piece)
	piece.global_position = _ground(at)
	piece.rotation.y = yaw
	MHPalette.apply(piece)
	piece.add_to_group("drop_debris")
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = Vector3(0, size.y / 2.0, 0)
		body.add_child(shape)
		piece.add_child(body)
	return piece

## The canopy, laid on the ground like the pallets' (scripts/drop_site.gd).
func _chute(at: Vector3, yaw: float, size: float) -> void:
	var chute: Node3D = PARACHUTE.instantiate()
	add_child(chute)
	var crown := _ground(at)
	chute.global_position = crown
	chute.rotation.y = yaw
	chute.scale = Vector3(size, 1.0, size)
	MHPalette.apply(chute)
	for mesh in chute.find_children("*", "MeshInstance3D", true, false): _drape(mesh as MeshInstance3D, crown.y)

func _drape(mesh_instance: MeshInstance3D, base_y: float) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if source == null: return
	var to_world := mesh_instance.global_transform
	var to_local := to_world.affine_inverse()
	var draped := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in points.size():
			var p := to_world * points[i]
			p.y = MHSiteTerrain.height(p.x, p.z) + (p.y - base_y)
			points[i] = to_local * p
		arrays[Mesh.ARRAY_VERTEX] = points
		draped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draped.surface_set_material(s, mesh_instance.get_active_material(s))
	mesh_instance.mesh = draped
	mesh_instance.extra_cull_margin = 4.0

func _debris(rng: RandomNumberGenerator, from: Vector3, across: Vector3, count: int) -> void:
	for i in count:
		var piece: Node3D = DEBRIS[(i + kind.length()) % DEBRIS.size()].instantiate()
		add_child(piece)
		var side := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(1.5, 6.0)
		piece.global_position = _ground(from + skid * float(i) * 3.0 + across * side)
		piece.rotation.y = rng.randf_range(0.0, TAU)
		MHPalette.apply(piece)
		piece.add_to_group("drop_debris")

# ---------- marks on the ground ----------

static func _ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "regolith_scar"
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.roughness = .95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = -1
	return m

## A dark crater or scorch: a disc laid on the ground, darkest at the middle,
## with a ragged edge.
func _scar(centre: Vector3, radius: float, colour: Color, strength: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var sectors := 28
	var noise := FastNoiseLite.new()
	noise.seed = int(centre.x * 7.0 + centre.z)
	var grid: Array = []
	for r in rings + 1:
		var row: Array = []
		for s in sectors:
			var a := TAU * s / sectors
			var t := float(r) / rings
			var ragged := 1.0 + .25 * noise.get_noise_2d(cos(a) * 40.0, sin(a) * 40.0)
			var p := centre + Vector3(cos(a), 0, sin(a)) * radius * t * ragged
			var alpha := strength * (1.0 - t * t)
			row.append([Vector3(p.x, MHSiteTerrain.height(p.x, p.z) + .04, p.z), Color(colour, alpha)])
		grid.append(row)
	for r in rings:
		for s in sectors:
			var n := (s + 1) % sectors
			for v in [grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][s], grid[r + 1][n], grid[r][n]]:
				st.set_color(v[1])
				st.add_vertex(v[0] - global_position)
	_add_mark(st)

## A skid gouge: a strip along the ground from `a` to `b`, fading at its sides.
func _strip(a: Vector3, b: Vector3, width: float, colour: Color, strength: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := (b - a).cross(Vector3.UP).normalized() * width / 2.0
	var steps := maxi(int(a.distance_to(b) / 1.5), 2)
	var rows: Array = []
	for i in steps + 1:
		var c := a.lerp(b, float(i) / steps)
		var fade := strength * (1.0 - absf(float(i) / steps - .45))
		var row: Array = []
		for k in [-1.0, 0.0, 1.0]:
			var p: Vector3 = c + across * k
			row.append([Vector3(p.x, MHSiteTerrain.height(p.x, p.z) + .05, p.z), Color(colour, fade * (1.0 - absf(k)))])
		rows.append(row)
	for i in steps:
		for k in 2:
			for v in [rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k], rows[i + 1][k + 1], rows[i][k + 1]]:
				st.set_color(v[1])
				st.add_vertex(v[0] - global_position)
	_add_mark(st)

func _add_mark(st: SurfaceTool) -> void:
	var mark := MeshInstance3D.new()
	mark.mesh = st.commit()
	mark.material_override = _ground_material()
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	mark.position = Vector3.ZERO

# ---------- the glint ----------

func _add_glint(lander_at: Vector3) -> void:
	glint = Sprite3D.new()
	glint.name = "Glint"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, .95, .85, 0))
	gradient.add_point(.12, Color(1, 1, 1, 1))
	gradient.add_point(.3, Color(1, .96, .88, .35))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(.5, .5)
	tex.fill_to = Vector2(1, .5)
	tex.width = 64
	tex.height = 64
	glint.texture = tex
	glint.pixel_size = .0005
	# Its own material: unshaded, fixed on screen, and out of the haze (the
	# distance fog swallowed it at 2 km).
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.fixed_size = true
	mat.disable_fog = true
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, .97, .9, 0)
	glint.material_override = mat
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glint)
	glint.global_position = _ground(lander_at) + Vector3.UP * 3.0

## How bright the glint is now, 0 to 1: a low sun, from far off, twinkling.
func glint_strength(from: Vector3) -> float:
	if glint == null: return 0.0
	var far := Vector2(from.x - glint.global_position.x, from.z - glint.global_position.z).length()
	if far < GLINT_FROM: return 0.0
	var sun := MHGame.sun_altitude(MHGame.sol_hour)
	if sun <= 0.0 or sun > GLINT_SUN: return 0.0
	var low := 1.0 - sun / GLINT_SUN
	var t := Time.get_ticks_msec() / 1000.0
	var twinkle := .55 + .45 * sin(t * 2.3) * sin(t * 3.7 + 1.0)
	return clampf(low * 1.6, 0.0, 1.0) * twinkle

func _process(delta: float) -> void:
	if glint == null or world == null or world.get("player") == null: return
	var you: Vector3 = (world.player as Node3D).global_position
	var strength := glint_strength(you)
	(glint.material_override as StandardMaterial3D).albedo_color.a = strength
	glint.visible = strength > .02
	_glint_check -= delta
	if _glint_check > 0.0 or strength < .3: return
	_glint_check = .5
	# Seen: on screen, with a clear line over the ground. It goes on the record
	# (and the manifest) as a glint, not yet as what it is.
	var known: Node = world.get("known")
	if known == null or known.knows("glint:habrover"): return
	var camera := get_viewport().get_camera_3d()
	var top := glint.global_position
	if camera == null or not camera.is_position_in_frustum(top): return
	var eye := you + Vector3.UP * 1.6
	var steps := maxi(int(Vector2(top.x - eye.x, top.z - eye.z).length() / 12.0), 1)
	for i in range(1, steps):
		var p := eye.lerp(top, float(i) / float(steps))
		if MHSiteTerrain.height(p.x, p.z) > p.y + .3: return
	var origin := Vector2.ZERO
	if world.has_method("_region_origin"): origin = world._region_origin()
	known.learn("glint:habrover", "find", Vector2(top.x, top.z) + origin, "A glint, far out", "you")
