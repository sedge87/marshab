extends StaticBody3D

## The bundle of survey stakes in the open stores pallet (chunk 2,
## docs/opening-slice.md Scene 10). It lies across the pallet's open top;
## E takes it, and from then on key 4 puts a stake in your hand
## (scripts/field_kit.gd). scripts/survey_line.gd places it and saves
## whether it's been taken.
##
## Model: Survey_Stake_Bundle from asset_packs/outpost_chunk2_v1, six stowed
## stakes with a carry handle. No lettering: the prompt names it.

const MODEL := "res://assets/models/chunk2/survey_stake_bundle.glb"
const MHPalette := preload("res://scripts/mh_palette.gd")
const REACH := Vector3(.95, .22, .3)   # the box you aim at, about the bundle's size

var line: Node
signal taken

func setup(target_line: Node, at: Transform3D) -> void:
	line = target_line
	name = "StakeBundle"
	add_to_group("stake_bundle")
	set_meta("interaction_target", self)
	var scene: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	if scene != null:
		var model := scene.instantiate() as Node3D
		add_child(model)
		MHPalette.apply(model)
		model.rotation.y = PI * .5   # lengthways along the pallet
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = REACH
	shape.shape = box
	shape.position.y = REACH.y * .5
	add_child(shape)
	line.world.add_child(self)
	global_transform = at

func interaction_prompt() -> Dictionary:
	return {"label": "Survey stakes · a bundle of six", "primary": "Take them"}

func interact(_actor: Node = null) -> bool:
	MHAudio.sfx("suit_clamp", -8.0)
	var hud: Node = line.world.get("explore_hud")
	if hud != null: hud.show_equipment_note("Survey stakes", "On your belt: 4 puts one in your hand.")
	taken.emit()
	queue_free()
	return true
