extends Node3D

## The base radio (chunk 3, docs/assets-chunk3-review.md §4): dressing, and a
## second way to call orbit from inside. The calls themselves come over
## suit comms anywhere (scripts/radio.gd); this set's lamp pulses while a
## call's on air and idles otherwise. E makes the ready call, the same as
## the slate's button (scripts/opening_slice.gd ready_call). Model:
## assets/models/chunk3/base_radio.glb (front lid, handset, call key, lamp).

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk3/base_radio.glb"
const HANDSET_TRAVEL := Vector3(0.026, 0.070, -0.119)

var _lamp_material: StandardMaterial3D
var _handset: Node3D
var _handset_rest := Vector3.ZERO
var _key: Node3D
var _t := 0.0

func _ready() -> void:
	add_to_group("base_radio")
	if not ResourceLoader.exists(MODEL): return
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	MHPalette.apply(model)
	var front := model.find_child("FrontLid", true, false) as Node3D
	if front != null: front.rotation.x = -PI * .487   # open: it lives on a shelf, not in its case
	_handset = model.find_child("Handset", true, false) as Node3D
	if _handset != null: _handset_rest = _handset.position
	_key = model.find_child("CallKey", true, false) as Node3D
	var lamp := model.find_child("CallLamp", true, false) as MeshInstance3D
	if lamp != null and lamp.mesh != null:
		var base := lamp.get_active_material(0)
		_lamp_material = (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
		_lamp_material.emission_enabled = true
		_lamp_material.emission = Color(1.0, .62, .22)
		lamp.material_override = _lamp_material
	var screen := model.find_child("Screen", true, false) as MeshInstance3D
	if screen != null:
		var glow := StandardMaterial3D.new()
		glow.resource_name = "display_screen_glow"
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("#0C1316")
		glow.emission_enabled = true
		glow.emission = Color("#8CC3CB")
		glow.emission_energy_multiplier = .45
		screen.material_override = glow

func _radio() -> Node:
	var world := get_tree().get_first_node_in_group("habitat_world")
	return world.get("radio") if world != null else null

func _process(delta: float) -> void:
	_t += delta
	if _lamp_material == null: return
	var radio := _radio()
	var on_air: bool = radio != null and radio.has_method("on_air") and bool(radio.on_air())
	_lamp_material.emission_energy_multiplier = (.25 + pow(.5 + .5 * cos(_t * TAU * 1.2), 2.0) * 2.5) if on_air else .2

func _slice() -> Node:
	return get_tree().get_first_node_in_group("opening_days")

func interaction_prompt() -> Dictionary:
	var slice := _slice()
	if slice != null and slice.has_method("ready_call_open") and slice.ready_call_open():
		return {"primary": "Call Castle: I'm ready", "label": "Base radio · orbit's on this channel"}
	return {"label": "Base radio · orbit's on this channel. Your suit hears it too."}

func interact(_actor: Node = null) -> bool:
	var slice := _slice()
	if slice == null or not slice.has_method("ready_call_open") or not slice.ready_call_open(): return false
	if _key != null: create_tween().tween_property(_key, "position:z", _key.position.z + .003, .08).set_trans(Tween.TRANS_SINE)
	if _handset != null:
		var lift := create_tween()
		lift.tween_property(_handset, "position", _handset_rest + HANDSET_TRAVEL, .3)
		lift.tween_interval(4.0)
		lift.tween_property(_handset, "position", _handset_rest, .4)
	MHAudio.sfx_at("ui_click", self, -4.0)
	slice.ready_call()
	return true
