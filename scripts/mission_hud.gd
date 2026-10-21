extends CanvasLayer

## Missions mode on screen: the mission panel (top right) with the step
## tracker (each step ticks itself off) and the requirements, a "next step"
## pill while building, a short brief card when a mission starts, the full
## brief and versions (J), and the Test (T): a fast-forward run with a
## report, reasons and graphs. See docs/missions-design.md.
const MHMissions := preload("res://scripts/mh_missions.gd")

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

func setup(target_world: Node) -> void:
	world = target_world

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
	# While building (the panel is hidden), a small pill keeps the next step in view.
	_next_pill = MHStyle.hud_panel(12, false, true)
	_next_pill.position = Vector2(48, 250)
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
	if not ticked.is_empty(): world.save_mission_progress()
	var step := MHMissions.current_step()
	_next_label.text = "" if step.is_empty() else str(step.text)
	_next_how.text = str(step.get("how", ""))
	_set_marker(str(step.get("marker", "")))
	return not ticked.is_empty()

## A compass landmark for the current step: the base site or the best ice.
func _set_marker(kind: String) -> void:
	var at := Vector2.INF
	var label := ""
	if kind == "base":
		at = MHMissions.base_site()
		label = "BASE SITE"
	elif kind == "ice":
		var best := 0.0
		for deposit in MHGame.site().get("ice_deposits", []):
			if float(deposit.richness) > best:
				best = float(deposit.richness)
				at = Vector2(float(deposit.x), float(deposit.z))
		label = "BEST ICE"
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

func _show_toast(text: String) -> void:
	if _toast != null: _toast.queue_free()
	_toast = MHStyle.hud_panel(12, false, true)
	_toast.theme = MHStyle.theme()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.anchor_left = .5
	_toast.anchor_right = .5
	_toast.offset_left = -260
	_toast.offset_right = 260
	_toast.offset_top = 150
	var row := MHStyle.hbox(10)
	row.add_child(MHStyle.icon("circle-check", 22, MHStyle.VALID))
	var words := MHStyle.vbox(2)
	words.add_child(MHStyle.eyebrow("Step done", MHStyle.VALID, 11))
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

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or event.ctrl_pressed: return
	if _overlay != null:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	if get_tree().paused: return
	if event.keycode == KEY_T:
		_run_test()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_J:
		_open_brief()
		get_viewport().set_input_as_handled()

# ---------- the panel ----------

func _refresh_panel() -> void:
	for child in _panel_body.get_children(): child.queue_free()
	var mission := MHMissions.current()
	_panel_body.add_child(MHStyle.eyebrow("Mission %d · %s" % [int(mission.number), str(mission.get("nasa_step", ""))], MHStyle.accent, 11))
	_panel_body.add_child(MHStyle.title(str(mission.title), 20))
	var budget := MHMissions.cargo_budget()
	var used: int = world.builder.used_cargo()
	_panel_body.add_child(MHStyle.mono("PAYLOAD  %s of %s used" % [MHStyle.kg(used), MHStyle.kg(budget)], 12, MHStyle.TEXT_SECONDARY if used <= budget else MHStyle.DANGER))
	var steps: Array = mission.get("steps", [])
	if not steps.is_empty():
		var done := MHMissions.steps_done(str(mission.id))
		var next := MHMissions.current_step()
		_panel_body.add_child(MHStyle.eyebrow("Steps · %d of %d done" % [done.size(), steps.size()], MHStyle.accent, 11))
		for step in steps:
			var is_done := done.has(str(step.id))
			var is_next := str(step.id) == str(next.get("id", ""))
			var row := MHStyle.hbox(8)
			row.add_child(MHStyle.icon("circle-check" if is_done else ("circle-arrow-right" if is_next else "circle-dashed"), 18, MHStyle.VALID if is_done else (MHStyle.accent if is_next else MHStyle.TEXT_MUTED)))
			var words := MHStyle.vbox(2)
			var text := MHStyle.body(str(step.text), 14 if is_next else 13, MHStyle.TEXT_PRIMARY if is_next else MHStyle.TEXT_MUTED)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.custom_minimum_size.x = 340
			words.add_child(text)
			if is_next:
				var how := MHStyle.body(str(step.get("how", "")), 13, MHStyle.TEXT_SECONDARY)
				how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				how.custom_minimum_size.x = 340
				words.add_child(how)
			row.add_child(words)
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
	_panel_body.add_child(MHStyle.mono("%s  ·  T TEST  ·  J BRIEF" % ("NOT TESTED YET" if versions.is_empty() else "VERSION %d TESTED" % versions.size()), 11, MHStyle.TEXT_MUTED))

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
	var first := MHMissions.current_step()
	if not first.is_empty():
		column.add_child(MHStyle.eyebrow("First step", MHStyle.accent, 12))
		column.add_child(_wrapped("%s. %s" % [str(first.text), str(first.get("how", ""))], 17, MHStyle.TEXT_SECONDARY, 776))
	column.add_child(_wrapped("The steps stay on screen, top right, and tick themselves off as you go.", 15, MHStyle.TEXT_MUTED, 776))
	var buttons := MHStyle.hbox(12)
	var go := MHStyle.button("Let's go", "primary", "play")
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
	var mission := MHMissions.current()
	var column := _open_overlay()
	column.add_child(MHStyle.eyebrow("Mission %d · Test" % int(mission.number), MHStyle.accent, 16))
	column.add_child(MHStyle.display("Testing… fast-forwarding %d sols" % int(mission.get("sols", 0)), 44))
	await get_tree().process_frame
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
		row.add_child(words)
		column.add_child(row)
	for goal in report.stretch:
		column.add_child(_wrapped(("★ Stretch goal met: " if goal.pass else "☆ Stretch goal: ") + str(goal.text), 15, MHStyle.accent if goal.pass else MHStyle.TEXT_MUTED, 1000))
	var graph := TestGraph.new()
	graph.report = report
	graph.custom_minimum_size = Vector2(1100, 300)
	column.add_child(graph)
	var buttons := MHStyle.hbox(12)
	if passed:
		var done := MHStyle.button("Complete mission", "primary", "circle-check")
		done.pressed.connect(_complete_mission)
		buttons.add_child(done)
	var back := MHStyle.button("Back to building", "secondary" if passed else "primary", "hammer")
	back.pressed.connect(_close_overlay)
	buttons.add_child(back)
	column.add_child(buttons)

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

## After the final mission: what they achieved, then carry a copy of the base
## into free play. The finished campaign stays in the Missions saves.
func _campaign_wrap_up(column: VBoxContainer) -> void:
	var tested := 0
	for mission in MHMissions.missions(): tested += MHMissions.versions(str(mission.id)).size()
	column.add_child(_wrapped("That was the final mission: the campaign is complete. Across all six missions you tested %d designs. Your base kept six people alive for 100 sols and started feeding itself." % tested, 20, MHStyle.TEXT_PRIMARY, 1100))
	column.add_child(MHStyle.eyebrow("Carry on with your base", MHStyle.accent, 13))
	column.add_child(_wrapped("A copy goes into your Free play saves. The finished campaign stays in the Missions saves, untouched.", 16, MHStyle.TEXT_SECONDARY, 1100))
	var slot := -1
	for candidate in range(1, MHGame.SAVE_SLOT_COUNT + 1):
		if slot < 0 and not bool(MHGame.save_slot_summary(candidate, "free_play").get("exists", false)): slot = candidate
	if slot < 0:
		column.add_child(_wrapped("Your three Free play save slots are full. Delete or overwrite one from the main menu first, then come back to this save.", 16, MHStyle.WARN, 1100))
		return
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
	if MHGame.save_habitat(slot, state, "free_play") != OK: return
	if MHGame.prepare_habitat_load(slot, "free_play"):
		get_tree().paused = false
		get_tree().reload_current_scene()

## Battery charge, solar and load over the test, with the storm shaded and
## the first failure marked.
class TestGraph extends Control:
	var report: Dictionary

	func _draw() -> void:
		var samples: Array = report.get("samples", [])
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .35))
		if samples.is_empty(): return
		var font := ThemeDB.fallback_font
		var total_hours: float = float(report.sols) * 24.0
		var left := 56.0
		var right := size.x - 56.0
		var top := 24.0
		var bottom := size.y - 34.0
		var x_of := func(hours: float) -> float: return left + (right - left) * hours / total_hours
		for storm in report.get("storms", []):
			draw_rect(Rect2(Vector2(x_of.call(float(storm.start)), top), Vector2(x_of.call(float(storm.start) + float(storm.hours)) - x_of.call(float(storm.start)), bottom - top)), Color(.9, .45, .2, .18))
			draw_string(font, Vector2(x_of.call(float(storm.start)) + 6, top + 14), "DUST STORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, .7, .45))
		var max_kw := 1.0
		for sample in samples: max_kw = maxf(max_kw, maxf(float(sample.generation_kw), float(sample.load_kw)))
		var lines := {"battery": [], "solar": [], "load": []}
		for sample in samples:
			var x: float = x_of.call(float(sample.elapsed))
			lines.battery.append(Vector2(x, bottom - (bottom - top) * float(sample.battery_pct) / 100.0))
			lines.solar.append(Vector2(x, bottom - (bottom - top) * float(sample.generation_kw) / max_kw))
			lines.load.append(Vector2(x, bottom - (bottom - top) * float(sample.load_kw) / max_kw))
		draw_polyline(PackedVector2Array(lines.solar), Color("#F2C14E"), 2.0)
		draw_polyline(PackedVector2Array(lines.load), Color(1, 1, 1, .7), 1.5)
		draw_polyline(PackedVector2Array(lines.battery), MHStyle.VALID, 3.0)
		for sol in range(int(report.sols) + 1):
			var x: float = x_of.call(sol * 24.0)
			draw_line(Vector2(x, bottom), Vector2(x, bottom + 5), Color(1, 1, 1, .5), 1.0)
			if sol < int(report.sols): draw_string(font, Vector2(x + 4, bottom + 22), "Sol %d" % (sol + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .7))
		draw_line(Vector2(left, top), Vector2(left, bottom), Color(1, 1, 1, .3), 1.0)
		draw_line(Vector2(left, bottom), Vector2(right, bottom), Color(1, 1, 1, .3), 1.0)
		draw_string(font, Vector2(6, top + 6), "100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MHStyle.VALID)
		draw_string(font, Vector2(right + 6, top + 6), "%d kW" % roundi(max_kw), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F2C14E"))
		var x0 := left + 10.0
		for entry in [["Battery charge", MHStyle.VALID], ["Power made (kW)", Color("#F2C14E")], ["Power used (kW)", Color(1, 1, 1, .7)]]:
			draw_rect(Rect2(Vector2(x0, size.y - 14), Vector2(12, 4)), entry[1])
			draw_string(font, Vector2(x0 + 16, size.y - 8), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, .8))
			x0 += 170.0
