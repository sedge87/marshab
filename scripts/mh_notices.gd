class_name MHNotices
extends Node

## Every piece of news, one way (docs/pda.md §4–5): a core's result, a storm
## forecast, a task done, something GAR-Y found. Each notice shows as one line
## under the compass for a few seconds, one at a time, and goes into the
## slate's Log (scripts/pda.gd), so nothing you missed is lost. The app it
## names (goals, map, base, comms, site, log) is where its details live, and
## gets an unread dot on the slate.
##
## Not saved: a loaded game starts with an empty log.

const TOP := 150.0      # under the compass and the sol clock
const WIDTH := 760.0
const KEEP := 200       # notices kept in the log

static var history: Array = []     # newest last: {tone, heading, text, app, time}
static var unread: Dictionary = {} # app -> count
static var hidden := false         # while the slate is up (its Log shows them)
static var _line: MHNotices

var _queue: Array = []
var _shown: Control
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
static func post(tone: String, heading: String, text: String, app := "log") -> void:
	var entry := {"tone": tone, "heading": heading, "text": text, "app": app, "time": MHGame.formatted_sol_time()}
	history.append(entry)
	while history.size() > KEEP: history.pop_front()
	unread[app] = int(unread.get(app, 0)) + 1
	if app != "log": unread["log"] = int(unread.get("log", 0)) + 1
	if _line != null and is_instance_valid(_line): _line._queue.append(entry)

## The slate opened an app: its dot goes.
static func seen(app: String) -> void:
	unread.erase(app)

## MHStyle colours by tone (for callers that only have a Color).
static func tone_of(colour: Color) -> String:
	if colour == MHStyle.DANGER: return "danger"
	if colour == MHStyle.WARN: return "warn"
	if colour == MHStyle.VALID: return "valid"
	return "info"

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 7
	add_child(_layer)

func _process(delta: float) -> void:
	if _shown != null:
		_age += delta
		# Hurry along when more is waiting, but give each a couple of seconds.
		if _age >= _hold or hidden or (not _queue.is_empty() and _age >= 2.5):
			_fade_out()
	if _shown == null and not _queue.is_empty() and not hidden:
		_show(_queue.pop_front())
	elif hidden and not _queue.is_empty():
		_queue.clear()   # the slate's Log has them

func _show(entry: Dictionary) -> void:
	var tone := str(entry.tone)
	var colour := MHStyle.tone_colour(tone)
	var panel := PanelContainer.new()
	panel.theme = MHStyle.theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := MHStyle.hud_box(10, true)
	style.border_color = Color(colour, .55)
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	var row := MHStyle.hbox(10)
	var glyph: String = {"invalid": "circle-x", "danger": "circle-x", "warn": "triangle-alert", "valid": "circle-check"}.get(tone, "info")
	row.add_child(MHStyle.icon(glyph, 18, colour))
	row.add_child(MHStyle.label(str(entry.heading), 15, MHStyle.TEXT_PRIMARY, 700))
	var text := str(entry.text)
	# Long news is cut short here (the line is full width); the whole of it
	# is in the slate's Log. Short news fits snugly, centred.
	var long := text.length() + str(entry.heading).length() > 80
	if not text.is_empty():
		var body := MHStyle.body(text, 14, MHStyle.TEXT_SECONDARY)
		body.autowrap_mode = TextServer.AUTOWRAP_OFF   # one line, always
		if long:
			body.clip_text = true
			body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)
	if long: row.add_child(MHStyle.mono("TAB", 11, MHStyle.TEXT_MUTED, 700))
	panel.add_child(row)
	panel.anchor_left = .5
	panel.anchor_right = .5
	panel.offset_left = -WIDTH / 2.0 if long else 0.0
	panel.offset_right = WIDTH / 2.0 if long else 0.0
	panel.offset_top = TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, .2)
	_shown = panel
	_age = 0.0
	_hold = clampf(3.0 + float(text.length() + str(entry.heading).length()) / 45.0, 3.5, 7.0)

func _fade_out() -> void:
	var going := _shown
	_shown = null
	var fade := going.create_tween()
	fade.tween_property(going, "modulate:a", 0.0, .25)
	fade.tween_callback(going.queue_free)
