extends Node

## Renders each catalogue item's real model into a small picture for the
## build bar, one item per frame, in its own hidden world. Pictures are cached
## in memory and saved to user://thumbnails, so each is only rendered once.
## Use: ModelThumbnails.request(tree, id, callback) - the callback receives a
## Texture2D (straight away if cached).
const SIZE := Vector2i(256, 168)
const DIRECTORY := "user://thumbnails"
const VERSION := 5   # bump to re-render every thumbnail

static var _cache := {}
static var _baker: Node

static func request(tree: SceneTree, id: String, callback: Callable) -> void:
	if _cache.has(id):
		callback.call(_cache[id])
		return
	var path := "%s/%s_v%d.png" % [DIRECTORY, id, VERSION]
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null:
			_cache[id] = ImageTexture.create_from_image(image)
			callback.call(_cache[id])
			return
	if _baker == null or not is_instance_valid(_baker):
		_baker = load("res://scripts/model_thumbnails.gd").new()
		_baker.name = "ModelThumbnails"
		_baker.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_baker)
	_baker._enqueue(id, callback)

# ---------- the baker (one per game) ----------

var _queue: Array = []        # [{id, callbacks}]
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _busy := false

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#C9D3D6")
	environment.environment.ambient_light_energy = .45
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -35, 0)
	key.light_energy = 1.7
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = .45
	_viewport.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)

func _enqueue(id: String, callback: Callable) -> void:
	for job in _queue:
		if job.id == id:
			job.callbacks.append(callback)
			return
	_queue.append({"id": id, "callbacks": [callback]})
	if not _busy: _bake_next()

func _bake_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var job: Dictionary = _queue.pop_front()
	var texture := await _bake(str(job.id))
	_cache[job.id] = texture
	for callback in job.callbacks:
		if callback.is_valid(): callback.call(texture)
	_bake_next()

func _bake(id: String) -> Texture2D:
	for child in _stage.get_children(): child.free()
	var model := instantiate_model(id)
	if model == null: return null
	_stage.add_child(model)
	frame_camera(_camera, model, Vector3(.9, .55, -1.0))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	image.save_png(ProjectSettings.globalize_path("%s/%s_v%d.png" % [DIRECTORY, id, VERSION]))
	model.queue_free()
	return ImageTexture.create_from_image(image)

## The item's model scene (without its interaction behaviour running).
static func instantiate_model(id: String) -> Node3D:
	var path := str(EquipmentCatalog.get_entry(id).get("asset_scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var scene := load(path) as PackedScene
	if scene == null: return null
	var model := scene.instantiate() as Node3D
	# A display copy: no rig behaviour, lights or interaction.
	model.set_script(null)
	return model

## Point a camera at a model from a three-quarter front view (its front faces -Z).
static func frame_camera(camera: Camera3D, model: Node3D, direction: Vector3) -> void:
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		var part: AABB = m.transform * m.get_aabb()
		var node: Node = m.get_parent()
		while node != null and node != model and node is Node3D:
			part = (node as Node3D).transform * part
			node = node.get_parent()
		box = part if first else box.merge(part)
		first = false
	box = model.transform * box
	var centre := box.get_center()
	var radius := maxf(.2, box.size.length() * .5)
	var distance := radius / tan(deg_to_rad(camera.fov * .5)) * 1.05
	camera.position = centre + direction.normalized() * distance
	camera.look_at(centre, Vector3.UP)
	camera.near = .02
	camera.far = distance * 4.0
