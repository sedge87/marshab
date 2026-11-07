extends StaticBody3D

## Your slate, lying on the cabin console at touchdown (docs/pda.md §8): the
## lander start's first object. A few seconds in, a text comes in from orbit
## and its screen lights up and beeps; ARDEN says it's there. E picks it up,
## and it rises in your hands on what came in (scripts/pda.gd hand_over()).
## Opening the hatch without it takes it anyway: nobody leaves without it.
## The same model as the one in your hands (asset_packs/mars_slate_v1), its
## screen a plain glow: no lettering on the model.

const SLATE_MODEL := preload("res://assets/models/suit/slate.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
## On the console's worktop (its desk_top mesh), at the right end clear of
## the keys: this far in from the end, metres of the model.
const FROM_END := .14
const BEEP_EVERY := 6.0

var world: Node
var waiting := false        # lit up: a text has come in
var _screen: StandardMaterial3D
var _beep := 0.0
var _clock := 0.0

func setup(target_world: Node, console: Node3D) -> void:
	world = target_world
	name = "SlateOnConsole"
	add_to_group("slate_cradle")
	set_meta("interaction_target", self)
	world.lander.add_child(self)
	# The worktop as placed (the lander may fit the model to its spot).
	var top: MeshInstance3D = null
	for mesh in console.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with("desk_top"): top = mesh
	var yaw := console.global_rotation.y
	if top != null:
		var box := top.get_aabb()
		global_position = top.global_transform * Vector3(box.end.x - FROM_END, box.end.y + .012, box.get_center().z + .05)
		yaw = top.global_rotation.y
	else:
		global_position = console.global_position + Vector3(0, 1.0, 0)
	# Flat on the desk, screen up, its long side along the console.
	global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * .5)
	var model := SLATE_MODEL.instantiate() as Node3D
	add_child(model)
	MHPalette.apply(model)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.224, .14)
	face.mesh = quad
	_screen = StandardMaterial3D.new()
	_screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen.albedo_color = Color(.02, .03, .05)
	face.material_override = _screen
	face.position = Vector3(0, 0, .0085)
	add_child(face)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.3, .2, .06)
	shape.shape = box
	add_child(shape)

## A text has come in: the screen lights and it beeps now and then.
func light_up() -> void:
	waiting = true
	_beep = 0.0

func _process(delta: float) -> void:
	_clock += delta
	if not waiting: return
	var pulse := .55 + .45 * sin(_clock * 3.0)
	_screen.albedo_color = Color(.25, .55, .75).lerp(Color(.6, .9, 1.0), pulse)
	_beep -= delta
	if _beep <= 0.0:
		_beep = BEEP_EVERY
		MHAudio.sfx_at("suit_beep", self, -6.0, 0.0)

func interaction_prompt() -> Dictionary:
	return {"label": "Your slate", "primary": "Pick up"}

func interact(_actor: Node = null) -> bool:
	take()
	return true

## Into your hands: the world's slate (scripts/pda.gd) takes over.
## `raise` false: grabbed on the way out through the hatch, it goes in your pocket.
func take(raise := true) -> void:
	if is_queued_for_deletion(): return
	MHAudio.sfx("place", -10.0)
	var pda: Node = world.get("pda")
	if pda != null and not bool(pda.received): pda.hand_over(raise)
	queue_free()
