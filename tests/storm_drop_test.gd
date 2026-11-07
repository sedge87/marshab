extends SceneTree

# The storm's first drop (scripts/storm_drop.gd, cargo_pallet.gd,
# o2_cartridge.gd, cabin_o2_port.gd; systems-and-items §14 step 2):
# - a new game places the parachute ridge about 400 m in front of the hatch,
#   on high ground, with the canopy laid onto the terrain, the backshell, and
#   a debris trail leading from near the lander;
# - the Notes thought names the ridge's direction; the orbiter knows where it
#   is, and you do once you're close;
# - holding E frees the pallet's latches one by one and opens it: the sample
#   kit, and the oxygen cartridge, reachable only once it's open;
# - carrying the cartridge slows you, Q puts it down, and E on the cabin's
#   oxygen port plugs it in: the tank grows and fills, the air thought settles;
# - the cabin's own tank lasts about a sol; saving.
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	var drop = world.storm_drop
	_check(drop != null, "a new game has the storm's first drop")
	if drop == null:
		quit(1)
		return
	var lander: Node3D = world.lander
	var out: Vector3 = drop.ridge - lander.global_position
	out.y = 0.0
	var ahead := -lander.global_transform.basis.z
	ahead.y = 0.0
	var angle := rad_to_deg(ahead.normalized().angle_to(out.normalized()))
	_check(out.length() > 330.0 and out.length() < 470.0 and angle < 36.0, "the ridge is about 400 m in front of the hatch (%.0f m, %.0f° off)" % [out.length(), angle])
	var low := 0.0
	for a in range(-35, 36, 5):
		var p := lander.global_position + ahead.normalized().rotated(Vector3.UP, deg_to_rad(a)) * 400.0
		low += MHSiteTerrain.height(p.x, p.z)
	_check(drop.ridge.y >= low / 15.0, "on higher ground than the arc round it (%.1f m against %.1f m)" % [drop.ridge.y, low / 15.0])

	# The first orbiter text: the photo, with the direction and distance, waiting on Comms.
	var texts: Node = world.orbiter_texts
	_check(texts != null and texts.has("parachute_photo") and str(texts.latest_photo().get("photo", "")) == "parachute", "Castellanos's text with Rao's parachute photo is waiting")
	_check(texts != null and str(texts.latest_photo().get("text", "")).contains(drop.direction_word(drop.ridge - lander.global_position)), "the text names the ridge's direction")
	_check(world.pda.screen._comms_signature() != "", "Comms can show it")

	# The canopy lies on the ground, wherever it is.
	var canopy := drop.get_node("Parachute").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var points: PackedVector3Array = canopy.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for i in range(0, points.size(), 97):
		var p := canopy.global_transform * points[i]
		worst = maxf(worst, MHSiteTerrain.height(p.x, p.z) - p.y)
	_check(worst < .05, "the canopy is draped over the ground, never under it (worst %.2f m)" % worst)
	_check(drop.get_tree().get_nodes_in_group("storm_debris").size() == 8, "eight pieces of storm debris")
	var nearest := INF
	for piece in drop.get_tree().get_nodes_in_group("storm_debris"): nearest = minf(nearest, (piece as Node3D).global_position.distance_to(lander.global_position))
	_check(nearest < 90.0, "the trail starts near the lander (%.0f m)" % nearest)

	# What's known and thought.
	var known = world.known
	_check(known.knows("find:parachute", "orbiter") and not known.knows("find:parachute"), "the orbiter knows where the parachute is; you don't yet")
	_check(world.notes.is_open("parachute") and world.notes.thoughts().any(func(t): return str(t.text).contains("of the hatch") and not str(t.text).contains("{dir}")), "your thought names the ridge's direction")

	# Walk up: you see it, then the pallet.
	var pallet = drop.pallet
	var player: Node3D = world.player
	player.global_position = pallet.global_position + pallet.global_transform.basis.z * 2.2 + Vector3(0, 1.0, 0)
	drop._check = 0.0
	for i in 3: await process_frame
	_check(known.knows("find:parachute"), "close by, you know where it is")
	_check(world.notes.stage("parachute") == "near", "and the thought changes")
	_check(drop.cartridge._shape.disabled, "the cartridge can't be reached through the lid")

	# Hold E to free the latches.
	_check(str(pallet.interaction_prompt().primary) == "Hold to free the latches", "the pallet's prompt")
	_key(KEY_E, true)
	await process_frame
	pallet.interact(player)
	for i in 30: await process_frame
	_key(KEY_E, false)
	await process_frame
	_check(not pallet.opened and pallet._freed == 0, "letting go early leaves the latches shut")
	_key(KEY_E, true)   # as in play: E goes down, and that press starts the hold
	await process_frame
	pallet.interact(player)
	var t0 := Time.get_ticks_msec()
	while not pallet.opened and Time.get_ticks_msec() - t0 < 6000: await process_frame
	_key(KEY_E, false)
	_check(pallet.opened, "holding E frees all four latches and opens it")
	_check(MHChapterOne.has_corer and not drop.cartridge._shape.disabled, "inside: the sample kit, and the cartridge within reach")
	_check(world.notes.is_settled("parachute") and world.notes.is_open("cargo"), "the parachute thought is answered, and the rest of the cargo comes to mind")
	_check(str(known.thing("find:parachute").name) == "Pallet 1", "the Map calls it Pallet 1 now")

	# Carry the cartridge home.
	var cart = drop.cartridge
	# As in play: stand at the pallet and look in; whatever the crosshair hits must offer the cartridge.
	var inside: Vector3 = pallet.inside_point()
	var eye: Vector3 = inside + pallet.global_basis.z * 1.2 + Vector3(0, 1.1, 0)
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + (inside - eye) * 1.5)
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
	var aimed: Node = hit.collider.get_meta("interaction_target", hit.collider) if not hit.is_empty() else null
	_check(aimed != null and str(aimed.interaction_prompt().get("primary", "")) == "Pick up", "looking into the open pallet offers to pick the cartridge up (%s)" % (str(aimed.interaction_prompt()) if aimed != null else "nothing hit"))
	if aimed != null: aimed.interact(player)
	_check(cart.where == "carried" and float(player.get_meta("load_speed", 1.0)) < .9, "picked up, it slows you (%.2f)" % float(player.get_meta("load_speed", 1.0)))
	_check(world.notes.stage("air") == "carrying", "you think about getting it home")
	cart.put_down()
	_check(cart.where == "ground" and is_equal_approx(float(player.get_meta("load_speed", 1.0)), 1.0), "Q puts it down")
	cart.interact(player)
	var cabin = world.cabin_life
	var port = cabin.port
	_check(port != null and port.get_parent() == lander, "the cabin has its oxygen port")
	var tank_before: float = cabin.core.tank_cap
	_check(absf(tank_before - .84) < .01, "the cabin's own tank holds about a sol (%.2f kg)" % tank_before)
	_check(cart.claim_label(port) == "Plug in the cartridge", "carrying it, the port offers to take it")
	_check(cart.claim(port, "interact"), "E plugs it in")
	_check(cart.where == "plugged" and cart.get_parent() == port and cabin.core.tank_cap > tank_before + 5.0 and is_equal_approx(cabin.core.tank_o2_kg, cabin.core.tank_cap), "the tank grows by its oxygen, full (%.2f kg)" % cabin.core.tank_cap)
	_check(world.notes.is_settled("air") and MHJournal.entries.back().lines.any(func(l): return str(l).begins_with("Plugged the new cartridge")), "the air thought settles into the journal")
	for i in 120: await process_frame
	_check(port._shown > .1, "the dial's needle swings up")

	# Saving.
	var state: Dictionary = world.current_state()
	_check(state.storm_drop.opened and str(state.storm_drop.cartridge) == "plugged" and state.storm_drop.ridge.size() == 3, "the drop is saved: where, opened, the cartridge plugged in")
	_check(float(state.cabin.tank_cap) > 6.0, "the bigger tank is saved")
	_check((state.orbiter_texts.messages as Array).size() == 1, "the orbiter's texts are saved")
	if failures == 0:
		print("Storm drop test passed: the ridge 400 m ahead on high ground, the canopy draped on the terrain, the debris trail, who knows where it is, the thought naming its direction, holding E to free the latches, the sample kit, carrying the cartridge slowly, putting it down, plugging it into the cabin's port, the tank and dial, the journal, the orbiter's photo text, and saving.")
	quit(1 if failures > 0 else 0)
