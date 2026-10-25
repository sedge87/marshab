extends CharacterBody3D

## The crew rover: the EVA-6, a small pressurised six-wheeler you can drive
## (model: asset_packs/mars_eva6_rover_v1, fitted from the user's design on
## 25 Oct; the first model is in mars_crew_rover_v1). It lives in the vehicle
## bay: it appears
## there when the base has one, charges while it's parked inside, and opens
## the bay's hangar door as you drive up to it (shutting it again once you're
## through), through the bay's interlock.
##
## Look at it and press E to get in. Driving: W/S throttle and reverse,
## A/D steer, Space brake, F headlights, V cab or chase view, mouse to look,
## E to get out (on the driver's side, or wherever there's room), R to
## recover it if it's wedged against something.
##
## From the EVA-6 design: the roof solar panel trickle-charges the battery in
## daylight, and the tail lights glow red when braking or reversing.
##
## Running flat: when the main battery empties, a reserve takes over (about
## 600 m at reduced speed, recharged only in the bay) and the HUD points home.
## With both empty it can only crawl on its roof solar, in daylight; at night
## it waits for sunrise. The rover charger in the bay can recall it: it drives
## itself home on whatever it has (never on solar at night).
##
## Arcade handling on a bicycle model; the body follows the ground with four
## rays (pitch, roll and height, like suspension), and its collision box sits
## above the wheels so small rocks don't stop it, but walls and machines do.

const MODEL_PATH := "res://assets/vehicles/crew_rover.glb"
const CARGO_LANDER := preload("res://scripts/cargo_lander.gd")   # its soft dust puff
const MHPalette := preload("res://scripts/mh_palette.gd")
const MAX_SPEED := 6.5          # m/s (about 23 km/h)
const REVERSE_SPEED := 2.5
const LIMP_SPEED := 1.0         # both batteries flat: crawling on roof solar (daylight only)
const RESERVE_SPEED := 3.0      # m/s on the reserve battery
const RESERVE_DRAIN_PER_M := 1.0 / 6.0   # reserve % per metre (about 600 m)
const DAYLIGHT := 0.1           # sunlight above this powers the solar crawl
const ACCEL := 2.3
const BRAKE := 6.5
const COAST := 0.9
const STEER_MAX := 0.52         # rad, front wheels; the rear pair steers half as much the other way
const WHEELBASE := 2.9
const WHEEL_R := 0.366
const HALF_TRACK := 0.99
const HALF_BASE := 1.29
const DRAIN_PER_M := 1.0 / 40.0 # battery % per metre driven (about 4 km a charge)
const CHARGE_PER_S := 1.5       # % a second, parked in the vehicle bay
const SOLAR_PER_S := 0.05       # % a second from the roof panel in full sun (3% a minute)
const SEAT := Vector3(-0.4, 1.5, -0.7)       # the driver's seat, in the rover's space (front is -Z)
const CAB_VIEW := Vector3(0.0, 1.45, -1.42)   # V: the view over the nose (the cab itself is closed)
const CHASE_DISTANCE := 7.5
const CHASE_HEIGHT := 2.6

var builder: Node
var speed := 0.0
var steer := 0.0
var battery := 100.0
var reserve := 100.0
## Driving itself home after a recall from the rover charger.
var recalling := false
var lights_on := false
var driving := false
var first_person := false

var _player: CharacterBody3D
var _model: Node3D
var _wheels := {}               # name -> Node3D
var _cam: Camera3D
var _look := Vector2(0.0, -0.22)   # camera yaw and pitch offsets (mouse)
var _pitch := 0.0
var _roll := 0.0
var _lights: Array[Light3D] = []
var _motor: AudioStreamPlayer3D
var _dust: Array[CPUParticles3D] = []
var _hud: CanvasLayer
var _readout: Label
var _hangar: Node = null        # the hangar door this rover opened
var _player_layers := Vector2i.ZERO
var _was_charging := false
var _tail_lights: Array[MeshInstance3D] = []
var _tail_glow: StandardMaterial3D
var _braking := false
var _recall_stage := ""         # "approach" (outside the hangar), then "enter"
var _stuck := 0.0
var _backing := 0.0

func setup(target_builder: Node) -> void:
	builder = target_builder

func _ready() -> void:
	add_to_group("crew_rover")
	set_meta("interaction_target", self)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.25, 1.5, 4.05)
	shape.shape = box
	shape.position = Vector3(0, 0.45 + box.size.y * .5, 0)
	add_child(shape)
	var scene := load(MODEL_PATH) as PackedScene
	_model = Node3D.new()
	_model.name = "Body"
	add_child(_model)
	if scene != null:
		var visual := scene.instantiate() as Node3D
		_model.add_child(visual)
		MHPalette.apply(visual)
		for node in visual.find_children("wheel_*", "Node3D", true, false):
			_wheels[str(node.name).substr(6, 2)] = node
		_tail_lights.assign(visual.find_children("tail_light_red*", "MeshInstance3D", true, false))
		_tail_glow = StandardMaterial3D.new()
		_tail_glow.albedo_color = Color("#E5484D")
		_tail_glow.emission_enabled = true
		_tail_glow.emission = Color("#FF3B30")
		_tail_glow.emission_energy_multiplier = 2.5
	_build_lights()
	_build_dust()
	_build_motor()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 2000.0
	add_child(_cam)
	_cam.top_level = true

# ---------- interaction ----------

func interaction_prompt() -> Dictionary:
	return {"label": "Crew rover · battery %d%%" % roundi(battery), "primary": "Drive", "secondary": "Headlights off" if lights_on else "Headlights on", "info": "About"}

func interact(_actor: Node = null) -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or driving: return false
	_get_in(player)
	return true

func interact_secondary(_actor: Node = null) -> bool:
	_set_lights(not lights_on)
	return true

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "Crew rover",
		"The EVA-6: a pressurised rover with a rear docking hatch and a roof solar panel. About 4 km to a charge, then a reserve for about 600 m; it charges in the vehicle bay, and the roof panel tops it up by day (never at night). The rover charger in the bay can recall it home. W/S drive, A/D steer, Space brake, F lights, V view, R free it, E get out.")
	return true

# ---------- getting in and out ----------

func _get_in(player: CharacterBody3D) -> void:
	_player = player
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world != null and world.get("carry") != null: world.carry.put_back()
	driving = true
	preload("res://scripts/feature_hints.gd").first(get_tree(), "rover")
	player.set_meta("driving", true)
	player.visible = false
	_player_layers = Vector2i(player.collision_layer, player.collision_mask)
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	_look = Vector2(0.0, -0.22)
	_cam.current = true
	_place_camera(1.0)
	_set_explore_hud(false)
	_show_hud(true)
	MHAudio.sfx("door_close", -6.0)

func _get_out() -> void:
	if _player == null: return
	var spot := _exit_spot()
	driving = false
	speed = 0.0
	_player.global_position = spot
	_player.rotation.y = rotation.y
	if "safe_position" in _player: _player.safe_position = spot
	_player.collision_layer = _player_layers.x
	_player.collision_mask = _player_layers.y
	_player.visible = true
	_player.set_meta("driving", false)
	var head_camera := _player.get_node_or_null("Head/Camera3D") as Camera3D
	if head_camera != null: head_camera.current = true
	_set_explore_hud(true)
	_show_hud(false)
	MHAudio.sfx("door_open", -6.0)
	_player = null

## Beside the driver's door, or the other side, or behind: the first spot
## with room to stand and ground under it.
func _exit_spot() -> Vector3:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	for local in [Vector3(-2.0, 0, 0.2), Vector3(2.0, 0, 0.2), Vector3(0, 0, 3.2), Vector3(0, 0, -3.4)]:
		var at: Vector3 = global_transform * local
		var ground := _ground_at(at)
		if is_inf(ground): continue
		var stand := Vector3(at.x, ground + 0.05, at.z)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, stand + Vector3.UP * 0.95)
		query.exclude = [get_rid()]
		if space.intersect_shape(query, 1).is_empty(): return stand
	return global_transform * Vector3(-2.0, 0, 0) + Vector3.UP * 0.1

func _set_explore_hud(on: bool) -> void:
	for hud in get_tree().get_nodes_in_group("explore_hud"):
		if hud is CanvasLayer: (hud as CanvasLayer).visible = on

# ---------- input while driving ----------

func _unhandled_input(event: InputEvent) -> void:
	if not driving or get_tree().paused: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look.x = wrapf(_look.x - event.relative.x * 0.0025, -PI, PI)
		_look.y = clampf(_look.y - event.relative.y * 0.0025, -1.1, 0.5)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_get_out()
				get_viewport().set_input_as_handled()
			KEY_F:
				_set_lights(not lights_on)
				get_viewport().set_input_as_handled()
			KEY_V:
				first_person = not first_person
				_look = Vector2(0.0, -0.2 if first_person else -0.22)
				get_viewport().set_input_as_handled()
			KEY_R:
				_recover()
				get_viewport().set_input_as_handled()
			KEY_B:
				get_viewport().set_input_as_handled()   # no building from the driver's seat

# ---------- driving ----------

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_in := 0.0
	var braking := false
	if driving and not get_tree().paused and not bool(_player.get_meta("ui_freeze", false)):
		throttle = _axis(KEY_W, "move_forward") - _axis(KEY_S, "move_back")
		steer_in = _axis(KEY_A, "move_left") - _axis(KEY_D, "move_right")
		braking = Input.is_key_pressed(KEY_SPACE)
	elif recalling and not get_tree().paused:
		var drive := _autopilot(delta)
		throttle = drive.x
		steer_in = drive.y
	var top := top_speed()
	_set_braking(braking or (throttle < 0.0 and speed < 0.05))
	if braking:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	elif throttle > 0.0:
		speed = move_toward(speed, 0.0, BRAKE * delta) if speed < -0.05 else move_toward(speed, top * throttle, ACCEL * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0, BRAKE * delta) if speed > 0.05 else move_toward(speed, -minf(REVERSE_SPEED, top), ACCEL * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	var steer_limit := STEER_MAX * lerpf(1.0, 0.45, clampf(absf(speed) / MAX_SPEED, 0.0, 1.0))
	steer = move_toward(steer, steer_in * steer_limit, 1.8 * delta)
	rotation.y += speed * tan(steer) / WHEELBASE * delta
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	velocity = forward * speed
	var before := global_position
	move_and_slide()
	# Bumping into something solid takes the speed off.
	if get_slide_collision_count() > 0:
		var moved := (global_position - before).length()
		if moved < absf(speed) * delta * 0.5:
			if absf(speed) > 2.5: MHAudio.sfx("land", -4.0)
			speed *= 0.3
	_follow_ground(delta)
	_spin_wheels(delta, global_position.distance_to(before))
	_battery(delta, Vector2(global_position.x - before.x, global_position.z - before.z).length())
	_hangar_doors()
	_update_effects()
	if driving:
		_player.global_position = global_transform * SEAT - Vector3.UP * 1.6
		_place_camera(delta)
		_update_hud()

func _axis(key: Key, action: String) -> float:
	return 1.0 if Input.is_key_pressed(key) or (InputMap.has_action(action) and Input.is_action_pressed(action)) else 0.0

## Height, pitch and roll from the ground under the four corner wheels.
func _follow_ground(delta: float) -> void:
	var fl := _ground_at(global_transform * Vector3(-HALF_TRACK, 0, -HALF_BASE))
	var fr := _ground_at(global_transform * Vector3(HALF_TRACK, 0, -HALF_BASE))
	var rl := _ground_at(global_transform * Vector3(-HALF_TRACK, 0, HALF_BASE))
	var rr := _ground_at(global_transform * Vector3(HALF_TRACK, 0, HALF_BASE))
	var heights := [fl, fr, rl, rr].filter(func(h): return not is_inf(h))
	if heights.is_empty(): return
	var mean := 0.0
	for h in heights: mean += h
	mean /= heights.size()
	if is_inf(fl): fl = mean
	if is_inf(fr): fr = mean
	if is_inf(rl): rl = mean
	if is_inf(rr): rr = mean
	var target := maxf(mean, maxf(maxf(fl, fr), maxf(rl, rr)) - 0.25)
	var rate := 10.0 if target > global_position.y else 6.0
	global_position.y = lerpf(global_position.y, target, minf(1.0, delta * rate))
	var pitch := atan2(((fl + fr) - (rl + rr)) * 0.5, HALF_BASE * 2.0)
	var roll := atan2(((rl + fl) - (rr + fr)) * 0.5, HALF_TRACK * 2.0)
	_pitch = lerpf(_pitch, pitch, minf(1.0, delta * 8.0))
	_roll = lerpf(_roll, roll, minf(1.0, delta * 8.0))
	_model.rotation = Vector3(_pitch, 0.0, -_roll)
	# Each wheel finds its own ground (a hint of suspension travel).
	for key in _wheels:
		var wheel: Node3D = _wheels[key]
		var corner := {"fl": fl, "fr": fr, "ml": (fl + rl) * .5, "mr": (fr + rr) * .5, "rl": rl, "rr": rr}
		if not wheel.has_meta("rest_y"): wheel.set_meta("rest_y", wheel.position.y)
		var offset := clampf(float(corner.get(str(key), mean)) - global_position.y, -0.12, 0.12)
		wheel.position.y = float(wheel.get_meta("rest_y")) + offset

## The ground (or floor, or ramp) under a point; INF if there's none.
func _ground_at(at: Vector3) -> float:
	var from := Vector3(at.x, global_position.y + 1.4, at.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0)
	query.exclude = [get_rid()]
	if _player != null: query.exclude.append(_player.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float((hit.position as Vector3).y) if not hit.is_empty() else INF

func _spin_wheels(delta: float, moved: float) -> void:
	var turn := moved / WHEEL_R * signf(speed)
	for key in _wheels:
		var wheel: Node3D = _wheels[key]
		var axle := str(key).substr(0, 1)
		var yaw := steer if axle == "f" else (-steer * 0.5 if axle == "r" else 0.0)
		var spin := float(wheel.get_meta("spin", 0.0)) - turn
		wheel.set_meta("spin", spin)
		wheel.transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, spin)

## What it can do now: full speed on the battery, slower on the reserve, a
## solar crawl by day with both flat, nothing at night.
func top_speed() -> float:
	if battery > 0.0: return MAX_SPEED
	if reserve > 0.0: return RESERVE_SPEED
	return LIMP_SPEED if MHGame.sunlight_fraction > DAYLIGHT else 0.0

func _battery(delta: float, moved: float) -> void:
	if battery > 0.0: battery = maxf(0.0, battery - moved * DRAIN_PER_M)
	elif reserve > 0.0:
		var was := reserve
		reserve = maxf(0.0, reserve - moved * RESERVE_DRAIN_PER_M)
		if was > 99.9 and driving: _flash("Main battery flat", "Running on the reserve: about 600 m. Head home to the vehicle bay.")
		if was > 0.0 and reserve <= 0.0 and driving: _flash("Reserve flat", "Crawling on solar by day only. At night it can't move until sunrise.")
	var charging := _in_bay() and absf(speed) < 0.1
	if charging:
		battery = minf(100.0, battery + CHARGE_PER_S * delta)
		reserve = minf(100.0, reserve + CHARGE_PER_S * delta)
	# The roof panel, in daylight, wherever it is outside.
	elif not _in_bay(): battery = minf(100.0, battery + SOLAR_PER_S * clampf(MHGame.sunlight_fraction, 0.0, 1.0) * delta)
	if charging and not _was_charging and driving and battery < 99.0: MHAudio.sfx("ui_confirm", -8.0)
	_was_charging = charging

func _flash(title: String, text: String) -> void:
	get_tree().call_group("explore_hud", "show_equipment_note", title, text)
	MHAudio.sfx("warn", -6.0)

# ---------- recall ----------

## The first vehicle bay: {centre, door (the hangar's outside face), out}.
func _home() -> Dictionary:
	if builder == null: return {}
	for zone in builder.zones:
		if str(zone.get("kind", "")) != "vehicle_bay": continue
		var outside: Vector2i = zone.get("door_direction", Vector2i(0, -1))
		var face: Dictionary = builder._zone_face(zone, outside)
		var centre := Vector2.ZERO
		for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
		centre /= float((zone.cells as Array).size())
		var door: Vector3 = face.position
		return {"centre": centre, "door": Vector2(door.x, door.z), "out": Vector2(outside)}
	return {}

## Called by the rover charger: drive home on its own. Returns what to tell
## the player.
func recall() -> String:
	var home := _home()
	if home.is_empty(): return "There's no vehicle bay to come home to."
	if driving: return "Someone's driving it."
	if _in_bay(): return "The rover's already here in the bay."
	if top_speed() <= 0.0: return "Its battery and reserve are flat and it's dark: it can't move until sunrise, when its roof panel can crawl it home."
	recalling = true
	_recall_stage = "approach"
	_stuck = 0.0
	var how := "on its battery" if battery > 0.0 else ("on its reserve" if reserve > 0.0 else "slowly, on its roof solar")
	return "Recalled: the rover is driving home %s, %d m away." % [how, roundi(Vector2(global_position.x, global_position.z).distance_to(home.centre))]

## Steering for the drive home: [throttle, steer]. Out to a point in front of
## the hangar, then straight in to the middle of the bay. If it stops making
## progress it backs off and tries again.
func _autopilot(delta: float) -> Vector2:
	var home := _home()
	if home.is_empty():
		recalling = false
		return Vector2.ZERO
	var at := Vector2(global_position.x, global_position.z)
	var approach: Vector2 = home.door + home.out * 7.0
	var target: Vector2 = approach if _recall_stage == "approach" else home.centre
	if _recall_stage == "approach" and at.distance_to(approach) < 2.5: _recall_stage = "enter"
	if _recall_stage == "enter" and at.distance_to(home.centre) < 1.2:
		recalling = false
		speed = 0.0
		if _hangar != null and _hangar.is_open(): _hangar.request_shut()
		_hangar = null
		return Vector2.ZERO
	if top_speed() <= 0.0:   # nightfall on solar: it stops and waits
		return Vector2.ZERO
	if _backing > 0.0:
		_backing -= delta
		return Vector2(-1.0, 0.6)
	if absf(speed) < 0.2:
		_stuck += delta
		if _stuck > 2.5:
			_stuck = 0.0
			_backing = 1.5
	else:
		_stuck = 0.0
	var to := target - at
	var wanted := atan2(-to.x, -to.y)
	var error := wrapf(wanted - rotation.y, -PI, PI)
	var near := clampf(at.distance_to(target) / 6.0, 0.35, 1.0)
	return Vector2(near if absf(error) < 1.4 else 0.4, clampf(error * 1.6, -1.0, 1.0))

## Tail lights glow while braking or reversing.
func _set_braking(on: bool) -> void:
	if on == _braking: return
	_braking = on
	for light in _tail_lights: light.material_override = _tail_glow if on else null

## R: wedged against something? Back it off a couple of metres onto open ground.
func _recover() -> void:
	if absf(speed) > 1.0: return
	var back := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	for distance in [2.5, -2.5, 4.0]:
		var test := global_transform.translated(back * distance)
		if not test_move(test, Vector3.ZERO):
			global_position += back * distance
			speed = 0.0
			MHAudio.sfx("place", -6.0)
			return
	MHAudio.sfx("invalid")

func _in_bay() -> bool:
	if builder == null: return false
	var zone: Dictionary = builder._zone_at_point(Vector2(global_position.x, global_position.z))
	return not zone.is_empty() and str(zone.get("kind", "")) == "vehicle_bay"

## The hangar door opens as you drive up to it (sealing the bay's other doors
## first, through the interlock) and shuts once you're well clear.
func _hangar_doors() -> void:
	if not driving and not recalling:
		return
	var nearest: Node = null
	var nearest_distance := 1e9
	for door in get_tree().get_nodes_in_group("airlock_door"):
		if not door.has_method("door_label") or str(door.door_label()) != "HANGAR": continue
		var d := (door as Node3D).global_position.distance_to(global_position)
		if d < nearest_distance:
			nearest = door
			nearest_distance = d
	if nearest == null: return
	var to_door := (nearest as Node3D).global_position - global_position
	to_door.y = 0.0
	var heading := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)) * signf(speed if absf(speed) > 0.05 else 1.0)
	if nearest_distance < 8.5 and absf(speed) > 0.05 and heading.dot(to_door.normalized()) > 0.55:
		if not nearest.is_open(): nearest.request_open()
		_hangar = nearest
	elif _hangar != null and _hangar.is_open() and ((_hangar as Node3D).global_position.distance_to(global_position) > 9.5 or (_in_bay() and nearest_distance > 3.5 and absf(speed) < 0.3)):
		# Well clear outside, or parked inside: shut it behind you.
		_hangar.request_shut()
		_hangar = null

# ---------- camera ----------

func _place_camera(delta: float) -> void:
	if first_person:
		_cam.global_position = _model.global_transform * CAB_VIEW
		_cam.global_transform.basis = Basis(Vector3.UP, rotation.y + _look.x) * Basis(Vector3.RIGHT, _look.y)
		return
	var yaw := rotation.y + _look.x
	var target := global_position + Vector3.UP * 1.5
	var back := Vector3(sin(yaw), 0.0, cos(yaw)) * CHASE_DISTANCE * cos(_look.y) + Vector3.UP * (CHASE_HEIGHT - 1.5 - sin(_look.y) * CHASE_DISTANCE)
	var wanted := target + back
	# Don't put the camera through a wall or the ground.
	var query := PhysicsRayQueryParameters3D.create(target, wanted)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): wanted = target + (hit.position - target) * 0.9
	_cam.global_position = _cam.global_position.lerp(wanted, minf(1.0, delta * 6.0))
	if _cam.global_position.distance_to(target) > 0.1: _cam.look_at(target, Vector3.UP)

# ---------- lights, dust, sound ----------

func _build_lights() -> void:
	# The EVA-6's two forward searchlights, and a roof light over the cab.
	for x in [-0.66, 0.66]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(x, 0.88, -2.05)
		lamp.rotation.x = deg_to_rad(-8)
		lamp.spot_range = 28.0
		lamp.spot_angle = 32.0
		lamp.light_energy = 3.2
		lamp.light_color = Color("#FFF1DA")
		lamp.shadow_enabled = false
		_model.add_child(lamp)
		_lights.append(lamp)
	var bar := SpotLight3D.new()
	bar.position = Vector3(0, 2.2, -1.0)
	bar.rotation.x = deg_to_rad(-20)
	bar.spot_range = 22.0
	bar.spot_angle = 50.0
	bar.light_energy = 2.0
	bar.light_color = Color("#F6F8FF")
	_model.add_child(bar)
	_lights.append(bar)
	_set_lights(false)

func _set_lights(on: bool) -> void:
	lights_on = on
	for lamp in _lights: lamp.visible = on
	if is_inside_tree(): MHAudio.sfx("ui_click", -10.0)

func _build_dust() -> void:
	for x in [-HALF_TRACK, HALF_TRACK]:
		var dust := CPUParticles3D.new()
		dust.amount = 40
		dust.lifetime = 1.6
		dust.emitting = false
		dust.local_coords = false
		dust.direction = Vector3(0, 0.6, 1)
		dust.spread = 25.0
		dust.initial_velocity_min = 0.6
		dust.initial_velocity_max = 1.6
		dust.gravity = Vector3(0, -0.4, 0)
		dust.scale_amount_min = 0.6
		dust.scale_amount_max = 1.6
		var puff := QuadMesh.new()
		puff.size = Vector2(0.9, 0.9)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(MHStyle.DUST_200, 0.22)
		m.albedo_texture = CARGO_LANDER.soft_puff_texture()
		puff.material = m
		dust.mesh = puff
		dust.position = Vector3(x, 0.2, HALF_BASE + 0.4)
		add_child(dust)
		_dust.append(dust)

func _build_motor() -> void:
	_motor = AudioStreamPlayer3D.new()
	var hum := load("res://assets/audio/ambience/hum.wav") as AudioStreamWAV
	if hum != null:
		hum = hum.duplicate() as AudioStreamWAV
		hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum.loop_begin = 0
		hum.loop_end = int(hum.get_length() * hum.mix_rate)
		_motor.stream = hum
	_motor.unit_size = 6.0
	_motor.volume_db = -14.0
	_motor.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_motor)

func _update_effects() -> void:
	var moving := absf(speed) > 1.2 and not _in_bay()
	for dust in _dust:
		if dust.emitting != moving: dust.emitting = moving
	if _motor.stream == null: return
	var running := driving or absf(speed) > 0.05
	if running and not _motor.playing: _motor.play()
	elif not running and _motor.playing: _motor.stop()
	_motor.pitch_scale = 0.75 + absf(speed) / MAX_SPEED * 0.6
	_motor.volume_db = -16.0 + absf(speed) / MAX_SPEED * 6.0

# ---------- the driving HUD ----------

func _show_hud(on: bool) -> void:
	if on and _hud == null:
		_hud = CanvasLayer.new()
		_hud.layer = 6
		add_child(_hud)
		var panel := MHStyle.hud_panel(16.0)
		# Lower left, clear of ARDEN's captions in the middle.
		panel.anchor_left = 0.0; panel.anchor_right = 0.0
		panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
		panel.offset_left = 32; panel.offset_right = 470
		panel.offset_top = -168; panel.offset_bottom = -90
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(panel)
		var column := MHStyle.vbox(4)
		panel.add_child(column)
		column.add_child(MHStyle.eyebrow("CREW ROVER"))
		_readout = MHStyle.mono("", 18)
		column.add_child(_readout)
		_hud.add_child(MHStyle.hint_strip([[["W", "S"], "Drive"], [["A", "D"], "Steer"], [["Space"], "Brake"], [["F"], "Lights"], [["V"], "View"], [["R"], "Recover"], [["E"], "Get out", "accent"]]))
	if _hud != null: _hud.visible = on

func _update_hud() -> void:
	if _readout == null: return
	var solar := not _was_charging and MHGame.sunlight_fraction > DAYLIGHT and battery < 100.0
	var power := "battery %d%%" % roundi(battery) if battery > 0.0 else ("RESERVE %d%%" % roundi(reserve) if reserve > 0.0 else "FLAT")
	var state := ""
	if _was_charging: state = "charging"
	elif battery <= 0.0: state = _home_marker() + ("" if reserve > 0.0 else ("   ·   solar crawl" if top_speed() > 0.0 else "   ·   dark: wait for sunrise"))
	elif solar and absf(speed) < 0.1: state = "solar topping up"
	elif lights_on: state = "lights on"
	_readout.text = "%3d km/h   ·   %s%s" % [roundi(absf(speed) * 3.6), power, "   ·   " + state if not state.is_empty() else ""]
	_readout.modulate = MHStyle.DANGER if battery < 15.0 else MHStyle.TEXT_PRIMARY

## "home 240 m" with an arrow: the way back to the vehicle bay, from where
## the rover faces.
func _home_marker() -> String:
	var home := _home()
	if home.is_empty(): return "no vehicle bay"
	var to: Vector2 = home.centre - Vector2(global_position.x, global_position.z)
	var bearing := wrapf(atan2(-to.x, -to.y) - rotation.y, -PI, PI)
	var arrows := ["\u2191", "\u2196", "\u2190", "\u2199", "\u2193", "\u2198", "\u2192", "\u2197"]
	var arrow: String = arrows[posmod(roundi(bearing / (PI / 4.0)), 8)]
	return "home %d m %s" % [roundi(to.length()), arrow]

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "battery": battery, "reserve": reserve, "lights": lights_on, "recalling": recalling}

func restore_state(state: Dictionary) -> void:
	if state.has("position"): global_position = state.position as Vector3
	rotation.y = float(state.get("yaw", rotation.y))
	battery = float(state.get("battery", battery))
	reserve = float(state.get("reserve", reserve))
	if bool(state.get("recalling", false)):
		recalling = true
		_recall_stage = "approach"
	_set_lights(bool(state.get("lights", false)))
