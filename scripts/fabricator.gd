extends Node3D

## The fabricator (docs/start-and-chapter-one.md §4): a bench-sized machine
## with a build chamber behind a window, a powder hopper and a small working
## display. E opens its screen (fabricator_screen.gd).
## The model is the HQ pass (asset_packs/mars_chapter_one_v1); the boxes
## below stand in only if it's missing.

const MODEL := "res://assets/equipment/mars_chapter_one_v1/models/fabricator.glb"

func _ready() -> void:
	if ResourceLoader.exists(MODEL):
		add_child((load(MODEL) as PackedScene).instantiate())
		return
	_box("Body", Vector3(1.4, .9, .8), Vector3(0, .45, 0), "shell")
	_box("Plinth", Vector3(1.44, .08, .84), Vector3(0, .04, 0), "graphite")
	_box("Chamber", Vector3(.86, .62, .62), Vector3(-.18, 1.21, 0), "shell")
	_box("Window", Vector3(.6, .44, .02), Vector3(-.18, 1.2, .315), "black_glass")
	_box("ChamberFrame", Vector3(.7, .54, .015), Vector3(-.18, 1.2, .305), "frame")
	_box("Hopper", Vector3(.34, .5, .4), Vector3(.48, 1.15, -.08), "metal")
	_box("HopperLid", Vector3(.38, .05, .44), Vector3(.48, 1.42, -.08), "orange")
	_box("Gasket", Vector3(1.42, .03, .82), Vector3(0, .9, 0), "rubber")
	_box("Drawer", Vector3(.9, .26, .02), Vector3(-.18, .5, .405), "graphite")
	var screen := _box("Screen", Vector3(.3, .2, .02), Vector3(.48, .72, .41), "screen")
	var glow := StandardMaterial3D.new()
	glow.resource_name = "screen_glow"
	glow.albedo_color = Color("#0C1316")
	glow.emission_enabled = true
	glow.emission = Color("#8CC3CB")
	glow.emission_energy_multiplier = .6
	screen.material_override = glow

func _box(node_name: String, size: Vector3, at: Vector3, role: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.resource_name = role
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
	return mesh

func interaction_prompt() -> Dictionary:
	var job := MHChapterOne.job
	return {"primary": "Open the fabricator", "label": "Fabricator" + ("" if job.is_empty() else " · making %s" % MHChapterOne.label(str(job.id)))}

func interact(_actor: Node = null) -> bool:
	get_tree().call_group("habitat_world", "open_fabricator")
	return true
