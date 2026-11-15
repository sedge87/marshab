@tool
extends Path3D

## Rocks laid along a line (B5 step 7, docs/terrain-design.md §13): draw a
## Path3D along a scarp's foot, a moraine or a riverbed's caprock, press
## Regenerate in the Inspector, and rocks are scattered along it: snapped to
## the ground, tilted part of the way to its slope, big ones solid, small ones
## drawn together in one MultiMesh. The material is MHPalette's ground_rock.
##
## A path names an anchor (region.json "anchors", MHRegion): its curve is
## relative to that point, so when the land editor moves the landform, the
## rocks follow. scenes/terrain/rock_paths.tscn holds the region's paths; the
## environment loads it with the region and each path re-anchors and builds
## its rocks on the game's own ground (MHSiteTerrain.height).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const RegionTerrain := preload("res://scripts/region_terrain.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL_DIRECTORY := "res://assets/original_mars/models/"

@export var anchor := ""                     ## the region anchor the curve is drawn from
@export var region_id := "test_region"       ## for the editor, where there's no site
@export var rock_models: PackedStringArray = ["decor_rock_00", "decor_rock_01", "decor_rock_02", "decor_rock_03", "decor_rock_04", "decor_rock_05", "decor_rock_06", "decor_rock_07"]
@export var spacing := 3.0                   ## metres between rocks along the path
@export var scale_range := Vector2(.5, 1.6)
@export var spread := 3.0                    ## metres either side of the line
@export_range(0.0, 1.0) var tilt := .5       ## how far a rock leans to the ground's slope
@export var solid_above := 1.25              ## rocks bigger than this get collision
@export var sink := .12                      ## how far a rock sits into the ground, for its size
@export var rng_seed := 1
@export_tool_button("Regenerate") var regenerate_button := regenerate

var _meshes: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint(): return
	place_at_anchor()
	regenerate()

## Where the anchor is now, in this world: site metres in the game (the
## region's zone centre taken off), region metres in the editor.
func place_at_anchor() -> void:
	if anchor.is_empty() or not MHRegion.has_anchor(anchor): return
	var p := MHRegion.anchor_position(anchor)
	var zone := MHSiteTerrain.region_zone()
	if not zone.is_empty():
		p -= Vector2(float(zone.centre[0]), float(zone.centre[1]))
	global_position = Vector3(p.x, 0.0, p.y)

func _ground(x: float, z: float) -> float:
	if not MHSiteTerrain.region_zone().is_empty(): return MHSiteTerrain.height(x, z)
	if RegionTerrain.meta().is_empty(): RegionTerrain.use(region_id)
	return RegionTerrain.height(x, z)

func _mesh(model: String) -> Mesh:
	if _meshes.has(model): return _meshes[model]
	var mesh: Mesh = null
	var path := MODEL_DIRECTORY + model + ".glb"
	if ResourceLoader.exists(path):
		var root: Node = (load(path) as PackedScene).instantiate()
		for node in root.find_children("*", "MeshInstance3D", true, false):
			mesh = (node as MeshInstance3D).mesh
			break
		root.free()
	_meshes[model] = mesh
	return mesh

func regenerate() -> void:
	var old := get_node_or_null("Rocks")
	if old != null:
		remove_child(old)
		old.free()
	if curve == null or curve.get_baked_length() < spacing or rock_models.is_empty(): return
	var holder := Node3D.new()
	holder.name = "Rocks"
	add_child(holder)
	holder.global_transform = Transform3D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var material := MHPalette.ground_rock_material()
	var small: Dictionary = {}   # model -> Array[Transform3D]
	var length := curve.get_baked_length()
	var along := rng.randf_range(0.0, spacing)
	# Nothing on a base's pad (the site's origin) if one was founded near here.
	var zone := MHSiteTerrain.region_zone()
	var keep_clear := MHBaseSite.pad_reach(zone) + 12.0 if not zone.is_empty() else 0.0
	while along < length:
		var local := curve.sample_baked(along)
		var ahead := curve.sample_baked(minf(along + 1.0, length)) - local
		var side := Vector3(-ahead.z, 0.0, ahead.x).normalized() if ahead.length() > .01 else Vector3.RIGHT
		var p := to_global(local) + side * rng.randf_range(-spread, spread)
		var size := lerpf(scale_range.x, scale_range.y, pow(rng.randf(), 1.6))
		if keep_clear > 0.0 and Vector2(p.x, p.z).length() < keep_clear:
			along += spacing
			continue
		var y := _ground(p.x, p.z)
		var n := Vector3(_ground(p.x - 1.0, p.z) - _ground(p.x + 1.0, p.z), 2.0, _ground(p.x, p.z - 1.0) - _ground(p.x, p.z + 1.0)).normalized()
		var up := Vector3.UP.lerp(n, tilt).normalized()
		var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var xform := Transform3D(basis.scaled(Vector3.ONE * size), Vector3(p.x, y - sink * size, p.z))
		var model := rock_models[rng.randi() % rock_models.size()]
		if size > solid_above:
			_add_solid(holder, model, xform, material)
		else:
			if not small.has(model): small[model] = []
			(small[model] as Array).append(xform)
		along += spacing * rng.randf_range(.6, 1.4)
	for model in small:
		var mesh := _mesh(model)
		if mesh == null: continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = (small[model] as Array).size()
		for k in mm.instance_count: mm.set_instance_transform(k, small[model][k])
		var draw := MultiMeshInstance3D.new()
		draw.name = "Small_" + model
		draw.multimesh = mm
		draw.material_override = material
		draw.visibility_range_end = 450.0
		holder.add_child(draw)

func _add_solid(holder: Node3D, model: String, xform: Transform3D, material: Material) -> void:
	var mesh := _mesh(model)
	if mesh == null: return
	var body := StaticBody3D.new()
	body.name = model
	holder.add_child(body)
	body.global_transform = xform
	var draw := MeshInstance3D.new()
	draw.mesh = mesh
	draw.material_override = material
	draw.visibility_range_end = 900.0
	body.add_child(draw)
	var shape := CollisionShape3D.new()
	var round := SphereShape3D.new()
	var box := mesh.get_aabb()
	round.radius = maxf(box.size.x, box.size.z) * .42
	shape.shape = round
	shape.position = box.get_center()
	body.add_child(shape)
