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

var _emissive_mesh: MeshInstance3D
var _dark_lamp_material: StandardMaterial3D
var _lit_lamp_material: StandardMaterial3D
var _drawer_open := [false, false, false]
var _drawer_nodes: Dictionary = {}
var _drawer_original_positions: Dictionary = {}

func _ready() -> void:
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
	for i in range(1, 4):
		var pieces: Array[Node3D] = []
		for suffix in ["composite", "trim", "metal", "safety"]:
			var mesh_name = "Drawer_%02d_Moveable__%s" % [i, suffix]
			var component = find_child(mesh_name, true, false) as Node3D
			if component != null:
				pieces.append(component)
				_drawer_original_positions[component] = component.position
		_drawer_nodes[i] = pieces
	set_reading_light_enabled(light_initially_enabled)
	set_privacy_closed(curtain_initially_closed)

func set_reading_light_enabled(enabled: bool) -> void:
	if reading_light != null:
		reading_light.visible = enabled
		reading_light.light_energy = light_energy
	if _emissive_mesh != null:
		_emissive_mesh.material_override = _lit_lamp_material if enabled else _dark_lamp_material
	reading_light_changed.emit(enabled)

func set_privacy_closed(closed: bool) -> void:
	if closed_curtain != null:
		closed_curtain.visible = closed
	privacy_curtain_changed.emit(closed)

func set_drawer_open(index: int, opened: bool) -> void:
	if index < 1 or index > 3:
		push_warning("Crew berth drawer index must be 1, 2, or 3")
		return
	_drawer_open[index-1] = opened
	var nodes: Array = _drawer_nodes.get(index, [])
	for piece: Node3D in nodes:
		var resting_position: Vector3 = _drawer_original_positions[piece]
		var target_position := resting_position + Vector3(0, 0, -0.22 if opened else 0.0)
		if is_inside_tree() and not Engine.is_editor_hint():
			var tween := create_tween()
			tween.tween_property(piece, "position", target_position, 0.22)
		else:
			piece.position = target_position
	drawer_changed.emit(index, opened)

func toggle_drawer(index: int) -> void:
	if index >= 1 and index <= 3:
		set_drawer_open(index, not _drawer_open[index-1])
