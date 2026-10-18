class_name MHExploreHUD
extends CanvasLayer

# First-person HUD (shot 1h): visor brackets, compass with airlock markers,
# colony chip, readiness panel (unmet items only), crosshair, interact prompt
# and the controls strip.

const INTERACT_RANGE := 2.8
const COLLAPSE_AFTER := 8.0

var player: Node3D
var builder: BuildController
var _root: Control
var _compass: MHWidgets.Compass
var _crosshair: MHWidgets.Crosshair
var _prompt: PanelContainer
var _prompt_keys: Label
var _prompt_verb: Label
var _prompt_state: Label
var _chip_slot: Control
var _chip_context := ""
var _readiness_slot: VBoxContainer
var _readiness_key := ""
var _readiness_age := 0.0
var _collapsed := false
var _telemetry_temp: Label
var _telemetry_radiation: Label
var _telemetry_sunlight: Label
var _sol_clock: Label
var _telemetry_context: Label
var _telemetry_key := ""

func setup(target_player: Node3D, target_builder: BuildController) -> void:
	player = target_player
	builder = target_builder
	builder.habitat_changed.connect(_refresh_readiness)

func _ready() -> void:
	name = "ExploreHUD"
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = MHStyle.theme()
	add_child(_root)
	var visor := MHWidgets.Visor.new()
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(visor)
	_root.add_child(MHStyle.hint_strip([[["W", "A", "S", "D"], "Move"], [["Shift"], "Sprint"], [["Space"], "Jump"], [["E"], "Interact", "accent"], [["B"], "Build"], [["M"], "Mission Control"], [["Esc"], "Pause"]]))
	# Compass, centred top inside the visor.
	var compass_band := CenterContainer.new()
	compass_band.anchor_right = 1
	compass_band.offset_top = 48
	compass_band.offset_bottom = 104
	compass_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(compass_band)
	_compass = MHWidgets.Compass.new()
	compass_band.add_child(_compass)
	_root.add_child(_build_sol_clock())
	# Colony chip, top-left inside the visor.
	_chip_slot = Control.new()
	_chip_slot.position = Vector2(104, 104)
	_chip_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chip_slot)
	# Compact site readout: useful context without competing with the build HUD.
	_root.add_child(_site_telemetry())
	# Readiness, top-right.
	_readiness_slot = MHStyle.vbox(0)
	_readiness_slot.anchor_left = 1
	_readiness_slot.anchor_right = 1
	_readiness_slot.offset_left = -524
	_readiness_slot.offset_right = -104
	_readiness_slot.offset_top = 104
	_readiness_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_readiness_slot)
	# Crosshair + interact prompt in the centre.
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	_crosshair = MHWidgets.Crosshair.new()
	centre.add_child(_crosshair)
	var prompt_band := CenterContainer.new()
	prompt_band.anchor_top = 0.5
	prompt_band.anchor_bottom = 0.5
	prompt_band.anchor_right = 1
	prompt_band.offset_top = 48
	prompt_band.offset_bottom = 104
	prompt_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(prompt_band)
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(8, 8, 18, 8)))
	_prompt.modulate.a = 0.0
	var prompt_row := MHStyle.hbox(12)
	_prompt_keys = MHStyle.mono("", 14, MHStyle.accent, 700)
	prompt_row.add_child(_prompt_keys)
	_prompt_verb = MHStyle.label("", 18, MHStyle.TEXT_PRIMARY, 600)
	prompt_row.add_child(_prompt_verb)
	_prompt_state = MHStyle.mono("", 14, MHStyle.TEXT_MUTED)
	_prompt_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_row.add_child(_prompt_state)
	_prompt.add_child(prompt_row)
	prompt_band.add_child(_prompt)
	_refresh_readiness()

func _site_telemetry() -> PanelContainer:
	var site: Dictionary = MHGame.site()
	var telemetry: Dictionary = site.get("telemetry", {})
	var panel := MHStyle.hud_panel(12, false, true)
	panel.position = Vector2(104, 174)
	panel.custom_minimum_size = Vector2(258, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := MHStyle.vbox(5)
	column.add_child(MHStyle.eyebrow("Site telemetry", MHStyle.accent, 10))
	var location := str(site.get("based_on", site.get("name", "Mars")))
	column.add_child(MHStyle.mono(location, 13, MHStyle.TEXT_PRIMARY, 600))
	_telemetry_context = MHStyle.eyebrow("Outside · EVA exposure", MHStyle.TEXT_MUTED, 9)
	column.add_child(_telemetry_context)
	var first_row := MHStyle.hbox(14)
	_telemetry_temp = _telemetry_metric("TEMP", str(telemetry.get("temperature", "—")), MHStyle.INFO)
	first_row.add_child(_telemetry_temp.get_parent())
	first_row.add_child(_telemetry_metric("ELEVATION", str(telemetry.get("elevation", "—")), MHStyle.TEXT_SECONDARY).get_parent())
	column.add_child(first_row)
	var second_row := MHStyle.hbox(14)
	_telemetry_radiation = _telemetry_metric("RADIATION", str(telemetry.get("radiation", "—")), MHStyle.WARN)
	second_row.add_child(_telemetry_radiation.get_parent())
	_telemetry_sunlight = _telemetry_metric("SUNLIGHT", str(telemetry.get("sunlight", "—")), MHStyle.VALID)
	second_row.add_child(_telemetry_sunlight.get_parent())
	column.add_child(second_row)
	column.add_child(MHStyle.body("Shift estimates · suit required outside", 10, MHStyle.TEXT_MUTED))
	panel.add_child(column)
	return panel

func _build_sol_clock() -> PanelContainer:
	var panel := MHStyle.hud_panel(7, false, true)
	panel.anchor_left = .5
	panel.anchor_right = .5
	panel.offset_left = -78
	panel.offset_right = 78
	panel.offset_top = 108
	panel.offset_bottom = 142
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := MHStyle.hbox(7)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(MHStyle.eyebrow("SOL", MHStyle.TEXT_MUTED, 10))
	_sol_clock = MHStyle.mono("08:00 · DAY", 13, MHStyle.INFO, 700)
	row.add_child(_sol_clock)
	panel.add_child(row)
	return panel

func _telemetry_metric(caption: String, value: String, colour: Color) -> Label:
	var metric := MHStyle.vbox(0)
	metric.custom_minimum_size = Vector2(104, 0)
	metric.add_child(MHStyle.eyebrow(caption, MHStyle.TEXT_MUTED, 9))
	var value_label := MHStyle.mono(value, 14, colour, 600)
	metric.add_child(value_label)
	return value_label

func _process(delta: float) -> void:
	if player == null or not visible: return
	_compass.heading = wrapf(rad_to_deg(-player.rotation.y), 0.0, 360.0)
	_compass.markers = _markers()
	_compass.queue_redraw()
	_update_chip()
	_update_telemetry()
	_update_sol_clock()
	_update_prompt()
	_readiness_age += delta
	if not _collapsed and _readiness_age > COLLAPSE_AFTER:
		_collapsed = true
		_render_readiness()

func _update_telemetry() -> void:
	if _telemetry_temp == null or builder == null:
		return
	var climate := builder.climate_at(player.global_position)
	var key := str([climate.temperature, climate.radiation, climate.context, MHGame.sol_hour, MHGame.sunlight_fraction])
	if key == _telemetry_key:
		return
	_telemetry_key = key
	_telemetry_temp.text = "%d °C" % roundi(float(climate.temperature))
	_telemetry_radiation.text = str(climate.radiation)
	_telemetry_radiation.add_theme_color_override("font_color", MHStyle.WARN if str(climate.radiation) == "High" else MHStyle.VALID)
	_telemetry_context.text = "%s · %s" % [str(climate.context), MHGame.formatted_sol_time()]
	if _telemetry_sunlight != null:
		_telemetry_sunlight.text = "%d%%" % roundi(MHGame.sunlight_fraction * 100.0)
		_telemetry_sunlight.add_theme_color_override("font_color", MHStyle.VALID if MHGame.sunlight_fraction > .1 else MHStyle.TEXT_MUTED)

func _update_sol_clock() -> void:
	if _sol_clock == null:
		return
	var daytime := MHGame.sunlight_fraction > .08
	_sol_clock.text = "%s · %s" % [MHGame.formatted_sol_time(), "DAY" if daytime else "NIGHT"]
	_sol_clock.add_theme_color_override("font_color", MHStyle.INFO if daytime else MHStyle.TEXT_MUTED)

func _markers() -> Array:
	var out: Array = []
	for candidate in get_tree().get_nodes_in_group("airlock_door"):
		var door := candidate as Node3D
		if door == null or not door.has_method("door_label"): continue
		var door_name: String = door.call("door_label")
		if door_name != "OUTER" and door_name != "HANGAR": continue
		var offset := door.global_position - player.global_position
		out.append({"bearing": wrapf(rad_to_deg(atan2(offset.x, -offset.z)), 0.0, 360.0), "label": "AIRLOCK" if door_name == "OUTER" else "HANGAR", "distance": Vector2(offset.x, offset.z).length()})
	return out

func _update_chip() -> void:
	var context := "Explore · Outside · " + MHGame.site_name()
	var cell := Vector2i(roundi(player.global_position.x / BuildController.CELL), roundi(player.global_position.z / BuildController.CELL))
	for zone in builder.zones:
		if cell in zone.cells and str(zone.kind) != "solar":
			context = "Explore · " + str(BuildController.ZONE_TYPES[zone.kind].label)
	if context == _chip_context: return
	_chip_context = context
	for child in _chip_slot.get_children(): child.queue_free()
	_chip_slot.add_child(MHStyle.colony_chip(context))

func _update_prompt() -> void:
	var target := _looked_at_interactable()
	var show := target != null
	_crosshair.interact = show
	if show:
		if target.has_method("interaction_prompt"):
			var prompt: Dictionary = target.call("interaction_prompt")
			var actions: Array[String] = []
			for action in [["E", "primary"], ["F", "secondary"], ["G", "tertiary"]]:
				var action_name := str(prompt.get(str(action[1]), ""))
				if not action_name.is_empty(): actions.append("%s %s" % [str(action[0]), action_name])
			_prompt_keys.text = "  ".join(actions)
			_prompt_verb.text = str(prompt.get("label", "Equipment"))
			_prompt_state.text = ""
		elif target.has_method("prompt_verb"):
			_prompt_keys.text = "E"
			_prompt_verb.text = str(target.call("prompt_verb"))
			_prompt_state.text = "· " + str(target.call("state_text"))
	# 120 ms fade
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if show else 0.0, get_process_delta_time() / 0.12)

func _looked_at_interactable() -> Node:
	if player == null or bool(player.get_meta("build_mode_active", false)) or bool(player.get_meta("interior_build_active", false)) or bool(player.get_meta("surface_build_active", false)):
		return null
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null or not camera.is_inside_tree():
		return null
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z * INTERACT_RANGE)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var node := hit.get("collider") as Node if not hit.is_empty() else null
	while node != null:
		if node.has_meta("interaction_target"):
			var target := node.get_meta("interaction_target") as Node
			if target != null and (target.has_method("interaction_prompt") or target.has_method("prompt_verb")):
				return target
		if node.has_method("interaction_prompt") or node.has_method("prompt_verb"):
			return node
		node = node.get_parent()
	return null

func _refresh_readiness() -> void:
	var items := builder.readiness()
	var key := str(items)
	if key == _readiness_key: return
	_readiness_key = key
	_readiness_age = 0.0
	_collapsed = false
	_render_readiness()

func _render_readiness() -> void:
	for child in _readiness_slot.get_children(): child.queue_free()
	var items := builder.readiness()
	var met := builder.readiness_met()
	if _collapsed or met == items.size():
		var row := MHStyle.hbox(0)
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(MHStyle.badge("%d / %d ready" % [met, items.size()] if met < items.size() else "Habitat ready", "valid" if met == items.size() else "warn", true))
		_readiness_slot.add_child(row)
		return
	var panel := MHStyle.hud_panel(20, false, true)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := MHStyle.vbox(8)
	column.add_child(MHStyle.eyebrow("Mission readiness · %d / %d" % [met, items.size()], MHStyle.accent))
	column.add_child(MHStyle.title("Still needed", 22))
	for item in items:
		if item.status != "met": column.add_child(MHStyle.readiness_item(item))
	panel.add_child(column)
	_readiness_slot.add_child(panel)
