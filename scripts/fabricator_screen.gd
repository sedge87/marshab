extends Control

## The fabricator's screen (E on a fabricator; docs/start-and-chapter-one.md §4).
## Pick a known plan, see its feedstock, Earth parts, time and power, and
## start it. One job at a time. The first job makes the plan: the item goes
## onto the build bar's Unpacked tab for good, and later copies are paid for
## from the stores as they're placed. The game keeps running while this is open.

signal closed

var world: Node
var _selected := ""
var _list: VBoxContainer
var _detail: VBoxContainer
var _stock: Label
var _job: Label
var _refresh := 0.0

func setup(target_world: Node) -> Control:
	world = target_world
	return self

func _builder() -> BuildController:
	return world.builder

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(.03, .05, .06, .94)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var column := MHStyle.vbox(14)
	margin.add_child(column)
	var head := MHStyle.hbox(14)
	var titles := MHStyle.vbox(4)
	titles.add_child(MHStyle.eyebrow("FABRICATOR", MHStyle.accent))
	titles.add_child(MHStyle.title("Make equipment from plans", 30))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var close := MHStyle.button("Close  Esc", "secondary", "x", 44)
	close.pressed.connect(_close)
	head.add_child(close)
	column.add_child(head)
	_stock = MHStyle.mono("", 15, MHStyle.TEXT_SECONDARY, 600)
	column.add_child(_stock)
	_job = MHStyle.mono("", 15, MHStyle.accent, 600)
	_job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_job)
	var body := MHStyle.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.2
	body.add_child(scroll)
	_list = MHStyle.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_detail = MHStyle.vbox(10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)
	_render()

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = .5
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _update_status() -> void:
	_stock.text = "FEEDSTOCK %s   ·   EARTH PARTS %d" % [MHStyle.kg(roundi(MHChapterOne.feedstock_kg)), MHChapterOne.earth_parts]
	var job := MHChapterOne.job
	if job.is_empty(): _job.text = "Idle. Pick a plan and start a job; it runs on the habitat's power."
	else:
		var done := 1.0 - float(job.hours_left) / maxf(.01, float(job.hours))
		var speed := MHChapterOne.fabricator_speed(_builder())
		_job.text = "MAKING %s · %d%% · about %d h left%s" % [MHChapterOne.label(str(job.id)).to_upper(), roundi(done * 100.0), ceili(float(job.hours_left) / maxf(.01, speed)), "  (General Module: 75 % speed)" if speed < 1.0 else ""]

func _render() -> void:
	for child in _list.get_children(): child.queue_free()
	var ids := MHChapterOne.fabricable()
	if _selected.is_empty() and not ids.is_empty(): _selected = str(ids[0])
	for id in ids:
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.clip_text = true
		row.custom_minimum_size = Vector2(0, 40)
		var cost := MHChapterOne.plan_cost(id)
		row.text = "  %s     %s · %d parts · %d h" % [MHChapterOne.label(id), MHStyle.kg(roundi(float(cost.feedstock_kg))), int(cost.earth_parts), roundi(float(cost.hours))]
		var picked: bool = id == _selected
		row.add_theme_stylebox_override("normal", MHStyle.box(MHStyle.tint(MHStyle.accent, .18) if picked else MHStyle.SURFACE_CONTROL, MHStyle.accent if picked else MHStyle.BORDER_SUBTLE, 6, 1, Vector4(10, 6, 10, 6)))
		row.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, 6, 1, Vector4(10, 6, 10, 6)))
		row.pressed.connect(func() -> void: _selected = id; _render())
		_list.add_child(row)
	_render_detail()
	_update_status()

func _render_detail() -> void:
	for child in _detail.get_children(): child.queue_free()
	if _selected.is_empty():
		_detail.add_child(MHStyle.body("No plans yet.", 16))
		return
	var entry := EquipmentCatalog.get_entry(_selected)
	if _selected == MHChapterOne.SPARES_KIT:
		var builder := _builder()
		var have := int(builder.simulation().life.spares) if builder != null else 0
		entry = {"description": "Filter beds, brine bags, seals and fittings, made from feedstock. One kit services a worn machine or repairs a broken one. You have %d." % have}
	var cost := MHChapterOne.plan_cost(_selected)
	_detail.add_child(MHStyle.eyebrow({"brought": "PLAN · BROUGHT FROM EARTH", "sent": "PLAN · SENT BY MISSION CONTROL", "discovered": "PLAN · FROM A DISCOVERY"}.get(MHChapterOne.plan_source(_selected), "PLAN")))
	_detail.add_child(MHStyle.title(MHChapterOne.label(_selected), 26))
	var about := MHStyle.body(str(entry.get("description", "")), 16)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(about)
	_detail.add_child(MHStyle.mono("Feedstock %s · Earth parts %d · %d game hours · 1.2 kW while it runs" % [MHStyle.kg(roundi(float(cost.feedstock_kg))), int(cost.earth_parts), roundi(float(cost.hours))], 14, MHStyle.TEXT_SECONDARY))
	var on_bar := "On the build bar: each extra one takes this feedstock and these parts as you place it" if MHChapterOne.made.has(_selected) else "Not made yet: the first job puts it on the build bar for good"
	if _selected == MHChapterOne.SPARES_KIT: on_bar = "Make them as you need them: worn machines lose output, then break"
	_detail.add_child(MHStyle.mono(on_bar, 14, MHStyle.TEXT_MUTED))
	var reason := MHChapterOne.job_reason(_selected, _builder())
	var start := MHStyle.button(("Make %d" % MHChapterOne.KITS_PER_JOB if _selected == MHChapterOne.SPARES_KIT else "Make first one") if reason.is_empty() else reason, "primary" if reason.is_empty() else "secondary", "play", 48)
	start.disabled = not reason.is_empty()
	start.pressed.connect(func() -> void:
		if MHChapterOne.start_job(_selected, _builder()).is_empty():
			MHAudio.sfx("ui_click")
			_render())
	_detail.add_child(start)
	if not MHChapterOne.job.is_empty():
		var cancel := MHStyle.button("Cancel the job (stock returned)", "secondary", "x", 44)
		cancel.pressed.connect(func() -> void: MHChapterOne.cancel_job(); _render())
		_detail.add_child(cancel)
