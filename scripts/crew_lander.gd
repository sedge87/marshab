extends Node3D
const LanderModel := preload("res://scripts/lander_model.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")

## The crew lander: where every game begins. It stands on level ground near the
## build area, hatch facing the site, always in the same spot for a site (so
## saves line up). You start in its cabin, a small round room with seats, a
## console and supplies, open to the airlock (the model's inner door is cut
## out): a safe, warm place. E on the lander opens the outer hatch, which
## swings down to become the ramp. It's not part of the habitat.
## Model: assets/vehicles/landers_v2 (26 Oct), 8.6 m tall, hatch facing -Z.
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SCENE := "res://assets/vehicles/landers_v2/Crew_Lander.glb"
const FLOOR_HEIGHT := 2.44       # airlock floor above the ground
const DECK := FLOOR_HEIGHT + .06 # the cabin's deck plate (over the model's floor)
const CEILING := 5.67            # the cabin's ceiling, level with the airlock's
const CABIN_RADIUS := 2.32
const FRONT_WALL := -.87         # the cabin's front face, where the inner door was
const PAD_OFFSETS := [Vector2(3.03, 2.95), Vector2(-3.03, 2.95), Vector2(3.03, -2.95), Vector2(-3.03, -2.95)]
const CABIN := AABB(Vector3(-2.35, 2.3, -2.6), Vector3(4.7, 3.5, 4.95))  # cabin and airlock, local space
## The cabin's fittings: catalogue item, lander-local spot, the direction it
## faces. Four landing seats (crew couches bolted to the deck, harnessed for
## touchdown) round a console at the back, a shelter locker and water either
## side of it, supplies against the front wall beside the airlock.
const FURNITURE := [
	["mission_planning_console", Vector3(0, 0, 1.55), Vector2(0, -1)],
	["landing_seat", Vector3(-.55, 0, .42), Vector2(0, 1)],
	["landing_seat", Vector3(.55, 0, .42), Vector2(0, 1)],
	["landing_seat", Vector3(-1.62, 0, .12), Vector2(1, .3)],
	["landing_seat", Vector3(1.62, 0, .12), Vector2(-1, .3)],
	["storm_shelter_locker", Vector3(-1.5, 0, 1.3), Vector2(.8, -1)],
	["potable_water_dispenser", Vector3(1.55, 0, 1.3), Vector2(-.8, -1)],
	["supply_crate_medium", Vector3(-1.55, 0, -.52), Vector2(0, 1)],
	["supply_crate_small", Vector3(-1.55, .447, -.52), Vector2(.3, 1)],
	["supply_crate_medium", Vector3(1.55, 0, -.52), Vector2(0, 1)],
]
## Catalogue models face -Z; turn by this to face `direction`.
const MODEL_FRONT := PI
const RAMP_OPEN_DEGREES := -132.0
## The model's inner airlock door (model space), cut out so the airlock opens
## straight into the cabin.
const INNER_DOOR := AABB(Vector3(-1.12, 2.52, -1.25), Vector3(2.24, 3.03, .45))

var rig: Node3D       # the model
var _ramp: Node3D     # its hinged hatch ramp
var _open := false

func _ready() -> void:
	add_to_group("landmark")
	set_meta("landmark_label", "LANDER")
	var parts := LanderModel.build(self, SCENE, "CrewRampPivot", Vector2(1.9, 3.23), _cut_out)
	if parts.is_empty(): return
	rig = parts.model
	_ramp = parts.pivot
	_build_cabin()
	call_deferred("_furnish")   # the builder makes the furniture (it's in the tree by then)
	# A warm, dim airlock light: the cosy contrast with Mars outside.
	var light := OmniLight3D.new()
	light.position = Vector3(0, FLOOR_HEIGHT + 2.3, -1.8)
	light.light_color = Color("#FFD9A8")
	light.light_energy = 0.45
	light.light_specular = .1   # no hot spot on the shut hatch
	light.omni_range = 2.6
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

## The cabin's deck plate and ceiling (the model's cabin is a bare shell
## 5 m tall with tank tops through the floor), and its lights.
## What's cut from the model (model space, 5 cm above lander space): the inner
## door, and the model's floor fittings that stand up through the cabin's deck.
static func _cut_out(centre: Vector3) -> bool:
	if INNER_DOOR.has_point(centre): return true
	var on_floor := centre.y > 2.47 and centre.y < 3.05 and centre.z > FRONT_WALL + .05
	return on_floor and Vector2(centre.x, centre.z).length() < CABIN_RADIUS - .15

func _build_cabin() -> void:
	var deck_body := StaticBody3D.new()
	deck_body.name = "CabinDeck"
	deck_body.collision_layer = 1
	deck_body.set_meta("interaction_target", self)
	add_child(deck_body)
	for part in [["frame_deck", DECK - .04, .08], ["shell_ceiling", CEILING + .05, .1]]:
		var disc := CylinderMesh.new()
		disc.top_radius = CABIN_RADIUS + .02; disc.bottom_radius = CABIN_RADIUS + .02
		disc.height = part[2]; disc.radial_segments = 40
		var source := StandardMaterial3D.new()
		source.resource_name = part[0]
		disc.material = MHPalette.material(source)
		var mesh := MeshInstance3D.new()
		mesh.mesh = disc
		mesh.position.y = part[1]
		add_child(mesh)
		var shape := CylinderShape3D.new()
		shape.radius = CABIN_RADIUS; shape.height = part[2]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = part[1]
		deck_body.add_child(collision)
	# The model is open to the outside in slots either side of its recessed
	# hatch (between the airlock walls and the hull): the cabin's front wall,
	# and solid fillers in the slots (one between the airlock wall and the
	# hatch frame post, one behind it flush with the hull), close it.
	for side in [-1.0, 1.0]:
		var outer := sqrt(CABIN_RADIUS * CABIN_RADIUS - FRONT_WALL * FRONT_WALL) + .05
		_wall(deck_body, Vector3(side * 1.08, DECK, FRONT_WALL - .04), Vector3(side * outer, CEILING, FRONT_WALL + .04))
		_wall(deck_body, Vector3(side * 1.0, 2.3, -2.62), Vector3(side * 1.34, 5.8, FRONT_WALL))
		_wall(deck_body, Vector3(side * 1.34, 2.3, -1.62), Vector3(side * 1.8, 5.8, FRONT_WALL))
	# Over the doorway: hides the trimmed edges of the old door's frame.
	_wall(deck_body, Vector3(-1.08, 5.4, FRONT_WALL + .03), Vector3(1.08, CEILING, FRONT_WALL + .09))
	# A round ceiling lamp, a downlight under it and a soft fill.
	var lamp := MeshInstance3D.new()
	var lamp_disc := CylinderMesh.new()
	lamp_disc.top_radius = .38; lamp_disc.bottom_radius = .42; lamp_disc.height = .05
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#FFF1DC")
	glow.emission_enabled = true
	glow.emission = Color("#FFE2BA")
	glow.emission_energy_multiplier = .9
	lamp_disc.material = glow
	lamp.mesh = lamp_disc
	lamp.position = Vector3(0, CEILING - .025, .3)
	add_child(lamp)
	var down := SpotLight3D.new()
	down.position = Vector3(0, CEILING - .1, .3)
	down.rotation.x = -PI * .5
	down.light_color = Color("#FFE4C0")
	down.light_energy = 2.2
	down.light_specular = .3
	down.spot_range = 4.5
	down.spot_angle = 68.0
	down.spot_attenuation = .9
	add_child(down)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, CEILING - .6, .3)
	fill.light_color = Color("#FFD9A8")
	fill.light_energy = .5
	fill.light_specular = 0.0
	fill.omni_range = 3.4
	add_child(fill)

## A solid wall block between two corners (lander space), in the house shell.
func _wall(body: StaticBody3D, corner_a: Vector3, corner_b: Vector3) -> void:
	var lo := corner_a.min(corner_b)
	var size := corner_a.max(corner_b) - lo
	var box := BoxMesh.new()
	box.size = size
	var source := StandardMaterial3D.new()
	source.resource_name = "shell_wall"
	box.material = MHPalette.material(source)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = lo + size * .5
	add_child(mesh)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = mesh.position
	body.add_child(collision)

func _furnish() -> void:
	var builder := get_tree().get_first_node_in_group("habitat_builder")
	if builder == null: return
	for index in FURNITURE.size():
		var item: Array = FURNITURE[index]
		var facing: Vector2 = item[2]
		var at: Vector3 = item[1] + Vector3(0, DECK, 0)
		var holder: Node3D = builder.free_interior_visual(str(item[0]), at, atan2(facing.x, facing.y) + MODEL_FRONT)
		holder.name = "Cabin_%s_%d" % [item[0], index]
		# Its own id, so a rigged item's switches don't share a habitat item's.
		holder.set_meta("interior_placement_id", "lander_cabin_%d" % index)
		for body in holder.find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = 1 if present else 0
		add_child(holder)

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

## Where a new game starts: standing in the cabin, facing the hatch through
## the airlock.
func cabin_start() -> Dictionary:
	return {"position": to_global(Vector3(0.0, DECK + .3, -.3)), "yaw": rotation.y}

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
