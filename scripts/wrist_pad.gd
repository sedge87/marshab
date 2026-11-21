extends Node3D

## The suit's wrist pad (scripts/suit.gd): your gloved left forearm with a
## small computer strapped on. Hold Alt (or D-pad up) to raise it into view;
## let go and it drops away. Its screen is a live info screen
## (info_screen.gd, "suit" mode): the ring of air with its home notch, power,
## the sky, the way to the nearest refill and the status icons. It runs on the
## suit's own battery, not the habitat grid. A child of the first-person
## camera, so it moves with your view.
##
## 21 Nov: the V05 arm (deliverables/Wrist_Review_01, CLAUDE_HANDOFF.md), with
## its own clips doing the whole lift: wrist_raise (0.5 s; wrist_raise_first,
## slower, the very first time), wrist_read_idle looping while held, and
## wrist_lower (0.43 s). It's held at the V06 mount, where the elbow stays out
## of view at any field of view up to 90 degrees. The old arm
## (assets/models/suit/wrist_arm.glb) stays in the project as a fallback.

const INFO_SCREEN := preload("res://scripts/info_screen.gd")
const ARM_MODEL := preload("res://assets/models/suit/wrist_arm_v05.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
## Checked like a watch (21 Nov): the forearm comes across in front of your
## chest and your head dips to meet it. Head space (the view before the dip):
## the screen's centre, which way it faces, and the forearm's line toward the
## fingers. (Was the V06 mount, up at eye level 17 cm out.)
const SCREEN_AT := Vector3(-.026, -.13, -.165)
const FACING := Vector3(.12, .61, .78)
const ALONG := Vector3(.92, .1, -.35)
## How far your head dips to read it (radians, about 30 degrees).
const DIP := .52
## The screen's centre in the model's own space (Blender (-.118, 0, .008)).
const SCREEN_LOCAL := Vector3(-.118, .008, 0)
const BLEND := .08   # seconds to blend between clips (letting go mid-raise)
## Its own render layer, so the helmet lamp a few centimetres away doesn't
## blow it out (the lamp skips this layer).
const LAYER := 1 << 19

var suit: Node
## How far up it is, 0 (away) to 1 (reading), following the clips.
var raised := 0.0
var held := false   # raised without the key (captures and tests)
var _arm: Node3D
var _anim: AnimationPlayer
var _screen: Control
var _view: SubViewport
## "down", "raising", "reading" or "lowering".
var _state := "down"

func _ready() -> void:
	name = "WristPad"
	_arm = Node3D.new()
	add_child(_arm)
	var facing := FACING.normalized()
	var along := (ALONG - facing * ALONG.dot(facing)).normalized()
	var basis := Basis(along, facing, along.cross(facing)).orthonormalized()
	_arm.transform = Transform3D(basis, SCREEN_AT - basis * SCREEN_LOCAL)
	var lamp := get_parent().get_node_or_null("Flashlight") as Light3D
	if lamp != null:
		lamp.light_cull_mask &= ~LAYER
		for spill in lamp.find_children("*", "Light3D", true, false): (spill as Light3D).light_cull_mask &= ~LAYER
	_build_arm()
	visible = false

func _build_arm() -> void:
	# The forearm, glove and pad case, in house materials, on the pad's own
	# layer, casting no shadows.
	var model := (ARM_MODEL.instantiate() as Node3D)
	_arm.add_child(model)
	MHPalette.apply(model)
	_anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_anim.get_animation("wrist_read_idle").loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_clip_done)
	var weave := _weave()
	var display: MeshInstance3D
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		mesh.layers = LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name.contains("Display_Surface_Wrist"): display = mesh
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
	# Its screen: the live face, drawn into a viewport on the model's display.
	_view = SubViewport.new()
	_view.size = Vector2i(720, 480)
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)
	_screen = INFO_SCREEN.new()
	_screen.mode = "suit"
	_screen.viewport = _view
	_screen.suit = suit
	_view.add_child(_screen)
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = _view.get_texture()
	screen_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if display != null: display.material_override = screen_material
	# A little screen glow on the glove and sleeve, for the dark: just off the
	# screen where it sits while you read.
	var glow := OmniLight3D.new()
	glow.light_color = Color("#9FE3FF")
	glow.light_energy = .07
	glow.omni_range = .16
	glow.position = SCREEN_LOCAL + Vector3(0, .04, 0)
	glow.light_cull_mask = LAYER
	glow.set_meta("budget_exempt", true)
	model.add_child(glow)

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
	return MHInput.held("wrist") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED   # hold Alt (21 Nov: was T) or D-pad up

func _process(_delta: float) -> void:
	var up := wanted()
	if up and _state in ["down", "lowering"]:
		if _state == "down":
			MHAudio.sfx("suit_beep", -18.0)
			_screen.refresh()
		# The very first look is the slow one; after that, quick.
		var first := suit != null and int(suit.get("wrist_hint_uses")) == 0 and _state == "down"
		_anim.play("wrist_raise_first" if first else "wrist_raise", -1.0 if _state == "down" else BLEND)
		# Pose it at the clip's first frame now: play() only poses it on the
		# player's next update, and for that one frame the arm would show in
		# its rest pose, up in view, before dropping and lifting (21 Nov).
		if _state == "down": _anim.seek(0.0, true)
		if _state == "down" and suit != null: suit.wrist_raised()
		_state = "raising"
	elif not up and _state in ["raising", "reading"]:
		_anim.play("wrist_lower", BLEND)
		_state = "lowering"
	visible = _state != "down"
	_screen.set_process(visible)
	match _state:
		"raising": raised = _progress()
		"reading": raised = 1.0
		"lowering": raised = 1.0 - _progress()
		_: raised = 0.0
	_dip()

## Your head dips with the lift: the camera pitches down and the pad, its
## child, turns back the same, so the arm stays put by your chest. The look
## (Head) is left alone, so your aim comes back where it was.
var _dipped := 0.0
func _dip() -> void:
	var dip := DIP * smoothstep(0.0, 1.0, raised)
	if dip == 0.0 and _dipped == 0.0: return
	_dipped = dip
	rotation.x = dip
	var camera := get_parent() as Camera3D
	if camera != null: camera.rotation.x = -dip
	var player := get_tree().get_first_node_in_group("player")
	if player != null: player.set_meta("wrist_tilt", dip)   # body.gd eases the camera toward it

func _progress() -> float:
	var length := _anim.current_animation_length
	return clampf(_anim.current_animation_position / length, 0.0, 1.0) if length > 0.0 else 1.0

func _clip_done(clip: StringName) -> void:
	if str(clip).begins_with("wrist_raise") and _state == "raising":
		_anim.play("wrist_read_idle")
		_state = "reading"
	elif clip == &"wrist_lower" and _state == "lowering":
		_anim.stop()
		_state = "down"
		visible = false
