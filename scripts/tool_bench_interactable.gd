class_name MHToolBenchInteractable
extends MHEquipmentInteractable

## A native, fully enclosed repair bench. The delivered GLB was useful as a
## design reference, but its detached drawer fronts did not hold up in-game.

var _drawers: Array[Node3D] = []
var _drawer_open := [false, false, false]

func _ready() -> void:
	display_name = "Tool Bench"
	primary_action = "Open left drawer"
	secondary_action = "Open centre drawer"
	_build_bench()
	super._ready()

func interaction_prompt() -> Dictionary:
	return {
		"primary": "Close left drawer" if _drawer_open[0] else "Open left drawer",
		"secondary": "Close centre drawer" if _drawer_open[1] else "Open centre drawer",
		"tertiary": "Close right drawer" if _drawer_open[2] else "Open right drawer",
		"label": display_name,
	}

func interact(_actor: Node = null) -> bool:
	_toggle_drawer(0)
	return true

func interact_secondary(_actor: Node = null) -> bool:
	_toggle_drawer(1)
	return true

func interact_tertiary(_actor: Node = null) -> bool:
	_toggle_drawer(2)
	return true

func _toggle_drawer(index: int) -> void:
	_drawer_open[index] = not _drawer_open[index]
	var drawer := _drawers[index]
	var target := Vector3((index - 1) * .53, .48, -.30 if _drawer_open[index] else -.02)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(drawer, "position", target, .24)

func _build_bench() -> void:
	var cream := Color("#D8D1B9")
	var graphite := Color("#20262A")
	var amber := Color("#E8782B")
	var steel := Color("#52616A")
	_box("Worktop", Vector3(1.76, .11, .78), Vector3(0, 1.04, 0), cream, .2)
	# Four legs and a dark lower frame make it read as a sturdy bench, not a
	# floating countertop with decorative fronts.
	for x in [-.76, .76]:
		for z in [-.30, .30]: _box("Leg", Vector3(.08, 1.02, .08), Vector3(x, .51, z), graphite, .55)
	_box("LowerFrame", Vector3(1.58, .10, .62), Vector3(0, .19, .02), graphite, .6)
	var backboard := _box("Pegboard", Vector3(1.58, .74, .055), Vector3(0, 1.46, .31), graphite, .72)
	for x in [-.58, -.29, 0.0, .29, .58]:
		_box("ToolRail", Vector3(.035, .38, .035), Vector3(x, 1.43, .265), steel, .45)
	_box("ViceBase", Vector3(.31, .09, .24), Vector3(-.48, 1.14, -.10), graphite, .5)
	_box("ViceJaw", Vector3(.08, .15, .20), Vector3(-.48, 1.24, -.18), steel, .42)
	for index in 3:
		var drawer := Node3D.new()
		drawer.name = "Drawer%d" % (index + 1)
		drawer.position = Vector3((index - 1) * .53, .48, -.02)
		add_child(drawer)
		_drawers.append(drawer)
		_drawer_box(drawer, amber)

func _drawer_box(drawer: Node3D, colour: Color) -> void:
	# An actual tray with bottom, sides and back—not a textureless face panel.
	for data in [
		[Vector3(.47, .045, .48), Vector3(0, -.15, .17)],
		[Vector3(.045, .25, .48), Vector3(-.235, -.02, .17)],
		[Vector3(.045, .25, .48), Vector3(.235, -.02, .17)],
		[Vector3(.47, .25, .045), Vector3(0, -.02, .39)],
		[Vector3(.49, .28, .045), Vector3(0, -.02, -.08)]
	]: _box("DrawerPart", data[0], data[1], colour, .35, drawer)
	_box("DrawerHandle", Vector3(.20, .035, .055), Vector3(0, -.02, -.115), Color("#1C2226"), .45, drawer)

func _box(node_name: String, size: Vector3, local_position: Vector3, colour: Color, roughness: float, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = .35 if roughness < .5 else .12
	material.roughness = roughness
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = local_position
	parent.add_child(visual)
	return visual
