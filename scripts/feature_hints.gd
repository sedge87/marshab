extends Node

## First-time hint cards (docs/tutorial-design.md, part 2): the first time a
## player opens a feature (the site plan, furnishing, carrying, the rover,
## Mission Control, shielding, a first alert), a small card shows how it's
## done: a looping clip of the real game (assets/tutorial/clips), the keys,
## and a link to the Field guide card for the why. Once per player, ever (not
## per save), and never with the tutorial set to Off or hint cards switched
## off. The game pauses while it's open; Enter, E, Esc or "Got it" closes it.
const HINTS_PATH := "res://data/feature_hints.json"
const HOW_IT_WORKS := preload("res://scripts/how_it_works.gd")
const GUIDE := preload("res://scripts/guide_overlay.gd")

static var _hints: Dictionary = {}

static func hints() -> Dictionary:
	if _hints.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(HINTS_PATH))
		if parsed is Dictionary: _hints = (parsed as Dictionary).get("hints", {})
	return _hints

## Show this feature's hint, if it has one and it hasn't been seen.
static func first(tree: SceneTree, id: String) -> void:
	if tree == null or not hints().has(id) or HOW_IT_WORKS.seen("hint_" + id) or not HOW_IT_WORKS.enabled(): return
	HOW_IT_WORKS.mark_seen(["hint_" + id])
	# One at a time: a second waits for the first to close.
	for node in tree.get_nodes_in_group("feature_hint"):
		(node as Node).set_meta("next", ((node as Node).get_meta("next", []) as Array) + [id])
		return
	var card: Node = load("res://scripts/feature_hints.gd").new()
	card.id = id
	tree.root.add_child(card)

var id := ""
var _was_paused := false
var _mouse := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	add_to_group("feature_hint")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hint: Dictionary = hints().get(id, {})
	var layer := CanvasLayer.new()
	layer.layer = 46
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = MHStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, .55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := MHStyle.hud_panel(22, false, true)
	centre.add_child(panel)
	var column := MHStyle.vbox(12)
	column.custom_minimum_size.x = 760
	panel.add_child(column)
	column.add_child(MHStyle.eyebrow("New · %s" % MHGame.habitat_name, MHStyle.accent, 12))
	column.add_child(MHStyle.title(str(hint.get("title", "")), 26))
	var clip := str(hint.get("clip", ""))
	if GUIDE.has_clip(clip):
		var player := VideoStreamPlayer.new()
		player.stream = load(GUIDE.CLIP_DIR + clip + ".ogv")
		player.custom_minimum_size = Vector2(760, 428)
		player.expand = true
		player.loop = true
		player.autoplay = true
		column.add_child(player)
	var text := MHStyle.body(str(hint.get("text", "")).replace("ARDEN", MHGame.habitat_name), 17, MHStyle.TEXT_PRIMARY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 760
	column.add_child(text)
	var keys: Array = hint.get("keys", [])
	var foot := MHStyle.hbox(16)
	if not keys.is_empty():
		var halves := MHStyle.hbox(24)
		var half := ceili(keys.size() / 2.0)
		halves.add_child(GUIDE.keys_box(keys.slice(0, half)))
		if keys.size() > half: halves.add_child(GUIDE.keys_box(keys.slice(half)))
		foot.add_child(halves)
	foot.add_child(MHStyle.spacer())
	var buttons := MHStyle.vbox(8)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	var guide_card := str(hint.get("guide", ""))
	if not guide_card.is_empty():
		var more := MHStyle.button("Field guide", "ghost", "book-open")
		more.pressed.connect(func() -> void:
			_close()
			HOW_IT_WORKS.show(get_tree(), [guide_card], "Field guide"))
		buttons.add_child(more)
	var ok := MHStyle.button("Got it", "primary", "check")
	ok.pressed.connect(_close)
	buttons.add_child(ok)
	foot.add_child(buttons)
	column.add_child(foot)
	MHAudio.sfx("ui_open", -6.0)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_E]:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if is_queued_for_deletion(): return
	var next: Array = get_meta("next", [])
	queue_free()
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse
	MHAudio.sfx("ui_close", -6.0)
	if not next.is_empty():
		var card: Node = load("res://scripts/feature_hints.gd").new()
		card.id = str(next[0])
		card.set_meta("next", next.slice(1))
		get_tree().root.add_child.call_deferred(card)
