extends Node

## The journal in the world (docs/samples-lab-journal.md §7): J opens the
## book anywhere except mid-EVA ("You can't write in the suit"), and E on a
## crew bunk opens it too (the notebook on its shelf). When MHJournal asks for
## a sketch, it waits for a quiet moment outside (standing, nothing open) and
## renders the view once from your eyes, without the HUD, at 480 × 270.

const BOOK := preload("res://scripts/journal_book.gd")
const SKETCH_SIZE := Vector2i(480, 270)

var world: Node
var _sketching := false
var _check := 0.0

func setup(target_world: Node) -> Node:
	world = target_world
	return self

func _ready() -> void:
	add_to_group("interaction_claims")

func _sol() -> int:
	return floori(float(world.builder.simulation().hours_run) / 24.0) + 1

func _outside() -> bool:
	var player: Node3D = world.player
	return not world.builder.is_inside(player.global_position) and not bool(world.lander.cabin_contains(player.global_position))

func _unhandled_input(event: InputEvent) -> void:
	if not MHJournal.on() or not (event is InputEventKey and event.pressed and not event.echo) or (event as InputEventKey).keycode != KEY_J: return
	if world.get("monitor") != null or world.get("pause_menu") != null or bool(world.player.get_meta("build_mode_active", false)): return
	get_viewport().set_input_as_handled()
	if _outside() and not bool(world.player.get_meta("driving", false)):
		world.call("show_chapter_messages", [{"id": "journal", "title": "You can't write in the suit", "text": "The journal's inside: J there, or the notebook by your bunk.", "tone": "info"}])
		return
	open_book()

func open_book() -> void:
	world.call("_open_live_view", BOOK.new())

# ---------- the notebook by the bunk ----------

func _equipment_id(target: Node) -> String:
	var node := target
	while node != null:
		if node.has_meta("equipment_id"): return str(node.get_meta("equipment_id"))
		node = node.get_parent()
	return str(target.get("equipment_id")) if target != null else ""

func claim_label(target: Node) -> String:
	if not MHJournal.on() or target == null: return ""
	return "Read the journal" if _equipment_id(target) == "crew_bunk" else ""

func claim(target: Node, method_name: String) -> bool:
	if method_name != "interact" or claim_label(target).is_empty(): return false
	open_book()
	return true

# ---------- sketches ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _sketching or not MHJournal.on() or MHJournal.wants_sketch.is_empty(): return
	_check = .5
	if world.get("monitor") != null or get_tree().paused or not _outside(): return
	var player: CharacterBody3D = world.player
	if player.velocity.length() > .5: return   # a quiet moment: standing still
	if MHJournal.sketches_on(_sol()) >= MHJournal.SKETCHES_PER_SOL:
		MHJournal.wants_sketch = ""
		return
	_sketch(MHJournal.wants_sketch)

## Render the view once from the player's eyes into a small picture, and save it.
func _sketch(caption: String) -> void:
	_sketching = true
	MHJournal.wants_sketch = ""
	var eye := world.player.get_node("Head/Camera3D") as Camera3D
	var view := SubViewport.new()
	view.size = SKETCH_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.fov = eye.fov
	camera.far = eye.far
	view.add_child(camera)
	add_child(view)
	camera.global_transform = eye.global_transform
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image() if view.get_texture() != null else null
	view.queue_free()
	_sketching = false
	if image == null or image.is_empty(): return   # headless: nothing drawn
	DirAccess.make_dir_recursive_absolute(MHJournal.folder())
	var sol := _sol()
	var path := MHJournal.folder() + "sol_%03d_%d.png" % [sol, MHJournal.sketches_on(sol)]
	if image.save_png(path) == OK: MHJournal.add_sketch(sol, path, caption)
