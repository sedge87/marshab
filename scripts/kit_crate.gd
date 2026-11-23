extends StaticBody3D

## The core's fit-out kit: one big case on the core's floor (opening slice,
## docs/opening-slice.md §4a Scene 7). 23 Nov: one box, not a crate a piece.
## E opens it: the lid lifts, the packed kit shows, and from then on B
## furnishes (scripts/build_rules.gd kit_open), with the whole kit on the
## list: bunk, rack, table, chair, work light and the Site plan terminal.
## It stays open and empty until every kit piece is placed, then it's gone.
## Worked out from the kit still to place (build_rules.gd kit_left) and one
## flag, MHChapterOne.unpacked["kit_box"], so nothing else is saved.
##
## Model: a stand-in, the chunk 1 large fit-out case scaled up to hold the
## kit, until the kit box model arrives (docs/assets-chunk3.md). It has a
## hinged Lid (opens 103° about its rear hinge) and packed cargo under
## "Contents". No lettering: the prompt names it.

const MHPalette := preload("res://scripts/mh_palette.gd")
const BUILD_RULES := preload("res://scripts/build_rules.gd")
const MODEL := "res://assets/models/chunk1/fitout_crate_large.glb"
const KIT_MODEL := "res://assets/models/chunk1/fitout_kit_box.glb"   # the real one, once it's made
const STAND_IN_SCALE := 1.6
const SIZE := Vector3(1.299, .711, .789) * STAND_IN_SCALE
const LID_OPEN := 103.0   # degrees
const LID_SECONDS := .5
const FLAG := "kit_box"

var world: Node
var _check := 0.0
var _lid: Node3D
var _lid_closed := 0.0
var _open := false

func setup(target_world: Node, at: Vector3, facing: Vector3) -> void:
	world = target_world
	name = "FitoutKitBox"
	add_to_group("kit_crate")
	set_meta("interaction_target", self)
	var real := ResourceLoader.exists(KIT_MODEL)
	var path := KIT_MODEL if real else MODEL
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene != null:
		var model := scene.instantiate() as Node3D
		model.name = "Model"
		if not real: model.scale = Vector3.ONE * STAND_IN_SCALE
		add_child(model)
		MHPalette.apply(model)
		_lid = model.find_child("Lid", true, false) as Node3D
		if _lid != null: _lid_closed = _lid.rotation.x
	else:
		_stand_in()
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = SIZE
	shape.shape = collision
	shape.position.y = SIZE.y * .5
	add_child(shape)
	world.add_child(self)
	global_position = at
	if facing.length() > .1: rotation.y = atan2(facing.x, facing.z)

## A ribbed box with a pale lid, if the models are missing.
func _stand_in() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	body.mesh = box
	body.material_override = _role("graphite")
	body.position.y = SIZE.y * .5
	add_child(body)
	var lid := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(SIZE.x + .04, .05, SIZE.z + .04)
	lid.mesh = lid_box
	lid.material_override = _role("white_painted")
	lid.position.y = SIZE.y + .025
	add_child(lid)

func _role(role: String) -> Material:
	var source := StandardMaterial3D.new()
	source.resource_name = role
	return MHPalette.material(source)

func interaction_prompt() -> Dictionary:
	if BUILD_RULES.kit_open(): return {"label": "Fit-out kit · unpacked: stand in a room and press B to furnish"}
	return {"label": "Fit-out kit · bunk, rack, table, chair, work light, Site plan terminal", "primary": "Open it"}

func interact(_actor: Node = null) -> bool:
	if BUILD_RULES.kit_open(): return false
	MHChapterOne.unpacked[FLAG] = true
	_set_open(true)
	MHAudio.sfx("suit_clamp", -8.0)
	# A beat to see what's inside before the notice.
	get_tree().create_timer(LID_SECONDS + .9).timeout.connect(func():
		MHNotices.post("valid", "Fit-out kit unpacked", "Press B to furnish. Everything in the kit is on your build list, the Site plan terminal too: place it where you'll pass it, and it plans new rooms.", "log"))
	return true

## The lid swings up; the packed kit stays in view.
func _set_open(on: bool) -> void:
	if on == _open: return
	_open = on
	if _lid == null: return
	var target := _lid_closed - deg_to_rad(LID_OPEN) if on else _lid_closed
	if not is_inside_tree():
		_lid.rotation.x = target
		return
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).tween_property(_lid, "rotation:x", target, LID_SECONDS)

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0: return
	_check = .5
	if world == null or BUILD_RULES.kit_left(world.builder).is_empty():
		queue_free()
		return
	if BUILD_RULES.kit_open() and not _open: _set_open(true)   # a loaded game: it stays open
