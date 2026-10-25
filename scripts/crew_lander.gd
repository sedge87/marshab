extends Node3D
const LanderModel := preload("res://scripts/lander_model.gd")

## The crew lander: where every game begins. It stands on level ground near the
## build area, hatch facing the site, always in the same spot for a site (so
## saves line up). You start in its airlock (the crew cabin behind the inner
## door stays sealed): a safe, warm place. E on the lander opens the outer
## hatch, which swings down to become the ramp. It's not part of the habitat.
## Model: assets/vehicles/landers_v2 (26 Oct), 8.6 m tall, hatch facing -Z.
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SCENE := "res://assets/vehicles/landers_v2/Crew_Lander.glb"
const FLOOR_HEIGHT := 2.44       # airlock floor above the ground
const PAD_OFFSETS := [Vector2(3.03, 2.95), Vector2(-3.03, 2.95), Vector2(3.03, -2.95), Vector2(-3.03, -2.95)]
const CABIN := AABB(Vector3(-1.0, 2.3, -2.6), Vector3(2.0, 3.4, 1.55))  # the airlock, local space
const RAMP_OPEN_DEGREES := -132.0

var rig: Node3D       # the model
var _ramp: Node3D     # its hinged hatch ramp
var _open := false

func _ready() -> void:
	add_to_group("landmark")
	set_meta("landmark_label", "LANDER")
	var parts := LanderModel.build(self, SCENE, "CrewRampPivot", Vector2(1.9, 3.23))
	if parts.is_empty(): return
	rig = parts.model
	_ramp = parts.pivot
	# A warm, dim airlock light: the cosy contrast with Mars outside.
	var light := OmniLight3D.new()
	light.position = Vector3(0, FLOOR_HEIGHT + 2.3, -1.8)
	light.light_color = Color("#FFD9A8")
	light.light_energy = 0.6
	light.light_specular = .1   # no hot spot on the shut hatch
	light.omni_range = 3.2
	light.shadow_enabled = false
	add_child(light)
	# A floodlight over the hatch, down onto the ramp.
	var door_light := SpotLight3D.new()
	door_light.position = Vector3(0, FLOOR_HEIGHT + 3.3, -3.1)
	door_light.rotation_degrees = Vector3(-62, 0, 0)
	door_light.light_color = Color("#FFE7C2")
	door_light.light_energy = 0.9
	door_light.spot_range = 7.0
	door_light.spot_angle = 38.0
	add_child(door_light)

func interaction_prompt() -> Dictionary:
	return {"label": "Crew Lander", "primary": "Close hatch" if _open else "Open hatch", "info": "About"}

func interact(_actor: Node = null) -> bool:
	set_hatch(not _open, true)
	return true

func interact_info(_actor: Node = null) -> bool:
	var entry := EquipmentCatalog.get_entry("crew_lander")
	get_tree().call_group("explore_hud", "show_equipment_note", "Crew Lander", str(entry.get("system_note", entry.get("description", ""))))
	return true

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
			var front := basis * Vector3(0, 0, -5.6)
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

## Where a new game starts: standing in the airlock, facing the hatch.
func cabin_start() -> Dictionary:
	return {"position": to_global(Vector3(0.0, FLOOR_HEIGHT + .3, -1.65)), "yaw": rotation.y}

## A spot on the ground beside the ramp (for the rover).
func beside_ramp() -> Vector3:
	var at := to_global(Vector3(3.6, 0, -6.4))
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
	return absf(local.x) < 4.0 + margin and local.z > -6.6 - margin and local.z < 4.0 + margin

## Descent engines on or off (the Mission 4 touchdown cutscene): four plumes
## under the hull, made the same way as the cargo lander's.
var _plume: Node3D

func set_burn(on: bool) -> void:
	if _plume == null: _plume = LanderModel.plume(self, [Vector2(1.2, 1.2), Vector2(-1.2, 1.2), Vector2(1.2, -1.2), Vector2(-1.2, -1.2)], .55)
	LanderModel.set_burn(_plume, on)

func hatch_open() -> bool:
	return _open

## Open (or close) the hatch; loaded games start open.
func set_hatch(open: bool, animate := false) -> void:
	if _ramp == null or _open == open: return
	_open = open
	LanderModel.swing(_ramp, open, RAMP_OPEN_DEGREES, 2.6 if animate else 0.0)
	if animate: MHAudio.sfx("mode_build", -6.0)
