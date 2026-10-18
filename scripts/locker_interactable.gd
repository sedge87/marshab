class_name MHLockerInteractable
extends Node3D

## Delivered locker art has separate door meshes but no animation rig.  At
## runtime we group each door around its real outside hinge and animate it.

@export var display_name := "Personal Locker"
@export var primary_action := "Open doors"

var _doors_open := false
var _left_hinge: Node3D
var _right_hinge: Node3D

func _ready() -> void:
	add_to_group("habitat_interactable")
	_make_model_materials_two_sided()
	_build_door_hinges()

func interaction_prompt() -> Dictionary:
	return {"primary": "Close doors" if _doors_open else primary_action, "label": display_name}

func interact(_actor: Node = null) -> bool:
	_doors_open = not _doors_open
	_animate_doors()
	return true

func _make_model_materials_two_sided() -> void:
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface, material)

func _build_door_hinges() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	_left_hinge = _create_hinge(model, "Door_L01", true)
	_right_hinge = _create_hinge(model, "Door_L02", false)

func _create_hinge(model: Node3D, prefix: String, left: bool) -> Node3D:
	var pieces: Array[MeshInstance3D] = []
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh != null and mesh.name.begins_with(prefix):
			pieces.append(mesh)
	if pieces.is_empty():
		return null
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	for mesh in pieces:
		var aabb := mesh.get_aabb()
		for corner in range(8):
			var point := aabb.position + Vector3(aabb.size.x if corner & 1 else 0.0, aabb.size.y if corner & 2 else 0.0, aabb.size.z if corner & 4 else 0.0)
			var local_point := model.to_local(mesh.to_global(point))
			bounds_min = bounds_min.min(local_point)
			bounds_max = bounds_max.max(local_point)
	var hinge := Node3D.new()
	hinge.name = "%s_Hinge" % prefix
	model.add_child(hinge)
	hinge.position = Vector3(bounds_min.x + .012 if left else bounds_max.x - .012, (bounds_min.y + bounds_max.y) * .5, (bounds_min.z + bounds_max.z) * .5)
	for mesh in pieces:
		mesh.reparent(hinge, true)
	return hinge

func _animate_doors() -> void:
	if _left_hinge == null or _right_hinge == null:
		return
	var left_target := deg_to_rad(-102.0 if _doors_open else 0.0)
	var right_target := deg_to_rad(102.0 if _doors_open else 0.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_left_hinge, "rotation:y", left_target, .32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_right_hinge, "rotation:y", right_target, .32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
