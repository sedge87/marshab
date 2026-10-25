extends Node3D
const LanderModel := preload("res://scripts/lander_model.gd")

## A robotic cargo lander (Missions 2-3, and resupplies): a boxy hold on
## four legs. The construction robot (the player) rides down inside the hold;
## E lowers its ramp door to the ground. The descent itself is played by
## MarsWorld (descend()). Model: assets/vehicles/landers_v2 (26 Oct), 9.3 m
## tall, ramp facing -Z.
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SCENE := "res://assets/vehicles/landers_v2/Cargo_Lander.glb"
const FLOOR_HEIGHT := 2.58                    # hold floor above the ground
const PAD_OFFSETS := [Vector2(3.64, 3.61), Vector2(-3.64, 3.61), Vector2(3.64, -3.61), Vector2(-3.64, -3.61)]
const CABIN := AABB(Vector3(-2.25, 2.4, -3.0), Vector3(4.5, 4.1, 5.55))   # the hold, local space
const RAMP_OPEN_DEGREES := -131.0

var number := 1
var ramp_open := false
var _door: Node3D
var _plume: Node3D

func _ready() -> void:
	add_to_group("landmark")
	if not has_meta("landmark_label"): set_meta("landmark_label", "CARGO %d" % number)
	var parts := LanderModel.build(self, SCENE, "CargoRampPivot", Vector2(3.26, 3.48))
	if parts.is_empty(): return
	_door = parts.pivot
	var hold_light := OmniLight3D.new()
	hold_light.position = Vector3(0, FLOOR_HEIGHT + 3.3, .4)
	hold_light.light_color = Color("#CFE6FF")
	hold_light.light_energy = .8
	hold_light.omni_range = 6.0
	add_child(hold_light)
	_plume = LanderModel.plume(self, [Vector2(1.5, 1.5), Vector2(-1.5, 1.5), Vector2(1.5, -1.5), Vector2(-1.5, -1.5)], .55)

## Engine plume on or off (the descent burn).
func set_burn(on: bool) -> void:
	LanderModel.set_burn(_plume, on)

## Stand on a ground point with the ramp facing `face_towards` (the base site).
func place_at(point: Vector2, face_towards: Vector2) -> void:
	var spot := spot_at(point, face_towards)
	global_position = spot.position
	rotation.y = float(spot.yaw)

## Where it would stand (on its highest footpad) and its yaw.
static func spot_at(point: Vector2, face_towards: Vector2) -> Dictionary:
	var to_base := face_towards - point
	var yaw := atan2(to_base.x, to_base.y) + PI if to_base.length() > 1.0 else 0.0
	var basis := Basis(Vector3.UP, yaw)
	var top := MHSiteTerrain.height(point.x, point.y)
	for pad in PAD_OFFSETS:
		var world := basis * Vector3(pad.x, 0, pad.y)
		top = maxf(top, MHSiteTerrain.height(point.x + world.x, point.y + world.z))
	return {"position": Vector3(point.x, top, point.y), "yaw": yaw}

## Where the robot starts: at the back of the hold, facing the ramp door.
func hold_start() -> Dictionary:
	return {"position": to_global(Vector3(0, FLOOR_HEIGHT + .3, .9)), "yaw": rotation.y}

func hold_contains(point: Vector3) -> bool:
	return CABIN.grow(.1).has_point(to_local(point))

func interaction_prompt() -> Dictionary:
	return {"label": "Cargo lander %d" % number, "primary": "Raise ramp" if ramp_open else "Lower ramp"}

func interact(_actor: Node = null) -> bool:
	set_ramp(not ramp_open, true)
	return true

func set_ramp(open: bool, animate := false) -> void:
	ramp_open = open
	LanderModel.swing(_door, open, RAMP_OPEN_DEGREES, 2.6 if animate else 0.0)
	if animate: MHAudio.sfx("mode_build", -6.0)

# ---------- particles ----------

## A soft round puff for dust and engine particles (no hard square edges).
static func soft_puff_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5, .5)
	texture.fill_to = Vector2(1.0, .5)
	texture.width = 64
	texture.height = 64
	return texture
