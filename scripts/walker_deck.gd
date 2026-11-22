extends Node3D

## Walker 1's deck on the dawn ride (opening slice, docs/opening-slice.md §4a
## Scene 6). Riding it while it's ready: hold W and it walks where you look.
## Its deck screen (a working display, so text is fine) reads the ground
## beneath it: ground, sun, shelter, water. E on the screen: "Set down here".
## A faint outline of the core and its airlock lies on the ground; look the
## way the airlock should face, and E again sets it down (Space backs out).
## The fold then plays through on its own (scripts/walker.gd deliver).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const BUILD_RULES := preload("res://scripts/build_rules.gd")
const READ_EVERY := 1.0          # seconds between readings while it walks
const READ_MOVED := 8.0          # ... or once it's this far from the last one
const LOOK_AHEAD := 20.0

var walker: Node3D
var world: Node
var siting := false              # the outline's down, waiting for E or Space
var _screen: Label3D
var _outline: Node3D
var _read_in := 0.0
var _read_at := Vector3.INF
var _reading := ""
var _dir := Vector2i(0, 1)
var _cells: Array = []
var _airlock: Vector2i
var _why := ""

func setup(target_walker: Node3D) -> void:
	walker = target_walker
	world = walker.world
	name = "Deck"
	_screen = Label3D.new()
	_screen.name = "DeckScreen"
	_screen.pixel_size = .0016
	_screen.font_size = 30
	_screen.outline_size = 0
	_screen.modulate = Color(.55, 1.0, .72)
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_screen.width = 520
	_screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen.double_sided = false
	_screen.no_depth_test = false
	walker.add_child(_screen)
	_screen.position = walker.NAV_AT + Vector3(0, .02, .07)
	_screen.rotation_degrees = Vector3(-18, 0, 0)
	_screen.visible = false

func active() -> bool:
	return bool(walker.riding) and str(walker.state) in ["ready", "parked"] and (str(walker.state) == "ready" or siting)

# ---------- each frame, riding ----------

func tick(delta: float) -> void:
	_screen.visible = active()
	if not active(): return
	if siting:
		_aim()
		return
	var moving := false
	if walker.ladder_out <= 0.0 and Input.is_physical_key_pressed(KEY_W) and not bool(world.player.get_meta("ui_freeze", false)):
		var ahead := _look_flat()
		if ahead != Vector3.ZERO:
			walker._drive(walker.global_position + ahead * LOOK_AHEAD, delta)
			moving = true
	_read_in -= delta
	if _reading.is_empty() or (_read_in <= 0.0 and (moving or walker.global_position.distance_to(_read_at) > 1.0)) or walker.global_position.distance_to(_read_at) > READ_MOVED:
		_read_in = READ_EVERY
		_read()
	_screen.text = _reading

func _look_flat() -> Vector3:
	var camera := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return Vector3.ZERO
	var f := -camera.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > .01 else Vector3.ZERO

## What the ground here is like, as the deck screen shows it.
func _read() -> void:
	_read_at = walker.global_position
	var known: Node = world.get("known")
	var origin: Vector2 = known.origin if known != null else Vector2.ZERO
	var at := Vector2(_read_at.x, _read_at.z)
	var rx := at.x + origin.x
	var rz := at.y + origin.y
	var lines: Array = ["SITE READ · HERE", ""]
	var why: String = walker.spot_reason(at)
	var dx: float = MHSiteTerrain.height(at.x + 6.0, at.y) - MHSiteTerrain.height(at.x - 6.0, at.y)
	var dz: float = MHSiteTerrain.height(at.x, at.y + 6.0) - MHSiteTerrain.height(at.x, at.y - 6.0)
	var slope := rad_to_deg(atan(Vector2(dx, dz).length() / 12.0))
	lines.append("GROUND   " + ("firm · %d° slope" % roundi(slope) if why.is_empty() else why.to_lower()))
	var conditions := MHBaseSite.conditions(rx, rz)
	var sun := MHBaseSite.sunshine(conditions.horizon)
	lines.append("SUN      %d%% of open sky · shaded %.1f h" % [roundi(float(sun.share) * 100.0), float(sun.hidden_hours)])
	var dust := float(conditions.dust_per_sol)
	lines.append("SHELTER  nights +%.1f °C · dust %s" % [float(conditions.shelter_c), "low" if dust < .018 else ("high" if dust > .03 else "some")])
	var ice := INF
	for d in MHBaseSite.ice_deposits(rx, rz):
		if float(d.richness) >= MHBaseSite.DRILLABLE: ice = minf(ice, Vector2(float(d.x), float(d.z)).length())
	lines.append("WATER    " + ("ice %d m" % roundi(ice) if not is_inf(ice) else "no ice near"))
	lines.append("")
	lines.append("[E] SET DOWN HERE" if why.is_empty() else "keep walking")
	_reading = "\n".join(lines)

# ---------- set down here ----------

## E on the deck screen.
func press(looked := false) -> bool:
	if siting:
		return confirm()
	if str(walker.state) != "ready" or not (looked or walker.looking_at_nav()): return false
	var at := Vector2(walker.global_position.x, walker.global_position.z)
	if not walker.spot_reason(at).is_empty():
		MHAudio.sfx("invalid", -6.0)
		return true
	siting = true
	walker.state = "parked"      # the build rules' set-down stage: the core and airlock can go here
	world.builder.found_base(walker.base_id, at)   # its build area, round here
	# Its airlock came with it (once).
	if not bool(walker.kit_given) and not walker.has_meta("airlock_given"):
		walker.set_meta("airlock_given", true)
		MHChapterOne.stock["airlock"] = int(MHChapterOne.stock.get("airlock", 0)) + 1
	_aim()
	MHAudio.sfx("suit_beep", -8.0)
	return true

## Space: back to walking.
func cancel() -> void:
	if not siting: return
	siting = false
	walker.state = "ready"
	_clear_outline()

## The outline follows where you look: the airlock faces that way.
func _aim() -> void:
	var f := _look_flat()
	var dir := _dir
	if f != Vector3.ZERO: dir = Vector2i(signi(roundi(f.x)), 0) if absf(f.x) > absf(f.z) else Vector2i(0, signi(roundi(f.z)))
	if dir == Vector2i.ZERO: dir = _dir
	if dir == _dir and _outline != null: return
	_dir = dir
	var builder: Node = world.builder
	var centre := Vector2i(roundi(walker.global_position.x / builder.CELL), roundi(walker.global_position.z / builder.CELL))
	var size: Vector2i = BUILD_RULES.MODULE_CELLS if dir.y != 0 else Vector2i(BUILD_RULES.MODULE_CELLS.y, BUILD_RULES.MODULE_CELLS.x)
	var start := centre - Vector2i(size.x / 2, size.y / 2)
	_cells = []
	for x in size.x:
		for z in size.y: _cells.append(start + Vector2i(x, z))
	# The airlock: off the middle of the core's side that faces `dir`.
	var mid := Vector2i(start.x + (size.x - 1) / 2, start.y + (size.y - 1) / 2)
	_airlock = Vector2i(start.x + size.x if dir.x > 0 else (start.x - 1 if dir.x < 0 else mid.x),
		start.y + size.y if dir.y > 0 else (start.y - 1 if dir.y < 0 else mid.y))
	builder.airlock_direction = dir
	builder.kind = "general"
	_why = builder._invalid_reason(_cells)
	if _why.is_empty():
		# The airlock's checked against the core, so the core's in the plan
		# for a moment (not built).
		var core := {"kind": "general", "cells": _cells, "door_direction": dir, "cost": 0, "carried": true, "base": walker.base_id}
		builder.zones.append(core)
		builder.kind = "airlock"
		_why = builder._invalid_reason([_airlock])
		builder.zones.erase(core)
	builder.kind = "general"
	_draw_outline()
	_screen.text = "SET DOWN HERE?\n\nThe airlock faces the way you look.\n\n" + ("[E] SET IT DOWN    [SPACE] BACK" if _why.is_empty() else "NOT HERE: %s\n[SPACE] BACK" % _why.to_lower())

func _draw_outline() -> void:
	_clear_outline()
	_outline = Node3D.new()
	_outline.name = "SetDownOutline"
	world.add_child(_outline)
	var cell_size: float = world.builder.CELL
	var good := _why.is_empty()
	for cell in _cells + [_airlock]:
		var mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(cell_size - .15, cell_size - .15)
		mesh.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var colour := Color(.5, .95, .7) if good else Color(1.0, .4, .3)
		if cell == _airlock: colour = colour.lightened(.35)
		colour.a = .28 if cell != _airlock else .42
		mat.albedo_color = colour
		mesh.material_override = mat
		var p := Vector3(cell.x * cell_size, 0, cell.y * cell_size)
		p.y = MHSiteTerrain.height(p.x, p.z) + .08
		_outline.add_child(mesh)
		mesh.global_position = p

func _clear_outline() -> void:
	if _outline != null and is_instance_valid(_outline): _outline.queue_free()
	_outline = null

## E again: the core and its airlock go in the plan, and it sets them down.
func confirm() -> bool:
	if not siting: return false
	if not _why.is_empty():
		MHAudio.sfx("invalid", -6.0)
		return true
	var builder: Node = world.builder
	var middle := Vector2.ZERO
	for c in _cells: middle += Vector2(c.x, c.y) * builder.CELL
	middle /= float(_cells.size())
	builder.found_base(walker.base_id, middle)
	builder.airlock_direction = _dir
	_place("general", _cells)
	_place("airlock", [_airlock])
	siting = false
	_clear_outline()
	BUILD_RULES.plan_closed(builder)
	MHAudio.sfx("place", -4.0)
	return true

func _place(kind: String, cells: Array) -> void:
	var builder: Node = world.builder
	builder.kind = kind
	if builder.zones.is_empty(): builder.habitat_base_y = builder._proposed_base_y(cells)
	var zone := {"kind": kind, "cells": cells, "door_direction": builder.airlock_direction, "cost": builder._zone_cost(cells)}
	BUILD_RULES.placed(builder, zone)
	builder.zones.append(zone)
	builder._history.append({"type": "zone", "zone": zone})
	builder._rebuild()
	builder.kind = "general"

func prompt() -> Dictionary:
	if siting: return {"keys": "E", "verb": "Set it down here" if _why.is_empty() else "Not here", "secondary": "Space · back"}
	if walker.looking_at_nav(): return {"keys": "E", "verb": "Set down here"}
	return {"keys": "W", "verb": "Walk where you look · E climbs down"}
