extends Control
const LANDING_PICKER_SCRIPT := preload("res://scripts/landing_picker.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# Title flow (shots 1a–1d): Title → Site select → Colony setup → Landing.
# The backdrop is the real Mars environment with a display-only colony built
# by the same BuildController, so it uses the game's modules and accent.

const WORLD_SCENE := "res://scenes/mars_world.tscn"
const ORIGINAL_ENVIRONMENT_SCRIPT := preload("res://scripts/original_mars_environment.gd")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/build_controller.gd")
const TIPS := [
	"A room only counts as shelter when a path of open cells connects it to an airlock.",
	"Airlocks need their inner end touching a room and their outer end facing Mars.",
	"Solar Arrays must be within 12 m of the habitat. Aim them north for full output.",
	"Every three cells of Living Quarters house two crew.",
	"Removing a zone refunds its full cargo mass, so experiment freely.",
	"Open Mission Control with M to see what your crew still needs."
]
# Camera presets from the reference scene: position, look-at, vertical FOV.
const CAMERAS := {
	"title": [Vector3(-25, 1.9, 17), Vector3(-1, 4.4, -14), 34.0],
	"hero": [Vector3(10.5, 1.25, 12.5), Vector3(.2, 2.4, 1.2), 36.0],
	"loading": [Vector3(46, 5.5, 36), Vector3(0, 2.5, -6), 26.0],
	"site-plains": [Vector3(95, 46, 95), Vector3(0, 0, -10), 34.0],
	"site-ridge": [Vector3(6, 52, 112), Vector3(0, 2, -30), 44.0],
	"site-crater": [Vector3(80, 46, 92), Vector3(-4, 0, -4), 44.0],
	"site-ice": [Vector3(95, 42, 95), Vector3(0, 0, -10), 34.0]
}

var backdrop: Node3D
var environment
var display_builder: BuildController
var camera: Camera3D
var marker: Node3D
var _site_preview_built := false
var _landing_label: Label
var ui_root: Control
var screen: Control
var screen_id := ""
var _camera_key := ""
var _camera_tween: Tween
var _time := 0.0
var _name_field: LineEdit
var _statement_field: TextEdit
var _land_button: Button
var _plaque_slot: Control
var _site_conditions: Control
var _site_buttons := {}
var _callout: Control
var _loading_meter: MHWidgets.Meter
var _tip_label: Label
var _tip_index := 0
var _load_started := 0
var _settings_panel: MHSettingsPanel

func _ready() -> void:
	MHGame.set_accent(MHGame.accent_index)
	theme = MHStyle.theme()
	_build_backdrop()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	show_screen("title")
	MHAudio.music("menu")
	MHAudio.ambience("menu")

func _process(delta: float) -> void:
	_time += delta
	if camera == null or (_camera_tween != null and _camera_tween.is_running()): return
	# Idle motion: slow dolly on the title, gentle ±8° orbit on the hero shot.
	var preset: Array = CAMERAS.get(_camera_key, CAMERAS["title"])
	if _camera_key == "title":
		camera.global_position = _safe(preset[0] + Vector3(sin(_time * .05) * 4.0, 0, 0))
		camera.look_at(preset[1])
	elif _camera_key == "hero":
		var target: Vector3 = preset[1]
		var offset: Vector3 = (preset[0] as Vector3) - target
		camera.global_position = _safe(target + offset.rotated(Vector3.UP, deg_to_rad(sin(_time * .12) * 8.0)))
		camera.look_at(target)
	if _callout != null and _callout.visible and marker != null:
		var p := camera.unproject_position(marker.global_position + Vector3(0, 8.6, 0))
		_callout.position = p - Vector2(26, _callout.size.y)
	if screen_id == "loading": _poll_loading()

func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel != null: return
	if screen_id == "site" and event is InputEventKey and event.pressed and not event.echo:
		var ids := _site_ids()
		var index := ids.find(MHGame.site_id)
		if event.keycode == KEY_DOWN: _choose_site(ids[(index + 1) % ids.size()])
		elif event.keycode == KEY_UP: _choose_site(ids[(index - 1 + ids.size()) % ids.size()])
	if event.is_action_pressed("ui_cancel"):
		if screen_id == "site": show_screen("title")
		elif screen_id == "colony": show_screen("site")
		elif screen_id == "landing": show_screen("colony")

# ---------- backdrop ----------
func _build_backdrop() -> void:
	backdrop = Node3D.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	environment = ORIGINAL_ENVIRONMENT_SCRIPT.new()
	environment.build("dusk")
	backdrop.add_child(environment)
	camera = Camera3D.new()
	camera.current = true
	camera.far = 3000.0
	backdrop.add_child(camera)
	MHGame.apply_settings(get_viewport(), environment.world_environment.environment, environment.sun, [])
	display_builder = BUILD_CONTROLLER_SCRIPT.new()
	display_builder.display_only = true
	backdrop.add_child(display_builder)
	marker = _landing_marker()
	backdrop.add_child(marker)
	_populate_colony.call_deferred()

func _populate_colony() -> void:
	# Terrain collision must exist before foundations can find the ground.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var living := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0)]
	display_builder.habitat_base_y = display_builder._proposed_base_y(living)
	display_builder.zones = [
		{"kind": "living", "cells": living, "door_direction": Vector2i(0, -1), "cost": 200},
		{"kind": "airlock", "cells": [Vector2i(0, 1)], "door_direction": Vector2i(0, 1), "cost": 50},
		{"kind": "corridor", "cells": [Vector2i(2, -1), Vector2i(3, -1)], "door_direction": Vector2i(0, -1), "cost": 100},
		{"kind": "science", "cells": [Vector2i(4, -2), Vector2i(5, -2), Vector2i(4, -1), Vector2i(5, -1)], "door_direction": Vector2i(0, -1), "cost": 200},
		{"kind": "hydroponics", "cells": [Vector2i(0, -3), Vector2i(1, -3), Vector2i(0, -2), Vector2i(1, -2)], "door_direction": Vector2i(0, -1), "cost": 200},
		{"kind": "solar", "cells": [Vector2i(3, 1)], "door_direction": Vector2i(0, -1), "cost": 50},
		{"kind": "solar", "cells": [Vector2i(5, 1)], "door_direction": Vector2i(0, -1), "cost": 50},
		{"kind": "solar", "cells": [Vector2i(7, -1)], "door_direction": Vector2i(0, -1), "cost": 50}
	]
	display_builder._rebuild()
	# Door status signs are for players, not the title shot.
	for label in display_builder.root.find_children("*", "Label3D", true, false): (label as Label3D).visible = false
	marker.visible = screen_id == "site"
	_set_camera(_camera_key, false)

func _landing_marker() -> Node3D:
	var group := Node3D.new()
	group.visible = false
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 16.0
	torus.outer_radius = 17.2
	torus.rings = 64
	ring.mesh = torus
	ring.scale = Vector3(1, .05, 1)
	ring.position.y = .4
	ring.material_override = MHGame.accent_material()
	group.add_child(ring)
	var mast := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .2
	cylinder.bottom_radius = .3
	cylinder.height = 8.0
	mast.mesh = cylinder
	mast.position.y = 4.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = MHStyle.FRAME_STEEL
	steel.metallic = .65
	steel.roughness = .38
	mast.material_override = steel
	group.add_child(mast)
	var beacon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .6
	sphere.height = 1.2
	beacon.mesh = sphere
	beacon.position.y = 8.4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = MHStyle.accent
	beacon.material_override = glow
	group.add_child(beacon)
	return group

func _safe(point: Vector3) -> Vector3:
	# Keep low cameras above the terrain.
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 200.0, point + Vector3.DOWN * 200.0, 1)
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty(): return point
	return Vector3(point.x, maxf(point.y, float(hit.position.y) + 1.4), point.z)

func _set_camera(key: String, animate := true) -> void:
	_camera_key = key
	var preset: Array = CAMERAS.get(key, CAMERAS["title"])
	var target_position := _safe(preset[0])
	var look: Vector3 = preset[1]
	var target_basis := Transform3D.IDENTITY.translated(target_position).looking_at(look, Vector3.UP).basis
	if _camera_tween != null: _camera_tween.kill()
	if not animate:
		camera.global_position = target_position
		camera.basis = target_basis
		camera.fov = preset[2]
		return
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "global_position", target_position, 1.2)
	_camera_tween.tween_property(camera, "quaternion", target_basis.get_rotation_quaternion(), 1.2)
	_camera_tween.tween_property(camera, "fov", float(preset[2]), 1.2)

# ---------- screens ----------
func show_screen(id: String) -> void:
	screen_id = id
	if screen != null: screen.queue_free()
	_callout = null
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(screen)
	marker.visible = id == "site"
	display_builder.root.visible = id != "site"
	match id:
		"title":
			environment.apply_palette("dusk"); _set_camera("title", false); _title_screen()
		"site":
			environment.apply_palette(MHGame.palette_name()); _set_camera("site-" + MHGame.site_id); _site_screen()
		"colony":
			environment.apply_palette("golden"); _set_camera("hero"); _colony_screen()
		"landing":
			environment.apply_palette(MHGame.palette_name()); _set_camera("hero"); _landing_screen()
		"loading":
			environment.apply_palette("golden"); _set_camera("loading", false); _loading_screen()
	MHGame.apply_settings(get_viewport(), environment.world_environment.environment, environment.sun, [])
	# Menus slide in (360 ms), fades only — no bounce.
	screen.modulate.a = 0.0
	screen.position.x = -24.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "modulate:a", 1.0, .36)
	tween.tween_property(screen, "position:x", 0.0, .36)

func _scrim(direction: String, width_fraction: float, strength: float, hold := 0.0) -> MHWidgets.Fade:
	var fade := MHWidgets.Fade.new()
	fade.direction = direction
	fade.strength = strength
	fade.hold = hold
	fade.anchor_bottom = 1
	fade.anchor_right = width_fraction
	screen.add_child(fade)
	return fade

func _bottom_bar(height := 120.0) -> HBoxContainer:
	var fade := MHWidgets.Fade.new()
	fade.direction = "up"
	fade.strength = .92
	fade.anchor_right = 1
	fade.anchor_top = 1
	fade.anchor_bottom = 1
	fade.offset_top = -height
	screen.add_child(fade)
	var row := MHStyle.hbox(28)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 120
	row.offset_right = -120
	fade.add_child(row)
	return row

func _stepper(active: int) -> void:
	var row := MHStyle.hbox(32)
	row.position = Vector2(120, 64)
	for i in 3:
		var text := "%02d %s" % [i + 1, ["Site", "Colony", "Land"][i]]
		var step := MHStyle.eyebrow(text, MHStyle.accent if i == active else MHStyle.TEXT_MUTED, 16)
		if i == active:
			step.draw.connect(func() -> void: step.draw_rect(Rect2(0, step.size.y + 6, step.size.x, 2), MHStyle.accent))
		row.add_child(step)
	screen.add_child(row)

func _place(control: Control, pos: Vector2, width := 0.0) -> Control:
	control.position = pos
	if width > 0.0:
		control.custom_minimum_size.x = width
		control.size.x = width
	screen.add_child(control)
	return control

# 1a ---------------------------------------------------------------
func _title_screen() -> void:
	_scrim("right", .6, .88)
	var head := MHStyle.vbox(22)
	_place(head, Vector2(120, 140), 820)
	head.add_child(MHStyle.eyebrow("Year 9 · Mission to Mars", MHStyle.accent, 18))
	var mark := MHStyle.wordmark(136)
	head.add_child(mark)
	var pitch := MHStyle.body("Design a home for a crew of %s on %s of cargo. Then walk through it." % [MHStyle.count_word(BuildController.CREW_TARGET), MHStyle.kg(MHGame.mission_cargo_budget())], 26)
	pitch.custom_minimum_size.x = 600
	pitch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(pitch)
	var menu := MHStyle.vbox(12)
	_place(menu, Vector2(120, 620), 480)
	var hero := _hero_button("New colony", "Choose a site · name your colony", "plus")
	hero.pressed.connect(func() -> void:
		if MHGame.game_mode == "missions": MHGame.game_mode = "survival"
		show_screen("site"))
	menu.add_child(hero)
	# Missions: the NASA-style campaign, with its own saves.
	var campaign := MHGame.save_slot_summary(1, "missions")
	if bool(campaign.get("exists", false)):
		var resume := MHStyle.button("Continue missions · %s" % str(campaign.get("colony_name", "")), "secondary", "rocket")
		resume.alignment = HORIZONTAL_ALIGNMENT_LEFT
		resume.pressed.connect(_load_slot.bind(1, "missions"))
		menu.add_child(resume)
	var missions := MHStyle.button("New missions campaign" if bool(campaign.get("exists", false)) else "Missions campaign", "ghost" if bool(campaign.get("exists", false)) else "secondary", "clipboard-check")
	missions.alignment = HORIZONTAL_ALIGNMENT_LEFT
	missions.tooltip_text = "Set up a Mars base step by step, like NASA: landing zones, cargo first, then the crew."
	missions.pressed.connect(func() -> void:
		MHGame.game_mode = "missions"
		MHMissions.reset()
		show_screen("site"))
	menu.add_child(missions)
	var quick := MHStyle.button("Quick start · %s" % MHGame.site_name(), "secondary", "rocket")
	quick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quick.pressed.connect(func() -> void:
		MHGame.landing_target = Vector2.INF
		show_screen("loading"))
	menu.add_child(quick)
	# Saves sit in their own scrolling panel beside the menu, so a long list
	# never pushes the menu off the bottom of the screen. Mission saves and
	# free-play saves are kept apart (MHGame.SAVE_SETS).
	var saves := MHStyle.vbox(8)
	for save_set in ["missions", "free_play"]:
		var heading_added := false
		for slot in range(1, MHGame.SAVE_SLOT_COUNT + 1):
			var summary := MHGame.save_slot_summary(slot, save_set)
			if not bool(summary.get("exists", false)):
				continue
			if not heading_added:
				saves.add_child(MHStyle.eyebrow("%s saves" % MHGame.SAVE_SETS[save_set], MHStyle.TEXT_MUTED, 11))
				heading_added = true
			var save_row := MHStyle.hbox(6)
			var load := MHStyle.button("Load %d · %s" % [slot, str(summary.get("colony_name", "Habitat"))], "ghost", "save", 44)
			load.alignment = HORIZONTAL_ALIGNMENT_LEFT
			load.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			load.tooltip_text = "%s · saved at %s on %s" % [str(summary.get("mode", "")), str(summary.get("site_name", "Mars")), str(summary.get("saved_at", ""))]
			load.pressed.connect(_load_slot.bind(slot, save_set))
			save_row.add_child(load)
			# Delete: a second click confirms.
			var delete := MHStyle.button("", "ghost", "trash-2", 44)
			delete.tooltip_text = "Delete this save"
			delete.pressed.connect(func() -> void:
				if delete.text.is_empty():
					delete.text = "Delete?"
					delete.theme_type_variation = "DangerButton"
					return
				MHGame.delete_habitat(slot, save_set)
				show_screen(screen_id))
			save_row.add_child(delete)
			saves.add_child(save_row)
	if saves.get_child_count() > 0:
		var saves_panel := PanelContainer.new()
		saves_panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD, MHStyle.BORDER_SUBTLE, 8, 1, Vector4(16, 14, 16, 14)))
		saves_panel.position = Vector2(640, 620)
		saves_panel.custom_minimum_size = Vector2(380, 0)
		screen.add_child(saves_panel)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(348, minf(saves.get_combined_minimum_size().y, 330.0))
		saves_panel.add_child(scroll)
		saves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(saves)
	var row := MHStyle.hbox(12)
	var settings := MHStyle.button("Settings", "ghost", "settings")
	settings.pressed.connect(_open_settings)
	row.add_child(settings)
	var quit := MHStyle.button("Quit", "ghost", "log-out")
	quit.pressed.connect(func() -> void: get_tree().quit())
	row.add_child(quit)
	menu.add_child(row)
	var bar := _bottom_bar(72)
	var version := MHStyle.eyebrow("v0.6 · Offline build", MHStyle.TEXT_MUTED, 14)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(version)
	bar.add_child(MHStyle.spacer())
	for hint in [[["↑", "↓"], "Navigate"], [["Enter"], "Select"]]:
		var h := MHStyle.control_hint(hint[0], hint[1])
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(h)
	hero.grab_focus.call_deferred()

func _load_slot(slot: int, save_set := "") -> void:
	if MHGame.prepare_habitat_load(slot, save_set):
		show_screen("loading")

func _hero_button(title_text: String, meta: String, icon_name: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "PrimaryButton"
	b.custom_minimum_size = Vector2(480, 80)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var glow := MHStyle.box(MHStyle.accent, Color(0, 0, 0, 0))
	glow.shadow_color = Color(MHStyle.accent, .35)
	glow.shadow_size = 12
	b.add_theme_stylebox_override("normal", glow)
	var row := MHStyle.hbox(20)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -22
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var glyph := MHStyle.icon(icon_name, 28, MHStyle.TEXT_ON_ACCENT)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := MHStyle.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(MHStyle.label(title_text.to_upper(), 22, MHStyle.TEXT_ON_ACCENT, 800, false, 2))
	text.add_child(MHStyle.mono(meta, 14, MHStyle.TEXT_ON_ACCENT))
	row.add_child(text)
	var chevron := MHStyle.icon("chevron-right", 24, MHStyle.TEXT_ON_ACCENT)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	return b

func _open_settings() -> void:
	_settings_panel = MHSettingsPanel.new()
	_settings_panel.applied.connect(func() -> void: MHGame.apply_settings(get_viewport(), environment.world_environment.environment, environment.sun, []))
	_settings_panel.closed.connect(func() -> void: _settings_panel = null)
	add_child(_settings_panel)

# 1b ---------------------------------------------------------------
func _site_ids() -> Array:
	var ids: Array = []
	for entry in MHGame.sites(): ids.append(str(entry.id))
	return ids

func _site_screen() -> void:
	_scrim("right", .52, .9, .3)
	_stepper(0)
	_place(MHStyle.display("Choose a build site", 64), Vector2(120, 120))
	var list := MHStyle.vbox(14)
	_place(list, Vector2(120, 232), 660)
	_site_buttons.clear()
	var first: Button
	for entry in MHGame.sites():
		var card := _site_card(entry)
		list.add_child(card)
		_site_buttons[str(entry.id)] = card
		if first == null: first = card
	_site_conditions = MHStyle.vbox(0)
	_site_conditions.anchor_left = 1
	_site_conditions.anchor_right = 1
	_site_conditions.offset_left = -620
	_site_conditions.offset_right = -120
	_site_conditions.offset_top = 232
	screen.add_child(_site_conditions)
	_callout = MHStyle.vbox(0)
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(14, 10, 14, 10)))
	var tag_col := MHStyle.vbox(4)
	tag_col.add_child(MHStyle.eyebrow("Landing zone", MHStyle.accent, 13))
	_landing_label = MHStyle.label(MHSiteTerrain.describe_build_area(), 20, MHStyle.TEXT_PRIMARY, 700)
	tag_col.add_child(_landing_label)
	tag.add_child(tag_col)
	_callout.add_child(tag)
	var stem := ColorRect.new()
	stem.color = MHStyle.accent
	stem.custom_minimum_size = Vector2(2, 92)
	stem.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var stem_box := MarginContainer.new()
	stem_box.add_theme_constant_override("margin_left", 24)
	stem_box.add_child(stem)
	_callout.add_child(stem_box)
	screen.add_child(_callout)
	var bar := _bottom_bar()
	for hint in [[["↑", "↓"], "Change site"]]:
		var h := MHStyle.control_hint(hint[0], hint[1])
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(h)
	bar.add_child(MHStyle.spacer())
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_screen.bind("title"))
	bar.add_child(back)
	var next := MHStyle.button("Continue", "primary", "chevron-right", 52, true)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(show_screen.bind("colony"))
	bar.add_child(next)
	_choose_site(MHGame.site_id, false)
	next.grab_focus.call_deferred()

func _site_card(entry: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(660, 159)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(_choose_site.bind(str(entry.id)))
	var row := MHStyle.hbox(20)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 12
	row.offset_right = -12
	row.offset_bottom = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var thumb := _palette_thumb(str(entry.get("palette", "day")), str(entry.get("icon", "sun")))
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thumb)
	var text := MHStyle.vbox(8)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(MHStyle.title(str(entry.name), 28))
	text.add_child(MHStyle.body(str(entry.blurb), 18))
	var badges := MHStyle.hbox(8)
	for badge in MHGame.site_card(entry).badges: badges.add_child(MHStyle.badge(str(badge[0]), str(badge[1])))
	text.add_child(badges)
	row.add_child(text)
	return card

# Stand-in thumbnail: the site's sky-to-ground palette with its icon.
func _palette_thumb(palette_name: String, icon_name: String) -> Control:
	var values: Dictionary = MHGame.PALETTES.get(palette_name, MHGame.PALETTES["day"])
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(240, 135)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.draw.connect(func() -> void:
		var w := thumb.size.x
		var h := thumb.size.y
		var horizon := h * .58
		thumb.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]), PackedColorArray([values.sky_top, values.sky_top, values.sky_horizon, values.sky_horizon]))
		var ridge := PackedVector2Array([Vector2(0, horizon), Vector2(w * .18, horizon - 14), Vector2(w * .33, horizon - 6), Vector2(w * .52, horizon - 22), Vector2(w * .7, horizon - 9), Vector2(w, horizon - 16), Vector2(w, horizon)])
		thumb.draw_colored_polygon(ridge, (values.ground as Color).lightened(.18))
		thumb.draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]), PackedColorArray([(values.ground as Color).lightened(.1), (values.ground as Color).lightened(.1), (values.ground as Color).darkened(.35), (values.ground as Color).darkened(.35)])))
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.offset_bottom = -40
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(MHStyle.icon(icon_name, 34, Color(1, 1, 1, .9)))
	thumb.add_child(centre)
	return thumb

func _choose_site(id: String, move_camera := true) -> void:
	# Preview the chosen site's own generated landscape behind the menu.
	if MHGame.site_id != id or not _site_preview_built:
		MHGame.site_id = id
		environment.rebuild_site()
		_site_preview_built = true
	for site_key in _site_buttons:
		var card: Button = _site_buttons[site_key]
		var style := MHStyle.selected_box(0) if site_key == id else MHStyle.control_box(0)
		for state in ["normal", "pressed", "hover_pressed", "focus"]: card.add_theme_stylebox_override(state, style)
		card.add_theme_stylebox_override("hover", style if site_key == id else MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG))
	environment.apply_palette(MHGame.palette_name())
	MHGame.apply_settings(get_viewport(), environment.world_environment.environment, environment.sun, [])
	if move_camera: _set_camera("site-" + id)
	if _landing_label != null: _landing_label.text = MHSiteTerrain.describe_build_area()
	for child in _site_conditions.get_children(): child.queue_free()
	var site := MHGame.site()
	var panel := MHStyle.hud_panel(28, false, true)
	var col := MHStyle.vbox(18)
	col.add_child(MHStyle.eyebrow(str(site.name), MHStyle.accent))
	col.add_child(MHStyle.title("Site conditions", 26))
	for condition in MHGame.site_card(site).conditions:
		col.add_child(MHWidgets.Meter.new().setup(str(condition[0]), float(condition[1]), 10.0, "", str(condition[3])))
		var meter: MHWidgets.Meter = col.get_child(col.get_child_count() - 1)
		meter.value_label = str(condition[2])
	var location := str(site.get("based_on", ""))
	var coordinates := str(site.get("coordinates", ""))
	if not location.is_empty():
		var attribution := "Based on %s, Mars" % location
		if not coordinates.is_empty(): attribution += " · " + coordinates
		col.add_child(MHStyle.body(attribution + ".", 13, MHStyle.TEXT_MUTED))
	col.add_child(MHStyle.body("Terrain and balance are simplified for this learning simulation, rather than a scale NASA map.", 13, MHStyle.TEXT_MUTED))
	panel.add_child(col)
	_site_conditions.add_child(panel)

# 1c ---------------------------------------------------------------
func _colony_screen() -> void:
	_scrim("right", .5, .92, .34)
	_stepper(1)
	_place(MHStyle.display("Name your colony", 64), Vector2(120, 120))
	var form := MHStyle.vbox(28)
	_place(form, Vector2(120, 240), 640)
	# Colony name
	var name_box := MHStyle.vbox(8)
	name_box.add_child(MHStyle.eyebrow("Colony name"))
	_name_field = LineEdit.new()
	_name_field.max_length = 24
	_name_field.placeholder_text = "e.g. Kestrel Base"
	_name_field.text = MHGame.colony_name
	_name_field.custom_minimum_size.y = 56
	name_box.add_child(_name_field)
	var name_hint := MHStyle.hbox(8)
	var privacy := MHStyle.body("Shown on your HUD and mission plaque. Don't use your real name.", 15, MHStyle.TEXT_MUTED)
	privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hint.add_child(privacy)
	var counter := MHStyle.mono("", 13, MHStyle.TEXT_MUTED)
	name_hint.add_child(counter)
	name_box.add_child(name_hint)
	form.add_child(name_box)
	# Game mode: the cargo challenge, or free building.
	var mode_box := MHStyle.vbox(8)
	var mode_head := MHStyle.hbox(12)
	mode_head.add_child(MHStyle.eyebrow("Game mode"))
	mode_head.add_child(MHStyle.mono("Missions: from the title screen", 13, MHStyle.TEXT_MUTED))
	mode_box.add_child(mode_head)
	if MHGame.game_mode == "missions":
		mode_box.add_child(MHStyle.title("Missions campaign", 24))
	else:
		var modes := MHWidgets.Segmented.new().setup(MHGame.GAME_MODES.values(), str(MHGame.GAME_MODES.get(MHGame.game_mode, "Survival")), 44)
		modes.changed.connect(func(label: String) -> void:
			MHGame.game_mode = MHGame.GAME_MODES.find_key(label)
			show_screen("colony"))
		mode_box.add_child(modes)
	var cargo_note := " Land with %s of cargo." % MHStyle.kg(MHGame.mission_cargo_budget()) if not MHGame.cargo_unlimited() else ""
	var mode_note := "Set up your base step by step, the way NASA would: choose landing zones, send the cargo first, test everything, then land the crew." if MHGame.game_mode == "missions" else str(MHGame.GAME_MODE_NOTES.get(MHGame.game_mode, "")) + cargo_note
	mode_box.add_child(MHStyle.body(mode_note, 14, MHStyle.TEXT_MUTED))
	form.add_child(mode_box)
	# Missions: the student's name, only for the exported mission dossier.
	if MHGame.game_mode == "missions":
		var student_box := MHStyle.vbox(6)
		student_box.add_child(MHStyle.eyebrow("Your name (for your mission dossier)"))
		var student := LineEdit.new()
		student.max_length = 40
		student.placeholder_text = "Optional"
		student.text = MHMissions.student_name()
		student.custom_minimum_size.y = 44
		student.text_changed.connect(func(text: String) -> void: MHMissions.set_student_name(text))
		student_box.add_child(student)
		student_box.add_child(MHStyle.body("Only printed on your exported dossier. You can change it when you export.", 14, MHStyle.TEXT_MUTED))
		form.add_child(student_box)
	_name_field.text_changed.connect(func(text: String) -> void:
		MHGame.colony_name = text.strip_edges()
		counter.text = "%d / 24" % text.length()
		_refresh_plaque())
	counter.text = "%d / 24" % _name_field.text.length()
	# Emblem
	var emblem_box := MHStyle.vbox(12)
	emblem_box.add_child(MHStyle.eyebrow("Mission emblem"))
	var emblems := GridContainer.new()
	emblems.columns = 6
	emblems.add_theme_constant_override("h_separation", 12)
	for emblem in MHGame.EMBLEMS:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(96, 92)
		tile.icon = MHIcons.texture(emblem, 40)
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_theme_constant_override("icon_max_width", 40)
		tile.focus_mode = Control.FOCUS_NONE
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.tooltip_text = str(emblem).capitalize()
		var on: bool = emblem == MHGame.emblem
		var style := MHStyle.selected_box(0) if on else MHStyle.control_box(0)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]: tile.add_theme_stylebox_override(state, style if state != "hover" or on else MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG))
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]: tile.add_theme_color_override(state, MHStyle.accent if on else MHStyle.STRUCTURAL_WHITE)
		tile.pressed.connect(func() -> void: MHGame.emblem = emblem; show_screen("colony"))
		emblems.add_child(tile)
	emblem_box.add_child(emblems)
	form.add_child(emblem_box)
	# Accent
	var accent_box := MHStyle.vbox(12)
	var accent_head := MHStyle.hbox(12)
	accent_head.add_child(MHStyle.eyebrow("Colony accent"))
	accent_head.add_child(MHStyle.mono(str(MHStyle.COLONY_ACCENTS[MHGame.accent_index].label), 13, MHStyle.TEXT_SECONDARY))
	accent_box.add_child(accent_head)
	var swatches := MHStyle.hbox(12)
	for index in MHStyle.COLONY_ACCENTS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(56, 56)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swatch.tooltip_text = str(MHStyle.COLONY_ACCENTS[index].label)
		var colour: Color = MHStyle.COLONY_ACCENTS[index].colour
		var selected: bool = index == MHGame.accent_index
		var swatch_style := MHStyle.box(colour, MHStyle.INK_100 if selected else Color(0, 0, 0, 0), MHStyle.RADIUS_MD, 3)
		if selected:
			swatch_style.shadow_color = Color(colour, .5)
			swatch_style.shadow_size = 10
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]: swatch.add_theme_stylebox_override(state, swatch_style)
		swatch.pressed.connect(func() -> void:
			MHGame.set_accent(index)
			theme = MHStyle.theme()
			show_screen("colony"))
		swatches.add_child(swatch)
	accent_box.add_child(swatches)
	form.add_child(accent_box)
	# Mission statement
	var statement_box := MHStyle.vbox(8)
	statement_box.add_child(MHStyle.eyebrow("Mission statement (optional)"))
	_statement_field = TextEdit.new()
	_statement_field.text = MHGame.mission_statement
	_statement_field.placeholder_text = "Two modules, one airlock, and enough sunlight for everyone."
	_statement_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_statement_field.custom_minimum_size.y = 112
	_statement_field.add_theme_font_size_override("font_size", 19)
	statement_box.add_child(_statement_field)
	var statement_counter := MHStyle.mono("%d / 140" % _statement_field.text.length(), 13, MHStyle.TEXT_MUTED)
	statement_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	statement_box.add_child(statement_counter)
	_statement_field.text_changed.connect(func() -> void:
		if _statement_field.text.length() > 140:
			_statement_field.text = _statement_field.text.left(140)
			_statement_field.set_caret_column(140)
		MHGame.mission_statement = _statement_field.text
		statement_counter.text = "%d / 140" % _statement_field.text.length()
		_refresh_plaque())
	form.add_child(statement_box)
	# Live plaque
	_plaque_slot = MHStyle.vbox(0)
	_plaque_slot.anchor_left = 1
	_plaque_slot.anchor_right = 1
	_plaque_slot.offset_left = -540
	_plaque_slot.offset_right = -120
	_plaque_slot.offset_top = 140
	screen.add_child(_plaque_slot)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_screen.bind("site"))
	bar.add_child(back)
	_land_button = MHStyle.button("Choose where to land", "primary", "map-pin")
	_land_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_land_button.pressed.connect(show_screen.bind("landing"))
	bar.add_child(_land_button)
	_refresh_plaque()
	_name_field.grab_focus.call_deferred()
	_name_field.caret_column = _name_field.text.length()

func _refresh_plaque() -> void:
	if _land_button != null: _land_button.disabled = MHGame.colony_name.length() < 2
	for child in _plaque_slot.get_children(): child.queue_free()
	var panel := MHStyle.hud_panel(24, false, true)
	var col := MHStyle.vbox(16)
	col.add_child(MHStyle.eyebrow("Mission plaque · live", MHStyle.accent))
	var row := MHStyle.hbox(18)
	row.add_child(MHStyle.icon_tile(MHGame.emblem, 72, 40, MHStyle.accent, MHStyle.TEXT_ON_ACCENT, MHStyle.RADIUS_MD))
	var text := MHStyle.vbox(4)
	var shown := MHGame.colony_name if MHGame.colony_name.length() > 0 else "Unnamed colony"
	var name_label := MHStyle.label(shown.to_upper(), 30, MHStyle.TEXT_PRIMARY, 800, false, 1)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 280
	text.add_child(name_label)
	text.add_child(MHStyle.eyebrow("%s · Crew of %d" % [MHGame.site_name(), BuildController.CREW_TARGET], MHStyle.TEXT_MUTED, 14))
	row.add_child(text)
	col.add_child(row)
	if not MHGame.mission_statement.strip_edges().is_empty():
		col.add_child(MHStyle.body("“%s”" % MHGame.mission_statement.strip_edges(), 17, MHStyle.TEXT_PRIMARY))
	col.add_child(MHStyle.body("Rails, door frames and beacons on every module take your accent.", 16))
	panel.add_child(col)
	_plaque_slot.add_child(panel)

# 1c+ --------------------------------------------------------------
## Land step: pick the landing target on a top-down site map. The ellipse
## shows where the lander might touch down (Survival); Freedom and Creative
## land exactly on target.
func _landing_screen() -> void:
	_scrim("right", .62, .95, .4)
	_stepper(2)
	_place(MHStyle.display("Choose where to land", 64), Vector2(120, 120))
	var picker := LANDING_PICKER_SCRIPT.new()
	picker.position = Vector2(120, 230)
	picker.custom_minimum_size = Vector2(760, 600)
	picker.size = Vector2(760, 600)
	screen.add_child(picker)
	if MHMissions.active():
		_mission_one_panel(picker)
		return
	var panel := MHStyle.hud_panel(24, false, true)
	panel.position = Vector2(930, 230)
	panel.custom_minimum_size = Vector2(520, 0)
	var col := MHStyle.vbox(14)
	col.add_child(MHStyle.eyebrow("%s · %s" % [MHGame.site_name(), str(MHGame.GAME_MODES.get(MHGame.game_mode, ""))], MHStyle.accent))
	col.add_child(MHStyle.title("The landing ellipse", 28))
	var how := MHStyle.body("A lander can't touch down on an exact spot. It comes down somewhere inside the oval around your target: the landing ellipse. Pick flat, open ground with room to spare. Click or drag on the map.", 17)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)
	var mode_note := "Survival: your lander will touch down somewhere inside the ellipse." if not (MHGame.game_mode == "freedom" or MHGame.game_mode == "creative") else "%s: your lander will touch down exactly on the target." % str(MHGame.GAME_MODES.get(MHGame.game_mode, ""))
	var mode_label := MHStyle.body(mode_note, 16, MHStyle.TEXT_PRIMARY)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(mode_label)
	var status := MHStyle.body("", 17)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	var suggest := MHStyle.button("Use the suggested spot", "ghost", "map-pin")
	suggest.pressed.connect(picker.use_suggested)
	col.add_child(suggest)
	panel.add_child(col)
	screen.add_child(panel)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_screen.bind("colony"))
	bar.add_child(back)
	var land := MHStyle.button("Land at %s" % MHGame.site_name(), "primary", "rocket")
	land.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	land.pressed.connect(func() -> void:
		MHGame.landing_target = picker.target
		show_screen("loading"))
	bar.add_child(land)
	var show_verdict := func(_target: Vector2, verdict: Dictionary) -> void:
		status.text = str(verdict.get("text", ""))
		var level := str(verdict.get("level", "red"))
		status.add_theme_color_override("font_color", MHStyle.VALID if level == "green" else (MHStyle.WARN if level == "orange" else MHStyle.DANGER))
		land.disabled = level == "red"
	picker.target_changed.connect(show_verdict)
	show_verdict.call(picker.target, picker.verdict)

## Missions: the Land step is Mission 1, Landing Zones. Left-click sets the
## landing target, right-click the base site; both checks update live.
func _mission_one_panel(picker: Control) -> void:
	var mission := MHMissions.get_mission("landing_zones")
	picker.base_mode = true
	var panel := MHStyle.hud_panel(24, false, true)
	panel.position = Vector2(930, 230)
	panel.custom_minimum_size = Vector2(520, 0)
	var col := MHStyle.vbox(12)
	col.add_child(MHStyle.eyebrow("Mission 1 · %s" % str(mission.nasa_step), MHStyle.accent))
	col.add_child(MHStyle.title(str(mission.title), 28))
	var situation := MHStyle.body(str(mission.situation), 16)
	situation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(situation)
	col.add_child(MHStyle.mono("LEFT-CLICK  landing target    RIGHT-CLICK  base site", 12, MHStyle.TEXT_MUTED))
	var rows := MHStyle.vbox(8)
	col.add_child(rows)
	panel.add_child(col)
	screen.add_child(panel)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_screen.bind("colony"))
	bar.add_child(back)
	var confirm := MHStyle.button("Confirm landing zone", "primary", "rocket")
	confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm.pressed.connect(func() -> void:
		MHMissions.progress.landing_target = picker.target
		MHMissions.progress.base_site = picker.base_site
		MHMissions.complete("landing_zones")
		MHGame.landing_target = Vector2.INF
		show_screen("loading"))
	bar.add_child(confirm)
	var refresh := func(_target: Vector2, _verdict: Dictionary) -> void:
		for child in rows.get_children(): child.queue_free()
		var result: Dictionary = MHMissions.check_landing(picker.target, picker.base_site)
		for line in [[bool(result.landing_safe), str(mission.requirements[0].text), str(result.landing_text)], [bool(result.landing_clear), str(mission.requirements[1].text), str(result.clear_text)]]:
			var row := MHStyle.hbox(10)
			row.add_child(MHStyle.icon("circle-check" if line[0] else "circle-x", 20, MHStyle.VALID if line[0] else MHStyle.DANGER))
			var words := MHStyle.vbox(2)
			var head := MHStyle.body(line[1], 15, MHStyle.TEXT_PRIMARY)
			head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			head.custom_minimum_size.x = 420
			words.add_child(head)
			var detail := MHStyle.body(line[2], 13)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 420
			words.add_child(detail)
			row.add_child(words)
			rows.add_child(row)
		var stretch := MHStyle.body(("★ Stretch goal met: " if bool(result.close) else "☆ Stretch goal: ") + str(mission.stretch[0].text), 13, MHStyle.accent if bool(result.close) else MHStyle.TEXT_MUTED)
		stretch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stretch.custom_minimum_size.x = 440
		rows.add_child(stretch)
		confirm.disabled = not bool(result.passed)
	picker.target_changed.connect(refresh)
	refresh.call(picker.target, picker.verdict)

# 1d ---------------------------------------------------------------
func _loading_screen() -> void:
	if MHGame.colony_name.length() < 2: MHGame.colony_name = "Habitat One"
	for spec in [[0.0, 104.0], [-150.0, 0.0]]:
		var bar := ColorRect.new()
		bar.color = MHStyle.INK_950
		bar.anchor_right = 1
		if spec[1] > 0.0:
			bar.offset_bottom = spec[1]
		else:
			bar.anchor_top = 1
			bar.anchor_bottom = 1
			bar.offset_top = spec[0]
		screen.add_child(bar)
	var fade := MHWidgets.Fade.new()
	fade.direction = "up"
	fade.strength = .85
	fade.anchor_right = 1
	fade.anchor_top = 1
	fade.anchor_bottom = 1
	fade.offset_top = -470
	fade.offset_bottom = -150
	screen.add_child(fade)
	var title := MHStyle.vbox(10)
	title.anchor_top = 1
	title.anchor_bottom = 1
	title.offset_left = 120
	title.offset_top = -420
	title.offset_bottom = -190
	title.offset_right = 1600
	title.alignment = BoxContainer.ALIGNMENT_END
	screen.add_child(title)
	title.add_child(MHStyle.eyebrow("Touchdown · " + MHGame.site_name(), MHStyle.accent, 18))
	title.add_child(MHStyle.display(MHGame.colony_name, 104))
	var cargo_line := "%s cargo delivered" % MHStyle.kg(MHGame.mission_cargo_budget()) if not MHGame.cargo_unlimited() else "Creative · unlimited cargo"
	title.add_child(MHStyle.mono("Crew of %d · %s" % [BuildController.CREW_TARGET, cargo_line], 18, MHStyle.TEXT_SECONDARY))
	var lower := MHStyle.hbox(80)
	lower.anchor_top = 1
	lower.anchor_bottom = 1
	lower.anchor_right = 1
	lower.offset_left = 120
	lower.offset_right = -120
	lower.offset_top = -150
	screen.add_child(lower)
	var tip := MHStyle.hbox(18)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tile := MHStyle.icon_tile("lightbulb", 44, 24, MHStyle.tint(MHStyle.INFO, .14), MHStyle.INFO, MHStyle.RADIUS_MD)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip.add_child(tile)
	_tip_label = MHStyle.body("", 22)
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_child(_tip_label)
	lower.add_child(tip)
	_loading_meter = MHWidgets.Meter.new().setup("Unpacking cargo", 0.0, 100.0, "", "accent", true, 20)
	_loading_meter.custom_minimum_size = Vector2(480, 58)
	_loading_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lower.add_child(_loading_meter)
	_tip_index = randi() % TIPS.size()
	_tip_label.text = "Tip — " + TIPS[_tip_index]
	_load_started = Time.get_ticks_msec()
	MHAudio.sfx("landing", 0.0, 0.0)
	ResourceLoader.load_threaded_request(WORLD_SCENE)

func _poll_loading() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(WORLD_SCENE, progress)
	var elapsed := (Time.get_ticks_msec() - _load_started) / 1000.0
	# Tips rotate every 6 s while loading.
	var tip := int(elapsed / 6.0)
	if _tip_label != null: _tip_label.text = "Tip — " + TIPS[(_tip_index + tip) % TIPS.size()]
	# Hold the landing card long enough to read, even on fast machines.
	var shown := minf(float(progress[0]) if not progress.is_empty() else 0.0, elapsed / 1.8)
	if status == ResourceLoader.THREAD_LOAD_LOADED: shown = minf(1.0, elapsed / 1.8)
	_loading_meter.value = shown * 100.0
	_loading_meter.value_label = "%d %%" % roundi(shown * 100.0)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		get_tree().change_scene_to_file(WORLD_SCENE)
	elif status == ResourceLoader.THREAD_LOAD_LOADED and shown >= 1.0:
		screen_id = ""
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(WORLD_SCENE))
