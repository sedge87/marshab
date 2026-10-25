class_name MHCompanionRover
extends CharacterBody3D
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")

## GAR-Y, the Geological Analysis Rover, Y-Class: the crew's companion.
##
## A small routine with a personality, and a life of its own:
## - Indoors it roams the habitat room to room, opening interior and vehicle
##   bay doors (never airlocks) and closing them behind it, lingering in a
##   room before moving on; now and then it comes to visit you.
## - It never opens an airlock, so it only goes in or out with you: a ping
##   (E) means "come with me" and it follows you closely for a while, through
##   any airlock you cycle.
## - Outdoors by day it roams near you (or near the airlock if you've gone
##   in) and now and then surveys: it scans the ground, plants a flag where
##   there's buried ice, or scoops a regolith sample.
## - Indoors it also potters about. Every few minutes it tidies: one of your
##   odds and ends from the floor onto a free table, desk or shelf (now and
##   then it rearranges one from surface to surface instead). It nudges the
##   plush to make it squeak, and worries out loud when the grid is down.
## - It reacts to the habitat (playtest, 25 Oct): when an alert goes up it
##   goes to look at the trouble (the battery for power, life support for the
##   air, the shelter in a solar storm), chirps happily when it clears, and
##   comes over to look at new things you place nearby.
## - At night it heads for its dock if the habitat has one (or naps where it
##   is); during a dust storm outside it frets.
## - Its eyes show its mood, its lamp only comes on in the dark, and E pings
##   it (ping it three times quickly for a spin).
## Settings → GAR-Y autonomy turns the wandering off. It owns no player or
## habitat state beyond its flags and tallies (saved with the base), and the
## world spawns it only when MarsWorld.SPAWN_SCOUT_ROVER is true.

@export var follow_distance := 4.4
@export var stop_distance := 2.4
@export var catch_up_distance := 11.0
@export var walk_speed := 2.15
@export var sprint_speed := 3.65
@export var step_height := 0.34
@export var wheel_radius := 0.165

const NAME := "GAR-Y"
const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")
const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const FULL_NAME := "Geological Analysis Rover, Y-Class"
const ABOUT := "GAR-Y is a multipurpose rover designed for geological surveys, surface sample collection, terrain mapping and identifying potential water-ice deposits."
## Eye colour and brightness for each mood.
const MOODS := {
	"curious": [Color("#7FE6FF"), 1.0], "busy": [Color("#FFB347"), 1.0], "happy": [Color("#8CF5A0"), 1.2],
	"sleepy": [Color("#5A7DFF"), .35], "worried": [Color("#FF5A61"), 1.0]
}
## Arm poses: shoulder, elbow and wrist pitch in degrees (forward is positive).
const POSES := {"stow": Vector3(0, 150, 30), "reach": Vector3(110, 40, 30), "carry": Vector3(40, 60, -10), "scoop": Vector3(108, 42, 70)}
## How often things happen (real seconds), so the autonomy stays rare.
const SURVEY_EVERY := Vector2(150.0, 300.0)
const MISCHIEF_EVERY := Vector2(150.0, 300.0)   # tidying (it used to wait 20-30 minutes and rarely found anything)
## How often a tidy-up rearranges a surface instead (when the floor is clear).
const REARRANGE_CHANCE := .3
const PLUSH_EVERY := Vector2(500.0, 900.0)
const WORRY_EVERY := Vector2(240.0, 420.0)
const NAP_AFTER := 25.0
const TASK_STOP := .75
const MAX_FLAGS := 12
const ESCORT_MS := 90000
## GAR-Y's rock collection: now and then a survey turns up a special rock,
## which GAR-Y names and keeps beside its charger. Each is a real kind of
## Mars rock: [name, kind, what it tells us, colour]. Gerald always comes first.
const ROCKS := [
	["Gerald", "Basalt", "Dark volcanic rock. Most of the surface of Mars is made of it.", Color("#4A4440")],
	["Blueberry", "Hematite concretion", "A little iron-rich ball that formed in water. Opportunity found thousands of them.", Color("#5B4A55")],
	["Olive", "Olivine basalt", "Green crystals that break down quickly in water, so this spot has been dry for a very long time.", Color("#6E7448")],
	["Sparkles", "Gypsum vein", "A white mineral left behind by water trickling through cracks in the rock.", Color("#E6E1D6")],
	["Swiss", "Vesicular basalt", "Full of holes made by gas bubbles as the lava cooled.", Color("#5E5650")],
	["Pebbles", "River conglomerate", "Smooth, rounded stones cemented together: an ancient riverbed, like the one Curiosity found.", Color("#8A6A50")],
	["Professor Crumbles", "Mudstone", "Fine layers of mud from an old lake. Good places to look for signs of ancient life.", Color("#9A7660")],
	["Sue", "Sulfur crystals", "Bright yellow. In 2024 Curiosity drove over a rock, cracked it open and found pure sulfur inside.", Color("#D8C25A")],
	["Clay-ton", "Clay-rich rock", "Clay forms in water that is not too acidic or salty: water that life could have used.", Color("#A0705A")],
	["Visitor", "Iron meteorite", "A lump of iron and nickel from space. Rovers have found several lying on Mars.", Color("#6A6A6E")],
	["Rusty", "Dust-coated rock", "Mars dust is mostly rusty iron oxide, finer than flour. It coats everything orange.", Color("#B5653A")],
	["Salty", "Perchlorate salt crust", "Salts in the soil that are harmful to people. It's why the crew clean dust off their suits.", Color("#D9CDB8")],
]
const ROCK_CHANCE := .35
const OWN_DOORS := ["INTERIOR", "BAY"]   # never OUTER, INNER or HANGAR: airlocks are yours to cycle

var target: Node3D
## The habitat builder (rooms, placed items, the simulation).
var habitat: Node

# ---- what it's up to ----
var task := ""                 # "", "survey", "fetch", "deliver", "plush", "charge"
var task_goal := Vector3.INF
var task_data := {}
var napping := false
var docked := false
var mood := "curious"
var ice_found := 0
var samples := 0
var rocks: Array = []          # ROCKS indices found, in order (saved)
## Every spot surveyed: Vector3(x, z, ice richness measured) (saved). The
## maps and the site plan's ice overlay show these (scripts/ice_knowledge.gd).
var ice_samples: Array = []
const MAX_SAMPLES := 80
var flags: Array = []          # flag positions (Vector3), saved
## Orders (hold G, or the Mission Control map): see order().
var staying := false           # "Stay": waits here until told otherwise
var has_core := false          # carrying a core sample for the Science Lab (saved)
var surveys_ordered := 0
var _stay_point := Vector3.INF
var _ordered := false          # the current errand was an order: more time, always reports back
var _core_check := 0.0
var _told_no_lab := false
var _mood_override := ""
var _mood_timer := 0.0
var _busy := false             # mid-animation: stand still
var _task_age := 0.0
var _survey_timer := 0.0
var _mischief_timer := 0.0
var _plush_timer := 0.0
var _worry_timer := 0.0
var _pings: Array = []
var _was_storm := false
var _carried: Node3D
var _rest_until := 0         # a nap or dock lasts at least until this (msec)
var _escort_until := 0       # "come with me": following you closely until this (msec)
var _route: Array = []       # waypoints through doors to where it's heading
var _route_dest := Vector3.INF
var _linger := 0.0           # how long it potters where it is before moving on
var _stop := 2.4             # how close it stops to the current point
var _door_timer := 0.0
var _opened: Array = []      # doors it opened, to close behind it
var _door_wait := 0.0

# ---- movement (as before) ----
var _roam_goal := Vector3.INF
var _roam_timer := 0.0
var _stuck_timer := 0.0
var _idle_time := 0.0
var _scan_time := 0.0
var _wander_phase := 0.0
var _chirp_timer := 0.0
var _met := false            # the GAR-Y card has had its chance this session

# ---- the body ----
var _visual: Node3D
var _wheels: Array[Node3D] = []
var _mast: Node3D
var _head: Node3D
var _eyes: Array[Node3D] = []
var _eye_material: StandardMaterial3D
var _arm: Array[Node3D] = []   # shoulder, elbow, wrist
var _grip: Node3D
var _lamp: SpotLight3D
var _blink_timer := 3.0
var _flag_root: Node3D
var _rock_root: Node3D
var _rocks_shown := false

func setup(follow_target: Node3D) -> MHCompanionRover:
	target = follow_target
	return self

func _ready() -> void:
	add_to_group("gar_y")
	floor_snap_length = step_height + .20
	floor_max_angle = deg_to_rad(54.0)
	safe_margin = .04
	_wander_phase = randf() * TAU
	_chirp_timer = randf_range(4.0, 8.0)
	_survey_timer = randf_range(60.0, 120.0)
	_mischief_timer = randf_range(MISCHIEF_EVERY.x, MISCHIEF_EVERY.y)
	_plush_timer = randf_range(PLUSH_EVERY.x, PLUSH_EVERY.y)
	_worry_timer = randf_range(WORRY_EVERY.x, WORRY_EVERY.y)
	_visual = get_node_or_null("RoverVisual") as Node3D
	MHPalette.apply(self)   # house materials, like the rest of the base
	for i in range(1, 7):
		var wheel := find_child("Wheel_%d" % i, true, false) as Node3D
		if wheel != null: _wheels.append(wheel)
	_mast = find_child("Mast", true, false) as Node3D
	_head = find_child("Head", true, false) as Node3D
	for eye_name in ["Eye_L", "Eye_R"]:
		var eye := find_child(eye_name, true, false) as Node3D
		if eye != null: _eyes.append(eye)
	_eye_material = StandardMaterial3D.new()
	_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for eye in _eyes:
		for mesh in eye.find_children("*", "MeshInstance3D", true, false): (mesh as MeshInstance3D).material_override = _eye_material
	for joint in ["ArmShoulder", "ArmElbow", "ArmWrist"]:
		var node := find_child(joint, true, false) as Node3D
		if node != null: _arm.append(node)
	_grip = find_child("Grip", true, false) as Node3D
	_set_pose("stow", false)
	# The torch: on the mast head, tilted down at the ground ahead, a soft warm
	# white, on only in the dark, no shadows, and outside the world's light cap
	# so it never pops on and off.
	var mount := find_child("LampMount", true, false) as Node3D
	_lamp = SpotLight3D.new()
	_lamp.name = "GarYLamp"
	_lamp.light_color = Color("#FFE7C4")
	_lamp.light_energy = 0.0
	_lamp.spot_range = 9.0
	_lamp.spot_angle = 30.0
	_lamp.spot_attenuation = 1.1
	_lamp.shadow_enabled = false
	_lamp.set_meta("budget_exempt", true)
	_lamp.rotation.x = deg_to_rad(-14.0)
	(mount if mount != null else self).add_child(_lamp)
	_apply_mood(0.0)

# ---------- each physics frame ----------

func _physics_process(delta: float) -> void:
	if target == null:
		return
	# Build mode uses an isometric construction camera; keep the rover out of it.
	var building := bool(target.get_meta("build_mode_active", false))
	visible = not building
	# Free play: the first time you walk up to GAR-Y, its card (once ever;
	# in Missions it's in the brief).
	if not _rocks_shown: _rebuild_rocks()
	if not _met and not building and global_position.distance_to(target.global_position) < 4.0:
		_met = true
		if not MHMissions.active(): HOW_IT_WORKS.first_meeting(get_tree(), "gar_y", "Meet GAR-Y")
	if building:
		if not task.is_empty(): _end_task(true)
		velocity = Vector3.ZERO
		return
	_think(delta)
	var desired := global_position if (_busy or napping) else _follow_point()
	var stop := _stop
	var flat_delta := desired - global_position
	flat_delta.y = 0.0
	var distance := flat_delta.length()
	var before := global_position
	if distance > stop:
		_idle_time = 0.0
		var direction := flat_delta.normalized()
		var maximum := sprint_speed if distance > follow_distance * 2.4 else walk_speed
		var speed := minf(maximum, (distance - stop) * 1.35 + (.4 if task_goal != Vector3.INF else 0.0))
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 7.0, 1.0))
	else:
		_idle_time += delta
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 5.0 * delta)
		if task_goal != Vector3.INF and not _busy: _arrived()
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = -.1
	move_and_slide()
	_try_step_over_threshold(flat_delta)
	# Stuck against a wall: indoor roaming picks somewhere else; a task gives up.
	if distance > stop and not _busy and not napping:
		var progress := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		_stuck_timer = _stuck_timer + delta if progress < .01 else 0.0
		if _stuck_timer > 2.0:
			_stuck_timer = 0.0
			# Blocked just short (by you, say): close enough to carry on.
			if not task.is_empty() and distance < 1.3: _arrived()
			elif not task.is_empty(): _end_task(true)
			else:
				_roam_goal = Vector3.INF   # blocked: pick somewhere else
				_route.clear()
	_animate(before, delta)
	_pet_sounds(delta)
	_door_timer -= delta
	if _door_timer <= 0.0:
		_door_timer = .2
		_manage_doors()
	# Lost far off outdoors (it never wanders that far by itself): back near you,
	# or near the airlock if you're inside. Indoors it stays where it is.
	if not _self_indoors() and global_position.distance_to(target.global_position) > 70.0:
		if not task.is_empty(): _end_task(true)
		global_position = _spawn_point()
		velocity = Vector3.ZERO
		napping = false

# ---------- the brain ----------

func _think(delta: float) -> void:
	var indoors := _self_indoors()
	var storm := _storm()
	var dark := MHGame.sunlight_fraction < .2
	var autonomy := bool(MHGame.setting("gary_autonomy"))
	if not task.is_empty(): _task_age += delta
	if task_age_limit() > 0.0 and _task_age > task_age_limit(): _end_task(true)
	# Storms: huddle close and fret.
	if storm and not _was_storm: _say("worried")
	_was_storm = storm
	# Naps: at night once it's been still near you a while; wakes for daylight,
	# a ping, or when you walk off.
	if napping:
		if not dark and Time.get_ticks_msec() > _rest_until: _wake()
	elif task.is_empty() and dark and not _escorting() and _idle_time > (6.0 if indoors else NAP_AFTER):
		if indoors and autonomy and _start_charge(): pass
		else: _nap()
	# Back inside with a core sample: take it to the Science Lab (checked every few seconds).
	_core_check -= delta
	if has_core and indoors and task.is_empty() and not _busy and not napping and _core_check <= 0.0:
		_core_check = 3.0
		_start_core_delivery()
	if staying or not autonomy or napping or not task.is_empty() or _busy or _escorting():
		return
	if indoors:
		_mischief_timer -= delta
		_plush_timer -= delta
		_worry_timer -= delta
		if _worry_timer <= 0.0:
			_worry_timer = randf_range(WORRY_EVERY.x, WORRY_EVERY.y)
			if habitat != null and not habitat.grid_power_online():
				_say("worried")
				_toast("GAR-Y looks worried", "The habitat's power grid is offline.", MHStyle.WARN)
		_look_check -= delta
		if _look_check <= 0.0:
			_look_check = 1.5
			if _look_at_new_thing(): return
		if _plush_timer <= 0.0:
			_plush_timer = randf_range(PLUSH_EVERY.x, PLUSH_EVERY.y)
			if start_plush(): return
		if _mischief_timer <= 0.0:
			_mischief_timer = randf_range(MISCHIEF_EVERY.x, MISCHIEF_EVERY.y)
			start_fetch()
	elif not storm and not dark:
		_survey_timer -= delta
		if _survey_timer <= 0.0:
			_survey_timer = randf_range(SURVEY_EVERY.x, SURVEY_EVERY.y)
			start_survey()

func task_age_limit() -> float:
	if task.is_empty(): return 0.0
	return 150.0 if _ordered or task == "patrol" else 40.0   # per stop on an ice hunt (reset at each)

func _start(kind: String, goal: Vector3, data := {}) -> void:
	task = kind
	task_goal = goal
	task_data = data
	_task_age = 0.0
	_stuck_timer = 0.0
	napping = false
	docked = false

## Clears the current errand. failed: put back anything it was carrying.
func _end_task(failed := false) -> void:
	if failed and _carried != null: _put_down(str(task_data.get("placement_id", "")), task_data.get("from", Vector3.ZERO) as Vector3, float(task_data.get("from_yaw", 0.0)))
	if failed and _ordered: _toast("GAR-Y couldn't finish", "It couldn't get there. Try a spot it can drive to.", MHStyle.WARN)
	task = ""
	task_goal = Vector3.INF
	task_data = {}
	_busy = false
	_ordered = false
	if not docked: _set_pose("stow")

func _arrived() -> void:
	match task:
		"survey": _survey_here()
		"fetch": _pick_up()
		"deliver": _deliver()
		"plush": _nudge_plush()
		"inspect": _inspect_here()
		"look": _look_here()
		"charge": _dock()
		"goto":
			staying = true
			_stay_point = global_position
			_say("happy")
			_end_task()
		"core": _core_here()
		"core_deliver": _core_delivered()
		"patrol": _patrol_next()

# ---- survey: scan, then flag ice or scoop a sample ----

func start_survey() -> bool:
	if habitat == null: return false
	for attempt in 8:
		var angle := randf() * TAU
		var spot := global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(7.0, 12.0)
		spot.y = global_position.y
		if habitat.is_inside(spot): continue
		_start("survey", spot)
		_say("curious")
		return true
	return false

func _survey_here() -> void:
	_busy = true
	_scan_time += 3.0
	await get_tree().create_timer(2.6).timeout
	if task != "survey": return
	var at := Vector2(global_position.x, global_position.z)
	var richness := float(habitat._ice_richness_at_point(at)) if habitat.has_method("_ice_richness_at_point") else 0.0
	var near_flag := flags.any(func(f): return Vector2((f as Vector3).x, (f as Vector3).z).distance_to(at) < 10.0)
	ice_samples.append(Vector3(at.x, at.y, snappedf(richness, .01)))
	while ice_samples.size() > MAX_SAMPLES: ice_samples.pop_front()
	var hunting: bool = task_data.has("hunt")
	if richness >= .25 and not near_flag:
		await _arm_move("reach", .7)
		_plant_flag(global_position + -global_transform.basis.z * .9)
		await _arm_move("stow", .6)
		ice_found += 1
		if _ordered and not hunting: _survey_done()
		_say("tada")
		if not hunting: _toast("GAR-Y found buried ice", "About %d%% ice under the flag it just planted. An ice extractor there would do well." % roundi(richness * 100.0), MHStyle.INFO)
	else:
		await _arm_move("scoop", .8)
		await get_tree().create_timer(.4).timeout
		await _arm_move("stow", .7)
		samples += 1
		_say("happy")
		var rock := _find_rock()
		if hunting: pass
		elif _ordered:
			_survey_done()
			if rock < 0: _toast("GAR-Y surveyed the spot", "No buried ice here (under 25%%). It scooped a regolith sample instead: %d so far." % samples, MHStyle.INFO)
		elif rock < 0 and (samples == 1 or samples % 5 == 0):
			_toast("GAR-Y scooped a sample", "Regolith samples collected so far: %d. No buried ice here." % samples, MHStyle.INFO)
		if rock >= 0:
			_say("tada")
			var found: Array = ROCKS[rock]
			_toast("GAR-Y found a special rock. It has named it %s." % found[0], "%s: %s It's keeping %s by its charger (%d of %d)." % [found[1], found[2], found[0], rocks.size(), ROCKS.size()], MHStyle.VALID)
	if hunting: _hunt_next(at, richness)
	else: _end_task()

## "Find ice": on to the next stop of the survey loop, or report the best spot.
func _hunt_next(at: Vector2, richness: float) -> void:
	if richness > float(task_data.get("best", -1.0)):
		task_data["best"] = richness
		task_data["best_at"] = at
	var left: Array = task_data.get("hunt", [])
	_busy = false
	if not left.is_empty():
		var next: Vector2 = left.pop_front()
		task_data.hunt = left
		task_goal = Vector3(next.x, global_position.y, next.y)
		_task_age = 0.0
		return
	_survey_done()
	var stops := int(task_data.get("stops", 0))
	var best := float(task_data.get("best", 0.0))
	if best >= ICE_KNOWLEDGE.WORTH_DRILLING:
		_say("tada")
		_toast("GAR-Y's ice survey: found it", "%d spots checked. The best had about %d%% ice, and it's flagged. An ice extractor there would make about %d L of water a sol. The site plan's ice overlay shows everything it measured." % [stops, roundi(best * 100.0), roundi(MHResources.setting("ice_drill_l", 120.0) * best)], MHStyle.VALID)
	else:
		_say("worried")
		_toast("GAR-Y's ice survey: not here", "%d spots checked, and the best had only %d%% ice: not worth drilling. Orbital radar only gives a rough idea. Try another likely zone." % [stops, roundi(best * 100.0)], MHStyle.WARN)
	_end_task()

## Sometimes a sample is a special rock it hasn't got yet (Gerald first).
## Returns its ROCKS index, or -1.
func _find_rock() -> int:
	if rocks.size() >= ROCKS.size(): return -1
	if not rocks.is_empty() and randf() > ROCK_CHANCE: return -1
	var left: Array = range(ROCKS.size()).filter(func(i): return not rocks.has(i))
	var pick: int = 0 if rocks.is_empty() else int(left.pick_random())
	rocks.append(pick)
	_rebuild_rocks()
	return pick

## The collection, in rows on the floor beside the first GAR-Y Dock indoors
## (none shown until there's a dock).
func _rebuild_rocks() -> void:
	_rocks_shown = true
	if habitat == null: return
	if habitat.has_signal("habitat_changed") and not habitat.is_connected("habitat_changed", _on_habitat_changed):
		habitat.connect("habitat_changed", _on_habitat_changed)
	if _rock_root == null or not is_instance_valid(_rock_root):
		_rock_root = Node3D.new()
		_rock_root.name = "GarYRocks"
		(get_parent() if get_parent() != null else self).add_child.call_deferred(_rock_root)
	for child in _rock_root.get_children(): child.queue_free()
	if rocks.is_empty(): return
	for item in habitat.placed_interior:
		if str(item.get("id", "")) != "rover_charger": continue
		var dock := Transform3D(Basis(Vector3.UP, float(item.get("rotation_y", 0.0))), item.get("position", Vector3.ZERO) as Vector3)
		for n in range(rocks.size()):
			var index := int(rocks[n])
			var spec: Array = ROCKS[index]
			var size := .05 + .025 * float((index * 7) % 5) / 4.0
			var rock := MeshInstance3D.new()
			rock.name = str(spec[0])
			var mesh := SphereMesh.new()
			mesh.radius = size
			mesh.height = size * 2.0
			mesh.radial_segments = 7
			mesh.rings = 4
			rock.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = spec[3]
			material.roughness = .4 if index == 3 or index == 9 else .9
			material.metallic = .5 if index == 9 else 0.0
			rock.material_override = material
			# Two neat rows along the dock's right side, each rock squashed a
			# little differently so they read as stones, not marbles.
			var local := Vector3(.7 + .15 * float(n / 6), size * .6, -.38 + .15 * float(n % 6))
			var shape := Basis(Vector3.UP, float(index) * 1.3).scaled(Vector3(1.2 - .05 * float(index % 3), .6 + .05 * float(index % 4), 1.0))
			rock.transform = dock * Transform3D(shape, local)
			_rock_root.add_child(rock)
		return

func _on_habitat_changed() -> void:
	_rebuild_rocks.call_deferred()

func _plant_flag(spot: Vector3) -> void:
	spot.y = global_position.y
	flags.append(spot)
	while flags.size() > MAX_FLAGS: flags.pop_front()
	_rebuild_flags()

func _rebuild_flags() -> void:
	if _flag_root == null or not is_instance_valid(_flag_root):
		_flag_root = Node3D.new()
		_flag_root.name = "GarYFlags"
		(get_parent() if get_parent() != null else self).add_child.call_deferred(_flag_root)
	for child in _flag_root.get_children(): child.queue_free()
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color("#C9CFD2")
	var flag_material := StandardMaterial3D.new()
	flag_material.albedo_color = Color("#7FE6FF")
	flag_material.emission_enabled = true
	flag_material.emission = Color("#7FE6FF")
	flag_material.emission_energy_multiplier = .6
	for spot in flags:
		var flag := Node3D.new()
		flag.position = spot as Vector3
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new(); pole_mesh.top_radius = .012; pole_mesh.bottom_radius = .015; pole_mesh.height = .7
		pole.mesh = pole_mesh; pole.material_override = pole_material; pole.position.y = .35
		flag.add_child(pole)
		var cloth := MeshInstance3D.new()
		var cloth_mesh := BoxMesh.new(); cloth_mesh.size = Vector3(.22, .13, .01)
		cloth.mesh = cloth_mesh; cloth.material_override = flag_material; cloth.position = Vector3(.11, .62, 0)
		flag.add_child(cloth)
		# What GAR-Y measured here.
		if habitat != null and habitat.has_method("_ice_richness_at_point"):
			var tag := Label3D.new()
			tag.text = "%d%% ICE" % roundi(100.0 * float(habitat._ice_richness_at_point(Vector2((spot as Vector3).x, (spot as Vector3).z))))
			tag.font_size = 40
			tag.pixel_size = .004
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.modulate = Color("#CFF3FF")
			tag.outline_size = 8
			tag.position = Vector3(0, .9, 0)
			flag.add_child(tag)
		_flag_root.add_child(flag)

# ---- mischief: carry an odds-and-ends item somewhere else in the room ----

## Small odds and ends on the floor of the room GAR-Y is in.
func _clutter_candidates() -> Array:
	if habitat == null: return []
	var room: Dictionary = habitat._zone_at_point(Vector2(global_position.x, global_position.z))
	var found: Array = []
	for item in habitat.placed_interior:
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if str(entry.get("group", "")) != "odds_and_ends" or not bool(entry.get("stackable", false)): continue
		if not habitat.items_resting_on(item).is_empty(): continue
		if habitat._zone_at_point(Vector2(at.x, at.z)) != room or at.distance_to(global_position) > 12.0: continue
		found.append(item)
	return found

func _on_floor(item: Dictionary) -> bool:
	return (item.get("position", Vector3.ZERO) as Vector3).y <= habitat.habitat_base_y + .2

## A tidy-up: something off the floor first; otherwise, now and then, it
## rearranges a surface.
func start_fetch() -> bool:
	var choices := _clutter_candidates()
	var on_floor := choices.filter(_on_floor)
	if not on_floor.is_empty(): choices = on_floor
	elif randf() > REARRANGE_CHANCE: return false
	if choices.is_empty(): return false
	var item: Dictionary = choices.pick_random()
	var at: Vector3 = item.position
	var approach := at + (global_position - at).normalized() * .45
	_start("fetch", approach, {"placement_id": str(item.placement_id), "id": str(item.id), "from": at, "from_yaw": float(item.get("rotation_y", 0.0))})
	_say("curious")
	return true

func _pick_up() -> void:
	_busy = true
	_face(task_data.get("from", global_position) as Vector3)
	await _arm_move("reach", .8)
	if task != "fetch": return
	var visual := _item_visual(str(task_data.placement_id))
	if visual == null:
		_end_task()
		return
	_carried = visual
	for body in visual.find_children("*", "StaticBody3D", true, false): (body as StaticBody3D).collision_layer = 0
	visual.reparent(_grip, true)
	visual.position = Vector3.ZERO
	await _arm_move("carry", .7)
	var spot := _spot_by_player(str(task_data.placement_id)) if bool(task_data.get("to_player", false)) else _tidy_spot(str(task_data.placement_id), task_data.from as Vector3)
	task_data.to = spot.position
	task_data.to_yaw = spot.yaw
	task = "deliver"
	task_goal = (spot.position as Vector3) + (global_position - (spot.position as Vector3)).normalized() * .5
	_task_age = 0.0
	_busy = false

## Where a tidy-up puts something: on a free table, desk, counter or shelf in
## the same room (another one if it's already on a surface), else a free
## floor spot.
func _tidy_spot(placement_id: String, from: Vector3) -> Dictionary:
	var room: Dictionary = habitat._zone_at_point(Vector2(from.x, from.z))
	var surfaces: Array = []
	for item in habitat.placed_interior:
		if str(item.get("placement_id", "")) == placement_id: continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if habitat._zone_at_point(Vector2(at.x, at.z)) != room: continue
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		if habitat.surface_tops(entry).is_empty(): continue
		# Not back onto the one it came off.
		if Vector2(at.x - from.x, at.z - from.z).length() < .9 and from.y > habitat.habitat_base_y + .2: continue
		surfaces.append(item)
	surfaces.shuffle()
	for item in surfaces:
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var size: Vector2 = habitat._surface_size(entry)
		var basis := Basis(Vector3.UP, float(item.get("rotation_y", 0.0)))
		for top in habitat.surface_tops(entry):
			for attempt in 10:
				var offset := basis * Vector3(randf_range(-.4, .4) * size.x, 0, randf_range(-.4, .4) * size.y)
				var spot := at + offset + Vector3.UP * float(top)
				var yaw := randf() * TAU
				if habitat.free_interior_move_reason(placement_id, spot, yaw).is_empty():
					return {"position": spot, "yaw": yaw}
	return _new_spot(placement_id, from)

## A fresh legal floor spot in the same room (or where it came from).
func _new_spot(placement_id: String, from: Vector3) -> Dictionary:
	var room: Dictionary = habitat._zone_at_point(Vector2(from.x, from.z))
	var cells: Array = room.get("cells", [])
	for attempt in 30:
		if cells.is_empty(): break
		var cell: Vector2i = cells.pick_random()
		var spot := Vector3(cell.x * 3.0 + randf_range(-1.1, 1.1), from.y, cell.y * 3.0 + randf_range(-1.1, 1.1))
		var yaw := randf() * TAU
		if spot.distance_to(from) > 1.5 and habitat.free_interior_move_reason(placement_id, spot, yaw).is_empty():
			return {"position": spot, "yaw": yaw}
	return {"position": from, "yaw": float(task_data.get("from_yaw", 0.0))}

func _deliver() -> void:
	_busy = true
	_face(task_data.to as Vector3)
	await _arm_move("reach", .8)
	if task != "deliver": return
	var placement_id := str(task_data.placement_id)
	var moved := _put_down(placement_id, task_data.to as Vector3, float(task_data.to_yaw))
	await _arm_move("stow", .7)
	if moved and bool(task_data.get("to_player", false)):
		_say("tada")
		_toast("GAR-Y brought you the %s" % str(EquipmentCatalog.get_entry(str(task_data.id)).get("label", "item")).to_lower(), "Delivered.", MHStyle.VALID)
	elif moved and (task_data.to as Vector3).distance_to(task_data.from as Vector3) > .5:
		_say("tada")
		var label := str(EquipmentCatalog.get_entry(str(task_data.id)).get("label", "things")).to_lower()
		var tidied: bool = (task_data.from as Vector3).y <= habitat.habitat_base_y + .2 and (task_data.to as Vector3).y > habitat.habitat_base_y + .2
		if tidied: _toast("GAR-Y tidied up", "It picked your %s up off the floor and put it away." % label, MHStyle.INFO)
		else: _toast("GAR-Y moved your %s" % label, "It's somewhere else in the room now. GAR-Y seems very pleased with itself.", MHStyle.INFO)
	_end_task()

## Sets a carried item down (and records it there); back where it was if that fails.
func _put_down(placement_id: String, spot: Vector3, yaw: float) -> bool:
	if _carried == null or not is_instance_valid(_carried):
		_carried = null
		return false
	var visual := _carried
	_carried = null
	visual.reparent(habitat.furnishing, true)
	for body in visual.find_children("*", "StaticBody3D", true, false): (body as StaticBody3D).collision_layer = 1
	if habitat.move_free_interior_equipment(placement_id, spot, yaw): return true
	for item in habitat.placed_interior:
		if str(item.get("placement_id", "")) == placement_id:
			visual.global_position = item.position as Vector3
			visual.rotation = Vector3(0, float(item.get("rotation_y", 0.0)), 0)
	return false

func _item_visual(placement_id: String) -> Node3D:
	for child in habitat.furnishing.get_children():
		if str(child.get_meta("interior_placement_id", "")) == placement_id: return child as Node3D
	return null

# ---- reacting to the habitat ----

## Where to look for each alert's trouble: the equipment first, else a room.
const TROUBLE := {
	"power": [["battery_bank"], "engineering", "batteries"], "life_support_power": [["battery_bank"], "engineering", "batteries"],
	"battery_sunset": [["battery_bank"], "engineering", "batteries"],
	"o2": [["oxygen_generator"], "life_support", "oxygen generator"], "co2": [["air_recycler"], "life_support", "air recycler"],
	"cold": [["thermal_control_unit"], "life_support", "heating"], "cold_spot": [["thermal_control_unit"], "life_support", "heating"],
	"water": [["water_reclaimer"], "life_support", "water"], "food": [["galley_kitchenette", "galley_oven"], "galley", "food"],
	"health": [["medical_exam_cot"], "medical", "medical bay"], "injury": [["medical_exam_cot"], "medical", "medical bay"],
	"radiation": [["storm_shelter_locker"], "", "storm shelter"], "breakdown": [["spare_parts_rack"], "engineering", "spare parts"],
	"breach": [["hull_patch_kit"], "", "hull breach"],
}
var _look_check := 2.0
var _seen_items := -1
var _inspected := {}   # alert id -> when it last went to look (msec)

## An alert went up (habitat_alerts.gd): look worried and go and check on it.
func on_habitat_alert(id: String, level: String) -> void:
	if habitat == null or level == "advisory": return
	_say("worried")
	if not bool(MHGame.setting("gary_autonomy")) or staying or _ordered or _escorting() or _busy or _carried != null: return
	if task in ["deliver", "core_deliver", "charge"]: return
	if Time.get_ticks_msec() - int(_inspected.get(id, -999999)) < 120000: return
	var goal := _trouble_spot(id)
	if is_inf(goal.x) or not _self_indoors(): return
	_inspected[id] = Time.get_ticks_msec()
	if not task.is_empty(): _end_task(true)
	napping = false
	_start("inspect", goal + (global_position - goal).normalized() * .9, {"alert": id, "at": goal, "what": str((TROUBLE.get(id, [[], "", "trouble"]) as Array)[2])})

## The alert cleared: a happy chirp.
func on_alert_cleared(_id: String) -> void:
	if habitat != null: _say("happy")

func _trouble_spot(id: String) -> Vector3:
	var trouble: Array = TROUBLE.get(id, [[], "", ""])
	var best := Vector3.INF
	for item in habitat.placed_interior:
		if not (trouble[0] as Array).has(str(item.get("id", ""))): continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if is_inf(best.x) or at.distance_to(global_position) < best.distance_to(global_position): best = at
	if not is_inf(best.x) or str(trouble[1]).is_empty(): return best
	for zone in habitat.zones:
		if str(zone.get("kind", "")) != str(trouble[1]): continue
		var cells: Array = zone.get("cells", [])
		if cells.is_empty(): continue
		var cell: Vector2i = cells[cells.size() / 2]
		return Vector3(cell.x * 3.0, habitat.habitat_base_y, cell.y * 3.0)
	return Vector3.INF

func _inspect_here() -> void:
	_busy = true
	_face(task_data.at as Vector3)
	await _arm_move("reach", .7)
	if task != "inspect": return
	await get_tree().create_timer(1.2).timeout
	await _arm_move("stow", .6)
	_say("worried")
	_toast("GAR-Y is checking the %s" % str(task_data.what), "It's found where the trouble is. Press N to see the alert.", MHStyle.WARN)
	_end_task()

## Something new placed nearby: go and have a look.
func _look_at_new_thing() -> bool:
	var count: int = habitat.placed_interior.size()
	var was := _seen_items
	_seen_items = count
	if was < 0 or count <= was: return false
	var item: Dictionary = habitat.placed_interior.back()
	var at: Vector3 = item.get("position", Vector3.ZERO)
	if at.distance_to(global_position) > 10.0 or not habitat.is_inside(at): return false
	if str(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("group", "")) == "odds_and_ends": return false
	_start("look", at + (global_position - at).normalized() * 1.1, {"id": str(item.get("id", "")), "at": at})
	return true

func _look_here() -> void:
	_busy = true
	_face(task_data.at as Vector3)
	_say("curious")
	if _visual != null:
		var tilt := create_tween().set_trans(Tween.TRANS_SINE)
		for angle in [.2, -.2, .12, 0.0]: tilt.tween_property(_visual, "rotation:z", angle, .25)
		await tilt.finished
	_say("happy")
	_end_task()

# ---- the plush ----

func start_plush() -> bool:
	if habitat == null: return false
	for item in habitat.placed_interior:
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if str(item.get("id", "")) == "zero_g_plush" and at.distance_to(global_position) < 9.0 and habitat.is_inside(at):
			_start("plush", at + (global_position - at).normalized() * .55, {"placement_id": str(item.placement_id), "at": at})
			return true
	return false

func _nudge_plush() -> void:
	_busy = true
	_face(task_data.at as Vector3)
	if _visual != null:
		var lunge := create_tween().set_trans(Tween.TRANS_SINE)
		lunge.tween_property(_visual, "position:z", -.14, .18)
		lunge.tween_property(_visual, "position:z", 0.0, .3)
	await get_tree().create_timer(.18).timeout
	var visual := _item_visual(str(task_data.placement_id))
	var rig := visual.get_node_or_null("Model") if visual != null else null
	if rig != null and rig.has_method("interact"): rig.interact()
	await get_tree().create_timer(.5).timeout
	_say("happy")
	_end_task()

# ---- night: dock on its charger in the room, or nap ----

## Where GAR-Y sits on a dock's pad (dock-local), and where it lines up first.
const DOCK_SPOT := Vector3(0, 0, -0.16)
const DOCK_APPROACH := Vector3(0, 0, -1.45)

func _start_charge() -> bool:
	if habitat == null: return false
	if not _self_indoors(): return false
	for item in habitat.placed_interior:
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if str(item.get("id", "")) != "rover_charger" or not habitat.is_inside(at): continue
		var dock := Transform3D(Basis(Vector3.UP, float(item.get("rotation_y", 0.0))), at)
		_start("charge", dock * DOCK_APPROACH, {"placement_id": str(item.placement_id), "dock": dock})
		return true
	return false

## Lines up in front of the pad, reverses on, and the dock's plug slides
## into its rear bumper.
func _dock() -> void:
	_busy = true
	var dock: Transform3D = task_data.dock
	var yaw := dock.basis.get_euler().y
	var turn := create_tween().set_trans(Tween.TRANS_SINE)
	turn.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), .6)
	await turn.finished
	if task != "charge": return
	var spot := dock * DOCK_SPOT
	spot.y = global_position.y
	var back := create_tween().set_trans(Tween.TRANS_SINE)
	back.tween_property(self, "global_position", spot, 2.2)
	await back.finished
	if task != "charge": return
	var rig := _dock_rig(str(task_data.placement_id))
	if rig != null: rig.set_state_key("plug", true)
	_say("sleepy")
	docked = true
	task_data = {"placement_id": task_data.placement_id}
	task = ""
	task_goal = Vector3.INF
	_busy = false
	_nap()

func _dock_rig(placement_id: String) -> Node:
	var visual := _item_visual(placement_id) if habitat != null else null
	var rig := visual.get_node_or_null("Model") if visual != null else null
	return rig if rig != null and rig.has_method("set_state_key") else null

func _nap() -> void:
	napping = true
	_rest_until = Time.get_ticks_msec() + (60000 if docked else 20000)
	_say("sleepy")
	_set_pose("stow")

func _wake() -> void:
	if docked:
		var rig := _dock_rig(str(task_data.get("placement_id", "")))
		if rig != null: rig.set_state_key("plug", false)
		task_data = {}
	napping = false
	docked = false
	_idle_time = 0.0

# ---------- orders (backlog 29) ----------

## The orders the menu offers right now (they depend on where GAR-Y is).
func available_orders() -> Array:
	if _self_indoors(): return ["come", "stay", "home", "fetch", "patrol"]
	return ["come", "stay", "home", "survey", "find_ice", "core"]

const ORDER_LABELS := {"come": "Come here", "stay": "Stay here", "home": "Go home", "fetch": "Fetch", "patrol": "Patrol",
	"survey": "Survey there", "core": "Core sample", "goto": "Go there", "find_ice": "Find ice"}

## Carry out an order. point: where you're aiming (survey, core, goto); item:
## the placement you're looking at (fetch). Returns "" or why it can't.
func order(kind: String, point := Vector3.INF, item := "") -> String:
	if habitat == null or target == null: return "GAR-Y isn't ready."
	if napping: _wake()
	if not task.is_empty():
		_ordered = false   # replaced, not failed
		_end_task(true)
	_escort_until = 0
	var indoors := _self_indoors()
	match kind:
		"come":
			staying = false
			_escort_until = Time.get_ticks_msec() + ESCORT_MS
			_say("happy")
		"stay":
			if staying:
				staying = false
				_say("happy")
				return ""
			staying = true
			_stay_point = global_position
			_say("curious")
		"home":
			staying = false
			if indoors:
				if not _start_charge(): return "There's no GAR-Y Dock inside yet. Build one in the Vehicle Bay, Storage or Power & Engineering."
			else:
				var wait := _airlock_waiting_spot()
				if wait == Vector3.INF: return "There's no airlock to wait at."
				_start("goto", wait)
			_ordered = true
			_say("happy")
		"survey", "goto", "core":
			if point == Vector3.INF: return "Aim at the ground where you want GAR-Y to go."
			var inside_point: bool = habitat.is_inside(point)
			if inside_point != indoors: return "GAR-Y can't use the airlock on its own. Ping it (E) so it comes through with you."
			if Vector2(point.x - global_position.x, point.z - global_position.z).length() > 60.0: return "That's too far for GAR-Y (over 60 m)."
			if kind != "goto" and inside_point: return "Surveys and core samples are for outside."
			if kind == "core" and has_core: return "GAR-Y is already carrying a core sample. Bring it inside to the Science Lab."
			staying = false
			point.y = global_position.y
			_start(kind if kind != "goto" else ("goto" if inside_point else "survey"), point)
			_ordered = true
			_say("curious")
		"find_ice":
			# Its own survey loop across the nearest likely zone from orbit.
			if indoors: return "GAR-Y looks for ice outside. Ping it (E) so it comes through the airlock with you."
			var here := Vector2(global_position.x, global_position.z)
			var zone := ICE_KNOWLEDGE.nearest_zone(here, 90.0)
			if zone.is_empty(): return "There's no likely ice within reach. Check the site map for where orbital radar sees it."
			var stops := ICE_KNOWLEDGE.survey_stops(zone, here)
			var first: Vector2 = stops.pop_front()
			staying = false
			_start("survey", Vector3(first.x, global_position.y, first.y), {"hunt": stops, "stops": stops.size() + 1, "best": -1.0})
			_ordered = true
			_say("curious")
			_toast("GAR-Y is off to find ice", "It'll check %d spots across the likely zone, flag any ice worth drilling, and report back." % (stops.size() + 1), MHStyle.INFO)
		"fetch":
			if not indoors: return "GAR-Y fetches things inside the habitat."
			var placement := _fetch_choice(item)
			if placement.is_empty(): return "Look at a small item (odds and ends) first, or put some sample jars in the base."
			staying = false
			var at: Vector3 = placement.position
			_start("fetch", at + (global_position - at).normalized() * .45, {"placement_id": str(placement.placement_id), "id": str(placement.id), "from": at, "from_yaw": float(placement.get("rotation_y", 0.0)), "to_player": true})
			_ordered = true
			_say("curious")
		"patrol":
			if not indoors: return "GAR-Y patrols inside the habitat."
			var points: Array = []
			for zone in habitat.zones:
				if not habitat._is_habitat_zone(zone) or str(zone.get("kind", "")) == "airlock": continue
				var centre := Vector3.ZERO
				for cell in zone.cells: centre += Vector3(cell.x * 3.0, 0, cell.y * 3.0)
				centre /= maxf(1.0, float((zone.cells as Array).size()))
				centre.y = global_position.y
				if habitat.is_inside(centre): points.append(centre)
			if points.is_empty(): return "There are no rooms to patrol."
			staying = false
			_start("patrol", points[0], {"points": points.slice(1), "rooms": points.size()})
			_say("curious")
		_:
			return "Unknown order."
	return ""

## Small items it can carry: the one you're looking at, else sample jars, else the plush.
func _fetch_choice(placement_id: String) -> Dictionary:
	var found := {}
	for preference in [placement_id, "sample_jars", "zero_g_plush"]:
		for entry in habitat.placed_interior:
			var id := str(entry.get("id", ""))
			var matches: bool = str(entry.get("placement_id", "")) == preference if preference == placement_id else id == preference
			if not matches or preference.is_empty(): continue
			var info := EquipmentCatalog.get_entry(id)
			if str(info.get("group", "")) != "odds_and_ends" or not habitat.items_resting_on(entry).is_empty(): continue
			if not habitat.is_inside(entry.position as Vector3): continue
			return entry
	return found

## A free floor spot right in front of you for something it fetched.
func _spot_by_player(placement_id: String) -> Dictionary:
	var ahead := -target.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > .01 else Vector3.FORWARD
	for distance in [1.0, 1.4, .8, 1.8]:
		for side in [0.0, .6, -.6, 1.0, -1.0]:
			var spot: Vector3 = target.global_position + ahead * distance + ahead.cross(Vector3.UP) * side
			spot.y = habitat.habitat_base_y
			if habitat.is_inside(spot) and habitat.free_interior_move_reason(placement_id, spot, target.rotation.y).is_empty():
				return {"position": spot, "yaw": target.rotation.y}
	return {"position": task_data.get("from", global_position), "yaw": float(task_data.get("from_yaw", 0.0))}

## Outside the nearest airlock's outer hatch, where it waits to be let in.
func _airlock_waiting_spot() -> Vector3:
	var best := Vector3.INF
	for node in get_tree().get_nodes_in_group("airlock_door"):
		var door := node as AirlockDoor
		if door == null or not door._leads_to_environment() or door.door_label() == "HANGAR": continue
		# A couple of metres out from the hatch, on the side away from the habitat.
		for direction in [door.global_transform.basis.z, -door.global_transform.basis.z]:
			var spot: Vector3 = door.global_position + direction * 2.6
			if habitat.is_inside(spot): continue
			spot.y = global_position.y
			if best == Vector3.INF or spot.distance_to(global_position) < best.distance_to(global_position): best = spot
	return best

func _survey_done() -> void:
	surveys_ordered += 1
	MHMissions.bump("gar_y_surveys")

# ---- core sample: drill outside, carry it in, deliver to the Science Lab ----

func _core_here() -> void:
	_busy = true
	_scan_time += 2.0
	await _arm_move("scoop", .9)
	await get_tree().create_timer(1.6).timeout
	if task != "core": return
	await _arm_move("carry", .8)
	has_core = true
	_say("tada")
	_toast("GAR-Y took a core sample", "A tube of layered regolith from below the surface. Bring GAR-Y inside (ping it so it follows you through the airlock) and it'll take the core to the Science Lab.", MHStyle.INFO)
	_end_task()

func _start_core_delivery() -> void:
	var labs: Array = habitat.zones.filter(func(z): return str(z.get("kind", "")) == "science")
	if labs.is_empty():
		if not _told_no_lab: _toast("GAR-Y has a core sample", "There's no Science Lab to take it to yet. It'll keep it safe until there is.", MHStyle.WARN)
		_told_no_lab = true
		return
	var cell: Vector2i = (labs[0].cells as Array)[0]
	var spot := Vector3(cell.x * 3.0, global_position.y, cell.y * 3.0)
	_start("core_deliver", spot)
	_ordered = true

func _core_delivered() -> void:
	_busy = true
	await _arm_move("reach", .8)
	if task != "core_deliver": return
	has_core = false
	habitat.simulation().research_boost_hours = 240.0
	MHMissions.bump("core_sample")
	await _arm_move("stow", .6)
	_say("tada")
	_toast("Core sample delivered", "The Science Lab is studying GAR-Y's core: research +20% for the next 10 sols.", MHStyle.VALID)
	_end_task()

# ---- patrol: every room in turn, then a report ----

func _patrol_next() -> void:
	var left: Array = task_data.get("points", [])
	if not left.is_empty():
		task_goal = left.pop_front()
		task_data.points = left
		_task_age = 0.0
		return
	var alerts := get_tree().get_first_node_in_group("habitat_alerts")
	var active: int = (alerts._active as Dictionary).size() if alerts != null else 0
	_say("happy" if active == 0 else "worried")
	_toast("GAR-Y finished its patrol", "%d room%s checked. %s" % [int(task_data.get("rooms", 0)), "" if int(task_data.get("rooms", 0)) == 1 else "s", "All quiet." if active == 0 else "%d alert%s active: see Mission Control's alert log." % [active, "" if active == 1 else "s"]], MHStyle.VALID if active == 0 else MHStyle.WARN)
	_end_task()

# ---------- look at it (explore HUD) ----------

func interaction_prompt() -> Dictionary:
	return {"label": "%s · %s" % [NAME, status_text()], "primary": "Ping", "info": "About"}

func status_text() -> String:
	if docked: return "charging %d%%" % clampi(roundi(100.0 * fmod(Time.get_ticks_msec() / 90000.0, 1.0)), 5, 99)
	if napping: return "napping"
	match task:
		"survey": return ("finding ice: stop %d of %d" % [int(task_data.stops) - (task_data.hunt as Array).size(), int(task_data.stops)]) if task_data.has("hunt") else "surveying"
		"fetch": return "eyeing your %s" % str(EquipmentCatalog.get_entry(str(task_data.get("id", ""))).get("label", "things")).to_lower()
		"deliver": return "carrying your %s" % str(EquipmentCatalog.get_entry(str(task_data.get("id", ""))).get("label", "things")).to_lower()
		"plush": return "up to something"
		"inspect": return "checking the %s" % str(task_data.get("what", "trouble"))
		"look": return "looking at your new %s" % str(EquipmentCatalog.get_entry(str(task_data.get("id", ""))).get("label", "thing")).to_lower()
		"goto": return "on its way"
		"core": return "taking a core sample"
		"core_deliver": return "taking a core sample to the lab"
		"patrol": return "on patrol"
	if staying: return "staying put" + (" · carrying a core sample" if has_core else "")
	if has_core: return "carrying a core sample"
	if _escorting(): return "coming with you"
	return "worried" if _storm() else FULL_NAME

## A ping: it wakes, chirps and wiggles. Three pings in a row: a spin.
func interact(_actor: Node = null) -> bool:
	if napping: _wake()
	staying = false
	# "Come with me": follow closely for a while (through airlocks you cycle).
	if not task.is_empty(): _end_task(true)
	_escort_until = Time.get_ticks_msec() + ESCORT_MS
	var now := Time.get_ticks_msec()
	_pings = _pings.filter(func(t): return now - int(t) < 4000)
	_pings.append(now)
	if _visual == null: return true
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	if _pings.size() >= 3:
		_pings.clear()
		_say("tada")
		tween.tween_property(_visual, "rotation:y", _visual.rotation.y + TAU, 1.1)
		tween.tween_callback(func() -> void: _visual.rotation.y = 0.0)
	else:
		_say("happy")
		for angle in [.22, -.18, .1, 0.0]: tween.tween_property(_visual, "rotation:y", angle, .09)
	return true

func interact_info(_actor: Node = null) -> bool:
	var tally := "\nIce deposits flagged: %d · Regolith samples: %d" % [ice_found, samples]
	if not rocks.is_empty():
		tally += "\nRock collection (%d of %d): %s" % [rocks.size(), ROCKS.size(), ", ".join(rocks.map(func(i): return str(ROCKS[int(i)][0])))]
	get_tree().call_group("explore_hud", "show_equipment_note", "%s — %s" % [NAME, FULL_NAME], ABOUT + tally)
	return true

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"flags": flags.duplicate(), "ice_found": ice_found, "samples": samples, "has_core": has_core, "rocks": rocks.duplicate(), "ice_samples": ice_samples.duplicate()}

func restore_state(state: Dictionary) -> void:
	flags = (state.get("flags", []) as Array).duplicate()
	ice_found = int(state.get("ice_found", 0))
	samples = int(state.get("samples", 0))
	has_core = bool(state.get("has_core", false))
	rocks = (state.get("rocks", []) as Array).map(func(i): return int(i))
	ice_samples = (state.get("ice_samples", []) as Array).duplicate()
	_rebuild_rocks()
	if not flags.is_empty(): _rebuild_flags()

# ---------- moods, voice, body ----------

func _say(kind: String) -> void:
	var sound := {"happy": "gary_happy", "curious": "gary_curious", "worried": "gary_worried", "sleepy": "gary_sleepy", "tada": "gary_tada"}.get(kind, "rover_chirp") as String
	MHAudio.sfx_at(sound, self, -8.0, .8)
	_mood_override = "happy" if kind == "tada" else kind
	_mood_timer = 3.5 if kind != "sleepy" else 0.0
	_chirp_timer = randf_range(9.0, 16.0)

func _current_mood() -> String:
	if _mood_timer > 0.0: return _mood_override
	if napping: return "sleepy"
	if _storm(): return "worried"
	if not task.is_empty(): return "busy"
	return "curious"

func _apply_mood(delta: float) -> void:
	_mood_timer = maxf(0.0, _mood_timer - delta)
	mood = _current_mood()
	var spec: Array = MOODS.get(mood, MOODS.curious)
	var colour: Color = spec[0]
	var level: float = spec[1]
	if mood == "worried": level *= .55 + .45 * absf(sin(_scan_time * 5.0))
	_eye_material.albedo_color = _eye_material.albedo_color.lerp(colour * level, minf(1.0, delta * 6.0) if delta > 0.0 else 1.0)
	# Blinks; sleepy eyes are half closed, happy ones squint.
	_blink_timer -= delta
	var open := .3 if mood == "sleepy" else (.65 if mood == "happy" else 1.0)
	if _blink_timer < .12: open = .1
	if _blink_timer <= 0.0: _blink_timer = randf_range(2.5, 6.0)
	for eye in _eyes: eye.scale.y = lerpf(eye.scale.y, open, minf(1.0, delta * 18.0) if delta > 0.0 else 1.0)

func _animate(before: Vector3, delta: float) -> void:
	var moved := global_position - before
	moved.y = 0.0
	var roll := moved.length() / wheel_radius
	if moved.dot(-global_transform.basis.z) < 0.0: roll = -roll
	for wheel in _wheels: wheel.rotate_object_local(Vector3.RIGHT, -roll)
	_scan_time += delta * (2.2 if task == "survey" and _busy else 1.0)
	_apply_mood(delta)
	# The head: looks at you when it's near and still, sweeps while surveying,
	# droops when napping.
	if _mast != null and _head != null:
		var pan := sin(_scan_time * .46) * deg_to_rad(18.0) * (1.0 if _idle_time > 1.0 else .35)
		var tilt := sin(_scan_time * .85) * deg_to_rad(6.0)
		if napping:
			pan = 0.0
			tilt = deg_to_rad(-22.0)
		elif task.is_empty() and _idle_time > 1.0 and target.global_position.distance_to(global_position) < 6.0:
			var local := global_transform.affine_inverse() * target.global_position
			pan = clampf(atan2(-local.x, -local.z), -1.2, 1.2) + sin(_scan_time * .5) * .08
			tilt = deg_to_rad(10.0)
		elif task == "survey" and _busy:
			pan = sin(_scan_time * 1.4) * deg_to_rad(40.0)
			tilt = deg_to_rad(-18.0)
		_mast.rotation.y = lerp_angle(_mast.rotation.y, pan, minf(1.0, delta * 4.0))
		_head.rotation.x = lerp_angle(_head.rotation.x, tilt, minf(1.0, delta * 4.0))
	# The torch fades in only in the dark (and off when napping).
	var want := 2.2 if (MHGame.sunlight_fraction < .3 and not napping and not _lit_room()) else 0.0
	_lamp.light_energy = move_toward(_lamp.light_energy, want, delta * 3.0)
	_lamp.visible = _lamp.light_energy > .01

func _set_pose(pose: String, animate := true) -> void:
	if _arm.size() < 3: return
	var angles: Vector3 = POSES.get(pose, POSES.stow)
	for i in 3:
		var value := deg_to_rad(-angles[i])
		if animate: create_tween().set_trans(Tween.TRANS_SINE).tween_property(_arm[i], "rotation:x", value, .6)
		else: _arm[i].rotation.x = value

func _arm_move(pose: String, seconds: float) -> void:
	if _arm.size() < 3:
		await get_tree().process_frame
		return
	var angles: Vector3 = POSES.get(pose, POSES.stow)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for i in 3: tween.tween_property(_arm[i], "rotation:x", deg_to_rad(-angles[i]), seconds)
	await tween.finished

func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() < .05: return
	create_tween().tween_property(self, "rotation:y", rotation.y + wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI), .35)

func _pet_sounds(delta: float) -> void:
	# Quiet while travelling; an occasional chirp once settled (not napping).
	if _idle_time < 2.5 or napping: return
	_chirp_timer -= delta
	if _chirp_timer > 0.0: return
	MHAudio.sfx_at("rover_chirp", self, -14.0, .8)
	_chirp_timer = randf_range(9.0, 16.0)

func _toast(title: String, text: String, tone: Color) -> void:
	var world := get_parent()
	if world != null and world.get("weather") != null: world.weather.toast(title, text, tone)

# ---------- where it is ----------

func _storm() -> bool:
	return habitat != null and float(habitat.simulation().storm_hours_left) > 0.0

func _self_indoors() -> bool:
	return habitat != null and habitat.has_method("is_inside") and habitat.is_inside(global_position)

## Indoors with the room lights on: no torch needed.
func _lit_room() -> bool:
	return _self_indoors() and habitat.grid_power_online()

func _escorting() -> bool:
	return Time.get_ticks_msec() < _escort_until

func _player_indoors() -> bool:
	return habitat != null and habitat.is_inside(target.global_position)

## Where to drive this frame (and how close to stop, in _stop).
func _follow_point() -> Vector3:
	if task_goal != Vector3.INF:
		return _routed(task_goal, TASK_STOP)
	if staying:
		_stop = .4
		return _stay_point if _stay_point != Vector3.INF else global_position
	if _escorting():
		# Close behind you; into an airlock chamber with you, and out the other side.
		_stop = 1.6
		_route.clear()
		return target.global_position + target.global_transform.basis.z * 1.2
	return _home_point() if _self_indoors() else _outdoor_point()

## Indoors: linger in a room pottering, then head somewhere else, sometimes
## to the room you're in.
func _home_point() -> Vector3:
	var delta := get_physics_process_delta_time()
	if _roam_goal == Vector3.INF or not habitat.is_inside(_roam_goal):
		_roam_goal = _pick_room_spot(true)
	var here := Vector2(global_position.x, global_position.z).distance_to(Vector2(_roam_goal.x, _roam_goal.z)) < 1.2
	if here:
		_linger -= delta
		if _linger <= 0.0:
			# Move on: a new room most of the time, or a new spot in this one.
			_roam_goal = _pick_room_spot(randf() < .6)
			_linger = randf_range(15.0, 40.0)
	return _routed(_roam_goal, .9)

## A spot in a habitat room: another room (a third of the time yours), or
## somewhere in the room it's in.
func _pick_room_spot(new_room: bool) -> Vector3:
	var rooms: Array = habitat.zones.filter(func(z): return habitat._is_habitat_zone(z) and str(z.get("kind", "")) != "airlock")
	if rooms.is_empty(): return global_position
	var mine: Dictionary = habitat._zone_at_point(Vector2(global_position.x, global_position.z))
	var room: Dictionary = mine
	if new_room:
		var yours: Dictionary = habitat._zone_at_point(Vector2(target.global_position.x, target.global_position.z)) if _player_indoors() else {}
		room = yours if not yours.is_empty() and str(yours.get("kind", "")) != "airlock" and randf() < .35 else rooms.pick_random()
	if room.is_empty(): room = rooms.pick_random()
	for attempt in 12:
		var cell: Vector2i = (room.cells as Array).pick_random()
		var spot := Vector3(cell.x * 3.0 + randf_range(-.9, .9), global_position.y, cell.y * 3.0 + randf_range(-.9, .9))
		if habitat.is_inside(spot): return spot
	return global_position

## Outdoors: roam near you if you're out here, or near where it is (by the
## airlock) if you've gone inside without it.
func _outdoor_point() -> Vector3:
	_route.clear()
	_stop = 1.0
	var anchor := target.global_position if not _player_indoors() else global_position
	_roam_timer -= get_physics_process_delta_time()
	if _roam_goal == Vector3.INF or _roam_timer <= 0.0 or habitat.is_inside(_roam_goal) or Vector2(_roam_goal.x - anchor.x, _roam_goal.z - anchor.z).length() > 14.0:
		_roam_timer = randf_range(9.0, 20.0)
		for attempt in 10:
			var angle := randf() * TAU
			var spot := anchor + Vector3(cos(angle), 0, sin(angle)) * randf_range(3.5, 9.0)
			spot.y = global_position.y
			if not habitat.is_inside(spot):
				_roam_goal = spot
				break
	if _storm() and not _player_indoors():
		return target.global_position + target.global_transform.basis.x * 2.0   # frets close by in a storm
	return _roam_goal if _roam_goal != Vector3.INF else global_position

# ---------- routes through the habitat's doors ----------

## The next point on the way to dest: through doors it may open, room to room.
func _routed(dest: Vector3, final_stop: float) -> Vector3:
	if habitat == null or not _self_indoors() or not habitat.is_inside(dest):
		_route.clear()
		_stop = final_stop
		return dest
	if _route_dest.distance_to(dest) > .3 or _route.is_empty():
		_route_dest = dest
		_route = _plan_route(dest)
	while _route.size() > 1 and Vector2(global_position.x, global_position.z).distance_to(Vector2((_route[0] as Vector3).x, (_route[0] as Vector3).z)) < .45:
		_route.pop_front()
	_stop = final_stop if _route.size() <= 1 else .3
	return _route[0] if not _route.is_empty() else dest

## Room to room via interior and bay doors (breadth-first over the rooms).
func _plan_route(dest: Vector3) -> Array:
	var from: Dictionary = habitat._zone_at_point(Vector2(global_position.x, global_position.z))
	var to: Dictionary = habitat._zone_at_point(Vector2(dest.x, dest.z))
	if from.is_empty() or to.is_empty() or from == to: return [dest]
	var links := _door_links()
	var came := {habitat.zones.find(from): -1}
	var via := {}
	var queue: Array = [habitat.zones.find(from)]
	var goal: int = habitat.zones.find(to)
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == goal: break
		for link in links:
			for pair in [[link.a, link.b, 1.0], [link.b, link.a, -1.0]]:
				if int(pair[0]) != at or came.has(int(pair[1])): continue
				came[int(pair[1])] = at
				via[int(pair[1])] = [link, float(pair[2])]
				queue.append(int(pair[1]))
	if not came.has(goal): return [dest]
	var points: Array = [dest]
	var step: int = goal
	while int(came[step]) != -1:
		var link: Dictionary = via[step][0]
		var dir: Vector3 = (link.dir as Vector3) * float(via[step][1])
		points.push_front(link.pos + dir * .95)
		points.push_front(link.pos - dir * .95)
		step = int(came[step])
	return points

## Every door GAR-Y may use, with the two rooms it joins.
func _door_links() -> Array:
	var links: Array = []
	for node in get_tree().get_nodes_in_group("airlock_door"):
		var door := node as AirlockDoor
		if door == null or not OWN_DOORS.has(door.door_label()): continue
		var at := door.global_position
		for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			var a: Dictionary = habitat._zone_at_point(Vector2(at.x - axis.x * 1.2, at.z - axis.z * 1.2))
			var b: Dictionary = habitat._zone_at_point(Vector2(at.x + axis.x * 1.2, at.z + axis.z * 1.2))
			if a.is_empty() or b.is_empty() or a == b: continue
			links.append({"a": habitat.zones.find(a), "b": habitat.zones.find(b), "pos": Vector3(at.x, global_position.y, at.z), "dir": axis, "door": door})
			break
	return links

## Opens the interior/bay and partition doors it's driving at, and closes the
## ones it opened once it's through (unless you're in the doorway).
func _manage_doors() -> void:
	if habitat == null or not _self_indoors(): return
	var heading := Vector3(velocity.x, 0, velocity.z)
	var ahead := heading.normalized() if heading.length() > .05 else -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("airlock_door"):
		var door := node as AirlockDoor
		if door == null or not OWN_DOORS.has(door.door_label()) or door.is_open(): continue
		var to := door.global_position - global_position
		to.y = 0.0
		if to.length() < 2.0 and to.normalized().dot(ahead) > .3:
			door.request_open()
			if not _opened.has(door): _opened.append(door)
	for node in get_tree().get_nodes_in_group("partition_door"):
		var to: Vector3 = node.centre() - global_position
		to.y = 0.0
		if not bool(node.open) and to.length() < 1.5 and to.normalized().dot(ahead) > .3:
			node.interact(self)
			if not _opened.has(node): _opened.append(node)
	for door in _opened.duplicate():
		if not is_instance_valid(door):
			_opened.erase(door)
			continue
		var centre: Vector3 = door.centre() if door.has_method("centre") else (door as Node3D).global_position
		if centre.distance_to(global_position) > 2.6 and centre.distance_to(target.global_position) > 2.5:
			if door is AirlockDoor: (door as AirlockDoor).request_shut()
			elif bool(door.open): door.interact()
			_opened.erase(door)

func _spawn_point() -> Vector3:
	var point := target.global_position + target.global_transform.basis.z * 2.4
	if _player_indoors():
		# You're inside: it waits outside by the nearest outer airlock door.
		for node in get_tree().get_nodes_in_group("airlock_door"):
			var door := node as AirlockDoor
			if door == null or door.door_label() != "OUTER": continue
			for offset in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
				if not habitat.is_inside(door.global_position + offset):
					point = door.global_position + offset
					break
			break
	point.y = target.global_position.y + .15
	return point

func _try_step_over_threshold(flat_delta: Vector3) -> void:
	# Airlock and deck thresholds can read as walls to a character collider. A
	# short, capped lift lets the rover roll over them; floor snapping settles it.
	if not is_on_wall() or flat_delta.length_squared() < .04:
		return
	var raised := global_position + Vector3.UP * step_height
	if not test_move(Transform3D(global_transform.basis, raised), flat_delta.normalized() * .26):
		global_position = raised
		velocity.y = 0.0
