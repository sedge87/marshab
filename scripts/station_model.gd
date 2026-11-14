extends Node3D

## Plain code-built models for A5's stations (rock saw, spectrometer,
## regolith washer, smelter), until a Blender pass. Built from boxes and
## cylinders whose material names carry the house roles (docs/house-style.md),
## so MHPalette gives them the base's colours: white shells, graphite
## recesses, satin metal trim, one orange accent each, a cyan screen and a
## status light. No lettering.

const MHPalette := preload("res://scripts/mh_palette.gd")

@export var kind := "rock_saw"

func _ready() -> void:
	match kind:
		"rock_saw": _rock_saw()
		"spectrometer": _spectrometer()
		"regolith_washer": _washer()
		"smelter": _smelter()
	MHPalette.apply(self)

# ---------- the pieces ----------

func _rock_saw() -> void:
	# A bench with a guarded diamond blade and a sample vice.
	_cabinet(Vector3(1.0, .82, .72))
	_box("worktop_shell_panel", Vector3(1.04, .06, .76), Vector3(0, .85, 0), "shell")
	_box("blade_guard_white", Vector3(.5, .26, .34), Vector3(.12, 1.02, 0), "white")
	_cyl("blade_steel", .17, .012, Vector3(.12, 1.0, 0), "metal", Vector3(PI * .5, 0, 0))
	_box("guard_window_black_glass", Vector3(.36, .14, .01), Vector3(.12, 1.04, -.172), "glass")
	_box("vice_frame", Vector3(.26, .08, .2), Vector3(-.3, .92, 0), "frame")
	_box("vice_jaw_orange", Vector3(.06, .1, .18), Vector3(-.2, .97, 0), "orange")
	_box("coolant_hose_rubber", Vector3(.04, .3, .04), Vector3(.42, 1.0, .24), "rubber")
	_status(Vector3(-.38, .78, -.37))

func _spectrometer() -> void:
	# A tall instrument: sample chamber, a lens turret and a screen.
	_cabinet(Vector3(.86, .9, .66))
	_box("instrument_white", Vector3(.82, .5, .6), Vector3(0, 1.17, .02), "white")
	_box("chamber_recess", Vector3(.36, .24, .04), Vector3(-.14, 1.12, -.29), "graphite")
	_box("chamber_door_black_glass", Vector3(.3, .18, .01), Vector3(-.14, 1.12, -.315), "glass")
	_cyl("lens_turret_steel", .07, .16, Vector3(.24, 1.5, .0), "metal")
	_box("handle_orange", Vector3(.2, .03, .04), Vector3(-.14, 1.27, -.32), "orange")
	_screen(Vector3(.26, .16), Vector3(.2, 1.15, -.305))
	_status(Vector3(.33, .82, -.34))

func _washer() -> void:
	# A drum washer on a frame: hopper on top, a sump tank, a hose to the floor drain.
	_cabinet(Vector3(1.0, .5, .8))
	_cyl("drum_white", .34, .7, Vector3(0, .9, 0), "white", Vector3(0, 0, PI * .5))
	_cyl("drum_band_orange", .345, .06, Vector3(.2, .9, 0), "orange", Vector3(0, 0, PI * .5))
	_box("hopper_frame", Vector3(.42, .3, .36), Vector3(-.2, 1.38, 0), "frame")
	_box("hopper_recess", Vector3(.34, .02, .28), Vector3(-.2, 1.54, 0), "graphite")
	_cyl("sump_tank_steel", .14, .32, Vector3(.36, .66, .26), "metal")
	_box("drain_hose_rubber", Vector3(.05, .05, .5), Vector3(.36, .5, -.1), "rubber")
	_screen(Vector3(.2, .12), Vector3(-.3, .36, -.405))
	_status(Vector3(.4, .44, -.41))

func _smelter() -> void:
	# A squat furnace with a heavy insulated door, a crucible tray and a flue.
	_cabinet(Vector3(1.8, .3, .96))
	_box("furnace_shell_panel", Vector3(1.1, 1.1, .9), Vector3(-.3, .85, 0), "shell")
	_box("door_recess", Vector3(.6, .6, .04), Vector3(-.3, .9, -.46), "graphite")
	_box("door_frame", Vector3(.52, .52, .06), Vector3(-.3, .9, -.49), "frame")
	_box("door_handle_orange", Vector3(.26, .04, .05), Vector3(-.3, 1.08, -.53), "orange")
	_cyl("flue_steel", .09, .7, Vector3(-.6, 1.75, .2), "metal")
	_box("pour_tray_frame", Vector3(.6, .08, .6), Vector3(.55, .62, 0), "frame")
	_box("mould_recess", Vector3(.46, .04, .2), Vector3(.55, .68, -.1), "graphite")
	_box("control_white", Vector3(.5, .5, .3), Vector3(.55, 1.0, .25), "white")
	_screen(Vector3(.22, .14), Vector3(.55, 1.08, .095))
	_status(Vector3(.75, .9, .095))

# ---------- helpers ----------

## The shared base: a white cabinet over a recessed dark plinth.
func _cabinet(size: Vector3) -> void:
	_box("plinth_recess", Vector3(size.x - .08, .08, size.z - .08), Vector3(0, .04, 0), "graphite")
	_box("cabinet_shell_panel", Vector3(size.x, size.y - .08, size.z), Vector3(0, .08 + (size.y - .08) * .5, 0), "shell")
	_box("door_seam_gasket", Vector3(.012, size.y - .2, .01), Vector3(0, .08 + (size.y - .08) * .5, -size.z * .5 - .004), "rubber")

const ROLE_COLOURS := {"white": "#F2F3F0", "shell": "#E3E7E5", "metal": "#C3CDD1", "frame": "#8796A0", "graphite": "#4C5A61", "rubber": "#323B40", "glass": "#25333A", "orange": "#E98A45"}

func _material(part: String, role: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = part
	material.albedo_color = Color(str(ROLE_COLOURS.get(role, "#C3CDD1")))
	return material

func _box(part: String, size: Vector3, at: Vector3, role: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(part, role)
	return _place(part, mesh, at, Vector3.ZERO)

func _cyl(part: String, radius: float, height: float, at: Vector3, role: String, turn := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = 24
	mesh.material = _material(part, role)
	return _place(part, mesh, at, turn)

func _place(part: String, mesh: Mesh, at: Vector3, turn: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part
	visual.mesh = mesh
	visual.position = at
	visual.rotation = turn
	add_child(visual)
	return visual

## A small cyan screen facing the front (-z): plain glow, no text.
func _screen(size: Vector2, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, .01)
	var material := StandardMaterial3D.new()
	material.resource_name = "display_screen_glass"
	material.albedo_color = Color("#1B3A44")
	material.emission_enabled = true
	material.emission = Color("#5FD0DC")
	material.emission_energy_multiplier = .6
	mesh.material = material
	_place("display_screen_glass", mesh, at, Vector3.ZERO)

func _status(at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = .018; mesh.height = .036
	var material := StandardMaterial3D.new()
	material.resource_name = "status_light_green"
	material.albedo_color = Color("#56D38A")
	material.emission_enabled = true
	material.emission = Color("#56D38A")
	material.emission_energy_multiplier = 1.2
	mesh.material = material
	_place("status_light_green", mesh, at, Vector3.ZERO)
