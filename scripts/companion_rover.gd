class_name MHCompanionRover
extends CharacterBody3D

## GAR-Y, the Geological Analysis Rover, Y-Class: the crew's companion.
##
## A small routine with a personality:
## - Outdoors by day it scouts near you and now and then wanders off to
##   survey: it scans the ground, plants a flag where there's buried ice, or
##   scoops a regolith sample.
## - Indoors it potters about. Very rarely it picks up one of your odds and
##   ends from the floor and puts it down somewhere else in the room, nudges
##   the plush to make it squeak, or worries out loud when the grid is down.
## - At night it naps (or docks on a rover charger in its room); during a
##   dust storm it huddles close.
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
const MISCHIEF_EVERY := Vector2(1200.0, 1800.0)
const PLUSH_EVERY := Vector2(500.0, 900.0)
const WORRY_EVERY := Vector2(240.0, 420.0)
const NAP_AFTER := 25.0
const TASK_STOP := .75
const MAX_FLAGS := 12

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
var flags: Array = []          # flag positions (Vector3), saved
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

# ---- movement (as before) ----
var _roam_goal := Vector3.INF
var _roam_timer := 0.0
var _stuck_timer := 0.0
var _idle_time := 0.0
var _scan_time := 0.0
var _wander_phase := 0.0
var _scout_anchor := Vector3.ZERO
var _anchor_player_position := Vector3.ZERO
var _has_scout_anchor := false
var _chirp_timer := 0.0

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
	if building:
		if not task.is_empty(): _end_task(true)
		velocity = Vector3.ZERO
		return
	_think(delta)
	var desired := global_position if (_busy or napping) else _follow_point()
	var stop := TASK_STOP if task_goal != Vector3.INF else stop_distance
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
			if not task.is_empty(): _end_task(true)
			elif _roam_goal != Vector3.INF: _roam_goal = _pick_roam_goal()
	_animate(before, delta)
	_pet_sounds(delta)
	# Stranded far away (and not off on an errand): respawn behind the player.
	var leash := catch_up_distance * (2.6 if not task.is_empty() else 1.0)
	if global_position.distance_to(target.global_position) > leash:
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
		if not dark or target.global_position.distance_to(global_position) > 7.0:
			_wake()
	elif task.is_empty() and dark and _idle_time > NAP_AFTER:
		if indoors and autonomy and _start_charge(): pass
		else: _nap()
	if not autonomy or napping or not task.is_empty() or _busy:
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
		if _plush_timer <= 0.0:
			_plush_timer = randf_range(PLUSH_EVERY.x, PLUSH_EVERY.y)
			start_plush()
		elif _mischief_timer <= 0.0:
			_mischief_timer = randf_range(MISCHIEF_EVERY.x, MISCHIEF_EVERY.y)
			start_fetch()
	elif not storm and not dark:
		_survey_timer -= delta
		if _survey_timer <= 0.0:
			_survey_timer = randf_range(SURVEY_EVERY.x, SURVEY_EVERY.y)
			start_survey()

func task_age_limit() -> float:
	return 40.0 if not task.is_empty() else 0.0

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
	task = ""
	task_goal = Vector3.INF
	task_data = {}
	_busy = false
	if not docked: _set_pose("stow")

func _arrived() -> void:
	match task:
		"survey": _survey_here()
		"fetch": _pick_up()
		"deliver": _deliver()
		"plush": _nudge_plush()
		"charge": _dock()

# ---- survey: scan, then flag ice or scoop a sample ----

func start_survey() -> bool:
	if habitat == null: return false
	for attempt in 8:
		var angle := randf() * TAU
		var spot := target.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(7.0, 12.0)
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
	if richness >= .25 and not near_flag:
		await _arm_move("reach", .7)
		_plant_flag(global_position + -global_transform.basis.z * .9)
		await _arm_move("stow", .6)
		ice_found += 1
		_say("tada")
		_toast("GAR-Y found buried ice", "About %d%% ice under the flag it just planted. An ice extractor there would do well." % roundi(richness * 100.0), MHStyle.INFO)
	else:
		await _arm_move("scoop", .8)
		await get_tree().create_timer(.4).timeout
		await _arm_move("stow", .7)
		samples += 1
		_say("happy")
		if samples == 1 or samples % 5 == 0:
			_toast("GAR-Y scooped a sample", "Regolith samples collected so far: %d. No buried ice here." % samples, MHStyle.INFO)
	_end_task()

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
		if at.y > habitat.habitat_base_y + .2 or not habitat.items_resting_on(item).is_empty(): continue
		if habitat._zone_at_point(Vector2(at.x, at.z)) != room or at.distance_to(global_position) > 9.0: continue
		found.append(item)
	return found

func start_fetch() -> bool:
	var choices := _clutter_candidates()
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
	var spot := _new_spot(str(task_data.placement_id), task_data.from as Vector3)
	task_data.to = spot.position
	task_data.to_yaw = spot.yaw
	task = "deliver"
	task_goal = (spot.position as Vector3) + (global_position - (spot.position as Vector3)).normalized() * .5
	_task_age = 0.0
	_busy = false

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
	if moved and (task_data.to as Vector3).distance_to(task_data.from as Vector3) > .5:
		_say("tada")
		_toast("GAR-Y moved your %s" % str(EquipmentCatalog.get_entry(str(task_data.id)).get("label", "things")).to_lower(), "It's somewhere else in the room now. GAR-Y seems very pleased with itself.", MHStyle.INFO)
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

# ---- night: dock on a charger in the room, or nap ----

func _start_charge() -> bool:
	if habitat == null: return false
	var room: Dictionary = habitat._zone_at_point(Vector2(global_position.x, global_position.z))
	for item in habitat.placed_interior:
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if str(item.get("id", "")) != "rover_charger" or habitat._zone_at_point(Vector2(at.x, at.z)) != room: continue
		var yaw := float(item.get("rotation_y", 0.0))
		var front := Vector3(-sin(yaw), 0, -cos(yaw))
		_start("charge", at + front * .9, {"at": at})
		return true
	return false

func _dock() -> void:
	_face(task_data.at as Vector3)
	docked = true
	task = ""
	task_goal = Vector3.INF
	_nap()

func _nap() -> void:
	napping = true
	_say("sleepy")
	_set_pose("stow")

func _wake() -> void:
	napping = false
	docked = false
	_idle_time = 0.0

# ---------- look at it (explore HUD) ----------

func interaction_prompt() -> Dictionary:
	return {"label": "%s · %s" % [NAME, status_text()], "primary": "Ping", "info": "About"}

func status_text() -> String:
	if docked: return "charging %d%%" % clampi(roundi(100.0 * fmod(Time.get_ticks_msec() / 90000.0, 1.0)), 5, 99)
	if napping: return "napping"
	match task:
		"survey": return "surveying"
		"fetch": return "eyeing your %s" % str(EquipmentCatalog.get_entry(str(task_data.get("id", ""))).get("label", "things")).to_lower()
		"deliver": return "carrying your %s" % str(EquipmentCatalog.get_entry(str(task_data.get("id", ""))).get("label", "things")).to_lower()
		"plush": return "up to something"
	return "worried" if _storm() else FULL_NAME

## A ping: it wakes, chirps and wiggles. Three pings in a row: a spin.
func interact(_actor: Node = null) -> bool:
	if napping: _wake()
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
	get_tree().call_group("explore_hud", "show_equipment_note", "%s — %s" % [NAME, FULL_NAME], ABOUT + tally)
	return true

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"flags": flags.duplicate(), "ice_found": ice_found, "samples": samples}

func restore_state(state: Dictionary) -> void:
	flags = (state.get("flags", []) as Array).duplicate()
	ice_found = int(state.get("ice_found", 0))
	samples = int(state.get("samples", 0))
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

func _indoors() -> bool:
	return habitat != null and habitat.has_method("is_inside") and habitat.is_inside(target.global_position) and habitat.is_inside(global_position)

func _follow_point() -> Vector3:
	if task_goal != Vector3.INF: return task_goal
	if _indoors():
		_roam_timer -= get_physics_process_delta_time()
		if _roam_goal == Vector3.INF or _roam_timer <= 0.0:
			_roam_goal = _pick_roam_goal()
			_roam_timer = randf_range(7.0, 14.0)
		if _roam_goal != Vector3.INF: return _roam_goal
	else:
		_roam_goal = Vector3.INF
	# Commit to a scouting spot until the astronaut actually moves on. In a
	# storm it huddles closer.
	if not _has_scout_anchor or target.global_position.distance_to(_anchor_player_position) > 2.5:
		_anchor_player_position = target.global_position
		_scout_anchor = _choose_scout_anchor()
		_has_scout_anchor = true
	var patrol := Vector3.ZERO
	if _idle_time > 1.0 and not _storm():
		patrol.x = sin(_scan_time * .31 + _wander_phase) * .55
		patrol.z = sin(_scan_time * .54 + _wander_phase) * .35
	return _scout_anchor + patrol

## Somewhere in a habitat room near the player: a random room cell centre.
func _pick_roam_goal() -> Vector3:
	var spots: Array = []
	for zone in habitat.zones:
		if not habitat._is_habitat_zone(zone): continue
		for cell in zone.get("cells", []):
			var spot := Vector3(cell.x * 3.0, global_position.y, cell.y * 3.0)
			if spot.distance_to(target.global_position) < 9.0 and spot.distance_to(global_position) > 1.5 and habitat.is_inside(spot): spots.append(spot)
	return spots.pick_random() if not spots.is_empty() else Vector3.INF

func _choose_scout_anchor() -> Vector3:
	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < .001: forward = Vector3.FORWARD
	var side := target.global_transform.basis.x
	side.y = 0.0
	if side.length_squared() < .001: side = Vector3.RIGHT
	var reach := 2.2 if _storm() else follow_distance
	return target.global_position + forward.normalized() * 1.5 + side.normalized() * reach

func _spawn_point() -> Vector3:
	var point := _follow_point() if task.is_empty() else target.global_position + target.global_transform.basis.z * 2.4
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
