extends ColorRect

## Mission Control's Crew screen (Act 2): who the crew are, how they are, what
## they need, and how safe the base is from radiation, breaches and
## breakdowns. Names can be changed here; in Missions, naming the crew ticks
## Mission 8's first step. Reads the live simulation (habitat_life.gd).
const MHMissions := preload("res://scripts/mh_missions.gd")
const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")

var builder: Node
var _fields: Array = []

func open(target_builder: Node) -> void:
	builder = target_builder
	color = Color(0, 0, 0, .6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := MHStyle.menu_panel(28, true)
	panel.custom_minimum_size = Vector2(1500, 0)
	centre.add_child(panel)
	var col := MHStyle.vbox(16)
	panel.add_child(col)
	var sim: RefCounted = builder.simulation()
	var life: RefCounted = sim.life
	var inv: Dictionary = sim.inventory()
	var crew_n: int = maxi(sim.crew_count(), int(MHMissions.current().get("crew", 0)) if MHMissions.active() else 0)
	life.ensure_crew(crew_n, MHMissions.progress.get("crew_names", []) if MHMissions.active() else [])
	# Header
	var head := MHStyle.hbox(10)
	head.add_child(MHStyle.icon("users", 26, MHStyle.accent))
	head.add_child(MHStyle.title("Crew", 30))
	head.add_child(MHStyle.spacer())
	for card in [["wellbeing", "Feeling okay"], ["fitness", "Staying fit"]]:
		var how := MHStyle.button(card[1], "ghost", "book-open", 44)
		how.pressed.connect(func() -> void: HOW_IT_WORKS.show(get_tree(), [card[0]]))
		head.add_child(how)
	var back := MHStyle.button("Back", "secondary", "chevron-left", 44)
	back.pressed.connect(_close)
	head.add_child(back)
	col.add_child(head)
	if (life.crew as Array).is_empty():
		col.add_child(MHStyle.body("No crew aboard yet. They arrive once there are bunks for them.", 17, MHStyle.TEXT_MUTED))
		return
	if not life.crew_on:
		col.add_child(MHStyle.notice("info", "Your crew, by name", "From Mission 8 your crew become individuals, with fitness and wellbeing to look after. You can name them now."))
	# The people
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	_fields = []
	for p in life.crew: grid.add_child(_person_card(p, life, inv))
	var names_row := MHStyle.hbox(12)
	var save := MHStyle.button("Save names", "primary", "save", 44)
	save.pressed.connect(_save_names)
	names_row.add_child(save)
	var hint := MHStyle.label("Click a name to change it.", 15, MHStyle.TEXT_MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names_row.add_child(hint)
	col.add_child(names_row)
	# Needs and safety side by side
	var lower := MHStyle.hbox(16)
	col.add_child(lower)
	lower.add_child(_needs_panel(life, inv, sim))
	lower.add_child(_safety_panel(life, inv))

func _person_card(p: Dictionary, life: RefCounted, inv: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MHStyle.box(Color(1, 1, 1, .04), Color(1, 1, 1, .1), 10, 1, Vector4(16, 14, 16, 14)))
	card.custom_minimum_size.x = 470
	var col := MHStyle.vbox(8)
	card.add_child(col)
	var role: Dictionary = life.role(str(p.role))
	var top := MHStyle.hbox(10)
	top.add_child(MHStyle.icon("user-round", 22, MHStyle.accent))
	var field := LineEdit.new()
	field.text = str(p.name)
	field.max_length = 24
	field.custom_minimum_size = Vector2(230, 40)
	field.add_theme_font_size_override("font_size", 18)
	_fields.append(field)
	top.add_child(field)
	top.add_child(MHStyle.spacer())
	top.add_child(MHStyle.badge(str(role.get("label", p.role)), "neutral"))
	col.add_child(top)
	var room_kind := str(role.get("room", ""))
	var has_room := (inv.rooms as Array).any(func(r): return str(r.kind) == room_kind)
	var room_label := str(BuildController.ZONE_TYPES.get(room_kind, {}).get("label", room_kind))
	col.add_child(MHStyle.label("Works in: %s%s" % [room_label, "" if has_room else "  (not built yet)"], 14, MHStyle.TEXT_SECONDARY if has_room else MHStyle.WARN))
	if life.crew_on:
		col.add_child(_bar("Fitness", float(p.fitness), float(life.value("fitness", "danger", 70.0))))
		col.add_child(_bar("Wellbeing", float(p.wellbeing), float(life.value("wellbeing", "danger", 60.0))))
	var fav := str(p.get("favourite", ""))
	var fav_label := str(EquipmentCatalog.get_entry(fav).get("label", fav))
	var has_fav := (inv.all_items as Array).any(func(i): return str(i.id) == fav)
	col.add_child(MHStyle.label("Favourite thing: %s %s" % [fav_label, "✓" if has_fav else "(not in the base)"], 14, MHStyle.VALID if has_fav else MHStyle.TEXT_MUTED))
	if float(p.injured_h) > 0.0:
		col.add_child(MHStyle.label("Injured: %d sols to recover in the Medical Bay" % ceili(float(p.injured_h) / 24.0), 15, MHStyle.DANGER, 600))
	return card

func _bar(label: String, value: float, danger: float) -> Control:
	var row := MHStyle.hbox(10)
	var caption := MHStyle.label(label, 14, MHStyle.TEXT_SECONDARY)
	caption.custom_minimum_size.x = 90
	row.add_child(caption)
	var bar := ProgressBar.new()
	bar.min_value = 0; bar.max_value = 100; bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(250, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tone: Color = MHStyle.VALID if value >= danger + 10.0 else (MHStyle.WARN if value >= danger else MHStyle.DANGER)
	bar.add_theme_stylebox_override("background", MHStyle.box(Color(1, 1, 1, .08), Color(0, 0, 0, 0), 6))
	bar.add_theme_stylebox_override("fill", MHStyle.box(tone, Color(0, 0, 0, 0), 6))
	row.add_child(bar)
	row.add_child(MHStyle.mono("%d%%" % roundi(value), 14, tone))
	return row

func _needs_panel(life: RefCounted, inv: Dictionary, sim: RefCounted) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MHStyle.box(Color(1, 1, 1, .03), Color(1, 1, 1, .08), 10, 1, Vector4(18, 16, 18, 16)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := MHStyle.vbox(10)
	panel.add_child(col)
	col.add_child(MHStyle.eyebrow("What the crew need", MHStyle.accent, 13))
	var icons := {"sleep": "bed-double", "space": "panels-top-left", "together": "utensils", "home": "image", "work": "wrench", "contact": "satellite"}
	for need in life.needs(inv, sim.last.get("tiers", {4: true})):
		var row := MHStyle.hbox(10)
		var met := float(need.score) >= .9
		row.add_child(MHStyle.icon(str(icons.get(str(need.id), "info")), 20, MHStyle.VALID if met else MHStyle.WARN))
		var words := MHStyle.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(MHStyle.label("%s  ·  %d%%" % [str(need.label), roundi(float(need.score) * 100.0)], 16, MHStyle.TEXT_PRIMARY, 600))
		if not met: words.add_child(MHStyle.label(str(need.missing), 14, MHStyle.TEXT_SECONDARY))
		row.add_child(words)
		col.add_child(row)
	return panel

func _safety_panel(life: RefCounted, inv: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MHStyle.box(Color(1, 1, 1, .03), Color(1, 1, 1, .08), 10, 1, Vector4(18, 16, 18, 16)))
	panel.custom_minimum_size.x = 560
	var col := MHStyle.vbox(10)
	panel.add_child(col)
	col.add_child(MHStyle.eyebrow("Ready for trouble", MHStyle.accent, 13))
	var place: Dictionary = life.shelter(inv)
	var safe := float(life.value("radiation", "safe_points", 20.0))
	if place.is_empty(): _line(col, "radiation", "Storm shelter: none yet (place a Storm Shelter Locker)", false)
	else: _line(col, "radiation", "Storm shelter: %s, %d of %d shield points, room for %d" % [str(place.label), roundi(float(place.rating)), roundi(safe), int(place.capacity)], bool(place.ok))
	var share: float = MHMissions.largest_section(builder)
	_line(col, "gauge", "Biggest section: %d%% of the base (rooms sharing air)" % roundi(share * 100.0), share <= .4)
	_line(col, "wind", "Air reserve: %d kg (refills about %d floor squares)" % [roundi(float(life.air_reserve_kg)), floori(float(life.air_reserve_kg) / float(life.value("breach", "air_kg_per_cell", 31.0)))], float(life.air_reserve_kg) > 0.0)
	_line(col, "wrench", "Hull patch kit: %s" % ("ready" if (inv.all_items as Array).any(func(i): return str(i.id) == "hull_patch_kit") else "none"), (inv.all_items as Array).any(func(i): return str(i.id) == "hull_patch_kit"))
	_line(col, "package", "Spare parts: %d%s" % [int(life.spares), "  ·  %d machine%s broken" % [(life.broken as Dictionary).size(), "" if (life.broken as Dictionary).size() == 1 else "s"] if not (life.broken as Dictionary).is_empty() else ""], int(life.spares) > 0)
	_line(col, "sun", "Radiation dose so far: %d mSv" % roundi(float(life.dose_msv)), true)
	return panel

func _line(col: VBoxContainer, icon: String, text: String, good: bool) -> void:
	var row := MHStyle.hbox(10)
	row.add_child(MHStyle.icon(icon, 20, MHStyle.VALID if good else MHStyle.WARN))
	var l := MHStyle.label(text, 15, MHStyle.TEXT_PRIMARY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	col.add_child(row)

func _save_names() -> void:
	var names: Array = _fields.map(func(f): return (f as LineEdit).text.strip_edges())
	var life: RefCounted = builder.simulation().life
	life.set_names(names)
	if MHMissions.active(): MHMissions.set_crew_names((life.crew as Array).map(func(p): return str(p.name)))
	get_tree().call_group("habitat_world", "save_mission_progress")

func _close() -> void:
	if not _fields.is_empty(): _save_names()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
