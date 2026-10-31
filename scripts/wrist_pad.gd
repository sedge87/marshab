extends Node3D

## The suit's wrist pad (scripts/suit.gd): your gloved left forearm with a
## small computer strapped on (the model: asset_packs/mars_suit_wrist_v1). Hold T to raise it into view; let go and it drops
## away. Its screen is a live info screen (info_screen.gd, "suit" mode):
## oxygen time, power, the scrubber, the turn-back time and the way to the
## nearest refill. It runs on the suit's own battery, not the habitat grid.
## A child of the first-person camera, so it moves with your view.

const INFO_SCREEN := preload("res://scripts/info_screen.gd")
const ARM_MODEL := preload("res://assets/models/suit/wrist_arm.glb")
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

func _build_arm() -> void:
	# The forearm, glove and pad case (asset_packs/mars_suit_wrist_v1), in
	# house materials, on the pad's own layer, casting no shadows.
	var model := (ARM_MODEL.instantiate() as Node3D)
	_arm.add_child(model)
	MHPalette.apply(model)
	var weave := _weave()
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		mesh.layers = LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The suit's fabric gets a fine weave, so it doesn't look like plastic.
		if mesh.name.contains("fabric"):
			for i in mesh.mesh.get_surface_count():
				var source := mesh.get_active_material(i) as StandardMaterial3D
				if source == null or source.resource_name.contains("rubber"): continue
				var cloth := source.duplicate() as StandardMaterial3D
				cloth.normal_enabled = true
				cloth.normal_texture = weave
				cloth.normal_scale = .35
				cloth.uv1_triplanar = true
				cloth.uv1_scale = Vector3.ONE * 90.0
				mesh.set_surface_override_material(i, cloth)
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

## A fine fabric weave, as a normal map.
static func _weave() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = .08
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 4.0
	texture.noise = noise
	return texture

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
