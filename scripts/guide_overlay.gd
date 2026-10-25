extends CanvasLayer

## ARDEN's pointers, shared by the tutorial (scripts/tutorial.gd) and the
## mission tracker (scripts/mission_hud.gd): a pulsing outline round the
## button or panel a step needs, key caps for a step, and "Show me": a short
## looping clip of the real game doing the step (assets/tutorial/clips).
##
## Buttons opt in by joining the "tutorial_target" group with a
## "tutorial_target" meta (part:<kind>, tab:<category>, item:<id>,
## group:<tab>, systems), so moving a button never breaks a step.

const CLIP_DIR := "res://assets/tutorial/clips/"

var _wanted: Array = []
var _frame: Control
var _clip_layer: Control
var _pulse := 0.0

func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame = Highlight.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)

## Outline the first visible target in `names` (in order of preference);
## an empty list clears it.
func set_highlight(names: Array) -> void:
	_wanted = names.duplicate()
	if _wanted.is_empty(): _frame.visible = false

## The control a target name points at, if one is on screen now.
static func find_target(tree: SceneTree, target_name: String) -> Control:
	for node in tree.get_nodes_in_group("tutorial_target"):
		var control := node as Control
		if control == null or str(control.get_meta("tutorial_target", "")) != target_name: continue
		if control.is_visible_in_tree() and control.get_global_rect().size.x > 2.0: return control
	return null

func _process(delta: float) -> void:
	_pulse += delta
	if _wanted.is_empty() or _clip_layer != null:
		_frame.visible = false
		return
	var target: Control = null
	for target_name in _wanted:
		target = find_target(get_tree(), str(target_name))
		if target != null: break
	_frame.visible = target != null
	if target == null: return
	var rect := target.get_global_rect().grow(6.0)
	_frame.position = rect.position
	_frame.size = rect.size
	(_frame as Highlight).pulse = _pulse
	_frame.queue_redraw()

## A pulsing accent outline with a "HERE" tag above it.
class Highlight extends Control:
	var pulse := 0.0
	func _draw() -> void:
		var glow := .55 + .45 * sin(pulse * 5.0)
		var colour := Color(MHStyle.accent, glow)
		draw_style_box(MHStyle.box(Color(MHStyle.accent, .08 * glow), colour, 10, 3), Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var tag := "HERE"
		var width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
		var top := -28.0 - 4.0 * sin(pulse * 5.0)
		draw_style_box(MHStyle.box(MHStyle.accent, Color(0, 0, 0, 0), 6, 0), Rect2(Vector2(size.x * .5 - width * .5, top), Vector2(width, 22)))
		draw_string(font, Vector2(size.x * .5 - width * .5 + 8.0, top + 16.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MHStyle.INK_900)

# ---------- a step's extras ----------

## Zone kinds with their own Show me clip (the rest use a similar one).
const ZONE_CLIPS := {"living": "living", "airlock": "airlock", "solar": "solar", "ice_extractor": "drill", "life_support": "life_support"}

## Keys, highlight targets and clip for a step (tutorial or mission). A
## step can name its own; otherwise they follow from what it checks.
static func step_extras(step: Dictionary) -> Dictionary:
	var check = step.get("check", "")
	var type := str(check.get("type", "")) if check is Dictionary else str(check)
	var keys: Array = []
	var highlight: Array = []
	var clip := ""
	match type:
		"left_lander": keys = [[["E"], "Use"]]
		"opened_plan", "build_mode":
			keys = [[["B"], "Site plan"]]
			clip = "plan"
		"zone":
			var kind := str(step.get("kind", check.get("kind", "") if check is Dictionary else ""))
			keys = [[["B"], "Site plan"], [["LMB"], "Place · drag"], [["R"], "Turn"]]
			var category := str((BuildController.ZONE_INFO.get(kind, {}) as Dictionary).get("cat", ""))
			highlight = ["part:" + kind, "tab:" + category]
			clip = str(ZONE_CLIPS.get(kind, "living" if category == "rooms" else ""))
		"item", "item_any", "redundant", "items":
			keys = [[["B"], "Furnish (in the room)"], [["LMB"], "Place"], [["R"], "Turn"]]
			var ids: Array = [step.item] if step.has("item") else step.get("items", check.get("ids", []) if check is Dictionary else [])
			for id in ids: highlight.append("item:" + str(id))
			highlight.append("group:here")
			clip = "bunk"
		"inside":
			keys = [[["E"], "Open a door"]]
			clip = "go_in"
		"counter":
			if str(step.get("key", "")) == "gar_y_surveys":
				keys = [[["Hold", "G"], "GAR-Y orders"]]
				clip = "gar_y"
		"tested", "passed":
			keys = [[["T"], "Test"], [["J"], "Brief · versions"]]
			clip = "test" if type == "tested" else ""
		"crew_named", "needs", "flag":
			keys = [[["C"], "Crew screen"]]
			clip = "crew"
		"moved":
			keys = [[["Mouse"], "Look"], [["W", "A", "S", "D"], "Walk"], [["Shift"], "Sprint"]]
			clip = "move"
	return {
		"keys": step.get("keys", keys),
		"highlight": step.get("highlight", highlight),
		"clip": str(step.get("clip", clip)),
	}

# ---------- key caps ----------

## A step's keys as compact control rows ([[caps], action] pairs).
static func keys_box(keys: Array) -> VBoxContainer:
	var column := MHStyle.vbox(0)
	for row in keys:
		column.add_child(MHStyle.control_row(row[0] as Array, str(row[1]), true))
	return column

# ---------- Show me ----------

static func has_clip(clip: String) -> bool:
	return not clip.is_empty() and ResourceLoader.exists(CLIP_DIR + clip + ".ogv")

func clip_open() -> bool:
	return _clip_layer != null

## The clip, looping, over a dimmed and paused game, with its keys under it.
## P, Esc or a click closes it.
func show_clip(clip: String, title: String, keys: Array = []) -> void:
	if not has_clip(clip) or _clip_layer != null: return
	var stream := load(CLIP_DIR + clip + ".ogv") as VideoStream
	if stream == null: return
	_clip_layer = Control.new()
	_clip_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip_layer.theme = MHStyle.theme()
	_clip_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_clip_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, .62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip_layer.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_layer.add_child(centre)
	var panel := MHStyle.hud_panel(18, false, true)
	centre.add_child(panel)
	var column := MHStyle.vbox(12)
	panel.add_child(column)
	column.add_child(MHStyle.eyebrow("%s · Show me" % MHGame.habitat_name, MHStyle.accent, 12))
	column.add_child(MHStyle.title(title, 22))
	var player := VideoStreamPlayer.new()
	player.stream = stream
	player.custom_minimum_size = Vector2(960, 540)
	player.expand = true
	player.loop = true
	player.autoplay = true
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	column.add_child(player)
	var foot := MHStyle.hbox(24)
	if not keys.is_empty(): foot.add_child(keys_box(keys))
	foot.add_child(MHStyle.spacer())
	var close := MHStyle.mono("P · ESC  CLOSE", 12, MHStyle.TEXT_MUTED)
	close.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(close)
	column.add_child(foot)
	_clip_layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: close_clip())
	_was_paused = get_tree().paused
	_mouse_was = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MHAudio.sfx("ui_open", -6.0)

var _was_paused := false
var _mouse_was := Input.MOUSE_MODE_VISIBLE

func close_clip() -> void:
	if _clip_layer == null: return
	_clip_layer.queue_free()
	_clip_layer = null
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_was
	MHAudio.sfx("ui_close", -6.0)

func _input(event: InputEvent) -> void:
	if _clip_layer == null: return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_P or event.keycode == KEY_ESCAPE):
		close_clip()
		get_viewport().set_input_as_handled()
