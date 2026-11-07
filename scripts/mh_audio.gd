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
const BUSES := ["Music", "Ambience", "SFX", "Voice"]
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
# The dynamic score (docs/music-and-ambience.md, stems from
# tools/generate_score.py). Each palette: its pads (chord -> file), which
# chord may follow which, the drone, levels, the gap between chords, the
# bells (recorded at bell_root semitones from D5), their notes, gaps, levels
# and figure, and an extra layer. Day is the original score.
const SCORE := {
	"day": {"pads": {"dm9": "pad_dm9", "bbmaj7": "pad_bbmaj7", "gm9": "pad_gm9", "fadd9": "pad_fadd9", "am7": "pad_am7", "csus2": "pad_csus2"},
		"next": {"dm9": ["bbmaj7", "gm9", "am7", "fadd9"], "bbmaj7": ["fadd9", "gm9", "csus2", "dm9"], "gm9": ["dm9", "bbmaj7", "csus2"], "fadd9": ["csus2", "dm9", "am7"], "am7": ["dm9", "bbmaj7", "fadd9"], "csus2": ["dm9", "gm9", "am7"]},
		"start": "dm9", "drone": "drone", "drone_db": -19.0, "pad_db": -15.0, "gap": 10.5,
		"bells": ["bell_glass", "bell_soft", "bell_chime"], "bell_root": 0, "notes": [-12, -9, -7, -5, -2, 0, 3, 5, 7], "bell_gap": Vector2(6, 14), "bell_db": Vector2(-24, -17), "figure": "single"},
	"dawn": {"pads": {"dmaj9": "dawn_dmaj9", "gmaj7": "dawn_gmaj7", "bm11": "dawn_bm11", "aadd9": "dawn_aadd9", "em9": "dawn_em9"},
		"next": {"dmaj9": ["gmaj7", "bm11", "aadd9"], "gmaj7": ["dmaj9", "em9", "aadd9"], "bm11": ["gmaj7", "em9", "dmaj9"], "aadd9": ["dmaj9", "bm11"], "em9": ["aadd9", "gmaj7"]},
		"start": "dmaj9", "drone": "drone_dawn", "drone_db": -22.0, "pad_db": -15.0, "gap": 12.0,
		"bells": ["bell_chime", "bell_glass"], "bell_root": 0, "notes": [0, 2, 4, 7, 9, 12, 14], "bell_gap": Vector2(5, 10), "bell_db": Vector2(-23, -17), "figure": "rising"},
	"dusk": {"pads": {"bbmaj9": "dusk_bbmaj9", "gm9": "dusk_gm9", "ebmaj7": "dusk_ebmaj7", "dm9": "dusk_dm9", "fadd9": "dusk_fadd9"},
		"next": {"bbmaj9": ["gm9", "ebmaj7", "dm9"], "gm9": ["ebmaj7", "dm9", "bbmaj9"], "ebmaj7": ["bbmaj9", "dm9", "fadd9"], "dm9": ["bbmaj9", "gm9"], "fadd9": ["dm9", "bbmaj9"]},
		"start": "bbmaj9", "drone": "drone_dusk", "drone_db": -19.0, "pad_db": -15.0, "gap": 13.0,
		"bells": ["bell_soft", "bell_glass"], "bell_root": 0, "notes": [12, 10, 7, 5, 3, 0], "bell_gap": Vector2(8, 15), "bell_db": Vector2(-24, -18), "figure": "falling", "extra": "blue"},
	"starlight": {"pads": {"dm": "starlight_dm", "am": "starlight_am", "bbmaj7": "starlight_bbmaj7", "csus2": "starlight_csus2"},
		"next": {"dm": ["bbmaj7", "am", "csus2"], "am": ["dm", "bbmaj7"], "bbmaj7": ["dm", "csus2"], "csus2": ["dm", "am"]},
		"start": "dm", "drone": "drone_starlight", "drone_db": -22.0, "pad_db": -20.0, "gap": 18.0,
		"bells": ["bell_star"], "bell_root": 12, "notes": [-12, -10, -7, -5, 0, 2, 5], "bell_gap": Vector2(6, 16), "bell_db": Vector2(-29, -23), "figure": "single", "extra": "twinkle"},
	"danger": {"pads": {"dmb9": "danger_dmb9", "gmmaj7": "danger_gmmaj7", "bbaug": "danger_bbaug", "dsus4b9": "danger_dsus4b9"},
		"next": {"dmb9": ["gmmaj7", "bbaug", "dsus4b9"], "gmmaj7": ["dmb9", "bbaug"], "bbaug": ["dmb9", "dsus4b9"], "dsus4b9": ["dmb9", "gmmaj7"]},
		"start": "dmb9", "drone": "drone_danger", "drone_db": -16.0, "pad_db": -15.0, "gap": 8.5,
		"bells": ["bell_metal"], "bell_root": -12, "notes": [0, 1, 6, 7, 13], "bell_gap": Vector2(5, 11), "bell_db": Vector2(-25, -19), "figure": "semitone", "extra": "heartbeat"},
}
const DANGER_ON := .35          # the score turns to Danger above this level
const DANGER_OFF := .2          # and resolves below this
const PASSAGE := Vector2(150, 240)   # seconds of music, then...
const QUIET := Vector2(80, 160)      # ...seconds of only the ambience (§10b)
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

# How much danger you're in, 0 to 1 (the world sets it: low suit oxygen, a
# storm on you, turning back too late...). Above about a third the score
# turns to Danger, with a heartbeat that follows the level; when it passes,
# a Dawn chord resolves it (docs/music-and-ambience.md §2).
static func danger(level: float) -> void:
	var d := director()
	if d != null: d._run("_set_danger", [level])

# The palette the score is using now: day, dawn, dusk, starlight or danger.
static func palette() -> String:
	var d := director()
	return d._palette if d != null else ""

# "menu", "surface" or "off". On the surface the time of day picks the
# palette (Dawn, Day, Dusk, Starlight) and music comes in passages.
static func music(mood: String) -> void:
	var d := director()
	if d != null: d._run("_set_mood", [mood])

# A moment worth marking (a pallet found, the cabin's air restored, the blue
# sunset): a warm chord over the music and three rising bells.
static func moment() -> void:
	var d := director()
	if d != null: d._run("_moment", [])

# "outside", "inside", "menu" or "off".
static func ambience(space: String) -> void:
	var d := director()
	if d != null: d._run("_set_space", [space])

static func build_layer(on: bool) -> void:
	var d := director()
	if d != null: d._run("_set_build_layer", [on])

# The habitat's voice (data/voice_lines.json, tools/generate_voice.py): a
# random variant of the line, never the same one twice running, with its text
# as a caption under the habitat's name. One line at a time: others wait their
# turn (at most two), and a line already waiting isn't queued twice.
static func voice(id: String, note := "") -> void:
	var d := director()
	if d != null: d._run("_queue_voice", ["habitat", id, note])

# The suit's own voice in your helmet (scripts/suit.gd): calm, short, after a
# soft chime; voice/<id>_<n>.wav like the habitat's, captioned "Suit".
# The suit has no voice (systems brief §10e+): an alert is a tone, plus the
# line as a short visor alert when it tells you something. Routine ones
# (sealed, topping up, full) are the tone alone.
static func suit(id: String) -> void:
	var d := director()
	if d != null: d._run("_suit_alert", [id])

# Someone at Mission Control on the radio from Earth (scripts/mission_control_link.gd):
# mc_<id>.wav, captioned with their name and role, with a note under it (how
# long ago it was sent, or that it was left for you).
static func cast_line(id: String, who: String, text: String, note := "") -> void:
	var d := director()
	if d != null: d._run("_queue_cast", [id, who, text, note])

# The orbiter crew live on the radio (the descent, scripts/descent.gd):
# orb_<id>.wav, captioned like the cast. cut_in stops whoever is talking and
# clears the queue first (the touchdown call, which ends in static).
static func orbiter_line(id: String, who: String, text: String, note := "", cut_in := false) -> void:
	var d := director()
	if d == null: return
	if cut_in: d._run("_hush", [])
	d._run("_queue_cast", [id, who, text, note, "voice/orb_" + id])

# Stops the voice now and drops anything waiting (a skipped descent).
static func hush() -> void:
	var d := director()
	if d != null: d._run("_hush", [])

# Whether anyone is talking (or waiting to): Mission Control holds its
# messages until the voice is free.
static func voice_busy() -> bool:
	var d := director()
	return d != null and (d._voice.playing or not d._voice_queue.is_empty())

# An orbiter overhead relaying for the rover (scripts/rover_radio.gd):
# relay_<id>_<n>.wav, an automated voice through a narrow link, captioned
# "Orbital relay" with the orbiter's name as the note.
static func relay(id: String, note := "") -> void:
	var d := director()
	if d != null: d._run("_queue_voice", ["relay", id, note])

const VOICE_LINES := "res://data/voice_lines.json"
static var _lines: Dictionary = {}

## Every line's variants: {"habitat": {id: [text]}, "suit": {...}, "relay": {...}}.
## (Mission Control's people are in data/mc_threads.json.)
static func lines() -> Dictionary:
	if _lines.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(VOICE_LINES))
		if parsed is Dictionary: _lines = parsed
	return _lines

# Muffles music and ambience behind pause / Mission Control.
static func muffle(on: bool) -> void:
	var d := director()
	if d != null: d._run("_set_muffle", [on])

# Applies volume settings (0–100). Pass unsaved values to preview them.
static func apply_volumes(values := {}) -> void:
	_ensure_buses()
	for key in ["vol_master", "vol_music", "vol_ambience", "vol_sfx", "vol_voice"]:
		var percent := float(values.get(key, MHGame.setting(key)))
		var bus := AudioServer.get_bus_index({"vol_master": "Master", "vol_music": "Music", "vol_ambience": "Ambience", "vol_sfx": "SFX", "vol_voice": "Voice"}[key])
		AudioServer.set_bus_mute(bus, percent <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(percent, 1.0) / 100.0))

static func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		if bus_name != "SFX" and bus_name != "Voice":
			var filter := AudioEffectLowPassFilter.new()
			filter.cutoff_hz = 900.0
			AudioServer.add_bus_effect(index, filter)
			AudioServer.set_bus_effect_enabled(index, 0, false)

# ---------- director ----------
var _streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _voice: AudioStreamPlayer
var _voice_queue: Array[Dictionary] = []
var _last_variant := {}
var _caption_layer: CanvasLayer
var _caption: PanelContainer
var _caption_left := 0.0
var _caption_building := false
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
var _palette := "day"
var _drone_b: AudioStreamPlayer        # the other drone, for crossfades
var _drone_file := "drone"
var _shimmer: AudioStreamPlayer        # dusk's blue shimmer
var _heartbeat: AudioStreamPlayer      # danger's heartbeat
var _wind_night: AudioStreamPlayer
var _danger := 0.0
var _in_danger := false
var _passage_on := true
var _passage_left := 200.0
var _look_t := 0.0                     # seconds to the next look at the clock
var _extra_t := 10.0                   # twinkles
var _amb_t := 6.0                      # cold ticks and dust devils
var _fades := {}

func _run(method: String, args: Array) -> void:
	if is_inside_tree(): callv(method, args)
	else: callv.call_deferred(method, args)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	apply_volumes()
	for i in 10: _sfx_players.append(_player("SFX"))
	_voice = _player("Voice")
	_voice.finished.connect(_next_voice)
	_drone = _player("Music", "music/drone", true)
	_drone_b = _player("Music")
	_shimmer = _player("Music", "music/blue_shimmer", true)
	_heartbeat = _player("Music", "music/heartbeat", true)
	_wind_night = _player("Ambience", "ambience/wind_night", true)
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
	_process_caption(delta)
	_process_ambience(delta)
	if _mood == "off": return
	var score: Dictionary = SCORE[_palette]
	var menu := _mood == "menu"
	# On the surface: look at the clock now and then, and run the passages.
	if not menu:
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = 2.0
			_choose_palette()
		_passage_left -= delta
		if _passage_left <= 0.0 and not _in_danger:
			_passage_on = not _passage_on
			_passage_left = randf_range(PASSAGE.x, PASSAGE.y) if _passage_on else randf_range(QUIET.x, QUIET.y)
			_apply_drone(6.0)
	var playing := menu or _passage_on or _in_danger
	_pad_timer -= delta
	if _pad_timer <= 0.0:
		_pad_timer = (12.0 if menu else float(score.gap)) * randf_range(.85, 1.15)
		if playing: _next_pad(-13.0 if menu else float(score.pad_db))
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		var gap: Vector2 = Vector2(4.0, 9.0) if menu else score.bell_gap
		_bell_timer = randf_range(gap.x, gap.y)
		# Inside the build blueprint the pulse carries the melody instead.
		if playing and not _build_on: _ring_bell()
	if str(score.get("extra", "")) == "twinkle" and playing:
		_extra_t -= delta
		if _extra_t <= 0.0:
			_extra_t = randf_range(11.0, 20.0)
			_one_shot("music/twinkle", 0.0, -26.0, 0.0)

## The palette for now: Danger while in danger, else the time of day (the
## same windows as the blue hour). A change waits for the next chord.
func _choose_palette() -> void:
	var want := "danger" if _in_danger else time_palette(MHGame.sol_hour)
	if want == _palette: return
	_palette = want
	_apply_drone(8.0)
	_apply_extras()

## Dawn, day, dusk or starlight for an hour of the sol.
static func time_palette(hour: float) -> String:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	if hour >= sunrise - .5 and hour < sunrise + 1.5: return "dawn"
	if hour >= sunset - 1.5 and hour < sunset + .7: return "dusk"
	if hour >= sunset + .7 or hour < sunrise - .5: return "starlight"
	return "day"

## The drone for the palette (crossfaded), quieter between passages.
func _apply_drone(time: float) -> void:
	var score: Dictionary = SCORE[_palette]
	var level := float(score.drone_db) if _mood != "menu" else -16.0
	if _mood == "surface" and not _passage_on and not _in_danger: level -= 6.0
	var file := str(score.drone)
	if file == _drone_file:
		_fade(_drone, level, time)
		return
	_drone_file = file
	var old := _drone
	_drone = _drone_b
	_drone_b = old
	_fade(old, -80.0, time, true)
	_kill_fade(_drone)
	_drone.stream = _stream("music/" + file, true)
	_drone.volume_db = -60.0
	_drone.play()
	_fade(_drone, level, time)

## Dusk's shimmer and Danger's heartbeat follow the palette.
func _apply_extras() -> void:
	var extra := str(SCORE[_palette].get("extra", ""))
	_fade(_shimmer, -30.0 if extra == "blue" and _mood == "surface" else -80.0, 6.0, extra != "blue")
	if extra != "heartbeat": _fade(_heartbeat, -80.0, 4.0, true)
	else: _fade(_heartbeat, lerpf(-34.0, -18.0, _danger), 2.0)

func _set_danger(level: float) -> void:
	_danger = clampf(level, 0.0, 1.0)
	if _mood != "surface": return
	if not _in_danger and _danger >= DANGER_ON:
		_in_danger = true
		_pad_timer = minf(_pad_timer, 1.5)   # turn quickly
		_choose_palette()
	elif _in_danger and _danger < DANGER_OFF:
		_in_danger = false
		_choose_palette()
		# The relief: a Dawn chord resolves it.
		_last_pad = "dmaj9"
		_play_pad("dawn_dmaj9", -13.0)
		_pad_timer = maxf(_pad_timer, 9.0)
		_passage_on = true
		_passage_left = maxf(_passage_left, 60.0)
	elif _in_danger:
		_fade(_heartbeat, lerpf(-34.0, -18.0, _danger), 1.0)

func _next_pad(level_db: float) -> void:
	var score: Dictionary = SCORE[_palette]
	var choices: Array = (score.next as Dictionary).get(_last_pad, [str(score.start)])
	var chord: String = choices[randi() % choices.size()]
	_last_pad = chord
	_play_pad(str(score.pads[chord]), level_db)

func _play_pad(file: String, level_db: float) -> void:
	var p := _pads[_pad_index]
	_pad_index = (_pad_index + 1) % _pads.size()
	p.stream = _stream("music/" + file)
	if p.stream == null: return
	_kill_fade(p)
	p.volume_db = level_db
	p.play()

## A short sound on its own player: a bell note or a twinkle.
func _one_shot(file: String, semitones: float, level_db: float, after: float) -> void:
	var stream := _stream(file)
	if stream == null: return
	var p := AudioStreamPlayer.new()
	p.bus = "Music" if file.begins_with("music/") else "Ambience"
	p.stream = stream
	p.pitch_scale = pow(2.0, semitones / 12.0)
	p.volume_db = level_db
	add_child(p)
	p.finished.connect(p.queue_free)
	if after <= 0.0: p.play()
	else: get_tree().create_timer(after).timeout.connect(func() -> void: if is_instance_valid(p): p.play())

func _moment() -> void:
	if _mood == "surface" and not _passage_on:
		_passage_on = true
		_passage_left = 60.0
		_apply_drone(3.0)
	var p := _pads[_pad_index]
	_pad_index = (_pad_index + 1) % _pads.size()
	p.stream = _stream("music/pad_fadd9")
	if p.stream != null:
		_kill_fade(p)
		p.volume_db = -11.0
		p.play()
		_pad_timer = maxf(_pad_timer, 9.0)
	for i in 3:
		var bell := AudioStreamPlayer.new()
		bell.bus = _bell.bus
		bell.stream = _stream("music/bell_glass")
		bell.pitch_scale = pow(2.0, [0.0, 4.0, 7.0][i] / 12.0)
		bell.volume_db = -15.0
		add_child(bell)
		get_tree().create_timer(.45 * i + .2).timeout.connect(func() -> void:
			bell.play()
			bell.finished.connect(bell.queue_free))
	_bell_timer = maxf(_bell_timer, 6.0)

## The palette's bell, in its figure: one note, three rising, two falling,
## or two a half step apart.
func _ring_bell() -> void:
	var score: Dictionary = SCORE[_palette]
	var bells: Array = score.bells
	var file := "music/" + str(bells[randi() % bells.size()])
	var notes: Array = score.notes
	var root := float(score.bell_root)
	var range_db: Vector2 = score.bell_db
	var level := randf_range(range_db.x, range_db.y)
	match str(score.figure):
		"rising":
			var i := randi() % maxi(1, notes.size() - 2)
			for k in 3: _one_shot(file, float(notes[i + k]) - root, level - 2.0 * k, .42 * k)
		"falling":
			var i := randi() % maxi(1, notes.size() - 1)
			_one_shot(file, float(notes[i]) - root, level, 0.0)
			_one_shot(file, float(notes[i + 1]) - root, level - 3.0, .9)
		"semitone":
			var n := float(notes[randi() % notes.size()])
			_one_shot(file, n - root, level, 0.0)
			_one_shot(file, n + 1.0 - root, level - 2.0, 1.6)
		_:
			_bell.stream = _stream(file)
			if _bell.stream == null: return
			_bell.pitch_scale = pow(2.0, (float(notes[randi() % notes.size()]) - root) / 12.0)
			_bell.volume_db = level
			_bell.play()

func _set_mood(mood: String) -> void:
	if mood == _mood or (mood != "off" and not MOODS.has(mood)): return
	var first := _mood == "off"
	_mood = mood
	if mood == "off":
		for p in [_drone, _drone_b, _pulse, _bell, _pads[0], _pads[1], _shimmer, _heartbeat]: _fade(p, -80.0, 2.0, true)
		return
	_palette = "day" if mood == "menu" else time_palette(MHGame.sol_hour)
	_in_danger = false
	_passage_on = true
	_passage_left = randf_range(PASSAGE.x, PASSAGE.y)
	_apply_drone(4.0)
	_apply_extras()
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
	var levels: Array = {"outside": [-12.0, -80.0], "inside": [-80.0, -27.0], "menu": [-20.0, -80.0], "off": [-80.0, -80.0]}.get(space, [-80.0, -80.0])
	_apply_wind(1.5)
	_fade(_hum, levels[1], 1.0, levels[1] <= -80.0)
	_apply_storm()

## How far into night it is outside, 0 (day) to 1 (night), easing through
## the dusk and dawn windows.
static func night_amount(hour: float) -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	if hour >= sunrise + .5 and hour < sunset - .5: return 0.0
	if hour >= sunset + .7 or hour < sunrise - .5: return 1.0
	if hour >= sunset - .5: return smoothstep(sunset - .5, sunset + .7, hour)
	return 1.0 - smoothstep(sunrise - .5, sunrise + .5, hour)

## Day wind and night wind, crossfaded by the hour (outside and the menu only).
func _apply_wind(time: float) -> void:
	var base: float = {"outside": -12.0, "menu": -20.0}.get(_space, -80.0)
	if base <= -80.0:
		_fade(_wind, -80.0, time, true)
		_fade(_wind_night, -80.0, time, true)
		return
	var night := night_amount(MHGame.sol_hour) if _space == "outside" else 0.0
	_fade(_wind, base + 20.0 * log(maxf(1.0 - night, .001)) / log(10.0), time, night >= .999)
	_fade(_wind_night, base - 6.0 + 20.0 * log(maxf(night, .001)) / log(10.0), time, night <= .001)

## Outside: now and then the cold ticks at night, or a dust devil passes by day.
func _process_ambience(delta: float) -> void:
	if _space != "outside": return
	_amb_t -= delta
	if _amb_t > 0.0: return
	var night := night_amount(MHGame.sol_hour)
	_apply_wind(2.0)
	if night > .6:
		_amb_t = randf_range(4.0, 13.0)
		_one_shot("ambience/cold_tick", randf_range(-3.0, 4.0), randf_range(-30.0, -24.0), 0.0)
	elif night < .1 and randf() < .02 and _storm_level < .1:
		_amb_t = 120.0
		_one_shot("ambience/dust_devil", randf_range(-1.0, 1.0), -18.0, 0.0)
	else:
		_amb_t = 3.0

func _set_weather(level: float) -> void:
	_storm_level = clampf(level, 0.0, 1.0)
	_apply_storm()

func _apply_storm() -> void:
	var inside := _space == "inside"
	for pair in [[_storm, -7.0, not inside and _space != "menu" and _space != "off"], [_storm_inside, -24.0, inside]]:
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

const SUIT_QUIET := ["suit_sealed", "suit_topping_up", "suit_full"]
const SUIT_URGENT := ["suit_o2_quarter", "suit_o2_critical", "suit_turn_back", "suit_power_out"]

func _suit_alert(id: String) -> void:
	var variants: Array = (lines().get("suit", {}) as Dictionary).get(id, [])
	_play_sfx("suit_alarm" if id in SUIT_URGENT else "suit_beep", -6.0 if id in SUIT_URGENT else -10.0, 0.0)
	if variants.is_empty() or id in SUIT_QUIET: return
	_show_caption("Suit", str(variants[0]), "", 4.0, false, true)

## Whether the player is inside the habitat or the lander cabin (true when
## there's no world, e.g. the menu). ARDEN speaks only there (§10e+).
func _player_indoors() -> bool:
	var world := get_tree().get_first_node_in_group("habitat_world") if is_inside_tree() else null
	if world == null or world.get("player") == null: return true
	var at: Vector3 = (world.player as Node3D).global_position
	var builder: Variant = world.get("builder")
	if builder != null and builder.has_method("is_inside") and builder.is_inside(at): return true
	var lander: Variant = world.get("lander")
	return lander != null and lander.has_method("cabin_contains") and lander.cabin_contains(at)

func _queue_voice(speaker: String, id: String, note: String) -> void:
	var variants: Array = (lines().get(speaker, {}) as Dictionary).get(id, [])
	if variants.is_empty(): return
	# ARDEN is the habitat's voice: out on the ground it says nothing (its
	# alerts still show as icons on the HUD).
	if speaker == "habitat" and not _player_indoors(): return
	var line := {"speaker": speaker, "id": id, "note": note}
	if _voice.playing:
		if not _voice_queue.any(func(q): return q.id == id) and _voice_queue.size() < 2: _voice_queue.append(line)
		return
	_play_line(line)

func _queue_cast(id: String, who: String, text: String, note: String, file := "") -> void:
	var line := {"speaker": "cast", "id": id, "who": who, "text": text, "note": note, "file": file if not file.is_empty() else "voice/mc_" + id}
	if _voice.playing:
		if _voice_queue.size() < 3: _voice_queue.append(line)
		return
	_play_line(line)

func _hush() -> void:
	_voice_queue.clear()
	_voice.stop()

func _play_line(line: Dictionary) -> void:
	var speaker := str(line.speaker)
	if speaker == "cast":
		var cast_stream := _stream(str(line.file))
		var length := 0.0
		if cast_stream != null:
			_voice.stream = cast_stream
			_voice.volume_db = -4.0
			_voice.play()
			length = cast_stream.get_length()
		_show_caption(str(line.who), str(line.text), str(line.note), maxf(length, 3.0 + str(line.text).length() * .06), true)
		return
	var variants: Array = (lines().get(speaker, {}) as Dictionary).get(str(line.id), [])
	var key := speaker + "/" + str(line.id)
	var n := randi() % variants.size()
	if variants.size() > 1 and n == int(_last_variant.get(key, -1)): n = (n + 1) % variants.size()
	_last_variant[key] = n
	var file := "voice/%s%s_%d" % ["relay_" if speaker == "relay" else "", str(line.id), n]
	var stream := _stream(file)
	if stream == null: return
	_voice.stream = stream
	_voice.volume_db = -5.0 if speaker == "relay" else -2.0
	_voice.play()
	var who := "Orbital relay" if speaker == "relay" else ("Suit" if speaker == "suit" else MHGame.habitat_name)
	_show_caption(who, str(variants[n]), str(line.get("note", "")), stream.get_length(), speaker == "relay")

func _next_voice() -> void:
	if _voice_queue.is_empty(): return
	_play_line(_voice_queue.pop_front())

## Subtitles (Settings → On screen): full, compact (the default) or off.
## Off shows nothing; Mission Control's lines still reach the Messages log.
static func subtitles() -> String:
	var value := str(MHGame.setting("subtitles"))
	return value if value in ["full", "compact", "off"] else "compact"

# Captions for everything said (for playing with the sound off): bottom
# centre while walking about; while building, a slim strip at the bottom
# left above the build bar, clear of the plan and the notices.
func _show_caption(who: String, text: String, note: String, seconds: float, radio := false, always := false) -> void:
	if subtitles() == "off" and not always: return
	if _caption_layer == null:
		_caption_layer = CanvasLayer.new()
		_caption_layer.layer = 7
		add_child(_caption_layer)
	if _caption != null and is_instance_valid(_caption): _caption.queue_free()
	_caption = PanelContainer.new()
	_caption.theme = MHStyle.theme()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_building = _building()
	var full := subtitles() == "full" and not _caption_building
	var pad := Vector4(18, 10, 18, 10) if full else Vector4(14, 7, 14, 8)
	_caption.add_theme_stylebox_override("panel", MHStyle.box(Color(MHStyle.SURFACE_HUD, .82), Color(0, 0, 0, 0), 8, 0, pad))
	_place_caption()
	var col := MHStyle.vbox(2)
	_caption.add_child(col)
	var head := MHStyle.hbox(8)
	head.add_child(MHStyle.eyebrow(who, MHStyle.INFO if radio else MHGame.accent(), 13 if full else 11))
	if not note.is_empty(): head.add_child(MHStyle.mono(note, 12 if full else 10, MHStyle.TEXT_MUTED))
	col.add_child(head)
	var size := 18 if full else (14 if _caption_building else 15)
	var words := MHStyle.body(text, size, MHStyle.TEXT_PRIMARY)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var widest := 720.0 if full else (420.0 if _caption_building else 520.0)
	words.custom_minimum_size.x = minf(widest, size * .78 * text.length() * .62 + 40.0)
	col.add_child(words)
	_caption_layer.add_child(_caption)
	_caption_left = seconds + 2.0

func _building() -> bool:
	var world := get_tree().get_first_node_in_group("habitat_world") if is_inside_tree() else null
	return world != null and world.get("builder") != null and (bool(world.builder.build_mode) or (world.get("interior_builder") != null and bool(world.interior_builder.active)))

## Bottom centre while walking about; bottom left above the build bar while building.
func _place_caption() -> void:
	if _caption_building:
		_caption.anchor_left = 0.0
		_caption.anchor_right = 0.0
		_caption.offset_left = 32.0
		_caption.offset_right = 32.0
		_caption.grow_horizontal = Control.GROW_DIRECTION_END
	else:
		_caption.anchor_left = .5
		_caption.anchor_right = .5
		_caption.offset_left = 0.0
		_caption.offset_right = 0.0
		_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_bottom = -340.0 if _caption_building else -132.0
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _process_caption(delta: float) -> void:
	if _caption == null or not is_instance_valid(_caption): return
	if _building() != _caption_building:
		_caption_building = not _caption_building
		_place_caption()
	_caption_left -= delta
	_caption.modulate.a = clampf(_caption_left / .5, 0.0, 1.0)
	if _caption_left <= 0.0:
		_caption.queue_free()
		_caption = null

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
	# Indoors, sounds from further off are usually outside or through a wall.
	var camera := get_viewport().get_camera_3d()
	if _space == "inside" and camera != null and target.global_position.distance_to(camera.global_position) > 6.0: p.volume_db -= 14.0
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
