extends SubViewportContainer

## A live, slowly turning 3D view of one catalogue item (the build bar's
## details panel). Call show_item(id).
const ModelThumbnails := preload("res://scripts/model_thumbnails.gd")

var _viewport: SubViewport
var _turntable: Node3D
var _camera: Camera3D
var _id := ""

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#C9D3D6")
	environment.environment.ambient_light_energy = .7
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -35, 0)
	key.light_energy = 1.7
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_energy = .6
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	# A soft light from the viewer's side, so the turning model is never dark.
	var front := DirectionalLight3D.new()
	front.light_energy = .7
	_camera.add_child(front)
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)

func show_item(id: String) -> void:
	if id == _id: return
	_id = id
	for child in _turntable.get_children(): child.queue_free()
	_turntable.rotation = Vector3.ZERO
	var model: Node3D = ModelThumbnails.instantiate_model(id)
	if model == null: return
	_turntable.add_child(model)
	ModelThumbnails.frame_camera(_camera, model, Vector3(.9, .5, -1.0))
	# Turn about the model's own centre.
	var centre := _model_centre(model)
	model.position -= Vector3(centre.x, 0, centre.z)
	ModelThumbnails.frame_camera(_camera, model, Vector3(.9, .5, -1.0))

func _model_centre(model: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		var part: AABB = m.global_transform * m.get_aabb() if m.is_inside_tree() else m.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box.get_center()

func _process(delta: float) -> void:
	if visible and _turntable != null: _turntable.rotate_y(delta * .45)
