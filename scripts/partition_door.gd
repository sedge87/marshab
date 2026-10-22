extends Node3D

## A door in a partition wall (bedrooms, toilet cubicles). E swings it open
## or shut about its hinge post, away from whoever opens it. Built by
## BuildController._build_partitions (solid or glass leaf).
var open := false
var _swing := -95.0
var _leaf: Node3D

func setup(leaf: Node3D) -> void:
	_leaf = leaf
	add_to_group("partition_door")

## The middle of the doorway (the door node sits on its hinge post).
func centre() -> Vector3:
	return (get_parent() as Node3D).global_position if get_parent() is Node3D else global_position

func interaction_prompt() -> Dictionary:
	return {"label": "Door", "primary": "Close door" if open else "Open door"}

func interact(actor: Node = null) -> bool:
	open = not open
	if open:
		# The leaf swings to local +Z at -95°: pick the side away from the opener.
		var opener := actor as Node3D if actor is Node3D else get_tree().get_first_node_in_group("player") as Node3D
		if opener != null: _swing = 95.0 if to_local(opener.global_position).z > 0.0 else -95.0
	if _leaf != null:
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_leaf, "rotation:y", deg_to_rad(_swing) if open else 0.0, .45)
	MHAudio.sfx("ui_click", -4.0)
	return true
