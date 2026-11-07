extends SceneTree

# The slate and the wrist pad, introduced in the world (docs/pda.md §8):
# - a new game's slate lies on the cabin console, not yet yours;
# - nine seconds in it lights up; E picks it up and it rises in your hands;
# - its screen shows the keys the first few times, then stops;
# - opening the hatch takes it if you left it, and the suit's seal check
#   lifts the wrist pad with its key, then lowers it;
# - the counts are saved.
# godot --headless --path . --script res://tests/opening_devices_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world.day_night.frozen = true
	return world

func _initialize() -> void:
	# A fresh launch boots with "older rules"; starting a new game from the
	# menu must clear it, or the menu shows the old landing map (8 Nov).
	MHChapterOne.older_rules = true
	MHGame.set_mode("survival")
	MHGame.start_new_challenge()
	_check(MHChapterOne.new_rules(), "a new game from the menu plays by the new rules (no landing map)")
	var menu = load("res://scripts/main_menu.gd").new()
	MHGame.site_id = "region"
	_check(menu._arrives(), "so the menu's third step is Arrive, not Land")
	menu.free()
	var world = await _new_world()
	var pda: Node = world.pda
	# The opening review (8 Nov): one seat, a quiet touchdown, the survey Map.
	var seats := 0
	for child in world.lander.get_children(): if str(child.name).begins_with("Cabin_landing_seat"): seats += 1
	_check(seats == 1 and world.lander.get_node_or_null("Cabin_landing_seat_1") != null, "one seat: you came alone (%d)" % seats)
	await create_timer(1.0).timeout
	_check(not world.notes.is_open("air") and not world.notes.is_open("parachute") and not world.notes.is_open("sunset"), "no thoughts piled up at touchdown")
	var spot: Vector2 = Vector2(world.lander.global_position.x, world.lander.global_position.z) + world.known.origin
	_check(world.known.seen_at(spot + Vector2(350, 0)) > .5, "the lander cameras' patch is sharp on the Map")
	_check(world.known.seen_share() < .05, "the rest is still the survey")
	_check(not pda.received, "a new game's slate isn't yours yet")
	var cradle: Node3D = world.slate_cradle
	_check(cradle != null and is_instance_valid(cradle), "it lies on the console")
	if cradle == null:
		quit(1)
		return
	var console: Node3D = null
	for child in world.lander.get_children():
		if str(child.name).begins_with("Cabin_mission_planning_console"): console = child
	var top: MeshInstance3D = null
	for mesh in console.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with("desk_top"): top = mesh
	var desk: AABB = top.global_transform * top.get_aabb() if top != null else AABB()
	var flat := Vector2(cradle.global_position.x - desk.get_center().x, cradle.global_position.z - desk.get_center().z).length()
	_check(top != null and flat < 1.0, "in its dock on the console (%.2f m from the desk's centre)" % flat)
	var up: float = cradle.global_position.y - console.global_position.y
	_check(up > 1.15 and up < 1.6, "standing at eye level above the console (%.2f m up)" % up)
	_check(cradle.global_basis.z.y < .5 and absf(cradle.global_basis.z.y) < .5, "upright, its screen facing out, not up")
	# Looking at it from the seats, the ray finds the slate, not the console.
	var eye: Vector3 = console.to_global(Vector3(0, 1.55, -1.4))
	await process_frame
	var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + (cradle.global_position - eye) * 1.5))
	_check(not hit.is_empty() and hit.collider == cradle, "looking at it from the seats, you're looking at the slate (hit %s)" % (str(hit.collider.name) if not hit.is_empty() else "nothing"))
	world._slate_lights_up()
	_check(cradle.waiting and world.notes.is_open("slate"), "nine seconds in it lights up, and a thought")
	_check(str(cradle.interaction_prompt().get("primary", "")) == "Pick up", "E picks it up")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cradle.interact()
	await process_frame
	_check(pda.received and pda.is_open, "picked up, it rises in your hands")
	_check(pda.show_keys() and pda.screen._keys.visible, "its screen shows the keys")
	_check(world.notes.is_settled("slate"), "the thought's answered")
	pda.close()
	_check(world._after_slate_done, "putting the slate down starts the next beats")
	await create_timer(9.5).timeout
	_check(world.notes.is_open("air") and not world.notes.is_open("parachute"), "then the air worry, before the parachute")
	await create_timer(7.0).timeout
	_check(world.notes.is_open("parachute"), "then the parachute")
	pda.open()
	for i in pda.HINT_TIMES:
		pda.close()
		pda.open()
	_check(not pda.show_keys() and not pda.screen._keys.visible, "after a few times, no more keys")
	pda.close()

	# Left on the console, the hatch pockets it without raising it.
	var w2 = await _new_world()
	w2.lander.set_hatch(true)
	w2._update_lander_intro()
	await process_frame
	_check(w2.pda.received and not w2.pda.is_open and not is_instance_valid(w2.slate_cradle), "opening the hatch pockets a forgotten slate, not raised")
	_check(w2.suit.seal_checked, "and the seal check runs straight away")
	w2.queue_free()
	await process_frame

	# The hatch: the suit's seal check on the wrist pad.
	var times: int = pda.HINT_TIMES
	var suit: Node = world.suit
	_check(not suit.seal_checked, "no seal check before the hatch")
	world.lander.set_hatch(true)
	world._update_lander_intro()
	_check(suit.seal_checked and suit.seal_banner and suit.pad.held, "the hatch opens: the seal check lifts the wrist pad")
	_check(bool(suit.readout().wrist_keys), "showing its key")
	await create_timer(suit.SEAL_CHECK_SECONDS + .3).timeout
	_check(not suit.pad.held and not suit.seal_banner, "then lowers it")
	suit.wrist_raised()
	_check(suit.wrist_hint_uses == 1, "raising it yourself counts")

	# Saved and loaded.
	var save: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	var again = await _new_world(save)
	_check(int(again.pda.hint_uses) == times + 2, "the slate's count loads (%d)" % int(again.pda.hint_uses))
	_check(again.suit.seal_checked and again.suit.wrist_hint_uses == 1, "the seal check and wrist count load")
	_check(again.slate_cradle == null, "a loaded game has no slate on the console")
	again.queue_free()
	await process_frame
	print("opening_devices_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
