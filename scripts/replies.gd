extends CanvasLayer

## Short replies (docs/systems-and-items.md §10e, §10f; data/replies.json):
## when ARDEN or an orbit text says something that wants an answer, two or
## three short replies come up above the subtitles (keys 1-3) and fade after
## a few seconds. Silence is an answer too. No dialogue tree.
## - Your words are written, never spoken: the pick shows as a "You" line.
## - Saying what you'll do takes up the Notes thought in your own words and
##   puts it first (scripts/notes.gd take_up): someone tells you, you
##   acknowledge it, and it becomes your thought (8 Nov playtest: "unclear
##   what I'm doing and why").
## - A text's sender answers on the next pass (another orbit text).
## One offer at a time, only when nobody's talking and the slate's down.

const DATA := "res://data/replies.json"
const SHOW_SECONDS := 9.0       # how long the choices wait
const SAID_SECONDS := 3.5       # your line stays this long
const ANSWER_AFTER := 45.0      # seconds to the next pass's answer
const TEXT_WAIT := 30.0         # an unread text's replies come up anyway after this
const GAP := 20.0               # never two offers closer than this (playthrough, 8 Nov)

var world: Node
var answered: Dictionary = {}   # id -> the reply's index, or -1 for silence
var _data: Dictionary = {}
var _queue: Array = []          # {id, who, line, at}
var _shown: Dictionary = {}     # the offer up now
var _left := 0.0
var _said_left := 0.0
var _gap := 0.0                 # seconds before the next offer may come up
var _answers: Array = []        # [seconds left, id, who, text]
var _panel: PanelContainer
var _box: VBoxContainer
var _context: Label
var _rows: Array = []
var _bar: ColorRect
var _you: Label

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "Replies"
	layer = 7
	add_to_group("replies")
	for id in (saved.get("answered", {}) as Dictionary): answered[str(id)] = int(saved.answered[id])
	for a in saved.get("answers", []): _answers.append([float(a[0]), str(a[1]), str(a[2]), str(a[3])])

func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary: _data = parsed
	return _data

func has_replies(id: String) -> bool:
	return data().has(id) and not answered.has(id)

## Something was said to you that wants an answer. `who` names the speaker
## ("ARDEN", "Castellanos"); `line` is a short reminder of what they said.
func offer(id: String, who: String, line: String, text_message := false, sender := "") -> void:
	if not has_replies(id) or _queue.any(func(q): return str(q.id) == id) or str(_shown.get("id", "")) == id: return
	_queue.append({"id": id, "who": who, "line": line, "text": text_message, "sender": sender, "wait": TEXT_WAIT if text_message else 0.0})

## ARDEN said line `id` (data/voice_lines.json): offer its replies once it's done.
func offer_voice(id: String) -> void:
	var lines: Array = (MHAudio.lines().get("habitat", {}) as Dictionary).get(id, [])
	offer(id, "ARDEN", str(lines[0]) if not lines.is_empty() else "")

func _ready() -> void:
	# A dark backing so it reads on any wall or sky, above the subtitles.
	_panel = PanelContainer.new()
	_panel.theme = MHStyle.theme()
	_panel.add_theme_stylebox_override("panel", MHStyle.hud_box(14, true))
	_panel.anchor_left = .5
	_panel.anchor_right = .5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_bottom = -170
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_box = MHStyle.vbox(6)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_box)
	_context = MHStyle.body("", 16, MHStyle.TEXT_SECONDARY)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_context)
	for i in 3:
		var row := MHStyle.label("", 19, MHStyle.TEXT_PRIMARY, 600)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(row)
		_rows.append(row)
	_bar = ColorRect.new()
	_bar.color = Color(MHStyle.accent, .8)
	_bar.custom_minimum_size = Vector2(0, 3)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_box.add_child(_bar)
	_you = MHStyle.label("", 19, MHStyle.TEXT_PRIMARY, 600)
	_you.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_you)

func _process(delta: float) -> void:
	# Answers from orbit, on the next pass.
	for a in _answers.duplicate():
		a[0] = float(a[0]) - delta
		if float(a[0]) <= 0.0:
			_answers.erase(a)
			var texts: Node = world.get("orbiter_texts") if world != null else null
			if texts != null: texts.send(str(a[1]), str(a[2]), str(a[3]))
	_gap = maxf(0.0, _gap - delta)
	if _said_left > 0.0:
		_said_left -= delta
		if _said_left <= 0.0: _panel.visible = false
		return
	if not _shown.is_empty():
		_left -= delta
		_bar.custom_minimum_size.x = 720.0 * clampf(_left / SHOW_SECONDS, 0.0, 1.0)
		if _left <= 0.0: choose(-1)
		return
	if _queue.is_empty() or not _free(): return
	var next: Dictionary = _queue[0]
	# A text waits until you've had the slate up (or a while has passed).
	if bool(next.text) and float(next.wait) > 0.0 and not _read_since(next):
		next.wait = float(next.wait) - delta
		return
	_queue.pop_front()
	_show(next)

func _free() -> bool:
	if world == null or world.get_tree().paused: return false
	if MHAudio.voice_busy() or _gap > 0.0: return false
	# Let the line before it be read first: the notice line is all but clear.
	var line = MHNotices._line
	if line != null and is_instance_valid(line) and line._queue.size() > 1: return false
	var pda: Node = world.get("pda")
	if pda != null and bool(pda.get("is_open")): return false
	var player: Node = world.get("player")
	return player == null or not bool(player.get_meta("ui_freeze", false)) or bool(player.get_meta("riding", false))

func _read_since(entry: Dictionary) -> bool:
	return bool(entry.get("read", false))

## The slate went down: any waiting text has been seen.
func slate_lowered() -> void:
	for q in _queue: q["read"] = true

func _show(entry: Dictionary) -> void:
	var spec: Dictionary = data().get(str(entry.id), {})
	var replies: Array = spec.get("replies", [])
	_shown = entry.duplicate()
	_shown["replies"] = replies
	_left = SHOW_SECONDS
	_context.text = "%s: %s" % [str(entry.who), str(entry.line)]
	for i in _rows.size():
		var row: Label = _rows[i]
		row.visible = i < replies.size()
		if row.visible: row.text = "%d   %s" % [i + 1, str(replies[i].text)]
	_bar.visible = true
	_you.visible = false
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, .2)
	MHAudio.sfx("ui_hover", -14.0)

func _input(event: InputEvent) -> void:
	if _shown.is_empty() or not (event is InputEventKey and event.pressed and not event.echo): return
	var key := (event as InputEventKey).keycode
	var index := [KEY_1, KEY_2, KEY_3].find(key)
	if index < 0 or index >= (_shown.replies as Array).size(): return
	choose(index)
	get_viewport().set_input_as_handled()

## Picks reply `index` (-1: you said nothing).
func choose(index: int) -> void:
	if _shown.is_empty(): return
	var entry := _shown
	_shown = {}
	_gap = GAP
	var id := str(entry.id)
	answered[id] = index
	var spec: Dictionary = data().get(id, {})
	var notes: Node = world.get("notes") if world != null else null
	if index < 0:
		_panel.visible = false
		var quiet := str(spec.get("silence_note", ""))
		if notes != null and not quiet.is_empty() and not notes.is_settled(quiet) and not notes.is_open(quiet): notes.think(quiet)
		return
	var reply: Dictionary = (entry.replies as Array)[index]
	for row in _rows: (row as Label).visible = false
	_bar.visible = false
	_context.text = ""
	_you.text = "You: %s" % str(reply.text)
	_you.visible = true
	_said_left = SAID_SECONDS
	MHAudio.sfx("suit_beep", -14.0)
	if notes != null and reply.has("note"): notes.take_up(str(reply.note), str(reply.get("said", "")))
	if bool(entry.get("text", false)):
		MHNotices.post("info", "You, to %s" % str(entry.who), str(reply.text), "comms")
		if reply.has("answer"): _answers.append([ANSWER_AFTER, id + "_answer", str(entry.get("sender", "castellanos")), str(reply.answer)])

func showing() -> bool:
	return not _shown.is_empty()

func export_state() -> Dictionary:
	return {"answered": answered.duplicate(), "answers": _answers.duplicate(true)}
