extends Node3D

## The lander's lifepod bench (step 3b, scripts/lifepod.gd): a fold-down
## worktop on the cabin's right wall, where a supply crate stood. On it, left
## to right as you face it: the ice melter, the bench with a hand lens and a
## lamp (and a shelf above where your studied samples sit), and the tiny
## printer. Plain parts in the house colours; no lettering.

const MHPalette := preload("res://scripts/mh_palette.gd")
const STATION := preload("res://scripts/lifepod_station.gd")
const FIND := preload("res://scripts/carried_find.gd")
## Lander frame, on the deck: centre of the bench, against the right wall.
const AT := Vector3(1.52, 0, -.5)
const TOP := .82                  # worktop height above the deck

var lifepod: Node
var stations := {}
var _shelf: Node3D
var _print_lamp: OmniLight3D
var _water_level: MeshInstance3D

func setup(target_lifepod: Node, lander: Node3D) -> void:
	lifepod = target_lifepod
	name = "LifepodBench"
	lander.add_child(self)
	position = AT + Vector3(0, float(lander.DECK), 0)
	rotation.y = PI * .5    # its front (−Z) faces into the cabin (−X)
	_build()

func _mat(role: String) -> StandardMaterial3D:
	var source := StandardMaterial3D.new()
	source.resource_name = role
	return MHPalette.material(source)

func _block(size: Vector3, at: Vector3, role: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _mat(role)
	parent.add_child(mesh)
	return mesh

func _build() -> void:
	# The worktop on two folding legs, a back panel and a shelf.
	_block(Vector3(1.0, .04, .5), Vector3(0, TOP, 0), "shell")
	for side in [-.44, .44]:
		_block(Vector3(.04, TOP, .04), Vector3(side, TOP * .5, -.18), "frame")
	_block(Vector3(1.0, .7, .03), Vector3(0, TOP + .35, .24), "white")
	_shelf = Node3D.new()
	_shelf.name = "Shelf"
	add_child(_shelf)
	_block(Vector3(.9, .03, .18), Vector3(0, TOP + .52, .15), "shell")
	# The melter: a squat box with a hopper and a small sight glass on the water level.
	var melter := Node3D.new()
	melter.position = Vector3(-.32, TOP + .02, -.02)
	add_child(melter)
	_block(Vector3(.26, .22, .3), Vector3(0, .11, 0), "white", melter)
	_block(Vector3(.2, .06, .22), Vector3(0, .25, 0), "graphite", melter)
	_block(Vector3(.05, .14, .02), Vector3(.09, .12, -.16), "glass", melter)
	_water_level = _block(Vector3(.04, .12, .01), Vector3(.09, .1, -.168), "teal", melter)
	_block(Vector3(.12, .02, .02), Vector3(-.06, .2, -.155), "orange", melter)
	# The bench: a hand lens on a little arm, and a lamp.
	var study := Node3D.new()
	study.position = Vector3(0, TOP + .02, -.02)
	add_child(study)
	_block(Vector3(.22, .01, .22), Vector3(0, .005, 0), "graphite", study)
	_block(Vector3(.02, .24, .02), Vector3(.12, .12, .08), "metal", study)
	var lens := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = .05
	disc.bottom_radius = .05
	disc.height = .01
	lens.mesh = disc
	lens.position = Vector3(.06, .22, .02)
	lens.rotation.x = deg_to_rad(70)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "lens_clear"
	glass.albedo_color = Color(.85, .95, 1.0, .35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens.material_override = glass
	study.add_child(lens)
	# The printer: a box with a window and a lamp inside that glows while it works.
	var printer := Node3D.new()
	printer.position = Vector3(.32, TOP + .02, -.02)
	add_child(printer)
	_block(Vector3(.28, .3, .3), Vector3(0, .15, 0), "white", printer)
	_block(Vector3(.2, .14, .01), Vector3(0, .17, -.152), "glass", printer)
	_block(Vector3(.26, .03, .02), Vector3(0, .02, -.15), "orange", printer)
	_print_lamp = OmniLight3D.new()
	_print_lamp.light_color = Color("#FFB866")
	_print_lamp.light_energy = 0.0
	_print_lamp.omni_range = .6
	_print_lamp.position = Vector3(0, .17, -.05)
	printer.add_child(_print_lamp)
	# The three stations, each taking E for itself.
	for spec in [["melter", melter, Vector3(.3, .3, .34)], ["study", study, Vector3(.3, .3, .34)], ["printer", printer, Vector3(.3, .34, .34)]]:
		var station: StaticBody3D = STATION.new()
		(spec[1] as Node3D).add_child(station)
		station.setup(lifepod, str(spec[0]), spec[2])
		stations[spec[0]] = station
	# The worktop itself is solid.
	var body := StaticBody3D.new()
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, TOP, .5)
	shape.shape = box
	shape.position = Vector3(0, TOP * .5, 0)
	body.add_child(shape)

func printing(on: bool) -> void:
	if _print_lamp == null: return
	create_tween().tween_property(_print_lamp, "light_energy", .9 if on else 0.0, .4)

## The sight glass shows the tank's level.
func _process(_delta: float) -> void:
	if _water_level == null or lifepod == null: return
	var level := clampf(float(lifepod.water_l()) / maxf(1.0, float(lifepod.water_cap())), .02, 1.0)
	_water_level.scale.y = level
	_water_level.position.y = .04 + .06 * level

## Studied samples sit on the shelf, in a row.
func shelve(kind: String, source: String) -> void:
	var count := _shelf.get_child_count()
	if count >= 8: return
	var lump := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.07, .05, .06)
	lump.mesh = box
	lump.position = Vector3(-.38 + count * .1, TOP + .56, .15)
	lump.rotation.y = count * .7
	lump.material_override = FIND.material("ice" if kind == "ice" else ("rock" if source == "iron" else "bead"))
	_shelf.add_child(lump)
