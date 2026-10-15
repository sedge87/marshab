class_name HabitatLadder
extends Node3D

var upper_y := 3.05

func setup(target_upper_y: float) -> void:
	upper_y = target_upper_y
	add_to_group("habitat_ladder")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(.45,.50,.53)
	metal.metallic = .7
	metal.roughness = .34
	for x in [-.42, .42]:
		_bar(Vector3(x, 1.45, 0), Vector3(.10, 2.9, .10), metal)
	for y in [.30,.70,1.10,1.50,1.90,2.30,2.70]:
		_bar(Vector3(0, y, 0), Vector3(.90,.08,.10), metal)

func use(player: CharacterBody3D) -> void:
	if player.global_position.y < global_position.y + 1.45:
		player.global_position = Vector3(global_position.x, upper_y + .28, global_position.z - .70)
	else:
		player.global_position = Vector3(global_position.x, global_position.y + .28, global_position.z - .70)
	player.velocity = Vector3.ZERO
	player.safe_position = player.global_position
	MHAudio.sfx("ladder")

func _bar(local_position: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = local_position
	add_child(mesh_instance)
