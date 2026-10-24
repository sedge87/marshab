extends Node3D

const WEATHER_SCRIPT := preload("res://scripts/weather.gd")
const SITE_WEATHER := preload("res://scripts/site_weather.gd")
const ALERTS_SCRIPT := preload("res://scripts/habitat_alerts.gd")
const MISSION_CONTROL_LINK := preload("res://scripts/mission_control_link.gd")
const GAR_Y_ORDERS := preload("res://scripts/gar_y_orders.gd")
const SLEEP := preload("res://scripts/sleep.gd")
const CARRY := preload("res://scripts/carry.gd")
const HABITAT_MONITOR := preload("res://scripts/habitat_monitor.gd")
const HABITAT_CAMERAS := preload("res://scripts/habitat_cameras.gd")
const SHOWCASE_SCRIPT := preload("res://scripts/showcase.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/main_menu.tscn"
const ORIGINAL_ENVIRONMENT_SCRIPT := preload("res://scripts/original_mars_environment.gd")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/build_controller.gd")
const INTERIOR_BUILD_CONTROLLER_SCRIPT := preload("res://scripts/interior_build_controller.gd")
const SURFACE_BUILD_CONTROLLER_SCRIPT := preload("res://scripts/surface_build_controller.gd")
const DAY_NIGHT_SCRIPT := preload("res://scripts/site_day_night.gd")
const DEBUG_PANEL_SCRIPT := preload("res://scripts/debug_panel.gd")
const CREW_LANDER_SCRIPT := preload("res://scripts/crew_lander.gd")
const CARGO_LANDER_SCRIPT := preload("res://scripts/cargo_lander.gd")
const LANDING_PICKER_SCRIPT := preload("res://scripts/landing_picker.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MISSION_HUD_SCRIPT := preload("res://scripts/mission_hud.gd")
const SCOUT_ROVER_SCENE_PATH := "res://scenes/mars_scout_rover.tscn"
# Optional companion feature. Set false to remove it without touching player,
# habitat or simulation code.
const SPAWN_SCOUT_ROVER := true

var environment
var builder: BuildController
var player: CharacterBody3D
var explore_hud: MHExploreHUD
var overlay_layer: CanvasLayer
var pause_menu: MHPauseMenu
var mission_control: MHMissionControl
var dust: CPUParticles3D
var weather: Node   # scripts/weather.gd: storm warnings, haze, dust and sound
## Each site's own weather (frost, fog, dust devils, quakes, twilight clouds).
var site_weather: Node3D
var alerts: Node    # scripts/habitat_alerts.gd: habitat alerts (backlog 26)
var earth_link: Node   # scripts/mission_control_link.gd: delayed messages from Earth
var _earth_link_state := {}
## The finished campaign's record (versions, reports) for a base carried on
## into free play, so Mission Control can still open its dossier.
var campaign_record := {}
var sleep: Node   # scripts/sleep.gd: sleep at a bunk to pass the time
var carry: Node   # scripts/carry.gd: pick up small things and put them elsewhere
var gar_y_orders: CanvasLayer   # scripts/gar_y_orders.gd: hold G to give GAR-Y orders
var monitor: Control            # the open live view (habitat_monitor.gd or habitat_cameras.gd)
var showcase: Node              # scripts/showcase.gd, in Showcase mode
var scout_rover: Node3D
## The crew rover (scripts/crew_rover.gd): it appears in the vehicle bay once
## the base has one, and is saved with the base.
const CREW_ROVER_SCRIPT := preload("res://scripts/crew_rover.gd")
var crew_rover: CharacterBody3D
var _crew_rover_state := {}
var interior_builder: MHInteriorBuildController
var surface_builder: MHSurfaceBuildController
var day_night: MHSiteDayNight
var debug_panel: CanvasLayer
var lander: Node3D
# New games start inside the lander: "inside" until the hatch opens, "open"
# until the player steps out, then "done".
var _start_in_lander := false
var _intro_stage := "done"
var _landing_miss := 0.0   # metres between the chosen target and the touchdown
var mission_hud: CanvasLayer
# The Compatibility renderer draws at most 32 lights in view and silently
# drops the rest, which made random rooms look unpowered. Only the nearest
# LIGHT_BUDGET lights stay on (their glowing diffusers always show).
const LIGHT_BUDGET := 28
const LIGHT_RANGE := 40.0
var _budget_lights: Array = []
var _budget_dirty := true
# Missions: cargo landers on site, the one this mission's robot rode down in,
# and what only the world knows for the step tracker.
var cargo_landers: Array = []
var current_cargo_lander: Node3D
var mission_flags := {"left_lander": false, "opened_plan": false, "inside": false}
# Mission 4: the crew's own lander touches down and they start in its cabin.
var crew_arrival := false
# Survival and Freedom: resupply landers on compressed launch windows.
var resupply_landers: Array = []   # [{position, yaw}] for saving
var _resupply_check := 0.0
var arrival_pending := false
signal arrival_finished
var _arrival_t := -1.0
var _arrival_camera: Camera3D
var _arrival_layer: CanvasLayer
var _arrival_caption: Array = []
var _arrival_dust: CPUParticles3D
var _arrival_from := Vector3.ZERO
var _arrival_landed := false
const ARRIVAL_LENGTH := 10.5

func _ready() -> void:
	add_to_group("habitat_world")
	MHGame.set_accent(MHGame.accent_index)
	_build_landscape()
	if MHMissions.active() and MHGame.pending_save_state.has("missions_progress"):
		MHMissions.load_state(MHGame.pending_save_state.get("missions_progress", {}) as Dictionary)
	elif not (MHGame.pending_save_state.get("campaign_record", {}) as Dictionary).is_empty():
		# A base carried on from a finished campaign keeps its dossier.
		campaign_record = (MHGame.pending_save_state.campaign_record as Dictionary).duplicate(true)
		MHMissions.progress = campaign_record.duplicate(true)
	lander = CREW_LANDER_SCRIPT.new()
	add_child(lander)
	_land_lander()
	_start_in_lander = MHGame.pending_save_state.is_empty() and not MHMissions.active()   # every new free-play game opens in the lander
	if MHMissions.active():
		lander.set_present(bool(MHMissions.current().get("lander", true)))
		_add_landing_zone_marker()
		_spawn_cargo_landers()
		var mission := MHMissions.current()
		if bool(mission.get("crew_arrival", false)) and not MHMissions.arrived(str(mission.id)):
			crew_arrival = true
			_start_in_lander = true
			arrival_pending = true   # the crew lander's descent, then you're in the cabin
			var target := MHMissions.landing_target()
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			lander.place_at(_clear_touchdown(target if not is_inf(target.x) else Vector2.ZERO, rng, false))
	_spawn_player()
	_spawn_scout_rover()
	builder = BUILD_CONTROLLER_SCRIPT.new()
	builder.lander = lander
	add_child(builder)
	if scout_rover != null: scout_rover.set("habitat", builder)   # it roams the rooms indoors
	builder.mission_control_requested.connect(_open_mission_control)
	builder.habitat_changed.connect(func() -> void: _budget_dirty = true)
	builder.habitat_changed.connect(_sync_crew_rover)
	if MHMissions.active(): builder.simulation().crew_cap = MHMissions.crew_cap()
	builder.interior_build_requested.connect(_open_interior_build)
	builder.surface_build_requested.connect(_open_surface_build)
	interior_builder = INTERIOR_BUILD_CONTROLLER_SCRIPT.new()
	add_child(interior_builder)
	interior_builder.setup(player, builder)
	surface_builder = SURFACE_BUILD_CONTROLLER_SCRIPT.new()
	add_child(surface_builder)
	surface_builder.setup(player, builder)
	day_night = DAY_NIGHT_SCRIPT.new()
	add_child(day_night)
	day_night.setup(environment, builder)
	_restore_pending_habitat()
	_sync_crew_rover()
	if MHMissions.active(): MHMissions.deliver_mission_food(builder.simulation())
	configure_life()
	if crew_arrival:
		var cabin: Dictionary = lander.cabin_start()
		player.global_position = cabin.position
		player.rotation.y = float(cabin.yaw)
		player.safe_position = player.global_position
	_build_hud()
	weather = WEATHER_SCRIPT.new()
	add_child(weather)
	weather.setup(self)
	site_weather = SITE_WEATHER.new()
	add_child(site_weather)
	site_weather.setup(self)
	alerts = ALERTS_SCRIPT.new()
	add_child(alerts)
	alerts.setup(self)
	earth_link = MISSION_CONTROL_LINK.new()
	add_child(earth_link)
	earth_link.setup(self)
	earth_link.restore_state(_earth_link_state)
	sleep = SLEEP.new()
	add_child(sleep)
	sleep.setup(self)
	carry = CARRY.new()
	add_child(carry)
	carry.setup(self)
	gar_y_orders = GAR_Y_ORDERS.new()
	add_child(gar_y_orders)
	gar_y_orders.setup(self)
	_begin_lander_intro()
	if MHMissions.active() and not MHGame.showcase:
		if str(MHMissions.current().get("player", "crew")) == "robot": explore_hud.chip_prefix = "ROBOT · "
		mission_hud = MISSION_HUD_SCRIPT.new()
		mission_hud.setup(self)
		add_child(mission_hud)
	_apply_settings()
	if arrival_pending: _start_arrival()
	else: _play_intro()
	MHAudio.music("surface")
	MHAudio.ambience("outside")
	MHAudio.build_layer(false)
	# Showcase: the base presents itself (scripts/showcase.gd).
	if MHGame.showcase:
		_intro_stage = "done"
		showcase = SHOWCASE_SCRIPT.new()
		add_child(showcase)
		showcase.setup.call_deferred(self)
	MHAudio.muffle(false)

func _unhandled_input(event: InputEvent) -> void:
	# Any key or click skips the touchdown cinematic.
	if _arrival_t >= 0.0:
		if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo() and _arrival_t > .6:
			_finish_arrival()
		get_viewport().set_input_as_handled()
		return
	# Hidden debug tools for testing: Ctrl+Shift+F12.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12 and event.ctrl_pressed and event.shift_pressed:
		if debug_panel == null:
			debug_panel = DEBUG_PANEL_SCRIPT.new()
			debug_panel.setup(self)
			add_child(debug_panel)
		else:
			debug_panel.toggle()
		get_viewport().set_input_as_handled()
		return
	if monitor != null or showcase != null: return   # those handle their own keys
	if event.is_action_pressed("ui_cancel"):
		if pause_menu == null: _show_pause()
		else: _resume()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_open_mission_control()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C and not event.ctrl_pressed and not bool(player.get_meta("build_mode_active", false)):
		# C: straight to the Crew screen (in Mission Control).
		_open_mission_control()
		if mission_control != null: mission_control.call_deferred("_show_crew")

func _open_interior_build() -> void:
	if pause_menu != null or mission_control != null or interior_builder == null:
		return
	interior_builder.enter()

func _open_surface_build(id: String) -> void:
	if pause_menu != null or mission_control != null or surface_builder == null:
		return
	surface_builder.enter(id)

# Wind outside, life-support hum once the player is inside a habitat zone.
var _space_check := 0.0
func _process(delta: float) -> void:
	_update_lander_intro()
	_resupply_check -= delta
	if _resupply_check <= 0.0:
		_resupply_check = 1.0
		_check_resupply()
	if _arrival_t >= 0.0: _update_arrival(delta)
	if MHMissions.active():
		if builder.build_mode: mission_flags.opened_plan = true
		if builder.is_inside(player.global_position): mission_flags.inside = true
		if crew_arrival or bool(MHMissions.current().get("crew_arrival", false)):
			if lander.hatch_open() and not lander.cabin_contains(player.global_position): mission_flags.left_lander = true
		elif current_cargo_lander == null or (current_cargo_lander.ramp_open and not current_cargo_lander.hold_contains(player.global_position)):
			mission_flags.left_lander = true
	_space_check -= delta
	if _space_check > 0.0: return
	_space_check = .3
	_apply_light_budget()
	var eye := get_viewport().get_camera_3d()
	if eye != null: builder.update_furniture_visibility(eye.global_position)
	# Room lights: the room you're in counts as occupied (like a motion sensor).
	var you_in := builder._room_key_at(Vector2(player.global_position.x, player.global_position.z)) if builder.is_inside(player.global_position) else ""
	if builder.simulation().player_room != you_in:
		builder.simulation().player_room = you_in
		builder.simulation().invalidate()
	builder.update_room_lights()
	var inside: bool = not builder.build_mode and (builder.is_inside(player.global_position) or bool(lander.cabin_contains(player.global_position)))
	MHAudio.ambience("inside" if inside else "outside")
	# Interior fill light only while the habitat's own lights are on (not in
	# the lander, which keeps its own dim cabin lighting).
	var fill := not builder.build_mode and builder.is_inside(player.global_position) and builder.room_light_state(you_in) == "on"
	var in_cabin: bool = lander.cabin_contains(player.global_position) or cargo_landers.any(func(c): return c.hold_contains(player.global_position))
	var in_habitat: bool = not builder.build_mode and builder.is_inside(player.global_position)
	if environment.interior_fill != fill or environment.cabin_dim != in_cabin or environment.inside_habitat != in_habitat:
		environment.interior_fill = fill
		environment.cabin_dim = in_cabin
		environment.inside_habitat = in_habitat
		environment.apply_daylight(MHGame.sunlight_fraction)

func _apply_light_budget() -> void:
	if _budget_dirty:
		_budget_dirty = false
		_budget_lights = find_children("*", "Light3D", true, false).filter(func(l): return not (l is DirectionalLight3D) and not player.is_ancestor_of(l) and not bool(l.get_meta("budget_exempt", false)))
		# Lights at the edge of the budget fade out with distance, not pop.
		for light in _budget_lights:
			(light as Light3D).distance_fade_enabled = true
			(light as Light3D).distance_fade_begin = LIGHT_RANGE - 10.0
			(light as Light3D).distance_fade_length = 8.0
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var eye := camera.global_position
	var live: Array = _budget_lights.filter(func(l): return is_instance_valid(l) and l.is_inside_tree())
	if live.size() != _budget_lights.size(): _budget_dirty = true
	live.sort_custom(func(a, b): return eye.distance_squared_to(a.global_position) < eye.distance_squared_to(b.global_position))
	for index in range(live.size()):
		var light: Light3D = live[index]
		light.visible = index < LIGHT_BUDGET and eye.distance_to(light.global_position) < LIGHT_RANGE and bool(light.get_meta("rig_on", true))

## A new game opens in the dim lander cabin with a minimal HUD; opening the
## hatch lowers the ramp, and stepping out onto Mars brings the full HUD in.
## Saved games restore the lander where it landed. New games land on the
## player's chosen target: exactly in Freedom and Creative, somewhere in the
## landing ellipse in Survival. Quick start lets the game pick.
## Missions: the landing zone (ellipse and its engine-blast margin) marked on
## the ground, so players can see where they mustn't build.
func _add_landing_zone_marker() -> void:
	var target := MHMissions.landing_target()
	if is_inf(target.x): return
	for ring in [[LANDING_PICKER_SCRIPT.ELLIPSE_A, LANDING_PICKER_SCRIPT.ELLIPSE_B, Color(1.0, .8, .3, .9), .35], [LANDING_PICKER_SCRIPT.ELLIPSE_A + MHMissions.BLAST_MARGIN, LANDING_PICKER_SCRIPT.ELLIPSE_B + MHMissions.BLAST_MARGIN, Color(1.0, .45, .2, .7), .2]]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 72
		for i in range(steps):
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			var points: Array = []
			for a in [a0, a1]:
				for scale in [1.0, 1.0 - float(ring[3]) / float(ring[1])]:
					var p: Vector2 = target + Vector2(cos(a) * float(ring[0]) * scale, sin(a) * float(ring[1]) * scale)
					points.append(Vector3(p.x, MHSiteTerrain.height(p.x, p.y) + .06, p.y))
			for index in [0, 2, 1, 1, 2, 3]: surface.add_vertex(points[index])
		var marker := MeshInstance3D.new()
		marker.name = "LandingZoneMarker"
		marker.mesh = surface.commit()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = ring[2]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		(marker.mesh as ArrayMesh).surface_set_material(0, material)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)

# ---------- resupply landers ----------

## When a launch window comes round, a resupply lander comes down near the
## crew lander, adds its cargo, and stays on site as a landmark.
func _check_resupply() -> void:
	if not MHGame.resupplies_on() or MHMissions.active() or _intro_stage != "done": return
	if MHGame.resupply_due_in_hours(builder.simulation().hours_run) > 0.0: return
	var spot := _resupply_spot()
	MHGame.resupply_count += 1
	MHGame.resupply_kg += MHGame.resupply_size_kg()
	var record := {"position": spot.position, "yaw": float(spot.yaw)}
	resupply_landers.append(record)
	var cargo := _add_resupply_lander(spot.position, float(spot.yaw), MHGame.resupply_count)
	# Seen from wherever the player is: a burn, a slow descent, dust, touchdown.
	var ground: Vector3 = spot.position
	cargo.global_position = ground + Vector3.UP * 60.0
	cargo.set_ramp(false)
	cargo.set_burn(true)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cargo, "global_position", ground, 7.0)
	tween.tween_callback(func() -> void:
		cargo.set_burn(false)
		cargo.set_ramp(true, true)
		MHAudio.sfx("land", 0.0, 0.0))
	MHAudio.sfx("landing", -2.0, 0.0)
	explore_hud.show_equipment_note("Resupply %d landed" % MHGame.resupply_count, "A launch window came round: %s of cargo from Earth has landed near your lander. Next one in %s sols." % [MHStyle.kg(MHGame.resupply_size_kg()), str(snappedf(MHGame.resupply_interval_sols(), 0.5))])
	builder.habitat_changed.emit()

func _add_resupply_lander(at: Vector3, yaw: float, number: int) -> Node3D:
	var cargo: Node3D = CARGO_LANDER_SCRIPT.new()
	cargo.number = number
	cargo.name = "ResupplyLander%d" % number
	add_child(cargo)
	cargo.set_meta("landmark_label", "RESUPPLY %d" % number)
	cargo.global_position = at
	cargo.rotation.y = yaw
	cargo.set_ramp(true)
	return cargo

## Flat open ground 18–30 m from the crew lander, clear of the habitat and
## earlier landers.
func _resupply_spot() -> Dictionary:
	var centre := Vector2(lander.global_position.x, lander.global_position.z)
	var taken: Array = resupply_landers.map(func(r): return Vector2((r.position as Vector3).x, (r.position as Vector3).z))
	for radius in [18.0, 23.0, 28.0, 34.0]:
		for step in range(16):
			var a: float = TAU * (step + MHGame.resupply_count * 5) / 16.0
			var p: Vector2 = centre + Vector2(cos(a), sin(a)) * radius
			if not MHSiteTerrain.is_buildable(p): continue
			if not builder._zone_at_point(p).is_empty() or builder.is_inside(Vector3(p.x, builder.habitat_base_y + .5, p.y)): continue
			var clear := true
			for zone in builder.zones:
				for cell in zone.get("cells", []):
					if Vector2(cell.x * 3.0, cell.y * 3.0).distance_to(p) < 7.0: clear = false
			for other in taken:
				if (other as Vector2).distance_to(p) < 9.0: clear = false
			if not clear: continue
			var probe: Node3D = CARGO_LANDER_SCRIPT.new()
			add_child(probe)
			probe.place_at(p, centre)
			var result := {"position": probe.global_position, "yaw": probe.rotation.y}
			probe.queue_free()
			return result
	var fallback := centre + Vector2(20, 0)
	return {"position": Vector3(fallback.x, MHSiteTerrain.height(fallback.x, fallback.y), fallback.y), "yaw": 0.0}

# ---------- Missions: cargo landers and the touchdown cinematic ----------

## Every cargo lander so far stands where it landed. A mission that arrives by
## cargo lander and has not played its arrival yet lands a new one now.
func _spawn_cargo_landers() -> void:
	for saved in MHMissions.cargo_landers():
		var cargo := _add_cargo_lander(int(saved.number))
		cargo.global_position = saved.position as Vector3
		cargo.rotation.y = float(saved.yaw)
		cargo.set_ramp(true)
	var mission := MHMissions.current()
	var number := int(mission.get("cargo_lander", 0))
	if number <= 0: return
	for cargo in cargo_landers:
		if int(cargo.number) == number: current_cargo_lander = cargo
	if MHMissions.arrived(str(mission.id)) or current_cargo_lander != null: return
	var target := MHMissions.landing_target()
	if is_inf(target.x): target = Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	current_cargo_lander = _add_cargo_lander(number)
	var base := MHMissions.base_site()
	current_cargo_lander.place_at(_clear_touchdown(target, rng), base if not is_inf(base.x) else Vector2.ZERO)
	MHMissions.cargo_landers().append({"number": number, "position": current_cargo_lander.global_position, "yaw": current_cargo_lander.rotation.y})
	arrival_pending = true

## A touchdown point in the landing ellipse that keeps clear of the landers
## already down: the best of several tries, at least 16 m from the others
## where the ellipse allows.
## Act 2 in live play: named crew (Mission 8 on, and free play) and, with
## the Settings toggle, rare hazards from missions already passed.
func configure_life() -> void:
	var sim: RefCounted = builder.simulation()
	var life: RefCounted = sim.life
	var kinds: Array = []
	if MHMissions.active():
		life.crew_on = int(MHMissions.current().get("number", 1)) >= 8
		if bool(MHGame.setting("live_hazards")):
			if MHMissions.is_complete("solar_shelter"): kinds.append("spe")
			if MHMissions.is_complete("hull_breach"): kinds.append("breach")
			if MHMissions.is_complete("long_silence"): kinds.append("breakdowns")
		if life.crew_on:
			life.ensure_crew(sim.crew_count(), MHMissions.progress.get("crew_names", []))
			life.set_names(MHMissions.progress.get("crew_names", []))
	else:
		life.crew_on = MHGame.simulation_on()
		if MHGame.game_mode == "survival" and bool(MHGame.setting("live_hazards")): kinds = ["spe", "breach", "breakdowns"]
	life.live_kinds = kinds

func _clear_touchdown(target: Vector2, rng: RandomNumberGenerator, avoid_lander := true) -> Vector2:
	var taken: Array = MHMissions.cargo_landers().map(func(c): return Vector2((c.position as Vector3).x, (c.position as Vector3).z))
	for cargo in cargo_landers: taken.append(Vector2(cargo.global_position.x, cargo.global_position.z))
	if avoid_lander and lander != null and lander.present: taken.append(Vector2(lander.global_position.x, lander.global_position.z))
	var best := LANDING_PICKER_SCRIPT.touchdown(target, "missions", rng) as Vector2
	var best_gap := -1.0
	for attempt in 40:
		var spot: Vector2 = LANDING_PICKER_SCRIPT.touchdown(target, "missions", rng) if attempt > 0 else best
		var gap := INF
		for other in taken: gap = minf(gap, spot.distance_to(other))
		if gap > best_gap:
			best_gap = gap
			best = spot
		if best_gap >= 16.0: break
	return best

func _add_cargo_lander(number: int) -> Node3D:
	var cargo: Node3D = CARGO_LANDER_SCRIPT.new()
	cargo.number = number
	cargo.name = "CargoLander%d" % number
	add_child(cargo)
	cargo_landers.append(cargo)
	return cargo

## The cargo lander's descent, seen from the ground: engine burn, dust, touchdown.
## Captions close Mission 1 and introduce this landing. Any key skips it.
func _start_arrival() -> void:
	var mission := MHMissions.current()
	var cargo := _arrival_craft()
	_arrival_landed = false
	_arrival_from = cargo.global_position
	cargo.global_position = _arrival_from + Vector3.UP * 90.0
	cargo.set_burn(true)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	explore_hud.visible = false
	if mission_hud != null: mission_hud.visible = false
	_arrival_camera = Camera3D.new()
	_arrival_camera.fov = 58.0
	add_child(_arrival_camera)
	var side: Vector3 = cargo.global_transform.basis * Vector3(15.0, 0.0, -11.0)
	var eye := _arrival_from + side
	eye.y = MHSiteTerrain.height(eye.x, eye.z) + 3.0
	_arrival_camera.global_position = eye
	_arrival_camera.current = true
	# Dust thrown out by the plume as it nears the ground.
	_arrival_dust = CPUParticles3D.new()
	_arrival_dust.emitting = false
	_arrival_dust.amount = 220
	_arrival_dust.lifetime = 3.0
	_arrival_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_arrival_dust.emission_ring_axis = Vector3.UP
	_arrival_dust.emission_ring_radius = 2.5
	_arrival_dust.emission_ring_inner_radius = .5
	_arrival_dust.emission_ring_height = .2
	_arrival_dust.direction = Vector3(1, .15, 0)
	_arrival_dust.spread = 180.0
	_arrival_dust.flatness = .85
	_arrival_dust.initial_velocity_min = 5.0
	_arrival_dust.initial_velocity_max = 13.0
	_arrival_dust.damping_min = 2.5
	_arrival_dust.damping_max = 4.0
	_arrival_dust.gravity = Vector3(0, -.3, 0)
	_arrival_dust.scale_amount_min = 1.0
	_arrival_dust.scale_amount_max = 2.4
	var puff := QuadMesh.new(); puff.size = Vector2(1.4, 1.4)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.albedo_color = Color(MHStyle.DUST_200, .28)
	puff_material.albedo_texture = CARGO_LANDER_SCRIPT.soft_puff_texture()
	puff.material = puff_material
	_arrival_dust.mesh = puff
	_arrival_dust.position = _arrival_from + Vector3.UP * .4
	add_child(_arrival_dust)
	# Letterbox and captions.
	_arrival_layer = CanvasLayer.new()
	_arrival_layer.layer = 30
	add_child(_arrival_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = MHStyle.INK_950
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1
		if top: bar.offset_bottom = 104
		else:
			bar.anchor_top = 1
			bar.anchor_bottom = 1
			bar.offset_top = -150
		_arrival_layer.add_child(bar)
	var title := str(mission.get("title", ""))
	var headline := title.get_slice(": ", 1) if title.contains(": ") else title
	var touchdown := "Crew lander · Touchdown · %d crew aboard" % int(mission.get("crew", 4)) if crew_arrival else "Cargo Lander %d · Touchdown · %s payload" % [int(mission.get("cargo_lander", 1)), MHStyle.kg(int(mission.get("payload_kg", 0)))]
	var captions := [["Mission %d complete" % (int(mission.get("number", 2)) - 1), str(mission.get("previous_line", ""))],
		[touchdown, headline]]
	for caption in captions:
		var box := MHStyle.vbox(6)
		box.anchor_top = 1
		box.anchor_bottom = 1
		box.offset_left = 120
		box.offset_top = -330
		box.offset_right = 1500
		box.modulate.a = 0.0
		box.add_child(MHStyle.eyebrow(caption[0], MHStyle.accent, 18))
		box.add_child(MHStyle.display(caption[1], 54))
		_arrival_layer.add_child(box)
		_arrival_caption.append(box)
	var skip := MHStyle.mono("ANY KEY  SKIP", 13, MHStyle.TEXT_MUTED)
	skip.anchor_left = 1; skip.anchor_right = 1; skip.anchor_top = 1; skip.anchor_bottom = 1
	skip.offset_left = -260; skip.offset_top = -92
	_arrival_layer.add_child(skip)
	MHAudio.sfx("landing", 0.0, 0.0)
	_arrival_t = 0.0

## What's landing in the cutscene: the crew lander (Mission 4) or this
## mission's cargo lander.
func _arrival_craft() -> Node3D:
	return lander if crew_arrival else current_cargo_lander

func _update_arrival(delta: float) -> void:
	_arrival_t += delta
	var cargo := _arrival_craft()
	# Descent: fast at first, easing to a gentle touchdown at 7 s.
	var fall := clampf(_arrival_t / 7.0, 0.0, 1.0)
	var height := 90.0 * pow(1.0 - fall, 2.6)
	cargo.global_position = _arrival_from + Vector3.UP * height
	if height < 14.0 and not _arrival_landed: _arrival_dust.emitting = true
	if fall >= 1.0 and not _arrival_landed:
		_arrival_landed = true
		cargo.set_burn(false)
		MHAudio.sfx("land", 0.0, 0.0)
		get_tree().create_timer(1.2).timeout.connect(func() -> void: if _arrival_dust != null: _arrival_dust.emitting = false)
	_arrival_camera.look_at(cargo.global_position + Vector3.UP * 2.0, Vector3.UP)
	# A little shake as the engine nears the ground and at touchdown.
	if fall > .7 and _arrival_t < 7.6:
		_arrival_camera.rotation += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * .004 * (1.0 - absf(_arrival_t - 7.0))
	# Captions: the first fades in and out, then the second holds.
	_fade_caption(_arrival_caption[0], _arrival_t, .6, 3.6)
	_fade_caption(_arrival_caption[1], _arrival_t, 4.4, ARRIVAL_LENGTH)
	if _arrival_t >= ARRIVAL_LENGTH: _finish_arrival()

func _fade_caption(box: Control, t: float, start: float, end: float) -> void:
	box.modulate.a = clampf(minf((t - start) / .5, (end - t) / .5), 0.0, 1.0)

func _finish_arrival() -> void:
	if _arrival_t < 0.0: return
	_arrival_t = -1.0
	var cargo := _arrival_craft()
	cargo.global_position = _arrival_from
	cargo.set_burn(false)
	if _arrival_dust != null:
		_arrival_dust.queue_free()
		_arrival_dust = null
	_arrival_camera.queue_free()
	_arrival_layer.queue_free()
	_arrival_caption.clear()
	var start: Dictionary = lander.cabin_start() if crew_arrival else cargo.hold_start()
	player.global_position = start.position
	player.rotation.y = float(start.yaw)
	player.safe_position = player.global_position
	player.process_mode = Node.PROCESS_MODE_INHERIT
	(player.get_node("Head/Camera3D") as Camera3D).current = true
	explore_hud.visible = true
	if mission_hud != null: mission_hud.visible = true
	arrival_pending = false
	arrival_finished.emit()
	if crew_arrival:
		# The crew lander: you're in the cabin; open the hatch to step out
		# (the lander intro marks the mission arrived once you're out).
		explore_hud.show_equipment_note("Touchdown", "The crew have landed. Look at the hatch and press E to open it.")
		_play_intro()
		return
	MHMissions.set_arrived(str(MHMissions.current().id))
	save_mission_progress()
	_play_intro()

func _land_lander() -> void:
	var saved: Dictionary = MHGame.pending_save_state.get("lander", {})
	if not saved.is_empty():
		lander.place_exact(saved.get("position", Vector3.ZERO) as Vector3, float(saved.get("yaw", 0.0)))
	elif MHMissions.active() and not is_inf(MHMissions.landing_target().x):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		lander.place_at(_clear_touchdown(MHMissions.landing_target(), rng, false))
	elif not MHGame.pending_save_state.is_empty() or is_inf(MHGame.landing_target.x):
		lander.place_on_site()
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var landed: Vector2 = LANDING_PICKER_SCRIPT.touchdown(MHGame.landing_target, MHGame.game_mode, rng)
		_landing_miss = landed.distance_to(MHGame.landing_target)
		lander.place_at(landed)
	MHGame.landing_target = Vector2.INF

func _begin_lander_intro() -> void:
	if not _start_in_lander:
		lander.set_hatch(true)
		return
	_intro_stage = "inside"
	explore_hud.set_minimal(true)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if _intro_stage == "inside":
			explore_hud.show_equipment_note("Touchdown", "You've landed on Mars. When you're ready, look at the hatch and press E to open it."))

func _update_lander_intro() -> void:
	if _intro_stage == "inside" and lander.hatch_open():
		_intro_stage = "open"
	elif _intro_stage == "open" and not lander.cabin_contains(player.global_position):
		_intro_stage = "done"
		explore_hud.set_minimal(false)
		if crew_arrival:
			crew_arrival = false
			MHMissions.set_arrived(str(MHMissions.current().id))
			save_mission_progress()
			explore_hud.show_equipment_note("Mission %d · %s" % [int(MHMissions.current().number), str(MHMissions.current().title)], "You're on Mars. The base your robots built is waiting: follow BASE SITE on your compass to the airlock.")
			return
		var landing := "You touched down %d m from your target: that's the landing ellipse at work. " % roundi(_landing_miss) if _landing_miss >= 1.0 else ""
		explore_hud.show_equipment_note(MHGame.site_name(), landing + "Welcome to Mars. Press B to open the site plan and design your habitat. The lander is always on your compass if you need shelter.")

func _build_landscape() -> void:
	environment = ORIGINAL_ENVIRONMENT_SCRIPT.new()
	environment.build()
	add_child(environment)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(6.0, 1.2, 10.0)
	player.rotation.y = deg_to_rad(-46.0)
	if _start_in_lander:
		var start: Dictionary = lander.cabin_start()
		player.position = start.position
		player.rotation.y = float(start.yaw)
	elif arrival_pending:
		# Missions: the robot rides down in the cargo lander's hold.
		var hold: Dictionary = current_cargo_lander.hold_start()
		player.position = hold.position
		player.rotation.y = float(hold.yaw)
	elif MHMissions.active() and not is_inf(MHMissions.base_site().x):
		# Missions: the robot starts at the base site, facing the landing zone.
		var base := MHMissions.base_site()
		player.position = Vector3(base.x, MHSiteTerrain.height(base.x, base.y) + 1.2, base.y)
		var to_zone := MHMissions.landing_target() - base
		if to_zone.length() > 1.0: player.rotation.y = atan2(-to_zone.x, -to_zone.y)
	player.safe_position = player.position
	add_child(player)
	var camera := player.get_node("Head/Camera3D") as Camera3D
	camera.set_meta("first_person", true)
	# Dust motes drawn only near the camera (cheap on older laptops).
	dust = CPUParticles3D.new()
	dust.name = "NearDust"
	dust.amount = 140
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(10, 3, 10)
	dust.direction = Vector3(1, .1, .3)
	dust.spread = 25.0
	dust.gravity = Vector3(0, -.02, 0)
	dust.initial_velocity_min = .15
	dust.initial_velocity_max = .5
	var mote := QuadMesh.new()
	mote.size = Vector2(.018, .018)
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.albedo_color = Color(MHStyle.DUST_200, .3)
	mote.material = mote_material
	dust.mesh = mote
	player.get_node("Head").add_child(dust)

func _spawn_scout_rover() -> void:

	if not SPAWN_SCOUT_ROVER:
		return
	# Missions: GAR-Y rolls out with the first cargo (Mission 2) to prospect for ice.
	if MHMissions.active() and not bool(MHMissions.current().get("rover", true)):
		return
	var rover_scene := load(SCOUT_ROVER_SCENE_PATH) as PackedScene
	if rover_scene == null:
		push_warning("GAR-Y rover scene is unavailable; continuing without companion.")
		return
	scout_rover = rover_scene.instantiate() as Node3D
	add_child(scout_rover)
	scout_rover.global_position = lander.beside_ramp() if _start_in_lander else player.global_position + player.global_transform.basis.z * 2.4
	scout_rover.call("setup", player)

## The crew rover: a saved one comes back where it was left; otherwise it
## appears in the first vehicle bay, facing the hangar door.
func _sync_crew_rover() -> void:
	if crew_rover != null or builder == null: return
	var bay: Dictionary = {}
	for zone in builder.zones:
		if str(zone.get("kind", "")) == "vehicle_bay": bay = zone
	if bay.is_empty() and _crew_rover_state.is_empty(): return
	crew_rover = CREW_ROVER_SCRIPT.new()
	crew_rover.setup(builder)
	add_child(crew_rover)
	if not _crew_rover_state.is_empty():
		crew_rover.restore_state(_crew_rover_state)
		_crew_rover_state = {}
		return
	var centre := Vector2.ZERO
	for cell in bay.cells: centre += Vector2(cell) * BuildController.CELL
	centre /= float((bay.cells as Array).size())
	var outside: Vector2i = bay.get("door_direction", Vector2i(0, -1))
	crew_rover.global_position = Vector3(centre.x, builder.habitat_base_y + 0.05, centre.y)
	crew_rover.rotation.y = builder._direction_yaw(outside)

func _build_hud() -> void:
	explore_hud = MHExploreHUD.new()
	explore_hud.setup(player, builder)
	add_child(explore_hud)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

func _apply_settings() -> void:
	MHGame.apply_settings(get_viewport(), environment.world_environment.environment, environment.sun, [player.get_node("Head/Camera3D")])
	dust.emitting = bool(MHGame.setting("dust"))
	dust.visible = dust.emitting

# ---------- overlays ----------
func _open_mission_control() -> void:
	if mission_control != null: return
	if pause_menu != null: _close_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	MHAudio.muffle(true)
	mission_control = MHMissionControl.new().setup(builder)
	# The mission panel and its toasts sit on a higher layer: hide them while
	# Mission Control is open.
	if mission_hud != null: mission_hud.visible = false
	mission_control.closed.connect(func() -> void:
		mission_control = null
		if mission_hud != null: mission_hud.visible = true
		_unpause())
	overlay_layer.add_child(mission_control)

## The habitat monitor: live, so the game keeps running while you read it
## (you stand still). From Mission Control's header or the Mission Planning
## Console in the base.
func open_monitor() -> void:
	_open_live_view(HABITAT_MONITOR.new().setup(self))

## The outside cameras, live like the monitor (pressing E on a mast opens it on that mast).
func open_cameras(mast: Node = null) -> void:
	_open_live_view(HABITAT_CAMERAS.new().setup(self, mast))

## A full-screen live view (monitor or cameras): the game keeps running and you stand still.
func _open_live_view(view: Control) -> void:
	if monitor != null:
		view.queue_free()
		return
	if mission_control != null: mission_control._close()
	if pause_menu != null: _close_pause()
	get_tree().paused = false
	MHAudio.muffle(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_meta("ui_freeze", true)
	if mission_hud != null: mission_hud.visible = false
	monitor = view
	monitor.closed.connect(func() -> void:
		monitor = null
		player.set_meta("ui_freeze", false)
		if mission_hud != null: mission_hud.visible = true
		_unpause())
	overlay_layer.add_child(monitor)

func _show_pause() -> void:
	if mission_control != null: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	MHAudio.muffle(true)
	MHAudio.sfx("ui_back", 0.0, 0.0)
	pause_menu = MHPauseMenu.new()
	pause_menu.resumed.connect(_resume)
	pause_menu.mission_control.connect(_open_mission_control)
	pause_menu.settings.connect(_open_settings)
	pause_menu.save_requested.connect(_save_habitat)
	pause_menu.load_requested.connect(_load_habitat)
	pause_menu.exit_to_menu.connect(_return_menu)
	overlay_layer.add_child(pause_menu)

func _open_settings() -> void:
	var panel := MHSettingsPanel.new()
	panel.applied.connect(_apply_settings)
	pause_menu.add_child(panel)

func _close_pause() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null

func _resume() -> void:
	_close_pause()
	_unpause()

func _unpause() -> void:
	get_tree().paused = false
	MHAudio.muffle(false)
	var needs_cursor := builder.build_mode or (interior_builder != null and interior_builder.wants_cursor())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if needs_cursor else Input.MOUSE_MODE_CAPTURED

func _return_menu() -> void:
	get_tree().paused = false
	MHAudio.muffle(false)
	MHAudio.build_layer(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

# ---------- three-slot habitat saves ----------
## Everything a save (or a debug site reload) needs to rebuild this colony.
func current_state() -> Dictionary:
	# Whatever you're carrying goes back first, so it's never lost from a save.
	if carry != null: carry.put_back()
	return {
		"site_id": MHGame.site_id,
		"site_name": MHGame.site_name(),
		"colony_name": MHGame.colony_name,
		"mission_statement": MHGame.mission_statement,
		"emblem": MHGame.emblem,
		"habitat_name": MHGame.habitat_name,
		"accent_index": MHGame.accent_index,
		"game_mode": MHGame.game_mode,
		"builder": builder.export_habitat_state(),
		"lander": {"position": lander.global_position, "yaw": lander.rotation.y},
		"missions_progress": MHMissions.save_state() if MHMissions.active() else {},
		"campaign_record": campaign_record,
		"player_position": player.global_position,
		"player_rotation_y": player.rotation.y,
		"day_night": day_night.export_state() if day_night != null else {},
		"resupply": {"kg": MHGame.resupply_kg, "count": MHGame.resupply_count, "landers": resupply_landers.duplicate(true)},
		"mission_control": earth_link.export_state() if earth_link != null else {},
		"gary": scout_rover.call("export_state") if scout_rover != null and scout_rover.has_method("export_state") else {},
		"crew_rover": crew_rover.export_state() if crew_rover != null else {}
	}

## Missions autosave: the campaign base and its progress (slot 1 of the
## Missions save set).
func save_mission_progress() -> void:
	if MHMissions.active(): MHGame.save_habitat(1, current_state(), "missions")

func _save_habitat(slot: int) -> void:
	if builder == null or player == null:
		return
	var state := current_state()
	# Saving happens from the pause screen, so report the result there (the
	# build HUD is hidden in Explore mode and frozen while paused).
	var saved := MHGame.save_habitat(slot, state) == OK
	MHAudio.sfx("ui_confirm" if saved else "invalid", 0.0, 0.0)
	if pause_menu != null:
		if saved: pause_menu.show_save_status("valid", "Saved %s to slot %d." % [MHGame.colony_name, slot])
		else: pause_menu.show_save_status("invalid", "Save failed: slot %d could not be written." % slot)

func _load_habitat(slot: int) -> void:
	if not MHGame.prepare_habitat_load(slot):
		return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _restore_pending_habitat() -> void:
	if MHGame.pending_save_state.is_empty():
		MHGame.resupply_kg = 0
		MHGame.resupply_count = 0
		return
	var resupply: Dictionary = MHGame.pending_save_state.get("resupply", {})
	MHGame.resupply_kg = int(resupply.get("kg", 0))
	MHGame.resupply_count = int(resupply.get("count", 0))
	for saved in resupply.get("landers", []):
		_add_resupply_lander(saved.position as Vector3, float(saved.yaw), resupply_landers.size() + 1)
		resupply_landers.append(saved)
	var state := MHGame.pending_save_state
	MHGame.pending_save_state = {}
	builder.restore_habitat_state(state.get("builder", {}) as Dictionary)
	_earth_link_state = state.get("mission_control", {}) as Dictionary
	if scout_rover != null and scout_rover.has_method("restore_state"): scout_rover.call("restore_state", state.get("gary", {}) as Dictionary)
	_crew_rover_state = state.get("crew_rover", {}) as Dictionary
	player.global_position = state.get("player_position", player.global_position) as Vector3
	player.rotation.y = float(state.get("player_rotation_y", player.rotation.y))
	player.safe_position = player.global_position
	if day_night != null:
		day_night.restore_state(state.get("day_night", {}) as Dictionary)

# Letterbox bars from the landing screen animate away into first person (360 ms).
func _play_intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var bars := []
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = MHStyle.INK_950
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1
		if top:
			bar.offset_bottom = 104
		else:
			bar.anchor_top = 1
			bar.anchor_bottom = 1
			bar.offset_top = -150
		layer.add_child(bar)
		bars.append(bar)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bars[0], "position:y", -110.0, .36).set_delay(.35)
	tween.tween_property(bars[1], "position:y", get_viewport().get_visible_rect().size.y + 10.0, .36).set_delay(.35)
	tween.chain().tween_callback(layer.queue_free)
