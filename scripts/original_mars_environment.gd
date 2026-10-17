class_name OriginalMarsEnvironment
extends Node3D

# Imported intact from the supplied Mars Simulator project. This node owns only
# scenery, lighting and collision; gameplay systems remain in Mars Habitat.
const TERRAIN_SCENE := preload("res://assets/original_mars/models/terrain.glb")
const FAR_TERRAIN_SCENE := preload("res://assets/original_mars/models/terrain_far.glb")
const DECOR_DATA_PATH := "res://data/original_mars_decor_placements.json"
const MODEL_DIRECTORY := "res://assets/original_mars/models/"
const CELESTIAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 body_colour : source_color = vec4(1.0);
uniform vec4 crater_colour : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float glow = 0.0;
uniform float crater_strength = 1.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = length(p);
	if (edge > 0.5) { discard; }
	float craters = smoothstep(0.085, 0.045, length(p - vec2(-0.16, 0.10)));
	craters += smoothstep(0.052, 0.023, length(p - vec2(0.13, -0.12)));
	craters += smoothstep(0.040, 0.017, length(p - vec2(0.05, 0.18)));
	vec3 colour = mix(body_colour.rgb * (0.92 - edge * 0.5), crater_colour.rgb, craters * crater_strength);
	ALBEDO = colour;
	EMISSION = body_colour.rgb * glow;
	ALPHA = smoothstep(0.5, 0.46, edge);
}
"""

var _terrain_body: StaticBody3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var palette_name := "day"
var _palette_values: Dictionary = {}
var _sky_material: ProceduralSkyMaterial
var _phobos: MeshInstance3D
var _deimos: MeshInstance3D
var _show_celestials := true

func build(palette := "") -> void:
	name = "OriginalMarsEnvironment"
	_show_celestials = palette.is_empty()
	palette_name = palette if not palette.is_empty() else MHGame.palette_name()
	_build_sky_and_lighting()
	_build_terrain()
	_build_far_horizon()
	_build_boundary()

func _ready() -> void:
	# Terrain collision must enter the physics space before decoration is snapped.
	await get_tree().physics_frame
	_build_site_landscape()
	_build_decor()

func _build_site_landscape() -> void:
	# The central imported terrain remains a flat, reliable construction pad. These
	# landmarks make each selected place recognisable without putting obstructions
	# or uneven ground under the student build grid.
	var profile := str(MHGame.site().get("terrain_profile", "elysium"))
	match profile:
		"valles":
			_build_valles_landscape()
		"gale":
			_build_gale_landscape()
		"utopia":
			_build_utopia_landscape()

func _landscape_material(colour: Color, roughness := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.vertex_color_use_as_albedo = true
	return material

func _terrain_height_at(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 300.0, point + Vector3.DOWN * 300.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.get("position", point).y)

func _add_landform(name: String, points: PackedVector3Array, colour: Color) -> void:
	if points.size() < 3:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in points:
		surface.set_color(colour)
		surface.add_vertex(point)
	var mesh := surface.commit()
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = _landscape_material(colour)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)

func _build_valles_landscape() -> void:
	# Two distant, broken escarpments evoke the Valles Marineris floor while
	# preserving a broad safe build area between them.
	var colour := Color("#80503A")
	for side in [-1.0, 1.0]:
		for section in range(3):
			var x0 := -96.0 + section * 66.0
			var x1 := x0 + 52.0
			var z: float = side * (58.0 + float(section % 2) * 8.0)
			var base0 := _terrain_height_at(Vector3(x0, 0.0, z))
			var base1 := _terrain_height_at(Vector3(x1, 0.0, z))
			var crest0 := Vector3(x0, base0 + 13.0 + section * 2.0, z - side * 12.0)
			var crest1 := Vector3(x1, base1 + 16.0 + section * 2.0, z - side * 12.0)
			_add_landform("VallesEscarpment", PackedVector3Array([
				Vector3(x0, base0, z), Vector3(x1, base1, z), crest1,
				Vector3(x0, base0, z), crest1, crest0
			]), colour)

func _build_gale_landscape() -> void:
	# A low, discontinuous outer crater rim: visible from the base but never a
	# wall around it, reflecting an open landing area in Gale's lowlands.
	var colour := Color("#8A5037")
	var segments := 18
	for index in range(segments):
		if index in [2, 11, 15]:
			continue
		var a0 := TAU * float(index) / segments
		var a1 := TAU * float(index + 1) / segments
		var inner0 := Vector3(cos(a0) * 67.0, 0.0, sin(a0) * 67.0)
		var inner1 := Vector3(cos(a1) * 67.0, 0.0, sin(a1) * 67.0)
		var outer0 := Vector3(cos(a0) * 91.0, 0.0, sin(a0) * 91.0)
		var outer1 := Vector3(cos(a1) * 91.0, 0.0, sin(a1) * 91.0)
		inner0.y = _terrain_height_at(inner0); inner1.y = _terrain_height_at(inner1)
		outer0.y = _terrain_height_at(outer0) + 6.0; outer1.y = _terrain_height_at(outer1) + 6.0
		_add_landform("GaleCraterRim", PackedVector3Array([inner0, inner1, outer1, inner0, outer1, outer0]), colour)

func _build_utopia_landscape() -> void:
	# Pale, shallow permafrost deposits sit outside the build pad; their subtle
	# colour makes the Utopia profile feel colder without becoming an obstacle.
	var colour := Color("#A99A90")
	var deposits: Array[Vector3] = [Vector3(-70.0, 0.0, -48.0), Vector3(68.0, 0.0, 45.0), Vector3(-38.0, 0.0, 76.0)]
	for deposit in deposits:
		var centre: Vector3 = deposit
		var radius := 16.0
		var points := PackedVector3Array()
		for index in range(10):
			var a0 := TAU * float(index) / 10.0
			var a1 := TAU * float(index + 1) / 10.0
			var p0: Vector3 = centre + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
			var p1: Vector3 = centre + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
			centre.y = _terrain_height_at(centre) + .05
			p0.y = _terrain_height_at(p0) + .06; p1.y = _terrain_height_at(p1) + .06
			points.append(centre); points.append(p0); points.append(p1)
		_add_landform("UtopiaPermafrost", points, colour)

func _build_sky_and_lighting() -> void:
	# The project targets the Compatibility renderer. Its stable built-in
	# procedural sky is used for the actual background; the optional Sky3D addon
	# remains installed for later Forward+/Mobile evaluation, but is not in the
	# runtime path after it produced a black sky on this renderer.
	world_environment = WorldEnvironment.new()
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "OriginalSun"
	sun.position = Vector3(0.0, 30.0, 0.0)
	add_child(sun)
	if _show_celestials:
		_build_celestial_bodies()
	apply_palette(palette_name)

func _build_celestial_bodies() -> void:
	# Phobos and Deimos are small teaching aids with visibly different orbital
	# periods. The Sun is represented by the directional light, never a sprite.
	_phobos = _celestial_disc("Phobos", 10.0, Color("#B8AA98"), .16)
	_deimos = _celestial_disc("Deimos", 5.5, Color("#9B9086"), .11)

func _celestial_disc(body_name: String, diameter: float, colour: Color, emission: float, crater_strength := 1.0) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = body_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2(diameter, diameter)
	body.mesh = mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = CELESTIAL_SHADER
	material.set_shader_parameter("body_colour", colour)
	material.set_shader_parameter("crater_colour", colour.darkened(.58))
	material.set_shader_parameter("glow", emission)
	material.set_shader_parameter("crater_strength", crater_strength)
	body.material_override = material
	add_child(body)
	return body

func apply_palette(palette: String) -> void:
	palette_name = palette if MHGame.PALETTES.has(palette) else "day"
	var values: Dictionary = MHGame.PALETTES[palette_name]
	_palette_values = values
	world_environment.environment = MHGame.build_environment(values)
	_sky_material = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	MHGame.configure_sun(sun, values)
	MHGame.set_window_glow(float(values.window))
func apply_daylight(sunlight: float) -> void:
	# Keep the art-direction palette, but let the simulated sun visibly set. A
	# small ambient floor preserves safe readability on low-end school devices.
	if _palette_values.is_empty() or sun == null or world_environment == null:
		return
	var level := clampf(sunlight, 0.0, 1.0)
	_apply_martian_sun_direction(level)
	sun.light_energy = float(_palette_values.get("sun_energy", 0.8)) * lerpf(0.025, 1.0, level)
	world_environment.environment.ambient_light_energy = float(_palette_values.get("ambient_energy", 0.35)) * lerpf(0.018, 1.0, level)
	if _sky_material != null:
		# Mars has a thin atmosphere, but midnight is still a true, dark sky—not
		# the washed-out daytime procedural sky from the initial implementation.
		_sky_material.sky_top_color = (Color("#080B16") as Color).lerp(_palette_values.get("sky_top", Color("#A06C49")) as Color, level)
		_sky_material.sky_horizon_color = (Color("#17121A") as Color).lerp(_palette_values.get("sky_horizon", Color("#E6B98F")) as Color, level)
		_sky_material.ground_horizon_color = (Color("#0D0A0C") as Color).lerp((_palette_values.get("sky_horizon", Color("#E6B98F")) as Color).darkened(.12), level)
		_sky_material.ground_bottom_color = (Color("#070609") as Color).lerp(_palette_values.get("ground", Color("#996142")) as Color, level)
		world_environment.environment.fog_light_color = (Color("#100D16") as Color).lerp(_palette_values.get("fog", Color("#D5A07A")) as Color, level)
		world_environment.environment.fog_density = lerpf(.0008, float(_palette_values.get("fog_density", .0024)), level)
	# When the base grid is online its window strips are deliberately brighter at
	# night, providing a clear warm navigational cue without lifting the sky.
	MHGame.set_window_glow(float(_palette_values.get("window", .9)) * lerpf(1.75, .9, level))
	_update_celestial_bodies(level)

func _apply_martian_sun_direction(sunlight: float) -> void:
	# The directional light is the actual solar source: it rises in the east,
	# crosses the southern sky at noon, sets in the west, changes the direction
	# of every shadow, and drops below the horizon at night. A reduced 55° noon
	# altitude is a clear Mars-like teaching approximation rather than a marker.
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var daylight_progress := clampf((MHGame.sol_hour - sunrise) / maxf(.1, sunset - sunrise), 0.0, 1.0)
	var altitude := sin(daylight_progress * PI) * deg_to_rad(55.0)
	if sunlight <= .015:
		altitude = -deg_to_rad(18.0)
	var horizontal := cos(altitude)
	# World -Z is the compass north. This produces E → S → W across the sky.
	var toward_sun := Vector3(cos(daylight_progress * PI) * horizontal, sin(altitude), sin(daylight_progress * PI) * horizontal)
	sun.basis = MHGame.sun_basis({"sun": toward_sun})
	var noon_colour: Color = _palette_values.get("sun_colour", Color.WHITE)
	sun.light_color = Color("#FFAC7B").lerp(noon_colour, clampf(sunlight * 1.3, 0.0, 1.0))

func _update_celestial_bodies(sunlight: float) -> void:
	if not _show_celestials or _phobos == null:
		return
	# The solar direction is owned by the DirectionalLight3D above. These are the
	# two actual Martian moons, shown only in low-light conditions.
	var hour := MHGame.sol_hour
	# Actual orbital periods: Phobos 7 h 39 m, Deimos ~30 h 18 m. Phobos moves
	# west-to-east as seen from Mars; Deimos follows the slower opposite drift.
	var phobos_angle := -PI * .45 + TAU * hour / 7.653
	var deimos_angle := PI * .22 - TAU * hour / 30.30
	_place_celestial(_phobos, sin(phobos_angle) * PI * .48, phobos_angle * .35, 680.0)
	_place_celestial(_deimos, sin(deimos_angle) * PI * .40, deimos_angle * .22 + .65, 720.0)
	_phobos.visible = sunlight < .18 and _phobos.position.y > 4.0
	_deimos.visible = sunlight < .18 and _deimos.position.y > 4.0

func _place_celestial(body: MeshInstance3D, altitude: float, azimuth: float, radius: float) -> void:
	if body == null:
		return
	var horizontal := cos(altitude)
	body.position = Vector3(sin(azimuth) * horizontal, sin(altitude), -cos(azimuth) * horizontal) * radius
	var active_camera := get_viewport().get_camera_3d()
	if active_camera != null:
		body.look_at(active_camera.global_position, Vector3.UP, true)

func _build_terrain() -> void:
	_terrain_body = StaticBody3D.new()
	_terrain_body.name = "OriginalWalkableTerrain"
	# Build equipment samples only this collider when it needs a ground height.
	# Keeping it identifiable prevents a newly placed object from ever becoming
	# the "ground" for the next one.
	_terrain_body.add_to_group("mars_terrain")
	_terrain_body.collision_layer = 1
	_terrain_body.collision_mask = 0
	add_child(_terrain_body)
	if str(MHGame.site().get("terrain_profile", "elysium")) == "utopia":
		_build_utopia_terrain()
		return
	var terrain_instance := TERRAIN_SCENE.instantiate()
	terrain_instance.name = "OriginalTerrainModel"
	_terrain_body.add_child(terrain_instance)
	_add_mesh_colliders(terrain_instance, Transform3D.IDENTITY)

func _utopia_height(x: float, z: float) -> float:
	# A very broad, low basin: the surveyed centre is deliberately level, with
	# gentle outer rises that define a map without compromising construction.
	var distance_from_centre := maxf(absf(x), absf(z))
	var outer := clampf((distance_from_centre - 72.0) / 76.0, 0.0, 1.0)
	var basin_edge := pow(outer, 1.6) * 10.0
	var subtle_roll := sin(x * .055) * cos(z * .045) * outer * 1.4
	return basin_edge + subtle_roll

func _build_utopia_terrain() -> void:
	# Dedicated playable map for Utopia Basin South. This replaces the shared
	# imported terrain with a large, shallow lowland bowl and a 144 m surveyed
	# centre, so both the visible terrain and collision are site-specific.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution := 72
	var radius := 148.0
	var step := radius * 2.0 / float(resolution)
	var colour := Color("#8E6C5B")
	for z_index in range(resolution):
		var z0 := -radius + float(z_index) * step
		var z1 := z0 + step
		for x_index in range(resolution):
			var x0 := -radius + float(x_index) * step
			var x1 := x0 + step
			var p00: Vector3 = Vector3(x0, _utopia_height(x0, z0), z0)
			var p10: Vector3 = Vector3(x1, _utopia_height(x1, z0), z0)
			var p01: Vector3 = Vector3(x0, _utopia_height(x0, z1), z1)
			var p11: Vector3 = Vector3(x1, _utopia_height(x1, z1), z1)
			for point in [p00, p10, p11, p00, p11, p01]:
				surface.set_color(colour)
				surface.add_vertex(point)
	surface.generate_normals()
	var terrain_mesh: ArrayMesh = surface.commit()
	var terrain_visual := MeshInstance3D.new()
	terrain_visual.name = "UtopiaBasinTerrain"
	terrain_visual.mesh = terrain_mesh
	terrain_visual.material_override = _landscape_material(colour)
	terrain_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_body.add_child(terrain_visual)
	var collision := CollisionShape3D.new()
	collision.name = "UtopiaBasinTerrain_collision"
	collision.shape = terrain_mesh.create_trimesh_shape()
	_terrain_body.add_child(collision)

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
	# Utopia supplies its own large basin terrain out to the safety boundary.
	if str(MHGame.site().get("terrain_profile", "elysium")) == "utopia":
		return
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
