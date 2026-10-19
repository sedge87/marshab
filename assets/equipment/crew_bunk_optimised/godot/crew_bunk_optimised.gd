@tool
extends Node3D
## Visual-only interaction adapter. Keep the project's established resource
## effects, placement rules and crew_bunk catalogue ID unchanged.
## GDScript for Godot 4.3+.

signal reading_light_changed(enabled: bool)
signal privacy_curtain_changed(closed: bool)
signal drawer_changed(index: int, opened: bool)

@export var light_initially_enabled: bool = true
@export var curtain_initially_closed: bool = false
@export_range(0.0, 2.0, 0.05) var light_energy: float = 0.6

@onready var reading_light: OmniLight3D = $ReadingLight
@onready var closed_curtain: Node3D = $ClosedCurtain
@onready var berth_model: Node3D = $BerthModel

var _emissive_mesh: MeshInstance3D
var _dark_lamp_material: StandardMaterial3D
var _lit_lamp_material: StandardMaterial3D
var _drawer_open := [false, false, false]
var _drawer_nodes: Dictionary = {}
var _drawer_original_positions: Dictionary = {}
var _next_drawer_index := 1
var _light_enabled := true
var _privacy_closed := false
var _curtain_home_position := Vector3.ZERO
var _curtain_tween: Tween

func _ready() -> void:
	add_to_group("habitat_interactable")
	_remove_unreadable_display_meshes()
	set_meta("interaction_hint", "E curtain · F light · G drawer")
	_emissive_mesh = find_child("ReadingLight_Emissive__light", true, false) as MeshInstance3D
	_dark_lamp_material = StandardMaterial3D.new()
	_dark_lamp_material.albedo_color = Color(0.44, 0.46, 0.43)
	_dark_lamp_material.metallic = 0.05
	_dark_lamp_material.roughness = 0.8
	if _emissive_mesh != null:
		var source_material := _emissive_mesh.get_active_material(0) as StandardMaterial3D
		_lit_lamp_material = source_material.duplicate() as StandardMaterial3D if source_material != null else StandardMaterial3D.new()
		_lit_lamp_material.emission_enabled = true
		if _lit_lamp_material.emission == Color.BLACK:
			_lit_lamp_material.emission = Color("#FFE0A0")
		_emissive_mesh.material_override = _lit_lamp_material
		_emissive_mesh.add_to_group("grid_powered_light")
		_emissive_mesh.set_meta("grid_emission_on", _lit_lamp_material.emission)
		_emissive_mesh.set_meta("grid_emission_off", Color("#293034"))
	if reading_light != null:
		reading_light.add_to_group("grid_powered_light")
		reading_light.set_meta("grid_light_energy", light_energy)
	if closed_curtain != null:
		_curtain_home_position = closed_curtain.position
	for i in range(1, 4):
		var pieces: Array[Node3D] = []
		for suffix in ["composite", "trim", "metal", "safety"]:
			var mesh_name = "Drawer_%02d_Moveable__%s" % [i, suffix]
			var component = find_child(mesh_name, true, false) as Node3D
			if component != null:
				pieces.append(component)
				_drawer_original_positions[component] = component.position
		_drawer_nodes[i] = pieces
	if not Engine.is_editor_hint():
		_build_drawer_shells()
	set_reading_light_enabled(light_initially_enabled)
	set_privacy_closed(curtain_initially_closed)

func _remove_unreadable_display_meshes() -> void:
	# The delivered bunk's baked signage is mirrored in our placement convention
	# and sits coplanar with the frame, producing visible z-fighting at corners.
	# Keep the physical bunk and its functional lamp/drawers, but omit these
	# presentation-only text/decal surfaces until a corrected source texture lands.
	for mesh_name in ["Static_Architecture__decal", "Control_Display__screen"]:
		var mesh := find_child(mesh_name, true, false) as VisualInstance3D
		if mesh != null:
			mesh.visible = false

func set_reading_light_enabled(enabled: bool) -> void:
	_light_enabled = enabled
	if reading_light != null:
		reading_light.visible = enabled
		reading_light.light_energy = light_energy
	if _emissive_mesh != null:
		_emissive_mesh.material_override = _lit_lamp_material if enabled else _dark_lamp_material
	reading_light_changed.emit(enabled)

func set_privacy_closed(closed: bool) -> void:
	_privacy_closed = closed
	if closed_curtain == null:
		privacy_curtain_changed.emit(closed)
		return
	if _curtain_tween != null and _curtain_tween.is_valid():
		_curtain_tween.kill()
	# Retract vertically into the bunk's overhead cassette. Sliding sideways
	# left a visible fabric panel beside the berth and read unlike a real curtain.
	var parked_position := _curtain_home_position + Vector3(0, 1.82, 0)
	_curtain_tween = create_tween()
	_curtain_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if closed:
		# The supplied closed panel is a single fabric sheet.  Pull it from the
		# right-hand track instead of making it pop into existence.
		closed_curtain.position = parked_position
		closed_curtain.visible = true
		_curtain_tween.tween_property(closed_curtain, "position", _curtain_home_position, 0.42)
	else:
		_curtain_tween.tween_property(closed_curtain, "position", parked_position, 0.42)
		_curtain_tween.tween_callback(func():
			if not _privacy_closed and closed_curtain != null:
				closed_curtain.visible = false
				closed_curtain.position = _curtain_home_position
		)
	privacy_curtain_changed.emit(closed)

func set_drawer_open(index: int, opened: bool) -> void:
	if index < 1 or index > 3:
		push_warning("Crew berth drawer index must be 1, 2, or 3")
		return
	_drawer_open[index-1] = opened
	var nodes: Array = _drawer_nodes.get(index, [])
	for piece: Node3D in nodes:
		var resting_position: Vector3 = _drawer_original_positions[piece]
		var target_position := resting_position + Vector3(0, 0, -0.38 if opened else 0.0)
		if is_inside_tree() and not Engine.is_editor_hint():
			var tween := create_tween()
			tween.tween_property(piece, "position", target_position, 0.22)
		else:
			piece.position = target_position
	drawer_changed.emit(index, opened)

func toggle_drawer(index: int) -> void:
	if index >= 1 and index <= 3:
		set_drawer_open(index, not _drawer_open[index-1])

func _build_drawer_shells() -> void:
	if berth_model == null:
		return
	for index in range(1, 4):
		var x: float = [-0.666, 0.0, 0.666][index - 1]
		var shell := Node3D.new()
		shell.name = "Drawer_%02d_StorageBox" % index
		# The source mesh contains the fronts and handles only.  These four
		# shallow panels make each drawer a physical tray once it is extended.
		shell.position = Vector3(x, 0.395, -0.495)
		berth_model.add_child(shell)
		_add_drawer_box_piece(shell, "Bottom", Vector3(0.56, 0.025, 0.45), Vector3(0, -0.145, 0.22))
		_add_drawer_box_piece(shell, "LeftSide", Vector3(0.025, 0.27, 0.45), Vector3(-0.28, -0.01, 0.22))
		_add_drawer_box_piece(shell, "RightSide", Vector3(0.025, 0.27, 0.45), Vector3(0.28, -0.01, 0.22))
		_add_drawer_box_piece(shell, "Back", Vector3(0.56, 0.27, 0.025), Vector3(0, -0.01, 0.44))
		var pieces: Array = _drawer_nodes.get(index, [])
		pieces.append(shell)
		_drawer_nodes[index] = pieces
		_drawer_original_positions[shell] = shell.position

func _add_drawer_box_piece(parent: Node3D, piece_name: String, size: Vector3, local_position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#3E4748")
	material.metallic = 0.18
	material.roughness = 0.62
	mesh_instance.material_override = material
	mesh_instance.position = local_position
	parent.add_child(mesh_instance)

## Player-facing interaction hooks. The simulation still owns the bunk's
## berth/happiness/power effects; these only change its presentation state.
func interact(_actor: Node = null) -> bool:
	set_privacy_closed(not _privacy_closed)
	return true

func interaction_prompt() -> Dictionary:
	var drawer_action := "Close drawer %d" % _next_drawer_index if _drawer_open[_next_drawer_index - 1] else "Open drawer %d" % _next_drawer_index
	return {
		"primary": "Curtain",
		"secondary": "Reading light",
		"tertiary": drawer_action,
		"label": "Crew Bunk",
	}

func interact_secondary(_actor: Node = null) -> bool:
	set_reading_light_enabled(not _light_enabled)
	return true

func interact_tertiary(_actor: Node = null) -> bool:
	toggle_drawer(_next_drawer_index)
	_next_drawer_index = 1 if _next_drawer_index == 3 else _next_drawer_index + 1
	return true
