extends SceneTree

# Purpose-first rooms place immediately.  Neighbouring rooms remain sealed
# until the player explicitly installs a door at their shared wall.
func _init() -> void:
	var builder := BuildController.new()
	builder.zones = [
		{"kind":"living","cells":[Vector2i(0,0)],"cost":50,"door_direction":Vector2i(0,-1)},
		{"kind":"hydroponics","cells":[Vector2i(1,0)],"cost":50,"door_direction":Vector2i(0,-1)}
	]
	var doorway := {"cell":Vector2i(0,0),"side":Vector2i(1,0)}
	assert(builder._room_door_invalid_reason(doorway).is_empty(), "A door should be valid on a shared wall between two rooms.")
	assert(builder._should_build_wall(Vector2i(0,0),Vector2i(1,0)), "Adjoining rooms must keep their wall until a door is installed.")
	builder.interior_doors.append(doorway)
	assert(not builder._should_build_wall(Vector2i(0,0),Vector2i(1,0)), "The explicit door should open only its selected shared wall.")
	assert(not builder._room_door_invalid_reason({"cell":Vector2i(0,0),"side":Vector2i(0,-1)}).is_empty(), "Exterior walls cannot receive an interior door.")
	builder.interior_doors.clear()
	builder.zones = [{"kind":"living","cells":[Vector2i(0,0)],"cost":50,"door_direction":Vector2i(0,-1)}]
	builder._begin_connection_guidance(builder.zones[0], true)
	assert(builder.guided_airlock_cells.size() == 4, "The first room should guide the player to one of its four exterior airlock edges.")
	builder.zones.append({"kind":"storage","cells":[Vector2i(1,0)],"cost":50,"door_direction":Vector2i(0,-1)})
	builder._begin_connection_guidance(builder.zones[1], false)
	assert(builder.guided_connection_edges.size() == 1, "An adjoining new room should guide one explicit internal connection.")
	print("Room doorway test passed: sealed joins and explicit interior doors.")
	quit(0)
