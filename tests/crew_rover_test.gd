extends SceneTree

# Run with: godot --headless --path . --script res://tests/crew_rover_test.gd
# The crew rover: it appears in a new vehicle bay, you get in, drive out
# through the hangar door (it opens as you drive up) and down the ramp, the
# battery runs down, you get out beside it, and it's saved with the base.
func _key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code; key.physical_keycode = code; key.pressed = pressed
	Input.parse_input_event(key)

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	var rover = world.crew_rover
	assert(rover != null, "A vehicle bay brings the crew rover.")
	for i in 30: await physics_frame
	var y: float = b.habitat_base_y
	assert(absf(rover.global_position.y - y) < 0.25 and rover._in_bay(), "It's parked on the bay floor (%s, floor %.2f)." % [rover.global_position, y])
	assert(not get_nodes_in_group("vehicle_bay_ramp").is_empty(), "The hangar has a ramp down to the ground.")
	assert(str(rover.interaction_prompt().primary) == "Drive", "Look at it: Drive.")
	# At night, so the roof panel isn't topping the battery up as it drains.
	world.day_night.set_hour(23.0); world.day_night.frozen = true
	for i in 5: await process_frame
	var player: Node3D = world.player
	player.global_position = rover.global_position + Vector3(-2.5, 0.2, 0)
	assert(rover.interact(), "Get in.")
	assert(bool(player.get_meta("driving", false)) and not player.visible, "You're in the driver's seat.")
	# Drive south, out of the hangar.
	_key(KEY_W, true)
	for i in 60 * 7: await physics_frame
	_key(KEY_W, false)
	for i in 60: await physics_frame
	var hangar_z := 1.5 * 3.0 + 1.5     # the bay's south face
	assert(rover.global_position.z > hangar_z + 3.0, "Out through the hangar door (z %.1f)." % rover.global_position.z)
	var ground: float = b._terrain_height(rover.global_position)
	assert(absf(rover.global_position.y - ground) < 0.35, "Down the ramp onto the ground (%.2f, ground %.2f)." % [rover.global_position.y, ground])
	assert(rover.battery < 100.0, "Driving uses the battery (%.1f%%)." % rover.battery)
	# Steer and keep going: it turns.
	var yaw_before: float = rover.rotation.y
	_key(KEY_W, true); _key(KEY_A, true)
	for i in 60 * 2: await physics_frame
	_key(KEY_W, false); _key(KEY_A, false)
	assert(absf(wrapf(rover.rotation.y - yaw_before, -PI, PI)) > 0.3, "A turns it left.")
	for i in 90: await physics_frame
	# Get out: you're standing beside it.
	_key(KEY_E, true); _key(KEY_E, false)
	for i in 5: await physics_frame
	assert(not bool(player.get_meta("driving", false)) and player.visible, "E gets you out.")
	assert(player.global_position.distance_to(rover.global_position) < 4.0, "Beside the rover (%s)." % player.global_position)
	# Saved and restored with the base.
	var state: Dictionary = world.current_state()
	assert(not (state.crew_rover as Dictionary).is_empty(), "The rover is in the save.")
	assert((state.crew_rover.position as Vector3).distance_to(rover.global_position) < 0.01, "Where it was left.")
	# Flat main battery: the reserve takes over, slower.
	world.day_night.set_hour(12.0); world.day_night.frozen = true
	for i in 5: await process_frame
	rover.battery = 0.0
	assert(is_equal_approx(rover.top_speed(), rover.RESERVE_SPEED), "On the reserve: reduced speed.")
	# Both flat at night: it can't move, and a recall says why.
	world.day_night.set_hour(23.0)
	for i in 10: await process_frame
	rover.reserve = 0.0
	assert(rover.top_speed() == 0.0, "Both flat at night: no solar, no movement.")
	assert(str(rover.recall()).contains("sunrise") and not rover.recalling, "A recall at night with nothing left is refused, with the reason.")
	# By day the roof solar can crawl it; with the reserve it comes home itself.
	world.day_night.set_hour(12.0)
	for i in 10: await process_frame
	assert(rover.top_speed() > 0.0, "By day: a solar crawl.")
	rover.reserve = 100.0
	rover.global_position = Vector3(16.0, b._terrain_height(Vector3(16, 0, 26)), 26.0)
	rover.rotation.y = 1.2
	for i in 5: await physics_frame
	rover.battery = 0.0   # (the roof panel has been topping it up meanwhile)
	var message := str(rover.recall())
	assert(rover.recalling and message.contains("reserve"), "Recalled from the charger: driving home on its reserve (%s)." % message)
	for i in 60 * 40:
		await physics_frame
		if not rover.recalling: break
	assert(not rover.recalling and rover._in_bay(), "It drove itself home into the bay (%s)." % rover.global_position)
	for i in 60 * 3: await physics_frame
	var hangar_open := get_nodes_in_group("airlock_door").any(func(d): return str(d.door_label()) == "HANGAR" and d.is_open())
	assert(not hangar_open, "And shut the hangar behind it.")
	assert(str(rover.recall()).contains("already"), "A second recall: it's already home.")
	print("Crew rover test passed: in the bay, the ramp, getting in, driving out through the hangar, steering, the battery, getting out, saving, the reserve, no solar at night, and a recall home.")
	quit(0)
