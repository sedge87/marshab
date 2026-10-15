class_name MarsTerrain
extends Node3D

# One maintainable heightfield is the source of truth for both terrain rendering
# and collision. Compatibility renderer friendly: 25,921 vertices / 51,200 tris.
const CELL_SIZE := 2.5
const RESOLUTION := 160
const HALF_SIZE := RESOLUTION * CELL_SIZE * 0.5
const PLAYABLE_HALF_SIZE := 172.0
const ROCK_LIBRARY := [
	preload("res://assets/models/mars_boulder_round.glb"),
	preload("res://assets/models/mars_boulder_flat.glb"),
	preload("res://assets/models/mars_boulder_dark.glb"),
	preload("res://assets/models/mars_rock_cluster.glb"),
	preload("res://assets/models/mars_rock_formation.glb"),
	preload("res://assets/models/mars_stone_debris.glb")
]

var height_data := PackedFloat32Array()
var terrain_material: StandardMaterial3D
var colour_noise: FastNoiseLite
var deposit_noise: FastNoiseLite

func build() -> void:
	name = "MarsTerrain"
	_generate_height_data()
	_create_visible_mesh()
	_create_heightmap_collision()
	_create_boundary()
	_create_boulders()

func height_at_world(world_x: float, world_z: float) -> float:
	# Bilinear interpolation mirrors how the rendered grid is sampled.
	var grid_x: float = clampf((world_x + HALF_SIZE) / CELL_SIZE, 0.0, float(RESOLUTION))
	var grid_z: float = clampf((world_z + HALF_SIZE) / CELL_SIZE, 0.0, float(RESOLUTION))
	var x0: int = int(floor(grid_x))
	var z0: int = int(floor(grid_z))
	var x1: int = mini(x0 + 1, RESOLUTION)
	var z1: int = mini(z0 + 1, RESOLUTION)
	var tx: float = grid_x - float(x0)
	var tz: float = grid_z - float(z0)
	var a := _height_at_index(x0, z0)
	var b := _height_at_index(x1, z0)
	var c := _height_at_index(x0, z1)
	var d := _height_at_index(x1, z1)
	return lerp(lerp(a, b, tx), lerp(c, d, tx), tz)

func _height_at_index(x_index: int, z_index: int) -> float:
	return height_data[z_index * (RESOLUTION + 1) + x_index]

func _generate_height_data() -> void:
	# Keep the playable land intentionally simple: a clear, flat construction site
	# that only rolls gently towards its outer boundary.
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = 413
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.014
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 2
	colour_noise = FastNoiseLite.new()
	colour_noise.seed = 1247
	colour_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	colour_noise.frequency = 0.026
	colour_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	colour_noise.fractal_octaves = 3
	deposit_noise = FastNoiseLite.new()
	deposit_noise.seed = 679
	deposit_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	deposit_noise.frequency = 0.009
	deposit_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	deposit_noise.fractal_octaves = 2
	for z_index in range(RESOLUTION + 1):
		for x_index in range(RESOLUTION + 1):
			var world_x := (x_index - RESOLUTION * 0.5) * CELL_SIZE
			var world_z := (z_index - RESOLUTION * 0.5) * CELL_SIZE
			var distance_from_centre := Vector2(world_x, world_z).length()
			var outer_blend := smoothstep(96.0, 166.0, distance_from_centre)
			var gentle_roll: float = terrain_noise.get_noise_2d(world_x, world_z) * 1.8 * outer_blend
			var boundary_rise: float = smoothstep(158.0, 198.0, distance_from_centre) * 3.5
			height_data.append(gentle_roll + boundary_rise)

func _create_visible_mesh() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for z_index in range(RESOLUTION + 1):
		for x_index in range(RESOLUTION + 1):
			var world_x := (x_index - RESOLUTION * 0.5) * CELL_SIZE
			var world_z := (z_index - RESOLUTION * 0.5) * CELL_SIZE
			var height := _height_at_index(x_index, z_index)
			vertices.append(Vector3(world_x, height, world_z))
			var left := _height_at_index(max(x_index - 1, 0), z_index)
			var right := _height_at_index(min(x_index + 1, RESOLUTION), z_index)
			var back := _height_at_index(x_index, max(z_index - 1, 0))
			var forward := _height_at_index(x_index, min(z_index + 1, RESOLUTION))
			var surface_normal := Vector3(left - right, CELL_SIZE * 2.0, back - forward).normalized()
			normals.append(surface_normal)
			colours.append(_terrain_colour(world_x, world_z, height, surface_normal))
	for z_index in range(RESOLUTION):
		for x_index in range(RESOLUTION):
			var base := z_index * (RESOLUTION + 1) + x_index
			indices.append_array([base, base + RESOLUTION + 1, base + 1, base + 1, base + RESOLUTION + 1, base + RESOLUTION + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain_material = StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.92
	terrain_material.metallic = 0.0
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "HeightmapTerrainMesh"
	terrain_mesh.mesh = mesh
	terrain_mesh.material_override = terrain_material
	add_child(terrain_mesh)

func _terrain_colour(world_x: float, world_z: float, height: float, surface_normal: Vector3) -> Color:
	# Multi-scale noise gives gradual mineral changes with fine surface variation.
	var mineral_noise: float = colour_noise.get_noise_2d(world_x, world_z)
	var sand_noise: float = deposit_noise.get_noise_2d(world_x, world_z)
	var slope_amount: float = 1.0 - surface_normal.y
	var dusty_orange := Color("#b86c42")
	var rusty_red := Color("#914532")
	var muted_brown := Color("#725244")
	var dark_basalt := Color("#453b3a")
	var light_sand := Color("#d29461")
	var colour := dusty_orange.lerp(rusty_red, smoothstep(-0.24, 0.62, mineral_noise))
	colour = colour.lerp(muted_brown, smoothstep(0.38, 0.82, mineral_noise) * 0.36)
	var sandy_deposit: float = smoothstep(-0.15, 0.55, sand_noise) * (1.0 - smoothstep(0.08, 0.26, slope_amount)) * 0.56
	colour = colour.lerp(light_sand, sandy_deposit)
	var exposed_rock: float = maxf(smoothstep(0.11, 0.34, slope_amount), smoothstep(8.5, 13.0, height) * 0.5)
	colour = colour.lerp(dark_basalt, exposed_rock * 0.76)
	return colour

func _create_heightmap_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "HeightmapTerrainCollision"
	var collision := CollisionShape3D.new()
	collision.name = "HeightmapCollisionShape"
	var shape := HeightMapShape3D.new()
	shape.map_width = RESOLUTION + 1
	shape.map_depth = RESOLUTION + 1
	shape.map_data = height_data
	# HeightMapShape3D cells are one unit apart; scaling by CELL_SIZE makes its
	# extents and every sampled height point exactly match the visible mesh.
	collision.shape = shape
	collision.scale = Vector3(CELL_SIZE, 1.0, CELL_SIZE)
	body.add_child(collision)
	add_child(body)

func _create_boundary() -> void:
	# Tall invisible walls stop exploration before the heightfield edge. Sparse
	# dark marker stones make the boundary legible without looking like a fence.
	for wall_data in [
		[Vector3(PLAYABLE_HALF_SIZE, 7.0, 0), Vector3(2.0, 54.0, PLAYABLE_HALF_SIZE * 2.0)],
		[Vector3(-PLAYABLE_HALF_SIZE, 7.0, 0), Vector3(2.0, 54.0, PLAYABLE_HALF_SIZE * 2.0)],
		[Vector3(0, 7.0, PLAYABLE_HALF_SIZE), Vector3(PLAYABLE_HALF_SIZE * 2.0, 54.0, 2.0)],
		[Vector3(0, 7.0, -PLAYABLE_HALF_SIZE), Vector3(PLAYABLE_HALF_SIZE * 2.0, 54.0, 2.0)]
	]:
		var wall := StaticBody3D.new()
		wall.name = "PlayableAreaBoundary"
		var wall_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall_data[1]
		wall_shape.shape = box
		wall.position = wall_data[0]
		wall.add_child(wall_shape)
		add_child(wall)
	var marker_material := _rock_material(Color("#4b2c2b"))
	for step in range(-150, 151, 30):
		_add_boundary_marker(Vector2(step, -PLAYABLE_HALF_SIZE + 3.0), marker_material)
		_add_boundary_marker(Vector2(step, PLAYABLE_HALF_SIZE - 3.0), marker_material)
		_add_boundary_marker(Vector2(-PLAYABLE_HALF_SIZE + 3.0, step), marker_material)
		_add_boundary_marker(Vector2(PLAYABLE_HALF_SIZE - 3.0, step), marker_material)

func _add_boundary_marker(location: Vector2, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 1.4
	mesh.height = 2.0
	mesh.radial_segments = 7
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.material_override = material
	marker.position = Vector3(location.x, height_at_world(location.x, location.y) + 0.55, location.y)
	add_child(marker)

func _create_boulders() -> void:
	# [asset index, location, scale, collision radius]. The open central plaza is
	# deliberately untouched; samples become denser only beyond the build space.
	var placements := [
		[0, Vector2(-48, -66), 1.2, 0.72], [1, Vector2(48, -72), 1.15, 0.82],
		[2, Vector2(78, 34), 1.4, 0.72], [3, Vector2(-92, 37), 1.35, 1.0],
		[4, Vector2(118, -52), 1.05, 1.7], [5, Vector2(-113, -79), 1.1, 0.62],
		[0, Vector2(31, 105), 0.9, 0.54], [1, Vector2(-67, 112), 1.15, 0.8],
		[2, Vector2(132, 73), 1.0, 0.58], [3, Vector2(-142, 9), 0.9, 0.72],
		[5, Vector2(92, 93), 0.8, 0.45], [0, Vector2(-99, -122), 0.85, 0.52],
		[4, Vector2(19, -137), 0.9, 1.45], [5, Vector2(142, -18), 0.9, 0.48]
	]
	for index in placements.size():
		var data: Array = placements[index]
		var library_index: int = data[0]
		var location: Vector2 = data[1]
		var scale_amount: float = data[2]
		var collision_radius: float = data[3]
		var rock: Node3D = ROCK_LIBRARY[library_index].instantiate() as Node3D
		rock.name = "MarsGeology"
		rock.position = Vector3(location.x, height_at_world(location.x, location.y) + 0.03, location.y)
		rock.rotation_degrees.y = float((index * 43) % 360)
		rock.scale = Vector3.ONE * scale_amount
		add_child(rock)
		var body := StaticBody3D.new()
		body.position = rock.position
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = collision_radius * scale_amount
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func _rock_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	return material
