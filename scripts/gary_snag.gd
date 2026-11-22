extends Node3D

## Scene 2 of the opening slice (docs/opening-slice.md §4a): GAR-Y caught
## in a drifting canopy. A torn piece of parachute is snagged on it, with
## lines wrapped round its wheels and mast. It strains and chirps unhappily.
## You free it by hand: hold E at each snag point (SNAGS of them) while it
## watches. When the last line comes away, scripts/drop_field.gd runs the
## meeting.
##
## The model (asset_packs/outpost_chunk1_v1/GAR_Y_Canopy_Snag), set at
## GAR-Y's origin: the torn Cloth slumped behind it and Line_1-3 (front-left
## wheel, back-right wheel, mast), each with its wrap. Each line goes as its
## snag is freed; the cloth stays behind as debris. If the model's missing,
## a scaled-down storm_cargo parachute and thin drawn lines stand in.

const CANOPY := "res://assets/models/chunk1/gar_y_canopy_snag.glb"
const MHPalette := preload("res://scripts/mh_palette.gd")
const PARACHUTE := "res://assets/models/storm_cargo/parachute.glb"
const SNAGS := 3
const FREE_SECONDS := 1.4
const REACH := 3.0
const STRAIN_EVERY := 4.0

signal freed

var gary: Node3D
var field: Node
var left: Array = []              # the snag points not yet freed
var _lines: Dictionary = {}       # point → its line mesh
var _strain := 1.0
var _cloth: Node3D

func setup(target_field: Node, target_gary: Node3D, already_freed: int = 0) -> void:
	field = target_field
	gary = target_gary
	name = "GarySnag"
	add_to_group("gary_snag")
	global_position = gary.global_position
	global_basis = gary.global_basis
	_build_cloth()
	# Snag points: front-left wheel, rear-right wheel, the mast.
	var spots := [Vector3(-.42, .18, -.38), Vector3(.42, .18, .40), Vector3(0, .9, .05)]
	var labels := ["A line round the front wheel", "A line round the back wheel", "The canopy's caught on its mast"]
	for i in SNAGS:
		var model_line: Node3D = _canopy.find_child("Line_%d" % (i + 1), true, false) as Node3D if _canopy != null else null
		if i < already_freed:
			if model_line != null: model_line.visible = false
			continue
		var point := SnagPoint.new()
		point.snag = self
		point.label = labels[i]
		add_child(point)
		point.position = spots[i]
		left.append(point)
		_lines[point] = model_line if model_line != null else _line(spots[i], Vector3(0, .5, 1.6))

var _canopy: Node3D
func _build_cloth() -> void:
	var model: PackedScene = load(CANOPY) if ResourceLoader.exists(CANOPY) else null
	if model != null:
		_canopy = model.instantiate() as Node3D
		add_child(_canopy)
		MHPalette.apply(_canopy)
		_cloth = _canopy.find_child("Cloth", true, false) as Node3D   # under the model's CanopySnag root
		return
	var scene: PackedScene = load(PARACHUTE) if ResourceLoader.exists(PARACHUTE) else null
	if scene != null:
		_cloth = scene.instantiate() as Node3D
		_cloth.scale = Vector3.ONE * .12
	else:
		var mesh := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(2.4, 1.8)
		mesh.mesh = quad
		_cloth = mesh
	add_child(_cloth)
	_cloth.position = Vector3(0, .1, 1.7)
	_cloth.rotation_degrees = Vector3(-12, 20, 0)

func _line(from: Vector3, to: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = .008
	tube.bottom_radius = .008
	tube.height = from.distance_to(to)
	mesh.mesh = tube
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.92, .55, .2)
	mesh.material_override = material
	add_child(mesh)
	# In the snag's own space (look_at works in world space, which put these
	# lines at the world's origin, by the lander).
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP) if absf(dir.dot(Vector3.UP)) < .99 else Vector3.RIGHT
	mesh.transform = Transform3D(Basis(side.normalized(), dir, side.normalized().cross(dir)).orthonormalized(), (from + to) * .5)
	return mesh

func freed_count() -> int:
	return SNAGS - left.size()

func point_freed(point: Node) -> void:
	left.erase(point)
	var line: Node = _lines.get(point)
	if line != null: line.queue_free()
	_lines.erase(point)
	point.queue_free()
	MHAudio.sfx_at("place", gary, -4.0, .6)
	if left.is_empty():
		if _cloth != null:
			var t := create_tween()
			t.tween_property(_cloth, "position", _cloth.position + Vector3(0, 0, 2.5), 2.0)
		freed.emit()

func _process(delta: float) -> void:
	if gary == null or not is_instance_valid(gary) or left.is_empty(): return
	_strain -= delta
	if _strain > 0.0: return
	_strain = STRAIN_EVERY
	# Straining against the lines: a lurch and an unhappy chirp.
	var body: Node3D = gary.get("_body")
	if body != null:
		var t := create_tween()
		t.tween_property(body, "rotation:z", .08, .25)
		t.tween_property(body, "rotation:z", -.06, .3)
		t.tween_property(body, "rotation:z", 0.0, .25)
	MHAudio.sfx_at("place", gary, -10.0, 1.8)

## One snag point: hold E here to free it.
class SnagPoint extends StaticBody3D:
	var snag: Node
	var label := ""
	var _holding := false
	var _held := 0.0

	func _ready() -> void:
		set_meta("interaction_target", self)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = .28
		shape.shape = sphere
		add_child(shape)

	func interaction_prompt() -> Dictionary:
		if _holding: return {"label": label, "primary": "Freeing it…"}
		return {"label": label, "primary": "Hold to free it"}

	func interact(_player: Node = null) -> bool:
		_holding = true
		_held = 0.0
		return true

	func _process(delta: float) -> void:
		if not _holding: return
		var player: Node3D = snag.field.world.player
		if not Input.is_key_pressed(KEY_E) or player.global_position.distance_to(global_position) > snag.REACH:
			_holding = false
			return
		free_for(delta * float(player.get_meta("hands_speed", 1.0)))

	## E held this long; the line comes away at the end. (Tests call it directly.)
	func free_for(delta: float) -> bool:
		_held += delta
		if _held < snag.FREE_SECONDS: return false
		_holding = false
		snag.point_freed(self)
		return true
