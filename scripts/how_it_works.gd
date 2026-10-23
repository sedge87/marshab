extends Node

## "How it works": game-mechanic tutorial cards (data/how_it_works.json).
## Each card explains one system in very simple words, with a picture, the
## one thing to remember, and a one-tap check (never graded). Cards appear:
##   - in a mission's brief ("What you need to know");
##   - from the mission panel (K: the card behind the current step);
##   - the first time you place a key machine (once ever);
##   - from a failed Test check ("How it works: Heating");
##   - in Mission Control's Field guide (every card unlocked so far).
## show() opens the viewer over anything (it pauses the game while open).

const PATH := "res://data/how_it_works.json"
const SEEN_PATH := "user://how_it_works.cfg"
const MHMissions := preload("res://scripts/mh_missions.gd")

## Which card explains a failed Test check.
const CHECK_CARDS := {"always_powered": "power", "life_support_powered": "power", "min_temp": "heating", "breathable": "air",
	"crew_aboard": "crew", "crew_safe": "crew", "crew_health_min": "crew", "water_per_sol": "water", "food_grown": "food", "research": "research"}

static var _cards: Array = []

static func cards() -> Array:
	if _cards.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _cards = parsed.get("cards", [])
	return _cards

static func card(id: String) -> Dictionary:
	for each in cards():
		if str(each.id) == id: return each
	return {}

static func for_mission(mission_id: String) -> Array:
	return cards().filter(func(c): return (c.get("missions", []) as Array).has(mission_id)).map(func(c): return str(c.id))

## The card for something you just placed (an item or zone id), or "".
static func for_trigger(id: String) -> String:
	for each in cards():
		if (each.get("triggers", []) as Array).has(id): return str(each.id)
	return ""

## The card behind a mission step (by what it asks for).
static func for_step(step: Dictionary) -> String:
	for key in ["learn", "item", "kind"]:
		var value := str(step.get(key, ""))
		if value.is_empty(): continue
		if key == "learn": return value
		var found := for_trigger(value)
		if not found.is_empty(): return found
	match str(step.get("check", "")):
		"tested", "passed": return "testing"
		"counter": return "gar_y" if str(step.get("key", "")) == "gar_y_surveys" else ""
		"food_share": return "food"
		"item_any": return "food"
	return ""

## Every card unlocked so far: in Missions, those for missions up to the
## current one; elsewhere, all of them.
static func unlocked() -> Array:
	if not MHMissions.active(): return cards().map(func(c): return str(c.id))
	var number := int(MHMissions.current().get("number", 1))
	var ids: Array = []
	for mission in MHMissions.missions():
		if int(mission.number) > number: continue
		for id in for_mission(str(mission.id)):
			if not ids.has(id): ids.append(id)
	return ids

# ---------- seen once ----------

static func seen(id: String) -> bool:
	var file := ConfigFile.new()
	if file.load(SEEN_PATH) != OK: return false
	return bool(file.get_value("seen", id, false))

static func mark_seen(ids: Array) -> void:
	var file := ConfigFile.new()
	file.load(SEEN_PATH)
	for id in ids: file.set_value("seen", str(id), true)
	file.save(SEEN_PATH)

## Placing something for the first time: show its card once (not in tests,
## Showcase or with tutorial cards switched off).
static func first_time(tree: SceneTree, placed_id: String) -> void:
	var id := for_trigger(placed_id)
	if id.is_empty() or seen(id) or not enabled(): return
	show(tree, [id], "New: how this works")

static func enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not MHGame.showcase and bool(MHGame.setting("tutorial_cards"))

# ---------- the viewer ----------

## Open the viewer on these cards (in order). Returns the viewer node.
static func show(tree: SceneTree, ids: Array, eyebrow := "How it works") -> Node:
	if ids.is_empty(): return null
	for node in tree.get_nodes_in_group("how_it_works_viewer"): node.queue_free()
	var viewer: Node = load("res://scripts/how_it_works.gd").new()
	viewer.ids = ids.duplicate()
	viewer.eyebrow = eyebrow
	tree.root.add_child(viewer)
	mark_seen(ids)
	return viewer

var ids: Array = []
var eyebrow := "How it works"
var index := 0
var _layer: CanvasLayer
var _body: VBoxContainer
var _was_paused := false
var _mouse := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	add_to_group("how_it_works_viewer")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer = CanvasLayer.new()
	_layer.layer = 45
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = MHStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, .7)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := MHStyle.menu_panel(28, true)
	panel.custom_minimum_size.x = 940
	centre.add_child(panel)
	_body = MHStyle.vbox(14)
	panel.add_child(_body)
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE: _close()
			KEY_RIGHT, KEY_ENTER: _go(1)
			KEY_LEFT: _go(-1)
		get_viewport().set_input_as_handled()

func _go(step: int) -> void:
	var next := index + step
	if next >= ids.size():
		_close()
		return
	index = clampi(next, 0, ids.size() - 1)
	_render()

func _close() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse
	queue_free()

func _render() -> void:
	for child in _body.get_children(): child.queue_free()
	var c := card(str(ids[index]))
	if c.is_empty():
		_close()
		return
	var head := MHStyle.hbox(10)
	head.add_child(MHStyle.icon(str(c.get("icon", "info")), 26, MHStyle.accent))
	var titles := MHStyle.vbox(2)
	titles.add_child(MHStyle.eyebrow("%s%s" % [eyebrow, "  ·  %d of %d" % [index + 1, ids.size()] if ids.size() > 1 else ""], MHStyle.accent, 13))
	titles.add_child(MHStyle.title(str(c.title), 28))
	head.add_child(titles)
	_body.add_child(head)
	var picture := Picture.new()
	picture.id = str(c.get("picture", c.id))
	picture.custom_minimum_size = Vector2(880, 250)
	_body.add_child(picture)
	for i in range((c.lines as Array).size()):
		var row := MHStyle.hbox(10)
		var number := MHStyle.mono("%d" % (i + 1), 16, MHStyle.accent, 700)
		number.custom_minimum_size.x = 18
		row.add_child(number)
		var line := MHStyle.body(str(c.lines[i]), 18, MHStyle.TEXT_PRIMARY)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		_body.add_child(row)
	var remember := PanelContainer.new()
	remember.add_theme_stylebox_override("panel", MHStyle.box(Color(MHStyle.accent, .14), Color(MHStyle.accent, .7), 8, 1, Vector4(16, 10, 16, 12)))
	var remember_text := MHStyle.body("Remember: " + str(c.remember), 18, MHStyle.TEXT_PRIMARY)
	remember_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	remember.add_child(remember_text)
	_body.add_child(remember)
	_add_check(c)
	var buttons := MHStyle.hbox(12)
	if index > 0:
		var back := MHStyle.button("Back", "secondary", "chevron-left")
		back.pressed.connect(_go.bind(-1))
		buttons.add_child(back)
	buttons.add_child(MHStyle.spacer())
	var next := MHStyle.button("Next" if index < ids.size() - 1 else "Got it", "primary", "chevron-right" if index < ids.size() - 1 else "circle-check")
	next.pressed.connect(_go.bind(1))
	buttons.add_child(next)
	_body.add_child(buttons)

## The quick check: tap an answer, see straight away if it's right.
func _add_check(c: Dictionary) -> void:
	var check: Dictionary = c.get("check", {})
	if check.is_empty(): return
	_body.add_child(MHStyle.eyebrow("Quick check: " + str(check.question), MHStyle.TEXT_SECONDARY, 13))
	var options: Array = check.options
	var right: String = str(options[int(check.answer)])
	# The same order every time for a card, but not always the right one first.
	var order: Array = range(options.size())
	var mix := hash(str(c.id))
	for i in range(order.size() - 1, 0, -1):
		var j := posmod(mix + i * 7, i + 1)
		var swap = order[i]; order[i] = order[j]; order[j] = swap
	var row := MHStyle.hbox(10)
	var verdict := MHStyle.body("", 16, MHStyle.TEXT_SECONDARY)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for o in order:
		var text := str(options[o])
		var choice := MHStyle.button(text, "secondary", "", 44)
		choice.pressed.connect(func() -> void:
			if text == right:
				verdict.text = "Right!"
				verdict.add_theme_color_override("font_color", MHStyle.VALID)
				MHAudio.sfx("ui_confirm", -6.0, 0.0)
			else:
				verdict.text = "Not quite. It's: %s." % right
				verdict.add_theme_color_override("font_color", MHStyle.WARN)
				MHAudio.sfx("invalid", -8.0, 0.0))
		row.add_child(choice)
	_body.add_child(row)
	_body.add_child(verdict)

# ---------- the pictures ----------

## Simple diagrams in the game's style: labelled boxes with icons, arrows.
class Picture extends Control:
	var id := ""
	const WARM := Color("#E98A45")
	const COOL := Color("#5DC8F9")
	const GOOD := Color("#3EE58A")
	const BAD := Color("#E5484D")
	const DIM := Color(1, 1, 1, .35)

	func _draw() -> void:
		draw_style_box(MHStyle.box(Color(1, 1, 1, .04), Color(1, 1, 1, .08), 10, 1), Rect2(Vector2.ZERO, size))
		match id:
			"landing": _landing()
			"testing": _testing()
			"power": _power()
			"water": _water()
			"gar_y": _gar_y()
			"heating": _heating()
			"air": _air()
			"crew": _crew()
			"food": _food()
			"storms": _storms()
			"research": _research()

	func _node(at: Vector2, icon: String, label: String, colour: Color, w := 150.0) -> Rect2:
		var r := Rect2(at - Vector2(w * .5, 34), Vector2(w, 68))
		draw_style_box(MHStyle.box(Color(colour, .16), colour, 8, 2), r)
		draw_texture_rect(MHIcons.texture(icon, 22), Rect2(at + Vector2(-11, -28), Vector2(22, 22)), false, colour)
		_text(label, at + Vector2(0, 20), 14, MHStyle.TEXT_PRIMARY)
		return r

	func _text(text: String, at: Vector2, font_size := 14, colour := MHStyle.TEXT_SECONDARY) -> void:
		var font := MHStyle.font(600)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, at - Vector2(w * .5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)

	func _arrow(a: Vector2, b: Vector2, colour: Color, label := "") -> void:
		draw_line(a, b, colour, 3.0)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([b, b - dir * 12 + side * 7, b - dir * 12 - side * 7]), colour)
		if not label.is_empty(): _text(label, (a + b) * .5 + Vector2(0, -10), 13, colour)

	func _landing() -> void:
		var target := Vector2(300, 125)
		draw_arc(target, 100, 0, TAU, 64, Color(COOL, .6), 2.0)
		_text("Landing ellipse", target + Vector2(0, -108), 13, COOL)
		draw_circle(target, 52, Color(BAD, .15))
		draw_arc(target, 52, 0, TAU, 48, BAD, 2.0)
		_text("Blast zone", target + Vector2(0, 74), 13, BAD)
		draw_texture_rect(MHIcons.texture("rocket", 32), Rect2(target - Vector2(16, 16), Vector2(32, 32)), false, MHStyle.TEXT_PRIMARY)
		_node(Vector2(620, 80), "circle-check", "Base out here", GOOD)
		_node(Vector2(620, 180), "circle-x", "Not in the blast", BAD)
		_arrow(Vector2(540, 80), Vector2(405, 115), GOOD)

	func _testing() -> void:
		var xs := [110.0, 330.0, 550.0, 770.0]
		var labels := [["hammer", "Design"], ["play", "Test (T)"], ["clipboard-check", "Read why"], ["wrench", "Improve"]]
		for i in 4:
			_node(Vector2(xs[i], 110), labels[i][0], labels[i][1], WARM if i == 1 else COOL, 160)
			if i < 3: _arrow(Vector2(xs[i] + 82, 110), Vector2(xs[i + 1] - 82, 110), DIM)
		draw_line(Vector2(770, 146), Vector2(770, 200), DIM, 3.0)
		draw_line(Vector2(770, 200), Vector2(110, 200), DIM, 3.0)
		_arrow(Vector2(110, 200), Vector2(110, 148), DIM)
		_text("Again, until it passes", Vector2(440, 225), 14, MHStyle.TEXT_SECONDARY)

	func _power() -> void:
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x * .5, size.y)), Color(1, .8, .3, .06))
		_text("DAY", Vector2(220, 30), 15, Color(1, .8, .3))
		_text("NIGHT", Vector2(660, 30), 15, COOL)
		_node(Vector2(90, 120), "sun", "Solar arrays", Color(1, .8, .3), 140)
		_node(Vector2(330, 75), "zap", "Batteries fill", GOOD, 140)
		_node(Vector2(330, 185), "panels-top-left", "Base runs", MHStyle.TEXT_PRIMARY, 140)
		_arrow(Vector2(162, 110), Vector2(258, 82), Color(1, .8, .3))
		_arrow(Vector2(162, 130), Vector2(258, 178), Color(1, .8, .3))
		_node(Vector2(560, 120), "sun", "No sun", DIM, 130)
		_node(Vector2(720, 75), "zap", "Batteries empty", COOL, 150)
		_node(Vector2(720, 185), "panels-top-left", "Base runs", MHStyle.TEXT_PRIMARY, 140)
		_arrow(Vector2(720, 110), Vector2(720, 150), COOL)

	func _water() -> void:
		draw_rect(Rect2(Vector2(0, 190), Vector2(size.x, 60)), Color(COOL, .18))
		_text("Buried ice", Vector2(120, 228), 14, COOL)
		draw_line(Vector2(150, 190), Vector2(150, 120), MHStyle.TEXT_PRIMARY, 4.0)
		_node(Vector2(150, 90), "droplets", "Ice drill", COOL, 140)
		_node(Vector2(410, 90), "droplets", "Water tank", COOL, 140)
		_node(Vector2(670, 90), "users", "Crew use it", MHStyle.TEXT_PRIMARY, 150)
		_arrow(Vector2(222, 90), Vector2(338, 90), COOL, "melted")
		_arrow(Vector2(482, 90), Vector2(593, 90), COOL)
		_node(Vector2(540, 200), "recycle", "Reclaimer", GOOD, 140)
		_arrow(Vector2(670, 126), Vector2(612, 178), GOOD, "used water")
		_arrow(Vector2(468, 190), Vector2(420, 126), GOOD, "clean again")

	func _gar_y() -> void:
		var c := Vector2(440, 125)
		draw_circle(c, 105, Color(0, 0, 0, .25))
		draw_arc(c, 105, 0, TAU, 64, Color(WARM, .6), 2.0)
		_text("Hold G", c + Vector2(0, 6), 18, MHStyle.TEXT_PRIMARY)
		var orders := [["footprints", "Come here"], ["map-pin", "Stay"], ["door-closed", "Go home"], ["mountain-snow", "Survey there"], ["flask-conical", "Core sample"]]
		for i in orders.size():
			var a := i * TAU / orders.size()
			var p := c + Vector2(sin(a), -cos(a)) * 80
			draw_circle(p, 22, WARM if i == 3 else Color(.1, .12, .14))
			draw_texture_rect(MHIcons.texture(orders[i][0], 20), Rect2(p - Vector2(10, 10), Vector2(20, 20)), false, MHStyle.TEXT_PRIMARY)
			_text(orders[i][1], p + Vector2(sin(a), -cos(a)) * 48 + Vector2(0, 5), 13, WARM if i == 3 else MHStyle.TEXT_SECONDARY)

	func _heating() -> void:
		_text("Spot heater: its room and next door", Vector2(220, 30), 14, WARM)
		_text("Thermal control unit: every room", Vector2(660, 30), 14, GOOD)
		for i in 4:
			var warm_l := i <= 1
			var r := Rect2(Vector2(20 + i * 100, 60), Vector2(92, 120))
			draw_rect(r, Color(WARM if warm_l else COOL, .3))
			draw_rect(r, WARM if warm_l else COOL, false, 2.0)
			_text("Warm" if warm_l else ("Cold spot" if i == 3 else "Cold"), r.get_center() + Vector2(0, 46), 13, MHStyle.TEXT_PRIMARY)
		draw_texture_rect(MHIcons.texture("flame", 30), Rect2(Vector2(51, 95), Vector2(30, 30)), false, WARM)
		for i in 4:
			var r := Rect2(Vector2(460 + i * 100, 60), Vector2(92, 120))
			draw_rect(r, Color(WARM, .3))
			draw_rect(r, WARM, false, 2.0)
			draw_line(Vector2(r.get_center().x, 190), Vector2(r.get_center().x, 180), GOOD, 3.0)
			_text("Warm", r.get_center() + Vector2(0, 46), 13, MHStyle.TEXT_PRIMARY)
		draw_line(Vector2(506, 190), Vector2(806, 190), GOOD, 3.0)
		_node(Vector2(656, 212), "sun", "", GOOD, 60)
		_text("1 kW power = about 3 kW heat", Vector2(510, 216), 13, GOOD)
		_text("Thermal control unit", Vector2(780, 216), 13, GOOD)

	func _air() -> void:
		_node(Vector2(440, 125), "users", "Crew", MHStyle.TEXT_PRIMARY, 140)
		_node(Vector2(130, 125), "wind", "Oxygen generator", COOL, 190)
		_node(Vector2(750, 125), "recycle", "Air recycler", GOOD, 170)
		_arrow(Vector2(226, 110), Vector2(368, 110), COOL, "oxygen in")
		_arrow(Vector2(512, 140), Vector2(663, 140), GOOD, "CO₂ out")
		_text("Both need power. The generator also needs water.", Vector2(440, 225), 14)

	func _crew() -> void:
		var needs := [["bed-double", "Bunk"], ["wind", "Air"], ["droplets", "Water"], ["wheat", "Food"], ["flame", "Warmth"]]
		for i in needs.size():
			_node(Vector2(100 + i * 170, 80), needs[i][0], needs[i][1], GOOD, 130)
			_arrow(Vector2(100 + i * 170, 116), Vector2(440 + (i - 2) * 30, 168), Color(GOOD, .5))
		_node(Vector2(440, 205), "heart-pulse", "Crew health", BAD, 170)

	func _food() -> void:
		_node(Vector2(140, 80), "package", "Food from Earth", WARM, 180)
		_text("runs out one day", Vector2(140, 140), 13, WARM)
		_node(Vector2(140, 195), "sprout", "Grow trays", GOOD, 180)
		_text("power + water + light", Vector2(140, 250), 13, GOOD)
		_node(Vector2(500, 135), "wheat", "Pantry", MHStyle.TEXT_PRIMARY, 140)
		_node(Vector2(760, 135), "users", "1.8 kg each a sol", MHStyle.TEXT_PRIMARY, 190)
		_arrow(Vector2(232, 90), Vector2(428, 125), WARM)
		_arrow(Vector2(232, 190), Vector2(428, 145), GOOD)
		_arrow(Vector2(572, 135), Vector2(663, 135), MHStyle.TEXT_PRIMARY)

	func _storms() -> void:
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x * .55, size.y)), Color(.85, .45, .2, .14))
		_node(Vector2(110, 120), "sun", "Sun blocked", DIM, 150)
		_node(Vector2(330, 120), "sun", "Solar: much less", WARM, 170)
		_arrow(Vector2(187, 120), Vector2(243, 120), DIM)
		_node(Vector2(640, 75), "zap", "Full batteries first", GOOD, 200)
		_node(Vector2(640, 185), "atom", "Reactor: no change", GOOD, 200)
		_text("Dust storm", Vector2(240, 30), 15, Color(1, .7, .45))

	func _research() -> void:
		_node(Vector2(140, 120), "flask-conical", "Science Lab", COOL, 160)
		_node(Vector2(400, 120), "wrench", "Workbench", COOL, 150)
		_node(Vector2(690, 120), "atom", "Research every sol", GOOD, 210)
		_arrow(Vector2(222, 120), Vector2(323, 120), COOL)
		_arrow(Vector2(477, 120), Vector2(583, 120), GOOD)
		_node(Vector2(400, 215), "truck", "GAR-Y core: +20%", WARM, 200)
		_arrow(Vector2(500, 205), Vector2(640, 158), WARM)
