extends Node3D

## The crew lander: where every game begins. It stands on level ground near the
## build area, hatch facing the site, always in the same spot for a site (so
## saves line up). The cabin is a safe, warm place; E on the lander opens the
## hatch, which lowers to become the ramp. It's not part of the habitat.
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SCENE := "res://assets/equipment/mars_crew_lander_v1/crew_lander.tscn"
const FLOOR_HEIGHT := 1.1        # cabin floor above the ground
const PAD_OFFSETS := [Vector2(3.4, 3.0), Vector2(-3.4, 3.0), Vector2(3.4, -3.0), Vector2(-3.4, -3.0)]
const CABIN := AABB(Vector3(-2.1, 1.0, -1.4), Vector3(4.2, 2.8, 2.8))  # local space

var rig: Node3D

func _ready() -> void:
	add_to_group("landmark")
	set_meta("landmark_label", "LANDER")
	var scene := load(SCENE) as PackedScene
	if scene == null:
		push_warning("Crew lander model is missing: %s" % SCENE)
		return
	rig = scene.instantiate() as Node3D
	add_child(rig)
	# Every collider on the lander points at its interaction rig (the hatch).
	for body in rig.find_children("*", "StaticBody3D", true, false):
		body.set_meta("interaction_target", rig)
		(body as StaticBody3D).collision_layer = 1
	# Thin hull walls: cast shadows from both sides so sunlight can't leak in.
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	# A warm, dim cabin light: the cosy contrast with Mars outside.
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.1, 0)
	light.light_color = Color("#FFD9A8")
	light.light_energy = 0.55
	light.omni_range = 4.2
	light.shadow_enabled = false
	add_child(light)
	var door_light := SpotLight3D.new()
	door_light.position = Vector3(0, 3.2, -1.7)
	door_light.rotation_degrees = Vector3(-60, 0, 0)
	door_light.light_color = Color("#FFE7C2")
	door_light.light_energy = 0.8
	door_light.spot_range = 5.0
	door_light.spot_angle = 40.0
	add_child(door_light)

## A level, buildable spot about 20 m from the site centre, and a yaw that
## turns the hatch towards the centre. Deterministic for each site.
static func find_spot() -> Dictionary:
	var best := {}
	var best_score := INF
	for radius: float in [18.0, 22.0, 26.0, 14.0]:
		for step in range(24):
			var angle := TAU * step / 24.0
			var centre: Vector2 = Vector2(cos(angle), sin(angle)) * float(radius)
			var to_site: Vector2 = -centre.normalized()
			var yaw := atan2(-to_site.x, -to_site.y)
			var basis := Basis(Vector3.UP, yaw)
			var heights: Array = [MHSiteTerrain.height(centre.x, centre.y)]
			var buildable := MHSiteTerrain.is_buildable(centre)
			for pad in PAD_OFFSETS:
				var world := basis * Vector3(pad.x, 0, pad.y)
				var at: Vector2 = centre + Vector2(world.x, world.z)
				heights.append(MHSiteTerrain.height(at.x, at.y))
				buildable = buildable and MHSiteTerrain.is_buildable(at)
			# The ground in front of the ramp must be walkable too.
			var front := basis * Vector3(0, 0, -4.5)
			buildable = buildable and MHSiteTerrain.is_buildable(centre + Vector2(front.x, front.z))
			if not buildable: continue
			var score: float = heights.max() - heights.min() + radius * .01
			if score < best_score:
				best_score = score
				best = {"position": Vector3(centre.x, heights.max(), centre.y), "yaw": yaw}
		if best_score < .35: break
	if best.is_empty(): best = {"position": Vector3(14, MHSiteTerrain.height(14, 18), 18), "yaw": 0.0}
	return best

func place_on_site() -> void:
	var spot := find_spot()
	global_position = spot.position
	rotation.y = float(spot.yaw)

## Stand on a chosen point: legs on the ground, hatch turned towards the site
## centre (where most bases are built).
func place_at(point: Vector2) -> void:
	var to_site := -point
	var yaw := atan2(-to_site.x, -to_site.y) if to_site.length() > 3.0 else 0.0
	var basis := Basis(Vector3.UP, yaw)
	var top := MHSiteTerrain.height(point.x, point.y)
	for pad in PAD_OFFSETS:
		var world := basis * Vector3(pad.x, 0, pad.y)
		top = maxf(top, MHSiteTerrain.height(point.x + world.x, point.y + world.z))
	global_position = Vector3(point.x, top, point.y)
	rotation.y = yaw

## Saved games put it back exactly where it landed.
func place_exact(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw

## Where a new game starts: standing at the back of the cabin, facing the hatch.
func cabin_start() -> Dictionary:
	return {"position": to_global(Vector3(0.0, FLOOR_HEIGHT + .95, .55)), "yaw": rotation.y}

## A spot on the ground beside the ramp (for the rover).
func beside_ramp() -> Vector3:
	var at := to_global(Vector3(3.2, 0, -5.2))
	return Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + .2, at.z)

var present := true

## Missions before the crew land: the lander isn't on Mars yet.
func set_present(on: bool) -> void:
	present = on
	visible = on
	for body in find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if on else 0
	if on: add_to_group("landmark")
	elif is_in_group("landmark"): remove_from_group("landmark")

func cabin_contains(point: Vector3) -> bool:
	return present and CABIN.grow(.1).has_point(to_local(point))

## Within this distance of the lander nothing can be built (metres, ground plane).
func keeps_clear(point: Vector2, margin := 0.0) -> bool:
	if not present: return false
	var local := to_local(Vector3(point.x, global_position.y, point.y))
	return absf(local.x) < 4.2 + margin and local.z > -6.8 - margin and local.z < 3.8 + margin

## Descent engines on or off (the Mission 4 touchdown cutscene): four plumes
## under the cabin, made the same way as the cargo lander's.
var _plume: Node3D

func set_burn(on: bool) -> void:
	if _plume == null:
		_plume = Node3D.new()
		add_child(_plume)
		for offset in [Vector2(1.2, 1.0), Vector2(-1.2, 1.0), Vector2(1.2, -1.0), Vector2(-1.2, -1.0)]:
			var flame := CPUParticles3D.new()
			flame.position = Vector3(offset.x, FLOOR_HEIGHT - .3, offset.y)
			flame.amount = 50
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
			glow.albedo_texture = preload("res://scripts/cargo_lander.gd").soft_puff_texture()
			quad.material = glow
			flame.mesh = quad
			_plume.add_child(flame)
		var light := OmniLight3D.new()
		light.light_color = Color("#FFB070")
		light.light_energy = 6.0
		light.omni_range = 14.0
		light.position = Vector3(0, .2, 0)
		_plume.add_child(light)
	_plume.visible = on
	for particles in _plume.find_children("*", "CPUParticles3D", true, false): (particles as CPUParticles3D).emitting = on

func hatch_open() -> bool:
	return rig != null and bool(rig.call("_state_on", "hatch"))

## Open (or close) without the player pressing E: loaded games start open.
func set_hatch(open: bool, animate := false) -> void:
	if rig == null or hatch_open() == open: return
	if animate:
		rig.call("interact")
	else:
		(rig.get("_state") as Dictionary)["hatch"] = open
		rig.call("_apply_state", 0, false)
