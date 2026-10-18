class_name MHInteriorBuildController
extends Node

## First-person construction is intentionally independent from BuildController's
## exterior plan camera.  It uses catalogue effects/costs, but records metres
## and yaw rather than a single exterior-grid cell.

const BUILD_RANGE := 4.8
# The selector starts with the validated Living Quarters batch, then keeps the
# existing vertical-slice equipment available for its own valid rooms.
const QUICK_ITEMS := ["crew_bunk", "locker", "common_table", "task_light", "privacy_divider", "exercise_station", "grow_tray", "seedling_station", "nutrient_mixer", "harvest_cart", "hydroponics_sensor_panel", "air_recycler", "water_reclaimer", "oxygen_reserve_tank", "thermal_control_unit", "life_support_console", "science_workbench", "sample_analysis_station", "microscope_station", "planetary_data_console", "sample_storage_cabinet", "cargo_rack"]

var builder: BuildController
var player: CharacterBody3D
var active := false
var selected_id := "crew_bunk"
var rotation_offset := 0.0
var preview: Node3D
var _hit := {}
var _valid_reason := "Look at an interior floor, wall or ceiling"
var _hud: CanvasLayer
var _placement_panel: PanelContainer
var _status: Label
var _selection: Label
var _selector: PanelContainer
var _selector_open := false
var _preview_material_valid := true
var _selector_tabs: HBoxContainer
var _selector_cards: GridContainer
var _selector_context: Label
var _selector_zone_kind := ""
var _selector_group := ""
var _selector_items: Array[String] = []
var _remove_mode := false
var _selected_structure := ""
var _door_target := {}

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
	# Choosing the part is the first step of interior construction, rather than
	# a hidden secondary menu. Selecting a tile returns to the aimed placement
	# view with the mouse captured.
	_set_selector_open(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
		if event.keycode == KEY_B and event.shift_pressed:
			exit()
			builder._toggle()
			get_viewport().set_input_as_handled()
			return
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
			if _remove_mode and event.keycode == KEY_X:
				_remove_mode = false
				_set_selector_open(true)
				_refresh_preview(true)
			else:
				_set_remove_mode(true)
			get_viewport().set_input_as_handled()
			return
		var number := int(event.keycode) - int(KEY_1)
		if number >= 0 and number < _selector_items.size():
			selected_id = _selector_items[number]
			_selected_structure = ""
			rotation_offset = 0.0
			_refresh_preview(true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# The palette is a non-modal picker. A click on the scene beside it
			# commits the selected hologram immediately, then restores look input.
			if _selector_open:
				if not _pointer_over_selector():
					_set_selector_open(false)
					_place_preview()
					get_viewport().set_input_as_handled()
				return
			if _remove_mode:
				_remove_target()
			else:
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
	_refresh_contextual_selector()
	if _remove_mode:
		_valid_reason = "Removal tool · aim at an interior item"
		if preview != null:
			preview.visible = false
		_update_hud()
		return
	if _hit.is_empty():
		_valid_reason = "Look at a completed interior surface"
		if preview != null: preview.visible = false
		_update_hud()
		return
	var point: Vector3 = _hit.position
	var normal: Vector3 = _hit.normal.normalized()
	if _selected_structure == "interior_door":
		_door_target = builder.interior_door_from_world_point(point, normal)
		_valid_reason = builder.interior_door_invalid_reason(_door_target.get("cell", Vector2i.ZERO), _door_target.get("side", Vector2i.ZERO))
		if force_rebuild or preview == null:
			if preview != null: preview.queue_free()
			preview = _interior_door_preview(_door_target, normal)
			preview.name = "InteriorDoorPreview"
			add_child(preview)
			_set_preview_material(preview, _valid_reason.is_empty())
			_preview_material_valid = _valid_reason.is_empty()
		elif _preview_material_valid != _valid_reason.is_empty():
			_set_preview_material(preview, _valid_reason.is_empty())
			_preview_material_valid = _valid_reason.is_empty()
		_position_interior_door_preview(preview, _door_target, normal)
		preview.visible = true
		_update_hud()
		return
	_valid_reason = builder.free_interior_invalid_reason(selected_id, point, normal, _placement_yaw(normal))
	if force_rebuild or preview == null:
		if preview != null: preview.queue_free()
		preview = builder.free_interior_visual(selected_id, point, _placement_yaw(normal))
		preview.name = "InteriorBuildPreview"
		preview.set_meta("preview", true)
		add_child(preview)
		_disable_preview_collision(preview)
		_set_preview_material(preview, _valid_reason.is_empty())
		_preview_material_valid = _valid_reason.is_empty()
	else:
		preview.position = point + normal * .012
		preview.rotation.y = _placement_yaw(normal)
		if _preview_material_valid != _valid_reason.is_empty():
			_set_preview_material(preview, _valid_reason.is_empty())
			_preview_material_valid = _valid_reason.is_empty()
	preview.visible = true
	_update_hud()

func _placement_yaw(normal: Vector3) -> float:
	# Floor equipment follows the viewer's heading. Future wall entries face out
	# from the hit surface without requiring an exterior-grid direction.
	var entry := EquipmentCatalog.get_entry(selected_id)
	if str(entry.get("placement", "floor")) == "wall":
		return atan2(-normal.x, -normal.z) + rotation_offset
	return player.rotation.y + float(entry.get("model_rotation_y", 0.0)) + rotation_offset

func _disable_preview_collision(node: Node) -> void:
	for body in node.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = true
	for light in node.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false

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
		material.emission_energy_multiplier = 1.25
		material.no_depth_test = true
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _interior_door_preview(target: Dictionary, hit_normal: Vector3) -> Node3D:
	var side: Vector2i = target.get("side", Vector2i.ZERO)
	var holder := Node3D.new()
	# A thin frame rides just proud of the face being aimed at. A solid door
	# preview was visually indistinguishable from clipping through the wall.
	_position_interior_door_preview(holder, target, hit_normal)
	var opening_width := 1.22
	var opening_height := 2.42
	var surface := MeshInstance3D.new()
	var surface_mesh := QuadMesh.new()
	surface_mesh.size = Vector2(opening_width, opening_height)
	surface.mesh = surface_mesh
	surface.rotation.y = PI * .5 if side.x != 0 else 0.0
	var surface_material := StandardMaterial3D.new()
	surface_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface_material.albedo_color = Color("#57F6B3", .18)
	surface_material.emission_enabled = true
	surface_material.emission = Color("#57F6B3")
	surface_material.emission_energy_multiplier = 1.25
	surface_material.no_depth_test = true
	surface.material_override = surface_material
	holder.add_child(surface)
	for offset in [-opening_width * .5, opening_width * .5]:
		var jamb := MeshInstance3D.new()
		var jamb_mesh := BoxMesh.new()
		jamb_mesh.size = Vector3(.055, opening_height, .10) if side.x != 0 else Vector3(.10, opening_height, .055)
		jamb.mesh = jamb_mesh
		if side.x != 0:
			jamb.position.z = offset
		else:
			jamb.position.x = offset
		holder.add_child(jamb)
	var header := MeshInstance3D.new()
	var header_mesh := BoxMesh.new()
	header_mesh.size = Vector3(.055, .075, opening_width + .11) if side.x != 0 else Vector3(opening_width + .11, .075, .055)
	header.mesh = header_mesh
	header.position.y = opening_height * .5
	holder.add_child(header)
	return holder

func _position_interior_door_preview(holder: Node3D, target: Dictionary, hit_normal: Vector3) -> void:
	var cell: Vector2i = target.get("cell", Vector2i.ZERO)
	var side: Vector2i = target.get("side", Vector2i.ZERO)
	holder.position = Vector3(cell.x * BuildController.CELL + side.x * BuildController.CELL * .5, builder.habitat_base_y + 1.45, cell.y * BuildController.CELL + side.y * BuildController.CELL * .5) + hit_normal * .065

func _place_preview() -> void:
	if preview == null or not _valid_reason.is_empty() or _hit.is_empty():
		if not _valid_reason.is_empty(): MHAudio.sfx("invalid")
		return
	if _selected_structure == "interior_door":
		if builder.place_interior_door(_door_target.get("cell", Vector2i.ZERO), _door_target.get("side", Vector2i.ZERO)):
			MHAudio.sfx("place")
			_refresh_preview(true)
		else:
			MHAudio.sfx("invalid")
		return
	var point: Vector3 = preview.global_position
	var cell := Vector2i(roundi(point.x / BuildController.CELL), roundi(point.z / BuildController.CELL))
	var final_visual := builder.free_interior_visual(selected_id, point, preview.rotation.y)
	var normal: Vector3 = _hit.get("normal", Vector3.UP) as Vector3
	if builder.place_free_interior_equipment(selected_id, point, preview.rotation.y, cell, final_visual, normal.normalized()):
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
	_placement_panel = panel
	# Keep this contextual placement readout clear of the explore HUD's site
	# telemetry and colony chip in the upper-left. It sits above the bottom
	# controls at lower-right, close enough to read while aiming at a surface.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -392
	panel.offset_right = -32
	panel.offset_top = -282
	panel.offset_bottom = -92
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
	column.add_child(MHStyle.mono("LMB place · X remove · TAB palette · B exit", 11, MHStyle.TEXT_MUTED))
	_selector = PanelContainer.new()
	_selector.anchor_left = .5
	_selector.anchor_right = .5
	_selector.anchor_top = 1.0
	_selector.anchor_bottom = 1.0
	_selector.offset_left = -458
	_selector.offset_right = 458
	_selector.offset_top = -444
	_selector.offset_bottom = -72
	_selector.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(18, 18, 18, 18)))
	_hud.add_child(_selector)
	var select_column := MHStyle.vbox(10)
	_selector.add_child(select_column)
	var selector_head := MHStyle.hbox(8)
	selector_head.add_child(MHStyle.title("Construction", 20))
	var door_button := MHStyle.button("Interior door", "neutral", "door-closed", 34)
	door_button.focus_mode = Control.FOCUS_NONE
	door_button.tooltip_text = "Place a sealed-room doorway on a shared interior wall."
	door_button.pressed.connect(_select_structure.bind("interior_door"))
	selector_head.add_child(door_button)
	selector_head.add_child(MHStyle.spacer())
	var remove_button := MHStyle.button("Remove placed equipment", "danger", "trash-2", 34)
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.tooltip_text = "Aim at placed interior equipment, then left-click to remove it and refund cargo."
	remove_button.pressed.connect(_set_remove_mode.bind(true))
	selector_head.add_child(remove_button)
	selector_head.add_child(MHStyle.mono("CLICK SCENE · PLACE", 11, MHStyle.TEXT_MUTED))
	select_column.add_child(selector_head)
	_selector_context = MHStyle.body("", 13, MHStyle.TEXT_SECONDARY)
	select_column.add_child(_selector_context)
	_selector_tabs = MHStyle.hbox(6)
	select_column.add_child(_selector_tabs)
	_selector_cards = GridContainer.new()
	_selector_cards.columns = 4
	_selector_cards.add_theme_constant_override("h_separation", 8)
	_selector_cards.add_theme_constant_override("v_separation", 8)
	select_column.add_child(_selector_cards)
	_set_selector_open(true)
	_refresh_contextual_selector(true)
	_update_hud()

func _select_item(id: String) -> void:
	selected_id = id
	_selected_structure = ""
	rotation_offset = 0.0
	_remove_mode = false
	_set_selector_open(false)
	_refresh_preview(true)

func _select_structure(structure_id: String) -> void:
	_selected_structure = structure_id
	_remove_mode = false
	_set_selector_open(false)
	_refresh_preview(true)

func _set_remove_mode(enabled: bool) -> void:
	_remove_mode = enabled
	if enabled:
		_set_selector_open(false)
		if preview != null:
			preview.visible = false
	_refresh_preview(true)

func _set_selector_open(open: bool) -> void:
	_selector_open = open
	if _selector != null:
		_selector.visible = open
	if _placement_panel != null:
		_placement_panel.visible = not open
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func _pointer_over_selector() -> bool:
	return _selector != null and _selector.visible and _selector.get_global_rect().has_point(get_viewport().get_mouse_position())

func _context_zone() -> Dictionary:
	if builder == null:
		return {}
	# The construction palette describes the room the player is currently in.
	# The reticle is intentionally reserved for the precise surface being built
	# on; aiming at a doorway or adjacent wall must not reshuffle the inventory.
	return builder._zone_at(Vector2i(roundi(player.global_position.x / BuildController.CELL), roundi(player.global_position.z / BuildController.CELL)))

func _refresh_contextual_selector(force := false) -> void:
	if _selector == null:
		return
	var zone := _context_zone()
	var zone_kind := str(zone.get("kind", ""))
	if not force and zone_kind == _selector_zone_kind:
		return
	_selector_zone_kind = zone_kind
	_selector_items.clear()
	for raw_id in QUICK_ITEMS:
		var id := str(raw_id)
		var entry := EquipmentCatalog.get_entry(id)
		if not entry.is_empty() and builder.interior_asset_available(id) and not zone_kind.is_empty() and (entry.get("valid_zones", []) as Array).has(zone_kind):
			_selector_items.append(id)
	if _selector_items.is_empty():
		_selector_group = ""
		for child in _selector_tabs.get_children():
			child.queue_free()
		for child in _selector_cards.get_children():
			child.queue_free()
		if _selector_context != null:
			_selector_context.text = "Aim at a completed room to see equipment that belongs there."
		return
	var groups: Array[String] = []
	for group in EquipmentCatalog.groups():
		var group_id := str((group as Dictionary).get("id", ""))
		for id in _selector_items:
			if str(EquipmentCatalog.get_entry(id).get("group", "")) == group_id:
				groups.append(group_id)
				break
	if not groups.has(_selector_group):
		_selector_group = str(EquipmentCatalog.get_entry(selected_id).get("group", groups[0]))
		if not groups.has(_selector_group):
			_selector_group = groups[0]
	if not _selector_items.has(selected_id):
		selected_id = _selector_items[0]
		rotation_offset = 0.0
	_render_selector_tabs(groups)
	_render_selector_cards()
	if _selector_context != null:
		var zone_label := str(BuildController.ZONE_TYPES.get(zone_kind, {}).get("label", "completed habitat"))
		_selector_context.text = "%s kit · %d delivered assets · free placement" % [zone_label, _selector_items.size()]

func _render_selector_tabs(groups: Array[String]) -> void:
	for child in _selector_tabs.get_children():
		child.queue_free()
	for group in EquipmentCatalog.groups():
		var details := group as Dictionary
		var group_id := str(details.get("id", ""))
		if not groups.has(group_id):
			continue
		var tab := Button.new()
		tab.text = str(details.get("label", group_id)).to_upper()
		tab.icon = MHIcons.texture(str(details.get("icon", "package")), 16)
		tab.focus_mode = Control.FOCUS_NONE
		tab.tooltip_text = "Show %s equipment" % str(details.get("label", group_id))
		tab.add_theme_stylebox_override("normal", MHStyle.control_box(0 if group_id != _selector_group else 1))
		tab.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, MHStyle.RADIUS_SM, 1, Vector4(8, 8, 8, 8)))
		tab.pressed.connect(_select_selector_group.bind(group_id))
		_selector_tabs.add_child(tab)

func _select_selector_group(group_id: String) -> void:
	_selector_group = group_id
	for id in _selector_items:
		if str(EquipmentCatalog.get_entry(id).get("group", "")) == group_id:
			selected_id = id
			rotation_offset = 0.0
			break
	_render_selector_tabs(_available_groups())
	_render_selector_cards()
	_refresh_preview(true)

func _available_groups() -> Array[String]:
	var groups: Array[String] = []
	for group in EquipmentCatalog.groups():
		var group_id := str((group as Dictionary).get("id", ""))
		for id in _selector_items:
			if str(EquipmentCatalog.get_entry(id).get("group", "")) == group_id:
				groups.append(group_id)
				break
	return groups

func _render_selector_cards() -> void:
	for child in _selector_cards.get_children():
		child.queue_free()
	var index := 0
	for id in _selector_items:
		var entry := EquipmentCatalog.get_entry(id)
		if str(entry.get("group", "")) != _selector_group:
			continue
		index += 1
		var card := Button.new()
		card.custom_minimum_size = Vector2(206, 96)
		card.focus_mode = Control.FOCUS_NONE
		card.tooltip_text = "%s\n%s" % [str(entry.get("label", id)), EquipmentCatalog.effects_text(id)]
		card.add_theme_stylebox_override("normal", MHStyle.control_box(1 if id == selected_id else 0))
		card.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, MHStyle.RADIUS_SM, 1, Vector4(8, 8, 8, 8)))
		var content := MHStyle.hbox(8)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var zone_data := BuildController.ZONE_TYPES.get(_selector_zone_kind, {}) as Dictionary
		var zone_colour := zone_data.get("colour", MHStyle.accent) as Color
		var icon_tile := PanelContainer.new()
		icon_tile.custom_minimum_size = Vector2(44, 44)
		icon_tile.add_theme_stylebox_override("panel", MHStyle.box(zone_colour.darkened(.55), zone_colour.lightened(.15), MHStyle.RADIUS_SM, 1, Vector4(6, 6, 6, 6)))
		var icon := TextureRect.new()
		icon.texture = MHIcons.texture(str(entry.get("icon", "package")), 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = zone_colour.lightened(.48)
		icon_tile.add_child(icon)
		content.add_child(icon_tile)
		var card_column := MHStyle.vbox(2)
		card_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_column.add_child(MHStyle.mono("%d" % index, 10, MHStyle.accent, 700))
		var name := MHStyle.label(str(entry.get("label", id)), 12, MHStyle.TEXT_PRIMARY, 600)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_column.add_child(name)
		var effect := EquipmentCatalog.effects_text(id)
		var effect_label := MHStyle.mono(effect if not effect.is_empty() else str(entry.get("role", "")), 9, MHStyle.TEXT_MUTED)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_column.add_child(effect_label)
		content.add_child(card_column)
		card.add_child(content)
		card.pressed.connect(_select_item.bind(id))
		_selector_cards.add_child(card)

func _update_hud() -> void:
	if _selection == null or _status == null:
		return
	var entry := EquipmentCatalog.get_entry(selected_id)
	_selection.text = "Remove equipment" if _remove_mode else ("Interior door" if _selected_structure == "interior_door" else str(entry.get("label", selected_id)))
	var effect := "Full cargo refund" if _remove_mode else ("Seals rooms until explicitly connected" if _selected_structure == "interior_door" else EquipmentCatalog.effects_text(selected_id))
	var state := "AIM AT AN INTERIOR ITEM" if _remove_mode else ("READY" if _valid_reason.is_empty() else _valid_reason)
	var context := str(BuildController.ZONE_TYPES.get(_selector_zone_kind, {}).get("label", "completed habitat"))
	_status.text = "%s%s\n%s · %s" % [state, " · " + effect if not effect.is_empty() else "", context, "X palette" if _remove_mode else "TAB palette"]
	_status.add_theme_color_override("font_color", MHStyle.WARN if _remove_mode else (MHStyle.VALID if _valid_reason.is_empty() else MHStyle.DANGER))
