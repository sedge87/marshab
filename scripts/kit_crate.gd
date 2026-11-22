extends StaticBody3D

## One piece of a core's fit-out kit in its crate, by the core's wall
## (opening slice, docs/opening-slice.md §4a Scene 7). E takes the piece out
## and it's in your hands (scripts/carry.gd carry_new): look where it goes,
## R turns it, E sets it down. Q puts it back. Once its piece is placed the
## crate's gone. Crates are worked out from the kit still to place
## (scripts/build_rules.gd kit_left), so nothing about them is saved.
##
## Stand-in look until the fit-out crates arrive (docs/assets-chunk1.md §4):
## a ribbed box with a pale lid. No lettering: the prompt names what's in it.

const MHPalette := preload("res://scripts/mh_palette.gd")
const SIZE := Vector3(.7, .55, .55)

var world: Node
var id := ""
var _check := 0.0

func setup(target_world: Node, piece: String, at: Vector3, facing: Vector3) -> void:
	world = target_world
	id = piece
	name = "KitCrate_" + id
	add_to_group("kit_crate")
	set_meta("interaction_target", self)
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
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = SIZE
	shape.shape = collision
	shape.position.y = SIZE.y * .5
	add_child(shape)
	world.add_child(self)
	global_position = at
	if facing.length() > .1: rotation.y = atan2(facing.x, facing.z)

func _role(role: String) -> Material:
	var source := StandardMaterial3D.new()
	source.resource_name = role
	return MHPalette.material(source)

func _label() -> String:
	return str(EquipmentCatalog.get_entry(id).get("label", id))

func interaction_prompt() -> Dictionary:
	return {"label": "Fit-out crate · " + _label(), "primary": "Take it out"}

func interact(_actor: Node = null) -> bool:
	var carry: Node = get_tree().get_first_node_in_group("carry")
	return carry != null and carry.carry_new(id)

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0: return
	_check = .5
	if MHChapterOne.available(id, world.builder) <= 0: queue_free()
