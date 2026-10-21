extends SceneTree

# The crew lander: new games start inside its cabin with a minimal HUD; E opens
# the hatch into a ramp; stepping out brings the HUD in; the lander stands on
# buildable ground, can't be built over, and loaded or Creative games start
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
	_check(lander != null and lander.rig != null, "the lander model loads with its rig")
	_check(lander.cabin_contains(player.global_position), "a new game starts inside the lander cabin")
	_check(str(world._intro_stage) == "inside" and bool(world.explore_hud._minimal), "the HUD stays minimal inside the lander")
	_check(not lander.hatch_open(), "the hatch starts closed")
	_check(str(world.builder.climate_at(player.global_position).context) == "Lander cabin", "the cabin is sheltered")
	var prompt: Dictionary = lander.rig.interaction_prompt()
	_check(str(prompt.get("primary", "")) == "Open hatch", "E opens the hatch (%s)" % prompt.get("primary", ""))
	lander.rig.interact()
	for i in 60: await process_frame
	_check(lander.hatch_open(), "the hatch opens")
	# The ramp's bottom edge reaches the ground.
	var ramp_low := 99.0
	for mesh in lander.rig.find_children("hatch_ramp_white_painted*", "MeshInstance3D", true, false):
		var box: AABB = (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		ramp_low = minf(ramp_low, box.position.y)
	_check(ramp_low < lander.global_position.y + .25, "the open ramp reaches the ground (lowest %.2f m)" % (ramp_low - lander.global_position.y))
	player.global_position = lander.to_global(Vector3(0, 1.0, -5.0))
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

	# Creative skips the opening: start outside with the hatch open.
	MHGame.game_mode = "creative"
	world = await _world()
	_check(not world.lander.cabin_contains(world.player.global_position) and world.lander.hatch_open(), "Creative starts outside with the hatch open")
	world.queue_free()
	MHGame.game_mode = "survival"
	if failures == 0:
		print("Crew lander test passed: placement, start inside, hatch and ramp, HUD, shelter, keep-clear, landing target and ellipse, saved position and Creative.")
	quit(1 if failures > 0 else 0)
