extends SceneTree

## UI sweep (1 Nov): opens each screen at several window sizes, saves a
## screenshot of each, and lists visible controls that run off the screen or
## overlap another panel. Run windowed (it needs a renderer):
##   godot --path . --script res://tools/ui_sweep.gd -- [out_dir] [WxH ...]
## Default sizes: 1920x1080, 1280x720, 1280x1024 (5:4), 2560x1080 (21:9).

var out_dir := "user://ui_sweep/"
var report: Array = []
var world: Node

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sizes: Array = []
	for arg in args:
		if "x" in arg and arg.split("x").size() == 2 and arg.split("x")[0].is_valid_int(): sizes.append(Vector2i(int(arg.split("x")[0]), int(arg.split("x")[1])))
		elif not arg.is_empty(): out_dir = arg.trim_suffix("/") + "/"
	if sizes.is_empty(): sizes = [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 1024), Vector2i(2560, 1080)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://ui_sweep_saves"
	for size in sizes:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		root.size = size
		for i in 10: await process_frame
		await _menus(size)
		await _game(size)
	var file := FileAccess.open(out_dir + "report.txt", FileAccess.WRITE)
	file.store_string("\n".join(report))
	print("\n".join(report))
	print("UI sweep written to ", ProjectSettings.globalize_path(out_dir))
	quit()

func _shot(size: Vector2i, name: String) -> void:
	# First-time tip cards would hide the screen under them.
	for card in get_nodes_in_group("feature_hint"): card.queue_free()
	paused = false
	for i in 8: await process_frame
	var tag := "%dx%d_%s" % [size.x, size.y, name]
	root.get_texture().get_image().save_png(out_dir + tag + ".png")
	_check_layout(tag)

## Off-screen and overlapping controls in what's showing now.
func _check_layout(tag: String) -> void:
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var panels: Array = []
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x < 2.0 or control.size.y < 2.0: continue
		if _clipped(control): continue
		var rect := control.get_global_rect()
		var parent := control.get_parent() as Control
		var parent_off := parent != null and parent.is_visible_in_tree() and not view.grow(2.0).encloses(parent.get_global_rect())
		if not view.grow(2.0).encloses(rect) and not parent_off and rect.intersects(view.grow(400.0)):
			report.append("%s  OFF-SCREEN  %s  %s" % [tag, _path(control), rect])
		if control is PanelContainer and control.mouse_filter != Control.MOUSE_FILTER_IGNORE or (control is PanelContainer and control.size.x < view.size.x * .9): panels.append(control)
	for i in panels.size():
		for j in range(i + 1, panels.size()):
			var a: Control = panels[i]
			var b: Control = panels[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if a.get_viewport() != b.get_viewport(): continue
			var overlap := a.get_global_rect().intersection(b.get_global_rect())
			if overlap.size.x > 6.0 and overlap.size.y > 6.0:
				report.append("%s  OVERLAP  %s  /  %s  (%s)" % [tag, _path(a), _path(b), overlap.size])

func _clipped(control: Control) -> bool:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer or (node is Control and (node as Control).clip_contents): return true
		if node is SubViewport: return true
		node = node.get_parent()
	return false

func _path(control: Control) -> String:
	var parts: Array = []
	var node: Node = control
	for i in 4:
		if node == null: break
		var text := ""
		if node is Label: text = "\"" + (node as Label).text.left(24) + "\""
		elif node is Button: text = "\"" + (node as Button).text.left(24) + "\""
		parts.push_front(node.get_class() + text)
		node = node.get_parent()
	return "/".join(parts)

func _menus(size: Vector2i) -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	for screen in ["title", "site", "colony", "rules", "landing", "saves"]:
		menu.show_screen(screen)
		await _shot(size, "menu_" + screen)
	MHGame.set_mode("custom")
	menu.show_screen("rules")
	await _shot(size, "menu_rules_custom")
	MHGame.set_mode("survival")
	menu.queue_free()
	await process_frame

func _game(size: Vector2i) -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "full"
	MHChapterOne.reset()   # as the menu does for a new game
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	await create_timer(1.0).timeout   # the intro letterbox slides away in real time
	await _shot(size, "game_cabin")
	for crate in world.get_children().filter(func(n): return str(n.name).begins_with("Crate_")): crate.interact(world.player)
	var b: BuildController = world.builder
	b.zones = [_room("general", 4, 0, 3, 3), _room("engineering", 7, 0, 2, 3), {"kind": "airlock", "cells": [Vector2i(5, 3)], "door_direction": Vector2i(0, 1), "cost": 0}, {"kind": "solar", "cells": [Vector2i(2, 5)], "door_direction": Vector2i(0, 1), "cost": 0}]
	b._rebuild()
	var y: float = b.habitat_base_y
	for item in [["crew_bunk", Vector3(13.0, y, 1.0)], ["fabricator", Vector3(22.5, y, 4.0)]]:
		b.place_free_interior_equipment(item[0], item[1], 0.0, Vector2i(roundi(item[1].x / 3), roundi(item[1].z / 3)), b.free_interior_visual(item[0], item[1], 0.0), Vector3.UP)
	world.player.global_position = Vector3(10.0, MHSiteTerrain.height(10.0, 14.0) + 1.0, 14.0)
	await _shot(size, "game_outside")
	world.player.global_position = Vector3(13.5, y + .2, 4.5)
	await _shot(size, "game_inside")
	b._toggle()
	for category in ["rooms", "power"]:
		b.category = category; b._refresh_catalogue()
		await _shot(size, "plan_" + category)
	b._toggle()
	for i in 5: await process_frame
	world._open_interior_build()
	await _shot(size, "furnish")
	world.interior_builder.exit()
	for i in 5: await process_frame
	world.open_fabricator()
	await _shot(size, "fabricator")
	if world.monitor != null: world.monitor._close()
	world._open_mission_control()
	await _shot(size, "mission_control")
	if world.mission_control != null: world.mission_control._close()
	world.open_monitor()
	await _shot(size, "monitor")
	if world.monitor != null: world.monitor._close()
	world._show_pause()
	await _shot(size, "pause")
	world._close_pause()
	world.queue_free()
	for i in 5: await process_frame

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
