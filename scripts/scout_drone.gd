extends Node3D

## The scout drone (A7, docs/bases-and-vehicles.md "Vehicles and the drone"
## and "As built (A7)"). Ingenuity's layout, a little bigger. It lives at a
## Garage's drone dock (scripts/drone_dock.gd), and the user chose this over a
## pocket drone: a small one would be thrown about by the weather. You fly it
## yourself from the dock's console. Your view becomes its camera feed on
## the console's screen.
##
## - **Flying:** W/S forward and back, A/D sideways, Space up, Shift down,
##   mouse to turn and tilt the camera. F logs a route marker where it is
##   (known things, kind "marker": the Map and compass show them, and B3
##   joins them to your stake trails). R flies it home. E or Esc hands it
##   back to its autopilot, which flies it home to the dock.
## - **Limits:** about three minutes of battery (BATTERY_SECONDS) and about
##   800 m of radio link from its dock. The feed breaks up past 650 m; at the
##   edge it holds and turns for home. At 15% it turns for home itself.
## - **It sharpens the Map:** wherever it flies clears the fog in a wide
##   circle, wider the higher it is.
## - **Wind:** gusts are strongest just after sunrise (InSight), and a dust
##   storm grounds it. The feed's windsock shows the gust; "GUSTING" is the
##   warning. Keep flying high in a strong gust and it's thrown down where it
##   is. It's marked on the Map ("Drone down"); go there with a spares kit
##   to fix it, and it flies itself home.
## - **Flat battery away from the dock:** it lands, and its solar panel brings
##   it back after a few hours of sun, then it flies home.
## - **Found:** in a wreck beside the first yardang maze (region.json
##   "drone_wreck"; the A7 test spawn, which C1 places for real). A spares
##   kit fixes it, then it flies to the nearest dock, or waits there until
##   you build a Garage.

const MODEL := preload("res://scripts/vehicle_model.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

const SPEED := 9.0              # m/s across
const CLIMB := 3.0              # m/s up and down
const CEILING := 60.0           # m above the ground
const BATTERY_SECONDS := 180.0  # of flight, real time
const DOCK_CHARGE_PER_H := 120.0   # % an hour (game time) on the cradle
const SOLAR_PER_H := 20.0       # % an hour in full sun, landed away from the dock
const SOLAR_WAKE := 40.0        # landed flat: it flies home once it's back to this
const RETURN_AT := 15.0
const LINK_RANGE := 800.0
const LINK_FADE := 650.0
const REVEAL_BASE := 110.0      # m of fog it clears round itself, at the ground
const REVEAL_PER_M := 2.0       # and this much more for every metre up
const GUST_WARN := .55
const GUST_CRASH := .82
const CRASH_AFTER := 2.0        # seconds in a crashing gust before it's thrown down

## "wrecked", "waiting" (fixed, no dock yet), "docked", "flying" (you),
## "returning" (its autopilot), "landed" (flat, away from the dock), "down" (crashed).
var state := "wrecked"
var battery := 100.0
var markers := 0
var dock: Node3D = null
var gust := 0.0
var _gust_time := 0.0
var _hold := 0.0                # seconds in a crashing gust
var _reveal_in := 0.0
var _last_hour := -1.0
var _model: Node3D
var _rotors: Array[Node3D] = []
var _cam: Camera3D
var _look := Vector2(0.0, -.35)
var _feed: CanvasLayer
var _readout: Label
var _warning: Label
var _noise: ColorRect
var _compass: MHWidgets.Compass
var _world: Node
var _body: StaticBody3D
var _said := {}

func setup(target_world: Node) -> void:
	_world = target_world

func _ready() -> void:
	add_to_group("scout_drone")
	_model = MODEL.new()
	_model.kind = "drone"
	add_child(_model)
	for name in ["rotor_top", "rotor_bottom"]:
		var rotor := _model.get_node_or_null(name) as Node3D
		if rotor != null: _rotors.append(rotor)
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.far = 3000.0
	_cam.position = Vector3(0, .36, -.18)
	add_child(_cam)
	# Something to look at and press E on, when it's not flying.
	_body = StaticBody3D.new()
	_body.set_meta("interaction_target", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.9, .9, .9)
	shape.shape = box
	shape.position = Vector3(0, .45, 0)
	_body.add_child(shape)
	add_child(_body)

func state_words() -> String:
	return {"wrecked": "wrecked", "waiting": "waiting for a dock", "docked": "docked", "flying": "flying", "returning": "flying home", "landed": "landed, flat", "down": "down"}.get(state, state)

# ---------- found, fixed, fetched ----------

func interaction_prompt() -> Dictionary:
	match state:
		"wrecked": return {"label": "A scout drone in the wreck · rotor arm broken", "primary": "Fix it (spares kit, %d in store)" % int(MHChapterOne.stock.get("spares_kit", 0))}
		"down": return {"label": "Scout drone · down · rotor bent", "primary": "Fix it (spares kit, %d in store)" % int(MHChapterOne.stock.get("spares_kit", 0))}
		"waiting": return {"label": "Scout drone · waiting for a drone dock (a Garage has one)"}
		"landed": return {"label": "Scout drone · landed flat · charging in the sun %d%%" % roundi(battery)}
	return {}

func interact(_actor: Node = null) -> bool:
	if state != "wrecked" and state != "down": return false
	if int(MHChapterOne.stock.get("spares_kit", 0)) < 1 and MHGame.simulation_on():
		MHAudio.sfx("invalid")
		_note("You need a spares kit (the Print Shop prints them) to fix its rotor.")
		return false
	if MHGame.simulation_on(): MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.spares_kit) - 1
	var was := state
	_unpin_down()
	MHAudio.sfx("ui_confirm", -4.0)
	if was == "wrecked": battery = 60.0
	_go_home_or_wait()
	_note(("Fixed. It spins up and flies to the drone dock: fly it from the dock's console." if dock != null else "Fixed. It needs a drone dock to live at: every Garage has one. It'll fly there by itself once you've built one.") if was == "wrecked" else "Rotor straightened. It lifts off and flies itself home to its dock.")
	return true

func _go_home_or_wait() -> void:
	dock = _nearest_dock()
	if dock == null:
		state = "waiting"
		return
	if global_position.distance_to(dock.cradle()) < 1.0:
		_dock_now()
		return
	state = "returning"

func _nearest_dock() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for candidate in get_tree().get_nodes_in_group("drone_dock"):
		var d := (candidate as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best = candidate
			best_d = d
	return best

func _dock_now() -> void:
	state = "docked"
	if dock != null:
		global_position = dock.cradle()
		rotation = Vector3(0, dock.rotation.y, 0)

## A dock appears (a Garage is built): a waiting drone flies there.
func dock_built() -> void:
	if state == "waiting" or (state == "docked" and (dock == null or not is_instance_valid(dock))): _go_home_or_wait()

# ---------- flying it ----------

## E at a dock's console.
func fly_from(from_dock: Node3D) -> bool:
	if state == "flying": return false
	if state != "docked" and state != "returning":
		_note("The drone isn't at the dock: it's %s." % state_words())
		return false
	if _storm():
		MHAudio.sfx("invalid")
		_note("A dust storm's blowing: the drone stays on its cradle until it passes.")
		return false
	if battery < 20.0:
		MHAudio.sfx("invalid")
		_note("It's charging: %d%%. Give it a little longer." % roundi(battery))
		return false
	dock = from_dock if state == "docked" else dock
	state = "flying"
	_said.clear()
	var player: Node = _world.player
	player.set_meta("riding", true)
	player.set_meta("piloting", true)
	_look = Vector2(0.0, -.35)
	_cam.current = true
	_show_feed(true)
	MHAudio.sfx("ui_confirm", -6.0)
	preload("res://scripts/feature_hints.gd").first(get_tree(), "drone")
	return true

## Back to your own eyes; the autopilot takes it home.
func stop_flying(go_home := true) -> void:
	if state != "flying": return
	var player: Node = _world.player
	player.set_meta("riding", false)
	player.remove_meta("piloting")
	var head := player.get_node_or_null("Head/Camera3D") as Camera3D
	if head != null: head.current = true
	_show_feed(false)
	state = "returning" if go_home else state

func _unhandled_input(event: InputEvent) -> void:
	if state != "flying" or get_tree().paused: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look.x = wrapf(_look.x - event.relative.x * .0025, -PI, PI)
		_look.y = clampf(_look.y - event.relative.y * .0025, -1.4, .4)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		stop_flying()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: stop_flying()
			KEY_R: stop_flying()
			KEY_F: drop_marker()
			_: return
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_charge()
	if get_tree().paused: return
	match state:
		"flying": _fly(delta)
		"returning": _autopilot(delta)
	var spinning := state == "flying" or state == "returning"
	for i in _rotors.size():
		if spinning: _rotors[i].rotation.y += (40.0 if i == 0 else -40.0) * delta

func _fly(delta: float) -> void:
	var input := Vector3.ZERO
	if not bool(_world.player.get_meta("ui_freeze", false)):
		input.z = _key(KEY_S) - _key(KEY_W)
		input.x = _key(KEY_D) - _key(KEY_A)
		input.y = _key(KEY_SPACE) - _key(KEY_SHIFT)
	rotation.y = _look.x
	var move := Basis(Vector3.UP, rotation.y) * Vector3(input.x, 0, input.z)
	if move.length() > 1.0: move = move.normalized()
	var step := move * SPEED * delta + Vector3.UP * input.y * CLIMB * delta
	_move(step, delta)
	_cam.rotation = Vector3(_look.y, 0, 0)
	_model.rotation = Vector3(input.z * .18, 0, -input.x * .18)   # it leans into the way it goes
	_drain(delta)
	_wind(delta)
	_link()
	_update_feed()

func _key(code: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(code) else 0.0

## Moves it, keeping between the ground and its ceiling, and clears the Map.
func _move(step: Vector3, delta: float) -> void:
	var next := global_position + step
	var ground := MHSiteTerrain.height(next.x, next.z)
	next.y = clampf(next.y, ground + .3, ground + CEILING)
	global_position = next
	_reveal_in -= delta
	if _reveal_in <= 0.0:
		_reveal_in = .5
		var known: Node = _world.get("known")
		if known != null:
			var zone := MHSiteTerrain.region_zone()
			var origin := Vector2(float(zone.centre[0]), float(zone.centre[1])) if not zone.is_empty() else Vector2.ZERO
			known.reveal(Vector2(next.x, next.z) + origin, REVEAL_BASE + (next.y - ground) * REVEAL_PER_M)

func height_above_ground() -> float:
	return global_position.y - MHSiteTerrain.height(global_position.x, global_position.z)

func _drain(delta: float) -> void:
	if not MHGame.simulation_on(): return
	battery = maxf(0.0, battery - 100.0 / BATTERY_SECONDS * delta)
	if battery <= RETURN_AT and _once("low"):
		_note("Battery %d%%: it's turning for home." % roundi(battery))
		stop_flying()
	if battery <= 0.0: _land_flat()

## The gust now: 0 calm to 1 wild. Strongest just after sunrise (InSight),
## stronger higher up, and a storm is beyond it.
func _gust_now(delta: float) -> float:
	_gust_time += delta
	var hour := MHGame.sol_hour
	var dawn := 1.0 - clampf(absf(hour - 7.0) / 2.0, 0.0, 1.0)   # 5:00 to 9:00, peaking at 7:00
	var base := .15 + .45 * dawn
	var swell := (sin(_gust_time * .7) * .5 + .5) * (sin(_gust_time * .23 + 1.3) * .5 + .5)
	var value := base + swell * (.25 + .35 * dawn)
	value *= 1.0 + clampf(height_above_ground() / 80.0, 0.0, .6)
	if _storm(): value = 1.0
	return clampf(value, 0.0, 1.0)

func _wind(delta: float) -> void:
	gust = _gust_now(delta)
	if gust >= GUST_CRASH and height_above_ground() > 3.0:
		_hold += delta
		if _hold >= CRASH_AFTER: _crash()
	else:
		_hold = maxf(0.0, _hold - delta)
	if gust >= GUST_WARN and _once("gust"): MHAudio.sfx("warn", -8.0)
	if gust < GUST_WARN * .8: _said.erase("gust")

func _storm() -> bool:
	var sim = _world.builder.simulation() if _world != null and _world.get("builder") != null else null
	return sim != null and float(sim.get("storm_hours_left") if sim.get("storm_hours_left") != null else 0.0) > 0.0

## Thrown down by a gust: it lies where it fell, marked on the Map.
func _crash() -> void:
	stop_flying(false)
	state = "down"
	_hold = 0.0
	global_position.y = MHSiteTerrain.height(global_position.x, global_position.z)
	_model.rotation = Vector3(.9, 0, .5)
	MHAudio.sfx("land", -2.0)
	var known: Node = _world.get("known")
	if known != null:
		var zone := MHSiteTerrain.region_zone()
		var origin := Vector2(float(zone.centre[0]), float(zone.centre[1])) if not zone.is_empty() else Vector2.ZERO
		known.learn("drone:down", "pin", Vector2(global_position.x, global_position.z) + origin, "Drone down")
	_note("A gust caught it and threw it down, %d m from the dock. It's marked on the Map: take a spares kit to fix its rotor." % roundi(_from_dock()))

func _unpin_down() -> void:
	var known: Node = _world.get("known")
	if known != null:
		for id in ["drone:down", "wreck:drone"]:
			if known.things.has(id): known.things.erase(id)
		known.changed.emit()
	_model.rotation = Vector3.ZERO

func _land_flat() -> void:
	stop_flying(false)
	state = "landed"
	global_position.y = MHSiteTerrain.height(global_position.x, global_position.z)
	_note("Its battery's flat and it's landed, %d m out. Its solar panel will bring it back after a few hours of sun, and it'll fly home." % roundi(_from_dock()))

func _from_dock() -> float:
	return global_position.distance_to(dock.global_position) if dock != null and is_instance_valid(dock) else 0.0

## Past LINK_FADE the feed breaks up; at LINK_RANGE it turns for home.
func _link() -> void:
	var d := _from_dock()
	if _noise != null: _noise.color.a = clampf((d - LINK_FADE) / (LINK_RANGE - LINK_FADE), 0.0, 1.0) * .55
	if d >= LINK_RANGE:
		_note("Link lost at %d m: it's flying itself home." % roundi(d))
		stop_flying()

## F: a route marker where it is (known things, kind "marker").
func drop_marker() -> bool:
	var known: Node = _world.get("known")
	if known == null: return false
	markers += 1
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1])) if not zone.is_empty() else Vector2.ZERO
	known.learn("marker:%d" % markers, "marker", Vector2(global_position.x, global_position.z) + origin, "Marker %d" % markers, "you", "drone")
	MHAudio.sfx("ui_click", -4.0)
	return true

# ---------- the autopilot home ----------

func _autopilot(delta: float) -> void:
	if dock == null or not is_instance_valid(dock):
		dock = _nearest_dock()
		if dock == null:
			state = "waiting"
			return
	var target: Vector3 = dock.cradle()
	var to := target - global_position
	var flat := Vector2(to.x, to.z)
	var cruise := MHSiteTerrain.height(global_position.x, global_position.z) + 20.0
	var step := Vector3.ZERO
	if flat.length() > 2.0:
		var dir := flat.normalized() * minf(SPEED * delta, flat.length())
		step = Vector3(dir.x, clampf(cruise - global_position.y, -CLIMB * delta, CLIMB * delta), dir.y)
		rotation.y = atan2(-to.x, -to.z)
	else:
		step = Vector3(to.x, clampf(to.y, -CLIMB * delta, CLIMB * delta), to.z)
	var next := global_position + step
	next.y = maxf(next.y, MHSiteTerrain.height(next.x, next.z) + (0.0 if flat.length() < 2.0 else .3))
	global_position = next
	if MHGame.simulation_on() and state == "returning": battery = maxf(1.0, battery - 100.0 / BATTERY_SECONDS * delta * .5)
	if global_position.distance_to(target) < .3: _dock_now()

# ---------- charging ----------

func _charge() -> void:
	var hour := MHGame.sol_hour
	var hours := wrapf(hour - _last_hour, 0.0, 24.0) if _last_hour >= 0.0 else 0.0
	_last_hour = hour
	if hours <= 0.0 or hours > 12.0: return
	match state:
		"docked": battery = minf(100.0, battery + DOCK_CHARGE_PER_H * hours)
		"landed":
			battery = minf(100.0, battery + SOLAR_PER_H * clampf(MHGame.sunlight_fraction, 0.0, 1.0) * hours)
			if battery >= SOLAR_WAKE: _go_home_or_wait()

# ---------- the feed (the dock console's screen) ----------

func _show_feed(on: bool) -> void:
	if on and _feed == null:
		_feed = CanvasLayer.new()
		_feed.layer = 6
		add_child(_feed)
		# The console's screen: the feed, framed by its bezel.
		var bezel := Panel.new()
		bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color("#1E2A2F")
		style.set_border_width_all(28)
		style.set_corner_radius_all(18)
		bezel.add_theme_stylebox_override("panel", style)
		bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_feed.add_child(bezel)
		_noise = ColorRect.new()
		_noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_noise.color = Color(.6, .6, .6, 0)
		_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_feed.add_child(_noise)
		_readout = MHStyle.mono("", 16, Color("#B9D7DC"))
		_readout.position = Vector2(48, 44)
		_feed.add_child(_readout)
		_warning = MHStyle.mono("", 22, Color("#F2C35A"))
		_warning.anchor_left = .5; _warning.anchor_right = .5
		_warning.offset_left = -200; _warning.offset_right = 200
		_warning.anchor_top = 1.0; _warning.anchor_bottom = 1.0
		_warning.offset_top = -150; _warning.offset_bottom = -116
		_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_feed.add_child(_warning)
		var compass_band := CenterContainer.new()
		compass_band.anchor_right = 1
		compass_band.offset_top = 48
		compass_band.offset_bottom = 104
		compass_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_feed.add_child(compass_band)
		_compass = MHWidgets.Compass.new()
		compass_band.add_child(_compass)
		_feed.add_child(MHStyle.hint_strip([[["W", "S"], "Forward"], [["A", "D"], "Sideways"], [["Space"], "Up"], [["Shift"], "Down"], [["F"], "Route marker"], [["R"], "Fly home"], [["E"], "Hand back", "accent"]]))
	if _feed != null: _feed.visible = on
	for hud in get_tree().get_nodes_in_group("explore_hud"):
		if hud is CanvasLayer: (hud as CanvasLayer).visible = not on

func _update_feed() -> void:
	if _readout == null: return
	var sock := "▮".repeat(clampi(roundi(gust * 8.0), 0, 8)) + "▯".repeat(8 - clampi(roundi(gust * 8.0), 0, 8))
	var link := clampf(1.0 - (_from_dock() - LINK_FADE) / (LINK_RANGE - LINK_FADE), 0.0, 1.0) if _from_dock() > LINK_FADE else 1.0
	_readout.text = "DRONE FEED\nBATTERY %d%%   ·   LINK %d%%\nALT %d m   ·   %d m FROM DOCK\nWIND %s\nMARKERS %d" % [roundi(battery), roundi(link * 100.0), roundi(height_above_ground()), roundi(_from_dock()), sock, markers]
	_warning.text = ("GUSTING · GET LOW" if _hold > 0.0 else "GUSTING") if gust >= GUST_WARN else ""
	_warning.add_theme_color_override("font_color", Color("#FF6B60") if _hold > 0.0 else Color("#F2C35A"))
	if _compass != null:
		_compass.heading = wrapf(rad_to_deg(-rotation.y), 0.0, 360.0)
		var known: Node = _world.get("known")
		_compass.markers = known.compass_markers(global_position) if known != null else []

func _once(key: String) -> bool:
	if _said.has(key): return false
	_said[key] = true
	return true

func _note(text: String) -> void:
	get_tree().call_group("explore_hud", "show_equipment_note", "Scout drone", text)

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"state": "returning" if state == "flying" else state, "position": global_position, "yaw": rotation.y, "battery": battery, "markers": markers}

func restore_state(saved: Dictionary) -> void:
	state = str(saved.get("state", state))
	if saved.has("position"): global_position = saved.position as Vector3
	rotation.y = float(saved.get("yaw", 0.0))
	battery = float(saved.get("battery", battery))
	markers = int(saved.get("markers", 0))
	if state == "down": _model.rotation = Vector3(.9, 0, .5)
	if state == "docked" or state == "returning": dock = _nearest_dock()
	if state == "docked" and dock == null: state = "waiting"
