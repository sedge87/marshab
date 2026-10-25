extends SceneTree

## The "Show me" clips for ARDEN's tutorial, the mission steps and the
## first-time hint cards (docs/tutorial-design.md): a few seconds of the real
## game doing one thing, with the keys pressed shown as big key caps.
## Record them all with tools/record_hint_clips.sh; one by hand:
##   godot --path . --write-movie out/<clip>.avi --fixed-fps 30 \
##         --script res://tools/capture_hint_clips.gd -- <clip>
## (1920×1080 needs the override.cfg the shell script writes.) WARMUP frames
## come first; the script trims them.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")
const WARMUP := 45
const FPS := 30.0

var world: Node
var b: BuildController
var p: CharacterBody3D
var _caps: CanvasLayer
var _caps_box: PanelContainer

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var clip: String = args[0] if not args.is_empty() else "plan"
	MHGame.tutorial_mode = "off"   # no tutorial panel or hint cards in the shot
	await call("clip_" + clip)
	quit()

# ---------- helpers ----------

func _frames(seconds: float) -> void:
	for i in int(seconds * FPS): await process_frame

func _new_world(hour := 11.0, lander_in_shot := false) -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	b = world.builder
	p = world.player
	world.day_night.set_hour(hour); world.day_night.frozen = true
	if world.scout_rover: world.scout_rover.queue_free()   # it wanders into shots
	if not lander_in_shot:
		# West of the tutorial base (x 12–21 m, z 0–6 m), facing it.
		world.lander.place_at(Vector2(-16, -12))
		world.lander.set_hatch(true)
	_caps = CanvasLayer.new()
	_caps.layer = 60
	root.add_child(_caps)

## The keys being pressed, big, bottom centre: [[caps], action] rows.
func _show_keys(rows: Array) -> void:
	if _caps_box != null: _caps_box.queue_free()
	_caps_box = null
	if rows.is_empty(): return
	_caps_box = MHStyle.hud_panel(14, false, true)
	_caps_box.theme = MHStyle.theme()
	var column := MHStyle.vbox(4)
	for row in rows: column.add_child(MHStyle.control_row(row[0], str(row[1]), true))
	_caps_box.add_child(column)
	_caps_box.scale = Vector2(1.8, 1.8)
	_caps.add_child(_caps_box)
	await process_frame
	# Upper middle: clear of the build bars and the HUD panels.
	_caps_box.position = Vector2(960 - _caps_box.size.x * .9, 330)

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

func _glide_mouse(to: Vector2, seconds: float) -> void:
	var from := root.get_mouse_position()
	var frames := int(seconds * FPS)
	for i in frames:
		var t := float(i + 1) / frames
		_mouse(from.lerp(to, t * t * (3.0 - 2.0 * t)))
		await process_frame

## Pick a part from the build bar by clicking its card, like a player.
func _pick_part(kind: String) -> void:
	b.category = str(BuildController.ZONE_INFO[kind].cat)
	b._refresh_catalogue()
	await process_frame
	var card: Control = load("res://scripts/guide_overlay.gd").find_target(self, "part:" + kind)
	if card != null:
		await _glide_mouse(card.get_global_rect().get_center(), .5)
		await _frames(.15)
	b._select_kind(kind)
	await _frames(.3)

## Drag out a zone in the site plan: press, sweep, release.
func _drag(from: Vector2i, to: Vector2i, seconds := 1.0) -> void:
	await _glide_mouse(_cell_screen(from), .5)
	_button(_cell_screen(from), true)
	var frames := int(seconds * FPS)
	for i in frames:
		var t := float(i + 1) / frames
		var c := Vector2(from).lerp(Vector2(to), t)
		_mouse(b.camera.unproject_position(Vector3(c.x * 3.0, b.habitat_base_y, c.y * 3.0)))
		await process_frame
	_button(_cell_screen(to), false)
	await _frames(.4)

func _walk(from: Vector3, to: Vector3, yaw_from: float, yaw_to: float, seconds: float, pitch := 0.0) -> void:
	var head := p.get_node("Head") as Node3D
	var frames := int(seconds * FPS)
	for i in frames:
		var t: float = float(i) / float(maxi(1, frames - 1))
		var e: float = t * t * (3.0 - 2.0 * t)
		p.global_position = from.lerp(to, e)
		p.rotation.y = lerp_angle(yaw_from, yaw_to, e)
		head.rotation.x = deg_to_rad(pitch)
		await process_frame

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _put(id: String, at: Vector3, yaw: float) -> Node3D:
	var v := b.free_interior_visual(id, at, yaw)
	b.place_free_interior_equipment(id, at, yaw, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), v, Vector3.UP)
	return v

## The tutorial's base: Living Quarters (cells 4..5, 0..1), Life Support to
## its east, an airlock on the south wall, a solar array.
func _base() -> void:
	b.zones = [_room("living", 4, 0, 2, 2), _room("life_support", 6, 0, 2, 2),
		{"kind": "airlock", "cells": [Vector2i(5, 2)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "solar", "cells": [Vector2i(2, 4)], "door_direction": Vector2i(0, 1), "cost": 0}]
	b._rebuild()
	b.place_interior_door(Vector2i(5, 0), Vector2i(1, 0))

func _door(label: String) -> Node:
	for d in world.find_children("*", "Node3D", true, false):
		if d.is_in_group("airlock_door") and str(d.door_label()) == label: return d
	return null

func _plan(centre: Vector3, zoom := 26.0) -> void:
	p.process_mode = Node.PROCESS_MODE_DISABLED
	b._toggle()
	b.pivot.position = centre
	b.zoom = zoom; b._zoom()

func _warm() -> void:
	for i in WARMUP: await process_frame

# ---------- the clips ----------

func clip_move() -> void:
	await _new_world(9.0, true)
	world.lander.set_hatch(true)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var a: Vector3 = world.lander.to_global(Vector3(0, 0, -8.0)); a.y = MHSiteTerrain.height(a.x, a.z) + 1.0
	var z: Vector3 = world.lander.to_global(Vector3(5.0, 0, -14.0)); z.y = MHSiteTerrain.height(z.x, z.z) + 1.0
	p.global_position = a
	var yaw: float = world.lander.rotation.y + PI
	await _warm()
	await _show_keys([[["Mouse"], "Look around"]])
	await _walk(a, a, yaw, yaw + 1.1, 1.6, -4.0)
	await _walk(a, a, yaw + 1.1, yaw - .4, 1.4, -4.0)
	await _show_keys([[["W", "A", "S", "D"], "Walk"], [["Shift"], "Sprint"]])
	await _walk(a, z, yaw - .4, yaw - .6, 2.6, -4.0)
	await _frames(.6)

func clip_outside() -> void:
	await _new_world(9.0, true)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var lander: Node3D = world.lander
	var start: Dictionary = lander.cabin_start()
	# Standing in the cabin, eyes level, facing the hatch.
	p.global_position = lander.to_global(Vector3(0, 1.15, .4)); p.rotation.y = lander.rotation.y
	start["yaw"] = lander.rotation.y
	(p.get_node("Head") as Node3D).rotation.x = 0.0
	await _warm()
	await _warm()   # the cabin's light settles
	await _frames(.6)
	await _show_keys([[["E"], "Open the hatch"]])
	lander.set_hatch(true, true)
	await _frames(1.8)
	await _show_keys([[["W"], "Walk down the ramp"]])
	var out: Vector3 = lander.to_global(Vector3(0, 0, -8.0))
	out.y = MHSiteTerrain.height(out.x, out.z) + 1.0
	await _walk(p.global_position, out, float(start.yaw), float(start.yaw) + .2, 3.0, -6.0)
	await _frames(.6)

func clip_plan() -> void:
	await _new_world()
	world.lander.set_hatch(true)
	var at := Vector3(12, 0, 8); at.y = MHSiteTerrain.height(at.x, at.z) + 1.0
	p.global_position = at
	p.process_mode = Node.PROCESS_MODE_DISABLED
	await _warm()
	await _frames(.6)
	await _show_keys([[["B"], "Site plan"]])
	b._toggle()
	b.pivot.position = Vector3(12, 0, 4); b.zoom = 30.0; b._zoom()
	await _frames(1.2)
	await _show_keys([[["W", "A", "S", "D"], "Pan"], [["Wheel"], "Zoom"]])
	for i in int(1.6 * FPS):
		b.pivot.position.x += .08
		await process_frame
	for i in int(1.2 * FPS):
		b.zoom = lerpf(30.0, 22.0, float(i) / (1.2 * FPS)); b._zoom()
		await process_frame
	await _show_keys([[["Q", "E"], "Orbit"]])
	for i in int(1.2 * FPS):
		b.pivot.rotation.y += .01
		await process_frame
	await _frames(.5)

func clip_living() -> void:
	await _new_world()
	await _plan(Vector3(15, 0, 3), 24.0)
	await _warm()
	await _show_keys([[["LMB"], "Pick Living Quarters"]])
	await _pick_part("living")
	await _show_keys([[["LMB"], "Drag out the room"]])
	await _drag(Vector2i(4, 0), Vector2i(5, 1), 1.0)
	await _show_keys([[["Ctrl", "Z"], "Undo"], [["X"], "Remove · refund"]])
	await _frames(1.4)

func clip_airlock() -> void:
	await _new_world()
	b.zones = [_room("living", 4, 0, 2, 2)]; b._rebuild()
	await _plan(Vector3(15, 0, 4), 24.0)
	await _warm()
	await _show_keys([[["LMB"], "Pick Airlock"]])
	await _pick_part("airlock")
	b.airlock_direction = Vector2i(1, 0)
	await _glide_mouse(_cell_screen(Vector2i(5, 2)), .6)
	await _show_keys([[["R"], "Turn: outer door faces Mars"]])
	# Turn until the outer door faces away from the room (south).
	for i in 4:
		if b.airlock_direction == Vector2i(0, 1): break
		_key(KEY_R)
		await _frames(.45)
	await _show_keys([[["LMB"], "Place it on the wall"]])
	await _drag(Vector2i(5, 2), Vector2i(5, 2), .2)
	await _glide_mouse(_cell_screen(Vector2i(8, 4)), .5)   # off it, to see it placed
	await _frames(.8)

func clip_solar() -> void:
	await _new_world()
	b.zones = [_room("living", 4, 0, 2, 2)]; b._rebuild()
	await _plan(Vector3(9, 0, 9), 22.0)
	await _warm()
	await _show_keys([[["LMB"], "Pick Solar Array"]])
	await _pick_part("solar")
	await _glide_mouse(_cell_screen(Vector2i(2, 4)), .6)
	await _show_keys([[["R"], "Turn: watch its output"]])
	for i in 4:
		_key(KEY_R)
		await _frames(.5)
	await _show_keys([[["LMB"], "Place"]])
	for cell in [Vector2i(2, 4), Vector2i(3, 4)]:
		_mouse(_cell_screen(cell))
		await _frames(.2)
		_button(_cell_screen(cell), true); _button(_cell_screen(cell), false)
		await _frames(.5)
	await _frames(.8)

func clip_drill() -> void:
	await _new_world()
	var deposit: Dictionary = MHGame.site().ice_deposits[0]
	var ice := Vector3(float(deposit.x), 0, float(deposit.z))
	await _plan(ice + Vector3(-6, 0, 4), 30.0)
	await _warm()
	await _show_keys([[["LMB"], "Pick Ice Extractor"]])
	await _pick_part("ice_extractor")
	await _show_keys([[["Mouse"], "Blue ground has ice"]])
	var cell := Vector2i(roundi(ice.x / 3.0), roundi(ice.z / 3.0))
	for i in int(1.6 * FPS):
		_mouse(_cell_screen(cell + Vector2i(roundi(sin(i * .07) * 3.0) - 2, 1)))
		await process_frame
	await _show_keys([[["LMB"], "Place on bright blue"]])
	_mouse(_cell_screen(cell)); await _frames(.4)
	_button(_cell_screen(cell), true); _button(_cell_screen(cell), false)
	await _frames(1.4)

func clip_life_support() -> void:
	await _new_world()
	b.zones = [_room("living", 4, 0, 2, 2)]; b._rebuild()
	await _plan(Vector3(16, 0, 4), 24.0)
	await _warm()
	await _show_keys([[["LMB"], "Pick Life Support"]])
	await _pick_part("life_support")
	await _show_keys([[["LMB"], "Drag it beside the room"]])
	await _drag(Vector2i(6, 0), Vector2i(7, 1), 1.0)
	b._after_room_placed()
	await _show_keys([])
	await _frames(1.8)

func clip_go_in() -> void:
	await _new_world(15.5)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base()
	await process_frame
	var outer := _door("OUTER")
	var inner := _door("INNER")
	var y := b.habitat_base_y + 1.0
	var outside := Vector3(15, y, 12.5)
	var at_outer := Vector3(15, y, 9.6)
	var in_lock := Vector3(15, y, 6.0)
	var past_inner := Vector3(15, y, 2.4)
	p.global_position = outside; p.rotation.y = 0.0
	await _warm()
	await _walk(outside, at_outer, 0.0, 0.0, 1.2)
	await _show_keys([[["E"], "Open the outer door"]])
	if outer: outer.toggle()
	await _frames(1.3)
	await _walk(at_outer, in_lock, 0.0, 0.0, 1.0)
	await _show_keys([[["E"], "Open the inner door: the outer one shuts first"]])
	if inner: inner.toggle()
	await _frames(2.4)
	await _walk(in_lock, past_inner, 0.0, 0.0, 1.2)
	await _frames(.4)

func _furnish(room_x: float, look_yaw: float, items: Array) -> void:
	await _new_world(15.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base()
	var y := b.habitat_base_y
	p.global_position = Vector3(room_x, y + 0.2, 3.6); p.rotation.y = deg_to_rad(look_yaw)
	(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(-28)
	await _warm()
	await _show_keys([[["B"], "Furnish this room"]])
	var ib = world.interior_builder
	ib.enter()
	await _frames(1.0)
	for id in items:
		await _show_keys([[["LMB"], "Pick it"]])
		ib._pick_card(str(id))
		await _frames(.6)
		ib._set_selector_open(false)
		await _show_keys([[["R"], "Turn"], [["LMB"], "Place"]])
		for i in 4:   # all the way round, back to where it fits
			_key(KEY_R)
			await _frames(.2)
		await _frames(.3)
		ib._place_preview()
		await _frames(.6)
		p.rotation.y += deg_to_rad(-35)
		ib._set_selector_open(true)
		await _frames(.4)
	await _frames(.8)

func clip_bunk() -> void:
	await _furnish(13.5, 10.0, ["crew_bunk"])

func clip_air() -> void:
	await _furnish(19.5, 10.0, ["oxygen_generator", "thermal_control_unit"])

func clip_crew() -> void:
	await _new_world(15.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base()
	p.global_position = Vector3(13.5, b.habitat_base_y + .2, 2.0)
	await _warm()
	await _frames(.6)
	await _show_keys([[["C"], "Crew screen"]])
	world._open_mission_control()
	if world.mission_control != null: world.mission_control._show_crew()
	await _frames(4.0)

func clip_carry() -> void:
	await _new_world(15.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_base()
	var y := b.habitat_base_y
	_put("galley_table_set", Vector3(14.0, y, 1.5), 0.0)
	var mug := _put("crew_mug", Vector3(13.6, y + .78, 1.3), 0.0)
	p.global_position = Vector3(13.6, y + 0.2, 3.6); p.rotation.y = 0.0
	(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(-30)
	await _warm()
	await _frames(.5)
	await _show_keys([[["E"], "Pick it up"]])
	if mug != null: world.carry.pick_up(str(mug.get_meta("interior_placement_id", "")))
	await _frames(1.0)
	await _show_keys([[["Mouse"], "Aim: green fits"]])
	for i in int(1.4 * FPS):
		p.rotation.y = deg_to_rad(-40.0 * float(i) / (1.4 * FPS))
		await process_frame
	await _show_keys([[["E"], "Put it down"], [["Q"], "Put it back"]])
	world.carry.put_down()
	await _frames(1.4)

func clip_rover() -> void:
	await _new_world(14.0)
	b.zones = [_room("living", 0, 0, 2, 2), {"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	var rover = world.crew_rover
	await _frames(.5)
	p.global_position = rover.global_position + Vector3(-2.5, .2, 0)
	p.rotation.y = -PI * .5
	await _warm()
	await _show_keys([[["E"], "Get in"]])
	rover.interact()
	await _frames(.8)
	await _show_keys([[["W"], "Drive"], [["A", "D"], "Steer"], [["Space"], "Brake"]])
	var press := func(code: Key, on: bool) -> void:
		var key := InputEventKey.new()
		key.keycode = code; key.physical_keycode = code; key.pressed = on
		Input.parse_input_event(key)
	press.call(KEY_W, true)
	await _frames(4.0)
	press.call(KEY_D, true)
	await _frames(1.2)
	press.call(KEY_D, false)
	press.call(KEY_W, false)
	await _frames(1.0)

func clip_shielding() -> void:
	await _new_world()
	_base()
	await _plan(Vector3(17, 0, 4), 22.0)
	await _warm()
	await _show_keys([[["LMB"], "Pick Roof Shielding"]])
	await _pick_part("shield_roof")
	await _show_keys([[["LMB"], "Click a room"]])
	for cell in [Vector2i(4, 0), Vector2i(6, 0)]:
		await _glide_mouse(_cell_screen(cell), .5)
		_button(_cell_screen(cell), true); _button(_cell_screen(cell), false)
		await _frames(.6)
	await _glide_mouse(_cell_screen(Vector2i(6, 4)), .5)   # off the roofs, to see them
	await _frames(.8)
