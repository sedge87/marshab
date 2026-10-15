extends SceneTree

func _wait_frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _init() -> void:
	var room := Node3D.new()
	get_root().add_child(room)
	var outer := AirlockDoor.new()
	var inner := AirlockDoor.new()
	room.add_child(outer)
	room.add_child(inner)
	outer.setup("OUTER")
	inner.setup("INNER")
	outer.set_partner(inner)
	inner.set_partner(outer)
	outer.toggle()
	assert(outer._target_amount > .9, "Outer airlock door should open from a closed pair.")
	inner.toggle()
	assert(inner._pending_open, "Inner door should queue a safe cycle while the outer door is open.")
	assert(outer._target_amount < .1, "Requesting the inner door must command the outer door to close.")
	await _wait_frames(180)
	assert(outer.is_closed(), "Outer door should seal before the inner door opens.")
	assert(inner._target_amount > .9, "Inner door should open automatically after the outer door seals.")
	print("Airlock interlock test passed: requested doors auto-cycle safely.")
	quit(0)
