extends SceneTree

## Gameplay trailer shots, HUD and all (22 Oct, after the reference trailer).
## Record one shot with Godot's movie writer (1080p needs override.cfg):
##   godot --path . --write-movie out/<shot>.avi --fixed-fps 30 \
##         --script res://tools/trailer_gameplay.gd -- <shot>
## Drives the real UI: mouse warps and clicks in the site plan, crosshair
## placement in furnishing, door cycling, overlays. WARMUP frames come first
## (trim them in the edit).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
const WARMUP := 45
const FPS := 30.0

var world: Node
var menu: Node
var b: BuildController
var p: CharacterBody3D
var o := Vector3.ZERO   # base origin (world) for prebuilt bases

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var shot: String = args[0] if not args.is_empty() else "siteplan"
	await call(shot)
	quit()

# ---------- helpers ----------

func _frames(seconds: float) -> void:
	for i in int(seconds * FPS): await process_frame

func _warm() -> void:
	for i in WARMUP: await process_frame

func _new_world(site := "plains", mode := "survival", hour := 10.0, keep_lander := false) -> void:
	MHGame.site_id = site; MHGame.game_mode = mode; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	b = world.builder
	p = world.player
	world.day_night.set_hour(hour); world.day_night.frozen = true
	if not keep_lander:
		world.lander.set_hatch(true)
		# Out of the way of the trailer base (x 10–35 m, z −8–22 m), facing it.
		world.lander.place_at(Vector2(-8, -14))
		world.lander.rotation.y = atan2(-(22.0 + 8.0), -(0.0 + 14.0)) + PI

func _mouse(at: Vector2) -> void:
	root.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at; motion.global_position = at
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)

func _button(at: Vector2, pressed: bool, index := MOUSE_BUTTON_LEFT) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = index; click.pressed = pressed
	click.position = at; click.global_position = at
	Input.parse_input_event(click)

func _key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code; key.physical_keycode = code; key.pressed = pressed; key.shift_pressed = shift
		Input.parse_input_event(key)

func _cell_screen(cell: Vector2i) -> Vector2:
	return b.camera.unproject_position(Vector3(cell.x * 3.0, b.habitat_base_y, cell.y * 3.0))

## Drag out a zone in the site plan like a player: press, sweep, release.
func _drag(kind: String, from: Vector2i, to: Vector2i, seconds := 1.0) -> void:
	b.kind = kind
	b._refresh_catalogue()
	_mouse(_cell_screen(from))
	await _frames(0.25)
	_button(_cell_screen(from), true)
	var frames := int(seconds * FPS)
	for i in frames:
		var t := float(i + 1) / frames
		var c := Vector2(from).lerp(Vector2(to), t)
		_mouse(_cell_screen(Vector2i(roundi(c.x), roundi(c.y))) if t >= 1.0 else b.camera.unproject_position(Vector3(c.x * 3.0, b.habitat_base_y, c.y * 3.0)))
		await process_frame
	_button(_cell_screen(to), false)
	await _frames(0.35)

func _walk(from: Vector3, to: Vector3, yaw_from: float, yaw_to: float, seconds: float, pitch := 0.0) -> void:
	var head := p.get_node("Head") as Node3D
	var frames := int(seconds * FPS)
	for i in frames:
		var t: float = float(i) / float(maxi(1, frames - 1))
		var e: float = t * t * (3.0 - 2.0 * t) * .3 + t * .7
		p.global_position = from.lerp(to, e)
		p.rotation.y = lerp_angle(yaw_from, yaw_to, e)
		head.rotation.x = deg_to_rad(pitch)
		await process_frame

func _yaw_at(from: Vector3, target: Vector3) -> float:
	var d := target - from
	return atan2(-d.x, -d.z)

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _put(id: String, at: Vector3, yaw: float, normal := Vector3.UP) -> Node3D:
	var v := b.free_interior_visual(id, at, yaw)
	b.place_free_interior_equipment(id, at, yaw, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), v, normal)
	return v

## A furnished base south-east of the origin, with an airlock facing south.
func _base(furnish := true) -> void:
	b.zones = [_room("living", 4, -2, 3, 2), _room("galley", 7, -2, 3, 2), _room("medical", 10, -2, 2, 2),
		_room("life_support", 4, 0, 3, 2), _room("engineering", 7, 0, 3, 2), _room("hydroponics", 10, 0, 2, 2),
		{"kind": "airlock", "cells": [Vector2i(8, 2)], "door_direction": Vector2i(0, 1), "cost": 0}]
	for i in 6: b.zones.append({"kind": "solar", "cells": [Vector2i(3 + (i % 3) * 2, 5 + (i / 3) * 2)], "door_direction": Vector2i(0, 1), "cost": 0})
	b._rebuild()
	for door in [[Vector2i(6, -1), Vector2i(1, 0)], [Vector2i(9, -1), Vector2i(1, 0)], [Vector2i(8, -1), Vector2i(0, 1)], [Vector2i(5, -1), Vector2i(0, 1)], [Vector2i(9, 1), Vector2i(1, 0)]]:
		b.place_interior_door(door[0], door[1])
	if not furnish: return
	var y := b.habitat_base_y
	# Galley x 19.5..28.5, z -7.5..-1.5
	_put("galley_table_set", Vector3(24.0, y, -4.2), 0.0)
	_put("galley_oven", Vector3(21.0, y, -6.9), PI)
	_put("galley_freezer", Vector3(22.1, y, -6.9), PI)
	_put("galley_rehydration_station", Vector3(23.2, y, -7.0), PI)
	_put("plant_pot", Vector3(27.9, y, -6.9), 0.0)
	# Living x 10.5..19.5
	_put("crew_bunk", Vector3(11.6, y, -6.6), PI)
	_put("crew_bunk", Vector3(14.6, y, -6.6), PI)
	_put("integrated_mess_booth", Vector3(15.5, y, -3.6), 0.0)
	# Medical x 28.5..34.5
	_put("medical_exam_cot", Vector3(31.5, y, -6.4), PI)
	_put("iv_drip_stand", Vector3(30.0, y, -6.6), 0.0)
	_put("crew_vitals_monitor", Vector3(32.8, y + 1.6, -7.37), PI, Vector3(0, 0, 1))
	# Hydroponics x 28.5..34.5, z -1.5..4.5
	for i in 3: _put("grow_tray", Vector3(29.8 + i * 1.9, y, 0.2), 0.0)
	# Engineering
	_put("battery_bank", Vector3(20.5, y, 3.8), 0.0)
	_put("battery_bank", Vector3(21.6, y, 3.8), 0.0)

func _door(label: String) -> Node:
	for d in world.find_children("*", "Node3D", true, false):
		if d.is_in_group("airlock_door") and str(d.door_label()) == label: return d
	return null

# ---------- menu shots ----------

func _menu() -> void:
	menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame

func title() -> void:
	await _menu()
	await _warm()
	await _frames(4.0)

func sites() -> void:
	MHGame.colony_name = "Habitat One"
	await _menu()
	menu.show_screen("site")
	await _warm()
	for id in ["plains", "ridge", "crater", "ice"]:
		menu._choose_site(id)
		await _frames(1.3)

func landing() -> void:
	MHGame.colony_name = "Habitat One"; MHGame.site_id = "plains"
	await _menu()
	menu.show_screen("landing")
	await _warm()
	var picker: Control = null
	for c in menu.find_children("*", "Control", true, false):
		if c.get_script() == PICKER: picker = c
	var start: Vector2 = PICKER.suggested() + Vector2(-30, 20)
	var goal: Vector2 = PICKER.suggested()
	for i in int(3.0 * FPS):
		var t := float(i) / (3.0 * FPS)
		if picker != null and i % 2 == 0: picker.set_target(start.lerp(goal, t * t * (3 - 2 * t)))
		await process_frame
	await _frames(1.0)

# ---------- in-world shots ----------

func lander() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	b = world.builder; p = world.player
	world.day_night.set_hour(9.0); world.day_night.frozen = true
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var lander: Node3D = world.lander
	var start: Dictionary = lander.cabin_start()
	p.global_position = start.position; p.rotation.y = float(start.yaw)
	await _warm()
	await _frames(1.0)
	lander.set_hatch(true, true)
	await _frames(1.6)
	var out: Vector3 = lander.to_global(Vector3(0, 0, -9.0))
	out.y = MHSiteTerrain.height(out.x, out.z) + 1.0
	await _walk(p.global_position, out, float(start.yaw), float(start.yaw) + 0.25, 4.0, -6.0)
	await _frames(1.2)

func siteplan() -> void:
	await _new_world("plains", "survival", 11.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(24, MHSiteTerrain.height(24, 12) + 1.2, 12)
	b._toggle()
	b.pivot.position = Vector3(23, 0, 5)
	b.zoom = 30.0; b._zoom()
	await _warm()
	await _drag("living", Vector2i(5, -2), Vector2i(7, -1), 0.9)
	await _drag("galley", Vector2i(8, -2), Vector2i(10, -1), 0.8)
	await _drag("life_support", Vector2i(5, 0), Vector2i(7, 1), 0.8)
	await _drag("engineering", Vector2i(8, 0), Vector2i(10, 1), 0.8)
	b.airlock_direction = Vector2i(0, 1)
	await _drag("airlock", Vector2i(9, 2), Vector2i(9, 2), 0.3)
	_mouse(Vector2(1240, 300))
	await _frames(1.2)

func power() -> void:
	await _new_world("plains", "survival", 11.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base(false)
	b._toggle()
	var deposit: Dictionary = MHGame.site().ice_deposits[0]
	b.pivot.position = Vector3(24, 0, 10)
	b.zoom = 36.0; b._zoom()
	await _warm()
	for cell in [Vector2i(9, 5), Vector2i(11, 5), Vector2i(9, 7)]:
		await _drag("solar", cell, cell, 0.25)
	# Ice: pan to the deposit and place a drill on the richest ground.
	var ice := Vector3(float(deposit.x), 0, float(deposit.z))
	for i in int(1.4 * FPS):
		b.pivot.position = b.pivot.position.lerp(ice, 0.06)
		await process_frame
	b.kind = "ice_extractor"; b._refresh_catalogue()
	var cell := Vector2i(roundi((ice.x - 3.0) / 3.0), roundi(ice.z / 3.0))
	for i in int(1.2 * FPS):
		_mouse(_cell_screen(cell + Vector2i(roundi(sin(i * .08) * 2.0), 0)))
		await process_frame
	await _drag("ice_extractor", cell, cell, 0.2)
	await _frames(1.0)

func airlock() -> void:
	await _new_world("plains", "survival", 15.5)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base(true)
	await process_frame
	var outer := _door("OUTER")
	var inner := _door("INNER")
	var outside := Vector3(24, 0, 12); outside.y = b.habitat_base_y + 1.0
	var at_outer := Vector3(24, b.habitat_base_y + 1.0, 10.8)
	var in_lock := Vector3(24, b.habitat_base_y + 1.0, 6.0)
	var past_inner := Vector3(24, b.habitat_base_y + 1.0, 2.2)
	p.global_position = outside; p.rotation.y = 0.0
	await _warm()
	await _walk(outside, at_outer, 0.0, 0.0, 1.6)
	if outer: outer.toggle()
	await _frames(1.4)
	await _walk(at_outer, in_lock, 0.0, 0.0, 1.3)
	if inner: inner.toggle()   # refused while the outer door is open: the interlock
	await _frames(0.6)
	p.rotation.y = PI
	await _frames(0.3)
	if outer: outer.toggle()
	await _frames(1.3)
	p.rotation.y = 0.0
	if inner: inner.toggle()
	await _frames(1.3)
	await _walk(in_lock, past_inner, 0.0, 0.0, 1.4)

func furnish() -> void:
	await _new_world("plains", "survival", 15.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	if world.scout_rover: world.scout_rover.queue_free()   # it follows indoors and catches the crosshair
	_base(false)
	var y := b.habitat_base_y
	p.global_position = Vector3(15.0, y + 0.2, -1.8); p.rotation.y = deg_to_rad(10)
	(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(-29)
	var ib = world.interior_builder
	ib.enter()
	await _warm()
	ib._pick_card("crew_bunk")
	ib._set_selector_open(false)
	await _frames(0.8)
	for i in 6:
		_key(KEY_R)
		await _frames(0.12)
	await _frames(0.4)
	ib._place_preview()
	await _frames(0.6)
	var head := p.get_node("Head") as Node3D
	for i in int(0.8 * FPS):
		p.rotation.y = lerp_angle(deg_to_rad(10), deg_to_rad(-35), float(i) / (0.8 * FPS))
		await process_frame
	ib._pick_card("locker")
	ib._set_selector_open(false)
	await _frames(0.6)
	ib._place_preview()
	await _frames(0.4)
	ib._set_selector_open(true)
	await _frames(1.4)

func partitions() -> void:
	await _new_world("plains", "survival", 15.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	if world.scout_rover: world.scout_rover.queue_free()   # it follows indoors and catches the crosshair
	_base(false)
	var y := b.habitat_base_y
	p.global_position = Vector3(18.8, y + 0.2, -1.8); p.rotation.y = deg_to_rad(50)
	var head := p.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(-24)
	var ib = world.interior_builder
	ib.enter()
	ib._select_selector_group("_structure")
	ib._pick_card("partition")
	ib._set_selector_open(false)
	await _warm()
	await _frames(0.5)
	_button(Vector2(960, 540), true)
	for i in int(1.6 * FPS):
		p.rotation.y = deg_to_rad(50 - 60.0 * float(i) / (1.6 * FPS))
		await process_frame
	_button(Vector2(960, 540), false)
	await _frames(0.5)
	ib._pick_card("partition_glass")
	ib._set_selector_open(false)
	_button(Vector2(960, 540), true)
	for i in int(1.0 * FPS):
		p.rotation.y = deg_to_rad(-10 - 35.0 * float(i) / (1.0 * FPS))
		await process_frame
	_button(Vector2(960, 540), false)
	await _frames(1.2)

func interact() -> void:
	await _new_world("plains", "survival", 15.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base(true)
	var y := b.habitat_base_y
	var eye := Vector3(22.1, y + 0.2, -4.4)
	p.global_position = eye; p.rotation.y = 0.0
	(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(-4)
	await _warm()
	await _frames(1.0)
	var freezer: Node = null
	for rig in world.find_children("*", "Node3D", true, false):
		if rig.get("equipment_id") == "galley_freezer": freezer = rig
	if freezer: freezer.interact()
	await _frames(1.2)
	if freezer: freezer.interact_secondary()
	await _frames(1.4)
	await _walk(eye, Vector3(28.0, y + 0.2, -4.6), 0.0, deg_to_rad(-30), 1.6)
	await _frames(0.6)

func mission_control() -> void:
	await _new_world("plains", "survival", 21.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base(true)
	p.global_position = Vector3(16, b.habitat_base_y + 0.2, -3.2); p.rotation.y = deg_to_rad(30)
	await _warm()
	await _frames(1.0)
	world._open_mission_control()
	await _frames(4.5)

func night() -> void:
	await _new_world("plains", "survival", 22.5)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base(true)
	p.set_flashlight_enabled(true)
	var a := Vector3(6, 0, 14); a.y = MHSiteTerrain.height(a.x, a.z) + 1.7
	var z := Vector3(14, 0, 11); z.y = MHSiteTerrain.height(z.x, z.z) + 1.7
	p.global_position = a
	await _warm()
	await _walk(a, z, _yaw_at(a, Vector3(20, 2, 0)), _yaw_at(z, Vector3(24, 2, 0)), 5.0, -4.0)

func rover() -> void:
	await _new_world("plains", "survival", 16.5)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base(false)
	var a := Vector3(-6, 0, 18); a.y = MHSiteTerrain.height(a.x, a.z) + 1.7
	var z := Vector3(10, 0, 13); z.y = MHSiteTerrain.height(z.x, z.z) + 1.7
	p.global_position = a
	var look := _yaw_at(a, Vector3(24, 2, 0))
	if world.scout_rover:
		world.scout_rover.set_physics_process(false)
		world.scout_rover.global_position = a + Vector3(-sin(look), 0, -cos(look)) * 4.0 + Vector3(0, -1.6, 0)
	await _warm()
	var rv: Node3D = world.scout_rover
	var head := p.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(-12)
	for i in int(5.0 * FPS):
		var t := float(i) / (5.0 * FPS)
		p.global_position = a.lerp(z, t)
		var dir := (z - a).normalized()
		if rv:
			rv.global_position = p.global_position + dir * 4.2 + Vector3(0.8 * sin(t * 6.0), 0, 0)
			rv.global_position.y = MHSiteTerrain.height(rv.global_position.x, rv.global_position.z) + 0.05
			rv.rotation.y = atan2(-dir.x, -dir.z)
			for w in rv._wheels: w.rotate_object_local(Vector3.RIGHT, -0.12)
		p.rotation.y = atan2(-dir.x, -dir.z)
		await process_frame

func missions() -> void:
	MHGame.save_directory = "user://trailer_saves"
	MHGame.site_id = "plains"; MHGame.game_mode = "missions"; MHGame.pending_save_state = {}
	MHMissions.reset()
	var target: Vector2 = PICKER.suggested()
	var base := Vector2.INF
	for x in range(-45, 46, 3):
		for zz in range(-45, 46, 3):
			var candidate := Vector2(x, zz)
			if is_inf(base.x) and bool(MHMissions.check_landing(target, candidate).passed) and candidate.distance_to(target) < 35.0: base = candidate
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = base
	MHMissions.complete("landing_zones")
	world = load("res://scenes/mars_world.tscn").instantiate(); root.add_child(world)
	await process_frame
	world.day_night.set_hour(9.5); world.day_night.frozen = true
	await _warm()
	await _frames(10.0)          # the touchdown cinematic and its captions
	await _frames(2.5)           # the short brief card
	world.mission_hud._close_overlay()
	await _frames(1.8)           # the step tracker, top right
	world.mission_hud._run_test()
	await _frames(3.5)           # the Test report
