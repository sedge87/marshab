extends Node3D

## The fabricator, the Print Shop (docs/start-and-chapter-one.md §4): a
## bench-sized machine with a build chamber behind a window, a feed hopper
## and a small working display. E opens its screen (fabricator_screen.gd).
##
## Chunk 3 (24 Nov, docs/assets-chunk3-review.md): the model is the chunk 3
## printer (assets/models/chunk3/print_shop_printer.glb, 1.58 x 1.46 x 0.60 m).
## While it prints, the chamber lamp is lit and the head works across the
## plate. A hand-sized part (MHChapterOne.HAND) comes out in the output
## drawer: the drawer slides open with the part on its mat, and E takes it.
## Iron-rich rock in the store goes in through the hopper by hand (E), at
## the smelter's yield. Older models, then boxes, stand in if it's missing.

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk3/print_shop_printer.glb"
const OLD_MODEL := "res://assets/equipment/mars_chapter_one_v1/models/fabricator.glb"
const CONNECTOR := "res://assets/models/chunk3/beacon_connector.glb"
const DRAWER_TRAVEL := .304      # the drawer slides out along -Z (the model's front)
const HEAD_HOME := -.315
const HEAD_SPAN := .235
const GANTRY_HOME := .629
const GANTRY_RISE := .109

var _drawer: Node3D
var _gantry: Node3D
var _head: Node3D
var _hopper_lid: Node3D
var _output: Node3D
var _lamp_material: StandardMaterial3D
var _light: OmniLight3D
var _shown_part := ""
var _part_node: Node3D
var _drawer_open := 0.0
var _t := 0.0

func _ready() -> void:
	var path := MODEL if ResourceLoader.exists(MODEL) else OLD_MODEL
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		add_child(model)
		if path == MODEL: _rig(model)
		return
	_box("Body", Vector3(1.4, .9, .8), Vector3(0, .45, 0), "shell")
	_box("Plinth", Vector3(1.44, .08, .84), Vector3(0, .04, 0), "graphite")
	_box("Chamber", Vector3(.86, .62, .62), Vector3(-.18, 1.21, 0), "shell")
	_box("Window", Vector3(.6, .44, .02), Vector3(-.18, 1.2, .315), "black_glass")
	_box("ChamberFrame", Vector3(.7, .54, .015), Vector3(-.18, 1.2, .305), "frame")
	_box("Hopper", Vector3(.34, .5, .4), Vector3(.48, 1.15, -.08), "metal")
	_box("HopperLid", Vector3(.38, .05, .44), Vector3(.48, 1.42, -.08), "orange")
	_box("Gasket", Vector3(1.42, .03, .82), Vector3(0, .9, 0), "rubber")
	_box("Drawer", Vector3(.9, .26, .02), Vector3(-.18, .5, .405), "graphite")
	var screen := _box("Screen", Vector3(.3, .2, .02), Vector3(.48, .72, .41), "screen")
	var glow := StandardMaterial3D.new()
	glow.resource_name = "screen_glow"
	glow.albedo_color = Color("#0C1316")
	glow.emission_enabled = true
	glow.emission = Color("#8CC3CB")
	glow.emission_energy_multiplier = .6
	screen.material_override = glow

## The chunk 3 model's moving parts (its PrintShopPrinterVisuals.gd.txt, here).
func _rig(model: Node3D) -> void:
	MHPalette.apply(model)
	_drawer = model.find_child("OutputDrawer", true, false) as Node3D
	_gantry = model.find_child("Gantry", true, false) as Node3D
	_head = _gantry.find_child("Head", true, false) as Node3D if _gantry != null else null
	_hopper_lid = model.find_child("HopperLid", true, false) as Node3D
	_output = model.find_child("OutputPoint", true, false) as Node3D
	var lamp := model.find_child("ChamberLamp", true, false) as MeshInstance3D
	if lamp != null and lamp.mesh != null:
		var base := lamp.get_active_material(0)
		_lamp_material = (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
		lamp.material_override = _lamp_material
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, .9, .73)
		_light.omni_range = .6
		_light.light_energy = 0.0
		lamp.add_child(_light)
		_light.position = Vector3(0, -.032, .036)
	# The model's screen: a soft glow, like the other screens (no baked text).
	var screen := model.find_child("Screen", true, false) as MeshInstance3D
	if screen != null:
		var glow := StandardMaterial3D.new()
		glow.resource_name = "display_screen_glow"
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("#0C1316")
		glow.emission_enabled = true
		glow.emission = Color("#8CC3CB")
		glow.emission_energy_multiplier = .6
		screen.material_override = glow
	_lit(false)

func _lit(on: bool) -> void:
	if _lamp_material != null:
		_lamp_material.emission_enabled = on
		_lamp_material.emission = Color(1.0, .9, .73)
		_lamp_material.emission_energy_multiplier = 2.1
	if _light != null: _light.light_energy = .54 if on else 0.0

func _process(delta: float) -> void:
	if _gantry == null: return
	_t += delta
	var here := placement()
	var printing := MHChapterOne.is_printing(here)
	_lit(printing)
	if printing and _head != null:
		_head.position.x = HEAD_HOME + HEAD_SPAN * sin(_t * 1.7)
		_gantry.position.y = GANTRY_HOME + GANTRY_RISE * (.5 + .5 * sin(_t * .23))
	# The drawer: out while a part waits in it.
	var part := str(MHChapterOne.tray.get(here, ""))
	_drawer_open = move_toward(_drawer_open, 1.0 if not part.is_empty() else 0.0, delta * 1.6)
	if _drawer != null: _drawer.position.z = -DRAWER_TRAVEL * _drawer_open
	if part != _shown_part: _show_part(part)

## The waiting part on the drawer's mat (it rides with the drawer).
func _show_part(part: String) -> void:
	_shown_part = part
	if _part_node != null and is_instance_valid(_part_node): _part_node.queue_free()
	_part_node = null
	if part.is_empty() or _output == null: return
	if part == "beacon_connector" and ResourceLoader.exists(CONNECTOR):
		_part_node = (load(CONNECTOR) as PackedScene).instantiate() as Node3D
		MHPalette.apply(_part_node)
		_output.add_child(_part_node)
		# The connector's pack places it on its side on this tray.
		_part_node.position = Vector3(-.018, .024, -.028)
		_part_node.rotation = Vector3(0, deg_to_rad(56.0), deg_to_rad(90.0))
		return
	# The sled's fittings: the antenna's electronics box and two skid shoes.
	_part_node = Node3D.new()
	_output.add_child(_part_node)
	_part_box(Vector3(.3, .12, .2), Vector3(0, .06, 0), "dark_alloy")
	_part_box(Vector3(.24, .03, .07), Vector3(-.2, .015, .1), "satin_steel")
	_part_box(Vector3(.24, .03, .07), Vector3(.2, .015, .1), "satin_steel")

func _part_box(size: Vector3, at: Vector3, role: String) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var source := StandardMaterial3D.new()
	source.resource_name = role
	mesh.mesh = box
	mesh.material_override = MHPalette.material(source)
	mesh.position = at
	_part_node.add_child(mesh)

func _box(node_name: String, size: Vector3, at: Vector3, role: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.resource_name = role
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
	return mesh

## Which Print Shop this is (its placement), for its own job and queue.
func placement() -> String:
	var node: Node = self
	while node != null:
		if node.has_meta("interior_placement_id"): return str(node.get_meta("interior_placement_id"))
		node = node.get_parent()
	return ""

## Iron-rich rock waits in the store and there's no Workshop smelter for it.
func _rock_for_hopper() -> bool:
	return MHMaterials.on() and MHMaterials.ore_kg() > 0.0 and MHMaterials.smelters(_builder()).is_empty()

func interaction_prompt() -> Dictionary:
	var here := placement()
	var part := str(MHChapterOne.tray.get(here, ""))
	if not part.is_empty(): return {"primary": "Take the %s" % MHChapterOne.label(part).to_lower(), "label": "Print Shop · %s in the drawer" % MHChapterOne.label(part).to_lower()}
	if _rock_for_hopper():
		return {"primary": "Feed the rock into the hopper", "label": "Print Shop · %s of iron-rich rock in the store" % MHStyle.kg(roundi(MHMaterials.ore_kg()))}
	var work := MHChapterOne.printer_work(here) if MHChapterOne.jobs.has(here) else {}
	var current: Dictionary = work.get("current", {})
	var waiting := (work.get("queue", []) as Array).size()
	var doing := "" if current.is_empty() else " · printing %s" % MHChapterOne.label(str(current.id))
	if waiting > 0: doing += " (+%d queued)" % waiting
	return {"primary": "Open the Print Shop", "label": "Print Shop" + doing}

func interact(_actor: Node = null) -> bool:
	var here := placement()
	var part := MHChapterOne.take_part(here)
	if not part.is_empty():
		MHAudio.sfx("suit_clamp", -4.0)
		if part == "radar_sled_fittings":
			# Onto the frame from pallet 6 (scripts/chunk_three.gd): the sled's built.
			var chunk := get_tree().get_first_node_in_group("chunk_three")
			if chunk != null and chunk.build_sled(): return true
		get_tree().call_group("habitat_world", "show_chapter_messages", [{"id": "part", "title": MHChapterOne.label(part), "text": "In your field kit." if part == "beacon_connector" else "Ready to fit to the sled's frame.", "tone": "valid"}])
		return true
	if _rock_for_hopper():
		var rock := MHMaterials.ore_kg()
		var made := MHMaterials.feed_hopper()
		_open_hopper()
		get_tree().call_group("habitat_world", "show_chapter_messages", [{"id": "hopper", "title": "Into the hopper: %s of rock" % MHStyle.kg(roundi(rock)), "text": "%s of iron in the store." % MHStyle.kg(roundi(made)), "tone": "valid"}])
		return true
	get_tree().call_group("habitat_world", "open_fabricator", here)
	return true

func _open_hopper() -> void:
	MHAudio.sfx_at("door_open", self, -8.0, 1.2)
	if _hopper_lid == null: return
	var tween := create_tween()
	tween.tween_property(_hopper_lid, "rotation:x", deg_to_rad(96.0), .5)
	tween.tween_interval(1.2)
	tween.tween_property(_hopper_lid, "rotation:x", 0.0, .6)

func _builder() -> Node:
	var world := get_tree().get_first_node_in_group("habitat_world")
	return world.get("builder") if world != null else null
