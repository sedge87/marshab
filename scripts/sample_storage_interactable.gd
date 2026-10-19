class_name MHSampleStorageInteractable
extends MHEquipmentInteractable

var _drawer: Node3D
var _drawer_home := Vector3.ZERO
var _open := false

func _ready() -> void:
	display_name = "Sample Storage Cabinet"
	primary_action = "Open archive drawers"
	_drawer = find_child("Sample_Drawers__shell", true, false) as Node3D
	if _drawer != null: _drawer_home = _drawer.position
	super._ready()

func interaction_prompt() -> Dictionary:
	return {"primary": "Close archive drawers" if _open else "Open archive drawers", "label": display_name}

func interact(_actor: Node = null) -> bool:
	if _drawer == null: return false
	_open = not _open
	var target := _drawer_home + Vector3(0, 0, -.36 if _open else 0)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(_drawer, "position", target, .25)
	return true
