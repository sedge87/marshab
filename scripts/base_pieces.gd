extends RefCounted

## The pieces A4 adds to the builder (scripts/build_controller.gd), built
## from code like the rest of the shell:
## - a corridor that climbs between rooms on different levels: a ramp, or,
##   when it's short for the climb, a steep ship's ladder you walk up;
## - the crew's landing pad and its beacon (the main base);
## - the traces a refolded base leaves: its rooms' printed footprints.
## Docs: docs/bases-and-vehicles.md, "As built (A4)".

const BASES := preload("res://scripts/bases.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const CELL := 3.0
const PAD_CELLS := 6            # the pad is 6 × 6 cells (18 m)
const PAD_UNEVEN := 1.5         # metres of ground fall the printer will fill under it
const WALL := .16
const HEIGHT := 2.9

# ---------- the landing pad ----------

static func pad_cells(at: Vector2i) -> Array:
	if at.x == 999: return []
	var out: Array = []
	var start := at - Vector2i(PAD_CELLS / 2, PAD_CELLS / 2)
	for x in PAD_CELLS:
		for z in PAD_CELLS: out.append(start + Vector2i(x, z))
	return out

static func pad_zone(builder: Object) -> Dictionary:
	for zone in builder.get("zones"):
		if str(zone.get("kind", "")) == "landing_pad": return zone
	return {}

## Why the pad can't go here ("" when it can, or for anything else).
static func pad_reason(builder: Object, kind: String, cells: Array) -> String:
	if kind != "landing_pad": return ""
	var there := pad_zone(builder)
	if not there.is_empty(): return "There's one landing pad, at %s" % BASES.label_for(BASES.base_of(there))
	var id := str(builder.get("active_base"))
	if BASES.zones_of(builder, id).is_empty(): return "Build it at a base: its core comes first"
	var low := INF
	var high := -INF
	for cell in cells:
		var h := float(builder.call("_cell_highest_terrain", cell))
		low = minf(low, h)
		high = maxf(high, h)
	if high - low > PAD_UNEVEN: return "Too uneven for the pad: find flatter ground"
	return ""

## The printed slab, its edge lights and the beacon mast at one corner.
static func build_landing_pad(builder: Object, zone: Dictionary) -> void:
	var cells: Array = zone.get("cells", [])
	if cells.is_empty(): return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var low := INF
	var top := -INF
	for cell in cells:
		lo = Vector2(minf(lo.x, cell.x), minf(lo.y, cell.y))
		hi = Vector2(maxf(hi.x, cell.x), maxf(hi.y, cell.y))
		var h := float(builder.call("_cell_highest_terrain", cell))
		top = maxf(top, h)
		low = minf(low, float(builder.call("_terrain_height", Vector3(cell.x * CELL, 0, cell.y * CELL))))
	top += .15
	var a := lo * CELL - Vector2.ONE * CELL * .5
	var b := hi * CELL + Vector2.ONE * CELL * .5
	var middle := (a + b) * .5
	var size := b - a
	var depth := maxf(.3, top - low + .3)
	builder.call("_add_box", Vector3(middle.x, top - depth * .5, middle.y), Vector3(size.x, depth, size.y), Color("#8E7A66"), true, "landing_pad")
	# A ring painted round the touchdown point (a darker inset, no lettering).
	builder.call("_add_box", Vector3(middle.x, top + .01, middle.y), Vector3(size.x * .55, .02, size.y * .55), Color("#6E5E50"), false, "landing_pad")
	var root: Node3D = builder.get("root")
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("#FFB347")
	lamp.emission_enabled = true
	lamp.emission = Color("#FFB347")
	lamp.emission_energy_multiplier = 2.0
	var corners := [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var steps := roundi(from.distance_to(to) / CELL)
		for k in steps:
			var p := from.lerp(to, float(k) / float(steps))
			var light := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = .09
			cyl.bottom_radius = .12
			cyl.height = .22
			light.mesh = cyl
			light.material_override = lamp
			light.position = Vector3(p.x, top + .11, p.y)
			light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(light)
	# The beacon: a mast at the far corner, its lamp slow-blinking red.
	var mast_at: Vector2 = b + Vector2(.8, .8)
	var ground := float(builder.call("_terrain_height", Vector3(mast_at.x, 0, mast_at.y)))
	builder.call("_add_box", Vector3(mast_at.x, ground + 3.0, mast_at.y), Vector3(.22, 6.0, .22), MHStyle.FRAME_STEEL, true, "landing_pad")
	var beacon := OmniLight3D.new()
	beacon.name = "PadBeacon"
	beacon.light_color = Color("#FF4A3A")
	beacon.light_energy = 3.0
	beacon.omni_range = 40.0
	beacon.position = Vector3(mast_at.x, ground + 6.2, mast_at.y)
	beacon.set_meta("budget_exempt", true)
	root.add_child(beacon)
	var blink := beacon.create_tween().set_loops()
	blink.tween_property(beacon, "light_energy", 0.0, .9)
	blink.tween_property(beacon, "light_energy", 3.0, .2)

# ---------- a corridor that climbs ----------

## Floor, roof and walls following the climb, the ends open to the rooms they
## meet (or capped), a light in the middle. Steeper than a ramp: steps over
## it, and rails.
static func build_climbing_corridor(builder: Object, zone: Dictionary) -> void:
	var ends := BASES.corridor_ends(zone)
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var rise: Array = zone.rise
	var ya := float(rise[0])
	var yb := float(rise[1])
	var along := (b - a).normalized()
	var across := Vector2(-along.y, along.x)
	var ramp := BASES.is_ramp(zone)
	var colour: Color = BuildController.ZONE_TYPES.corridor.colour
	var point := func(t: float, s: float, h: float) -> Vector3:
		var p: Vector2 = a.lerp(b, t) + across * s
		return Vector3(p.x, lerpf(ya, yb, t) + h, p.y)
	var slab := func(s0: float, s1: float, h0: float, h1: float, tint: Color, solid: bool, visible := true, material: Material = null) -> void:
		var c: Array = [point.call(0.0, s0, h0), point.call(1.0, s0, h0), point.call(1.0, s1, h0), point.call(0.0, s1, h0),
			point.call(0.0, s0, h1), point.call(1.0, s0, h1), point.call(1.0, s1, h1), point.call(0.0, s1, h1)]
		prism(builder, c, tint, solid, visible, material)
	var steps := ceili(absf(yb - ya) / .25)
	var riser := absf(yb - ya) / maxf(1.0, steps)
	# The walking surface: smooth either way; a ship's ladder's steps sit on it.
	var deck: Material = BuildController._deck_material(colour)
	slab.call(-CELL * .5, CELL * .5, -.2 + (0.0 if ramp else riser * .5), 0.0 + (0.0 if ramp else riser * .5), colour, true, ramp, deck)
	slab.call(-CELL * .5, CELL * .5, HEIGHT, HEIGHT + .15, MHStyle.STRUCTURAL_WHITE, true, true, BuildController._ceiling_material())
	slab.call(CELL * .5 - WALL, CELL * .5, -.2, HEIGHT, MHStyle.STRUCTURAL_WHITE, true)
	slab.call(-CELL * .5, -CELL * .5 + WALL, -.2, HEIGHT, MHStyle.STRUCTURAL_WHITE, true)
	# Orange edge strips along a ramp's floor, so the slope reads.
	if ramp:
		for s in [CELL * .5 - WALL - .12, -CELL * .5 + WALL + .02]:
			slab.call(s, s + .1, .0, .015, MHStyle.SAFETY_ORANGE, false)
	else:
		var length := a.distance_to(b)
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var y_top := maxf(lerpf(ya, yb, t0), lerpf(ya, yb, t1))
			var centre := a.lerp(b, (t0 + t1) * .5)
			var run := length / steps
			var size := Vector3(absf(along.x) * run + absf(across.x) * 2.5, .06, absf(along.y) * run + absf(across.y) * 2.5)
			builder.call("_add_box", Vector3(centre.x, y_top - .03, centre.y), size, colour.darkened(.3), false, "habitat_floor")
		for s in [CELL * .5 - WALL - .1, -CELL * .5 + WALL + .05]:
			slab.call(s, s + .05, .95, 1.0, MHStyle.SAFETY_ORANGE, false)
	# Ends that meet no room are walled off.
	var cells: Array = zone.cells
	for end in 2:
		var cell: Vector2i = cells[0] if end == 0 else cells[cells.size() - 1]
		var hits := BASES.touching(builder, [cell], zone)
		if not hits.is_empty(): continue
		var face: Vector2 = a if end == 0 else b
		var y := ya if end == 0 else yb
		var size := Vector3(absf(along.x) * WALL + absf(across.x) * CELL, HEIGHT, absf(along.y) * WALL + absf(across.y) * CELL)
		builder.call("_add_box", Vector3(face.x, y + HEIGHT * .5, face.y), size, MHStyle.STRUCTURAL_WHITE, true, "habitat_wall")
	var mid := a.lerp(b, .5)
	builder.call("_add_powered_fixture", Vector3(mid.x, lerpf(ya, yb, .5) + 2.81, mid.y), "corridor")
	for cell in cells:
		builder.call("_add_plan_tile", Vector3(cell.x * CELL, BASES.corridor_cell_y(builder, zone, cell) - float(builder.get("habitat_base_y")), cell.y * CELL), BuildController.plan_colour("corridor"), "corridor")

## A solid of eight corners (bottom four, then the top four above them, in
## the same order), drawn and, if solid, collided with exactly.
static func prism(builder: Object, c: Array, tint: Color, solid: bool, visible := true, material: Material = null) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("habitat_floor" if solid else "habitat_trim")
	(builder.get("root") as Node3D).add_child(body)
	if visible:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for quad in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
			for i in [0, 1, 2, 0, 2, 3]: st.add_vertex(c[quad[i]])
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		var m: Material = material
		if m == null:
			var plain := StandardMaterial3D.new()
			plain.albedo_color = tint
			plain.roughness = .7
			m = plain
		if m is BaseMaterial3D and (m as BaseMaterial3D).cull_mode != BaseMaterial3D.CULL_DISABLED:
			m = (m as BaseMaterial3D).duplicate()
			(m as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = m
		body.add_child(mesh)
	if solid:
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array(c)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)

# ---------- traces ----------

## What a refolded base leaves: each room's printed footprint on the ground.
static func build_traces(builder: Object) -> void:
	var list: Array = builder.get("traces")
	if list.is_empty(): return
	var root: Node3D = builder.get("root")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#5E4C40")
	material.roughness = .95
	for trace in list:
		for cell in trace.get("cells", []):
			var c := Vector2i(cell) if cell is Vector2i else Vector2i(int(cell[0]), int(cell[1]))
			var at := Vector3(c.x * CELL, 0, c.y * CELL)
			var pad := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(CELL - .08, .06, CELL - .08)
			pad.mesh = box
			pad.material_override = material
			pad.position = Vector3(at.x, float(builder.call("_cell_highest_terrain", c)) + .02, at.z)
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pad.name = "BaseTrace"
			root.add_child(pad)
