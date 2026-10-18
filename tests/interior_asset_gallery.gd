extends SceneTree

# Produces Godot-rendered visual inspection images for the interior first batch.
const ASSETS := {
	"crew_bunk": "res://assets/equipment/crew_bunk.glb",
	"grow_tray": "res://assets/equipment/grow_tray.glb",
	"air_recycler": "res://assets/equipment/air_recycler.glb",
	"water_reclaimer": "res://assets/equipment/water_reclaimer.glb",
	"oxygen_reserve_tank": "res://assets/equipment/oxygen_reserve_tank.glb",
	"thermal_control_unit": "res://assets/equipment/thermal_control_unit.glb",
	"life_support_console": "res://assets/equipment/life_support_console.glb",
	"science_workbench": "res://assets/equipment/science_workbench.glb",
	"sample_analysis_station": "res://assets/equipment/sample_analysis_station.glb",
	"microscope_station": "res://assets/equipment/microscope_station.glb",
	"planetary_data_console": "res://assets/equipment/planetary_data_console.glb",
	"sample_storage_cabinet": "res://assets/equipment/sample_storage_cabinet.glb",
	"cargo_rack": "res://assets/equipment/cargo_rack.glb",
	"partition_solid_3m": "res://assets/interior_kit/partition_solid_3m.glb",
	"interior_window": "res://assets/interior_kit/interior_window.glb",
	"interior_sliding_door": "res://assets/interior_kit/interior_sliding_door.glb",
}

func _initialize() -> void:
	root.size = Vector2i(960, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#17232A")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#B7CAD4")
	environment.environment.ambient_light_energy = .7
	scene.add_child(environment)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new(); floor_mesh.size = Vector2(12, 12); floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new(); floor_material.albedo_color = Color("#313B3E"); floor_material.roughness = .86; floor.material_override = floor_material
	scene.add_child(floor)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-48, -32, 0); key.light_energy = 2.0; key.shadow_enabled = true; scene.add_child(key)
	var fill := OmniLight3D.new(); fill.position = Vector3(-2.5, 3.5, 2.0); fill.light_color = Color("#A7D7E5"); fill.light_energy = 8.0; fill.omni_range = 10; scene.add_child(fill)
	var camera := Camera3D.new(); camera.position = Vector3(4.4, 3.0, 5.4); camera.look_at(Vector3(0, 1.0, 0)); camera.current = true; scene.add_child(camera)
	var out_dir := ProjectSettings.globalize_path("res://artifacts/interior_previews")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for id in ASSETS:
		var resource := load(str(ASSETS[id])) as PackedScene
		assert(resource != null, "%s did not import as PackedScene" % id)
		var model := resource.instantiate() as Node3D
		assert(model != null, "%s could not instantiate" % id)
		scene.add_child(model)
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var output := out_dir.path_join("%s.png" % id)
		assert(image.save_png(output) == OK, "Could not write preview for %s" % id)
		model.queue_free()
		await process_frame
	print("Interior asset gallery generated at %s" % out_dir)
	quit(0)
