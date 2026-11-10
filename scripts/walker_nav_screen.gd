extends CanvasLayer

## Walker 1's nav screen, on its front deck (scripts/walker.gd; master-design §2,
## "Knocked off course"). With the sun and stars hidden by the storm it fell
## back on magnetic heading, and the Reach's crustal field bent it: it's lost,
## not broken. Seated in front of the screen you set it right, in three steps:
## 1. Sight: steer its mast camera onto the sun (Phobos at night) and hold it
##    there. True north is fixed, and the screen shows how far off its compass
##    was: a quiet seed for the buried heart.
## 2. Fix: match landmarks you've been to against its own blurry scan. Each
##    one tightens its position circle until it locks. Places you've never
##    been to can't be picked: what you explored pays off.
## 3. Home: mark the lander as home, and it stands up and walks.
## Text is fine here: it's a working display (no lettering on the model).
## Esc closes it; a fixed sight is kept.

const SIGHT_HOLD := 2.5        # seconds on target to fix true north
const SIGHT_ON := 20.0         # pixels from the body's centre that count as on it
const SKY := 320.0             # the viewfinder, pixels across
const SCAN := 320.0            # the terrain scan, pixels across
const SCAN_METRES := 3600.0    # metres across the scan
const START_RADIUS := 1200.0   # its position circle before any landmark, metres
const LOCK_RADIUS := 100.0
const ALONE_SECONDS := 4.0     # one landmark only: it takes longer to settle

var walker: Node
var world: Node
var step := "sight"
var error_deg := 0
var landmarks: Array = []      # {id, name, at: Vector2 (region m), known: bool}
var picks: Array = []
var need := 2
var radius := START_RADIUS
var _held := 0.0
var _clock := 0.0
var _alone := -1.0
var _target := Vector2(96, -64)
var _body_name := "the sun"
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _freeze_before := false
var _panel: PanelContainer
var _title: Label
var _status: Label
var _area: VBoxContainer
var _sky: Control
var _scan: Control
var _scan_tex: Texture2D

func setup(target_walker: Node) -> void:
	walker = target_walker
	world = walker.world
	layer = 20
	name = "WalkerNavScreen"
	error_deg = 24 + absi(int(walker.global_position.x * 7.0 + walker.global_position.z * 3.0)) % 27
	if bool(walker.nav_sight_done): step = "fix"
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var hour := MHGame.sol_hour
	if hour < float(cycle.get("sunrise_hour", 5.0)) or hour > float(cycle.get("sunset_hour", 19.0)): _body_name = "Phobos"
	_gather_landmarks()

func _ready() -> void:
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: Node = world.get("player") if world != null else null
	if player != null:
		_freeze_before = bool(player.get_meta("ui_freeze", false))
		player.set_meta("ui_freeze", true)
	_panel = PanelContainer.new()
	_panel.theme = MHStyle.theme()
	_panel.add_theme_stylebox_override("panel", MHStyle.hud_box(22, true))
	_panel.anchor_left = .5
	_panel.anchor_right = .5
	_panel.anchor_top = .5
	_panel.anchor_bottom = .5
	_panel.offset_left = -400
	_panel.offset_right = 400
	_panel.offset_top = -290
	_panel.offset_bottom = 290
	add_child(_panel)
	var column := MHStyle.vbox(12)
	_panel.add_child(column)
	var head := MHStyle.hbox(12)
	head.add_child(MHStyle.eyebrow("WALKER 1 · NAVIGATION", MHStyle.accent, 14))
	head.add_child(MHStyle.spacer())
	head.add_child(MHStyle.mono("ESC CLOSE", 12, MHStyle.TEXT_MUTED, 700))
	column.add_child(head)
	_title = MHStyle.label("", 24, MHStyle.TEXT_PRIMARY, 700)
	column.add_child(_title)
	_status = MHStyle.body("", 17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_area = MHStyle.vbox(10)
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_area)
	_show_step()

func _exit_tree() -> void:
	Input.mouse_mode = _mouse_before if _mouse_before != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	var player: Node = world.get("player") if world != null else null
	if player != null: player.set_meta("ui_freeze", _freeze_before)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if is_queued_for_deletion(): return
	MHAudio.sfx("ui_back", -12.0)
	if walker != null: walker.nav_closed()
	queue_free()

# ---------- the steps ----------

func _show_step() -> void:
	for child in _area.get_children(): child.free()
	_sky = null
	_scan = null
	match step:
		"sight":
			_title.text = "1 · Find true north"
			_status.text = "Its compass can't be trusted. Put the crosshair on %s with the mouse and hold it there." % _body_name
			_sky = Control.new()
			_sky.custom_minimum_size = Vector2(SKY, SKY)
			_sky.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_sky.mouse_filter = Control.MOUSE_FILTER_PASS
			_sky.draw.connect(_draw_sky)
			_area.add_child(_sky)
		"fix":
			_title.text = "2 · Where is it?"
			_status.text = "True north fixed. Its magnetic compass was off by %d°. Now match landmarks you know to its scan. %s" % [error_deg, _fix_text()]
			var row := MHStyle.hbox(16)
			_area.add_child(row)
			_scan = Control.new()
			_scan.custom_minimum_size = Vector2(SCAN, SCAN)
			_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scan.draw.connect(_draw_scan)
			row.add_child(_scan)
			var list := MHStyle.vbox(6)
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(list)
			for mark in landmarks:
				var picked: bool = str(mark.id) in picks
				var text: String = str(mark.name) if bool(mark.known) else "Unknown: you've never been there"
				var button := MHStyle.button(text + ("  ✓" if picked else ""), "secondary", "", 40)
				button.disabled = picked or not bool(mark.known) or picks.size() >= need
				var id := str(mark.id)
				button.pressed.connect(func() -> void: pick(id))
				list.add_child(button)
		"home":
			_title.text = "3 · Home"
			_status.text = "Position locked. Its compass was off by %d°, and nobody expected the ground here to pull it that far. It's ready to walk." % error_deg
			var go := MHStyle.button("Set home: the lander", "primary", "", 52)
			go.pressed.connect(set_home)
			_area.add_child(go)

func _fix_text() -> String:
	if picks.size() >= need: return ""
	if need == 1: return "You only know the lander well enough. It'll take a little longer."
	return "%d more." % (need - picks.size())

func _process(delta: float) -> void:
	_clock += delta
	if step == "sight" and _sky != null:
		var at := _body_at()
		var mouse := _sky.get_local_mouse_position() - Vector2(SKY, SKY) * .5
		if mouse.distance_to(at) <= SIGHT_ON:
			_held += delta
			if _held >= SIGHT_HOLD:
				sight_fixed()   # the next step's screen replaces the sky: nothing left to redraw
				return
		else:
			_held = maxf(0.0, _held - delta * 2.0)
		_sky.queue_redraw()
	elif step == "fix":
		if _alone >= 0.0:
			_alone += delta
			radius = lerpf(START_RADIUS * .25, LOCK_RADIUS, clampf(_alone / ALONE_SECONDS, 0.0, 1.0))
			if _alone >= ALONE_SECONDS:
				_alone = -1.0
				_locked()
		if _scan != null: _scan.queue_redraw()

## Where the body sits in the viewfinder (from its centre): the mast sways.
func _body_at() -> Vector2:
	return _target + Vector2(sin(_clock * .7), cos(_clock * .5)) * 34.0

func sight_fixed() -> void:
	if step != "sight": return
	walker.nav_sight_done = true
	MHAudio.sfx("suit_beep", -6.0)
	step = "fix"
	_show_step()

## A landmark you know, matched to its scan: the circle tightens.
func pick(id: String) -> bool:
	if step != "fix" or id in picks or picks.size() >= need: return false
	var mark: Dictionary = {}
	for m in landmarks: if str(m.id) == id: mark = m
	if mark.is_empty() or not bool(mark.known): return false
	picks.append(id)
	MHAudio.sfx("place", -8.0)
	if picks.size() >= need:
		if need == 1:
			radius = START_RADIUS * .25
			_alone = 0.0
		else:
			_locked()
			return true
	else:
		radius = START_RADIUS * pow(.25, picks.size())
	_show_step()
	return true

func _locked() -> void:
	radius = LOCK_RADIUS
	MHAudio.sfx("suit_beep", -4.0)
	step = "home"
	_show_step()

func set_home() -> void:
	if step != "home": return
	walker.recalibrated()
	close()

# ---------- what it can match ----------

## Landmarks: the lander, and what you've been to yourself (the known-things
## record); a few of the region's places you haven't, greyed out.
func _gather_landmarks() -> void:
	landmarks.clear()
	var known: Node = world.get("known")
	var lander: Vector3 = world.lander.global_position
	var origin: Vector2 = known.origin if known != null else Vector2.ZERO
	landmarks.append({"id": "lander", "name": "The lander", "at": Vector2(lander.x, lander.z) + origin, "known": true})
	var names := {}
	if known != null:
		for id in known.things:
			var thing: Dictionary = known.things[id]
			if str(id) == str(walker.ID) or not ("you" in (thing.who as Array)): continue
			if str(thing.get("kind", "")) not in ["find", "place"]: continue
			var thing_name := str(thing.name)
			if names.has(thing_name): continue
			names[thing_name] = true
			landmarks.append({"id": str(id), "name": thing_name, "at": thing.at, "known": true})
	var unknown := 0
	for feature in RegionTerrain.meta().get("features", []):
		if unknown >= 2 or names.has(str(feature.name)): continue
		var spot := Vector2(float(feature.position[0]), float(feature.position[1]))
		if known != null and known.knows(known.place_id(str(feature.name), spot)): continue
		landmarks.append({"id": "unknown_%d" % unknown, "name": str(feature.name), "at": spot, "known": false})
		unknown += 1
	var count := 0
	for m in landmarks: if bool(m.known): count += 1
	need = mini(2, count)

const RegionTerrain := preload("res://scripts/region_terrain.gd")
const KNOWN := preload("res://scripts/known_things.gd")

# ---------- drawing ----------

func _draw_sky() -> void:
	var c := Vector2(SKY, SKY) * .5
	var night := _body_name != "the sun"
	_sky.draw_circle(c, SKY * .5, Color(.05, .07, .12) if night else Color(.42, .3, .22))
	_sky.draw_arc(c, SKY * .5 - 1.0, 0.0, TAU, 64, MHStyle.BORDER_STRONG, 2.0)
	var at := c + _body_at()
	if night:
		_sky.draw_circle(at, 7.0, Color(.85, .8, .72))
	else:
		_sky.draw_circle(at, 18.0, Color(.75, .85, 1.0, .35))   # the blue round the sun
		_sky.draw_circle(at, 10.0, Color(1.0, .97, .9))
	var mouse := _sky.get_local_mouse_position()
	var cross := MHStyle.accent
	_sky.draw_line(mouse + Vector2(-16, 0), mouse + Vector2(-5, 0), cross, 2.0)
	_sky.draw_line(mouse + Vector2(5, 0), mouse + Vector2(16, 0), cross, 2.0)
	_sky.draw_line(mouse + Vector2(0, -16), mouse + Vector2(0, -5), cross, 2.0)
	_sky.draw_line(mouse + Vector2(0, 5), mouse + Vector2(0, 16), cross, 2.0)
	if _held > 0.0: _sky.draw_arc(mouse, 24.0, -PI / 2.0, -PI / 2.0 + TAU * _held / SIGHT_HOLD, 40, MHStyle.VALID, 3.0)

func _draw_scan() -> void:
	var known: Node = world.get("known")
	var lander: Vector3 = world.lander.global_position
	var origin: Vector2 = known.origin if known != null else Vector2.ZERO
	var centre := Vector2(lander.x, lander.z) + origin
	var scale := SCAN / SCAN_METRES
	if _scan_tex == null:
		var image: Image = KNOWN._survey()
		if image != null: _scan_tex = ImageTexture.create_from_image(image)
	var half: float = known.half if known != null else 3072.0
	if _scan_tex != null:
		var px := _scan_tex.get_width() / (half * 2.0)
		var src := Rect2((centre - Vector2(SCAN_METRES, SCAN_METRES) * .5 + Vector2(half, half)) * px, Vector2(SCAN_METRES, SCAN_METRES) * px)
		_scan.draw_texture_rect_region(_scan_tex, Rect2(Vector2.ZERO, Vector2(SCAN, SCAN)), src)
	else:
		_scan.draw_rect(Rect2(Vector2.ZERO, Vector2(SCAN, SCAN)), Color(.12, .09, .07))
	_scan.draw_rect(Rect2(Vector2.ZERO, Vector2(SCAN, SCAN)), MHStyle.BORDER_STRONG, false, 1.0)
	var to_screen := func(region: Vector2) -> Vector2: return (region - centre) * scale + Vector2(SCAN, SCAN) * .5
	var here: Vector2 = Vector2(walker.global_position.x, walker.global_position.z) + origin
	for mark in landmarks:
		if not (str(mark.id) in picks): continue
		var p: Vector2 = to_screen.call(mark.at)
		_scan.draw_line(p, to_screen.call(here), Color(MHStyle.accent, .5), 1.5)
		_scan.draw_circle(p, 5.0, MHStyle.accent)
	_scan.draw_arc(to_screen.call(here), maxf(4.0, radius * scale), 0.0, TAU, 48, MHStyle.VALID if radius <= LOCK_RADIUS else MHStyle.WARN, 2.0)
