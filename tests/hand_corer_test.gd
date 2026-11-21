extends SceneTree

# Run with: godot --headless --path . --script res://tests/hand_corer_test.gd
# Phase 6: the MC-01 hand corer worked by hand (scripts/hand_corer.gd): plant,
# strokes, the regolith shoe skidding on ice, the ice shoe, open, draw, cap;
# rushing the strokes gives a smeared (partial) core.

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region_plains"; MHGame.game_mode = "survival"
	MHGame.base_site = {}
	MHGame.pending_save_state = {}
	MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 30: await process_frame
	var corer = world.hand_corer
	MHChapterOne.has_corer = true
	var at := Vector3(80, 0, 80)
	at.y = MHCaves.ground_y(at)
	world.player.global_position = at + Vector3(0, .1, 1.2)
	# Ice ground: a reading rich enough to be ice.
	corer._plant(at)
	corer._core = {"x": at.x, "z": at.z, "dry": false, "good": true, "purity": .5, "depth_m": 1.0}
	_check(corer.stage == "drive" and corer._tool != null and corer._tool.visible, "E plants the MC-01")
	_check(corer._rig != null and corer._rig._collar != null and corer._rig._sleeve != null, "its moving parts are found")
	for i in 6:
		corer._clock += 1.0
		corer._stroke()
	_check(corer._stalled and corer._strokes == 3, "the regolith shoe skids on the ice halfway (%d strokes)" % corer._strokes)
	corer._swap_shoe()
	_check(corer.ice_shoe and not corer._stalled, "R swaps in the ice shoe")
	for i in 3:
		corer._clock += 1.0
		corer._stroke()
	_check(corer.stage == "open", "full depth: open the head")
	corer.stage = "draw"
	corer._draw = 1.0
	corer.stage = "cap"
	var before: int = MHChapterOne.cores.size()
	corer._cap()
	var core: Dictionary = MHChapterOne.cores.back()
	_check(MHChapterOne.cores.size() == before + 1 and bool(core.good) and not bool(core.partial), "a clean ice core (%s)" % str(core))
	corer._abandon()
	# Rushed: strokes quicker than a stroke takes smear the layers.
	corer._plant(at)
	corer._core = {"x": at.x, "z": at.z, "dry": true, "good": false, "purity": .02, "depth_m": 0.0}
	for i in 6:
		corer._clock += .1
		corer._stroke()
	corer.stage = "cap"
	corer._cap()
	core = MHChapterOne.cores.back()
	_check(bool(core.partial), "rushing gives a partial read")
	# Walking off leaves it.
	corer._plant(at)
	world.player.global_position = at + Vector3(10, 0, 0)
	corer._process(.016)
	_check(corer.stage == "" and not corer._tool.visible, "walk away and it's left")
	print("Hand corer test %s." % ("passed" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures > 0 else 0)
