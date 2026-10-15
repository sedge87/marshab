extends SceneTree

# Runtime safety check for the imported Mars Simulator environment. Run with:
# godot --headless --path . --script res://tests/m0_smoke_test.gd
func _initialize() -> void:
	var world := preload("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for frame in 40:
		await physics_frame
	var player := world.get_node("Player") as CharacterBody3D
	if not player.is_on_floor():
		_fail("spawn did not settle on the imported terrain")
		return
	var decor_colliders := world.find_children("DecorCollider", "StaticBody3D", true, false)
	if decor_colliders.is_empty():
		_fail("imported boulder placements did not create collision")
		return
	var start := player.global_position
	Input.action_press("move_forward")
	for frame in 12:
		await physics_frame
	Input.action_release("move_forward")
	var moved_distance := player.global_position.distance_to(start)
	if moved_distance < 0.25:
		_fail("player did not move using the existing Input Map")
		return
	var space_state: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for point: Vector2 in [Vector2(6, 10), Vector2(-48, -48), Vector2(56, -40), Vector2(0, 82)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 180.0, point.y), Vector3(point.x, -80.0, point.y), 1)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			_fail("terrain collision has no surface at %s" % point)
			return
		player.global_position = hit["position"] + Vector3.UP * 1.0
		player.velocity = Vector3.ZERO
		for frame in 18:
			await physics_frame
		if player.global_position.y < float(hit["position"].y) - 0.05 or player.global_position.y > float(hit["position"].y) + 0.45:
			_fail("player did not settle safely on terrain at %s (player_y=%.3f, terrain_y=%.3f)" % [point, player.global_position.y, float(hit["position"].y)])
			return
	player.global_position = Vector3(120.0, 16.0, 0.0)
	player.velocity = Vector3.ZERO
	var boundary_collision: KinematicCollision3D = player.move_and_collide(Vector3(25.0, 0.0, 0.0), true)
	if boundary_collision == null:
		_fail("outer safety boundary has no collision")
		return
	player.global_position.y = -31.0
	await physics_frame
	if player.global_position.y < -10.0:
		_fail("fall-recovery system did not return player to safe ground")
		return
	print("Original Mars environment smoke test passed: movement, terrain collision, boundary, and recovery are working.")
	quit(0)

func _fail(message: String) -> void:
	push_error("Original Mars environment smoke test failed: " + message)
	quit(1)
