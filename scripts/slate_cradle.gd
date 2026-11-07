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
## Standing upright in a dock on top of the console's back panel (its
## static_back mesh), at eye level and facing the seats, so it's seen and
## clear of the console's own click box (8 Nov playtest: flat on the desk it
## hid and E found the console). Metres above the panel's top, and its lean.
const ABOVE_PANEL := .15
const LEAN := -14.0
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
	# The back panel as placed (the lander may fit the model to its spot).
	var panel: MeshInstance3D = null
	for mesh in console.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with("static_back"): panel = mesh
	if panel != null:
		var box := panel.get_aabb()
		global_position = panel.global_transform * Vector3(box.get_center().x, box.end.y + ABOVE_PANEL, box.get_center().z)
		# Its screen (+Z) faces the console's front (the model's −Z), leaning back a little.
		global_basis = panel.global_basis.orthonormalized() * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(LEAN))
	else:
		global_position = console.global_position + Vector3(0, 1.3, 0)
	_dock()
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
	box.size = Vector3(.36, .26, .12)   # a little generous, so it's easy to look at
	shape.shape = box
	add_child(shape)

## The dock it stands in: a small bracket under its bottom edge, house colours.
func _dock() -> void:
	var source := StandardMaterial3D.new()
	source.resource_name = "graphite"
	var mat := MHPalette.material(source)
	for spec in [[Vector3(.26, .025, .05), Vector3(0, -.095, .0)], [Vector3(.05, .05, .03), Vector3(0, -.115, -.03)]]:
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[0]
		block.mesh = mesh
		block.position = spec[1]
		block.material_override = mat
		add_child(block)

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
