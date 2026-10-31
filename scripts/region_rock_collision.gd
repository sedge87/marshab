extends Node3D

## Collision for a region's scattered rocks (original_mars_environment.gd).
## Terrain3D's instancer draws them but gives them no collision, and tens of
## thousands of colliders would be wasteful: instead a small pool of spheres
## follows whoever is moving (the player, the crew rover and GAR-Y), so the
## big rocks near them are solid. Small stones stay walk-over.

const CELL := 32.0          # metres per grid cell for finding nearby rocks
const REACH := 30.0         # rocks within this of someone are solid
const POOL := 140           # most colliders at once
const REFRESH := .25        # seconds between updates

var _grid: Dictionary = {}  # Vector2i -> Array of Vector4(x, y, z, radius)
var _bodies: Array[StaticBody3D] = []
var _shapes: Array[SphereShape3D] = []
var _timer := 0.0

## rocks: Array of Vector4(x, centre y, z, radius), world space.
func setup(rocks: Array) -> void:
	name = "RegionRockCollision"
	add_to_group("region_rocks")
	for rock in rocks:
		var key := Vector2i(floori(rock.x / CELL), floori(rock.z / CELL))
		if not _grid.has(key): _grid[key] = []
		(_grid[key] as Array).append(rock)
	for index in POOL:
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 0
		var shape := SphereShape3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		_bodies.append(body)
		_shapes.append(shape)

## Every rock in an area (for planning the rover's way home).
func rocks_in(area: Rect2) -> Array:
	var found: Array = []
	for gx in range(floori(area.position.x / CELL), floori(area.end.x / CELL) + 1):
		for gz in range(floori(area.position.y / CELL), floori(area.end.y / CELL) + 1):
			found.append_array(_grid.get(Vector2i(gx, gz), []))
	return found

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0: return
	_timer = REFRESH
	var centres: Array = []
	for group in ["player", "crew_rover", "gar_y"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D and (node as Node3D).is_inside_tree(): centres.append((node as Node3D).global_position)
	var near: Array = []
	var seen := {}
	for centre in centres:
		var low := Vector2i(floori((centre.x - REACH) / CELL), floori((centre.z - REACH) / CELL))
		var high := Vector2i(floori((centre.x + REACH) / CELL), floori((centre.z + REACH) / CELL))
		for gx in range(low.x, high.x + 1):
			for gz in range(low.y, high.y + 1):
				for rock in _grid.get(Vector2i(gx, gz), []):
					if seen.has(rock): continue
					var d := Vector2(rock.x - centre.x, rock.z - centre.z).length()
					if d < REACH:
						seen[rock] = true
						near.append([d, rock])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for index in POOL:
		var body := _bodies[index]
		if index < near.size():
			var rock: Vector4 = near[index][1]
			_shapes[index].radius = rock.w
			body.position = Vector3(rock.x, rock.y, rock.z)
			body.collision_layer = 1
		elif body.collision_layer != 0:
			body.collision_layer = 0
