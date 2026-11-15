extends Node3D

## The lander cabin's status screen (playtest 8 Nov: "some sort of visual
## inside showing its power, water, air", diegetic and visual). A live
## screen on the side wall by the water dispenser (16 Nov: it hid the slate on the console): five tiles (air, water,
## power, heat, food), each an icon, a bar and one big number, amber when
## low, red when urgent (info_screen.gd "cabin" mode). A working display, so
## its text is fine; nothing is lettered on the model. Dark without power.

const INFO_SCREEN := preload("res://scripts/info_screen.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const SIZE := Vector2(.5, .3125)        # metres (16:10)
const PIXELS := Vector2i(640, 400)
const ABOVE := .34                      # (no longer used: it sat over the slate's dock)
const LEAN := -10.0
## 16 Nov playtest: off the console, where it hid the slate, onto the side
## wall by the water dispenser at standing eye height (lander space).
const ON_WALL := Vector3(2.16, 1.62, .78)

var world: Node
var _view: SubViewport
var screen: Control

func setup(target_world: Node, console: Node3D) -> void:
	world = target_world
	name = "CabinPanel"
	add_to_group("cabin_panel")
	world.lander.add_child(self)
	var outward := Vector3(ON_WALL.x, 0, ON_WALL.z).normalized()
	position = ON_WALL + Vector3(0, float(world.lander.DECK), 0)
	basis = Basis.looking_at(outward, Vector3.UP)   # its face (+Z) towards the cabin
	_view = SubViewport.new()
	_view.size = PIXELS
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)
	screen = INFO_SCREEN.new()
	screen.mode = "cabin"
	screen.viewport = _view
	screen.cabin = world.get("cabin_life")
	screen.pod = world.get("lifepod")
	_view.add_child(screen)
	# A thin graphite bezel behind the glass.
	var bezel := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(SIZE.x + .03, SIZE.y + .03, .02)
	bezel.mesh = box_mesh
	var source := StandardMaterial3D.new()
	source.resource_name = "graphite"
	bezel.material_override = MHPalette.material(source)
	bezel.position = Vector3(0, 0, -.012)
	add_child(bezel)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SIZE
	face.mesh = quad
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = _view.get_texture()
	face.material_override = glass
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(face)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#9FE3FF")
	glow.light_energy = .12
	glow.omni_range = .9
	glow.position = Vector3(0, 0, .2)
	glow.set_meta("budget_exempt", true)
	add_child(glow)
