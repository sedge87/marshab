extends Node3D

## A door in a partition wall (bedrooms, toilet cubicles). E swings it open
## or shut about its hinge post. Built by BuildController._build_partitions.
var open := false
var _leaf: Node3D

func setup(leaf: Node3D) -> void:
	_leaf = leaf

func interaction_prompt() -> Dictionary:
	return {"label": "Door", "primary": "Close door" if open else "Open door"}

func interact(_actor: Node = null) -> bool:
	open = not open
	if _leaf != null:
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_leaf, "rotation:y", deg_to_rad(-95.0) if open else 0.0, .45)
	MHAudio.sfx("ui_click", -4.0)
	return true
