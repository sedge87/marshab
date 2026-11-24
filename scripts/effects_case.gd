extends StaticBody3D

## A crew effects case on the plain (chunk 3, docs/assets-chunk3-review.md):
## the manifest's corrupted line, found by walking. E opens it; inside on its
## tray is Kai's niece's plush bear (canon). E again takes it, and the bear
## goes on B's Unpacked tab to be placed at home. A find, not a quest: no
## call, no mark, nothing gated on it. Model: assets/models/chunk3/
## effects_case.glb (Lid hinged at the back, ItemPoint on the tray; its
## ExampleKeepsake is a display sample and stays hidden).

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk3/effects_case.glb"
const PLUSH := "res://assets/equipment/mars_odds_and_ends_v1/models/zero_g_plush.glb"

var chunk: Node
var _lid: Node3D
var _item_point: Node3D
var _bear: Node3D

func setup(owner_chunk: Node, at: Vector3) -> void:
	chunk = owner_chunk
	name = "EffectsCase"
	add_to_group("effects_case")
	set_meta("interaction_target", self)
	collision_layer = 1
	global_position = at
	rotation.y = .7
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.66, .3, .5)
	shape.shape = box
	shape.position.y = .15
	add_child(shape)
	if ResourceLoader.exists(MODEL):
		var model := (load(MODEL) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		MHPalette.apply(model)
		add_child(model)
		_lid = model.find_child("Lid", true, false) as Node3D
		_item_point = model.find_child("ItemPoint", true, false) as Node3D
		var sample := model.find_child("ExampleKeepsake", true, false) as Node3D
		if sample != null: sample.visible = false
	if bool(chunk.case_opened):
		if _lid != null: _lid.rotation.x = deg_to_rad(104.0)
		if not bool(chunk.plush_taken): _show_bear()

func _show_bear() -> void:
	if _bear != null or _item_point == null or not ResourceLoader.exists(PLUSH): return
	_bear = (load(PLUSH) as PackedScene).instantiate() as Node3D
	MHPalette.apply(_bear)
	_item_point.add_child(_bear)
	_bear.scale = Vector3.ONE * .62
	_bear.rotation = Vector3(deg_to_rad(-80.0), .3, 0)   # lying on its back on the tray

func interaction_prompt() -> Dictionary:
	if not bool(chunk.case_opened): return {"label": "Crew effects case · the manifest's corrupted line", "primary": "Open it"}
	if not bool(chunk.plush_taken): return {"label": "Crew effects case · a plush bear in a little suit", "primary": "Take the bear"}
	return {"label": "Crew effects case · empty"}

func interact(_player: Node = null) -> bool:
	if not bool(chunk.case_opened):
		chunk.case_opened = true
		MHAudio.sfx_at("suit_clamp", self, -6.0, 1.1)
		if _lid != null: create_tween().tween_property(_lid, "rotation:x", deg_to_rad(104.0), .8).set_trans(Tween.TRANS_SINE)
		_show_bear()
		return true
	if not bool(chunk.plush_taken):
		if _bear != null: _bear.queue_free()
		_bear = null
		chunk.plush_found()
		MHAudio.moment()
		return true
	return false
