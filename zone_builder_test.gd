extends SceneTree

# Run with: godot --headless --path . --script res://tests/zone_builder_test.gd
func _init() -> void:
	var builder := BuildController.new()
	builder.kind = "living"
	var room := [Vector2i(8,8), Vector2i(8,9), Vector2i(9,8), Vector2i(9,9)]
	assert(builder._valid(room), "A clear room footprint should be valid.")
	assert(builder._cells(Vector2i(0,0),Vector2i(0,0)) == [Vector2i(0,0)], "One click must create one cell.")
	assert(builder._cells(Vector2i(0,0),Vector2i(2,2)).size() == 9, "A 3x3 drag must create nine cells.")
	builder.zones.append({"kind":"living","cells":room,"cost":200,"door_direction":Vector2i(0,-1)})
	assert(int(builder._systems().crew_capacity)==3, "A 2x2 Living Quarters should support three crew, not an unrealistic eight.")
	assert(not builder._valid([Vector2i(8,8)]), "Overlapping an existing room must be rejected.")
	builder.kind = "corridor"
	assert(builder._valid([Vector2i(7,8),Vector2i(6,8)]), "A corridor can extend from a room.")
	assert(builder._cells(Vector2i(0,0),Vector2i(1,1)).is_empty(), "Diagonal corridors are rejected.")
	builder.kind = "airlock"
	builder.airlock_direction = Vector2i(0,-1)
	assert(builder._valid([Vector2i(8,7)]), "Airlock requires a room behind its interior door.")
	var long_airlock := builder._cells(Vector2i(8,6),Vector2i(8,7))
	assert(long_airlock.size()==2 and builder._valid(long_airlock), "A straight two-cell airlock chamber should connect at its inner end.")
	assert(not builder._valid([Vector2i(-10,-10)]), "Free-standing airlocks are rejected.")
	builder.zones.append({"kind":"airlock","cells":[Vector2i(8,7)],"cost":50,"door_direction":Vector2i(0,-1)})
	builder.kind = "vehicle_bay"
	builder.airlock_direction = Vector2i(-1,0)
	var bay := [Vector2i(6,8),Vector2i(6,9),Vector2i(7,8),Vector2i(7,9)]
	assert(builder._valid(bay), "A 2x2 vehicle bay should be valid when its hangar face is outside and it joins a room.")
	builder.airlock_direction = Vector2i(1,0)
	assert(not builder._valid(bay), "A vehicle bay hangar face cannot point into an existing room.")
	builder.kind = "solar"
	builder.airlock_direction = Vector2i(0,-1)
	assert(builder._valid([Vector2i(8,12)]), "Solar arrays can connect within the 12m cable range.")
	assert(not builder._valid([Vector2i(8,14)]), "Solar arrays outside the cable range are rejected.")
	builder.zones.append({"kind":"solar","cells":[Vector2i(8,12)],"cost":50,"door_direction":Vector2i(0,-1)})
	var systems := builder._systems()
	assert(int(systems.generation)==BuildController.SOLAR_OUTPUT, "A sun-facing solar array should produce full power.")
	var route := builder._airlock_connected_cells()
	assert(route.has(Vector2i(8,8)), "A room beside an airlock must be reachable.")
	assert(not route.has(Vector2i(0,0)), "A disconnected room position must not be reachable.")
	print("Zone builder test passed: floorplan cells, overlap checks, corridors, airlocks, and routes.")
	builder.free()
	quit(0)
