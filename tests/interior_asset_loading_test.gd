extends SceneTree

# Every interior item in the catalogue loads its art through BuildController
# (the same path furnishing uses): the scene resolves, the visual holds the
# model rather than a fallback proxy, and it can be bumped into.
# (Rewritten 21 Oct: it used to list 30 ids, several since retired.)
# Run with: godot --headless --path . --script res://tests/interior_asset_loading_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	var count := 0
	for id in EquipmentCatalog.entries():
		var entry := EquipmentCatalog.get_entry(id)
		if (entry.get("valid_zones", []) as Array).is_empty(): continue   # surface gear has its own builder
		count += 1
		var path := str(entry.get("asset_scene", ""))
		_check(not path.is_empty() and ResourceLoader.exists(path), "%s resolves its art: %s" % [id, path])
		var visual := builder.free_interior_visual(id, Vector3(count * 4.0, 0, 0), 0.0)
		world.add_child(visual)
		_check(visual.find_child("Model", true, false) != null, "%s shows its model, not a fallback" % id)
		# Walk-through items and thin strips (15 cm or less) have no collision by design.
		var walkthrough := bool(entry.get("walkthrough", false)) or builder._free_interior_size(entry).y <= .15
		_check(walkthrough or not visual.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s has collision" % id)
		visual.queue_free()
	if failures == 0:
		print("Interior art loading test passed: %d items load their models with collision." % count)
	quit(1 if failures > 0 else 0)
