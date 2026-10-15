class_name HabitatPiece
extends StaticBody3D

var part_id := ""
var definition: Dictionary
var preview := false
var connector_used: Array[bool] = []

func setup(id: String, data: Dictionary, is_preview := false) -> void:
	part_id = id; definition = data; preview = is_preview; name = "Habitat_" + id
	var scene: PackedScene = load("res://assets/habitat_modules/" + str(data.model))
	var visual := scene.instantiate(); add_child(visual)
	if preview: _tint(visual, Color(0.12, 1.0, 0.35, 0.42))
	else: _collision()
	for c in data.connectors: connector_used.append(false)
	if not preview: _make_connector_markers()

func _tint(node: Node, colour: Color) -> void:
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new(); m.albedo_color=colour; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		(node as MeshInstance3D).material_override=m
	for child in node.get_children(): _tint(child, colour)

func _collision() -> void:
	var s: Array = definition.size
	var width := float(s[0]); var length := float(s[2]); var h := 2.9
	_box(Vector3(0,.125,0), Vector3(width,.25,length))
	_box(Vector3(0,h,0), Vector3(width,.18,length))
	# Each wall is split around a standard 2.2 m × 2.35 m doorway where a socket exists.
	for side in [Vector3(0,0,-1),Vector3(0,0,1),Vector3(-1,0,0),Vector3(1,0,0)]:
		var open := _has_opening(side)
		if absf(side.z)>0:
			var z: float = side.z*length*.5
			if open:
				_box(Vector3(-width*.38,1.17,z),Vector3(width*.24,2.35,.16)); _box(Vector3(width*.38,1.17,z),Vector3(width*.24,2.35,.16)); _box(Vector3(0,2.64,z),Vector3(width,.34,.16))
			else: _box(Vector3(0,1.45,z),Vector3(width,2.9,.16))
		else:
			var x: float = side.x*width*.5
			if open:
				_box(Vector3(x,1.17,-length*.38),Vector3(.16,2.35,length*.24)); _box(Vector3(x,1.17,length*.38),Vector3(.16,2.35,length*.24)); _box(Vector3(x,2.64,0),Vector3(.16,.34,length))
			else: _box(Vector3(x,1.45,0),Vector3(.16,2.9,length))

func _box(position: Vector3, size: Vector3) -> void:
	var c := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size=size; c.shape=b; c.position=position; add_child(c)

func _has_opening(side: Vector3) -> bool:
	for c in definition.connectors:
		if Vector3(c[3],c[4],c[5]).is_equal_approx(side): return true
	return part_id == "airlock" and side == Vector3(0,0,-1)

func expanded_contains(world_point: Vector3, radius := .65) -> bool:
	var local := global_transform.affine_inverse()*world_point; var s: Array=definition.size
	return absf(local.x)<float(s[0])*.5+radius and absf(local.z)<float(s[2])*.5+radius and local.y>-radius and local.y<3.1+radius

func overlaps_piece(other, margin := .08) -> bool:
	var a: Array=definition.size; var b: Array=other.definition.size
	# Pieces only rotate in right angles, so this conservative footprint check is reliable.
	return absf(global_position.x-other.global_position.x)<(float(a[0])+float(b[0]))*.5-margin and absf(global_position.z-other.global_position.z)<(float(a[2])+float(b[2]))*.5-margin and absf(global_position.y-other.global_position.y)<3.0

func connector(index: int) -> Dictionary:
	var c: Array = definition.connectors[index]
	return {"position": global_transform * Vector3(c[0],c[1],c[2]), "direction": global_transform.basis * Vector3(c[3],c[4],c[5])}

func _make_connector_markers() -> void:
	for index in definition.connectors.size():
		var c: Array = definition.connectors[index]
		var marker := MeshInstance3D.new()
		marker.name = "ConnectorMarker_%d" % index
		var mesh := BoxMesh.new()
		# A lintel marker reads clearly from the isometric view and is centred on
		# the physical doorway, rather than appearing beside the module at floor level.
		mesh.size = Vector3(2.2, .14, .22) if absf(float(c[5])) > .5 else Vector3(.22, .14, 2.2)
		marker.mesh = mesh
		var direction := Vector3(c[3], c[4], c[5])
		marker.position = Vector3(c[0], 2.38, c[2]) + direction * .10
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(.12, 1.0, .38, .85)
		material.emission_enabled = true
		material.emission = Color(.08, .8, .25)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		marker.visible = false
		add_child(marker)

func set_connectors_visible(show: bool) -> void:
	for index in connector_used.size():
		var marker := get_node_or_null("ConnectorMarker_%d" % index) as MeshInstance3D
		if marker == null: continue
		marker.visible = show
		var material := marker.material_override as StandardMaterial3D
		if material != null:
			var colour := Color(.12, 1.0, .38, .85) if not connector_used[index] else Color(.28, .30, .30, .45)
			material.albedo_color = colour
			material.emission = colour
