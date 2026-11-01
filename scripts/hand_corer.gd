extends Node

## The hand corer (docs/start-and-chapter-one.md §6), from the Outside crate.
## Only on ground GAR-Y has surveyed (no hole without a reason), away from
## the base and not looking at anything: hold E to drive a core into the
## ground in front of you. The core shows the ice's depth
## and purity: shallow, clean ice makes the extractor run faster, and some
## cores come up dry. The first good core is the ice discovery.
## GAR-Y's "Survey zone" finds where to try; the wrist only does life support.

const MHResources := preload("res://scripts/mh_resources.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const ICE_KNOWLEDGE := preload("res://scripts/ice_knowledge.gd")
const HOLD_SECONDS := 1.8
const KEEP_CLEAR_M := 8.0   # from the habitat and landers, so a tap of E still works the doors

const MODEL := "res://assets/equipment/mars_chapter_one_v1/models/hand_corer.glb"
## How far the corer sinks while you hold E (m).
const SINK_M := .55

var world: Node
var _held := 0.0
var _ring: Control
var _tool: Node3D   # the corer, planted where you're coring

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
	var player: Node3D = world.player
	if player == null or bool(player.get_meta("driving", false)) or player._any_build_mode_active(): return Vector3.INF
	if world.builder.is_inside(player.global_position) or world.lander.cabin_contains(player.global_position): return Vector3.INF
	var at := player.global_position - player.global_transform.basis.z * 1.2
	if world.builder.is_inside(at + Vector3.UP * .5): return Vector3.INF
	for node in [world.lander] + (world.cargo_landers as Array):
		if node != null and Vector2(node.global_position.x - at.x, node.global_position.z - at.z).length() < KEEP_CLEAR_M: return Vector3.INF
	if not world.builder.zones.is_empty() and world.builder.call("_zone_at_point", Vector2(at.x, at.z)).size() > 0: return Vector3.INF
	if not ICE_KNOWLEDGE.surveyed(ICE_KNOWLEDGE.samples(get_tree()), Vector2(at.x, at.z)): return Vector3.INF
	return at

## The HUD's hint while you could take one.
func prompt() -> String:
	return "core" if _target() != Vector3.INF else ""

func _process(delta: float) -> void:
	var at := _target()
	var holding := Input.is_physical_key_pressed(KEY_E) and at != Vector3.INF and not world.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_held = _held + delta if holding else 0.0
	_ring.visible = _held > .15
	_ring.queue_redraw()
	_show_tool(at if _held > .15 else Vector3.INF)
	if _held >= HOLD_SECONDS:
		_held = 0.0
		_ring.visible = false
		_take_core(at)

## The corer stands in the ground in front of you and sinks as you work it.
func _show_tool(at: Vector3) -> void:
	if at == Vector3.INF:
		if _tool != null: _tool.visible = false
		return
	if _tool == null:
		if not ResourceLoader.exists(MODEL): return
		_tool = (load(MODEL) as PackedScene).instantiate() as Node3D
		MHPalette.apply(_tool)
		world.add_child(_tool)
	_tool.visible = true
	var ground := MHCaves.ground_y(at)
	_tool.global_position = Vector3(at.x, ground - SINK_M * clampf(_held / HOLD_SECONDS, 0.0, 1.0), at.z)
	_tool.rotation.y = world.player.rotation.y + _held * 4.0

func _draw_ring() -> void:
	var c := Vector2(40, 40)
	_ring.draw_arc(c, 30.0, 0.0, TAU, 48, Color(1, 1, 1, .25), 5.0, true)
	_ring.draw_arc(c, 30.0, -PI * .5, -PI * .5 + TAU * clampf(_held / HOLD_SECONDS, 0.0, 1.0), 48, MHStyle.accent, 5.0, true)

func _take_core(at: Vector3) -> void:
	var point := Vector2(at.x, at.z)
	var richness := float(world.builder._ice_richness_at_point(point))
	var core := MHChapterOne.core_at(point, richness)
	MHChapterOne.record_core(core)
	MHAudio.sfx("ui_click")
	var title := "Core: dry" if bool(core.dry) else "Core: ice at %.1f m, %d%% pure" % [float(core.depth_m), roundi(float(core.purity) * 100.0)]
	var text := "No ice in this one. Try where GAR-Y's readings are stronger." if bool(core.dry) else ("Rich enough to extract: about %d L of water a sol." % roundi(MHResources.setting("ice_drill_l", 120.0) * richness) if bool(core.good) else "Some ice, but too thin and dirty to be worth an extractor.")
	world.builder._flash_notice("valid" if bool(core.good) else ("warn" if bool(core.dry) else "info"), title, text)
	if bool(core.good):
		var now := float(world.builder.simulation().hours_run)
		world.call("show_chapter_messages", MHChapterOne.ice_found(now))
	world.call("show_chapter_messages", MHChapterOne.bag_soil())

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
