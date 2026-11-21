extends SceneTree

## 21 Nov: GAR-Y cycling an empty airlock by itself, through the 1.2 m
## bulkhead hatches: the inner hatch open, then the outer, then out.
##   godot --path . --resolution 1280x800 --script res://tools/gary_airlock_look.gd -- <out_dir>

func _room(kind: String, x0: int, w: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame._settings["gary_autonomy"] = true
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.time_scale = 0.0
	world.day_night.set_hour(10.5)
	var b: BuildController = world.builder
	b.zones = [_room("living", 0, 3), {"kind": "airlock", "cells": [Vector2i(1, 3)], "door_direction": Vector2i(0, 1), "cost": 1500}]
	b._rebuild()
	for i in 10: await process_frame
	var y := b.habitat_base_y
	var p: CharacterBody3D = world.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	p.global_position = Vector3(3.0, b._terrain_height(Vector3(3.0, 0, 22.0)) + 1.0, 22.0)
	var g = world.scout_rover
	g.global_position = Vector3(4.5, y + .2, 3.0)
	g._apart = 999.0
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.make_current()
	var inner: AirlockDoor
	var outer: AirlockDoor
	for d in get_nodes_in_group("airlock_door"):
		if d.door_label() == "INNER": inner = d
		if d.door_label() == "OUTER": outer = d
	# From the living quarters, looking at the inner hatch.
	cam.look_at_from_position(inner.global_position + Vector3(-1.6, 1.5, -3.4), inner.global_position + Vector3(0, .6, .5))
	var shots := 0
	for i in 60 * 70:
		await physics_frame
		if shots == 0 and inner.is_open() and g.global_position.distance_to(inner.global_position) < 1.3:
			await _shot(out + "gary_1_through_inner.png"); shots = 1
			# Now from outside, looking at the outer hatch.
			cam.look_at_from_position(outer.global_position + Vector3(2.4, 1.6, 3.6), outer.global_position + Vector3(0, .5, -.3))
		elif shots == 1 and outer.is_open() and g.global_position.distance_to(outer.global_position) < 1.6:
			await _shot(out + "gary_2_through_outer.png"); shots = 2
		elif shots == 2 and not g.in_airlock_trip():
			await _shot(out + "gary_3_out.png"); shots = 3
			break
	print("shots ", shots)
	quit()

func _shot(path: String) -> void:
	for i in 3: await process_frame
	root.get_texture().get_image().save_png(path)
