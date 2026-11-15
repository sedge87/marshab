extends SceneTree

# The 15 Nov playtest fixes that stand alone (docs/opening-days.md, "After the
# 15 Nov playtest"):
# - the orbiter shows only at twilight, rising west and fading before the east,
#   on some sols and not others (scripts/orbiter_sky.gd);
# - the lope breathes harder than a walk even in full flow (scripts/suit.gd);
# - the descent checks the lander's footprint, not a base pad (scripts/descent.gd).
# godot --headless --path . --script res://tests/orbiter_sky_test.gd

const SKY := preload("res://scripts/orbiter_sky.gd")
const SUIT := preload("res://scripts/suit.gd")
const DESCENT := preload("res://scripts/descent.gd")

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region_plains"
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	# Never by day, never in the deep night.
	for hour in [sunrise + 1.0, 12.0, sunset - .5, sunset + 3.0, 0.0]:
		for sol in 6:
			_check(SKY.pass_progress(hour, sol) < 0.0, "no orbiter at %.1f h on sol %d" % [hour, sol])
	# A dusk pass on most sols, not all.
	var dusk := sunset + SKY.DUSK_AFTER + SKY.PASS_HOURS * .4
	var seen := 0
	for sol in 6:
		if SKY.pass_progress(dusk, sol) >= 0.0: seen += 1
	_check(seen >= 3 and seen < 6, "a dusk pass on some sols, not all (%d of 6)" % seen)
	# West to east, up in the sky, fading at both ends.
	_check(SKY.direction(0.0).x < -.5 and SKY.direction(1.0).x > .5, "it rises in the west and goes east")
	_check(SKY.direction(.5).y > .6, "high overhead mid-pass")
	_check(SKY.brightness(0.0) == 0.0 and SKY.brightness(.4) > .9 and SKY.brightness(.97) == 0.0, "it fades in and slides into shadow")
	# The lope costs air, even in rhythm.
	_check(SUIT.LOPE > SUIT.LOPE_FLOW and SUIT.LOPE_FLOW > 1.0, "the lope breathes harder than a walk, even in full flow (%.1f, %.1f)" % [SUIT.LOPE, SUIT.LOPE_FLOW])
	# The lander's footprint.
	_check(DESCENT.LANDER_HALF < 30.0, "the descent checks the lander's footprint (%.0f m), not a base pad" % DESCENT.LANDER_HALF)
	print("orbiter_sky_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
