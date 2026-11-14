extends SceneTree

# The habitat's supply (docs/hab-supply.md; scripts/survival_core.gd):
# - with the power out, the module gets cold first (about a quarter of a sol),
#   then the air you breathe goes stale (harmful about half a sol in), because
#   with the fans off your breath pools round you;
# - nothing happens at once: never harmful in the first few hours;
# - power back, the pocket clears; nobody inside, no pocket;
# - saved and loaded.
# godot --headless --path . --script res://tests/hab_supply_test.gd
const CORE := preload("res://scripts/survival_core.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _flat_module() -> RefCounted:
	var c = CORE.new("module")
	c.heater_mode = "low"
	c.temp_c = 12.0
	c.battery_kwh = 0.0
	return c

func _initialize() -> void:
	var c := _flat_module()
	var h := 0.0
	var cold_at := -1.0
	var stale_at := -1.0
	var harm_at := -1.0
	while h < 30.0:
		c.step(.05, -60.0, 0.0)
		h += .05
		var co2 := float(c.conditions().co2_pct)
		if cold_at < 0.0 and c.temp_c < 0.0: cold_at = h
		if stale_at < 0.0 and co2 >= 1.0: stale_at = h
		if harm_at < 0.0 and co2 >= 3.0: harm_at = h
	_check(cold_at > 4.0 and cold_at < 9.0, "cold in about a quarter of a sol (got %.1f h)" % cold_at)
	_check(harm_at > 9.0 and harm_at < 15.0, "harmful stale air about half a sol in (got %.1f h)" % harm_at)
	_check(cold_at < harm_at, "cold comes before the air turns harmful")
	_check(stale_at > 2.0, "nothing stale in the first two hours (got %.1f h)" % stale_at)
	_check(not c.alerts().filter(func(a): return str(a.id) == "module_co2").is_empty(), "the stale-air alert sounds")
	# Power back: the fans clear the pocket.
	c.battery_kwh = c.battery_cap
	for i in 40: c.step(.05, -60.0, 0.0)
	_check(float(c.still_co2_pct) < .5, "power back, the pocket clears")
	# Nobody inside: no pocket.
	var empty := _flat_module()
	empty.people = 0.0
	for i in 200: empty.step(.05, -60.0, 0.0)
	_check(float(empty.still_co2_pct) == 0.0, "nobody inside, no pocket")
	# Saved and loaded.
	var a := _flat_module()
	for i in 100: a.step(.05, -60.0, 0.0)
	var b = CORE.new("module")
	b.load_state(a.export_state())
	_check(is_equal_approx(float(b.still_co2_pct), float(a.still_co2_pct)), "the pocket is saved")
	print("hab_supply_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
