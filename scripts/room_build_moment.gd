extends Node3D

## The short "watch it build" moment when a liner room is placed
## (docs/rooms-and-equipment.md, "How building feels"): the liner inflates
## off the floor, then the crawler makes one quick pass over the roof laying
## the regolith shell behind it, and the room is simply there. About three
## seconds, purely for show: the room works the moment it's placed.
## House materials only (scripts/mh_palette.gd roles); no lettering.

const MHPalette := preload("res://scripts/mh_palette.gd")
const INFLATE := 1.1
const PASS := 1.6
const FADE := .4
const REGOLITH := Color("#9A6B4C")

var _liner: MeshInstance3D
var _shell: MeshInstance3D
var _crawler: Node3D
var _mats: Array = []
var _lo := Vector2.ZERO
var _hi := Vector2.ZERO
var _top := 0.0

## outline: the room's floor polygon (world x, z); base_y: its floor.
func setup(outline: PackedVector2Array, base_y: float, height: float) -> Node3D:
	name = "RoomBuildMoment"
	if outline.size() < 3: return self
	_lo = outline[0]; _hi = outline[0]
	for p in outline:
		_lo = Vector2(minf(_lo.x, p.x), minf(_lo.y, p.y))
		_hi = Vector2(maxf(_hi.x, p.x), maxf(_hi.y, p.y))
	_top = height + .06
	position = Vector3(0, base_y, 0)
	# The liner: the room's own shape, pale and soft, a touch proud of the walls.
	_liner = MeshInstance3D.new()
	_liner.mesh = _prism(outline, _top, .08)
	_liner.material_override = _mat(MHPalette.ROLES.white[0], .55)
	_liner.scale = Vector3(1, .04, 1)
	add_child(_liner)
	# The shell, laid by the crawler: a roof skin that grows behind it.
	_shell = MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(1, .12, _hi.y - _lo.y + .3)
	_shell.mesh = slab
	_shell.material_override = _mat(REGOLITH, .7)
	_shell.position = Vector3(_lo.x, _top + .06, (_lo.y + _hi.y) * .5)
	_shell.scale = Vector3(.001, 1, 1)
	_shell.visible = false
	add_child(_shell)
	_crawler = _make_crawler()
	_crawler.visible = false
	add_child(_crawler)
	_run()
	return self

func _run() -> void:
	var tween := create_tween()
	tween.tween_property(_liner, "scale:y", 1.0, INFLATE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_pass)
	tween.tween_method(_pass, 0.0, 1.0, PASS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_fade, 1.0, 0.0, FADE)
	tween.tween_callback(queue_free)

func _start_pass() -> void:
	_shell.visible = true
	_crawler.visible = true
	_crawler.position = Vector3(_lo.x - .6, _top + .35, (_lo.y + _hi.y) * .5)

## The crawler's pass, 0 to 1: the shell is laid behind it.
func _pass(t: float) -> void:
	var width := _hi.x - _lo.x
	_crawler.position.x = _lo.x - .6 + (width + 1.2) * t
	var laid := clampf(width * t, .001, width)
	_shell.scale.x = laid
	_shell.position.x = _lo.x + laid * .5

func _fade(a: float) -> void:
	for m in _mats: (m as StandardMaterial3D).albedo_color.a = a * float((m as StandardMaterial3D).get_meta("alpha", 1.0))

func _mat(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, alpha)
	m.roughness = .7
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.set_meta("alpha", alpha)
	_mats.append(m)
	return m

## The crawler: a low tracked body with a print head, from house roles.
func _make_crawler() -> Node3D:
	var body := Node3D.new()
	var parts := [
		[Vector3(1.1, .38, .9), Vector3(0, .1, 0), "graphite"],
		[Vector3(1.2, .22, .2), Vector3(0, -.12, .42), "rubber"],
		[Vector3(1.2, .22, .2), Vector3(0, -.12, -.42), "rubber"],
		[Vector3(.25, .3, .7), Vector3(-.6, -.05, 0), "orange"],   # the print head, trailing
		[Vector3(.5, .12, .5), Vector3(.1, .35, 0), "frame"],
	]
	for part in parts:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		mesh.material_override = _mat(MHPalette.ROLES[str(part[2])][0])
		body.add_child(mesh)
	return body

## The outline pushed out by `grow` and extruded to `height`, closed on top.
func _prism(outline: PackedVector2Array, height: float, grow: float) -> ArrayMesh:
	var ring := outline
	var grown := Geometry2D.offset_polygon(outline, grow)
	if not grown.is_empty(): ring = grown[0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var v := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, height, b.y), Vector3(a.x, height, a.y)]
		for idx in [0, 1, 2, 0, 2, 3]: st.add_vertex(v[idx])
	var tris := Geometry2D.triangulate_polygon(ring)
	for i in tris: st.add_vertex(Vector3(ring[i].x, height, ring[i].y))
	st.generate_normals()
	return st.commit()
