extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const MOUSE_SENSITIVITY := 0.0025
# Tunable Martian movement values. 5.3 m/s against 14 m/s² reaches roughly 1 m.
const GRAVITY := 14.0
const JUMP_VELOCITY := 5.3

@onready var head: Node3D = $Head
var safe_position := Vector3.ZERO
var _jump_was_pressed := false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Lets the controller follow small terrain undulations without hopping or snagging.
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(52.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if not _use_nearby_habitat_ladder():
			_toggle_nearby_airlock_door()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
	# Build Mode needs a free cursor for repeated placement clicks. The builder
	# marks the player while its isometric camera is active.
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not bool(get_meta("build_mode_active", false)):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if global_position.y < -30.0:
		global_position = safe_position
		velocity = Vector3.ZERO
		return
	var grounded := is_on_floor()
	var jump_pressed := Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE)
	if grounded and jump_pressed and not _jump_was_pressed:
		velocity.y = JUMP_VELOCITY
	elif not grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	_jump_was_pressed = jump_pressed
	# Input actions are retained for remapping. Direct key checks are a reliable
	# fallback if a Project Settings input map is unavailable or damaged.
	var input_vector := Vector2(
		_axis_pressed("move_right", KEY_D) - _axis_pressed("move_left", KEY_A),
		_axis_pressed("move_back", KEY_S) - _axis_pressed("move_forward", KEY_W)
	)
	input_vector = input_vector.limit_length(1.0)
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if is_on_floor() and global_position.y > -10.0:
		safe_position = global_position

func _axis_pressed(action: StringName, fallback_key: Key) -> float:
	return 1.0 if Input.is_action_pressed(action) or Input.is_key_pressed(fallback_key) else 0.0

func _toggle_nearby_airlock_door() -> void:
	var nearest: Node3D
	var nearest_distance := 2.8
	for candidate in get_tree().get_nodes_in_group("airlock_door"):
		var door := candidate as Node3D
		if door != null and global_position.distance_to(door.global_position) < nearest_distance:
			nearest = door
			nearest_distance = global_position.distance_to(door.global_position)
	if nearest != null:
		nearest.toggle()

func _use_nearby_habitat_ladder() -> bool:
	var nearest: Node3D
	var nearest_distance := 2.2
	for candidate in get_tree().get_nodes_in_group("habitat_ladder"):
		var ladder := candidate as Node3D
		if ladder != null and global_position.distance_to(ladder.global_position) < nearest_distance:
			nearest = ladder
			nearest_distance = global_position.distance_to(ladder.global_position)
	if nearest != null:
		nearest.use(self)
		return true
	return false

