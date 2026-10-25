extends Node

## Picking up small things and putting them down elsewhere (Batch C). Anything
## that can sit on a shelf (catalogue "stackable": odds and ends, the plush,
## GAR-y, sample jars) can be carried: E picks it up (hold E when E already
## does something to it, like squeezing the plush). While carrying, a ghost
## shows where it would go (green if it fits, red if not): click or E puts it
## down there, on a floor, table, shelf or bunk; Q puts it back where it was.
## Going into build mode or saving puts it back first. Big furniture still
## moves in build mode.

const MHPlacementGhost := preload("res://scripts/placement_ghost.gd")
const HOLD_SECONDS := .45
const REACH := 4.0

var world: Node
var carrying := {}             # the record as it was: id, position, rotation_y, zone_cell, state
var _ghost: Node3D
var _point := Vector3.INF
var _normal := Vector3.UP
var _valid := false
var _hold := 0.0
var _e_was_down := false
var _hold_target := ""
## After putting something down with E, E has to come up again before it
## can pick anything up (or the same press grabbed it straight back).
var _wait_for_release := false

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("carry")

func builder() -> Node:
	return world.builder

func _camera() -> Camera3D:
	return world.player.get_node_or_null("Head/Camera3D") as Camera3D

## The placed small item a node belongs to ("" if it isn't one).
func pickable_id(node: Node) -> String:
	while node != null and not node.has_meta("interior_placement_id"): node = node.get_parent()
	if node == null: return ""
	var placement := str(node.get_meta("interior_placement_id"))
	for item in builder().placed_interior:
		if str(item.get("placement_id", "")) == placement:
			return placement if bool(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("stackable", false)) else ""
	return ""

## For the explore HUD's prompt: "E" or "Hold E" to pick this up, or "".
func pickup_key(target: Node) -> String:
	if not carrying.is_empty() or target == null or pickable_id(target).is_empty(): return ""
	return "Hold E" if _has_primary(target) else "E"

func _has_primary(target: Node) -> bool:
	return target.has_method("interaction_prompt") and not str((target.call("interaction_prompt") as Dictionary).get("primary", "")).is_empty()

func _looked_at() -> Node:
	var hud := get_tree().get_first_node_in_group("explore_hud")
	return hud.call("_looked_at_interactable") if hud != null and hud.has_method("_looked_at_interactable") else null

func _busy_elsewhere() -> bool:
	var player: Node = world.player
	return bool(player.get_meta("build_mode_active", false)) or bool(player.get_meta("interior_build_active", false)) or bool(player.get_meta("surface_build_active", false)) or bool(player.get_meta("ui_freeze", false)) or get_tree().paused

# ---------- each frame ----------

func _process(delta: float) -> void:
	var e_down := Input.is_physical_key_pressed(KEY_E)
	if not carrying.is_empty():
		if _busy_elsewhere():
			put_back()
		else:
			_update_ghost()
		_e_was_down = e_down
		return
	if _busy_elsewhere():
		_hold = 0.0
		_e_was_down = e_down
		return
	if _wait_for_release:
		if not e_down: _wait_for_release = false
		_hold = 0.0
		_e_was_down = e_down
		return
	# Not carrying: E (or holding E) on a small item picks it up.
	var target := _looked_at() if e_down else null
	var placement := pickable_id(target) if target != null else ""
	if placement.is_empty():
		_hold = 0.0
		_hold_target = ""
	elif e_down and not _e_was_down and not _has_primary(target):
		pick_up(placement)
	elif e_down:
		if placement != _hold_target:
			_hold_target = placement
			_hold = 0.0
		_hold += delta
		if _hold >= HOLD_SECONDS: pick_up(placement)
	_e_was_down = e_down

func _unhandled_input(event: InputEvent) -> void:
	if carrying.is_empty() or _busy_elsewhere(): return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo and key.keycode == KEY_Q:
		get_viewport().set_input_as_handled()
		put_back()
	elif (key != null and key.pressed and not key.echo and key.keycode == KEY_E) or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if put_down(): _wait_for_release = true

# ---------- picking up and putting down ----------

func pick_up(placement_id: String) -> bool:
	var record := {}
	for item in builder().placed_interior:
		if str(item.get("placement_id", "")) == placement_id: record = (item as Dictionary).duplicate(true)
	if record.is_empty(): return false
	builder().remove_free_interior_equipment(placement_id)
	carrying = record
	preload("res://scripts/feature_hints.gd").first(get_tree(), "carrying")
	_hold = 0.0
	_e_was_down = true   # this press doesn't also put it down
	var label := str(EquipmentCatalog.get_entry(str(record.id)).get("label", record.id))
	_ghost = builder().free_interior_visual(str(record.id), record.get("position", Vector3.ZERO) as Vector3, float(record.get("rotation_y", 0.0)))
	for child in _ghost.find_children("*", "", true, false):
		if child.get_script() != null: child.set_script(null)
	for body in _ghost.find_children("*", "StaticBody3D", true, false): (body as StaticBody3D).collision_layer = 0
	for shape in _ghost.find_children("*", "CollisionShape3D", true, false): (shape as CollisionShape3D).disabled = true
	for light in _ghost.find_children("*", "Light3D", true, false): (light as Light3D).visible = false
	world.add_child(_ghost)
	MHAudio.sfx("ui_click", -4.0)
	get_tree().call_group("explore_hud", "show_equipment_note", "Carrying: %s" % label, "Click or press E to put it down where the ghost is green. Q puts it back where it was.")
	return true

func _update_ghost() -> void:
	var camera := _camera()
	if camera == null or _ghost == null: return
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * REACH)
	query.exclude = [(world.player as CollisionObject3D).get_rid()]
	query.collision_mask = 1
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	_point = Vector3.INF
	if not hit.is_empty():
		var on_top := _top_of(hit, camera)
		if on_top != Vector3.INF:
			_point = on_top
			_normal = Vector3.UP
		elif (hit.normal as Vector3).y > .7:
			_point = hit.position
			_normal = Vector3.UP
	_ghost.visible = _point != Vector3.INF
	if not _ghost.visible:
		_valid = false
		return
	var yaw := _yaw()
	_valid = builder().free_interior_invalid_reason(str(carrying.id), _point, _normal, yaw).is_empty()
	_ghost.global_position = _point + Vector3.UP * .012
	_ghost.rotation.y = yaw
	MHPlacementGhost.apply(_ghost, _valid)

## Facing the player, like placing it in build mode.
func _yaw() -> float:
	return float(world.player.rotation.y) + PI + float(EquipmentCatalog.get_entry(str(carrying.id)).get("model_rotation_y", 0.0))

## Aiming at a table, shelf, bunk or crate: the spot on its top under the
## crosshair (as interior build does), or Vector3.INF.
func _top_of(hit: Dictionary, camera: Camera3D) -> Vector3:
	var node := hit.get("collider") as Node
	while node != null and not node.has_meta("interior_placement_id"): node = node.get_parent()
	if node == null: return Vector3.INF
	var direction := -camera.global_transform.basis.z
	if direction.y > -.05: return Vector3.INF
	for item in builder().placed_interior:
		if str(item.get("placement_id", "")) != str(node.get_meta("interior_placement_id")): continue
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var best := Vector3.INF
		var nearest := INF
		for top in builder().surface_tops(entry):
			var t := (at.y + float(top) - camera.global_position.y) / direction.y
			var spot := camera.global_position + direction * t
			if t > 0.0 and t < nearest and builder()._rests_within(spot, Vector3(.02, 0, .02), 0.0, at, builder()._surface_size(entry), float(item.get("rotation_y", 0.0))):
				nearest = t
				best = spot
		return best
	return Vector3.INF

func put_down() -> bool:
	if carrying.is_empty(): return false
	if _point == Vector3.INF or not _valid:
		MHAudio.sfx("invalid")
		return false
	return _place(_point, _yaw(), _normal)

## Back where it came from.
func put_back() -> bool:
	if carrying.is_empty(): return false
	var placed := _place(carrying.get("position", Vector3.ZERO) as Vector3, float(carrying.get("rotation_y", 0.0)), Vector3.UP, true)
	return placed

func _place(at: Vector3, yaw: float, normal: Vector3, original := false) -> bool:
	var id := str(carrying.id)
	var cell := Vector2i(roundi(at.x / BuildController.CELL), roundi(at.z / BuildController.CELL))
	if original: cell = carrying.get("zone_cell", cell) as Vector2i
	get_tree().call_group("explore_hud", "hide_equipment_note", "Carrying")
	var visual: Node3D = builder().free_interior_visual(id, at, yaw)
	if not builder().place_free_interior_equipment(id, at, yaw, cell, visual, normal):
		visual.queue_free()
		if not original:
			MHAudio.sfx("invalid")
			return false
		# Its old spot is taken now: put the record straight back.
		builder().placed_interior.append(carrying.duplicate(true))
		builder()._rebuild()
	else:
		# Keep its switches (a lamp on, a drawer open).
		var record: Dictionary = builder().placed_interior[builder().placed_interior.size() - 1]
		record["state"] = (carrying.get("state", {}) as Dictionary).duplicate(true)
	carrying = {}
	if _ghost != null: _ghost.queue_free()
	_ghost = null
	MHAudio.sfx("place", -4.0)
	return true
