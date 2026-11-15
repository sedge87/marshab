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
## Chapter 5 (15 Nov, docs/opening-days.md "Chapter 5"): pallet 6's crate,
## the Print Shop and a regolith intake flat-packed with a starter sack of
## feedstock. Too heavy to carry; GAR-Y tows it home the same way.
const PRINT_SHOP_KG := 160.0
const STARTER_FEEDSTOCK := 250.0  # enough to print the ice extractor on the day
const HOME_REACH := 30.0
var kind := "spares"             # spares (chapter 2) or print_shop (chapter 5)

var world: Node
var drop: Node                   # where it lives when it's on the ground (lifepod.unload_cargo)
var where := "ground"            # ground, sled
var opened := false
var _shape: CollisionShape3D
var _lid: MeshInstance3D

func setup(target_world: Node, home: Node, at: Vector3, saved: Dictionary) -> void:
	world = target_world
	drop = home
	kind = str(saved.get("kind", kind))
	name = "PrintShopCrate" if kind == "print_shop" else "SparesCrate"
	add_to_group("print_shop_crate" if kind == "print_shop" else "spares_crate")
	set_meta("interaction_target", self)
	opened = bool(saved.get("opened", false))
	_build()
	global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.z), at.z)
	rotation.y = float(saved.get("yaw", randf() * TAU))

func _build() -> void:
	var body := MeshInstance3D.new()
	var big := kind == "print_shop"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, .62, .78)
	if big: scale = Vector3(1.5, 1.3, 1.5)
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

## Home: by the lander, or (chapter 5's crate) by a base's core too.
func _near_lander() -> bool:
	if global_position.distance_to(world.lander.global_position) < HOME_REACH: return true
	return kind == "print_shop" and near_a_core(world, global_position)

static func near_a_core(in_world: Node, p: Vector3) -> bool:
	var module: Node = in_world.get("module_life")
	if module != null and not (module.zone() as Dictionary).is_empty():
		var c: Vector3 = module._centre()
		if Vector2(p.x - c.x, p.z - c.z).length() < HOME_REACH: return true
	var builder: Node = in_world.get("builder")
	return builder != null and builder.is_inside(p + Vector3(0, 1, 0))

func _title() -> String:
	return "Print Shop crate" if kind == "print_shop" else "Spares crate"

func _kg() -> float:
	return PRINT_SHOP_KG if kind == "print_shop" else KG

func interaction_prompt() -> Dictionary:
	if opened: return {"label": "%s · empty" % _title()}
	if _near_lander(): return {"label": "%s · %d kg" % [_title(), roundi(_kg())], "primary": "Open it"}
	var pod := _lifepod()
	var gary := _gary()
	if pod != null and gary != null and pod.sled_takes(gary) and gary.global_position.distance_to(global_position) < GARY_REACH:
		return {"label": "%s · %d kg" % [_title(), roundi(_kg())], "primary": "Hitch it to GAR-Y's sled"}
	if pod != null and bool((pod.prints as Dictionary).has("hitch")): return {"label": "%s · %d kg · bring GAR-Y close to hitch it" % [_title(), roundi(_kg())]}
	return {"label": "%s · %d kg · too heavy to carry" % [_title(), roundi(_kg())]}

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
	if kind == "print_shop":
		_open_print_shop()
		return
	var known: Node = world.get("known")
	if known != null: known.finish("spares_crate")
	_open_lid()
	MHAudio.sfx_at("suit_clamp", self, -4.0, .9)
	var pod := _lifepod()
	if pod != null:
		pod.parts = int(pod.parts) + PARTS
		pod.walker_due = true   # day 2's work done: the walker moves tonight
	MHChapterOne.stock["spares_kit"] = int(MHChapterOne.stock.get("spares_kit", 0)) + SPARES
	MHNotices.post("valid", "Spares crate", "Wiring, brackets, seals and fasteners: %d parts for the lander's printer, %d spares kits put by for the module, and a bigger air pack for your suit." % [PARTS, SPARES], "log")
	# 15 Nov playtest: the bare suit's first add-on comes here, after a day of
	# feeling its limit (it was at pallet 1). It goes on at the next refill.
	var suit: Node = world.get("suit")
	if suit != null and suit.has_method("give_addon"): suit.give_addon("air_pack")
	MHAudio.moment()
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d2_crate")

## Chapter 5: the Print Shop, an intake and a sack of feedstock, into the
## store (the build bar's Unpacked tab).
func _open_print_shop() -> void:
	var known: Node = world.get("known")
	if known != null: known.finish("print_shop_crate")
	_open_lid()
	MHAudio.sfx_at("suit_clamp", self, -4.0, .9)
	for id in ["fabricator", "regolith_intake"]:
		MHChapterOne.stock[id] = int(MHChapterOne.stock.get(id, 0)) + 1
	MHChapterOne.feedstock_kg += STARTER_FEEDSTOCK
	MHNotices.post("valid", "Pallet 6: the Print Shop", "The Print Shop, a regolith intake and a %s sack of feedstock, in the store. B for the build bar: they're on its Unpacked tab." % MHStyle.kg(roundi(STARTER_FEEDSTOCK)), "log")
	MHAudio.moment()
	var radio: Node = world.get("radio")
	if radio != null: radio.ring("d5_unpacked")

func export_state() -> Dictionary:
	var at := global_position
	if where == "sled":
		var gary := _gary()
		if gary != null: at = gary.global_position + gary.global_basis.z * 1.2
	return {"at": [at.x, at.y, at.z], "yaw": rotation.y, "opened": opened, "kind": kind}
