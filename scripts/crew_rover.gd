extends CharacterBody3D

## The vehicles (A7, docs/bases-and-vehicles.md "Vehicles and the drone" and
## "As built (A7)"). One driving script, two kinds:
##
## - "buggy", the scout buggy: open, so you stay suited and breathe your own
##   air. Quick (5 m/s), about 2 km to a charge, a small locker for what you
##   carry. Model: Scout 02 (Phase 6; the old code-built one in
##   scripts/vehicle_model.gd is the fallback). Found in a ring 1
##   cargo wreck: a printed part (a spares kit) and a battery bridged from
##   your suit bring it back.
## - "rover", the HabRover: Traverse 06 (Phase 6; the EVA-6 model is the
##   fallback). Slow (3 m/s), about 6 km to a charge. A sealed cab with its own
##   air, power, water and food: one of the three survival states (in a hab,
##   in the rover, on foot; docs/pillars.md). Parked, you can sleep (Z), eat
##   and drink (X), and your suit tops up from it. It bogs on sand and ripple
##   ground, its wheels wear on sharp boulders and platy lava, and it takes
##   add-ons in two slots: dune wheels (the dune sea's gate, landmark 24) and
##   traction mats. Found in a big cargo wreck at the edge of ring 2.
##
## Driving: W/S throttle and reverse, A/D steer, Space brake, C cruise, F
## lights, V cockpit or chase view, mouse to look, O radio, R recover it if
## it's wedged (not when bogged: dig out or lay a mat), E get out.
##
## The dashboards are working screens in the cab, drawn like the wrist
## (scripts/vehicle_screens.gd): Scout 02 has Drive and Return to hab (the
## way home, and your suit's air in minutes against the drive); the HabRover
## has Drive, Nav (the breadcrumb route you drove) and Cabin (its own air,
## with a live alarm). The cockpit view looks at them; the chase view shows
## the Drive screen small in a corner. The compass strip stays on in both.
##
## Hands-on cab (Phase 6): parked, look at a part and click (LMB, or RB): the
## buggy's glove box (food bars, water pouches) and its suit charge lead
## (power, no air); the HabRover's three galley drawers (meals, water, food
## bars), reached by turning right round into the aisle.
##
## Charging: the Garage charges fast and refills air, water and food. The
## buggy drives in; the HabRover is too tall and long for the hangar, so it
## docks on a pad outside beside the big door, its airlock backed on to the
## wall by an umbilical; parked by the lander or any base's core it trickle-charges;
## anywhere outside its roof solar adds a little by day. Main battery flat,
## a reserve takes over at reduced speed; both flat, a solar crawl by day.
##
## In Creative the batteries and supplies never run down.

const MODEL_PATH := "res://assets/vehicles/crew_rover.glb"
const MODEL := preload("res://scripts/vehicle_model.gd")
## Phase 6 (21 Nov): the user's field models (asset_packs/outpost_field_assets_v1,
## cleaned of lettering). Their fronts face +Z, so they're turned to face -Z;
## the game hangs its parts on their named empties (Wheel_FL, Steer_FL,
## Driver_Eye, Display_Surface_Dash_Drive, Glove_Box_Hinge, Galley_Drawer_01).
const FIELD_MODELS := {"buggy": "res://assets/models/field/scout_02.glb", "rover": "res://assets/models/field/traverse_06.glb"}
const SCREENS := preload("res://scripts/vehicle_screens.gd")
## Each Display_Surface: what it shows and its pixels (the quads' own shapes).
const SCREEN_MODES := {"Dash_Drive": ["drive", Vector2i(650, 300)], "Dash_EVA": ["home", Vector2i(560, 260)],
	"Dash_Nav": ["nav", Vector2i(510, 300)], "Dash_Life_Support": ["cabin", Vector2i(530, 280)]}
## Things in the cab you use by looking at them and clicking (the cockpit
## view): model empty -> what it is.
const CAB_PARTS := {"buggy": {"Glove_Box_Access": "glove_box", "Charge_Lead_Access": "lead"},
	"rover": {"Galley_Drawer_01": "drawer_meals", "Galley_Drawer_02": "drawer_water", "Galley_Drawer_03": "drawer_bars"}}
const AIM_CONE := .16           # rad off the look line that still counts as looking at a part
const AIM_REACH := 3.0          # m from your eye (the galley is behind the seats)
const STASH := {"bars": 2, "water_l": 1.5}   # the buggy's glove box, full
const LEAD_PER_H := 1.0         # suit battery shares an hour on the buggy's lead
const TRAIL_STEP := 25.0        # m between the rover's breadcrumbs
const TRAIL_MAX := 600
const ALARM_EVERY := 4.0        # s between the cab alarm's tones
const CABIN := preload("res://scripts/vehicle_cabin.gd")
const EYE_FORWARD := .25        # m ahead of the model's Driver_Eye: a better view out the front (playtest 21 Nov)
const EYE_UP := {"rover": .15}  # m above it: the HabRover's seat sat you too low (playtest 21 Nov)
const BOARD_SECONDS := .85      # getting in or out, or up from the seat: the camera's move
const CAB_EYE_HEIGHT := 1.4     # standing under the HabRover's ceiling
## Wrecks (21 Nov decision, docs/bases-and-vehicles.md): a hard hit, a fall or
## a roll wrecks a vehicle where it lies. Never lost: fix it there with
## spares, or GAR-Y tows it (about a sol per 3 km; from somewhere you can't
## reach, back to the last safe spot). A wreck never breaches the HabRover's
## hull: its cabin stays a shelter.
const CRASH_SPEED := .65        # of top speed, into something solid
const FALL_M := 3.5             # m dropped in one go
const DEEP_FALL_M := 15.0       # a drop this big: somewhere you can't drive out of
const ROLL_RAD := .8            # tipped past this (about 46 degrees)...
const ROLL_SECONDS := .6        # ...for this long: rolled
const CRASH_SPARES := {"buggy": 1, "rover": 2}
const TOW_M_PER_SOL := 3000.0
const SAFE_EVERY := 2.0         # s between remembering a safe spot
const DASH := preload("res://scripts/vehicle_dash.gd")
const CARGO_LANDER := preload("res://scripts/cargo_lander.gd")   # its soft dust puff
const MHPalette := preload("res://scripts/mh_palette.gd")
const SUIT := preload("res://scripts/suit.gd")
const ROVER_ROUTE := preload("res://scripts/rover_route.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const GROUND := preload("res://scripts/ground.gd")

## Per kind. Distances are a full battery's worth; the reserve is extra.
const SPECS := {
	"rover": {"label": "HabRover", "speed": 7.5, "reverse": 2.0, "reserve_speed": 3.0, "range_m": 6000.0, "reserve_m": 600.0,
		"solar_per_h": 6.0, "sealed": true, "wheelbase": 3.56, "wheel_r": .59, "half_track": 1.64, "half_base": 1.78,
		"hull": Vector3(3.6, 2.9, 6.4), "seat": Vector3(-.4, 1.5, -.7), "cab_view": Vector3(0, 1.45, -1.42),
		"dash": Vector3(-.05, 1.24, -1.86), "dash_size": Vector2(.42, .246), "chase": Vector2(7.5, 2.6)},
	"buggy": {"label": "Scout buggy", "speed": 12.0, "reverse": 3.0, "reserve_speed": 4.0, "range_m": 2000.0, "reserve_m": 300.0,
		"solar_per_h": 4.0, "sealed": false, "wheelbase": 2.24, "wheel_r": .51, "half_track": .99, "half_base": 1.12,
		"hull": Vector3(2.2, 1.0, 3.4), "seat": Vector3(-.32, 1.0, .2), "cab_view": Vector3(-.32, 1.62, .18),
		"dash": Vector3.INF, "dash_size": Vector2.ZERO, "chase": Vector2(6.0, 2.4)},
}
const LIMP_SPEED := 0.8         # both batteries flat: crawling on roof solar (daylight only)
const DAYLIGHT := 0.1           # sunlight above this powers the solar crawl
const ACCEL := 2.0
const BRAKE := 6.0
const COAST := 0.9
const STEER_MAX := 0.52         # rad, front wheels; the rear pair steers half as much the other way
## Charging, % an hour (game time).
const GARAGE_PER_H := 150.0     # the Garage's rover dock: full in about 40 min
const BASE_PER_H := 30.0        # parked by the lander or a base's core: a few hours
const BASE_REACH := 30.0        # m from a core or the lander that counts as parked by it
const GHOST_DISTANCE := 150.0   # m from you: past this a recalled vehicle drives home without physics
const HOP_AFTER := 20.0         # s without getting closer to its next waypoint: lifted on to it
## The rover's stores.
## Cab life support (power + hull, 21 Nov): one built-in core that runs off
## the batteries. No oxygen tank: the air is made while there's power.
const CAB_LIFE_PER_H := 1.2     # battery % an hour while you're aboard
const CAB_STALE_HOURS := 3.5    # no power: fresh to unbreathable in this long
const CAB_MAKE_PER_H := 60.0    # cab air % an hour the core can make back
const SUIT_O2_COST := .4        # battery % per hour of suit oxygen made
## Hull (%): hard knocks short of a crash, quakes and storms. Below
## HULL_LEAK_AT a seam leaks; the lower, the faster.
const HULL_KNOCK_FROM := 2.6    # m/s into something solid starts denting
const HULL_KNOCK_PER_MS := 9.0  # hull % per m/s above that
const HULL_LEAK_AT := 65.0
const HULL_LEAK_PER_H := 120.0  # cab air % an hour lost at 0% hull
const HULL_PATCH := 25.0        # a field patch (patch kit); the Garage mends it fully
const HULL_PATCH_TO := 85.0
const HULL_EVENT := {"quake": 10.0, "storm": 5.0}
const WATER_L := 20.0
const MEALS := 6
const SUIT_POWER_COST := 8.0    # battery % to charge a flat suit
## Bogging (the rover on loose ground): the slip builds while you drive on it
## and fades when you ease off or reach firm ground. Full slip: bogged.
const SLIP_RATE := {"sand": .22, "ripples": .45}
const SLIP_FADE := .5
const SLIP_FROM := 1.0          # m/s: slower than this, the wheels don't dig in
const DIG_SECONDS := 20.0       # digging out by hand (G beside it)
const DIG_AIR_HOURS := .4       # what the digging costs your suit, in hours of air
## Wheel wear (the rover): % per metre.
const WEAR_SHARP := .05         # sharp boulders and platy lava, at full speed (slower is gentler)
const WEAR_ANY := .0005
const WHEEL_FIX := 50.0         # % a spares kit gives back in the field
## Add-ons (the rover): the dune-wheel plan comes with the rover's wreck.
const ADDONS := {
	"dune_wheels": {"slot": "wheels", "label": "Dune wheels", "cost": {"metal_kg": 30.0, "salvage_kg": 10.0},
		"says": "Wide mesh wheels that float on sand: no bogging on dune sand, much less on ripples."},
	"traction_mats": {"slot": "kit", "label": "Traction mats", "cost": {"feedstock_kg": 20.0, "salvage_kg": 4.0},
		"says": "Three printed mats in a rack on the back: L lays one under the wheels when you're bogged."},
}
const MATS := 3
## Wrecks (A7 test spawns; C1 places them for real): what each needs.
const BUGGY_BRIDGE_POWER := .3  # the share of your suit battery that wakes its battery
const BUGGY_WAKE_CHARGE := 30.0
const ROVER_FIX := {"spares": 2, "cost": {"metal_kg": 20.0, "salvage_kg": 10.0}}
const ROVER_WAKE_CHARGE := 40.0

@export var kind := "rover"

var builder: Node
var speed := 0.0
var steer := 0.0
var battery := 100.0
var reserve := 100.0
var o2 := 100.0                 # cab air, % fresh (made from the battery)
var hull := 100.0               # cab hull integrity, %
var water_l := WATER_L
var meals := MEALS
var wheels := 100.0             # the rover's wheel condition, %
var addons: Array = []          # fitted add-on ids
var mats := 0                   # traction mats left in the rack
var slip := 0.0                 # 0..1: bogging builds
var bogged := false
var wrecked := false            # found as a wreck: needs fixing on the spot
var repair := ""                # the wreck's next step: "part" (buggy), "battery" (buggy), "parts" (rover)
var _last_hour := -1.0
var _dig := 0.0                 # seconds dug so far
var _ground := "dust"

var recalling := false
var lights_on := false
var driving := false
var cruise := 0.0
var radio_on := bool(MHGame.setting("rover_radio"))
var first_person := true        # cockpit view first (V: chase)

var _spec: Dictionary
var _max_speed := 3.0
var _half_track := .99
var _half_base := 1.29
var _wheel_r := .366
var _player: CharacterBody3D
var _model: Node3D
var _wheels := {}               # name -> Node3D
var _cam: Camera3D
var _look := Vector2(0.0, -0.2)  # camera yaw and pitch offsets (mouse)
var _pitch := 0.0
var _roll := 0.0
var _lights: Array[Light3D] = []
var _motor: AudioStreamPlayer3D
var _dust: Array[CPUParticles3D] = []
var _hud: CanvasLayer
var _dash   # scripts/vehicle_dash.gd
var _dash_echo: TextureRect
var _compass: MHWidgets.Compass
var _hints: Control
var _hint_key := ""
var _hangar: Node = null        # the hangar door this vehicle opened
var _player_layers := Vector2i.ZERO
var _was_charging := false
var _charging := ""             # "garage", "base", "solar" or ""
var _tail_lights: Array[MeshInstance3D] = []
var _tail_glow: StandardMaterial3D
var _braking := false
var _recall_stage := ""         # "approach" (outside the hangar), then "enter"
var _route := PackedVector2Array()
var _route_i := 0
var _best := INF
var _since_better := 0.0
var _stuck := 0.0
var _backing := 0.0
var _hull: CollisionShape3D
var _hull_centre := Vector3.ZERO
var _said := {}
var _field := false             # wearing a Phase 6 field model
var _screens := {}              # mode -> SubViewport (vehicle_screens.gd)
var _cab := {}                  # what -> Node3D in the cab you can click (CAB_PARTS)
var _cab_rest := {}             # what -> its closed transform
var _cab_open := {}             # what -> true while open
var _aimed := ""                # the cab part you're looking at
var _yoke: Node3D
var _galley_eye := Vector3.INF  # the HabRover: where you stand in the aisle to reach the galley
var _yoke_rest := Basis.IDENTITY
var _yoke_axis := Vector3.FORWARD
var _reticle: Control
var lead := false               # the buggy's charge lead plugged into your suit
var stash := STASH.duplicate()  # the buggy's glove box
var trail := PackedVector2Array()   # the rover's breadcrumbs from home
var _alarm_clock := 0.0
var crash := ""                 # what wrecked it: "hit", "fall" or "roll" (saved)
var tow := {}                   # GAR-Y's tow: {to: Vector3, yaw, hours_left, home} (saved)
var _safe := Vector3.INF        # the last spot it sat level on firm ground (saved)
var _safe_clock := 0.0
var _tipped := 0.0
var _tow_hour := -1.0
var _rear_m := 3.4              # body centre to the rear airlock face
var _cabin: Node                # the HabRover's walk-in cabin (scripts/vehicle_cabin.gd)
var _boarding := false          # the camera is moving you in or out
var _board := Vector3.INF       # the buggy's side step, body space
var _ride_legs := 0             # legs in the camera's last boarding move (tests read it)
var _boards: Array = []         # both side steps, body space (you climb in over the nearer one)

func setup(target_builder: Node, vehicle_kind := "") -> void:
	builder = target_builder
	if vehicle_kind != "": kind = vehicle_kind

func label() -> String:
	return str(_spec.get("label", "Rover"))

func sealed() -> bool:
	return bool(_spec.get("sealed", false))

func _ready() -> void:
	_spec = (SPECS.get(kind, SPECS.rover) as Dictionary).duplicate()
	_max_speed = float(_spec.speed)
	_half_track = float(_spec.half_track)
	_half_base = float(_spec.half_base)
	_wheel_r = float(_spec.wheel_r)
	add_to_group("vehicle")
	add_to_group("crew_rover" if kind == "rover" else "scout_buggy")
	if kind == "rover": add_to_group("hull_events")
	set_meta("interaction_target", self)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _spec.hull
	shape.shape = box
	_hull_centre = Vector3(0, (.45 if kind == "rover" else .4) + box.size.y * .5, 0)
	shape.position = _hull_centre
	add_child(shape)
	_hull = shape
	_model = Node3D.new()
	_model.name = "Body"
	add_child(_model)
	var visual: Node3D
	var field_path: String = FIELD_MODELS.get(kind, "")
	if not field_path.is_empty() and ResourceLoader.exists(field_path):
		visual = (load(field_path) as PackedScene).instantiate() as Node3D
		visual.rotation.y = PI
		_model.add_child(visual)
		MHPalette.apply(visual)
		_field = true
	elif kind == "rover":
		var scene := load(MODEL_PATH) as PackedScene
		if scene != null:
			visual = scene.instantiate() as Node3D
			_model.add_child(visual)
			MHPalette.apply(visual)
	else:
		visual = MODEL.new()
		visual.kind = "buggy"
		_model.add_child(visual)
	if _field:
		_fit_field_model(visual)
	elif visual != null:
		for node in visual.find_children("wheel_*", "Node3D", true, false):
			_wheels[str(node.name).substr(6, 2)] = node
		_tail_lights.assign(visual.find_children("tail_light_red*", "MeshInstance3D", true, false))
	_tail_glow = StandardMaterial3D.new()
	_tail_glow.albedo_color = Color("#E5484D")
	_tail_glow.emission_enabled = true
	_tail_glow.emission = Color("#FF3B30")
	_tail_glow.emission_energy_multiplier = 2.5
	_build_dash(visual)
	_build_lights()
	_build_dust()
	_build_motor()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 2000.0
	add_child(_cam)
	_cam.top_level = true
	var radio := preload("res://scripts/rover_radio.gd").new()   # chatter on the drive
	radio.rover = self
	add_child(radio)
	if kind == "buggy":
		o2 = 0.0
		water_l = 0.0
		meals = 0

# ---------- the field models (Phase 6) ----------

## A direction in this vehicle's own space, as seen in `node`'s parent's axes.
func _in_parent(node: Node3D, body_dir: Vector3) -> Vector3:
	var parent := node.get_parent() as Node3D
	var from_parent := _model.global_transform.affine_inverse().basis * parent.global_transform.basis
	return (from_parent.inverse() * body_dir).normalized()

func _body_point(node: Node3D) -> Vector3:
	return _model.global_transform.affine_inverse() * node.global_position

## Wheels by where they sit (not by the model's own side names), the eye and
## seat, the yoke, the screens and the cab parts.
func _fit_field_model(visual: Node3D) -> void:
	for found in visual.find_children("Wheel_*", "Node3D", true, false):
		var wheel := found as Node3D
		if str(wheel.name).length() != 8: continue
		var at := _body_point(wheel)
		var key := ("f" if at.z < -.5 else ("r" if at.z > .5 else "m")) + ("l" if at.x < 0.0 else "r")
		_wheels[key] = wheel
		wheel.set_meta("rest", wheel.transform.basis)
		wheel.set_meta("axle", _in_parent(wheel, Vector3.RIGHT))
		var pivot := visual.find_child("Steer_" + str(wheel.name).substr(6), true, false) as Node3D
		if pivot != null:
			pivot.set_meta("rest", pivot.transform.basis)
			pivot.set_meta("up", _in_parent(pivot, Vector3.UP))
			wheel.set_meta("steer", pivot)
	var hatch := visual.find_child("Airlock_Entry", true, false) as Node3D
	if hatch != null: _rear_m = absf(_body_point(hatch).z)
	var eye := visual.find_child("Driver_Eye", true, false) as Node3D
	if eye != null: _spec["cab_view"] = _body_point(eye) + Vector3.FORWARD * EYE_FORWARD + Vector3.UP * float(EYE_UP.get(kind, 0.0))
	var seat := visual.find_child("Driver_Seat", true, false) as Node3D
	if seat != null: _spec["seat"] = _body_point(seat) + Vector3.UP * 1.0
	_yoke = visual.find_child("Steering_Yoke", true, false) as Node3D
	if _yoke != null:
		_yoke_rest = _yoke.transform.basis
		var toward := (_spec.cab_view as Vector3) - _body_point(_yoke)
		toward.x = 0.0
		_yoke_axis = _in_parent(_yoke, toward.normalized() if toward.length() > .01 else Vector3.BACK)
	for found in visual.find_children("Display_Surface_*", "MeshInstance3D", true, false):
		var role := str(found.name).trim_prefix("Display_Surface_")
		if not SCREEN_MODES.has(role): continue
		var spec: Array = SCREEN_MODES[role]
		_screens[spec[0]] = SCREENS.attach(self, found as MeshInstance3D, str(spec[0]), spec[1])
		_lift_screen(found as MeshInstance3D)
	var galley := visual.find_child("Galley_Drawer_02", true, false) as Node3D
	if galley != null and kind != "rover":
		var g := _body_point(galley)
		_galley_eye = Vector3(g.x + (1.0 if g.x < 0.0 else -1.0), (_spec.cab_view as Vector3).y, g.z)
	var parts: Dictionary = CAB_PARTS.get(kind, {})
	for part_name in parts:
		var part := visual.find_child(str(part_name), true, false) as Node3D
		if part == null: continue
		var what: String = parts[part_name]
		# The glove box swings on its hinge; drawers slide; the lead lifts.
		var moving: Node3D = part
		if what == "glove_box":
			var hinge := visual.find_child("Glove_Box_Hinge", true, false) as Node3D
			if hinge != null: moving = hinge
		_cab[what] = part
		_cab_rest[what] = moving.transform
		part.set_meta("moves", moving)
	# The buggy's side step on the driver's side: you climb in over it.
	for side in ["Board_Left", "Board_Right"]:
		var step := visual.find_child(side, true, false) as Node3D
		if step == null: continue
		var at := _body_point(step)
		_boards.append(at)
		if _board == Vector3.INF or signf(at.x) == signf((_spec.seat as Vector3).x): _board = at
	# The HabRover: a cabin you walk into through the rear airlock.
	if kind == "rover" and visual.find_child("Airlock_Inside", true, false) != null:
		_cabin = CABIN.new()
		_cabin.name = "Cabin"
		add_child(_cabin)
		_cabin.setup(self, visual)

## A screen sits a few millimetres proud of its panel, toward the driver
## (Scout 02's quads were flush with the panel face and lost behind it).
func _lift_screen(screen: MeshInstance3D) -> void:
	var normals = screen.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	if normals == null or (normals as PackedVector3Array).is_empty(): return
	var facing := (screen.global_transform.basis * (normals as PackedVector3Array)[0]).normalized()
	var to_eye := _model.global_transform * (_spec.cab_view as Vector3) - screen.global_transform * screen.mesh.get_aabb().get_center()
	if facing.dot(to_eye) < 0.0: facing = -facing
	screen.global_position += facing * .006

## What the screens show (vehicle_screens.gd), all live. Minutes are game
## minutes, as the wrist counts them.
func screen_state() -> Dictionary:
	var s := {"on": battery > 0.0 or reserve > 0.0 or not MHGame.simulation_on(), "speed": absf(speed), "top": maxf(_max_speed, .1),
		"cruise": cruise, "battery": battery, "reserve": reserve, "lights": lights_on, "slip": slip > .35, "bogged": bogged,
		"wheels": wheels if kind == "rover" else 100.0, "charging": _charging == "garage" or _charging == "base",
		"range_m": battery / _drain_per_m() + reserve / _reserve_drain_per_m(), "lead": lead,
		"here": Vector2(global_position.x, global_position.z), "yaw": rotation.y, "trail": trail}
	if not MHGame.simulation_on():
		s.battery = 100.0
		s.range_m = -1.0
	var home := _home_target()
	if not home.is_empty():
		var to: Vector2 = (home.at as Vector2) - (s.here as Vector2)
		var metres := to.length()
		var drive_seconds := metres / maxf(.5, _max_speed * .8)
		s["home"] = {"at": home.at, "metres": metres, "bearing": wrapf(atan2(-to.x, -to.y) - rotation.y, -PI, PI),
			"minutes": drive_seconds / SUIT.real_seconds_per_hour() * 60.0}
	var suit := get_tree().get_first_node_in_group("suit")
	if suit != null and SUIT.active():
		var r: Dictionary = suit.readout()
		s["suit_minutes"] = float(r.o2_hours) * 60.0
		s["suit_full_minutes"] = float(suit.o2_hours()) * 60.0
	if sealed():
		s["cab_live"] = SUIT.active()
		s["cab_o2"] = o2
		s["kpa"] = 70.3 if o2 > 0.0 else 0.0
		s["hull"] = hull
		s["leak"] = leaking()
		s["temp_c"] = 21.0 if battery > 0.0 or reserve > 0.0 else -20.0
		s["water_l"] = water_l
		s["water_full"] = WATER_L
		s["meals"] = meals
		s["meals_full"] = MEALS
		s["alarm"] = _cab_alarm()
	return s

## The cab alarm: sealed, aboard, and the cab air low or the hull leaking.
func _cab_alarm() -> bool:
	return sealed() and aboard() and SUIT.active() and (o2 < 20.0 or leaking())

## Where "home" is for the screens: the Garage, else the lander.
func _home_target() -> Dictionary:
	var home := _home()
	if not home.is_empty(): return {"at": home.centre}
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world == null or world.get("lander") == null: return {}
	var at: Vector3 = (world.lander as Node3D).global_position
	return {"at": Vector2(at.x, at.z)}

# ---------- the HabRover's pad and umbilical ----------

var _pad: Node3D
var _umbilical: MeshInstance3D
var _pad_at := Vector2.INF

## A plain pad beside the Garage door and, while docked, the umbilical from
## the Garage wall to the HabRover's airlock (charge, air, water, food).
func _update_dock_pad() -> void:
	if not _docks_outside(): return
	var home := _home()
	if home.is_empty():
		if _pad != null: _pad.visible = false
		return
	if _pad == null:
		_pad = Node3D.new()
		_pad.name = "HabRoverPad"
		_pad.top_level = true
		add_child(_pad)
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(_half_track * 2.0 + 1.4, .12, _half_base * 2.0 + 2.2)
		var paint := StandardMaterial3D.new()
		paint.resource_name = "pad_regolith_concrete"
		paint.albedo_color = Color("#8A6E5E")
		paint.roughness = 1.0
		box.material = paint
		slab.mesh = box
		slab.position.y = .02
		_pad.add_child(slab)
		_umbilical = MeshInstance3D.new()
		var hose := CylinderMesh.new()
		hose.top_radius = .07
		hose.bottom_radius = .07
		hose.height = 1.0
		var rubber := StandardMaterial3D.new()
		rubber.resource_name = "umbilical_rubber_graphite"
		rubber.albedo_color = Color("#2E3539")
		rubber.roughness = .8
		hose.material = rubber
		_umbilical.mesh = hose
		_umbilical.top_level = true
		add_child(_umbilical)
	_pad.visible = true
	if _pad_at != (home.pad as Vector2):
		_pad_at = home.pad
		var out: Vector2 = home.out
		var y := float(home.get("y", 0.0))
		var ground := _ground_under(Vector3(_pad_at.x, y, _pad_at.y), y)
		_pad.global_transform = Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.y)), Vector3(_pad_at.x, ground if not is_inf(ground) else y, _pad_at.y))
	var docked := _in_bay() and absf(speed) < .3 and not wrecked and not home.has("port")
	_umbilical.visible = docked
	if docked:
		# From the Garage wall (beside the door, at waist height) to the airlock.
		var out3 := Vector3((home.out as Vector2).x, 0, (home.out as Vector2).y)
		var rear := global_position + out3 * -(_half_base - .1) + Vector3.UP * 1.1
		var wall := Vector3(rear.x, rear.y + .5, rear.z) - out3 * (rear - Vector3((home.door as Vector2).x, rear.y, (home.door as Vector2).y)).dot(out3)
		var mid := (rear + wall) * .5
		var along := wall - rear
		var length := along.length()
		if length < .05:
			_umbilical.visible = false
			return
		var up := along / length
		var x := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < .9 else Vector3.RIGHT).normalized()
		_umbilical.global_transform = Transform3D(Basis(x, up * length, x.cross(up)), mid)

# ---------- the cab: things you look at and click ----------

## Which cab part you're looking at, from the cockpit view, parked or slow.
func _aim_cab() -> void:
	var was := _aimed
	_aimed = ""
	if first_person and absf(speed) < .3 and _cam != null:
		var eye := _cam.global_position
		var look := -_cam.global_transform.basis.z
		var best := AIM_CONE
		for what in _cab:
			var to: Vector3 = (_cab[what] as Node3D).global_position - eye
			if to.length() > AIM_REACH: continue
			var off := look.angle_to(to)
			if off < best:
				best = off
				_aimed = what
	if _reticle != null:
		_reticle.visible = first_person and not _cab.is_empty()
		_reticle.modulate = MHStyle.accent if not _aimed.is_empty() else Color(1, 1, 1, .45)
	if _aimed != was: _hint_key = ""

func _cab_label(what: String) -> String:
	var open := bool(_cab_open.get(what, false))
	match what:
		"glove_box": return ("Take from the glove box" if _stash_has() else "Close the glove box (empty)") if open else "Open the glove box"
		"lead": return "Unplug the suit lead" if lead else "Plug in the suit lead"
		"drawer_meals": return ("Eat a meal" if meals > 0 or not MHGame.needs_food_water() else "Close (no meals)") if open else "Open the meals drawer"
		"drawer_water": return ("Drink and fill the drink bag" if water_l > .1 or not MHGame.needs_food_water() else "Close (tank empty)") if open else "Open the water drawer"
		"drawer_bars": return ("Pack a food bar" if meals > 0 or not MHGame.needs_food_water() else "Close (empty)") if open else "Open the snacks drawer"
	return what

func _stash_has() -> bool:
	return int(stash.get("bars", 0)) > 0 or float(stash.get("water_l", 0.0)) > .05

## Click: open it, take from it, or (nothing to take) close it.
func use_cab_part(what: String) -> bool:
	if not _cab.has(what): return false
	if what == "lead":
		lead = not lead
		MHAudio.sfx("place", -6.0)
		_cab_move(what, lead)
		_note(label(), "The charge lead clicks into your suit: the buggy's battery is charging it. It carries no air." if lead else "Lead unplugged.")
		return true
	if not bool(_cab_open.get(what, false)):
		_cab_move(what, true)
		MHAudio.sfx("door_open", -12.0)
		return true
	var took := false
	match what:
		"glove_box": took = _take_from_stash()
		"drawer_meals": took = _eat_meal()
		"drawer_water": took = _drink()
		"drawer_bars": took = _pack_bar()
	if not took:
		_cab_move(what, false)
		MHAudio.sfx("door_close", -12.0)
	return true

func _cab_move(what: String, open: bool) -> void:
	_cab_open[what] = open
	var part: Node3D = _cab[what]
	var moving: Node3D = part.get_meta("moves", part)
	var rest: Transform3D = _cab_rest[what]
	var target := rest
	if what == "glove_box": target.basis = rest.basis * Basis(Vector3.RIGHT, -deg_to_rad(72.0) if open else 0.0)
	elif what.begins_with("drawer"):   # out into the aisle, toward the middle
		var toward_aisle := Vector3.RIGHT if _body_point(part).x < 0.0 else Vector3.LEFT
		target.origin = rest.origin + (_in_parent(moving, toward_aisle) * .385 if open else Vector3.ZERO)
	elif what == "lead": target.origin = rest.origin + (_in_parent(moving, Vector3.UP) * .05 if open else Vector3.ZERO)
	if not is_inside_tree() or not moving.is_inside_tree():
		moving.transform = target
		return
	var motion := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(moving, "transform", target, .28)

func _close_cab() -> void:
	for what in _cab_open.keys():
		if bool(_cab_open[what]) and what != "lead": _cab_move(what, false)

func _suit_node() -> Node:
	var world := get_tree().get_first_node_in_group("habitat_world")
	return world.get("suit") if world != null else null

func _take_from_stash() -> bool:
	var suit := _suit_node()
	var lines: Array = []
	if suit != null and not bool(suit.food_bar) and int(stash.get("bars", 0)) > 0:
		stash["bars"] = int(stash.bars) - 1
		suit.food_bar = true
		lines.append("a food bar into the suit's pocket (%d left)" % int(stash.bars))
	if suit != null and float(stash.get("water_l", 0.0)) > .05:
		var give := minf(float(SUIT.DRINK_L) - float(suit.drink_l), float(stash.water_l))
		if give > .05:
			stash["water_l"] = float(stash.water_l) - give
			suit.drink_l = float(suit.drink_l) + give
			suit.dry_hours = 0.0
			lines.append("a water pouch into the drink bag (%.1f L left)" % float(stash.water_l))
	if lines.is_empty(): return false
	MHAudio.sfx("ui_confirm", -8.0)
	_note(label(), "From the glove box: " + " and ".join(lines) + ".")
	return true

## The buggy's glove box, refilled at a Garage (bars from the ration crate).
func _restock_stash() -> void:
	stash["water_l"] = STASH.water_l
	var world := get_tree().get_first_node_in_group("habitat_world")
	var pod: Node = world.get("lifepod") if world != null else null
	while int(stash.bars) < int(STASH.bars):
		if MHGame.needs_food_water() and not (pod != null and pod.has_method("take_ration") and pod.take_ration()): break
		stash["bars"] = int(stash.bars) + 1

func _eat_meal() -> bool:
	var needs := MHGame.needs_food_water()
	if meals <= 0 and needs: return false
	if needs: meals -= 1
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world != null and world.get("body") != null: world.body.eat()
	MHAudio.sfx("ui_confirm", -8.0)
	_note(label(), "You eat a meal from the galley drawer (%d left)." % meals if needs else "You eat.")
	return true

func _drink() -> bool:
	var suit := _suit_node()
	if suit == null: return false
	var needs := MHGame.needs_food_water()
	if needs and water_l <= .1: return false
	var give := float(SUIT.DRINK_L) - float(suit.drink_l)
	if needs: give = minf(give, water_l)
	suit.drink_l = float(suit.drink_l) + give
	suit.dry_hours = 0.0
	if needs: water_l -= give
	MHAudio.sfx("ui_confirm", -8.0)
	_note(label(), "You drink and fill the suit's drink bag (%.0f L left in the tank)." % water_l if needs else "You drink.")
	return true

func _pack_bar() -> bool:
	var suit := _suit_node()
	if suit == null or bool(suit.food_bar): return false
	if MHGame.needs_food_water():
		if meals <= 0: return false
		meals -= 1
	suit.food_bar = true
	MHAudio.sfx("ui_confirm", -8.0)
	_note(label(), "Packed a food bar for the suit.")
	return true

## Seated on the buggy with the lead in: its battery charges your suit.
func _lead_charge(hours: float) -> void:
	if not lead or not driving: return
	var suit := _suit_node()
	if suit == null or not SUIT.active() or float(suit.power) >= 1.0: return
	var given := supply_suit(0.0, minf(1.0 - float(suit.power), LEAD_PER_H * hours))
	suit.power = minf(1.0, float(suit.power) + given.y)

## The rover's breadcrumbs: dropped as it goes, cleared at home.
func _drop_crumb() -> void:
	if kind != "rover" or wrecked: return
	var here := Vector2(global_position.x, global_position.z)
	if _charging == "garage":
		trail = PackedVector2Array([here])
		return
	if trail.is_empty() or trail[trail.size() - 1].distance_to(here) >= TRAIL_STEP:
		trail.append(here)
		if trail.size() > TRAIL_MAX: trail.remove_at(1)

## The cab alarm sounds while the screen flashes.
func _sound_alarm(delta: float) -> void:
	if not _cab_alarm():
		_alarm_clock = 0.0
		return
	_alarm_clock -= delta
	if _alarm_clock <= 0.0:
		_alarm_clock = ALARM_EVERY
		MHAudio.sfx("warn", -10.0)

# ---------- interaction ----------

func interaction_prompt() -> Dictionary:
	if wrecked: return _wreck_prompt()
	if walk_in(): return outside_prompt()
	var head := "%s · battery %d%%" % [label(), roundi(battery)]
	if sealed() and SUIT.active(): head += " · air %d%%" % roundi(o2)
	if kind == "rover" and hull < 100.0: head += " · hull %d%%" % roundi(hull)
	if bogged: return {"label": head + " · BOGGED", "primary": "Drive", "tertiary": "Dig it out (%ds)" % roundi(DIG_SECONDS - _dig), "info": "About"}
	var prompt := {"label": head, "primary": "Drive", "secondary": "Headlights off" if lights_on else "Headlights on", "info": "About"}
	if leaking(): prompt["tertiary"] = "Patch the hull (patch kit)"
	elif kind == "rover" and wheels < 99.0 and MHChapterOne.stock.get("spares_kit", 0) > 0: prompt["tertiary"] = "Fix the wheels (spares kit, %d%%)" % roundi(wheels)
	elif SUIT.active(): prompt["tertiary"] = "Top up suit" if sealed() else "Charge suit"
	return prompt

## The walk-in HabRover from outside: its state, the lights and a suit top-up;
## you get in by the rear hatch, and field fixes are done from the kit locker.
func outside_prompt() -> Dictionary:
	var head := "%s · battery %d%%" % [label(), roundi(battery)]
	if SUIT.active(): head += " · air %d%%" % roundi(o2)
	if hull < 100.0: head += " · hull %d%%" % roundi(hull)
	var prompt := {"label": head + (" · BOGGED" if bogged else " · in by the rear hatch"), "secondary": "Headlights off" if lights_on else "Headlights on", "info": "About"}
	if bogged: prompt["tertiary"] = "Dig it out (%ds)" % roundi(DIG_SECONDS - _dig)
	elif SUIT.active(): prompt["tertiary"] = "Top up suit"
	return prompt

## The HabRover you walk into (not a wreck: that keeps the seat-only "Get in").
func walk_in() -> bool:
	return _cabin != null and not wrecked

## Aboard: in the driver's seat, or on your feet in the cabin.
func aboard() -> bool:
	return driving or (_cabin != null and bool(_cabin.player_in))

## The base's docking port the rear airlock is mated to now, or null.
func docked_port() -> Node3D:
	var home := _home()
	if home.has("port") and _in_bay() and absf(speed) < .3: return home.port as Node3D
	return null

## Ground a step behind the rear airlock (where you step down to).
func ground_behind() -> Vector3:
	var at: Vector3 = _model.global_transform * Vector3(0, 0, _rear_m + 1.1)
	var ground := _ground_at(at)
	return Vector3(at.x, (ground if not is_inf(ground) else global_position.y) + .05, at.z)

## E on the driver's seat (walking in the HabRover): sit and drive.
func sit_down(player: CharacterBody3D) -> bool:
	if player == null or driving: return false
	_get_in(player)
	return true

## A spares kit on the worn wheels (from the kit locker, or G beside the rover).
func fix_wheels() -> bool:
	if kind != "rover" or wheels >= 99.0 or int(MHChapterOne.stock.get("spares_kit", 0)) <= 0: return false
	MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.spares_kit) - 1
	wheels = minf(100.0, wheels + WHEEL_FIX)
	MHAudio.sfx("place", -4.0)
	_note(label(), "You swap the torn tread segments from a spares kit: the wheels are at %d%%. The Garage's wheel bench does a full refit." % roundi(wheels))
	return true

func interact(_actor: Node = null) -> bool:
	if wrecked: return _work_on_wreck()
	if walk_in(): return false   # in by the rear hatch (scripts/vehicle_cabin.gd)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or driving: return false
	_get_in(player)
	return true

func interact_secondary(_actor: Node = null) -> bool:
	if wrecked:
		if repair == "crash" and sealed() and tow.is_empty():
			var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
			if player != null and not driving: _get_in(player)
			return true
		return false
	_set_lights(not lights_on)
	return true

## G beside it: dig it out when bogged, fix worn wheels with a spares kit,
## or top your suit up (the buggy gives power only: it has no air).
func interact_tertiary(_actor: Node = null) -> bool:
	if wrecked or driving: return false
	if bogged:
		_dig_step()
		return true
	if not walk_in():   # the walk-in HabRover does these from its kit locker
		if leaking(): return patch_hull()
		if fix_wheels(): return true
	var suit := get_tree().get_first_node_in_group("suit")
	if suit == null: return false
	_note(label(), str(suit.top_up_from_rover(self)))
	return true

## Up to `o2_hours` of suit oxygen and `power_share` of a suit battery, both
## made from the batteries. Returns what it gave (hours, share).
func supply_suit(o2_hours: float, power_share: float) -> Vector2:
	var give_o2 := 0.0
	if sealed() and life_on():
		give_o2 = clampf(o2_hours, 0.0, _power() / SUIT_O2_COST) if MHGame.simulation_on() else o2_hours
		_draw(give_o2 * SUIT_O2_COST)
	var give_power := clampf(power_share, 0.0, battery / SUIT_POWER_COST)
	battery -= give_power * SUIT_POWER_COST
	return Vector2(give_o2, give_power)

func interact_info(_actor: Node = null) -> bool:
	_note(label(), about())
	return true

func about() -> String:
	if kind == "buggy":
		return "An open scout buggy: you stay suited and breathe your own air. About 2 km to a charge (5 m/s), then a short reserve. It charges fast at a Garage, slowly parked by the lander or a base's core, and a little from its solar panel by day. G beside it charges your suit from its battery. W/S drive, A/D steer, Space brake, C cruise, F lights, V cockpit or chase view, R free it if it's wedged, E get out."
	return "The HabRover: a sealed cabin whose life support runs off its batteries (hull %d%%), with water and food, and about 6 km to a charge at 3 m/s. Parked, Z sleeps and X eats and drinks; your suit tops up from it. It bogs on sand and ripples (dig out, or lay a traction mat with L), and sharp boulders and platy lava wear its wheels (spares kits, or the Garage's wheel bench). Add-ons are fitted at a Garage: dune wheels and traction mats. A Garage charges it fast, mends the hull and restocks its water and food; a patch kit seals a leak in the field." % roundi(hull)

func _note(title: String, text: String) -> void:
	get_tree().call_group("explore_hud", "show_equipment_note", title, text)

# ---------- the wreck (A7 test spawns; C1 places them for real) ----------

## Starts as a wreck: battery dead, a part missing.
func make_wreck() -> void:
	wrecked = true
	battery = 0.0
	reserve = 0.0
	o2 = 0.0
	water_l = 0.0
	meals = 0
	repair = "part" if kind == "buggy" else "parts"
	if kind == "rover": wheels = 60.0
	_model.rotation = Vector3(.05, 0, -.08)

func _wreck_prompt() -> Dictionary:
	var what := "Wrecked %s" % label().to_lower()
	match repair:
		"part": return {"label": what + " · a steering link sheared", "primary": "Fit a printed part (spares kit, %d in store)" % int(MHChapterOne.stock.get("spares_kit", 0)), "info": "About"}
		"battery": return {"label": what + " · battery dead", "primary": "Bridge its battery from your suit (%d%% of your power)" % roundi(BUGGY_BRIDGE_POWER * 100.0), "info": "About"}
		"parts": return {"label": what + " · drive train and seals damaged", "primary": "Repair it (%d spares kits, %s)" % [ROVER_FIX.spares, MHMaterials.cost_line(ROVER_FIX.cost).trim_prefix("0 kg · ")], "info": "About"}
		"crash":
			if not tow.is_empty(): return {"label": what + " · " + _tow_line(), "info": "About"}
			var prompt := {"label": what + " · " + _crash_text(), "primary": "Fix it (%d spares kit%s, %d in store)" % [_crash_spares(), "" if _crash_spares() == 1 else "s", int(MHChapterOne.stock.get("spares_kit", 0))], "info": "About"}
			if sealed(): prompt["secondary"] = "Get in (the cabin still holds air)"
			return prompt
	return {"label": what}

func _work_on_wreck() -> bool:
	match repair:
		"crash":
			if not tow.is_empty():
				_note(label(), _tow_line())
				return false
			if int(MHChapterOne.stock.get("spares_kit", 0)) < _crash_spares():
				_refuse("You need %d spares kit%s (the Print Shop prints them) to fix it. Or recall it from a Garage: GAR-Y tows it home, about a sol per 3 km." % [_crash_spares(), "" if _crash_spares() == 1 else "s"])
				return false
			MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.spares_kit) - _crash_spares()
			crash = ""
			_fixed(battery)
			_note(label(), "Fixed: bent parts swapped from the spares kits, and it's back on its wheels.")
			return true
		"part":
			if int(MHChapterOne.stock.get("spares_kit", 0)) < 1:
				_refuse("You need a spares kit (the Print Shop prints them) to make a new steering link.")
				return false
			MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.spares_kit) - 1
			repair = "battery"
			MHAudio.sfx("place", -4.0)
			_note(label(), "The new steering link is in. Its battery is dead flat: bridge it from your suit's to wake it.")
			return true
		"battery":
			var suit := get_tree().get_first_node_in_group("suit")
			if suit != null and SUIT.active():
				if float(suit.power) < BUGGY_BRIDGE_POWER + .05:
					_refuse("Your suit battery is too low to bridge it: come back with more charge.")
					return false
				suit.power = float(suit.power) - BUGGY_BRIDGE_POWER
			_fixed(BUGGY_WAKE_CHARGE)
			_note(label(), "The dash flickers and comes up: %d%%, enough to get it home. Park it by the lander or a core to charge it." % roundi(BUGGY_WAKE_CHARGE))
			return true
		"parts":
			if int(MHChapterOne.stock.get("spares_kit", 0)) < int(ROVER_FIX.spares):
				_refuse("You need %d spares kits (the Print Shop prints them) for its drive train and seals." % ROVER_FIX.spares)
				return false
			var short := MHMaterials.short_of(ROVER_FIX.cost) if MHGame.simulation_on() else ""
			if short != "":
				_refuse(short + " to repair it.")
				return false
			MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.spares_kit) - int(ROVER_FIX.spares)
			if MHGame.simulation_on(): MHMaterials.pay(ROVER_FIX.cost)
			_fixed(ROVER_WAKE_CHARGE)
			o2 = 10.0
			water_l = 2.0
			_learn_plan("dune_wheels")
			_note(label(), "The drive train turns and the cab holds pressure again. Its batteries kept %d%%, enough to run the cab's life support: get it to a Garage, which restocks its water and food. Its manifest had a plan for dune wheels too." % roundi(ROVER_WAKE_CHARGE))
			return true
	return false

# ---------- crashes, wrecks and GAR-Y's tow ----------

func _crash_spares() -> int:
	return int(CRASH_SPARES.get(kind, 1))

func _crash_text() -> String:
	match crash:
		"hit": return "a wheel and the steering bent in a hard hit"
		"fall": return "suspension broken in a fall"
		"roll": return "rolled: a wheel and a mast broken"
	return "damaged"

## Wrecked where it lies: pinned on the Map with a beacon, never lost.
func _wreck_here(why: String, drop := 0.0) -> void:
	wrecked = true
	repair = "crash"
	crash = why
	speed = 0.0
	cruise = 0.0
	recalling = false
	_tipped = 0.0
	_model.rotation = Vector3(.06, 0, -.12) if why != "roll" else Vector3(.1, 0, -.35)
	MHAudio.sfx("land", 0.0)
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world != null and world.has_method("_mark_wreck"): world._mark_wreck(kind, global_position, "%s (wrecked)" % label())
	var line := "The %s is wrecked: %s. Fix it here with %d spares kit%s, or recall it from a Garage and GAR-Y tows it home." % [label().to_lower(), _crash_text(), _crash_spares(), "" if _crash_spares() == 1 else "s"]
	if driving and not sealed():
		_get_out(false)   # thrown clear of the open buggy; your suit takes it
	elif driving:
		line += " The cabin's hull held: it's still a shelter, with its air, water and food. Press G to radio GAR-Y for a tow."
	# Somewhere you can't drive out of (a big drop): GAR-Y brings it back up.
	if why == "fall" and drop > DEEP_FALL_M and _safe != Vector3.INF:
		var metres := Vector2(global_position.x - _safe.x, global_position.z - _safe.z).length()
		tow = {"to": _safe, "yaw": rotation.y, "hours_left": clampf(metres / TOW_M_PER_SOL, 1.0, 2.0) * 24.0, "home": false}
		_tow_hour = MHGame.sol_hour
		line = "The %s went over a %d m drop: there's no driving out of there. GAR-Y will winch it back up to where it was last on firm ground, about %s." % [label().to_lower(), roundi(drop), _hours_text(float(tow.hours_left))]
	_flash("%s wrecked" % label(), line)

## Tipped past ROLL_RAD for ROLL_SECONDS: it's rolled. Level on firm ground:
## a safe spot to remember.
func _watch_roll(delta: float) -> void:
	if absf(_roll) > ROLL_RAD or absf(_pitch) > ROLL_RAD + .1:
		_tipped += delta
		if _tipped > ROLL_SECONDS and not recalling: _wreck_here("roll")
		return
	_tipped = 0.0
	_safe_clock -= delta
	if _safe_clock <= 0.0 and absf(_roll) < .2 and absf(_pitch) < .2 and not bogged:
		_safe_clock = SAFE_EVERY
		_safe = global_position

func _hours_text(hours: float) -> String:
	if hours >= 30.0: return "%.1f sols" % (hours / 24.0)
	return "%d hours" % maxi(1, roundi(hours))

func _tow_line() -> String:
	return "GAR-Y is towing it %s: %s to go" % ["home" if bool(tow.get("home", true)) else "back up", _hours_text(float(tow.get("hours_left", 0.0)))]

## Recalled while wrecked: GAR-Y tows it home, about a sol per 3 km.
func _start_tow(home: Dictionary) -> String:
	if not tow.is_empty(): return _tow_line() + "."
	if home.is_empty(): return "It's wrecked, and there's no Garage for GAR-Y to tow it to. Fix it where it lies with spares."
	var to := Vector3((home.centre as Vector2).x, float(home.get("y", global_position.y)), (home.centre as Vector2).y)
	var metres := Vector2(global_position.x - to.x, global_position.z - to.z).length()
	var out: Vector2 = home.out
	tow = {"to": to, "yaw": atan2(-out.x, -out.y), "hours_left": maxf(2.0, metres / TOW_M_PER_SOL * 24.0), "home": true}
	_tow_hour = MHGame.sol_hour
	return "GAR-Y's going out to tow it home: %s, about %s. GAR-Y can't survey while it tows, but it always comes for you." % [("%.1f km" % (metres / 1000.0)) if metres >= 1000.0 else "%d m" % roundi(metres), _hours_text(float(tow.hours_left))]

## The tow runs on game time (sleeping passes it too). Done: it's where it
## was taken, still wrecked, to be fixed with spares (a Garage is the easy place).
func _tick_tow() -> void:
	if tow.is_empty(): return
	var hour := MHGame.sol_hour
	if _tow_hour < 0.0: _tow_hour = hour
	var passed := wrapf(hour - _tow_hour, 0.0, 24.0)
	_tow_hour = hour
	if passed <= 0.0 or passed > 20.0: return
	tow["hours_left"] = float(tow.hours_left) - passed
	if float(tow.hours_left) > 0.0: return
	var to: Vector3 = tow.to
	var ground := _ground_under(to, to.y)
	global_position = Vector3(to.x, ground if not is_inf(ground) else to.y, to.z)
	rotation.y = float(tow.get("yaw", rotation.y))
	var home := bool(tow.get("home", true))
	tow = {}
	_note(label(), ("GAR-Y has towed the %s home. It's still damaged: fix it with %d spares kit%s." if home else "GAR-Y has winched the %s back up on to firm ground. It's still damaged: fix it with %d spares kit%s.") % [label().to_lower(), _crash_spares(), "" if _crash_spares() == 1 else "s"])

## Is GAR-Y busy towing anything? (companion_rover.gd won't survey then.)
static func gary_towing(tree: SceneTree) -> String:
	for vehicle in tree.get_nodes_in_group("vehicle"):
		var t = vehicle.get("tow")
		if t is Dictionary and not (t as Dictionary).is_empty(): return str(vehicle.call("_tow_line"))
	return ""

func _refuse(text: String) -> void:
	MHAudio.sfx("invalid")
	_note(label(), text)

func _fixed(charge: float) -> void:
	wrecked = false
	repair = ""
	battery = charge
	reserve = 100.0
	_model.rotation = Vector3.ZERO
	MHAudio.sfx("ui_confirm", -4.0)
	get_tree().call_group("habitat_world", "vehicle_fixed", self)

## A plan that came with the wreck (scripts/chapter_one.gd keeps the known ones).
func _learn_plan(id: String) -> void:
	if not MHChapterOne.known.has(id): MHChapterOne.known[id] = "found"

# ---------- on the compass and Map ----------

## 22 Nov playtest: your vehicles are marked on the compass and the Map at any
## distance, wherever you left them. Not while you're in one, and not a wreck
## you haven't got going (that's still a find).
var _mark_in := 0.0
func _mark_tick(delta: float) -> void:
	_mark_in -= delta
	if _mark_in > 0.0: return
	_mark_in = 1.5
	var known: Node = get_tree().get_first_node_in_group("known_things")
	if known == null:
		var world := get_tree().get_first_node_in_group("habitat_world")
		known = world.get("known") if world != null else null
	if known == null: return
	var id := "vehicle:" + kind
	if wrecked or driving or not is_inside_tree(): known.picked_up(id)
	else: known.set_down(id, str(_spec.get("label", "Rover")), global_position, "vehicle")

# ---------- getting in and out ----------

func _get_in(player: CharacterBody3D, animate := true) -> void:
	var from := _head_eye(player)
	_player = player
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world != null and world.get("carry") != null: world.carry.put_back()
	driving = true
	preload("res://scripts/feature_hints.gd").first(get_tree(), "rover")
	player.set_meta("driving", true)
	player.set_meta("vehicle", self)
	player.visible = false
	_player_layers = Vector2i(player.collision_layer, player.collision_mask)
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	if player.has_meta("in_cab"): player.remove_meta("in_cab")
	_look = Vector2(0.0, -0.2)
	_cam.current = true
	_place_camera(1.0)
	_set_explore_hud(false)
	_show_hud(true)
	if walk_in(): MHAudio.sfx("place", -10.0)
	else: MHAudio.sfx("door_close" if sealed() else "place", -6.0)
	if animate and first_person and from != Transform3D.IDENTITY:
		# The camera carries you from where you stood: over the buggy's side
		# step, or down into the HabRover's seat.
		var seated := _cam.global_transform
		var path: Array = [from]
		var step := _nearest_board(from.origin)
		if step != Vector3.INF:
			path.append(_eye_at(step + Vector3.UP * 1.45, rotation.y + PI * .5 * signf(step.x)))
			var seat_x := (_model.global_transform.affine_inverse() * seated.origin).x
			if signf(step.x) != signf(seat_x):
				# In over the passenger side: down into that seat, then shuffle
				# across, a little ducked, into the driver's.
				var across := _model.global_transform.affine_inverse() * seated.origin
				across.x = -across.x
				path.append(Transform3D(seated.basis, _model.global_transform * (across + Vector3.DOWN * .08)))
				path.append(Transform3D(seated.basis, _model.global_transform * (Vector3(0.0, across.y - .12, across.z))))
		path.append(seated)
		_ride(path)

## The side step nearer `world_at` (body space), or INF when the vehicle has none.
func _nearest_board(world_at: Vector3) -> Vector3:
	if _boards.is_empty(): return _board
	var local := _model.global_transform.affine_inverse() * world_at
	var best: Vector3 = _boards[0]
	for at in _boards:
		if signf((at as Vector3).x) == signf(local.x): best = at
	return best

## Your eye as you stand, for the camera's move into the seat.
func _head_eye(player: Node) -> Transform3D:
	var head_camera := player.get_node_or_null("Head/Camera3D") as Camera3D if player != null else null
	return head_camera.global_transform if head_camera != null and head_camera.is_inside_tree() else Transform3D.IDENTITY

## A level eye at a body-space point, looking along world yaw `yaw`.
func _eye_at(body: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -.15), _model.global_transform * body)

## Moves the driving camera through `path` (world transforms); keys wait till it's done.
func _ride(path: Array, then := Callable()) -> void:
	_boarding = true
	_ride_legs = path.size() - 1
	_cam.global_transform = path[0]
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Two legs (in over the step, down into the seat) take BOARD_SECONDS; a
	# shuffle across from the passenger seat adds a little for each extra leg.
	var each := BOARD_SECONDS * (1.0 + .4 * maxf(0.0, path.size() - 3.0)) / maxf(1.0, path.size() - 1.0)
	for i in range(1, path.size()):
		t.tween_property(_cam, "global_transform", path[i], each)
	t.tween_callback(func() -> void:
		_boarding = false
		if then.is_valid(): then.call())

## E in the seat: the walk-in HabRover stands you up into the aisle (you
## leave by the airlock); the buggy, or a wreck, puts you out beside it.
func _exit_pressed() -> void:
	if _boarding: return
	if walk_in() and absf(speed) > .3:
		_refuse("Stop first: you can only get up from the seat when it's parked.")
		return
	_get_out()

func _stand_up() -> void:
	var seat: Vector3 = _spec.seat
	var stand := Vector3(0.0, (_cabin._floor_y if _cabin != null else seat.y - 1.0), seat.z + .8)
	var yaw := rotation.y + PI   # toward the aisle and the galley
	var spot: Vector3 = _model.global_transform * stand
	_player.set_meta("cab_ceiling", true)
	var target := _eye_at(stand + Vector3.UP * CAB_EYE_HEIGHT, yaw)
	_close_cab()
	_aimed = ""
	driving = false
	speed = 0.0
	cruise = 0.0
	_ride([_cam.global_transform, _eye_at(seat + Vector3(0, .25, .35), rotation.y + PI * .5), target], func() -> void: _release(spot, yaw))

func _get_out(animate := true) -> void:
	if _player == null: return
	if animate and walk_in() and _cabin != null:
		_stand_up()
		return
	var spot := _exit_spot()
	var through_port := false
	if _docks_outside():
		var inside := _port_exit()
		if inside != Vector3.INF:
			spot = inside
			through_port = true
	if lead: use_cab_part("lead")
	_close_cab()
	_aimed = ""
	driving = false
	speed = 0.0
	cruise = 0.0
	var yaw := rotation.y + (PI if through_port else 0.0)
	if animate and first_person and _board != Vector3.INF:
		var step := _eye_at(_board + Vector3.UP * 1.45, rotation.y + PI * .5 * signf(_board.x))
		_ride([_cam.global_transform, step, Transform3D(Basis(Vector3.UP, yaw), spot + Vector3.UP * 1.6)], func() -> void: _release(spot, yaw))
		return
	_release(spot, yaw)

## Back on your own feet at `spot`, facing `yaw`: seen, solid, your own camera.
func _release(spot: Vector3, yaw: float) -> void:
	if _player == null: return
	_player.global_position = spot
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO
	if "safe_position" in _player: _player.safe_position = spot
	_player.collision_layer = _player_layers.x
	_player.collision_mask = _player_layers.y
	_player.visible = true
	_player.set_meta("driving", false)
	_player.remove_meta("vehicle")
	var head_camera := _player.get_node_or_null("Head/Camera3D") as Camera3D
	if head_camera != null: head_camera.current = true
	_set_explore_hud(true)
	_show_hud(false)
	if not walk_in(): MHAudio.sfx("door_open" if sealed() else "place", -6.0)
	_player = null

## Beside the driver's door, or the other side, or behind: the first spot
## with room to stand and ground under it.
func _exit_spot() -> Vector3:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var side := _half_track + 1.0
	for local in [Vector3(-side, 0, 0.2), Vector3(side, 0, 0.2), Vector3(0, 0, _half_base + 1.9), Vector3(0, 0, -_half_base - 2.1)]:
		var at: Vector3 = global_transform * local
		var ground := _ground_at(at)
		if is_inf(ground): continue
		var stand := Vector3(at.x, ground + 0.05, at.z)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, stand + Vector3.UP * 0.95)
		query.exclude = _own_rids()
		if space.intersect_shape(query, 1).is_empty(): return stand
	return global_transform * Vector3(-side, 0, 0) + Vector3.UP * 0.1

func _set_explore_hud(on: bool) -> void:
	for hud in get_tree().get_nodes_in_group("explore_hud"):
		if hud is CanvasLayer: (hud as CanvasLayer).visible = on

# ---------- input while driving ----------

## Something in your hands to turn with R (scripts/carry.gd): R is its, not the recover.
func _carrying() -> bool:
	var carry: Node = get_tree().get_first_node_in_group("carry")
	return carry != null and not (carry.get("carrying") as Dictionary).is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if not driving and not get_tree().paused and MHInput.pressed(event, "recover"):
		# Standing beside it: R frees it too.
		var world := get_tree().get_first_node_in_group("habitat_world")
		var walker: Node3D = world.player if world != null else null
		if walker != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not (world.builder != null and world.builder.build_mode) and not bool(walker.get_meta("interior_build_active", false)) and not bool(walker.get_meta("surface_build_active", false)) and not _carrying() 				and walker.global_position.distance_to(global_position) < 6.0 and not wrecked:
			_recover()
			get_viewport().set_input_as_handled()
		return
	if not driving or get_tree().paused: return
	if _boarding:
		get_viewport().set_input_as_handled()
		return
	if not _aimed.is_empty() and ((event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER)):
		use_cab_part(_aimed)
		_hint_key = ""
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look.x = wrapf(_look.x - event.relative.x * 0.0025, -PI, PI)
		_look.y = clampf(_look.y - event.relative.y * 0.0025, -1.1, 0.5)
	# The gamepad's own buttons (scripts/mh_input.gd): out, lights, cruise, free it.
	if event is InputEventJoypadButton:
		var pad_handled := true
		if MHInput.pressed(event, "vehicle_exit"): _exit_pressed()
		elif MHInput.pressed(event, "vehicle_lights"): _set_lights(not lights_on)
		elif MHInput.pressed(event, "cruise"): _toggle_cruise()
		elif MHInput.pressed(event, "recover"): _recover()
		elif MHInput.pressed(event, "camera_view") or (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK:
			first_person = not first_person
			_look = Vector2(0.0, -0.2 if first_person else -0.22)
			if _dash_echo != null: _dash_echo.visible = not first_person
		else: pad_handled = false
		if pad_handled: get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.keycode:
			KEY_E: _exit_pressed()
			KEY_F: _set_lights(not lights_on)
			KEY_V:
				first_person = not first_person
				_look = Vector2(0.0, -0.2 if first_person else -0.22)
				if _dash_echo != null: _dash_echo.visible = not first_person
			KEY_R: _recover()
			KEY_C: _toggle_cruise()
			KEY_O:
				radio_on = not radio_on
				MHAudio.sfx("ui_click", -8.0)
			KEY_L: lay_mat()
			KEY_Z: _cabin_sleep()
			KEY_X: _cabin_eat()
			KEY_1: fit_addon("dune_wheels")
			KEY_2: fit_addon("traction_mats")
			KEY_3: refit_wheels()
			KEY_B: pass   # no building from the driver's seat
			KEY_G:
				if wrecked and repair == "crash": _note(label(), recall())
				else: handled = false
			_: handled = false
		if handled: get_viewport().set_input_as_handled()

# ---------- the rover's cabin ----------

## Parked with the cab sealed: the cabin is a safe pocket.
func cabin_ready() -> bool:
	return sealed() and aboard() and absf(speed) < .1 and (o2 > 0.0 or not SUIT.active())

func _cabin_sleep() -> void:
	if not sealed(): return
	if not cabin_ready():
		_refuse("Park first, with power for the cab's air, to sleep in the cab.")
		return
	get_tree().call_group("sleep", "open", self)

## X in the parked cab: a meal and a drink from the rover's galley locker, and
## the suit's drink bag and food bar topped up.
func _cabin_eat() -> void:
	if not sealed(): return
	if not cabin_ready():
		_refuse("Park first to eat in the cab.")
		return
	var world := get_tree().get_first_node_in_group("habitat_world")
	var lines: Array = []
	var needs := MHGame.needs_food_water()
	if needs and meals <= 0 and water_l <= .1:
		_refuse("The rover's galley locker and water tank are empty. A Garage restocks them.")
		return
	if not needs or meals > 0:
		if needs: meals -= 1
		if world != null and world.get("body") != null: world.body.eat()
		lines.append("You eat a meal from the galley locker (%d left)." % meals if needs else "You eat.")
	var suit: Node = world.get("suit") if world != null else null
	if suit != null:
		var want := float(SUIT.DRINK_L) - float(suit.drink_l)
		var give := minf(want, water_l) if needs else want
		suit.drink_l = float(suit.drink_l) + give
		if needs: water_l -= give
		suit.dry_hours = 0.0
		if not bool(suit.food_bar) and (meals > 0 or not needs):
			suit.food_bar = true
			if needs: meals -= 1
			lines.append("Packed a food bar for the suit.")
		lines.append("Drank, and refilled the suit's drink bag (%.0f L left in the tank)." % water_l if needs else "Drank.")
	MHAudio.sfx("ui_confirm", -8.0)
	_note(label(), " ".join(lines))

# ---------- add-ons, mats and wheels (the rover) ----------

func has_addon(id: String) -> bool:
	return addons.has(id)

## 1 / 2 in the cab, parked at a Garage: fit an add-on.
func fit_addon(id: String) -> bool:
	if kind != "rover" or not ADDONS.has(id): return false
	if not _in_bay():
		_refuse("Add-ons are fitted at a Garage's add-on bench: park it in the Garage.")
		return false
	if absf(speed) > .1: return false
	var spec: Dictionary = ADDONS[id]
	if id == "traction_mats" and has_addon(id):
		if mats >= MATS:
			_refuse("The mat rack is full.")
			return false
		return _pay_then(spec.cost, func():
			mats = MATS
			_note(label(), "The Print Shop's mats are back in the rack: %d." % MATS))
	if has_addon(id):
		_refuse("%s are already fitted." % str(spec.label))
		return false
	if id == "dune_wheels" and not MHChapterOne.known.has(id) and str(MHGame.rule("plans")) != "all":
		_refuse("You don't have a plan for dune wheels yet.")
		return false
	return _pay_then(spec.cost, func():
		addons = addons.filter(func(a): return str(ADDONS[a].slot) != str(spec.slot))
		addons.append(id)
		if id == "traction_mats": mats = MATS
		_note(label(), "%s fitted. %s" % [str(spec.label), str(spec.says)]))

func _pay_then(cost: Dictionary, then: Callable) -> bool:
	if MHGame.simulation_on():
		if MHChapterOne.feedstock_kg < float(cost.get("feedstock_kg", 0.0)) - .001 or MHMaterials.short_of(cost) != "":
			var short := MHMaterials.short_of(cost)
			_refuse((short if short != "" else "Not enough feedstock") + ".")
			return false
		MHChapterOne.feedstock_kg -= float(cost.get("feedstock_kg", 0.0))
		MHMaterials.pay(cost)
	MHAudio.sfx("place", -4.0)
	then.call()
	return true

## 3 in the cab at a Garage: the wheel bench refits the tread (a spares kit).
func refit_wheels() -> bool:
	if kind != "rover": return false
	if not _in_bay():
		_refuse("The wheel bench is in the Garage. In the field, G beside the rover patches a wheel with a spares kit.")
		return false
	if wheels >= 99.9:
		_refuse("The wheels are fine.")
		return false
	if int(MHChapterOne.stock.get("spares_kit", 0)) < 1 and MHGame.simulation_on():
		_refuse("The wheel bench needs a spares kit.")
		return false
	if MHGame.simulation_on(): MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.spares_kit) - 1
	wheels = 100.0
	MHAudio.sfx("place", -4.0)
	_note(label(), "The wheel bench refits every tread: the wheels are as good as new.")
	return true

## L: a traction mat under the wheels frees it at once.
func lay_mat() -> bool:
	if not bogged: return false
	if mats <= 0:
		_refuse("No traction mats left. Get out and dig it free (G beside it).")
		return false
	mats -= 1
	_unbog()
	_note(label(), "You lay a mat under the wheels and creep out onto firmer ground (%d mats left)." % mats)
	return true

## G beside it, again and again: each press digs a few seconds' worth; the
## suit pays in air.
func _dig_step() -> void:
	var step := 4.0
	_dig += step
	var suit: Node = get_tree().get_first_node_in_group("suit")
	if suit != null and SUIT.active() and float(suit.o2_hours()) > 0.0:
		suit.o2 = maxf(0.0, float(suit.o2) - DIG_AIR_HOURS * step / DIG_SECONDS / float(suit.o2_hours()))
	MHAudio.sfx("place", -6.0)
	if _dig >= DIG_SECONDS:
		_unbog()
		_note(label(), "Dug out: the wheels are clear. Back off the soft ground the way you came.")
	else:
		_note(label(), "Digging the sand from round the wheels: hard work, it costs air (%d s to go)." % roundi(DIG_SECONDS - _dig))

func _unbog() -> void:
	bogged = false
	slip = 0.0
	_dig = 0.0
	MHAudio.sfx("ui_confirm", -8.0)

# ---------- driving ----------

func _physics_process(delta: float) -> void:
	_mark_tick(delta)
	if _cabin != null:
		var walk := walk_in() and not driving and not recalling and tow.is_empty()
		if walk != bool(_cabin.walk): _cabin.set_walk(walk)
	var throttle := 0.0
	var steer_in := 0.0
	var braking := false
	if wrecked:
		_tick_tow()
		if driving:
			# Aboard a wreck (the HabRover's cabin is a shelter): it can't move,
			# but the cab still breathes, the screens and the galley still work.
			speed = 0.0
			_battery(delta, 0.0)
			_sound_alarm(delta)
			_player.global_position = global_transform * (_spec.seat as Vector3) - Vector3.UP * 1.6
			if not _boarding: _place_camera(delta)
			_aim_cab()
			_update_hud()
		return
	if driving and not get_tree().paused and not _boarding and not bool(_player.get_meta("ui_freeze", false)):
		# Keys, or RT/LT and the left stick (scripts/mh_input.gd): how far, not just on or off.
		throttle = maxf(_axis(KEY_W, "throttle"), MHInput.amount("move_forward")) - maxf(_axis(KEY_S, "brake"), MHInput.amount("move_back"))
		steer_in = _axis(KEY_A, "move_left") - _axis(KEY_D, "move_right")
		braking = MHInput.held("handbrake")
		var stick := MHInput.pad_look(delta)
		if stick != Vector2.ZERO:
			_look.x = wrapf(_look.x - stick.x, -PI, PI)
			_look.y = clampf(_look.y - stick.y, -1.1, 0.5)
		throttle = _cruise_throttle(throttle, braking)
	elif driving and not get_tree().paused:
		throttle = _cruise_throttle(0.0, false)   # cruising on while you look at the map
	elif recalling and not get_tree().paused:
		if _far_from_you():
			_ghost_drive(delta)
			return
		var drive := _autopilot(delta)
		throttle = drive.x
		steer_in = drive.y
	var top := top_speed()
	_set_braking(braking or (throttle < 0.0 and speed < 0.05))
	if bogged:
		speed = move_toward(speed, 0.0, BRAKE * delta)
		if absf(throttle) > 0.0: _spin_wheels(delta, absf(throttle) * delta * 2.0)   # spinning in place
	elif braking:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	elif throttle > 0.0:
		speed = move_toward(speed, 0.0, BRAKE * delta) if speed < -0.05 else move_toward(speed, top * throttle, ACCEL * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0, BRAKE * delta) if speed > 0.05 else move_toward(speed, -minf(float(_spec.reverse), top), ACCEL * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	var steer_limit := STEER_MAX * lerpf(1.0, 0.45, clampf(absf(speed) / _max_speed, 0.0, 1.0))
	steer = move_toward(steer, steer_in * steer_limit, 1.8 * delta)
	rotation.y += speed * tan(steer) / float(_spec.wheelbase) * delta
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	velocity = forward * speed
	var before := global_position
	move_and_slide()
	# Bumping into something solid takes the speed off.
	if get_slide_collision_count() > 0:
		var moved := (global_position - before).length()
		if moved < absf(speed) * delta * 0.5:
			if absf(speed) > 2.5: MHAudio.sfx("land", -4.0)
			var impact := absf(speed)
			speed *= 0.3
			if impact > CRASH_SPEED * _max_speed and not recalling:
				_wreck_here("hit")
				return
			if impact > HULL_KNOCK_FROM and not recalling and sealed():
				damage_hull((impact - HULL_KNOCK_FROM) * HULL_KNOCK_PER_MS, "a hard knock")
	_follow_ground(delta)
	if wrecked: return   # it went over an edge
	_watch_roll(delta)
	if wrecked: return
	var flat_moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_spin_wheels(delta, global_position.distance_to(before))
	_terrain_effects(delta, flat_moved)
	_battery(delta, flat_moved)
	_drop_crumb()
	_sound_alarm(delta)
	_update_dock_pad()
	_hangar_doors()
	_update_effects()
	if driving:
		_player.global_position = global_transform * (_spec.seat as Vector3) - Vector3.UP * 1.6
		_player.rotation.y = rotation.y   # you face where it's going (the region map's arrow)
		if not _boarding: _place_camera(delta)
		_aim_cab()
		_update_hud()

## The ground under the wheels: bogging and wheel wear (the rover only).
func _terrain_effects(delta: float, moved: float) -> void:
	if kind != "rover" or not MHSiteTerrain.shape() == "region": return
	_ground = GROUND.kind_at(global_position.x, global_position.z)
	if not MHGame.simulation_on(): return
	# Wear: sharp ground cuts the tread, gentler the slower you go.
	var pace := clampf(absf(speed) / _max_speed, 0.0, 1.0)
	var was := wheels
	wheels = maxf(0.0, wheels - moved * (WEAR_ANY + (WEAR_SHARP * (.25 + .75 * pace * pace) if GROUND.sharp(_ground) else 0.0)))
	if was >= 40.0 and wheels < 40.0: _warn("wheels40", "Wheels worn", "Sharp rock has cut the tread: it's slower now. Patch a wheel with a spares kit (G beside it), or refit at the Garage's wheel bench.")
	if was >= 15.0 and wheels < 15.0: _warn("wheels15", "A wheel is torn", "It's limping now. Fix it before you go much further.")
	# Bogging: loose ground builds the slip while you push on.
	var rate: float = float(SLIP_RATE.get(_ground, 0.0)) if GROUND.loose(_ground) else 0.0
	if has_addon("dune_wheels"): rate = 0.0 if _ground == "sand" else rate * .3
	if rate > 0.0 and absf(speed) > SLIP_FROM:
		slip = minf(1.0, slip + rate * pace * delta)
		if slip > .5: _warn("slip", "Wheels slipping", "The ground's soft: ease off or turn for firmer ground before it bogs.")
	else:
		slip = maxf(0.0, slip - SLIP_FADE * delta)
		if slip < .2: _said.erase("slip")
	if slip >= 1.0 and not bogged:
		bogged = true
		speed = 0.0
		cruise = 0.0
		MHAudio.sfx("warn", -4.0)
		var how := "lay a traction mat (L)" if mats > 0 else "get out and dig it free (G beside it)"
		_note(label(), "Bogged down: the wheels have dug into the %s. %s." % ["sand" if _ground == "sand" else "ripple", how.capitalize()])

func _warn(key: String, title: String, text: String) -> void:
	if _said.has(key): return
	_said[key] = true
	_flash(title, text)

## C: hold the speed you're doing, or full speed from a standstill.
func _toggle_cruise() -> void:
	if cruise > 0.0:
		cruise = 0.0
		MHAudio.sfx("ui_click", -8.0)
		return
	if speed < -0.05: return
	cruise = speed if speed > 1.0 else _max_speed
	MHAudio.sfx("ui_confirm", -10.0)

## Cruise control's throttle: W raises the set speed, S or Space lets go;
## otherwise it holds the set speed (as far as the battery allows).
func _cruise_throttle(throttle: float, braking: bool) -> float:
	if cruise <= 0.0: return throttle
	if braking or throttle < 0.0:
		cruise = 0.0
		return throttle
	if throttle > 0.0:
		cruise = maxf(cruise, speed)
		return throttle
	var top := top_speed()
	return clampf(minf(cruise, top) / top, 0.0, 1.0) if top > 0.0 else 0.0

func _axis(key: Key, action: String) -> float:
	return 1.0 if Input.is_key_pressed(key) else MHInput.amount(action)

## Height, pitch and roll from the ground under the four corner wheels.
func _follow_ground(delta: float) -> void:
	var fl := _ground_at(global_transform * Vector3(-_half_track, 0, -_half_base))
	var fr := _ground_at(global_transform * Vector3(_half_track, 0, -_half_base))
	var rl := _ground_at(global_transform * Vector3(-_half_track, 0, _half_base))
	var rr := _ground_at(global_transform * Vector3(_half_track, 0, _half_base))
	var heights := [fl, fr, rl, rr].filter(func(h): return not is_inf(h))
	if heights.is_empty():
		# Nothing under any wheel within reach: over an edge.
		var below := _ground_under(global_position, global_position.y)
		if not is_inf(below) and global_position.y - below > FALL_M and not recalling:
			var drop := global_position.y - below
			global_position.y = below
			_wreck_here("fall", drop)
		return
	var mean := 0.0
	for h in heights: mean += h
	mean /= heights.size()
	if is_inf(fl): fl = mean
	if is_inf(fr): fr = mean
	if is_inf(rl): rl = mean
	if is_inf(rr): rr = mean
	# Sit on the plane through the four wheels (the tilt follows it), lifted
	# only for a bump that sticks up out of that plane.
	var along := ((fl + fr) - (rl + rr)) * .25
	var across := ((fl + rl) - (fr + rr)) * .25
	var bump := maxf(maxf(fl - (mean + along + across), fr - (mean + along - across)), maxf(rl - (mean - along + across), rr - (mean - along - across)))
	var target := mean + maxf(0.0, bump - 0.1) - (.12 * slip if kind == "rover" else 0.0)   # sinking in as it bogs
	if global_position.y - target > FALL_M and not recalling and not _in_bay():
		var drop := global_position.y - target
		global_position.y = target
		_wreck_here("fall", drop)
		return
	var rate := 10.0 if target > global_position.y else 6.0
	global_position.y = lerpf(global_position.y, target, minf(1.0, delta * rate))
	var pitch := atan2(((fl + fr) - (rl + rr)) * 0.5, _half_base * 2.0)
	var roll := atan2(((rl + fl) - (rr + fr)) * 0.5, _half_track * 2.0)
	_pitch = lerpf(_pitch, pitch, minf(1.0, delta * 8.0))
	_roll = lerpf(_roll, roll, minf(1.0, delta * 8.0))
	_model.rotation = Vector3(_pitch, 0.0, -_roll)
	if _hull != null:
		_hull.rotation = _model.rotation
		_hull.position = Basis.from_euler(_model.rotation) * _hull_centre
	for key in _wheels:
		var wheel: Node3D = _wheels[key]
		var corner := {"fl": fl, "fr": fr, "ml": (fl + rl) * .5, "mr": (fr + rr) * .5, "rl": rl, "rr": rr}
		if not wheel.has_meta("rest_y"): wheel.set_meta("rest_y", wheel.position.y)
		var offset := clampf(float(corner.get(str(key), mean)) - global_position.y, -0.12, 0.12)
		wheel.position.y = float(wheel.get_meta("rest_y")) + offset

## The ground (or floor, or ramp) under a point; INF if there's none.
## What the rover's own rays look past: itself, its walk-in cabin (its floor
## isn't the ground) and you.
func _own_rids() -> Array[RID]:
	var rids: Array[RID] = [get_rid()]
	if _cabin != null:
		for body in _cabin._bodies: rids.append((body as CollisionObject3D).get_rid())
	var world := get_tree().get_first_node_in_group("habitat_world") if is_inside_tree() else null
	if world != null and world.get("player") != null: rids.append((world.player as CollisionObject3D).get_rid())
	return rids

func _ground_at(at: Vector3) -> float:
	var from := Vector3(at.x, global_position.y + 1.6, at.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(.02, -7.0, .015))
	query.exclude = _own_rids()
	if _player != null: query.exclude.append(_player.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float((hit.position as Vector3).y) if not hit.is_empty() else INF

func _spin_wheels(delta: float, moved: float) -> void:
	var turn := moved / _wheel_r * (signf(speed) if absf(speed) > .01 else 1.0)
	for key in _wheels:
		var wheel: Node3D = _wheels[key]
		var axle := str(key).substr(0, 1)
		var yaw := steer if axle == "f" else (-steer * 0.5 if axle == "r" else 0.0)
		var spin := float(wheel.get_meta("spin", 0.0)) - turn
		wheel.set_meta("spin", spin)
		if wheel.has_meta("rest"):
			# A field model: spin about the axle and steer on its Steer_ empty,
			# both worked out in the parent's own axes (the model is turned).
			wheel.transform.basis = Basis(wheel.get_meta("axle") as Vector3, spin) * (wheel.get_meta("rest") as Basis)
			var pivot: Node3D = wheel.get_meta("steer") if wheel.has_meta("steer") else null
			if pivot != null: pivot.transform.basis = Basis(pivot.get_meta("up") as Vector3, yaw) * (pivot.get_meta("rest") as Basis)
			continue
		wheel.transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, spin)
	if _yoke != null: _yoke.transform.basis = Basis(_yoke_axis, steer * 2.2) * _yoke_rest

## What it can do now: full speed on the battery (less on worn wheels),
## slower on the reserve, a solar crawl by day with both flat, nothing at night.
func top_speed() -> float:
	var top := 0.0
	if battery > 0.0: top = _max_speed
	elif reserve > 0.0: top = float(_spec.reserve_speed)
	else: top = LIMP_SPEED if MHGame.sunlight_fraction > DAYLIGHT else 0.0
	if kind == "rover": top *= (.45 if wheels < 15.0 else (.75 if wheels < 40.0 else 1.0))
	return top

func _drain_per_m() -> float:
	return 100.0 / float(_spec.range_m)

func _reserve_drain_per_m() -> float:
	return 100.0 / float(_spec.reserve_m)

func _battery(_delta: float, moved: float) -> void:
	var hour := MHGame.sol_hour
	var hours := wrapf(hour - _last_hour, 0.0, 24.0) if _last_hour >= 0.0 else 0.0
	_last_hour = hour
	_charging = _charge_source()
	if not MHGame.simulation_on():   # Creative: it never runs down
		battery = 100.0
		reserve = 100.0
		if sealed(): o2 = 100.0
		_was_charging = _charging == "garage"
		return
	if battery > 0.0: battery = maxf(0.0, battery - moved * _drain_per_m())
	elif reserve > 0.0:
		var was := reserve
		reserve = maxf(0.0, reserve - moved * _reserve_drain_per_m())
		if was > 99.9 and driving: _flash("Main battery flat", "Running on the reserve: about %d m at reduced speed. Head for a Garage, a base or the lander." % roundi(float(_spec.reserve_m)))
		if was > 0.0 and reserve <= 0.0 and driving: _flash("Reserve flat", "Crawling on solar by day only. At night it can't move until sunrise.")
	if hours > 0.0 and hours < 12.0:   # more is a load, not time passing
		var add := 0.0
		match _charging:
			"garage": add = GARAGE_PER_H
			"base": add = BASE_PER_H
			"solar": add = float(_spec.solar_per_h) * clampf(MHGame.sunlight_fraction, 0.0, 1.0)
		battery = minf(100.0, battery + add * hours)
		if _charging == "garage" or _charging == "base": reserve = minf(100.0, reserve + add * hours)
		if sealed(): _cabin_air(hours)
		else:
			_lead_charge(hours)
			if _charging == "garage": _restock_stash()
	var docked := _charging == "garage"
	if docked and not _was_charging and driving and battery < 99.0: MHAudio.sfx("ui_confirm", -8.0)
	_was_charging = docked

## Where it's charging from: the Garage dock (parked in one), a base's core or
## the lander nearby (parked), or the sun.
func _charge_source() -> String:
	if absf(speed) > .1: return "solar" if not _in_bay() else ""
	if _in_bay(): return "garage"
	var world := get_tree().get_first_node_in_group("habitat_world")
	var here := Vector2(global_position.x, global_position.z)
	if world != null and world.get("lander") != null and world.lander.get("present") != false:
		var lander_at: Vector3 = (world.lander as Node3D).global_position
		if here.distance_to(Vector2(lander_at.x, lander_at.z)) < BASE_REACH: return "base"
	if builder != null and builder.get("bases") is Dictionary:
		for id in builder.bases:
			var core_at: Vector2 = MHBases.centre(builder, str(id))
			if here.distance_to(core_at) < BASE_REACH and not MHBases.zones_of(builder, str(id)).is_empty(): return "base"
	return "solar"

## The cab's life support: while you're aboard it runs off the batteries and
## keeps the air fresh; with no power the air goes stale over a few hours, and
## a leaking hull bleeds it faster than the core can make it back.
func _cabin_air(hours: float) -> void:
	if not SUIT.active():
		o2 = 100.0
		return
	if _charging == "garage": _restock(hours)
	if not aboard(): return
	var was := o2
	var leak := leak_per_h()
	if life_on():
		_draw(hours * CAB_LIFE_PER_H * (1.0 + leak / 60.0))
		o2 = clampf(o2 + (CAB_MAKE_PER_H - leak) * hours, 0.0, 100.0)
	else:
		o2 = maxf(0.0, o2 - (100.0 / CAB_STALE_HOURS + leak) * hours)
	var why := "the hull's leaking: patch it (patch kit, G outside) or get to a Garage" if leak > 0.0 else "no power: the batteries are flat"
	if was > 20.0 and o2 <= 20.0: _flash("Cab air going stale", "The cab's air is at 20%%: %s." % why)
	if was > 0.0 and o2 <= 0.0: _flash("Cab air gone", "The cab can't hold air: your suit is on its own. Head home.")

## Life support runs while either battery has charge.
func life_on() -> bool:
	return battery > 0.0 or reserve > 0.0 or not MHGame.simulation_on()

func _power() -> float:
	return battery + reserve

## Takes `pct` from the main battery, then the reserve.
func _draw(pct: float) -> void:
	if not MHGame.simulation_on(): return
	var from_main := minf(battery, pct)
	battery -= from_main
	reserve = maxf(0.0, reserve - (pct - from_main))

## Cab air % an hour the hull loses: nothing at or above HULL_LEAK_AT.
func leak_per_h() -> float:
	if hull >= HULL_LEAK_AT: return 0.0
	return HULL_LEAK_PER_H * (1.0 - hull / HULL_LEAK_AT) + 10.0

func leaking() -> bool:
	return kind == "rover" and hull < HULL_LEAK_AT

func damage_hull(pct: float, cause: String) -> void:
	if kind != "rover" or pct <= 0.0 or not MHGame.simulation_on(): return
	var was := hull
	hull = maxf(0.0, hull - pct)
	if was >= HULL_LEAK_AT and hull < HULL_LEAK_AT:
		_flash("Cab leak", "%s opened a seam in the cab (hull %d%%): you can hear it hiss. Seal it with a patch kit from outside (G), or get to a Garage." % [cause.capitalize(), roundi(hull)])
	elif driving and pct >= 3.0:
		_note(label(), "%s: the hull's at %d%%." % [cause.capitalize(), roundi(hull)])

## Quakes and storms (the hull_events group). Parked in the Garage, it's sheltered.
func hull_event(what: String) -> void:
	if wrecked or _in_bay(): return
	damage_hull(float(HULL_EVENT.get(what, 0.0)) * randf_range(.5, 1.5), "the " + ("quake" if what == "quake" else "storm"))

## A field patch seals the leak and gives some hull back; the Garage mends it fully.
func patch_hull() -> bool:
	var field := _drop_field()
	if field == null or not bool(field.get("tools")):
		_refuse("You need the patch kit (from Pallet 3) to seal the hull.")
		return false
	hull = maxf(HULL_LEAK_AT, minf(HULL_PATCH_TO, hull + HULL_PATCH))
	MHAudio.sfx("place", -4.0)
	_note(label(), "You find the hiss by the frost on the seam and press a patch over it: the hull's at %d%%. A Garage mends it properly." % roundi(hull))
	return true

func _drop_field() -> Node:
	var world := get_tree().get_first_node_in_group("habitat_world")
	var field: Node = world.get("drop_field") if world != null else null
	return field if field != null else get_tree().get_first_node_in_group("drop_field")

func _restock(hours: float) -> void:
	hull = minf(100.0, hull + 50.0 * hours)
	o2 = minf(100.0, o2 + 200.0 * hours)
	water_l = minf(WATER_L, water_l + 40.0 * hours)
	if meals < MEALS:
		var world := get_tree().get_first_node_in_group("habitat_world")
		var pod: Node = world.get("lifepod") if world != null else null
		while meals < MEALS and pod != null and pod.has_method("take_ration") and pod.take_ration(): meals += 1
		if not MHGame.needs_food_water(): meals = MEALS

func _flash(title: String, text: String) -> void:
	_note(title, text)
	MHAudio.sfx("warn", -6.0)

# ---------- recall ----------

## The first Garage: {centre, door (the hangar's outside face), out}.
func _home() -> Dictionary:
	if builder == null: return {}
	# The HabRover: a docking port on a room's outside wall comes first.
	if _docks_outside():
		var port := _port()
		if port != null:
			var out3: Vector3 = port.port_out()
			var out := Vector2(out3.x, out3.z)
			var at := Vector2(port.global_position.x, port.global_position.z)
			var pad := at + out * (_rear_m + .75)
			return {"centre": pad, "pad": pad, "door": at, "out": out, "y": port.global_position.y, "port": port}
	for zone in builder.zones:
		if str(zone.get("kind", "")) != "vehicle_bay": continue
		var outside: Vector2i = zone.get("door_direction", Vector2i(0, -1))
		var face: Dictionary = builder._zone_face(zone, outside)
		var centre := Vector2.ZERO
		for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
		centre /= float((zone.cells as Array).size())
		var door: Vector3 = face.position
		var home := {"centre": centre, "door": Vector2(door.x, door.z), "out": Vector2(outside), "y": MHBases.zone_y(builder, zone)}
		if _docks_outside():
			# The HabRover is too tall and long for the hangar: its pad is
			# outside, beside the big door (the drone dock is on the other
			# side), backed on to the wall with its airlock to the Garage.
			var out := Vector2(outside)
			var side := Vector2(-out.y, out.x)
			home["pad"] = home.door + out * (_half_base + 1.9) - side * (float(face.get("width", 6.0)) * .5 + _half_track + 1.0)
			home["centre"] = home.pad
		return home
	return {}

## The HabRover docks outside (a docking port, else a pad by the Garage
## door); the buggy drives in.
func _docks_outside() -> bool:
	return kind == "rover" and _field

## The first docking port built against an outside wall.
func _port() -> Node3D:
	for port in get_tree().get_nodes_in_group("docking_port"):
		if port.has_method("port_outside") and bool(port.port_outside()): return port as Node3D
	return null

## Docked at this port (the rig asks, for its prompt).
func docked_at(port: Node) -> bool:
	var home := _home()
	return home.get("port") == port and _in_bay() and absf(speed) < .3

## E on a docking port inside the base: through the mated hatch into the
## cabin, or (not docked) call the HabRover here. Returns a note, or "".
func through_port(port: Node) -> String:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not bool(port.call("port_outside")): return "A docking port needs an outside wall: nothing but open ground beyond it."
	if docked_at(port):
		if player == null or driving: return ""
		if walk_in():
			_cabin.through_from_port(player)
			return ""
		MHAudio.sfx("door_open", -6.0)
		_get_in(player)
		_look = Vector2(PI, -0.35)   # in through the back: up in the aisle, by the galley
		_place_camera(1.0)
		return ""
	if wrecked: return "The HabRover is wrecked: fix it, or have GAR-Y tow it home." if tow.is_empty() else _tow_line()
	return recall()

## Docked at a port, the rear airlock is mated: out that way is into the base.
func _port_exit() -> Vector3:
	var home := _home()
	if not home.has("port") or not _in_bay(): return Vector3.INF
	var port: Node3D = home.port
	var inward: Vector3 = -port.port_out()
	return port.global_position + inward * 1.1

## Called by the Garage's charger: drive home on its own. Returns what to
## tell the player.
func recall() -> String:
	var home := _home()
	if wrecked and repair == "crash": return _start_tow(home)
	if wrecked: return "It's still a wreck where you found it."
	if bogged: return "It's bogged down: someone has to dig it out or lay a mat first."
	if home.is_empty(): return "There's no Garage to come home to."
	if driving: return "Someone's driving it."
	if _cabin != null and bool(_cabin.player_in): return "You're aboard: sit in the driver's seat to drive it."
	if _in_bay(): return "It's already docked at the Garage." if _docks_outside() else "It's already here in the Garage."
	if top_speed() <= 0.0: return "Its battery and reserve are flat and it's dark: it can't move until sunrise, when its solar can crawl it home."
	_start_recall()
	var how := "on its battery" if battery > 0.0 else ("on its reserve" if reserve > 0.0 else "slowly, on its solar")
	return "Recalled: the %s is driving home %s, %d m away." % [label().to_lower(), how, roundi(Vector2(global_position.x, global_position.z).distance_to(home.centre))]

func _autopilot(delta: float) -> Vector2:
	var home := _home()
	if home.is_empty():
		recalling = false
		return Vector2.ZERO
	var at := Vector2(global_position.x, global_position.z)
	var target := _next_target(home, at)
	if _recall_stage == "approach" and top_speed() > 0.0 and _no_progress(at.distance_to(target), delta): _hop()
	if _recall_stage == "enter" and _no_progress(at.distance_to(home.centre), delta):
		park_at_home(false)
		return Vector2.ZERO
	if _recall_stage == "enter" and _docks_outside() and at.distance_to(home.centre) < 7.5:
		park_at_home(false)   # it reverses on to the pad and the umbilical: done in one step
		return Vector2.ZERO
	if _recall_stage == "enter" and at.distance_to(home.centre) < 1.2:
		recalling = false
		speed = 0.0
		if _hangar != null and _hangar.is_open(): _hangar.request_shut()
		_hangar = null
		return Vector2.ZERO
	if top_speed() <= 0.0:
		return Vector2.ZERO
	if _backing > 0.0:
		_backing -= delta
		return Vector2(-1.0, 0.6)
	if absf(speed) < 0.2:
		_stuck += delta
		if _stuck > 2.5:
			_stuck = 0.0
			_backing = 1.5
	else:
		_stuck = 0.0
	var to := target - at
	var wanted := atan2(-to.x, -to.y)
	var error := wrapf(wanted - rotation.y, -PI, PI)
	var near := clampf(at.distance_to(target) / 6.0, 0.35, 1.0)
	return Vector2(near if absf(error) < 1.4 else 0.4, clampf(error * 1.6, -1.0, 1.0))

func _start_recall() -> void:
	recalling = true
	_recall_stage = "approach"
	_stuck = 0.0
	_best = INF
	_since_better = 0.0
	var home := _home()
	if home.is_empty(): return
	var approach: Vector2 = (home.pad + home.out * 6.0) if _docks_outside() else home.door + home.out * 7.0
	var from := Vector2(global_position.x, global_position.z)
	var rocks: Array = []
	var field := get_tree().get_first_node_in_group("region_rocks")
	if field != null: rocks = field.rocks_in(Rect2(from, Vector2.ZERO).expand(approach).grow(ROVER_ROUTE.MARGIN))
	var rooms := func(p: Vector2) -> bool:
		for offset in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
			if not builder._zone_at_point(p + offset).is_empty(): return true
		return false
	_route = ROVER_ROUTE.plan(from, approach, rooms, rocks)
	if _route.is_empty(): _route = PackedVector2Array([approach])
	_route_i = 0

func _next_target(home: Dictionary, at: Vector2) -> Vector2:
	if _recall_stage != "approach": return home.centre
	if _route.is_empty(): _start_recall()
	while _route_i < _route.size() - 1 and at.distance_to(_route[_route_i]) < 6.0: _advance()
	if _route_i >= _route.size() - 1 and at.distance_to(_route[_route.size() - 1]) < 2.5:
		_recall_stage = "enter"
		_best = INF
		_since_better = 0.0
		return home.centre
	return _route[mini(_route_i, _route.size() - 1)]

func _advance() -> void:
	_route_i += 1
	_best = INF
	_since_better = 0.0

func _no_progress(distance: float, delta: float) -> bool:
	if distance < _best - 1.0:
		_best = distance
		_since_better = 0.0
		return false
	_since_better += delta
	return _since_better > HOP_AFTER

func _hop() -> void:
	_since_better = 0.0
	_best = INF
	for index in range(_route_i, mini(_route_i + 3, _route.size())):
		var point := _route[index]
		if set_down_at(Vector3(point.x, MHSiteTerrain.height(point.x, point.y), point.y), atan2(-(point.x - global_position.x), -(point.y - global_position.z))):
			recalling = true
			_route_i = index
			return
	_route_i = mini(_route_i + 1, _route.size() - 1)

func _far_from_you() -> bool:
	var world := get_tree().get_first_node_in_group("habitat_world")
	return world != null and world.player != null and (world.player as Node3D).global_position.distance_to(global_position) > GHOST_DISTANCE

func _ghost_drive(delta: float) -> void:
	speed = 0.0
	var home := _home()
	if home.is_empty():
		recalling = false
		return
	var at := Vector2(global_position.x, global_position.z)
	var target := _next_target(home, at)
	if _recall_stage == "enter":
		park_at_home(false)
		return
	var step := top_speed() * delta
	var to := target - at
	var moved := minf(step, to.length())
	if moved > 0.0:
		var next := at + to.normalized() * moved
		rotation.y = atan2(-to.x, -to.y)
		global_position = Vector3(next.x, MHSiteTerrain.height(next.x, next.y), next.y)
		_follow_ground(1.0)
	_battery(delta, moved)

func _set_braking(on: bool) -> void:
	if on == _braking: return
	_braking = on
	for light in _tail_lights: light.material_override = _tail_glow if on else null

## R: wedged against a rock or nosed into a slope it can't climb? It's set
## down on the nearest open, fairly level ground. Not for bogging: that's
## digging or a mat.
func _recover() -> bool:
	if bogged:
		_refuse("It's bogged, not wedged: lay a traction mat (L) or get out and dig it free (G beside it).")
		return false
	var back := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var side := Vector3(back.z, 0.0, -back.x)
	for distance in [3.0, 5.0, 8.0, 12.0]:
		for direction in [back, -back, side, -side, (back + side).normalized(), (back - side).normalized()]:
			var at: Vector3 = global_position + direction * distance
			if set_down_at(at): return true
	MHAudio.sfx("invalid")
	_flash("Can't free it", "No open ground nearby. Recall it from the Garage, or walk home.")
	return false

func set_down_at(at: Vector3, yaw := INF) -> bool:
	var corners := []
	for local in [Vector3(-_half_track, 0, -_half_base), Vector3(_half_track, 0, -_half_base), Vector3(-_half_track, 0, _half_base), Vector3(_half_track, 0, _half_base)]:
		var corner: Vector3 = at + Basis(Vector3.UP, rotation.y if is_inf(yaw) else yaw) * local
		var ground := _ground_under(corner, at.y)
		if is_inf(ground): return false
		corners.append(ground)
	if (corners.max() as float) - (corners.min() as float) > 1.2: return false
	var floor_y: float = (corners[0] + corners[1] + corners[2] + corners[3]) * .25
	var test := Transform3D(Basis(Vector3.UP, rotation.y if is_inf(yaw) else yaw), Vector3(at.x, floor_y + .35, at.z))
	_hull.rotation = Vector3.ZERO
	_hull.position = _hull_centre
	if test_move(test, Vector3.ZERO): return false
	global_transform = test
	speed = 0.0
	steer = 0.0
	_pitch = 0.0
	_roll = 0.0
	recalling = false
	MHAudio.sfx("place", -6.0)
	return true

func _ground_under(at: Vector3, near_y: float) -> float:
	var from := Vector3(at.x, near_y + 25.0, at.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(.02, -60.0, .015))
	query.exclude = _own_rids()
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world != null and world.player != null: query.exclude.append(world.player.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float((hit.position as Vector3).y) if not hit.is_empty() else INF

## Debug: straight home, parked in the Garage facing out, charged and stocked.
func park_at_home(refilled := true) -> bool:
	var home := _home()
	if home.is_empty() or driving: return false
	var out: Vector2 = home.out
	var y := float(home.get("y", builder.habitat_base_y))
	if _docks_outside():
		var ground := _ground_under(Vector3(home.centre.x, y, home.centre.y), y)
		if not is_inf(ground): y = ground
	global_position = Vector3(home.centre.x, y, home.centre.y)
	rotation.y = atan2(-out.x, -out.y)
	speed = 0.0
	recalling = false
	if refilled: refill()
	return true

## After GAR-Y has dragged you home: while you were out, it called this
## vehicle home too, if it could. Returns a line for the wake-up note.
func come_home_after_rescue() -> String:
	var home := _home()
	if wrecked or bogged: return ""
	if home.is_empty(): return "The %s is still where you left it: there's no Garage for it to come home to." % label().to_lower()
	if _in_bay() or driving: return ""
	var metres := Vector2(global_position.x, global_position.z).distance_to(home.centre) * 1.2
	var on_battery := minf(metres, battery / _drain_per_m())
	var on_reserve := minf(metres - on_battery, reserve / _reserve_drain_per_m())
	if on_battery + on_reserve >= metres - 1.0:
		battery = maxf(0.0, battery - on_battery * _drain_per_m())
		reserve = maxf(0.0, reserve - on_reserve * _reserve_drain_per_m())
		park_at_home(false)
		return "GAR-Y called the %s home as well: it drove itself back to the Garage while you were out%s." % [label().to_lower(), " on its reserve" if on_reserve > 0.0 else ""]
	_start_recall()
	return "GAR-Y called the %s home too. Its battery is low, so it's making its own way back, crawling on its solar by day; it's %.1f km out." % [label().to_lower(), metres / 1.2 / 1000.0]

## Debug: full battery, reserve and stores.
func refill() -> void:
	battery = 100.0
	reserve = 100.0
	if sealed():
		o2 = 100.0
		water_l = WATER_L
		meals = MEALS

## Docked: in the Garage (the buggy), or on its pad outside the door (the HabRover).
func _in_bay() -> bool:
	if _docks_outside():
		var home := _home()
		return not home.is_empty() and Vector2(global_position.x, global_position.z).distance_to(home.pad) < 3.0
	return _in_bay_room()

func _in_bay_room() -> bool:
	if builder == null: return false
	var zone: Dictionary = builder._zone_at_point(Vector2(global_position.x, global_position.z))
	return not zone.is_empty() and str(zone.get("kind", "")) == "vehicle_bay"

func _hangar_doors() -> void:
	if (not driving and not recalling) or _docks_outside():
		return
	var nearest: Node = null
	var nearest_distance := 1e9
	for door in get_tree().get_nodes_in_group("airlock_door"):
		if not door.has_method("door_label") or str(door.door_label()) != "HANGAR": continue
		var d := (door as Node3D).global_position.distance_to(global_position)
		if d < nearest_distance:
			nearest = door
			nearest_distance = d
	if nearest == null: return
	var to_door := (nearest as Node3D).global_position - global_position
	to_door.y = 0.0
	var heading := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)) * signf(speed if absf(speed) > 0.05 else 1.0)
	if nearest_distance < 8.5 and absf(speed) > 0.05 and heading.dot(to_door.normalized()) > 0.55:
		if not nearest.is_open(): nearest.request_open()
		_hangar = nearest
	elif _hangar != null and _hangar.is_open() and ((_hangar as Node3D).global_position.distance_to(global_position) > 9.5 or (_in_bay() and nearest_distance > 3.5 and absf(speed) < 0.3)):
		_hangar.request_shut()
		_hangar = null

# ---------- camera ----------

func _place_camera(delta: float) -> void:
	if first_person:
		# Parked in the HabRover, turning right round: you're up in the aisle by the galley.
		var eye: Vector3 = _spec.cab_view
		if _galley_eye != Vector3.INF and absf(speed) < .1 and absf(_look.x) > 1.75: eye = _galley_eye
		_cam.global_position = _model.global_transform * eye
		_cam.global_transform.basis = Basis(Vector3.UP, rotation.y + _look.x) * Basis(Vector3.RIGHT, _look.y)
		return
	var chase: Vector2 = _spec.chase
	var yaw := rotation.y + _look.x
	var target := global_position + Vector3.UP * 1.5
	var back := Vector3(sin(yaw), 0.0, cos(yaw)) * chase.x * cos(_look.y) + Vector3.UP * (chase.y - 1.5 - sin(_look.y) * chase.x)
	var wanted := target + back
	var query := PhysicsRayQueryParameters3D.create(target, wanted)
	query.exclude = _own_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): wanted = target + (hit.position - target) * 0.9
	_cam.global_position = _cam.global_position.lerp(wanted, minf(1.0, delta * 6.0))
	if _cam.global_position.distance_to(target) > 0.1: _cam.look_at(target, Vector3.UP)

# ---------- lights, dust, sound ----------

func _build_lights() -> void:
	var lamps: Array = [Vector3(-0.66, 0.88, -2.05), Vector3(0.66, 0.88, -2.05)] if kind == "rover" else [Vector3(-.45, .62, -1.36), Vector3(.45, .62, -1.36)]
	for at in lamps:
		var lamp := SpotLight3D.new()
		lamp.position = at
		lamp.rotation.x = deg_to_rad(-8)
		lamp.spot_range = 28.0
		lamp.spot_angle = 32.0
		lamp.light_energy = 3.2
		lamp.light_color = Color("#FFF1DA")
		lamp.shadow_enabled = false
		_model.add_child(lamp)
		_lights.append(lamp)
	if kind == "rover":
		var bar := SpotLight3D.new()
		bar.position = Vector3(0, 2.2, -1.0)
		bar.rotation.x = deg_to_rad(-20)
		bar.spot_range = 22.0
		bar.spot_angle = 50.0
		bar.light_energy = 2.0
		bar.light_color = Color("#F6F8FF")
		_model.add_child(bar)
		_lights.append(bar)
	_set_lights(false)

func _set_lights(on: bool) -> void:
	lights_on = on
	for lamp in _lights:
		lamp.visible = on
		lamp.set_meta("rig_on", on)
	if is_inside_tree(): MHAudio.sfx("ui_click", -10.0)

func _build_dust() -> void:
	for x in [-_half_track, _half_track]:
		var dust := CPUParticles3D.new()
		dust.amount = 40
		dust.lifetime = 1.6
		dust.emitting = false
		dust.local_coords = false
		dust.direction = Vector3(0, 0.6, 1)
		dust.spread = 25.0
		dust.initial_velocity_min = 0.6
		dust.initial_velocity_max = 1.6
		dust.gravity = Vector3(0, -0.4, 0)
		dust.scale_amount_min = 0.6
		dust.scale_amount_max = 1.6
		var puff := QuadMesh.new()
		puff.size = Vector2(0.9, 0.9)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(MHStyle.DUST_200, 0.22)
		m.albedo_texture = CARGO_LANDER.soft_puff_texture()
		puff.material = m
		dust.mesh = puff
		dust.position = Vector3(x, 0.2, _half_base + 0.4)
		add_child(dust)
		_dust.append(dust)

func _build_motor() -> void:
	_motor = AudioStreamPlayer3D.new()
	var hum := load("res://assets/audio/ambience/hum.wav") as AudioStreamWAV
	if hum != null:
		hum = hum.duplicate() as AudioStreamWAV
		hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum.loop_begin = 0
		hum.loop_end = int(hum.get_length() * hum.mix_rate)
		_motor.stream = hum
	_motor.unit_size = 6.0
	_motor.volume_db = -14.0
	_motor.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_motor)

func _update_effects() -> void:
	var moving := (absf(speed) > 1.2 or (bogged and driving and _axis(KEY_W, "move_forward") > 0.0)) and not _in_bay()
	for dust in _dust:
		if dust.emitting != moving: dust.emitting = moving
	if _motor.stream == null: return
	var running := driving or absf(speed) > 0.05
	if running and not _motor.playing: _motor.play()
	elif not running and _motor.playing: _motor.stop()
	_motor.pitch_scale = 0.75 + absf(speed) / _max_speed * 0.6
	_motor.volume_db = -16.0 + absf(speed) / _max_speed * 6.0

# ---------- the dashboard ----------

## The cab's screen: on the buggy's control column (its model's dash_screen),
## or in front of the EVA-6's driver (the field models have their own screens).
func _build_dash(visual: Node3D) -> void:
	_dash = DASH.new()
	add_child(_dash)
	var screen: MeshInstance3D = null
	if visual != null:
		var found := visual.find_children("dash_screen", "MeshInstance3D", true, false)
		if not found.is_empty(): screen = found[0]
	if screen == null and _spec.dash != Vector3.INF and not _field:
		screen = MeshInstance3D.new()
		screen.name = "dash_screen"
		var quad := QuadMesh.new()
		quad.size = _spec.dash_size
		screen.mesh = quad
		screen.position = _spec.dash
		screen.rotation.x = deg_to_rad(-28)
		_model.add_child(screen)
		var bezel := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3((_spec.dash_size as Vector2).x + .04, (_spec.dash_size as Vector2).y + .04, .03)
		var bezel_material := StandardMaterial3D.new()
		bezel_material.resource_name = "dash_bezel_graphite"
		bezel_material.albedo_color = Color("#4C5A61")
		box.material = bezel_material
		bezel.mesh = box
		bezel.position = Vector3(0, 0, -.017)
		screen.add_child(bezel)
	if screen != null: _dash.attach_to(screen)
	_refresh_dash()

func _refresh_dash() -> void:
	if _dash == null: return
	var power := "BATTERY %d%%" % roundi(battery) if battery > 0.0 else ("RESERVE %d%%" % roundi(reserve) if reserve > 0.0 else "FLAT")
	if not MHGame.simulation_on(): power = "BATTERY ∞"
	var km := (battery / _drain_per_m() + (reserve / _reserve_drain_per_m() if battery <= 0.0 else 0.0)) / 1000.0
	var lines: Array = ["%s   ·   RANGE %.1f km" % [power, km]]
	if _was_charging: lines[0] += "   ·   DOCKED, CHARGING"
	elif _charging == "base": lines[0] += "   ·   CHARGING"
	lines.append(_home_marker() + ("   ·   CRUISE %d" % roundi(cruise * 3.6) if cruise > 0.0 else ""))
	if sealed():
		var air := "CAB AIR %d%%   ·   HULL %d%%   ·   WATER %.0f L   ·   MEALS %d" % [roundi(o2), roundi(hull), water_l, meals] if SUIT.active() else "CAB SEALED   ·   HULL %d%%" % roundi(hull)
		lines.append(air)
		var kit: Array = ["WHEELS %d%%" % roundi(wheels)]
		if has_addon("dune_wheels"): kit.append("DUNE WHEELS")
		if has_addon("traction_mats"): kit.append("MATS %d" % mats)
		lines.append("   ·   ".join(kit))
	lines.append(("RADIO ON" if radio_on else "RADIO OFF") + ("   ·   LIGHTS" if lights_on else ""))
	var alert := ""
	var danger := false
	if bogged:
		alert = "BOGGED · " + ("L: LAY A MAT" if mats > 0 else "GET OUT AND DIG (G)")
		danger = true
	elif slip > .35: alert = "WHEELS SLIPPING · EASE OFF"
	elif kind == "rover" and wheels < 40.0:
		alert = "WHEELS WORN · SLOWER"
		danger = wheels < 15.0
	elif battery <= 0.0:
		alert = "MAIN BATTERY FLAT" if reserve > 0.0 else ("SOLAR CRAWL" if top_speed() > 0.0 else "DARK · WAIT FOR SUNRISE")
		danger = true
	elif battery < 15.0:
		alert = "BATTERY LOW"
		danger = true
	elif sealed() and SUIT.active() and o2 < 20.0:
		alert = "CAB AIR LOW" if o2 > 0.0 else "CAB AIR EMPTY · ON SUIT"
		danger = true
	elif leaking():
		alert = "HULL LEAK · PATCH IT (G OUTSIDE)"
		danger = true
	elif cabin_ready(): alert = "PARKED · Z SLEEP · X EAT AND DRINK"
	_dash.show_state(label().to_upper(), "%d km/h" % roundi(absf(speed) * 3.6), lines, alert, danger)

# ---------- the driving screen: compass, key hints, the dashboard's echo ----------

func _show_hud(on: bool) -> void:
	if on and _hud == null:
		_hud = CanvasLayer.new()
		_hud.layer = 6
		add_child(_hud)
		# The dashboard's echo for the chase view: the same screen, small, low left.
		_dash_echo = TextureRect.new()
		_dash_echo.texture = (_screens.drive as SubViewport).get_texture() if _screens.has("drive") else _dash.get_texture()
		_dash_echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_dash_echo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_dash_echo.anchor_top = 1.0; _dash_echo.anchor_bottom = 1.0
		_dash_echo.offset_left = 32; _dash_echo.offset_right = 32 + 320
		_dash_echo.offset_top = -100 - 188; _dash_echo.offset_bottom = -100
		_dash_echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(_dash_echo)
		# A small dot in the cockpit view: it lights on a part you can click.
		_reticle = Control.new()
		_reticle.set_anchors_preset(Control.PRESET_CENTER)
		_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reticle.draw.connect(func(): _reticle.draw_circle(Vector2.ZERO, 3.5, Color.WHITE); _reticle.draw_arc(Vector2.ZERO, 8.0, 0, TAU, 24, Color.WHITE, 1.5, true))
		_reticle.visible = false
		_hud.add_child(_reticle)
		# The compass, where it sits on foot (top centre): always on.
		var compass_band := CenterContainer.new()
		compass_band.anchor_right = 1
		compass_band.offset_top = 48
		compass_band.offset_bottom = 104
		compass_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(compass_band)
		_compass = MHWidgets.Compass.new()
		compass_band.add_child(_compass)
	if _hud != null:
		_hud.visible = on
		_dash_echo.visible = not first_person
		_hint_key = ""
		_refresh_hints()

func _refresh_hints() -> void:
	var key := "%s%s%s%s%s%s%s" % [cabin_ready(), bogged, _in_bay(), _aimed, _cab_open.get(_aimed, false), wrecked, tow.is_empty()]
	if key == _hint_key or _hud == null: return
	_hint_key = key
	if _hints != null: _hints.queue_free()
	var map_hint: Array = [[["Tab"], "Map"]] if MHGame.site().get("terrain", {}).get("shape", "") == "region" else []
	var hints: Array = [[["W", "S"], "Drive"], [["A", "D"], "Steer"], [["Space"], "Brake"], [["C"], "Cruise"], [["F"], "Lights"], [["V"], "Chase" if first_person else "Cockpit"]]
	if bogged: hints.append([["L"], "Lay a mat"])
	elif cabin_ready(): hints += [[["Z"], "Sleep"], [["X"], "Eat and drink"]]
	if kind == "rover" and _in_bay() and absf(speed) < .1: hints += [[["1"], "Dune wheels"], [["2"], "Mats"], [["3"], "Wheel bench"]]
	else: hints.append([["R"], "Recover"])
	if not _aimed.is_empty(): hints.push_front([["LMB"], _cab_label(_aimed), "accent"])
	if wrecked and repair == "crash": hints = [[["G"], "Radio GAR-Y for a tow" if tow.is_empty() else _tow_line()]] + ([[["Z"], "Sleep"], [["X"], "Eat and drink"]] if cabin_ready() else [])
	_hints = MHStyle.hint_strip(hints + map_hint + [[["E"], "Get out", "accent"]])
	_hud.add_child(_hints)

func _update_hud() -> void:
	_refresh_dash()
	_refresh_hints()
	if _compass != null:
		var look := -_cam.global_transform.basis.z
		_compass.heading = wrapf(rad_to_deg(atan2(look.x, -look.z)), 0.0, 360.0)
		var hud := get_tree().get_first_node_in_group("explore_hud")
		_compass.markers = hud.compass_markers() if hud != null and hud.has_method("compass_markers") else []

## "HOME 240 m ↑": the way back to the Garage (or the lander), from where it faces.
func _home_marker() -> String:
	var home := _home()
	var to := Vector2.ZERO
	var what := "GARAGE"
	if home.is_empty():
		var world := get_tree().get_first_node_in_group("habitat_world")
		if world == null or world.get("lander") == null: return "NO GARAGE"
		var at: Vector3 = (world.lander as Node3D).global_position
		to = Vector2(at.x, at.z) - Vector2(global_position.x, global_position.z)
		what = "LANDER"
	else:
		to = (home.centre as Vector2) - Vector2(global_position.x, global_position.z)
	var bearing := wrapf(atan2(-to.x, -to.y) - rotation.y, -PI, PI)
	var arrows := ["↑", "↖", "←", "↙", "↓", "↘", "→", "↗"]
	var arrow: String = arrows[posmod(roundi(bearing / (PI / 4.0)), 8)]
	return "%s %s %s" % [what, ("%.1f km" % (to.length() / 1000.0)) if to.length() >= 1000.0 else "%d m" % roundi(to.length()), arrow]

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"kind": kind, "position": global_position, "yaw": rotation.y, "battery": battery, "reserve": reserve, "o2": o2, "hull": hull, "lights": lights_on, "recalling": recalling, "radio": radio_on,
		"water_l": water_l, "meals": meals, "wheels": wheels, "addons": addons, "mats": mats, "bogged": bogged, "slip": slip, "wrecked": wrecked, "repair": repair,
		"trail": Array(trail), "stash": stash.duplicate(), "crash": crash, "tow": tow.duplicate(), "safe": _safe}

func restore_state(state: Dictionary) -> void:
	if state.has("position"): global_position = state.position as Vector3
	rotation.y = float(state.get("yaw", rotation.y))
	battery = float(state.get("battery", battery))
	reserve = float(state.get("reserve", reserve))
	o2 = float(state.get("o2", o2))
	hull = float(state.get("hull", 100.0))
	water_l = float(state.get("water_l", water_l))
	meals = int(state.get("meals", meals))
	wheels = float(state.get("wheels", wheels))
	addons = (state.get("addons", []) as Array).duplicate()
	mats = int(state.get("mats", 0))
	bogged = bool(state.get("bogged", false))
	slip = float(state.get("slip", 0.0))
	wrecked = bool(state.get("wrecked", false))
	repair = str(state.get("repair", ""))
	trail = PackedVector2Array(state.get("trail", []) as Array)
	crash = str(state.get("crash", ""))
	tow = (state.get("tow", {}) as Dictionary).duplicate()
	_safe = state.get("safe", Vector3.INF)
	if state.get("stash") is Dictionary: stash = (state.stash as Dictionary).duplicate()
	if wrecked: _model.rotation = Vector3(.05, 0, -.08)
	if bool(state.get("recalling", false)):
		_start_recall.call_deferred()
	_set_lights(bool(state.get("lights", false)))
	radio_on = bool(state.get("radio", radio_on))
