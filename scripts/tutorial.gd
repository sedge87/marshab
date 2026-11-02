extends CanvasLayer

## ARDEN's getting-started tutorial (docs/tutorial-design.md), for Survival,
## Freedom and Creative when the player chose Tutorial: Full. Missions mode
## doesn't use this: its own step tracker (mission_hud.gd) carries the same
## guidance.
##
## A checklist of goals (2 Nov): each goal ("Set up camp", "Your first
## module", ...) shows all its tasks at once at the top right, and they tick
## themselves off in any order from what you actually do. The next task gets
## its how-to and keys, its button a pulsing outline, its place in the world a
## compass marker, and P plays a clip of it. Under chapter rules it carries on
## into chapter one's goal, Self-sufficient (ice, water, oxygen, food). While
## building, a slim pill sits above the build bar on the right. H cycles the
## checklist full, folded, hidden (Settings, On screen, remembers it).
const STEPS_PATH := "res://data/tutorial.json"
const MHMissions := preload("res://scripts/mh_missions.gd")
const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
const GUIDE := preload("res://scripts/guide_overlay.gd")

var world: Node
var done: Array = []
var _steps: Array = []
var _panel: PanelContainer
var _body: VBoxContainer
var _pill: PanelContainer
var _pill_body: VBoxContainer
var _toast: PanelContainer
var _marker: Node3D
var guide: CanvasLayer
var _check_in := 0.0
var _shown_step := ""
var _shown_inside := false
## The view shown (full, folded or hidden), to redraw when it changes.
var _shown_view := ""
# "moved": how far you've walked and turned since the step came up.
var _walked := 0.0
var _turned := 0.0
var _last_position := Vector3.INF
var _last_yaw := 0.0
var _read_pressed := false
var finished := false

## The steps for this game mode.
static func steps() -> Array:
	var all: Array = _data().get("steps", [])
	return all.filter(func(step): return (not step.has("modes") or (step.modes as Array).has(MHGame.game_mode)) and _rules_fit(step) and (not bool(step.get("needs_food", false)) or MHGame.needs_food_water()) and (not bool(step.get("needs_sim", false)) or MHGame.simulation_on()))

## The goals in order: [{id, title}].
static func goals() -> Array:
	return _data().get("goals", [])

static func _data() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STEPS_PATH))
	return parsed if parsed is Dictionary else {}

## Full, folded (the goal line only) or hidden (Settings, On screen; H cycles it).
static func view() -> String:
	var value := str(MHGame.setting("checklist"))
	return value if value in ["full", "folded", "hidden"] else "full"

## Chapter-one steps (unpacking, the fabricator) or the older ones (drill, Life Support).
static func _rules_fit(step: Dictionary) -> bool:
	match str(step.get("rules", "")):
		"chapter": return MHChapterOne.on()
		"classic": return not MHChapterOne.on()
	return true

func setup(target_world: Node, state: Dictionary) -> void:
	world = target_world
	done = (state.get("done", []) as Array).duplicate()
	_steps = steps()

func export_state() -> Dictionary:
	return {"mode": "full", "done": done.duplicate()}

func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	guide = GUIDE.new()
	add_child(guide)
	_panel = MHStyle.hud_panel(18, false, true)
	_panel.anchor_left = 1
	_panel.anchor_right = 1
	_panel.offset_left = -444
	_panel.offset_right = -104
	_panel.offset_top = 104
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = MHStyle.theme()
	_body = MHStyle.vbox(8)
	_panel.add_child(_body)
	add_child(_panel)
	_pill = MHStyle.hud_panel(12, false, true)
	# While building: bottom right, above the build bar, clear of the notices.
	_pill.anchor_left = 1
	_pill.anchor_right = 1
	_pill.anchor_top = 1
	_pill.anchor_bottom = 1
	_pill.offset_right = -48
	_pill.offset_bottom = -340
	_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pill.custom_minimum_size = Vector2(360, 0)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.theme = MHStyle.theme()
	_pill_body = MHStyle.vbox(4)
	_pill.add_child(_pill_body)
	add_child(_pill)
	finished = current().is_empty()
	_refresh()

## The goal being worked on: the first with a task not done ("" when all are).
func current_goal() -> String:
	for step in _steps:
		if not done.has(str(step.id)): return str(step.get("goal", ""))
	return ""

## A goal's tasks, in order (the current goal's by default).
func goal_steps(goal := "") -> Array:
	var id := goal if not goal.is_empty() else current_goal()
	return _steps.filter(func(step): return str(step.get("goal", "")) == id)

## The next task: the first not done in the current goal ({} when all are).
func current() -> Dictionary:
	for step in goal_steps():
		if not done.has(str(step.id)): return step
	return {}

func _goal_title(goal: String) -> String:
	for g in goals():
		if str(g.id) == goal: return str(g.title)
	return "Getting started"

func _building() -> bool:
	return bool(world.builder.build_mode) or (world.interior_builder != null and bool(world.interior_builder.active))

func _process(delta: float) -> void:
	if world == null or world.player == null: return
	# (Shown in the lander's minimal HUD too: that's where step 1 happens.)
	var overlay_open: bool = world.pause_menu != null or world.mission_control != null or world.monitor != null
	var shown := not finished and not overlay_open and view() != "hidden"
	_panel.visible = shown and not _building()
	_pill.visible = shown and _building()
	_track_movement()
	_check_in -= delta
	if _check_in > 0.0: return
	_check_in = .25
	if finished: return
	var advanced := false
	# Tick any of the current goal's tasks, in any order; a finished goal
	# moves on to the next (whose tasks may be done already: built ahead).
	var goal := current_goal()
	while not goal.is_empty():
		for step in goal_steps(goal):
			if done.has(str(step.id)) or not _met(step): continue
			done.append(str(step.id))
			advanced = true
			if str((step.get("check", {}) as Dictionary).get("type", "")) == "read": _read_pressed = false
			_step_done(step, goal)
		if current_goal() == goal: break
		goal = current_goal()
	if advanced and current_goal().is_empty(): _finish()
	var next := current()
	if advanced or str(next.get("id", "")) != _shown_step or _building() != _shown_inside or view() != _shown_view: _refresh()

func _track_movement() -> void:
	var player: Node3D = world.player
	if not is_inf(_last_position.x):
		var step_moved := Vector2(player.global_position.x - _last_position.x, player.global_position.z - _last_position.z).length()
		if step_moved < 2.0: _walked += step_moved   # not teleports
		_turned += absf(wrapf(player.rotation.y - _last_yaw, -PI, PI))
	_last_position = player.global_position
	_last_yaw = player.rotation.y

## Is this step's check met by what's in the world now?
func _met(step: Dictionary) -> bool:
	var check: Dictionary = step.get("check", {})
	var builder: Node = world.builder
	match str(check.get("type", "")):
		"moved": return _walked >= 3.0 and _turned >= 1.2
		"left_lander":
			var lander: Node3D = world.lander
			if lander == null or not bool(lander.get("present")): return true
			return lander.hatch_open() and not lander.cabin_contains(world.player.global_position)
		"build_mode": return bool(builder.build_mode)
		"interior_mode": return world.interior_builder != null and bool(world.interior_builder.active)
		"zone": return builder.zones.any(func(z): return str(z.kind) == str(check.kind))
		"inside": return not _building() and bool(builder.is_inside(world.player.global_position))
		"items":
			for id in check.get("ids", []):
				if not builder.placed_interior.any(func(i): return str(i.get("id", "")) == str(id)): return false
			return true
		"read": return _read_pressed
		"unpacked": return MHChapterOne.crates_left() == 0
		"fab_job": return MHChapterOne.printing() or MHChapterOne.known.has("spare_parts_rack")
		"chapter_step": return MHChapterOne.steps.has(str(check.step))
		"flag": return bool((world.guide_flags as Dictionary).get(str(check.key), false))
	return false

func _step_done(step: Dictionary, goal: String) -> void:
	MHAudio.sfx("ui_confirm", -4.0)
	var goal_done := goal_steps(goal).all(func(s): return done.has(str(s.id)))
	if goal_done: _show_toast(_goal_title(goal), "Goal done" if not current_goal().is_empty() else "Checklist complete")
	else: _show_toast(str(step.text), "Done")
	if not str(step.get("said", "")).is_empty(): MHAudio.voice(str(step.said))

func _finish() -> void:
	finished = true
	guide.set_highlight([])
	_set_marker("")
	var values := MHGame.settings()
	values["tutorial_finished"] = true
	MHGame.save_settings(values)

func _unhandled_input(event: InputEvent) -> void:
	if finished or not (event is InputEventKey and event.pressed and not event.echo) or event.ctrl_pressed: return
	if get_tree().paused: return
	var step := current()
	match event.keycode:
		KEY_P:
			if GUIDE.has_clip(str(step.get("clip", ""))):
				guide.show_clip(str(step.clip), str(step.text), step.get("keys", []))
				get_viewport().set_input_as_handled()
		KEY_H:
			if _building(): return
			var values := MHGame.settings()
			values["checklist"] = {"full": "folded", "folded": "hidden"}.get(view(), "full")
			MHGame.save_settings(values)
			_refresh()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			var reading := goal_steps().any(func(s): return not done.has(str(s.id)) and str((s.get("check", {}) as Dictionary).get("type", "")) == "read")
			if reading and not _building():
				_read_pressed = true
				_check_in = 0.0
				get_viewport().set_input_as_handled()

# ---------- what's on screen ----------

func _refresh() -> void:
	var step := current()
	_shown_step = str(step.get("id", ""))
	_shown_inside = _building()
	_shown_view = view()
	for child in _body.get_children(): child.queue_free()
	for child in _pill_body.get_children(): child.queue_free()
	if step.is_empty(): return
	var goal := current_goal()
	var tasks := goal_steps(goal)
	var ticked := tasks.filter(func(s): return done.has(str(s.id))).size()
	var used: Array = goals().map(func(g): return str(g.id)).filter(func(id): return _steps.any(func(s): return str(s.get("goal", "")) == id))
	var clip := GUIDE.has_clip(str(step.get("clip", "")))
	var folded := view() == "folded"
	_body.add_child(MHStyle.eyebrow("%s · Goal %d of %d · %d of %d done" % [MHGame.habitat_name, used.find(goal) + 1, used.size(), ticked, tasks.size()], MHStyle.accent, 11))
	_body.add_child(MHStyle.title(_goal_title(goal), 19))
	if not folded:
		for task in tasks:
			var is_done := done.has(str(task.id))
			var is_next := str(task.id) == str(step.id)
			var row := MHStyle.hbox(8)
			row.add_child(MHStyle.icon("circle-check" if is_done else ("circle-arrow-right" if is_next else "circle-dashed"), 16, MHStyle.VALID if is_done else (MHStyle.accent if is_next else MHStyle.TEXT_MUTED)))
			row.add_child(_wrapped(str(task.text), 15, MHStyle.TEXT_MUTED if is_done else (MHStyle.TEXT_PRIMARY if is_next else MHStyle.TEXT_SECONDARY), 290))
			_body.add_child(row)
			if is_next:
				var indent := MarginContainer.new()
				indent.add_theme_constant_override("margin_left", 24)
				var detail := MHStyle.vbox(6)
				detail.add_child(_wrapped(str(task.get("how", "")), 13, MHStyle.TEXT_SECONDARY, 290))
				if not (task.get("keys", []) as Array).is_empty(): detail.add_child(GUIDE.keys_box(task.keys))
				indent.add_child(detail)
				_body.add_child(indent)
	var foot: Array = []
	if clip and not folded: foot.append("P SHOW ME")
	foot.append("H " + str({"full": "FOLD", "folded": "HIDE"}.get(view(), "SHOW")))
	_body.add_child(MHStyle.mono("  ·  ".join(foot), 11, MHStyle.TEXT_MUTED))
	# While building: the pill, above the build bar on the right.
	_pill_body.add_child(MHStyle.eyebrow("%s · %s · %d of %d" % [MHGame.habitat_name, _goal_title(goal), ticked, tasks.size()], MHStyle.accent, 11))
	_pill_body.add_child(_wrapped(str(step.text), 15, MHStyle.TEXT_PRIMARY, 330))
	if not folded:
		_pill_body.add_child(_wrapped(str(step.get("how", "")), 13, MHStyle.TEXT_SECONDARY, 330))
		if clip: _pill_body.add_child(MHStyle.mono("P SHOW ME", 11, MHStyle.TEXT_MUTED))
	guide.set_highlight(step.get("highlight", []))
	_set_marker(str(step.get("marker", "")))

func _wrapped(text: String, size: int, colour: Color, width := 380.0) -> Label:
	var label := MHStyle.body(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label

func _show_toast(text: String, heading: String) -> void:
	if _toast != null: _toast.queue_free()
	_toast = MHStyle.hud_panel(12, false, true)
	_toast.theme = MHStyle.theme()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Beside the checklist, clear of the notices in the middle: under the
	# panel while walking about, above the pill while building.
	_toast.anchor_left = 1
	_toast.anchor_right = 1
	_toast.offset_left = -444
	_toast.offset_right = -104
	if _building():
		_toast.anchor_top = 1
		_toast.anchor_bottom = 1
		_toast.offset_right = -48
		_toast.offset_left = -408
		_toast.offset_bottom = _pill.offset_bottom - (_pill.size.y + 12.0 if _pill.visible else 0.0)
		_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		_toast.offset_top = _panel.get_rect().end.y + 12.0 if _panel.visible else 104.0
	var row := MHStyle.hbox(10)
	row.add_child(MHStyle.icon("circle-check", 22, MHStyle.VALID))
	var words := MHStyle.vbox(2)
	words.add_child(MHStyle.eyebrow(heading, MHStyle.VALID, 11))
	var label := MHStyle.body(text, 16, MHStyle.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 280
	words.add_child(label)
	row.add_child(words)
	_toast.add_child(row)
	add_child(_toast)
	var fade := _toast.create_tween()
	fade.tween_interval(2.6)
	fade.tween_property(_toast, "modulate:a", 0.0, .5)
	fade.tween_callback(_toast.queue_free)

## A compass landmark for the step: the lander, the base, ice or the airlock.
func _set_marker(kind: String) -> void:
	var at := Vector2.INF
	var label := ""
	var builder: Node = world.builder
	match kind:
		"lander":
			if world.lander != null and bool(world.lander.get("present")):
				var by: Vector3 = world.lander.beside_ramp()
				at = Vector2(by.x, by.z)
				label = "LANDER HATCH"
		"base":
			at = _base()
			label = "BUILD HERE"
		"ice":
			var found := ICE_KNOWLEDGE.best_found(get_tree())
			if not found.is_empty() and float(found.richness) >= ICE_KNOWLEDGE.WORTH_DRILLING:
				at = found.at
			else:
				var zone := ICE_KNOWLEDGE.nearest_zone(_base())
				if not zone.is_empty(): at = zone.centre
			label = "ICE"
		"airlock":
			for zone in builder.zones:
				if str(zone.kind) != "airlock": continue
				var cell: Vector2i = (zone.cells as Array)[0]
				at = Vector2(cell) * BuildController.CELL
				label = "AIRLOCK"
				break
	if is_inf(at.x):
		if _marker != null:
			_marker.queue_free()
			_marker = null
		return
	if _marker == null:
		_marker = Node3D.new()
		_marker.add_to_group("landmark")
		world.add_child(_marker)
	_marker.set_meta("landmark_label", label)
	_marker.global_position = Vector3(at.x, 0, at.y)

## Where the base is (its first room), or the middle of the site before
## anything is built (the lander stands about 20 m from it).
func _base() -> Vector2:
	for zone in world.builder.zones:
		if world.builder._is_habitat_zone(zone):
			var cell: Vector2i = (zone.cells as Array)[0]
			return Vector2(cell) * BuildController.CELL
	return Vector2.ZERO
