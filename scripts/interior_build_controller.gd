class_name MHInteriorBuildController
extends Node

## First-person construction is intentionally independent from BuildController's
## exterior plan camera.  It uses catalogue effects/costs, but records metres
## and yaw rather than a single exterior-grid cell.

const BUILD_RANGE := 4.8
const QUICK_ITEMS := ["crew_bunk", "grow_tray", "air_recycler", "science_workbench", "cargo_rack"]

var builder: BuildController
var player: CharacterBody3D
var active := false
var selected_id := "crew_bunk"
var rotation_offset := 0.0
var preview: Node3D
var _hit := {}
var _valid_reason := "Look at an interior floor, wall or ceiling"
var _hud: CanvasLayer
var _status: Label
var _selection: Label
var _selector: PanelContainer
var _selector_open := false

func setup(target_player: CharacterBody3D, target_builder: BuildController) -> void:
	player = target_player
	builder = target_builder

func enter() -> void:
	if active or builder == null or player == null:
		return
	active = true
	rotation_offset = 0.0
	player.set_meta("interior_build_active", true)
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MHAudio.sfx("mode_build", -2.0, 0.0)
	MHAudio.build_layer(true)
	_refresh_preview(true)

func exit() -> void:
	if not active:
		return
	active = false
	player.set_meta("interior_build_active", false)
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
			rotation_offset = wrapf(rotation_offset + PI / 12.0, -PI, PI)
			_refresh_preview(true)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			_set_selector_open(not _selector_open)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_X or event.keycode == KEY_DELETE:
			_remove_target()
			get_viewport().set_input_as_handled()
			return
		var number := int(event.keycode) - int(KEY_1)
		if number >= 0 and number < QUICK_ITEMS.size():
			selected_id = str(QUICK_ITEMS[number])
			rotation_offset = 0.0
			_refresh_preview(true)
			get_viewport().set_input_as_handled()
			return
	if _selector_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place_preview()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rotation_offset = wrapf(rotation_offset + (PI / 24.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -PI / 24.0), -PI, PI)
			_refresh_preview(true)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not active:
		return
	_refresh_preview(false)

func _camera() -> Camera3D:
	return player.get_node_or_null("Head/Camera3D") as Camera3D

func _raycast() -> Dictionary:
	var camera := _camera()
	if camera == null or not camera.is_inside_tree():
		return {}
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * BUILD_RANGE)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _refresh_preview(force_rebuild: bool) -> void:
	_hit = _raycast()
	if _hit.is_empty():
		_valid_reason = "Look at a completed interior surface"
		if preview != null: preview.visible = false
		_update_hud()
		return
	var point: Vector3 = _hit.position
	var normal: Vector3 = _hit.normal.normalized()
	_valid_reason = builder.free_interior_invalid_reason(selected_id, point, normal, _placement_yaw(normal))
	if force_rebuild or preview == null:
		if preview != null: preview.queue_free()
		preview = builder.free_interior_visual(selected_id, point, _placement_yaw(normal))
		preview.name = "InteriorBuildPreview"
		preview.set_meta("preview", true)
		add_child(preview)
		_disable_preview_collision(preview)
		_set_preview_material(preview, _valid_reason.is_empty())
	else:
		preview.position = point + normal * .012
		preview.rotation.y = _placement_yaw(normal)
	preview.visible = true
	_update_hud()

func _placement_yaw(normal: Vector3) -> float:
	# Floor equipment follows the viewer's heading. Future wall entries face out
	# from the hit surface without requiring an exterior-grid direction.
	var entry := EquipmentCatalog.get_entry(selected_id)
	if str(entry.get("placement", "floor")) == "wall":
		return atan2(-normal.x, -normal.z) + rotation_offset
	return player.rotation.y + rotation_offset

func _disable_preview_collision(node: Node) -> void:
	for body in node.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = true

func _set_preview_material(node: Node, valid: bool) -> void:
	var tint := Color("#57F6B3") if valid else Color("#FF5A61")
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var source := mesh.get_active_material(0) as StandardMaterial3D
		var material := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(tint, .38)
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = .35
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _place_preview() -> void:
	if preview == null or not _valid_reason.is_empty() or _hit.is_empty():
		if not _valid_reason.is_empty(): MHAudio.sfx("invalid")
		return
	var point: Vector3 = preview.global_position
	var cell := Vector2i(roundi(point.x / BuildController.CELL), roundi(point.z / BuildController.CELL))
	var final_visual := builder.free_interior_visual(selected_id, point, preview.rotation.y)
	if builder.place_free_interior_equipment(selected_id, point, preview.rotation.y, cell, final_visual):
		MHAudio.sfx("place")
		_refresh_preview(true)
	else:
		final_visual.queue_free()
		MHAudio.sfx("invalid")

func _remove_target() -> void:
	var hit := _raycast()
	if hit.is_empty():
		return
	var node := hit.get("collider") as Node
	while node != null and not node.has_meta("interior_placement_id"):
		node = node.get_parent()
	if node != null:
		builder.remove_free_interior_equipment(str(node.get_meta("interior_placement_id")))
		MHAudio.sfx("remove")

func _build_hud() -> void:
	if _hud != null:
		return
	_hud = CanvasLayer.new()
	_hud.layer = 25
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(32, 140)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(16, 16, 16, 16)))
	_hud.add_child(panel)
	var column := MHStyle.vbox(7)
	panel.add_child(column)
	column.add_child(MHStyle.eyebrow("Interior construction", MHStyle.accent, 11))
	_selection = MHStyle.title("", 19)
	column.add_child(_selection)
	_status = MHStyle.body("", 13, MHStyle.TEXT_SECONDARY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	column.add_child(MHStyle.mono("1–5 Select · LMB Place · R / wheel Rotate · X Remove · B Exit", 11, MHStyle.TEXT_MUTED))
	_selector = PanelContainer.new()
	_selector.anchor_left = .5
	_selector.anchor_right = .5
	_selector.anchor_top = 1.0
	_selector.anchor_bottom = 1.0
	_selector.offset_left = -352
	_selector.offset_right = 352
	_selector.offset_top = -332
	_selector.offset_bottom = -72
	_selector.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(18, 18, 18, 18)))
	_hud.add_child(_selector)
	var select_column := MHStyle.vbox(10)
	_selector.add_child(select_column)
	var selector_head := MHStyle.hbox(8)
	selector_head.add_child(MHStyle.title("Interior kit", 20))
	selector_head.add_child(MHStyle.spacer())
	selector_head.add_child(MHStyle.mono("TAB CLOSE", 11, MHStyle.TEXT_MUTED))
	select_column.add_child(selector_head)
	select_column.add_child(MHStyle.body("Choose an installed item. Placement remains free-positioned in first person.", 13, MHStyle.TEXT_SECONDARY))
	var cards := GridContainer.new()
	cards.columns = 5
	cards.add_theme_constant_override("h_separation", 8)
	select_column.add_child(cards)
	for index in QUICK_ITEMS.size():
		var id := str(QUICK_ITEMS[index])
		var entry := EquipmentCatalog.get_entry(id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(124, 106)
		card.focus_mode = Control.FOCUS_NONE
		card.tooltip_text = "%s\n%s" % [str(entry.get("label", id)), EquipmentCatalog.effects_text(id)]
		card.add_theme_stylebox_override("normal", MHStyle.control_box(0))
		card.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, MHStyle.RADIUS_SM, 1, Vector4(8, 8, 8, 8)))
		var card_column := MHStyle.vbox(4)
		card_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := MHStyle.mono("%d" % (index + 1), 11, MHStyle.accent, 700)
		card_column.add_child(key)
		var name := MHStyle.label(str(entry.get("label", id)), 13, MHStyle.TEXT_PRIMARY, 600)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_column.add_child(name)
		var effect := EquipmentCatalog.effects_text(id)
		var effect_label := MHStyle.mono(effect if not effect.is_empty() else str(entry.get("role", "")), 10, MHStyle.TEXT_MUTED)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_column.add_child(effect_label)
		card.add_child(card_column)
		card.pressed.connect(_select_item.bind(id))
		cards.add_child(card)
	_set_selector_open(false)
	_update_hud()

func _select_item(id: String) -> void:
	selected_id = id
	rotation_offset = 0.0
	_set_selector_open(false)
	_refresh_preview(true)

func _set_selector_open(open: bool) -> void:
	_selector_open = open
	if _selector != null:
		_selector.visible = open
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func _update_hud() -> void:
	if _selection == null or _status == null:
		return
	var entry := EquipmentCatalog.get_entry(selected_id)
	_selection.text = str(entry.get("label", selected_id))
	var effect := EquipmentCatalog.effects_text(selected_id)
	var state := "READY" if _valid_reason.is_empty() else _valid_reason
	_status.text = "%s%s\nTAB · choose interior item" % [state, " · " + effect if not effect.is_empty() else ""]
	_status.add_theme_color_override("font_color", MHStyle.VALID if _valid_reason.is_empty() else MHStyle.DANGER)
