extends SceneTree

# Run with: godot --headless --path . --script res://tests/airlock_interlock_test.gd
# Like a real airlock: an outer hatch only opens once its own inner door is
# sealed (opening it seals that door), and the rest of the base's doors carry
# on working while it's open. (Until 24 Oct an open outer hatch locked every
# interior door in the base, so auto doors seemed to stop at random.)
func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var outer := AirlockDoor.new()
	world.add_child(outer)
	outer.setup("OUTER", true)
	var inner := AirlockDoor.new()
	inner.position = Vector3(0, 0, 3)
	world.add_child(inner)
	inner.setup("INNER", true)
	outer.set_partner(inner)
	inner.set_partner(outer)
	var interior := AirlockDoor.new()
	interior.position = Vector3(8, 0, 0)
	world.add_child(interior)
	interior.setup("INTERIOR", true)
	inner.toggle()
	interior.toggle()
	await create_timer(.6).timeout
	assert(not inner.is_closed() and not interior.is_closed(), "Setup: the inner and interior doors are open.")
	outer.toggle()
	await create_timer(1.2).timeout
	assert(inner.is_closed(), "Opening to Mars seals this airlock's own inner door first.")
	assert(not outer.is_closed(), "Then the outer hatch opens.")
	assert(not interior.is_closed(), "Other doors in the base are left alone.")
	interior.toggle()
	await create_timer(.6).timeout
	interior.toggle()
	await create_timer(.6).timeout
	assert(not interior.is_closed(), "Interior doors still open and close while an outer hatch is open.")
	inner.toggle()
	await create_timer(1.2).timeout
	assert(outer.is_closed() and not inner.is_closed(), "Opening the inner door seals the outer hatch first.")
	print("Airlock interlock test passed: each airlock seals its own pair; the rest of the base keeps working.")
	quit(0)
