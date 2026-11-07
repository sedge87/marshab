extends SceneTree

# The dynamic score (docs/music-and-ambience.md, scripts/mh_audio.gd): every
# stem exists; the menu plays Day; on the surface the hour picks Dawn, Day,
# Dusk or Starlight; danger turns it to Danger with a heartbeat and resolves
# with a Dawn chord; the night wind takes over from the day wind. Run with:
# godot --headless --path . --script res://tests/score_test.gd

var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	for palette in MHAudio.SCORE:
		var score: Dictionary = MHAudio.SCORE[palette]
		var files: Array = (score.pads as Dictionary).values() + score.bells + [score.drone]
		for file in files: _check(ResourceLoader.exists("res://assets/audio/music/%s.wav" % file), "%s: music/%s exists" % [palette, file])
		for chord in score.next:
			_check((score.pads as Dictionary).has(chord) and (score.next[chord] as Array).all(func(c): return (score.pads as Dictionary).has(c)), "%s: every chord leads to chords it has" % palette)
	for file in ["music/twinkle", "music/heartbeat", "music/blue_shimmer", "ambience/wind_night", "ambience/cold_tick", "ambience/dust_devil"]:
		_check(ResourceLoader.exists("res://assets/audio/%s.wav" % file), "%s exists" % file)
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	_check(MHAudio.time_palette(sunrise + .5) == "dawn" and MHAudio.time_palette(12.0) == "day" and MHAudio.time_palette(sunset) == "dusk" and MHAudio.time_palette(sunset + 2.0) == "starlight" and MHAudio.time_palette(1.0) == "starlight", "the hour picks dawn, day, dusk and starlight")

	MHAudio.music("menu")
	await process_frame
	await process_frame
	var audio: MHAudio = MHAudio.director()
	_check(MHAudio.palette() == "day" and audio._drone.playing, "the menu plays Day with its drone")
	MHAudio.music("off")
	MHGame.sol_hour = sunset + 2.0
	MHAudio.music("surface")
	MHAudio.ambience("outside")
	await process_frame
	await process_frame
	_check(MHAudio.palette() == "starlight" and audio._drone_file == "drone_starlight", "after dark the surface plays Starlight (%s)" % MHAudio.palette())
	audio._pad_timer = 0.0
	audio._process(.01)
	_check(audio._last_pad in (MHAudio.SCORE.starlight.pads as Dictionary), "Starlight's chords play")
	_check(audio._wind_night.playing and audio._wind_night.volume_db > -80.0, "the night wind is up")
	MHAudio.danger(.8)
	await process_frame
	_check(MHAudio.palette() == "danger" and audio._heartbeat.playing, "danger turns the score to Danger with a heartbeat")
	MHAudio.danger(0.0)
	await process_frame
	_check(MHAudio.palette() == "starlight" and audio._last_pad == "dmaj9", "when it passes, a Dawn chord resolves it and the hour's palette comes back")
	MHGame.sol_hour = sunset - .5
	audio._look_t = 0.0
	audio._process(.01)
	_check(MHAudio.palette() == "dusk", "dusk follows the clock")
	if failures == 0:
		print("Score test passed: every stem, the hour's palettes, the menu's Day, Starlight's chords and night wind, Danger's heartbeat and its Dawn resolution, and dusk following the clock.")
	quit(1 if failures > 0 else 0)
