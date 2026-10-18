extends SceneTree

# Runtime loading contract for the grounded first batch.  It deliberately
# exercises BuildController rather than directly instantiating GLBs, so a
# catalogue path, placement offset or fallback regression is caught here.
const MODELLED_IDS := ["crew_bunk", "locker", "common_table", "task_light", "privacy_divider", "exercise_station", "grow_tray", "seedling_station", "nutrient_mixer", "harvest_cart", "hydroponics_sensor_panel", "air_recycler", "science_workbench", "cargo_rack"]

func _initialize() -> void:
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	for index in MODELLED_IDS.size():
		var id: String = MODELLED_IDS[index]
		var entry := EquipmentCatalog.get_entry(id)
		var path := str(entry.get("asset_scene", ""))
		assert(ResourceLoader.exists(path), "%s must resolve its catalogue asset_scene: %s" % [id, path])
		var visual := builder._equipment_visual(id, Vector2i(index, 0), Vector2i(0, -1))
		world.add_child(visual)
		assert(visual.get_node_or_null("Model") != null, "%s must use GLB art, not its fallback proxy." % id)
		assert(not visual.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s must retain catalogue collision." % id)
		if int(EquipmentCatalog.effects(id).get("power_draw", 0)) > 0:
			assert(not visual.get_tree().get_nodes_in_group("grid_powered_light").is_empty(), "%s must retain a grid-powered indicator." % id)
		visual.queue_free()
	# An unbuilt catalogue asset must still display safely through the explicit proxy.
	var fallback := builder._equipment_visual("greenhouse_planter", Vector2i(9, 0), Vector2i(0, -1))
	world.add_child(fallback)
	assert(fallback.get_node_or_null("Model") == null, "Unavailable art must use fallback, not a broken model node.")
	assert(not fallback.find_children("*", "MeshInstance3D", true, false).is_empty(), "Fallback must retain its presentation proxy.")
	print("Interior art loading test passed: %d GLBs, collision, grid indicators and fallback." % MODELLED_IDS.size())
	quit(0)
