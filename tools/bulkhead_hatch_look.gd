extends SceneTree

## 21 Nov: the bulkhead hatches and GAR-Y's rover flap in a small base:
## a room hatch on its hold-back, the airlock's inner and outer hatches shut
## and open, the flap open.
##   godot --path . --resolution 1280x800 --script res://tools/bulkhead_hatch_look.gd -- <out_dir>

func _room(kind: String, x0: int, w: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame._settings["gary_autonomy"] = false
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.time_scale = 0.0
	world.day_night.set_hour(10.5)
	var b: BuildController = world.builder
	b.zones = [_room("living", 0, 3), _room("galley", 3, 3), {"kind": "airlock", "cells": [Vector2i(1, 3)], "door_direction": Vector2i(0, 1), "cost": 1500}]
	b._rebuild()
	b.place_interior_door(Vector2i(2, 1), Vector2i(1, 0))
	for i in 10: await process_frame
	var y := b.habitat_base_y
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.visible = false
	world.player.global_position = Vector3(40, y + 5, 40)
	var g: Node3D = world.scout_rover
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.global_position = Vector3(40, y, 40)
	for hud in ["hud", "explore_hud"]:
		var h = world.get(hud)
		if h is CanvasItem: h.visible = false
		elif h is CanvasLayer: h.visible = false
	var cam := Camera3D.new()
	cam.fov = 62
	root.add_child(cam)
	cam.make_current()
	var doors := {}
	for d in get_nodes_in_group("airlock_door"): doors[d.door_label()] = d
	# 1. The room hatch, standing open between the living quarters and galley.
	cam.look_at_from_position(Vector3(1.6, y + 1.65, 1.2), Vector3(7.5, y + 1.0, 3.0))
	await _shot(out + "hatch_room_open.png")
	# 2. The airlock's inner hatch from the living quarters, shut, with the flap.
	var inner: Node3D = doors.INNER
	var face := inner.global_transform.basis.z
	var side := 1.0 if b.is_inside(inner.global_position + face * 1.5 + Vector3.UP) and b._zone_at_point(Vector2(inner.global_position.x + face.x * 1.5, inner.global_position.z + face.z * 1.5)).get("kind", "") != "airlock" else -1.0
	cam.look_at_from_position(inner.global_position + face * side * 3.2 + Vector3(-1.0, 1.6, 0), inner.global_position + Vector3(0, 1.0, 0))
	await _shot(out + "hatch_inner_shut.png")
	# 3. The outer hatch from outside, shut.
	var outer: Node3D = doors.OUTER
	var oface := outer.global_transform.basis.z
	var oside := -1.0 if b.is_inside(outer.global_position + oface * 1.5 + Vector3.UP) else 1.0
	cam.look_at_from_position(outer.global_position + oface * oside * 4.0 + Vector3(1.6, 1.5, 0), outer.global_position + Vector3(0, 1.0, 0))
	await _shot(out + "hatch_outer_shut.png")
	# 4. Open, with GAR-Y's flap open on the outside face.
	outer.toggle()
	outer.set_flap(int(oside), true)
	for i in 90: await process_frame
	await _shot(out + "hatch_outer_open_flap.png")
	quit()

func _shot(path: String) -> void:
	for i in 12: await process_frame
	root.get_texture().get_image().save_png(path)
