extends CanvasLayer

## The region map (Tab, while exploring a region site): shaded relief of the
## whole region, coloured by ground, with named places, the landing zones,
## you (and which way you face), the lander, the base, the crew rover and
## GAR-Y, a 1 km scale bar and the distance home. Gameplay loop prototype
## (docs/gameplay-loop-brief.md §5.3); the map image is made by
## tools/generate_region.py.

const RegionTerrain := preload("res://scripts/region_terrain.gd")
const SIZE := 860.0          # map square on screen, px

var world: Node
var _panel: Control
var _map: TextureRect
var _markers: Control
var _readout: Label
var _origin := Vector2.ZERO  # the landing zone's centre, region metres
var _half := 3072.0

func setup(target_world: Node, zone: Dictionary) -> void:
	world = target_world
	_origin = Vector2(float(zone.centre[0]), float(zone.centre[1]))
	_half = float(RegionTerrain.meta().get("half", 3072.0))

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
	head.add_child(MHStyle.control_hint(["Tab"], "Close"))
	column.add_child(head)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(SIZE, SIZE)
	column.add_child(frame)
	_map = TextureRect.new()
	_map.texture = load(RegionTerrain.DIRECTORY + str(RegionTerrain.meta().get("id", "")) + "/map.png") as Texture2D
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.size = Vector2(SIZE, SIZE)
	frame.add_child(_map)
	_markers = Control.new()
	_markers.size = Vector2(SIZE, SIZE)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	frame.add_child(_markers)
	for feature in RegionTerrain.meta().get("features", []):
		_label(str(feature.name), _region_to_map(Vector2(float(feature.position[0]), float(feature.position[1]))), MHStyle.TEXT_PRIMARY)
	for zone_id in (RegionTerrain.meta().get("zones", {}) as Dictionary):
		var zone: Dictionary = RegionTerrain.zone(zone_id)
		_label("Landing zone: " + str(zone.get("label", zone_id)), _region_to_map(Vector2(float(zone.centre[0]), float(zone.centre[1]))) + Vector2(0, 18), MHStyle.accent)
	_readout = MHStyle.mono("", 13, MHStyle.TEXT_SECONDARY)
	column.add_child(_readout)

func _label(text: String, at: Vector2, colour: Color) -> void:
	var label := MHStyle.label(text, 13, colour, 600)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	label.add_theme_constant_override("outline_size", 5)
	label.position = at + Vector2(-60, -9)
	label.custom_minimum_size.x = 120
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.add_child(label)

func _region_to_map(region: Vector2) -> Vector2:
	return (region + Vector2(_half, _half)) / (_half * 2.0) * SIZE

func _world_to_map(world_position: Vector3) -> Vector2:
	return _region_to_map(Vector2(world_position.x, world_position.z) + _origin)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	var key := (event as InputEventKey).keycode
	if key == KEY_TAB and (visible or _can_open()):
		visible = not visible
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and visible:
		visible = false
		get_viewport().set_input_as_handled()

## Only while exploring: not in a build mode or another screen.
func _can_open() -> bool:
	if world == null or get_tree().paused: return false
	if world.builder != null and world.builder.build_mode: return false
	if world.get("interior_builder") != null and bool(world.interior_builder.active): return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if not visible: return
	_markers.queue_redraw()
	var player: Node3D = world.player
	var home: Vector3 = world.lander.global_position if world.lander != null else Vector3.ZERO
	var away := Vector2(player.global_position.x - home.x, player.global_position.z - home.z).length()
	_readout.text = "YOU  %.1f km from the lander   ·   1 SQUARE = 1 KM   ·   NORTH IS UP" % (away / 1000.0)

func _draw_markers() -> void:
	var c := _markers
	# 1 km grid.
	var km := SIZE / (_half * 2.0) * 1000.0
	var lines := int(_half * 2.0 / 1000.0)
	for i in range(1, lines + 1):
		var at := fmod(i * km, SIZE)
		c.draw_line(Vector2(at, 0), Vector2(at, SIZE), Color(1, 1, 1, .08), 1.0)
		c.draw_line(Vector2(0, at), Vector2(SIZE, at), Color(1, 1, 1, .08), 1.0)
	# The base: every room cell.
	if world.builder != null:
		for zone in world.builder.zones:
			for cell in zone.get("cells", []):
				var p := _world_to_map(Vector3(cell.x * 3.0, 0, cell.y * 3.0))
				c.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color("#F2F3F0"))
	if world.lander != null and world.lander.visible: _marker(world.lander.global_position, "Lander", Color("#F2C35A"), "square")
	for rover in world.get_tree().get_nodes_in_group("crew_rover"): _marker((rover as Node3D).global_position, "Rover", Color("#8CC3CB"), "circle")
	for gary in world.get_tree().get_nodes_in_group("gar_y"): _marker((gary as Node3D).global_position, "GAR-Y", Color("#8CC3CB"), "circle")
	# You: an arrow pointing the way you face.
	var player: Node3D = world.player
	var at := _world_to_map(player.global_position)
	var forward := -player.global_transform.basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	c.draw_colored_polygon(PackedVector2Array([at + dir * 13.0, at - dir * 8.0 + side * 8.0, at - dir * 4.0, at - dir * 8.0 - side * 8.0]), MHStyle.accent)
	c.draw_polyline(PackedVector2Array([at + dir * 13.0, at - dir * 8.0 + side * 8.0, at - dir * 4.0, at - dir * 8.0 - side * 8.0, at + dir * 13.0]), Color(0, 0, 0, .8), 1.5)

func _marker(world_position: Vector3, text: String, colour: Color, shape: String) -> void:
	var at := _world_to_map(world_position)
	if shape == "square": _markers.draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), colour)
	else: _markers.draw_circle(at, 6.0, colour)
	_markers.draw_string(ThemeDB.fallback_font, at + Vector2(10, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
