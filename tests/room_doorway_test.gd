extends SceneTree

# Purpose-first rooms remain the normal construction choice.  Their selected
# port is the only place an airlock can join, and later rooms must join an
# existing pressurised shell through a chosen boundary edge.
func _init() -> void:
	var builder := BuildController.new()
	builder.kind = "hydroponics"
	var hydro := {
		"kind": "hydroponics", "room_shell": true,
		"cells": [Vector2i(0, 0)], "door_cell": Vector2i(0, 0),
		"door_side": Vector2i(0, -1), "door_direction": Vector2i(0, -1), "cost": 50
	}
	builder.zones.append(hydro)
	builder.kind = "airlock"
	builder.airlock_direction = Vector2i(0, -1)
	assert(builder._valid_airlock([Vector2i(0, -1)]), "An airlock must be allowed at the room's chosen port.")
	builder.airlock_direction = Vector2i(1, 0)
	assert(not builder._valid_airlock([Vector2i(-1, 0)]), "An airlock must not cut through an unselected room wall.")
	var attached_room := [Vector2i(1, 0)]
	var doorway := {"cell": Vector2i(1, 0), "side": Vector2i(-1, 0)}
	assert(builder._room_doorway_invalid_reason(attached_room, doorway).is_empty(), "A later purpose-selected room should be able to join the existing shell.")
	assert(not builder._room_doorway_invalid_reason(attached_room, {"cell": Vector2i(1, 0), "side": Vector2i(1, 0)}).is_empty(), "A disconnected room doorway must be rejected.")
	print("Room doorway test passed: purpose-first rooms, selected ports and sealed joins.")
	quit(0)
