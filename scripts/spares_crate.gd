extends StaticBody3D

## The spares crate GAR-Y was circling on day 2 (the guided days, version 2;
## docs/opening-days.md): it fell from a pallet that broke up in the storm.
## Too heavy to carry. GAR-Y has a tow mount but no hitch: print one on the
## lander's printer from storm scrap, then E here with GAR-Y close hitches the
## crate to its sled (scripts/lifepod.gd load_on_sled). At the lander, E on
## GAR-Y unloads it; E on the crate opens it: printer parts, and spares for
## the module's shelf when it comes. Plain shapes, house colours, no lettering.

const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const KG := 70.0
const GARY_REACH := 7.0
const PARTS := 8
const SPARES := 3                # banked for the module (MHChapterOne.stock "spares_kit")

var world: Node
var drop: Node                   # where it lives when it's on the ground (lifepod.unload_cargo)
var where := "ground"            # ground, sled
var opened := false
var _shape: CollisionShape3D
var _lid: MeshInstance3D

func setup(target_world: Node, home: Node, at: Vector3, saved: Dictionary) -> void:
	world = target_world
	drop = home
	name = "SparesCrate"
	add_to_group("spares_crate")
	set_meta("interaction_target", self)
	opened = bool(saved.get("opened", false))
	_build()
	global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.z), at.z)
	rotation.y = float(saved.get("yaw", randf() * TAU))

func _build() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, .62, .78)
	body.mesh = box
	body.position = Vector3(0, .31, 0)
	body.material_override = _mat(Color(.62, .6, .55), "structure")
	add_child(body)
	for x in [-.5, .5]:
		var band := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(.06, .64, .8)
		band.mesh = b
		band.position = Vector3(x, .31, 0)
		band.material_override = _mat(Color(.85, .62, .18), "accent")
		add_child(band)
	_lid = MeshInstance3D.new()
	var lid := BoxMesh.new()
	lid.size = Vector3(1.14, .06, .82)
	_lid.mesh = lid
	_lid.position = Vector3(0, .65, 0)
	_lid.material_override = _mat(Color(.5, .49, .46), "structure")
	add_child(_lid)
	if opened: _open_lid()
	_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, .7, .8)
	_shape.shape = shape
	_shape.position = Vector3(0, .35, 0)
	add_child(_shape)

func _mat(colour: Color, role: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = .85
	m.set_meta("mh_role", role)
	return m

func _open_lid() -> void:
	_lid.position = Vector3(0, .7, -.45)
	_lid.rotation.x = deg_to_rad(-70.0)

func reachable(on: bool) -> void:
	_shape.disabled = not on

func _lifepod() -> Node:
	return world.get("lifepod")

func _gary() -> Node3D:
	var g: Variant = world.get("scout_rover")
	return g as Node3D if g != null and is_instance_valid(g) else null

func _near_lander() -> bool:
	return global_position.distance_to(world.lander.global_position) < 30.0

func interaction_prompt() -> Dictionary:
	if opened: return {"label": "Spares crate · empty"}
	if _near_lander(): return {"label": "Spares crate · %d kg" % roundi(KG), "primary": "Open it"}
	var pod := _lifepod()
	var gary := _gary()
	if pod != null and gary != null and pod.sled_takes(gary) and gary.global_position.distance_to(global_position) < GARY_REACH:
		return {"label": "Spares crate · %d kg" % roundi(KG), "primary": "Hitch it to GAR-Y's sled"}
	if pod != null and bool((pod.prints as Dictionary).has("hitch")): return {"label": "Spares crate · %d kg · bring GAR-Y close to hitch it" % roundi(KG)}
	return {"label": "Spares crate · %d kg · too heavy to carry" % roundi(KG)}

func interact(_player: Node = null) -> bool:
	if opened: return false
	if _near_lander():
		_open()
		return true
	var pod := _lifepod()
	var gary := _gary()
	if pod == null or gary == null or not pod.sled_takes(gary) or gary.global_position.distance_to(global_position) > GARY_REACH: return false
	pod.load_on_sled(self, gary)
	return true

func _open() -> void:
	opened = true
	var known: Node = world.get("known")
	if known != null: known.finish("spares_crate")
	_open_lid()
	MHAudio.sfx_at("suit_clamp", self, -4.0, .9)
	var pod := _lifepod()
	if pod != null:
		pod.parts = int(pod.parts) + PARTS
		pod.walker_due = true   # day 2's work done: the walker moves tonight
	MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.get("spares_kit", 0)) + SPARES
	MHNotices.post("valid", "Spares crate", "Wiring, brackets, seals and fasteners: %d parts for the lander's printer, and %d spares kits put by for the module." % [PARTS, SPARES], "log")
	MHAudio.moment()
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d2_crate")

func export_state() -> Dictionary:
	var at := global_position
	if where == "sled":
		var gary := _gary()
		if gary != null: at = gary.global_position + gary.global_basis.z * 1.2
	return {"at": [at.x, at.y, at.z], "yaw": rotation.y, "opened": opened}
