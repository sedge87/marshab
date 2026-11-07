extends StaticBody3D

## Something you've chipped off Mars and carry by hand (step 3b, the lifepod
## days; scripts/lifepod.gd): an ice chunk for the lander's melter, or a rock
## sample to look at closely on the lander's bench. E picks it up, Q puts it
## down, and while you carry it the bench's stations (scripts/lifepod_bench.gd)
## take E: "Melt the ice", "Look closer". Like the oxygen cartridge
## (scripts/o2_cartridge.gd), carrying it slows you by its weight.
##
## kind: "ice" or "rock". where: "ground" or "carried" (used up once melted or
## studied).

const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const HELD_AT := Vector3(.26, -.4, -.6)

var lifepod: Node
var kind := "ice"
var kg := 8.0
var source := ""                # the thread it came from: "iron", "ice_wall", "frost"
var where := "ground"
var _shape: CollisionShape3D

func setup(target_lifepod: Node, find_kind: String, weight: float, from: String) -> void:
	lifepod = target_lifepod
	kind = find_kind
	kg = weight
	source = from
	name = "Carried_%s" % kind
	add_to_group("carried_find")
	add_to_group("interaction_claims")
	set_meta("interaction_target", self)
	add_child(_build())
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.42, .3, .36) if kind == "ice" else Vector3(.22, .16, .2)
	_shape.shape = box
	_shape.position = Vector3(0, box.size.y * .5, 0)
	add_child(_shape)

## A rough chunk: a few lumpy boxes, ice pale and glassy, rock rust-dark with
## grey beads in it.
func _build() -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(source + kind)
	var scale := 1.0 if kind == "ice" else .45
	for i in 4:
		var lump := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(.18, .3), rng.randf_range(.12, .22), rng.randf_range(.16, .28)) * scale
		lump.mesh = box
		lump.position = Vector3(rng.randf_range(-.08, .08), box.size.y * .5, rng.randf_range(-.07, .07)) * scale / maxf(scale, .5)
		lump.rotation = Vector3(rng.randf_range(-.4, .4), rng.randf_range(0, TAU), rng.randf_range(-.4, .4))
		lump.material_override = material(kind)
		root.add_child(lump)
	return root

static func material(what: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	match what:
		"ice":
			mat.resource_name = "ice_dusty"
			mat.albedo_color = Color("#8EA7B4")
			mat.roughness = .18
			mat.metallic_specular = .9
			mat.rim_enabled = true
			mat.rim = .4
			mat.rim_tint = .2
		"frost":
			mat.resource_name = "frost_ground"
			mat.albedo_color = Color("#D9D2C8")
			mat.roughness = .9
		"bead":
			mat.resource_name = "rock_bead_grey"
			mat.albedo_color = Color("#5C5E62")
			mat.roughness = .5
			mat.metallic = .3
		_:
			mat.resource_name = "rock_haematite"
			mat.albedo_color = Color("#5E3227")
			mat.roughness = .85
	return mat

func label() -> String:
	if kind == "ice": return "Ice chunk · %d kg" % roundi(kg)
	return "Rock sample · %s" % ("haematite?" if source == "iron" else "rock")

func interaction_prompt() -> Dictionary:
	return {"label": label(), "primary": "Pick up"}

func interact(_player: Node = null) -> bool:
	if where == "carried": return false
	pick_up()
	return true

func pick_up() -> void:
	var world: Node = lifepod.world
	var camera := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return
	for other in get_tree().get_nodes_in_group("carried_find"):
		if other != self and str(other.where) == "carried": other.put_down()
	where = "carried"
	_shape.disabled = true
	if get_parent() != null: get_parent().remove_child(self)
	camera.add_child(self)
	position = HELD_AT
	rotation = Vector3(0, deg_to_rad(30), 0)
	scale = Vector3.ONE * (.55 if kind == "ice" else .8)   # held low and out of the way
	world.player.set_meta("load_speed", lerpf(1.0, .6, clampf(kg / 40.0, 0.0, 1.0)))
	MHAudio.sfx("suit_clamp", -8.0)
	var hud: Node = world.get("explore_hud")
	if hud != null:
		var what := "Melt it in the lander's melter (E on it)." if kind == "ice" else "Look at it closely on the lander's bench (E on it)."
		hud.show_equipment_note("Carrying: " + label(), what + " Q puts it down.")

func put_down() -> void:
	if where != "carried": return
	var world: Node = lifepod.world
	var player: Node3D = world.player
	get_parent().remove_child(self)
	lifepod.add_child(self)
	var ahead := player.global_position - player.global_transform.basis.z * .8
	var floor_y := MHSiteTerrain.height(ahead.x, ahead.z)
	if world.lander.cabin_contains(player.global_position): floor_y = player.global_position.y - .9
	global_position = Vector3(ahead.x, floor_y, ahead.z)
	scale = Vector3.ONE
	rotation = Vector3(0, player.rotation.y, 0)
	where = "ground"
	_shape.disabled = false
	player.set_meta("load_speed", 1.0)
	MHAudio.sfx("place", -8.0)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")

## Melted or studied: gone from your hands.
func used_up() -> void:
	var world: Node = lifepod.world
	world.player.set_meta("load_speed", 1.0)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Carrying")
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if where != "carried": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		put_down()
		get_viewport().set_input_as_handled()

# ---------- the bench's stations take E while you carry it ----------

func claim(target: Node, method_name: String) -> bool:
	if where != "carried" or method_name != "interact" or claim_label(target).is_empty(): return false
	return bool(target.call("take", self))

func claim_label(target: Node) -> String:
	if where != "carried" or target == null or not target.has_method("takes"): return ""
	return str(target.call("takes", self))

func export_state() -> Dictionary:
	var at := global_position
	return {"kind": kind, "kg": kg, "source": source, "at": [at.x, at.y, at.z]}
