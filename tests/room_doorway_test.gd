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
	print("Room doorway test passed: sealed joins and explicit interior doors.")
	quit(0)
