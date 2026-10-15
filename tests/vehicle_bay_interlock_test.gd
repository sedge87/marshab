extends SceneTree

func _wait_frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _init() -> void:
	var room := Node3D.new()
	get_root().add_child(room)
	var hangar := AirlockDoor.new()
	var bay_door_a := AirlockDoor.new()
	var bay_door_b := AirlockDoor.new()
	room.add_child(hangar)
	room.add_child(bay_door_a)
	room.add_child(bay_door_b)
	hangar.setup("HANGAR",true,5.7,2.58)
	bay_door_a.setup("BAY",true)
	bay_door_b.setup("BAY",true)
	for bay_door in [bay_door_a,bay_door_b]:
		hangar.add_partner(bay_door)
		bay_door.add_partner(hangar)
	bay_door_a.toggle()
	assert(bay_door_a._target_amount > .9, "A closed hangar allows an internal bay door to open.")
	hangar.toggle()
	assert(hangar._pending_open, "Hangar should queue when an internal bay door is open.")
	assert(bay_door_a._target_amount < .1, "Requesting the hangar must command the internal door to close.")
	await _wait_frames(180)
	assert(bay_door_a.is_closed(), "The internal bay door should finish closing.")
	assert(hangar._target_amount > .9, "The hangar should open automatically after the bay seals.")
	bay_door_b.toggle()
	assert(bay_door_b._pending_open, "A bay door should queue when the hangar is open.")
	await _wait_frames(180)
	assert(hangar.is_closed() and bay_door_b._target_amount > .9, "Bay door opens only after the hangar closes.")
	print("Vehicle bay interlock test passed: hangar and habitat doors auto-cycle safely.")
	quit(0)
