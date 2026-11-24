extends Node3D

## The chunk 3 regolith intake's moving parts (its RegolithIntakeVisuals.gd.txt,
## adapted): four legs swing out and extend, the boom telescopes, the chute
## swings over. A newly placed intake unfolds once; afterwards the scoop
## wheel and sieve drum turn while it digs. The intake's feedstock numbers
## stay in the game (habitat_sim); this only shows it working.

const MHPalette := preload("res://scripts/mh_palette.gd")
const UNFOLD_SECONDS := 3.2

static var _seen := {}

var _rig: Node3D
var _arm: Node3D
var _wheel: Node3D
var _sieve: Node3D
var _chute: Node3D
var _chute_extension: Node3D
var _rock: Node3D
var _lamp_mat: StandardMaterial3D
var _legs: Array[Node3D] = []
var _slides: Array[Node3D] = []
var _tips: Array[Node3D] = []
var _pads: Array[Node3D] = []
var _stages: Array[Node3D] = []
var _deployment := 1.0
var _unfolding := false

func _ready() -> void:
	MHPalette.apply(self)
	_rig = find_child("RegolithIntake", true, false) as Node3D
	if _rig == null: return
	_arm = _rig.get_node_or_null("ScoopArm") as Node3D
	_wheel = _rig.find_child("ScoopWheel", true, false) as Node3D
	_sieve = _rig.get_node_or_null("SieveDrum") as Node3D
	_chute = _rig.get_node_or_null("DischargeChute") as Node3D
	_chute_extension = _chute.get_node_or_null("ChuteExtension") as Node3D if _chute != null else null
	_rock = _rig.find_child("ChokeRock", true, false) as Node3D
	if _rock != null: _rock.visible = false
	var lamp := _rig.get_node_or_null("StateLight") as MeshInstance3D
	if lamp != null and lamp.mesh != null:
		var base := lamp.get_active_material(0)
		_lamp_mat = (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
		lamp.material_override = _lamp_mat
	for i in range(1, 5):
		var leg := _rig.get_node_or_null("Leg_%d" % i) as Node3D
		if leg == null: continue
		_legs.append(leg)
		_slides.append(leg.get_node_or_null("LegSlide_%d" % i) as Node3D)
		_tips.append(leg.find_child("LegTip_%d" % i, true, false) as Node3D)
		_pads.append(leg.find_child("FootPad_%d" % i, true, false) as Node3D)
	if _arm != null:
		for i in range(2, 7):
			var stage := _arm.find_child("BoomStage_%d" % i, true, false) as Node3D
			if stage != null: _stages.append(stage)
	# Unfold once when it's first set down in play (not on every rebuild or load).
	var key := _key()
	var fresh := not key.is_empty() and not _seen.has(key) and Engine.get_process_frames() > 600
	if not key.is_empty(): _seen[key] = true
	_set_deployment(0.0 if fresh else 1.0)
	_unfolding = fresh
	if fresh: MHAudio.sfx_at("door_open", self, -6.0, .7)

func _key() -> String:
	var node: Node = self
	while node != null:
		if node.has_meta("zone_placement_id"): return str(node.get_meta("zone_placement_id"))
		node = node.get_parent()
	return ""

func _progress(begin: float, end: float) -> float:
	return clampf((_deployment - begin) / (end - begin), 0.0, 1.0)

func _set_deployment(fraction: float) -> void:
	_deployment = clampf(fraction, 0.0, 1.0)
	var leg_turn := _progress(0.0, 0.43)
	var leg_slide := _progress(0.43, 0.80)
	var boom := _progress(0.26, 1.0)
	for i in range(_legs.size()):
		var side := -1.0 if i < 2 else 1.0
		var angle := -side * deg_to_rad(114.0) * leg_turn
		_legs[i].rotation = Vector3(0.0, 0.0, angle)
		if _slides[i] != null: _slides[i].position.y = 0.134 * leg_slide
		if _tips[i] != null: _tips[i].position.y = 0.134 * leg_slide
		if _pads[i] != null: _pads[i].rotation = Vector3(0.0, 0.0, -angle)
	if _arm != null: _arm.rotation = Vector3(-0.060 * boom, 0.0, 0.0)
	for stage in _stages: stage.position.z = -0.209 * boom
	if _chute != null:
		_chute.position.y = 0.478 + 0.087 * (1.0 - _progress(0.74, 0.94))
		_chute.rotation = Vector3(-PI + (PI + 0.174) * _progress(0.11, 0.74), 0.0, 0.0)
	if _chute_extension != null: _chute_extension.position.z = 0.333 * _progress(0.69, 1.0)
	if _lamp_mat != null:
		_lamp_mat.emission = Color(1.0, 0.46, 0.10)
		_lamp_mat.emission_enabled = _deployment >= .999
		_lamp_mat.emission_energy_multiplier = 1.2

func _process(delta: float) -> void:
	if _rig == null: return
	if _unfolding:
		_set_deployment(_deployment + delta / UNFOLD_SECONDS)
		_unfolding = _deployment < 1.0
		return
	if _wheel != null: _wheel.rotate_object_local(Vector3.RIGHT, delta * .6 * TAU * 0.84)
	if _sieve != null: _sieve.rotate_object_local(Vector3.BACK, -delta * .6 * TAU * 0.46)
