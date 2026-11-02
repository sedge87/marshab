extends Node

## Step 5's field kit (docs/samples-lab-journal.md §3–4): the scoop, rock
## chips and the six-slot sample case, with the hand corer from step 4.
## Outside, with nothing else in view:
##   - aim at a rock and hold E: chip a sample (one per rock);
##   - look down at the ground and hold E: scoop regolith;
##   - on surveyed ground the hand corer has E instead (hand_corer.gd);
##   - in a cave, aim at the wall and hold E: chip it (one per 3 m of wall),
##     or cut ice in the ice cave and at the lava tube's ice; the suit logs
##     its readings at the tube's reading spot by itself (cave_climate).
## The case shows as six pips at the visor's bottom edge; I gives its line,
## holding I leaves the last sample behind. Back at base, E on a Science
## Workbench or the Sample Storage Cabinet unloads the case, and E on a
## workbench opens the lab.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CHIP_SECONDS := 1.6
const SCOOP_SECONDS := 1.2
const REACH_M := 3.0
## Looking down this far (radians below level) means you're looking at the ground at your feet.
const LOOK_DOWN := -.55
const KEEP_CLEAR_M := 8.0
const CUT_SECONDS := 2.2
const CAVE_CELL := 3.0   # metres of cave wall one chip uses up
const PIP_COLOURS := {"regolith": Color("#B58A62"), "rock": Color("#8C8A88"), "ice_core": Color("#8CC3CB")}

var world: Node
var _held := 0.0
var _info_held := 0.0
var _ring: Control
var _pips: Control
var _rocks: Array = []
var _reading_check := 0.0
const AIR_READING_M := 150.0

func setup(target_world: Node) -> Node:
	world = target_world
	return self

func _ready() -> void:
	add_to_group("sample_tools")
	add_to_group("interaction_claims")
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.offset_left = -40; _ring.offset_top = -40; _ring.offset_right = 40; _ring.offset_bottom = 40
	_ring.visible = false
	_ring.draw.connect(_draw_ring)
	world.overlay_layer.add_child(_ring)
	_pips = Control.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.anchor_left = .5; _pips.anchor_right = .5; _pips.anchor_top = 1; _pips.anchor_bottom = 1
	_pips.offset_left = -66; _pips.offset_right = 66; _pips.offset_top = -112; _pips.offset_bottom = -98
	_pips.draw.connect(_draw_pips)
	world.overlay_layer.add_child(_pips)
	for placement in MHSiteTerrain.rock_placements():
		_rocks.append([Vector2(placement.position.x, placement.position.z), float(placement.get("scale", 1.0))])

# ---------- where a sample could come from ----------

func _outside_free() -> bool:
	if not MHSamples.on() or not MHChapterOne.has_corer: return false
	var player: Node3D = world.player
	if player == null or bool(player.get_meta("driving", false)) or player._any_build_mode_active(): return false
	if world.builder.is_inside(player.global_position) or world.lander.cabin_contains(player.global_position): return false
	if world.explore_hud != null and world.explore_hud.call("_looked_at_interactable") != null: return false
	var corer: Node = world.hand_corer
	return corer == null or str(corer.call("prompt")).is_empty()

## The rock you're aiming at: {point (Vector3), key, cave} or {}. In a cave,
## any wall or rock you aim at; outside, the site's rock props.
func _rock_target() -> Dictionary:
	var camera := world.player.get_node("Head/Camera3D") as Camera3D
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * REACH_M)
	query.exclude = [world.player.get_rid()]
	var hit: Dictionary = world.player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return {}
	var cave := MHCaves.cave_at(world.player.global_position)
	if not cave.is_empty():
		# Not the floor at your feet: that's for the scoop.
		if (hit.normal as Vector3).y > .7: return {}
		var p: Vector3 = hit.position
		return {"point": p, "key": "%s:%d,%d" % [cave.id, roundi(p.x / CAVE_CELL), roundi(p.z / CAVE_CELL)], "cave": cave}
	var at := Vector2(hit.position.x, hit.position.z)
	var best: Array = []
	var best_gap := INF
	for rock in _rocks:
		var gap := (rock[0] as Vector2).distance_to(at)
		if gap < float(rock[1]) * 1.3 + .4 and gap < best_gap: best = rock; best_gap = gap
	if best.is_empty(): return {}
	var point: Vector2 = best[0]
	return {"point": Vector3(point.x, MHSiteTerrain.height(point.x, point.y), point.y), "key": MHSamples.rock_key(point), "cave": {}}

## Whether a cave wall here is ice: the ice cave, or the ice at the lava tube's far end.
func _ice_wall(target: Dictionary) -> bool:
	if (target.cave as Dictionary).is_empty(): return false
	return str(target.cave.kind) == "ice_cave" or MHSamples.find_near(target.point) == "cave_ice"

## Ground at your feet when you look down: a point, or INF.
func _scoop_target() -> Vector3:
	var player: Node3D = world.player
	if (player.get_node("Head") as Node3D).rotation.x > LOOK_DOWN: return Vector3.INF
	var at := player.global_position - player.global_transform.basis.z * .9
	for node in [world.lander] + (world.cargo_landers as Array):
		if node != null and Vector2(node.global_position.x - at.x, node.global_position.z - at.z).length() < KEEP_CLEAR_M: return Vector3.INF
	if not world.builder.zones.is_empty() and world.builder.call("_zone_at_point", Vector2(at.x, at.z)).size() > 0: return Vector3.INF
	return at

## What E would do now: "chip", "cut" (cave ice), "chipped", "scoop" or "".
func prompt() -> String:
	if not _outside_free(): return ""
	var rock := _rock_target()
	if not rock.is_empty():
		if MHSamples.chipped.has(str(rock.key)): return "chipped"
		return "cut" if _ice_wall(rock) else "chip"
	return "scoop" if _scoop_target() != Vector3.INF else ""

func prompt_text() -> String:
	match prompt():
		"chip": return "Hold to chip a rock sample"
		"cut": return "Hold to cut an ice sample"
		"chipped": return "Already sampled"
		"scoop": return "Hold to scoop regolith"
	return ""

# ---------- holding E and I ----------

func _process(delta: float) -> void:
	# Out on the ground with the corer: the case's visor pips (Classic HUD; the
	# wrist pad shows the count either way), the air reading and the I key.
	var out_here: bool = MHSamples.on() and MHChapterOne.has_corer and world.player != null and not world.builder.is_inside(world.player.global_position) and not bool(world.lander.cabin_contains(world.player.global_position)) and world.explore_hud != null and world.explore_hud.visible
	_pips.visible = out_here and MHGame.classic_hud()
	_pips.queue_redraw()
	var mode := prompt()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused
	var holding := captured and Input.is_physical_key_pressed(KEY_E) and mode in ["chip", "cut", "scoop"]
	_held = _held + delta if holding else 0.0
	var need: float = {"chip": CHIP_SECONDS, "cut": CUT_SECONDS}.get(mode, SCOOP_SECONDS)
	_ring.visible = _held > .15
	_ring.set_meta("fraction", clampf(_held / need, 0.0, 1.0))
	_ring.queue_redraw()
	if _held >= need:
		_held = 0.0
		_ring.visible = false
		_take(mode)
	# The suit logs its readings at a cave's reading spot.
	_reading_check -= delta
	if _reading_check <= 0.0 and MHSamples.on() and world.player != null:
		_reading_check = 1.0
		var daylight := MHGame.sun_altitude(MHGame.sol_hour) > 0.0
		if MHSamples.find_near(world.player.global_position) == "cave_climate":
			world.call("show_chapter_messages", MHSamples.log_reading("cave_climate", daylight, _now()))
		# The air (mars_air): logged by day and by night, away from the base's own exhaust.
		elif out_here and world.player.global_position.distance_to(world.lander.global_position) > AIR_READING_M:
			world.call("show_chapter_messages", MHSamples.log_reading("mars_air", daylight, _now()))
	# I: the case's line; hold I: leave the last sample behind.
	var info := captured and out_here and Input.is_physical_key_pressed(KEY_I) and world.explore_hud.call("_looked_at_interactable") == null
	if info:
		if _info_held == 0.0: world.explore_hud.call("show_equipment_note", "Sample case", MHSamples.case_line())
		_info_held += delta
		if _info_held >= 1.0 and _info_held - delta < 1.0: world.call("show_chapter_messages", [MHSamples.drop_last()].filter(func(m): return not m.is_empty()))
	else:
		_info_held = 0.0

func _now() -> float:
	return float(world.builder.simulation().hours_run)

func _take(mode: String) -> void:
	var message := {}
	if mode == "chip" or mode == "cut":
		var rock := _rock_target()
		if rock.is_empty(): return
		var point: Vector3 = rock.point
		var extra := _cave_extra(rock.cave)
		if mode == "cut": extra.merge({"depth_m": 0.0, "purity": .9})
		else: extra["rock"] = MHSamples.rock_at(point)
		message = MHSamples.take("ice_core" if mode == "cut" else "rock", Vector2(point.x, point.z), _now(), extra)
		if str(message.id) == "sample": MHSamples.chipped[str(rock.key)] = true
	else:
		var at := _scoop_target()
		if at == Vector3.INF: return
		message = MHSamples.take("regolith", Vector2(at.x, at.z), _now(), _cave_extra(MHCaves.cave_at(world.player.global_position)))
	MHAudio.sfx("ui_click")
	world.call("show_chapter_messages", [message])

## A sample from inside a cave is labelled with the cave's own ground.
func _cave_extra(cave: Dictionary) -> Dictionary:
	return {} if cave.is_empty() else {"unit": str(cave.kind), "in_cave": true}

## A good or thin core goes in the case too, if there's room (hand_corer.gd).
func keep_core(core: Dictionary) -> Array:
	if bool(core.get("dry", true)) or MHSamples.case_full(): return []
	return [MHSamples.take("ice_core", Vector2(float(core.x), float(core.z)), _now(), {"depth_m": float(core.depth_m), "purity": float(core.purity)})]

func _draw_ring() -> void:
	var c := Vector2(40, 40)
	_ring.draw_arc(c, 30.0, 0.0, TAU, 48, Color(1, 1, 1, .25), 5.0, true)
	_ring.draw_arc(c, 30.0, -PI * .5, -PI * .5 + TAU * float(_ring.get_meta("fraction", 0.0)), 48, MHStyle.accent, 5.0, true)

func _draw_pips() -> void:
	for i in MHSamples.CASE_SLOTS:
		var rect := Rect2(Vector2(i * 22.0, 0.0), Vector2(16, 14))
		if i < MHSamples.case_items.size():
			_pips.draw_rect(rect, PIP_COLOURS.get(str(MHSamples.case_items[i].kind), Color.WHITE))
		else:
			_pips.draw_rect(rect, Color(1, 1, 1, .35), false, 1.5)

# ---------- at base: unload, open the lab ----------

func _equipment(target: Node) -> Array:
	var node := target
	while node != null:
		if node.has_meta("interior_placement_id"): return [str(node.get_meta("equipment_id", "")), str(node.get_meta("interior_placement_id"))]
		node = node.get_parent()
	return [str(target.get("equipment_id")) if target != null else "", ""]

func claim_label(target: Node) -> String:
	if not MHSamples.on() or target == null: return ""
	var id: String = _equipment(target)[0]
	if id in ["science_workbench", "sample_storage_cabinet"] and not MHSamples.case_items.is_empty(): return "Unload the sample case (%d)" % MHSamples.case_items.size()
	if id == "science_workbench": return "Open the lab"
	return ""

func claim(target: Node, method_name: String) -> bool:
	if method_name != "interact" or claim_label(target).is_empty(): return false
	var found := _equipment(target)
	MHAudio.sfx("ui_click")
	if not MHSamples.case_items.is_empty():
		var count := MHSamples.unload()
		world.call("show_chapter_messages", [{"id": "unloaded", "title": "Sample case unloaded", "text": "%d sample%s in the lab's store. Analyse them at a Science Workbench." % [count, "" if count == 1 else "s"], "tone": "valid"}])
		return true
	world.call("open_lab", str(found[1]))
	return true
