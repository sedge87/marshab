extends SceneTree

# The lander cabin on the new survival core, in the game world
# (scripts/lander_cabin_life.gd, body.gd; docs/systems-and-items.md §14 step 1):
# - the three wall switches and what they do to the cabin's lights;
# - the clock runs the cabin, with you breathing in it;
# - the alerts engine shows the cabin's alerts, and the slate's Base app shows
#   its gauges;
# - you can sleep in a landing seat;
# - the body: cold shows and slows you, and the comfort setting tones the cues;
# - collapse and coming round; saving.
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	var cabin = world.cabin_life
	_check(cabin != null and cabin.running(), "the world runs the lander cabin on the new core")
	_check(cabin.switches.size() == 3 and cabin.switches.values().all(func(s): return s.get_parent() == world.lander), "three switches on the cabin wall")
	var player: Node3D = world.player
	player.global_position = world.lander.to_global(Vector3(0, world.lander.DECK + .9, .3))
	for i in 3: await process_frame
	_check(cabin.player_inside(), "you're in the cabin")

	# The switches.
	var lights: Array = world.lander.cabin_lights
	var lit_energy := float((lights[0] as Light3D).light_energy)
	cabin.switches.lights.interact()
	for i in 2: await process_frame
	_check(not cabin.core.lights_on and is_zero_approx((lights[0] as Light3D).light_energy), "the lights switch goes dark (was %.2f)" % lit_energy)
	cabin.switches.lights.interact()
	var heater_prompt: Dictionary = cabin.switches.heater.interaction_prompt()
	_check(str(heater_prompt.label).begins_with("Cabin heater") and str(heater_prompt.primary) == "Set to Low", "the heater's prompt (%s)" % str(heater_prompt))
	cabin.switches.heater.interact()
	_check(cabin.core.heater_mode == "low", "E sets the heater to Low")
	cabin.core.heater_mode = "warm"
	cabin.core.battery_kwh = 0.0
	for i in 2: await process_frame
	_check(world.lander.get_node("CabinEmergencyLight").visible and is_zero_approx((lights[0] as Light3D).light_energy), "a flat battery: lights out, a red emergency glow")
	cabin.core.battery_kwh = cabin.core.battery_cap

	# The clock runs it, with you breathing.
	var co2_before: float = cabin.core.co2_pct()
	cabin.core.scrubber_on = false
	world.get_tree().call_group("survival_core", "advance", 2.0, 21.0)
	_check(is_equal_approx(cabin.core.people, 1.0) and cabin.core.co2_pct() > co2_before, "two hours pass: you breathe the cabin's air (CO₂ %.2f → %.2f%%)" % [co2_before, cabin.core.co2_pct()])
	cabin.core.scrubber_on = true

	# Alerts and the Base app.
	cabin.core.temp_c = 8.0
	var ids: Array = world.alerts.evaluate().map(func(a): return str(a.id))
	_check(ids.has("cabin_cold"), "the alerts engine has the cabin's alerts (%s)" % str(ids))
	var rows: Dictionary = world.pda.screen._cabin_rows(cabin)
	_check(rows.has("battery") and rows.has("warmth") and rows.has("air") and str(rows.warmth.text).begins_with("8 °C"), "the slate's Base app shows the cabin's gauges (%s)" % str(rows.warmth))

	# Sleep in a landing seat.
	_check(world.sleep.blocked_reason() == "", "you can sleep in the cabin (%s)" % world.sleep.blocked_reason())
	_check(world.lander.get_node("Cabin_landing_seat_1").get_meta("interaction_target", null) == cabin and str(cabin.interaction_prompt().get("sleep", "")) == "Sleep", "a landing seat offers Z to sleep")

	# The body: cold shows, slows you and is toned by the comfort setting.
	var body = world.body
	cabin.core.temp_c = -2.0
	for i in 90: await process_frame
	_check(body.cold > .3 and float(player.get_meta("body_speed", 1.0)) < .95, "cold shows and slows you (cold %.2f, speed %.2f)" % [body.cold, float(player.get_meta("body_speed", 1.0))])
	_check(body._veil.visible, "the frosted edge is on screen")
	var keep := str(MHGame.setting("body_cues"))
	var values := MHGame.settings(); values["body_cues"] = "low"; MHGame.save_settings(values)
	_check(is_equal_approx(body.comfort(), .3), "the comfort setting tones the cues down")
	values["body_cues"] = keep; MHGame.save_settings(values)
	_check(body.causes.has("cold"), "below freezing, the cold is hurting you (%s)" % str(body.causes))

	# Collapse and coming round.
	body.health = 0.0
	body._collapse()
	_check(body.collapsed and bool(player.get_meta("ui_freeze", false)), "at zero health you collapse")
	body._out_for = body.COLLAPSE_HOURS
	MHGame.sol_hour = fposmod(MHGame.sol_hour + .1, 24.0)
	for i in 3: await process_frame
	_check(not body.collapsed and is_equal_approx(body.health, body.WAKE_HEALTH) and not bool(player.get_meta("ui_freeze", false)), "hours later you come round, weak (%.0f)" % body.health)
	world.day_night.time_scale = 1.0

	# Saving.
	var state: Dictionary = world.current_state()
	_check(state.has("cabin") and is_equal_approx(float(state.cabin.temp_c), cabin.core.temp_c) and state.has("body"), "the cabin and your health are saved")
	if failures == 0:
		print("Cabin night test passed: the switches and lights, a flat battery's emergency glow, the clock running the cabin as you breathe, its alerts and Base gauges, sleeping in a landing seat, cold showing and slowing you, the comfort setting, collapse and coming round, and saving.")
	quit(1 if failures > 0 else 0)
