extends SceneTree

## Trailer shot director. Record one shot with Godot's movie writer:
##   godot --path . --write-movie out/<shot>.avi --fixed-fps 30 --resolution 1920x1080 \
##         --script res://tools/trailer_capture.gd -- <shot>
## Each shot builds its site (and a small furnished base where needed), hides
## the HUD, waits WARMUP frames (trim them later), then flies a scripted camera.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CARGO_LANDER := preload("res://scripts/cargo_lander.gd")
const WARMUP := 45          # frames before the shot starts (1.5 s, trimmed in the edit)
const FPS := 30.0

var world: Node
var b: BuildController
var cam: Camera3D
var base_offset := Vector2i.ZERO

const SHOTS := {
	"night_sky": {"site": "plains", "hour": 22.6, "seconds": 7.0, "base": true, "palette": "dusk"},
	"touchdown": {"site": "plains", "hour": 7.2, "seconds": 8.5, "base": false},
	"hatch": {"site": "plains", "hour": 10.0, "seconds": 6.0, "base": false},
	"step_out": {"site": "plains", "hour": 10.0, "seconds": 6.5, "base": false},
	"golden_base": {"site": "plains", "hour": 17.6, "seconds": 7.0, "base": true, "palette": "golden"},
	"ridge": {"site": "ridge", "hour": 9.0, "seconds": 6.0, "base": false},
	"ice": {"site": "ice", "hour": 10.5, "seconds": 6.0, "base": false},
	"night_base": {"site": "plains", "hour": 21.4, "seconds": 6.5, "base": true, "palette": "dusk"},
	"galley": {"site": "plains", "hour": 21.4, "seconds": 5.0, "base": true},
	"hydroponics": {"site": "plains", "hour": 21.4, "seconds": 4.5, "base": true},
	"finale": {"site": "plains", "hour": 22.2, "seconds": 8.0, "base": true, "palette": "dusk"},
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var shot: String = args[0] if not args.is_empty() else "golden_base"
	var spec: Dictionary = SHOTS[shot]
	MHGame.site_id = str(spec.site); MHGame.game_mode = "creative"; MHGame.pending_save_state = {}
	MHGame.landing_target = Vector2.INF
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	b = world.builder
	if spec.has("palette"): world.environment.apply_palette(str(spec.palette))
	world.day_night.set_hour(float(spec.hour)); world.day_night.frozen = true
	world.environment.apply_daylight(MHGame.sunlight_fraction)
	world.explore_hud.visible = false
	if world.scout_rover != null: world.scout_rover.queue_free()
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	if bool(spec.base): _build_base()
	cam = Camera3D.new(); cam.fov = 50.0; cam.far = 2000.0
	world.add_child(cam); cam.current = true
	await call(shot)
	quit()

# ---------- the base ----------

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z) + base_offset)
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _put(id: String, at: Vector3, yaw: float, normal := Vector3.UP) -> void:
	var v := b.free_interior_visual(id, at, yaw)
	b.place_free_interior_equipment(id, at, yaw, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), v, normal)

## A believable little base on the far side of the site from the crew lander.
func _build_base() -> void:
	var l: Vector3 = world.lander.global_position
	var away := -Vector2(l.x, l.z).normalized() * 6.0
	base_offset = Vector2i(roundi(away.x), roundi(away.y))
	b.zones = [_room("living", -3, -2, 3, 2), _room("galley", 0, -2, 3, 2), _room("hydroponics", 3, -2, 3, 2),
		_room("life_support", -3, 0, 3, 2), _room("engineering", 0, 0, 3, 2),
		{"kind": "airlock", "cells": [Vector2i(1, 2) + base_offset], "door_direction": Vector2i(0, 1), "cost": 0}]
	for i in 6:
		b.zones.append({"kind": "solar", "cells": [Vector2i(-6 + (i % 3) * 2, 4 + (i / 3) * 2) + base_offset], "door_direction": Vector2i(0, 1), "cost": 0})
	b.zones.append({"kind": "ice_extractor", "cells": [Vector2i(7, 3) + base_offset], "cost": 0})
	b._rebuild()
	for door in [[Vector2i(-1, -1), Vector2i(1, 0)], [Vector2i(2, -1), Vector2i(1, 0)], [Vector2i(-2, -1), Vector2i(0, 1)], [Vector2i(1, -1), Vector2i(0, 1)]]:
		b.place_interior_door(door[0] + base_offset, door[1])
	var y := b.habitat_base_y
	var o := Vector3(base_offset.x * 3.0, 0, base_offset.y * 3.0)
	# Galley (cells x 0..2, z -2..-1): x -1.5..7.5, z -7.5..-1.5
	_put("galley_table_set", o + Vector3(3.0, y, -4.2), 0.0)
	_put("galley_oven", o + Vector3(0.0, y, -6.9), PI)
	_put("galley_freezer", o + Vector3(1.1, y, -6.9), PI)
	_put("galley_rehydration_station", o + Vector3(2.2, y, -7.0), PI)
	_put("plant_pot", o + Vector3(6.9, y, -6.9), 0.0)
	_put("wall_whiteboard", o + Vector3(4.6, y + 1.5, -7.37), PI, Vector3(0, 0, 1))
	# Hydroponics (x 7.5..16.5).
	for i in 4: _put("grow_tray", o + Vector3(9.5 + i * 1.9, y, -5.5), 0.0)
	# Living (x -10.5..-1.5).
	_put("integrated_mess_booth", o + Vector3(-6.0, y, -4.5), 0.0)
	_put("crew_bunk", o + Vector3(-9.3, y, -6.6), PI)
	_put("work_desk", o + Vector3(-3.0, y, -6.9), PI)
	_put("crew_chair", o + Vector3(-3.0, y, -6.2), 0.0)

func _base_centre() -> Vector3:
	return Vector3(base_offset.x * 3.0 + 3.0, b.habitat_base_y, base_offset.y * 3.0 - 1.5)

# ---------- camera moves ----------

func _ground(x: float, z: float) -> float:
	return MHSiteTerrain.height(x, z)

func _move(seconds: float, from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, warm := true, each := Callable()) -> void:
	if warm:
		cam.global_position = from; cam.look_at(look_from, Vector3.UP)
		for i in WARMUP: await process_frame
	var frames := int(seconds * FPS)
	for i in frames:
		var t := float(i) / float(frames - 1)
		var e := t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65   # mostly linear, soft ends
		cam.global_position = from.lerp(to, e)
		cam.look_at(look_from.lerp(look_to, e), Vector3.UP)
		if each.is_valid(): each.call(t)
		await process_frame

# ---------- shots ----------

func night_sky() -> void:
	var c := _base_centre()
	var eye := c + Vector3(-34, 0, 26)
	eye.y = _ground(eye.x, eye.z) + 1.4
	await _move(7.0, eye, eye + Vector3(4, 0.6, -3), c + Vector3(0, 6, 0), c + Vector3(0, 26, -10))

func touchdown() -> void:
	var cargo: Node3D = CARGO_LANDER.new()
	world.add_child(cargo)
	cargo.place_at(Vector2(-22, 8), Vector2.ZERO)
	var ground_at: Vector3 = cargo.global_position
	cargo.set_burn(true)
	var dust := _dust(ground_at)
	var eye := ground_at + Vector3(16, 0, 11)
	eye.y = _ground(eye.x, eye.z) + 2.2
	cargo.global_position = ground_at + Vector3.UP * 70.0
	await _move(8.5, eye, eye + Vector3(-2.5, 0.4, -1.5), ground_at + Vector3(0, 30, 0), ground_at + Vector3(0, 2, 0), true, func(t: float) -> void:
		var fall := clampf(t / 0.8, 0.0, 1.0)
		cargo.global_position = ground_at + Vector3.UP * 70.0 * pow(1.0 - fall, 2.6)
		dust.emitting = fall > 0.55 and fall < 1.0 or (t < 0.9 and fall >= 1.0)
		if fall >= 1.0: cargo.set_burn(false))

func _dust(at: Vector3) -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.emitting = false; dust.amount = 260; dust.lifetime = 3.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP; dust.emission_ring_radius = 2.5; dust.emission_ring_inner_radius = .5; dust.emission_ring_height = .2
	dust.direction = Vector3(1, .15, 0); dust.spread = 180.0; dust.flatness = .85
	dust.initial_velocity_min = 5.0; dust.initial_velocity_max = 13.0; dust.damping_min = 2.5; dust.damping_max = 4.0
	dust.gravity = Vector3(0, -.3, 0); dust.scale_amount_min = 1.0; dust.scale_amount_max = 2.6
	var puff := QuadMesh.new(); puff.size = Vector2(1.4, 1.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(MHStyle.DUST_200, .3)
	m.albedo_texture = CARGO_LANDER.soft_puff_texture()
	puff.material = m; dust.mesh = puff
	dust.position = at + Vector3.UP * .4
	world.add_child(dust)
	return dust

func hatch() -> void:
	var lander: Node3D = world.lander
	lander.set_hatch(false)
	world.environment.cabin_dim = true
	world.environment.apply_daylight(MHGame.sunlight_fraction)
	var start: Dictionary = lander.cabin_start()
	var eye: Vector3 = lander.to_global(Vector3(0, 2.05, 0.9))
	var door: Vector3 = lander.to_global(Vector3(0, 1.9, -3.0))
	var opened := false
	await _move(6.0, eye, eye + (door - eye).normalized() * 0.5, door, door + Vector3.DOWN * 0.3, true, func(t: float) -> void:
		if t > 0.15 and not opened:
			opened = true
			lander.set_hatch(true, true))

func step_out() -> void:
	var lander: Node3D = world.lander
	lander.set_hatch(true)
	var inside: Vector3 = lander.to_global(Vector3(0, 2.05, -0.6))
	var out: Vector3 = lander.to_global(Vector3(0, 0, -7.5))
	out.y = _ground(out.x, out.z) + 1.65
	var horizon: Vector3 = lander.to_global(Vector3(0, 1.6, -40))
	await _move(6.5, inside, out, lander.to_global(Vector3(0, 1.0, -6)), horizon)

func golden_base() -> void:
	var c := _base_centre()
	var a := Vector3(-30, 9, 24) + c
	var z := Vector3(-14, 5, 22) + c
	await _move(7.0, a, z, c + Vector3(0, 1.5, 0), c + Vector3(2, 1.5, -2))

func ridge() -> void:
	var a := Vector3(0, _ground(0, 30) + 7, 30)
	await _move(6.0, a, a + Vector3(6, 3, -16), Vector3(30, 18, -60), Vector3(45, 22, -80))

func ice() -> void:
	var a := Vector3(-24, 0, 18)
	a.y = _ground(a.x, a.z) + 1.3
	var z := a + Vector3(10, 0.25, -12)
	await _move(6.0, a, z, a + Vector3(10, -0.6, -12), z + Vector3(12, 0.2, -14))

func night_base() -> void:
	var c := _base_centre()
	var a := c + Vector3(-16, 0, 14); a.y = _ground(a.x, a.z) + 2.0
	var z := c + Vector3(6, 0, 15); z.y = _ground(z.x, z.z) + 2.6
	await _move(6.5, a, z, c + Vector3(-4, 1.2, 0), c + Vector3(6, 1.2, 0))

func galley() -> void:
	var o := Vector3(base_offset.x * 3.0, b.habitat_base_y, base_offset.y * 3.0)
	await _move(5.0, o + Vector3(6.6, 1.55, -2.2), o + Vector3(4.2, 1.6, -2.0), o + Vector3(1.0, 1.0, -6.5), o + Vector3(2.4, 1.0, -6.8))

func hydroponics() -> void:
	var o := Vector3(base_offset.x * 3.0, b.habitat_base_y, base_offset.y * 3.0)
	await _move(4.5, o + Vector3(15.6, 1.4, -2.2), o + Vector3(14.6, 1.6, -3.0), o + Vector3(9.0, 0.8, -5.5), o + Vector3(10.0, 0.9, -5.8))

func finale() -> void:
	var c := _base_centre()
	var a := c + Vector3(0, 0, 30); a.y = _ground(a.x, a.z) + 1.6
	await _move(8.0, a, a + Vector3(0, 9, 10), c + Vector3(0, 2, 0), c + Vector3(0, 10, -20))
