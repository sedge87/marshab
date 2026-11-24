extends Node3D

## The salvage tub by the Print Shop (chunk 3, docs/assets-chunk3-review.md
## §6): what's stripped from the storm pallets, shown, not handled. Its three
## groups (harness, control board, mounting hardware) fill as the salvage
## store rises; no pickup busywork. Model: assets/models/chunk3/salvage_tub.glb.

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk3/salvage_tub.glb"
const GROUPS := [["MountingHardware", 1.0], ["PowerDataHarness", 40.0], ["ControlBoard", 85.0]]

var _model: Node3D
var _check := 0.0

func _ready() -> void:
	if not ResourceLoader.exists(MODEL): return
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	MHPalette.apply(_model)
	var lid := _model.find_child("Lid", true, false) as Node3D
	if lid != null: lid.rotation.x = deg_to_rad(100.0)

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _model == null: return
	_check = 1.0
	for group in GROUPS:
		var node := _model.find_child(str(group[0]), true, false) as Node3D
		if node != null: node.visible = MHMaterials.salvage_kg >= float(group[1])

func interaction_prompt() -> Dictionary:
	return {"label": "Salvage tub · %s of salvage in the store" % MHStyle.kg(roundi(MHMaterials.salvage_kg))}

func interact(_actor: Node = null) -> bool:
	return false
