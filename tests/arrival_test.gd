extends SceneTree

# The arrival story (docs/master-design.md §2, 7 Nov):
# - no landing map in a story game: the entry carries you near one of the
#   region's landing zones, onto ground with room for a base;
# - the descent's cameras mark up to three safe spots, spread apart, tagged;
# - the Map starts with what the cameras saw coming down; beyond it, an
#   opaque coarse survey;
# - ARDEN's touchdown brief exists, voiced;
# - the slate's Cargo app lists 12 pallets and 3 walkers, pallet 1 going from
#   seen to recovered.
# godot --headless --path . --script res://tests/arrival_test.gd
const MENU := preload("res://scripts/main_menu.gd")
const PICKER := preload("res://scripts/region_landing_picker.gd")
const DESCENT := preload("res://scripts/descent.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHChapterOne.reset()
	# Where the entry carries you.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var zones: Dictionary = MHSiteTerrain_meta()
	for i in 5:
		var at: Vector2 = MENU.entry_area(rng)
		var near := INF
		for id in zones: near = minf(near, at.distance_to(Vector2(float(zones[id].centre[0]), float(zones[id].centre[1]))))
		_check(near <= 501.0, "the entry lands near a zone (%.0f m)" % near)
		_check(str(PICKER.evaluate(at).level) == "green", "with plenty of room for a base")
	# The cameras' safe spots.
	var descent: Node3D = DESCENT.new()
	descent.centre = MENU.entry_area(rng)
	var hud := CanvasLayer.new()
	hud.add_child(Control.new())
	descent._hud = hud
	descent.add_child(hud)
	descent._find_safe_spots()
	_check(descent._safe.size() >= 2, "the cameras mark safe spots (%d)" % descent._safe.size())
	for i in descent._safe.size():
		for j in range(i + 1, descent._safe.size()):
			_check((descent._safe[i].at as Vector2).distance_to(descent._safe[j].at) >= 140.0, "spread apart")
	_check(descent._safe.all(func(s): return not str(s.tag).is_empty()), "each tagged (%s)" % ", ".join(descent._safe.map(func(s): return str(s.tag))))
	descent.marker = descent._safe[0].at
	_check(descent._on_safe() != "", "on a safe spot, the hint says so")
	descent.free()
	# The world: the map, ARDEN, the manifest.
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	var known: Node = world.known
	var here: Vector2 = Vector2(world.lander.global_position.x, world.lander.global_position.z) + known.origin
	_check(known.seen_at(here) > .9 and known.seen_at(here + Vector2(300, 0)) > .3, "the Map is clear round the landing (the descent's view)")
	_check(known.seen_at(here + Vector2(1500, 0)) < .01, "and dark further out")
	var fog: Image = known.fog_image()
	var far: Vector2 = here + Vector2(1500, 300)
	var cell: float = known.half * 2.0 / known.GRID
	var px := fog.get_pixel(int((far.x + known.half) / cell), int((far.y + known.half) / cell))
	_check(px.a > .99 and px.r > .02, "unexplored is opaque survey, not black (%s)" % px)
	var lines = JSON.parse_string(FileAccess.get_file_as_string("res://data/voice_lines.json"))
	_check((lines.habitat as Dictionary).has("lander_brief") and FileAccess.file_exists("res://assets/audio/voice/lander_brief_0.wav"), "ARDEN's touchdown brief is written and voiced")
	var screen: Control = world.pda.screen
	_check(screen.apps().has("cargo"), "the slate has a Cargo app")
	var data: Dictionary = screen._manifest_data()
	_check((data.pallets as Array).size() == 12 and (data.walkers as Array).size() == 3, "12 pallets and 3 walkers on the manifest")
	var first: Dictionary = data.pallets[0]
	_check(screen.cargo_state(first) == "seen", "pallet 1: seen (the orbiter's photo) at the start (%s)" % screen.cargo_state(first))
	world.storm_drop.pallet.open(false)
	await process_frame
	_check(screen.cargo_state(first) == "recovered", "opened: recovered")
	_check(screen.cargo_state(data.pallets[4]) == "missing", "the rest: no signal")
	_check(screen._cargo_page() != null, "the page draws")
	world.queue_free()
	await process_frame
	if failures == 0: print("Arrival test passed: the entry near a zone on good ground; the cameras' tagged safe spots; the Map clear round the landing and coarse survey beyond; ARDEN's brief; the Cargo manifest.")
	quit(1 if failures > 0 else 0)

func MHSiteTerrain_meta() -> Dictionary:
	var terrain := preload("res://scripts/site_terrain.gd")
	terrain.region_zone()
	return terrain.RegionTerrain.meta().get("zones", {})
