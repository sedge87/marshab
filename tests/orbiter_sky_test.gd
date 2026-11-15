extends SceneTree

# The 15 Nov playtest fixes that stand alone (docs/opening-days.md, "After the
# 15 Nov playtest"):
# - the ship in its one-sol orbit: a dive at every dusk, fading into shadow
#   before it goes behind Mars, then a faint high star till dawn (scripts/orbiter_sky.gd);
# - the lope breathes harder than a walk even in full flow (scripts/suit.gd);
# - the descent checks the lander's footprint, not a base pad (scripts/descent.gd).
# godot --headless --path . --script res://tests/orbiter_sky_test.gd

const SKY := preload("res://scripts/orbiter_sky.gd")
const SUIT := preload("res://scripts/suit.gd")
const DESCENT := preload("res://scripts/descent.gd")
const RADIO := preload("res://scripts/radio.gd")

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
	# The one-sol orbit: never by day, never while it's behind the planet.
	var los: Vector2 = RADIO.los_window()
	for hour in [sunrise + 1.0, 12.0, sunset - .5, sunset + .2, los.x + .5, los.y - .1]:
		_check(SKY.pass_progress(hour) < 0.0 and SKY.high_progress(hour) < 0.0, "nothing in the sky at %.1f h" % hour)
	# Every dusk, the dive: high in the south-west, falling to the east, gone
	# into shadow before she goes behind the planet.
	var dusk := sunset + SKY.DUSK_AFTER + .1
	_check(SKY.pass_progress(dusk) >= 0.0, "every dusk, the dive (%.2f h)" % dusk)
	_check(SKY.pass_progress(los.x - .02) < 0.0, "in shadow before it goes behind Mars")
	_check(SKY.direction(0.0).x < 0.0 and SKY.direction(0.0).y > .7 and SKY.direction(1.0).x > .8 and SKY.direction(1.0).y < .2, "it falls from high in the south-west to low in the east")
	_check(SKY.brightness(0.0) == 0.0 and SKY.brightness(.4) > .9 and SKY.brightness(1.0) == 0.0, "it brightens as the sky darkens, then fades into shadow")
	# Back round: a faint high star through the night, gone by dawn.
	_check(SKY.high_progress(los.y + SKY.HIGH_AFTER + .5) >= 0.0 and SKY.high_progress(2.0) >= 0.0, "back round: the high star in the night")
	_check(SKY.high_progress(sunrise - .3) < 0.0, "the dawn sky washes it out")
	_check(SKY.high_direction(1.0).y > SKY.high_direction(0.0).y, "it climbs through the night")
	# The lope costs air, even in rhythm.
	_check(SUIT.LOPE > SUIT.LOPE_FLOW and SUIT.LOPE_FLOW > 1.0, "the lope breathes harder than a walk, even in full flow (%.1f, %.1f)" % [SUIT.LOPE, SUIT.LOPE_FLOW])
	# The lander's footprint.
	_check(DESCENT.LANDER_HALF < 30.0, "the descent checks the lander's footprint (%.0f m), not a base pad" % DESCENT.LANDER_HALF)
	print("orbiter_sky_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
