extends SceneTree

# Checks the generated audio is present and the director can drive it. Run with:
# godot --headless --path . --script res://tests/audio_test.gd
# (Generate the files first: python generate_audio.py <project>/assets/audio)
const EFFECTS := ["ui_hover", "ui_click", "ui_confirm", "ui_back", "place", "remove", "undo", "invalid", "warn", "rotate", "mode_build", "mode_explore", "door_open", "door_close", "door_interlock", "jump", "land", "ladder", "landing"]

func _initialize() -> void:
	var missing: Array = []
	for id in EFFECTS: _check("sfx/" + id, missing)
	for i in 4:
		_check("sfx/step_dirt_%d" % i, missing)
		_check("sfx/step_metal_%d" % i, missing)
	for id in MHAudio.PADS + MHAudio.BELLS + ["drone", "pulse"]: _check("music/" + id, missing)
	for id in ["wind", "hum"]: _check("ambience/" + id, missing)
	if not missing.is_empty():
		_fail("missing audio files: %s" % ", ".join(missing))
		return
	MHAudio.music("menu")
	MHAudio.ambience("outside")
	MHAudio.sfx("place")
	await process_frame
	await process_frame
	var director := MHAudio.director()
	if director == null or not director.is_inside_tree():
		_fail("audio director did not join the tree")
		return
	for bus_name in MHAudio.BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			_fail("audio bus %s was not created" % bus_name)
			return
	if not director._drone.playing or not director._wind.playing:
		_fail("drone or wind did not start")
		return
	var looped := director._wind.stream as AudioStreamWAV
	if looped == null or looped.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail("ambience stream is not looping")
		return
	MHAudio.apply_volumes({"vol_music": 0})
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")):
		_fail("music at 0 % should mute the Music bus")
		return
	MHAudio.apply_volumes()
	# The settings sheet's Audio tab builds without errors.
	var panel := MHSettingsPanel.new()
	root.add_child(panel)
	await process_frame
	panel._show_tab("audio")
	await process_frame
	panel.queue_free()
	MHAudio.music("off")
	MHAudio.ambience("off")
	print("Audio test passed: all sounds load, buses exist, music and ambience loop, volume and Audio tab work.")
	quit(0)

func _check(id: String, missing: Array) -> void:
	if not ResourceLoader.exists(MHAudio.DIR + id + ".wav"): missing.append(id)

func _fail(message: String) -> void:
	push_error("Audio test failed: " + message)
	quit(1)
