class_name RoomAssignmentLabel
extends StaticBody3D

# A small, physical room-sign interaction point.  The picker itself stays in
# the player's HUD; this object only answers the usual reticle interaction.
var _builder: BuildController
var _zone_index := -1
var _room_name := "Unassigned Habitat"

func setup(builder: BuildController, zone_index: int, room_name: String) -> void:
	_builder = builder
	_zone_index = zone_index
	_room_name = room_name
	name = "RoomAssignmentLabel"
	collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, .62, .12)
	collision.shape = shape
	collision.position.y = .18
	add_child(collision)
	var label := Label3D.new()
	label.text = _room_name.to_upper()
	label.font = MHStyle.font(700, false, 1)
	label.font_size = 34
	label.outline_size = 7
	label.outline_modulate = Color(MHStyle.INK_950, .86)
	label.modulate = MHStyle.INK_100
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = .010
	label.position.y = .18
	add_child(label)

func interaction_prompt() -> Dictionary:
	return {"primary": "Assign room", "label": _room_name}

func interact(_actor: Node = null) -> bool:
	if _builder == null or not is_instance_valid(_builder):
		return false
	_builder.open_room_assignment(_zone_index)
	return true
