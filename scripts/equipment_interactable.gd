class_name MHEquipmentInteractable
extends Node3D

## Lightweight first-person interaction adapter for delivered equipment art.
## Catalogue effects remain in BuildController; this owns only inspect/on-off UI.

@export var display_name := "Equipment"
@export var primary_action := "Inspect"
@export var secondary_action := ""
@export_multiline var educational_note := ""
@export var light_node_path: NodePath
@export var emissive_node_path: NodePath

var _light_enabled := true
var _equipment_light: Light3D
var _emissive_mesh: MeshInstance3D
var _lit_emissive_material: StandardMaterial3D
var _dark_emissive_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("habitat_interactable")
	_make_model_materials_two_sided()
	if not light_node_path.is_empty():
		_equipment_light = get_node_or_null(light_node_path) as Light3D
		if _equipment_light != null:
			_equipment_light.add_to_group("grid_powered_light")
			_equipment_light.set_meta("grid_light_energy", _equipment_light.light_energy)
	if not emissive_node_path.is_empty():
		_emissive_mesh = get_node_or_null(emissive_node_path) as MeshInstance3D
		if _emissive_mesh != null:
			var source := _emissive_mesh.get_active_material(0) as StandardMaterial3D
			_lit_emissive_material = source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
			_lit_emissive_material.emission_enabled = true
			if _lit_emissive_material.emission == Color.BLACK:
				_lit_emissive_material.emission = Color("#FFE0A0")
			_dark_emissive_material = _lit_emissive_material.duplicate() as StandardMaterial3D
			_dark_emissive_material.emission_enabled = false
			_dark_emissive_material.albedo_color = Color("#39403C")
	_set_light_enabled(true)

func _make_model_materials_two_sided() -> void:
	# Thin sheet-metal panels in delivered GLBs must remain visible from either
	# side in Godot's Compatibility renderer.
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

func interaction_prompt() -> Dictionary:
	return {
		"primary": primary_action,
		"secondary": secondary_action,
		"label": display_name,
	}

func interact(_actor: Node = null) -> bool:
	var note := _live_readout()
	if note.is_empty():
		note = educational_note
	if not note.is_empty():
		get_tree().call_group("explore_hud", "show_equipment_note", display_name, note)
	return true

func _live_readout() -> String:
	# These displays are supplied as static GLB artwork. Put changing simulation
	# data in the player's depth-safe HUD rather than spawning labels through walls.
	var builder := get_tree().get_first_node_in_group("habitat_builder") as BuildController
	if builder == null:
		return ""
	var climate := builder.climate_at(global_position)
	if display_name == "Common Table":
		return "COMMON TABLE\n%s · %.1f °C\n%s" % [MHGame.formatted_sol_time(), float(climate.get("temperature", 0.0)), str(climate.get("context", "Habitat systems"))]
	if display_name == "Planetary Data Console":
		var telemetry: Dictionary = MHGame.site().get("telemetry", {})
		return "PLANETARY DATA\n%s · %s\nSurface %s · sunlight %d%%\nElevation %s · radiation %s" % [str(MHGame.site().get("based_on", MHGame.site_name())), MHGame.formatted_sol_time(), str(telemetry.get("temperature", "—")), roundi(MHGame.sunlight_fraction * 100.0), str(telemetry.get("elevation", "—")), str(telemetry.get("radiation", "—"))]
	return ""

func interact_secondary(_actor: Node = null) -> bool:
	if secondary_action.is_empty():
		return false
	_set_light_enabled(not _light_enabled)
	return true

func _set_light_enabled(enabled: bool) -> void:
	_light_enabled = enabled
	if _equipment_light != null:
		_equipment_light.visible = enabled
	if _emissive_mesh != null:
		_emissive_mesh.material_override = _lit_emissive_material if enabled else _dark_emissive_material
