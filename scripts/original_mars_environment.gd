class_name OriginalMarsEnvironment
extends Node3D

# Imported intact from the supplied Mars Simulator project. This node owns only
# scenery, lighting and collision; gameplay systems remain in Mars Habitat.
const TERRAIN_SCENE := preload("res://assets/original_mars/models/terrain.glb")
const FAR_TERRAIN_SCENE := preload("res://assets/original_mars/models/terrain_far.glb")
const DECOR_DATA_PATH := "res://data/original_mars_decor_placements.json"
const MODEL_DIRECTORY := "res://assets/original_mars/models/"

var _terrain_body: StaticBody3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var palette_name := "day"

func build(palette := "") -> void:
	name = "OriginalMarsEnvironment"
	palette_name = palette if not palette.is_empty() else MHGame.palette_name()
	_build_sky_and_lighting()
	_build_terrain()
	_build_far_horizon()
	_build_boundary()

func _ready() -> void:
	# Terrain collision must enter the physics space before decoration is snapped.
	await get_tree().physics_frame
	_build_decor()

func _build_sky_and_lighting() -> void:
	# Butterscotch sky, warm key light and ochre fog from the design reference
	# scene. The palette (day / golden / dusk / cold) follows the chosen site.
	world_environment = WorldEnvironment.new()
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "OriginalSun"
	sun.position = Vector3(0.0, 30.0, 0.0)
	add_child(sun)
	apply_palette(palette_name)

func apply_palette(palette: String) -> void:
	palette_name = palette if MHGame.PALETTES.has(palette) else "day"
	var values: Dictionary = MHGame.PALETTES[palette_name]
	world_environment.environment = MHGame.build_environment(values)
	MHGame.configure_sun(sun, values)
	MHGame.set_window_glow(float(values.window))

func _build_terrain() -> void:
	_terrain_body = StaticBody3D.new()
	_terrain_body.name = "OriginalWalkableTerrain"
	_terrain_body.collision_layer = 1
	_terrain_body.collision_mask = 0
	add_child(_terrain_body)
	var terrain_instance := TERRAIN_SCENE.instantiate()
	terrain_instance.name = "OriginalTerrainModel"
	_terrain_body.add_child(terrain_instance)
	_add_mesh_colliders(terrain_instance, Transform3D.IDENTITY)

func _add_mesh_colliders(node: Node, parent_transform: Transform3D) -> void:
	for child in node.get_children():
		var child_transform := parent_transform
		if child is Node3D:
			child_transform *= (child as Node3D).transform
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh != null:
				var collision := CollisionShape3D.new()
				collision.name = mesh_instance.name + "_collision"
				collision.shape = mesh_instance.mesh.create_trimesh_shape()
				_terrain_body.add_child(collision)
				collision.transform = child_transform
		_add_mesh_colliders(child, child_transform)

func _build_far_horizon() -> void:
	var far_terrain := FAR_TERRAIN_SCENE.instantiate()
	far_terrain.name = "OriginalFarTerrain"
	add_child(far_terrain)

func _build_boundary() -> void:
	# Original invisible safety ring, just inside its visible boundary hills.
	var radius := 126.0
	var segments := 40
	var height := 80.0
	var segment_length := TAU * radius / segments * 1.15
	var boundary := StaticBody3D.new()
	boundary.name = "OriginalBoundarySafetyRing"
	boundary.collision_layer = 1
	boundary.collision_mask = 0
	add_child(boundary)
	for index in range(segments):
		var angle := TAU * index / segments
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(segment_length, height, 2.0)
		shape.shape = box
		shape.position = Vector3(cos(angle) * radius, height * 0.5 - 20.0, sin(angle) * radius)
		shape.rotation.y = -angle + PI * 0.5
		boundary.add_child(shape)

func _build_decor() -> void:
	if not FileAccess.file_exists(DECOR_DATA_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DECOR_DATA_PATH))
	if not (parsed is Dictionary):
		return
	var transforms_by_mesh := {}
	var space_state := get_world_3d().direct_space_state
	for placement in parsed.get("placements", []):
		var model_name := str(placement.get("mesh", ""))
		var coordinates: Array = placement.get("position", [0.0, 0.0, 0.0])
		var hint := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
		var ground_query := PhysicsRayQueryParameters3D.create(hint + Vector3.UP * 400.0, hint + Vector3.DOWN * 400.0, 1)
		var ground_hit: Dictionary = space_state.intersect_ray(ground_query)
		if ground_hit.is_empty():
			continue
		var scale_amount := float(placement.get("scale", 1.0))
		var yaw := deg_to_rad(float(placement.get("yaw", 0.0)))
		var transform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * scale_amount), ground_hit["position"] - Vector3.UP * 0.15 * scale_amount)
		if not transforms_by_mesh.has(model_name):
			transforms_by_mesh[model_name] = []
		transforms_by_mesh[model_name].append(transform)
	for model_name in transforms_by_mesh:
		var mesh := _load_model_mesh(str(model_name))
		if mesh == null:
			continue
		var transforms: Array = transforms_by_mesh[model_name]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for index in transforms.size():
			multimesh.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = str(model_name)
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(instance)
		_add_decor_colliders(mesh, transforms)

func _load_model_mesh(model_name: String) -> Mesh:
	var scene_path := MODEL_DIRECTORY + model_name + ".glb"
	if not ResourceLoader.exists(scene_path):
		return null
	var scene: PackedScene = load(scene_path)
	var model_root := scene.instantiate()
	var mesh_nodes := model_root.find_children("*", "MeshInstance3D", true, false)
	var result: Mesh = null
	if mesh_nodes.size() > 0:
		result = (mesh_nodes[0] as MeshInstance3D).mesh
	model_root.free()
	return result

func _add_decor_colliders(mesh: Mesh, transforms: Array) -> void:
	var bounds := mesh.get_aabb()
	for transform in transforms:
		var body := StaticBody3D.new()
		body.name = "DecorCollider"
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(bounds.size.x, bounds.size.z) * 0.42 * transform.basis.get_scale().x
		collision.shape = sphere
		collision.position = Vector3(0.0, bounds.size.y * 0.45 * transform.basis.get_scale().y, 0.0)
		body.add_child(collision)
		add_child(body)
		body.global_position = transform.origin
		body.rotation.y = transform.basis.get_euler().y
