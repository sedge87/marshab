extends SceneTree

# The known-things record and the Map that fills in (scripts/known_things.gd,
# region_map.gd; docs/systems-and-items.md §14 step 2):
# - a new game's Map is dark except round where you stand;
# - walking clears it, and named places join the record once in sight;
# - who knows what: you, GAR-Y, Earth, the orbiter;
# - clicking the Map drops a pin and clicking it again lifts it; pins show on
#   the compass;
# - only places you know are named on the Map;
# - saving and loading, and older saves clearing the fog along their trail.
const RegionTerrain := preload("res://scripts/region_terrain.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	var known = world.known
	_check(known != null and known.is_in_group("known_things"), "the world keeps a known-things record")
	known._check = 0.0
	for i in 3: await process_frame
	var here: Vector2 = known.you()
	_check(known.seen_at(here) > .9, "the ground round you is clear on the Map")
	_check(known.seen_share() < .05, "the rest of the region starts dark (%.1f%% seen)" % (known.seen_share() * 100.0))

	# Walking clears the fog; a place in sight joins the record.
	var feature: Dictionary = RegionTerrain.meta().features[0]
	var spot := Vector2(float(feature.position[0]), float(feature.position[1]))
	var id: String = known.place_id(str(feature.name), spot)
	_check(not known.knows(id), "a far place isn't known yet (%s)" % feature.name)
	var share_before: float = known.seen_share()
	known.look_from(spot + Vector2(300, 0))
	_check(known.knows(id) and str(known.thing(id).kind) == "place", "within sight, %s joins the record" % feature.name)
	_check(known.seen_share() > share_before and known.seen_at(spot + Vector2(300, 0)) > .9, "looking round clears the fog there")
	_check(known.learned.get_connections().size() >= 0 and not known.learn(id, "place", spot, str(feature.name)), "learning it twice isn't news")

	# Who knows what.
	_check(not known.knows(id, "earth") and known.tell(id, "earth") and known.knows(id, "earth"), "you can tell Earth, and then Earth knows")
	_check(not known.knows(id, "gary"), "GAR-Y still doesn't")
	known.rename(id, "The Bowl")
	_check(str(known.thing(id).name) == "The Bowl", "your words name the place")

	# The Map: only known places are named, and clicks drop pins.
	var map = world.region_map
	map._span = map._half * 2.0
	map._centre = Vector2.ZERO
	map._set_view()
	var names: Array = map._labels.get_children().map(func(l): return str(l.text))
	_check("The Bowl" in names, "the Map names the place you know, by your name for it (%s)" % str(names))
	var unknown := 0
	for f in RegionTerrain.meta().features:
		if not known.knows(known.place_id(str(f.name), Vector2(float(f.position[0]), float(f.position[1])))) and str(f.name) in names: unknown += 1
	_check(unknown == 0, "places you don't know aren't on it")
	_check(map._fog.visible and map._fog.texture != null, "the fog is drawn over the Map")
	var at_px: Vector2 = map._region_to_map(here + Vector2(0, -500))
	var pin: String = map.toggle_pin(at_px)
	_check(not pin.is_empty() and str(known.thing(pin).kind) == "pin", "a click drops a pin")
	var bearings: Array = known.compass_markers(world.player.global_position).filter(func(m): return str(m.label) == str(known.thing(pin).name))
	_check(bearings.size() == 1 and absf(wrapf(float(bearings[0].bearing), -180.0, 180.0)) < 2.0 and absf(float(bearings[0].distance) - 500.0) < 2.0, "the pin shows on the compass, due north 500 m (%s)" % str(bearings))
	var hud_markers: Array = world.explore_hud.compass_markers() if world.get("explore_hud") != null else []
	_check(world.get("explore_hud") == null or hud_markers.any(func(m): return str(m.label) == str(known.thing(pin).name)), "the HUD compass carries it")
	map.toggle_pin(at_px + Vector2(3, 2))
	_check(known.known("you", "pin").is_empty(), "clicking the pin again lifts it")
	var kept: String = map.toggle_pin(at_px)

	# The compass strip: always on screen, even in the lander, and Settings choose its marks.
	var hud = world.explore_hud
	hud.set_minimal(true)
	_check(hud._compass.is_visible_in_tree(), "the compass stays on screen in the lander")
	hud.set_minimal(false)
	var keep := MHGame.settings()
	var values := keep.duplicate(); values["compass_pins"] = false; values["compass_distance"] = false; MHGame.save_settings(values)
	var marks: Array = hud.compass_markers()
	_check(not marks.any(func(m): return str(m.label) == str(known.thing(kept).name)) and not hud._compass.show_distance, "Settings can take pins and distances off the compass")
	MHGame.save_settings(keep)
	_check(hud.compass_markers().any(func(m): return str(m.label) == str(known.thing(kept).name)), "and put them back")

	# Saving.
	var state: Dictionary = world.current_state()
	_check(state.has("known") and not str(state.known.fog).is_empty(), "the record is saved")
	var copy = load("res://scripts/known_things.gd").new()
	copy.setup(world, known.origin, known.half)
	copy.load_state(JSON.parse_string(JSON.stringify(state.known)))
	_check(copy.knows(id, "earth") and str(copy.thing(id).name) == "The Bowl" and copy.thing(kept).at.distance_to(known.thing(kept).at) < .01, "it loads back: places, who knows, names and pins")
	_check(absf(copy.seen_share() - known.seen_share()) < .0001, "and the fog")
	var next: String = copy.add_pin(Vector2.ZERO)
	_check(next != kept, "pin numbers carry on after a load")
	var old = load("res://scripts/known_things.gd").new()
	old.setup(world, known.origin, known.half)
	old.from_trail(PackedVector2Array([Vector2.ZERO, Vector2(0, -400)]))
	_check(old.seen_at(known.origin + Vector2(0, -400)) > .9, "an older save clears the fog along its trail")
	copy.free(); old.free()
	if failures == 0:
		print("Known things test passed: a dark Map that clears round you, places joining the record in sight, who knows what, your names, only known places named, pins from a click and on the compass, a compass always on screen with marks you choose, saving and older saves.")
	quit(1 if failures > 0 else 0)
