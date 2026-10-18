class_name MHEquipmentInteractable
extends Node3D

## Lightweight first-person interaction adapter for delivered equipment art.
## Catalogue effects remain in BuildController; this owns only inspect/on-off UI.

@export var display_name := "Equipment"
@export var primary_action := "Inspect"
@export var secondary_action := ""
@export_multiline var educational_note := ""
@export var light_node_path: NodePath

var _inspected := false
var _light_enabled := true
var _readout: Label3D
var _equipment_light: Light3D

func _ready() -> void:
	add_to_group("habitat_interactable")
	if not light_node_path.is_empty():
		_equipment_light = get_node_or_null(light_node_path) as Light3D
		if _equipment_light != null:
			_equipment_light.add_to_group("grid_powered_light")
			_equipment_light.set_meta("grid_light_energy", _equipment_light.light_energy)
	_build_readout()

func interaction_prompt() -> Dictionary:
	return {
		"primary": primary_action,
		"secondary": secondary_action,
		"label": display_name,
	}

func interact(_actor: Node = null) -> bool:
	_inspected = not _inspected
	if _readout != null:
		_readout.visible = _inspected
	return true

func interact_secondary(_actor: Node = null) -> bool:
	if secondary_action.is_empty():
		return false
	_light_enabled = not _light_enabled
	if _equipment_light != null:
		_equipment_light.visible = _light_enabled
	return true

func _build_readout() -> void:
	if educational_note.is_empty():
		return
	_readout = Label3D.new()
	_readout.name = "InspectReadout"
	_readout.text = educational_note
	_readout.font = MHStyle.font(600, false, 1)
	_readout.font_size = 32
	_readout.outline_size = 8
	_readout.outline_modulate = Color(MHStyle.INK_950, .9)
	_readout.modulate = MHStyle.TEXT_PRIMARY
	_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_readout.pixel_size = .008
	_readout.position = Vector3(0, 1.15, -.06)
	_readout.visible = false
	add_child(_readout)
