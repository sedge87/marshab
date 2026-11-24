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
var _sol_day: Label
var _telemetry_context: Label
var _telemetry_head: Label       # "Site telemetry", or "This room"
var _telemetry_place: Label
var _telemetry_elevation: Label
var _telemetry_note: Label       # indoors: how long the room's power and air last
var _telemetry_site := ""
var _runway_age := 99.0
var _runway_text := ""
var _battery_was := -1.0
var _battery_trend := 0.0
var _telemetry_key := ""
var _hint_strip: Control
var _hint_pad := false
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
	_minimal_nodes = [sol_clock]   # the compass stays: you can always orient yourself
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
	# The old Classic HUD panels stay hidden: the slate has all of it
	# (docs/pda.md §4). They go with the old sim (docs/systems-and-items.md §14).
	# The sol clock stays (playtest 10 Nov: it vanished after loading a save,
	# since only stepping out of the lander at the start ever showed it).
	for node in [_chip_slot, telemetry, _readiness_slot]: (node as CanvasItem).visible = false
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
	apply_hud_style()

## On screen: the crosshair, prompts, compass, notice line, warning icons
## and storm pill; the slate has the rest (docs/pda.md §4).
func apply_hud_style() -> void:
	if _hint_strip != null: _hint_strip.visible = not _key_rows.is_empty()
	_update_systems_panel()

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
	apply_hud_style()

## News while you're walking about (a core's result, a new plan, a crate
## unpacked): one line under the compass, kept in the slate's Log (MHNotices).
func flash_notice(tone: String, heading: String, text: String, app := "log") -> void:
	MHNotices.post(tone, heading, text, app)

## A how-to hint: on the one notice line now, readable (playthrough, 8 Nov).
func show_equipment_note(title: String, note: String) -> void:
	MHNotices.hint(title, note.replace(title.to_upper() + "\n", ""))
	if _note_title != null: _note_title.text = title.to_upper()   # what's being hinted (hide_equipment_note)

## Clears the note early if its title starts with this (e.g. "Carrying").
func hide_equipment_note(title_prefix: String) -> void:
	MHNotices.drop(title_prefix)
	if _note_title != null and _note_title.text.begins_with(title_prefix.to_upper()):
		_note_time_left = 0.0
		_note_panel.modulate.a = 0.0

func _site_telemetry() -> PanelContainer:
	var site: Dictionary = MHGame.site()
	var telemetry: Dictionary = site.get("telemetry", {})
	var panel := MHStyle.hud_panel(12, false, true)
	panel.position = Vector2(104, 174)
	panel.custom_minimum_size = Vector2(258, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := MHStyle.vbox(5)
	_telemetry_head = MHStyle.eyebrow("Site telemetry", MHStyle.accent, 10)
	column.add_child(_telemetry_head)
	var location := str(site.get("name", site.get("based_on", "Mars")))   # the region's own name (14 Nov: "Gale Crater" read as the wrong place)
	_telemetry_site = location
	_telemetry_place = MHStyle.mono(location, 13, MHStyle.TEXT_PRIMARY, 600)
	column.add_child(_telemetry_place)
	_telemetry_context = MHStyle.eyebrow("Outside · EVA exposure", MHStyle.TEXT_MUTED, 9)
	column.add_child(_telemetry_context)
	var first_row := MHStyle.hbox(14)
	_telemetry_temp = _telemetry_metric("TEMP", str(telemetry.get("temperature", "—")), MHStyle.INFO)
	first_row.add_child(_telemetry_temp.get_parent())
	_telemetry_elevation = _telemetry_metric("ELEVATION", str(telemetry.get("elevation", "—")), MHStyle.TEXT_SECONDARY)
	first_row.add_child(_telemetry_elevation.get_parent())
	column.add_child(first_row)
	var second_row := MHStyle.hbox(14)
	_telemetry_radiation = _telemetry_metric("RADIATION", str(telemetry.get("radiation", "—")), MHStyle.WARN)
	second_row.add_child(_telemetry_radiation.get_parent())
	_telemetry_sunlight = _telemetry_metric("SOLAR", "—", MHStyle.VALID)
	second_row.add_child(_telemetry_sunlight.get_parent())
	column.add_child(second_row)
	_telemetry_note = MHStyle.body("", 11, MHStyle.TEXT_SECONDARY)
	_telemetry_note.visible = false
	column.add_child(_telemetry_note)
	column.add_child(MHStyle.body("Shift estimates · hold Alt for your suit", 10, MHStyle.TEXT_MUTED) if preload("res://scripts/suit.gd").active() else MHStyle.body("Shift estimates · suit required outside", 10, MHStyle.TEXT_MUTED))
	panel.add_child(column)
	return panel

func _build_systems_panel() -> PanelContainer:
	_systems_panel = MHStyle.hud_panel(12, false, true)
	_systems_panel.set_meta("tutorial_target", "systems")
	_systems_panel.add_to_group("tutorial_target")
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
	if _rows_out != null:
		_rows_out[id] = {"text": text, "fraction": clampf(fraction, 0.0, 1.0), "tone": tone}
		return
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
	_systems_panel.visible = false   # the old Classic HUD panel: the slate's Base app has it
	if not _systems_panel.visible: return
	_systems_title.text = "HABITAT SYSTEMS · %d CREW%s" % [sim.crew_count(), " · DUST STORM" if bool(sim.last.get("storm", false)) else ""]
	_compute_rows(sim, inv)
	for child in _systems_warnings.get_children(): child.queue_free()
	var shown := 0
	for warning in sim.warnings():
		if shown >= 3 or str(warning.level) == "info": continue
		var line := MHStyle.body("• " + str(warning.text), 11, MHStyle.DANGER if str(warning.level) == "danger" else MHStyle.WARN)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(276, 0)
		_systems_warnings.add_child(line)
		shown += 1

## Battery, water, food, air and crew health: each row's words, how full
## and its tone (_set_system_row), for the panel or the slate's Base app.
func _compute_rows(sim: RefCounted, inv: Dictionary) -> void:
	var last: Dictionary = sim.last
	var flows: Dictionary = sim.daily_flows(false)
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
	var air_text := "O₂ %.1f%% · CO₂ %.2f%%" % [o2, co2]
	# Chapter one: the landed stores as sols left, first.
	if MHChapterOne.on():
		var left := MHChapterOne.sols_left(sim)
		water_text = "%s left · %d L" % [MHChapterOne.sols_text(float(left.water)), roundi(sim.water_l)]
		_set_system_row("water", water_text, float(sim.water_l) / maxf(1.0, water_cap), MHStyle.VALID if float(left.water) < 0.0 or float(left.water) > 20.0 else (MHStyle.WARN if float(left.water) > 5.0 else MHStyle.DANGER))
		_set_system_row("food", "%s left · %d kg" % [MHChapterOne.sols_text(float(left.food)), roundi(sim.food_kg)], minf(1.0, food_sols / 60.0), MHStyle.VALID if food_sols > 20.0 else (MHStyle.WARN if food_sols > 5.0 else MHStyle.DANGER))
		air_text = "O₂ stores %s left · CO₂ %.2f%%" % [MHChapterOne.sols_text(float(left.oxygen)), co2]
	_set_system_row("air", air_text, clampf(1.0 - co2 / 1.0, 0.0, 1.0), air_tone)
	var health := float(sim.crew_health)
	# Why it's changing: what's harming the crew (CO2, oxygen, cold, water,
	# food), or that it's recovering because everything is safe again.
	var causes: Array = sim.health_causes
	var trend := ""
	if not causes.is_empty(): trend = " · falling: " + ", ".join(causes)
	elif health < 99.5: trend = " · recovering"
	if not MHGame.crew_can_be_harmed(): trend = " · Freedom mode: no harm"
	_set_system_row("crew", "%d%%%s" % [roundi(health), trend], health / 100.0, MHStyle.DANGER if not causes.is_empty() and MHGame.crew_can_be_harmed() else (MHStyle.VALID if health > 70.0 else (MHStyle.WARN if health > 30.0 else MHStyle.DANGER)))

var _rows_out = null   # collecting rows for system_rows() instead of drawing them

## The habitat's rows for the slate's Base app: id -> {text, fraction, tone}
## ({} with no habitat or no simulation).
func system_rows() -> Dictionary:
	if builder == null or not MHGame.simulation_on(): return {}
	var sim: RefCounted = builder.simulation()
	var inv: Dictionary = sim.inventory()
	if int(inv.get("cells", 0)) <= 0: return {}
	_rows_out = {}
	_compute_rows(sim, inv)
	var out: Dictionary = _rows_out
	_rows_out = null
	return out

## The sol clock time after some game hours, e.g. "04:30".
func _clock_after(hours: float) -> String:
	if hours > 48.0: return "in %d sols" % floori(hours / 24.6)
	var at := fmod(MHGame.sol_hour + hours, 24.0)
	return "%02d:%02d" % [int(at), int(fmod(at, 1.0) * 60.0)]

func _build_sol_clock() -> PanelContainer:
	var panel := MHStyle.hud_panel(7, false, true)
	panel.anchor_left = .5
	panel.anchor_right = .5
	panel.offset_left = -104
	panel.offset_right = 104
	panel.offset_top = 108
	panel.offset_bottom = 142
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := MHStyle.hbox(7)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# The day tracker (8 Nov playtest): which sol it is, always.
	_sol_day = MHStyle.mono("SOL 1", 13, MHStyle.TEXT_PRIMARY, 700)
	row.add_child(_sol_day)
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
	_compass.markers = compass_markers()
	var suit: Node = get_tree().get_first_node_in_group("suit")
	_compass.sealed = suit != null and suit.has_method("wearing") and bool(suit.wearing())
	_compass.queue_redraw()
	_track_tag_update()
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
## Another mode's keys along the bottom (Interior furnishing), or [] for the
## walking keys again.
var _key_rows: Array = []
func set_key_strip(rows: Array) -> void:
	_key_rows = rows.duplicate()
	if _hint_strip != null: _hint_strip.queue_free()
	_hint_strip = null
	_refresh_hint_strip()

func _refresh_hint_strip() -> void:
	var inside := builder != null and builder.player_can_furnish()
	if _hint_strip != null and inside == _hint_inside and MHInput.pad == _hint_pad:
		return
	_hint_inside = inside
	_hint_pad = MHInput.pad
	if _hint_strip != null:
		_hint_strip.queue_free()
	if not _key_rows.is_empty():
		_hint_strip = MHStyle.hint_strip(_key_rows)
		_root.add_child(_hint_strip)
		_root.move_child(_hint_strip, 1)
		return
	var gary_here := get_tree().get_first_node_in_group("gar_y") != null
	var wrist_on: bool = preload("res://scripts/suit.gd").active()
	if MHInput.pad:   # 21 Nov: the same strip in the gamepad's buttons (scripts/mh_input.gd)
		_hint_strip = MHStyle.hint_strip([[["Left stick"], "Move"], [["L3"], "Sprint"], [["A"], "Jump"], [["R3"], "Crouch"], [["X"], "Use", "accent"], [["D-pad ↓"], "Light"]] + ([[["Y"], "GAR-Y"]] if gary_here else []) + [[["D-pad ←"], "Build"], [["View"], "Slate"], [["D-pad →"], "Map"]] + ([[["D-pad ↑"], "Wrist"]] if wrist_on else []) + [[["Menu"], "Pause"]])
	else:
		var build_hints: Array = [[["B"], "Furnish room"], [["Shift", "B"], "Site plan"]] if inside else [[["B"], "Site plan"]]
		var gary: Array = [[["G"], "Hold: GAR-Y"]] if gary_here else []
		_hint_strip = MHStyle.hint_strip([[["W", "A", "S", "D"], "Move"], [["Shift"], "Sprint"], [["Space"], "Jump"], [["Ctrl"], "Crouch"], [["E"], "Interact", "accent"], [["F"], "Light"]] + gary + build_hints + [[["Tab"], "Slate"]] + ([[["Alt"], "Wrist"]] if wrist_on else []) + [[["M"], "Base"], [["Esc"], "Pause"]])
	_root.add_child(_hint_strip)
	_hint_strip.visible = false
	# Keep the strip under the other HUD layers, where it was originally built.
	_root.move_child(_hint_strip, 1)

func _update_telemetry() -> void:
	if _telemetry_temp == null or builder == null:
		return
	# 23 Nov playtest: inside, the card read the outside's -32 °C and
	# "Sheltered". Where a room runs on its own life support (the lander
	# cabin, the walker core and the rooms joined to it), the card is that
	# room's: its air, its warmth, its power and how long they last.
	var life := _life_here()
	if not life.is_empty():
		_update_room_card(life)
		return
	_set_caption(_telemetry_temp, "TEMP")
	_set_caption(_telemetry_elevation, "ELEVATION")
	_set_caption(_telemetry_radiation, "RADIATION")
	_set_caption(_telemetry_sunlight, "SOLAR")
	_telemetry_note.visible = false
	var climate := builder.climate_at(player.global_position)
	var outside := str(climate.get("state", "")) == "outside"
	_telemetry_head.text = "Site telemetry" if outside else "This room"
	_telemetry_place.text = _telemetry_site
	_telemetry_elevation.text = str(MHGame.site().get("telemetry", {}).get("elevation", "—"))
	_telemetry_elevation.add_theme_color_override("font_color", MHStyle.TEXT_SECONDARY)
	var key := str([climate.temperature, climate.radiation, climate.context, MHGame.sol_hour, MHGame.sunlight_fraction, roundi(MHGame.solar_irradiance(MHGame.sol_hour) * 100.0)])
	if key == _telemetry_key:
		return
	_telemetry_key = key
	_telemetry_temp.text = "%d °C" % roundi(float(climate.temperature))
	var exposed := str(climate.radiation) == "High"
	_telemetry_radiation.text = "Exposed" if exposed else str(climate.radiation)
	_telemetry_radiation.add_theme_color_override("font_color", MHStyle.WARN if exposed else MHStyle.VALID)
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

const SURVIVAL_CORE := preload("res://scripts/survival_core.gd")

## The room you're in, if it runs on its own life support: {core, name}.
func _life_here() -> Dictionary:
	var world: Node = builder.get("world") if builder != null else null
	if world == null or player == null: return {}
	var lander: Node = world.get("lander")
	var cabin: Node = world.get("cabin_life")
	if cabin != null and cabin.get("core") != null and lander != null and lander.has_method("cabin_contains") and lander.cabin_contains(player.global_position):
		return {"core": cabin.get("core"), "name": "Lander cabin"}
	var module: Node = world.get("module_life")
	if module != null and module.get("core") != null and module.has_method("player_inside") and module.player_inside():
		var here: Dictionary = builder._zone_at_point(Vector2(player.global_position.x, player.global_position.z))
		var label := str(BuildController.ZONE_TYPES.get(str(here.get("kind", "")), {}).get("label", "Core"))
		if bool(here.get("carried", false)): label = "Walker core"
		return {"core": module.get("core"), "name": label}
	return {}

func _set_caption(value: Label, caption: String) -> void:
	if value == null: return
	var holder := value.get_parent()
	if holder != null and holder.get_child_count() > 0 and holder.get_child(0) is Label: (holder.get_child(0) as Label).text = caption

## Inside: air, temperature, power, and how long they last.
func _update_room_card(life: Dictionary) -> void:
	var core: RefCounted = life.core
	_telemetry_head.text = "This room"
	_telemetry_place.text = str(life.name)
	_set_caption(_telemetry_temp, "AIR")
	_set_caption(_telemetry_elevation, "TEMP")
	_set_caption(_telemetry_radiation, "POWER")
	_set_caption(_telemetry_sunlight, "OUTSIDE")
	var limits_o2: Array = SURVIVAL_CORE.O2_LIMITS
	var limits_cold: Array = SURVIVAL_CORE.COLD_LIMITS
	if bool(core.get("vented")):
		_telemetry_temp.text = "Vented"
		_telemetry_temp.add_theme_color_override("font_color", MHStyle.DANGER)
	else:
		var o2: float = core.call("o2_pct")
		var air: float = core.call("air_fraction")
		_telemetry_temp.text = "%.1f%% O2" % o2
		_telemetry_temp.add_theme_color_override("font_color", MHStyle.DANGER if o2 < float(limits_o2[1]) or air < .2 else (MHStyle.WARN if o2 < float(limits_o2[0]) or air < .6 else MHStyle.VALID))
	var temp: float = core.get("temp_c")
	_telemetry_elevation.text = "%d °C" % roundi(temp)
	_telemetry_elevation.add_theme_color_override("font_color", MHStyle.DANGER if temp < float(limits_cold[1]) else (MHStyle.WARN if temp < float(limits_cold[0]) else MHStyle.VALID))
	var powered := bool(core.call("powered"))
	var battery: float = core.call("battery_pct")
	_runway_age += get_process_delta_time()
	var fresh := _runway_age >= 5.0
	if fresh:
		if _battery_was >= 0.0: _battery_trend = battery - _battery_was
		_battery_was = battery
	var arrow := " ▲" if _battery_trend > .05 else (" ▼" if _battery_trend < -.05 else "")
	_telemetry_radiation.text = ("Flat" if not powered else "%d%%" % roundi(battery)) + arrow
	_telemetry_radiation.add_theme_color_override("font_color", MHStyle.DANGER if not powered or battery < 10.0 else (MHStyle.WARN if battery < 30.0 else MHStyle.VALID))
	var outside_c := MHGame.outside_temperature_c if MHGame.outside_temperature_c != 0.0 else float(MHGame.site().get("telemetry", {}).get("outside_temp_c", -30.0))
	_telemetry_sunlight.text = "%d °C" % roundi(outside_c)
	_telemetry_sunlight.add_theme_color_override("font_color", MHStyle.INFO)
	_telemetry_context.text = "Inside · %s" % MHGame.formatted_sol_time()
	# How long it lasts: the core's own look ahead, every 5 s (it runs a sol).
	if fresh:
		_runway_age = 0.0
		_runway_text = _runway_line(core.call("runway", MHGame.sol_hour, 24.0))
	_telemetry_note.text = _runway_text
	_telemetry_note.visible = not _runway_text.is_empty()
	_telemetry_key = ""

## The first thing to run out in the next sol, as a clock time.
func _runway_line(ahead: Dictionary) -> String:
	var first := ""
	var soonest := INF
	for key in ["power", "oxygen", "air", "cold"]:
		var t := float(ahead.get(key, -1.0))
		if t >= 0.0 and t < soonest:
			soonest = t
			first = key
	if first.is_empty(): return "Power, air and warmth good for the next sol"
	var at := wrapf(MHGame.sol_hour + soonest, 0.0, 24.0)
	var clock := "%02d:%02d" % [floori(at), floori(fmod(at, 1.0) * 60.0)]
	match first:
		"power": return "Power lasts till %s" % clock
		"oxygen": return "Oxygen runs thin by %s" % clock
		"air": return "Air goes stale by %s" % clock
	return "Too cold by %s" % clock

func _update_sol_clock() -> void:
	if _sol_clock == null:
		return
	var daytime := MHGame.sunlight_fraction > .08
	_sol_clock.text = "%s · %s" % [MHGame.formatted_sol_time(), "DAY" if daytime else "NIGHT"]
	if _sol_day != null and builder != null: _sol_day.text = "SOL %d" % (floori(float(builder.simulation().hours_run) / 24.0) + 1)
	if MHGame.resupplies_on() and builder != null:
		var due := MHGame.resupply_due_in_hours(builder.simulation().hours_run)
		_sol_clock.text += "  ·  RESUPPLY %s" % ("%d H" % ceili(due) if due < 24.0 else "%.1f SOLS" % (due / 24.0))
	_sol_clock.add_theme_color_override("font_color", MHStyle.INFO if daytime else MHStyle.TEXT_MUTED)

## Landmarks and airlocks for a compass, from where you are (the rover's
## driving HUD shows them too).
func compass_markers() -> Array:
	var out: Array = []
	_compass.show_distance = bool(MHGame.setting("compass_distance"))
	if bool(MHGame.setting("compass_home")): _home_markers(out)
	# Your pins, finds and places you know (scripts/known_things.gd), as Settings choose.
	var known := get_tree().get_first_node_in_group("known_things")
	if known != null:
		for marker in known.compass_markers(player.global_position):
			var shown: Variant = MHGame.setting("compass_" + str(marker.kind) + "s")   # no setting yet (the drone's markers, A7): shown
			if shown == null or bool(shown) or bool(marker.get("tracked", false)): out.append(marker)
	# 21 Nov playtest: the strip was clogged. Home, the nearest airlock and the
	# mark you're tracking always show; anything else only when it's near where
	# you're facing (the Compass widget then merges any that overlap).
	var heading := wrapf(rad_to_deg(-player.rotation.y), 0.0, 360.0)
	return out.filter(func(m): return bool(m.get("always", false)) or bool(m.get("tracked", false)) or absf(wrapf(float(m.bearing) - heading, -180.0, 180.0)) <= FACING_SPREAD)

const FACING_SPREAD := 35.0   # degrees either side of your heading where other marks show

func _home_markers(out: Array) -> void:
	for landmark in get_tree().get_nodes_in_group("landmark"):
		var spot := (landmark as Node3D).global_position - player.global_position
		out.append({"bearing": wrapf(rad_to_deg(atan2(spot.x, -spot.z)), 0.0, 360.0), "label": str(landmark.get_meta("landmark_label", "")), "distance": Vector2(spot.x, spot.z).length(), "always": landmark.is_in_group("home_landmark") or str(landmark.get_meta("landmark_label", "")).to_upper().contains("LANDER")})
	# Only the nearest way in (21 Nov: every base's doors crowded the strip).
	var best := {}
	for candidate in get_tree().get_nodes_in_group("airlock_door"):
		var door := candidate as Node3D
		if door == null or not door.has_method("door_label"): continue
		var door_name: String = door.call("door_label")
		if door_name != "OUTER" and door_name != "HANGAR": continue
		var offset := door.global_position - player.global_position
		var d := Vector2(offset.x, offset.z).length()
		if best.is_empty() or d < float(best.distance):
			best = {"bearing": wrapf(rad_to_deg(atan2(offset.x, -offset.z)), 0.0, 360.0), "label": "AIRLOCK" if door_name == "OUTER" else "HANGAR", "distance": d, "always": true}
	if not best.is_empty(): out.append(best)

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
			for claimer in get_tree().get_nodes_in_group("interaction_claims"):
				var claimed: String = claimer.call("claim_label", target)
				if not claimed.is_empty(): prompt = prompt.duplicate(); prompt["primary"] = claimed
			var actions: Array[String] = []
			for action in [[MHInput.glyph("use"), "primary"], [MHInput.glyph("lamp"), "secondary"], [MHInput.glyph("gar_y"), "tertiary"], [MHInput.glyph("sleep"), "sleep"], [MHInput.glyph("info"), "info"]]:
				var action_name := str(prompt.get(str(action[1]), ""))
				if not action_name.is_empty(): actions.append(("%s %s" % [str(action[0]), action_name]).strip_edges())
			var carry := get_tree().get_first_node_in_group("carry")
			var pickup: String = carry.call("pickup_key", target) if carry != null else ""
			if not pickup.is_empty(): actions.insert(mini(1, actions.size()), "%s Pick up" % pickup)
			_prompt_keys.text = "  ".join(actions)
			_prompt_verb.text = str(prompt.get("label", "Equipment"))
			_prompt_state.text = ""
		elif target.has_method("prompt_verb"):
			_prompt_keys.text = MHInput.glyph("use")
			_prompt_verb.text = str(target.call("prompt_verb"))
			_prompt_state.text = "· " + str(target.call("state_text"))
	# Riding Walker 1: how to get down (or use its nav), wherever you look.
	if not show:
		var ride := get_tree().get_first_node_in_group("riding_prompt")
		if ride != null and ride.has_method("ride_prompt"):
			var line: Dictionary = ride.ride_prompt()
			show = true
			_prompt_keys.text = str(line.get("keys", ""))
			_prompt_verb.text = str(line.get("verb", ""))
			_prompt_state.text = ("· " + str(line.secondary)) if line.has("secondary") else ""
	# Chapter one: outside with the hand corer and nothing in view.
	if not show:
		var corer := get_tree().get_first_node_in_group("hand_corer")
		if corer != null and not str(corer.call("prompt")).is_empty():
			show = true
			_prompt_keys.text = MHInput.glyph("use")
			_prompt_verb.text = str(corer.call("prompt_verb"))
			_prompt_state.text = ""
	# Chunk 2: the survey stakes in hand (scripts/survey_line.gd).
	if not show:
		var line := get_tree().get_first_node_in_group("survey_line")
		var said: String = line.call("prompt_text") if line != null else ""
		if not said.is_empty():
			show = true
			var can := said.begins_with("Plant")
			_prompt_keys.text = MHInput.glyph("use") if can else ""
			_prompt_verb.text = said
			_prompt_state.text = ""
	# Chunk 4: the wind logger in hand (scripts/chunk_four.gd).
	if not show:
		var four := get_tree().get_first_node_in_group("chunk_four")
		var logger_said: String = four.call("prompt_text") if four != null else ""
		if not logger_said.is_empty():
			show = true
			_prompt_keys.text = MHInput.glyph("use")
			_prompt_verb.text = logger_said
			_prompt_state.text = ""
	# Step 5: a rock to chip, or the ground at your feet to scoop.
	if not show:
		var tools := get_tree().get_first_node_in_group("sample_tools")
		var text: String = tools.call("prompt_text") if tools != null else ""
		if not text.is_empty():
			show = true
			_prompt_keys.text = "" if text == "Already sampled" else MHInput.glyph("use")
			_prompt_verb.text = text
			_prompt_state.text = ""
	# Chapter one: holding E on ground GAR-Y hasn't surveyed says why no core.
	if not show and MHInput.held("use") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var corer := get_tree().get_first_node_in_group("hand_corer")
		var why: String = corer.call("why_not") if corer != null else ""
		if not why.is_empty():
			show = true
			_prompt_keys.text = MHInput.glyph("use")
			_prompt_verb.text = "No core"
			_prompt_state.text = "· " + why
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
	# The story game (23 Nov playtest): the old builder's readiness list isn't
	# this game's goal. The goal lives on the slate's Today page.
	if MHChapterOne.new_rules():
		_readiness_slot.visible = false
		return
	_readiness_slot.visible = true
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


# ---------- the tracked mark's visor tag (21 Nov) ----------

const TAG_RANGE := 200.0   # metres: closer than this, the tracked mark gets a small tag in the visor
var _track_tag: Label

## A small diamond and distance over the tracked mark, once it's near enough to
## look for, so you can find it on the ground. Only the one you're tracking.
func _track_tag_update() -> void:
	if _track_tag == null:
		_track_tag = MHStyle.mono("", 14, MHStyle.accent, 700)
		_track_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_track_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, .7))
		_track_tag.add_theme_constant_override("outline_size", 4)
		_root.add_child(_track_tag)
	var known := get_tree().get_first_node_in_group("known_things")
	var camera := get_viewport().get_camera_3d()
	var entry: Dictionary = known.tracked_thing() if known != null and known.has_method("tracked_thing") else {}
	var show := not entry.is_empty() and camera != null and not bool(MHGame.setting("hud_minimal") if MHGame.setting("hud_minimal") != null else false)
	if show:
		var flat: Vector2 = (entry.at as Vector2) - (known.origin as Vector2)
		var spot := Vector3(flat.x, 0.0, flat.y)
		spot.y = preload("res://scripts/site_terrain.gd").height(spot.x, spot.z) + 2.0
		var metres := Vector2(spot.x - player.global_position.x, spot.z - player.global_position.z).length()
		show = metres <= TAG_RANGE and metres > 6.0 and not camera.is_position_behind(spot)
		if show:
			_track_tag.text = "◆ %s · %d m" % [str(entry.name), roundi(metres)]
			_track_tag.reset_size()
			_track_tag.position = camera.unproject_position(spot) - Vector2(9, _track_tag.size.y * .5)
	_track_tag.visible = show
