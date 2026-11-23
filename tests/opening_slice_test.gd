extends SceneTree

## The opening slice (version 3, docs/opening-slice.md) boots and its first
## beats ring: a new story game runs scripts/opening_slice.gd, the radio
## loads data/radio/slice/ instead of the old days, the assignment plays,
## and the slate, helmet and hatch move it on. Grows as chunk 1 is built.
## godot --headless --path . --script res://tests/opening_slice_test.gd

var world: Node
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
var failures: Array = []

func check(ok: bool, what: String) -> void:
	if not ok: failures.append(what)

func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += root.get_process_delta_time()

func _ground(p: Vector3) -> Vector3:
	var terrain := preload("res://scripts/site_terrain.gd")
	return Vector3(p.x, terrain.height(p.x, p.z) + 1.0, p.z)

## A floor spot in the core where `id` is allowed, scanning a 0.5 m grid.
func _free_spot(builder: Node, id: String, cells: Array) -> Dictionary:
	for cell in cells:
		for dx in [-1.0, -.5, 0.0, .5, 1.0]:
			for dz in [-1.0, -.5, 0.0, .5, 1.0]:
				for rot in [0.0, PI * .5]:
					var at := Vector3(cell.x * builder.CELL + dx, builder.habitat_base_y, cell.y * builder.CELL + dz)
					if builder.free_interior_invalid_reason(id, at, Vector3.UP, rot).is_empty(): return {"at": at, "rot": rot}
	return {}

## A 2x2 block of cells against the core that the plan takes.
func _beside(builder: Node, core: Array) -> Array:
	for c in core:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for shift in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				var start: Vector2i = c + d * (1 if d.x + d.y > 0 else 2) + shift
				var cells: Array = builder._cells(start, start + Vector2i(1, 1))
				if not cells.is_empty() and builder._invalid_reason(cells).is_empty(): return cells
	return []

func _heard(radio: Node, section: String, seconds: float) -> bool:
	var t := 0.0
	while t < seconds and not (radio.heard as Dictionary).has(section):
		await wait(1.0)
		t += 1.0
	# And let it finish, so the next call can come.
	t = 0.0
	while t < 60.0 and str(radio.playing) == section:
		await wait(1.0)
		t += 1.0
	return (radio.heard as Dictionary).has(section)

func _outside(player: Node3D, at: Vector3) -> void:
	if world.suit != null and not bool(world.suit.helmet): world.suit.suit_up()
	await wait(1.0)
	player.global_position = _ground(at)
	await wait(2.0)

## A line GAR-Y runs between a and b (site metres); waits for it to finish.
func _run_line(lines: Node, gary: Node3D, a: Vector2, b: Vector2) -> Dictionary:
	var before: int = (lines.lines as Array).size()
	gary.global_position = _ground(Vector3(a.x, 0, a.y) + Vector3(1.5, 0, 0))
	check(lines.plant(Vector3(a.x, preload("res://scripts/site_terrain.gd").height(a.x, a.y), a.y)), "the first stake didn't go in")
	check(lines.plant(Vector3(b.x, preload("res://scripts/site_terrain.gd").height(b.x, b.y), b.y)), "the far stake didn't go in: %s" % lines.far_reason(Vector3(b.x, 0, b.y)))
	var t := 0.0
	while t < 240.0 and (lines.lines as Array).size() == before:
		await wait(2.0)
		t += 2.0
	check((lines.lines as Array).size() > before, "GAR-Y never finished the line")
	return (lines.lines as Array).back() if (lines.lines as Array).size() > before else {}

## Chunk 2 (docs/opening-slice.md §4a Scenes 8–12): the pad has failed.
func _chunk_two(days: Node, radio: Node, player: Node3D, gary: Node3D, lander: Node3D) -> void:
	var pad: Node3D = days.pad
	var lines: Node = days.lines
	check(pad != null and lines != null, "no pad or survey line in the slice")
	if pad == null or lines == null: return
	var to_lander: float = pad.centre_2d().distance_to(Vector2(lander.global_position.x, lander.global_position.z))
	var to_pit: float = pad.centre_2d().distance_to(pad.pit_centre())
	check(to_lander > 120.0 and to_lander < 600.0, "the pad is %.0f m from the lander" % to_lander)
	check(to_pit > 160.0 and to_pit < 250.0, "the pad is %.0f m from the pit, not ~200" % to_pit)
	var field: Node = world.drop_field
	check(field.sites.has("print_shop"), "pallet 6 isn't down near the pad")
	if field.sites.has("print_shop"):
		var p6: Vector3 = field.sites.print_shop.at
		check(Vector2(p6.x, p6.z).distance_to(pad.centre_2d()) < 120.0, "pallet 6 isn't in sight of the pad")
	check(str(pad.keep_clear(pad.centre_2d())) != "", "a base could go on the pad")
	# Scene 8: up close, you see it.
	check(not days.done("pad_seen"), "the pad counted as seen before going there")
	var beacon: Vector3 = pad.beacon_at()
	await _outside(player, beacon + Vector3(4, 0, 4))
	await wait(8.0)
	check(bool(pad.seen) and days.done("pad_seen"), "standing at the beacon didn't count as seeing it")
	check(await _heard(radio, "s2_pad_seen", 90.0), "Castle didn't see the pad on the helmet camera (reached %s)" % str(days.reached))
	# Scene 9: lever the foot, then GAR-Y pulls the mast upright.
	check(not bool(pad.press("mast").ok), "the mast came up before its foot was levered")
	var foot: Node = pad.find_child("Point_foot", true, false)
	check(foot != null, "no sunk foot to lever")
	if foot != null: check(foot.hold_for(5.0), "holding E didn't lever the foot")
	await wait(2.0)
	check(bool(pad.levered), "the foot isn't levered")
	gary.global_position = _ground(beacon + Vector3(3, 0, 0))
	pad.press("lead")
	check(bool(pad.connector_seen), "looking at the lead didn't count")
	check(bool(pad.press("mast").ok), "GAR-Y's cable wouldn't clip on")
	var t := 0.0
	while t < 90.0 and not bool(pad.reseated):
		await wait(2.0)
		t += 2.0
	check(bool(pad.reseated) and days.done("pad_reseated"), "the mast never came upright")
	check(await _heard(radio, "s2_reseat", 90.0), "Tamsin didn't ask for the line")
	# Scene 10: the line across the pad. Stakes in hand with 4.
	world.field_kit.select(3)
	check(str(world.field_kit.held) == "stakes", "key 4 didn't put the stakes in hand")
	var path: Array = pad.void_path()
	var along: Vector2 = ((path[2] as Vector2) - (path[0] as Vector2)).normalized()
	var across := Vector2(-along.y, along.x)
	var c: Vector2 = pad.centre_2d()
	var line: Dictionary = await _run_line(lines, gary, c - across * 13.0, c + across * 13.0)
	check(str(line.get("kind", "")) == "pad" and str(line.get("verdict", "")) == "void", "the pad's line reads %s / %s, not a void across the pad: %s" % [str(line.get("kind", "")), str(line.get("verdict", "")), str(line.get("readings", []))])
	var readings: Array = line.get("readings", [])
	check(not readings.is_empty() and float(readings[0]) < .25 and float(readings[-1]) < .25, "the pad line's ends aren't solid: %s" % str(readings))
	check(await _heard(radio, "s2_pad_line", 90.0), "the pad line got no reaction")
	check(world.pda.screen.tabs("map").any(func(tab): return str(tab[0]) == "lines"), "the slate has no Lines tab")
	var page: Control = world.pda.screen._lines_page()
	check(page != null, "the Lines page didn't build")
	if page != null: page.free()
	# Scene 11: the pit. Look down, then a line too far back, then a close one.
	var pit: Vector2 = pad.pit_centre()
	var out := -(c - pit).normalized()   # the side away from the pad: the void's tube runs the other way
	await _outside(player, Vector3(pit.x, 0, pit.y) + Vector3(out.x, 0, out.y) * (pad.pit_edge + 4.5))
	await wait(2.0)
	check(bool(pad.pit_seen) and days.done("pit_seen"), "standing at the lip didn't count as seeing the pit")
	var side := Vector2(-out.y, out.x)
	var far: Dictionary = await _run_line(lines, gary, pit + out * 17.0 - side * 9.0, pit + out * 17.0 + side * 9.0)
	check(str(far.get("kind", "")) == "pit" and str(far.get("verdict", "")) != "void", "a line far back from the lip read clearly (%s %s)" % [str(far.get("verdict", "")), str(far.get("readings", []))])
	check(await _heard(radio, "s2_pit_faint", 60.0), "Tamsin didn't ask for closer")
	lines.first = Vector3(pit.x - 15.0, 0, pit.y)
	check(lines.far_reason(Vector3(pit.x + 15.0, 0, pit.y)).contains("edge"), "a line across the pit was allowed")
	lines.first = Vector3.INF
	var close: Dictionary = await _run_line(lines, gary, pit + out * 11.5 - side * 10.0, pit + out * 11.5 + side * 10.0)
	check(str(close.get("kind", "")) == "pit" and str(close.get("verdict", "")) == "void", "the close line at the pit reads %s" % str(close.get("verdict", "")))
	check(days.done("pit_line"), "the two matching lines didn't count")
	player.global_position = _ground(Vector3(pit.x, 0, pit.y) + Vector3(out.x, 0, out.y) * 30.0)
	check(await _heard(radio, "s2_hold", 120.0), "the hold call didn't play (reached %s)" % str(days.reached))
	# The lip: crumbling within 3 m, and the last metre gives way. GAR-Y
	# brings you home.
	player.global_position = _ground(Vector3(pit.x, 0, pit.y) + Vector3(out.x, 0, out.y) * (pad.pit_edge + 2.0))
	await wait(2.0)
	check(not bool(pad.fell), "fell in from 2 m back")
	player.global_position = _ground(Vector3(pit.x, 0, pit.y) + Vector3(out.x, 0, out.y) * (pad.pit_edge + .5))
	t = 0.0
	while t < 20.0 and not bool(world.suit.passed_out):
		await wait(1.0)
		t += 1.0
	check(bool(pad.fell) and bool(world.suit.passed_out), "the last metre didn't give way (fell %s, out %s)" % [str(pad.fell), str(world.suit.passed_out)])
	t = 0.0
	while t < 300.0 and bool(world.suit.passed_out):
		await wait(3.0)
		t += 3.0
	check(not bool(world.suit.passed_out), "never came round after the fall")
	check(str(world.suit.where) != "outside", "came round outside after the fall (%s)" % str(world.suit.where))
	# Scene 12: Tamsin's sled plan, then home at dusk, the new job.
	check(await _heard(radio, "s2_sled", 120.0), "Tamsin's sled plan didn't come")
	var inside: Vector3 = world.module_life._centre()
	player.global_position = Vector3(inside.x, world.builder.habitat_base_y + 1.0, inside.z)
	await wait(2.0)
	if bool(world.suit.helmet): world.suit.suit_off()
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	if MHGame.sol_hour < float(cycle.get("sunset_hour", 19.0)) - 2.0 and MHGame.sol_hour > 6.0: world.day_night.set_hour(float(cycle.get("sunset_hour", 19.0)) - 1.0)
	check(await _heard(radio, "s2_job", 150.0), "the new job's call didn't play (reached %s, where %s, helmet %s)" % [str(days.reached), str(world.suit.where), str(world.suit.helmet)])
	await wait(3.0)
	check(str(world.known.tracked) == "pallet_6", "pallet 6 isn't tracked on the compass (%s)" % str(world.known.tracked))
	check(int(days.chapter) == 3 and not days.guided(), "the opening didn't end after the new job (chapter %d)" % int(days.chapter))
	# Saved and loaded: the pad keeps its state.
	var state: Dictionary = days.export_state()
	check(bool(state.pad.reseated) and (state.lines.lines as Array).size() == 3, "the pad and lines didn't save")

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHGame.start_new_challenge()
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	Engine.time_scale = 8.0
	var days: Node = world.opening_days
	var radio: Node = world.radio
	check(int(world.opening_version) == 3, "a new game is on opening version %d, not 3" % int(world.opening_version))
	check(days != null and days.get_script() == load("res://scripts/opening_slice.gd"), "the opening isn't the slice")
	check(radio != null and (radio.sections() as Dictionary).has("s1_manifest"), "the slice's calls didn't load")
	check(radio != null and not (radio.sections() as Dictionary).has("d2_wake"), "the old days' calls loaded too")
	radio.fast = true
	await wait(30.0)
	check((radio.heard as Dictionary).has("d1_relock"), "the assignment call didn't play")
	for node in world.get_children():
		if node.get_script() == world.WAKE_UP and bool(node.get("strapped")): node.unbuckle()
	await wait(2.0)
	check(days.hatch_refusal() != "", "the hatch opens before the slate and helmet")
	if world.slate_cradle != null and is_instance_valid(world.slate_cradle):
		world.slate_cradle.interact()
		await wait(4.0)
		world.pda.close()
	check(days.done("slate"), "taking the slate didn't count")
	await wait(4.0)
	check((days.reached as Array).has("slate"), "the slate beat wasn't reached")
	if world.suit != null and not bool(world.suit.helmet): world.suit.suit_up()
	await wait(2.0)
	check(days.hatch_refusal() == "", "the hatch still refuses: %s" % days.hatch_refusal())
	# Out: the first step.
	var lander: Node3D = world.lander
	var player: Node3D = world.player
	lander.interact(player)
	await wait(5.0)
	world._update_lander_intro()
	await wait(6.0)
	player.global_position = _ground(lander.ramp_foot(4.0))
	await wait(8.0)
	check(days.done("outside"), "the first step didn't count")
	# Scene 2: the cradle near, GAR-Y snagged past its stakes.
	var field: Node = world.drop_field
	var cradle_d: float = lander.global_position.distance_to(field.sites.gary.at)
	check(cradle_d > 100.0 and cradle_d < 200.0, "GAR-Y's cradle is %.0f m out, not ~150" % cradle_d)
	var gary: Node3D = world.scout_rover
	check(gary != null and field.snag != null, "GAR-Y isn't out there snagged")
	if gary != null:
		check((gary.ice_samples as Array).size() >= 5, "only %d stakes lead to GAR-Y" % (gary.ice_samples as Array).size())
		check(not days.done("gary_met"), "met GAR-Y before freeing it")
		player.global_position = _ground(gary.global_position + Vector3(2, 0, 0))
		await wait(1.0)
		for point in (field.snag.left as Array).duplicate(): point.free_for(5.0)
		await wait(30.0)
		check(days.done("gary_met"), "freeing GAR-Y didn't lead to the meeting")
		check(str(gary.get("task")) == "goto", "GAR-Y isn't leading to a pallet (task '%s')" % str(gary.get("task")))
		# Scene 3: the three pallets, the hitch, the power module on the sled.
		world.storm_drop.pallet.open(false)
		for kind in ["power", "tools"]: field.sites[kind].pallet.open(false)
		await wait(2.0)
		check(days.done("pallets"), "opening the three pallets didn't count")
		# The survey stakes: a bundle on the open stores pallet, taken by hand.
		var bundle: Node = get_first_node_in_group("stake_bundle")
		check(bundle != null, "no stakes bundle on the open stores pallet")
		check(not world.field_kit.has("stakes"), "the stakes are yours before you've taken the bundle")
		if bundle != null: bundle.interact(world.player)
		await process_frame
		check(world.field_kit.has("stakes") and get_first_node_in_group("stake_bundle") == null, "taking the bundle didn't give you the stakes")
		# The field kit: tools are chosen with 1-4, not guessed.
		var field_kit: Node = world.field_kit
		check(field_kit != null and bool(field_kit.has("corer")) and bool(field_kit.has("hammer")), "the corer and hammer aren't in the kit")
		if field_kit != null:
			check(not preload("res://scripts/field_kit.gd").holding_in(world, "corer"), "the corer works without being in hand")
			field_kit.select(0)
			check(str(field_kit.held) == "corer" and preload("res://scripts/field_kit.gd").holding_in(world, "corer"), "key 1 didn't put the corer in hand")
			await wait(.5)
			check(player.get_node("Head/Camera3D").get_node_or_null("InHand") != null, "the corer doesn't show in your hand")
			field_kit.select(0)
			check(str(field_kit.held) == "", "key 1 again didn't put it away")
			var manifest: Control = world.pda.screen._cargo_page()
			check(manifest != null, "the Cargo page didn't build")
			if manifest != null: manifest.free()
			var page: Control = world.pda.screen._kit_page()
			check(page != null and page.get_child_count() > 4, "the slate's Kit page is empty")
			if page != null: page.free()
		check(world.storm_drop.cartridge == null, "pallet 1 still has an air cartridge in version 3")
		check(int(MHChapterOne.stock.get("spares_kit", 0)) >= 2, "the tools pallet gave no spares kits")
		check(field.hitch != null and bool(field.hitch.have), "the hitch bracket isn't in your kit")
		var module: Node3D = field.sites.power.module
		check(module != null and str(module.where) == "pallet", "the power module isn't in pallet 2")
		if field.hitch != null:
			check(field.hitch.claim_label(gary) != "", "no 'fit the hitch' on GAR-Y")
			# The way you'd really do it: stand by GAR-Y, look at it, press E
			# (22 Nov playtest: the prompt showed but E pinged it instead).
			gary.set("staying", true)
			var head_cam := world.player.get_node("Head/Camera3D") as Camera3D
			for side in [Vector3(1.6, 0, 0), Vector3(-1.6, 0, 0), Vector3(0, 0, 1.6), Vector3(0, 0, -1.6)]:
				var face: Vector3 = gary.global_position + side
				face.y = MHSiteTerrain.height(face.x, face.z) + .1
				world.player.global_position = face
				world.player.look_at(Vector3(gary.global_position.x, face.y, gary.global_position.z), Vector3.UP)
				head_cam.look_at(gary.global_position + Vector3.UP * .45, Vector3.UP)
				for i in 3: await physics_frame
				if world.explore_hud._looked_at_interactable() == gary: break   # a clear look (not past a pallet)
			world.player._use_looked_at_interactable("interact")
			check(bool(field.hitch.fitted), "E on GAR-Y didn't fit the hitch bracket")
			if not bool(field.hitch.fitted): field.hitch.claim(gary, "interact")
			gary.set("staying", false)
		await wait(2.0)
		check(days.done("hitched"), "fitting the hitch bracket didn't count")
		var walker: Node3D = world.walker
		if module != null and walker != null:
			player.global_position = _ground(module.global_position + Vector3(1.5, 0, 0))
			gary.global_position = _ground(module.global_position + Vector3(-2, 0, 0))
			module.interact()
			check(str(module.where) == "carried", "picking up the module didn't carry it (%s)" % str(module.where))
			check(module.claim(gary, "interact"), "GAR-Y's sled wouldn't take the module")
			check(str(module.where) == "sled", "the module isn't on the sled (%s)" % str(module.where))
			# Tow it to Walker 1 and plug it in from the sled.
			var socket: Vector3 = walker.power_socket()
			gary.global_position = _ground(socket + Vector3(6, 0, 0))
			player.global_position = _ground(socket + Vector3(3, 0, 0))
			await wait(1.0)
			check(module.claim(walker, "interact"), "couldn't plug the module in from the sled")
			await wait(2.0)
			check(str(module.where) == "plugged" and str(walker.state) == "coming", "Walker 1 didn't wake (module %s, walker %s)" % [str(module.where), str(walker.state)])
			check(days.done("walker_awake"), "the walker_awake beat didn't count")
			# Scene 4: the seal, then it walks home on its own.
			player.global_position = _ground(walker.fault_spot() + Vector3(1, 0, 0))
			await wait(1.0)
			check(walker.interact(), "couldn't patch the seal")
			check(days.done("walker_fixed"), "patching the seal didn't count")
			player.global_position = _ground(world.lander.ramp_foot(4.0))
			var t := 0.0
			while t < 600.0 and str(walker.state) != "ready":
				await wait(5.0)
				t += 5.0
			check(str(walker.state) == "ready", "Walker 1 didn't walk home (state %s)" % str(walker.state))
			var parked: float = Vector2(walker.global_position.x - lander.global_position.x, walker.global_position.z - lander.global_position.z).length()
			check(parked < 40.0, "Walker 1 parked %.0f m from the lander" % parked)
			check(days.done("walker_home"), "the walker_home beat didn't count")
			# Scene 5: dusk in the cabin. The crew's evening call, the hatch
			# stays shut after dark, and the seat is sleep till dawn.
			var cycle: Dictionary = MHGame.site().get("day_cycle", {})
			var sunset := float(cycle.get("sunset_hour", 19.0))
			world.day_night.set_hour(sunset - 3.0)
			player.global_position = lander.to_global(Vector3(0, lander.DECK + .9, .3))
			lander.set_hatch(false)
			await wait(4.0)
			check(not (radio.heard as Dictionary).has("s1_dusk") and not (radio.queue as Array).has("s1_dusk"), "the evening call came before dusk")
			world.day_night.set_hour(sunset - 1.0)
			var waited := 0.0
			while waited < 120.0 and not (radio.heard as Dictionary).has("s1_dusk"):
				await wait(2.0)
				waited += 2.0
				if MHGame.sol_hour > sunset - .2: world.day_night.set_hour(sunset - .5)
			check((radio.heard as Dictionary).has("s1_dusk"), "the evening call didn't play in the cabin at dusk")
			await wait(2.0)
			var gary_d: float = gary.global_position.distance_to(lander.ramp_foot(2.5))
			check(str(gary.get("task")) == "goto" or gary_d < 4.0, "GAR-Y didn't head for the steps (%.0f m off)" % gary_d)
			world.day_night.set_hour(sunset + .7)
			await wait(1.0)
			check(days.hatch_refusal().contains("Humour me"), "the hatch isn't shut for the first night: '%s'" % days.hatch_refusal())
			check(days.straight_to_sleep(), "the seat isn't sleep till dawn on the first night")
			world.sleep.open()
			await wait(1.0)
			check(bool(world.sleep.asleep), "strapping in didn't sleep: %s" % world.sleep.blocked_reason())
			waited = 0.0
			while waited < 120.0 and bool(world.sleep.asleep):
				await wait(2.0)
				waited += 2.0
			await wait(2.0)
			check(not bool(world.sleep.asleep) and days.done("slept"), "no dawn after the first night (asleep %s, nights %d, hour %.1f)" % [str(world.sleep.asleep), int(days.nights), MHGame.sol_hour])
			check(days.hatch_refusal() == "", "the hatch is still shut after the night: '%s'" % days.hatch_refusal())
			# Scene 6: the dawn ride. Climb aboard, it walks where you look,
			# the deck screen reads the ground, and "Set down here".
			check(str(walker.state) == "ready", "Walker 1 isn't ready to ride at dawn (%s)" % str(walker.state))
			player.global_position = _ground(walker.to_global(walker.STEP_OFF))
			await wait(1.0)
			check(walker.climb(), "couldn't climb aboard Walker 1")
			await wait(3.0)
			var deck: Node = walker.get_node_or_null("Deck")
			check(deck != null and deck.active(), "the deck isn't live while you ride")
			if deck != null:
				var reading: String = deck.screen_text()
				check(deck.screen_lit() and (reading.contains("GOOD SPOT") or reading.contains("NOT HERE")) and reading.contains("Water"), "the deck screen doesn't read the ground: '%s'" % reading)
				var before: Vector3 = walker.global_position
				var w := InputEventKey.new()
				w.physical_keycode = KEY_W; w.keycode = KEY_W; w.pressed = true
				Input.parse_input_event(w)
				await wait(4.0)
				w = w.duplicate(); w.pressed = false
				Input.parse_input_event(w)
				check(walker.global_position.distance_to(before) > 3.0, "holding W didn't walk it (moved %.1f m)" % walker.global_position.distance_to(before))
				# Walk it out to good ground (teleported: the test can't steer 200 m).
				var home_at := Vector2.INF
				for k in 80:
					var at := Vector2(lander.global_position.x, lander.global_position.z) + Vector2.from_angle(k * .7) * (80.0 + k * 6.0)
					if walker.spot_reason(at).is_empty():
						home_at = at
						break
				check(not is_inf(home_at.x), "no good ground for home near the lander")
				if not is_inf(home_at.x):
					walker.global_position = Vector3(home_at.x, 0, home_at.y)
					walker._settle()
					await wait(4.0)
					check(deck.screen_text().contains("GOOD SPOT"), "good ground doesn't say 'GOOD SPOT': '%s'" % deck.screen_text())
					# 22 Nov playtest: E sets down wherever you look (it used to need the screen).
					check(deck.press() and bool(deck.siting), "E on the deck didn't lay the outline")
					await wait(1.0)
					check(str(deck._why) == "", "the outline says not here: %s" % str(deck._why))
					deck.press()
					await wait(1.0)
					check(str(walker.state) in ["carrying", "lowering", "done"], "confirming didn't set it down (%s)" % str(walker.state))
					t = 0.0
					while t < 120.0 and str(walker.state) != "done":
						await wait(2.0)
						t += 2.0
					check(str(walker.state) == "done" and days.done("core_down"), "the core didn't come down (%s)" % str(walker.state))
					check(not bool(walker.riding), "still on the deck after the fold")
					# Scene 7: inside the core. It runs on the power module, no
					# cartridge or blanket; the kit's in one box on the floor.
					var life: Node = world.module_life
					check(life != null and bool(life.commissioned) and life.breathable() and life.has_blanket(), "the core isn't running on the power module (commissioned %s)" % str(life.commissioned if life != null else "no core"))
					var builder: Node = world.builder
					var rules := preload("res://scripts/build_rules.gd")
					var inside: Vector3 = life._centre()
					player.global_position = Vector3(inside.x, builder.habitat_base_y + 1.0, inside.z)
					await wait(3.0)
					# 23 Nov: the kit's one box, and B waits until it's open.
					var crates: Array = root.get_tree().get_nodes_in_group("kit_crate")
					check(crates.size() == 1, "%d kit boxes, not one" % crates.size())
					check(not rules.b_reason(builder).is_empty(), "B works before the kit box is open")
					# The box lies inside the core's floor, clear of its walls.
					var lo := Vector2(INF, INF)
					var hi := Vector2(-INF, -INF)
					for c in rules.module_zone(builder).get("cells", []):
						lo = Vector2(minf(lo.x, (c.x - .5) * builder.CELL), minf(lo.y, (c.y - .5) * builder.CELL))
						hi = Vector2(maxf(hi.x, (c.x + .5) * builder.CELL), maxf(hi.y, (c.y + .5) * builder.CELL))
					for crate in crates:
						var reach := 1.1   # half the stand-in box's length, and a little
						var p: Vector3 = (crate as Node3D).global_position
						check(p.x - reach > lo.x and p.x + reach < hi.x and p.z - reach > lo.y and p.z + reach < hi.y, "the kit box pokes through the core's wall (%s in %s..%s)" % [str(p), str(lo), str(hi)])
					var kit: Array = rules.kit_left(builder)
					check(kit.has("site_plan_terminal"), "the kit has no Site plan terminal: %s" % str(kit))
					var core_cells: Array = rules.module_zone(builder).get("cells", [])
					check(rules.unpacked_kit(builder).is_empty(), "kit on the build list before the box is open")
					if not crates.is_empty(): check(crates[0].interact(), "the kit box didn't open")
					check(rules.b_reason(builder).is_empty(), "B inside the core is refused once the box is open: '%s'" % rules.b_reason(builder))
					for piece in kit:
						check(rules.unpacked_kit(builder).has(piece), "the %s isn't on the build list after opening the box" % piece)
					for piece in kit:
						# Placed the B way (the interior builder's own placement).
						var spot := _free_spot(builder, str(piece), core_cells)
						check(not spot.is_empty(), "no floor spot for the %s" % piece)
						if not spot.is_empty():
							var at: Vector3 = spot.at
							builder.place_free_interior_equipment(str(piece), at, float(spot.rot), Vector2i(roundi(at.x / builder.CELL), roundi(at.z / builder.CELL)), builder.free_interior_visual(str(piece), at, float(spot.rot)))
						await wait(1.0)
					await wait(2.0)
					check(root.get_tree().get_nodes_in_group("kit_crate").is_empty(), "crates left after placing the kit")
					check(days.done("kit_placed"), "placing the kit didn't count (left %s)" % str(rules.kit_left(builder)))
					# The first Quarters, planned at the terminal.
					world.open_site_plan()
					await wait(1.0)
					check(bool(builder.build_mode) and bool(builder.from_terminal), "the terminal didn't open the plan")
					builder.kind = "living"
					var quarters := _beside(builder, core_cells)
					check(not quarters.is_empty(), "no spot for the Quarters beside the core")
					if not quarters.is_empty():
						var zone := {"kind": "living", "cells": quarters, "door_direction": builder.airlock_direction, "cost": builder._zone_cost(quarters)}
						rules.placed(builder, zone)
						check(bool(zone.get("kit", false)), "the first Quarters wasn't free")
						check(rules.zone_reason(builder, "living", quarters).is_empty() or quarters.size() > rules.FREE_QUARTERS_CELLS, "the free Quarters refused: %s" % rules.zone_reason(builder, "living", quarters))
						builder.zones.append(zone)
						builder._history.append({"type": "zone", "zone": zone})
						builder._rebuild()
					builder._toggle()
					t = 0.0
					while t < 300.0 and not days.done("helmet_off"):
						await wait(3.0)
						t += 3.0
					check(days.done("quarters"), "the Quarters never stood")
					check(days.done("helmet_off"), "helmet off in the Quarters didn't count")
					await wait(3.0)
					t = 0.0
					while t < 120.0 and not (radio.heard as Dictionary).has("s2_quiet"):
						await wait(3.0)
						t += 3.0
					check((radio.heard as Dictionary).has("s2_quiet"), "Castle's quiet call didn't play (reached %s)" % str(days.reached))
					await wait(2.0)
					check(days.guided(), "the opening ended at the first room: chunk 2's pad is still to come")
					await _chunk_two(days, radio, player, gary, lander)
	Engine.time_scale = 1.0
	if failures.is_empty(): print("Opening slice test passed: version 3 boots, the slice's calls load (not the old days), the assignment plays, the slate and helmet open the hatch, GAR-Y's cradle is near and it's snagged past its stakes, freeing it runs the meeting, it leads to a pallet, the three pallets give the stores, the stakes bundle comes off the stores pallet by hand, tools go in hand with 1-4 and show on the slate's Kit page, the module, spares and the hitch, the module tows on the sled and wakes Walker 1, the seal patches and it walks home by the lander, the crew call at dusk in the cabin, GAR-Y parks by the steps, the hatch stays shut that night, the seat sleeps you to dawn, you ride Walker 1 at dawn steering where you look, the deck screen reads the ground, Set down here lays the outline and folds the core, which runs on the power module, B waits for the one kit box, opening it puts the whole kit on B's list, and the terminal plans the free Quarters. Chunk 2: the pad is ~200 m from the pit with pallet 6 in sight and no base allowed on it; up close it counts as seen and Castle calls; the foot levers, GAR-Y's cable pulls the mast upright; stakes go in hand with 4; a line across the pad reads a void band with solid ends; the Lines tab shows it; at the pit a far line reads faint and Tamsin asks for closer, a line over the pit is refused, a close one reads void; the hold plays; the lip gives way on the last metre and GAR-Y brings you round inside; Tamsin's sled plan, then the new job at home pins pallet 6 and ends the opening.")
	else:
		for f in failures: print("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)
