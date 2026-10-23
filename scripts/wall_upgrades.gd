extends RefCounted

## Wall and roof upgrades (Batch C): improvements to the habitat's walls, not
## things placed in rooms. Interior build → Structure tab.
##   Regolith shielding  Bags of Mars soil stacked against an outside wall bay,
##                       printed by the regolith printer (no cargo from Earth
##                       once you're printing). Blocks radiation.
##   Water wall          A water tank panel on an outside wall bay. Water is a
##                       very good radiation shield.
##   Roof shielding      Regolith piled on a room's whole roof: most radiation
##                       comes from overhead.
##   Roof ladder         A ladder on an outside wall, up to a railed roof
##                       (scripts/roof_ladder.gd: E climbs up and down).
##   Sound insulation    Padded panels on a wall shared by two rooms, so a noisy
##                       neighbour (Power & Engineering, Life Support, a
##                       printer) doesn't keep the Living Quarters awake.
## A room's shield points: 5 for the hull, plus its upgrades' points spread
## over its floor squares (habitat_life.gd), so small rooms are easier to make
## into a storm shelter. Outside upgrades can't share a bay with a window.
## BuildController keeps the records in `wall_upgrades`:
##   walls {kind, mid, dir, outward}  ·  roof {kind: "roof", cell}.

## kind -> where it goes, its label, radiation points (per bay, or per roof
## square), Earth cargo (per bay or per roof square) and whether it's printed.
const KINDS := {
	"regolith": {"place": "outer", "label": "Regolith shielding", "points": 8.0, "cargo": 900, "printable": true, "icon": "shield"},
	"water": {"place": "outer", "label": "Water wall", "points": 10.0, "cargo": 260, "printable": false, "icon": "droplets"},
	"roof": {"place": "roof", "label": "Roof shielding", "points": 8.0, "cargo": 900, "printable": true, "icon": "house"},
	"ladder": {"place": "outer", "label": "Roof ladder", "points": 0.0, "cargo": 60, "printable": false, "icon": "arrow-up"},
	"acoustic": {"place": "shared", "label": "Sound insulation", "points": 0.0, "cargo": 80, "printable": false, "icon": "volume-x"},
}
const REGOLITH := Color("#8E6248")
const WATER := Color("#5A7480")
const PADDING := Color("#47525A")
const ROOF_LADDER := preload("res://scripts/roof_ladder.gd")
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func spec(kind: String) -> Dictionary:
	return KINDS.get(kind, {})

# ---------- costs ----------

## Earth cargo for all upgrades; with printable_only, just the printed ones.
static func cargo(builder: Node, printable_only := false) -> int:
	var total := 0
	for record in builder.wall_upgrades:
		var each: Dictionary = spec(str(record.kind))
		if printable_only and not bool(each.get("printable", false)): continue
		total += int(each.get("cargo", 0))
	return total

## The cost of placing this upgrade on this target (a whole roof is per square).
static func target_cargo(kind: String, target: Dictionary) -> int:
	var each := int(spec(kind).get("cargo", 0))
	return each * (target.cells as Array).size() if kind == "roof" else each

# ---------- aiming ----------

## What an upgrade would go on, from a first-person aim point and the surface
## normal there; {} if nothing suitable.
static func target_at(builder: Node, kind: String, point: Vector3, normal: Vector3) -> Dictionary:
	match str(spec(kind).get("place", "")):
		"outer":
			var bay: Dictionary = builder.window_target_at(point)
			return {} if bay.is_empty() else {"mid": bay.mid, "dir": bay.dir, "outward": bay.outward, "length": bay.length, "tangent": bay.tangent}
		"roof":
			if normal.y > -.5 or point.y < float(builder.habitat_base_y) + 2.0: return {}
			var zone: Dictionary = builder._zone_at_point(Vector2(point.x, point.z))
			if zone.is_empty() or not builder._is_habitat_zone(zone) or (zone.get("cells", []) as Array).is_empty(): return {}
			return {"cells": (zone.cells as Array).duplicate(), "zone": zone}
		"shared":
			if absf(normal.y) > .5: return {}
			var cell_size: float = BuildController.CELL
			var inside := Vector2(point.x + normal.x * .4, point.z + normal.z * .4)
			var a := Vector2i(roundi(inside.x / cell_size), roundi(inside.y / cell_size))
			var side := Vector2i(roundi(-normal.x), roundi(-normal.z))
			if absi(side.x) + absi(side.y) != 1: return {}
			var b := a + side
			var zone_a: Dictionary = builder._zone_at_cell(a) if builder.has_method("_zone_at_cell") else builder._zone_at_point(Vector2(a) * cell_size)
			var zone_b: Dictionary = builder._zone_at_cell(b) if builder.has_method("_zone_at_cell") else builder._zone_at_point(Vector2(b) * cell_size)
			if zone_a.is_empty() or zone_b.is_empty() or zone_a == zone_b: return {}
			if not builder._is_habitat_zone(zone_a) or not builder._is_habitat_zone(zone_b): return {}
			var mid := (Vector2(a) + Vector2(b)) * .5 * cell_size
			var tangent := Vector2(-side.y, side.x)
			return {"mid": mid, "dir": BuildController._canonical_wall_dir(tangent), "tangent": tangent, "outward": Vector2(side), "length": cell_size, "cells": [a, b]}
	return {}

## Index of an upgrade of this placement type at a wall (or roof square); -1.
static func index_at(builder: Node, kind: String, target: Dictionary) -> int:
	var place := str(spec(kind).get("place", ""))
	for index in range(builder.wall_upgrades.size()):
		var record: Dictionary = builder.wall_upgrades[index]
		if str(spec(str(record.kind)).get("place", "")) != place: continue
		if place == "roof":
			if (target.cells as Array).has(record.cell): return index
		elif (record.mid as Vector2).distance_to(target.mid) < .6 and absf((record.dir as Vector2).dot(target.dir)) > .99:
			return index
	return -1

static func invalid_reason(builder: Node, kind: String, target: Dictionary) -> String:
	var place := str(spec(kind).get("place", ""))
	if target.is_empty():
		match place:
			"outer": return "Aim at an outside wall of a room"
			"roof": return "Aim at the ceiling of a room"
			_: return "Aim at a wall between two rooms"
	if place != "roof" and builder._window_index_at(target.mid, target.dir) >= 0: return "There's a window in this wall bay"
	if place == "roof":
		if (target.cells as Array).all(func(c): return index_at(builder, kind, {"cells": [c]}) >= 0): return "This roof is already shielded"
	elif index_at(builder, kind, target) >= 0:
		return "This wall already has an upgrade"
	var cost := target_cargo(kind, target)
	if bool(spec(kind).get("printable", false)): cost = maxi(0, cost - builder.mars_made_left())
	if builder._used_cargo() + cost > MHGame.cargo_budget(): return "Not enough cargo left"
	return ""

static func place(builder: Node, kind: String, target: Dictionary) -> bool:
	if not invalid_reason(builder, kind, target).is_empty(): return false
	if str(spec(kind).get("place", "")) == "roof":
		for cell in target.cells:
			if index_at(builder, kind, {"cells": [cell]}) < 0: builder.wall_upgrades.append({"kind": kind, "cell": cell})
	else:
		builder.wall_upgrades.append({"kind": kind, "mid": target.mid, "dir": target.dir, "outward": target.outward})
	builder._rebuild()
	return true

## The upgrade an aim point is on (any kind), or -1. A roof gives its first square.
static func index_near(builder: Node, point: Vector3, normal: Vector3) -> int:
	for kind in ["roof", "acoustic", "regolith"]:
		var target := target_at(builder, kind, point, normal)
		if target.is_empty(): continue
		var index := index_at(builder, kind, target)
		if index >= 0: return index
	return -1

## Remove an upgrade; a roof comes off the whole room at once.
static func remove(builder: Node, index: int) -> void:
	if index < 0 or index >= builder.wall_upgrades.size(): return
	var record: Dictionary = builder.wall_upgrades[index]
	if str(record.kind) == "roof":
		var zone: Dictionary = builder._zone_at_point(Vector2(record.cell) * BuildController.CELL)
		var cells: Array = zone.get("cells", [record.cell])
		builder.wall_upgrades = builder.wall_upgrades.filter(func(r): return not (str(r.kind) == "roof" and cells.has(r.cell)))
	else:
		builder.wall_upgrades.remove_at(index)
	builder._rebuild()

# ---------- what each room gets ----------

## Room index (in the simulation's room list) for each upgrade: walls by the
## cell just inside them, roofs by their square. Shared walls count for both.
static func room_points(room_of_cell: Dictionary, builder: Node) -> Dictionary:
	var points := {}
	var cell_size: float = BuildController.CELL
	for record in builder.wall_upgrades:
		var value := float(spec(str(record.kind)).get("points", 0.0))
		if value <= 0.0: continue
		var cell: Vector2i
		if str(record.kind) == "roof": cell = record.cell
		else:
			var inside: Vector2 = (record.mid as Vector2) - (record.outward as Vector2) * .75
			cell = Vector2i(roundi(inside.x / cell_size), roundi(inside.y / cell_size))
		var room: int = room_of_cell.get(cell, -1)
		if room >= 0: points[room] = float(points.get(room, 0.0)) + value
	return points

## True when every wall between these two sets of cells has sound insulation.
static func insulated_between(builder: Node, cells_a: Array, cells_b: Array) -> bool:
	var shared := 0
	for a in cells_a:
		for side in SIDES:
			var b: Vector2i = (a as Vector2i) + side
			if not cells_b.has(b): continue
			shared += 1
			var mid := (Vector2(a) + Vector2(b)) * .5 * BuildController.CELL
			var dir := BuildController._canonical_wall_dir(Vector2(-side.y, side.x))
			if index_at(builder, "acoustic", {"mid": mid, "dir": dir}) < 0: return false
	return shared > 0

# ---------- building them ----------

## Drop upgrades whose wall or roof is gone, then build the rest.
static func build(builder: Node) -> void:
	var cell_size: float = BuildController.CELL
	builder.wall_upgrades = builder.wall_upgrades.filter(func(record): return _still_valid(builder, record))
	var base_y: float = builder.habitat_base_y
	_roof_rails(builder)
	for record in builder.wall_upgrades:
		var kind := str(record.kind)
		if kind == "roof":
			var centre := Vector3(record.cell.x * cell_size, base_y + 2.975, record.cell.y * cell_size)
			_roof(builder, centre, cell_size)
			continue
		var outward: Vector2 = record.outward
		var basis: Basis = builder._bay_basis(Vector2(-outward.y, outward.x), outward)
		var mid := Vector3(record.mid.x, base_y, record.mid.y)
		var out := Vector3(outward.x, 0, outward.y)
		match kind:
			"regolith": _bags(builder, mid + out * .3, basis, cell_size - .1)
			"water": _tank(builder, mid + out * .25, basis, cell_size - .2)
			"ladder": _ladder(builder, record, mid, out, basis)
			"acoustic":
				for face in [-1.0, 1.0]:
					_padding(builder, mid + out * (face * .13), basis, cell_size - .5)

static func _still_valid(builder: Node, record: Dictionary) -> bool:
	match str(spec(str(record.kind)).get("place", "")):
		"roof":
			var zone: Dictionary = builder._zone_at_point(Vector2(record.cell) * BuildController.CELL)
			return not zone.is_empty() and builder._is_habitat_zone(zone)
		"outer":
			return (builder._hull_bays as Array).any(func(bay): return (bay.mid as Vector2).distance_to(record.mid) < .6 and absf((bay.dir as Vector2).dot(record.dir)) > .99) and builder._window_index_at(record.mid, record.dir) < 0
		"shared":
			var cell_size: float = BuildController.CELL
			var a: Vector2 = (record.mid as Vector2) - (record.outward as Vector2) * cell_size * .5
			var b: Vector2 = (record.mid as Vector2) + (record.outward as Vector2) * cell_size * .5
			var zone_a: Dictionary = builder._zone_at_point(a)
			var zone_b: Dictionary = builder._zone_at_point(b)
			return not zone_a.is_empty() and not zone_b.is_empty() and zone_a != zone_b
	return false

static func _material(colour: Color, roughness := .95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material

static func _box(builder: Node, at: Vector3, size: Vector3, basis: Basis, material: Material, solid := false) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, at)
	body.collision_layer = 1 if solid else 0
	body.add_to_group("wall_upgrade")
	builder.root.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)

## An invisible solid wall (behind the roof rail).
static func _barrier(builder: Node, at: Vector3, size: Vector3, basis: Basis) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, at)
	body.collision_layer = 1
	body.add_to_group("wall_upgrade")
	builder.root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

## Courses of regolith bags against the wall, each course a little staggered.
static func _bags(builder: Node, at: Vector3, basis: Basis, length: float) -> void:
	var courses := 6
	var height := 2.9 / courses
	for row in courses:
		var shade := REGOLITH.lightened(.06) if row % 2 == 0 else REGOLITH.darkened(.05)
		var shift := basis.x * (.12 if row % 2 == 0 else -.12)
		var depth := .42 - row * .02
		_box(builder, at + Vector3.UP * (height * (row + .5)) + shift - basis.z * (depth * .5 - .2), Vector3(length - .25, height - .04, depth), basis, _material(shade))
	_box(builder, at + Vector3.UP * 1.45, Vector3(length, 2.9, .3), basis, _material(REGOLITH.darkened(.15)), true)

## A ribbed water tank panel with a small gauge.
static func _tank(builder: Node, at: Vector3, basis: Basis, length: float) -> void:
	_box(builder, at + Vector3.UP * 1.4, Vector3(length, 2.6, .28), basis, _material(WATER, .4), true)
	for height in [.5, 1.4, 2.3]:
		_box(builder, at + Vector3.UP * height - basis.z * .16, Vector3(length + .04, .08, .06), basis, _material(WATER.lightened(.2), .35))
	_box(builder, at + Vector3.UP * 1.9 + basis.x * (length * .35) - basis.z * .17, Vector3(.18, .18, .04), basis, MHGame.accent_material())

## Padded, quilted panels on a shared wall (one face).
static func _padding(builder: Node, at: Vector3, basis: Basis, length: float) -> void:
	_box(builder, at + Vector3.UP * 1.35, Vector3(length, 2.2, .05), basis, _material(PADDING, 1.0))
	for step in range(1, 5):
		var x := -length * .5 + length * step / 5.0
		_box(builder, at + Vector3.UP * 1.35 + basis.x * x, Vector3(.025, 2.2, .07), basis, _material(PADDING.darkened(.25), 1.0))

## A steel ladder from the ground to hoops above the roof edge, and the body
## you aim at to climb (scripts/roof_ladder.gd).
static func _ladder(builder: Node, record: Dictionary, mid: Vector3, out: Vector3, basis: Basis) -> void:
	var steel := _material(MHStyle.FRAME_STEEL, .45)
	var foot := mid + out * .32
	var ground: float = builder._terrain_height(Vector3(foot.x, 0, foot.z))
	var bottom := minf(ground, mid.y) - .1
	var top := mid.y + 3.9
	for side in [-.28, .28]:
		_box(builder, Vector3(foot.x, (bottom + top) * .5, foot.z) + basis.x * side, Vector3(.05, top - bottom, .05), basis, steel)
	var rung := bottom + .3
	while rung < mid.y + 3.0:
		_box(builder, Vector3(foot.x, rung, foot.z), Vector3(.56, .035, .035), basis, steel)
		rung += .3
	# Safety hoops where you step on and off at the top.
	for height in [3.25, 3.7]:
		_box(builder, Vector3(foot.x, mid.y + height, foot.z) + out * .18, Vector3(.62, .04, .04), basis, MHGame.accent_material())
	var body: StaticBody3D = ROOF_LADDER.new()
	body.transform = Transform3D(basis, Vector3(foot.x, (bottom + top) * .5, foot.z))
	body.collision_layer = 1
	builder.root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.66, top - bottom, .2)
	shape.shape = box
	body.add_child(shape)
	body.setup(builder, record.mid, record.outward)

## With a ladder, a rail round the roof edge (1 m, the colony accent), with a
## gap where each ladder comes up.
static func _roof_rails(builder: Node) -> void:
	var ladders: Array = builder.wall_upgrades.filter(func(r): return str(r.kind) == "ladder")
	if ladders.is_empty(): return
	var cell_size: float = BuildController.CELL
	var top: float = builder.habitat_base_y + 2.975
	var rail := MHGame.accent_material()
	var post := _material(MHStyle.FRAME_STEEL, .45)
	for zone in builder.zones:
		if not builder._is_habitat_zone(zone) or zone.has("angled_mount"): continue
		for cell in zone.get("cells", []):
			for side in SIDES:
				if builder._is_habitat_zone(builder._zone_across(cell, side)): continue
				var edge_mid := (Vector2(cell) + Vector2(side) * .5) * cell_size
				if ladders.any(func(l): return (l.mid as Vector2).distance_to(edge_mid) < .6): continue
				var along := Vector3(-side.y, 0, side.x)
				var at := Vector3(edge_mid.x, top, edge_mid.y) - Vector3(side.x, 0, side.y) * .12
				var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
				_barrier(builder, at + Vector3.UP * .5, Vector3(cell_size, 1.0, .1), basis)
				for height in [.5, 1.0]:
					_box(builder, at + Vector3.UP * height, Vector3(cell_size, .05, .05), basis, rail)
				_box(builder, at + Vector3.UP * .5 - along * (cell_size * .5 - .03), Vector3(.06, 1.0, .06), basis, post)

## Regolith piled on one roof square, in two rows of bags.
static func _roof(builder: Node, centre: Vector3, cell_size: float) -> void:
	_box(builder, centre + Vector3.UP * .16, Vector3(cell_size - .2, .32, cell_size - .2), Basis.IDENTITY, _material(REGOLITH), true)
	for side in [-1.0, 1.0]:
		_box(builder, centre + Vector3(0, .36, side * cell_size * .22), Vector3(cell_size - .5, .14, cell_size * .38), Basis.IDENTITY, _material(REGOLITH.lightened(.05)))

## Shield a whole room: this upgrade on every free outside wall bay, and
## optionally the roof. Returns how many records were added (tests, tools).
static func shield_room(builder: Node, zone: Dictionary, kind := "regolith", roof := true) -> int:
	var added := 0
	for bay in builder._hull_bays:
		if builder._zone_at_point((bay.mid as Vector2) - (bay.outward as Vector2) * .8) != zone: continue
		var target := {"mid": bay.mid, "dir": bay.dir, "outward": bay.outward}
		if builder._window_index_at(bay.mid, bay.dir) >= 0 or index_at(builder, kind, target) >= 0: continue
		builder.wall_upgrades.append({"kind": kind, "mid": bay.mid, "dir": bay.dir, "outward": bay.outward})
		added += 1
	if roof:
		for cell in zone.get("cells", []):
			if index_at(builder, "roof", {"cells": [cell]}) < 0:
				builder.wall_upgrades.append({"kind": "roof", "cell": cell})
				added += 1
	return added

# ---------- older saves ----------

const OLD_BLOCKS := {"regolith_shield_block": "regolith", "water_wall_panel": "water"}

## Shield blocks and water wall panels used to stand inside rooms. Each one
## becomes that upgrade on a free outside wall bay of its room (or, with none
## left, roof shielding for a regolith block). Returns how many changed.
static func convert_old_blocks(builder: Node) -> int:
	var old: Array = (builder.placed_interior as Array).filter(func(item): return OLD_BLOCKS.has(str(item.get("id", ""))))
	for item in old:
		var kind := str(OLD_BLOCKS[str(item.id)])
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var zone: Dictionary = builder._zone_at_point(Vector2(at.x, at.z))
		builder.remove_free_interior_equipment(str(item.get("placement_id", "")))
		if zone.is_empty(): continue
		var done := false
		for bay in builder._hull_bays:
			var inside: Vector2 = (bay.mid as Vector2) - (bay.outward as Vector2) * .8
			if builder._zone_at_point(inside) != zone: continue
			var target := {"mid": bay.mid, "dir": bay.dir, "outward": bay.outward}
			if builder._window_index_at(bay.mid, bay.dir) >= 0 or index_at(builder, kind, target) >= 0: continue
			builder.wall_upgrades.append({"kind": kind, "mid": bay.mid, "dir": bay.dir, "outward": bay.outward})
			done = true
			break
		if not done and kind == "regolith":
			for cell in zone.get("cells", []):
				if index_at(builder, "roof", {"cells": [cell]}) < 0: builder.wall_upgrades.append({"kind": "roof", "cell": cell})
	return old.size()
