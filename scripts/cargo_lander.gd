extends Node3D

## A robotic cargo lander (Missions 2-3): a squat descent stage on four legs
## with a cargo hold on top. The construction robot (the player) rides down
## inside the hold; E on the ramp door lowers it to the ground. Built from
## primitives so it reads as a different craft from the crew lander.
## The descent itself is played by MarsWorld (descend()).
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const FLOOR_HEIGHT := 1.1                     # hold floor above the ground
const HOLD := Vector3(3.2, 2.5, 4.4)          # inside width, height, depth
const WALL := .12
const DOOR_HEIGHT := 2.4
const RAMP_SLOPE := 27.3                      # degrees: the lowered door's tip meets the ground
const CABIN := AABB(Vector3(-1.6, 1.0, -2.2), Vector3(3.2, 2.6, 4.4))   # the hold, local space

var number := 1
var ramp_open := false
var _door: Node3D
var _plume: Node3D
var _hold_light: OmniLight3D

func _ready() -> void:
	add_to_group("landmark")
	set_meta("landmark_label", "CARGO %d" % number)
	var hull := _material("#D9D6CE", .7)
	var dark := _material("#3A4045", .6)
	var foil := _material("#C9A24B", .35, .6)
	var accent := _material(MHStyle.accent.to_html(), .5)
	# Descent stage: an octagonal deck under the hold, tanks and the engine.
	var deck := _mesh(_cylinder(2.5, 2.5, .5, 8), hull, Vector3(0, FLOOR_HEIGHT - .3, 0))
	deck.rotation.y = PI / 8.0
	_mesh(_cylinder(2.55, 2.55, .08, 8), accent, Vector3(0, FLOOR_HEIGHT - .14, 0)).rotation.y = PI / 8.0
	for corner in [Vector2(1.5, 1.5), Vector2(-1.5, 1.5), Vector2(1.5, -1.5), Vector2(-1.5, -1.5)]:
		var tank := MeshInstance3D.new()
		var sphere := SphereMesh.new(); sphere.radius = .42; sphere.height = .84
		tank.mesh = sphere; tank.material_override = foil
		tank.position = Vector3(corner.x * .75, FLOOR_HEIGHT - .75, corner.y * .75)
		add_child(tank)
	_mesh(_cylinder(.22, .5, .55, 16), dark, Vector3(0, FLOOR_HEIGHT - .82, 0))
	# Four splayed legs with footpads.
	for side in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var top := Vector3(side.x * 1.7, FLOOR_HEIGHT - .4, side.y * 1.7)
		var foot := Vector3(side.x * 2.7, .08, side.y * 2.7)
		_strut(top, foot, dark)
		_strut(Vector3(side.x * 1.2, FLOOR_HEIGHT - .55, side.y * 1.9), foot, dark)
		_mesh(_cylinder(.38, .42, .1, 16), dark, foot - Vector3(0, .03, 0))
	# The hold: floor, roof, side and back walls. The front (-Z) is the ramp door.
	var half := HOLD * .5
	var floor_y := FLOOR_HEIGHT
	_solid(Vector3(HOLD.x + WALL * 2, .16, HOLD.z + WALL * 2), Vector3(0, floor_y - .08, 0), dark)
	_solid(Vector3(HOLD.x + WALL * 2, WALL, HOLD.z + WALL * 2), Vector3(0, floor_y + HOLD.y + WALL * .5, 0), hull)
	for x in [-1.0, 1.0]:
		_solid(Vector3(WALL, HOLD.y + WALL, HOLD.z + WALL * 2), Vector3(x * (half.x + WALL * .5), floor_y + half.y + WALL * .5, 0), hull)
	_solid(Vector3(HOLD.x, HOLD.y, WALL), Vector3(0, floor_y + half.y, half.z + WALL * .5), hull)
	# Header above the door opening.
	var header := HOLD.y - DOOR_HEIGHT
	_solid(Vector3(HOLD.x, header, WALL), Vector3(0, floor_y + DOOR_HEIGHT + header * .5, -half.z - WALL * .5), hull)
	# Roof gear: an antenna and folded solar wings, so it reads as a spacecraft.
	_mesh(_cylinder(.03, .03, .9, 6), dark, Vector3(.9, floor_y + HOLD.y + .55, 1.2))
	var dish := MeshInstance3D.new()
	var dish_mesh := SphereMesh.new(); dish_mesh.radius = .32; dish_mesh.height = .2; dish_mesh.is_hemisphere = true
	dish.mesh = dish_mesh; dish.material_override = hull
	dish.position = Vector3(.9, floor_y + HOLD.y + 1.0, 1.2); dish.rotation_degrees = Vector3(200, 0, 0)
	add_child(dish)
	for x in [-1.0, 1.0]:
		_mesh(_box(Vector3(.06, 1.6, 2.6)), _material("#24324A", .3, .4), Vector3(x * (half.x + .2), floor_y + 1.2, .4))
	# Hold interior: cargo straps, crates already unloaded from the back, a light.
	for crate in [[Vector3(-.95, 0, 1.45), Vector3(1.0, .9, .9)], [Vector3(.95, 0, 1.55), Vector3(1.0, 1.2, .8)], [Vector3(-.95, .9, 1.5), Vector3(.8, .6, .7)]]:
		var size: Vector3 = crate[1]
		_solid(size, Vector3(crate[0].x, floor_y + crate[0].y + size.y * .5, crate[0].z), _material("#8A7B62", .9))
	for x in [-1.0, 1.0]:
		_mesh(_box(Vector3(.04, .04, HOLD.z - .3)), accent, Vector3(x * (half.x - .03), floor_y + 1.0, 0))
	_hold_light = OmniLight3D.new()
	_hold_light.position = Vector3(0, floor_y + HOLD.y - .3, .4)
	_hold_light.light_color = Color("#CFE6FF")
	_hold_light.light_energy = .7
	_hold_light.omni_range = 4.0
	add_child(_hold_light)
	# Thin walls cast shadows both ways so sunlight can't leak into the hold.
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_build_door(hull, accent)
	_build_plume()

func _build_door(hull: Material, accent: Material) -> void:
	# Hinged along the bottom edge of the opening; it swings out and down.
	_door = Node3D.new()
	_door.name = "RampDoor"
	_door.position = Vector3(0, FLOOR_HEIGHT, -HOLD.z * .5 - WALL * 1.5)
	add_child(_door)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0, DOOR_HEIGHT * .5 + .03, 0)
	body.set_meta("interaction_target", self)
	_door.add_child(body)
	var size := Vector3(HOLD.x + WALL * 2.0, DOOR_HEIGHT + .06, WALL)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box(size); mesh.material_override = hull
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = size; shape.shape = box
	body.add_child(shape)
	# Hazard chevrons on the outside face (the ramp's walking surface when down).
	for index in 5:
		var stripe := MeshInstance3D.new()
		stripe.mesh = _box(Vector3(HOLD.x - .3, .07, .02)); stripe.material_override = accent
		stripe.position = Vector3(0, -DOOR_HEIGHT * .5 + .3 + index * .45, -WALL * .5 - .01)
		body.add_child(stripe)

func _build_plume() -> void:
	_plume = Node3D.new()
	_plume.position = Vector3(0, FLOOR_HEIGHT - 1.1, 0)
	_plume.visible = false
	add_child(_plume)
	var flame := CPUParticles3D.new()
	flame.amount = 90
	flame.lifetime = .35
	flame.direction = Vector3.DOWN
	flame.spread = 8.0
	flame.initial_velocity_min = 14.0
	flame.initial_velocity_max = 20.0
	flame.gravity = Vector3.ZERO
	flame.scale_amount_min = .5
	flame.scale_amount_max = 1.0
	var quad := QuadMesh.new(); quad.size = Vector2(.5, .5)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, .62, .3, .55)
	glow.albedo_texture = soft_puff_texture()
	quad.material = glow
	flame.mesh = quad
	_plume.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color("#FFB070")
	light.light_energy = 6.0
	light.omni_range = 14.0
	light.position = Vector3(0, -.8, 0)
	_plume.add_child(light)

## Engine plume on or off (the descent burn).
func set_burn(on: bool) -> void:
	_plume.visible = on
	for particles in _plume.find_children("*", "CPUParticles3D", true, false): (particles as CPUParticles3D).emitting = on

## Stand on a ground point with the ramp facing `face_towards` (the base site).
func place_at(point: Vector2, face_towards: Vector2) -> void:
	var to_base := face_towards - point
	var yaw := atan2(to_base.x, to_base.y) + PI if to_base.length() > 1.0 else 0.0
	var top := MHSiteTerrain.height(point.x, point.y)
	for corner in [Vector2(2.7, 2.7), Vector2(-2.7, 2.7), Vector2(2.7, -2.7), Vector2(-2.7, -2.7)]:
		top = maxf(top, MHSiteTerrain.height(point.x + corner.x, point.y + corner.y))
	global_position = Vector3(point.x, top, point.y)
	rotation.y = yaw

## Where the robot starts: at the back of the hold, facing the ramp door.
func hold_start() -> Dictionary:
	return {"position": to_global(Vector3(0, FLOOR_HEIGHT + .95, .3)), "yaw": rotation.y}

func hold_contains(point: Vector3) -> bool:
	return CABIN.grow(.1).has_point(to_local(point))

func interaction_prompt() -> Dictionary:
	return {"label": "Cargo lander %d" % number, "primary": "Raise ramp" if ramp_open else "Lower ramp"}

func interact(_actor: Node = null) -> bool:
	set_ramp(not ramp_open, true)
	return true

func set_ramp(open: bool, animate := false) -> void:
	ramp_open = open
	var angle := -deg_to_rad(90.0 + RAMP_SLOPE) if open else 0.0
	if animate:
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_door, "rotation:x", angle, 2.2)
		MHAudio.sfx("mode_build", -6.0)
	else:
		_door.rotation.x = angle

# ---------- primitives ----------

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


func _material(colour: String, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour)
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new(); box.size = size
	return box

func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top; cylinder.bottom_radius = bottom; cylinder.height = height; cylinder.radial_segments = sides
	return cylinder

func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh; instance.material_override = material; instance.position = at
	add_child(instance)
	return instance

func _solid(size: Vector3, at: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = at
	add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box(size); mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = size; shape.shape = box
	body.add_child(shape)

func _strut(from: Vector3, to: Vector3, material: Material) -> void:
	var strut := MeshInstance3D.new()
	strut.mesh = _cylinder(.06, .06, from.distance_to(to), 8)
	strut.material_override = material
	# Cylinders run along Y: turn Y onto the strut's direction.
	strut.transform = Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), (from + to) * .5)
	add_child(strut)
