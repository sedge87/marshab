extends SceneTree

# House materials (scripts/mh_palette.gd, docs/house-style.md): material roles
# map onto one shared set, natural/signal materials are left alone, and every
# catalogue model loads with them.
# Run with: godot --headless --path . --script res://tests/house_style_test.gd
const THUMBS := preload("res://scripts/model_thumbnails.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _mat(name: String, colour: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = Color(colour)
	return m

func _initialize() -> void:
	var cases := {"Storage_graphite": "graphite", "graphite": "graphite", "satin_steel": "metal", "Brushed_Aluminium": "metal",
		"white_painted": "white", "Storage_ivory": "white", "ochre": "orange", "Science_orange": "orange", "Safety_Amber": "amber",
		"black_rubber": "rubber", "dark_glass": "glass", "teal_soft": "teal", "dark_alloy": "frame",
		"Science_ice": "keep", "Mars": "keep", "leaf_green": "keep", "book_red": "keep", "iv_clear": "keep", "plush_tan": "keep", "Science_rock_red": "keep"}
	for name in cases:
		_check(MHPalette.role_of(_mat(name, "#808890")) == cases[name], "%s is %s (got %s)" % [name, cases[name], MHPalette.role_of(_mat(name, "#808890"))])
	# Pale "graphite" (a whole bunk frame) becomes the frame grey, not near-black.
	var pale := MHPalette.material(_mat("graphite", "#CED9DC"))
	_check(pale.albedo_color.is_equal_approx(MHPalette.ROLES.frame[0]), "pale graphite maps to the frame grey")
	var dark := MHPalette.material(_mat("graphite", "#6F797E"))
	_check(dark.albedo_color.is_equal_approx(MHPalette.ROLES.graphite[0]), "dark graphite maps to graphite")
	# Same source -> the same shared material; a house material isn't re-mapped.
	var source := _mat("orange", "#EFAF73")
	_check(MHPalette.material(source) == MHPalette.material(source), "materials are shared")
	_check(MHPalette.material(MHPalette.material(source)) == MHPalette.material(source), "house materials are left as they are")
	_check(MHPalette.material(source).cull_mode == BaseMaterial3D.CULL_DISABLED, "house materials are two-sided")
	# Every catalogue model: each named-role surface carries its house colour.
	var models := 0
	for id in EquipmentCatalog.entries():
		var model := THUMBS.instantiate_model(id)
		if model == null: continue
		models += 1
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null: continue
			for s in mesh.mesh.get_surface_count():
				var m := mesh.get_active_material(s) as StandardMaterial3D
				if m == null: continue
				_check(MHPalette._made.has(m.get_instance_id()), "%s %s uses a house material" % [id, mesh.name])
		model.free()
	_check(models >= 100, "every catalogue model loads (%d)" % models)
	if failures == 0:
		print("House style test passed: roles, keep-list, shared two-sided materials, %d models." % models)
	quit(1 if failures > 0 else 0)
