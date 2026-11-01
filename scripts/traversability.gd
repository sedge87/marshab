extends MeshInstance3D

## Rover ground (debug panel): the ground round you coloured by whether the
## crew rover can drive it, from the real heights and rocks and the rover's
## own limits (scripts/rover_route.gd): green is full speed, yellow is slow
## going (steeper than GENTLE, or sand), red is what the route planner
## avoids (steeper than STEEP, a cliff, or a rock too big to drive over).
## Region sites only. The region map (Tab) shows the same over the region.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const ROUTE := preload("res://scripts/rover_route.gd")
const RADIUS := 120.0       # metres round you
const CELL := 2.0
const REDRAW_AFTER := 25.0  # metres moved
const FOOTPRINT := 2.0      # the rover's half-length: slopes are measured across it

## While on, the region map draws its own layer too.
static var on := false
static var _map_layer: ImageTexture

var world: Node
var _drawn_at := Vector3(INF, 0, INF)

func setup(target_world: Node) -> void:
	world = target_world
	name = "RoverGround"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material

func _process(_delta: float) -> void:
	var player: Node3D = world.player
	var at := player.global_position
	if Vector2(at.x - _drawn_at.x, at.z - _drawn_at.z).length() < REDRAW_AFTER: return
	_drawn_at = at
	_redraw(Vector2(roundf(at.x / CELL) * CELL, roundf(at.z / CELL) * CELL))

## 0 green, 1 yellow, 2 red, for the ground at (x, z) in site metres.
static func grade_class(x: float, z: float, sand: bool) -> int:
	var e := FOOTPRINT
	var grade := maxf(absf(MHSiteTerrain.height(x + e, z) - MHSiteTerrain.height(x - e, z)), absf(MHSiteTerrain.height(x, z + e) - MHSiteTerrain.height(x, z - e))) / (2.0 * e)
	if grade > ROUTE.STEEP: return 2
	if grade > ROUTE.GENTLE or sand: return 1
	return 0

const COLOURS := [Color(.2, .85, .3, .35), Color(.95, .8, .15, .45), Color(.95, .2, .15, .5)]

func _redraw(centre: Vector2) -> void:
	var area := Rect2(centre - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)
	var big_rocks := {}
	var field := get_tree().get_first_node_in_group("region_rocks")
	if field != null:
		for rock in field.rocks_in(area):
			if (rock as Vector4).w < ROUTE.BIG_ROCK: continue
			big_rocks[Vector2i(roundi(rock.x / CELL), roundi(rock.z / CELL))] = true
	var cells := int(RADIUS * 2.0 / CELL)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for gz in cells:
		for gx in cells:
			var x := area.position.x + gx * CELL
			var z := area.position.y + gz * CELL
			if Vector2(x, z).distance_to(centre) > RADIUS: continue
			var sand := MHSiteTerrain.geology_unit(x, z) == "dune_sand"
			var kind := 2 if big_rocks.has(Vector2i(roundi(x / CELL), roundi(z / CELL))) else grade_class(x, z, sand)
			surface.set_color(COLOURS[kind])
			var corners := [Vector2(x, z), Vector2(x + CELL, z), Vector2(x + CELL, z + CELL), Vector2(x, z + CELL)]
			var up: Array[Vector3] = []
			for c in corners: up.append(Vector3(c.x, MHSiteTerrain.height(c.x, c.y) + .25, c.y))
			for i in [0, 1, 2, 0, 2, 3]: surface.add_vertex(up[i])
	mesh = surface.commit()

## The same over the whole region, for the region map: an image `pixels`
## across (region coordinates), made once.
static func map_layer(pixels := 256) -> ImageTexture:
	if _map_layer != null: return _map_layer
	var RT := MHSiteTerrain.RegionTerrain
	var half := float(RT.meta().get("half", 3072.0))
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	var image := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	var step := half * 2.0 / pixels
	for py in pixels:
		for px in pixels:
			var rx := -half + (px + .5) * step
			var rz := -half + (py + .5) * step
			var kind := grade_class(rx - origin.x, rz - origin.y, RT.geology(rx, rz) == "dune_sand")
			var colour: Color = COLOURS[kind]
			colour.a = .55
			image.set_pixel(px, py, colour)
	_map_layer = ImageTexture.create_from_image(image)
	return _map_layer
