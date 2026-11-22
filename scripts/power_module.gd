extends StaticBody3D

## The power module (opening slice, docs/opening-slice.md §4a Scenes 3-4):
## one heavy unit in the power pallet. It wakes Walker 1, whose own battery
## the storm ran flat, then rides home inside it and becomes the core's power
## and basic life support when it folds. One object, two jobs. It replaces
## the old air cartridge and solar blanket (scripts/o2_cartridge.gd,
## scripts/power_pack.gd), which version 3 never spawns.
##
## where: "pallet" (until the lid's off), "ground", "carried" (slow: it's
## heavy), "sled" (behind GAR-Y, once its hitch is fitted) or "plugged"
## (into Walker 1's frame socket; from then on it's the walker's).
##
## The model (asset_packs/outpost_chunk1_v1/Power_Module): a ruggedised box
## on runners, its keyed plug (SocketFace) at one end, a tow eye at the
## other, grab bars and a StatusLamp (off asleep, steady amber plugged in).
## Turned so the plug faces +X, the side that meets Walker 1's socket.

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk1/power_module.glb"
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const HELD_AT := Vector3(.25, -.55, -.85)
const SIZE := Vector3(1.0, .5, .6)
const KG := 45.0
const PLUG_REACH := 4.0          # this near Walker 1's socket (carried or set down) to plug it in
const SLED_PLUG_REACH := 14.0    # ... or GAR-Y this near the walker with it on the sled

var site: Node
var world: Node
var where := "pallet"
var _box: Node3D
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _shape: CollisionShape3D

func setup(target_site: Node, start: String) -> void:
	site = target_site
	world = site.world
	name = "PowerModule"
	add_to_group("power_module")
	add_to_group("interaction_claims")   # GAR-Y's sled takes it while you carry it
	set_meta("interaction_target", self)
	_box = _build()
	add_child(_box)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	_shape.shape = box
	_shape.position = Vector3(0, SIZE.y * .5, 0)
	add_child(_shape)
	where = start
	match start:
		"pallet":
			global_position = site.pallet.inside_point()
			global_basis = site.pallet.global_basis
			reachable(site.pallet.opened)
		"plugged":
			visible = false
			reachable(false)

func reachable(on: bool) -> void:
	_shape.disabled = not on

func kg() -> float:
	return KG

func _build() -> Node3D:
	var scene: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	if scene == null: return _build_stand_in()
	var model := scene.instantiate() as Node3D
	model.name = "Box"
	model.rotation.y = -PI * .5   # its plug end (-Z) to +X
	MHPalette.apply(model)
	_lamp = model.find_child("StatusLamp", true, false) as MeshInstance3D
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(.12, .11, .1)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color.BLACK
	if _lamp != null: _lamp.material_override = _lamp_mat
	return model

## The old block-out, if the model's missing.
func _build_stand_in() -> Node3D:
	var root := Node3D.new()
	root.name = "Box"
	var body := _block(SIZE, "white_painted")
	body.position = Vector3(0, SIZE.y * .5, 0)
	root.add_child(body)
	var face := _block(Vector3(.06, .34, .4), "graphite")   # SocketFace: the keyed plug
	face.name = "SocketFace"
	face.position = Vector3(SIZE.x * .5 + .03, SIZE.y * .5, 0)
	root.add_child(face)
	for side in [-1.0, 1.0]:
		var bar := _block(Vector3(.7, .04, .04), "dark_alloy")   # Handles
		bar.position = Vector3(0, SIZE.y + .05, side * .22)
		root.add_child(bar)
		var skid := _block(Vector3(SIZE.x + .1, .05, .06), "graphite")   # Skid
		skid.position = Vector3(0, .02, side * .24)
		root.add_child(skid)
	_lamp = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .035
	sphere.height = .07
	_lamp.mesh = sphere
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp_mat.albedo_color = Color(.1, .1, .1)
	_lamp_mat.emission = Color.BLACK
	_lamp.material_override = _lamp_mat
	_lamp.position = Vector3(SIZE.x * .5 - .1, SIZE.y + .02, .2)
	root.add_child(_lamp)
	return root

func _block(size: Vector3, role: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var source := StandardMaterial3D.new()
	source.resource_name = role
	mesh.material_override = MHPalette.material(source)
	return mesh

# ---------- where it goes ----------

func _walker() -> Node3D:
	var walker: Node3D = world.get("walker")
	return walker if walker != null and str(walker.state) == "stalled" else null

func _at() -> Vector3:
	return (world.player as Node3D).global_position if where == "carried" else global_position

func near_walker() -> bool:
	var walker := _walker()
	if walker == null: return false
	var socket: Vector3 = walker.power_socket()
	var at := _at()
	var reach := PLUG_REACH
	if where == "sled":
		at = (get_parent() as Node3D).global_position
		reach = SLED_PLUG_REACH
	return Vector2(at.x - socket.x, at.z - socket.z).length() < reach

func interaction_prompt() -> Dictionary:
	var label := "Power module · %d kg" % roundi(kg())
	if where == "ground" and near_walker(): return {"label": label, "primary": "Plug it into Walker 1"}
	return {"label": label, "primary": "Pick up (heavy)"}

func interact(_player: Node = null) -> bool:
	if where in ["carried", "sled", "plugged"]: return false
	if where == "ground" and near_walker():
		plug_in()
		return true
	pick_up()
	return true

func pick_up() -> void:
	var camera := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return
	where = "carried"
	reachable(false)
	var known_left: Node = world.get("known")
	if known_left != null: known_left.picked_up(LEFT_ID)
	get_parent().remove_child(self)
	camera.add_child(self)
	position = HELD_AT
	rotation = Vector3(0, deg_to_rad(80), deg_to_rad(-6))
	world.player.set_meta("load_speed", lerpf(1.0, .45, clampf(kg() / 50.0, 0.0, 1.0)))
	MHAudio.sfx("suit_clamp", -6.0)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.show_equipment_note("Carrying the power module", "Heavy. Q sets it down." + (" E on GAR-Y loads it on its sled." if _hitched() else ""))

const LEFT_ID := "left:power_module"   # its mark on the compass while it's on the ground

func put_down() -> void:
	if where != "carried": return
	var player: Node3D = world.player
	get_parent().remove_child(self)
	site.add_child(self)
	var ahead := player.global_position - player.global_transform.basis.z * 1.0
	global_position = Vector3(ahead.x, MHSiteTerrain.height(ahead.x, ahead.z), ahead.z)
	rotation = Vector3(0, player.rotation.y + PI * .5, 0)
	where = "ground"
	reachable(true)
	var known_left: Node = world.get("known")
	if known_left != null: known_left.set_down(LEFT_ID, "Power module", global_position)
	player.set_meta("load_speed", 1.0)
	MHAudio.sfx("place", -6.0)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")

func _hitched() -> bool:
	var pod: Node = world.get("lifepod")
	return pod != null and (pod.prints as Dictionary).has("hitch")

## Into Walker 1's frame socket: its lamp goes steady and it wakes.
func plug_in() -> void:
	var walker := _walker()
	if walker == null: return
	if where == "carried": world.player.set_meta("load_speed", 1.0)
	var known_left: Node = world.get("known")
	if known_left != null: known_left.picked_up(LEFT_ID)
	if where == "sled":
		var pod: Node = world.get("lifepod")
		if pod != null: (pod.sled_cargo as Array).erase(self)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")
	# Its plug (SocketFace) meets the walker's PowerSocket face to face.
	var face := _box.find_child("SocketFace", true, false) as Node3D
	var in_case := global_transform.affine_inverse() * face.global_transform if face != null else Transform3D.IDENTITY
	get_parent().remove_child(self)
	walker.add_child(self)
	if face != null:
		global_transform = (walker.socket_transform() * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)) * in_case.affine_inverse()
	else:
		position = walker.SOCKET_LOCAL
		rotation = Vector3.ZERO
	where = "plugged"
	reachable(false)
	_lamp_mat.albedo_color = Color("#ffb449")
	_lamp_mat.emission = Color("#ffb449")
	_lamp_mat.emission_energy_multiplier = 1.25
	MHAudio.sfx("suit_clamp", -2.0)
	walker.power_in()

# ---------- GAR-Y's sled claims E while you carry it ----------

func claim(target: Node, method_name: String) -> bool:
	if method_name != "interact": return false
	# With it on GAR-Y's sled near the walker, E on the walker plugs it in.
	if where == "sled" and target == world.get("walker") and near_walker():
		plug_in()
		return true
	if where == "carried" and target == world.get("walker") and near_walker():
		plug_in()
		return true
	if where != "carried": return false
	var pod: Node = world.get("lifepod")
	if pod == null or not pod.sled_takes(target): return false
	pod.load_on_sled(self, target)
	return true

func claim_label(target: Node) -> String:
	if where in ["sled", "carried"] and target == world.get("walker") and near_walker(): return "Plug the power module into Walker 1"
	var pod: Node = world.get("lifepod")
	return "Load it on GAR-Y's sled" if where == "carried" and pod != null and pod.sled_takes(target) else ""

func _unhandled_input(event: InputEvent) -> void:
	if where != "carried": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		put_down()
		get_viewport().set_input_as_handled()

func export_state() -> Dictionary:
	var at := global_position
	return {"where": where if where != "carried" and where != "sled" else "ground", "at": [at.x, at.y, at.z]}
