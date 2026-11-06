class_name MHPda
extends Node3D

## The slate (docs/pda.md): the crew's rugged handheld, in code the PDA. Tab
## lifts it into view and lowers it again; Esc lowers it too. Its screen is a
## live 2D page (pda_screen.gd) drawn into a SubViewport on the model
## (asset_packs/mars_slate_v1), and the mouse works on that screen directly:
## a cursor appears, clicks land where it points. The world keeps running
## while it's up (you stand still, and outside your oxygen keeps going).
## A child of the first-person camera, like the wrist pad (wrist_pad.gd).

const PDA_SCREEN := preload("res://scripts/pda_screen.gd")
const SLATE_MODEL := preload("res://assets/models/suit/slate.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const LAYER := 1 << 19                    # the wrist pad's layer: the helmet lamp skips it
const SCREEN := Vector2(.224, .14)        # the opening in the bezel, metres (16:10)
const PIXELS := Vector2i(1280, 800)
const FILL := .62                         # of the view's height, by the screen
const SPEED := 5.0                        # raise and lower, per second
const DROP := Vector3(.06, -.34, .1)      # lowered, below the view
const DIM := .5                           # the world behind, darkened

var world: Node
var raised := 0.0
var is_open := false
var received := true         # false from touchdown in the crew lander until ARDEN hands it over
var _handing := false        # the hand-over's own raise: it doesn't tick "Raise your slate"
var screen: Control
var _view: SubViewport
var _slate: Node3D
var _face: MeshInstance3D
var _dim: MeshInstance3D
var _dim_material: StandardMaterial3D
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _freeze_before := false
var _hidden: Array = []   # HUD parts hidden with the slate up: [node, was visible]

func setup(target_world: Node) -> MHPda:
	world = target_world
	return self

func _ready() -> void:
	name = "Slate"
	add_to_group("pda")
	received = not bool(world.get("_start_in_lander"))
	_slate = Node3D.new()
	add_child(_slate)
	var model := SLATE_MODEL.instantiate() as Node3D
	_slate.add_child(model)
	MHPalette.apply(model)
	for part in model.find_children("*", "MeshInstance3D", true, false):
		(part as MeshInstance3D).layers = LAYER
		(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The screen: a live page in a SubViewport, on a quad just proud of the case.
	_view = SubViewport.new()
	_view.size = PIXELS
	_view.transparent_bg = false
	_view.gui_embed_subwindows = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	screen = PDA_SCREEN.new()
	screen.world = world
	screen.pda = self
	_view.add_child(screen)
	_face = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN
	_face.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _view.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_face.material_override = material
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.position = Vector3(0, 0, .0085)
	_face.layers = LAYER
	_slate.add_child(_face)
	# A little screen glow on the case and gloves, for the dark.
	var glow := OmniLight3D.new()
	glow.light_color = Color("#9FE3FF")
	glow.light_energy = .12
	glow.omni_range = .3
	glow.position = Vector3(0, 0, .08)
	glow.light_cull_mask = LAYER
	glow.set_meta("budget_exempt", true)
	_slate.add_child(glow)
	# The world behind, dimmed so the screen reads: a dark veil just behind it.
	_dim = MeshInstance3D.new()
	var veil := QuadMesh.new()
	veil.size = Vector2(4, 4)
	_dim.mesh = veil
	_dim_material = StandardMaterial3D.new()
	_dim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dim_material.albedo_color = Color(0, 0, 0, 0)
	_dim_material.render_priority = -1
	_dim.material_override = _dim_material
	_dim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dim.layers = LAYER
	add_child(_dim)
	visible = false

## Where the slate sits, raised: far enough out that its screen fills FILL of
## the view's height, whatever the field of view.
func _raised_distance() -> float:
	var camera := get_parent() as Camera3D
	var fov := camera.fov if camera != null else 72.0
	return SCREEN.y / (FILL * 2.0 * tan(deg_to_rad(fov) / 2.0))

# ---------- up and down ----------

## Exploring (or parked in the rover), with nothing else open.
func can_open() -> bool:
	if world == null or get_tree().paused or not received: return false
	var player: Node = world.player
	if bool(player.get_meta("driving", false)) or bool(player.get_meta("ui_freeze", false)) or player._any_build_mode_active(): return false
	if world.get("interior_builder") != null and bool(world.interior_builder.active): return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

## The lander start (docs/pda.md §8): ARDEN passes the slate over once you've
## had a moment to take in the cabin. It lifts into view on Goals; lowering it
## is on you, and the first task then asks you to raise it yourself.
func hand_over() -> void:
	if received: return
	received = true
	_handing = true
	MHNotices.post("info", "ARDEN: your slate", "It has your goals, the map, the base, comms and a log of everything you're told. Tab raises and lowers it.", "goals")
	MHAudio.sfx("suit_beep", -8.0)
	open("goals")

## Raise it, on an app if one is named (otherwise the last one used).
func open(app := "") -> void:
	if is_open: return
	is_open = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_freeze_before = bool(world.player.get_meta("ui_freeze", false))
	world.player.set_meta("ui_freeze", true)
	# The HUD steps aside: the explore HUD, the checklist and its highlights,
	# a mission's panel and the alert icon row (the red edge glow stays). They
	# come back as they were.
	_hidden.clear()
	var tutorial: Node = world.get("tutorial")
	var alerts: Node = world.get("alerts")
	for layer in [world.get("explore_hud"), tutorial, tutorial.get("guide") if tutorial != null else null, alerts.get("_icons") if alerts != null else null]:
		if (layer is CanvasLayer or layer is CanvasItem) and is_instance_valid(layer):
			_hidden.append([layer, bool(layer.visible)])
			layer.visible = false
	MHNotices.hidden = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if world.get("guide_flags") != null and not _handing: world.guide_flags["slate"] = true   # the tutorial's first task
	screen.opened(app)
	MHAudio.sfx("suit_beep", -14.0)

func close() -> void:
	if not is_open: return
	is_open = false
	_handing = false
	Input.mouse_mode = _mouse_before
	world.player.set_meta("ui_freeze", _freeze_before)
	for entry in _hidden:
		if is_instance_valid(entry[0]): entry[0].visible = bool(entry[1])
	_hidden.clear()
	MHNotices.hidden = false
	screen.closed()
	MHAudio.sfx("ui_back", -12.0)

func _process(delta: float) -> void:
	# Dropped if something else takes over: a rescue, sleep, a cutscene, pause.
	if is_open and (get_tree().paused or bool(world.player.get_meta("driving", false))): close()
	raised = move_toward(raised, 1.0 if is_open else 0.0, delta * SPEED)
	visible = raised > 0.0
	if not visible:
		if _view.render_target_update_mode != SubViewport.UPDATE_DISABLED: _view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var t := ease(raised, -2.0)
	var at := Vector3(0, -.004, -_raised_distance())
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-50.0)) * Basis(Vector3.FORWARD, deg_to_rad(8.0))
	_slate.transform = Transform3D(tilt.slerp(Basis.IDENTITY, t), (at + DROP).lerp(at, t))
	_dim.position = Vector3(0, 0, at.z - .03)
	_dim_material.albedo_color.a = DIM * t

# ---------- keys and the mouse ----------

func _unhandled_input(event: InputEvent) -> void:
	if is_open or not (event is InputEventKey and event.pressed and not event.echo): return
	if (event as InputEventKey).keycode == KEY_TAB and can_open():
		open()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_open: return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_TAB or key.keycode == KEY_ESCAPE) and not screen.typing():
			close()
		else:
			_view.push_input(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		var at := _screen_point((event as InputEventMouse).position)
		if at.x >= 0.0:
			var moved := event.duplicate() as InputEventMouse
			moved.position = at
			moved.global_position = at
			if moved is InputEventMouseMotion:
				(moved as InputEventMouseMotion).relative *= float(PIXELS.y) / maxf(1.0, _screen_height_on_display())
			_view.push_input(moved, true)
		get_viewport().set_input_as_handled()

## Where on the slate's screen (its pixels) the mouse points, or (-1, -1).
func _screen_point(mouse: Vector2) -> Vector2:
	var camera := get_parent() as Camera3D
	if camera == null or raised < 1.0: return Vector2(-1, -1)
	var from := camera.project_ray_origin(mouse)
	var along := camera.project_ray_normal(mouse)
	var face := _face.global_transform
	var hit = Plane(face.basis.z.normalized(), face.origin).intersects_ray(from, along)
	if hit == null: return Vector2(-1, -1)
	var local: Vector3 = face.affine_inverse() * (hit as Vector3)
	var uv := Vector2(local.x / SCREEN.x + .5, .5 - local.y / SCREEN.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: return Vector2(-1, -1)
	return uv * Vector2(PIXELS)

func _screen_height_on_display() -> float:
	return FILL * get_viewport().get_visible_rect().size.y
