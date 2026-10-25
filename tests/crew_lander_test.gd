extends SceneTree

# The crew lander: new games start inside its cabin with a minimal HUD; E opens
# the hatch into a ramp; stepping out brings the HUD in; the lander stands on
# buildable ground, can't be built over, and loaded games start
# with the hatch open.
# Run with: godot --headless --path . --script res://tests/crew_lander_test.gd
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _world() -> Node:
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	return world

func _initialize() -> void:
	for site in ["plains", "ridge", "crater", "ice"]:
		MHGame.site_id = site
		var spot: Dictionary = preload("res://scripts/crew_lander.gd").find_spot()
		var at: Vector3 = spot.position
		_check(MHSiteTerrain.is_buildable(Vector2(at.x, at.z)), "%s: the lander stands on buildable ground" % site)

	MHGame.site_id = "plains"
	MHGame.game_mode = "survival"
	MHGame.pending_save_state = {}
	var world: Node = await _world()
	var lander: Node3D = world.lander
	var player: CharacterBody3D = world.player
	_check(lander != null and lander.rig != null, "the lander model loads")
	_check(lander.cabin_contains(player.global_position), "a new game starts inside the lander cabin")
	_check(str(world._intro_stage) == "inside" and bool(world.explore_hud._minimal), "the HUD stays minimal inside the lander")
	_check(not lander.hatch_open(), "the hatch starts closed")
	_check(str(world.builder.climate_at(player.global_position).context) == "Lander cabin", "the cabin is sheltered")
	var prompt: Dictionary = lander.interaction_prompt()
	_check(str(prompt.get("primary", "")) == "Open hatch", "E opens the hatch (%s)" % prompt.get("primary", ""))
	lander.interact()
	await create_timer(3.0).timeout
	_check(lander.hatch_open(), "the hatch opens")
	# The ramp's bottom edge reaches the ground.
	var ramp_low := 99.0
	for mesh in lander.rig.find_child("CrewRampPivot", true, false).find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		ramp_low = minf(ramp_low, box.position.y)
	_check(ramp_low < lander.global_position.y + .25, "the open ramp reaches the ground (lowest %.2f m)" % (ramp_low - lander.global_position.y))
	# Walk out: from the airlock, down the ramp, onto the ground.
	var start_y := player.global_position.y
	Input.action_press("move_forward")
	for i in 150: await physics_frame
	Input.action_release("move_forward")
	var out_at := lander.to_local(player.global_position)
	_check(out_at.z < -6.0 and out_at.y < .6, "you can walk out of the airlock and down the ramp (ended at %s)" % out_at.snapped(Vector3.ONE * .01))
	_check(start_y - player.global_position.y > 1.8, "the walk ends on the ground, not on the deck")
	# And back up into the airlock.
	player.rotation.y += PI
	Input.action_press("move_forward")
	for i in 300: await physics_frame
	Input.action_release("move_forward")
	_check(lander.cabin_contains(player.global_position) or lander.to_local(player.global_position).z > -2.7, "you can walk back up the ramp into the airlock (at %s)" % lander.to_local(player.global_position).snapped(Vector3.ONE * .01))
	player.global_position = lander.to_global(Vector3(0, 1.0, -7.0))
	for i in 10: await process_frame
	_check(str(world._intro_stage) == "done" and not bool(world.explore_hud._minimal), "stepping out brings the full HUD in")
	# Nothing can be built on the lander.
	var under := Vector2i(roundi(lander.global_position.x / BuildController.CELL), roundi(lander.global_position.z / BuildController.CELL))
	world.builder.kind = "living"
	_check(str(world.builder._invalid_reason([under])) == "Too close to the lander", "rooms can't be built on the lander")
	world.queue_free()
	await process_frame

	# Landing on a chosen target: Freedom exactly, Survival inside the ellipse.
	var picker := preload("res://scripts/landing_picker.gd")
	var target: Vector2 = picker.suggested()
	_check(str(picker.evaluate(target).level) == "green", "the suggested landing target is fully safe")
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	_check(picker.touchdown(target, "freedom", rng) == target, "Freedom lands exactly on target")
	var all_inside := true
	var any_off := false
	for i in range(20):
		var landed: Vector2 = picker.touchdown(target, "survival", rng)
		var d := landed - target
		if (d.x * d.x) / (picker.ELLIPSE_A * picker.ELLIPSE_A) + (d.y * d.y) / (picker.ELLIPSE_B * picker.ELLIPSE_B) > 1.001: all_inside = false
		if d.length() > .5: any_off = true
	_check(all_inside and any_off, "Survival lands somewhere inside the ellipse")
	MHGame.landing_target = target
	MHGame.game_mode = "freedom"
	world = await _world()
	var landed_at := Vector2(world.lander.global_position.x, world.lander.global_position.z)
	_check(landed_at.distance_to(target) < .01, "a new Freedom game lands the lander on the chosen target")
	var saved: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	MHGame.pending_save_state = saved
	world = await _world()
	_check(Vector2(world.lander.global_position.x, world.lander.global_position.z).distance_to(landed_at) < .01, "a loaded game puts the lander back where it landed")
	world.queue_free()
	await process_frame
	MHGame.pending_save_state = {}

	# Every free-play mode opens in the lander, Creative and Freedom included.
	for mode in ["creative", "freedom"]:
		MHGame.game_mode = mode
		world = await _world()
		_check(world.lander.cabin_contains(world.player.global_position) and not world.lander.hatch_open(), "%s starts inside the lander with the hatch shut" % mode)
		world.queue_free()
		await process_frame
	MHGame.game_mode = "survival"
	if failures == 0:
		print("Crew lander test passed: placement, start inside, hatch and ramp, HUD, shelter, keep-clear, landing target and ellipse, saved position and Creative.")
	quit(1 if failures > 0 else 0)
