class_name MHExploreHUD
extends CanvasLayer

const MHResources := preload("res://scripts/mh_resources.gd")

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
var _note_panel: PanelContainer
var _note_title: Label
var _note_body: Label
var _note_time_left := 0.0
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
var _hint_strip: Control
var _hint_inside := false
# Habitat systems panel (the life-support simulation's stores and warnings).
var _systems_panel: PanelContainer
var _systems_title: Label
var _systems_rows := {}
var _systems_warnings: VBoxContainer
var _systems_age := 1.0
# While the player is still in the lander only the crosshair, prompts and
# notes show; the rest fades in when they step outside (set_minimal).
var _minimal := false
var _minimal_nodes: Array = []
## "ROBOT" in Missions before the crew land (set by the world).
var chip_prefix := ""

func setup(target_player: Node3D, target_builder: BuildController) -> void:
	player = target_player
	builder = target_builder
	builder.habitat_changed.connect(_refresh_readiness)
	builder.power_changed.connect(_refresh_readiness.bind(true))

func _ready() -> void:
	name = "ExploreHUD"
	add_to_group("explore_hud")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = MHStyle.theme()
	add_child(_root)
	var visor := MHWidgets.Visor.new()
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(visor)
	_refresh_hint_strip()
	# Compass, centred top inside the visor.
	var compass_band := CenterContainer.new()
	compass_band.anchor_right = 1
	compass_band.offset_top = 48
	compass_band.offset_bottom = 104
	compass_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(compass_band)
	_compass = MHWidgets.Compass.new()
	compass_band.add_child(_compass)
	var sol_clock := _build_sol_clock()
	_root.add_child(sol_clock)
	_minimal_nodes = [compass_band, sol_clock]
	# Colony chip, top-left inside the visor.
	_chip_slot = Control.new()
	_chip_slot.position = Vector2(104, 104)
	_chip_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chip_slot)
	# Compact site readout: useful context without competing with the build HUD.
	var telemetry := _site_telemetry()
	_root.add_child(telemetry)
	_root.add_child(_build_systems_panel())
	_minimal_nodes += [_chip_slot, telemetry, _systems_panel]
	# Readiness, top-right.
	_readiness_slot = MHStyle.vbox(0)
	_readiness_slot.anchor_left = 1
	_readiness_slot.anchor_right = 1
	_readiness_slot.offset_left = -524
	_readiness_slot.offset_right = -104
	_readiness_slot.offset_top = 104
	_readiness_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_readiness_slot)
	_minimal_nodes.append(_readiness_slot)
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
	_build_equipment_note()
	_refresh_readiness()

func _build_equipment_note() -> void:
	var note_band := CenterContainer.new()
	note_band.anchor_top = .5
	note_band.anchor_bottom = .5
	note_band.anchor_right = 1
	note_band.offset_top = 110
	note_band.offset_bottom = 192
	note_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(note_band)
	_note_panel = PanelContainer.new()
	_note_panel.custom_minimum_size = Vector2(500, 0)
	_note_panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(12, 10, 16, 10)))
	_note_panel.modulate.a = 0.0
	var column := MHStyle.vbox(3)
	_note_title = MHStyle.eyebrow("", MHStyle.accent, 10)
	_note_body = MHStyle.body("", 14, MHStyle.TEXT_PRIMARY)
	_note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note_title)
	column.add_child(_note_body)
	_note_panel.add_child(column)
	note_band.add_child(_note_panel)

## Hide everything but the crosshair, prompts and notes (inside the lander at
## the start), or fade it all back in.
func set_minimal(on: bool) -> void:
	_minimal = on
	for node in _minimal_nodes:
		var control := node as CanvasItem
		if control == null: continue
		if on:
			control.visible = false
		else:
			control.visible = true
			control.modulate.a = 0.0
			create_tween().tween_property(control, "modulate:a", 1.0, 1.2)
	if not on: _update_systems_panel()

func show_equipment_note(title: String, note: String) -> void:
	if _note_panel == null or note.is_empty():
		return
	_note_title.text = title.to_upper()
	_note_body.text = note.replace(title.to_upper() + "\n", "")
	_note_time_left = 4.5
	_note_panel.modulate.a = 1.0

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
	_telemetry_sunlight = _telemetry_metric("SOLAR", "—", MHStyle.VALID)
	second_row.add_child(_telemetry_sunlight.get_parent())
	column.add_child(second_row)
	column.add_child(MHStyle.body("Shift estimates · suit required outside", 10, MHStyle.TEXT_MUTED))
	panel.add_child(column)
	return panel

func _build_systems_panel() -> PanelContainer:
	_systems_panel = MHStyle.hud_panel(12, false, true)
	_systems_panel.position = Vector2(104, 372)
	_systems_panel.custom_minimum_size = Vector2(300, 0)
	_systems_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := MHStyle.vbox(6)
	_systems_title = MHStyle.eyebrow("Habitat systems", MHStyle.accent, 10)
	column.add_child(_systems_title)
	for id in ["battery", "water", "food", "air", "crew"]:
		var row := MHStyle.vbox(2)
		var head := MHStyle.hbox(8)
		var caption := MHStyle.eyebrow({"battery": "Battery", "water": "Water", "food": "Food", "air": "Air", "crew": "Crew health"}[id], MHStyle.TEXT_MUTED, 9)
		caption.custom_minimum_size = Vector2(78, 0)
		head.add_child(caption)
		var value := MHStyle.mono("—", 12, MHStyle.TEXT_PRIMARY, 600)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(value)
		row.add_child(head)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, .08)
		track.custom_minimum_size = Vector2(0, 4)
		var fill := ColorRect.new()
		fill.color = MHStyle.VALID
		fill.custom_minimum_size = Vector2(0, 4)
		track.add_child(fill)
		row.add_child(track)
		column.add_child(row)
		_systems_rows[id] = {"value": value, "track": track, "fill": fill}
	_systems_warnings = MHStyle.vbox(3)
	column.add_child(_systems_warnings)
	_systems_panel.add_child(column)
	return _systems_panel

func _set_system_row(id: String, text: String, fraction: float, tone: Color) -> void:
	var row: Dictionary = _systems_rows[id]
	(row.value as Label).text = text
	(row.value as Label).add_theme_color_override("font_color", tone if tone != MHStyle.VALID else MHStyle.TEXT_PRIMARY)
	var fill: ColorRect = row.fill
	fill.color = tone
	fill.size = Vector2(maxf(0.0, (row.track as Control).size.x * clampf(fraction, 0.0, 1.0)), 4)

## Battery, water, food, air and crew health from the habitat simulation,
## with the most serious warnings (each says why).
func _update_systems_panel() -> void:
	if _systems_panel == null or builder == null: return
	var sim: RefCounted = builder.simulation()
	var inv: Dictionary = sim.inventory()
	_systems_panel.visible = MHGame.simulation_on() and int(inv.get("cells", 0)) > 0 and not _minimal
	if not _systems_panel.visible: return
	var last: Dictionary = sim.last
	var flows: Dictionary = sim.daily_flows(false)
	var crew: int = sim.crew_count()
	_systems_title.text = "HABITAT SYSTEMS · %d CREW%s" % [crew, " · DUST STORM" if bool(last.get("storm", false)) else ""]
	# Battery: charge and whether it is filling or draining.
	var capacity := float(inv.capacity.kwh)
	var rate := float(last.get("battery_rate_kw", 0.0))
	if capacity <= 0.0:
		_set_system_row("battery", "No battery bank", 0.0, MHStyle.WARN)
	else:
		var pct := float(sim.battery_kwh) / capacity
		var trend := "charging +%.1f kW" % rate if rate > .05 else ("−%.1f kW · empty ~%s" % [-rate, _clock_after(float(sim.battery_kwh) / -rate)] if rate < -.05 else "steady")
		_set_system_row("battery", "%d%% · %s" % [roundi(pct * 100.0), trend], pct, MHStyle.VALID if pct > .3 else (MHStyle.WARN if pct > .1 else MHStyle.DANGER))
	# Water and food: stored amount and how many sols it lasts.
	var water_net := float(flows.water_made) - float(flows.water_used)
	var water_cap := float(inv.capacity.water)
	var water_text := "%d L · %s" % [roundi(sim.water_l), ("+%d L a sol" % roundi(water_net) if water_net > 0.5 else "steady") if water_net >= 0.0 else "lasts %.1f sols" % (float(sim.water_l) / -water_net)]
	_set_system_row("water", water_text, float(sim.water_l) / maxf(1.0, water_cap), MHStyle.VALID if water_net >= 0.0 else (MHStyle.WARN if float(sim.water_l) / -water_net > 3.0 else MHStyle.DANGER))
	var food_net := float(flows.food_grown) - float(flows.food_eaten)
	var food_sols := float(sim.food_kg) / -food_net if food_net < 0.0 else 999.0
	_set_system_row("food", "%d kg · %s" % [roundi(sim.food_kg), "lasts %d sols" % floori(food_sols) if food_sols < 999.0 else "growing enough"], minf(1.0, food_sols / 60.0), MHStyle.VALID if food_sols > 20.0 else (MHStyle.WARN if food_sols > 5.0 else MHStyle.DANGER))
	var co2 := float(sim.co2_pct)
	var o2 := float(sim.o2_pct)
	var air_tone := MHStyle.DANGER if co2 > 1.0 or o2 < 19.5 else (MHStyle.WARN if co2 > .5 or o2 < 20.0 else MHStyle.VALID)
	_set_system_row("air", "O₂ %.1f%% · CO₂ %.2f%%" % [o2, co2], clampf(1.0 - co2 / 1.0, 0.0, 1.0), air_tone)
	var health := float(sim.crew_health)
	# Why it's changing: what's harming the crew (CO2, oxygen, cold, water,
	# food), or that it's recovering because everything is safe again.
	var causes: Array = sim.health_causes
	var trend := ""
	if not causes.is_empty(): trend = " · falling: " + ", ".join(causes)
	elif health < 99.5: trend = " · recovering"
	if not MHGame.crew_can_be_harmed(): trend = " · Freedom mode: no harm"
	_set_system_row("crew", "%d%%%s" % [roundi(health), trend], health / 100.0, MHStyle.DANGER if not causes.is_empty() and MHGame.crew_can_be_harmed() else (MHStyle.VALID if health > 70.0 else (MHStyle.WARN if health > 30.0 else MHStyle.DANGER)))
	for child in _systems_warnings.get_children(): child.queue_free()
	var shown := 0
	for warning in sim.warnings():
		if shown >= 3 or str(warning.level) == "info": continue
		var line := MHStyle.body("• " + str(warning.text), 11, MHStyle.DANGER if str(warning.level) == "danger" else MHStyle.WARN)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(276, 0)
		_systems_warnings.add_child(line)
		shown += 1

## The sol clock time after some game hours, e.g. "04:30".
func _clock_after(hours: float) -> String:
	if hours > 48.0: return "in %d sols" % floori(hours / 24.6)
	var at := fmod(MHGame.sol_hour + hours, 24.0)
	return "%02d:%02d" % [int(at), int(fmod(at, 1.0) * 60.0)]

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
	_refresh_hint_strip()
	_update_chip()
	_update_telemetry()
	_update_sol_clock()
	_systems_age += delta
	if _systems_age > .5:
		_systems_age = 0.0
		_update_systems_panel()
	_update_prompt()
	if _note_time_left > 0.0:
		_note_time_left = maxf(0.0, _note_time_left - delta)
		_note_panel.modulate.a = clampf(_note_time_left / .35, 0.0, 1.0)
	_readiness_age += delta
	if not _collapsed and _readiness_age > COLLAPSE_AFTER:
		_collapsed = true
		_render_readiness()

# The B hint names the build view it will actually open from where the player
# stands, and offers Shift+B for the Site plan while inside.
func _refresh_hint_strip() -> void:
	var inside := builder != null and builder.player_can_furnish()
	if _hint_strip != null and inside == _hint_inside:
		return
	_hint_inside = inside
	if _hint_strip != null:
		_hint_strip.queue_free()
	var build_hints: Array = [[["B"], "Furnish room"], [["Shift", "B"], "Site plan"]] if inside else [[["B"], "Site plan"]]
	var gary: Array = [[["G"], "Hold: GAR-Y"]] if get_tree().get_first_node_in_group("gar_y") != null else []
	_hint_strip = MHStyle.hint_strip([[["W", "A", "S", "D"], "Move"], [["Shift"], "Sprint"], [["Space"], "Jump"], [["Ctrl"], "Crouch"], [["E"], "Interact", "accent"], [["F"], "Light"]] + gary + build_hints + [[["M"], "Mission Control"], [["Esc"], "Pause"]])
	_root.add_child(_hint_strip)
	# Keep the strip under the other HUD layers, where it was originally built.
	_root.move_child(_hint_strip, 1)

func _update_telemetry() -> void:
	if _telemetry_temp == null or builder == null:
		return
	var climate := builder.climate_at(player.global_position)
	var key := str([climate.temperature, climate.radiation, climate.context, MHGame.sol_hour, MHGame.sunlight_fraction, roundi(MHGame.solar_irradiance(MHGame.sol_hour) * 100.0)])
	if key == _telemetry_key:
		return
	_telemetry_key = key
	_telemetry_temp.text = "%d °C" % roundi(float(climate.temperature))
	_telemetry_radiation.text = str(climate.radiation)
	_telemetry_radiation.add_theme_color_override("font_color", MHStyle.WARN if str(climate.radiation) == "High" else MHStyle.VALID)
	_telemetry_context.text = "%s · %s" % [str(climate.context), MHGame.formatted_sol_time()]
	if _telemetry_sunlight != null:
		# Share of full panel output available now: builds through the morning,
		# fades in the evening and drops early where terrain hides the sun.
		var solar := MHGame.solar_irradiance(MHGame.sol_hour)
		# A dust storm blocks much of the sunlight reaching the arrays.
		if builder != null and float(builder.simulation().storm_hours_left) > 0.0:
			solar *= 1.0 - float(builder.simulation().solar_cut())
		_telemetry_sunlight.text = "%d%%" % roundi(solar * 100.0)
		_telemetry_sunlight.add_theme_color_override("font_color", MHStyle.VALID if solar > .1 else MHStyle.TEXT_MUTED)

func _update_sol_clock() -> void:
	if _sol_clock == null:
		return
	var daytime := MHGame.sunlight_fraction > .08
	_sol_clock.text = "%s · %s" % [MHGame.formatted_sol_time(), "DAY" if daytime else "NIGHT"]
	if MHGame.resupplies_on() and MHGame.game_mode != "missions" and builder != null:
		var due := MHGame.resupply_due_in_hours(builder.simulation().hours_run)
		_sol_clock.text += "  ·  RESUPPLY %s" % ("%d H" % ceili(due) if due < 24.0 else "%.1f SOLS" % (due / 24.0))
	_sol_clock.add_theme_color_override("font_color", MHStyle.INFO if daytime else MHStyle.TEXT_MUTED)

func _markers() -> Array:
	var out: Array = []
	for landmark in get_tree().get_nodes_in_group("landmark"):
		var spot := (landmark as Node3D).global_position - player.global_position
		out.append({"bearing": wrapf(rad_to_deg(atan2(spot.x, -spot.z)), 0.0, 360.0), "label": str(landmark.get_meta("landmark_label", "")), "distance": Vector2(spot.x, spot.z).length()})
	for candidate in get_tree().get_nodes_in_group("airlock_door"):
		var door := candidate as Node3D
		if door == null or not door.has_method("door_label"): continue
		var door_name: String = door.call("door_label")
		if door_name != "OUTER" and door_name != "HANGAR": continue
		var offset := door.global_position - player.global_position
		out.append({"bearing": wrapf(rad_to_deg(atan2(offset.x, -offset.z)), 0.0, 360.0), "label": "AIRLOCK" if door_name == "OUTER" else "HANGAR", "distance": Vector2(offset.x, offset.z).length()})
	return out

func _update_chip() -> void:
	var context := chip_prefix + "ZONE · OUTSIDE · " + MHGame.site_name()
	var cell := Vector2i(roundi(player.global_position.x / BuildController.CELL), roundi(player.global_position.z / BuildController.CELL))
	for zone in builder.zones:
		if cell in zone.cells and str(zone.kind) != "solar":
			context = chip_prefix + "ZONE · " + str(BuildController.ZONE_TYPES[zone.kind].label).to_upper()
	# Inside a lander (the crew cabin or a cargo hold).
	for landmark in get_tree().get_nodes_in_group("landmark"):
		if (landmark.has_method("hold_contains") and landmark.hold_contains(player.global_position)) or (landmark.has_method("cabin_contains") and landmark.cabin_contains(player.global_position)):
			context = chip_prefix + "INSIDE · " + str(landmark.get_meta("landmark_label", "LANDER"))
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
			for action in [["E", "primary"], ["F", "secondary"], ["G", "tertiary"], ["Z", "sleep"], ["I", "info"]]:
				var action_name := str(prompt.get(str(action[1]), ""))
				if not action_name.is_empty(): actions.append("%s %s" % [str(action[0]), action_name])
			var carry := get_tree().get_first_node_in_group("carry")
			var pickup: String = carry.call("pickup_key", target) if carry != null else ""
			if not pickup.is_empty(): actions.insert(mini(1, actions.size()), "%s Pick up" % pickup)
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
	# Looking at a table, shelf or cabinet: something sitting on or in it may
	# be what you mean, even though the furniture's own collision box is hit
	# first (a shelf's box wraps everything on its shelves).
	if node != null and _placement_of(node) != "":
		var on_top := _item_on_furniture(camera.global_position, -camera.global_transform.basis.z, camera.global_position.distance_to(hit.position), _placement_of(node))
		if on_top != null: return on_top
	while node != null:
		if node.has_meta("interaction_target"):
			var target := node.get_meta("interaction_target") as Node
			if target != null and (target.has_method("interaction_prompt") or target.has_method("prompt_verb")):
				return target
		if node.has_method("interaction_prompt") or node.has_method("prompt_verb"):
			return node
		node = node.get_parent()
	return null

## The placed item a node belongs to ("" if none).
func _placement_of(node: Node) -> String:
	while node != null and not node.has_meta("interior_placement_id"): node = node.get_parent()
	return "" if node == null else str(node.get_meta("interior_placement_id"))

## The nearest raised item (not on the floor) the line of sight passes
## through, from just in front of the furniture that was hit to a little
## beyond it; its interactable, or null.
func _item_on_furniture(origin: Vector3, direction: Vector3, hit_distance: float, support_id: String) -> Node:
	if builder == null: return null
	var best_id := ""
	var nearest := hit_distance + 1.2
	for item in builder.placed_interior:
		var placement := str(item.get("placement_id", ""))
		if placement == support_id: continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if at.y < builder.habitat_base_y + .12: continue
		var size: Vector3 = builder._free_interior_size(EquipmentCatalog.get_entry(str(item.get("id", ""))))
		var turn := Basis(Vector3.UP, float(item.get("rotation_y", 0.0)))
		var centre := at + Vector3.UP * size.y * .5
		var local_origin: Vector3 = turn.inverse() * (origin - centre)
		var local_direction: Vector3 = turn.inverse() * direction
		var box := AABB(-size * .5 - Vector3.ONE * .04, size + Vector3.ONE * .08)
		var entry_point: Variant = box.intersects_ray(local_origin, local_direction)
		if entry_point == null: continue
		var distance := (entry_point as Vector3).distance_to(local_origin)
		if distance < nearest:
			nearest = distance
			best_id = placement
	if best_id.is_empty(): return null
	for holder in builder.furnishing.get_children():
		if not holder.has_meta("interior_placement_id") or str(holder.get_meta("interior_placement_id")) != best_id: continue
		if holder.has_method("interaction_prompt"): return holder
		for child in holder.find_children("*", "", true, false):
			if child.has_method("interaction_prompt") or child.has_method("prompt_verb"): return child
		return holder
	return null

func _refresh_readiness(quiet := false) -> void:
	var items := builder.readiness()
	var key := str(items)
	if key == _readiness_key: return
	_readiness_key = key
	# Layout changes pop the panel open; power drifting with the sun only
	# updates it in place.
	if not quiet:
		_readiness_age = 0.0
		_collapsed = false
	_render_readiness()

func _render_readiness() -> void:
	for child in _readiness_slot.get_children(): child.queue_free()
	if MHGame.game_mode == "missions": return   # the mission panel shows the requirements instead
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
