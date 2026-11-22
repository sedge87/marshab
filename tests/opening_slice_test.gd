extends SceneTree

## The opening slice (version 3, docs/opening-slice.md) boots and its first
## beats ring: a new story game runs scripts/opening_slice.gd, the radio
## loads data/radio/slice/ instead of the old days, the assignment plays,
## and the slate, helmet and hatch move it on. Grows as chunk 1 is built.
## godot --headless --path . --script res://tests/opening_slice_test.gd

var world: Node
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
			field.hitch.claim(gary, "interact")
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
				var screen: Label3D = deck.get_node_or_null("../DeckScreen") if deck.get_node_or_null("../DeckScreen") != null else walker.get_node_or_null("DeckScreen")
				check(screen != null and screen.visible and screen.text.contains("GROUND") and screen.text.contains("WATER"), "the deck screen doesn't read the ground: '%s'" % (screen.text if screen != null else "none"))
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
					check(screen.text.contains("SET DOWN HERE"), "good ground doesn't offer 'Set down here': '%s'" % screen.text)
					check(deck.press(true) and bool(deck.siting), "E on the deck screen didn't lay the outline")
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
					# cartridge or blanket; the kit's in crates by the wall.
					var life: Node = world.module_life
					check(life != null and bool(life.commissioned) and life.breathable() and life.has_blanket(), "the core isn't running on the power module (commissioned %s)" % str(life.commissioned if life != null else "no core"))
					var builder: Node = world.builder
					var rules := preload("res://scripts/build_rules.gd")
					check(rules.b_reason(builder).contains("terminal"), "B still opens the plan: '%s'" % rules.b_reason(builder))
					var inside: Vector3 = life._centre()
					player.global_position = Vector3(inside.x, builder.habitat_base_y + 1.0, inside.z)
					await wait(3.0)
					var crates: Array = root.get_tree().get_nodes_in_group("kit_crate")
					var kit: Array = rules.kit_left(builder)
					check(kit.has("site_plan_terminal"), "the kit has no Site plan terminal: %s" % str(kit))
					check(crates.size() == kit.size(), "%d crates for %d kit pieces" % [crates.size(), kit.size()])
					var carry: Node = root.get_tree().get_first_node_in_group("carry")
					var core_cells: Array = rules.module_zone(builder).get("cells", [])
					for crate in crates:
						var piece := str(crate.id)
						check(crate.interact(), "the %s crate didn't give its piece" % piece)
						check(str(carry.carrying.get("id", "")) == piece, "not holding the %s" % piece)
						var spot := _free_spot(builder, piece, core_cells)
						check(not spot.is_empty(), "no floor spot for the %s" % piece)
						if not spot.is_empty(): check(carry._place(spot.at, spot.rot, Vector3.UP), "couldn't set the %s down" % piece)
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
					check(int(days.chapter) == 3 and not days.guided(), "the opening didn't end after the first room (chapter %d)" % int(days.chapter))
	Engine.time_scale = 1.0
	if failures.is_empty(): print("Opening slice test passed: version 3 boots, the slice's calls load (not the old days), the assignment plays, the slate and helmet open the hatch, GAR-Y's cradle is near and it's snagged past its stakes, freeing it runs the meeting, it leads to a pallet, the three pallets give the stores, tools go in hand with 1-4 and show on the slate's Kit page, the module, spares and the hitch, the module tows on the sled and wakes Walker 1, the seal patches and it walks home by the lander, the crew call at dusk in the cabin, GAR-Y parks by the steps, the hatch stays shut that night, the seat sleeps you to dawn, you ride Walker 1 at dawn steering where you look, the deck screen reads the ground, Set down here lays the outline and folds the core, which runs on the power module, B sends you to the terminal, the kit comes out of its crates by hand, and the terminal plans the free Quarters.")
	else:
		for f in failures: print("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)
