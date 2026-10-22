extends SceneTree

# The world for Missions 3–6: Cargo Lander 2 arrives (Cargo Lander 1 still on
# site), the arrival caption names the mission just finished, the crew land
# in their own lander in Mission 4 and step out of it, the live simulation
# carries the mission's crew, and Mission 6's supply lander brings food.
# Run with: godot --headless --path . --script res://tests/missions_flow_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _campaign_at(mission_id: String, arrived: Array) -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "missions"; MHGame.pending_save_state = {}
	MHMissions.reset()
	var target: Vector2 = PICKER.suggested()
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = target + Vector2(30, 0)
	for id in ["landing_zones", "cargo_power_water", "cargo_habitat", "crew_land", "storm_season"]:
		if id == mission_id: break
		(MHMissions.progress.completed as Array).append(id)
	MHMissions.progress.current = mission_id
	for id in arrived: MHMissions.set_arrived(id)
	MHMissions.cargo_landers().append({"number": 1, "position": Vector3(target.x + 3, 0, target.y), "yaw": 0.0})

func _world() -> Node:
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await process_frame
	return world

func _initialize() -> void:
	# Mission 3: Cargo Lander 2 touches down; Cargo Lander 1 is still there.
	_campaign_at("cargo_habitat", ["cargo_power_water"])
	var world: Node = await _world()
	_check(bool(world.arrival_pending) and world.current_cargo_lander != null and int(world.current_cargo_lander.number) == 2, "Mission 3 opens with Cargo Lander 2's touchdown")
	var first: Array = MHMissions.cargo_landers().filter(func(c): return int(c.number) == 1)
	if not first.is_empty(): _check((first[0].position as Vector3).distance_to(world.current_cargo_lander.global_position) > 10.0, "Cargo Lander 2 lands clear of Cargo Lander 1")
	_check(world.cargo_landers.size() == 2, "Cargo Lander 1 is still on site (%d landers)" % world.cargo_landers.size())
	_check(int(world.builder.simulation().crew_cap) == 0 and str(world.explore_hud.chip_prefix) == "ROBOT · ", "Mission 3 is still robots only")
	var caption_text := ""
	for label in world._arrival_layer.find_children("*", "Label", true, false): caption_text += label.text + " "
	_check(caption_text.to_lower().contains("mission 2 complete") and caption_text.to_lower().contains("power and water"), "the caption closes Mission 2: %s" % caption_text)
	world._finish_arrival()
	_check(world.current_cargo_lander.hold_contains(world.player.global_position), "the robot starts in Cargo Lander 2's hold")
	world.queue_free()
	await process_frame

	# Mission 4: the crew land in their own lander and start in its cabin.
	_campaign_at("crew_land", ["cargo_power_water", "cargo_habitat"])
	world = await _world()
	_check(bool(world.crew_arrival) and bool(world.lander.present), "Mission 4 lands the crew lander")
	_check(bool(world.arrival_pending) and world._arrival_t >= 0.0, "with a touchdown cutscene for the crew lander")
	var crew_caption := ""
	for label in world._arrival_layer.find_children("*", "Label", true, false): crew_caption += label.text + " "
	_check(crew_caption.to_lower().contains("crew lander"), "captioned as the crew lander (%s)" % crew_caption.strip_edges())
	world._finish_arrival()
	await process_frame
	var crew_spot := Vector2(world.lander.global_position.x, world.lander.global_position.z)
	_check(MHMissions.cargo_landers().all(func(c): return Vector2((c.position as Vector3).x, (c.position as Vector3).z).distance_to(crew_spot) > 10.0), "the crew lander lands clear of the cargo landers (%s)" % [MHMissions.cargo_landers().map(func(c): return roundi(Vector2((c.position as Vector3).x, (c.position as Vector3).z).distance_to(crew_spot)))])
	_check(world.lander.cabin_contains(world.player.global_position), "the crew start inside the lander's cabin")
	_check(int(world.builder.simulation().crew_cap) == 4 and str(world.explore_hud.chip_prefix) != "ROBOT · ", "Mission 4 has four crew, not a robot")
	_check(str(MHMissions.current_step().get("id", "")) == "hatch", "the first step is to open the hatch")
	world.lander.set_hatch(true)
	await process_frame
	world.player.global_position = world.lander.to_global(Vector3(0, 1.5, -9.0))
	for i in 3: await process_frame
	world._space_check = 0.0
	await process_frame
	MHMissions.update_steps(world.builder, world.mission_flags)
	_check(bool(world.mission_flags.left_lander), "stepping off the ramp counts as leaving the lander")
	_check(MHMissions.arrived("crew_land") and not bool(world.crew_arrival), "the crew's arrival is recorded once they step out")
	world.queue_free()
	await process_frame

	# Mission 6: the supply lander brings food, once.
	_campaign_at("self_sufficiency", ["cargo_power_water", "cargo_habitat", "crew_land"])
	world = await _world()
	_check(float(world.builder.simulation().food_kg) >= 6 * 1.8 * 60 - 1.0, "Mission 6's supply lander brings 60 sols of food (%d kg)" % roundi(float(world.builder.simulation().food_kg)))
	_check(bool((MHMissions.progress.get("food_delivered", {}) as Dictionary).get("self_sufficiency", false)), "the delivery is recorded so it isn't repeated")
	world.queue_free()
	await process_frame
	MHGame.game_mode = "survival"
	if failures == 0:
		print("Missions flow test passed: Cargo Lander 2, captions, robots, the crew landing, crew sizes and Mission 6 food.")
	quit(1 if failures > 0 else 0)
