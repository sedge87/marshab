extends RefCounted

## The Site plan as an architect's floor plan (25 Oct). Room colours stay;
## on top, the structure is drawn with plan symbols, all in group
## "habitat_plan" so they only show in the Site plan:
##   walls        thick charcoal round the outside of the base, thinner
##                between rooms (partitions are drawn by BuildController)
##   doors        a gap and a quarter-circle swing; airlock hatches a double
##                bar with an arrow pointing out (BuildController calls door())
##   windows      a gap with three thin blue lines in the wall (window())
##   regolith     a brown hatched band outside the wall
##   water wall   a blue band with waves outside the wall
##   insulation   a zig-zag along the shared wall
##   roof shield  a cross-hatch over the room, and a ROOF SHIELDED tag
##   ladder       rails and rungs outside the wall, "↑ ROOF"
##   roof rail    a dashed accent line round the roof edge
## The legend (Legend, below) explains them, with a north arrow and a scale.

const WALL := Color("#1B2226")
const GAP := Color("#E9EEF0")
const GLASS := Color("#7CC8EE")
const REGOLITH := Color("#9A6B4C")
const WATER := Color("#3F82B8")
const INSULATION := Color("#E8C468")
const LADDER := Color("#F2F4F5")
const OUTER_WIDTH := .24
const SHARED_WIDTH := .12
const Y_WALLS := .13
const Y_SYMBOLS := .16
const WALL_UPGRADES := preload("res://scripts/wall_upgrades.gd")

const PATTERN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 colour : source_color = vec4(0.6, 0.42, 0.3, 1.0);
uniform vec4 back : source_color = vec4(0.6, 0.42, 0.3, 0.35);
uniform int pattern = 0;   // 0 hatch, 1 waves, 2 zig-zag, 3 cross-hatch
uniform vec2 size = vec2(3.0, 0.4);   // metres
void fragment() {
	vec2 p = UV * size;
	float line = 0.0;
	if (pattern == 0) {
		line = step(0.62, fract((p.x + p.y) / 0.22));
	} else if (pattern == 1) {
		float wave = 0.5 * size.y + sin(p.x * 9.0) * size.y * 0.22;
		line = 1.0 - smoothstep(0.02, 0.05, abs(p.y - wave));
	} else if (pattern == 2) {
		float tri = abs(fract(p.x / 0.3) * 2.0 - 1.0);
		line = 1.0 - smoothstep(0.015, 0.04, abs(p.y - (0.15 + tri * (size.y - 0.3))));
	} else {
		float a = step(0.85, fract((p.x + p.y) / 0.45));
		float b = step(0.85, fract((p.x - p.y) / 0.45));
		line = max(a, b);
	}
	vec4 c = mix(back, colour, line);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

static var _shader: Shader
static var _flat := {}

static func _material(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if _flat.has(key): return _flat[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if colour.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.disable_fog = true
	_flat[key] = material
	return material

static func _pattern(colour: Color, back: Color, pattern: int, size: Vector2) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PATTERN_SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("colour", colour)
	material.set_shader_parameter("back", back)
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("size", size)
	return material

## A flat strip from a to b (plan coordinates), this wide, at this height.
static func _strip(parent: Node3D, a: Vector2, b: Vector2, width: float, y: float, material: Material, extend := 0.0) -> MeshInstance3D:
	var length := a.distance_to(b)
	if length < .01: return null
	var along := Vector3(b.x - a.x, 0, b.y - a.y) / length
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length + extend, .02, width)
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mid := (a + b) * .5
	mesh.transform = Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(mid.x, y, mid.y))
	parent.add_child(mesh)
	return mesh

## A flat patterned band from a to b, `width` deep, its far edge `out` of the line.
static func _band(parent: Node3D, a: Vector2, b: Vector2, out: Vector2, offset: float, width: float, y: float, material: ShaderMaterial) -> void:
	var length := a.distance_to(b)
	if length < .05: return
	var along := Vector3(b.x - a.x, 0, b.y - a.y) / length
	var plane := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(length, width)
	plane.mesh = quad
	plane.material_override = material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mid := (a + b) * .5 + out * (offset + width * .5)
	var normal := Vector3(out.x, 0, out.y)
	plane.transform = Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(mid.x, y, mid.y))
	# PlaneMesh's local Z is its width: make sure it runs outward.
	if plane.transform.basis.z.dot(normal) < 0.0: plane.transform.basis = plane.transform.basis.rotated(Vector3.UP, PI)
	parent.add_child(plane)

static func _label(parent: Node3D, text: String, at: Vector3, colour: Color, size := 26) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = MHStyle.font(700, true, 1)
	label.font_size = size
	label.pixel_size = .01
	label.modulate = colour
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, .6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	parent.add_child(label)

# ---------- the whole plan ----------

## Rebuild the plan layer (BuildController._rebuild calls this).
static func build(builder: Node) -> void:
	var layer := Node3D.new()
	layer.name = "FloorPlan"
	layer.add_to_group("habitat_plan")
	layer.visible = builder.build_mode
	builder.root.add_child(layer)
	var base_y: float = builder.habitat_base_y
	_walls(builder, layer, base_y)
	_upgrades(builder, layer, base_y)
	for node in layer.find_children("*", "VisualInstance3D", true, false): (node as VisualInstance3D).visible = builder.build_mode

## Every room's sides in short pieces: thick where there's open ground beyond,
## thin where another room is (drawn once), nothing inside a room.
static func _walls(builder: Node, layer: Node3D, base_y: float) -> void:
	var outer := _material(WALL)
	var shared := _material(WALL.lightened(.12))
	var half: float = BuildController.CELL * .5
	for zone_index in range(builder.zones.size()):
		var zone: Dictionary = builder.zones[zone_index]
		if not builder._is_habitat_zone(zone): continue
		var sides: Array = []
		var outline := PackedVector2Array()
		if zone.has("angled_mount"): outline = builder._angled_mount_outline(zone.angled_mount)
		elif zone.has("outline") or not str(zone.kind) in BuildController.NON_ROOM_KINDS: outline = builder.zone_outline(zone)
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
			var pieces := maxi(1, ceili(length / .75))
			var run := ""
			var run_start := 0
			for i in range(pieces + 1):
				var kind := ""
				if i < pieces:
					var beyond: Dictionary = builder._zone_at_point(a.lerp(b, (i + .5) / pieces) + out * .3)
					if beyond == zone: kind = ""
					elif not builder._is_habitat_zone(beyond): kind = "outer"
					elif builder.zones.find(beyond) > zone_index: kind = "shared"
				if kind != run:
					if run == "outer": _strip(layer, a.lerp(b, float(run_start) / pieces), a.lerp(b, float(i) / pieces), OUTER_WIDTH, base_y + Y_WALLS, outer, OUTER_WIDTH)
					elif run == "shared": _strip(layer, a.lerp(b, float(run_start) / pieces), a.lerp(b, float(i) / pieces), SHARED_WIDTH, base_y + Y_WALLS, shared, SHARED_WIDTH)
					run = kind
					run_start = i

## Shielding, insulation, roof shielding, ladders and the roof rail.
static func _upgrades(builder: Node, layer: Node3D, base_y: float) -> void:
	var cell_size: float = BuildController.CELL
	var y := base_y + Y_SYMBOLS
	var roofed := {}
	for record in builder.wall_upgrades:
		var kind := str(record.kind)
		if kind == "roof":
			var c: Vector2 = Vector2(record.cell) * cell_size
			_band(layer, c + Vector2(-cell_size * .5 + .1, 0), c + Vector2(cell_size * .5 - .1, 0), Vector2(0, 1), -(cell_size * .5 - .1), cell_size - .2, base_y + .05,
				_pattern(Color(1, 1, 1, .5), Color(1, 1, 1, 0), 3, Vector2(cell_size - .2, cell_size - .2)))
			var zone: Dictionary = builder._zone_at_point(c)
			if not zone.is_empty(): roofed[builder.zones.find(zone)] = zone
			continue
		var mid: Vector2 = record.mid
		var out: Vector2 = record.outward
		var along := Vector2(-out.y, out.x)
		var a := mid - along * (cell_size * .5 - .15)
		var b := mid + along * (cell_size * .5 - .15)
		match kind:
			"regolith": _band(layer, a, b, out, OUTER_WIDTH * .5, .42, y, _pattern(REGOLITH, Color(REGOLITH, .35), 0, Vector2(a.distance_to(b), .42)))
			"water": _band(layer, a, b, out, OUTER_WIDTH * .5, .42, y, _pattern(WATER.lightened(.3), Color(WATER, .45), 1, Vector2(a.distance_to(b), .42)))
			"acoustic": _band(layer, a + along * .2, b - along * .2, out, -.2, .4, y, _pattern(INSULATION, Color(INSULATION, 0.0), 2, Vector2(a.distance_to(b) - .4, .4)))
			"ladder": _ladder(layer, mid, out, along, y)
	for index in roofed:
		var zone: Dictionary = roofed[index]
		var centre := Vector3.ZERO
		var cells: Array = zone.get("cells", [])
		for cell in cells: centre += Vector3(cell.x * cell_size, 0, cell.y * cell_size)
		if cells.size() > 0: centre /= cells.size()
		_label(layer, "ROOF SHIELDED", centre + Vector3(0, base_y + .5, 0) + Vector3(0, 0, 1.0), Color("#F2F4F5"), 22)
	# The roof rail: dashes just inside the outer edge, once there's a ladder.
	if builder.wall_upgrades.any(func(r): return str(r.kind) == "ladder"):
		var dash := _material(MHStyle.accent)
		for edge in WALL_UPGRADES._outer_edges(builder):
			var ea: Vector2 = (edge[0] as Vector2) - (edge[2] as Vector2) * .35
			var eb: Vector2 = (edge[1] as Vector2) - (edge[2] as Vector2) * .35
			var length := ea.distance_to(eb)
			var step := .8
			var t := .15
			while t < length - .1:
				_strip(layer, ea.lerp(eb, t / length), ea.lerp(eb, minf(t + .45, length) / length), .07, y + .005, dash)
				t += step

static func _ladder(layer: Node3D, mid: Vector2, out: Vector2, along: Vector2, y: float) -> void:
	var white := _material(LADDER)
	var foot := mid + out * .35
	var tip := mid + out * 1.15
	for side in [-.28, .28]:
		_strip(layer, foot + along * side, tip + along * side, .06, y, white)
	for i in range(1, 5):
		var at := foot.lerp(tip, i / 5.0)
		_strip(layer, at - along * .28, at + along * .28, .05, y, white)
	var label_at := mid + out * 1.7
	_label(layer, "↑ ROOF", Vector3(label_at.x, y + .4, label_at.y), LADDER, 24)

# ---------- doors and windows (called by BuildController) ----------

## A door's plan symbol, in the door's own frame (local X along the doorway).
## Airlock hatches (OUTER, HANGAR): a double accent bar and an arrow pointing
## out. Inner hatches (INNER, BAY): a double amber bar. Room doors: a gap,
## the leaf and its quarter-circle swing.
static func door(builder: Node, door: Node3D, door_name: String, width: float) -> void:
	var holder := Node3D.new()
	holder.name = "DoorPlanMarker"
	holder.position = Vector3(0, Y_SYMBOLS - .02, 0)
	holder.add_to_group("habitat_plan")
	door.add_child(holder)
	var gap := _material(GAP)
	_strip(holder, Vector2(-width * .5, 0), Vector2(width * .5, 0), .3, 0.0, gap)
	if door_name in ["OUTER", "HANGAR", "INNER", "BAY"]:
		var colour: Color = MHStyle.accent if door_name in ["OUTER", "HANGAR"] else MHStyle.BEACON_YELLOW
		for z in [-.11, .11]:
			_strip(holder, Vector2(-width * .5, z), Vector2(width * .5, z), .06, .01, _material(colour))
		if door_name in ["OUTER", "HANGAR"]:
			# Which side is Mars: the arrow points out.
			var normal: Vector3 = door.global_transform.basis.z
			var probe := door.global_position + normal * .9
			var outside: float = 1.0 if builder._zone_at_point(Vector2(probe.x, probe.z)).is_empty() else -1.0
			_arrow(holder, outside, _material(colour))
	else:
		var leaf := width * .9
		var hinge := Vector2(-width * .5, 0)
		_strip(holder, hinge, hinge + Vector2(0, leaf), .05, .01, _material(WALL))
		_arc(holder, hinge, leaf, _material(WALL.lightened(.25)))
	holder.visible = builder.build_mode
	for node in holder.find_children("*", "VisualInstance3D", true, false): (node as VisualInstance3D).visible = builder.build_mode

static func _arrow(holder: Node3D, side: float, material: Material) -> void:
	var points := PackedVector3Array([Vector3(-.22, .01, .3 * side), Vector3(.22, .01, .3 * side), Vector3(0, .01, .62 * side)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	holder.add_child(node)

## The door's swing: a thin quarter circle from the open leaf to the closed one.
static func _arc(holder: Node3D, hinge: Vector2, radius: float, material: Material) -> void:
	var points := PackedVector3Array()
	var steps := 14
	for i in range(steps):
		for k in [[i, radius - .025], [i, radius + .025], [i + 1, radius + .025], [i, radius - .025], [i + 1, radius + .025], [i + 1, radius - .025]]:
			var angle := float(k[0]) / steps * PI * .5
			points.append(Vector3(hinge.x + cos(angle) * float(k[1]), .01, hinge.y + sin(angle) * float(k[1])))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	holder.add_child(node)

## A window's plan symbol: a gap in the wall with three thin blue lines.
static func window(builder: Node, mid: Vector2, basis: Basis, length: float) -> void:
	var holder := Node3D.new()
	holder.name = "WindowPlanMarker"
	holder.transform = Transform3D(basis, Vector3(mid.x, builder.habitat_base_y + Y_SYMBOLS, mid.y))
	holder.add_to_group("habitat_plan")
	builder.root.add_child(holder)
	_strip(holder, Vector2(-length * .5 + .2, 0), Vector2(length * .5 - .2, 0), .3, 0.0, _material(GAP))
	for z in [-.1, 0.0, .1]:
		_strip(holder, Vector2(-length * .5 + .2, z), Vector2(length * .5 - .2, z), .03, .01, _material(GLASS))
	holder.visible = builder.build_mode
	for node in holder.find_children("*", "VisualInstance3D", true, false): (node as VisualInstance3D).visible = builder.build_mode

# ---------- the legend ----------

## The key to the plan symbols, with a north arrow and a scale bar (they
## turn and grow with the camera: BuildController calls update()).
class Legend extends PanelContainer:
	var north: Control
	var scale_label: Label
	var scale_bar: Control
	var _north_angle := 0.0
	var _bar_pixels := 60.0
	const ENTRIES := [["outer", "Outside wall"], ["shared", "Wall between rooms"], ["door", "Door"], ["hatch", "Airlock hatch"],
		["window", "Window"], ["regolith", "Regolith shielding"], ["water", "Water wall"], ["roof", "Roof shielding"],
		["insulation", "Sound insulation"], ["ladder", "Roof ladder"], ["rail", "Roof rail"]]

	func _ready() -> void:
		add_theme_stylebox_override("panel", MHStyle.box(MHStyle.SURFACE_HUD, MHStyle.BORDER_SUBTLE, 8, 1, Vector4(14, 10, 14, 12)))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := MHStyle.vbox(8)
		add_child(col)
		var head := MHStyle.hbox(10)
		col.add_child(head)
		head.add_child(MHStyle.eyebrow("Plan key · L hides", MHStyle.accent, 11))
		head.add_child(MHStyle.spacer())
		scale_bar = Control.new()
		scale_bar.custom_minimum_size = Vector2(80, 16)
		scale_bar.draw.connect(_draw_scale)
		head.add_child(scale_bar)
		north = Control.new()
		north.custom_minimum_size = Vector2(22, 22)
		north.draw.connect(_draw_north)
		head.add_child(north)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 4)
		col.add_child(grid)
		for entry in ENTRIES:
			var row := MHStyle.hbox(6)
			var swatch := Control.new()
			swatch.custom_minimum_size = Vector2(30, 14)
			swatch.draw.connect(_draw_swatch.bind(swatch, str(entry[0])))
			row.add_child(swatch)
			row.add_child(MHStyle.mono(str(entry[1]), 11, MHStyle.TEXT_SECONDARY))
			grid.add_child(row)

	## Camera yaw (radians) and how many pixels 5 m covers at the base.
	func update(yaw: float, pixels_for_5m: float) -> void:
		if absf(yaw - _north_angle) > .01:
			_north_angle = yaw
			north.queue_redraw()
		var pixels := clampf(pixels_for_5m, 8.0, 78.0)
		if absf(pixels - _bar_pixels) > .5:
			_bar_pixels = pixels
			scale_bar.queue_redraw()

	func _draw_north() -> void:
		var c := north.size * .5
		var up := Vector2(0, -1).rotated(_north_angle)
		var side := up.orthogonal()
		north.draw_colored_polygon(PackedVector2Array([c + up * 9, c - up * 6 + side * 5, c - up * 6 - side * 5]), Color("#F2F4F5"))
		north.draw_string(ThemeDB.fallback_font, c + up * 15 - Vector2(4, -4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#F2F4F5"))

	func _draw_scale() -> void:
		var y := scale_bar.size.y - 4
		var x0 := scale_bar.size.x - _bar_pixels
		scale_bar.draw_line(Vector2(x0, y), Vector2(scale_bar.size.x, y), Color("#F2F4F5"), 2.0)
		scale_bar.draw_line(Vector2(x0, y - 4), Vector2(x0, y), Color("#F2F4F5"), 2.0)
		scale_bar.draw_line(Vector2(scale_bar.size.x - 1, y - 4), Vector2(scale_bar.size.x - 1, y), Color("#F2F4F5"), 2.0)
		scale_bar.draw_string(ThemeDB.fallback_font, Vector2(x0 - 28, y + 1), "5 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#F2F4F5"))

	func _draw_swatch(swatch: Control, kind: String) -> void:
		var w := swatch.size.x
		var h := swatch.size.y
		var mid := h * .5
		match kind:
			"outer": swatch.draw_rect(Rect2(0, mid - 2.5, w, 5), Color("#3A464C"))
			"shared": swatch.draw_rect(Rect2(0, mid - 1.2, w, 2.4), Color("#5A676D"))
			"door":
				swatch.draw_line(Vector2(4, h), Vector2(4, 1), Color("#C9D2D6"), 1.5)
				swatch.draw_arc(Vector2(4, h), h - 1, -PI * .5, 0, 10, Color("#C9D2D6"), 1.0)
			"hatch":
				swatch.draw_line(Vector2(2, mid - 2.5), Vector2(w - 8, mid - 2.5), MHStyle.accent, 2.0)
				swatch.draw_line(Vector2(2, mid + 2.5), Vector2(w - 8, mid + 2.5), MHStyle.accent, 2.0)
				swatch.draw_colored_polygon(PackedVector2Array([Vector2(w - 7, mid - 4), Vector2(w - 7, mid + 4), Vector2(w - 1, mid)]), MHStyle.accent)
			"window":
				for dy in [-3.0, 0.0, 3.0]: swatch.draw_line(Vector2(0, mid + dy), Vector2(w, mid + dy), Color("#7CC8EE"), 1.0)
			"regolith":
				swatch.draw_rect(Rect2(0, 2, w, h - 4), Color(0.6, 0.42, 0.3, .35))
				for x in range(-10, int(w), 4): swatch.draw_line(Vector2(x, h - 2), Vector2(x + h - 4, 2), Color("#9A6B4C"), 1.0)
			"water":
				swatch.draw_rect(Rect2(0, 2, w, h - 4), Color(0.25, 0.51, 0.72, .45))
				var points := PackedVector2Array()
				for i in range(16): points.append(Vector2(i * w / 15.0, mid + sin(i * 1.2) * 2.5))
				swatch.draw_polyline(points, Color("#9CC3E0"), 1.2)
			"roof":
				for x in range(-12, int(w), 5):
					swatch.draw_line(Vector2(x, h), Vector2(x + h, 0), Color(1, 1, 1, .45), 1.0)
					swatch.draw_line(Vector2(x, 0), Vector2(x + h, h), Color(1, 1, 1, .45), 1.0)
			"insulation":
				var zig := PackedVector2Array()
				for i in range(9): zig.append(Vector2(i * w / 8.0, 2 if i % 2 == 0 else h - 2))
				swatch.draw_polyline(zig, Color("#E8C468"), 1.4)
			"ladder":
				swatch.draw_line(Vector2(3, mid - 4), Vector2(w - 3, mid - 4), Color("#F2F4F5"), 1.5)
				swatch.draw_line(Vector2(3, mid + 4), Vector2(w - 3, mid + 4), Color("#F2F4F5"), 1.5)
				for x in [8, 14, 20]: swatch.draw_line(Vector2(x, mid - 4), Vector2(x, mid + 4), Color("#F2F4F5"), 1.2)
			"rail":
				for x in range(0, int(w), 8): swatch.draw_line(Vector2(x, mid), Vector2(x + 5, mid), MHStyle.accent, 2.0)
