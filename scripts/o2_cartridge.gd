extends StaticBody3D

## Pallet 1's oxygen cartridge (scripts/storm_drop.gd): about 20 kg, carried
## by hand. E picks it up, Q puts it down at your feet, and E on the cabin's
## oxygen port (scripts/cabin_o2_port.gd) plugs it in: the cabin's tank grows
## by its oxygen and the dial swings over to full. Carrying it slows you.
##
## where: "pallet" (inside, until the lid is open), "ground", "carried",
## "sled" (on GAR-Y's sled) or "plugged" (in a cradle, for good).
##
## The opening's redesign (8 Nov, docs/opening-days.md): the lander makes its
## own air, so this is the General Module's. It waits by the lander (on foot
## or on GAR-Y's sled) and plugs into the module's outside socket
## (scripts/module_life.gd). An older game's lander still takes it.

const MODEL := preload("res://assets/models/storm_cargo/o2_cartridge.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const HELD_AT := Vector3(.28, -.42, -.62)   # in front of the camera, low and to the right

var drop: Node
var where := "pallet"
var plugged_into := "cabin"     # "cabin" (older games) or "module"
var _model: Node3D
var _shape: CollisionShape3D

func setup(target_drop: Node, start: String) -> void:
	drop = target_drop
	name = "O2Cartridge"
	add_to_group("o2_cartridge")
	add_to_group("interaction_claims")
	set_meta("interaction_target", self)
	_model = MODEL.instantiate()
	add_child(_model)
	MHPalette.apply(_model)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.86, .3, .3)
	_shape.shape = box
	_shape.position = Vector3(0, .14, 0)
	add_child(_shape)
	where = start
	match start:
		"pallet":
			global_position = drop.pallet.inside_point()
			global_basis = drop.pallet.global_basis
			reachable(drop.pallet.opened)
		"plugged":
			_into_port.call_deferred()

## Inside a shut pallet you can't get at it.
func reachable(on: bool) -> void:
	_shape.disabled = not on

func kg() -> float:
	return MHResources.revamp("cartridge_carry_kg", 20.0)

func oxygen_kg() -> float:
	return MHResources.revamp("cartridge_o2_kg", 6.0)

func interaction_prompt() -> Dictionary:
	if where == "plugged": return {"label": "Air cartridge · plugged in"}
	return {"label": "Module air cartridge · %d kg" % roundi(kg()), "primary": "Pick up"}

func interact(_player: Node = null) -> bool:
	if where in ["carried", "plugged", "sled"]: return false
	pick_up()
	return true

func pick_up() -> void:
	var camera := drop.world.player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return
	where = "carried"
	reachable(false)
	get_parent().remove_child(self)
	camera.add_child(self)
	position = HELD_AT
	rotation = Vector3(0, deg_to_rad(80), deg_to_rad(-8))
	drop.world.player.set_meta("load_speed", lerpf(1.0, .6, clampf(kg() / 40.0, 0.0, 1.0)))
	MHAudio.sfx("suit_clamp", -6.0)
	var notes: Node = drop.world.get("notes")
	if notes != null: notes.think("module_air", "carrying")
	var hud: Node = drop.world.get("explore_hud")
	if hud != null:
		if _cabin_takes_it(): hud.show_equipment_note("Carrying the cartridge", "E on the cabin's oxygen port plugs it in. Q puts it down.")
		elif _module_socket() != null: hud.show_equipment_note("Carrying the cartridge", "E on the module's outside socket plugs it in. Q puts it down.")
		else: hud.show_equipment_note("Carrying the cartridge", "Q puts it down by the lander for the module. E on GAR-Y loads it on its sled, once it has a hitch.")

## Q: down at your feet.
func put_down() -> void:
	if where != "carried": return
	var player: Node3D = drop.world.player
	get_parent().remove_child(self)
	drop.add_child(self)
	var ahead := player.global_position - player.global_transform.basis.z * .9
	var floor_y := MHSiteTerrain.height(ahead.x, ahead.z)
	if drop.world.lander.cabin_contains(player.global_position): floor_y = player.global_position.y - .9
	global_position = Vector3(ahead.x, floor_y, ahead.z)
	rotation = Vector3(0, player.rotation.y + PI * .5, 0)
	where = "ground"
	reachable(true)
	player.set_meta("load_speed", 1.0)
	MHAudio.sfx("place", -6.0)
	var hud: Node = drop.world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")

func _unhandled_input(event: InputEvent) -> void:
	if where != "carried": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		put_down()
		get_viewport().set_input_as_handled()

# ---------- the cabin's port claims E while you carry it ----------

func claim(target: Node, method_name: String) -> bool:
	if where != "carried" or method_name != "interact": return false
	var pod: Node = drop.world.get("lifepod")
	if pod != null and pod.sled_takes(target):
		pod.load_on_sled(self, target)
		return true
	if not _takes(target): return false
	plug_in(target)
	return true

func claim_label(target: Node) -> String:
	if where != "carried": return ""
	var pod: Node = drop.world.get("lifepod")
	if pod != null and pod.sled_takes(target): return "Load it on GAR-Y's sled"
	return "Plug in the cartridge" if _takes(target) else ""

## Where it can go: the module's socket, or an older game's cabin port.
func _takes(target: Node) -> bool:
	if target == null: return false
	if target.is_in_group("module_socket"): return target.has_method("running") and target.running()
	return target.is_in_group("cabin_o2_port") and _cabin_takes_it()

func _cabin_takes_it() -> bool:
	var cabin: Node = drop.world.get("cabin_life")
	return cabin != null and not bool(cabin.core.self_sufficient)

func _module_socket() -> Node:
	var module: Node = drop.world.get("module_life")
	return module if module != null and module.running() else null

## Into the port's cradle: the cabin's tank takes its oxygen, the dial swings.
func plug_in(port: Node) -> void:
	where = "plugged"
	drop.world.player.set_meta("load_speed", 1.0)
	var hud: Node = drop.world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")
	var notes: Node = drop.world.get("notes")
	if port.is_in_group("module_socket"):
		plugged_into = "module"
		_into_port()
		port.add_cartridge(oxygen_kg())
		if notes != null: notes.answer("module_air")
	else:
		plugged_into = "cabin"
		_into_port()
		var cabin: Node = drop.world.get("cabin_life")
		if cabin != null: cabin.add_cartridge(oxygen_kg())
		port.plugged()
		if notes != null: notes.answer("air")
	MHAudio.sfx("suit_fill", -4.0)
	MHAudio.moment()

func _into_port() -> void:
	if plugged_into == "module":
		# On the module's socket plate (built a moment after loading).
		var module: Node = drop.world.get("module_life")
		var plate: Node3D = module.socket if module != null else null
		if plate == null or not is_instance_valid(plate):
			get_tree().create_timer(.5).timeout.connect(_into_port)
			return
		if get_parent() != null: get_parent().remove_child(self)
		plate.add_child(self)
		position = Vector3(0, -.32, .22)
		rotation = Vector3.ZERO
		reachable(false)
		return
	var port := get_tree().get_first_node_in_group("cabin_o2_port") as Node3D
	if port == null: return
	if get_parent() != null: get_parent().remove_child(self)
	port.add_child(self)
	position = port.CRADLE
	rotation = Vector3.ZERO
	reachable(false)
