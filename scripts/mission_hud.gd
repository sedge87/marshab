extends CanvasLayer
const MHDossier := preload("res://scripts/mh_dossier.gd")

## Missions mode on screen: the mission panel (top right) with the step
## tracker (each step ticks itself off) and the requirements, a "next step"
## pill while building, a short brief card when a mission starts, the full
## brief and versions (J), and the Test (T): a fast-forward run with a
## report, reasons and graphs. See docs/missions-design.md.
const MHMissions := preload("res://scripts/mh_missions.gd")
const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")
const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
## ARDEN's pointers on each step: its keys, an outline round the button it
## needs (Tutorial: Full) and P to Show me a clip of it being done.
const GUIDE := preload("res://scripts/guide_overlay.gd")
var guide: CanvasLayer
var _walked := 0.0
var _turned := 0.0
var _last_position := Vector3.INF
var _last_yaw := 0.0

var world: Node
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _overlay: Control
var _last_report: Dictionary = {}
var _refresh_in := 0.0
var _steps_in := 0.0
var _next_pill: PanelContainer
var _next_label: Label
var _next_how: Label
var _toast: PanelContainer
var _marker: Node3D

## The mission this world was loaded for. Completing it moves the campaign
## on; if you keep building instead, the next one waits to be started (J).
var _loaded_mission := ""
## H folds the panel down to the mission and its next step (kept for the session).
static var _compact := false

func setup(target_world: Node) -> void:
	world = target_world
	_loaded_mission = str(MHMissions.current().get("id", ""))

func _next_mission_waiting() -> bool:
	return not _loaded_mission.is_empty() and str(MHMissions.current().get("id", "")) != _loaded_mission

func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = MHStyle.hud_panel(18, false, true)
	_panel.anchor_left = 1
	_panel.anchor_right = 1
	_panel.offset_left = -524
	_panel.offset_right = -104
	_panel.offset_top = 104
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = MHStyle.theme()
	_panel_body = MHStyle.vbox(8)
	_panel.add_child(_panel_body)
	add_child(_panel)
	guide = GUIDE.new()
	add_child(guide)
	# While building (the panel is hidden), a small pill keeps the next step in view.
	_next_pill = MHStyle.hud_panel(12, false, true)
	_next_pill.position = Vector2(740, 128)   # top middle, clear of the plan key
	_next_pill.custom_minimum_size = Vector2(440, 0)
	_next_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_pill.theme = MHStyle.theme()
	var pill_column := MHStyle.vbox(4)
	pill_column.add_child(MHStyle.eyebrow("Next step", MHStyle.accent, 11))
	_next_label = MHStyle.body("", 15, MHStyle.TEXT_PRIMARY)
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.custom_minimum_size.x = 410
	pill_column.add_child(_next_label)
	_next_how = MHStyle.body("", 13, MHStyle.TEXT_SECONDARY)
	_next_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_how.custom_minimum_size.x = 410
	pill_column.add_child(_next_how)
	_next_pill.add_child(pill_column)
	add_child(_next_pill)
	_update_steps()
	_refresh_panel()
	var mission := MHMissions.current()
	if not bool((MHMissions.progress.get("briefed", {}) as Dictionary).get(str(mission.id), false)):
		(MHMissions.progress.briefed as Dictionary)[str(mission.id)] = true
		# After the touchdown cinematic, or once the opening letterbox has slid
		# away (pausing would freeze it).
		if bool(world.arrival_pending): world.arrival_finished.connect(func() -> void: get_tree().create_timer(1.0).timeout.connect(_open_short_brief), CONNECT_ONE_SHOT)
		else: get_tree().create_timer(1.2).timeout.connect(_open_short_brief)

func _process(delta: float) -> void:
	var builder: Node = world.builder
	_panel.visible = _overlay == null and not bool(builder.build_mode) and not bool(world.explore_hud._minimal)
	_next_pill.visible = _overlay == null and not _panel.visible and not _next_label.text.is_empty()
	_track_movement()
	_steps_in -= delta
	if _steps_in <= 0.0:
		_steps_in = .4
		if _update_steps(): _refresh_in = 0.0
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = 1.0
		_refresh_panel()

# ---------- steps ----------

## Tick finished steps (a chime and a toast for each), point the compass at
## the next one, and keep the "next step" pill current. True if anything ticked.
func _update_steps() -> bool:
	var ticked: Array = MHMissions.update_steps(world.builder, world.mission_flags)
	for step in ticked:
		MHAudio.sfx("ui_confirm", -4.0)
		_show_toast(str(step.text))
	for step in MHMissions.last_unticked:
		# Something a finished step needed was removed: say so, and it's back
		# on the list until it's put right.
		MHAudio.sfx("warn", -2.0)
		var progress := MHMissions.step_progress(step, world.builder)
		_show_toast("%s%s" % [str(step.text), (" (now %s)" % progress) if not progress.is_empty() else ""], true)
	if not ticked.is_empty() or not MHMissions.last_unticked.is_empty(): world.save_mission_progress()
	var step := MHMissions.current_step()
	_next_label.text = "" if step.is_empty() else str(step.text)
	var extras := GUIDE.step_extras(step)
	_next_how.text = str(step.get("how", "")) + ("
P  SHOW ME" if GUIDE.has_clip(str(extras.clip)) else "")
	_set_marker(str(step.get("marker", "")))
	guide.set_highlight(extras.highlight if MHGame.tutorial_mode == "full" and not step.is_empty() else [])
	return not ticked.is_empty() or not MHMissions.last_unticked.is_empty()

## ARDEN's "look around and move" step: walked a few metres and turned.
func _track_movement() -> void:
	var player: Node3D = world.player
	if player == null or bool(world.mission_flags.get("moved", false)): return
	if not is_inf(_last_position.x):
		var moved := Vector2(player.global_position.x - _last_position.x, player.global_position.z - _last_position.z).length()
		if moved < 2.0: _walked += moved
		_turned += absf(wrapf(player.rotation.y - _last_yaw, -PI, PI))
	_last_position = player.global_position
	_last_yaw = player.rotation.y
	if _walked >= 3.0 and _turned >= 1.2: world.mission_flags["moved"] = true

## A compass landmark for the current step: the base site or the best ice.
func _set_marker(kind: String) -> void:
	var at := Vector2.INF
	var label := ""
	if kind == "base":
		at = MHMissions.base_site()
		label = "BASE SITE"
	elif kind == "ice":
		# What's known: GAR-Y's best find, else the likely zone nearest the base.
		var found := ICE_KNOWLEDGE.best_found(get_tree())
		if not found.is_empty() and float(found.richness) >= ICE_KNOWLEDGE.WORTH_DRILLING:
			at = found.at
			label = "BEST ICE FOUND"
		else:
			var near := MHMissions.base_site() if not is_inf(MHMissions.base_site().x) else Vector2.ZERO
			var zone := ICE_KNOWLEDGE.nearest_zone(near)
			if not zone.is_empty():
				at = zone.centre
				label = "LIKELY ICE"
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

func _show_toast(text: String, warning := false) -> void:
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
	var tone := MHStyle.WARN if warning else MHStyle.VALID
	row.add_child(MHStyle.icon("triangle-alert" if warning else "circle-check", 22, tone))
	var words := MHStyle.vbox(2)
	words.add_child(MHStyle.eyebrow("Step undone" if warning else "Step done", tone, 11))
	var label := MHStyle.body(text, 16, MHStyle.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(label)
	row.add_child(words)
	_toast.add_child(row)
	add_child(_toast)
	var fade := _toast.create_tween()
	fade.tween_interval(4.5 if warning else 2.6)
	fade.tween_property(_toast, "modulate:a", 0.0, .5)
	fade.tween_callback(_toast.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or event.ctrl_pressed: return
	if _overlay != null:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	if get_tree().paused: return
	if event.keycode == KEY_P:
		var step := MHMissions.current_step()
		var extras := GUIDE.step_extras(step)
		if GUIDE.has_clip(str(extras.clip)):
			guide.show_clip(str(extras.clip), str(step.text), extras.keys)
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T:
		if _next_mission_waiting(): _open_brief()   # start it first
		else: _run_test()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_J:
		_open_brief()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_K:
		var step_card := HOW_IT_WORKS.for_step(MHMissions.current_step())
		var all := HOW_IT_WORKS.for_mission(str(MHMissions.current().id))
		if not step_card.is_empty(): all.erase(step_card); all.push_front(step_card)
		HOW_IT_WORKS.show(get_tree(), all if not all.is_empty() else HOW_IT_WORKS.unlocked())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_H and not _next_mission_waiting():
		_compact = not _compact
		_refresh_panel()
		get_viewport().set_input_as_handled()

# ---------- the panel ----------

func _refresh_panel() -> void:
	for child in _panel_body.get_children(): child.queue_free()
	var mission := MHMissions.current()
	if _next_mission_waiting():
		_panel_body.add_child(MHStyle.eyebrow("Mission %d complete" % (int(mission.number) - 1), MHStyle.VALID, 11))
		_panel_body.add_child(MHStyle.title("Mission %d is ready" % int(mission.number), 20))
		var ready_text := MHStyle.body("%s. Keep improving this base as long as you like, then press J to start it." % str(mission.title), 14, MHStyle.TEXT_SECONDARY)
		ready_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ready_text.custom_minimum_size.x = 380
		_panel_body.add_child(ready_text)
		_panel_body.add_child(MHStyle.mono("J  START MISSION %d" % int(mission.number), 12, MHStyle.accent, 700))
		return
	_panel_body.add_child(MHStyle.eyebrow("Mission %d · %s" % [int(mission.number), str(mission.get("nasa_step", ""))], MHStyle.accent, 11))
	_panel_body.add_child(MHStyle.title(str(mission.title), 20))
	var budget := MHMissions.cargo_budget()
	var used: int = world.builder.used_cargo()
	_panel_body.add_child(MHStyle.mono("PAYLOAD  %s of %s used" % [MHStyle.kg(used), MHStyle.kg(budget)], 12, MHStyle.TEXT_SECONDARY if used <= budget else MHStyle.DANGER))
	var steps: Array = MHMissions.steps_of(mission)
	if _compact:
		# Collapsed: just the current step, but all of it.
		var next_step := MHMissions.current_step()
		if not next_step.is_empty():
			var row := MHStyle.hbox(8)
			row.add_child(MHStyle.icon("circle-arrow-right", 18, MHStyle.accent))
			row.add_child(_step_words(next_step, true))
			_panel_body.add_child(row)
		_panel_body.add_child(MHStyle.mono("H  SHOW STEPS  ·  T TEST  ·  J BRIEF", 11, MHStyle.TEXT_MUTED))
		return
	if not steps.is_empty():
		var done := MHMissions.steps_done(str(mission.id))
		var next := MHMissions.current_step()
		_panel_body.add_child(MHStyle.eyebrow("Steps · %d of %d done" % [done.size(), steps.size()], MHStyle.accent, 11))
		for step in steps:
			var is_done := done.has(str(step.id))
			var is_next := str(step.id) == str(next.get("id", ""))
			var row := MHStyle.hbox(8)
			row.add_child(MHStyle.icon("circle-check" if is_done else ("circle-arrow-right" if is_next else "circle-dashed"), 18, MHStyle.VALID if is_done else (MHStyle.accent if is_next else MHStyle.TEXT_MUTED)))
			row.add_child(_step_words(step, is_next))
			_panel_body.add_child(row)
		_panel_body.add_child(MHStyle.eyebrow("The test checks", MHStyle.accent, 11))
	var results := {}
	if str(_last_report.get("mission", "")) == str(mission.id):
		for result in _last_report.results: results[result.id] = result.pass
	for requirement in mission.get("requirements", []):
		var row := MHStyle.hbox(8)
		var state: Variant = results.get(requirement.id, null)
		row.add_child(MHStyle.icon("circle-dashed" if state == null else ("circle-check" if state else "circle-x"), 18, MHStyle.TEXT_MUTED if state == null else (MHStyle.VALID if state else MHStyle.DANGER)))
		var text := MHStyle.body(str(requirement.text), 13, MHStyle.TEXT_SECONDARY)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 340
		row.add_child(text)
		_panel_body.add_child(row)
	var versions := MHMissions.versions(str(mission.id))
	_panel_body.add_child(MHStyle.mono("%s  ·  T TEST  ·  J BRIEF  ·  K HOW IT WORKS  ·  H HIDE" % ("NOT TESTED YET" if versions.is_empty() else "VERSION %d TESTED" % versions.size()), 11, MHStyle.TEXT_MUTED))

## A step's words: the step, and for the current one how to do it and how
## far it's got ("2 of 4 doubled · still need a second water reclaimer").
func _step_words(step: Dictionary, current: bool) -> VBoxContainer:
	var words := MHStyle.vbox(2)
	var text := MHStyle.body(str(step.text), 14 if current else 13, MHStyle.TEXT_PRIMARY if current else MHStyle.TEXT_MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 340
	words.add_child(text)
	if not current: return words
	var how := MHStyle.body(str(step.get("how", "")), 13, MHStyle.TEXT_SECONDARY)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 340
	words.add_child(how)
	var extras := GUIDE.step_extras(step)
	if not (extras.keys as Array).is_empty(): words.add_child(GUIDE.keys_box(extras.keys))
	if GUIDE.has_clip(str(extras.clip)): words.add_child(MHStyle.mono("P  SHOW ME", 11, MHStyle.accent))
	var progress := MHMissions.step_progress(step, world.builder)
	if not progress.is_empty():
		var now := MHStyle.body("Now: " + progress, 13, MHStyle.accent)
		now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		now.custom_minimum_size.x = 340
		words.add_child(now)
	return words

# ---------- overlays ----------

func _open_overlay() -> VBoxContainer:
	_close_overlay(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = MHStyle.theme()
	add_child(_overlay)
	var scrim := MHWidgets.BlurScrim.new()
	scrim.set_dim(.84)
	_overlay.add_child(scrim)
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: page.add_theme_constant_override("margin_" + side, 120)
	page.add_theme_constant_override("margin_top", 64)
	page.add_theme_constant_override("margin_bottom", 56)
	_overlay.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := MHStyle.vbox(22)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _close_overlay(resume := true) -> void:
	if _overlay == null: return
	_overlay.queue_free()
	_overlay = null
	if resume: world._unpause()
	_refresh_panel()

func _header(column: VBoxContainer, eyebrow: String, title: String) -> HBoxContainer:
	var header := MHStyle.hbox(16)
	var titles := MHStyle.vbox(6)
	titles.add_child(MHStyle.eyebrow(eyebrow, MHStyle.accent, 16))
	titles.add_child(MHStyle.display(title, 52))
	header.add_child(titles)
	header.add_child(MHStyle.spacer())
	var close := MHStyle.button("Back to building", "secondary", "x")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_overlay)
	header.add_child(close)
	column.add_child(header)
	return header

func _wrapped(text: String, size := 17, colour := MHStyle.TEXT_SECONDARY, width := 760.0) -> Label:
	var label := MHStyle.body(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label

## The first thing a mission shows: what's happening, the goal, and the first
## step, in a small card. The full brief is one key away (J).
func _open_short_brief() -> void:
	var mission := MHMissions.current()
	if str(mission.get("brief", "")).is_empty():
		_open_brief()
		return
	_close_overlay(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = MHStyle.theme()
	add_child(_overlay)
	var scrim := MHWidgets.BlurScrim.new()
	scrim.set_dim(.55)
	_overlay.add_child(scrim)
	var card := MHStyle.hud_panel(32, true, true)
	card.anchor_left = .5
	card.anchor_right = .5
	card.anchor_top = .5
	card.anchor_bottom = .5
	card.offset_left = -420
	card.offset_right = 420
	card.offset_top = -270
	_overlay.add_child(card)
	var column := MHStyle.vbox(14)
	card.add_child(column)
	column.add_child(MHStyle.eyebrow("Mission %d · %s" % [int(mission.number), str(mission.get("nasa_step", ""))], MHStyle.accent, 14))
	column.add_child(MHStyle.title(str(mission.title), 34))
	column.add_child(_wrapped(str(mission.brief), 18, MHStyle.TEXT_PRIMARY, 776))
	column.add_child(MHStyle.eyebrow("Your goal", MHStyle.accent, 12))
	column.add_child(_wrapped(str(mission.get("goal", "")), 18, MHStyle.TEXT_PRIMARY, 776))
	var learn := HOW_IT_WORKS.for_mission(str(mission.id))
	if not learn.is_empty():
		column.add_child(MHStyle.eyebrow("What you need to know", MHStyle.accent, 12))
		column.add_child(_learn_row(learn))
	var first := MHMissions.current_step()
	if not first.is_empty():
		column.add_child(MHStyle.eyebrow("First step", MHStyle.accent, 12))
		column.add_child(_wrapped("%s. %s" % [str(first.text), str(first.get("how", ""))], 17, MHStyle.TEXT_SECONDARY, 776))
	column.add_child(_wrapped("The steps stay on screen, top right, and tick themselves off as you go.", 15, MHStyle.TEXT_MUTED, 776))
	var buttons := MHStyle.hbox(12)
	# New to these systems: learning comes first.
	var unseen := learn.filter(func(id): return not HOW_IT_WORKS.seen(id))
	if not unseen.is_empty():
		var how := MHStyle.button("Learn how it works (%d)" % unseen.size(), "primary", "book-open")
		how.pressed.connect(func() -> void: HOW_IT_WORKS.show(get_tree(), unseen))
		buttons.add_child(how)
	var go := MHStyle.button("Let's go", "secondary" if not unseen.is_empty() else "primary", "play")
	go.pressed.connect(_close_overlay)
	buttons.add_child(go)
	var more := MHStyle.button("Full brief  (J)", "ghost", "clipboard-check")
	more.pressed.connect(_open_brief)
	buttons.add_child(more)
	column.add_child(buttons)
	go.grab_focus.call_deferred()

## Understand: the situation, requirements, constraints, the site, and
## every version tested so far.
func _open_brief() -> void:
	var mission := MHMissions.current()
	var column := _open_overlay()
	if _next_mission_waiting():
		var start := MHStyle.button("Start Mission %d" % int(mission.number), "primary", "rocket")
		start.pressed.connect(_start_next_mission)
		column.add_child(start)
		start.grab_focus.call_deferred()
	_header(column, "Mission %d · %s · %s" % [int(mission.number), str(mission.get("nasa_step", "")), MHGame.site_name()], str(mission.title))
	column.add_child(_wrapped(str(mission.get("situation", "")), 20, MHStyle.TEXT_PRIMARY, 1100))
	var body := MHStyle.hbox(28)
	column.add_child(body)
	var left := MHStyle.vbox(12)
	left.custom_minimum_size.x = 640
	body.add_child(left)
	left.add_child(MHStyle.eyebrow("Requirements: the Test checks these", MHStyle.accent, 13))
	for requirement in mission.get("requirements", []):
		var row := MHStyle.hbox(10)
		row.add_child(MHStyle.icon("circle-dashed", 20, MHStyle.TEXT_SECONDARY))
		row.add_child(_wrapped(str(requirement.text), 17, MHStyle.TEXT_PRIMARY, 580))
		left.add_child(row)
	for goal in mission.get("stretch", []):
		left.add_child(_wrapped("☆ Stretch goal: " + str(goal.text), 15, MHStyle.accent, 600))
	left.add_child(MHStyle.eyebrow("Hints", MHStyle.accent, 13))
	for hint in mission.get("hints", []):
		left.add_child(_wrapped("• " + str(hint), 15, MHStyle.TEXT_SECONDARY, 600))
	var right := MHStyle.vbox(12)
	right.custom_minimum_size.x = 440
	body.add_child(right)
	var learn := HOW_IT_WORKS.for_mission(str(mission.id))
	if not learn.is_empty():
		right.add_child(MHStyle.eyebrow("How it works", MHStyle.accent, 13))
		right.add_child(_learn_row(learn, true))
	right.add_child(MHStyle.eyebrow("Constraints", MHStyle.accent, 13))
	var who := "A construction robot: no crew yet" if str(mission.get("player", "crew")) == "robot" else "%d crew" % int(mission.get("crew", 0))
	for line in ["Payload this landing: %s (total budget so far %s)" % [MHStyle.kg(int(mission.get("payload_kg", 0))), MHStyle.kg(MHMissions.cargo_budget())],
			"Test length: %d sols" % int(mission.get("sols", 0)), who, "Delivered: %s" % _unlocks_text(mission)]:
		right.add_child(_wrapped("• " + line, 15, MHStyle.TEXT_PRIMARY, 440))
	right.add_child(MHStyle.eyebrow("Know your site", MHStyle.accent, 13))
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var site_lines := ["Daylight %d hours; nights fall to %d °C" % [int(float(cycle.get("sunset_hour", 19)) - float(cycle.get("sunrise_hour", 5))), int(cycle.get("night_temp_c", -60))],
		"Best ice richness %d%%" % roundi(100.0 * _best_ice()), str(MHGame.site().get("blurb", ""))]
	for line in site_lines: right.add_child(_wrapped("• " + line, 15, MHStyle.TEXT_SECONDARY, 440))
	var versions := MHMissions.versions(str(mission.id))
	if not versions.is_empty():
		column.add_child(MHStyle.eyebrow("Versions tested (Improve)", MHStyle.accent, 13))
		for version in versions:
			var passed := bool(version.passed)
			var line := "Version %d · %s · %s · %s" % [int(version.version), str(version.time), "passed" if passed else "not yet", _version_line(versions, int(version.version))]
			column.add_child(_wrapped(line, 15, MHStyle.VALID if passed else MHStyle.TEXT_SECONDARY, 1100))
	var start := MHStyle.button("Start designing" if versions.is_empty() else "Back to building", "primary", "play")
	start.pressed.connect(_close_overlay)
	column.add_child(start)

## Buttons for How it works cards (each opens the viewer from that card).
func _learn_row(ids: Array, stacked := false) -> Container:
	var row: Container = MHStyle.vbox(6) if stacked else HFlowContainer.new()
	if row is HFlowContainer:
		(row as HFlowContainer).add_theme_constant_override("h_separation", 8)
		(row as HFlowContainer).add_theme_constant_override("v_separation", 8)
	for i in range(ids.size()):
		var c := HOW_IT_WORKS.card(str(ids[i]))
		var b := MHStyle.button(str(c.get("title", ids[i])), "ghost", str(c.get("icon", "info")), 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: HOW_IT_WORKS.show(get_tree(), ids.slice(i) + ids.slice(0, i)))
		row.add_child(b)
	return row

func _version_line(versions: Array, number: int) -> String:
	var design: Dictionary = versions[number - 1].design
	var summary := "%s cargo" % MHStyle.kg(int(design.get("cargo_kg", 0)))
	if number > 1: summary += " · " + MHMissions.design_changes(versions[number - 2].design, design)
	return summary

func _unlocks_text(mission: Dictionary) -> String:
	var names: Array = []
	for kind in mission.get("unlock_zones", []):
		names.append(str(BuildController.ZONE_TYPES.get(kind, {}).get("label", kind)))
	for id in mission.get("unlock_items", []):
		names.append(str(EquipmentCatalog.get_entry(id).get("label", id)))
	return ", ".join(names) if not names.is_empty() else "nothing new"

func _best_ice() -> float:
	var best := 0.0
	for deposit in MHGame.site().get("ice_deposits", []): best = maxf(best, float(deposit.richness))
	return best

## Test: fast-forward on a copy of the base, then the report.
func _run_test() -> void:
	MHMissions.pending_prediction = ""
	_test_now()

func _test_now() -> void:
	var mission := MHMissions.current()
	var column := _open_overlay()
	column.add_child(MHStyle.eyebrow("Mission %d · Test" % int(mission.number), MHStyle.accent, 16))
	column.add_child(MHStyle.display("Testing… fast-forwarding %d sols" % int(mission.get("sols", 0)), 44))
	await get_tree().process_frame
	# The dossier's pictures of this version (plan and outside view).
	await MHDossier.capture(world, str(mission.id), MHMissions.versions(str(mission.id)).size() + 1)
	await get_tree().process_frame
	_last_report = MHMissions.run_test(world.builder)
	world.save_mission_progress()
	_show_report(_last_report)

func _show_report(report: Dictionary) -> void:
	var mission := MHMissions.current()
	var column := _open_overlay()
	var passed := bool(report.passed)
	_header(column, "Mission %d · Test report · Version %d" % [int(mission.number), int(report.version)], "All requirements met" if passed else "Not there yet")
	column.add_child(_wrapped("Changes since the last test: %s." % str(report.changes), 16, MHStyle.TEXT_SECONDARY, 1100))
	for result in report.results:
		var row := MHStyle.hbox(12)
		row.add_child(MHStyle.icon("circle-check" if result.pass else "circle-x", 26, MHStyle.VALID if result.pass else MHStyle.DANGER))
		var words := MHStyle.vbox(2)
		words.add_child(_wrapped(str(result.text), 18, MHStyle.TEXT_PRIMARY, 1000))
		words.add_child(_wrapped(str(result.detail), 15, MHStyle.TEXT_SECONDARY, 1000))
		if not bool(result.pass) and not str(result.get("tip", "")).is_empty():
			words.add_child(_wrapped("Try this: " + str(result.tip), 15, MHStyle.accent, 1000))
		if not bool(result.pass):
			var card_id := _card_for_result(result)
			if not card_id.is_empty():
				var learn := MHStyle.button("How it works: %s" % str(HOW_IT_WORKS.card(card_id).get("title", "")), "ghost", "book-open", 36)
				learn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				learn.pressed.connect(func() -> void: HOW_IT_WORKS.show(get_tree(), [card_id]))
				words.add_child(learn)
		row.add_child(words)
		column.add_child(row)
	# The habitat's alerts on the test run: the early warning players would have had.
	var warned: Array = report.get("alerts", [])
	if not warned.is_empty():
		column.add_child(MHStyle.eyebrow("What the habitat would have told you", MHStyle.accent, 13))
		var colours := {"advisory": Color("#5DC8F9"), "warning": Color("#F5C542"), "critical": Color("#E5484D")}
		for entry in warned.slice(0, 8):
			column.add_child(_wrapped("%s · %s · %s" % [str(entry.when).substr(0, 1).to_upper() + str(entry.when).substr(1), str(entry.level).to_upper(), str(entry.title)], 15, colours.get(str(entry.level), MHStyle.WARN), 1000))
		if warned.size() > 8: column.add_child(_wrapped("…and %d more in the alert log." % (warned.size() - 8), 14, MHStyle.TEXT_MUTED, 1000))
	for goal in report.stretch:
		column.add_child(_wrapped(("★ Stretch goal met: " if goal.pass else "☆ Stretch goal: ") + str(goal.text), 15, MHStyle.accent if goal.pass else MHStyle.TEXT_MUTED, 1000))
	for mode in ["battery", "power"]:
		var graph := TestGraph.new()
		graph.report = report
		graph.mode = mode
		graph.custom_minimum_size = Vector2(1100, 210)
		column.add_child(graph)
	# Once there's a crew: how close the air, food, warmth and health came.
	if int(MHMissions.current().get("crew", 0)) > 0:
		var life := LifeGraph.new()
		life.report = report
		life.custom_minimum_size = Vector2(1100, 5 * 44 + 30)
		column.add_child(life)
	# Act 2: the readings this mission checks (radiation, pressure, fitness, wellbeing).
	var act2: Array = []
	var checks: Array = (mission.get("requirements", []) as Array).map(func(q): return str(q.check))
	for row in LifeGraph.ACT2_ROWS:
		if checks.has(str(row[8])): act2.append(row)
	if not act2.is_empty():
		var hazards := LifeGraph.new()
		hazards.report = report
		hazards.rows = act2
		hazards.title = "LIVING ON MARS OVER THE TEST"
		hazards.custom_minimum_size = Vector2(1100, act2.size() * 44 + 30)
		column.add_child(hazards)
	# The player's note on this version, for the dossier (optional).
	var note_row := MHStyle.hbox(12)
	var note := LineEdit.new()
	note.max_length = 240
	note.placeholder_text = "Optional note for your dossier: what will you change next, and why?"
	note.custom_minimum_size = Vector2(860, 48)
	note_row.add_child(note)
	var save_note := MHStyle.button("Save note", "secondary", "save")
	var keep := func() -> void:
		MHMissions.set_version_note(str(mission.id), int(report.version), note.text)
		world.save_mission_progress()
		save_note.text = "Saved"
	save_note.pressed.connect(keep)
	note.text_submitted.connect(func(_t: String) -> void: keep.call())
	note_row.add_child(save_note)
	column.add_child(note_row)
	var buttons := MHStyle.hbox(12)
	if passed:
		var done := MHStyle.button("Complete mission", "primary", "circle-check")
		done.pressed.connect(_complete_mission)
		buttons.add_child(done)
	var back := MHStyle.button("Back to building", "secondary" if passed else "primary", "hammer")
	back.pressed.connect(_close_overlay)
	buttons.add_child(back)
	column.add_child(buttons)

## The card that explains why a check failed (crew safety: by its reason).
func _card_for_result(result: Dictionary) -> String:
	var check := ""
	for requirement in MHMissions.current().get("requirements", []):
		if str(requirement.id) == str(result.id): check = str(requirement.check)
	if check == "crew_safe":
		var why := str(result.get("detail", "")).to_lower()
		if why.contains("oxygen") or why.contains("carbon"): return "air"
		if why.contains("°c") or why.contains("cold"): return "heating"
		if why.contains("water"): return "water"
		if why.contains("food"): return "food"
	return str(HOW_IT_WORKS.CHECK_CARDS.get(check, ""))

func _complete_mission() -> void:
	var mission := MHMissions.current()
	MHMissions.complete(str(mission.id))
	world.save_mission_progress()
	var next := MHMissions.next_after(str(mission.id))
	var column := _open_overlay()
	_header(column, "Mission %d complete" % int(mission.number), str(mission.title))
	var versions := MHMissions.versions(str(mission.id)).size()
	column.add_child(_wrapped("You tested %d version%s to get here. That's the engineering process: understand, design, test, improve." % [versions, "" if versions == 1 else "s"], 20, MHStyle.TEXT_PRIMARY, 1100))
	if next.is_empty():
		_campaign_wrap_up(column)
	elif not bool(next.get("available", false)):
		column.add_child(_wrapped("Next: Mission %d, %s. It arrives in a later update; your base is saved and ready for it. You can keep improving this design in the meantime." % [int(next.number), str(next.title)], 18))
	else:
		column.add_child(_wrapped("Next: Mission %d, %s. %s" % [int(next.number), str(next.title), str(next.get("brief", ""))], 18))
		var buttons := MHStyle.hbox(12)
		var go := MHStyle.button("Start Mission %d" % int(next.number), "primary", "rocket")
		go.pressed.connect(_start_next_mission)
		buttons.add_child(go)
		var stay := MHStyle.button("Keep improving this base", "secondary", "hammer")
		stay.pressed.connect(_close_overlay)
		buttons.add_child(stay)
		column.add_child(buttons)
		go.grab_focus.call_deferred()

## The next mission starts from the saved base, so its arrival plays.
func _start_next_mission() -> void:
	world.save_mission_progress()
	if MHGame.prepare_habitat_load(1, "missions"):
		get_tree().paused = false
		get_tree().reload_current_scene()

var _carry_slot := -1   # a full Free play slot chosen to replace

## After the final mission: what they achieved, then carry a copy of the base
## into free play. The finished campaign stays in the Missions saves.
func _campaign_wrap_up(column: VBoxContainer) -> void:
	var tested := 0
	for mission in MHMissions.missions(): tested += MHMissions.versions(str(mission.id)).size()
	column.add_child(_wrapped("That was the final mission: the campaign is complete. Across all %d missions you tested %d designs. Your base kept six people alive, fit and well for 200 sols on their own, through breakdowns, radiation and a blackout, in three different futures." % [MHMissions.missions().size(), tested], 20, MHStyle.TEXT_PRIMARY, 1100))
	column.add_child(MHStyle.eyebrow("Carry on with your base", MHStyle.accent, 13))
	column.add_child(_wrapped("A copy goes into your Free play saves. The finished campaign stays in the Missions saves, untouched.", 16, MHStyle.TEXT_SECONDARY, 1100))
	var slot := _carry_slot
	for candidate in range(1, MHGame.SAVE_SLOT_COUNT + 1):
		if slot < 0 and not bool(MHGame.save_slot_summary(candidate, "free_play").get("exists", false)): slot = candidate
	if slot < 0:
		# Every Free play slot is used (Missions saves are separate):
		# choose one to replace, right here.
		column.add_child(_wrapped("All %d of your Free play save slots are in use (your Missions save is kept separately). Choose one to replace:" % MHGame.SAVE_SLOT_COUNT, 16, MHStyle.WARN, 1100))
		var slots := GridContainer.new()
		slots.columns = 2
		slots.add_theme_constant_override("h_separation", 12)
		slots.add_theme_constant_override("v_separation", 10)
		for candidate in range(1, MHGame.SAVE_SLOT_COUNT + 1):
			var summary := MHGame.save_slot_summary(candidate, "free_play")
			var replace := MHStyle.button("Replace slot %d · %s · %s" % [candidate, str(summary.get("colony_name", "Habitat")), str(summary.get("saved_at", "")).get_slice(" ", 0)], "secondary", "save")
			replace.pressed.connect(func() -> void:
				_carry_slot = candidate
				for child in column.get_children(): child.queue_free()
				_campaign_wrap_up(column))
			slots.add_child(replace)
		column.add_child(slots)
		return
	if _carry_slot > 0: column.add_child(_wrapped("Your base will replace Free play slot %d." % _carry_slot, 16, MHStyle.TEXT_SECONDARY, 1100))
	var buttons := MHStyle.hbox(12)
	for mode in [["survival", "Survival", "Keep living there for real."], ["freedom", "Freedom", "Keep expanding without risk."], ["creative", "Creative", "Unlimited cargo: build your dream base."]]:
		var button := MHStyle.button("%s · %s" % [mode[1], mode[2]], "primary" if mode[0] == "survival" else "secondary", "rocket")
		button.pressed.connect(_carry_on.bind(str(mode[0]), slot))
		buttons.add_child(button)
	column.add_child(buttons)

func _carry_on(mode: String, slot: int) -> void:
	var state: Dictionary = world.current_state()
	state["game_mode"] = mode
	state["missions_progress"] = {}
	state["campaign_record"] = MHMissions.save_state()
	if MHGame.save_habitat(slot, state, "free_play") != OK: return
	if MHGame.prepare_habitat_load(slot, "free_play"):
		get_tree().paused = false
		get_tree().reload_current_scene()

## One chart from the test: "battery" (charge, 0-100%) or "power" (power
## made against power used, kW). The storm is shaded; sol labels thin out on
## long tests so they never overlap.
class TestGraph extends Control:
	var report: Dictionary
	var mode := "battery"

	func _draw() -> void:
		var samples: Array = report.get("samples", [])
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .35))
		if samples.is_empty(): return
		var font := ThemeDB.fallback_font
		var total_hours: float = float(report.sols) * 24.0
		var left := 70.0
		var right := size.x - 30.0
		var top := 40.0
		var bottom := size.y - 34.0
		var x_of := func(hours: float) -> float: return left + (right - left) * hours / total_hours
		for storm in report.get("storms", []):
			draw_rect(Rect2(Vector2(x_of.call(float(storm.start)), top), Vector2(x_of.call(float(storm.start) + float(storm.hours)) - x_of.call(float(storm.start)), bottom - top)), Color(.9, .45, .2, .18))
			draw_string(font, Vector2(x_of.call(float(storm.start)) + 6, top + 16), "DUST STORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, .7, .45))
		var entries := []
		if mode == "battery":
			var points := PackedVector2Array()
			for sample in samples:
				points.append(Vector2(x_of.call(float(sample.elapsed)), bottom - (bottom - top) * float(sample.battery_pct) / 100.0))
			# A faint line at 20%: below it the base is close to running flat.
			var low_y := bottom - (bottom - top) * .2
			draw_line(Vector2(left, low_y), Vector2(right, low_y), Color(1, .45, .45, .35), 1.0)
			draw_polyline(points, MHStyle.VALID, 3.0)
			draw_string(font, Vector2(10, top + 6), "100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MHStyle.VALID)
			draw_string(font, Vector2(10, bottom), "0%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MHStyle.VALID)
			entries = [["BATTERY CHARGE", MHStyle.VALID]]
		else:
			var max_kw := 1.0
			for sample in samples: max_kw = maxf(max_kw, maxf(float(sample.generation_kw), float(sample.load_kw)))
			var made := PackedVector2Array()
			var used := PackedVector2Array()
			for sample in samples:
				var x: float = x_of.call(float(sample.elapsed))
				made.append(Vector2(x, bottom - (bottom - top) * float(sample.generation_kw) / max_kw))
				used.append(Vector2(x, bottom - (bottom - top) * float(sample.load_kw) / max_kw))
			draw_polyline(made, Color("#F2C14E"), 2.0)
			draw_polyline(used, Color(1, 1, 1, .75), 1.5)
			draw_string(font, Vector2(10, top + 6), "%d kW" % roundi(max_kw), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F2C14E"))
			draw_string(font, Vector2(10, bottom), "0 kW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F2C14E"))
			entries = [["POWER MADE", Color("#F2C14E")], ["POWER USED", Color(1, 1, 1, .75)]]
		# Sol ticks, labelled every n sols so labels keep at least 60 px apart.
		var sols := int(report.sols)
		var every := maxi(1, ceili(60.0 / maxf(1.0, (right - left) / maxf(1.0, float(sols)))))
		for nice in [1, 2, 5, 10, 20, 25, 50, 100]:
			if nice >= every:
				every = nice
				break
		for sol in range(sols + 1):
			var x: float = x_of.call(sol * 24.0)
			# Sol 1, then every n-th: 5, 10, 15 ...
			var labelled := (sol + 1) % every == 0 or (sol == 0 and every != 2)
			draw_line(Vector2(x, bottom), Vector2(x, bottom + (5 if labelled else 2)), Color(1, 1, 1, .5 if labelled else .2), 1.0)
			if labelled and sol < sols: draw_string(font, Vector2(x + 4, bottom + 22), "Sol %d" % (sol + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .7))
		draw_line(Vector2(left, top), Vector2(left, bottom), Color(1, 1, 1, .3), 1.0)
		draw_line(Vector2(left, bottom), Vector2(right, bottom), Color(1, 1, 1, .3), 1.0)
		# Title and key along the top.
		var x0 := 12.0
		for entry in entries:
			draw_rect(Rect2(Vector2(x0, 14), Vector2(12, 4)), entry[1])
			draw_string(font, Vector2(x0 + 16, 20), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .8))
			x0 += font.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 44.0

## Life support over the test, one strip each: oxygen, carbon dioxide, food,
## the habitat temperature and crew health, each with its safe line, so
## players can see how close it came (and when).
class LifeGraph extends Control:
	var report: Dictionary
	const ROW := 44.0
	# label, sample key, axis low, axis high, safe line, safe when above it, colour, unit
	const ROWS := [
		["Oxygen", "o2_pct", 15.0, 25.0, 19.5, true, Color("#7FD6FF"), "%"],
		["Carbon dioxide", "co2_pct", 0.0, 2.0, 1.0, false, Color("#C9A8FF"), "%"],
		["Food", "food_kg", 0.0, -1.0, 0.0, true, Color("#9AE07A"), " kg"],
		["Temperature", "coldest_c", -10.0, 30.0, 15.0, true, Color("#FFB37A"), " °C"],
		["Crew health", "crew_health", 0.0, 100.0, 50.0, true, Color("#FF8A8A"), "%"]]
	# The same, plus the check each row belongs to (shown only when the mission checks it).
	const ACT2_ROWS := [
		["Radiation (event)", "event_dose_msv", 0.0, 100.0, 50.0, false, Color("#F5C542"), " mSv", "dose_max"],
		["Air pressure", "pressure_pct", 0.0, 100.0, 70.0, true, Color("#7FD6FF"), "%", "pressure_min"],
		["Lowest fitness", "fitness", 40.0, 100.0, 70.0, true, Color("#9AE07A"), "%", "fitness_min"],
		["Wellbeing", "wellbeing", 30.0, 100.0, 60.0, true, Color("#E9A5FF"), "%", "wellbeing_min"]]
	var rows: Array = ROWS
	var title := "LIFE SUPPORT OVER THE TEST"

	func _draw() -> void:
		var samples: Array = report.get("samples", [])
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .35))
		if samples.is_empty(): return
		var font := ThemeDB.fallback_font
		var total_hours: float = float(report.sols) * 24.0
		var left := 170.0
		var right := size.x - 110.0
		draw_string(font, Vector2(12, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .6))
		for index in range(rows.size()):
			var spec: Array = rows[index]
			var top := 28.0 + index * ROW
			var bottom := top + ROW - 10.0
			var low: float = spec[2]
			var high: float = spec[3]
			if high < 0.0:
				high = 1.0
				for sample in samples: high = maxf(high, float(sample.get(spec[1], 0.0)))
			var y_of := func(value: float) -> float: return bottom - (bottom - top) * clampf((value - low) / (high - low), 0.0, 1.0)
			draw_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)), Color(1, 1, 1, .04))
			# The safe line, dashed, with the unsafe side tinted.
			var safe_y: float = y_of.call(float(spec[4]))
			var unsafe := Rect2(Vector2(left, safe_y), Vector2(right - left, bottom - safe_y)) if bool(spec[5]) else Rect2(Vector2(left, top), Vector2(right - left, safe_y - top))
			draw_rect(unsafe, Color(1, .3, .3, .07))
			var dash := left
			while dash < right:
				draw_line(Vector2(dash, safe_y), Vector2(minf(dash + 6.0, right), safe_y), Color(1, .45, .45, .55), 1.0)
				dash += 12.0
			var points := PackedVector2Array()
			var worst := float(samples[0].get(spec[1], 0.0))
			for sample in samples:
				var value := float(sample.get(spec[1], 0.0))
				worst = minf(worst, value) if bool(spec[5]) else maxf(worst, value)
				points.append(Vector2(left + (right - left) * float(sample.elapsed) / total_hours, y_of.call(value)))
			draw_polyline(points, spec[6], 2.0)
			draw_string(font, Vector2(12, top + 18), str(spec[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, spec[6])
			var bad: bool = (worst < float(spec[4])) if bool(spec[5]) else (worst > float(spec[4]))
			var word: String = ("fell to " if bad else "lowest ") if bool(spec[5]) else ("rose to " if bad else "highest ")
			var shown := str(roundi(worst)) if absf(worst) >= 10.0 else str(snappedf(worst, .1))
			draw_string(font, Vector2(right + 8, top + 18), word + shown + str(spec[7]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MHStyle.DANGER if bad else Color(1, 1, 1, .6))
