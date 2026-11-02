extends CanvasLayer

## The region map (Tab, while exploring a region site, on foot or driving):
## shaded relief of the whole region, coloured by ground, with named places,
## the landing zones, you (and which way you face), the lander, the base, the
## crew rover and GAR-Y, a grid and the distance home. Gameplay loop prototype
## (docs/gameplay-loop-brief.md §5.3); the map images (relief with contours)
## are made by tools/generate_region.py.
##
## It's a map you can move: the mouse wheel zooms (towards the cursor), drag
## or W/A/S/D pans, Z jumps between the whole region and the kilometre round
## you, Space centres on you. L shows or hides the ice survey layer, and G
## sends GAR-Y to survey the ice zone under the cursor. Coordinates are X east and Y north, in metres on
## the region's own grid (the lines on the map), for you and for the cursor.
##
## Your trail: every step since you last came in through an airlock (into the
## habitat, the vehicle bay or a lander), walked or driven, drawn on the map so
## you can find your way back. Saved with the colony.

const RegionTerrain := preload("res://scripts/region_terrain.gd")
const SIZE := 860.0          # map square on screen, px
const ZOOMED := 1000.0       # metres across for Z's close view
const MIN_SPAN := 150.0      # closest zoom, metres across
const DETAIL_BELOW := 3000.0 # closer than this uses the close-up image
const ZOOM_STEP := 1.25
const PAN_SPEED := .6        # map widths a second with the keys
const TRAIL_STEP := 6.0      # metres between trail points
const TRAIL_MAX := 6000      # points kept (thinned to half past this)
const TRAVERSABILITY := preload("res://scripts/traversability.gd")
const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
const SURVEY_STAKES := preload("res://scripts/survey_stakes.gd")
## The ice survey layer (L): likely zones from orbit, GAR-Y's readings with
## the ring you can core in, the cores taken and its stops still to go.
var survey_layer := true
var _note := ""
var _note_left := 0.0

var world: Node
## World x, z of every few metres since you last came in through an airlock.
var trail := PackedVector2Array()
var _panel: Control
var _frame: Control
var _map: TextureRect
var _markers: Control
var _readout: Label
var _cursor_readout: Label
var _origin := Vector2.ZERO  # the landing zone's centre, region metres
var _half := 3072.0
var _centre := Vector2.ZERO  # region metres at the middle of the map
var _span := 0.0             # metres across
var _view := Rect2()         # the region (metres) the map shows
var _overview: Texture2D
var _detail: Texture2D
var _layer: TextureRect     # Rover ground (debug)
var _labels: Control
var _dragging := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _freeze_before := false
var _trail_check := 0.0
## On the slate's screen (docs/pda.md §3): the map square is lent to its Map
## app, scaled to fit, and takes the mouse there (embed / unembed).
var embedded := false
var _cursor_at := Vector2(-1, -1)   # the mouse over the lent map, map px
var _frame_home: Control

func setup(target_world: Node, zone: Dictionary) -> void:
	world = target_world
	_origin = Vector2(float(zone.centre[0]), float(zone.centre[1]))
	_half = float(RegionTerrain.meta().get("half", 3072.0))
	_span = _half * 2.0

func _ready() -> void:
	layer = 40
	visible = false
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHStyle.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, .55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD_STRONG, MHStyle.BORDER_SUBTLE, 10, 1, Vector4(20, 18, 20, 18)))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)
	var column := MHStyle.vbox(10)
	_panel.add_child(column)
	var head := MHStyle.hbox(12)
	head.add_child(MHStyle.eyebrow("REGION MAP · %s" % str(MHGame.site().get("name", "")).to_upper(), MHStyle.accent, 13))
	head.add_child(MHStyle.spacer())
	head.add_child(MHStyle.control_hint(["Wheel"], "Zoom"))
	head.add_child(MHStyle.control_hint(["Drag"], "Move"))
	head.add_child(MHStyle.control_hint(["Z"], "Region / 1 km"))
	head.add_child(MHStyle.control_hint(["Space"], "You"))
	head.add_child(MHStyle.control_hint(["L"], "Ice survey"))
	head.add_child(MHStyle.control_hint(["G"], "GAR-Y: survey zone"))
	head.add_child(MHStyle.control_hint(["Tab"], "Close"))
	column.add_child(head)
	_frame = Control.new()
	_frame.custom_minimum_size = Vector2(SIZE, SIZE)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_frame)
	_frame.clip_contents = true
	_frame.gui_input.connect(_frame_input)
	var folder := RegionTerrain.DIRECTORY + str(RegionTerrain.meta().get("id", "")) + "/"
	_overview = load(folder + "map.png") as Texture2D
	_detail = load(folder + "map_detail.jpg") as Texture2D
	_map = TextureRect.new()
	_map.texture = _overview
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.size = Vector2(SIZE, SIZE)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_map)
	_layer = TextureRect.new()
	_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_layer.stretch_mode = TextureRect.STRETCH_SCALE
	_layer.size = Vector2(SIZE, SIZE)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.visible = false
	_frame.add_child(_layer)
	_markers = Control.new()
	_markers.size = Vector2(SIZE, SIZE)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	_frame.add_child(_markers)
	_labels = Control.new()
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.add_child(_labels)
	_set_view()
	_readout = MHStyle.mono("", 13, MHStyle.TEXT_SECONDARY)
	column.add_child(_readout)
	_cursor_readout = MHStyle.mono("", 13, MHStyle.TEXT_MUTED)
	column.add_child(_cursor_readout)

# ---------- the view ----------

## Shows _span metres across round _centre (kept inside the region), on the
## close-up image once it's near enough.
func _set_view() -> void:
	_span = clampf(_span, MIN_SPAN, _half * 2.0)
	var reach := _half - _span * .5
	_centre = _centre.clamp(Vector2(-reach, -reach), Vector2(reach, reach))
	_view = Rect2(_centre - Vector2(_span, _span) * .5, Vector2(_span, _span))
	var image := _detail if _span < DETAIL_BELOW and _detail != null else _overview
	var crop := AtlasTexture.new()
	crop.atlas = image
	var pixels_per_m := image.get_width() / (_half * 2.0)
	crop.region = Rect2((_view.position + Vector2(_half, _half)) * pixels_per_m, _view.size * pixels_per_m)
	_map.texture = crop
	_layer.visible = TRAVERSABILITY.on
	if _layer.visible:
		var layer := AtlasTexture.new()
		layer.atlas = TRAVERSABILITY.map_layer()
		var layer_scale := layer.atlas.get_width() / (_half * 2.0)
		layer.region = Rect2((_view.position + Vector2(_half, _half)) * layer_scale, _view.size * layer_scale)
		_layer.texture = layer
	for child in _labels.get_children(): child.free()
	for feature in RegionTerrain.meta().get("features", []):
		_label(str(feature.name), _region_to_map(Vector2(float(feature.position[0]), float(feature.position[1]))), MHStyle.TEXT_PRIMARY)
	for zone_id in (RegionTerrain.meta().get("zones", {}) as Dictionary):
		var zone: Dictionary = RegionTerrain.zone(zone_id)
		_label("Landing zone: " + str(zone.get("label", zone_id)), _region_to_map(Vector2(float(zone.centre[0]), float(zone.centre[1]))) + Vector2(0, 18), MHStyle.accent)

func _you() -> Vector2:
	return Vector2(world.player.global_position.x, world.player.global_position.z) + _origin

## Zoom by `factor` keeping the region point under `at` (map px) where it is.
func _zoom(factor: float, at: Vector2) -> void:
	var under := _map_to_region(at)
	_span = clampf(_span * factor, MIN_SPAN, _half * 2.0)
	_centre = under - (at / SIZE - Vector2(.5, .5)) * _span
	_set_view()

func _label(text: String, at: Vector2, colour: Color) -> void:
	if not Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)).has_point(at): return
	var label := MHStyle.label(text, 13, colour, 600)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	label.add_theme_constant_override("outline_size", 5)
	label.position = at + Vector2(-60, -9)
	label.custom_minimum_size.x = 120
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.add_child(label)

func _region_to_map(region: Vector2) -> Vector2:
	return (region - _view.position) / _view.size.x * SIZE

func _map_to_region(at: Vector2) -> Vector2:
	return _view.position + at / SIZE * _view.size.x

func _world_to_map(world_position: Vector3) -> Vector2:
	return _region_to_map(Vector2(world_position.x, world_position.z) + _origin)

## "X 1234  Y -567": metres east and north on the region's grid.
static func _coordinates(region: Vector2) -> String:
	return "X %+5d  Y %+5d" % [roundi(region.x), roundi(-region.y)]

# ---------- input ----------

## The mouse, while the map is open: wheel zoom and drag (before the player,
## who would take a click to recapture the mouse).
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var at := _mouse()
		if button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if not Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)).has_point(at): at = Vector2(SIZE, SIZE) * .5
			_zoom(1.0 / ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP, at)
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_centre -= (event as InputEventMouseMotion).relative / SIZE * _span
		_set_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_TAB, KEY_ESCAPE: _close()
				KEY_Z:
					_span = ZOOMED if _span > ZOOMED * 1.5 else _half * 2.0
					_centre = _you()
					_set_view()
				KEY_SPACE:
					_centre = _you()
					_set_view()
				KEY_L:
					survey_layer = not survey_layer
					_say("Ice survey layer on." if survey_layer else "Ice survey layer off.")
				KEY_G: _send_gar_y()
		get_viewport().set_input_as_handled()   # nothing else hears keys while it's open

## Where the mouse is over the map square, in map px.
func _mouse() -> Vector2:
	return _cursor_at if embedded else _frame.get_local_mouse_position()

## Lends the map square to the slate's Map app, scaled to `fit` px across.
func embed(holder: Control, fit: float) -> void:
	if embedded: return
	embedded = true
	_frame_home = _frame.get_parent()
	_frame_home.remove_child(_frame)
	holder.add_child(_frame)
	_frame.scale = Vector2.ONE * fit / SIZE
	_frame.position = Vector2.ZERO
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_dragging = false
	_cursor_at = Vector2(-1, -1)
	if _span < _half * 2.0: _centre = _you()
	_set_view()

## Takes the map square back (the slate went down or changed app).
func unembed() -> void:
	if not embedded: return
	embedded = false
	_frame.get_parent().remove_child(_frame)
	_frame_home.add_child(_frame)
	_frame_home.move_child(_frame, 1)   # under the header row
	_frame.scale = Vector2.ONE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dragging = false

## The mouse on the lent map: wheel zoom, drag to move.
func _frame_input(event: InputEvent) -> void:
	if not embedded: return
	if event is InputEventMouse: _cursor_at = (event as InputEventMouse).position
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_zoom(1.0 / ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP, button.position)
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button.pressed
		_frame.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_centre -= (event as InputEventMouseMotion).relative / SIZE * _span
		_set_view()
		_frame.accept_event()

## A key on the slate's Map app; true when the map used it.
func slate_key(keycode: int) -> bool:
	if not embedded: return false
	match keycode:
		KEY_Z:
			_span = ZOOMED if _span > ZOOMED * 1.5 else _half * 2.0
			_centre = _you()
			_set_view()
		KEY_SPACE:
			_centre = _you()
			_set_view()
		KEY_L:
			survey_layer = not survey_layer
			_say("Ice survey layer on." if survey_layer else "Ice survey layer off.")
		KEY_G: _send_gar_y()
		_: return false
	return true

## Readouts for the slate's Map app: [you, cursor or note].
func readouts() -> Array:
	return [_readout.text, _cursor_readout.text]

## Only while exploring: not in a build mode or another screen.
func _can_open() -> bool:
	if world == null or get_tree().paused: return false
	if world.builder != null and world.builder.build_mode: return false
	if world.get("interior_builder") != null and bool(world.interior_builder.active): return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

## Open with a cursor, the player held still (a cruising rover keeps going).
func _open() -> void:
	visible = true
	_dragging = false
	if _span < _half * 2.0: _centre = _you()
	_set_view()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_freeze_before = bool(world.player.get_meta("ui_freeze", false))
	world.player.set_meta("ui_freeze", true)

func _close() -> void:
	visible = false
	_dragging = false
	Input.mouse_mode = _mouse_before
	world.player.set_meta("ui_freeze", _freeze_before)

# ---------- every frame ----------

func _process(delta: float) -> void:
	_record_trail(delta)
	if not visible and not embedded: return
	var pan := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if pan != Vector2.ZERO:
		_centre += pan.normalized() * _span * PAN_SPEED * delta
		_set_view()
	_markers.queue_redraw()
	var player: Node3D = world.player
	var home: Vector3 = world.lander.global_position if world.lander != null else Vector3.ZERO
	var away := Vector2(player.global_position.x - home.x, player.global_position.z - home.z).length()
	_readout.text = "YOU  %s   ·   %.1f km from the lander   ·   1 SQUARE = %s   ·   NORTH IS UP" % [_coordinates(_you()), away / 1000.0, _distance(_grid_spacing())]
	var at := _mouse()
	_note_left -= delta
	if _note_left > 0.0:
		_cursor_readout.text = _note
	elif Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)).has_point(at) and (not embedded or _cursor_at.x >= 0.0):
		var there := _map_to_region(at)
		_cursor_readout.text = "CURSOR  %s   ·   %s from you" % [_coordinates(there), _distance(there.distance_to(_you()))]
	else:
		_cursor_readout.text = "TRAIL  %s since the airlock" % _distance(_trail_length()) if trail.size() > 1 else "TRAIL  starts when you go out through an airlock"

static func _distance(metres: float) -> String:
	return "%.1f km" % (metres / 1000.0) if metres >= 1000.0 else "%d m" % roundi(metres)

## Grid lines a few hundred pixels apart at any zoom.
func _grid_spacing() -> float:
	for spacing in [50.0, 100.0, 250.0, 500.0, 1000.0]:
		if _span / spacing <= 12.0: return spacing
	return 1000.0

# ---------- the trail ----------

## Twice a second: a point every few metres while you're out, cleared once
## you're back in through an airlock.
func _record_trail(delta: float) -> void:
	_trail_check -= delta
	if _trail_check > 0.0 or world == null or world.player == null: return
	_trail_check = .5
	var at: Vector3 = world.player.global_position
	if _indoors(at):
		if not trail.is_empty(): trail.clear()
		return
	var flat := Vector2(at.x, at.z)
	if trail.is_empty() or trail[trail.size() - 1].distance_to(flat) >= TRAIL_STEP:
		trail.append(flat)
		if trail.size() > TRAIL_MAX:
			var thinned := PackedVector2Array()
			for i in range(0, trail.size(), 2): thinned.append(trail[i])
			trail = thinned

func _indoors(at: Vector3) -> bool:
	if world.builder != null and world.builder.is_inside(at): return true
	if world.lander != null and world.lander.has_method("cabin_contains") and world.lander.cabin_contains(at): return true
	for landmark in get_tree().get_nodes_in_group("landmark"):
		if landmark.has_method("hold_contains") and landmark.hold_contains(at): return true
	return false

func _trail_length() -> float:
	var total := 0.0
	for i in range(1, trail.size()): total += trail[i - 1].distance_to(trail[i])
	return total

# ---------- drawing ----------

func _draw_markers() -> void:
	var c := _markers
	var font := ThemeDB.fallback_font
	# The grid, on the region's own lines, numbered along the top and left.
	var spacing := _grid_spacing()
	var first := Vector2(ceilf(_view.position.x / spacing), ceilf(_view.position.y / spacing)) * spacing
	var gx := first.x
	while gx < _view.end.x:
		var at := _region_to_map(Vector2(gx, 0)).x
		c.draw_line(Vector2(at, 0), Vector2(at, SIZE), Color(1, 1, 1, .08), 1.0)
		c.draw_string(font, Vector2(at + 3, 13), "%d" % roundi(gx), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, .45))
		gx += spacing
	var gz := first.y
	while gz < _view.end.y:
		var at := _region_to_map(Vector2(0, gz)).y
		c.draw_line(Vector2(0, at), Vector2(SIZE, at), Color(1, 1, 1, .08), 1.0)
		c.draw_string(font, Vector2(3, at - 3), "%d" % roundi(-gz), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, .45))
		gz += spacing
	# The base: every room cell.
	if world.builder != null:
		for zone in world.builder.zones:
			for cell in zone.get("cells", []):
				var p := _world_to_map(Vector3(cell.x * 3.0, 0, cell.y * 3.0))
				var w := maxf(4.0, 3.0 / _view.size.x * SIZE)   # true size when zoomed in
				c.draw_rect(Rect2(p - Vector2(w, w) * .5, Vector2(w, w)), Color("#F2F3F0"))
	if survey_layer: _draw_survey()
	_draw_trail()
	if world.lander != null and world.lander.visible: _marker(world.lander.global_position, "Lander", Color("#F2C35A"), "square")
	for rover in world.get_tree().get_nodes_in_group("crew_rover"): _marker((rover as Node3D).global_position, "Rover", Color("#8CC3CB"), "circle")
	for gary in world.get_tree().get_nodes_in_group("gar_y"): _marker((gary as Node3D).global_position, "GAR-Y", Color("#8CC3CB"), "circle")
	# What you dropped when you blacked out (scripts/suit.gd).
	var suit: Node = world.get("suit")
	if suit != null:
		for item in suit.dropped: _marker(item.position, "Dropped: %s" % item.label, MHStyle.WARN, "square")
	# You: an arrow pointing the way you face.
	var player: Node3D = world.player
	var at := _world_to_map(player.global_position)
	var forward := -player.global_transform.basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	c.draw_colored_polygon(PackedVector2Array([at + dir * 13.0, at - dir * 8.0 + side * 8.0, at - dir * 4.0, at - dir * 8.0 - side * 8.0]), MHStyle.accent)
	c.draw_polyline(PackedVector2Array([at + dir * 13.0, at - dir * 8.0 + side * 8.0, at - dir * 4.0, at - dir * 8.0 - side * 8.0, at + dir * 13.0]), Color(0, 0, 0, .8), 1.5)

## Your way out from the airlock: a dotted line, a dot every few pixels.
func _draw_trail() -> void:
	if trail.size() < 2: return
	var colour := Color("#F6E7B0")
	var points := PackedVector2Array()
	for point in trail: points.append(_region_to_map(point + _origin))
	var gap := 7.0
	var carried := 0.0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var length := a.distance_to(b)
		if length > SIZE * 2.0: continue   # a jump (a load, a rescue): no line across the map
		var along := gap - carried
		while along <= length:
			var p := a.lerp(b, along / length)
			if p.x > -4 and p.y > -4 and p.x < SIZE + 4 and p.y < SIZE + 4:
				_markers.draw_circle(p, 2.6, Color(0, 0, 0, .55))
				_markers.draw_circle(p, 1.8, colour)
			along += gap
		carried = length - (along - gap)
	var start := points[0]
	_markers.draw_arc(start, 6.0, 0.0, TAU, 20, colour, 2.0, true)
	_markers.draw_string(ThemeDB.fallback_font, start + Vector2(10, -6), "Airlock", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colour)

func _marker(world_position: Vector3, text: String, colour: Color, shape: String) -> void:
	var at := _world_to_map(world_position)
	if shape == "square": _markers.draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), colour)
	else: _markers.draw_circle(at, 6.0, colour)
	_markers.draw_string(ThemeDB.fallback_font, at + Vector2(10, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)

# ---------- the ice survey layer ----------

## A line under the map for a few seconds (replies to L and G).
func _say(text: String) -> void:
	_note = text.to_upper()
	_note_left = 4.0

## G: GAR-Y surveys the likely ice zone under the cursor.
func _send_gar_y() -> void:
	var gary := get_tree().get_first_node_in_group("gar_y")
	if gary == null:
		_say("GAR-Y isn't here.")
		return
	var at := _mouse()
	if not Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)).has_point(at):
		_say("Point at a dashed ice zone first.")
		return
	var there := _map_to_region(at) - _origin
	var why: String = gary.call("order", "find_ice_at", Vector3(there.x, 0.0, there.y))
	_say(why if not why.is_empty() else "GAR-Y is on its way to survey the zone.")

## Dashed circles where orbital radar sees likely ice, each reading as a dot
## in its signal colour inside the ring you can core in, a tick or cross for
## the cores taken, and GAR-Y's stops still to go on a zone survey.
func _draw_survey() -> void:
	var c := _markers
	var font := ThemeDB.fallback_font
	var px_per_m := SIZE / _view.size.x
	var zone_colour := Color(SURVEY_STAKES.STRONG_COLOUR, .75)
	for zone in ICE_KNOWLEDGE.likely_zones():
		var centre := _region_to_map((zone.centre as Vector2) + _origin)
		var r := maxf(6.0, float(zone.radius) * px_per_m)
		var dashes := maxi(12, int(r * .5))
		for i in dashes:
			if i % 2 == 1: continue
			c.draw_arc(centre, r, TAU * i / dashes, TAU * (i + 1) / dashes, 4, zone_colour, 2.0, true)
		if r > 14.0: c.draw_string(font, centre + Vector2(-40, -r - 6), "LIKELY ICE", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, zone_colour)
	var stakes := get_tree().get_first_node_in_group("survey_stakes")
	var readings: Array = stakes.call("readings") if stakes != null else ICE_KNOWLEDGE.samples(get_tree()).map(func(v): return {"at": Vector2(v.x, v.y), "reading": float(v.z), "cored": ""})
	for entry in readings:
		var at := _region_to_map((entry.at as Vector2) + _origin)
		if at.x < -20 or at.y < -20 or at.x > SIZE + 20 or at.y > SIZE + 20: continue
		var colour := SURVEY_STAKES.colour_for(SURVEY_STAKES.strength(float(entry.reading)))
		var ring := ICE_KNOWLEDGE.CORE_REACH * px_per_m
		if ring > 4.0:
			c.draw_circle(at, ring, Color(colour, .14))
			c.draw_arc(at, ring, 0.0, TAU, 32, Color(colour, .6), 1.0, true)
		c.draw_circle(at, 4.0, Color(0, 0, 0, .7))
		c.draw_circle(at, 3.0, colour)
		match str(entry.cored):
			"ice":
				c.draw_polyline(PackedVector2Array([at + Vector2(5, 0), at + Vector2(8, 4), at + Vector2(14, -5)]), SURVEY_STAKES.STRONG_COLOUR, 2.0, true)
			"dry":
				c.draw_line(at + Vector2(6, -4), at + Vector2(13, 3), SURVEY_STAKES.WEAK_COLOUR, 2.0, true)
				c.draw_line(at + Vector2(6, 3), at + Vector2(13, -4), SURVEY_STAKES.WEAK_COLOUR, 2.0, true)
	# GAR-Y's zone survey: the stops still to go, in order.
	for gary in get_tree().get_nodes_in_group("gar_y"):
		if str(gary.get("task")) != "survey": continue
		var data: Dictionary = gary.get("task_data")
		if not data.has("hunt"): continue
		var path := PackedVector2Array([_world_to_map((gary as Node3D).global_position)])
		var goal: Vector3 = gary.get("task_goal")
		if goal != Vector3.INF: path.append(_world_to_map(goal))
		for stop in data.hunt: path.append(_region_to_map((stop as Vector2) + _origin))
		if path.size() > 1: c.draw_polyline(path, Color(1, 1, 1, .35), 1.0, true)
		for i in range(1, path.size()): c.draw_arc(path[i], 4.0, 0.0, TAU, 12, Color(1, 1, 1, .8), 1.5, true)
