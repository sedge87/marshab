extends StaticBody3D

## Pallet 1's oxygen cartridge (scripts/storm_drop.gd): about 20 kg, carried
## by hand. E picks it up, Q puts it down at your feet, and E on the cabin's
## oxygen port (scripts/cabin_o2_port.gd) plugs it in: the cabin's tank grows
## by its oxygen and the dial swings over to full. Carrying it slows you.
##
## where: "pallet" (inside, until the lid is open), "ground", "carried" or
## "plugged" (in the port's cradle, for good).

const MODEL := preload("res://assets/models/storm_cargo/o2_cartridge.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const HELD_AT := Vector3(.28, -.42, -.62)   # in front of the camera, low and to the right

var drop: Node
var where := "pallet"
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
	return {"label": "Oxygen cartridge · %d kg" % roundi(kg()), "primary": "Pick up"} if where != "plugged" else {"label": "Oxygen cartridge · plugged in"}

func interact(_player: Node = null) -> bool:
	if where == "carried" or where == "plugged": return false
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
	if notes != null: notes.think("air", "carrying")
	var hud: Node = drop.world.get("explore_hud")
	if hud != null: hud.show_equipment_note("Carrying the cartridge", "E on the cabin's oxygen port plugs it in. Q puts it down.")

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
	if where != "carried" or method_name != "interact" or target == null or not target.is_in_group("cabin_o2_port"): return false
	plug_in(target)
	return true

func claim_label(target: Node) -> String:
	return "Plug in the cartridge" if where == "carried" and target != null and target.is_in_group("cabin_o2_port") else ""

## Into the port's cradle: the cabin's tank takes its oxygen, the dial swings.
func plug_in(port: Node) -> void:
	where = "plugged"
	drop.world.player.set_meta("load_speed", 1.0)
	var hud: Node = drop.world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")
	_into_port()
	var cabin: Node = drop.world.get("cabin_life")
	if cabin != null: cabin.add_cartridge(oxygen_kg())
	port.plugged()
	var notes: Node = drop.world.get("notes")
	if notes != null: notes.answer("air")
	MHAudio.sfx("suit_fill", -4.0)
	MHAudio.moment()

func _into_port() -> void:
	var port := get_tree().get_first_node_in_group("cabin_o2_port") as Node3D
	if port == null: return
	if get_parent() != null: get_parent().remove_child(self)
	port.add_child(self)
	position = port.CRADLE
	rotation = Vector3.ZERO
	reachable(false)
