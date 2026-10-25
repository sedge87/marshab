class_name MHSettingsPanel
extends Control

# Settings sheet (shot 1l): Graphics, Audio and Controls tabs over a dimmed, blurred
# scene. Saves to user://settings.cfg and emits `applied` so the owner scene
# can update its sun, environment and cameras.

signal applied
signal closed

var _values := {}
var _preset_cards := {}
var _switches := {}
var _segments := {}
var _content: Control
var _tab_buttons := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_values = MHGame.settings()
	var scrim := MHWidgets.BlurScrim.new()
	scrim.set_dim(.8)
	add_child(scrim)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", MHStyle.menu_box(0))
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.offset_left = 120; sheet.offset_right = -120; sheet.offset_top = 100; sheet.offset_bottom = -100
	add_child(sheet)
	var columns := MHStyle.hbox(0)
	sheet.add_child(columns)
	# Tab rail
	var rail := PanelContainer.new()
	rail.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_950, Color(0, 0, 0, 0), 0, 0, Vector4(20, 40, 20, 40)))
	rail.custom_minimum_size.x = 300
	columns.add_child(rail)
	var tabs := MHStyle.vbox(6)
	rail.add_child(tabs)
	var heading := MHStyle.display("Settings", 36)
	heading.custom_minimum_size.y = 72
	tabs.add_child(heading)
	for tab in [["graphics", "Graphics", "monitor"], ["audio", "Audio", "volume-2"], ["controls", "Controls", "keyboard"]]:
		var b := MHStyle.button(tab[1], "ghost", tab[2])
		b.text = tab[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", MHStyle.font(600))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_show_tab.bind(tab[0]))
		tabs.add_child(b)
		_tab_buttons[tab[0]] = b
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: _content.add_theme_constant_override("margin_" + side, 56)
	for side in ["top", "bottom"]: _content.add_theme_constant_override("margin_" + side, 48)
	columns.add_child(_content)
	MHStyle.add_rail(sheet, 32)
	_show_tab("graphics")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _show_tab(tab: String) -> void:
	for id in _tab_buttons:
		(_tab_buttons[id] as Button).theme_type_variation = "SelectedButton" if id == tab else "GhostButton"
	for child in _content.get_children(): child.queue_free()
	if tab == "graphics": _content.add_child(_graphics())
	elif tab == "audio": _content.add_child(_audio())
	else: _content.add_child(_controls())

## Graphics presets and every Forward+ effect, each with what it costs.
const GRAPHICS_TOGGLES := [
	["shadows", "Sun shadows", "The biggest single cost. Turn off first if the game stutters."],
	["room_shadows", "Room light shadows", "Ceiling lights in the room you're in cast shadows. High and Ultra."],
	["ssao", "Ambient occlusion", "Soft contact shadows under furniture and in corners. Small cost."],
	["decals", "Dust and footprints", "Dust walked in at the airlocks. Very small cost."],
	["sdfgi", "Bounce light (SDFGI)", "Light bouncing off walls and floors. Beautiful but heavy: Ultra, or a fast graphics card."],
	["dynamic_resolution", "Dynamic resolution", "Below 30 frames a second, draws a little smaller for a while. Keeps busy moments smooth."],
	["dust", "Dust particles", "Only drawn within 10 m of the camera."],
	["weather", "Weather effects", "Storm haze, dusty skies and blowing dust. Storms still happen and are announced."],
	["glow", "Glow", "Bloom on lit windows, screens and beacons."],
]
const GAME_TOGGLES := [
	["gary_autonomy", "GAR-Y autonomy", "GAR-Y goes off surveying, naps at night, tidies up and checks on trouble."],
	["alert_advisories", "Habitat advisories", "Early heads-ups (like low batteries before sunset). Warnings and critical alerts always show."],
	["tutorial_cards", "How it works cards", "Short cards the first time you meet something new. They're always in the Field guide."],
	["live_hazards", "Hazards in play", "Rare solar storms, hull breaches and breakdowns in normal play, once their mission is passed (and in Survival)."],
]
const GRAPHICS_SEGMENTS := [
	["render_scale", "Render scale (FSR upscaling)", ["67 %", "85 %", "100 %"]],
	["reflections", "Reflections", ["Off", "Rooms", "Rooms + screen"]],
	["volumetric_fog", "Volumetric dust", ["Off", "Storms", "Always"]],
	["light_budget", "Lights at once", ["48", "96", "160", "256"]],
	["fov", "Field of view", ["70°", "80°", "90°"]],
]

func _graphics() -> Control:
	var grid := MHStyle.hbox(48)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(scroll)
	var form := MHStyle.vbox(32)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var preset_box := MHStyle.vbox(14)
	preset_box.add_child(MHStyle.eyebrow("Quality preset", MHStyle.TEXT_MUTED, 14))
	var cards := MHStyle.hbox(12)
	_preset_cards.clear()
	for preset in [["low", "Low", "Laptops. No shadows, 67 % scale."], ["medium", "Medium", "Good laptops. Shadows, soft corners, room reflections."], ["high", "High", "Graphics cards. Room light shadows, dust in the air."], ["ultra", "Ultra", "Fast graphics cards. Adds bounce light."]]:
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 116)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col := MHStyle.vbox(8)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 20; col.offset_top = 18; col.offset_right = -20
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := MHStyle.hbox(8)
		top.add_child(MHStyle.title(preset[1], 22))
		top.add_child(MHStyle.spacer())
		if preset[0] == MHGame.detected_preset(): top.add_child(MHStyle.badge("For this PC", "accent"))
		col.add_child(top)
		col.add_child(MHStyle.body(preset[2], 15))
		card.add_child(col)
		card.pressed.connect(_choose_preset.bind(preset[0]))
		cards.add_child(card)
		_preset_cards[preset[0]] = card
	preset_box.add_child(cards)
	form.add_child(preset_box)
	var segs := GridContainer.new()
	segs.columns = 2
	segs.add_theme_constant_override("h_separation", 24)
	segs.add_theme_constant_override("v_separation", 18)
	_segments.clear()
	for seg in GRAPHICS_SEGMENTS:
		var col2 := MHStyle.vbox(10)
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col2.add_child(MHStyle.eyebrow(seg[1], MHStyle.TEXT_MUTED, 14))
		var control := MHWidgets.Segmented.new().setup(seg[2], _segment_label(seg[0]))
		control.changed.connect(_on_segment.bind(seg[0]))
		col2.add_child(control)
		segs.add_child(col2)
		_segments[seg[0]] = control
	form.add_child(segs)
	var toggles := MHStyle.vbox(20)
	_switches.clear()
	for toggle in GRAPHICS_TOGGLES + [["", "", ""]] + GAME_TOGGLES:
		if str(toggle[0]).is_empty():
			toggles.add_child(MHStyle.eyebrow("Gameplay", MHStyle.TEXT_MUTED, 14))
			continue
		var row := MHStyle.hbox(18)
		var sw := MHWidgets.Switch.new()
		sw.button_pressed = bool(_values.get(toggle[0], false))
		sw.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		sw.toggled.connect(func(on: bool) -> void: _values[toggle[0]] = on; _values["preset"] = MHGame.matching_preset(_values); _refresh_cards())
		row.add_child(sw)
		var text := MHStyle.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(MHStyle.label(toggle[1], 19, MHStyle.TEXT_PRIMARY, 600))
		text.add_child(MHStyle.body(toggle[2], 15, MHStyle.TEXT_MUTED))
		row.add_child(text)
		toggles.add_child(row)
		_switches[toggle[0]] = sw
	form.add_child(toggles)
	# In a game: its tutorial, changed straight away (Full, Hints only, Off).
	var game := get_tree().get_first_node_in_group("habitat_world") if is_inside_tree() else null
	if game != null and game.has_method("set_tutorial_mode"):
		var tutorial_box := MHStyle.vbox(10)
		tutorial_box.add_child(MHStyle.eyebrow("Tutorial (this game)", MHStyle.TEXT_MUTED, 14))
		var choices := {"full": "Full", "hints": "Hints only", "off": "Off"}
		var tutorial_choice := MHWidgets.Segmented.new().setup(choices.values(), str(choices.get(MHGame.tutorial_mode, "Hints only")))
		tutorial_choice.changed.connect(func(label: String) -> void: game.set_tutorial_mode(str(choices.find_key(label))))
		tutorial_box.add_child(tutorial_choice)
		tutorial_box.add_child(MHStyle.body("Full: ARDEN's step-by-step guide and first-time hints. Hints only: just a card the first time you meet something new.", 15, MHStyle.TEXT_MUTED))
		form.add_child(tutorial_box)
	# Right column: what this machine is running + actions.
	var side := MHStyle.vbox(14)
	side.custom_minimum_size.x = 460
	side.add_child(MHStyle.eyebrow("This computer", MHStyle.TEXT_MUTED, 14))
	var tiles := GridContainer.new()
	tiles.columns = 2
	tiles.add_theme_constant_override("h_separation", 12)
	tiles.add_theme_constant_override("v_separation", 12)
	for tile in [["Renderer", "Forward+"], ["Window", "%d × %d" % [get_window().size.x, get_window().size.y]], ["Graphics card", RenderingServer.get_video_adapter_name().get_slice("(", 0).strip_edges().left(22)], ["Saved to", "settings.cfg"]]:
		var p := PanelContainer.new()
		p.theme_type_variation = "RaisedPanel"
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := MHStyle.vbox(4)
		v.add_child(MHStyle.eyebrow(tile[0], MHStyle.TEXT_MUTED, 12))
		var value := MHStyle.label(tile[1], 17, MHStyle.TEXT_PRIMARY, 600)
		value.clip_text = true
		v.add_child(value)
		p.add_child(v)
		tiles.add_child(p)
	side.add_child(tiles)
	side.add_child(MHStyle.body("Settings apply straight away and are remembered on this computer.", 15, MHStyle.TEXT_MUTED))
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(grow)
	var actions := MHStyle.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel := MHStyle.button("Cancel", "ghost")
	cancel.pressed.connect(_close)
	actions.add_child(cancel)
	var apply := MHStyle.button("Apply", "primary", "check")
	apply.pressed.connect(_apply)
	actions.add_child(apply)
	side.add_child(actions)
	grid.add_child(side)
	_refresh_cards()
	return grid

const VOLUME_STEPS := ["Off", "25 %", "50 %", "75 %", "100 %"]

func _audio() -> Control:
	var grid := MHStyle.hbox(48)
	var form := MHStyle.vbox(30)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(form)
	for row in [["vol_master", "Master", "Everything at once."], ["vol_music", "Music", "Slow synth score. It never repeats the same way twice."], ["vol_ambience", "Ambience", "Wind on the surface, life-support hum inside the habitat."], ["vol_sfx", "Effects", "Airlocks, building, footsteps and menu clicks."], ["vol_voice", "Habitat voice", "The habitat computer's spoken alerts and greetings."]]:
		var col := MHStyle.vbox(10)
		var text := MHStyle.hbox(12)
		text.add_child(MHStyle.label(row[1], 19, MHStyle.TEXT_PRIMARY, 600))
		var hint := MHStyle.body(row[2], 15, MHStyle.TEXT_MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(hint)
		col.add_child(text)
		var control := MHWidgets.Segmented.new().setup(VOLUME_STEPS, _volume_label(row[0]))
		control.changed.connect(_on_volume.bind(row[0]))
		col.add_child(control)
		form.add_child(col)
	var side := MHStyle.vbox(14)
	side.custom_minimum_size.x = 460
	side.add_child(MHStyle.eyebrow("Listening", MHStyle.TEXT_MUTED, 14))
	side.add_child(MHStyle.body("Changes play straight away so you can hear them. Apply keeps them; Cancel puts them back.", 15, MHStyle.TEXT_MUTED))
	var test := MHStyle.button("Play a test sound", "secondary", "volume-2")
	test.pressed.connect(func() -> void: MHAudio.sfx("door_open"))
	side.add_child(test)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(grow)
	var actions := MHStyle.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel := MHStyle.button("Cancel", "ghost")
	cancel.pressed.connect(_close)
	actions.add_child(cancel)
	var apply := MHStyle.button("Apply", "primary", "check")
	apply.pressed.connect(_apply)
	actions.add_child(apply)
	side.add_child(actions)
	grid.add_child(side)
	return grid

func _volume_label(key: String) -> String:
	return VOLUME_STEPS[clampi(roundi(float(_values.get(key, 80)) / 25.0), 0, 4)]

func _on_volume(value: String, key: String) -> void:
	_values[key] = VOLUME_STEPS.find(value) * 25
	MHAudio.apply_volumes(_values)

func _controls() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var columns := MHStyle.hbox(48)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	for group in MHGame.CONTROLS:
		var col := MHStyle.vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(MHStyle.eyebrow(group[0], MHStyle.accent, 14))
		for entry in group[1]: col.add_child(MHStyle.control_row(entry[0], entry[1]))
		columns.add_child(col)
	return scroll

const REFLECTION_LABELS := {"off": "Off", "probes": "Rooms", "ssr": "Rooms + screen"}
const FOG_LABELS := {"off": "Off", "storms": "Storms", "on": "Always"}

func _segment_label(key: String) -> String:
	match key:
		"render_scale":
			var scale := float(_values.get("render_scale", 1.0))
			return "67 %" if scale < .76 else ("85 %" if scale < .95 else "100 %")
		"reflections": return str(REFLECTION_LABELS.get(str(_values.get("reflections", "probes")), "Rooms"))
		"volumetric_fog": return str(FOG_LABELS.get(str(_values.get("volumetric_fog", "storms")), "Storms"))
		"light_budget": return str(int(_values.get("light_budget", 96)))
	return "%d°" % int(_values.get("fov", 70))

func _on_segment(value: String, key: String) -> void:
	match key:
		"render_scale": _values[key] = .67 if value.begins_with("67") else (.85 if value.begins_with("85") else 1.0)
		"reflections": _values[key] = str(REFLECTION_LABELS.find_key(value))
		"volumetric_fog": _values[key] = str(FOG_LABELS.find_key(value))
		"light_budget": _values[key] = int(value)
		_: _values[key] = int(value.trim_suffix("°"))
	_values["preset"] = MHGame.matching_preset(_values)
	_refresh_cards()

func _choose_preset(preset: String) -> void:
	for key in MHGame.PRESETS[preset]: _values[key] = MHGame.PRESETS[preset][key]
	_values["preset"] = preset
	for key in _switches: (_switches[key] as MHWidgets.Switch).set_pressed_no_signal(bool(_values[key]))
	for key in _switches: (_switches[key] as MHWidgets.Switch).queue_redraw()
	for key in _segments: (_segments[key] as MHWidgets.Segmented).select(_segment_label(key))
	_refresh_cards()

func _refresh_cards() -> void:
	var current := str(_values.get("preset", "custom"))
	for id in _preset_cards:
		var card: Button = _preset_cards[id]
		var style := MHStyle.selected_box(0) if id == current else MHStyle.control_box(0)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			card.add_theme_stylebox_override(state, style if state != "hover" or id == current else MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG))

func _apply() -> void:
	_values["preset"] = MHGame.matching_preset(_values)
	MHGame.save_settings(_values)
	applied.emit()
	_close()

func _close() -> void:
	# Drops any unapplied volume preview.
	MHAudio.apply_volumes()
	closed.emit()
	queue_free()
