extends VehicleBody3D
## OUTPOST ONE: MARS — pressurised six-wheeled rover.
## VehicleBody3D handles the suspension and wheel forces; this script adds
## friendly low-speed rover controls, brake lights, and camera switching.

@export var max_forward_speed_kmh: float = 38.0
@export var max_reverse_speed_kmh: float = 14.0
@export var engine_force_newtons: float = 115.0
@export var braking_force: float = 30.0
@export var steering_limit_degrees: float = 27.0
@export var steering_response: float = 2.7
@export var mouse_captured: bool = false

@onready var chase_camera: Camera3D = $ChaseCamera
@onready var cockpit_camera: Camera3D = $CockpitCamera
@onready var info_label: Label = $HUD/Panel/VBox/Info
@onready var speed_label: Label = $HUD/Panel/VBox/Speed

var _current_steering: float = 0.0
var _cockpit_view: bool = false

func _ready() -> void:
	chase_camera.current = true
	cockpit_camera.current = false
	_update_camera()

func _physics_process(delta: float) -> void:
	# Fallback keyboard inputs work even in a completely new Godot project.
	var throttle := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	var reverse := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	var left := float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var right := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
	var handbrake := Input.is_key_pressed(KEY_SPACE)
	var target_steer := (left - right) * deg_to_rad(steering_limit_degrees)
	_current_steering = move_toward(_current_steering, target_steer, steering_response * delta)
	steering = _current_steering
	var forward_speed := -global_basis.z.dot(linear_velocity)
	var speed_kmh := linear_velocity.length() * 3.6
	var speed_limit := max_forward_speed_kmh if throttle > 0.0 else max_reverse_speed_kmh
	var driving_input := throttle - reverse
	engine_force = driving_input * engine_force_newtons if speed_kmh < speed_limit or sign(driving_input) != sign(forward_speed) else 0.0
	brake = braking_force if handbrake else 0.0
	speed_label.text = "%02.0f km/h" % speed_kmh
	info_label.text = "OUTPOST ONE   |   %s   |   W A S D  •  SPACE BRAKE  •  C CAMERA" % ("COCKPIT" if _cockpit_view else "CHASE")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_cockpit_view = not _cockpit_view
			_update_camera()
		elif event.keycode == KEY_R:
			# Recover on the rare occasion the vehicle gets stuck on its roof.
			if linear_velocity.length() < 1.5:
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
				global_basis = Basis(Vector3.UP, rotation.y)
				global_position.y += 1.5

func _update_camera() -> void:
	if is_instance_valid(chase_camera) and is_instance_valid(cockpit_camera):
		chase_camera.current = not _cockpit_view
		cockpit_camera.current = _cockpit_view
