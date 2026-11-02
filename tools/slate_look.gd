extends SceneTree

## Raises the slate in a new Survival game, windowed, and saves screenshots:
## the Log with some notices, the Map app, and the notice line after it's lowered.
##   godot --path . --script res://tools/slate_look.gd -- [out_dir]

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

var out_dir := "user://slate_look/"
var world: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://slate_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "full"; MHGame.colony_name = "Slate"
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	await create_timer(1.5).timeout
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	MHNotices.post("valid", "Core 3: ice found", "Rich ice 1.2 m down. The Ice Extractor goes within 7 m of it.", "map")
	MHNotices.post("warn", "Dust storm forecast", "A regional storm reaches the base in about 10 hours.", "site")
	await create_timer(.8).timeout
	await _shot("notice_line")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pda: MHPda = world.pda
	print("can open: ", pda.can_open())
	pda.open("log")
	await create_timer(1.0).timeout
	await _shot("slate_log")
	pda.screen.show_app("goals")
	await create_timer(.5).timeout
	await _shot("slate_goals")
	pda.screen.show_app("map")
	await create_timer(.8).timeout
	print("map lent: ", world.region_map.embedded if world.region_map != null else "no region map")
	await _shot("slate_map")
	# The wheel zooms in, at the middle of the lent map.
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var mid := Vector2(1600, 900) * .5 + Vector2(-90, 20)
	wheel.position = mid
	wheel.global_position = mid
	var span_before: float = world.region_map._span
	for i in 4:
		wheel.pressed = true
		Input.parse_input_event(wheel.duplicate())
		wheel.pressed = false   # a real wheel sends both
		Input.parse_input_event(wheel.duplicate())
		await process_frame
	print("wheel zoom: span ", span_before, " -> ", world.region_map._span)
	await create_timer(.3).timeout
	await _shot("slate_map_zoomed")
	# A click on the rail's first button (Map is 1, Log 2) lands through the 3D screen.
	# Where the Log button sits on the display (from the slate_map shot: Goals, Map, Log), and
	# where on the screen's own pixels that lands.
	var at := Vector2(430, 356)
	print("display ", at, " -> screen pixels ", pda._screen_point(at), "; Log button rect ", pda.screen._rail_buttons["log"].button.get_global_rect())
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await process_frame
	await create_timer(.4).timeout
	print("after click on Log: app = ", pda.screen.app)
	await _shot("slate_clicked")
	pda.close()
	await create_timer(.6).timeout
	print("after close, map back home: ", world.region_map != null and not world.region_map.embedded and world.region_map._frame.get_parent() != null)
	print("closed; mouse captured: ", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, ", frozen: ", world.player.get_meta("ui_freeze", false))
	await _shot("lowered")
	quit()

func _shot(name: String) -> void:
	for i in 6: await process_frame
	root.get_texture().get_image().save_png(out_dir + name + ".png")
