extends SceneTree

## Screenshots of step 3c, windowed: Walker 1 stalled with its lamp, its
## tracks, the Site plan's first lesson (two parts on the bar), the module
## being lowered, the module down with its socket and the solar blanket, and
## the fit-out kit in the Interior view.
##   godot --path . --script res://tools/walker_look.gd -- [out_dir]

const RULES := preload("res://scripts/build_rules.gd")
var out_dir := "user://walker_look/"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args(): out_dir = arg.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MHGame.save_directory = "user://walker_look_saves"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF; MHGame.tutorial_mode = "hints"; MHGame.colony_name = "Look"
	MHChapterOne.reset()
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	MHGame.sol_hour = 16.5
	world.day_night.call("_apply", 0.0) if world.day_night.has_method("_apply") else null
	await create_timer(2.0).timeout
	if world.pda.is_open: world.pda.close()
	var walker: Node3D = world.walker
	var player: Node3D = world.player
	var lander: Vector3 = world.lander.global_position

	# Stalled, its lamp on.
	_stand(player, walker.global_position + walker.global_basis.x * 22.0 + walker.global_basis.z * -14.0, walker.global_position + Vector3(0, 3, 0))
	await _blink_on(walker)
	await _shot("0_walker_stalled")
	_stand(player, walker.to_global(walker.FORK) + walker.global_basis.x * 3.0 + Vector3(0, .2, 0), walker.to_global(walker.FORK))
	await _blink_on(walker)
	await _shot("1_jammed_wheel")

	# The tracks.
	world.lifepod.walker_night()
	var marks: Array = world.get_tree().get_nodes_in_group("walker_tracks")
	var near: Node3D = marks[2]
	var far: Node3D = marks[8]
	_stand(player, near.global_position - (far.global_position - near.global_position).normalized() * 6.0 + Vector3(4, 0, 0), far.global_position)
	await create_timer(1.0).timeout
	await _shot("2_tracks")

	# Home and parked.
	walker.dig_for(10.0)
	walker.global_position = walker.home + Vector3(0, 0, 0)
	walker._settle()
	walker._process(.1)
	while walker.state != "parked": walker._process(.5)
	_stand(player, lander + (walker.global_position - lander).normalized() * 12.0 + Vector3(10, 0, 6), walker.global_position + Vector3(0, 3, 0))
	await create_timer(1.0).timeout
	await _shot("3_parked_by_lander")

	# The Site plan's first lesson.
	var builder: Node = world.builder
	builder._toggle()
	await create_timer(1.2).timeout
	await _shot("4_site_plan_bar")
	var cells := _module_spot(builder, lander)
	_place(builder, cells)
	builder.kind = "airlock"
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			builder.airlock_direction = d
			if builder._invalid_reason([c + d]).is_empty():
				_place(builder, [c + d])
				break
		if builder.zones.size() >= 2: break
	await create_timer(.8).timeout
	await _shot("5_site_plan_placed")
	builder._toggle()

	# Carried and lowered.
	while walker.state == "carrying": walker._process(.5)
	var view := walker.global_position + walker.global_basis.x * 24.0 + Vector3(0, 0, 10)
	_stand(player, view, walker.global_position + Vector3(0, 3, 0))
	for i in 40: walker._process(.1)
	await create_timer(.6).timeout
	await _shot("6_lowering")
	while walker.state == "lowering": walker._process(.5)
	await create_timer(1.0).timeout
	var life: Node = world.module_life
	var socket: Vector3 = life.socket_spot()
	var out := Vector3(socket.x - life._centre().x, 0, socket.z - life._centre().z).normalized()
	_stand(player, socket + out * 14.0 + out.cross(Vector3.UP) * 6.0, life._centre() + Vector3(0, 1, 0))
	await create_timer(1.0).timeout
	await _shot("7_module_down")

	# The blanket at the socket.
	var pack: Node = world.drop_field.sites.power.pack
	pack.where = "ground"
	pack.lay_out("lander")
	pack.interact()
	player.global_position = socket + out * 3.0
	pack.put_down()
	pack.interact()
	await create_timer(1.5).timeout
	_stand(player, socket + out * 9.0 + out.cross(Vector3.UP) * 4.0, socket + out * 3.0 + Vector3(0, -1, 0))
	await create_timer(.8).timeout
	await _shot("8_blanket_at_socket")

	# Inside: the kit.
	var inside: Vector2i = cells[2]
	_stand(player, Vector3(inside.x * builder.CELL, builder.habitat_base_y + .1, inside.y * builder.CELL), Vector3(cells[0].x * builder.CELL, builder.habitat_base_y + 1.2, cells[0].y * builder.CELL))
	await create_timer(1.0).timeout
	await _shot("9_inside_module")
	world._open_interior_build()
	await create_timer(1.2).timeout
	await _shot("10_fit_out_kit")
	quit()

func _stand(player: Node3D, at: Vector3, look: Vector3) -> void:
	var ground := preload("res://scripts/site_terrain.gd").height(at.x, at.z)
	player.global_position = Vector3(at.x, maxf(at.y, ground) + .1, at.z)
	player.velocity = Vector3.ZERO
	var to := look - (player.global_position + Vector3(0, 1.6, 0))
	player.rotation.y = atan2(-to.x, -to.z)
	var head := player.get_node_or_null("Head") as Node3D
	if head != null: head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

func _blink_on(walker: Node) -> void:
	for i in 60:
		await process_frame
		if walker._light.visible: return

func _module_spot(builder: Node, lander: Vector3) -> Array:
	builder.kind = "general"
	for r in [30.0, 42.0, 55.0, 70.0]:
		for step in 16:
			var a := step * TAU / 16.0
			var p: Vector3 = lander + Vector3(sin(a), 0, cos(a)) * float(r)
			var cell := Vector2i(roundi(p.x / builder.CELL), roundi(p.z / builder.CELL))
			var cells: Array = builder._cells(cell, cell)
			if builder._invalid_reason(cells).is_empty(): return cells
	return []

func _place(builder: Node, cells: Array) -> void:
	if builder.zones.is_empty(): builder.habitat_base_y = builder._proposed_base_y(cells)
	var zone := {"kind": builder.kind, "cells": cells, "door_direction": builder.airlock_direction, "cost": builder._zone_cost(cells)}
	RULES.placed(builder, zone)
	builder.zones.append(zone)
	builder._history.append({"type": "zone", "zone": zone})
	builder._rebuild()

func _shot(shot_name: String) -> void:
	var world: Node = root.get_node_or_null("MarsWorld")
	for w in root.get_children(): if w.get("pda") != null and w.pda.is_open: w.pda.close()
	await create_timer(.4).timeout
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir + shot_name + ".png")
	print("shot ", shot_name)
