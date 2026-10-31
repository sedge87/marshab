extends Node3D

## The suit's wrist pad (scripts/suit.gd): your left forearm with a small
## computer on the cuff. Hold T to raise it into view; let go and it drops
## away. Its screen is a live info screen (info_screen.gd, "suit" mode):
## oxygen time, power, the scrubber, the turn-back time and the way to the
## nearest refill. It runs on the suit's own battery, not the habitat grid.
## A child of the first-person camera, so it moves with your view.

const INFO_SCREEN := preload("res://scripts/info_screen.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const RAISED := Vector3(-.03, -.1, -.33)     # the pad, raised, in the camera's space
const DROP := Vector3(-.05, -.42, .06)
const SPEED := 6.0                           # raise and drop, per second
## Its own render layer, so the helmet lamp a few centimetres away doesn't
## blow it out (the lamp skips this layer).
const LAYER := 1 << 19

var suit: Node
var raised := 0.0
var held := false   # raised without T (captures and tests)
var _arm: Node3D
var _screen: Control
var _view: SubViewport
var _raised_basis: Basis
var _lowered_basis: Basis

func _ready() -> void:
	name = "WristPad"
	# The pad faces your eyes; the forearm runs in from the lower left.
	var facing := (-RAISED).normalized()
	var along := Vector3(1.0, .06, -.22)
	along = (along - facing * along.dot(facing)).normalized()
	_raised_basis = Basis(along, facing, along.cross(facing)).orthonormalized()
	_lowered_basis = Basis(Vector3.RIGHT, deg_to_rad(-55.0)) * _raised_basis
	_arm = Node3D.new()
	add_child(_arm)
	var lamp := get_parent().get_node_or_null("Flashlight") as Light3D
	if lamp != null:
		lamp.light_cull_mask &= ~LAYER
		for spill in lamp.find_children("*", "Light3D", true, false): (spill as Light3D).light_cull_mask &= ~LAYER
	_build_arm()
	visible = false

func _part(mesh: Mesh, material_name: String, colour: Color, at: Vector3, rotation_deg := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = colour
	mesh.surface_set_material(0, material)
	part.position = at
	part.rotation_degrees = rotation_deg
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.layers = LAYER
	_arm.add_child(part)
	return part

func _build_arm() -> void:
	# The sleeve, along the arm's X (the wrist is at +X).
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = .043; sleeve.bottom_radius = .05; sleeve.height = .36
	_part(sleeve, "suit_fabric_white", Color.WHITE, Vector3(-.17, -.045, 0), Vector3(0, 0, 90))
	var cuff := CylinderMesh.new()
	cuff.top_radius = .047; cuff.bottom_radius = .047; cuff.height = .03
	_part(cuff, "cuff_orange", Color("#E98A45"), Vector3(.02, -.045, 0), Vector3(0, 0, 90))
	var glove := CapsuleMesh.new()
	glove.radius = .04; glove.height = .13
	_part(glove, "glove_rubber", Color("#323B40"), Vector3(.075, -.048, 0), Vector3(0, 0, 90))
	# The pad: a dark case strapped on top of the forearm.
	var case := BoxMesh.new()
	case.size = Vector3(.135, .018, .094)
	_part(case, "pad_graphite", Color("#4C5A61"), Vector3(-.08, .0, 0))
	for x in [-.135, -.025]:
		var strap := BoxMesh.new()
		strap.size = Vector3(.018, .1, .104)
		_part(strap, "strap_rubber", Color("#323B40"), Vector3(x, -.045, 0))
	MHPalette.apply(_arm)
	# Its screen.
	_view = SubViewport.new()
	_view.size = Vector2i(480, 320)
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)
	_screen = INFO_SCREEN.new()
	_screen.mode = "suit"
	_screen.viewport = _view
	_screen.suit = suit
	_view.add_child(_screen)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.12, .12 * 320.0 / 480.0)
	face.mesh = quad
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = _view.get_texture()
	face.material_override = screen_material
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.position = Vector3(-.08, .0095, 0)
	face.layers = LAYER
	face.rotation_degrees = Vector3(-90, 0, 0)
	_arm.add_child(face)
	# A little screen glow on the glove and sleeve, for the dark.
	var glow := OmniLight3D.new()
	glow.light_color = Color("#9FE3FF")
	glow.light_energy = .07
	glow.omni_range = .16
	glow.position = Vector3(-.08, .05, 0)
	glow.light_cull_mask = LAYER
	glow.set_meta("budget_exempt", true)
	_arm.add_child(glow)

func wanted() -> bool:
	if held: return true
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or get_tree().paused: return false
	if bool(player.get_meta("driving", false)) or bool(player.get_meta("ui_freeze", false)) or player._any_build_mode_active(): return false
	return Input.is_physical_key_pressed(KEY_T) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	var up := wanted()
	var was := raised
	raised = move_toward(raised, 1.0 if up else 0.0, delta * SPEED)
	if raised > 0.0 and was <= 0.0:
		MHAudio.sfx("suit_beep", -18.0)
		_screen.refresh()
	visible = raised > 0.0
	_screen.set_process(visible)
	if not visible: return
	var t := ease(raised, -2.0)
	_arm.transform = Transform3D(_lowered_basis.slerp(_raised_basis, t), DROP.lerp(Vector3.ZERO, t) + RAISED)
