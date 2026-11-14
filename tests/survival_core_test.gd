extends SceneTree

# The new survival core (scripts/survival_core.gd, docs/systems-and-items.md
# §14 step 1), on its own: a night in the General Module (the base; the
# lander has looked after itself since 8 Nov) is a real choice.
# - Everything on, without pallet 2's blanket: the battery runs out in the
#   night, but nothing kills you (how it fails: tests/hab_supply_test.gd).
# Also the runway (it predicts when the battery runs out), the alerts, the
# 30-minute sol, the suit's 8 hours and saving.

const CORE := preload("res://scripts/survival_core.gd")
const BODY := preload("res://scripts/body.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

## A night from sunset (19:00) to 08:00 the next morning; returns the core and
## when (hours after sunset) the battery ran out, or -1.
func _night(setup: Callable) -> Array:
	var core = CORE.new("module")
	setup.call(core)
	var flat := -1.0
	var lowest := 99.0
	var worst_co2 := 0.0
	var lost := 0.0
	var hour := 19.0
	for i in 68:   # to noon
		core.advance(.25, hour)
		lost += maxf(0.0, float(BODY.harm_for(core.conditions()).rate)) * .25
		hour = wrapf(hour + .25, 0.0, 24.0)
		if flat < 0.0 and not core.powered(): flat = (i + 1) * .25
		lowest = minf(lowest, core.temp_c)
		worst_co2 = maxf(worst_co2, core.co2_pct())
	return [core, flat, lowest, worst_co2, lost]

func _initialize() -> void:
	MHGame.site_id = "region"
	# Everything on, heater warm.
	var all_on := _night(func(c): pass)
	var flat_at := float(all_on[1])
	print("all on: flat after %.2f h, coldest %.1f C, worst CO2 %.2f%%, health lost %.1f" % [flat_at, all_on[2], all_on[3], all_on[4]])
	_check(flat_at > 3.0 and flat_at < 9.5, "everything on: the battery runs out in the night (%.2f h after sunset)" % flat_at)
	_check(float(all_on[4]) < 40.0, "but it's nowhere near killing you (%.1f health)" % float(all_on[4]))
	_check((all_on[0] as RefCounted).powered() and (all_on[0] as RefCounted).temp_c > 12.0, "by noon the sun has the cabin powered and warm again")
	# Heater off: the battery lasts; cold, fresh air.
	var no_heat := _night(func(c): c.heater_mode = "off")
	print("heater off: flat %.2f, coldest %.1f C, worst CO2 %.2f%%, health lost %.1f" % [no_heat[1], no_heat[2], no_heat[3], no_heat[4]])
	_check(float(no_heat[2]) <= float(all_on[2]) + .5, "heater off is no warmer (%.1f °C)" % float(no_heat[2]))
	_check(float(no_heat[3]) < .3, "and the scrubber keeps the air fresh (%.2f%%)" % float(no_heat[3]))
	# Heater low: in between.
	var low := _night(func(c): c.heater_mode = "low")
	print("heater low: flat %.2f, coldest %.1f C, health lost %.1f" % [low[1], low[2], low[4]])
	# Scrubber off all night (heater off too, to keep the power).
	var stale := _night(func(c): c.scrubber_on = false; c.heater_mode = "off")
	print("scrubber off: worst CO2 %.2f%%" % stale[3])
	# The runway: predicted at sunset, everything on.
	var fresh = CORE.new("module")
	var ahead: Dictionary = fresh.runway(19.0)
	_check(absf(float(ahead.power) - flat_at) <= .5, "the runway predicts the battery running out (%.2f h vs %.2f h)" % [float(ahead.power), flat_at])
	# The alerts engine.
	var dark = all_on[0]
	dark.battery_kwh = 0.0
	dark.temp_c = 8.0
	var ids: Array = dark.alerts().map(func(a): return str(a.id))
	_check(ids.has("module_power") and ids.has("module_cold"), "a flat battery and a cold cabin raise their alerts (%s)" % str(ids))
	dark.co2_kg = dark.air_kg * .035 / dark.CO2_VOL
	var co2_alert: Array = dark.alerts().filter(func(a): return str(a.id) == "module_co2")
	_check(not co2_alert.is_empty() and str(co2_alert[0].level) == "critical", "3.5% CO₂ is critical")
	_check(float(BODY.harm_for(dark.conditions()).rate) > 0.0, "and it harms you")
	# Suit refills draw on the cabin.
	var tank: float = fresh.tank_o2_kg
	_check(is_equal_approx(fresh.take_oxygen(.2), .2) and is_equal_approx(fresh.tank_o2_kg, tank - .2), "a suit refill takes oxygen from the cabin tank")
	# Saving.
	var copy = CORE.new("module")
	copy.load_state(dark.export_state())
	_check(is_equal_approx(copy.temp_c, dark.temp_c) and is_equal_approx(copy.co2_kg, dark.co2_kg) and copy.heater_mode == dark.heater_mode, "the cabin saves and loads")
	# The clock and the suit.
	_check(is_equal_approx(MHGame.daylight_minutes() + MHGame.night_minutes(), 30.0) and is_equal_approx(MHGame.daylight_minutes(), 22.0), "a sol is 30 real minutes, 22 of daylight")
	_check(is_equal_approx(preload("res://scripts/suit.gd").O2_HOURS, 8.0), "the suit holds 8 game hours of oxygen")
	if failures == 0:
		print("Survival core test passed: the module runs its battery flat in a heated night without the blanket, nothing in it kills, the runway, the alerts, suit refills, saving, the 30-minute sol and the 8-hour suit.")
	quit(1 if failures > 0 else 0)
