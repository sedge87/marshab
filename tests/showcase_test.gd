extends SceneTree

# Showcase mode (backlog 32): the shot list (orbit, masts or high shots, every
# room, a sol in 60 seconds, the story), its own camera with the game UI
# hidden and you frozen, the presenter's keys, room captions, and never saving.
# Run with: godot --headless --path . --script res://tests/showcase_test.gd
const SHOWCASE := preload("res://scripts/showcase.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.colony_name = "Kestrel Base"
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	var b: BuildController = world.builder
	var cells := []
	for x in range(10, 13):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones.append({"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600})
	b.zones.append({"kind": "galley", "cells": [Vector2i(13, 0), Vector2i(14, 0)], "door_direction": Vector2i(0, -1), "cost": 300})
	b.zones.append({"kind": "airlock", "cells": [Vector2i(9, 1)], "door_direction": Vector2i(-1, 0), "cost": 300})
	b._rebuild()
	var y := b.habitat_base_y
	for i in 3:
		var at := Vector3(29.0 + i * 1.6, y, 6.0)
		b.place_free_interior_equipment("crew_bunk", at, 0.0, Vector2i(10 + i, 2), b.free_interior_visual("crew_bunk", at, 0.0))
	b.simulation().invalidate()

	# Start it.
	MHGame.showcase = true
	var show = SHOWCASE.new()
	world.add_child(show)
	world.showcase = show
	show.setup(world)
	await process_frame
	var kinds: Array = show._shots.map(func(s): return str(s.kind))
	_check(kinds[0] == "orbit" and kinds.has("timelapse") and kinds[-1] == "story", "orbit first, a sol in 60 seconds, the story last (%s)" % [kinds])
	_check(kinds.count("room") == 2, "every room but the airlock gets a walk-through (%d)" % kinds.count("room"))
	_check(kinds.count("high") == 3, "with no camera masts, three high shots")
	_check(get_root().get_viewport().get_camera_3d() == show.camera, "Showcase has its own camera")
	_check(not world.explore_hud.visible and bool(world.player.get_meta("ui_freeze", false)), "the game's HUD is hidden and you're frozen")
	_check(show._title_card.visible, "the title card shows over the opening orbit")

	# Rooms: captions and the (invisible) player standing in them.
	var living: int = kinds.find("room")
	show._begin(living)
	_check(show._caption.text.contains("°C") and show._caption.text.contains("Crew Bunk"), "room captions say what's there (%s)" % show._caption.text)
	_check(b.is_inside(world.player.global_position), "the player stands in the room, so its lights come on")
	# The time-lapse runs the clock at 20x, and only for that shot.
	show._begin(kinds.find("timelapse"))
	_check(is_equal_approx(world.day_night.time_scale, 20.0), "a sol in 60 seconds runs the clock 20x")
	show._begin(kinds.find("story"))
	_check(is_equal_approx(world.day_night.time_scale, 1.0) and show._story.visible and show._story.get_child_count() > 0, "then normal time, and the story card")

	# The presenter's keys.
	var at: int = show._index
	show._input(_key(KEY_SPACE))
	_check(show.paused, "Space pauses the tour")
	show._input(_key(KEY_SPACE))
	show._input(_key(KEY_RIGHT))
	_check(show._index == (at + 1) % show._shots.size(), "→ skips ahead (and loops)")
	show._input(_key(KEY_LEFT))
	_check(show._index == at, "← goes back")
	# F: a free camera to fly round, then back to the tour.
	show._input(_key(KEY_F))
	_check(show.free, "F takes the camera")
	var before: Vector3 = show.camera.global_position
	show._yaw = 0.0
	show._pitch = 0.0
	show.camera.global_position = before
	show._fly(1.0)
	_check(show.camera.global_position.y >= world.builder._terrain_height(show.camera.global_position) + .39, "the free camera stays above the ground")
	show._input(_key(KEY_SPACE))
	_check(not show.paused, "Space doesn't pause while flying")
	show._input(_key(KEY_F))
	_check(not show.free and show._index == at, "F again hands back to the tour where it was")

	# Never saves.
	var path := ProjectSettings.globalize_path(MHGame._save_path(3, "free_play"))
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	_check(MHGame.save_habitat(3, world.current_state(), "free_play") == OK and not FileAccess.file_exists(path), "a showcase never writes a save")
	MHGame.showcase = false

	if failures == 0:
		print("Tour test passed: shot list, own camera and hidden HUD, room captions, time-lapse, story, keys, the free camera, never saving.")
	quit(1 if failures > 0 else 0)
