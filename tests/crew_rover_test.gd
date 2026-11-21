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
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	var rover = world.crew_rover
	assert(rover != null, "A vehicle bay brings the crew rover.")
	for i in 30: await physics_frame
	# Phase 6: the HabRover (Traverse 06) is too tall for the hangar: it docks
	# on a pad outside the big door, backed on to the wall by an umbilical.
	var pad_ground: float = b._terrain_height(rover.global_position)
	assert(rover._docks_outside() and rover._in_bay() and not rover._in_bay_room(), "Docked on its pad outside the Garage (%s)." % rover.global_position)
	assert(absf(rover.global_position.y - pad_ground) < 0.35, "On the ground (%.2f, ground %.2f)." % [rover.global_position.y, pad_ground])
	assert(rover._umbilical != null and rover._umbilical.visible and str(rover._charge_source()) == "garage", "The umbilical's on: it charges and restocks from the Garage.")
	assert(not get_nodes_in_group("vehicle_bay_ramp").is_empty(), "The hangar has a ramp down to the ground.")
	assert(rover._cabin != null and not rover.interaction_prompt().has("primary"), "Look at it: you get in by the rear hatch (21 Nov), not E on its side.")
	MHGame.game_mode = "freedom"   # the batteries run down (Creative's never do)
	# At night, so the roof panel isn't topping the battery up as it drains.
	world.day_night.set_hour(23.0); world.day_night.frozen = true
	for i in 5: await process_frame
	var player: Node3D = world.player
	player.global_position = rover.global_position + Vector3(-2.5, 0.2, 0)
	assert(rover.sit_down(player), "Sit in the driver's seat.")
	assert(bool(player.get_meta("driving", false)) and not player.visible, "You're in the driver's seat.")
	for i in 70: await physics_frame   # the camera carries you down into it
	# Drive south, away from the Garage.
	_key(KEY_W, true)
	for i in 60 * 7: await physics_frame
	_key(KEY_W, false)
	for i in 60: await physics_frame
	var hangar_z := 1.5 * 3.0 + 1.5     # the bay's south face
	assert(rover.global_position.z > hangar_z + 3.0, "Away from the Garage (z %.1f)." % rover.global_position.z)
	var ground: float = b._terrain_height(rover.global_position)
	assert(absf(rover.global_position.y - ground) < 0.35, "On the ground (%.2f, ground %.2f)." % [rover.global_position.y, ground])
	assert(rover.battery < 100.0, "Driving uses the battery (%.1f%%)." % rover.battery)
	# Steer and keep going: it turns.
	var yaw_before: float = rover.rotation.y
	_key(KEY_W, true); _key(KEY_A, true)
	for i in 60 * 2: await physics_frame
	_key(KEY_W, false); _key(KEY_A, false)
	assert(absf(wrapf(rover.rotation.y - yaw_before, -PI, PI)) > 0.3, "A turns it left.")
	for i in 90: await physics_frame
	# The compass is on the driving HUD, with the airlocks on it.
	assert(rover._compass != null and rover._compass.is_visible_in_tree(), "The compass shows while driving.")
	assert(rover._compass.markers.any(func(m): return str(m.label) in ["AIRLOCK", "HANGAR"]), "The nearest way in is on the rover's compass (%s)." % str(rover._compass.markers))
	# C: cruise control holds the speed with no keys held; Space lets go.
	_key(KEY_W, true)
	for i in 60: await physics_frame
	_key(KEY_W, false)
	_key(KEY_C, true); _key(KEY_C, false)
	for i in 60 * 3: await physics_frame
	assert(rover.cruise > 2.5 and rover.speed > 2.5, "Cruising (the rover is 3 m/s since A7): still at %.1f m/s (set %.1f) with nothing held." % [rover.speed, rover.cruise])
	_key(KEY_SPACE, true)
	for i in 30: await physics_frame
	_key(KEY_SPACE, false)
	assert(rover.cruise == 0.0, "Braking turns cruise control off.")
	for i in 90: await physics_frame
	# Get up: brake to a stop (it won't let you up while it rolls), then E.
	_key(KEY_E, true); _key(KEY_E, false)
	for i in 5: await physics_frame
	assert(rover.driving, "Still rolling: E won't get you up (%.1f m/s)." % rover.speed)
	_key(KEY_SPACE, true)
	for i in 120: await physics_frame
	_key(KEY_SPACE, false)
	_key(KEY_E, true); _key(KEY_E, false)
	for i in 80: await physics_frame
	assert(not bool(player.get_meta("driving", false)) and player.visible and rover._cabin.player_in, "E stands you up into the aisle (driving %s, visible %s, in %s, walk %s, speed %.2f, at %s)." % [player.get_meta("driving", false), player.visible, rover._cabin.player_in, rover._cabin.walk, rover.speed, player.global_position])
	rover._cabin.go_out()
	await create_timer(4.5).timeout
	assert(not rover._cabin.player_in and player.global_position.distance_to(rover.global_position) < 6.0, "Out by the airlock, behind it (%s)." % player.global_position)
	# Saved and restored with the base.
	var state: Dictionary = world.current_state()
	assert(not (state.crew_rover as Dictionary).is_empty(), "The rover is in the save.")
	assert((state.crew_rover.position as Vector3).distance_to(rover.global_position) < 0.01, "Where it was left.")
	# Flat main battery: the reserve takes over, slower.
	world.day_night.set_hour(12.0); world.day_night.frozen = true
	for i in 5: await process_frame
	rover.battery = 0.0
	assert(is_equal_approx(rover.top_speed(), float(rover._spec.reserve_speed)), "On the reserve: reduced speed.")
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
	assert(not rover.recalling and rover._in_bay(), "It drove itself home to its pad (%s)." % rover.global_position)
	for i in 60 * 3: await physics_frame
	var hangar_open := get_nodes_in_group("airlock_door").any(func(d): return str(d.door_label()) == "HANGAR" and d.is_open())
	assert(not hangar_open, "It never opens the hangar.")
	assert(str(rover.recall()).contains("already"), "A second recall: it's already home.")
	# In Creative the batteries never run down.
	MHGame.game_mode = "creative"
	rover.battery = 30.0
	rover.reserve = 0.0
	for i in 3: await physics_frame
	assert(rover.battery == 100.0 and rover.reserve == 100.0, "Creative: always full.")
	print("Crew rover test passed: docked on its pad outside the Garage, the ramp, getting in, driving away, steering, the battery, getting out, saving, the reserve, no solar at night, a recall home, the compass, cruise control and Creative's endless battery.")
	quit(0)
