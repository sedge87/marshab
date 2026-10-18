extends SceneTree

# Run with: godot --headless --path . --script res://tests/airlock_interlock_test.gd
# An environmental hatch must seal every inner pressure door before it opens.
func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var outer := AirlockDoor.new()
	world.add_child(outer)
	outer.setup("OUTER", true)
	var interior := AirlockDoor.new()
	interior.position = Vector3(4, 0, 0)
	world.add_child(interior)
	interior.setup("INTERIOR", true)
	interior.toggle()
	await create_timer(.45).timeout
	assert(not interior.is_closed(), "The test setup must first open the interior door.")
	outer.toggle()
	await create_timer(.65).timeout
	assert(interior.is_closed(), "Opening to Mars must close every interior door.")
	assert(not outer.is_closed(), "The outer hatch should open once inner doors are sealed.")
	print("Airlock interlock test passed: outer hatch seals all inner doors.")
	quit(0)
