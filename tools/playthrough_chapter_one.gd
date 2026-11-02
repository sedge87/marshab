extends SceneTree

## A scripted play through chapter one (1 Nov), windowed, for looking at:
## each step drives the real paths (aiming at things and pressing E, holding
## E for a core) and saves a screenshot plus a log of what happened.
##   godot --path . --script res://tools/playthrough_chapter_one.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://playthrough/"
var log_lines: Array = []
var world: Node
var shot := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://playthrough_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	await _play()
	var file := FileAccess.open(out_dir + "log.txt", FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	print("\n".join(log_lines))
	quit()

func _note(text: String) -> void:
	log_lines.append(text)

func _shot(name: String) -> void:
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	paused = false
	for i in 10: await process_frame
	shot += 1
	root.get_texture().get_image().save_png(out_dir + "%02d_%s.png" % [shot, name])
	_note("shot %02d %s" % [shot, name])

## Face the camera at a point.
func _aim(point: Vector3) -> void:
	var player: Node3D = world.player
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var d := point - camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	(player.get_node("Head") as Node3D).rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 3: await physics_frame

## Stand a little way from a thing, face it and press E.
func _use(target: Node3D, from: Vector3, at_height := 1.0) -> bool:
	world.player.global_position = from
	world.player.velocity = Vector3.ZERO
	await _aim(target.global_position + Vector3.UP * at_height)
	var prompt := _prompt()
	var done: bool = world.player._use_looked_at_interactable("interact")
	_note("E on %s (prompt: %s) -> %s" % [target.name, prompt, done])
	return done

func _prompt() -> String:
	var hud: Node = world.explore_hud
	var bits: Array = []
	for label in hud.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text.length() > 0 and (label as Label).get_global_rect().position.y > 500: bits.append((label as Label).text)
	return " | ".join(bits.slice(0, 6))

func _toasts() -> String:
	var bits: Array = []
	var column: Node = world.explore_hud.get("_notices")
	for root_node in [world.builder.notice_column, column]:
		if root_node == null: continue
		for label in root_node.find_children("*", "Label", true, false):
			if (label as Label).is_visible_in_tree(): bits.append((label as Label).text)
	return " | ".join(bits.slice(0, 8))

func _key_e(down: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = down
	Input.parse_input_event(key)

func _hold_e(seconds: float) -> void:
	_key_e(true)
	await create_timer(seconds).timeout
	_key_e(false)

func _advance(hours: float) -> void:
	var sim: Object = world.builder.simulation()
	sim.hours_run = float(sim.hours_run) + hours
	await create_timer(.7).timeout   # the world ticks chapter one every half second

func _play() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "full"; MHGame.colony_name = "Playthrough"
	MHChapterOne.reset()   # the menu's new-game path
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	await create_timer(1.2).timeout
	await _shot("cabin_start")
	_note("chapter rules on: %s, crates left %d" % [MHChapterOne.on(), MHChapterOne.crates_left()])
	_note("stores: %s" % [MHChapterOne.sols_left(world.builder.simulation())])

	# ---- outside: the crates ----
	var crates: Array = world.get_children().filter(func(n): return str(n.name).begins_with("Crate_"))
	_note("crates by the landers: %d" % crates.size())
	if crates.is_empty(): return
	var first: Node3D = crates[0]
	var stand: Vector3 = first.global_position + Vector3(0, 0, 2.6)
	stand.y = MHSiteTerrain.height(stand.x, stand.z) + 1.0
	world.player.global_position = stand
	await _aim(first.global_position + Vector3.UP * .6)
	await _shot("looking_at_crate")
	_note("crate prompt: " + _prompt())
	for crate in crates:
		var spot: Vector3 = (crate as Node3D).global_position + Vector3(0, 0, 2.4)
		spot.y = MHSiteTerrain.height(spot.x, spot.z) + 1.0
		await _use(crate, spot, .6)
	await _shot("crates_unpacked")
	_note("after unpacking: crates left %d, has corer %s, feedstock %s" % [MHChapterOne.crates_left(), MHChapterOne.has_corer, MHChapterOne.feedstock_kg])
	_note("toasts: " + _toasts())

	# ---- the build bar's Unpacked tab ----
	var b: BuildController = world.builder
	b._toggle()
	for i in 5: await process_frame
	await _shot("site_plan_hull_kit")
	b._toggle()
	world._open_interior_build()
	for i in 5: await process_frame
	var ib: Node = world.interior_builder
	ib.call("_select_selector_group", "_unpacked")
	await _shot("interior_unpacked_tab")
	ib.exit()

	# ---- a small base: General Module, Workshop, airlock, solar ----
	var room := func(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
		var cells := []
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
		return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}
	b.zones = [room.call("general", 4, 0, 3, 3), room.call("engineering", 7, 0, 2, 3), {"kind": "airlock", "cells": [Vector2i(5, 3)], "door_direction": Vector2i(0, 1), "cost": 0}, {"kind": "solar", "cells": [Vector2i(2, 5)], "door_direction": Vector2i(0, 1), "cost": 0}]
	b._rebuild()
	var y: float = b.habitat_base_y
	for item in [["fabricator", Vector3(20.6, y, 1.0)], ["tool_bench", Vector3(23.0, y, 3.0)], ["crew_bunk", Vector3(12.5, y, 0.5)], ["air_recycler", Vector3(17.5, y, 0.5)]]:
		_note("%s: available %d, reason '%s'" % [item[0], MHChapterOne.available(item[0], b), MHChapterOne.item_reason(item[0], b)])
		var placed: bool = b.place_free_interior_equipment(item[0], item[1], 0.0, Vector2i(roundi(item[1].x / 3), roundi(item[1].z / 3)), b.free_interior_visual(item[0], item[1], 0.0), Vector3.UP)
		_note("  placed %s: %s (placed_interior %d)" % [item[0], placed, b.placed_interior.size()])
	for i in 10: await process_frame

	# ---- the fabricator ----
	var fab: Node3D = _placed("fabricator")
	_note("fabricator placed: %s" % (fab != null))
	if fab != null:
		await _use(fab, fab.global_position + Vector3(0, y + 1.0 - fab.global_position.y, 2.2), .9)
		await _shot("fabricator_screen")
		var screen: Node = root.find_children("*", "Control", true, false).filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("fabricator_screen.gd")).front() if true else null
		if screen != null:
			var start: Array = screen.find_children("*", "Button", true, false).filter(func(n): return (n as Button).text.to_lower().contains("start"))
			if not start.is_empty(): (start[0] as Button).pressed.emit()
			for i in 5: await process_frame
			await _shot("fabricator_job_started")
			_note("job: %s" % [MHChapterOne.job])
			if screen.has_method("_close"): screen.call("_close")
			else: screen.call("emit_signal", "closed")
		await _advance(24.0)
		await _shot("job_done")
		_note("after a day: job %s, toasts: %s" % [MHChapterOne.job, _toasts()])

	# ---- outside: GAR-Y's survey, then a core ----
	var ice_at := _rich_spot(b)
	_note("rich ice spot: %s (richness %.2f)" % [ice_at, b._ice_richness_at_point(Vector2(ice_at.x, ice_at.z))])
	world.player.global_position = Vector3(ice_at.x, MHSiteTerrain.height(ice_at.x, ice_at.z) + 1.0, ice_at.z + 1.2)
	world.player.rotation.y = 0.0
	(world.player.get_node("Head") as Node3D).rotation.x = -.5
	for i in 5: await physics_frame
	_note("corer before any survey: '%s'" % world.hand_corer.prompt())
	await _shot("unsurveyed_no_prompt")
	# GAR-Y's survey would leave readings here (its order takes game hours).
	var rover: Node = get_first_node_in_group("gar_y")
	if rover != null: (rover.ice_samples as Array).append(Vector3(ice_at.x, ice_at.z, .2))
	_note("corer after a reading here: '%s'" % world.hand_corer.prompt())
	await _shot("corer_ready")
	_key_e(true)
	await create_timer(1.0).timeout
	await _shot("corer_holding")
	await create_timer(1.4).timeout
	_key_e(false)
	await create_timer(.4).timeout
	await _shot("core_taken")
	_note("cores %d, ice step %s, toasts: %s" % [MHChapterOne.cores.size(), MHChapterOne.steps.has("ice"), _toasts()])

	# ---- skip to after the oxygen step, then the food step by hand ----
	var now := float(b.simulation().hours_run)
	for step in ["ice", "water", "oxygen"]: MHChapterOne.steps[step] = now
	for id in ["ice_drill", "water_reclaimer", "oxygen_generator"]: MHChapterOne.known[id] = "discovered"
	b.simulation().water_l = maxf(float(b.simulation().water_l), 200.0)
	await _hold_e(2.4)
	await create_timer(.4).timeout
	await _shot("soil_bagged")
	_note("soil after a core: %s, toasts: %s" % [MHChapterOne.soil, _toasts()])
	var bench: Node3D = _placed("tool_bench")
	_note("bench placed: %s" % (bench != null))
	if bench != null:
		world.player.global_position = bench.global_position + Vector3(0, y + 1.0 - bench.global_position.y, 1.6)
		await _aim(bench.global_position + Vector3.UP * .9)
		_note("bench prompt with the sample: " + _prompt())
		await _shot("bench_prompt")
		await _use(bench, world.player.global_position, .9)
		await _shot("bench_washed")
		_note("soil %s, water %.0f L, toasts: %s" % [MHChapterOne.soil, float(b.simulation().water_l), _toasts()])
		await _use(bench, world.player.global_position, .9)
		_note("soil %s" % MHChapterOne.soil)
		await _advance(25.0)
		await _shot("seedling")
		_note("food plans known: %s, toasts: %s" % [MHChapterOne.plan_known("grow_tray"), _toasts()])
	world.queue_free()
	for i in 5: await process_frame

func _placed(id: String) -> Node3D:
	for node in world.find_children("*", "", true, false):
		if node.has_meta("equipment_id") and str(node.get_meta("equipment_id")) == id and node is Node3D: return node
	return null

## Somewhere away from the base with ice good enough for a core.
func _rich_spot(b: BuildController) -> Vector3:
	var best := Vector3(40, 0, 40)
	var best_r := -1.0
	for x in range(-150, 151, 6):
		for z in range(-150, 151, 6):
			var p := Vector2(x, z)
			if p.distance_to(Vector2(world.lander.global_position.x, world.lander.global_position.z)) < 25.0: continue
			if p.distance_to(Vector2(15, 3)) < 20.0: continue
			var r: float = b._ice_richness_at_point(p)
			if r > best_r: best_r = r; best = Vector3(x, 0, z)
	return best
