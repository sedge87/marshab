extends Control
const MHSaves := preload("res://scripts/saves.gd")   # named saves, one file per base
const LANDING_PICKER_SCRIPT := preload("res://scripts/landing_picker.gd")
const REGION_LANDING_PICKER_SCRIPT := preload("res://scripts/region_landing_picker.gd")
const DESCENT_SCRIPT := preload("res://scripts/descent.gd")
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
	"Every three cells of Sleeping Quarters house two crew.",
	"Removing a zone refunds its full cargo mass, so experiment freely.",
	"Press M to raise your slate on Base: how the base is doing."
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

const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")
const CHALLENGE_UI := preload("res://scripts/challenge_options_ui.gd")
var backdrop: Node3D
var environment
var display_builder: BuildController
var camera: Camera3D
var marker: Node3D
var _site_preview_built := false
var _rebuild_wanted := 0   # counts site changes, so only the last one rebuilds the landscape
var _landing_label: Label
## Quick start goes straight to the landing map; Back returns to the title.
var _quick_start := false
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
	MHGame.migrate_old_saves()   # saves from when the game was called MARS: HABITAT
	MHSaves.migrate_once()   # the old numbered slots and habitat library become named saves
	MHSaves.playlist = []    # back at the menu: any Showcase has ended
	MHGame.showcase = false   # back at the menu: whatever loads next is a normal game unless Tour is pressed
	MHGame.set_accent(MHGame.accent_index)
	theme = MHStyle.theme()
	_build_backdrop()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	show_screen("title")
	# Drop save files (from another computer) on the window to add them.
	get_window().files_dropped.connect(_on_files_dropped)
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
		elif screen_id == "colony": show_screen("title")
		elif screen_id == "rules": show_screen("colony")
		elif screen_id == "landing": show_screen(_landing_back())

# ---------- backdrop ----------
func _build_backdrop() -> void:
	backdrop = Node3D.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	environment = ORIGINAL_ENVIRONMENT_SCRIPT.new()
	environment.preview = true
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
	# (From the heights: the backdrop's ground has no collision.)
	return Vector3(point.x, maxf(point.y, MHSiteTerrain.height(point.x, point.z) + 1.4), point.z)

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
	display_builder.root.visible = id != "site" and id != "descent"
	match id:
		"title":
			environment.apply_palette("dusk"); _set_camera("title", false); _title_screen()
		"site":
			environment.apply_palette(MHGame.palette_name()); _set_camera("site-" + MHGame.site_id); _site_screen()
		"colony":
			environment.apply_palette("golden"); _set_camera("hero"); _colony_screen()
		"rules":
			environment.apply_palette("golden"); _set_camera("hero"); _rules_screen()
		"landing":
			environment.apply_palette(MHGame.palette_name()); _set_camera("hero"); _landing_screen()
		"loading":
			environment.apply_palette("golden"); _set_camera("loading", false); _loading_screen()
		"descent":
			environment.apply_palette(MHGame.palette_name()); _camera_key = "descent"; _descent_screen()
		"saves":
			environment.apply_palette("dusk"); _set_camera("title", false); _saves_screen()
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

func _stepper(current: String) -> void:
	var row := MHStyle.hbox(32)
	row.position = Vector2(120, 64)
	# No site step (the Land step picks the spot on the region), but a Rules step.
	var steps := ["Colony", "Rules", "Arrive" if _arrives() else "Land"]
	var active := steps.find(current)
	for i in steps.size():
		var text := "%02d %s" % [i + 1, steps[i]]
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
	head.add_child(MHStyle.eyebrow("Build it · Live in it · Survive Mars", MHStyle.accent, 18))
	var mark := MHStyle.wordmark(136)
	head.add_child(mark)
	var pitch := MHStyle.body("Land with the crates sent ahead. Build a home for a crew of %s, live in it, and make it last." % MHStyle.count_word(BuildController.CREW_TARGET), 26)
	pitch.custom_minimum_size.x = 600
	pitch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(pitch)
	var newest := MHSaves.latest()
	var save_count := MHSaves.entries().size()
	var menu := MHStyle.vbox(12)
	var menu_y := 560.0 if not newest.is_empty() else 620.0
	_place(menu, Vector2(120, menu_y), 480)
	# Below the heading however many lines the wordmark and pitch wrap to.
	head.resized.connect(func() -> void: menu.position.y = maxf(menu_y, head.position.y + head.size.y + 36.0))
	# Continue: the newest save, in one click.
	if not newest.is_empty():
		var go_on := _hero_button("Continue", "%s · %s" % [str(newest.get("name", "Habitat")), MHSaves.mode_label(newest)], "play")
		go_on.tooltip_text = "%s · saved %s" % [str(newest.get("site_name", "Mars")), MHPauseMenu._when(str(newest.get("saved_at", "")))]
		go_on.pressed.connect(_open_save.bind(str(newest.path)))
		menu.add_child(go_on)
	var hero: Button = _hero_button("New colony", "Name your colony · choose where to land", "plus") if newest.is_empty() else MHStyle.button("New colony", "secondary", "plus")
	hero.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hero.pressed.connect(func() -> void:
		MHGame.set_mode(MHGame.game_mode)
		MHGame.tutorial_mode = MHGame.default_tutorial_mode()
		MHGame.start_new_challenge()
		MHSaves.current_path = ""
		_quick_start = false
		# Free play lands anywhere on the region: name the colony, then choose
		# where on the map (no site cards).
		_use_region_site()
		show_screen("colony"))
	menu.add_child(hero)
	# Load: every save, with pictures, search, Tour and Showcase.
	if save_count > 0:
		var load := MHStyle.button("Load · %d save%s" % [save_count, "" if save_count == 1 else "s"], "secondary", "save")
		load.alignment = HORIZONTAL_ALIGNMENT_LEFT
		load.tooltip_text = "Every saved base: play, tour, duplicate or showcase them"
		load.pressed.connect(func() -> void: show_screen("saves"))
		menu.add_child(load)
	var quick := MHStyle.button("Quick start · %s" % str(MHGame.picker_sites()[0].get("name", "Mars")), "ghost" if not newest.is_empty() else "secondary", "rocket")
	quick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quick.pressed.connect(func() -> void:
		# Straight to choosing where to land (skipping the site and colony steps).
		MHGame.set_mode(MHGame.game_mode)
		MHGame.landing_target = Vector2.INF
		MHGame.tutorial_mode = MHGame.default_tutorial_mode()
		MHGame.start_new_challenge()
		MHSaves.current_path = ""
		_quick_start = true
		_use_region_site()
		show_screen("landing"))
	menu.add_child(quick)
	var row := MHStyle.hbox(12)
	var settings := MHStyle.button("Settings", "ghost", "settings")
	settings.pressed.connect(_open_settings)
	row.add_child(settings)
	var guide := MHStyle.button("Field guide", "ghost", "book-open")
	guide.tooltip_text = "How the habitat's systems work"
	guide.pressed.connect(func() -> void: add_child(HOW_IT_WORKS.guide(get_tree())))
	row.add_child(guide)
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
	(menu.get_child(0) as Control).grab_focus.call_deferred()

# ---------- the Saves screen (scripts/saves.gd) ----------

var _saves_query := ""
var _saves_sort := 0            # see SAVES_SORTS
var _saves_note := ""
var _saves_grid: GridContainer
var _renaming := ""             # path of the card being renamed
const SAVES_SORTS := ["Newest first", "Name", "Builder", "Site", "Biggest", "Longest on Mars"]

func _saves_screen() -> void:
	_scrim("right", 1.0, .9)
	var head := MHStyle.vbox(10)
	_place(head, Vector2(120, 70), 1680)
	head.add_child(MHStyle.eyebrow("Every base, one file each", MHStyle.accent, 16))
	var title_row := MHStyle.hbox(16)
	head.add_child(title_row)
	title_row.add_child(MHStyle.display("Saves", 56))
	title_row.add_child(MHStyle.spacer())
	var showcase := MHStyle.button("Showcase", "primary", "presentation", 48)
	showcase.tooltip_text = "Tour every base shown here in turn, unattended, until a key is pressed (nothing is saved)"
	showcase.pressed.connect(_start_showcase)
	showcase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(showcase)
	var folder := MHStyle.button("Open folder", "ghost", "package", 48)
	folder.tooltip_text = MHSaves.directory()
	folder.pressed.connect(func() -> void: OS.shell_open(MHSaves.directory()))
	folder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(folder)
	var back := MHStyle.button("Back", "ghost", "chevron-left", 48)
	back.pressed.connect(func() -> void: show_screen("title"))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(back)
	var tools := MHStyle.hbox(12)
	head.add_child(tools)
	var search := LineEdit.new()
	search.placeholder_text = "Search names, builders and sites"
	search.text = _saves_query
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(460, 46)
	search.text_changed.connect(func(text: String) -> void:
		_saves_query = text
		_fill_saves())
	tools.add_child(search)
	var sort := OptionButton.new()
	for label in SAVES_SORTS: sort.add_item(label)
	sort.selected = _saves_sort
	sort.custom_minimum_size = Vector2(200, 46)
	sort.item_selected.connect(func(index: int) -> void:
		_saves_sort = index
		_fill_saves())
	tools.add_child(sort)
	var note := MHStyle.body(_saves_note if not _saves_note.is_empty() else "Saved in Documents/Outpost One/Saves. To bring bases from other computers, copy their files into that folder, or drop them on this window.", 15, MHStyle.TEXT_MUTED)
	if not _saves_note.is_empty(): note.add_theme_color_override("font_color", MHStyle.VALID)
	_saves_note = ""
	head.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(120, 300)
	scroll.size = Vector2(1700, 690)
	screen.add_child(scroll)
	_saves_grid = GridContainer.new()
	_saves_grid.columns = 3
	_saves_grid.add_theme_constant_override("h_separation", 20)
	_saves_grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(_saves_grid)
	_fill_saves()
	search.grab_focus.call_deferred()

## The saves shown, after search and the sort.
func _shown_saves() -> Array:
	var query := _saves_query.strip_edges().to_lower()
	var saves: Array = MHSaves.entries().filter(func(h):
		var words := " ".join([h.get("name", ""), h.get("builder", ""), h.get("site_name", ""), h.get("colony_name", "")]).to_lower()
		return query.is_empty() or words.contains(query))
	match _saves_sort:
		1: saves.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
		2: saves.sort_custom(func(a, b): return (str(a.get("builder", "")) + str(a.name)).naturalnocasecmp_to(str(b.get("builder", "")) + str(b.name)) < 0)
		3: saves.sort_custom(func(a, b): return str(a.site_name) + str(a.name) < str(b.site_name) + str(b.name))
		4: saves.sort_custom(func(a, b): return int(a.get("rooms", 0)) > int(b.get("rooms", 0)))
		5: saves.sort_custom(func(a, b): return int(a.get("sols", 0)) > int(b.get("sols", 0)))
	return saves

func _fill_saves() -> void:
	if _saves_grid == null or not is_instance_valid(_saves_grid): return
	for child in _saves_grid.get_children(): child.queue_free()
	var saves := _shown_saves()
	if saves.is_empty():
		_saves_grid.add_child(MHStyle.body("No saves yet." if _saves_query.strip_edges().is_empty() else "No saves match.", 20, MHStyle.TEXT_SECONDARY))
		return
	for save in saves: _saves_grid.add_child(_save_card(save))

func _save_card(save: Dictionary) -> Control:
	var path := str(save.path)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD, MHStyle.BORDER_SUBTLE, 10, 1, Vector4(12, 12, 12, 14)))
	card.custom_minimum_size = Vector2(540, 0)
	var col := MHStyle.vbox(6)
	card.add_child(col)
	var texture := MHSaves.thumbnail(save)
	if texture != null:
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(516, 290)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.texture = texture
		col.add_child(picture)
	else:
		var blank := PanelContainer.new()
		blank.custom_minimum_size = Vector2(516, 290)
		blank.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_950, MHStyle.BORDER_SUBTLE, 6))
		var glyph := MHStyle.icon("house", 48, MHStyle.TEXT_MUTED)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		blank.add_child(glyph)
		col.add_child(blank)
	if _renaming == path:
		var rename_box := LineEdit.new()
		rename_box.text = str(save.get("name", ""))
		rename_box.max_length = 60
		rename_box.custom_minimum_size = Vector2(516, 40)
		rename_box.text_submitted.connect(func(value: String) -> void:
			_renaming = ""
			if not value.strip_edges().is_empty(): MHSaves.rename(path, value)
			show_screen("saves"))
		col.add_child(rename_box)
		rename_box.grab_focus.call_deferred()
		rename_box.select_all.call_deferred()
	else:
		var name_label := MHStyle.label(str(save.get("name", "Habitat")), 20, MHStyle.TEXT_PRIMARY, 700)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size.x = 516
		col.add_child(name_label)
	var maker := str(save.get("builder", ""))
	col.add_child(MHStyle.body("by " + maker if not maker.is_empty() else "Builder not named", 15, MHStyle.accent if not maker.is_empty() else MHStyle.TEXT_MUTED))
	col.add_child(MHStyle.body("%s · %s" % [MHSaves.mode_label(save), save.get("site_name", "Mars")], 14, MHStyle.TEXT_SECONDARY))
	var size_line := "%d rooms · %d items" % [int(save.get("rooms", 0)), int(save.get("items", 0))]
	if save.has("crew"): size_line = "%d crew · %s" % [int(save.crew), size_line]
	if save.has("sols"): size_line += " · sol %d" % int(save.sols)
	col.add_child(MHStyle.body(size_line, 14, MHStyle.TEXT_MUTED))
	col.add_child(MHStyle.mono("Saved %s" % MHPauseMenu._when(str(save.get("saved_at", ""))), 12, MHStyle.TEXT_MUTED))
	var buttons := MHStyle.hbox(6)
	col.add_child(buttons)
	var play := MHStyle.button("Play", "primary", "play", 40)
	play.tooltip_text = "Carry on with this base (saving updates this save)"
	play.pressed.connect(_open_save.bind(path))
	buttons.add_child(play)
	var tour := MHStyle.button("", "ghost", "presentation", 40)
	tour.tooltip_text = "Tour: watch it present itself, or press F to fly round it (never saved)"
	tour.pressed.connect(func() -> void:
		MHSaves.playlist = []
		if MHSaves.prepare_load(path, true): show_screen("loading"))
	buttons.add_child(tour)
	var copy := MHStyle.button("", "ghost", "package", 40)
	copy.tooltip_text = "Duplicate: a separate copy of this save"
	copy.pressed.connect(func() -> void:
		var made := MHSaves.duplicate_save(path)
		_saves_note = ("Duplicated as \"%s\"." % str(MHSaves.read_header(made).get("name", ""))) if not made.is_empty() else "Couldn't duplicate it."
		show_screen("saves"))
	buttons.add_child(copy)
	var rename := MHStyle.button("", "ghost", "pencil", 40)
	rename.tooltip_text = "Rename (type the new name, then Enter)"
	rename.pressed.connect(func() -> void:
		_renaming = path
		show_screen("saves"))
	buttons.add_child(rename)
	buttons.add_child(MHStyle.spacer())
	var remove := MHStyle.button("", "ghost", "trash-2", 40)
	remove.tooltip_text = "Delete this save (its last few backups stay in Saves/Backups)"
	remove.pressed.connect(func() -> void:
		if remove.text.is_empty():
			remove.text = "Delete?"
			remove.theme_type_variation = "DangerButton"
			return
		MHSaves.remove(path)
		show_screen("saves"))
	buttons.add_child(remove)
	return card

## Showcase: tour every save shown, one after another (scripts/showcase.gd
## moves on to the next when a base's tour has played through).
func _start_showcase() -> void:
	var paths: Array = _shown_saves().map(func(h): return str(h.path))
	if paths.is_empty(): return
	MHSaves.playlist = paths
	MHSaves.playlist_index = 0
	if MHSaves.prepare_load(str(paths[0]), true): show_screen("loading")

func _on_files_dropped(files: PackedStringArray) -> void:
	if screen_id == "loading": return
	var added := MHSaves.import_files(files)
	_saves_note = ("Added %d save%s." % [added, "" if added == 1 else "s"]) if added > 0 else "Nothing added: drop Outpost One save files (.save) or older .habitat files."
	show_screen("saves")

## Play a save (Continue, a card's Play).
func _open_save(path: String) -> void:
	if MHSaves.prepare_load(path): show_screen("loading")

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
## A new free-play colony is on the region (the first site a colony can
## choose), whatever site the last game was on.
func _use_region_site() -> void:
	MHGame.base_site = {}
	if _site_ids().has(MHGame.site_id): return
	MHGame.site_id = str(_site_ids()[0])
	environment.rebuild_site()   # the backdrop: the region

func _site_ids() -> Array:
	var ids: Array = []
	for entry in MHGame.picker_sites(): ids.append(str(entry.id))
	return ids

func _site_screen() -> void:
	_scrim("right", .52, .9, .3)
	_stepper("Site")
	_place(MHStyle.display("Choose a build site", 64), Vector2(120, 120))
	# The sites scroll when there are more than fit.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(676, 720)
	scroll.size = scroll.custom_minimum_size
	_place(scroll, Vector2(120, 232))
	var list := MHStyle.vbox(14)
	list.custom_minimum_size.x = 660
	scroll.add_child(list)
	_site_buttons.clear()
	var first: Button
	for entry in MHGame.picker_sites():
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
	# An old save's site (or a hidden one) isn't on the list: start on the first.
	_choose_site(MHGame.site_id if _site_ids().has(MHGame.site_id) else str(_site_ids()[0]), false)
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

func _rebuild_site_if_last(wanted: int) -> void:
	if wanted == _rebuild_wanted: environment.rebuild_site()

func _choose_site(id: String, move_camera := true) -> void:
	# Preview the chosen site's own generated landscape behind the menu.
	# The landscape follows once the choice rests (holding an arrow key
	# through the list rebuilds it once, not at every card).
	if MHGame.site_id != id or not _site_preview_built:
		MHGame.site_id = id
		_site_preview_built = true
		_rebuild_wanted += 1
		get_tree().create_timer(.15).timeout.connect(_rebuild_site_if_last.bind(_rebuild_wanted))
	if _site_buttons.has(id) and is_instance_valid(_site_buttons[id]):
		var holder := (_site_buttons[id] as Control).get_parent().get_parent() as ScrollContainer
		if holder != null: holder.ensure_control_visible.call_deferred(_site_buttons[id])
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
	_stepper("Colony")
	_place(MHStyle.display("Name your colony", 64), Vector2(120, 120))
	var form := MHStyle.vbox(28)
	_place(form, Vector2(120, 240), 640)
	# The right column: the live plaque, then the emblem, accent and statement.
	var side := MHStyle.vbox(28)
	side.anchor_left = 1
	side.anchor_right = 1
	side.offset_left = -580
	side.offset_right = -120
	side.offset_top = 140
	screen.add_child(side)
	_plaque_slot = MHStyle.vbox(0)
	side.add_child(_plaque_slot)
	var picks_panel := MHStyle.hud_panel(24, false, true)
	var picks := MHStyle.vbox(22)
	picks_panel.add_child(picks)
	side.add_child(picks_panel)
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
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Beside it: what the habitat itself is called (it speaks under this name).
	var name_row := MHStyle.hbox(16)
	name_row.add_child(name_box)
	var voice_box := MHStyle.vbox(8)
	voice_box.custom_minimum_size.x = 200
	voice_box.add_child(MHStyle.eyebrow("Habitat's name"))
	var voice_field := LineEdit.new()
	voice_field.max_length = 12
	voice_field.placeholder_text = "ARDEN"
	voice_field.text = MHGame.habitat_name
	voice_field.custom_minimum_size.y = 56
	voice_field.tooltip_text = "Your habitat talks to you. This is what it's called."
	voice_field.text_changed.connect(func(text: String) -> void:
		MHGame.habitat_name = text.strip_edges().to_upper() if text.strip_edges().length() > 0 else "ARDEN")
	voice_box.add_child(voice_field)
	voice_box.add_child(MHStyle.body("It talks to you.", 15, MHStyle.TEXT_MUTED))
	name_row.add_child(voice_box)
	form.add_child(name_row)
	# Who's building: on every save's card and in Tour ("Designed by").
	# Remembered for next time.
	var maker := MHGame.maker()
	var maker_box := MHStyle.vbox(6)
	maker_box.add_child(MHStyle.eyebrow("Your name"))
	var maker_row := MHStyle.hbox(10)
	var player_box := LineEdit.new()
	player_box.max_length = 40
	player_box.placeholder_text = "Your name (optional)"
	player_box.text = str(maker.name) if not str(maker.name).is_empty() else ""
	player_box.custom_minimum_size.y = 44
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maker_row.add_child(player_box)
	var keep_maker := func(_text := "") -> void:
		MHGame.set_maker(player_box.text)
	player_box.text_changed.connect(keep_maker)
	maker_box.add_child(maker_row)
	maker_box.add_child(MHStyle.body("Shown on your saves and in Tour, so a showcase can say who built each base.", 14, MHStyle.TEXT_MUTED))
	form.add_child(maker_box)
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
		tile.custom_minimum_size = Vector2(64, 64)
		tile.icon = MHIcons.texture(emblem, 32)
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_theme_constant_override("icon_max_width", 32)
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
	picks.add_child(emblem_box)
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
	picks.add_child(accent_box)
	# Mission statement
	var statement_box := MHStyle.vbox(8)
	statement_box.add_child(MHStyle.eyebrow("Mission statement (optional)"))
	_statement_field = TextEdit.new()
	_statement_field.text = MHGame.mission_statement
	_statement_field.placeholder_text = "Two modules, one airlock, and enough sunlight for everyone."
	_statement_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_statement_field.custom_minimum_size.y = 88
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
	picks.add_child(statement_box)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: show_screen("title"))
	bar.add_child(back)
	_land_button = MHStyle.button("Next: rules", "primary", "chevron-right")
	_land_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_land_button.pressed.connect(show_screen.bind("rules"))
	bar.add_child(_land_button)
	_refresh_plaque()
	_name_field.grab_focus.call_deferred()
	_name_field.caret_column = _name_field.text.length()

## A new game whose rules land precursor crates (chapter one).
func _crates_mode() -> bool:
	return str(MHGame.rule("cargo")) == "crates"

## Where Back goes from the Land step.
func _landing_back() -> String:
	if _quick_start: return "title"
	return "rules"

# 1b+ --------------------------------------------------------------
## Rules step (docs/game-modes.md): four mode cards, the crew, the challenge,
## the rules (every row editable in Custom), and the tutorial.
func _rules_screen() -> void:
	_scrim("right", .5, .92, .34)
	_stepper("Rules")
	_place(MHStyle.display("How you'll play", 64), Vector2(120, 120))
	var cards := MHStyle.hbox(20)
	_place(cards, Vector2(120, 236), 1180)
	for mode in ["survival", "freedom", "creative", "custom"]:
		cards.add_child(_mode_card(mode))
	var below := MHStyle.hbox(40)
	_place(below, Vector2(120, 512), 1180)
	var left := MHStyle.vbox(24)
	left.custom_minimum_size.x = 560
	below.add_child(left)
	# The crew (crew_plan.gd): no choice since 7 Nov; the story's five wait in orbit.
	if _crates_mode():
		var crew_box := MHStyle.vbox(8)
		crew_box.add_child(MHStyle.eyebrow("Crew"))
		var crew_note := MHStyle.body("You land first and alone, to commission the base. The other %d wait in the orbiter until it's safe to bring them down." % MHCrewPlan.IN_ORBIT, 14, MHStyle.TEXT_MUTED)
		crew_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		crew_box.add_child(crew_note)
		left.add_child(crew_box)
	if left.get_child_count() == 0:
		var nothing := MHStyle.body("Nothing to survive, so no crew plan. Mission Control, samples and the Discoveries still run.", 16, MHStyle.TEXT_MUTED)
		nothing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(nothing)
	# The rules themselves: read-only, or every row for Custom.
	var right := MHStyle.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	below.add_child(right)
	var rules_head := MHStyle.hbox(12)
	rules_head.add_child(MHStyle.eyebrow("Rules"))
	rules_head.add_child(MHStyle.mono("Change any rule" if MHGame.game_mode == "custom" else "Pick Custom to change these", 13, MHStyle.TEXT_MUTED))
	right.add_child(rules_head)
	if MHGame.game_mode == "custom":
		var start_row := MHStyle.hbox(12)
		var start_label := MHStyle.body("Start from", 14, MHStyle.TEXT_MUTED)
		start_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		start_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		start_row.add_child(start_label)
		var presets := {"survival": "Survival", "freedom": "Freedom", "creative": "Creative"}
		var start := MHWidgets.Segmented.new().setup(presets.values(), "", 34)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.changed.connect(func(label: String) -> void:
			MHGame.rules = MHGame.preset(str(presets.find_key(label)))
			show_screen("rules"))
		start_row.add_child(start)
		right.add_child(start_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 300 if MHGame.game_mode == "custom" else 350
	var rows := CHALLENGE_UI.build_rules(false, func() -> void: show_screen("rules"))
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	right.add_child(scroll)
	# The side column: the tutorial and the challenge.
	var side := MHStyle.vbox(20)
	side.anchor_left = 1
	side.anchor_right = 1
	side.offset_left = -560
	side.offset_right = -120
	side.offset_top = 236
	screen.add_child(side)
	var tutorial_panel := MHStyle.hud_panel(24, false, true)
	tutorial_panel.add_child(_tutorial_choice())
	side.add_child(tutorial_panel)
	# Challenge options (docs/new-game-options.md): in the game, each can only be switched on.
	var challenge := CHALLENGE_UI.build(false, MHGame.remember_challenge)
	if challenge != null:
		var challenge_box := MHStyle.vbox(10)
		var challenge_head := MHStyle.hbox(12)
		challenge_head.add_child(MHStyle.eyebrow("Challenge"))
		challenge_head.add_child(MHStyle.mono("Can be switched on later, never off", 13, MHStyle.TEXT_MUTED))
		challenge_box.add_child(challenge_head)
		challenge_box.add_child(challenge)
		var challenge_panel := MHStyle.hud_panel(24, false, false)
		challenge_panel.add_child(challenge_box)
		side.add_child(challenge_panel)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	# The whole choice in one line.
	var summary := MHStyle.mono(_rules_summary(), 14, MHStyle.TEXT_SECONDARY)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(summary)
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_screen.bind("colony"))
	bar.add_child(back)
	var next := MHStyle.button("Arrival" if _arrives() else "Choose where to land", "primary", "rocket" if _arrives() else "map-pin")
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(show_screen.bind("landing"))
	bar.add_child(next)

## One mode's card: icon, name, pitch and what's on; click to pick it.
func _mode_card(mode: String) -> Control:
	var on := MHGame.game_mode == mode
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 240)
	card.add_theme_stylebox_override("panel", MHStyle.selected_box(18) if on else MHStyle.control_box(18))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not on:
			MHGame.set_mode(mode)
			MHGame.start_new_challenge()
			show_screen("rules"))
	var col := MHStyle.vbox(10)
	var head := MHStyle.hbox(12)
	head.add_child(MHStyle.icon_tile(str(MHGame.MODE_ICONS[mode]), 40, 22, MHStyle.accent if on else MHStyle.SURFACE_CONTROL_HOVER, MHStyle.TEXT_ON_ACCENT if on else MHStyle.STRUCTURAL_WHITE, MHStyle.RADIUS_SM))
	var name_label := MHStyle.title(str(MHGame.GAME_MODES[mode]), 24)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	col.add_child(head)
	var pitch := MHStyle.body(str(MHGame.GAME_MODE_NOTES.get(mode, "")), 14, MHStyle.TEXT_SECONDARY)
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.custom_minimum_size.y = 58
	col.add_child(pitch)
	if mode == "custom" and not on:
		var how := MHStyle.body("Start from a mode, then switch any rule on or off.", 14, MHStyle.TEXT_SECONDARY)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(how)
	else:
		var rules := MHGame.current_rules() if mode == "custom" else MHGame.preset(mode)
		for tick in CHALLENGE_UI.mode_ticks(rules):
			var row := MHStyle.hbox(8)
			row.add_child(MHStyle.icon("check" if bool(tick[0]) else "x", 15, MHStyle.VALID if bool(tick[0]) else MHStyle.TEXT_MUTED))
			var tick_label := MHStyle.body(str(tick[1]), 14, MHStyle.TEXT_PRIMARY if bool(tick[0]) else MHStyle.TEXT_MUTED)
			tick_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(tick_label)
			col.add_child(row)
	_ignore_mouse(col)
	card.add_child(col)
	return card

func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children(): if child is Control: _ignore_mouse(child)

## "Freedom · Rare surprises · Tutorial: Full".
func _rules_summary() -> String:
	var parts := [str(MHGame.GAME_MODES.get(MHGame.game_mode, ""))]
	var hard := MHGame.challenge_summary(MHGame.challenge, MHGame.game_mode) if not MHGame.challenge_options().is_empty() else ""
	if not hard.is_empty(): parts.append(hard)
	parts.append("Tutorial: %s" % str(TUTORIAL_CHOICES.get(MHGame.tutorial_mode, "Hints")))
	return " · ".join(parts)

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
	text.add_child(MHStyle.eyebrow("%s · Crew of %d" % [MHGame.site_name(), MHCrewPlan.final_size if _crates_mode() else BuildController.CREW_TARGET], MHStyle.TEXT_MUTED, 14))
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
	if MHSiteTerrain.shape() == "region" and _arrives():
		_arrival_screen()
		return
	if MHSiteTerrain.shape() == "region":
		_region_landing_screen()
		return
	_scrim("right", .62, .95, .4)
	_stepper("Land")
	_place(MHStyle.display("Choose where to land", 64), Vector2(120, 120))
	var picker := LANDING_PICKER_SCRIPT.new()
	picker.position = Vector2(120, 230)
	picker.custom_minimum_size = Vector2(760, 600)
	picker.size = Vector2(760, 600)
	screen.add_child(picker)
	var panel := MHStyle.hud_panel(24, false, true)
	panel.position = Vector2(930, 230)
	panel.custom_minimum_size = Vector2(520, 0)
	var col := MHStyle.vbox(14)
	col.add_child(MHStyle.eyebrow("%s · %s" % [MHGame.site_name(), str(MHGame.GAME_MODES.get(MHGame.game_mode, ""))], MHStyle.accent))
	col.add_child(MHStyle.title("The landing ellipse", 28))
	var how := MHStyle.body("A lander can't touch down on an exact spot. It comes down somewhere inside the oval around your target: the landing ellipse. Pick flat, open ground with room to spare. Click or drag on the map.", 17)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)
	var mode_note := "Your lander will touch down somewhere inside the ellipse." if str(MHGame.rule("landing")) != "target" else "Your lander will touch down exactly on the target."
	var mode_label := MHStyle.body(mode_note, 16, MHStyle.TEXT_PRIMARY)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(mode_label)
	var status := MHStyle.body("", 17)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	var suggest := MHStyle.button("Use the suggested spot", "ghost", "map-pin")
	suggest.pressed.connect(picker.use_suggested)
	col.add_child(suggest)
	if _quick_start: col.add_child(_tutorial_choice())   # quick start skips the Rules step
	panel.add_child(col)
	screen.add_child(panel)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: show_screen(_landing_back()))
	bar.add_child(back)
	var land := MHStyle.button("Land at %s" % MHGame.site_name(), "primary", "rocket")
	land.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	land.pressed.connect(func() -> void:
		MHGame.landing_target = picker.target
		MHGame.base_site = {}   # a new colony: founded at the site's named zone
		MHGame.cargo_at = Vector2.INF
		MHChapterOne.reset()   # a new free-play game: chapter rules, no crates (the revamp's pallets instead)
		show_screen("loading"))
	bar.add_child(land)
	var show_verdict := func(_target: Vector2, verdict: Dictionary) -> void:
		status.text = str(verdict.get("text", ""))
		var level := str(verdict.get("level", "red"))
		status.add_theme_color_override("font_color", MHStyle.VALID if level == "green" else (MHStyle.WARN if level == "orange" else MHStyle.DANGER))
		land.disabled = level == "red"
	picker.target_changed.connect(show_verdict)
	show_verdict.call(picker.target, picker.verdict)

## The Land step on a region site: the landing oval on the whole region map
## (docs/landing-and-base-siting.md §5.1). The base is founded where the
## lander touches down; until the descent is built, the autopilot picks the
## nearest good ground to the oval's centre.
func _region_landing_screen() -> void:
	_scrim("right", .62, .95, .4)
	_stepper("Land")
	_place(MHStyle.display("Choose where to land", 64), Vector2(120, 120))
	var picker := REGION_LANDING_PICKER_SCRIPT.new()
	picker.position = Vector2(120, 230)
	picker.custom_minimum_size = Vector2(760, 640)
	picker.size = Vector2(760, 640)
	screen.add_child(picker)
	var panel := MHStyle.hud_panel(24, false, true)
	panel.position = Vector2(930, 230)
	panel.custom_minimum_size = Vector2(520, 0)
	var col := MHStyle.vbox(14)
	col.add_child(MHStyle.eyebrow("%s · %s" % [MHGame.site_name(), str(MHGame.GAME_MODES.get(MHGame.game_mode, ""))], MHStyle.accent))
	col.add_child(MHStyle.title("The landing oval", 28))
	var how := MHStyle.body("Your lander can reach anywhere inside the oval on the way down, and your base is founded where it touches down. The two cargo landers came down at its centre months ago. Green dots are level, open ground for a base. Each spot trades water, sun, shelter, dust and room: the orbital report says how. Click or drag on the map.", 17)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)
	var status := MHStyle.body("", 17)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	# The orbital report: what living at the touchdown spot would be like.
	var report := MHStyle.vbox(6)
	col.add_child(report)
	if _quick_start: col.add_child(_tutorial_choice())   # quick start skips the Rules step
	# Every mode flies the descent; this box skips it.
	var skip := CheckBox.new()
	skip.text = "Skip the descent (the autopilot picks the spot)"
	skip.button_pressed = bool(MHGame.setting("skip_descent"))
	skip.toggled.connect(func(on: bool) -> void:
		var values := MHGame.settings()
		values["skip_descent"] = on
		MHGame.save_settings(values))
	col.add_child(skip)
	panel.add_child(col)
	screen.add_child(panel)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: show_screen(_landing_back()))
	bar.add_child(back)
	var land := MHStyle.button("Land", "primary", "rocket")
	land.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	land.pressed.connect(func() -> void:
		_landing_area = picker.centre
		if bool(MHGame.setting("skip_descent")): _found_base(picker.touchdown())
		else: show_screen("descent"))
	bar.add_child(land)
	var show_verdict := func(_centre: Vector2, verdict: Dictionary) -> void:
		status.text = str(verdict.get("text", ""))
		var level := str(verdict.get("level", "red"))
		status.add_theme_color_override("font_color", MHStyle.VALID if level == "green" else (MHStyle.WARN if level == "orange" else MHStyle.DANGER))
		land.disabled = level == "red"
		_show_report(report, REGION_LANDING_PICKER_SCRIPT.report(picker.touchdown()) if level != "red" else [])
	picker.area_changed.connect(show_verdict)
	show_verdict.call(picker.centre, picker.verdict)

## The orbital report's rows (region_landing_picker.gd report) in box.
func _show_report(box: VBoxContainer, rows: Array) -> void:
	for child in box.get_children(): child.queue_free()
	if rows.is_empty(): return
	box.add_child(MHStyle.eyebrow("Orbital report · where you'd touch down", MHStyle.accent, 12))
	for row in rows:
		var colour: Color = {"green": MHStyle.VALID, "orange": MHStyle.WARN, "red": MHStyle.DANGER}.get(str(row[3]), MHStyle.TEXT_PRIMARY)
		var line := MHStyle.hbox(10)
		line.add_child(MHStyle.icon(str(row[0]), 16, colour))
		var what := MHStyle.mono(str(row[1]), 13, MHStyle.TEXT_MUTED)
		what.custom_minimum_size.x = 56
		line.add_child(what)
		var text := MHStyle.body(str(row[2]), 14, MHStyle.TEXT_PRIMARY)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 380
		line.add_child(text)
		box.add_child(line)

var _landing_area := Vector2.INF   # the landing oval's centre (region metres)

## A story game on a region (docs/master-design.md §2): no landing map. You
## were to home in on the finished base's beacon; it's silent and the dusty
## air throws your entry long, so where you come down is chosen on the way
## down from what the lander's cameras see (scripts/descent.gd). Creative
## keeps the map.
func _arrives() -> bool:
	return MHChapterOne.new_rules() and MHGame.game_mode != "creative" and MHSiteTerrain.shape() == "region"

## Where the entry carries you: near one of the region's landing zones,
## off by up to half a kilometre, on ground with room for a base.
static func entry_area(rng: RandomNumberGenerator) -> Vector2:
	MHSiteTerrain.region_zone()
	var zones: Dictionary = MHSiteTerrain.RegionTerrain.meta().get("zones", {})
	var ids := zones.keys()
	for attempt in 24:
		var zone: Dictionary = zones[ids[rng.randi() % ids.size()]] if not ids.is_empty() else {"centre": [0.0, 0.0]}
		var at := Vector2(float(zone.centre[0]), float(zone.centre[1])) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 500.0)
		if str(REGION_LANDING_PICKER_SCRIPT.evaluate(at).level) == "green" or attempt == 23: return at
	return Vector2.ZERO

## The Arrive step: the briefing, then the descent.
func _arrival_screen() -> void:
	_scrim("right", .62, .95, .4)
	_stepper("Arrive")
	_place(MHStyle.display("Arrival", 64), Vector2(120, 120))
	var panel := MHStyle.hud_panel(24, false, true)
	panel.position = Vector2(120, 240)
	panel.custom_minimum_size = Vector2(760, 0)
	var col := MHStyle.vbox(14)
	col.add_child(MHStyle.eyebrow("%s · %s" % [MHGame.site_name(), str(MHGame.GAME_MODES.get(MHGame.game_mode, ""))], MHStyle.accent))
	col.add_child(MHStyle.title("Seven months out", 28))
	for text in [
		"The cargo went ahead of you. Its walkers were to gather the pallets and build the base, and you'd land beside it, walk in and commission it.",
		"Halfway through your cruise a planet-wide dust storm swallowed the Reach. The walkers and the cargo beacons went quiet. There's no turning back mid-transfer.",
		"Now you're coming down. The base's landing beacon is silent and the dusty air will carry you long. The lander's cameras will find you safe ground on the way down: steer for it, or let the autopilot choose."]:
		var line := MHStyle.body(text, 18)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)
	if _quick_start: col.add_child(_tutorial_choice())
	var skip := CheckBox.new()
	skip.text = "Skip the descent (the autopilot picks the spot)"
	skip.button_pressed = bool(MHGame.setting("skip_descent"))
	skip.toggled.connect(func(on: bool) -> void:
		var values := MHGame.settings()
		values["skip_descent"] = on
		MHGame.save_settings(values))
	col.add_child(skip)
	panel.add_child(col)
	screen.add_child(panel)
	var bar := _bottom_bar()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var back := MHStyle.button("Back", "ghost", "chevron-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: show_screen(_landing_back()))
	bar.add_child(back)
	var land := MHStyle.button("Begin the descent", "primary", "rocket")
	land.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	land.pressed.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_landing_area = entry_area(rng)
		if bool(MHGame.setting("skip_descent")):
			var near := MHBaseSite.nearest_valid(_landing_area.x, _landing_area.y, 250.0)
			_found_base(near if not is_inf(near.x) else _landing_area)
		else: show_screen("descent"))
	bar.add_child(land)

## The descent into the landing oval, in the backdrop (scripts/descent.gd).
func _descent_screen() -> void:
	var descent := DESCENT_SCRIPT.new()
	descent.setup(camera, environment, _landing_area)
	descent.finished.connect(func(touchdown: Vector2) -> void:
		descent.queue_free()
		# Flown once: later landings skip it (the Land step's box turns it back on).
		if not bool(MHGame.setting("descent_flown")):
			var values := MHGame.settings()
			values["descent_flown"] = true
			values["skip_descent"] = true
			MHGame.save_settings(values)
		_found_base(touchdown))
	backdrop.add_child(descent)

## Found the base where the lander touched down (region metres) and load the world there.
func _found_base(touchdown: Vector2) -> void:
	if is_inf(touchdown.x): return
	MHGame.base_site = MHBaseSite.make(touchdown.x, touchdown.y, MHGame.colony_name)
	MHGame.cargo_at = _landing_area - touchdown   # site metres from the base
	MHGame.landing_target = Vector2.INF            # the lander sets down on the pad's centre
	MHChapterOne.reset()
	environment.rebuild_site()   # the backdrop behind the loading screen: the new base
	show_screen("loading")

## The old step-by-step walk-through (Full) went with the crates; new games
## choose between first-time hints and nothing.
const TUTORIAL_CHOICES := {"hints": "Hints", "off": "Off"}
const TUTORIAL_NOTES := {
	"full": "ARDEN walks you through your first base, step by step, and explains each new thing the first time you meet it.",
	"hints": "No steps: just a short card the first time you meet something new.",
	"off": "Nothing pops up. The Field guide in the pause menu still explains everything.",
}

## Tutorial · Full · Hints only · Off, for this game.
func _tutorial_choice() -> Control:
	var box := MHStyle.vbox(6)
	var head := MHStyle.hbox(8)
	head.add_child(MHStyle.icon("lightbulb", 16, MHStyle.accent))
	head.add_child(MHStyle.eyebrow("Tutorial", MHStyle.accent, 12))
	box.add_child(head)
	if not TUTORIAL_CHOICES.has(MHGame.tutorial_mode): MHGame.tutorial_mode = "hints"
	var note := MHStyle.body(str(TUTORIAL_NOTES[MHGame.tutorial_mode]), 13, MHStyle.TEXT_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 440
	var choice := MHWidgets.Segmented.new().setup(TUTORIAL_CHOICES.values(), str(TUTORIAL_CHOICES[MHGame.tutorial_mode]), 40)
	choice.changed.connect(func(label: String) -> void:
		MHGame.tutorial_mode = str(TUTORIAL_CHOICES.find_key(label))
		note.text = str(TUTORIAL_NOTES[MHGame.tutorial_mode]))
	box.add_child(choice)
	box.add_child(note)
	return box

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
	if _crates_mode(): cargo_line = "%d crates of precursor cargo" % MHChapterOne.crates().size()
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
