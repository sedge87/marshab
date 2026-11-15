extends CharacterBody3D

const WALK_SPEED := 5.0
const SLATE_WALK := .55   # of walking pace, with the slate up
const SPRINT_SPEED := 8.0
const MOUSE_SENSITIVITY := 0.0025
# Mars's pull is 38% of Earth's (docs/traversal.md): long, floaty jumps and slow
# falls. 3.6 m/s against 5.5 m/s² reaches about 1.2 m, with 1.3 s in the air.
const GRAVITY := 5.5
const JUMP_VELOCITY := 3.6
# The lope (docs/traversal.md, phase 1): outside, holding sprint bounds you
# along on its own. Tapping jump as you land is never needed and never
# punished: each tap in time builds your flow, and flow makes you faster,
# your bounds longer and your breathing easier (scripts/suit.gd).
const LOPE_SPEED := 7.5
const LOPE_FLOW_SPEED := .7     # more m/s for each step of flow
const LOPE_UP := 2.2            # each bound's lift: about .8 s in the air
const LOPE_FLOW_UP := .06       # a longer bound for each step of flow
const LOPE_FLOW_MAX := 3
const LOPE_TAP_BEFORE := .4     # tap this long before you land, or
const LOPE_TAP_AFTER := .18     # this long after
const LOPE_TOO_EARLY := .3      # a tap this soon after push-off just doesn't count
const STUMBLE_TIME := 1.0
const STUMBLE_SPEED := .45      # of your pace, while you find your feet
const AIR_STEER := 2.5          # m/s² of steering in the air: a nudge, not a turn
const HARD_LANDING := 7.0       # m/s: a drop of about 4.5 m
# Hold Ctrl to crouch: lower eyes, a shorter body, a slow walk.
const CROUCH_SPEED := 2.4
## Up a steep slope the lope gives way to a driving climbing stride (playtest
## 14 Nov: uphill, each bound was cut short into a stutter). Like Apollo
## crews on crater walls: short, quick steps, no bounding. It starts above
## CLIMB_FROM and ends below CLIMB_UNTIL, so it doesn't flicker.
const CLIMB_SPEED := 6.0
const CLIMB_FROM := 12.0          # degrees, going uphill
const CLIMB_UNTIL := 8.0
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
var loping := false            # in the bounding gait
var lope_flow := 0             # 0 to LOPE_FLOW_MAX: taps in time, in a row
var _tap_age := 99.0           # since the last jump tap that could count
var _air_age := 0.0            # since this bound's push-off
var _rewarded := false         # this landing's tap has been counted
var _stumble := 0.0
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
	# Driving the crew rover (scripts/crew_rover.gd): it takes the keys.
	var exploring := not _any_build_mode_active() and not bool(get_meta("driving", false)) and not bool(get_meta("riding", false)) and not bool(get_meta("strapped", false))
	if exploring and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		# With the wrist pad up (T held), E eats the suit's food bar (scripts/suit.gd).
		var suit := get_tree().get_first_node_in_group("suit")
		if Input.is_physical_key_pressed(KEY_T) and suit != null and suit.eat_bar(): pass
		elif not _use_looked_at_interactable("interact"):
			_toggle_nearby_airlock_door()
	if exploring and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		# Focused equipment retains its contextual secondary action (such as a
		# bunk reading light); otherwise F always operates the suit flashlight.
		# With the wrist pad up (T held), F pings GAR-Y's survey stakes.
		var stakes := get_tree().get_first_node_in_group("survey_stakes")
		if Input.is_physical_key_pressed(KEY_T) and stakes != null and stakes.call("ping"): pass
		elif not _use_looked_at_interactable("interact_secondary"):
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
		var look := float(get_meta("look_speed", 1.0))   # a lazier look when hungry (scripts/body.gd)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY * look)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY * look)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
		# Strapped into the landing seat (scripts/wake_up.gd): the head turns, the body doesn't.
		if bool(get_meta("strapped", false)):
			var home := float(get_meta("strap_yaw", rotation.y))
			var reach := float(get_meta("strap_reach", PI))
			rotation.y = home + clampf(wrapf(rotation.y - home, -PI, PI), -reach, reach)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-45.0), deg_to_rad(35.0))
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
	if bool(get_meta("build_mode_active", false)) or bool(get_meta("ui_freeze", false)) or bool(get_meta("driving", false)) or bool(get_meta("riding", false)) or bool(get_meta("slate_still", false)) or bool(get_meta("strapped", false)):
		velocity = Vector3.ZERO
		return
	if bool(get_meta("debug_fly", false)):
		_debug_fly(delta)
		return
	var grounded := is_on_floor()
	_crouch(delta)
	var slate_up := bool(get_meta("slate_up", false))   # walking with the slate up: no jumping, no running
	var jump_pressed := not slate_up and (Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE))
	var jump_tapped := jump_pressed and not _jump_was_pressed
	_jump_was_pressed = jump_pressed
	# Input actions are retained for remapping. Direct key checks are a reliable
	# fallback if a Project Settings input map is unavailable or damaged.
	var input_vector := Vector2(
		_axis_pressed("move_right", KEY_D) - _axis_pressed("move_left", KEY_A),
		_axis_pressed("move_back", KEY_S) - _axis_pressed("move_forward", KEY_W)
	)
	input_vector = input_vector.limit_length(1.0)
	var sprint_held := not slate_up and (Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT))
	var indoors := _indoors()
	var can_lope := sprint_held and not crouching and not indoors and input_vector.length() > .1 and _stumble <= 0.0
	_update_climb(grounded, (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized(), can_lope)
	if climbing: can_lope = false
	if grounded and jump_tapped and not crouching and not loping and not can_lope:
		velocity.y = JUMP_VELOCITY
		MHAudio.sfx("jump")
	elif not grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	_lope(delta, grounded, jump_tapped, can_lope)
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	# Indoors sprint is a plain run; outside it's the lope.
	var speed := CROUCH_SPEED if crouching else (LOPE_SPEED + LOPE_FLOW_SPEED * lope_flow) if loping else CLIMB_SPEED if climbing else SPRINT_SPEED if sprint_held and indoors else WALK_SPEED
	if _stumble > 0.0: speed *= STUMBLE_SPEED
	if slate_up: speed *= SLATE_WALK
	speed *= float(get_meta("body_speed", 1.0))   # the cold and low oxygen slow you (scripts/body.gd)
	speed *= float(get_meta("load_speed", 1.0))   # carrying something heavy (scripts/o2_cartridge.gd)
	if grounded:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# In the air you keep the momentum you left the ground with: thin air
		# doesn't slow you, and you can only nudge your line a little.
		var flat := Vector2(velocity.x, velocity.z)
		if direction != Vector3.ZERO:
			flat = flat.move_toward(Vector2(direction.x, direction.z) * maxf(flat.length(), WALK_SPEED * .5), AIR_STEER * delta)
		velocity.x = flat.x
		velocity.z = flat.y
	var meant := Vector3(velocity.x, 0.0, velocity.z)
	move_and_slide()
	_step_up(meant, delta)
	if is_on_floor() and global_position.y > -10.0:
		safe_position = global_position
	_footsteps(speed, delta)

var climbing := false   # the climbing stride (see CLIMB_SPEED)

## Sprinting up a steep slope: the climbing stride instead of the lope.
func _update_climb(grounded: bool, direction: Vector3, wants_lope: bool) -> void:
	if not wants_lope:
		climbing = false
	elif grounded and direction != Vector3.ZERO:
		var normal := get_floor_normal()
		var slope := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		var uphill := Vector2(normal.x, normal.z).dot(Vector2(direction.x, direction.z)) < 0.0
		climbing = uphill and slope > (CLIMB_UNTIL if climbing else CLIMB_FROM)
	set_meta("climbing", climbing)

## Walking into a low ledge (the lander's airlock sill, a doorway, a rock
## step) lifts you onto it instead of stopping you dead (playtest 14 Nov:
## you had to jump into the airlock).
const STEP_UP := .3
func _step_up(meant: Vector3, delta: float) -> void:
	if not is_on_floor() or not is_on_wall() or meant.length() < .5: return
	var ahead := meant.normalized() * maxf(.15, meant.length() * delta)
	var up := Vector3.UP * STEP_UP
	if test_move(global_transform, up): return              # no headroom
	var raised := global_transform.translated(up)
	if test_move(raised, ahead): return                      # a real wall, not a ledge
	# Down onto the ledge's top from there.
	var probe := KinematicCollision3D.new()
	if not test_move(raised.translated(ahead), -up, probe): return
	var rise := STEP_UP - probe.get_travel().length()
	if rise <= .01: return
	global_position += Vector3.UP * (rise + .01) + ahead

## The lope: hold sprint and you bound along. A tap in time builds flow.
func _lope(delta: float, grounded: bool, tapped: bool, can_lope: bool) -> void:
	_tap_age += delta
	if _stumble > 0.0:
		_stumble = maxf(0.0, _stumble - delta)
		head.rotation.z = move_toward(head.rotation.z, 0.0, delta * .25)
	if not loping:
		set_meta("loping", false)
		if grounded and can_lope: _bound(true)
		return
	if not grounded:
		_air_age += delta
		if tapped:
			# Just after landing still counts for the landing you've just made.
			if _air_age <= LOPE_TAP_AFTER and not _rewarded: _flow(true)
			elif _air_age >= LOPE_TOO_EARLY: _tap_age = 0.0
		return
	# Landed.
	if not can_lope:
		_end_lope()   # you let go: back to a walk
		return
	if tapped: _tap_age = 0.0
	var in_time := _tap_age <= LOPE_TAP_BEFORE
	_bound(false)
	if in_time: _flow(true)
	else: _rewarded = false   # still open for a tap just after

## A tap in time: one more step of flow. A landing with no tap lets one go.
func _flow(up: bool) -> void:
	if up:
		_rewarded = true
		lope_flow = mini(lope_flow + 1, _flow_max())
		MHAudio.sfx("suit_beep", -26.0 + 2.0 * lope_flow, .0)   # the suit's soft tick
	else: lope_flow = maxi(lope_flow - 1, 0)

## Tired, the lope loses its spring (15 Nov: fatigue is felt, not a meter):
## a sol awake caps the rhythm at 2, two sols at 1. Sleep gives it back.
func _flow_max() -> int:
	var body := get_tree().get_first_node_in_group("body")
	if body == null: return LOPE_FLOW_MAX
	if bool(body.call("doze_risk")): return 1
	if bool(body.call("tired")): return 2
	return LOPE_FLOW_MAX

var _bound_sound_ms := 0   # when the last push-off sound played
func _bound(first: bool) -> void:
	# The last landing went by with no tap: flow eases off, nothing worse.
	if not first and not _rewarded: _flow(false)
	loping = true
	set_meta("loping", true)
	if first: lope_flow = 0
	var laden := float(get_meta("load_speed", 1.0)) < .999
	velocity.y = LOPE_UP * (1.0 + LOPE_FLOW_UP * lope_flow) * (.85 if laden else 1.0)
	_air_age = 0.0
	_tap_age = 99.0
	_rewarded = false
	_step_index = (_step_index + 1 + randi() % 3) % 4
	# Uphill the slope cuts each arc short and the bounds come in a stutter
	# (playtest 14 Nov video): a push-off sound at most every 0.45 s.
	var now := Time.get_ticks_msec()
	if first or now - _bound_sound_ms >= 450:
		_bound_sound_ms = now
		MHAudio.sfx("step_dirt_%d" % _step_index, -5.0, .06)

func _end_lope() -> void:
	loping = false
	set_meta("loping", false)
	lope_flow = 0

## You lose your footing: slow for a moment, and the view lurches.
func stumble() -> void:
	if _stumble > 0.0: return
	_stumble = STUMBLE_TIME
	_end_lope()
	head.rotation.z = .09 if randf() < .5 else -.09
	MHAudio.sfx("land", -2.0)

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
var _land_quiet := 0.0   # seconds before the next landing thud
func _footsteps(speed: float, delta: float) -> void:
	var grounded := is_on_floor()
	_land_quiet = maxf(0.0, _land_quiet - delta)
	# Loping, every bound lands: only a real drop thuds, and never twice in a
	# breath (playtest 14 Nov: uphill, the short bounds thudded nonstop).
	if grounded and not _was_grounded and _fall_speed > (6.0 if loping else 3.5):
		if _land_quiet <= 0.0: MHAudio.sfx("land", -2.0 if _on_deck() else 0.0)
		_land_quiet = .8
		_stride = 0.0
		if _fall_speed > HARD_LANDING: stumble()   # slow falls on Mars: it trips you, no more
	_fall_speed = maxf(0.0, -velocity.y) if not grounded else 0.0
	_was_grounded = grounded
	if not grounded or bool(get_meta("build_mode_active", false)): return
	var moved := Vector2(velocity.x, velocity.z).length() * delta
	if moved < .001:
		_stride = 0.0
		return
	_stride += moved
	if _stride >= (2.2 if climbing else 2.6 if speed > WALK_SPEED else 2.0):   # climbing: quick, steady steps
		_stride = 0.0
		_step_index = (_step_index + 1 + randi() % 3) % 4
		MHAudio.sfx(("step_metal_%d" if _on_deck() else "step_dirt_%d") % _step_index, -8.0, .06)

## Inside the lander, a room or a vehicle (the suit knows: scripts/suit.gd).
var _suit: Node
func _indoors() -> bool:
	if _suit == null or not is_instance_valid(_suit): _suit = get_tree().get_first_node_in_group("suit")
	if _suit != null: return str(_suit.get("where")) != "outside"
	return _on_deck()

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
			# Something you're carrying can take E over (chapter one's soil sample).
			for claimer in get_tree().get_nodes_in_group("interaction_claims"):
				if bool(claimer.call("claim", target, method_name)): return true
			if target != null and target.has_method(method_name):
				return bool(target.call(method_name, self))
		if node.has_method(method_name):
			return bool(node.call(method_name, self))
		node = node.get_parent()
	return false

