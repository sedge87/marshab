extends Node3D

## The descent (docs/landing-and-base-siting.md §5.2): after the Land step on a
## region site, the crew lander comes down into the landing oval and you
## move the landing point; the autopilot flies. Played in the main menu's
## backdrop: its landscape is rebuilt round the oval (a preview: no caves or
## collision). It always ends safely: a landing point on bad ground snaps to
## the nearest good ground, and ARDEN says why. When it's done, finished
## gives the touchdown spot (region metres) and the menu loads the world
## centred there.
##   1. Entry: a few seconds of glow and shake, high up. No control.
##   2. Powered descent from 800 m: the camera over the lander's shoulder,
##      the landing point's marker and the ground's hazards round it. WASD
##      or the arrow keys move it; each metre moved burns fuel, and the
##      reach shrinks as you come down. Space confirms.
##   3. Final approach from 100 m (or once confirmed, or out of fuel): the
##      point locks, the lander sets down on it.
##   4. Touchdown: dust, engines off, fade.
## Hold Esc to skip: the autopilot takes the nearest good ground to the oval's centre.

signal finished(touchdown: Vector2)

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const TRAVERSABILITY := preload("res://scripts/traversability.gd")
const OVAL := Vector2(400.0, 250.0)       # the landing oval's half axes (region_landing_picker.gd)
const LANDER_SCENE := "res://assets/vehicles/landers_v2/Crew_Lander.glb"
const ENTRY_TIME := 5.0
const POWERED_FROM := 800.0               # metres up when the marker appears
const FINAL_AT := 100.0                   # metres up when the point locks
const POWERED_TIME := 42.0                # seconds from POWERED_FROM to FINAL_AT
const FINAL_TIME := 9.0
const FUEL_PER_METRE := 1.0 / 900.0       # a full tank moves the point about 900 m
const MARKER_SPEED := 70.0                # metres a second the marker moves
const LANDER_SPEED := 30.0                # metres a second the lander slides towards it
const HAZARD_CELL := 15.0
const HAZARD_CELLS := 9                   # a 135 m square of hazards round the marker
const SKIP_HOLD := .6

var camera: Camera3D
var environment: Node
var centre := Vector2.ZERO                # the oval's centre, region metres (the site's origin here)
var phase := "entry"
var fuel := 1.0
var altitude := 2500.0
var marker := Vector2.ZERO                # site metres
var _t := 0.0
var _lander: Node3D
var _marker_mesh: MeshInstance3D
var _hazards: MultiMeshInstance3D
var _hazards_at := Vector2.INF
var _check_t := 0.0
var _valid := true
var _reason := ""
var _locked := Vector2.INF
var _lock_from := Vector3.ZERO
var _skip_t := 0.0
var _told_ground := false
var _hud: CanvasLayer
var _alt_label: Label
var _fuel_bar: ProgressBar
var _cargo_label: Label
var _arden: Label
var _hint: Label
var _glow: ColorRect
var _fade: ColorRect

## camera and environment are the main menu's; at is the oval's centre (region metres).
func setup(menu_camera: Camera3D, menu_environment: Node, at: Vector2) -> void:
	camera = menu_camera
	environment = menu_environment
	centre = at

func _ready() -> void:
	# The world round the oval: the site's origin at its centre, no pad.
	MHGame.base_site = {"centre": [centre.x, centre.y], "height": MHSiteTerrain.RegionTerrain.height(centre.x, centre.y), "label": "descent"}
	environment.rebuild_site()
	# Clear air: from hundreds of metres up the region's haze would hide the ground.
	var env: Environment = environment.world_environment.environment
	env.fog_density *= .12
	env.volumetric_fog_enabled = false
	_lander = (load(LANDER_SCENE) as PackedScene).instantiate()
	add_child(_lander)
	_marker_mesh = _make_marker()
	add_child(_marker_mesh)
	_marker_mesh.visible = false
	_hazards = _make_hazards()
	add_child(_hazards)
	_hazards.visible = false
	for side in [-1.0, 1.0]: add_child(_beacon(Vector2(side * 16.0, 9.0)))
	_build_hud()
	camera.fov = 60.0
	_place_lander(Vector2(-OVAL.x * .8, 0.0))

func _process(delta: float) -> void:
	_t += delta
	if Input.is_key_pressed(KEY_ESCAPE):
		_skip_t += delta
		if _skip_t >= SKIP_HOLD and phase != "done":
			_finish(_autopilot())
			return
	else:
		_skip_t = 0.0
	match phase:
		"entry": _entry(delta)
		"powered": _powered(delta)
		"final": _final(delta)
		"touchdown": _touchdown(delta)
	_update_hud()

# ---------- phases ----------

func _entry(_delta: float) -> void:
	var k := clampf(_t / ENTRY_TIME, 0.0, 1.0)
	altitude = lerpf(2500.0, POWERED_FROM, k)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (1.0 - k) * 2.5
	camera.global_position = _lander.global_position + Vector3(0, 6, 22) + shake
	camera.look_at(_lander.global_position + Vector3(60, -40, -200))
	_glow.color.a = (1.0 - k) * (.35 + .1 * sin(_t * 20.0))
	_place_lander(Vector2(lerpf(-OVAL.x * .8, -OVAL.x * .25, k), 0.0))
	if k >= 1.0:
		phase = "powered"
		_t = 0.0
		marker = Vector2.ZERO
		_marker_mesh.visible = true
		_hazards.visible = true
		# The tutorial: Full has ARDEN talk you through it; Hints only leaves the
		# controls line at the foot of the screen; Off says nothing.
		if MHGame.tutorial_mode == "full": _say("Powered descent. Move the landing point with WASD; watch the fuel.")
		_hint.visible = MHGame.tutorial_mode != "off"

func _powered(delta: float) -> void:
	var k := clampf(_t / POWERED_TIME, 0.0, 1.0)
	altitude = lerpf(POWERED_FROM, FINAL_AT, smoothstep(0.0, 1.0, k))
	var move := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if move != Vector2.ZERO and fuel > 0.0:
		var before := marker
		marker = _clamp_marker(marker + move.normalized() * MARKER_SPEED * delta)
		fuel = maxf(0.0, fuel - before.distance_to(marker) * FUEL_PER_METRE)
	_slide_lander(delta)
	_follow_camera(delta, 30.0, 40.0)
	_update_marker(delta)
	if k >= 1.0 or Input.is_key_pressed(KEY_SPACE) or fuel <= 0.0: _lock()

func _final(delta: float) -> void:
	var k := clampf(_t / FINAL_TIME, 0.0, 1.0)
	altitude = lerpf(_lock_from.y, 0.0, 1.0 - pow(1.0 - k, 2.0))
	var at := Vector2(_lock_from.x, _lock_from.z).lerp(_locked, smoothstep(0.0, .7, k))
	_place_lander(at)
	_follow_camera(delta, lerpf(30.0, 26.0, k), lerpf(40.0, 7.0, k))
	if k >= 1.0:
		phase = "touchdown"
		_t = 0.0
		_say("Contact. Engines off.")

func _touchdown(_delta: float) -> void:
	_fade.color.a = clampf((_t - 1.2) / 1.3, 0.0, 1.0)
	if _t > 2.6: _finish(_locked + centre)

func _lock() -> void:
	var region := marker + centre
	var why := MHBaseSite.reason(region.x, region.y)
	_locked = marker
	if not why.is_empty():
		var near := MHBaseSite.nearest_valid(region.x, region.y, 400.0)
		if is_inf(near.x): near = _autopilot()
		_locked = near - centre
		_say("Diverting: %s." % why)
	else:
		_say("Landing point locked.")
	marker = _locked
	_update_marker(1.0, true)
	_lock_from = Vector3(_lander.global_position.x, altitude, _lander.global_position.z)
	phase = "final"
	_t = 0.0

## The nearest good ground to the oval's centre (region metres).
func _autopilot() -> Vector2:
	var near := MHBaseSite.nearest_valid(centre.x, centre.y, minf(OVAL.x, OVAL.y))
	return near if not is_inf(near.x) else centre

func _finish(touchdown: Vector2) -> void:
	phase = "done"
	set_process(false)
	finished.emit(touchdown)

# ---------- the lander, camera and marker ----------

func _place_lander(at: Vector2) -> void:
	_lander.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y) + altitude, at.y)

func _slide_lander(delta: float) -> void:
	var at := Vector2(_lander.global_position.x, _lander.global_position.z)
	_place_lander(at.move_toward(marker, LANDER_SPEED * delta))

## Over the lander's shoulder: it sits in the upper part of the view, the
## ground it's heading for below.
func _follow_camera(delta: float, back: float, up: float) -> void:
	var target := _lander.global_position + Vector3(back * .25, up, back)
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	var ground := Vector3(marker.x, MHSiteTerrain.height(marker.x, marker.y), marker.y)
	var below := minf(60.0, _lander.global_position.distance_to(ground) * .5)
	camera.look_at(_lander.global_position + (ground - _lander.global_position).normalized() * below)

## Within the oval and within reach of the lander (the reach shrinks as it comes down).
func _clamp_marker(point: Vector2) -> Vector2:
	var p := point
	var e := Vector2(p.x / OVAL.x, p.y / OVAL.y)
	if e.length() > 1.0: p = Vector2(p.x, p.y) / e.length()
	var lander := Vector2(_lander.global_position.x, _lander.global_position.z)
	var reach := 40.0 + OVAL.x * clampf(altitude / POWERED_FROM, 0.0, 1.0)
	if p.distance_to(lander) > reach: p = lander + (p - lander).normalized() * reach
	return p

func _update_marker(delta: float, force := false) -> void:
	_marker_mesh.global_position = Vector3(marker.x, MHSiteTerrain.height(marker.x, marker.y) + .5, marker.y)
	_check_t -= delta
	if _check_t <= 0.0 or force:
		_check_t = .25
		var region := marker + centre
		_reason = MHBaseSite.reason(region.x, region.y)
		_valid = _reason.is_empty()
		(_marker_mesh.material_override as StandardMaterial3D).albedo_color = MHStyle.VALID if _valid else MHStyle.DANGER
	if force or _hazards_at.distance_to(marker) > HAZARD_CELL: _draw_hazards()

## The lander's sensor view: the ground round the marker, green, yellow or red.
func _draw_hazards() -> void:
	_hazards_at = marker
	var multimesh := _hazards.multimesh
	var first := -(HAZARD_CELLS - 1) * .5
	var index := 0
	for i in HAZARD_CELLS:
		for j in HAZARD_CELLS:
			var x := marker.x + (first + i) * HAZARD_CELL
			var z := marker.y + (first + j) * HAZARD_CELL
			var sand := MHSiteTerrain.geology_unit(x, z) == "dune_sand"
			var kind := TRAVERSABILITY.grade_class(x, z, sand)
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, MHSiteTerrain.height(x, z) + .4, z)))
			var colour: Color = TRAVERSABILITY.COLOURS[kind]
			# Fading out from the marker: the lander's sensor, not a grid on the land.
			colour.a = .5 * clampf(1.0 - Vector2(first + i, first + j).length() / (HAZARD_CELLS * .55), 0.0, 1.0)
			multimesh.set_instance_color(index, colour)
			index += 1

func _make_marker() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 11.0
	ring.mesh = torus
	ring.scale = Vector3(1, .1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MHStyle.VALID
	material.no_depth_test = true
	ring.material_override = material
	return ring

func _make_hazards() -> MultiMeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2(HAZARD_CELL, HAZARD_CELL) * .92
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = HAZARD_CELLS * HAZARD_CELLS
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	return instance

## A cargo lander's beacon: a tall thin light, visible from high up.
func _beacon(at: Vector2) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .6
	cylinder.bottom_radius = 1.2
	cylinder.height = 60.0
	beam.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(MHStyle.accent, .55)
	beam.material_override = material
	beam.position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y) + 30.0, at.y)
	return beam

# ---------- HUD ----------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 30
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHStyle.theme()
	_hud.add_child(root)
	_glow = ColorRect.new()
	_glow.color = Color(1.0, .45, .15, 0.0)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_glow)
	var panel := MHStyle.hud_panel(18, false, true)
	panel.position = Vector2(40, 40)
	var col := MHStyle.vbox(8)
	col.add_child(MHStyle.eyebrow("Descent", MHStyle.accent, 13))
	_alt_label = MHStyle.mono("", 18, MHStyle.TEXT_PRIMARY)
	col.add_child(_alt_label)
	col.add_child(MHStyle.mono("FUEL", 12, MHStyle.TEXT_SECONDARY))
	_fuel_bar = ProgressBar.new()
	_fuel_bar.custom_minimum_size = Vector2(220, 10)
	_fuel_bar.max_value = 1.0
	_fuel_bar.show_percentage = false
	col.add_child(_fuel_bar)
	_cargo_label = MHStyle.mono("", 14, MHStyle.TEXT_SECONDARY)
	col.add_child(_cargo_label)
	panel.add_child(col)
	root.add_child(panel)
	_arden = MHStyle.label("", 20, MHStyle.TEXT_PRIMARY, 600)
	_arden.anchor_left = .5
	_arden.anchor_right = .5
	_arden.offset_left = -500
	_arden.offset_right = 500
	_arden.offset_top = 60
	_arden.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arden.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	_arden.add_theme_constant_override("outline_size", 6)
	root.add_child(_arden)
	_hint = MHStyle.mono("WASD  move the landing point    SPACE  confirm    HOLD ESC  skip", 13, MHStyle.TEXT_SECONDARY)
	_hint.anchor_top = 1
	_hint.anchor_bottom = 1
	_hint.offset_left = 40
	_hint.offset_top = -50
	root.add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

func _update_hud() -> void:
	_alt_label.text = "ALT %4d m" % roundi(altitude)
	_fuel_bar.value = fuel
	_cargo_label.text = "CARGO  %d m" % roundi(marker.distance_to(Vector2(0, 9))) if phase != "entry" else ""
	if phase == "powered" and MHGame.tutorial_mode == "full" and _t > 6.0 and not _told_ground:
		_told_ground = true
		_say("Green ground is good for the base. The beacons are the cargo.")
	if phase == "powered" and not _valid: _hint.text = "Landing point: %s    SPACE  confirm    HOLD ESC  skip" % _reason
	elif phase == "powered": _hint.text = "WASD  move the landing point    SPACE  confirm    HOLD ESC  skip"
	elif phase != "entry": _hint.text = ""
	_hint.add_theme_color_override("font_color", MHStyle.DANGER if phase == "powered" and not _valid else MHStyle.TEXT_SECONDARY)

func _say(line: String) -> void:
	_arden.text = "ARDEN: " + line
