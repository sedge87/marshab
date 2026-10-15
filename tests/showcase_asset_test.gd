extends SceneTree

const WALL := preload("res://assets/showcase_modules/mh_wall_bay.glb")
const CORNER := preload("res://assets/showcase_modules/mh_corner_post.glb")
const AIRLOCK := preload("res://assets/showcase_modules/mh_airlock_surround.glb")
const CORRIDOR := preload("res://assets/showcase_modules/mh_corridor_bay.glb")
const SOLAR := preload("res://assets/showcase_modules/mh_solar_array.glb")

func _bounds(scene: PackedScene) -> AABB:
	var root := Node3D.new()
	get_root().add_child(root)
	var instance := scene.instantiate()
	root.add_child(instance)
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		# These exports have one mesh below a zero-origin scene root.
		var box := mesh.get_aabb()
		box.position += mesh.position
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	root.queue_free()
	return result

func _init() -> void:
	var wall := _bounds(WALL)
	var corner := _bounds(CORNER)
	var airlock := _bounds(AIRLOCK)
	var corridor := _bounds(CORRIDOR)
	var solar := _bounds(SOLAR)
	assert(wall.size.x > 2.8 and wall.size.y > 2.7 and wall.position.y > -.1, "Wall asset must use a 3m bay with its base at origin: %s" % wall)
	assert(corner.size.x < .6 and corner.size.y > 2.7 and corner.position.y > -.1, "Corner asset must be compact and base-aligned.")
	assert(airlock.size.x > 2.8 and airlock.size.y > 2.7 and airlock.position.y > -.1, "Airlock surround must be base-aligned.")
	assert(corridor.size.z > 2.8 and corridor.size.y > 2.7 and corridor.position.y > -.1, "Corridor bay must be base-aligned.")
	assert(solar.size.x > 2.5 and solar.size.y > 1.3 and absf(solar.position.y) < .11, "Solar array must be ground-aligned and wide enough to read as exterior equipment.")
	print("Showcase Blender assets passed origin and dimensions checks.")
	quit(0)
