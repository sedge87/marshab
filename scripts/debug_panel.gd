extends CanvasLayer

# Hidden testing tools, opened in a colony with Ctrl+Shift+F12 (and closed the
# same way). Cheats last for this session only and are never saved. Once the
# panel has been opened, N toggles fly/noclip, and while flying T teleports to
# where you look (T alone raises the wrist pad).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SPEEDS := {"×1": 1.0, "×10": 10.0, "×60": 60.0}

var world
var _panel: PanelContainer
var _info: Label
var _hour: Label
var _fly_button: Button
var _cargo_button: Button
var _power_button: Button
var _freeze_button: Button
var _suit_button: Button

func setup(target_world) -> void:
	world = target_world

func _ready() -> void:
	name = "DebugPanel"
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = MHStyle.hud_panel(18, true)
	_panel.anchor_left = 1
	_panel.anchor_right = 1
	_panel.offset_left = -500
	_panel.offset_right = -24
	_panel.offset_top = 120
	_panel.theme = MHStyle.theme()
	add_child(_panel)
	var col := MHStyle.vbox(10)
	_panel.add_child(col)
	var head := MHStyle.hbox(8)
	head.add_child(MHStyle.title("Debug tools", 22))
	head.add_child(MHStyle.spacer())
	head.add_child(MHStyle.mono("Ctrl+Shift+F12", 12, MHStyle.TEXT_MUTED))
	col.add_child(head)
	col.add_child(MHStyle.body("For testing only. Nothing here is saved.", 13, MHStyle.TEXT_MUTED))

	col.add_child(MHStyle.eyebrow("Cheats", MHStyle.accent))
	_fly_button = _toggle_row(col, "Fly / noclip  [N; T flies you where you look]", _set_fly)
	_cargo_button = _toggle_row(col, "Unlimited cargo", func(on: bool) -> void: MHGame.debug_unlimited_cargo = on; _refresh_builder())
	_power_button = _toggle_row(col, "Free power (grid always online)", func(on: bool) -> void: MHGame.debug_free_power = on; world.builder.refresh_power_grid())

	col.add_child(MHStyle.eyebrow("Stuck? Get home safe", MHStyle.accent))
	_suit_button = _toggle_row(col, "Suit never runs out", func(on: bool) -> void: MHGame.debug_suit_never_runs_out = on)
	var safe := _flow()
	for spec in [["Refill suit", _refill_suit], ["To the airlock", _teleport_to_airlock], ["To the lander", _teleport_to_lander],
			["Rover to me", _rover_to_me], ["Rover home (refilled)", _rover_home], ["Refill rover", _refill_rover]]:
		var b := _small_button(spec[0])
		b.pressed.connect(spec[1])
		safe.add_child(b)
	col.add_child(safe)

	# Challenge options, either way (the save is marked "debug").
	col.add_child(MHStyle.eyebrow("Challenge (either way; marks the save)", MHStyle.accent))
	var challenge := _flow()
	for level in MHGame.SURPRISE_LEVELS:
		var b := _small_button("Surprises %s" % str(MHGame.SURPRISE_LABELS[level]))
		b.pressed.connect(func() -> void: MHGame.debug_set_challenge("surprises", level); world.configure_life())
		challenge.add_child(b)
	for option in MHGame.CHALLENGE_SWITCHES:
		var b := _small_button("Flip %s" % str(MHGame.CHALLENGE_LABELS[option]).to_lower())
		b.pressed.connect(func() -> void: MHGame.debug_set_challenge(option, not bool(MHGame.challenge.get(option, false))); world.configure_life())
		challenge.add_child(b)
	col.add_child(challenge)

	col.add_child(MHStyle.eyebrow("Time", MHStyle.accent))
	_hour = MHStyle.mono("", 14)
	col.add_child(_hour)
	var jumps := _flow()
	for spec in [["Dawn", "dawn_hour"], ["Noon", ""], ["Dusk", "dusk_hour"], ["Night", "night"]]:
		var jump := _small_button(spec[0])
		jump.pressed.connect(_jump_time.bind(spec[1]))
		jumps.add_child(jump)
	for step in [-1.0, 1.0]:
		var nudge := _small_button("%+dh" % int(step))
		nudge.pressed.connect(func() -> void: world.day_night.set_hour(world.day_night.hour + step))
		jumps.add_child(nudge)
	col.add_child(jumps)
	var speed_row := MHStyle.hbox(8)
	var speed := MHWidgets.Segmented.new().setup(SPEEDS.keys(), "×1", 36)
	speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed.changed.connect(func(value: String) -> void: world.day_night.time_scale = float(SPEEDS[value]))
	speed_row.add_child(speed)
	_freeze_button = _toggle_button("Freeze", func(on: bool) -> void: world.day_night.frozen = on)
	speed_row.add_child(_freeze_button)
	col.add_child(speed_row)

	col.add_child(MHStyle.eyebrow("Weather", MHStyle.accent))
	var weather := _flow()
	for spec in [["Forecast storm (1 h)", _weather.bind("forecast")], ["Dust storm now", _weather.bind("storm")], ["Clear sky", _weather.bind("clear")]]:
		var w := _small_button(spec[0])
		w.pressed.connect(spec[1])
		weather.add_child(w)
	col.add_child(weather)

	col.add_child(MHStyle.eyebrow("GAR-Y", MHStyle.accent))
	var gary := _flow()
	for spec in [["Survey now", "start_survey"], ["Move clutter", "start_fetch"], ["Nudge plush", "start_plush"], ["Dock", "_start_charge"], ["Nap", "_nap"]]:
		var g := _small_button(spec[0])
		g.pressed.connect(func() -> void:
			var rover = world.scout_rover
			if rover == null: return
			if spec[1] != "_nap" and not bool(rover.call(spec[1])): _info.text = "GAR-Y: nothing to do for that here (no odds and ends, plush or GAR-Y dock in its room, or it's outside)."
			elif spec[1] == "_nap": rover.call("_nap"))
		gary.add_child(g)
	col.add_child(gary)

	col.add_child(MHStyle.eyebrow("Teleport", MHStyle.accent))
	var teleports := _flow()
	for spec in [["Where I look  [T]", _teleport_to_look], ["Habitat", _teleport_to_habitat], ["Spawn", _teleport_to_spawn]]:
		var go := _small_button(spec[0])
		go.pressed.connect(spec[1])
		teleports.add_child(go)
	col.add_child(teleports)

	col.add_child(MHStyle.eyebrow("Reload this colony at another site", MHStyle.accent))
	var sites := _flow()
	for entry in MHGame.sites():
		var site_button := _small_button(str(entry.name).split(" ")[0])
		site_button.tooltip_text = str(entry.name)
		site_button.disabled = str(entry.id) == MHGame.site_id
		site_button.pressed.connect(_reload_at_site.bind(str(entry.id)))
		sites.add_child(site_button)
	col.add_child(sites)

	_info = MHStyle.mono("", 12, MHStyle.TEXT_SECONDARY)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info)
	_sync_buttons()
	_show(true)

func toggle() -> void:
	_show(not visible)

func _show(open: bool) -> void:
	visible = open
	# The panel needs a free cursor; closing returns to whatever the game uses.
	if open: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not world.builder.build_mode: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.ctrl_pressed or event.shift_pressed: return
	if event.keycode == KEY_N:
		_set_fly(not bool(world.player.get_meta("debug_fly", false)))
		_sync_buttons()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T and not world.builder.build_mode and bool(world.player.get_meta("debug_fly", false)):
		_teleport_to_look()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible: return
	var hour: float = world.day_night.hour
	_hour.text = "Sol %s · solar %d%% · %s" % [MHGame.formatted_sol_time(), roundi(MHGame.solar_irradiance(hour) * 100.0), "frozen" if world.day_night.frozen else "×%s" % world.day_night.time_scale]
	var systems: Dictionary = world.builder._systems()
	var at: Vector3 = world.player.global_position
	_info.text = "%d fps · (%.1f, %.1f, %.1f) · %s · power %.1f / %.1f kW (heating %.1f) · cargo %s" % [Engine.get_frames_per_second(), at.x, at.y, at.z, MHGame.site_name(), float(world.builder.simulation().last.get("generation_kw", 0.0)), float(world.builder.simulation().last.get("demand_kw", 0.0)), float(world.builder.simulation().last.get("heat_pump_kw", 0.0)), MHStyle.kg(world.builder.used_cargo())]

# ---------- actions ----------

func _set_fly(on: bool) -> void:
	world.player.set_debug_fly(on)

func _jump_time(cycle_key: String) -> void:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var hour := 12.0
	if cycle_key == "night": hour = 0.5
	elif not cycle_key.is_empty(): hour = float(cycle.get(cycle_key, 12.0)) + (.5 if cycle_key == "dawn_hour" else -.5)
	world.day_night.set_hour(hour)

## Try the weather without waiting for one: a forecast an hour out, a full
## storm straight away (haze at full strength at once), or a clear sky.
func _weather(kind: String) -> void:
	var sim = world.builder.simulation()
	match kind:
		"forecast":
			sim.storm_hours_left = 0.0
			sim.forecast_storm(1.0)
		"storm":
			sim.start_storm(1.0)
			if world.weather != null: world.weather._level = 1.0
		"clear":
			sim.storm_hours_left = 0.0
			sim.storm_eta_hours = -1.0
	world.builder.refresh_power_grid()

func _teleport(to: Vector3) -> void:
	world.player.global_position = to
	world.player.velocity = Vector3.ZERO
	world.player.safe_position = to

func _teleport_to_look() -> void:
	var camera := world.player.get_node("Head/Camera3D") as Camera3D
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_transform.basis.z * 300.0)
	query.exclude = [world.player.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	_teleport(hit.position + (hit.normal as Vector3) * .6 + Vector3.UP * .2)

func _teleport_to_habitat() -> void:
	var builder: BuildController = world.builder
	if builder.zones.is_empty(): return
	var zone: Dictionary = builder.zones[0]
	var middle := Vector2.ZERO
	var outline := builder.zone_outline(zone)
	if outline.is_empty():
		for cell in zone.get("cells", []): middle += Vector2(cell.x * 3.0, cell.y * 3.0)
		middle /= maxf(1.0, float((zone.get("cells", []) as Array).size()))
	else:
		middle = builder._outline_centroid(outline)
	_teleport(Vector3(middle.x, builder.habitat_base_y + .3, middle.y))

## The first airlock, facing in (where the suit tops up), else the habitat.
func _teleport_to_airlock() -> void:
	if not world.builder.zones.any(func(z): return str(z.get("kind", "")) == "airlock"):
		_info.text = "No airlock yet: sent to the lander cabin instead."
		_teleport_to_lander()
		return
	_out_of_rover()
	for zone in world.builder.zones:
		if str(zone.get("kind", "")) != "airlock": continue
		var centre := Vector2.ZERO
		for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
		centre /= float((zone.cells as Array).size())
		var out := Vector2(zone.get("door_direction", Vector2i(0, -1)))
		_teleport(Vector3(centre.x, world.builder.habitat_base_y + .3, centre.y))
		world.player.rotation.y = atan2(out.x, out.y)   # facing in, away from the outer door
		return

func _teleport_to_lander() -> void:
	if world.lander == null or not world.lander.present:
		_info.text = "There's no lander on site."
		return
	_out_of_rover()
	var spot: Dictionary = world.lander.cabin_start()
	_teleport(spot.position)
	world.player.rotation.y = float(spot.yaw)

func _refill_suit() -> void:
	var suit: Node = world.get("suit")
	if suit == null: return
	suit.debug_refill()
	_info.text = "Suit full: oxygen, battery and scrubber, seals mended."

func _rover() -> Node:
	var rover: Node = world.get("crew_rover")
	if rover == null: _info.text = "There's no crew rover yet: it comes with a vehicle bay."
	return rover

## Get out of the rover first, so a teleport doesn't leave you seated in it.
func _out_of_rover() -> void:
	var rover: Node = world.get("crew_rover")
	if rover != null and bool(rover.driving): rover._get_out()

func _rover_to_me() -> void:
	var rover: Node = _rover()
	if rover == null: return
	if bool(rover.driving):
		_info.text = "You're driving it."
		return
	var player: Node3D = world.player
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > .01 else Vector3.FORWARD
	for distance in [6.0, 9.0, 13.0]:
		for turn in [0.0, .6, -.6, 1.2, -1.2, PI]:
			var at: Vector3 = player.global_position + forward.rotated(Vector3.UP, turn) * distance
			if rover.set_down_at(at, player.rotation.y):
				_info.text = "Rover parked %d m from you." % roundi(distance)
				return
	_info.text = "No open ground near you for the rover. Try somewhere flatter."

func _rover_home() -> void:
	var rover: Node = _rover()
	if rover == null: return
	_out_of_rover()
	_info.text = "Rover parked in the vehicle bay, charged and full of oxygen." if rover.park_at_home() else "No vehicle bay to park it in."

func _refill_rover() -> void:
	var rover: Node = _rover()
	if rover == null: return
	rover.refill()
	_info.text = "Rover battery, reserve and oxygen tank full."

func _teleport_to_spawn() -> void:
	_teleport(Vector3(6.0, MHSiteTerrain.height(6.0, 10.0) + 1.2, 10.0))

func _reload_at_site(site_id: String) -> void:
	MHGame.pending_save_state = world.current_state()
	MHGame.site_id = site_id
	get_tree().paused = false
	get_tree().reload_current_scene()

func _refresh_builder() -> void:
	world.builder._update_budget()
	world.builder.refresh_power_grid()

# ---------- widgets ----------

## A row of buttons that wraps onto further lines inside the panel.
func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	return flow

func _small_button(text: String) -> Button:
	var b := MHStyle.button(text, "secondary", "", 36)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _toggle_button(text: String, on_change: Callable) -> Button:
	var b := MHStyle.button(text, "ghost", "", 36)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.toggled.connect(func(on: bool) -> void:
		b.theme_type_variation = "SelectedButton" if on else "GhostButton"
		on_change.call(on))
	return b

func _toggle_row(parent: Control, text: String, on_change: Callable) -> Button:
	var b := _toggle_button(text, on_change)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	return b

func _sync_buttons() -> void:
	for pair in [[_fly_button, bool(world.player.get_meta("debug_fly", false))], [_cargo_button, MHGame.debug_unlimited_cargo], [_power_button, MHGame.debug_free_power], [_freeze_button, world.day_night.frozen], [_suit_button, MHGame.debug_suit_never_runs_out]]:
		var b: Button = pair[0]
		b.set_pressed_no_signal(pair[1])
		b.theme_type_variation = "SelectedButton" if pair[1] else "GhostButton"

