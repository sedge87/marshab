extends Node

## Showcase mode (backlog item 32): a finished base presents itself on a big
## screen, with nobody at the keyboard. Started from the title screen's
## Present button beside any save. It plays a copy: nothing is ever saved.
##
## The loop, then round again:
##   1. The base: a slow orbit at golden hour, with a title card (colony,
##      site, emblem, "Designed by …" when the dossier has a name).
##   2. The camera masts, each sweeping slowly (or high automatic shots
##      when there are none).
##   3. A walk through every room, with a caption of what it's doing.
##   4. A sol in 60 seconds: the sun crosses, solar and batteries rise and
##      fall, the lights go from on to dim.
##   5. The story: the dossier's highlights (or what was built).
## Live stats run along the bottom throughout. Space pauses the tour,
## ←/→ skip, Esc returns to the menu.

const MHMissions := preload("res://scripts/mh_missions.gd")
const MONITOR := preload("res://scripts/habitat_monitor.gd")
const ORBIT_SECONDS := 26.0
const MAST_SECONDS := 9.0
const ROOM_SECONDS := 7.5
const TIMELAPSE_SECONDS := 60.0
const STORY_SECONDS := 10.0
const MAX_ROOMS := 8

var world: Node
var camera: Camera3D
var paused := false
var _shots: Array = []        # [{kind, seconds, ...}]
var _index := 0
var _t := 0.0
var _centre := Vector3.ZERO
var _reach := 20.0
var _layer: CanvasLayer
var _title_card: Control
var _label: Label
var _caption: Label
var _stats: Label
var _paused_label: Label
var _story: Control
var _clock := 0.0

func setup(target_world: Node) -> void:
	world = target_world
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 1200.0
	add_child(camera)
	camera.current = true
	_hide_game_ui()
	_measure_base()
	_build_overlay()
	_plan()
	MHAudio.music("menu")
	_begin(0)

# ---------- set-up ----------

func _hide_game_ui() -> void:
	world.player.set_meta("ui_freeze", true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for node in [world.explore_hud, world.mission_hud, world.gar_y_orders]:
		if node != null: node.visible = false
	if world.alerts != null:
		world.alerts.set_process(false)
		world.alerts._layer.visible = false
	if world.weather != null and world.weather.get("_layer") != null: world.weather._layer.visible = false

func _measure_base() -> void:
	var b: BuildController = world.builder
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for zone in b.zones:
		for cell in zone.get("cells", []):
			var at := Vector2(cell.x, cell.y) * BuildController.CELL
			low = Vector2(minf(low.x, at.x), minf(low.y, at.y))
			high = Vector2(maxf(high.x, at.x), maxf(high.y, at.y))
	if low.x == INF: low = Vector2.ZERO; high = Vector2.ZERO
	var flat := (low + high) * .5
	_centre = Vector3(flat.x, b.habitat_base_y + 1.0, flat.y)
	_reach = maxf(14.0, (high - low).length() * .5 + 10.0)

## The shot list for one loop.
func _plan() -> void:
	_shots = [{"kind": "orbit", "seconds": ORBIT_SECONDS, "label": "The base"}]
	var masts: Array = get_tree().get_nodes_in_group("camera_mast")
	if masts.is_empty():
		for angle in [.5, 2.6, 4.4]: _shots.append({"kind": "high", "seconds": 7.0, "angle": angle, "label": "From above"})
	else:
		for i in range(masts.size()): _shots.append({"kind": "mast", "seconds": MAST_SECONDS, "mast": masts[i], "label": "Camera mast %d" % (i + 1)})
	var rooms: Array = world.builder.simulation().inventory().rooms
	var shown := 0
	for index in range(rooms.size()):
		if str(rooms[index].kind) == "airlock" or shown >= MAX_ROOMS: continue
		if (rooms[index].zone.get("cells", []) as Array).is_empty(): continue
		_shots.append({"kind": "room", "seconds": ROOM_SECONDS, "room": index, "label": str(rooms[index].label)})
		shown += 1
	_shots.append({"kind": "timelapse", "seconds": TIMELAPSE_SECONDS, "label": "A sol in 60 seconds"})
	_shots.append({"kind": "story", "seconds": STORY_SECONDS, "label": "The story"})

# ---------- the loop ----------

func _begin(index: int) -> void:
	_end_shot()
	_index = posmod(index, _shots.size())
	if _index == 0: _plan()   # a new loop picks up any change (a mast moved, say)
	_t = 0.0
	var shot: Dictionary = _shots[_index]
	_label.text = str(shot.label).to_upper()
	_caption.text = ""
	_title_card.visible = shot.kind == "orbit"
	_story.visible = shot.kind == "story"
	var day_night = world.day_night
	match str(shot.kind):
		"orbit":
			day_night.set_hour(16.9)   # golden hour
			_place_player_outside()
		"mast":
			if is_instance_valid(shot.mast): shot.mast.set_camera_setting("cam_sweep", true)
			_place_player_outside()
		"high": _place_player_outside()
		"room":
			_caption.text = _room_caption(int(shot.room))
			_place_player_in_room(int(shot.room))
		"timelapse":
			day_night.set_hour(5.5)
			day_night.time_scale = 20.0   # 15 min day + 5 min night -> 60 s
			_place_player_outside()
			_caption.text = "Watch the solar output and the batteries rise and fall."
		"story":
			_fill_story()
			_place_player_outside()

func _end_shot() -> void:
	if world != null and world.day_night != null: world.day_night.time_scale = 1.0

func _process(delta: float) -> void:
	if world == null: return
	_clock += delta
	_update_stats()
	if paused: return
	_t += delta
	var shot: Dictionary = _shots[_index]
	if _t >= float(shot.seconds):
		_begin(_index + 1)
		return
	var f := _t / float(shot.seconds)
	_title_card.modulate.a = clampf(1.0 - (_t - 7.0) / 1.5, 0.0, 1.0) if shot.kind == "orbit" else 0.0
	match str(shot.kind):
		"orbit": _orbit(_reach * 1.15, _reach * .42, .9 + f * 1.4)
		"high":
			var r := _reach * lerpf(1.0, .8, f)
			var a := float(shot.angle) + f * .25
			camera.global_position = _centre + Vector3(sin(a) * r, _reach * .7, cos(a) * r)
			camera.look_at(_centre, Vector3.UP)
		"mast":
			if is_instance_valid(shot.mast):
				camera.global_transform = shot.mast.camera_view()
				camera.fov = float(shot.mast.camera_setting("cam_fov", 60.0))
		"room": _room_shot(int(shot.room), f)
		"timelapse":
			_orbit(_reach * 1.35, _reach * .62, 3.3 + f * .8)
			_caption.text = "%02d:%02d · %s" % [int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60.0), "Day: the panels charge the batteries" if MHGame.sunlight_fraction > .2 else "Night: everything runs on the batteries"]
		"story": _orbit(_reach * 1.5, _reach * .8, 5.0 + f * .5)
	if shot.kind != "mast": camera.fov = 55.0

func _orbit(radius: float, height: float, angle: float) -> void:
	camera.global_position = _centre + Vector3(sin(angle) * radius, height, cos(angle) * radius)
	camera.look_at(_centre, Vector3.UP)

# ---------- rooms ----------

func _room(index: int) -> Dictionary:
	return world.builder.simulation().inventory().rooms[index]

func _room_centre(index: int) -> Vector3:
	var cells: Array = _room(index).zone.get("cells", [])
	var sum := Vector2.ZERO
	for cell in cells: sum += Vector2(cell.x, cell.y) * BuildController.CELL
	sum /= maxf(1.0, cells.size())
	return Vector3(sum.x, world.builder.habitat_base_y, sum.y)

## From one corner of the room towards the middle, slowly turning.
func _room_shot(index: int, f: float) -> void:
	var centre := _room_centre(index)
	var cells: Array = _room(index).zone.get("cells", [])
	var far := centre
	for cell in cells:
		var at := Vector3(cell.x * BuildController.CELL, centre.y, cell.y * BuildController.CELL)
		if at.distance_to(centre) >= far.distance_to(centre): far = at
	# Stand in the far cell (or a corner of a one-cell room) and look across,
	# drifting a little towards the middle and panning gently.
	var start := far if far != centre else centre + Vector3(.9, 0, .9)
	var across := (centre - start).normalized() if far != centre else Vector3(-1, 0, -1).normalized()
	var eye := start.lerp(centre, f * .35) + Vector3(0, 1.6, 0)
	camera.global_position = eye
	var sway := sin(f * PI - PI * .5) * .35
	var look := eye + across.rotated(Vector3.UP, sway) * 4.0
	look.y = eye.y - .55
	camera.look_at(look, Vector3.UP)

func _room_caption(index: int) -> String:
	var s = world.builder.simulation()
	var inv: Dictionary = s.inventory()
	var room := _room(index)
	var groups := {}
	for item in inv.items:
		if int(item.room) != index: continue
		if not groups.has(item.id): groups[item.id] = {"item": item, "count": 0}
		groups[item.id].count += 1
	var ids: Array = groups.keys()
	ids.sort_custom(func(a, b): return int(groups[a].count) > int(groups[b].count))
	var parts: Array = ["%d °C" % roundi(float(s.room_temp.get(room.key, 20.0)))]
	for id in ids.slice(0, 2):
		var count: int = groups[id].count
		var label := str(EquipmentCatalog.get_entry(str(id)).get("label", id))
		var what := MONITOR.doing(groups[id].item, true, count)
		parts.append("%s%s%s" % ["%d × " % count if count > 1 else "", label, (": " + what) if not what in ["no power needed", "switched off"] else ""])
	return " · ".join(parts)

## The (invisible, frozen) player stands where the camera is, so the room
## lights, furniture culling and GAR-Y all follow the tour.
func _place_player_in_room(index: int) -> void:
	world.player.global_position = _room_centre(index) + Vector3(0, .1, 0)

func _place_player_outside() -> void:
	var b: BuildController = world.builder
	var spot := _centre + Vector3(_reach * .6, 0, _reach * .6)
	spot.y = b._terrain_height(spot) + 1.0
	world.player.global_position = spot

# ---------- the overlay ----------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHStyle.theme()
	_layer.add_child(root)
	# Shot label and caption, top left.
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(48, 36)
	top_panel.add_theme_stylebox_override("panel", MHStyle.box(Color(0, 0, 0, .5), Color(0, 0, 0, 0), 8, 0, Vector4(18, 12, 22, 14)))
	root.add_child(top_panel)
	var top := MHStyle.vbox(4)
	top_panel.add_child(top)
	_label = MHStyle.eyebrow("", MHStyle.accent, 18)
	top.add_child(_label)
	_caption = MHStyle.body("", 22, MHStyle.TEXT_PRIMARY)
	_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_caption)
	# Live stats along the bottom.
	var bar := PanelContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -74
	bar.add_theme_stylebox_override("panel", MHStyle.box(Color(0, 0, 0, .55), Color(0, 0, 0, 0), 0, 0, Vector4(64, 16, 64, 16)))
	var row := MHStyle.hbox(24)
	_stats = MHStyle.mono("", 19, MHStyle.TEXT_PRIMARY, 700)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_stats)
	_paused_label = MHStyle.mono("", 15, MHStyle.accent, 700)
	row.add_child(_paused_label)
	bar.add_child(row)
	root.add_child(bar)
	var keys := MHStyle.mono("SPACE PAUSE · LEFT/RIGHT SKIP · ESC MENU", 13, Color(1, 1, 1, .55))
	keys.anchor_left = 1.0
	keys.anchor_right = 1.0
	keys.offset_left = -420
	keys.offset_right = -40
	keys.offset_top = 40
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(keys)
	# Title card.
	_title_card = CenterContainer.new()
	_title_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := PanelContainer.new()
	backing.add_theme_stylebox_override("panel", MHStyle.box(Color(0, 0, 0, .55), Color(MHStyle.accent, .6), 14, 2, Vector4(64, 36, 64, 40)))
	var card := MHStyle.vbox(10)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	backing.add_child(card)
	var emblem := TextureRect.new()
	emblem.texture = MHIcons.texture(MHGame.emblem, 72)
	emblem.modulate = MHStyle.accent
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	emblem.custom_minimum_size = Vector2(0, 90)
	card.add_child(emblem)
	var name_label := MHStyle.display(MHGame.colony_name, 84)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	var site := MHStyle.eyebrow("%s · Mars" % MHGame.site_name(), MHStyle.accent, 20)
	site.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(site)
	var commander := MHMissions.player_name() if MHGame.game_mode == "missions" else ""
	if not commander.is_empty():
		var by := MHStyle.body("Designed by %s" % commander, 28, MHStyle.TEXT_PRIMARY)
		by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(by)
	if not MHGame.mission_statement.strip_edges().is_empty():
		var statement := MHStyle.body("“%s”" % MHGame.mission_statement.strip_edges(), 20, MHStyle.TEXT_SECONDARY)
		statement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(statement)
	_title_card.add_child(backing)
	root.add_child(_title_card)
	# The story card (filled when it plays).
	_story = CenterContainer.new()
	_story.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story.visible = false
	root.add_child(_story)

func _update_stats() -> void:
	if not MHGame.simulation_on():
		_stats.text = "%s · CREATIVE MODE" % MHGame.colony_name.to_upper()
		return
	var s = world.builder.simulation()
	var snap: Dictionary = s.snapshot(MHGame.sol_hour)
	var flows: Dictionary = s.daily_flows(false)
	_stats.text = "CREW %d   ·   POWER %.1f / %.1f kW   ·   BATTERY %d%%   ·   O₂ %.1f%%   ·   WATER %d L   ·   FOOD %d kg   ·   RESEARCH %.1f   ·   %02d:%02d" % [
		int(flows.crew), float(snap.generation_kw), float(snap.load_kw), roundi(float(snap.battery_pct)), float(snap.o2_pct), roundi(float(snap.water_l)), roundi(float(snap.food_kg)), float(flows.research),
		int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60.0)]
	_paused_label.text = "PAUSED" if paused else ""

## The dossier's highlights, or what was built.
func _fill_story() -> void:
	for child in _story.get_children(): child.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MHStyle.box(Color(0, 0, 0, .62), Color(MHStyle.accent, .8), 10, 2, Vector4(48, 36, 48, 36)))
	var col := MHStyle.vbox(12)
	panel.add_child(col)
	col.add_child(MHStyle.eyebrow("How %s was built" % MHGame.colony_name, MHStyle.accent, 18))
	var lines: Array = []
	if MHGame.game_mode == "missions":
		var done: Array = (MHMissions.progress.get("completed", []) as Array)
		var tests := 0
		for mission in MHMissions.missions(): tests += MHMissions.versions(str(mission.id)).size()
		lines.append("%d mission%s completed, %d design%s tested." % [done.size(), "" if done.size() == 1 else "s", tests, "" if tests == 1 else "s"])
		for mission in MHMissions.missions():
			var list := MHMissions.versions(str(mission.id))
			var passed: Array = list.filter(func(v): return bool(v.passed))
			if passed.is_empty(): continue
			var line := "Mission %d, %s: passed on version %d." % [int(mission.number), str(mission.title), int(passed[0].version)]
			var fixes := MHMissions.fixes(str(mission.id))
			if not fixes.is_empty(): line += " Fixed %s with %s." % [str(fixes[-1].text).to_lower(), str(fixes[-1].changes)]
			lines.append(line)
	else:
		var b: BuildController = world.builder
		var rooms: int = (b.simulation().inventory().rooms as Array).size()
		lines.append("%d rooms and %d pieces of equipment, built in %s mode." % [rooms, b.placed_interior.size() + b.placed_surface.size(), str(MHGame.GAME_MODES.get(MHGame.game_mode, MHGame.game_mode))])
		lines.append("%s of cargo from Earth." % MHStyle.kg(b.used_cargo()))
	for line in lines.slice(0, 7):
		var label := MHStyle.body(str(line), 22, MHStyle.TEXT_PRIMARY)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 980
		col.add_child(label)
	_story.add_child(panel)

# ---------- the presenter's keys ----------

func _input(event: InputEvent) -> void:
	# Showcase owns the keyboard and mouse: nothing reaches the game.
	if event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	if not key.pressed or key.echo: return
	match key.keycode:
		KEY_SPACE: paused = not paused
		KEY_RIGHT: _begin(_index + 1)
		KEY_LEFT: _begin(_index - 1)
		KEY_ESCAPE:
			_end_shot()
			MHGame.showcase = false
			world._return_menu()
