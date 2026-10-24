extends SceneTree

## OUTPOST ONE: MARS trailer director. A separate tool: it builds a showpiece
## base in a throwaway world (nothing is saved, no game file changes), hides
## the game HUD, and flies a smooth spline camera through each shot.
##
## Scout a still (shot, time 0..1):
##   godot --path . --script res://trailer_outpost_one/capture/director.gd -- still <shot> <t> <out.png>
## Record a shot with Godot's movie writer (1080p30, see capture_all.sh):
##   godot --path . --write-movie <out.avi> --fixed-fps 30 --resolution 1920x1080 \
##         --script res://trailer_outpost_one/capture/director.gd -- shot <shot>
## Every recording starts with WARMUP frames (trimmed in the edit) so the
## weather, lights and particles have settled.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CARGO_LANDER := preload("res://scripts/cargo_lander.gd")
const WARMUP := 60
const FPS := 30.0

var world: Node
var b: BuildController
var cam: Camera3D
var clean_ui := true          # hide every HUD layer (cinematic shots)
var _mode := "shot"
var _still_t := 0.0
var _still_out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_mode = args[0] if not args.is_empty() else "still"
	var shot: String = args[1] if args.size() > 1 else "reveal"
	if _mode == "still":
		_still_t = float(args[2]) if args.size() > 2 else 0.5
		_still_out = args[3] if args.size() > 3 else "user://still.png"
	var spec: Dictionary = SHOTS[shot]
	var hour := float(spec.hour)
	if _mode == "still" and args.size() > 4: hour = float(args[4])   # scouting the light
	_settings()
	await _world(str(spec.site), hour, str(spec.get("palette", "")), bool(spec.get("base", true)))
	await call(shot)
	quit()

# ---------- shots: site, time of day, length ----------

const SHOTS := {
	# Act 1: the frontier
	"canyon_dawn": {"site": "ridge", "hour": 7.4, "base": false, "seconds": 7.0},
	"crater_dusk": {"site": "crater", "hour": 18.3, "base": false, "seconds": 6.0},
	"ice_fog": {"site": "ice", "hour": 7.2, "base": false, "seconds": 6.0},
	"touchdown": {"site": "plains", "hour": 8.0, "base": false, "seconds": 8.0},
	# Act 2: the outpost
	"reveal": {"site": "plains", "hour": 17.4, "base": true, "seconds": 8.0},
	"hull_glide": {"site": "plains", "hour": 17.8, "base": true, "seconds": 6.0},
	"airlock_in": {"site": "plains", "hour": 17.8, "base": true, "seconds": 6.0},
	"galley": {"site": "plains", "hour": 19.6, "base": true, "seconds": 6.0},
	"hydro": {"site": "plains", "hour": 19.6, "base": true, "seconds": 6.0},
	"window_dusk": {"site": "plains", "hour": 18.6, "base": true, "seconds": 6.0},
	# Act 3: building a future
	"science": {"site": "plains", "hour": 14.0, "base": true, "seconds": 5.0},
	"engineering": {"site": "plains", "hour": 14.0, "base": true, "seconds": 5.0},
	"solar_field": {"site": "plains", "hour": 11.0, "base": true, "seconds": 5.0},
	"storm": {"site": "plains", "hour": 13.0, "base": true, "seconds": 7.0},
	# Act 4: Outpost One
	"finale": {"site": "plains", "hour": 19.4, "base": true, "seconds": 13.0},
	# Gameplay (real UI)
	"siteplan": {"site": "plains", "hour": 11.0, "base": true, "seconds": 3.5},
	"power": {"site": "plains", "hour": 11.0, "base": true, "seconds": 4.0},
	"furnish": {"site": "plains", "hour": 15.0, "base": true, "seconds": 4.0},
}

# ---------- the world ----------

func _settings() -> void:
	# High quality, no tutorials or random events, in memory only.
	var s: Dictionary = MHGame.defaults()
	s.merge(MHGame.PRESETS.high, true)
	s["preset"] = "high"
	s["tutorial_cards"] = false
	s["alert_advisories"] = false
	s["live_hazards"] = false
	s["gary_autonomy"] = false
	s["fov"] = 60
	MHGame._settings = s

func _world(site: String, hour: float, palette: String, with_base: bool) -> void:
	MHGame.site_id = site
	MHGame.game_mode = "creative"
	MHGame.save_directory = "user://trailer_scratch"
	MHGame.pending_save_state = {"site_id": site, "builder": {}}
	MHGame.landing_target = Vector2.INF
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 3: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	b = world.builder
	if not palette.is_empty(): world.environment.apply_palette(palette)
	world.day_night.set_hour(hour)
	world.day_night.frozen = true
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.global_position = Vector3(0, -50, 0)   # out of every shot
	if world.scout_rover != null: world.scout_rover.set_physics_process(false)
	if with_base: _build_base()
	else:
		# The frontier: nobody here yet.
		world.lander.visible = false
		world.lander.position.y -= 200.0
		if world.scout_rover != null: world.scout_rover.visible = false
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.05
	cam.far = 3000.0
	world.add_child(cam)
	cam.current = true
	_hide_ui()

func _hide_ui() -> void:
	if not clean_ui: return
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	# The doors' "E - open" prompts are for players, not the camera.
	for door in root.get_tree().get_nodes_in_group("airlock_door"):
		var status = door.get("_status")
		if status != null: (status as Label3D).visible = false

# ---------- the showpiece base ----------
# Two rows of rooms (3 m cells): north row Living, Galley, Hydroponics,
# Science; south row Medical, Mission Operations, Life Support, Engineering;
# an airlock out of Mission Operations to the south. Solar field to the
# south-east, a reactor east, the regolith intake north, a mast and lights.

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _put(id: String, at: Vector3, yaw: float, normal := Vector3.UP) -> void:
	var v := b.free_interior_visual(id, at, yaw)
	b.place_free_interior_equipment(id, at, yaw, Vector2i(roundi(at.x / 3.0), roundi(at.z / 3.0)), v, normal)

func _site(kind: String, at: Vector2, yaw: float, roof := false) -> void:
	var cell := Vector2i(roundi(at.x / 3.0), roundi(at.y / 3.0))
	var zone := {"kind": kind, "cells": [cell], "at": at, "yaw": yaw, "door_direction": Vector2i(0, 1), "cost": 0}
	if roof: zone["roof"] = true
	b.zones.append(zone)

func _surface(id: String, at: Vector2, yaw: float) -> void:
	var p := Vector3(at.x, MHSiteTerrain.height(at.x, at.y), at.y)
	b.place_surface_equipment(id, p, yaw, b.surface_visual(id, p, yaw))

func _bay(mid: Vector2, outward: Vector2) -> Dictionary:
	for bay in b._hull_bays:
		if (bay.mid as Vector2).distance_to(mid) < .2 and (bay.outward as Vector2).dot(outward) > .9: return bay
	return {}

func _build_base() -> void:
	world.lander.place_at(Vector2(-34, 20))
	world.lander.rotation.y = atan2(34.0, -20.0)
	world.lander.set_hatch(true)
	b.zones = [_room("living", -4, -2, 3, 2), _room("galley", -1, -2, 3, 2), _room("hydroponics", 2, -2, 3, 2), _room("science", 5, -2, 2, 2),
		_room("medical", -4, 0, 2, 2), _room("communications", -2, 0, 3, 2), _room("life_support", 1, 0, 3, 2), _room("engineering", 4, 0, 3, 2),
		{"kind": "airlock", "cells": [Vector2i(-1, 2)], "door_direction": Vector2i(0, 1), "cost": 0}]
	# Solar field (south-facing, a little turned), a reactor, the intake.
	for i in 8:
		_site("solar", Vector2(8.0 + (i % 4) * 4.2, 16.0 + (i / 4) * 4.4), PI + deg_to_rad(-8.0))
	_site("solar", Vector2(6.0, -4.6), PI, true)
	_site("solar", Vector2(10.6, -4.6), PI, true)
	_site("reactor", Vector2(30.0, 3.0), -PI * .5)
	_site("regolith_intake", Vector2(2.0, -17.0), 0.0)
	b._rebuild()
	for door in [[Vector2i(-2, -1), Vector2i(1, 0)], [Vector2i(1, -1), Vector2i(1, 0)], [Vector2i(4, -1), Vector2i(1, 0)],
			[Vector2i(-1, -1), Vector2i(0, 1)], [Vector2i(-3, -1), Vector2i(0, 1)], [Vector2i(2, -1), Vector2i(0, 1)], [Vector2i(5, -1), Vector2i(0, 1)],
			[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(3, 0), Vector2i(1, 0)]]:
		b.place_interior_door(door[0], door[1])
	# Windows: the north row looks north, the south row south.
	for x in [-4, -2, 0, 3, 5]: b.place_window({"mid": Vector2(x * 3.0, -7.5), "dir": Vector2(1, 0)})
	for x in [-4, 1, 3, 5]: b.place_window({"mid": Vector2(x * 3.0, 4.5), "dir": Vector2(1, 0)})
	# Regolith on the west end, water walls by Living, roof shielding, a ladder.
	for mid in [Vector2(-13.5, -3.0), Vector2(-13.5, 0.0) + Vector2(0, 3.0)]:
		var bay := _bay(mid, Vector2(-1, 0))
		if not bay.is_empty(): b.wall_upgrades.append({"kind": "regolith", "mid": bay.mid, "dir": bay.dir, "outward": bay.outward})
	var ladder := _bay(Vector2(19.5, -3.0), Vector2(1, 0))
	if not ladder.is_empty(): b.wall_upgrades.append({"kind": "ladder", "mid": ladder.mid, "dir": ladder.dir, "outward": ladder.outward})
	for cell in [Vector2i(-4, -2), Vector2i(-3, -2), Vector2i(-2, -2), Vector2i(-4, -1), Vector2i(-3, -1), Vector2i(-2, -1)]:
		b.wall_upgrades.append({"kind": "roof", "cell": cell})
	b._rebuild()
	_furnish()
	_surface("comms_antenna", Vector2(-9.0, 9.5), 0.3)
	_surface("high_light_post", Vector2(-6.5, 11.5), 0.0)
	_surface("high_light_post", Vector2(4.0, 11.0), 0.0)
	_surface("path_beacon", Vector2(-3.0, 13.0), 0.0)
	_surface("path_beacon", Vector2(-3.0, 17.0), 0.0)
	_surface("cargo_crate_large", Vector2(-14.0, 12.0), 0.5)
	_surface("equipment_pallet", Vector2(-17.0, 9.5), 0.2)
	if world.scout_rover != null:
		var r: Node3D = world.scout_rover
		r.global_position = Vector3(1.0, MHSiteTerrain.height(1.0, 10.0) + .05, 10.0)
		r.rotation.y = 2.3

func _furnish() -> void:
	var y := b.habitat_base_y
	# Living (x -13.5..-4.5, z -7.5..-1.5)
	_put("crew_bunk", Vector3(-12.3, y, -6.5), PI)
	_put("crew_bunk", Vector3(-9.4, y, -6.5), PI)
	_put("retro_mars_poster", Vector3(-6.7, y + 1.5, -7.38), PI, Vector3(0, 0, 1))
	_put("guitar", Vector3(-5.2, y, -6.9), PI)
	_put("integrated_mess_booth", Vector3(-8.0, y, -3.2), 0.0)
	_put("plant_pot", Vector3(-12.9, y, -2.2), 0.0)
	# Galley (x -4.5..4.5)
	_put("galley_kitchenette", Vector3(-2.4, y, -6.9), PI)
	_put("galley_freezer", Vector3(-0.2, y, -6.9), PI)
	_put("potable_water_dispenser", Vector3(1.2, y, -7.0), PI)
	_put("galley_table_set", Vector3(0.0, y, -3.9), 0.0)
	_put("herb_pot", Vector3(3.6, y, -7.0), PI)
	# Hydroponics (x 4.5..13.5)
	for i in 4: _put("grow_tray", Vector3(6.2 + i * 2.0, y, -5.3), 0.0)
	_put("seedling_station", Vector3(12.4, y, -7.0), PI)
	_put("nutrient_mixer", Vector3(5.6, y, -2.2), 0.0)
	# Science (x 13.5..19.5)
	_put("science_workbench", Vector3(15.6, y, -6.9), PI)
	_put("microscope_station", Vector3(18.5, y, -6.9), PI)
	_put("sample_storage_cabinet", Vector3(18.8, y, -2.4), 0.0)
	# Medical (x -13.5..-7.5, z -1.5..4.5)
	_put("medical_exam_cot", Vector3(-11.2, y, 3.6), 0.0)
	_put("medical_cabinet", Vector3(-8.4, y, 3.9), 0.0)
	# Mission Operations (x -7.5..1.5)
	_put("communications_station", Vector3(-6.2, y, 3.9), 0.0)
	_put("mission_planning_console", Vector3(0.4, y, 0.8), -PI * .5)
	_put("crew_chair", Vector3(-6.2, y, 3.0), PI)
	# Life Support (x 1.5..10.5)
	_put("air_recycler", Vector3(3.0, y, 3.9), 0.0)
	_put("water_reclaimer", Vector3(5.4, y, 3.9), 0.0)
	_put("oxygen_generator", Vector3(7.8, y, 3.9), 0.0)
	_put("thermal_control_unit", Vector3(9.8, y, 0.4), -PI * .5)
	# Engineering (x 10.5..19.5)
	for i in 3: _put("battery_bank", Vector3(12.0 + i * 1.2, y, 3.9), 0.0)
	_put("regolith_printer", Vector3(17.8, y, 3.5), 0.0)
	_put("tool_bench", Vector3(18.8, y, 0.0), -PI * .5)

func centre() -> Vector3:
	return Vector3(3.0, b.habitat_base_y, -1.5)

# ---------- the camera ----------

func _ground(x: float, z: float) -> float:
	return MHSiteTerrain.height(x, z)

func _at(x: float, z: float, above: float) -> Vector3:
	return Vector3(x, _ground(x, z) + above, z)

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func _path(points: Array, t: float) -> Vector3:
	if points.size() == 1: return points[0]
	var span := float(points.size() - 1)
	var f := clampf(t, 0.0, 1.0) * span
	var i := mini(int(f), points.size() - 2)
	var local := f - i
	var p0: Vector3 = points[maxi(i - 1, 0)]
	var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
	return _catmull(p0, points[i], points[i + 1], p3, local)

## Slow, deliberate: almost linear, eased only at the very ends.
static func _ease(t: float) -> float:
	var s := t * t * (3.0 - 2.0 * t)
	return lerpf(t, s, 0.3)

func _place_cam(eye: Array, look: Array, t: float, fov := Vector2(42, 42)) -> void:
	var e := _ease(t)
	cam.global_position = _path(eye, e)
	var target := _path(look, e)
	if cam.global_position.distance_to(target) > .01: cam.look_at(target, Vector3.UP)
	cam.fov = lerpf(fov.x, fov.y, e)

## Run a camera move: a still at _still_t, or WARMUP frames then the move.
func _move(seconds: float, eye: Array, look: Array, fov := Vector2(42, 42), each := Callable()) -> void:
	if _mode == "still":
		_place_cam(eye, look, _still_t, fov)
		if each.is_valid(): each.call(_still_t)
		for i in 40:
			_hide_ui()
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(_still_out)
		return
	_place_cam(eye, look, 0.0, fov)
	for i in WARMUP:
		_hide_ui()
		if each.is_valid(): each.call(0.0)
		await process_frame
	var frames := int(seconds * FPS)
	for i in frames:
		var t := float(i) / float(frames - 1)
		_place_cam(eye, look, t, fov)
		if each.is_valid(): each.call(t)
		_hide_ui()
		await process_frame

# ---------- act 1 ----------

func canyon_dawn() -> void:
	var a := _at(-10, 40, 9.0)
	await _move(7.0, [a, a + Vector3(5, 1.0, -8)], [Vector3(20, 14, -70), Vector3(30, 12, -80)], Vector2(38, 36))

## A dust devil, put where the camera will see it, drifting slowly.
func _devil(at: Vector2, drift: Vector2) -> void:
	var weather = world.site_weather
	if weather == null: return
	weather._spawn_devil(false)
	if weather._devils.is_empty(): return
	var d: Dictionary = weather._devils.back()
	(d.node as Node3D).global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y), at.y)
	d.velocity = drift
	d.life = 60.0

func crater_dusk() -> void:
	var a := _at(-30, 30, 4.0)
	await _move(6.0, [a, a + Vector3(6, 0.6, -3)], [a + Vector3(60, 6, -60), a + Vector3(70, 6, -56)], Vector2(36, 36))

func ice_fog() -> void:
	var a := _at(-24, 18, 7.0)
	await _move(6.0, [a, a + Vector3(6, 0.5, -6)], [a + Vector3(30, -3.5, -36), a + Vector3(40, -3.0, -44)], Vector2(34, 34))

func touchdown() -> void:
	var cargo: Node3D = CARGO_LANDER.new()
	world.add_child(cargo)
	cargo.place_at(Vector2(-6, 6), Vector2.ZERO)
	var ground_at: Vector3 = cargo.global_position
	cargo.set_burn(true)
	var eye := _at(26, 34, 1.5)
	var dust := _dust(ground_at)
	cargo.global_position = ground_at + Vector3.UP * 60.0
	await _move(8.0, [eye, eye + Vector3(-1.5, 0.2, -1.0)], [ground_at + Vector3(0, 9, 0), ground_at + Vector3(0, 4, 0)], Vector2(30, 30), func(t: float) -> void:
		var fall := clampf(t / 0.8, 0.0, 1.0)
		cargo.global_position = ground_at + Vector3.UP * 60.0 * pow(1.0 - fall, 2.4)
		dust.emitting = fall > 0.6 and t < 0.92
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

# ---------- act 2 ----------

func reveal() -> void:
	var c := centre()
	_devil(Vector2(40, -60), Vector2(-1.2, 0.3))
	await _move(8.0, [_at(-40, 34, 2.0), _at(-30, 30, 3.5), _at(-20, 26, 5.0)], [c + Vector3(-6, 1, 0), c + Vector3(0, 1.5, 0), c + Vector3(3, 1.5, -1)], Vector2(36, 38))

func hull_glide() -> void:
	var y := b.habitat_base_y
	await _move(6.0, [Vector3(22, y + 1.2, 9.0), Vector3(10, y + 1.4, 8.4)], [Vector3(6, y + 1.5, 4.5), Vector3(-4, y + 1.6, 4.5)], Vector2(40, 40))

func airlock_in() -> void:
	var y := b.habitat_base_y
	var outer = null
	for d in world.find_children("*", "Node3D", true, false):
		if d.is_in_group("airlock_door") and str(d.door_label()) == "OUTER": outer = d
	var opened := [false]
	await _move(6.0, [Vector3(-3.0, y + 1.6, 13.0), Vector3(-3.0, y + 1.6, 9.0)], [Vector3(-3.0, y + 1.4, 6.0), Vector3(-3.0, y + 1.3, 4.0)], Vector2(44, 44), func(t: float) -> void:
		if t > 0.25 and not opened[0] and outer != null:
			opened[0] = true
			outer.toggle())

func galley() -> void:
	var y := b.habitat_base_y
	await _move(6.0, [Vector3(3.9, y + 1.55, -2.0), Vector3(2.4, y + 1.5, -2.3)], [Vector3(-1.5, y + 0.9, -6.8), Vector3(-1.0, y + 0.95, -6.6)], Vector2(48, 46))

func hydro() -> void:
	var y := b.habitat_base_y
	await _move(6.0, [Vector3(13.0, y + 1.3, -2.0), Vector3(12.6, y + 1.2, -2.6)], [Vector3(6.0, y + 0.7, -5.6), Vector3(7.5, y + 0.8, -5.8)], Vector2(46, 44))

func window_dusk() -> void:
	var y := b.habitat_base_y
	await _move(6.0, [Vector3(-9.5, y + 1.55, -3.0), Vector3(-10.2, y + 1.55, -4.0)], [Vector3(-12.0, y + 1.5, -9.0), Vector3(-12.0, y + 1.6, -12.0)], Vector2(48, 46))

# ---------- act 3 ----------

func science() -> void:
	var y := b.habitat_base_y
	await _move(5.0, [Vector3(17.6, y + 1.5, -3.2), Vector3(16.8, y + 1.4, -4.2)], [Vector3(15.6, y + 0.9, -7.0), Vector3(15.4, y + 1.0, -7.0)], Vector2(44, 40))

func engineering() -> void:
	var y := b.habitat_base_y
	await _move(5.0, [Vector3(16.0, y + 1.5, 0.2), Vector3(14.6, y + 1.4, 0.8)], [Vector3(12.0, y + 0.8, 4.0), Vector3(13.0, y + 0.8, 4.2)], Vector2(44, 42))

func solar_field() -> void:
	await _move(5.0, [_at(4, 28, 1.2), _at(10, 28, 1.4)], [Vector3(12, 1.5, 16), Vector3(18, 1.4, 17)], Vector2(40, 40))

func storm() -> void:
	var sim: RefCounted = b.simulation()
	sim.storm_eta_hours = -1.0
	sim.storm_hours_left = 6.0
	var w = world.weather
	w._state = "storm"
	w._wall_angle = atan2(-1.0, 0.6)
	var c := centre()
	await _move(7.0, [_at(-26, 22, 2.2), _at(-22, 20, 2.4)], [c + Vector3(-2, 2, 0), c + Vector3(2, 2.5, -2)], Vector2(40, 40), func(t: float) -> void:
		# The front rolls in over the shot: haze and dust rising to a full storm.
		var level := lerpf(0.35, 1.0, t)
		w._level = level
		w._haze = level
		w._wall_amount = lerpf(0.5, 0.85, t)
		w._wall_ring = t)

# ---------- act 4 ----------

func finale() -> void:
	var c := centre()
	await _move(13.0, [_at(-6, 40, 3.2), _at(-4, 36, 8.0), _at(0, 34, 17.0)], [c + Vector3(0, 2.6, 0), c + Vector3(0, 2.5, -2), c + Vector3(0, 0.0, -8)], Vector2(40, 46))

# ---------- gameplay shots: the real UI, driven like a player ----------

func _mouse(at: Vector2) -> void:
	root.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at; motion.global_position = at
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)

func _button(at: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = pressed
	click.position = at; click.global_position = at
	Input.parse_input_event(click)

func _cell_screen(cell: Vector2i) -> Vector2:
	return b.camera.unproject_position(Vector3(cell.x * 3.0, b.habitat_base_y, cell.y * 3.0))

## Only the game's own build HUD stays: captions, toasts and the explore HUD go.
func _gameplay_ui() -> void:
	clean_ui = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		var keep: bool = layer.name in ["BuildHUD"] or layer.get_parent() == world.interior_builder
		(layer as CanvasLayer).visible = keep

## Frames for a gameplay shot: in still mode, jump to the end state and save.
func _frames(seconds: float) -> void:
	if _mode == "still": return
	for i in int(seconds * FPS):
		_gameplay_ui()
		await process_frame

func _save_still() -> void:
	if _mode != "still": return
	for i in 30:
		_gameplay_ui()
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(_still_out)

func _drag(kind: String, from: Vector2i, to: Vector2i, seconds := 1.0) -> void:
	b._select_kind(kind)
	_mouse(_cell_screen(from))
	await _frames(0.3)
	_button(_cell_screen(from), true)
	if _mode == "still":
		for i in 3: await process_frame
	var frames := 3 if _mode == "still" else int(seconds * FPS)
	for i in frames:
		var t := float(i + 1) / frames
		var c := Vector2(from).lerp(Vector2(to), t)
		_mouse(b.camera.unproject_position(Vector3(c.x * 3.0, b.habitat_base_y, c.y * 3.0)))
		await process_frame
	_button(_cell_screen(to), false)
	await _frames(0.4)

## Site plan: draw the south row of rooms onto the floor plan, then an airlock.
func siteplan() -> void:
	b.zones = b.zones.filter(func(z): return not str(z.kind) in ["life_support", "engineering"])
	b._rebuild()
	b._toggle()
	b._set_catalogue_open(true)
	b.pivot.position = Vector3(5, 0, 0)
	b.zoom = 22.0; b._zoom()
	for child in b.notice_column.get_children(): child.queue_free()
	for i in WARMUP if _mode != "still" else 20:
		_gameplay_ui()
		await process_frame
	await _drag("life_support", Vector2i(1, 0), Vector2i(3, 1), 0.9)
	await _drag("engineering", Vector2i(4, 0), Vector2i(6, 1), 0.9)
	_mouse(_cell_screen(Vector2i(8, 3)))
	await _frames(1.0)
	await _save_still()

## Power and water: a solar array turned on the plan, then an ice drill over
## the subsurface ice survey.
func power() -> void:
	b._toggle()
	b._set_catalogue_open(true)
	var deposit: Dictionary = MHGame.site().ice_deposits[0]
	var ice := Vector2(float(deposit.x), float(deposit.z))
	b.pivot.position = Vector3(ice.x - 2.0, 0, ice.y + 3.0)
	b.zoom = 30.0; b._zoom()
	b._select_kind("ice_extractor")
	for i in WARMUP if _mode != "still" else 20:
		_gameplay_ui()
		await process_frame
	var frames := 1 if _mode == "still" else int(2.6 * FPS)
	for i in frames:
		var t := 1.0 if _mode == "still" else float(i) / maxf(1.0, frames - 1)
		var p := ice + Vector2(-9.0, 6.0).lerp(Vector2(0.5, -0.5), t * t * (3.0 - 2.0 * t))
		_mouse(b.camera.unproject_position(Vector3(p.x, 0.0, p.y)))
		_gameplay_ui()
		await process_frame
	b._place_free_site()
	await _frames(1.2)
	await _save_still()

## Furnishing from inside: a bunk turned into place, then the poster.
func furnish() -> void:
	b.placed_interior = b.placed_interior.filter(func(i): return not str(i.id) in ["crew_bunk", "retro_mars_poster", "guitar"])
	b._rebuild()
	var p: CharacterBody3D = world.player
	var y := b.habitat_base_y
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.global_position = Vector3(-9.0, y + .1, -2.4)
	p.rotation.y = 0.0
	(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(-22)
	p.set_physics_process(false)
	(p.get_node("Head/Camera3D") as Camera3D).current = true
	var ib = world.interior_builder
	ib.enter()
	ib._select_item("crew_bunk")
	for i in WARMUP if _mode != "still" else 20:
		_gameplay_ui()
		await process_frame
	ib.rotation_offset = PI
	await _frames(0.8)
	ib._place_preview()
	await _frames(0.5)
	var frames := 1 if _mode == "still" else int(0.9 * FPS)
	for i in frames:
		p.rotation.y = lerp_angle(0.0, deg_to_rad(-6), float(i + 1) / frames)
		(p.get_node("Head") as Node3D).rotation.x = lerp_angle(deg_to_rad(-22), deg_to_rad(-2), float(i + 1) / frames)
		if _mode != "still": await process_frame
	ib._select_item("retro_mars_poster")
	await _frames(0.7)
	ib._place_preview()
	await _frames(1.0)
	await _save_still()
