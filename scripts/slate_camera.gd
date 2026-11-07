extends Node

## The slate's camera (step 3b; the Camera app in scripts/pda_screen.gd):
## raise the slate, open Camera, and its screen is a viewfinder on what's in
## front of you; the mouse still looks round. E, Space or a click takes the
## picture: a shutter and a white flash, and the photo goes into the journal
## (MHJournal.add_photo) in colour, with an automatic caption you can change
## in the book. What was in frame and close by is kept with it as its
## subjects, so later steps can tell what you photographed (3c: the walker's
## tracks).

const PHOTO_SIZE := Vector2i(960, 540)
const VIEW_SIZE := Vector2i(640, 360)
const SUBJECT_REACH := 60.0
const SLATE_LAYER := 1 << 19      # scripts/pda.gd LAYER: the slate keeps out of its own pictures
const PHOTOS_PER_SOL := 6

var world: Node
var _view: SubViewport
var _eye_copy: Camera3D
var _busy := false

func setup(target_world: Node) -> Node:
	world = target_world
	name = "SlateCamera"
	add_to_group("slate_camera")
	return self

func _eye() -> Camera3D:
	return world.player.get_node_or_null("Head/Camera3D") as Camera3D

func _sol() -> int:
	return floori(float(world.builder.simulation().hours_run) / 24.0) + 1

# ---------- the viewfinder ----------

## A live picture of the view for the Camera page; it follows your eyes.
func viewfinder() -> Texture2D:
	if _view == null:
		_view = SubViewport.new()
		_view.size = VIEW_SIZE
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_eye_copy = Camera3D.new()
		_eye_copy.cull_mask = 0xFFFFF & ~SLATE_LAYER
		_view.add_child(_eye_copy)
		add_child(_view)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return _view.get_texture()

func stop_viewfinder() -> void:
	if _view != null: _view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	if _eye_copy == null or _view.render_target_update_mode == SubViewport.UPDATE_DISABLED: return
	var eye := _eye()
	if eye == null: return
	_eye_copy.fov = eye.fov
	_eye_copy.far = eye.far
	_eye_copy.global_transform = eye.global_transform
	_eye_copy.current = true

# ---------- what's in the picture ----------

## [{id, name, at}] for each thing worth naming in front of you and close.
func subjects() -> Array:
	var eye := _eye()
	if eye == null: return []
	var out: Array = []
	var candidates: Array = []
	for site in get_tree().get_nodes_in_group("thread_site"):
		candidates.append([site.id(), str(site.NAMES.get(site.kind, "Find")), (site as Node3D).global_position + Vector3(0, .6, 0)])
	for site in get_tree().get_nodes_in_group("storm_drop_site"):
		candidates.append([site.id(), str(site.NAMES.get(site.kind, site.label())), site.pallet_spot() + Vector3(0, .6, 0) if site.has_method("pallet_spot") else (site as Node3D).global_position])
	var gary: Node3D = world.get("scout_rover")
	if gary != null and is_instance_valid(gary): candidates.append(["gary", "GAR-Y", gary.global_position + Vector3(0, .4, 0)])
	for node in get_tree().get_nodes_in_group("photo_subject"):
		candidates.append([str(node.get_meta("photo_id", node.name)), str(node.get_meta("photo_name", node.name)), (node as Node3D).global_position])
	for c in candidates:
		var at: Vector3 = c[2]
		if eye.global_position.distance_to(at) > SUBJECT_REACH or not eye.is_position_in_frustum(at): continue
		out.append({"id": str(c[0]), "name": str(c[1]), "at": at})
	out.sort_custom(func(a, b): return eye.global_position.distance_to(a.at) < eye.global_position.distance_to(b.at))
	return out

## "Sol 2 · Ice wall · 1.1 km north-west"
func caption(found: Array) -> String:
	var you: Vector3 = world.player.global_position
	var lander: Node3D = world.lander
	if lander != null and lander.cabin_contains(you): return "Sol %d · In the lander" % _sol()
	var what := str(found[0].name) if not found.is_empty() else "Out on the plain"
	if lander == null: return "Sol %d · %s" % [_sol(), what]
	var offset := you - lander.global_position
	var metres := Vector2(offset.x, offset.z).length()
	var far := "%d m" % (roundi(metres / 10.0) * 10) if metres < 1000.0 else "%.1f km" % (metres / 1000.0)
	if metres < 30.0: return "Sol %d · %s · by the lander" % [_sol(), what]
	return "Sol %d · %s · %s %s" % [_sol(), what, far, preload("res://scripts/storm_drop.gd").direction_word(offset)]

# ---------- taking it ----------

func can_take() -> bool:
	return not _busy and MHJournal.photos_on(_sol()) < PHOTOS_PER_SOL

## The shutter: render once from your eyes without the slate, save it, put it
## in the journal. Returns the photo's record (or {} if the page is full).
func take() -> Dictionary:
	if not can_take(): return {}
	_busy = true
	var found := subjects()
	var words := caption(found)
	var sol := _sol()
	MHAudio.sfx("ui_click", -2.0, 0.0)
	_flash()
	var eye := _eye()
	var view := SubViewport.new()
	view.size = PHOTO_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.cull_mask = 0xFFFFF & ~SLATE_LAYER
	view.add_child(camera)
	add_child(view)
	if eye != null:
		camera.fov = eye.fov
		camera.far = eye.far
		camera.global_transform = eye.global_transform
	camera.current = true
	var image: Image = null
	if DisplayServer.get_name() != "headless":   # headless: nothing is drawn, so no picture
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		image = view.get_texture().get_image() if view.get_texture() != null else null
	view.queue_free()
	var path := ""
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(MHJournal.folder())
		path = MHJournal.folder() + "photo_%03d_%d.png" % [sol, MHJournal.photos_on(sol)]
		if image.save_png(path) != OK: path = ""
	var record := MHJournal.add_photo(sol, path, words, found.map(func(s): return str(s.id)))
	_busy = false
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("photo")
	MHNotices.post("info", "Photo", words + " · in the journal (J).", "log")
	return record

## A white flash across the screen.
func _flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, .85)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(white)
	add_child(layer)
	var tween := white.create_tween()
	tween.tween_property(white, "color:a", 0.0, .35)
	tween.tween_callback(layer.queue_free)
