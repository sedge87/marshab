class_name MHAudio
extends Node

# Music, ambience and sound effects. Like MHGame this is used through static
# calls (no autoload): the first call parks one director node on the tree root,
# where it survives scene changes so the score carries on from menu to Mars.
#
# Every sound is synthesised by generate_audio.py into assets/audio/. The score
# is generative: slow D-minor pads crossfade in a wandering order over a drone,
# with glass bells on a pentatonic scale, so it never loops audibly. Build mode
# adds a soft data pulse. Missing files are skipped silently.

const DIR := "res://assets/audio/"
const BUSES := ["Music", "Ambience", "SFX"]
const PADS := ["pad_dm9", "pad_bbmaj7", "pad_gm9", "pad_fadd9", "pad_am7", "pad_csus2"]
# Which chords may follow which: keeps the harmony moving without lurching.
const PAD_NEXT := {
	"pad_dm9": ["pad_bbmaj7", "pad_gm9", "pad_am7", "pad_fadd9"],
	"pad_bbmaj7": ["pad_fadd9", "pad_gm9", "pad_csus2", "pad_dm9"],
	"pad_gm9": ["pad_dm9", "pad_bbmaj7", "pad_csus2"],
	"pad_fadd9": ["pad_csus2", "pad_dm9", "pad_am7"],
	"pad_am7": ["pad_dm9", "pad_bbmaj7", "pad_fadd9"],
	"pad_csus2": ["pad_dm9", "pad_gm9", "pad_am7"]
}
const BELLS := ["bell_glass", "bell_soft", "bell_chime"]
# D minor pentatonic, as semitones from the bells' recorded D5.
const BELL_NOTES := [-12, -9, -7, -5, -2, 0, 3, 5, 7]
# Per-effect level trims (dB) so the generated files sit together in the mix.
const SFX_TRIM := {
	"ui_hover": -16.0, "ui_click": -9.0, "ui_back": -9.0, "ui_confirm": -6.0, "invalid": -14.0,
	"warn": -8.0, "undo": -6.0, "rotate": -9.0, "rover_chirp": -10.0, "place": -2.0, "remove": -4.0, "jump": -10.0,
	"land": -6.0, "ladder": -4.0, "landing": -2.0, "mode_build": -6.0, "mode_explore": -6.0,
	"storm_alert": -7.0, "all_clear": -8.0,
	"guitar_strum_0": -5.0, "guitar_strum_1": -5.0, "guitar_strum_2": -5.0, "guitar_strum_3": -5.0,
	"plush_squeak_0": -12.0, "plush_squeak_1": -12.0, "plush_squeak_2": -12.0
}
# Mood -> [drone dB, pad dB, seconds between pads, seconds between bells].
const MOODS := {
	"menu": [-16.0, -13.0, 12.0, Vector2(4.0, 9.0)],
	"surface": [-19.0, -15.0, 10.5, Vector2(6.0, 14.0)]
}

static var _director: MHAudio

# ---------- static API ----------
static func director() -> MHAudio:
	if _director != null and is_instance_valid(_director): return _director
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null: return null
	_director = MHAudio.new()
	_director.name = "MHAudio"
	# Deferred: callers are often in the middle of a scene's _ready.
	tree.root.add_child.call_deferred(_director)
	return _director

# Plays a 2D effect, e.g. MHAudio.sfx("place"). pitch_jitter varies each play.
static func sfx(id: String, volume_db := 0.0, pitch_jitter := 0.04) -> void:
	var d := director()
	if d != null: d._run("_play_sfx", [id, volume_db, pitch_jitter])

# Plays an effect from a point in the world (airlock doors), height metres
# above the target's origin.
static func sfx_at(id: String, target: Node3D, volume_db := 0.0, height := 1.4) -> void:
	var d := director()
	if d != null and target != null: d._run("_play_at", [id, target, volume_db, height])

# Dust storm loudness, 0 (calm) to 1 (full storm): a roar outside, a muffled
# buffet and sand ticks through the hull inside. Set smoothly by MHWeather.
static func weather(storm_level: float) -> void:
	var d := director()
	if d != null: d._run("_set_weather", [storm_level])

# "menu", "surface" or "off".
static func music(mood: String) -> void:
	var d := director()
	if d != null: d._run("_set_mood", [mood])

# "outside", "inside", "menu" or "off".
static func ambience(space: String) -> void:
	var d := director()
	if d != null: d._run("_set_space", [space])

static func build_layer(on: bool) -> void:
	var d := director()
	if d != null: d._run("_set_build_layer", [on])

# Muffles music and ambience behind pause / Mission Control.
static func muffle(on: bool) -> void:
	var d := director()
	if d != null: d._run("_set_muffle", [on])

# Applies volume settings (0–100). Pass unsaved values to preview them.
static func apply_volumes(values := {}) -> void:
	_ensure_buses()
	for key in ["vol_master", "vol_music", "vol_ambience", "vol_sfx"]:
		var percent := float(values.get(key, MHGame.setting(key)))
		var bus := AudioServer.get_bus_index({"vol_master": "Master", "vol_music": "Music", "vol_ambience": "Ambience", "vol_sfx": "SFX"}[key])
		AudioServer.set_bus_mute(bus, percent <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(percent, 1.0) / 100.0))

static func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		if bus_name != "SFX":
			var filter := AudioEffectLowPassFilter.new()
			filter.cutoff_hz = 900.0
			AudioServer.add_bus_effect(index, filter)
			AudioServer.set_bus_effect_enabled(index, 0, false)

# ---------- director ----------
var _streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _drone: AudioStreamPlayer
var _pulse: AudioStreamPlayer
var _pads: Array[AudioStreamPlayer] = []
var _bell: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _storm: AudioStreamPlayer
var _storm_inside: AudioStreamPlayer
var _storm_level := 0.0
var _mood := "off"
var _space := "off"
var _build_on := false
var _pad_index := 0
var _last_pad := ""
var _pad_timer := 0.0
var _bell_timer := 4.0
var _fades := {}

func _run(method: String, args: Array) -> void:
	if is_inside_tree(): callv(method, args)
	else: callv.call_deferred(method, args)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	apply_volumes()
	for i in 10: _sfx_players.append(_player("SFX"))
	_drone = _player("Music", "music/drone", true)
	_pulse = _player("Music", "music/pulse", true)
	for i in 2: _pads.append(_player("Music"))
	_bell = _player("Music")
	_wind = _player("Ambience", "ambience/wind", true)
	_hum = _player("Ambience", "ambience/hum", true)
	_storm = _player("Ambience", "ambience/storm", true)
	_storm_inside = _player("Ambience", "ambience/storm_inside", true)
	# Every button in the game gets the same hover tick and click.
	get_tree().node_added.connect(_hook_button)
	_hook_tree(get_tree().root)

# Stops playback on quit so the audio server lets go of every stream.
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
	_streams.clear()

func _player(bus: String, id := "", loop := false) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	if not id.is_empty():
		p.stream = _stream(id, loop)
		p.volume_db = -80.0
	add_child(p)
	return p

func _stream(id: String, loop := false) -> AudioStream:
	if _streams.has(id): return _streams[id]
	var path := DIR + id + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream is AudioStreamWAV and loop:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	_streams[id] = stream
	return stream

func _process(delta: float) -> void:
	if _mood == "off": return
	var mood: Array = MOODS[_mood]
	_pad_timer -= delta
	if _pad_timer <= 0.0:
		_pad_timer = float(mood[2]) * randf_range(.85, 1.15)
		_next_pad(float(mood[1]))
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		var gap: Vector2 = mood[3]
		_bell_timer = randf_range(gap.x, gap.y)
		# Inside the build blueprint the pulse carries the melody instead.
		if not _build_on: _ring_bell()

func _next_pad(level_db: float) -> void:
	var choices: Array = PAD_NEXT.get(_last_pad, PADS)
	var id: String = choices[randi() % choices.size()]
	_last_pad = id
	var p := _pads[_pad_index]
	_pad_index = (_pad_index + 1) % _pads.size()
	p.stream = _stream("music/" + id)
	if p.stream == null: return
	_kill_fade(p)
	p.volume_db = level_db
	p.play()

func _ring_bell() -> void:
	var id: String = BELLS[randi() % BELLS.size()]
	_bell.stream = _stream("music/" + id)
	if _bell.stream == null: return
	_bell.pitch_scale = pow(2.0, BELL_NOTES[randi() % BELL_NOTES.size()] / 12.0)
	_bell.volume_db = randf_range(-24.0, -17.0)
	_bell.play()

func _set_mood(mood: String) -> void:
	if mood == _mood or (mood != "off" and not MOODS.has(mood)): return
	var first := _mood == "off"
	_mood = mood
	if mood == "off":
		for p in [_drone, _pulse, _bell, _pads[0], _pads[1]]: _fade(p, -80.0, 2.0, true)
		return
	var settings: Array = MOODS[mood]
	_fade(_drone, float(settings[0]), 4.0)
	# Start a chord straight away on first entry; otherwise let the current one ring out.
	if first:
		_pad_timer = 0.0
		_bell_timer = randf_range(3.0, 6.0)

func _set_build_layer(on: bool) -> void:
	_build_on = on
	_fade(_pulse, -15.0 if on else -80.0, 1.2 if on else 2.5, not on)

func _set_space(space: String) -> void:
	if space == _space: return
	_space = space
	var levels: Array = {"outside": [-12.0, -80.0], "inside": [-28.0, -15.0], "menu": [-20.0, -80.0], "off": [-80.0, -80.0]}.get(space, [-80.0, -80.0])
	_fade(_wind, levels[0], 1.5, levels[0] <= -80.0)
	_fade(_hum, levels[1], 1.0, levels[1] <= -80.0)
	_apply_storm()

func _set_weather(level: float) -> void:
	_storm_level = clampf(level, 0.0, 1.0)
	_apply_storm()

func _apply_storm() -> void:
	var inside := _space == "inside"
	for pair in [[_storm, -7.0, not inside and _space != "menu" and _space != "off"], [_storm_inside, -13.0, inside]]:
		var p: AudioStreamPlayer = pair[0]
		if p == null or p.stream == null: continue
		var on: bool = pair[2] and _storm_level > .01
		if not on:
			if p.playing: p.stop()
			continue
		p.volume_db = lerpf(-40.0, float(pair[1]), sqrt(_storm_level))
		if not p.playing: p.play()

func _set_muffle(on: bool) -> void:
	for bus_name in ["Music", "Ambience"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index != -1 and AudioServer.get_bus_effect_count(index) > 0: AudioServer.set_bus_effect_enabled(index, 0, on)

func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after := false) -> void:
	if p == null or p.stream == null: return
	_kill_fade(p)
	if not p.playing:
		if to_db <= -80.0: return
		p.volume_db = -60.0
		p.play()
	var tween := create_tween()
	tween.tween_property(p, "volume_db", to_db, time).set_trans(Tween.TRANS_SINE)
	if stop_after: tween.tween_callback(p.stop)
	_fades[p] = tween

func _kill_fade(p: AudioStreamPlayer) -> void:
	if _fades.has(p) and (_fades[p] as Tween).is_valid(): (_fades[p] as Tween).kill()
	_fades.erase(p)

func _play_sfx(id: String, volume_db: float, pitch_jitter: float) -> void:
	var stream := _stream("sfx/" + id)
	if stream == null: return
	var p := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	p.stream = stream
	p.volume_db = volume_db + float(SFX_TRIM.get(id, -3.0))
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()

func _play_at(id: String, target: Node3D, volume_db: float, height := 1.4) -> void:
	var stream := _stream("sfx/" + id)
	if stream == null or not is_instance_valid(target) or not target.is_inside_tree(): return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db + float(SFX_TRIM.get(id, -2.0))
	p.unit_size = 4.0
	p.max_distance = 40.0
	p.pitch_scale = randf_range(.97, 1.03)
	target.add_child(p)
	p.position = Vector3(0, height, 0)
	p.finished.connect(p.queue_free)
	p.tree_exiting.connect(func() -> void: p.stop(); p.stream = null)
	p.play()

func _hook_tree(node: Node) -> void:
	_hook_button(node)
	for child in node.get_children(): _hook_tree(child)

func _hook_button(node: Node) -> void:
	if not node is BaseButton or node.has_meta("mh_audio"): return
	var b := node as BaseButton
	b.set_meta("mh_audio", true)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled: _play_sfx("ui_hover", 0.0, .03))
	b.pressed.connect(func() -> void: _play_sfx("ui_click", 0.0, .03))
