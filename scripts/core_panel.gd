extends StaticBody3D

## The core's upgrade panel, on its rack beside the life-support switches
## (scripts/module_life.gd): a small dark screen with a lamp, amber while an
## upgrade plan waits to be fitted. E opens the upgrades
## (scripts/core_upgrades_screen.gd). No lettering on the model.

const MHPalette := preload("res://scripts/mh_palette.gd")

var world: Node
var _lamp: StandardMaterial3D

func setup(target_world: Node) -> void:
	world = target_world
	name = "CorePanel"
	set_meta("interaction_target", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.26, .22, .08)
	shape.shape = box
	add_child(shape)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(.24, .2, .03)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = MHPalette.ROLES.graphite[0]
	plate_mat.roughness = .6
	plate_mesh.material = plate_mat
	plate.mesh = plate_mesh
	add_child(plate)
	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(.18, .12, .01)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = MHPalette.ROLES.glass[0]
	glass_mat.emission_enabled = true
	glass_mat.emission = Color("#2E6F7A")
	glass_mat.emission_energy_multiplier = .6
	glass_mesh.material = glass_mat
	glass.mesh = glass_mesh
	glass.position = Vector3(0, .015, -.02)
	add_child(glass)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = .012; lamp_mesh.height = .024
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	lamp_mesh.material = _lamp
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(.09, -.07, -.02)
	add_child(lamp)
	refresh()

## Amber while a known upgrade isn't fitted yet; dark otherwise.
func refresh() -> void:
	var waiting := _waiting()
	var colour := Color("#F2B544") if waiting > 0 else Color("#222222")
	_lamp.albedo_color = colour.darkened(.3)
	_lamp.emission = colour
	_lamp.emission_energy_multiplier = 2.0 if waiting > 0 else 0.0

func _waiting() -> int:
	if not MHRoomTypes.gated(): return 0
	var count := 0
	for id in MHRoomTypes.UPGRADES:
		if MHRoomTypes.plan_known(str(id)) and not MHRoomTypes.is_fitted(str(id)): count += 1
	return count

func interaction_prompt() -> Dictionary:
	var fitted := 0
	for id in MHRoomTypes.UPGRADES:
		if MHRoomTypes.is_fitted(str(id)): fitted += 1
	var words := "%d of %d fitted" % [fitted, MHRoomTypes.UPGRADES.size()]
	if _waiting() > 0: words += " · a plan to fit"
	return {"label": "Core upgrades · " + words, "primary": "Open"}

func interact(_actor: Node = null) -> bool:
	if world != null and world.has_method("open_core_upgrades"): world.open_core_upgrades()
	return true
