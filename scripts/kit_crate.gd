extends StaticBody3D

## One piece of a core's fit-out kit in its crate, by the core's wall
## (opening slice, docs/opening-slice.md §4a Scene 7). E takes the piece out
## and it's in your hands (scripts/carry.gd carry_new): look where it goes,
## R turns it, E sets it down. Q puts it back. Once its piece is placed the
## crate's gone. Crates are worked out from the kit still to place
## (scripts/build_rules.gd kit_left), so nothing about them is saved.
##
## The models (asset_packs/outpost_chunk1_v1/Fitout_Crates): three moulded
## cases with a hinged Lid (opens 103° about its rear hinge) and packed cargo
## under "Contents". Each crate shows only its own piece's cargo (if the case
## has one); taking it out opens the lid and lifts that cargo out, putting it
## back closes it again. No lettering: the prompt names what's in it.

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODELS := "res://assets/models/chunk1/fitout_crate_%s.glb"
## Which case each piece comes in, and the packed cargo node that stands for it.
const CASES := {
	"portable_interior_work_light": ["small", "WorkLight"],
	"crew_chair": ["medium", "FoldedChair"],
	"general_module_rack": ["medium", "RackRails"],
	"site_plan_terminal": ["large", "PackedSitePlanTerminal"],
	"crew_bunk": ["large", ""],
	"common_table": ["large", ""],
}
const SIZES := {"small": Vector3(.584, .242, .393), "medium": Vector3(.888, .329, .609), "large": Vector3(1.299, .711, .789)}
const LID_OPEN := 103.0   # degrees
const LID_SECONDS := .34

var world: Node
var id := ""
var _check := 0.0
var _lid: Node3D
var _lid_closed := 0.0
var _cargo: Node3D        # this piece's packed cargo, or null
var _open := false

func setup(target_world: Node, piece: String, at: Vector3, facing: Vector3) -> void:
	world = target_world
	id = piece
	name = "KitCrate_" + id
	add_to_group("kit_crate")
	set_meta("interaction_target", self)
	var case: Array = CASES.get(id, ["medium", ""])
	var size: Vector3 = SIZES[case[0]]
	var path := MODELS % case[0]
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene != null:
		var model := scene.instantiate() as Node3D
		model.name = "Model"
		add_child(model)
		MHPalette.apply(model)
		_lid = model.find_child("Lid", true, false) as Node3D
		if _lid != null: _lid_closed = _lid.rotation.x
		var contents := model.find_child("Contents", true, false)
		if contents != null:
			for item in contents.get_children():
				if str(item.name) == str(case[1]): _cargo = item as Node3D
				else: (item as Node3D).visible = false   # another piece's cargo: its own crate has it
	else:
		_stand_in(size)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = size
	shape.shape = collision
	shape.position.y = size.y * .5
	add_child(shape)
	world.add_child(self)
	global_position = at
	if facing.length() > .1: rotation.y = atan2(facing.x, facing.z)

## A ribbed box with a pale lid, if the models are missing.
func _stand_in(size: Vector3) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	body.material_override = _role("graphite")
	body.position.y = size.y * .5
	add_child(body)
	var lid := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(size.x + .04, .05, size.z + .04)
	lid.mesh = lid_box
	lid.material_override = _role("white_painted")
	lid.position.y = size.y + .025
	add_child(lid)

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
	if carry == null or not carry.carry_new(id): return false
	_set_open(true)
	return true

## The lid swings up and the cargo's lifted out; shut again, it's back.
func _set_open(on: bool) -> void:
	if on == _open: return
	_open = on
	if _cargo != null: _cargo.visible = not on
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
	if MHChapterOne.available(id, world.builder) <= 0:
		queue_free()
		return
	# Put back (Q) or dropped: the piece is in its crate again.
	if _open:
		var carry: Node = get_tree().get_first_node_in_group("carry")
		var held: Dictionary = carry.get("carrying") if carry != null else {}
		if str(held.get("id", "")) != id: _set_open(false)
