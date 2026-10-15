class_name MHMissionControl
extends Control

# Mission Control overlay (shot 1j). Three columns over a dimmed scene:
# cargo, readiness and a blueprint plan of the habitat, plus a suggested step.

signal closed

const CATEGORY_LABELS := {"rooms": ["Rooms", "bed-double"], "structure": ["Structure", "box"], "power": ["Power", "sun"]}
const CATEGORY_COLOURS := {"rooms": MHStyle.CELL_LINE, "structure": MHStyle.STRUCTURAL_WHITE, "power": MHStyle.BEACON_YELLOW}

var builder: BuildController

func setup(target_builder: BuildController) -> MHMissionControl:
	builder = target_builder
	return self

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MHStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scrim := MHWidgets.BlurScrim.new()
	scrim.set_dim(.82)
	add_child(scrim)
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 120)
	page.add_theme_constant_override("margin_right", 120)
	page.add_theme_constant_override("margin_top", 72)
	page.add_theme_constant_override("margin_bottom", 64)
	add_child(page)
	var column := MHStyle.vbox(32)
	page.add_child(column)
	# Header
	var header := MHStyle.hbox(16)
	var titles := MHStyle.vbox(8)
	titles.add_child(MHStyle.eyebrow("%s · %s" % [MHGame.colony_name, MHGame.site_name()], MHStyle.accent, 16))
	titles.add_child(MHStyle.display("Mission Control", 64))
	header.add_child(titles)
	header.add_child(MHStyle.spacer())
	var esc := MHStyle.keycap("Esc")
	esc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(esc)
	var close := MHStyle.button("Close", "secondary", "x")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	header.add_child(close)
	column.add_child(header)
	# Three columns
	var body := MHStyle.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_cargo_column())
	body.add_child(_readiness_column())
	body.add_child(_plan_column())
	column.add_child(MHStyle.notice("info", "Suggested next step", builder.suggestion()))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _sheet(width: float, rail := true) -> PanelContainer:
	var p := MHStyle.menu_panel(28, rail)
	p.custom_minimum_size.x = width
	return p

func _cargo_column() -> Control:
	var panel := _sheet(500)
	var col := MHStyle.vbox(16)
	panel.add_child(col)
	var used := builder.used_cargo()
	var remaining := BuildController.CARGO_BUDGET - used
	col.add_child(MHStyle.eyebrow("Cargo remaining"))
	col.add_child(MHStyle.label(MHStyle.kg(remaining), 72, MHStyle.accent if remaining > BuildController.CARGO_BUDGET * .1 else MHStyle.WARN, 600, true))
	col.add_child(MHStyle.mono("of %s delivered" % MHStyle.kg(BuildController.CARGO_BUDGET), 16, MHStyle.TEXT_MUTED))
	var breakdown := builder.cargo_by_category()
	col.add_child(_stacked_bar(breakdown, used))
	for id in ["rooms", "structure", "power"]:
		var row := MHStyle.hbox(12)
		var swatch := ColorRect.new()
		swatch.color = CATEGORY_COLOURS[id]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(MHStyle.label(CATEGORY_LABELS[id][0], 18, MHStyle.TEXT_SECONDARY, 500))
		row.add_child(MHStyle.spacer())
		row.add_child(MHStyle.mono(MHStyle.kg(int(breakdown[id])), 17, MHStyle.TEXT_PRIMARY, 600))
		col.add_child(row)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grow)
	var systems := builder._systems()
	var stats := MHStyle.hbox(12)
	for stat in [["Research", str(systems.research)], ["Zones", str(builder.zones.size())]]:
		var tile := PanelContainer.new()
		tile.theme_type_variation = "RaisedPanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := MHStyle.vbox(4)
		v.add_child(MHStyle.eyebrow(stat[0], MHStyle.TEXT_MUTED, 12))
		v.add_child(MHStyle.mono(stat[1], 28, MHStyle.TEXT_PRIMARY, 600))
		tile.add_child(v)
		stats.add_child(tile)
	col.add_child(stats)
	col.add_child(MHStyle.body("Removing a zone refunds its full mass.", 15, MHStyle.TEXT_MUTED))
	return panel

func _stacked_bar(breakdown: Dictionary, used: int) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size.y = 14
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), MHStyle.INK_800)
		var x := 0.0
		for id in ["rooms", "structure", "power"]:
			var w: float = bar.size.x * float(breakdown[id]) / BuildController.CARGO_BUDGET
			if w > 0.0:
				bar.draw_rect(Rect2(x, 0, w, bar.size.y), CATEGORY_COLOURS[id])
				x += w + (2.0 if w > 2.0 else 0.0))
	return bar

func _readiness_column() -> Control:
	var panel := _sheet(600)
	var col := MHStyle.vbox(12)
	panel.add_child(col)
	var items := builder.readiness()
	var met := builder.readiness_met()
	var head := MHStyle.hbox(8)
	head.add_child(MHStyle.eyebrow("Readiness · Crew of %d" % BuildController.CREW_TARGET))
	head.add_child(MHStyle.spacer())
	head.add_child(MHStyle.mono("%d / %d" % [met, items.size()], 18, MHStyle.VALID if met == items.size() else MHStyle.accent, 700))
	col.add_child(head)
	var score := MHWidgets.Segments.new()
	score.total = items.size()
	score.filled = met
	col.add_child(score)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	col.add_child(spacer)
	# met → partial → unmet
	var order := {"met": 0, "partial": 1, "unmet": 2}
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order[a.status] < order[b.status])
	for item in items:
		col.add_child(MHStyle.readiness_item(item))
		var rule := ColorRect.new()
		rule.color = MHStyle.BORDER_SUBTLE
		rule.custom_minimum_size.y = 1
		col.add_child(rule)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grow)
	col.add_child(MHStyle.body("Simplified game-balance estimates — not NASA specifications.", 14, MHStyle.TEXT_MUTED))
	return panel

func _plan_column() -> Control:
	var panel := _sheet(0, false)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := MHStyle.vbox(12)
	panel.add_child(col)
	var head := MHStyle.hbox(8)
	head.add_child(MHStyle.eyebrow("Habitat plan"))
	head.add_child(MHStyle.spacer())
	head.add_child(MHStyle.mono("Grid 1 m · cell 3 m", 13, MHStyle.TEXT_MUTED))
	col.add_child(head)
	var plan := PlanView.new()
	plan.builder = builder
	plan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(plan)
	var legend := MHStyle.hbox(18)
	for entry in [["Airlock face", MHStyle.accent], ["Room", MHStyle.CELL_LINE], ["Solar", MHStyle.BEACON_YELLOW]]:
		var item := MHStyle.hbox(8)
		var swatch := ColorRect.new()
		swatch.color = entry[1]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		item.add_child(MHStyle.mono(entry[0], 13, MHStyle.TEXT_SECONDARY))
		legend.add_child(item)
	col.add_child(legend)
	return panel

# Blueprint plan generated from the placed zones.
class PlanView extends Control:
	var builder: BuildController
	func _ready() -> void:
		clip_contents = true
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_style_box(MHStyle.box(MHStyle.BLUEPRINT, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_SM), Rect2(Vector2.ZERO, size))
		if builder.zones.is_empty():
			var font := MHStyle.font(500)
			var text := "No zones yet — press B to start building."
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(font, Vector2((size.x - w) * .5, size.y * .5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MHStyle.TEXT_MUTED)
			return
		var min_c := Vector2i(999, 999)
		var max_c := Vector2i(-999, -999)
		for zone in builder.zones:
			for cell in zone.cells:
				min_c = Vector2i(mini(min_c.x, cell.x), mini(min_c.y, cell.y))
				max_c = Vector2i(maxi(max_c.x, cell.x), maxi(max_c.y, cell.y))
		var cells_w := float(max_c.x - min_c.x + 3)
		var cells_h := float(max_c.y - min_c.y + 3)
		var unit := minf(size.x / cells_w, size.y / cells_h)
		var origin := (size - Vector2(cells_w, cells_h) * unit) * .5 + Vector2(unit, unit) - Vector2(min_c) * unit
		# 1 m grid with brighter 3 m cell lines
		var metre := unit / BuildController.CELL
		var boundary := origin - Vector2(unit, unit) * .5
		for k in range(floori(-boundary.x / metre), ceili((size.x - boundary.x) / metre) + 1):
			var x := boundary.x + k * metre
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(MHStyle.CELL_LINE, .22 if posmod(k, 3) == 0 else .07), 1.0)
		for k in range(floori(-boundary.y / metre), ceili((size.y - boundary.y) / metre) + 1):
			var y := boundary.y + k * metre
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(MHStyle.CELL_LINE, .22 if posmod(k, 3) == 0 else .07), 1.0)
		var font_b := MHStyle.font(700, true, 1)
		for zone in builder.zones:
			var kind := str(zone.kind)
			var colour: Color = MHStyle.BEACON_YELLOW if kind == "solar" else (BuildController.ZONE_TYPES[kind].colour as Color).lightened(.2)
			var centre := Vector2.ZERO
			for cell in zone.cells:
				var r := Rect2(origin + Vector2(cell.x - .5, cell.y - .5) * unit, Vector2(unit, unit))
				draw_rect(r.grow(-1), Color(colour, .28))
				centre += r.get_center()
				# Outline only on edges that face outside the zone
				for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if (cell + side) in zone.cells: continue
					var a := r.get_center() + Vector2(side) * unit * .5 + Vector2(side.y, side.x) * unit * .5
					var b := r.get_center() + Vector2(side) * unit * .5 - Vector2(side.y, side.x) * unit * .5
					draw_line(a, b, colour, 2.0)
			centre /= zone.cells.size()
			if kind == "airlock" or kind == "vehicle_bay" or kind == "solar":
				var facing: Vector2i = zone.get("door_direction", Vector2i(0, -1))
				var tip := centre + Vector2(facing) * unit * .9
				var side_v := Vector2(facing.y, -facing.x) * unit * .22
				draw_colored_polygon(PackedVector2Array([tip, centre + Vector2(facing) * unit * .45 + side_v, centre + Vector2(facing) * unit * .45 - side_v]), MHStyle.accent)
			if kind != "solar":
				var text := str(BuildController.ZONE_TYPES[kind].label).to_upper()
				var tw := font_b.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				if tw < unit * sqrt(float(zone.cells.size())) * 1.4:
					draw_string(font_b, centre + Vector2(-tw * .5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MHStyle.INK_100)
