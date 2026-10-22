class_name MHCompanionRover
extends CharacterBody3D

## GAR-Y, the Geological Analysis Rover, Y-Class: the crew's companion
## rover. Look at it for its name; E pings it, I tells you what it does.
## A self-contained, optional companion. It deliberately owns no player or
## habitat state: remove its scene or set MarsWorld.SPAWN_SCOUT_ROVER to false.
@export var follow_distance := 4.4
@export var stop_distance := 2.4
@export var catch_up_distance := 11.0
@export var walk_speed := 2.15
@export var sprint_speed := 3.65
@export var step_height := 0.34
@export var wheel_radius := 0.205

var target: Node3D
## Optional: the habitat builder. Indoors the rover roams the rooms on its own
## instead of shadowing the player.
var habitat: Node
var _roam_goal := Vector3.INF
var _roam_timer := 0.0
var _stuck_timer := 0.0
var _wheels: Array[Node3D] = []
var _mast: Node3D
var _lamp: SpotLight3D
var _scan_time := 0.0
var _idle_time := 0.0
var _wander_phase := 0.0
var _scout_anchor := Vector3.ZERO
var _anchor_player_position := Vector3.ZERO
var _has_scout_anchor := false
var _chirp_timer := 0.0

func setup(follow_target: Node3D) -> MHCompanionRover:

	target = follow_target
	return self

func _ready() -> void:

	floor_snap_length = step_height + .20
	floor_max_angle = deg_to_rad(54.0)
	safe_margin = .04
	_wander_phase = randf() * TAU
	_chirp_timer = randf_range(4.0, 8.0)
	# The model ships hubs only (lowest point 0.14 m), which reads as hovering.
	# Each corner gets a treaded tyre that meets the ground, and the tyre, hub
	# and cap spin together about the hub's axle.
	for wheel_name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wheel := _build_tyre(find_child(wheel_name + "_Mount", true, false) as Node3D)
		if wheel != null:
			_wheels.append(wheel)
	_mast = find_child("Mast_Control", true, false) as Node3D
	_lamp = get_node_or_null("ScoutFlashlight") as SpotLight3D

func _build_tyre(mount: Node3D) -> Node3D:

	if mount == null:
		return null
	var hub := mount.find_child("*_Hub", false, false) as MeshInstance3D
	if hub == null:
		return null
	var hub_box: AABB = hub.transform * hub.get_aabb()
	var pivot := Node3D.new()
	pivot.name = "TyrePivot"
	pivot.position = hub_box.get_center()
	mount.add_child(pivot)
	for part in mount.get_children():
		if part != pivot and part is MeshInstance3D:
			var keep: Transform3D = (part as Node3D).transform
			mount.remove_child(part)
			pivot.add_child(part)
			(part as Node3D).transform = pivot.transform.affine_inverse() * keep
	# Tyre: the hub's centre sits wheel_radius above the ground plane.
	var width := maxf(hub_box.size.x, .11) + .03
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#1E2124")
	rubber.roughness = .95
	var tyre := MeshInstance3D.new()
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = wheel_radius - .02
	tyre_mesh.bottom_radius = wheel_radius - .02
	tyre_mesh.height = width
	tyre_mesh.radial_segments = 24
	tyre.mesh = tyre_mesh
	tyre.material_override = rubber
	tyre.rotation.z = PI * .5
	pivot.add_child(tyre)
	# Chunky tread blocks round the rim so the rolling reads clearly.
	var tread_mesh := BoxMesh.new()
	tread_mesh.size = Vector3(width + .01, .045, .06)
	for index in 14:
		var angle := TAU * index / 14.0
		var tread := MeshInstance3D.new()
		tread.mesh = tread_mesh
		tread.material_override = rubber
		tread.rotation.x = angle
		tread.position = Vector3(0, cos(angle), sin(angle)) * (wheel_radius - .03)
		pivot.add_child(tread)
	return pivot

func _physics_process(delta: float) -> void:

	if target == null:
		return
	# Build mode uses an isometric construction camera. Keeping the rover out of
	# sight avoids it obstructing planned cells and makes this companion harmless.
	visible = not bool(target.get_meta("build_mode_active", false))
	if not visible:
		velocity = Vector3.ZERO
		return

	var desired := _follow_point()
	var flat_delta := desired - global_position
	flat_delta.y = 0.0
	var distance := flat_delta.length()
	var before := global_position
	if distance > stop_distance:
		_idle_time = 0.0
		var direction := flat_delta.normalized()
		var maximum := sprint_speed if distance > follow_distance * 2.4 else walk_speed
		var speed := minf(maximum, (distance - stop_distance) * 1.35)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var desired_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, minf(delta * 7.0, 1.0))
	else:
		_idle_time += delta
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 5.0 * delta)

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = -.1
	move_and_slide()
	_try_step_over_threshold(flat_delta)
	# Indoors: a roaming rover that stalls against a wall picks somewhere else.
	if _roam_goal != Vector3.INF and distance > stop_distance:
		var progress := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		_stuck_timer = _stuck_timer + delta if progress < .01 else 0.0
		if _stuck_timer > 1.5:
			_stuck_timer = 0.0
			_roam_goal = _pick_roam_goal()
	_animate_motion(before, delta)
	_pet_sounds(delta)
	# A companion that becomes stranded far away respawns behind the player. This
	# avoids a permanent lost rover without teleporting during ordinary movement.
	if global_position.distance_to(target.global_position) > catch_up_distance:
		global_position = _spawn_point()
		velocity = Vector3.ZERO

func _follow_point() -> Vector3:
	if _indoors():
		_roam_timer -= get_physics_process_delta_time()
		if _roam_goal == Vector3.INF or _roam_timer <= 0.0:
			_roam_goal = _pick_roam_goal()
			_roam_timer = randf_range(7.0, 14.0)
		if _roam_goal != Vector3.INF: return _roam_goal
	else:
		_roam_goal = Vector3.INF

	# Do not recompute the rover's side simply because the player looks around.
	# It commits to a small scouting spot until the astronaut has actually moved
	# onward, which prevents a distracting orbit around the camera.
	if not _has_scout_anchor or target.global_position.distance_to(_anchor_player_position) > 2.5:
		_anchor_player_position = target.global_position
		_scout_anchor = _choose_scout_anchor()
		_has_scout_anchor = true
	var patrol := Vector3.ZERO
	if _idle_time > 1.0:
		# A shallow figure-eight makes the rover feel curious while keeping its
		# exploration contained around the spot it chose.
		patrol.x = sin(_scan_time * .31 + _wander_phase) * .55
		patrol.z = sin(_scan_time * .54 + _wander_phase) * .35
	return _scout_anchor + patrol

func _indoors() -> bool:
	return habitat != null and habitat.has_method("is_inside") and habitat.is_inside(target.global_position) and habitat.is_inside(global_position)

## Somewhere in a habitat room near the player: a random room cell centre.
func _pick_roam_goal() -> Vector3:
	var spots: Array = []
	for zone in habitat.zones:
		if not habitat._is_habitat_zone(zone): continue
		for cell in zone.get("cells", []):
			var spot := Vector3(cell.x * 3.0, global_position.y, cell.y * 3.0)
			if spot.distance_to(target.global_position) < 9.0 and spot.distance_to(global_position) > 1.5 and habitat.is_inside(spot): spots.append(spot)
	return spots.pick_random() if not spots.is_empty() else Vector3.INF

func _choose_scout_anchor() -> Vector3:

	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < .001:
		forward = Vector3.FORWARD
	var side := target.global_transform.basis.x
	side.y = 0.0
	if side.length_squared() < .001:
		side = Vector3.RIGHT
	return target.global_position + forward.normalized() * 1.5 + side.normalized() * follow_distance

func _spawn_point() -> Vector3:

	var point := _follow_point()
	point.y = target.global_position.y + .15
	return point

func _try_step_over_threshold(flat_delta: Vector3) -> void:

	# Airlock and deck thresholds are small but can be treated as a wall by a
	# character collider. A short, capped lift lets this high-clearance rover roll
	# over them, then floor snapping settles it onto the destination deck.
	if not is_on_wall() or flat_delta.length_squared() < .04:
		return
	var raised := global_position + Vector3.UP * step_height
	# CharacterBody3D.test_move expects a transform and motion vector directly.
	# Test the short forward roll from the lifted position before stepping up.
	if not test_move(Transform3D(global_transform.basis, raised), flat_delta.normalized() * .26):
		global_position = raised
		velocity.y = 0.0

func _animate_motion(before: Vector3, delta: float) -> void:

	var moved := global_position - before
	moved.y = 0.0
	var roll := moved.length() / wheel_radius
	if moved.dot(-global_transform.basis.z) < 0.0:
		roll = -roll
	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.RIGHT, roll)
	_scan_time += delta
	if _mast != null:
		# The mast only gives its full, pet-like scan once it has settled nearby.
		var scan_strength := 1.0 if _idle_time > 1.0 else .35
		_mast.rotation.z = sin(_scan_time * .85) * deg_to_rad(12.0) * scan_strength
		_mast.rotation.y = sin(_scan_time * .46) * deg_to_rad(18.0) * scan_strength
	if _lamp != null:
		_lamp.rotation.y = sin(_scan_time * .46) * deg_to_rad(10.0)
		_lamp.light_energy = 3.25 + sin(_scan_time * 1.7) * .18

const NAME := "GAR-Y"
const FULL_NAME := "Geological Analysis Rover, Y-Class"
const ABOUT := "GAR-Y is a multipurpose rover designed for geological surveys, surface sample collection, terrain mapping and identifying potential water-ice deposits."

# ---------- look at it (explore HUD) ----------

func interaction_prompt() -> Dictionary:
	return {"label": "%s · %s" % [NAME, FULL_NAME], "primary": "Ping", "info": "About"}

## A ping: it chirps back and sweeps its mast round.
func interact(_actor: Node = null) -> bool:
	MHAudio.sfx_at("rover_chirp", self, -6.0, .6)
	_scan_time += PI
	_chirp_timer = randf_range(7.0, 13.0)
	return true

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "%s — %s" % [NAME, FULL_NAME], ABOUT)
	return true

func _pet_sounds(delta: float) -> void:

	# Keep the companion quiet while travelling. Its occasional two-note radio
	# chirp is a gentle acknowledgement once it has settled into its scout spot.
	if _idle_time < 2.5:
		return
	_chirp_timer -= delta
	if _chirp_timer > 0.0:
		return
	MHAudio.sfx_at("rover_chirp", self, -14.0)
	_chirp_timer = randf_range(7.0, 13.0)
