extends Node

## The hand corer (docs/start-and-chapter-one.md §6), from the Outside crate.
## Only on ground GAR-Y has surveyed (no hole without a reason), away from
## the base and not looking at anything: E plants the MC-01 in front of you
## and you work it by hand (stroke by stroke, then open, draw and cap). The core shows the ice's depth
## and purity: shallow, clean ice makes the extractor run faster, and some
## cores come up dry. The first good core is the ice discovery.
## GAR-Y's "Survey zone" finds where to try; the wrist only does life support.

const MHResources := preload("res://scripts/mh_resources.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
const FIELD_KIT := preload("res://scripts/field_kit.gd")
const KEEP_CLEAR_M := 8.0   # from the habitat and landers, so a tap of E still works the doors

const MODEL := "res://assets/equipment/mars_chapter_one_v1/models/hand_corer.glb"
## How far the barrel goes in over a full set of strokes (m): the barrel only, the head stays up.
const SINK_M := .3
## Phase 6: the MC-01 (asset_packs/outpost_field_assets_v1), worked by hand.
const MC01 := "res://assets/models/field/mc01_corer.glb"
const STROKES := 6
const STROKE_GAP := .45      # s: a stroke quicker than this is rushing it
const RUSHED_LIMIT := 2      # rushed strokes that smear the layers: a partial read
const DRAW_SECONDS := 1.2    # holding E to draw the liner up
const PACK_SECONDS := 2.5    # the capped core stays in view this long
const LEAVE_M := 3.0         # walk this far from it and you leave it

var world: Node
var stage := ""              # "", "drive", "open", "draw", "cap", "done"
var ice_shoe := false        # which shoe is on (the ice shoe cuts ice)
var _ring: Control
var _tool: Node3D   # the corer, planted where you're coring
var _rig             # MC01Rig
var _at := Vector3.INF
var _ground := 0.0
var _core := {}
var _strokes := 0
var _rushed := 0
var _stalled := false
var _draw := 0.0
var _clock := 0.0
var _last_stroke := -10.0
var _done_at := 0.0
var _was_down := false
var _was_swap := false

func setup(target_world: Node) -> Node:
	world = target_world
	return self

func _ready() -> void:
	add_to_group("hand_corer")
	add_to_group("interaction_claims")
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.offset_left = -40; _ring.offset_top = -40; _ring.offset_right = 40; _ring.offset_bottom = 40
	_ring.visible = false
	_ring.draw.connect(_draw_ring)
	world.overlay_layer.add_child(_ring)

## Where a core would go now, or INF when it can't.
func _target() -> Vector3:
	if not MHChapterOne.on() or not MHChapterOne.has_corer: return Vector3.INF
	if not FIELD_KIT.holding_in(world, "corer"): return Vector3.INF   # version 3: in your hand (key 1)
	var player: Node3D = world.player
	if player == null or bool(player.get_meta("driving", false)) or bool(player.get_meta("riding", false)) or player._any_build_mode_active(): return Vector3.INF
	if world.builder.is_inside(player.global_position) or world.lander.cabin_contains(player.global_position): return Vector3.INF
	var at := player.global_position - player.global_transform.basis.z * 1.2
	if world.builder.is_inside(at + Vector3.UP * .5): return Vector3.INF
	for node in [world.lander] + (world.cargo_landers as Array):
		if node != null and Vector2(node.global_position.x - at.x, node.global_position.z - at.z).length() < KEEP_CLEAR_M: return Vector3.INF
	if not world.builder.zones.is_empty() and world.builder.call("_zone_at_point", Vector2(at.x, at.z)).size() > 0: return Vector3.INF
	if not ICE_KNOWLEDGE.surveyed(ICE_KNOWLEDGE.samples(get_tree()), Vector2(at.x, at.z)): return Vector3.INF
	return at

## Why holding E here takes no core, when the only reason is the ground
## hasn't been surveyed (shown while you hold E): the way to the nearest
## stake, or how to get a survey. "" otherwise.
func why_not() -> String:
	if not MHChapterOne.on() or not MHChapterOne.has_corer or world.player == null: return ""
	if not FIELD_KIT.holding_in(world, "corer"): return ""
	var player: Node3D = world.player
	if bool(player.get_meta("driving", false)) or bool(player.get_meta("riding", false)) or player._any_build_mode_active(): return ""
	if world.builder.is_inside(player.global_position) or world.lander.cabin_contains(player.global_position): return ""
	var at := player.global_position - player.global_transform.basis.z * 1.2
	if ICE_KNOWLEDGE.surveyed(ICE_KNOWLEDGE.samples(get_tree()), Vector2(at.x, at.z)): return ""
	var stakes := get_tree().get_first_node_in_group("survey_stakes")
	var nearest: Dictionary = stakes.call("nearest", Vector2(at.x, at.z)) if stakes != null else {}
	if nearest.is_empty(): return "Not surveyed · hold G: Survey zone, or G on the map (Tab)"
	var gap := (nearest.at as Vector2) - Vector2(at.x, at.z)
	var heading := wrapf(rad_to_deg(atan2(gap.x, -gap.y)), 0.0, 360.0)
	var points := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return "Not surveyed here · nearest stake %d m %s" % [roundi(gap.length()), points[roundi(heading / 45.0) % 8]]

## The HUD's hint: a corer stage under way, or ground you could core.
func prompt() -> String:
	if not stage.is_empty(): return stage
	return "core" if _target() != Vector3.INF else ""

## What E does now, for the HUD (explore_hud.gd).
func prompt_verb() -> String:
	match stage:
		"drive":
			if _stalled: return "Fit the ice shoe (%s)" % MHInput.glyph("rotate")
			return "Pump: drive it down (%d/%d)" % [_strokes, STROKES]
		"open": return "Open the head"
		"draw": return "Hold: draw the liner"
		"cap": return "Cap the core"
		"done": return ""
	return "Plant the corer"

## Phase 6 (21 Nov): the MC-01, worked by hand. E plants it; each press of E
## is a stroke (the collar drops, the ratchet clicks round) and it goes down
## a step; then open the head, hold E to draw the liner up, and E to cap it.
## Pumping faster than a stroke takes disturbs the layers: a partial read.
## The regolith shoe skids on ice; R swaps in the ice shoe, by hand.
func _process(delta: float) -> void:
	var down := MHInput.held("use") and not world.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var press := down and not _was_down
	_was_down = down
	_clock += delta
	if not stage.is_empty() and (world.player == null or Vector2(world.player.global_position.x - _at.x, world.player.global_position.z - _at.z).length() > LEAVE_M):
		_abandon()
		return
	match stage:
		"":
			if press:
				var at := _target()
				if at != Vector3.INF: _plant(at)
		"drive":
			if MHInput.held("rotate") and not _was_swap: _swap_shoe()
			if press: _stroke()
		"open":
			if press:
				stage = "draw"
				_tween_to(func(v: float): _rig.call("head", v), 0.0, 1.0, .45)
				MHAudio.sfx("door_open", -10.0)
		"draw":
			if down:
				_draw = minf(1.0, _draw + delta / DRAW_SECONDS * float(world.player.get_meta("hands_speed", 1.0)))
				_rig.call("sleeve", _draw)
				if _draw >= 1.0:
					stage = "cap"
					_rig.call("show_core", true, _icy())
		"cap":
			if press: _cap()
		"done":
			if _clock - _done_at > PACK_SECONDS: _abandon()
	_was_swap = MHInput.held("rotate")
	_ring.visible = stage == "drive" or stage == "draw"
	_ring.queue_redraw()

func _plant(at: Vector3) -> void:
	_at = at
	_strokes = 0
	_rushed = 0
	_stalled = false
	_draw = 0.0
	_last_stroke = -10.0
	_core = MHChapterOne.core_at(Vector2(at.x, at.z), float(world.builder._ice_richness_at_point(Vector2(at.x, at.z))))
	stage = "drive"
	_show_tool(true)
	MHAudio.sfx("place", -6.0)

## One stroke: down a step, unless the shoe is on ice it can't cut.
func _stroke() -> void:
	if _stalled:
		MHAudio.sfx("land", -12.0)
		return
	var gap := _clock - _last_stroke
	_last_stroke = _clock
	if gap < STROKE_GAP: _rushed += 1
	# The regolith shoe reaches the ice partway down and skids on it.
	var ice_step := ceili(float(STROKES) * .5)
	if not ice_shoe and not bool(_core.dry) and _strokes >= ice_step:
		_stalled = true
		MHAudio.sfx("land", -8.0)
		world.builder._flash_notice("info", "The shoe skids", "Something hard about %.1f m down: ice. The regolith shoe won't cut it. Swap in the ice shoe (%s)." % [float(_core.depth_m), MHInput.glyph("rotate")])
		return
	_strokes += 1
	MHAudio.sfx("ui_click", -4.0 if gap >= STROKE_GAP else -10.0)
	_rig.call("stroke")
	_sink(float(_strokes) / float(STROKES))
	if _strokes >= STROKES:
		stage = "open"

func _swap_shoe() -> void:
	ice_shoe = not ice_shoe
	_stalled = false
	_rig.call("shoe", ice_shoe)
	MHAudio.sfx("place", -8.0)

func _icy() -> bool:
	return ice_shoe and not bool(_core.dry)

func _cap() -> void:
	_rig.call("cap", true)
	stage = "done"
	_done_at = _clock
	var core := _core.duplicate()
	core["partial"] = _rushed >= RUSHED_LIMIT
	if bool(core.partial): core["good"] = false
	if not _icy() and not bool(core.dry):
		core["good"] = false   # the regolith shoe stopped above the ice
		core["above_ice"] = true
	_take_core(core)

func _abandon() -> void:
	stage = ""
	_at = Vector3.INF
	_ring.visible = false
	_show_tool(false)

## The corer stands where you planted it, sunk by `share` of its depth.
func _show_tool(on: bool) -> void:
	if not on:
		if _tool != null: _tool.visible = false
		return
	if _tool == null:
		var path := MC01 if ResourceLoader.exists(MC01) else MODEL
		if not ResourceLoader.exists(path): return
		_tool = (load(path) as PackedScene).instantiate() as Node3D
		MHPalette.apply(_tool)
		world.add_child(_tool)
		_rig = MC01Rig.new(_tool)
	_rig.call("reset", ice_shoe)
	_tool.visible = true
	_ground = MHCaves.ground_y(_at)
	_tool.rotation.y = world.player.rotation.y
	_sink(0.0)

func _sink(share: float) -> void:
	if _tool == null: return
	_tool.global_position = Vector3(_at.x, _ground - float(_rig.lift) - SINK_M * clampf(share, 0.0, 1.0), _at.z)

func _tween_to(apply: Callable, from: float, to: float, seconds: float) -> void:
	if _tool == null: return
	_tool.create_tween().tween_method(apply, from, to, seconds)

func _draw_ring() -> void:
	var c := Vector2(40, 40)
	var share := float(_strokes) / float(STROKES) if stage == "drive" else _draw
	var colour := MHStyle.WARN if _stalled or _rushed >= RUSHED_LIMIT else MHStyle.accent
	_ring.draw_arc(c, 30.0, 0.0, TAU, 48, Color(1, 1, 1, .25), 5.0, true)
	_ring.draw_arc(c, 30.0, -PI * .5, -PI * .5 + TAU * clampf(share, 0.0, 1.0), 48, colour, 5.0, true)
	if stage == "drive":
		for i in STROKES:   # a tick per stroke
			var a := -PI * .5 + TAU * float(i) / float(STROKES)
			_ring.draw_line(c + Vector2(cos(a), sin(a)) * 24.0, c + Vector2(cos(a), sin(a)) * 36.0, Color(0, 0, 0, .5), 2.0)

func _take_core(core: Dictionary) -> void:
	MHChapterOne.record_core(core)
	MHAudio.sfx("ui_confirm", -6.0)
	var title := ""
	var text := ""
	if bool(core.get("partial", false)):
		title = "Core: smeared"
		text = "You drove it too fast and the layers ran together. %s Take another, a stroke at a time." % ("Dry, as far as you can tell." if bool(core.dry) else "There's ice in it, but you can't read how deep or how clean.")
	elif bool(core.get("above_ice", false)):
		title = "Core: stopped on ice"
		text = "The regolith shoe stopped on ice about %.1f m down. Fit the ice shoe and core it again for a proper read." % float(core.depth_m)
	elif bool(core.dry):
		title = "Core: dry"
		text = "Dust and gravel all the way down: no ice in this one. Try where GAR-Y's readings are stronger."
	else:
		title = "Core: ice at %.1f m, %d%% pure" % [float(core.depth_m), roundi(float(core.purity) * 100.0)]
		text = "Rich enough to extract: about %d L of water a sol." % roundi(MHResources.setting("ice_drill_l", 120.0) * float(core.purity)) if bool(core.good) else "Some ice, but too thin and dirty to be worth an extractor."
	world.builder._flash_notice("valid" if bool(core.good) else ("warn" if bool(core.dry) or bool(core.get("partial", false)) else "info"), title, text)
	if bool(core.good):
		var now := float(world.builder.simulation().hours_run)
		world.call("show_chapter_messages", MHChapterOne.ice_found(now))
	world.call("show_chapter_messages", MHChapterOne.bag_soil())
	if world.get("sample_tools") != null: world.call("show_chapter_messages", world.sample_tools.call("keep_core", core))

## The MC-01's moving parts (from the model's own script, MC01Corer.gd):
## the slide collar, the ratchet head, the hinged head, the liner, the seal
## cap, the two shoes and the recovered core. Works without them too.
class MC01Rig:
	var lift := 0.0   # how far the model's origin sits below its ground contact
	var _upper: Node3D
	var _head: Node3D
	var _collar: Node3D
	var _sleeve: Node3D
	var _cap: Node3D
	var _seat: Node3D
	var _core: Node3D
	var _regolith: Node3D
	var _ice: Node3D
	var _shoe_regolith: Node3D
	var _shoe_ice: Node3D
	var _collar_rest := Vector3.ZERO
	var _sleeve_rest := Vector3.ZERO
	var _cap_rest := Vector3.ZERO
	var _turn := 0.0

	func _init(model: Node3D) -> void:
		var find := func(n: String) -> Node3D: return model.find_child(n, true, false) as Node3D
		_upper = find.call("Upper_Assembly_Hinge")
		_head = find.call("Ratchet_Head")
		_collar = find.call("Slide_Collar")
		_sleeve = find.call("Sleeve_Assembly")
		_cap = find.call("Seal_Cap")
		_seat = find.call("Seal_Seat")
		_core = find.call("Recovered_Core")
		_regolith = find.call("Core_Regolith")
		_ice = find.call("Core_Ice")
		_shoe_regolith = find.call("Shoe_Regolith")
		_shoe_ice = find.call("Shoe_Ice")
		var contact: Node3D = find.call("Ground_Contact")
		if contact != null: lift = contact.global_position.y - model.global_position.y
		if _collar != null: _collar_rest = _collar.position
		if _sleeve != null: _sleeve_rest = _sleeve.position
		if _cap != null: _cap_rest = _cap.position
		if _ice != null and _regolith != null: _ice.position = _regolith.position
		if _shoe_ice != null and _shoe_regolith != null: _shoe_ice.position = _shoe_regolith.position

	func reset(ice_shoe: bool) -> void:
		head(0.0)
		sleeve(0.0)
		cap(false)
		show_core(false, false)
		shoe(ice_shoe)

	func shoe(ice: bool) -> void:
		if _shoe_ice != null: _shoe_ice.visible = ice
		if _shoe_regolith != null: _shoe_regolith.visible = not ice

	## One stroke: the collar drops and springs back; the ratchet clicks round.
	func stroke() -> void:
		_turn += deg_to_rad(30.0)
		if _head != null: _head.rotation.y = _turn
		if _collar == null: return
		var motion := _collar.create_tween()
		motion.tween_property(_collar, "position", _collar_rest - Vector3.UP * .046, .12)
		motion.tween_property(_collar, "position", _collar_rest, .2)

	func head(amount: float) -> void:
		if _upper != null: _upper.rotation.x = deg_to_rad(118.0) * clampf(amount, 0.0, 1.0)

	func sleeve(amount: float) -> void:
		if _sleeve != null: _sleeve.position = _sleeve_rest + Vector3.UP * .34 * clampf(amount, 0.0, 1.0)

	func cap(sealed: bool) -> void:
		if _cap == null or _seat == null: return
		_cap.position = _seat.position + (_sleeve.position - _sleeve_rest) if sealed and _sleeve != null else _cap_rest

	func show_core(on: bool, icy: bool) -> void:
		if _core != null: _core.visible = on
		if _regolith != null: _regolith.visible = not icy
		if _ice != null: _ice.visible = icy

# ---------- the food step at the Workshop Bench ----------

## A label for E on this target when the food step takes it over, or "".
func claim_label(target: Node) -> String:
	if target == null or str(target.get("equipment_id")) != "tool_bench": return ""
	return MHChapterOne.bench_action()

## E on the Workshop Bench while carrying the regolith sample.
func claim(target: Node, method_name: String) -> bool:
	if method_name != "interact" or claim_label(target).is_empty(): return false
	MHAudio.sfx("ui_click")
	world.call("show_chapter_messages", MHChapterOne.bench_use(world.builder.simulation(), float(world.builder.simulation().hours_run)))
	return true
