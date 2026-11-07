extends SceneTree

# Step 4a, the five needs early (scripts/body.gd, scripts/suit.gd,
# scripts/lifepod.gd, scripts/ration_crate.gd; systems-and-items §14 step 4a):
# - hunger's stages (peckish 12 h, hungry 24 h, starving 72 h) and eating;
# - tiredness at 24 h, the doze risk at 48 h, sleep clearing it, well rested;
# - the hands, walking and suit-oxygen factors;
# - the ration crate: two packs at the start, pallet 1's ten once home;
# - the suit's drink bag drains outside, the food bar eats, both restock;
# - Freedom has neither; saved and loaded.
# godot --headless --path . --script res://tests/needs_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}, mode := "survival") -> Node:
	MHGame.site_id = "region"; MHGame.set_mode(mode); MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	return world

func _initialize() -> void:
	var world = await _new_world()
	var body: Node = world.body
	var suit: Node = world.suit
	var lifepod: Node = world.lifepod
	_check(body != null and suit != null and lifepod != null, "the world has a body, a suit and the lifepod")
	if body == null or suit == null or lifepod == null:
		quit(1)
		return
	_check(MHGame.tiredness_on(), "Survival has tiredness")

	# Hunger.
	body.fed_hours = 0.0
	body.tick_needs(11.0, false)
	_check(not body.peckish(), "not peckish 11 h after eating")
	body.tick_needs(2.0, false)
	_check(body.peckish() and not body.hungry(), "peckish at 13 h")
	body.tick_needs(12.0, false)
	_check(body.hungry() and body.hands_factor() < 1.0, "hungry at 25 h, slower hands")
	var walk_hungry: float = body.speed_factor()
	body.tick_needs(48.0, false)
	_check(body.starving() and body.needs_words().has("weak with hunger"), "starving at 73 h")
	body.eat()
	_check(not body.peckish() and body.speed_factor() > walk_hungry, "eating clears hunger")

	# Tiredness and rest.
	body.awake_hours = 0.0
	body.rested_hours = 0.0
	body.tick_needs(23.0, false)
	_check(not body.tired(), "not tired after 23 h")
	body.tick_needs(2.0, false)
	_check(body.tired() and not body.doze_risk(), "tired after 25 h")
	body.tick_needs(24.0, false)
	_check(body.doze_risk() and body.needs_words().has("exhausted"), "the doze risk after 49 h")
	body.tick_needs(8.0, true)
	_check(is_equal_approx(body.awake_hours, 33.0), "8 h asleep clears 16 h (%.1f left)" % body.awake_hours)
	body.awake_hours = 0.0
	body.slept(4.0)
	_check(not body.rested(), "4 h isn't enough to wake rested")
	body.fed_hours = 0.0
	body.slept(7.0)
	_check(body.rested() and body.hands_factor() > 1.0 and body.o2_factor() < 1.0, "7 h leaves you well rested")
	body.tick_needs(17.0, false)
	_check(not body.rested(), "well rested wears off after 16 h")

	# The ration crate.
	_check(int(lifepod.rations) == lifepod.START_RATIONS, "two packs in the crate at the start")
	var crate := root.get_tree().get_first_node_in_group("ration_crate")
	_check(crate != null, "the small supply crate is the ration crate")
	body.fed_hours = 30.0
	_check(lifepod.eat_ration() and is_zero_approx(body.fed_hours) and int(lifepod.rations) == 1, "E at the crate eats a pack")
	world.storm_drop.pallet_opened()
	_check(int(lifepod.rations_carried) == lifepod.PALLET_RATIONS, "pallet 1's packs go in your pockets")
	world.player.global_position = world.lander.to_global(Vector3(0, world.lander.DECK + .9, .2))
	lifepod._stow_rations()
	_check(int(lifepod.rations) == 1 + lifepod.PALLET_RATIONS and lifepod.rations_carried == 0, "and into the crate once you're in the cabin")

	# The suit's drink bag and food bar.
	suit.where = "outside"
	suit.drink_l = suit.DRINK_L
	suit.sip(4.0)
	_check(absf(float(suit.drink_l) - .5) < .01, "4 h outside drinks half the bag")
	suit.sip(5.0)
	_check(is_zero_approx(suit.drink_l) and suit.dry_hours > 0.0, "the bag runs dry")
	suit.sip(12.0)
	_check(suit.thirsty(), "thirsty after 12 h dry outside")
	body.fed_hours = 30.0
	suit.food_bar = true
	_check(suit.eat_bar() and not suit.food_bar and is_zero_approx(body.fed_hours), "T and E eat the food bar")
	_check(not suit.eat_bar(), "no second bar")
	var tank: float = world.cabin_life.core.water_l
	var packs: int = lifepod.rations
	suit.where = "lander"
	suit.restock()
	_check(is_equal_approx(suit.drink_l, suit.DRINK_L) and suit.food_bar and int(lifepod.rations) == packs - 1, "at the lander the bag fills and a bar goes in")
	_check(absf(tank - float(world.cabin_life.core.water_l) - suit.DRINK_L) < .01, "the bag's water comes from the cabin tank")

	# Saved and loaded.
	body.fed_hours = 20.0
	body.awake_hours = 30.0
	body.rested_hours = 0.0
	suit.drink_l = .3
	suit.food_bar = false
	var save: Dictionary = world.current_state()
	var packs_saved: int = lifepod.rations
	_check(not save.is_empty(), "the world saves")
	world.queue_free()
	await process_frame
	var again = await _new_world(save)
	_check(absf(float(again.body.fed_hours) - 20.0) < .1 and absf(float(again.body.awake_hours) - 30.0) < .1, "hunger and tiredness load")
	# Loaded in the cabin, the suit restocks at once, so read what was restored.
	_check(absf(float(save.suit.drink_l) - .3) < .001 and not bool(save.suit.food_bar), "the drink bag and food bar save")
	again.suit.restore_state(save.suit)
	_check(absf(float(again.suit.drink_l) - .3) < .001 and not bool(again.suit.food_bar), "and load")
	_check(int(again.lifepod.rations) >= packs_saved - 1, "the crate's packs load (%d saved, %d loaded)" % [packs_saved, int(again.lifepod.rations)])
	again.queue_free()
	await process_frame

	# Freedom: no hunger, no tiredness.
	var free_world = await _new_world({}, "freedom")
	free_world.body.fed_hours = 0.0
	free_world.body.awake_hours = 0.0
	free_world.body.tick_needs(100.0, false)
	_check(not free_world.body.peckish() and not free_world.body.tired(), "Freedom has neither hunger nor tiredness")
	free_world.queue_free()
	await process_frame
	MHGame.set_mode("survival")
	print("needs_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
