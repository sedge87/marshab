extends RefCounted

## Wall and roof upgrades (Batch C): improvements to the habitat's walls, not
## things placed in rooms. Interior build → Structure tab.
##   Regolith shielding  Mars soil packed behind an outside wall bay's panel,
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
## Subtle on purpose (user feedback, 24 Oct): a flush panel inside the bay's
## frame, a tint off the white hull, faint lines and a small tag, so you can
## tell it's shielded and with what, without it changing the base's shape.
const REGOLITH := Color("#CDB096")        # pale sand
const REGOLITH_LINE := Color("#B8987C")
const REGOLITH_TAG := Color("#8E6248")
const WATER := Color("#BDCBD1")           # pale blue-grey
const WATER_LINE := Color("#A6B8C0")
const WATER_TAG := Color("#3F82B8")
const PADDING := Color("#C9CBC6")
const PADDING_LINE := Color("#B4B7B1")
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
		var cells: Array = target.cells
		if builder.zones.any(func(z): return z.get("roof", false) and cells.has(Vector2i(roundi(z.at.x / BuildController.CELL), roundi(z.at.y / BuildController.CELL)))):
			return "Solar panels are on this roof: take them off first"
		if (target.cells as Array).all(func(c): return index_at(builder, kind, {"cells": [c]}) >= 0): return "Done: this roof is shielded"
	else:
		var existing := index_at(builder, kind, target)
		if existing >= 0: return "Done: this wall has %s" % str(spec(str(builder.wall_upgrades[existing].kind)).label).to_lower()
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
		if kind == "acoustic": _shift_wall_items(builder, target, PANEL_DEPTH)
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
		if str(record.kind) == "acoustic": _shift_wall_items(builder, record, -PANEL_DEPTH)
		builder.wall_upgrades.remove_at(index)
	builder._rebuild()

## How far an insulation panel's face stands out from the wall it's on.
const PANEL_DEPTH := .135

## Posters, shelves and other wall items on this shared wall (either side)
## move out onto a new insulation panel's face, or back to the wall when it
## comes off, with anything resting on them.
static func _shift_wall_items(builder: Node, wall: Dictionary, by: float) -> void:
	var mid: Vector2 = wall.mid
	var out: Vector2 = (wall.outward as Vector2).normalized()
	var along := Vector2(-out.y, out.x)
	# [item, the wall face it's on]: things resting on a shelf go with the shelf.
	var moving: Array = []
	for item in builder.placed_interior:
		var normal: Vector3 = item.get("anchor_normal", Vector3.UP)
		if absf(normal.y) > .5 or absf(Vector2(normal.x, normal.z).dot(out)) < .9: continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var offset := Vector2(at.x, at.z) - mid
		if absf(offset.dot(along)) > BuildController.CELL * .5 or absf(offset.dot(out)) > .4: continue
		moving.append([item, normal])
		for resting in builder.items_resting_on(item): moving.append([resting, normal])
	for entry in moving:
		var item: Dictionary = entry[0]
		var normal: Vector3 = entry[1]
		var shift := Vector3(normal.x, 0, normal.z).normalized() * by
		item.position = (item.position as Vector3) + shift
		for child in builder.furnishing.get_children():
			if str(child.get_meta("interior_placement_id", "")) == str(item.get("placement_id", "")):
				(child as Node3D).global_position += shift

# ---------- what each room gets ----------

## The habitat's shielding in total (it eases the everyday background dose; a
## storm shelter is shielded by what's on its own room): the shield
## points of every panel on the outside walls and roof, added up.
static func habitat_points(builder: Node) -> float:
	var total := 0.0
	for record in builder.wall_upgrades: total += float(spec(str(record.kind)).get("points", 0.0))
	return total

## True when one panel of sound insulation is on any wall between these two
## sets of cells: that's enough to quiet the neighbour.
static func insulated_between(builder: Node, cells_a: Array, cells_b: Array) -> bool:
	for a in cells_a:
		for side in SIDES:
			var b: Vector2i = (a as Vector2i) + side
			if not cells_b.has(b): continue
			var mid := (Vector2(a) + Vector2(b)) * .5 * BuildController.CELL
			var dir := BuildController._canonical_wall_dir(Vector2(-side.y, side.x))
			if index_at(builder, "acoustic", {"mid": mid, "dir": dir}) >= 0: return true
	return false

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
			var patches := roof_patches(builder, record.cell)
			if patches.size() == 1 and (patches[0] as PackedVector2Array).size() == 4 and not _roof_clipped(builder, record.cell):
				_roof(builder, centre, cell_size)
			else:
				for patch in patches: _slab(builder, patch, base_y + 2.975, base_y + 3.035, _material(REGOLITH))
			continue
		var outward: Vector2 = record.outward
		var basis: Basis = builder._bay_basis(Vector2(-outward.y, outward.x), outward)
		var mid := Vector3(record.mid.x, base_y, record.mid.y)
		var out := Vector3(outward.x, 0, outward.y)
		match kind:
			"regolith": _cladding(builder, mid, out, basis, REGOLITH, REGOLITH_LINE, REGOLITH_TAG, true)
			"water": _cladding(builder, mid, out, basis, WATER, WATER_LINE, WATER_TAG, false)
			"ladder": _ladder(builder, record, mid, out, basis)
			"acoustic":
				for face in [-1.0, 1.0]:
					_padding(builder, mid + out * (face * .2), basis, cell_size - .6, face)

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

## A flush panel inside the bay's frame, just proud of the hull: horizontal
## courses for regolith, vertical ribs for a water wall, and a small tag.
static func _cladding(builder: Node, mid: Vector3, out: Vector3, basis: Basis, colour: Color, line: Color, tag: Color, courses: bool) -> void:
	var face := mid + out * .12
	var width := 2.55
	_box(builder, face + Vector3.UP * 1.35, Vector3(width, 2.35, .04), basis, _material(colour))
	var line_material := _material(line)
	if courses:
		for row in range(1, 7):
			_box(builder, face + out * .022 + Vector3.UP * (.18 + row * .335), Vector3(width, .016, .008), basis, line_material)
	else:
		for column in range(1, 6):
			_box(builder, face + out * .022 + Vector3.UP * 1.35 + basis.x * (-width * .5 + width * column / 6.0), Vector3(.03, 2.35, .008), basis, line_material)
	_box(builder, face + out * .025 + Vector3.UP * 2.25 + basis.x * (width * .5 - .3), Vector3(.2, .2, .01), basis, _material(tag, .6))

## A quilted panel on one face of a shared wall, close to the wall colour,
## with a small accent tag.
static func _padding(builder: Node, at: Vector3, basis: Basis, length: float, face: float) -> void:
	var toward := basis.z * (-1.0 if face > 0.0 else 1.0)
	# A solid slab standing proud of the wall, so the wall's vents and
	# fittings are covered rather than showing through it.
	# Solid, so posters and shelves hang on its face, not hidden behind it.
	_box(builder, at + Vector3.UP * 1.3, Vector3(length, 2.0, .1), basis, _material(PADDING, 1.0), true)
	var seam := _material(PADDING_LINE, 1.0)
	for step in range(1, 8):
		_box(builder, at + Vector3.UP * 1.3 + basis.x * (-length * .5 + length * step / 8.0) + toward * .052, Vector3(.012, 2.0, .01), basis, seam)
	_box(builder, at + Vector3.UP * 2.15 + basis.x * (length * .5 - .25) + toward * .055, Vector3(.2, .12, .01), basis, MHGame.accent_material())

## A steel ladder from the ground to the roof edge. Its rails carry on to
## handrail height and bend over the edge down onto the roof (a gooseneck),
## lining up with an opening in the roof rail; the body you aim at to climb
## is scripts/roof_ladder.gd.
const LADDER_HALF_WIDTH := .28
static func _ladder(builder: Node, record: Dictionary, mid: Vector3, out: Vector3, basis: Basis) -> void:
	var steel := _material(MHStyle.FRAME_STEEL, .45)
	var foot := mid + out * .32
	var ground: float = builder._terrain_height(Vector3(foot.x, 0, foot.z))
	var bottom := minf(ground, mid.y) - .1
	var roof := mid.y + 2.975
	var grab := roof + 1.0
	var inward := mid - out * .35
	for side in [-LADDER_HALF_WIDTH, LADDER_HALF_WIDTH]:
		var across: Vector3 = basis.x * side
		_box(builder, Vector3(foot.x, (bottom + grab) * .5, foot.z) + across, Vector3(.05, grab - bottom, .05), basis, steel)
		# Over the edge and down onto the roof.
		var over := (foot + inward) * .5
		_box(builder, Vector3(over.x, grab, over.z) + across, Vector3(.05, .05, foot.distance_to(inward) + .05), basis, steel)
		_box(builder, Vector3(inward.x, (roof + grab) * .5, inward.z) + across, Vector3(.05, grab - roof, .05), basis, steel)
	var rung := bottom + .3
	while rung < roof - .05:
		_box(builder, Vector3(foot.x, rung, foot.z), Vector3(LADDER_HALF_WIDTH * 2.0, .035, .035), basis, steel)
		rung += .3
	var body: StaticBody3D = ROOF_LADDER.new()
	body.transform = Transform3D(basis, Vector3(foot.x, (bottom + grab) * .5, foot.z))
	body.collision_layer = 1
	builder.root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LADDER_HALF_WIDTH * 2.0 + .1, grab - bottom, .2)
	shape.shape = box
	body.add_child(shape)
	body.setup(builder, record.mid, record.outward)

## With a ladder, a rail round the outside edge of the whole base's roof (1 m,
## the colony accent), with an opening where each ladder comes up. It follows
## each room's real outline (free-shape rooms too), and only where there's open
## ground just beyond the edge, so no rail runs between rooms or across a room.
static func _roof_rails(builder: Node) -> void:
	var ladders: Array = builder.wall_upgrades.filter(func(r): return str(r.kind) == "ladder")
	if ladders.is_empty(): return
	var top: float = builder.habitat_base_y + 2.975
	var rail := MHGame.accent_material()
	var post := _material(MHStyle.FRAME_STEEL, .45)
	for edge in _outer_edges(builder):
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var out: Vector2 = edge[2]
		var length := a.distance_to(b)
		var tangent := (b - a) / length
		var mid := (a + b) * .5
		# Runs along this edge, [from, to] from its middle; split round a ladder.
		var runs := [[-length * .5, length * .5]]
		for ladder in ladders:
			var offset: Vector2 = (ladder.mid as Vector2) - mid
			if absf(offset.dot(out)) > .3 or absf(offset.dot(tangent)) > length * .5: continue
			var at := offset.dot(tangent)
			var split: Array = []
			for run in runs:
				if at + LADDER_HALF_WIDTH <= float(run[0]) or at - LADDER_HALF_WIDTH >= float(run[1]): split.append(run); continue
				if at - LADDER_HALF_WIDTH - float(run[0]) > .1: split.append([float(run[0]), at - LADDER_HALF_WIDTH])
				if float(run[1]) - (at + LADDER_HALF_WIDTH) > .1: split.append([at + LADDER_HALF_WIDTH, float(run[1])])
			runs = split
		var along := Vector3(tangent.x, 0, tangent.y)
		var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		var centre := Vector3(mid.x, top, mid.y) - Vector3(out.x, 0, out.y) * .12
		for run in runs:
			var run_length := float(run[1]) - float(run[0])
			var at: Vector3 = centre + along * ((float(run[0]) + float(run[1])) * .5)
			_barrier(builder, at + Vector3.UP * .5, Vector3(run_length, 1.0, .1), basis)
			for height in [.5, 1.0]:
				_box(builder, at + Vector3.UP * height, Vector3(run_length, .05, .05), basis, rail)
			for end in run:
				_box(builder, centre + along * float(end) + Vector3.UP * .5, Vector3(.06, 1.0, .06), basis, post)

## The base's outer roof edges: [a, b, outward] for every edge of every room
## (its outline, or its squares) that has open ground just beyond it.
static func _outer_edges(builder: Node) -> Array:
	var edges: Array = []
	var half: float = BuildController.CELL * .5
	for zone in builder.zones:
		if not builder._is_habitat_zone(zone) or zone.has("angled_mount"): continue
		var sides: Array = []
		var outline: PackedVector2Array = builder.zone_outline(zone) if zone.has("outline") or not str(zone.kind) in BuildController.NON_ROOM_KINDS else PackedVector2Array()
		if outline.size() >= 3:
			for i in range(outline.size()): sides.append([outline[i], outline[(i + 1) % outline.size()]])
		else:
			for cell in zone.get("cells", []):
				var c := Vector2(cell) * BuildController.CELL
				var corners := [c + Vector2(-half, -half), c + Vector2(half, -half), c + Vector2(half, half), c + Vector2(-half, half)]
				for i in 4: sides.append([corners[i], corners[(i + 1) % 4]])
		for side in sides:
			var a: Vector2 = side[0]
			var b: Vector2 = side[1]
			var length := a.distance_to(b)
			if length < .2: continue
			var normal := (b - a).normalized().orthogonal()
			var out := -normal if builder._point_in_zone((a + b) * .5 + normal * .3, zone) else normal
			if builder._point_in_zone((a + b) * .5 + out * .3, zone): continue   # inside the room
			# In short pieces, so a side only partly shared with the next room
			# keeps its rail just where there's open ground; open pieces in a
			# row join back into one run.
			var pieces := maxi(1, ceili(length / .75))
			var run_start := -1
			for i in range(pieces + 1):
				var open := false
				if i < pieces:
					var piece_mid := a.lerp(b, (i + .5) / pieces)
					open = not builder._is_habitat_zone(builder._zone_at_point(piece_mid + out * .3))
				if open and run_start < 0: run_start = i
				elif not open and run_start >= 0:
					edges.append([a.lerp(b, float(run_start) / pieces), a.lerp(b, float(i) / pieces), out])
					run_start = -1
	return edges

## The room a roof square belongs to (the zone whose squares include it).
static func _roof_zone(builder: Node, cell: Vector2i) -> Dictionary:
	for zone in builder.zones:
		if builder._is_habitat_zone(zone) and (zone.get("cells", []) as Array).has(cell): return zone
	return {}

## The room's outline when it isn't plain grid squares (free-shape or angled).
static func _roof_outline(builder: Node, zone: Dictionary) -> PackedVector2Array:
	if zone.has("outline"): return builder.zone_outline(zone)
	if zone.has("angled_mount"): return builder._angled_mount_outline(zone.get("angled_mount", {}))
	return PackedVector2Array()

static func _roof_clipped(builder: Node, cell: Vector2i) -> bool:
	return not _roof_outline(builder, _roof_zone(builder, cell)).is_empty()

## One roof square's shielding, as polygons on the ground plane (x, z): the
## square, inset from its edges, for a grid room; for a free-shape or angled
## room, the part of the square under the roof, so it follows angled walls
## instead of hanging over them as a square.
static func roof_patches(builder: Node, cell: Vector2i, inset := .175) -> Array:
	var size: float = BuildController.CELL
	var c := Vector2(cell) * size
	var h := size * .5
	var square := PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
	var outline := _roof_outline(builder, _roof_zone(builder, cell))
	var pieces: Array = [square] if outline.is_empty() else Geometry2D.intersect_polygons(square, outline)
	var out: Array = []
	for piece in pieces:
		for shrunk in Geometry2D.offset_polygon(piece, -inset):
			if (shrunk as PackedVector2Array).size() >= 3: out.append(shrunk)
	return out

## A flat slab over a polygon (x, z) from y0 to y1; solid, so you can walk on it.
static func _slab(builder: Node, poly: PackedVector2Array, y0: float, y1: float, material: Material) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty(): return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var add_tri := func(a: Vector3, b: Vector3, c: Vector3, up: Vector3) -> void:
		if (b - a).cross(c - a).dot(up) < 0.0:
			var t := b; b = c; c = t
		for v in [a, b, c]: st.add_vertex(v)
	for i in range(0, tris.size(), 3):
		var p := [poly[tris[i]], poly[tris[i + 1]], poly[tris[i + 2]]]
		add_tri.call(Vector3(p[0].x, y1, p[0].y), Vector3(p[1].x, y1, p[1].y), Vector3(p[2].x, y1, p[2].y), Vector3.UP)
		add_tri.call(Vector3(p[0].x, y0, p[0].y), Vector3(p[1].x, y0, p[1].y), Vector3(p[2].x, y0, p[2].y), Vector3.DOWN)
	var middle := Vector2.ZERO
	for v in poly: middle += v
	middle /= poly.size()
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var mid := (a + b) * .5
		var out := Vector3(mid.x - middle.x, 0, mid.y - middle.y)
		add_tri.call(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), out)
		add_tri.call(Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), out)
	st.generate_normals()
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_to_group("wall_upgrade")
	builder.root.add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)

## A thin layer of regolith on one roof square, inset from the edge, with
## faint lines; solid, so you can walk on it.
static func _roof(builder: Node, centre: Vector3, cell_size: float) -> void:
	_box(builder, centre + Vector3.UP * .03, Vector3(cell_size - .35, .06, cell_size - .35), Basis.IDENTITY, _material(REGOLITH), true)
	var line := _material(REGOLITH_LINE)
	for offset in [-.75, 0.0, .75]:
		_box(builder, centre + Vector3(0, .065, offset), Vector3(cell_size - .35, .008, .02), Basis.IDENTITY, line)

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
