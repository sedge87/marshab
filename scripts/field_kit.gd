extends Node

## The field kit's four slots (opening slice, docs/opening-slice.md §4a
## Scene 3): what's in your hand is what you chose, with 1–4, never guessed
## from what you're looking at. 1 the hand corer, 2 the rock hammer, 3 the
## sample scoop, 4 the survey stakes (chunk 2). The same key again puts it
## away. Only a version 3 game gates the tools; older games keep working the
## tool by context (holding() is always true there).
##
## What's in your hand shows in your hand, low on the right: the corer is the
## MC-01 model, the others stand-ins until their models arrive.

const MC01 := "res://assets/models/field/mc01_corer.glb"
const MHPalette := preload("res://scripts/mh_palette.gd")
const SLOTS := [
	["corer", "Hand corer"],
	["hammer", "Rock hammer"],
	["scoop", "Sample scoop"],
	["stakes", "Survey stakes"],
]
const HELD_AT := Vector3(.32, -.34, -.62)

var world: Node
var held := ""
var _model: Node3D
var _check := 0.0

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "FieldKit"
	add_to_group("field_kit")
	held = str(saved.get("held", ""))
	if not has(held): held = ""
	_show.call_deferred()

func export_state() -> Dictionary:
	return {"held": held}

static func gates(target_world: Node) -> bool:
	return target_world != null and int(target_world.get("opening_version")) >= 3

## A tool may work now: it's in your hand (or this game doesn't gate tools).
static func holding_in(target_world: Node, id: String) -> bool:
	if not gates(target_world): return true
	var kit: Node = target_world.get_tree().get_first_node_in_group("field_kit")
	return kit == null or str(kit.held) == id

## You've got this tool (it's in the kit, whether in hand or not).
func has(id: String) -> bool:
	match id:
		"corer", "scoop": return MHChapterOne.has_corer
		"hammer": return MHChapterOne.has_hammer
		"stakes": return false   # the survey line comes with chunk 2
	return false

func label(id: String) -> String:
	for slot in SLOTS:
		if str(slot[0]) == id: return str(slot[1])
	return ""

## Each slot as the slate's Kit page shows it: [key, id, label, have, in hand].
func slots() -> Array:
	var out := []
	for i in SLOTS.size():
		var id := str(SLOTS[i][0])
		out.append([i + 1, id, str(SLOTS[i][1]), has(id), held == id])
	return out

func select(index: int) -> void:
	if index < 0 or index >= SLOTS.size(): return
	var id := str(SLOTS[index][0])
	var hud: Node = world.get("explore_hud")
	if not has(id):
		MHAudio.sfx("invalid", -8.0)
		if hud != null: hud.show_equipment_note("Kit", "Slot %d is empty." % (index + 1))
		return
	held = "" if held == id else id
	MHAudio.sfx("suit_clamp", -10.0)
	_show()
	if hud != null:
		if held.is_empty(): hud.hide_equipment_note("In hand")
		else: hud.show_equipment_note("In hand: " + label(held), "%d again puts it away." % (index + 1))

func _unhandled_input(event: InputEvent) -> void:
	if not gates(world) or not (event is InputEventKey) or not event.pressed or event.echo: return
	var key := (event as InputEventKey).keycode
	if key < KEY_1 or key > KEY_4 or (event as InputEventKey).ctrl_pressed: return
	var player: Node = world.get("player")
	if player == null or bool(player.get_meta("ui_freeze", false)) or bool(player.get_meta("driving", false)) or player._any_build_mode_active(): return
	var pda: Node = world.get("pda")
	if pda != null and bool(pda.get("is_open")): return
	select(key - KEY_1)
	get_viewport().set_input_as_handled()

# ---------- in your hand ----------

func _show() -> void:
	if _model != null and is_instance_valid(_model): _model.queue_free()
	_model = null
	if held.is_empty() or world.get("player") == null: return
	var camera := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return
	match held:
		"corer":
			var scene: PackedScene = load(MC01) if ResourceLoader.exists(MC01) else null
			if scene != null:
				_model = scene.instantiate() as Node3D
				_model.scale = Vector3.ONE * .45
				_model.rotation_degrees = Vector3(-8, 20, -12)
		"hammer": _model = _stand_in([[Vector3(.04, .04, .36), Vector3(0, 0, .1), "dark_alloy"], [Vector3(.12, .05, .05), Vector3(0, 0, -.08), "graphite"]])
		"scoop": _model = _stand_in([[Vector3(.03, .03, .3), Vector3(0, 0, .1), "dark_alloy"], [Vector3(.1, .03, .12), Vector3(0, 0, -.1), "white_painted"]])
		"stakes": _model = _stand_in([[Vector3(.02, .3, .02), Vector3.ZERO, "orange"]])
	if _model == null: return
	_model.name = "InHand"
	camera.add_child(_model)
	_model.position = HELD_AT
	for mesh in _model.find_children("*", "MeshInstance3D", true, false): (mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _stand_in(parts: Array) -> Node3D:
	var root := Node3D.new()
	for part in parts:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		var source := StandardMaterial3D.new()
		source.resource_name = str(part[2])
		mesh.material_override = MHPalette.material(source)
		mesh.position = part[1]
		root.add_child(mesh)
	root.rotation_degrees = Vector3(-20, 15, 0)
	return root

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _model == null or not is_instance_valid(_model): return
	_check = .2
	# Out of sight while your hands are full or the corer's planted.
	var player: Node = world.get("player")
	var carry: Node = get_tree().get_first_node_in_group("carry")
	var busy: bool = (carry != null and not (carry.carrying as Dictionary).is_empty()) or float(player.get_meta("load_speed", 1.0)) < 1.0
	var corer: Node = world.get("hand_corer")
	if corer != null and not str(corer.get("stage")).is_empty(): busy = true
	_model.visible = not busy and not bool(player.get_meta("riding", false))
