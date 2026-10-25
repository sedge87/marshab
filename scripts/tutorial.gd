extends CanvasLayer

## ARDEN's getting-started tutorial (docs/tutorial-design.md), for Survival,
## Freedom and Creative when the player chose Tutorial: Full. Missions mode
## doesn't use this: its own step tracker (mission_hud.gd) carries the same
## guidance.
##
## It looks like the mission tracker: a panel at the top right with the
## current step (what to do, how, its keys), a "next step" pill while
## building, and a "Step done" toast as each step ticks itself off from what
## you actually do. The step's button gets a pulsing outline, its place in
## the world a compass marker, and P plays a clip of it being done. Steps
## already done when they come up are skipped. H folds the panel down.
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
## H folds the panel down to one line.
var _compact := false
# "moved": how far you've walked and turned since the step came up.
var _walked := 0.0
var _turned := 0.0
var _last_position := Vector3.INF
var _last_yaw := 0.0
var _read_pressed := false
var finished := false

## The steps for this game mode.
static func steps() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STEPS_PATH))
	var all: Array = (parsed as Dictionary).get("steps", []) if parsed is Dictionary else []
	return all.filter(func(step): return not step.has("modes") or (step.modes as Array).has(MHGame.game_mode))

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
	_panel.offset_left = -524
	_panel.offset_right = -104
	_panel.offset_top = 104
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = MHStyle.theme()
	_body = MHStyle.vbox(8)
	_panel.add_child(_body)
	add_child(_panel)
	_pill = MHStyle.hud_panel(12, false, true)
	_pill.position = Vector2(740, 128)   # top middle, clear of the plan key
	_pill.custom_minimum_size = Vector2(440, 0)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.theme = MHStyle.theme()
	_pill_body = MHStyle.vbox(4)
	_pill.add_child(_pill_body)
	add_child(_pill)
	finished = current().is_empty()
	_refresh()

## The first step not done yet ({} when the tutorial is over).
func current() -> Dictionary:
	for step in _steps:
		if not done.has(str(step.id)): return step
	return {}

func _building() -> bool:
	return bool(world.builder.build_mode) or (world.interior_builder != null and bool(world.interior_builder.active))

func _process(delta: float) -> void:
	if world == null or world.player == null: return
	# (Shown in the lander's minimal HUD too: that's where step 1 happens.)
	var overlay_open: bool = world.pause_menu != null or world.mission_control != null or world.monitor != null
	_panel.visible = not finished and not _building() and not overlay_open
	_pill.visible = not finished and _building() and not overlay_open
	_track_movement()
	_check_in -= delta
	if _check_in > 0.0: return
	_check_in = .25
	if finished: return
	var step := current()
	var advanced := false
	# Tick the current step, then any later ones already done (built ahead).
	while not step.is_empty() and _met(step):
		done.append(str(step.id))
		advanced = true
		_step_done(step)
		step = current()
	if advanced:
		_walked = 0.0
		_turned = 0.0
		_read_pressed = false
		if step.is_empty(): _finish()
	if advanced or str(step.get("id", "")) != _shown_step or _building() != _shown_inside: _refresh()

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
		"flag": return bool((world.guide_flags as Dictionary).get(str(check.key), false))
	return false

func _step_done(step: Dictionary) -> void:
	MHAudio.sfx("ui_confirm", -4.0)
	_show_toast(str(step.text))
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
			_compact = not _compact
			_refresh()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if str((step.get("check", {}) as Dictionary).get("type", "")) == "read" and not _building():
				_read_pressed = true
				_check_in = 0.0
				get_viewport().set_input_as_handled()

# ---------- what's on screen ----------

func _refresh() -> void:
	var step := current()
	_shown_step = str(step.get("id", ""))
	_shown_inside = _building()
	for child in _body.get_children(): child.queue_free()
	for child in _pill_body.get_children(): child.queue_free()
	if step.is_empty(): return
	var number := _steps.find(step) + 1
	var clip := GUIDE.has_clip(str(step.get("clip", "")))
	_body.add_child(MHStyle.eyebrow("%s · Getting started · %d of %d" % [MHGame.habitat_name, number, _steps.size()], MHStyle.accent, 11))
	_body.add_child(MHStyle.title(str(step.text), 20))
	if not _compact:
		_body.add_child(_wrapped(str(step.get("how", "")), 14, MHStyle.TEXT_SECONDARY))
		if not (step.get("keys", []) as Array).is_empty(): _body.add_child(GUIDE.keys_box(step.keys))
	var foot: Array = []
	if clip: foot.append("P SHOW ME")
	foot.append("H SHOW" if _compact else "H HIDE")
	_body.add_child(MHStyle.mono("  ·  ".join(foot), 11, MHStyle.TEXT_MUTED))
	# While building: the pill, top left of the plan.
	_pill_body.add_child(MHStyle.eyebrow("%s · Step %d of %d" % [MHGame.habitat_name, number, _steps.size()], MHStyle.accent, 11))
	var title := _wrapped(str(step.text), 15, MHStyle.TEXT_PRIMARY, 410)
	_pill_body.add_child(title)
	_pill_body.add_child(_wrapped(str(step.get("how", "")), 13, MHStyle.TEXT_SECONDARY, 410))
	if clip: _pill_body.add_child(MHStyle.mono("P SHOW ME", 11, MHStyle.TEXT_MUTED))
	guide.set_highlight(step.get("highlight", []))
	_set_marker(str(step.get("marker", "")))

func _wrapped(text: String, size: int, colour: Color, width := 380.0) -> Label:
	var label := MHStyle.body(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label

func _show_toast(text: String) -> void:
	if _toast != null: _toast.queue_free()
	_toast = MHStyle.hud_panel(12, false, true)
	_toast.theme = MHStyle.theme()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.anchor_left = .5
	_toast.anchor_right = .5
	_toast.offset_left = -260
	_toast.offset_right = 260
	_toast.offset_top = 222   # under the alert row
	var row := MHStyle.hbox(10)
	row.add_child(MHStyle.icon("circle-check", 22, MHStyle.VALID))
	var words := MHStyle.vbox(2)
	words.add_child(MHStyle.eyebrow("Step done" if not current().is_empty() else "Tutorial complete", MHStyle.VALID, 11))
	var label := MHStyle.body(text, 16, MHStyle.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
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
