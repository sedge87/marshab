extends CanvasLayer

## GAR-Y orders (backlog item 29): hold G for a radial menu, move the mouse
## towards an order and let go. A quick tap of G still does the looked-at
## item's third action, as before.
##
## Inside: Come here, Stay here (or Carry on), Go home (its dock), Fetch (the
## small item you're looking at, else the sample jars or the plush) and
## Patrol. Outside: Come here, Stay here, Go home (waits by the airlock),
## Survey there and Core sample (where you're aiming). GAR-Y must be within
## 30 m; further off, Mission Control's map can send it.

const HOLD := .25          # seconds: shorter is a tap (the item's G action)
const RANGE := 30.0
const RADIUS := 150.0
const ICONS := {"come": "footprints", "stay": "map-pin", "home": "door-closed", "fetch": "package", "patrol": "clipboard-check",
	"survey": "mountain-snow", "core": "flask-conical"}

var world: Node
var _held := 0.0
var _open := false
var _pointer := Vector2.ZERO
var _orders: Array = []
var _selected := -1
var _aim := Vector3.INF
var _aim_item := ""
var _blocked := ""          # why there's no menu (too far away)
var _canvas: Control

func setup(target_world: Node) -> void:
	world = target_world
	layer = 7
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_menu)
	_canvas.visible = false
	add_child(_canvas)

func rover() -> Node:
	return world.scout_rover if world != null and is_instance_valid(world.scout_rover) else null

func _player() -> Node3D:
	return world.player if world != null else null

func _can_use() -> bool:
	var player := _player()
	return player != null and not get_tree().paused and not player._any_build_mode_active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	var down := Input.is_physical_key_pressed(KEY_G)
	if down and (_open or _can_use()):
		_held += delta
		if not _open and _held >= HOLD: _open_menu()
	elif _held > 0.0:
		if _open: _choose()
		elif _held < HOLD and _can_use(): _player()._use_looked_at_interactable("interact_tertiary")
		_held = 0.0
		_close_menu()

## While open, mouse movement points at an order instead of turning your head.
func _input(event: InputEvent) -> void:
	if not _open or not event is InputEventMouseMotion: return
	_pointer += (event as InputEventMouseMotion).relative
	if _pointer.length() > RADIUS: _pointer = _pointer.normalized() * RADIUS
	_selected = _sector(_pointer)
	_canvas.queue_redraw()
	get_viewport().set_input_as_handled()

func _sector(at: Vector2) -> int:
	if at.length() < 40.0 or _orders.is_empty(): return -1
	var step := TAU / _orders.size()
	var angle := fposmod(atan2(at.x, -at.y) + step * .5, TAU)
	return int(angle / step) % _orders.size()

func _open_menu() -> void:
	var gary := rover()
	_open = true
	_pointer = Vector2.ZERO
	_selected = -1
	_blocked = ""
	_orders = []
	if gary == null:
		_blocked = "GAR-Y isn't with you on this mission."
	else:
		var distance: float = gary.global_position.distance_to(_player().global_position)
		if distance > RANGE: _blocked = "GAR-Y is %d m away. Go closer, or send it from Mission Control's map (M)." % roundi(distance)
		else: _orders = gary.available_orders()
	_aim_at()
	_canvas.visible = true
	_canvas.queue_redraw()
	MHAudio.sfx("ui_hover", -4.0, 0.0)

func _close_menu() -> void:
	_open = false
	_canvas.visible = false

func _choose() -> void:
	var gary := rover()
	if gary == null or _selected < 0 or _selected >= _orders.size(): return
	var kind := str(_orders[_selected])
	var why: String = gary.order(kind, _aim, _aim_item)
	if why.is_empty():
		MHAudio.sfx("ui_confirm", -4.0, 0.0)
	else:
		MHAudio.sfx("invalid", -4.0, 0.0)
		get_tree().call_group("explore_hud", "show_equipment_note", "GAR-Y", why)

## Where you're looking: a ground point (survey, core sample) and the small
## item there, if any (fetch).
func _aim_at() -> void:
	_aim = Vector3.INF
	_aim_item = ""
	var camera := _player().get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_transform.basis.z * 60.0)
	query.exclude = [_player().get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# Looking at the sky or the horizon: about 12 m ahead of you.
		var ahead := -camera.global_transform.basis.z
		ahead.y = 0.0
		_aim = _player().global_position + ahead.normalized() * 12.0
		return
	_aim = hit.position
	var node: Node = hit.collider
	while node != null:
		if node.has_meta("interior_placement_id"):
			_aim_item = str(node.get_meta("interior_placement_id"))
			break
		node = node.get_parent()

func _label(kind: String) -> String:
	var gary := rover()
	if kind == "stay" and gary != null and bool(gary.staying): return "Carry on"
	return str(gary.ORDER_LABELS.get(kind, kind)) if gary != null else kind

func _draw_menu() -> void:
	var centre := _canvas.size * .5
	var font := MHStyle.font(700)
	_canvas.draw_circle(centre, RADIUS + 54.0, Color(0, 0, 0, .4))
	_canvas.draw_arc(centre, RADIUS + 54.0, 0, TAU, 96, Color(MHStyle.accent, .5), 2.0)
	var gary := rover()
	var title := "GAR-Y"
	_canvas.draw_string(font, centre + Vector2(-60, -6), title, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, MHStyle.TEXT_PRIMARY)
	var status := str(gary.status_text()) if gary != null else ""
	_canvas.draw_string(MHStyle.font(500), centre + Vector2(-90, 16), status, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, MHStyle.TEXT_MUTED)
	if not _blocked.is_empty():
		_canvas.draw_string(MHStyle.font(500), centre + Vector2(-200, RADIUS + 120), _blocked, HORIZONTAL_ALIGNMENT_CENTER, 400, 15, MHStyle.WARN)
		return
	var step := TAU / maxf(1.0, _orders.size())
	for i in range(_orders.size()):
		var kind := str(_orders[i])
		var angle := i * step
		var direction := Vector2(sin(angle), -cos(angle))
		var at := centre + direction * RADIUS
		var on := i == _selected
		_canvas.draw_circle(at, 46.0, Color(MHStyle.accent, .9) if on else Color(.08, .1, .12, .9))
		_canvas.draw_arc(at, 46.0, 0, TAU, 48, MHStyle.accent if on else Color(1, 1, 1, .25), 2.0)
		var icon := MHIcons.texture(str(ICONS.get(kind, "circle-dashed")), 28)
		_canvas.draw_texture_rect(icon, Rect2(at - Vector2(17, 17), Vector2(34, 34)), false, Color("#0C1316") if on else MHStyle.TEXT_PRIMARY)
		# The label sits just outside the bubble, away from the centre.
		var label_at := at + direction * 64.0 + Vector2(-70, 5)
		_canvas.draw_string(font, label_at + Vector2(1, 1), _label(kind).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(0, 0, 0, .7))
		_canvas.draw_string(font, label_at, _label(kind).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 13, MHStyle.accent if on else MHStyle.TEXT_PRIMARY)
	# The pointer, and a hint.
	_canvas.draw_line(centre, centre + _pointer, Color(MHStyle.accent, .7), 2.0)
	var hint := "Move the mouse to an order, let go of G" if _selected < 0 else _hint(str(_orders[_selected]))
	_canvas.draw_string(MHStyle.font(500), centre + Vector2(-220, RADIUS + 120), hint, HORIZONTAL_ALIGNMENT_CENTER, 440, 15, MHStyle.TEXT_SECONDARY)

func _hint(kind: String) -> String:
	match kind:
		"come": return "Follows close behind you for a while (through airlocks you cycle)."
		"stay": return "Waits right here until you give another order." if not bool(rover().staying) else "Back to pottering about."
		"home": return "To its GAR-Y Dock to charge." if rover()._self_indoors() else "Waits outside the airlock."
		"fetch": return "Brings you the small item you're looking at (or the sample jars)."
		"patrol": return "Checks every room, then reports any alerts."
		"survey": return "Drives where you're aiming and scans for buried ice." if _aim != Vector3.INF else "Aim at the ground first."
		"core": return "Drills a core sample where you're aiming, for the Science Lab." if _aim != Vector3.INF else "Aim at the ground first."
	return ""
