extends RefCounted

## Telling the rooms apart from the inside (playtest, 21 Oct): each habitat
## room gets
##   - a band in its room colour round the walls, just under the ceiling line
##     (the waist rails keep the colony accent);
##   - a sign on both faces of every door header naming the room it leads to;
##   - overhead detail that matches the room's job: ducts, pipes, cable trays,
##     grow-light rails, a curtain track... all above the 2.46 m door opening,
##     so nothing blocks walking or furniture.
## Built by BuildController._rebuild into its `root`; purely visual.

const BAND_Y := 2.26           # band centre above the floor, just under the wall kit's top beam
const RUN_INSET := .35         # how far the first run sits off the wall
const BRACKET_STEP := 1.2

## Overhead kits: runs along a wall. side 0 = the room's longest wall, 1 = the
## wall opposite it. shape: duct (w x h box, with vents), pipe (radius r),
## tray (cable tray), rail (w x h), lights (glowing grow-light bar).
const KITS := {
	"life_support": [
		{"shape": "duct", "side": 0, "off": .5, "y": 2.6, "w": .55, "h": .32, "colour": "#B9BFC3", "vents": true},
		{"shape": "pipe", "side": 1, "off": .25, "y": 2.7, "r": .075, "colour": "#DCD5C5"},
		{"shape": "pipe", "side": 1, "off": .45, "y": 2.7, "r": .05, "colour": "#4F86B0"}],
	"engineering": [
		{"shape": "tray", "side": 0, "off": .4, "y": 2.66, "w": .45, "colour": "#5E666B"},
		{"shape": "pipe", "side": 1, "off": .2, "y": 2.72, "r": .04, "colour": "#3A4045"},
		{"shape": "pipe", "side": 1, "off": .32, "y": 2.72, "r": .04, "colour": "#E0A33A"}],
	"hydroponics": [
		{"shape": "lights", "side": 0, "off": 1.0, "y": 2.66, "w": .14, "h": .05, "colour": "#D77BFF"},
		{"shape": "lights", "side": 0, "off": 2.0, "y": 2.66, "w": .14, "h": .05, "colour": "#D77BFF"},
		{"shape": "pipe", "side": 1, "off": .25, "y": 2.68, "r": .035, "colour": "#6FAF6F", "drips": true}],
	"galley": [
		{"shape": "duct", "side": 0, "off": .55, "y": 2.62, "w": .6, "h": .28, "colour": "#C8CCD0", "vents": true},
		{"shape": "pipe", "side": 1, "off": .22, "y": 2.72, "r": .035, "colour": "#8FB6D0"},
		{"shape": "pipe", "side": 1, "off": .34, "y": 2.72, "r": .035, "colour": "#C0864F"}],
	"hygiene": [
		{"shape": "pipe", "side": 0, "off": .2, "y": 2.72, "r": .045, "colour": "#8FB6D0"},
		{"shape": "pipe", "side": 0, "off": .36, "y": 2.68, "r": .065, "colour": "#6B6F72"},
		{"shape": "duct", "side": 1, "off": .4, "y": 2.66, "w": .32, "h": .2, "colour": "#C8CCD0", "vents": true}],
	"medical": [
		{"shape": "rail", "side": 0, "off": 1.3, "y": 2.8, "w": .05, "h": .04, "colour": "#D2D6DA", "curtain": true},
		{"shape": "pipe", "side": 1, "off": .22, "y": 2.72, "r": .03, "colour": "#6FC07A"},
		{"shape": "pipe", "side": 1, "off": .32, "y": 2.72, "r": .03, "colour": "#E8EEF2"}],
	"science": [
		{"shape": "duct", "side": 0, "off": .45, "y": 2.62, "w": .36, "h": .36, "colour": "#E2E4E6", "vents": true},
		{"shape": "pipe", "side": 1, "off": .2, "y": 2.72, "r": .025, "colour": "#E8C547"},
		{"shape": "pipe", "side": 1, "off": .3, "y": 2.72, "r": .025, "colour": "#4F86B0"}],
	"storage": [
		{"shape": "rail", "side": 0, "off": .3, "y": 2.7, "w": .08, "h": .08, "colour": "#6E7478"},
		{"shape": "rail", "side": 1, "off": .3, "y": 2.7, "w": .08, "h": .08, "colour": "#6E7478"}],
	"communications": [
		{"shape": "tray", "side": 0, "off": .35, "y": 2.68, "w": .35, "colour": "#4A5157"},
		{"shape": "pipe", "side": 1, "off": .25, "y": 2.7, "r": .06, "colour": "#2B3034"}],
	"waste_management": [
		{"shape": "duct", "side": 0, "off": .5, "y": 2.58, "w": .45, "h": .45, "colour": "#8C8F84", "vents": true},
		{"shape": "pipe", "side": 1, "off": .3, "y": 2.68, "r": .07, "colour": "#5E5A52"}],
	"living": [
		{"shape": "rail", "side": 0, "off": .1, "y": 2.76, "w": .12, "h": .06, "colour": "#E6E2D8"}],
}

static var _materials := {}

static func build(builder: Node) -> void:
	var holder := Node3D.new()
	holder.name = "RoomIdentity"
	builder.root.add_child(holder)
	var base_y: float = builder.habitat_base_y
	for zone in builder.zones:
		var kind := str(zone.get("kind", ""))
		if zone.has("angled_mount") or not builder._is_habitat_zone(zone) or kind in ["corridor", "airlock", "vehicle_bay"]: continue
		var outline := _straight_walls(builder.zone_outline(zone))
		if outline.size() < 3: continue
		var colour: Color = builder.ZONE_TYPES.get(kind, {}).get("colour", Color.WHITE)
		_band(builder, holder, zone, outline, base_y, colour)
		_kit(holder, outline, base_y, KITS.get(kind, []))
	_door_signs(builder, holder, base_y)
	_emblems(builder, holder, base_y)

# ---------- the colour band ----------

## Only where a wall really stands: never across a doorway or an open
## corridor end. Grid rooms ask the builder face by face; free-form rooms
## skip the 3 m around any door on an edge.
static func _band(builder: Node, holder: Node3D, zone: Dictionary, outline: PackedVector2Array, base_y: float, colour: Color) -> void:
	var material := _material(colour, .35)
	if not zone.has("outline"):
		var half: float = builder.CELL * .5
		for cell in zone.get("cells", []):
			for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not builder._should_build_wall(cell, side): continue
				var face := Vector2(cell.x * builder.CELL, cell.y * builder.CELL) + Vector2(side) * (half - .13)
				var along := Vector2(-side.y, side.x)
				_box(holder, Vector3(builder.CELL - .02, .16, .02), Vector3(face.x, base_y + BAND_Y, face.y), -atan2(along.y, along.x), material)
		return
	var doors: Array = []
	for door in builder.root.find_children("*", "Node3D", true, false):
		# Doors from before this rebuild are still there, queued for deletion.
		if door.is_in_group("airlock_door") and not door.is_queued_for_deletion(): doors.append(Vector2(door.position.x, door.position.z))
	for index in range(outline.size()):
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var length := a.distance_to(b)
		if length < .3: continue
		var tangent := (b - a) / length
		var inward := _inward(outline, (a + b) * .5, tangent)
		# Pieces of the edge between doors.
		var cuts: Array = []
		for door: Vector2 in doors:
			var along: float = (door - a).dot(tangent)
			if absf((door - a).cross(tangent)) < .4 and along > -1.5 and along < length + 1.5: cuts.append(along)
		cuts.sort()
		var pieces: Array = []
		var from := 0.0
		for cut in cuts:
			if cut - 1.5 > from: pieces.append([from, cut - 1.5])
			from = maxf(from, cut + 1.5)
		if from < length: pieces.append([from, length])
		for piece in pieces:
			var piece_length: float = piece[1] - piece[0]
			if piece_length < .3: continue
			var mid: Vector2 = a + tangent * ((piece[0] + piece[1]) * .5) + inward * .13   # the wall's inner face is 0.115 m in
			_box(holder, Vector3(piece_length - .02, .16, .02), Vector3(mid.x, base_y + BAND_Y, mid.y), -atan2(tangent.y, tangent.x), material)

# ---------- overhead kits ----------

static func _kit(holder: Node3D, outline: PackedVector2Array, base_y: float, runs: Array) -> void:
	if runs.is_empty(): return
	var walls := _two_walls(outline)
	for run in runs:
		var wall: Array = walls[int(run.get("side", 0))]
		if wall.is_empty(): continue
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var length := a.distance_to(b) - .7
		if length < 1.0: continue
		var tangent := (b - a).normalized()
		var inward := _inward(outline, (a + b) * .5, tangent)
		var off := float(run.get("off", RUN_INSET))
		# Skip runs that would leave the room (narrow rooms, odd shapes).
		var start := a + tangent * .35 + inward * off
		var finish := b - tangent * .35 + inward * off
		if not (Geometry2D.is_point_in_polygon(start, outline) and Geometry2D.is_point_in_polygon(finish, outline) and Geometry2D.is_point_in_polygon((start + finish) * .5, outline)): continue
		var mid := (start + finish) * .5
		var yaw := -atan2(tangent.y, tangent.x)
		var y := base_y + float(run.get("y", 2.65))
		var colour := Color(str(run.get("colour", "#A0A6AA")))
		var material := _material(colour)
		match str(run.shape):
			"duct":
				var size := Vector3(length, float(run.h), float(run.w))
				_box(holder, size, Vector3(mid.x, y, mid.y), yaw, material)
				if bool(run.get("vents", false)):
					var grille := _material(colour.darkened(.45))
					for step in range(int(length / 1.5)):
						var at := start + tangent * (.75 + step * 1.5)
						_box(holder, Vector3(.42, .02, float(run.w) * .7), Vector3(at.x, y - float(run.h) * .5 - .005, at.y), yaw, grille)
			"pipe":
				_pipe(holder, start, finish, y, float(run.r), material)
				if bool(run.get("drips", false)):
					for step in range(int(length / .6)):
						var at := start + tangent * (.3 + step * .6)
						_box(holder, Vector3(.012, .35, .012), Vector3(at.x, y - .2, at.y), yaw, material)
			"tray":
				var w := float(run.w)
				_box(holder, Vector3(length, .02, w), Vector3(mid.x, y, mid.y), yaw, material)
				for side: float in [-1.0, 1.0]:
					var lip := mid + Vector2(-tangent.y, tangent.x) * side * w * .5
					_box(holder, Vector3(length, .07, .015), Vector3(lip.x, y + .035, lip.y), yaw, material)
				var cables := _material(Color("#1F2326"))
				for lane: float in [-.12, 0.0, .12]:
					var lane_offset := Vector2(-tangent.y, tangent.x) * lane * w
					_pipe(holder, start + lane_offset, finish + lane_offset, y + .03, .025, cables)
			"rail":
				_box(holder, Vector3(length, float(run.h), float(run.w)), Vector3(mid.x, y, mid.y), yaw, material)
				if bool(run.get("curtain", false)):
					var curtain := _material(Color("#9FC7C4"), 0.0, .85)
					var gathered := minf(1.4, length * .35)
					var at := start + tangent * gathered * .5
					_box(holder, Vector3(gathered, 1.0, .04), Vector3(at.x, y - .55, at.y), yaw, curtain)
			"lights":
				var glow := _material(colour, 2.4)
				_box(holder, Vector3(length, float(run.h), float(run.w)), Vector3(mid.x, y, mid.y), yaw, glow)
		# Hangers up to the ceiling every BRACKET_STEP.
		var hanger := _material(Color("#4A5055"))
		var top := base_y + 2.9
		if top - y > .12:
			for step in range(int(length / BRACKET_STEP) + 1):
				var at := start + tangent * minf(step * BRACKET_STEP, length)
				_box(holder, Vector3(.025, top - y, .025), Vector3(at.x, (top + y) * .5, at.y), yaw, hanger)

## The room's longest wall, and the wall most nearly opposite it.
static func _two_walls(outline: PackedVector2Array) -> Array:
	var longest := -1
	var best := 0.0
	for index in range(outline.size()):
		var length := outline[index].distance_to(outline[(index + 1) % outline.size()])
		if length > best:
			best = length
			longest = index
	if longest < 0: return [[], []]
	var a := outline[longest]
	var b := outline[(longest + 1) % outline.size()]
	var direction := (b - a).normalized()
	var opposite: Array = []
	var far := 0.0
	for index in range(outline.size()):
		if index == longest: continue
		var c := outline[index]
		var d := outline[(index + 1) % outline.size()]
		if c.distance_to(d) < 1.5 or absf((d - c).normalized().dot(direction)) < .95: continue
		var gap := absf((((c + d) * .5) - a).cross(direction))
		if gap > far:
			far = gap
			opposite = [c, d]
	return [[a, b], opposite]

# ---------- door signs ----------

## On both faces of every door header: the name of the room through it, in
## that room's colour. Outer airlock doors say MARS SURFACE from inside.
static func _door_signs(builder: Node, holder: Node3D, base_y: float) -> void:
	var plate := _material(Color("#14191C"))
	for door in builder.root.find_children("*", "Node3D", true, false):
		if not door.is_in_group("airlock_door") or door.is_queued_for_deletion(): continue   # a removed door's sign goes with it
		var position: Vector3 = door.position
		var facing: Vector3 = door.transform.basis.z
		var normal := Vector2(facing.x, facing.z).normalized()
		for side: float in [1.0, -1.0]:
			var here: Dictionary = builder._zone_at_point(Vector2(position.x, position.z) + normal * side * .8)
			var there: Dictionary = builder._zone_at_point(Vector2(position.x, position.z) - normal * side * .8)
			if here.is_empty(): continue   # no signs facing Mars
			var text := "MARS SURFACE"
			var colour := Color("#F2A65A")
			if not there.is_empty():
				var kind := str(there.kind)
				text = str(builder.ZONE_TYPES.get(kind, {}).get("label", kind)).to_upper()
				colour = builder.ZONE_TYPES.get(kind, {}).get("colour", Color.WHITE)
			if not there.is_empty() and is_same(here, there): continue
			var at := Vector2(position.x, position.z) + normal * side * .17
			var yaw := atan2(normal.x * side, normal.y * side)
			_box(holder, Vector3(1.7, .2, .02), Vector3(at.x, base_y + 2.58, at.y), yaw, plate)
			_box(holder, Vector3(.12, .12, .022), Vector3(at.x, base_y + 2.58, at.y) + Basis(Vector3.UP, yaw) * Vector3(-.72, 0, .002), yaw, _material(colour, .6))
			var label := Label3D.new()
			label.text = text
			label.font = MHStyle.font(800, false, 2)
			label.font_size = 40
			label.pixel_size = .0032
			label.modulate = colour.lightened(.35)
			label.outline_size = 0
			label.double_sided = false
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.position = Vector3(at.x, base_y + 2.58, at.y) + Basis(Vector3.UP, yaw) * Vector3(.08, 0, .015)
			label.rotation.y = yaw
			holder.add_child(label)

# ---------- the colony emblem ----------

## The emblem chosen on the colony screen, like a mission patch: a roundel
## above every outside airlock door, and a larger one with the colony's name
## on one outside wall of each room of two squares or more (never on a window).
static func _emblems(builder: Node, holder: Node3D, base_y: float) -> void:
	for door in builder.root.find_children("*", "Node3D", true, false):
		if not door.is_in_group("airlock_door") or door.is_queued_for_deletion(): continue
		var position: Vector3 = door.position
		var facing: Vector3 = door.transform.basis.z
		var normal := Vector2(facing.x, facing.z).normalized()
		for side: float in [1.0, -1.0]:
			# The side that faces Mars.
			if not builder._zone_at_point(Vector2(position.x, position.z) + normal * side * .8).is_empty(): continue
			if builder._zone_at_point(Vector2(position.x, position.z) - normal * side * .8).is_empty(): continue
			var at := Vector2(position.x, position.z) + normal * side * .32
			_roundel(holder, Vector3(at.x, base_y + 2.62, at.y), atan2(normal.x * side, normal.y * side), .27, "")
	var done := {}
	for bay in builder.get("_hull_bays"):
		var mid: Vector2 = bay.mid
		var outward: Vector2 = bay.outward
		var zone: Dictionary = builder._zone_at_point(mid - outward * .8)
		if zone.is_empty() or str(zone.get("kind", "")) in ["corridor", "airlock", "vehicle_bay"]: continue
		var cells: int = (zone.get("cells", []) as Array).size()
		if cells > 0 and cells < 2: continue
		var key: String = builder.simulation()._room_key(zone)
		if done.has(key): continue
		if builder._window_index_at(mid, builder._canonical_wall_dir(bay.tangent)) >= 0: continue
		done[key] = true
		var at := mid + outward * .2
		_roundel(holder, Vector3(at.x, base_y + 1.55, at.y), atan2(outward.x, outward.y), .5, MHGame.colony_name.to_upper())

static func _roundel(holder: Node3D, at: Vector3, yaw: float, radius: float, caption: String) -> void:
	var node := Node3D.new()
	node.name = "ColonyEmblem"
	node.position = at
	node.rotation.y = yaw
	holder.add_child(node)
	# A graphite rim, the accent disc, then the emblem in white.
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius * 1.12; rim_mesh.bottom_radius = radius * 1.12; rim_mesh.height = .02; rim_mesh.radial_segments = 40
	rim.mesh = rim_mesh
	rim.rotation.x = PI * .5
	rim.material_override = _material(Color("#4C5A61"))
	node.add_child(rim)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius; disc_mesh.bottom_radius = radius; disc_mesh.height = .03; disc_mesh.radial_segments = 40
	disc.mesh = disc_mesh
	disc.rotation.x = PI * .5
	disc.position.z = .006
	disc.material_override = MHGame.accent_material()
	node.add_child(disc)
	var icon := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 1.25, radius * 1.25)
	icon.mesh = quad
	icon.position.z = .024
	var material := StandardMaterial3D.new()
	material.albedo_texture = MHIcons.texture(MHGame.emblem, 128)
	material.albedo_color = Color("#F6F4EE")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = .5
	icon.material_override = material
	node.add_child(icon)
	for child in node.get_children(): (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if caption.length() >= 2:
		var label := Label3D.new()
		label.text = caption
		label.font = MHStyle.font(800, false, 3)
		label.font_size = 48
		label.pixel_size = .004
		label.modulate = Color("#F6F4EE")
		label.outline_modulate = Color("#2C353A")
		label.outline_size = 10
		label.double_sided = false
		label.position = Vector3(0, -radius - .2, .03)
		node.add_child(label)

# ---------- helpers ----------

## Outlines come with a vertex every 3 m; merge straight runs into whole walls.
static func _straight_walls(outline: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := outline.size()
	for index in range(count):
		var before := outline[(index - 1 + count) % count]
		var here := outline[index]
		var after := outline[(index + 1) % count]
		if absf((here - before).normalized().cross((after - here).normalized())) > .01: out.append(here)
	return out if out.size() >= 3 else outline

static func _inward(outline: PackedVector2Array, point: Vector2, tangent: Vector2) -> Vector2:
	var normal := Vector2(-tangent.y, tangent.x)
	return normal if Geometry2D.is_point_in_polygon(point + normal * .3, outline) else -normal

static func _material(colour: Color, glow := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [colour.to_html(), glow, alpha]
	if _materials.has(key): return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour, alpha)
	material.roughness = .6
	if alpha < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material

static func _box(holder: Node3D, size: Vector3, at: Vector3, yaw: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.rotation.y = yaw
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh)

static func _pipe(holder: Node3D, from: Vector2, to: Vector2, y: float, radius: float, material: Material) -> void:
	var length := from.distance_to(to)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius; cylinder.bottom_radius = radius; cylinder.height = length; cylinder.radial_segments = 10
	mesh.mesh = cylinder
	mesh.material_override = material
	var mid := (from + to) * .5
	var direction := Vector3(to.x - from.x, 0, to.y - from.y).normalized()
	mesh.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction)), Vector3(mid.x, y, mid.y))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh)
