class_name MHSurfaceBuildController
extends Node
const MHPlacementGhost := preload("res://scripts/placement_ghost.gd")

## First-person free placement for non-structural outdoor props.  This does
## not alter the plan-grid reactor, ice extractor, habitat shell or airlocks.

const BUILD_RANGE := 7.5

var builder: BuildController
var player: CharacterBody3D
var active := false
var selected_id := ""
var rotation_offset := 0.0
## Hold R to keep turning (a tap still turns 15°); Shift+R turns the other way.
const HOLD_DELAY := .25
const HOLD_SPEED := deg_to_rad(120.0)
var _r_held := 0.0
var preview: Node3D
var _hit := {}
var _valid_reason := "Look at outdoor ground"
var _hud: CanvasLayer
var _selection: Label
var _status: Label
var _valid_visual := true

func setup(target_player: CharacterBody3D, target_builder: BuildController) -> void:
	player = target_player
	builder = target_builder

func enter(id: String) -> void:
	if active or builder == null or player == null or builder.surface_entry(id).is_empty():
		return
	active = true
	selected_id = id
	rotation_offset = 0.0
	player.set_meta("surface_build_active", true)
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MHAudio.sfx("mode_build", -2.0, 0.0)
	MHAudio.build_layer(true)
	_refresh_preview(true)

func exit() -> void:
	if not active:
		return
	active = false
	player.set_meta("surface_build_active", false)
	if preview != null:
		preview.queue_free()
		preview = null
	if _hud != null:
		_hud.queue_free()
		_hud = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MHAudio.sfx("mode_explore", -2.0, 0.0)
	MHAudio.build_layer(false)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
			exit()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			rotation_offset = wrapf(rotation_offset + (-PI if event.shift_pressed else PI) / 12.0, -PI, PI)
			_refresh_preview(true)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_X or event.keycode == KEY_DELETE:
			_remove_target()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place_preview()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rotation_offset = wrapf(rotation_offset + (PI / 24.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -PI / 24.0), -PI, PI)
			_refresh_preview(true)

func _process(delta: float) -> void:
	if active:
		_hold_rotate(delta)
		_refresh_preview(false)

## While R is held past HOLD_DELAY the item turns smoothly.
func _hold_rotate(delta: float) -> bool:
	if not Input.is_physical_key_pressed(KEY_R):
		_r_held = 0.0
		return false
	_r_held += delta
	if _r_held < HOLD_DELAY: return false
	var direction := -1.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	rotation_offset = wrapf(rotation_offset + HOLD_SPEED * delta * direction, -PI, PI)
	return true

func _raycast() -> Dictionary:
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null or not camera.is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z * BUILD_RANGE)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _refresh_preview(force_rebuild: bool) -> void:
	_hit = _raycast()
	if _hit.is_empty() or float((_hit.get("normal", Vector3.UP) as Vector3).y) < .72:
		_valid_reason = "Look at level outdoor ground"
		if preview != null: preview.visible = false
		_update_hud()
		return
	var point: Vector3 = _hit.position
	_valid_reason = builder.surface_invalid_reason(selected_id, point)
	if force_rebuild or preview == null:
		if preview != null: preview.queue_free()
		preview = builder.surface_visual(selected_id, point, player.rotation.y + rotation_offset)
		preview.name = "SurfaceBuildPreview"
		add_child(preview)
		for body in preview.find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = 0
		for shape in preview.find_children("*", "CollisionShape3D", true, false):
			(shape as CollisionShape3D).disabled = true
		_set_preview(preview, _valid_reason.is_empty())
		_valid_visual = _valid_reason.is_empty()
	else:
		preview.global_position = point + Vector3.UP * .01
		preview.rotation.y = player.rotation.y + rotation_offset
		if _valid_visual != _valid_reason.is_empty():
			_set_preview(preview, _valid_reason.is_empty())
			_valid_visual = _valid_reason.is_empty()
	preview.visible = true
	_update_hud()

func _set_preview(node: Node, valid: bool) -> void:
	MHPlacementGhost.apply(node, valid)

func _place_preview() -> void:
	if preview == null or not _valid_reason.is_empty() or _hit.is_empty():
		if not _valid_reason.is_empty(): MHAudio.sfx("invalid")
		return
	var final_visual := builder.surface_visual(selected_id, preview.global_position, preview.rotation.y)
	if builder.place_surface_equipment(selected_id, preview.global_position, preview.rotation.y, final_visual):
		MHAudio.sfx("place")
		_refresh_preview(true)
	else:
		final_visual.queue_free()
		MHAudio.sfx("invalid")

func _remove_target() -> void:
	var hit := _raycast()
	var node := hit.get("collider") as Node if not hit.is_empty() else null
	while node != null and not node.has_meta("surface_placement_id"):
		node = node.get_parent()
	if node != null and builder.remove_surface_equipment(str(node.get_meta("surface_placement_id"))):
		MHAudio.sfx("remove")

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 25
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0; panel.anchor_right = 1.0; panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = -392; panel.offset_right = -32; panel.offset_top = -246; panel.offset_bottom = -92
	panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(16, 16, 16, 16)))
	_hud.add_child(panel)
	var column := MHStyle.vbox(7)
	panel.add_child(column)
	column.add_child(MHStyle.eyebrow("Surface equipment", MHStyle.accent, 11))
	_selection = MHStyle.title("", 19)
	column.add_child(_selection)
	_status = MHStyle.body("", 13, MHStyle.TEXT_SECONDARY)
	column.add_child(_status)
	column.add_child(MHStyle.mono("LMB Place · R / wheel Rotate · X Remove · B Exit", 11, MHStyle.TEXT_MUTED))

func _update_hud() -> void:
	if _selection == null: return
	var entry := builder.surface_entry(selected_id)
	_selection.text = str(entry.get("label", selected_id))
	_status.text = "READY · free ground placement" if _valid_reason.is_empty() else _valid_reason
	_status.add_theme_color_override("font_color", MHStyle.VALID if _valid_reason.is_empty() else MHStyle.DANGER)
