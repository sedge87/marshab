extends SceneTree

# Focused controller check: run with
# godot --headless --path . --script res://tests/player_jump_test.gd
func _initialize() -> void:
	var world := preload("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for frame in 40:
		await physics_frame
	var player := world.get_node("Player") as CharacterBody3D
	if not player.is_on_floor():
		_fail("player did not begin grounded")
		return
	var start_y := player.global_position.y
	var peak_y := start_y
	Input.action_press("jump")
	for frame in 8:
		await physics_frame
	# A second press while airborne must not provide a second jump.
	Input.action_release("jump")
	await physics_frame
	Input.action_press("jump")
	for frame in 90:
		await physics_frame
		peak_y = maxf(peak_y, player.global_position.y)
	Input.action_release("jump")
	for frame in 30:
		await physics_frame
	var jump_height := peak_y - start_y
	if jump_height < 0.70 or jump_height > 1.30:
		_fail("jump height %.2f m is outside the intended approximately 1 m range" % jump_height)
		return
	var ground_query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 30.0, player.global_position + Vector3.DOWN * 30.0, 1)
	ground_query.exclude = [player.get_rid()]
	var ground_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ground_query)
	if ground_hit.is_empty() or player.global_position.y < float(ground_hit["position"].y) - 0.05:
		var terrain_y := -999.0 if ground_hit.is_empty() else float(ground_hit["position"].y)
		_fail("player did not land safely on the terrain (player_y=%.3f, terrain_y=%.3f)" % [player.global_position.y, terrain_y])
		return
	print("Player jump test passed: %.2f m jump, no aerial double-jump, safe landing." % jump_height)
	quit(0)

func _fail(message: String) -> void:
	push_error("Player jump test failed: " + message)
	quit(1)
