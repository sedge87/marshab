extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const MOUSE_SENSITIVITY := 0.0025
# Tunable Martian movement values. 5.3 m/s against 14 m/s² reaches roughly 1 m.
const GRAVITY := 14.0
const JUMP_VELOCITY := 5.3
# Hold Ctrl to crouch: lower eyes, a shorter body, a slow walk.
const CROUCH_SPEED := 2.4
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STAND_EYES := 1.6

@onready var head: Node3D = $Head
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
var safe_position := Vector3.ZERO
var _jump_was_pressed := false
var _stride := 0.0
var _was_grounded := true
var _fall_speed := 0.0
var _step_index := 0
var _flashlight_enabled := false
var crouching := false
@onready var _body_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Lets the controller follow small terrain undulations without hopping or snagging.
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(52.0)
	set_flashlight_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	# Build modes reuse E (orbit) and other keys; explore actions must not fire
	# behind the build camera, so only mouse-look below is shared.
	var exploring := not _any_build_mode_active()
	if exploring and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if not _use_looked_at_interactable("interact"):
			_toggle_nearby_airlock_door()
	if exploring and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		# Focused equipment retains its contextual secondary action (such as a
		# bunk reading light); otherwise F always operates the suit flashlight.
		if not _use_looked_at_interactable("interact_secondary"):
			set_flashlight_enabled(not _flashlight_enabled)
	# I: the looked-at item's info card (what it does in the habitat).
	if exploring and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		_use_looked_at_interactable("interact_info")
	# Z: sleep, at a bunk (scripts/sleep.gd).
	if exploring and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z and not event.ctrl_pressed:
		_use_looked_at_interactable("interact_sleep")
	# G: a tap is the looked-at item's third action, holding it opens GAR-Y's
	# orders. Both are handled by scripts/gar_y_orders.gd.
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
	# Exterior construction uses the same movement keys to pan its bird's-eye
	# camera. Freeze the character in place so panning never changes the real
	# player cell represented by the build-mode marker.
	if bool(get_meta("build_mode_active", false)) or bool(get_meta("ui_freeze", false)):
		velocity = Vector3.ZERO
		return
	if bool(get_meta("debug_fly", false)):
		_debug_fly(delta)
		return
	var grounded := is_on_floor()
	_crouch(delta)
	var jump_pressed := Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE)
	if grounded and jump_pressed and not _jump_was_pressed and not crouching:
		velocity.y = JUMP_VELOCITY
		MHAudio.sfx("jump")
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
	var speed := CROUCH_SPEED if crouching else SPRINT_SPEED if Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if is_on_floor() and global_position.y > -10.0:
		safe_position = global_position
	_footsteps(speed, delta)

## Ctrl held: crouch. Letting go stands you up once there's headroom.
func _crouch(delta: float) -> void:
	var want := Input.is_key_pressed(KEY_CTRL)
	if crouching and not want and _headroom_blocked(): want = true
	crouching = want
	var capsule := _body_shape.shape as CapsuleShape3D
	var height := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	if not is_equal_approx(capsule.height, height):
		capsule.height = height
		_body_shape.position.y = height * .5
	var eyes := STAND_EYES - (STAND_HEIGHT - CROUCH_HEIGHT) if crouching else STAND_EYES
	head.position.y = move_toward(head.position.y, eyes, delta * 4.0)

func _headroom_blocked() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * CROUCH_HEIGHT, global_position + Vector3.UP * (STAND_HEIGHT + .05))
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# Debug fly / noclip: move where the camera looks, Space up, Ctrl down,
# Shift fast; collisions off so walls and terrain are no obstacle.
func _debug_fly(_delta: float) -> void:
	var camera_basis := (get_node("Head/Camera3D") as Camera3D).global_transform.basis
	var input := Vector3(
		_axis_pressed("move_right", KEY_D) - _axis_pressed("move_left", KEY_A),
		(1.0 if Input.is_key_pressed(KEY_SPACE) else 0.0) - (1.0 if Input.is_key_pressed(KEY_CTRL) else 0.0),
		_axis_pressed("move_back", KEY_S) - _axis_pressed("move_forward", KEY_W))
	var direction := camera_basis.x * input.x + Vector3.UP * input.y + camera_basis.z * input.z
	velocity = direction.normalized() * (40.0 if Input.is_key_pressed(KEY_SHIFT) else 12.0) if direction.length() > .01 else Vector3.ZERO
	move_and_slide()
	safe_position = global_position

## Debug: switch fly/noclip on or off.
func set_debug_fly(enabled: bool) -> void:
	set_meta("debug_fly", enabled)
	collision_mask = 0 if enabled else 1
	velocity = Vector3.ZERO

# Suit footsteps: regolith crunch outside, deck plate inside the habitat.
func _footsteps(speed: float, delta: float) -> void:
	var grounded := is_on_floor()
	if grounded and not _was_grounded and _fall_speed > 3.5:
		MHAudio.sfx("land", -2.0 if _on_deck() else 0.0)
		_stride = 0.0
	_fall_speed = maxf(0.0, -velocity.y) if not grounded else 0.0
	_was_grounded = grounded
	if not grounded or bool(get_meta("build_mode_active", false)): return
	var moved := Vector2(velocity.x, velocity.z).length() * delta
	if moved < .001:
		_stride = 0.0
		return
	_stride += moved
	if _stride >= (2.6 if speed > WALK_SPEED else 2.0):
		_stride = 0.0
		_step_index = (_step_index + 1 + randi() % 3) % 4
		MHAudio.sfx(("step_metal_%d" if _on_deck() else "step_dirt_%d") % _step_index, -8.0, .06)

func _on_deck() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider() as Node
		if collider != null and str(collider.get_path()).contains("/Habitat/"): return true
	return false

func _axis_pressed(action: StringName, fallback_key: Key) -> float:
	return 1.0 if Input.is_action_pressed(action) or Input.is_key_pressed(fallback_key) else 0.0

func set_flashlight_enabled(enabled: bool) -> void:
	_flashlight_enabled = enabled
	if flashlight != null:
		flashlight.visible = enabled
	set_meta("flashlight_enabled", enabled)

func flashlight_enabled() -> bool:
	return _flashlight_enabled

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

func _any_build_mode_active() -> bool:
	return bool(get_meta("build_mode_active", false)) or bool(get_meta("interior_build_active", false)) or bool(get_meta("surface_build_active", false))

func _use_looked_at_interactable(method_name: String) -> bool:
	if _any_build_mode_active():
		return false
	var camera := get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null or not camera.is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z * 3.0)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var node := hit.get("collider") as Node if not hit.is_empty() else null
	while node != null:
		if node.has_meta("interaction_target"):
			var target := node.get_meta("interaction_target") as Node
			if target != null and target.has_method(method_name):
				return bool(target.call(method_name, self))
		if node.has_method(method_name):
			return bool(node.call(method_name, self))
		node = node.get_parent()
	return false

