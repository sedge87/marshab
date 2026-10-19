class_name MHSparesCabinetInteractable
extends MHEquipmentInteractable

## The supplied cabinet had eighteen drawer fronts merged into one unanimated
## triangle mesh. Replace only that assembly with individual physical drawers.

func _ready() -> void:
	display_name = "Spares Cabinet"
	primary_action = "Inspect drawers"
	for name in ["Parts_Organisers__cream", "Tray_Handles__alloy", "Parts_Labels__amber", "Parts_Labels__mint"]:
		var source := find_child(name, true, false) as Node3D
		if source != null: source.visible = false
	_build_drawers()
	super._ready()

func _build_drawers() -> void:
	for row in 6:
		for column in 3:
			var drawer := MHSparesDrawer.new()
			drawer.name = "SparesDrawer_%d_%d" % [row + 1, column + 1]
			drawer.drawer_number = row * 3 + column + 1
			drawer.position = Vector3((column - 1) * .36, .40 + row * .225, -.43)
			add_child(drawer)

class MHSparesDrawer extends Node3D:
	var drawer_number := 0
	var _open := false
	var _home := Vector3.ZERO

	func _ready() -> void:
		_home = position
		_build_visual()
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.set_meta("interaction_target", self)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(.31, .17, .34)
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

	func interaction_prompt() -> Dictionary:
		return {"primary": "Close drawer %02d" % drawer_number if _open else "Open drawer %02d" % drawer_number, "label": "Spares Cabinet"}

	func interact(_actor: Node = null) -> bool:
		_open = not _open
		var target := _home + Vector3(0, 0, -.30 if _open else 0)
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(self, "position", target, .18)
		return true

	func _build_visual() -> void:
		var cream := Color("#D7D0BA")
		var graphite := Color("#262D31")
		_box("Tray", Vector3(.31, .17, .31), Vector3(0, 0, .08), cream)
		_box("Face", Vector3(.33, .18, .035), Vector3(0, 0, -.105), graphite)
		_box("Handle", Vector3(.15, .025, .045), Vector3(0, -.015, -.135), cream)
		var indicator := Color("#83E3C1") if drawer_number % 4 else Color("#E8782B")
		_box("Status", Vector3(.035, .035, .045), Vector3(.11, .035, -.135), indicator)

	func _box(node_name: String, size: Vector3, local_position: Vector3, colour: Color) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.metallic = .22
		material.roughness = .46
		mesh.material = material
		var visual := MeshInstance3D.new()
		visual.name = node_name
		visual.mesh = mesh
		visual.position = local_position
		add_child(visual)
