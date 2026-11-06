extends SceneTree

const HABITAT_LIFE := preload("res://scripts/habitat_life.gd")
const CHALLENGE_UI := preload("res://scripts/challenge_options_ui.gd")

# Challenge options (docs/new-game-options.md): defaults, the one-way rule in
# a game, which modes offer what, old saves loading as they played, saving
# and loading, the debug mark, and the sim following surprises and radiation.
# Run with: godot --headless --path . --script res://tests/challenge_options_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.game_mode = "survival"
	MHGame.challenge = MHGame.default_challenge()
	_check(str(MHGame.challenge.surprises) == "rare" and not MHGame.challenge.radiation and not MHGame.challenge.injuries and not MHGame.challenge.fatigue, "a new game starts on Rare surprises, the rest off")
	_check(MHGame.surprise_scale() == 0.5, "Rare halves today's rates")
	_check(MHGame.challenge_options() == ["surprises", "wear", "radiation", "injuries"], "Survival offers surprises, wear, radiation and injuries (fatigue hidden until built)")

	# The one-way rule.
	_check(MHGame.raise_challenge("radiation", true) and MHGame.challenge_on("radiation"), "radiation can be switched on")
	_check(not MHGame.raise_challenge("radiation", false) and MHGame.challenge_on("radiation"), "and never off again")
	_check(MHGame.raise_challenge("surprises", "often") and MHGame.surprise_scale() == 2.0, "surprises can go up")
	_check(not MHGame.raise_challenge("surprises", "usual") and str(MHGame.challenge.surprises) == "often", "and never down")
	_check(not MHGame.raise_challenge("fatigue", true), "fatigue can't be switched on until it's built")

	# Modes.
	MHGame.game_mode = "freedom"
	_check(MHGame.challenge_options() == ["surprises", "wear", "radiation", "injuries"], "Freedom offers every option (shortages hurt there too)")
	_check(MHGame.raise_challenge("wear", 1.5) and not MHGame.raise_challenge("wear", 1.0) and is_equal_approx(float(MHGame.challenge.wear), 1.5), "in a game, wear can go faster but not slower")
	MHGame.challenge.wear = 1.0
	MHGame.set_mode("custom")
	MHGame.rules.harm = false
	_check(MHGame.challenge.radiation and not MHGame.challenge_on("radiation") and MHGame.challenge_options() == ["surprises", "wear"], "with harm off (Custom) nothing hurts, whatever was set, and only surprises and wear are offered")
	MHGame.set_mode("freedom")
	MHGame.game_mode = "creative"
	_check(MHGame.challenge_options().is_empty() and MHGame.surprise_scale() == 0.0, "Creative has no options and no surprises")
	_check(CHALLENGE_UI.build(true) == null, "and shows no Challenge rows")
	MHGame.game_mode = "survival"
	var rows := CHALLENGE_UI.build(true)
	_check(rows != null and rows.get_child_count() == 4, "Survival's pause sheet shows four rows")
	rows.free()

	# Saving, loading and the debug mark.
	var saved := MHGame.export_challenge()
	MHGame.challenge = MHGame.default_challenge()
	MHGame.prepare_state_load({"game_mode": "survival", "challenge": saved})
	_check(MHGame.challenge.radiation and str(MHGame.challenge.surprises) == "often" and not MHGame.challenge_debugged, "a save keeps its options")
	MHGame.debug_set_challenge("radiation", false)
	_check(not MHGame.challenge.radiation and MHGame.export_challenge().get("debug", false), "the debug panel can switch one off, and marks the save")
	MHGame.prepare_state_load({"game_mode": "survival", "challenge": MHGame.export_challenge()})
	_check(MHGame.challenge_debugged, "the debug mark survives a load")

	# Older saves load as they played.
	var hazards_were := bool(MHGame.setting("live_hazards"))
	var old := MHGame.challenge_from_state({"game_mode": "survival"})
	_check(old.radiation and old.injuries and not old.fatigue and str(old.surprises) == ("usual" if hazards_were else "off"), "an old Survival save keeps crew harm and its hazards setting")
	_check(str(MHGame.challenge_from_state({"game_mode": "freedom"}).surprises) == "usual", "an old Freedom save loads on Usual")
	_check(MHGame.challenge_summary(old, "survival").begins_with("Usual surprises" if hazards_were else "Off surprises") and MHGame.challenge_summary(old, "survival").contains("Radiation"), "save cards list the options")

	# The sim: radiation off counts no dose; surprises scale the rates.
	var life = HABITAT_LIFE.new()
	life.radiation_on = false
	life.spe_hours_left = 24.0
	var inv := {"rooms": [], "items": []}
	life.post_step(1.0, inv, {}, 4, 0.0)
	_check(float(life.dose_msv) < .1 and float(life.spe_hours_left) == 23.0 and life.risk_pct(float(life.dose_msv)) == 0.0, "radiation off: a solar event runs its course with no dose, and the everyday dose never counts")
	life.radiation_on = true
	life.post_step(1.0, inv, {}, 4, 0.0)
	_check(float(life.dose_msv) > 0.0, "radiation on: the crew take a dose")
	life.live_scale = 0.0
	_check(is_zero_approx(float(HABITAT_LIFE.value("live", "breakdown_scale", .3)) * life.live_scale), "surprises Off: no live breakdowns")

	MHGame.challenge = MHGame.default_challenge()
	MHGame.challenge_debugged = false
	if failures == 0: print("Challenge options test passed: defaults, on-only in a game, modes, saves old and new, the debug mark, and the sim.")
	quit(1 if failures > 0 else 0)
