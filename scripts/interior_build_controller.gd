class_name MHInteriorBuildController
extends Node

## First-person construction is intentionally independent from BuildController's
## exterior plan camera.  It uses catalogue effects/costs, but records metres
## and yaw rather than a single exterior-grid cell.

const BUILD_RANGE := 4.8
const MHMissions := preload("res://scripts/mh_missions.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const ModelThumbnails := preload("res://scripts/model_thumbnails.gd")
const MODEL_PREVIEW := preload("res://scripts/model_preview.gd")
## The build bar's last tab: doors, windows and removing things.
const STRUCTURE_TAB := "_structure"
const STRUCTURE_TOOLS := [
	{"id": "partition", "label": "Partition wall", "icon": "brick-wall", "text": "Divide a room into bedrooms or cubicles. Hold the mouse button and drag along the floor to draw 1.5 m panels. The room stays one space for air and heat."},
	{"id": "partition_glass", "label": "Glass partition", "icon": "panels-top-left", "text": "A glass panel in a metal frame: it divides the room but keeps it open and light. Drag to draw, or aim at a wall panel to glaze it."},
	{"id": "partition_door", "label": "Partition door", "icon": "door-open", "text": "A door in a partition wall: aim at a wall panel to turn it into a door, or at the floor to add one. Press E to open it."},
	{"id": "interior_door", "label": "Room door", "icon": "door-closed", "text": "A doorway in a shared wall, so two sealed rooms connect."},
	{"id": "window", "label": "Window", "icon": "sun", "text": "Glazes one outside wall bay. A view of Mars, but glass loses heat faster than the hull."},
	{"id": "remove", "label": "Remove", "icon": "trash-2", "text": "Aim at an item, door or window and click to remove it. Cargo is refunded."},
]
# The selector starts with the validated Living Quarters batch, then keeps the
# existing vertical-slice equipment available for its own valid rooms.
const QUICK_ITEMS := ["crew_bunk", "locker", "common_table", "task_light", "privacy_divider", "exercise_station", "crew_chair", "crew_personal_desk", "grow_tray", "seedling_station", "nutrient_mixer", "harvest_cart", "hydroponics_sensor_panel", "greenhouse_planter", "greenhouse_shade_screen", "greenhouse_observation_seat", "pollination_tool_station", "air_recycler", "water_reclaimer", "oxygen_reserve_tank", "thermal_control_unit", "life_support_console", "science_workbench", "sample_analysis_station", "microscope_station", "planetary_data_console", "sample_storage_cabinet", "medical_cabinet", "medical_exam_cot", "cargo_rack", "spares_cabinet", "cold_storage_unit", "tool_bench", "galley_counter", "galley_sink", "food_warmer", "pantry_cabinet", "potable_water_dispenser", "hygiene_shower", "hygiene_toilet", "hygiene_washbasin", "waste_sorting_unit", "communications_station", "corridor_light_strip", "wayfinding_panel", "fire_safety_station", "utility_conduit", "airlock_control_panel", "suit_service_panel", "dust_grate", "emergency_supply_lockbox", "power_distribution_panel", "battery_bank", "inverter_cabinet", "reactor_monitor_console", "rover_charger", "eva_tool_station", "suit_rack", "decontamination_arch"]

var builder: BuildController
var player: CharacterBody3D
var active := false
var selected_id := "crew_bunk"
var rotation_offset := 0.0
## Hold R to keep turning (a tap still turns 15°); Shift+R turns the other way.
const HOLD_DELAY := .25
const HOLD_SPEED := deg_to_rad(120.0)
var _r_held := 0.0
var preview: Node3D
var _hit := {}
var _valid_reason := "Look at an interior floor, wall or ceiling"
var _hud: CanvasLayer
var _selector_open := false
var _preview_material_valid := true
var _selector_tabs: HBoxContainer
var _selector_cards: HBoxContainer
var _selector_context: Label
var _selector_zone_kind := ""
var _selector_group := ""
var _selector_items: Array[String] = []
var _remove_mode := false
var _selected_structure := ""
var _door_target := {}
var _window_target := {}
var _mode_switcher: Dictionary = {}
# Build bar (AAA layout): bottom tabs and picture cards, a turning 3D preview
# with real numbers on the right, and a placement tag under the crosshair.
var _bar: PanelContainer
var _details: PanelContainer
var _preview_3d: SubViewportContainer
var _preview_stage: Control
var _details_group: Label
var _details_title: Label
var _details_text: Label
var _details_chips: HFlowContainer
var _tag: PanelContainer
var _tag_label: Label
var _tag_icon: TextureRect
var _hints: Label
var _was_minimal := false
var _partition_target := {}
var _last_painted := ""

## Every placeable interior item, in inventory-group order (outdoor props
## excluded): new catalogue items appear here without code changes.
func _catalogue_ids() -> Array:
	var ids: Array = []
	for group in EquipmentCatalog.groups():
		for id in EquipmentCatalog.ids_in_group(str(group.id)):
			if not ids.has(id): ids.append(id)
	return ids

func setup(target_player: CharacterBody3D, target_builder: BuildController) -> void:
	player = target_player
	builder = target_builder

func enter() -> void:
	if active or builder == null or player == null:
		return
	active = true
	rotation_offset = 0.0
	player.set_meta("interior_build_active", true)
	var explore := get_tree().get_first_node_in_group("explore_hud")
	if explore != null:
		_was_minimal = bool(explore.get("_minimal"))
		explore.call("set_minimal", true)   # a clean screen while building
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
	var explore := get_tree().get_first_node_in_group("explore_hud")
	if explore != null and not _was_minimal: explore.call("set_minimal", false)
	if preview != null:
		preview.queue_free()
		preview = null
	if _hud != null:
		_hud.queue_free()
		_hud = null
		_mode_switcher = {}
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MHAudio.sfx("mode_explore", -2.0, 0.0)
	MHAudio.build_layer(false)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B and event.shift_pressed:
			_switch_to_site_plan()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
			exit()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			rotation_offset = wrapf(rotation_offset + (-PI if event.shift_pressed else PI) / 12.0, -PI, PI)
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
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if builder.undo_last_structure(): _refresh_preview(true)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_Q or event.keycode == KEY_E:
			var tabs := _tab_ids()
			if not tabs.is_empty():
				var index := maxi(0, tabs.find(_selector_group))
				_select_selector_group(tabs[(index + (1 if event.keycode == KEY_E else -1) + tabs.size()) % tabs.size()])
				MHAudio.sfx("ui_click", -6.0)
			get_viewport().set_input_as_handled()
			return
		var number := int(event.keycode) - int(KEY_1)
		var visible_cards := _visible_ids()
		if number >= 0 and number < visible_cards.size():
			_pick_card(visible_cards[number])
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

func _process(delta: float) -> void:
	if not active:
		return
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
		_valid_reason = "Removal tool · aim at an item, door or window"
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
	if _selected_structure == "window":
		_window_target = builder.window_target_at(point)
		_valid_reason = builder.window_invalid_reason(_window_target)
		if force_rebuild or preview == null:
			if preview != null: preview.queue_free()
			preview = _window_preview()
			preview.name = "WindowPreview"
			add_child(preview)
			_preview_material_valid = not _valid_reason.is_empty()
		if _preview_material_valid != _valid_reason.is_empty():
			_set_preview_material(preview, _valid_reason.is_empty())
			_preview_material_valid = _valid_reason.is_empty()
		preview.visible = not _window_target.is_empty()
		if not _window_target.is_empty():
			preview.transform = builder.window_target_transform(_window_target)
			preview.scale = Vector3(float(_window_target.length) / BuildController.CELL, 1, 1)
		_update_hud()
		return
	if _selected_structure.begins_with("partition"):
		_partition_target = builder.partition_segment_at(point - normal * .05 if absf(normal.y) < .5 else point)
		var door := _selected_structure == "partition_door"
		var glass := _selected_structure == "partition_glass"
		_valid_reason = builder.partition_invalid_reason(_partition_target, door, glass)
		if force_rebuild or preview == null:
			if preview != null: preview.queue_free()
			preview = _partition_preview(door)
			preview.name = "PartitionPreview"
			add_child(preview)
			_preview_material_valid = not _valid_reason.is_empty()
		if _preview_material_valid != _valid_reason.is_empty():
			_set_preview_material(preview, _valid_reason.is_empty())
			_preview_material_valid = _valid_reason.is_empty()
		preview.visible = true
		preview.transform = builder.partition_transform(_partition_target)
		# Hold the button and drag to keep drawing panels.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _selector_open and _valid_reason.is_empty():
			var key := str(_partition_target)
			if key != _last_painted:
				_last_painted = key
				if builder.place_partition(_partition_target, door, glass): MHAudio.sfx("place", -4.0)
		_update_hud()
		return
	if _selected_structure == "interior_door":
		_door_target = builder.interior_door_from_world_point(point, normal)
		_valid_reason = builder.interior_door_target_invalid_reason(_door_target)
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
	# Models face -Z; turn them half round so the front faces the player.
	return player.rotation.y + PI + float(entry.get("model_rotation_y", 0.0)) + rotation_offset

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
	var holder := Node3D.new()
	# A thin frame rides just proud of the face being aimed at. A solid door
	# preview was visually indistinguishable from clipping through the wall.
	# The holder's local X runs along the wall (grid or angled), so the frame
	# below is built once in that frame.
	_position_interior_door_preview(holder, target, hit_normal)
	var opening_width := 1.22
	var opening_height := 2.42
	var surface := MeshInstance3D.new()
	var surface_mesh := QuadMesh.new()
	surface_mesh.size = Vector2(opening_width, opening_height)
	surface.mesh = surface_mesh
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
		jamb_mesh.size = Vector3(.10, opening_height, .055)
		jamb.mesh = jamb_mesh
		jamb.position.x = offset
		holder.add_child(jamb)
	var header := MeshInstance3D.new()
	var header_mesh := BoxMesh.new()
	header_mesh.size = Vector3(opening_width + .11, .075, .055)
	header.mesh = header_mesh
	header.position.y = opening_height * .5
	holder.add_child(header)
	return holder

func _position_interior_door_preview(holder: Node3D, target: Dictionary, hit_normal: Vector3) -> void:
	var opening := builder.interior_door_target_transform(target)
	holder.transform = Transform3D(opening.basis, opening.origin + Vector3.UP * 1.45 + hit_normal * .065)

## Bay-sized ghost of the glazed band, shown on the wall bay being aimed at.
## Ghost of a partition panel (or door frame) for the aimed segment.
func _partition_preview(door: bool) -> Node3D:
	var holder := Node3D.new()
	var height := BuildController.ROOM_HEIGHT - .12
	var parts: Array = [[Vector3(BuildController.PARTITION_STEP, height, BuildController.PARTITION_THICKNESS), Vector3(0, height * .5, 0)]]
	if door:
		parts = [[Vector3(.1, height, .12), Vector3(-.7, height * .5, 0)], [Vector3(.1, height, .12), Vector3(.7, height * .5, 0)], [Vector3(1.3, height - 2.1, .1), Vector3(0, 2.1 + (height - 2.1) * .5, 0)]]
	for part in parts:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = part[0]; mesh.mesh = box
		mesh.position = part[1]
		holder.add_child(mesh)
	_set_preview_material(holder, true)
	return holder

func _window_preview() -> Node3D:
	var holder := Node3D.new()
	var band := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(BuildController.CELL - .5, BuildController.WINDOW_HEAD - BuildController.WINDOW_SILL, .34)
	band.mesh = mesh
	band.position.y = (BuildController.WINDOW_SILL + BuildController.WINDOW_HEAD) * .5 - BuildController.ROOM_HEIGHT * .5
	holder.add_child(band)
	var outline := MeshInstance3D.new()
	var outline_mesh := BoxMesh.new()
	outline_mesh.size = Vector3(BuildController.CELL, BuildController.ROOM_HEIGHT, .3)
	outline.mesh = outline_mesh
	outline.scale = Vector3(1, 1, .3)
	holder.add_child(outline)
	return holder

func _place_preview() -> void:
	if preview == null or not _valid_reason.is_empty() or _hit.is_empty():
		if not _valid_reason.is_empty(): MHAudio.sfx("invalid")
		return
	if _selected_structure == "window":
		if builder.place_window(_window_target):
			MHAudio.sfx("place")
			_refresh_preview(true)
		else:
			MHAudio.sfx("invalid")
		return
	if _selected_structure.begins_with("partition"):
		_last_painted = str(_partition_target)
		if builder.place_partition(_partition_target, _selected_structure == "partition_door", _selected_structure == "partition_glass"):
			MHAudio.sfx("place")
			_refresh_preview(true)
		else:
			MHAudio.sfx("invalid")
		return
	if _selected_structure == "interior_door":
		if builder.place_interior_door_target(_door_target):
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
	if node != null and node.has_meta("partition_index"):
		builder.remove_partition(int(node.get_meta("partition_index")))
		MHAudio.sfx("remove")
		return
	while node != null and not node.has_meta("interior_placement_id"):
		node = node.get_parent()
	if node != null:
		builder.remove_free_interior_equipment(str(node.get_meta("interior_placement_id")))
		MHAudio.sfx("remove")
		return
	# Interior doors: aim at the hatch or the wall right beside it to seal
	# that wall again.
	var door_index := builder.interior_door_index_near(hit.position)
	if door_index >= 0:
		builder.remove_interior_door(door_index)
		MHAudio.sfx("remove")
		return
	var window_index := builder.window_index_near(hit.position)
	if window_index >= 0:
		builder.remove_window(window_index)
		MHAudio.sfx("remove")

func _build_hud() -> void:
	if _hud != null:
		return
	_hud = CanvasLayer.new()
	_hud.layer = 25
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHStyle.theme()
	_hud.add_child(root)
	_mode_switcher = MHStyle.build_mode_switcher("interior", _purpose_text(), _switch_to_site_plan, func() -> void: pass, exit)
	(_mode_switcher.root as Control).offset_top = 40
	(_mode_switcher.root as Control).offset_bottom = 128
	root.add_child(_mode_switcher.root)
	root.add_child(_build_placement_tag())
	root.add_child(_build_details())
	root.add_child(_build_bar())
	_refresh_contextual_selector(true)
	_update_hud()

## The bar along the bottom: category tabs, then a row of picture cards.
func _build_bar() -> PanelContainer:
	_bar = PanelContainer.new()
	_bar.anchor_left = .5
	_bar.anchor_right = .5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -780
	_bar.offset_right = 780
	_bar.offset_top = -330
	_bar.offset_bottom = -92
	_bar.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, 8, 1, Vector4(18, 16, 18, 16)))
	MHStyle.add_rail(_bar, 28)
	var column := MHStyle.vbox(12)
	_bar.add_child(column)
	var head := MHStyle.hbox(8)
	_selector_tabs = MHStyle.hbox(6)
	head.add_child(_selector_tabs)
	head.add_child(MHStyle.spacer())
	_selector_context = MHStyle.mono("", 12, MHStyle.TEXT_MUTED)
	_selector_context.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_selector_context)
	_hints = MHStyle.mono("", 12, MHStyle.TEXT_SECONDARY)
	_hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_hints)
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 168)
	column.add_child(scroll)
	_selector_cards = HBoxContainer.new()
	_selector_cards.add_theme_constant_override("separation", 10)
	scroll.add_child(_selector_cards)
	return _bar

## Right-hand panel: the selected item turning in 3D, what it is, and its
## real numbers (from the balance spreadsheet).
func _build_details() -> PanelContainer:
	_details = PanelContainer.new()
	_details.anchor_left = 1.0
	_details.anchor_right = 1.0
	_details.anchor_top = .5
	_details.anchor_bottom = .5
	_details.offset_left = -470
	_details.offset_right = -48
	_details.offset_top = -380
	_details.offset_bottom = -380   # grows to fit its content
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD, MHStyle.BORDER_SUBTLE, 8, 1, Vector4(18, 18, 18, 18)))
	MHStyle.add_rail(_details, 28)
	var column := MHStyle.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(column)
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 230)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_theme_stylebox_override("panel", MHStyle.box(Color(1, 1, 1, .035), Color(0, 0, 0, 0), 6, 0))
	_preview_3d = MODEL_PREVIEW.new()
	stage.add_child(_preview_3d)
	column.add_child(stage)
	_preview_stage = stage
	_details_group = MHStyle.eyebrow("", MHStyle.accent, 12)
	column.add_child(_details_group)
	_details_title = MHStyle.title("", 26)
	column.add_child(_details_title)
	_details_text = MHStyle.body("", 15, MHStyle.TEXT_SECONDARY)
	_details_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_text.max_lines_visible = 4
	column.add_child(_details_text)
	_details_chips = HFlowContainer.new()
	_details_chips.add_theme_constant_override("h_separation", 6)
	_details_chips.add_theme_constant_override("v_separation", 6)
	_details_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_details_chips)
	return _details

## Under the crosshair: does it fit here, or why not, and which keys to use.
func _build_placement_tag() -> Control:
	var band := CenterContainer.new()
	band.anchor_top = .5
	band.anchor_bottom = .5
	band.anchor_right = 1.0
	band.offset_top = 44
	band.offset_bottom = 92
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag = PanelContainer.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := MHStyle.hbox(8)
	_tag_icon = TextureRect.new()
	_tag_icon.custom_minimum_size = Vector2(18, 18)
	_tag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_tag_icon)
	_tag_label = MHStyle.mono("", 13, MHStyle.TEXT_PRIMARY, 600)
	row.add_child(_tag_label)
	_tag.add_child(row)
	band.add_child(_tag)
	return band

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

## The bar is always on screen; "open" frees the cursor to click its cards
## (Tab). Clicking the scene places the item and captures the mouse again.
func _set_selector_open(open: bool) -> void:
	_selector_open = open
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	_update_hud()


## Interior → Site plan, e.g. to add an airlock or rooms from inside.
func _switch_to_site_plan() -> void:
	exit()
	if not builder.build_mode: builder._toggle()

func _purpose_text() -> String:
	return "Interior · furnishing %s" % builder.player_room_label() if builder != null and builder.player_can_furnish() else "Interior · walk into a room to furnish it"

## True while the kit selector is open and needs a free cursor (used when
## returning from the pause screen or Mission Control).
func wants_cursor() -> bool:
	return active and _selector_open

func _pointer_over_selector() -> bool:
	return _bar != null and _bar.visible and _bar.get_global_rect().has_point(get_viewport().get_mouse_position())

func _context_zone() -> Dictionary:
	if builder == null:
		return {}
	# The construction palette describes the room the player is currently in.
	# The reticle is intentionally reserved for the precise surface being built
	# on; aiming at a doorway or adjacent wall must not reshuffle the inventory.
	# By position, so angled (free-form) rooms list their equipment too.
	return builder._zone_at_point(Vector2(player.global_position.x, player.global_position.z))

func _refresh_contextual_selector(force := false) -> void:
	if _bar == null:
		return
	var zone := _context_zone()
	var zone_kind := str(zone.get("kind", ""))
	if not force and zone_kind == _selector_zone_kind:
		return
	_selector_zone_kind = zone_kind
	if not _mode_switcher.is_empty():
		(_mode_switcher.purpose as Label).text = _purpose_text()
	_selector_items.clear()
	for raw_id in _catalogue_ids():
		var id := str(raw_id)
		var entry := EquipmentCatalog.get_entry(id)
		if not entry.is_empty() and builder.interior_asset_available(id) and not zone_kind.is_empty() and (entry.get("valid_zones", []) as Array).has(zone_kind) and MHMissions.item_unlocked(id):
			_selector_items.append(id)
	if _selector_items.is_empty():
		_selector_group = ""
		for child in _selector_tabs.get_children():
			child.queue_free()
		for child in _selector_cards.get_children():
			child.queue_free()
		if _selector_context != null:
			_selector_context.text = "WALK INTO A ROOM TO FURNISH IT"
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
		_selector_context.text = "%s · %d ITEMS   " % [zone_label.to_upper(), _selector_items.size()]

func _render_selector_tabs(groups: Array[String]) -> void:
	for child in _selector_tabs.get_children():
		child.queue_free()
	var specs: Array = []
	for group in EquipmentCatalog.groups():
		var details := group as Dictionary
		if groups.has(str(details.get("id", ""))): specs.append([str(details.id), str(details.get("label", "")), str(details.get("icon", "package"))])
	specs.append([STRUCTURE_TAB, "Structure", "door-closed"])
	for spec in specs:
		var selected: bool = spec[0] == _selector_group
		var tab := Button.new()
		tab.text = "  " + str(spec[1])
		tab.icon = MHIcons.texture(str(spec[2]), 18)
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(0, 40)
		tab.add_theme_font_size_override("font_size", 15)
		tab.add_theme_color_override("font_color", MHStyle.TEXT_PRIMARY if selected else MHStyle.TEXT_SECONDARY)
		tab.add_theme_stylebox_override("normal", MHStyle.box(MHStyle.tint(MHStyle.accent, .22) if selected else MHStyle.SURFACE_CONTROL, MHStyle.accent if selected else MHStyle.BORDER_SUBTLE, 6, 1, Vector4(14, 6, 16, 6)))
		tab.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, 6, 1, Vector4(14, 6, 16, 6)))
		tab.add_theme_stylebox_override("pressed", tab.get_theme_stylebox("normal"))
		tab.pressed.connect(_select_selector_group.bind(str(spec[0])))
		_selector_tabs.add_child(tab)

func _select_selector_group(group_id: String) -> void:
	_selector_group = group_id
	if group_id != STRUCTURE_TAB:
		for id in _selector_items:
			if str(EquipmentCatalog.get_entry(id).get("group", "")) == group_id:
				selected_id = id
				_selected_structure = ""
				_remove_mode = false
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
	for id in _visible_ids():
		index += 1
		_selector_cards.add_child(_card(id, index))

## Tabs in order (equipment groups for this room, then Structure).
func _tab_ids() -> Array:
	var tabs: Array = []
	for group in _available_groups(): tabs.append(group)
	tabs.append(STRUCTURE_TAB)
	return tabs

## Card ids in the current tab (equipment ids, or structure tool ids).
func _visible_ids() -> Array:
	if _selector_group == STRUCTURE_TAB:
		return STRUCTURE_TOOLS.map(func(tool): return str(tool.id))
	return _selector_items.filter(func(id): return str(EquipmentCatalog.get_entry(id).get("group", "")) == _selector_group)

func _structure_tool(id: String) -> Dictionary:
	for tool in STRUCTURE_TOOLS:
		if str(tool.id) == id: return tool
	return {}

func _pick_card(id: String) -> void:
	MHAudio.sfx("ui_click", -6.0)
	if _selector_group == STRUCTURE_TAB:
		if id == "remove": _set_remove_mode(true)
		else: _select_structure(id)
	else:
		_select_item(id)
	_render_selector_cards()

func _is_selected(id: String) -> bool:
	if _selector_group == STRUCTURE_TAB:
		return (id == "remove" and _remove_mode) or (not _remove_mode and _selected_structure == id)
	return id == selected_id and _selected_structure.is_empty() and not _remove_mode

## One picture card: a rendered thumbnail of the real model, its number key,
## name and cargo mass.
func _card(id: String, index: int) -> Button:
	var structure := _structure_tool(id) if _selector_group == STRUCTURE_TAB else {}
	var entry := EquipmentCatalog.get_entry(id)
	var selected := _is_selected(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(186, 164)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", MHStyle.box(MHStyle.tint(MHStyle.accent, .16) if selected else MHStyle.SURFACE_CONTROL, MHStyle.accent if selected else MHStyle.BORDER_SUBTLE, 8, 2 if selected else 1, Vector4(8, 8, 8, 8)))
	card.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.accent if selected else MHStyle.BORDER_STRONG, 8, 2 if selected else 1, Vector4(8, 8, 8, 8)))
	card.add_theme_stylebox_override("pressed", card.get_theme_stylebox("hover"))
	var column := MHStyle.vbox(4)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_top = 8
	column.offset_right = -8
	column.offset_bottom = -8
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(170, 104)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if structure.is_empty():
		picture.texture = MHIcons.texture(str(entry.get("icon", "package")), 48)
		picture.modulate = Color(1, 1, 1, .35)
		ModelThumbnails.request(get_tree(), id, func(texture: Texture2D) -> void:
			if is_instance_valid(picture) and texture != null:
				picture.texture = texture
				picture.modulate = Color.WHITE)
	else:
		picture.texture = MHIcons.texture(str(structure.icon), 56)
		picture.modulate = MHStyle.accent if selected else MHStyle.TEXT_SECONDARY
	column.add_child(picture)
	var name := MHStyle.label(str(structure.get("label", entry.get("label", id))), 14, MHStyle.TEXT_PRIMARY, 600)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name)
	var sub := MHStyle.mono(("%d  ·  %s" % [index, MHStyle.kg(int(entry.get("cargo_cost", 0)))]) if structure.is_empty() else "%d" % index, 11, MHStyle.TEXT_MUTED)
	column.add_child(sub)
	card.add_child(column)
	card.pressed.connect(_pick_card.bind(id))
	return card

func _update_hud() -> void:
	if _tag == null:
		return
	var structure := _structure_tool("remove" if _remove_mode else _selected_structure)
	# Placement tag under the crosshair.
	var ok := _valid_reason.is_empty()
	var tone := MHStyle.WARN if _remove_mode else (MHStyle.VALID if ok else MHStyle.DANGER)
	_tag_icon.texture = MHIcons.texture("trash-2" if _remove_mode else ("circle-check" if ok else "circle-x"), 18)
	_tag_icon.modulate = tone
	if _remove_mode: _tag_label.text = "AIM AT AN ITEM, DOOR OR WINDOW   ·   LMB REMOVE"
	elif ok and (_selected_structure == "partition" or _selected_structure == "partition_glass"): _tag_label.text = "FITS HERE   ·   HOLD LMB AND DRAG TO DRAW"
	elif ok and _selected_structure == "partition_door": _tag_label.text = "FITS HERE   ·   LMB PLACE DOOR"
	elif ok: _tag_label.text = "FITS HERE   ·   LMB PLACE   ·   HOLD R ROTATE"
	else: _tag_label.text = _valid_reason.to_upper()
	_tag_label.add_theme_color_override("font_color", tone if not ok or _remove_mode else MHStyle.TEXT_PRIMARY)
	_tag.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, tone, 20, 1, Vector4(14, 6, 16, 6)))
	if _hints != null:
		_hints.text = "Q / E  TABS    1-9  PICK    " + ("CLICK A CARD" if _selector_open else "TAB  CURSOR")
	# Details panel.
	if not structure.is_empty():
		_preview_stage.visible = false
		_details.reset_size()
		_details_group.text = "STRUCTURE"
		_details_title.text = str(structure.label)
		_details_text.text = str(structure.text)
		var structure_chips: Array = []
		if structure.id == "window": structure_chips = [[MHStyle.kg(BuildController.window_cargo()), MHStyle.TEXT_SECONDARY], ["Adds heat loss", MHStyle.WARN]]
		elif str(structure.id).begins_with("partition"): structure_chips = [["%s per 1.5 m panel" % MHStyle.kg(BuildController.partition_cargo()), MHStyle.TEXT_SECONDARY], ["Room stays one space for air and heat", MHStyle.INFO]]
		_set_chips(structure_chips)
		return
	var entry := EquipmentCatalog.get_entry(selected_id)
	_preview_stage.visible = true
	_preview_3d.show_item(selected_id)
	var group_label := ""
	for group in EquipmentCatalog.groups():
		if str(group.id) == str(entry.get("group", "")): group_label = str(group.get("label", ""))
	_details_group.text = group_label.to_upper()
	_details_title.text = str(entry.get("label", selected_id))
	_details_text.text = str(entry.get("description", entry.get("system_note", "")))
	_set_chips(_stat_chips(selected_id))

func _set_chips(chips: Array) -> void:
	for child in _details_chips.get_children(): child.queue_free()
	for chip in chips:
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.tint(chip[1], .14), MHStyle.tint(chip[1], .45), 12, 1, Vector4(10, 3, 10, 3)))
		pill.add_child(MHStyle.mono(str(chip[0]), 12, chip[1], 600))
		_details_chips.add_child(pill)

## What the item costs and does, from the balance spreadsheet.
func _stat_chips(id: String) -> Array:
	var item := MHResources.item(id)
	var chips: Array = [[MHStyle.kg(int(EquipmentCatalog.get_entry(id).get("cargo_cost", 0))), MHStyle.TEXT_SECONDARY]]
	var power := float(item.get("power_kw", 0.0))
	if power > 0.0: chips.append(["-%s kW" % _num(power) + (" (%d h a sol)" % int(item.hours_per_sol) if float(item.get("hours_per_sol", 24.0)) < 24.0 and float(item.get("hours_per_sol", 0.0)) > 0.0 else ""), MHStyle.WARN])
	for spec in [["o2_kg", "+%s kg O2 a sol", 1.0], ["water_l", "+%s L water a sol", 1.0], ["food_kg", "+%s kg food a sol", 1.0]]:
		var value := float(item.get(spec[0], 0.0))
		if value > 0.0: chips.append([str(spec[1]) % _num(value), MHStyle.VALID])
		elif value < 0.0 and spec[0] == "water_l": chips.append(["uses %s L water a sol" % _num(-value), MHStyle.INFO])
	if float(item.get("co2_kg", 0.0)) < 0.0: chips.append(["removes %s kg CO2 a sol" % _num(-float(item.co2_kg)), MHStyle.VALID])
	for spec in [["stores_kwh", "stores %s kWh"], ["stores_water_l", "holds %s L water"], ["stores_food_kg", "holds %s kg food"], ["stores_o2_kg", "holds %s kg O2"]]:
		if float(item.get(spec[0], 0.0)) > 0.0: chips.append([str(spec[1]) % _num(float(item[spec[0]])), MHStyle.INFO])
	if int(item.get("berths", 0)) > 0: chips.append(["%d berth" % int(item.berths), MHStyle.VALID])
	if id == "thermal_control_unit": chips.append(["moves up to %s kW of heat" % _num(float(item.get("heat_kw", 12.0))), MHStyle.VALID])
	if EquipmentCatalog.levels(id).size() > 0: chips.append(["warms its room", MHStyle.VALID])
	return chips

func _num(value: float) -> String:
	return str(snappedf(value, .01)).trim_suffix(".0")

