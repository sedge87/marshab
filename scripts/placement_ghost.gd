extends RefCounted

## The green (fits) / red (doesn't) hologram shown while placing an item.
## One shader for furnishing and outdoor props; materials are shared.
const SHADER := preload("res://shaders/placement_ghost.gdshader")
const VALID := Color("#57F6B3")
const INVALID := Color("#FF5A61")
static var _materials := {}

static func material(valid: bool) -> ShaderMaterial:
	if not _materials.has(valid):
		var made := ShaderMaterial.new()
		made.shader = SHADER
		made.set_shader_parameter("tint", VALID if valid else INVALID)
		made.render_priority = 1
		_materials[valid] = made
	return _materials[valid]

static func apply(node: Node, valid: bool) -> void:
	var made := material(valid)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.material_override = made
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
