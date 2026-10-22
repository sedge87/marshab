extends Control

## The outside cameras (backlog item 28): look through the camera masts you've
## placed outside. Live, like the monitor: the game keeps running and you
## stand still. The mast's head physically turns as you aim it.
##   drag the view, or A/D and W/S: pan round 360° and tilt;
##   mouse wheel: zoom;  Tab or ←/→ (or click a thumbnail): next mast;
##   Auto-sweep: slowly pans back and forth (for a wall screen or showcase);
##   Esc or C: close.
## Opened from Mission Control (Cameras) or by pressing E on a mast.

signal closed

const PAN_SPEED := 1.2      # radians a second with the keys
const DRAG := .005          # radians per pixel dragged
const FOV_RANGE := Vector2(14.0, 75.0)

var world: Node
var mast: Node              # the rig (equipment_rig.gd) being watched
var _port: SubViewport
var _camera: Camera3D
var _view: TextureRect
var _caption: Label
var _sweep: Button
var _thumbs: HBoxContainer
var _thumb_ports: Array = []   # [{mast, port, camera}]
var _thumb_clock := 0.0
var _dragging := false

func setup(target_world: Node, start: Node = null) -> Control:
	world = target_world
	mast = start
	return self

static func masts(tree: SceneTree) -> Array:
	var out: Array = tree.get_nodes_in_group("camera_mast").filter(func(m): return is_instance_valid(m) and m.is_inside_tree())
	out.sort_custom(func(a, b): return str(a._placement_id()) < str(b._placement_id()))
	return out

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(.03, .05, .06, 1.0)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var column := MHStyle.vbox(12)
	margin.add_child(column)
	var head := MHStyle.hbox(14)
	var titles := MHStyle.vbox(4)
	titles.add_child(MHStyle.eyebrow("%s · Outside cameras" % MHGame.colony_name, MHStyle.accent, 14))
	_caption = MHStyle.display("", 34)
	titles.add_child(_caption)
	head.add_child(titles)
	head.add_child(MHStyle.spacer())
	head.add_child(MHStyle.mono("DRAG OR WASD  AIM · WHEEL  ZOOM · TAB  NEXT MAST", 12, MHStyle.TEXT_MUTED))
	_sweep = MHStyle.button("Auto-sweep", "secondary", "rotate-cw")
	_sweep.toggle_mode = true
	_sweep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sweep.toggled.connect(func(on: bool) -> void:
		if mast != null: mast.set_camera_setting("cam_sweep", on))
	head.add_child(_sweep)
	var close := MHStyle.button("Close", "secondary", "x")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	head.add_child(close)
	column.add_child(head)
	var list := masts(get_tree())
	if list.is_empty():
		var empty := MHStyle.body("No camera masts yet. Build one outside: open the site plan (Shift+B), choose Outdoor, then Camera Mast. Up to 4 per base.", 18, MHStyle.TEXT_SECONDARY)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(empty)
		_caption.text = "No cameras"
		return
	if mast == null or not list.has(mast): mast = list[0]
	# The main view: its own camera in the same world, following the mast's lens.
	_port = SubViewport.new()
	_port.size = Vector2i(1280, 720)
	_port.world_3d = world.get_viewport().world_3d
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 900.0
	_port.add_child(_camera)
	add_child(_port)
	_view = TextureRect.new()
	_view.texture = _port.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_view_input)
	_view.draw.connect(_draw_overlay)
	column.add_child(_view)
	_thumbs = MHStyle.hbox(10)
	column.add_child(_thumbs)
	for each in list: _add_thumb(each)
	_thumbs.visible = list.size() > 1   # thumbnails only help with more than one mast
	_select(mast)

func _add_thumb(each: Node) -> void:
	var port := SubViewport.new()
	port.size = Vector2i(256, 144)
	port.world_3d = world.get_viewport().world_3d
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.current = true
	camera.far = 900.0
	port.add_child(camera)
	add_child(port)
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(256, 144)
	button.texture_normal = port.get_texture()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_select.bind(each))
	_thumbs.add_child(button)
	_thumb_ports.append({"mast": each, "port": port, "camera": camera, "button": button})

func _select(each: Node) -> void:
	mast = each
	_sweep.set_pressed_no_signal(bool(mast.camera_setting("cam_sweep", false)))
	var list := masts(get_tree())
	_caption.text = "Mast %d of %d" % [list.find(mast) + 1, list.size()]
	for thumb in _thumb_ports: (thumb.button as TextureButton).modulate = Color.WHITE if thumb.mast == mast else Color(1, 1, 1, .55)

func _process(delta: float) -> void:
	if mast == null or not is_instance_valid(mast) or _camera == null: return
	# Keys aim it (and stop any auto-sweep).
	var pan := float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	var tilt := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	if pan != 0.0 or tilt != 0.0: _turn(pan * PAN_SPEED * delta, tilt * PAN_SPEED * .6 * delta)
	_camera.global_transform = mast.camera_view()
	_camera.fov = float(mast.camera_setting("cam_fov", 60.0))
	_view.queue_redraw()
	_thumb_clock -= delta
	if _thumb_clock <= 0.0:
		_thumb_clock = 2.0
		for thumb in _thumb_ports:
			if not is_instance_valid(thumb.mast): continue
			(thumb.camera as Camera3D).global_transform = thumb.mast.camera_view()
			(thumb.camera as Camera3D).fov = float(thumb.mast.camera_setting("cam_fov", 60.0))
			(thumb.port as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

func _turn(yaw: float, pitch: float) -> void:
	if bool(mast.camera_setting("cam_sweep", false)):
		mast.set_camera_setting("cam_sweep", false)
		_sweep.set_pressed_no_signal(false)
	var now: Vector2 = mast.aim()
	mast.set_aim(now.x + yaw, now.y + pitch)

func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT: _dragging = button.pressed
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var fov := float(mast.camera_setting("cam_fov", 60.0)) * (.9 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / .9)
			mast.set_camera_setting("cam_fov", clampf(fov, FOV_RANGE.x, FOV_RANGE.y))
		_view.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_turn(-motion.relative.x * DRAG, -motion.relative.y * DRAG)
		_view.accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo: return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE or key == KEY_C or key == KEY_M:
		get_viewport().set_input_as_handled()
		_close()
	elif mast != null and key in [KEY_TAB, KEY_RIGHT, KEY_LEFT]:
		var list := masts(get_tree())
		if list.size() > 1: _select(list[(list.find(mast) + (-1 if key == KEY_LEFT else 1) + list.size()) % list.size()])
		get_viewport().set_input_as_handled()

## The camera's readout over the picture: heading, tilt, zoom and REC.
func _draw_overlay() -> void:
	if mast == null or not is_instance_valid(mast): return
	var font := MHStyle.font(700)
	var heading := wrapf(rad_to_deg(-_camera.global_rotation.y), 0.0, 360.0)
	var points := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var compass: String = points[roundi(heading / 45.0) % 8]
	var zoom := 60.0 / float(mast.camera_setting("cam_fov", 60.0))
	var text := "HEADING %03d° %s · TILT %+d° · ZOOM %.1f×%s" % [roundi(heading), compass, roundi(rad_to_deg(mast.aim().y)), zoom, " · AUTO-SWEEP" if bool(mast.camera_setting("cam_sweep", false)) else ""]
	_view.draw_rect(Rect2(Vector2(12, 12), Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 52, 30)), Color(0, 0, 0, .55))
	_view.draw_circle(Vector2(30, 27), 6, Color(1, .25, .2) if fmod(Time.get_ticks_msec() / 1000.0, 1.2) < .7 else Color(1, .25, .2, .25))
	_view.draw_string(font, Vector2(44, 33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MHStyle.TEXT_PRIMARY)
	# A thin centre cross.
	var c := _view.size * .5
	_view.draw_line(c - Vector2(14, 0), c + Vector2(14, 0), Color(1, 1, 1, .45), 1.0)
	_view.draw_line(c - Vector2(0, 14), c + Vector2(0, 14), Color(1, 1, 1, .45), 1.0)

func _close() -> void:
	closed.emit()
	queue_free()
