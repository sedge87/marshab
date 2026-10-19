class_name MHColdStorageInteractable
extends MHEquipmentInteractable

var _open := [false, false]
var _doors: Array[Node3D] = []
var _homes: Array[Vector3] = []

func _ready() -> void:
	display_name = "Cold Storage Unit"
	primary_action = "Open upper door"
	secondary_action = "Open lower door"
	for mesh_name in ["Door_1__cream", "Door_2__cream"]:
		var door := find_child(mesh_name, true, false) as Node3D
		if door != null:
			_doors.append(door)
			_homes.append(door.position)
	super._ready()

func interaction_prompt() -> Dictionary:
	return {
		"primary": "Close upper door" if _open[0] else "Open upper door",
		"secondary": "Close lower door" if _open[1] else "Open lower door",
		"label": display_name,
	}

func interact(_actor: Node = null) -> bool:
	_toggle(0)
	return true

func interact_secondary(_actor: Node = null) -> bool:
	_toggle(1)
	return true

func _toggle(index: int) -> void:
	if index >= _doors.size(): return
	_open[index] = not _open[index]
	# The delivered doors are separate meshes but have no hinge pivot. Slide each
	# shallowly aside instead of rotating around its centre like a cardboard sign.
	var target := _homes[index] + Vector3(.42 if index == 0 else -.42, 0, 0) if _open[index] else _homes[index]
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(_doors[index], "position", target, .25)
