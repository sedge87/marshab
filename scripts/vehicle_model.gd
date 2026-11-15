extends Node3D

## Plain code-built models for A7 (docs/bases-and-vehicles.md, "As built
## (A7)"), until a Blender pass: the scout buggy, the scout drone, the drone
## dock and the scattered debris of a cargo wreck. Boxes and cylinders whose
## material names carry the house roles (docs/house-style.md), so MHPalette
## gives them the base's colours. No lettering; screens are plain glow until
## a vehicle draws its dashboard on them.
##
## Front is -Z. The buggy's wheels are named wheel_fl / wheel_fr / wheel_rl /
## wheel_rr (scripts/crew_rover.gd spins and steers them); the drone's rotors
## are rotor_top / rotor_bottom.

const MHPalette := preload("res://scripts/mh_palette.gd")

@export var kind := "buggy"

## Buggy sizes, shared with its driving spec in crew_rover.gd.
const BUGGY_WHEEL_R := .38
const BUGGY_HALF_TRACK := .92
const BUGGY_HALF_BASE := 1.12

func _ready() -> void:
	match kind:
		"buggy": _buggy()
		"drone": _drone()
		"drone_dock": _drone_dock()
		"wreck_small": _wreck(1.0)
		"wreck_big": _wreck(2.4)
	MHPalette.apply(self)

# ---------- the scout buggy ----------

func _buggy() -> void:
	# An open two-seat frame on four wire-mesh wheels: like Apollo's LRV,
	# with a roll hoop, a small rear locker and a solar panel on a mast.
	var r := BUGGY_WHEEL_R
	var deck_y := r + .12
	_box("chassis_frame", Vector3(1.3, .12, 2.5), Vector3(0, deck_y, 0), "frame")
	_box("floor_pan_graphite", Vector3(1.2, .03, 1.5), Vector3(0, deck_y + .07, .1), "graphite")
	for side in [-1.0, 1.0]:
		_box("side_rail_steel", Vector3(.05, .05, 2.4), Vector3(side * .64, deck_y + .1, 0), "metal")
		# Fenders over each wheel.
		for end in [-1.0, 1.0]:
			_box("fender_white", Vector3(.34, .04, .8), Vector3(side * BUGGY_HALF_TRACK, r * 2.0 + .08, end * BUGGY_HALF_BASE), "white")
			_box("suspension_arm_frame", Vector3(.3, .06, .1), Vector3(side * (BUGGY_HALF_TRACK - .2), r, end * BUGGY_HALF_BASE), "frame")
	# Two seats, side by side; the driver sits on the left.
	for x in [-.32, .32]:
		_box("seat_pan_shell", Vector3(.48, .08, .5), Vector3(x, deck_y + .3, .2), "shell")
		_box("seat_back_shell", Vector3(.48, .55, .07), Vector3(x, deck_y + .58, .46), "shell")
		_box("seat_strap_orange", Vector3(.05, .5, .01), Vector3(x + .12, deck_y + .58, .42), "orange")
		_box("seat_frame", Vector3(.4, .26, .4), Vector3(x, deck_y + .14, .2), "frame")
	# The roll hoop behind the seats.
	for x in [-.6, .6]:
		_cyl("roll_hoop_steel", .03, 1.1, Vector3(x, deck_y + .6, .58), "metal")
	_cyl("roll_hoop_steel", .03, 1.2, Vector3(0, deck_y + 1.15, .58), "metal", Vector3(0, 0, PI * .5))
	# The control column in front of the driver: hand controller and the dashboard.
	_box("column_frame", Vector3(.08, .5, .08), Vector3(-.32, deck_y + .3, -.42), "frame")
	_box("dash_housing_graphite", Vector3(.46, .3, .06), Vector3(-.32, deck_y + .66, -.5), "graphite").rotation.x = deg_to_rad(-25)
	# The screen itself (a quad facing the driver: crew_rover.gd draws the dashboard on it).
	var quad := QuadMesh.new()
	quad.size = Vector2(.4, .234)
	quad.material = _material("dash_screen_glass", "glass")
	var dash := _place(self, "dash_screen", quad, Vector3(-.32, deck_y + .665, -.462), Vector3.ZERO)
	dash.rotation.x = deg_to_rad(-25)
	_box("hand_controller_rubber", Vector3(.06, .14, .06), Vector3(-.12, deck_y + .45, -.3), "rubber")
	# The rear locker and the solar mast.
	_box("locker_white", Vector3(1.1, .4, .45), Vector3(0, deck_y + .26, 1.0), "white")
	_box("locker_latch_orange", Vector3(.16, .05, .02), Vector3(0, deck_y + .32, .765), "orange")
	_cyl("mast_steel", .025, .9, Vector3(.5, deck_y + .9, 1.1), "metal")
	_box("solar_panel_black_glass", Vector3(.9, .02, .6), Vector3(.5, deck_y + 1.36, 1.1), "glass").rotation.x = deg_to_rad(12)
	_box("solar_frame", Vector3(.94, .03, .64), Vector3(.5, deck_y + 1.345, 1.1), "frame").rotation.x = deg_to_rad(12)
	# The high-gain dish on its own short mast.
	_cyl("antenna_mast_steel", .015, .6, Vector3(-.5, deck_y + .8, 1.05), "metal")
	_cyl("antenna_dish_white", .2, .03, Vector3(-.5, deck_y + 1.12, 1.05), "white", Vector3(deg_to_rad(-60), 0, 0))
	# Headlight pods on the front bumper.
	_box("bumper_frame", Vector3(1.2, .08, .08), Vector3(0, deck_y + .02, -1.28), "frame")
	for x in [-.45, .45]:
		_box("lamp_pod_graphite", Vector3(.16, .1, .08), Vector3(x, deck_y + .1, -1.3), "graphite")
	# The wheels: mesh tyres with chevron treads, on hubs.
	for key in ["fl", "fr", "rl", "rr"]:
		var wheel := Node3D.new()
		wheel.name = "wheel_" + key
		wheel.position = Vector3(BUGGY_HALF_TRACK * (-1.0 if key.ends_with("l") else 1.0), r, BUGGY_HALF_BASE * (-1.0 if key.begins_with("f") else 1.0))
		add_child(wheel)
		_cyl_in(wheel, "tyre_mesh_steel", r, .24, Vector3.ZERO, "metal", Vector3(0, 0, PI * .5))
		_cyl_in(wheel, "hub_graphite", .12, .26, Vector3.ZERO, "graphite", Vector3(0, 0, PI * .5))
		for i in 8:
			var a := TAU * i / 8.0
			_box_in(wheel, "tread_chevron_rubber", Vector3(.25, .05, .08), Vector3(0, sin(a) * (r - .01), cos(a) * (r - .01)), "rubber").rotation.x = -a

# ---------- the scout drone ----------

func _drone() -> void:
	# Ingenuity's layout, a little bigger: a cube body on four legs, a mast
	# with two counter-rotating rotors, and a solar panel on top.
	_box("body_white", Vector3(.3, .2, .3), Vector3(0, .42, 0), "white")
	_box("camera_pod_black_glass", Vector3(.08, .06, .02), Vector3(0, .38, -.16), "glass")
	_box("body_band_orange", Vector3(.31, .03, .31), Vector3(0, .5, 0), "orange")
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := _box("leg_frame", Vector3(.02, .5, .02), Vector3(corner.x * .26, .2, corner.y * .26), "frame")
		leg.rotation = Vector3(corner.y * .35, 0, -corner.x * .35)
		_box("foot_rubber", Vector3(.06, .02, .06), Vector3(corner.x * .36, .01, corner.y * .36), "rubber")
	_cyl("mast_steel", .02, .5, Vector3(0, .77, 0), "metal")
	for rotor in [["rotor_bottom", .68], ["rotor_top", .86]]:
		var spin := Node3D.new()
		spin.name = str(rotor[0])
		spin.position = Vector3(0, float(rotor[1]), 0)
		add_child(spin)
		for blade in 2:
			var b := _box_in(spin, "blade_graphite", Vector3(1.2, .01, .09), Vector3.ZERO, "graphite")
			b.rotation.y = PI * .5 * blade
	_box("solar_panel_black_glass", Vector3(.36, .01, .18), Vector3(0, 1.03, 0), "glass")

# ---------- the drone dock ----------

func _drone_dock() -> void:
	# A printed pad with a charging cradle, a windsock mast (it reads the
	# gusts) and a pilot's console you stand at to fly.
	_box("pad_shell", Vector3(2.2, .1, 2.2), Vector3(0, .05, 0), "shell")
	_box("pad_ring_orange", Vector3(1.0, .012, .06), Vector3(0, .106, -.5), "orange")
	_box("pad_ring_orange", Vector3(1.0, .012, .06), Vector3(0, .106, .5), "orange")
	_box("pad_ring_orange", Vector3(.06, .012, 1.0), Vector3(-.5, .106, 0), "orange")
	_box("pad_ring_orange", Vector3(.06, .012, 1.0), Vector3(.5, .106, 0), "orange")
	_box("cradle_frame", Vector3(.5, .06, .5), Vector3(0, .14, 0), "frame")
	_cyl("windsock_mast_steel", .02, 1.6, Vector3(1.0, .85, 1.0), "metal")
	_box("windsock_amber", Vector3(.06, .06, .32), Vector3(1.0, 1.6, 1.16), "amber")
	# The console, at the pad's front edge, facing -Z.
	_box("console_frame", Vector3(.1, .9, .1), Vector3(-.7, .5, -1.25), "frame")
	_box("console_shell_panel", Vector3(.56, .36, .14), Vector3(-.7, 1.05, -1.25), "shell").rotation.x = deg_to_rad(-30)
	var screen := _box("console_screen", Vector3(.46, .26, .01), Vector3(-.7, 1.07, -1.33), "glass")
	screen.rotation.x = deg_to_rad(-30)
	_status(Vector3(-.48, .92, -1.31))

# ---------- a wreck's debris ----------

func _wreck(scale_by: float) -> void:
	# A cargo lander that came down hard: a cracked deck, a bent leg, a torn
	# shell panel and scattered pieces, half buried in the dust.
	var s := scale_by
	_box("deck_frame", Vector3(2.4, .2, 2.0) * s, Vector3(-1.8 * s, .1 * s, .6 * s), "frame").rotation = Vector3(.08, .4, -.12)
	_box("shell_panel_white", Vector3(1.6, .06, 1.1) * s, Vector3(-1.3 * s, .35 * s, -.9 * s), "white").rotation = Vector3(.5, -.3, .3)
	_box("shell_panel_white", Vector3(1.0, .05, .9) * s, Vector3(2.1 * s, .12 * s, 1.4 * s), "white").rotation = Vector3(-.2, 1.1, .15)
	_cyl("leg_strut_steel", .06 * s, 1.8 * s, Vector3(-2.7 * s, .5 * s, -.2 * s), "metal", Vector3(.2, 0, 1.0))
	_cyl("foot_pad_frame", .3 * s, .06 * s, Vector3(-3.4 * s, .04 * s, -.3 * s), "frame")
	_box("strap_orange", Vector3(.05, .02, 1.2) * s, Vector3(-1.6 * s, .22 * s, .7 * s), "orange").rotation.y = .4
	for i in 6:
		var a := TAU * i / 6.0 + .5
		var at := Vector3(cos(a) * 3.2 * s, .06, sin(a) * 2.8 * s)
		_box("debris_shell_panel", Vector3(.4, .05, .3) * s, at, "shell").rotation = Vector3(.3 * i, a, .2)

# ---------- helpers (as scripts/station_model.gd) ----------

const ROLE_COLOURS := {"white": "#F2F3F0", "shell": "#E3E7E5", "metal": "#C3CDD1", "frame": "#8796A0", "graphite": "#4C5A61", "rubber": "#323B40", "glass": "#25333A", "orange": "#E98A45", "amber": "#F2C35A"}

func _material(part: String, role: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = part
	material.albedo_color = Color(str(ROLE_COLOURS.get(role, "#C3CDD1")))
	return material

func _box(part: String, size: Vector3, at: Vector3, role: String) -> MeshInstance3D:
	return _box_in(self, part, size, at, role)

func _box_in(parent: Node3D, part: String, size: Vector3, at: Vector3, role: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(part, role)
	return _place(parent, part, mesh, at, Vector3.ZERO)

func _cyl(part: String, radius: float, height: float, at: Vector3, role: String, turn := Vector3.ZERO) -> MeshInstance3D:
	return _cyl_in(self, part, radius, height, at, role, turn)

func _cyl_in(parent: Node3D, part: String, radius: float, height: float, at: Vector3, role: String, turn := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = 20
	mesh.material = _material(part, role)
	return _place(parent, part, mesh, at, turn)

func _place(parent: Node3D, part: String, mesh: Mesh, at: Vector3, turn: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part
	visual.mesh = mesh
	visual.position = at
	visual.rotation = turn
	parent.add_child(visual)
	return visual

func _status(at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = .02; mesh.height = .04
	var material := StandardMaterial3D.new()
	material.resource_name = "status_light_green"
	material.albedo_color = Color("#56D38A")
	material.emission_enabled = true
	material.emission = Color("#56D38A")
	material.emission_energy_multiplier = 1.2
	mesh.material = material
	_place(self, "status_light_green", mesh, at, Vector3.ZERO)
