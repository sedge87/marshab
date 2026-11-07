extends SceneTree

# Step 3a, the first night (scripts/drop_field.gd, drop_site.gd, power_pack.gd,
# gary_sunset.gd; systems-and-items §14 step 3):
# - pallets 2-4 are placed round the landing at their distances, apart from
#   each other and from the first parachute, each on its kind of ground;
# - no GAR-Y at the start; from the Parachute ridge you see pallets 2 and 3;
# - pallet 2's power pack is carried to the lander and laid out: the cabin
#   gets the blanket and battery, and night one runs everything all night;
# - pallet 3 wakes GAR-Y, who points you to pallet 4; pallet 4's tools;
# - GAR-Y asks you to watch the sunset, and you can say yes;
# - all of it is saved and loaded;
# - blacking out before you've met it, GAR-Y comes from its pallet to find you.
# godot --headless --path . --script res://tests/drop_field_test.gd
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	return world

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _open(pallet: Node) -> void:
	pallet.open(false)
	await process_frame

func _initialize() -> void:
	var world = await _new_world()
	var field: Node = world.drop_field
	_check(field != null and field.sites.size() == 3, "a new game has pallets 2-4")
	if field == null:
		quit(1)
		return
	var lander: Node3D = world.lander
	var ridge: Vector3 = world.storm_drop.ridge
	var ranges := {"power": [500.0, 700.0], "gary": [700.0, 920.0], "tools": [880.0, 1170.0]}
	for kind in ranges:
		var d := _flat(field.sites[kind].at, lander.global_position)
		_check(d >= ranges[kind][0] and d <= ranges[kind][1], "%s is %.0f-%.0f m out (%.0f m)" % [kind, ranges[kind][0], ranges[kind][1], d])
		_check(_flat(field.sites[kind].at, ridge) > 240.0, "%s is well away from the first parachute" % kind)
	var kinds := ["power", "gary", "tools"]
	for i in kinds.size():
		for j in range(i + 1, kinds.size()):
			var a: float = field._bearing(field.sites[kinds[i]].at)
			var b: float = field._bearing(field.sites[kinds[j]].at)
			_check(absf(angle_difference(a, b)) >= deg_to_rad(49.0), "%s and %s lie in different directions" % [kinds[i], kinds[j]])
	_check(field._roughness(field.sites.gary.at) >= field._roughness(field.sites.power.at), "GAR-Y's pallet is on rougher ground than the power pallet (%.2f vs %.2f)" % [field._roughness(field.sites.gary.at), field._roughness(field.sites.power.at)])
	_check(field._ring_mean(field.sites.tools.at, 60.0) > field.sites.tools.at.y, "the tools pallet lies in a hollow")
	_check(world.scout_rover == null and not world.gary_met, "no GAR-Y at the start")

	# Up on the ridge, two more parachutes.
	var player: Node3D = world.player
	player.global_position = ridge + Vector3(0, 1.5, 0)
	for i in 4: await process_frame
	await create_timer(.6).timeout
	var known = world.known
	_check(known.knows(field.sites.power.id()) and known.knows(field.sites.gary.id()) and not known.knows(field.sites.tools.id()), "from the ridge you see pallets 2 and 3, not 4")
	_check(world.notes.is_open("chutes") and not str(world.notes.thoughts()[0].text).contains("{"), "a thought names their directions")

	# Pallet 2: the power pack, carried home and laid out.
	var power: Node = field.sites.power
	await _open(power.pallet)
	var pack: Node = power.pack
	_check(power.pallet.interaction_prompt().get("primary", "") == "Pick up", "looking into the open pallet offers the power pack")
	power.pallet.interact(player)
	_check(pack.where == "carried" and float(player.get_meta("load_speed", 1.0)) < .9, "carrying the pack slows you")
	var cabin: Node = world.cabin_life
	var dusk_hour := float((MHGame.site().get("day_cycle", {}) as Dictionary).get("sunset_hour", 19.0)) - 1.0
	var before: Dictionary = cabin.core.runway(dusk_hour, 14.0)
	player.global_position = lander.to_global(Vector3(5.0, 0, 3.0))
	player.global_position.y = MHSiteTerrain.height(player.global_position.x, player.global_position.z) + 1.0
	pack.put_down()
	_check(pack.where == "ground" and pack.near_lander() and str(pack.interaction_prompt().primary) == "Lay out the solar blanket", "set down by the lander, it offers to lay out the blanket")
	pack.interact(player)
	_check(pack.where == "laid" and is_equal_approx(float(cabin.core.pack_kw), 1.5) and is_equal_approx(float(cabin.core.battery_cap), 16.0), "laid out: the cabin has the blanket and a 16 kWh battery (%s)" % str(cabin.core.battery_cap))
	cabin.core.battery_kwh = cabin.core.battery_cap
	var after: Dictionary = cabin.core.runway(dusk_hour, 14.0)
	_check(float(before.power) > 0.0 and float(after.power) < 0.0, "night one: everything on ran the battery flat before (%.1f h); now it lasts" % float(before.power))
	_check(world.notes.is_settled("power") and world.notes.is_settled("power_pallet"), "the power worry is settled")

	# Pallet 3: GAR-Y wakes, and points to pallet 4.
	player.global_position = field.sites.gary.pallet.global_position + Vector3(2.5, 1.0, 0)
	await _open(field.sites.gary.pallet)
	_check(world.gary_met and world.scout_rover != null and _flat(world.scout_rover.global_position, field.sites.gary.pallet.global_position) < 6.0, "opening pallet 3 wakes GAR-Y beside it")
	_check(world.notes.is_settled("gary") and world.notes.is_open("tools") and known.knows(field.sites.tools.id()), "GAR-Y points you to pallet 4")
	for i in 3: await process_frame
	_check(world.notes.is_settled("chutes"), "both pallets seen from the ridge are found")

	# Pallet 4: the field tools.
	var lamp: SpotLight3D = player.get("flashlight")
	var reach := lamp.spot_range
	await _open(field.sites.tools.pallet)
	_check(field.tools and MHChapterOne.has_hammer and lamp.spot_range > reach * 1.5, "the hammer, and the headlamp throws further (%.0f → %.0f m)" % [reach, lamp.spot_range])
	_check(world.suit._patch_kit(), "the patch kit works anywhere")

	# GAR-Y's sunset: it asks; you say yes.
	var gary: Node3D = world.scout_rover
	var sunset_hour := dusk_hour + 1.0
	world.day_night.set_hour(sunset_hour - .3)
	MHGame.sol_hour = sunset_hour - .3
	player.global_position = gary.global_position + Vector3(3, 1, 0)
	await create_timer(.7).timeout
	_check(gary.has_meta("sunset_offer") and str(gary.interaction_prompt().primary) == "Watch the sunset together", "at sunset GAR-Y asks you to watch it together")
	gary.interact(player)
	_check(field.sunset.phase == "watch" and bool(player.get_meta("ui_freeze", false)), "saying yes: you sit and watch")
	field.sunset._t = field.sunset.WATCH - .01
	await create_timer(.2).timeout
	_check(field.sunset.shared and not bool(player.get_meta("ui_freeze", false)) and world.notes.is_settled("sunset_gary"), "then it's in the journal, and you're free again")

	# Saved and loaded.
	var spots := {}
	for kind in field.sites: spots[kind] = field.sites[kind].at
	var state: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	var again = await _new_world(state)
	var field2: Node = again.drop_field
	_check(field2 != null and spots.keys().all(func(k): return field2.sites[k].at.distance_to(spots[k]) < .1), "the pallets are where they were")
	_check(field2 != null and field2.sites.power.pack.where == "laid" and is_equal_approx(float(again.cabin_life.core.battery_cap), 16.0), "the blanket is still laid out, the battery still big")
	_check(again.gary_met and again.scout_rover != null and field2.tools and field2.sunset.shared, "GAR-Y, the tools and the sunset are kept")
	again.queue_free()
	await process_frame

	# Blacking out before meeting GAR-Y: it comes from its pallet.
	var third = await _new_world()
	third.drop_field.gary_finds_you()
	_check(third.gary_met and third.scout_rover != null and third.drop_field.sites.gary.empty, "GAR-Y comes to find you; its pallet is empty")
	await _open(third.drop_field.sites.gary.pallet)
	_check(third.get_tree().get_nodes_in_group("gar_y").size() == 1, "opening its empty cradle doesn't make a second GAR-Y")

	if failures == 0:
		print("Drop field test passed: pallets 2-4 placed round the landing on their ground; no GAR-Y at the start; two parachutes seen from the ridge; the power pack carried and laid out, night one lasting; GAR-Y woken and pointing to pallet 4; the tools; GAR-Y's sunset; saved and loaded; and GAR-Y finding you.")
	quit(1 if failures > 0 else 0)
