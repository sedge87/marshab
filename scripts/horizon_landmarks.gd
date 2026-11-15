extends Node3D

## Far horizon landmarks (B5, docs/terrain-design.md §14): a volcano and a
## great crater's rim beyond the edge of the region, so the skyline isn't the
## same all the way round and you can steer by it. They come from region.json
## "horizon" ({id, kind, bearing (degrees clockwise from north), distance,
## height, width}, all metres), set in data/region_layout.json.
##
## They're tens of kilometres off, further than any camera draws, so each is
## drawn at DRAW_AT metres, scaled down to look the same size, and follows the
## camera sideways like a backdrop (no parallax, as at that distance). The fog
## lights them, so they read as pale silhouettes.

const DRAW_AT := 1700.0          # inside the rover camera's 2 km far plane
const SINK := .25                # the curve of the planet hides the foot of each
const COLOUR := Color("#B08868")

var _base_y := 0.0

func build(meta: Dictionary, ground_y := 0.0) -> void:
	name = "HorizonLandmarks"
	_base_y = ground_y
	for item in meta.get("horizon", []):
		var mark := _landmark(item)
		if mark != null: add_child(mark)

func _landmark(item: Dictionary) -> Node3D:
	var distance := maxf(float(item.get("distance", 20000.0)), DRAW_AT)
	var k := DRAW_AT / distance
	var height := float(item.get("height", 1000.0)) * k
	var width := float(item.get("width", 10000.0)) * k
	var bearing := deg_to_rad(float(item.get("bearing", 0.0)))
	var direction := Vector3(sin(bearing), 0.0, -cos(bearing))   # north is -Z
	var mesh := MeshInstance3D.new()
	mesh.name = str(item.get("id", "landmark"))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match str(item.get("kind", "")):
		"volcano":   # a broad shield: gentle flanks, a flat summit with its caldera
			var cone := CylinderMesh.new()
			cone.bottom_radius = width * .5
			cone.top_radius = width * .04
			cone.height = height
			cone.radial_segments = 28
			cone.rings = 1
			mesh.mesh = cone
			mesh.position = direction * DRAW_AT + Vector3(0, height * (.5 - SINK), 0)
		"crater_rim":   # a long low wall across the skyline, side on
			var rim := PrismMesh.new()
			rim.size = Vector3(width, height, height * 6.0)
			mesh.mesh = rim
			mesh.position = direction * DRAW_AT + Vector3(0, height * (.5 - SINK), 0)
			mesh.rotation.y = atan2(direction.x, direction.z)
		_:
			return null
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOUR
	material.roughness = 1.0
	mesh.material_override = material
	return mesh

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	global_position = Vector3(camera.global_position.x, _base_y, camera.global_position.z)
