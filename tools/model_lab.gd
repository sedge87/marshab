extends SceneTree

## Model lab: photographs catalogue items one at a time in a furnished room,
## closed and with each of their actions (E, F, G) done, for reviewing the
## models and their moving parts. Nothing is saved.
##   godot --path . --script res://tools/model_lab.gd -- <out_dir> [id ...]
## Writes <out_dir>/<id>.png: the item closed, then after E, F and G (up to
## four tiles side by side). Without ids, every interior item.

var world: Node
var b: BuildController
var cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var ids: Array = args.slice(1)
	MHGame.site_id = "plains"; MHGame.save_directory = "user://model_lab"; MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	world.day_night.set_hour(13.0); world.day_night.frozen = true
	b = world.builder
	var cells := []
	for x in 4:
		for z in 3: cells.append(Vector2i(x, z))
	b.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}]
	b._rebuild()
	world.player.global_position = Vector3(4.5, b.habitat_base_y + .1, 6.5)
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	if world.scout_rover != null: world.scout_rover.queue_free()
	cam = Camera3D.new(); cam.fov = 38.0
	world.add_child(cam); cam.current = true
	if ids.is_empty():
		var all := EquipmentCatalog.entries()
		for id in all:
			var entry: Dictionary = all[id]
			if bool(entry.get("retired", false)) or str(entry.get("group", "")) == "exterior": continue
			ids.append(str(id))
	for id in ids: await _photograph(str(id), out)
	quit()

func _hide_ui() -> void:
	for layer in root.find_children("*", "CanvasLayer", true, false): (layer as CanvasLayer).visible = false

func _photograph(id: String, out: String) -> void:
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty(): return
	var size: Vector3 = b._free_interior_size(entry)
	var y := b.habitat_base_y
	var wall_z := -1.385
	var wall := str(entry.get("placement", "floor")) == "wall"
	var at := Vector3(4.5, y + float(entry.get("mount_height", 1.4)), wall_z) if wall else Vector3(4.5, y, wall_z + size.z * .5 + .06)
	# Placed for real, so the rig's state changes don't rebuild it away.
	var visual := b.free_interior_visual(id, at, PI)
	b.place_free_interior_equipment(id, at, PI, Vector2i(roundi(at.x / 3.0), roundi(at.z / 3.0)), visual, Vector3(0, 0, 1) if wall else Vector3.UP)
	var placement_id := str(b.placed_interior.back().placement_id)
	var rig: Node = null
	for node in b.furnishing.find_children("*", "Node", true, false):
		if node.has_method("interact_secondary") and node.has_method("interaction_prompt"): rig = node; break
	var s := maxf(size.x, maxf(size.y, size.z))
	var centre := at + Vector3(0, (0.0 if wall else size.y * .5), (size.z * .5 if wall else 0.0))
	cam.global_position = centre + Vector3(s * .75 + .25, s * .45 + .25, s * 1.55 + .7)
	cam.look_at(centre, Vector3.UP)
	var tiles: Array[Image] = []
	tiles.append(await _grab())
	if rig != null:
		for method in ["interact", "interact_secondary", "interact_tertiary"]:
			rig = _rig()
			if rig == null: break
			var prompt: Dictionary = rig.interaction_prompt()
			var key: String = {"interact": "primary", "interact_secondary": "secondary", "interact_tertiary": "tertiary"}[method]
			if str(prompt.get(key, "")).is_empty(): continue
			rig.call(method)
			for i in 40: await process_frame
			tiles.append(await _grab())
			rig = _rig()
			if rig != null: rig.call(method)
			for i in 30: await process_frame
	var sheet := Image.create(640 * tiles.size(), 360, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		tiles[i].resize(640, 360)
		sheet.blit_rect(tiles[i], Rect2i(0, 0, 640, 360), Vector2i(640 * i, 0))
	sheet.save_png(out.path_join(id + ".png"))
	b.remove_free_interior_equipment(placement_id)
	for i in 3: await process_frame

func _rig() -> Node:
	for node in b.furnishing.find_children("*", "Node", true, false):
		if node.has_method("interact_secondary") and node.has_method("interaction_prompt"): return node
	return null

func _grab() -> Image:
	for i in 6:
		_hide_ui()
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image
