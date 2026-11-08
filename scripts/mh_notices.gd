class_name MHNotices
extends Node

## Every piece of news, one way (docs/pda.md §4–5): a core's result, a storm
## forecast, a task done, something GAR-Y found, a thought of your own. Each
## notice shows in one box under the compass, one at a time, long enough to
## read, and goes into the slate's Log (scripts/pda.gd), so nothing you
## missed is lost. The app it names (notes, map, base, comms, site, log) is
## where its details live, and gets an unread dot on the slate.
##
## Readable (playtest 8 Nov): big text that wraps instead of being cut off,
## and a hold of about four seconds plus reading time. Who's talking is a
## plain heading and an icon in the same box for everyone: "You think…"
## (your own thought), "Castellanos, from orbit", ARDEN. What matters stands
## out: a pressing notice (warn or danger, or a pressing thought) has an
## amber edge, goes ahead of the queue and stays up longer. Chatter that only
## repeats something can go to the Log alone (screen = false).
##
## Not saved: a loaded game starts with an empty log.

const TOP := 150.0      # under the compass and the sol clock
const WIDTH := 820.0    # the box wraps its text at this width
const HEADING_SIZE := 18
const BODY_SIZE := 17
const KEEP := 200       # notices kept in the log
const HOLD_MIN := 4.0   # seconds on screen, plus reading time
const HOLD_MAX := 10.0
const PRESSING_EXTRA := 2.0
const BACKLOG := 4      # this many waiting and the shown one goes after HOLD_MIN

## Headings that say who's talking (the box's icon comes from these).
const YOU_THINK := "You think…"

static var history: Array = []     # newest last: {tone, heading, text, app, time, pressing}
static var unread: Dictionary = {} # app -> count
static var hidden := false         # while the slate is up: the queue waits
static var _line: MHNotices

var _queue: Array = []
var _shown: Control
var _shown_entry: Dictionary = {}
var _age := 0.0
var _hold := 0.0
var _layer: CanvasLayer

## Starts a fresh log for a world, with its notice line (mars_world._build_hud).
static func attach(world: Node) -> void:
	history.clear()
	unread.clear()
	hidden = false
	_line = MHNotices.new()
	_line.name = "NoticeLine"
	world.add_child(_line)

## Posts a notice. tone: info, valid, warn, danger, invalid (MHStyle.notice).
## pressing: -1 works it out from the tone (warn and danger are pressing),
## 0 or 1 says so. screen = false puts it in the Log only (chatter that just
## repeats something you already know).
static func post(tone: String, heading: String, text: String, app := "log", pressing := -1, screen := true) -> void:
	var urgent := (tone in ["warn", "danger"]) if pressing < 0 else pressing > 0
	var entry := {"tone": tone, "heading": heading, "text": text, "app": app, "time": MHGame.formatted_sol_time(), "pressing": urgent}
	history.append(entry)
	while history.size() > KEEP: history.pop_front()
	unread[app] = int(unread.get(app, 0)) + 1
	if app != "log": unread["log"] = int(unread.get("log", 0)) + 1
	if screen and _line != null and is_instance_valid(_line): _line._enqueue(entry)

## The slate opened an app: its dot goes.
static func seen(app: String) -> void:
	unread.erase(app)

## MHStyle colours by tone (for callers that only have a Color).
static func tone_of(colour: Color) -> String:
	if colour == MHStyle.DANGER: return "danger"
	if colour == MHStyle.WARN: return "warn"
	if colour == MHStyle.VALID: return "valid"
	return "info"

## Who's talking, as an icon: your own thought, someone in orbit or on
## Earth, the habitat's voice; otherwise the tone's own mark.
static func glyph_for(entry: Dictionary) -> String:
	var heading := str(entry.get("heading", ""))
	if heading == YOU_THINK: return "pencil"
	if heading.ends_with("from orbit") or heading.begins_with("Message from"): return "satellite"
	if heading == MHGame.habitat_name: return "volume-2"
	return {"invalid": "circle-x", "danger": "circle-x", "warn": "triangle-alert", "valid": "circle-check"}.get(str(entry.get("tone", "info")), "info")

## Seconds a notice stays up: long enough to read it.
static func hold_for(entry: Dictionary) -> float:
	var length := float(str(entry.get("text", "")).length() + str(entry.get("heading", "")).length())
	var hold := minf(HOLD_MIN + length / 40.0, HOLD_MAX)
	return hold + PRESSING_EXTRA if bool(entry.get("pressing", false)) else hold

func _enqueue(entry: Dictionary) -> void:
	# The same words twice in a row are said once.
	for waiting in _queue:
		if str(waiting.heading) == str(entry.heading) and str(waiting.text) == str(entry.text): return
	if bool(entry.get("pressing", false)):
		# Ahead of everything that isn't pressing, behind what already is.
		_queue.insert(_after_pressing(), entry)
	else:
		_queue.append(entry)

## Where ordinary news starts in the queue.
func _after_pressing() -> int:
	var at := 0
	while at < _queue.size() and bool(_queue[at].get("pressing", false)): at += 1
	return at

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 7
	add_child(_layer)

func _process(delta: float) -> void:
	if _shown != null:
		_age += delta
		if hidden:
			# The slate came up over it: it waits its turn again if it was
			# barely read.
			if _age < _hold * .5: _queue.insert(0 if bool(_shown_entry.get("pressing", false)) else _after_pressing(), _shown_entry)
			_fade_out()
		elif _age >= _hold or _cut_short():
			_fade_out()
	if _shown == null and not _queue.is_empty() and not hidden:
		_show(_queue.pop_front())

## A pressing notice is waiting behind ordinary news, or a long backlog: the
## shown one goes once it's had its basic time.
func _cut_short() -> bool:
	if _age < HOLD_MIN or _queue.is_empty(): return false
	if bool(_queue[0].get("pressing", false)) and not bool(_shown_entry.get("pressing", false)): return true
	return _queue.size() >= BACKLOG

func _show(entry: Dictionary) -> void:
	var tone := str(entry.tone)
	var pressing := bool(entry.get("pressing", false))
	var colour := MHStyle.tone_colour(tone)
	if pressing and tone in ["info", "valid"]: colour = MHStyle.WARN
	var panel := PanelContainer.new()
	panel.name = "Notice"
	panel.theme = MHStyle.theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := MHStyle.hud_box(14, true)
	style.border_color = Color(colour, .9 if pressing else .55)
	if pressing:
		style.border_width_left = 5   # the amber edge: this one matters
	style.content_margin_top = 10
	style.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", style)
	var column := MHStyle.vbox(4)
	var row := MHStyle.hbox(10)
	row.add_child(MHStyle.icon(glyph_for(entry), 20, colour))
	row.add_child(MHStyle.label(str(entry.heading), HEADING_SIZE, MHStyle.TEXT_PRIMARY, 700))
	column.add_child(row)
	var text := str(entry.text)
	# Short news fits snugly, centred; longer news wraps (never clipped) in
	# a box WIDTH wide.
	var wide := MHStyle.font(400).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_SIZE).x + 40.0 > WIDTH
	if not text.is_empty():
		var body := MHStyle.body(text, BODY_SIZE, MHStyle.TEXT_PRIMARY if pressing else MHStyle.TEXT_SECONDARY)
		body.name = "Body"
		body.clip_text = false
		body.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		if wide:
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			body.autowrap_mode = TextServer.AUTOWRAP_OFF
		column.add_child(body)
	panel.add_child(column)
	panel.anchor_left = .5
	panel.anchor_right = .5
	panel.offset_left = -WIDTH / 2.0 if wide else 0.0
	panel.offset_right = WIDTH / 2.0 if wide else 0.0
	panel.offset_top = TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, .2)
	_shown = panel
	_shown_entry = entry
	_age = 0.0
	_hold = hold_for(entry)

func _fade_out() -> void:
	var going := _shown
	_shown = null
	_shown_entry = {}
	var fade := going.create_tween()
	fade.tween_property(going, "modulate:a", 0.0, .25)
	fade.tween_callback(going.queue_free)
