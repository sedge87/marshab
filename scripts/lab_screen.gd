extends Control

## The lab's screen (E on a Science Workbench; docs/samples-lab-journal.md §5).
## The samples waiting in the store on the left, the one you pick on the
## right, with Analyse. One job per bench, on the clock and on power; a
## Microscope Station in the same room makes rock and regolith faster.
## Below: the leads being followed up, and the archive. The game keeps
## running while this is open (the fabricator screen's pattern).

signal closed

var world: Node
var bench := ""        # the Science Workbench's placement id
var _selected := -1
var _list: VBoxContainer
var _detail: VBoxContainer
var _leads: VBoxContainer
var _job: Label
var _refresh := 0.0
var _shown_jobs := ""

func setup(target_world: Node, bench_key: String) -> Control:
	world = target_world
	bench = bench_key
	return self

func _microscope() -> bool:
	for entry in MHSamples.benches(world.builder):
		if str(entry.key) == bench: return bool(entry.microscope)
	return false

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
	titles.add_child(MHStyle.eyebrow("SCIENCE LAB", MHStyle.accent))
	titles.add_child(MHStyle.title("Analyse samples", 30))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var close := MHStyle.button("Close  Esc", "secondary", "x", 44)
	close.pressed.connect(_close)
	head.add_child(close)
	column.add_child(head)
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
	var right := MHStyle.vbox(18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_detail = MHStyle.vbox(10)
	right.add_child(_detail)
	_leads = MHStyle.vbox(6)
	right.add_child(_leads)
	_render()

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = .5
	# A job finishing changes the lists; otherwise only the progress line.
	var jobs := str(MHSamples.jobs.keys()) + str(MHSamples.store.size())
	if jobs != _shown_jobs: _render()
	else: _update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _update_status() -> void:
	var job: Dictionary = MHSamples.jobs.get(bench, {})
	if job.is_empty():
		_job.text = "This bench is free. Pick a sample and analyse it; it runs on the habitat's power.%s" % ("  A microscope in the room speeds up rock and soil." if _microscope() else "")
		return
	var record := MHSamples.sample(int(job.sample))
	var done := 1.0 - float(job.hours_left) / maxf(.01, float(job.hours))
	_job.text = "ANALYSING %s · %d%% · about %d h left" % [MHSamples.sample_label(record).to_upper(), roundi(done * 100.0), ceili(float(job.hours_left))]

func _render() -> void:
	_shown_jobs = str(MHSamples.jobs.keys()) + str(MHSamples.store.size())
	for child in _list.get_children(): child.queue_free()
	var waiting := MHSamples.waiting()
	if waiting.filter(func(r): return int(r.id) == _selected).is_empty():
		_selected = int(waiting[0].id) if not waiting.is_empty() else -1
	_list.add_child(MHStyle.eyebrow("WAITING · %d" % waiting.size(), MHStyle.TEXT_MUTED, 12))
	if waiting.is_empty():
		var none := MHStyle.body("No samples waiting. Take some outside (the scoop, rock chips, the corer) and unload the case here or at the Sample Storage Cabinet.", 15, MHStyle.TEXT_SECONDARY)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(none)
	for record in waiting:
		var id := int(record.id)
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.clip_text = true
		row.custom_minimum_size = Vector2(0, 40)
		row.text = "  %s%s     %s" % [MHSamples.sample_label(record).capitalize(), " (GAR-Y)" if str(record.get("by", "")) == "gar_y" else "", MHSamples.where_line(record)]
		var picked: bool = id == _selected
		row.add_theme_stylebox_override("normal", MHStyle.box(MHStyle.tint(MHStyle.accent, .18) if picked else MHStyle.SURFACE_CONTROL, MHStyle.accent if picked else MHStyle.BORDER_SUBTLE, 6, 1, Vector4(10, 6, 10, 6)))
		row.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, 6, 1, Vector4(10, 6, 10, 6)))
		row.pressed.connect(func() -> void: _selected = id; _render())
		_list.add_child(row)
	var archive := MHSamples.archive()
	if not archive.is_empty():
		_list.add_child(MHStyle.eyebrow("ANALYSED · %d" % archive.size(), MHStyle.TEXT_MUTED, 12))
		for record in archive.slice(maxi(0, archive.size() - 8)):
			var names: Array = (record.findings as Array).map(func(id): return str(MHSamples.discovery(str(id)).get("label", id)))
			var line := MHStyle.mono("%s · %s" % [MHSamples.sample_label(record).capitalize(), ", ".join(names) if not names.is_empty() else "nothing new"], 13, MHStyle.TEXT_SECONDARY)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(line)
	_render_detail()
	_render_leads()
	_update_status()

func _render_detail() -> void:
	for child in _detail.get_children(): child.queue_free()
	var record := MHSamples.sample(_selected)
	if record.is_empty(): return
	_detail.add_child(MHStyle.eyebrow("SAMPLE %d · %s" % [int(record.id), str(MHSamples.KIND_LABELS.get(str(record.kind), record.kind)).to_upper()]))
	_detail.add_child(MHStyle.title(MHSamples.sample_label(record).capitalize(), 26))
	_detail.add_child(MHStyle.mono(MHSamples.where_line(record), 14, MHStyle.TEXT_SECONDARY))
	if record.has("name"): _detail.add_child(MHStyle.body("GAR-Y calls it %s." % str(record.name), 15, MHStyle.TEXT_SECONDARY))
	var hours := MHSamples.analysis_hours(str(record.kind), _microscope())
	_detail.add_child(MHStyle.mono("Analysis: %s game hours · part of the sample is used up" % ("%.1f" % hours if hours < 10.0 else str(roundi(hours))), 14, MHStyle.TEXT_MUTED))
	var busy := MHSamples.jobs.has(bench)
	var start := MHStyle.button("This bench is busy" if busy else "Analyse", "secondary" if busy else "primary", "play", 48)
	start.disabled = busy
	start.pressed.connect(func() -> void:
		if MHSamples.start_job(bench, _selected, _microscope()).is_empty():
			MHAudio.sfx("ui_click")
			_render())
	_detail.add_child(start)
	if busy:
		var cancel := MHStyle.button("Stop the analysis (the sample goes back)", "secondary", "x", 44)
		cancel.pressed.connect(func() -> void: MHSamples.cancel_job(bench); _render())
		_detail.add_child(cancel)

## The leads being followed: how many more samples, from where.
func _render_leads() -> void:
	for child in _leads.get_children(): child.queue_free()
	if MHSamples.leads.is_empty(): return
	_leads.add_child(MHStyle.eyebrow("LEADS", MHStyle.accent, 12))
	for id in MHSamples.leads:
		var entry := MHSamples.discovery(str(id))
		var have := (MHSamples.evidence.get(id, []) as Array).size()
		var text := "%s · %d of %d samples from different spots" % [str(entry.get("lead", entry.get("label", id))), have, int(entry.get("need", 1))]
		if str(entry.get("kind", "")) == "reading": text = "%s · readings: %s" % [str(entry.get("lead", entry.label)), " and ".join((MHSamples.readings.get(id, {}) as Dictionary).keys())]
		var line := MHStyle.body(text, 14, MHStyle.TEXT_PRIMARY)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_leads.add_child(line)
