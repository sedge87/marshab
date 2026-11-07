extends StaticBody3D

## Pallet 2's power pack (scripts/drop_site.gd): a rolled solar blanket
## strapped to a battery, about 18 kg, carried by hand like the oxygen
## cartridge. E picks it up, Q puts it down. Set down near the lander, E lays
## it out: the blanket unrolls on the ground beside the hull, a cable runs to
## the lander, and the cabin gets the blanket's sunlight and the battery's
## store (scripts/survival_core.gd add_power_pack), enough for the heater to
## run all night.
##
## where: "pallet" (inside, until the lid is open), "ground", "carried" or
## "laid" (set up by the lander, for good).

const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const HELD_AT := Vector3(.3, -.46, -.7)
const LAY_REACH := 16.0            # how near the lander it must be to lay it out
const BLANKET := Vector2(6.0, 1.4) # metres, unrolled
## Where the blanket lies, in the lander's frame: off its right side, clear
## of the ramp and the ladder.
const BLANKET_AT := Vector3(8.4, 0, 1.0)

var site: Node
var world: Node
var where := "pallet"
var _roll: Node3D
var _shape: CollisionShape3D

func setup(target_site: Node, start: String) -> void:
	site = target_site
	world = site.world
	name = "PowerPack"
	add_to_group("power_pack")
	set_meta("interaction_target", self)
	_roll = _build_roll()
	add_child(_roll)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.9, .42, .46)
	_shape.shape = box
	_shape.position = Vector3(0, .21, 0)
	add_child(_shape)
	where = start
	match start:
		"pallet":
			global_position = site.pallet.inside_point()
			global_basis = site.pallet.global_basis
			reachable(site.pallet.opened)
		"laid":
			_lay_out.call_deferred(false)

func reachable(on: bool) -> void:
	_shape.disabled = not on

func kg() -> float:
	return MHResources.revamp("power_pack_carry_kg", 18.0)

## The roll and the battery, from plain parts in the house colours.
func _build_roll() -> Node3D:
	var root := Node3D.new()
	root.name = "Roll"
	var roll := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .15
	cylinder.bottom_radius = .15
	cylinder.height = .86
	roll.mesh = cylinder
	roll.rotation.z = PI / 2.0
	roll.position = Vector3(0, .3, -.06)
	roll.material_override = _mat("dark_glass")
	root.add_child(roll)
	for side in [-1.0, 1.0]:
		var strap := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = .158
		ring.bottom_radius = .158
		ring.height = .05
		strap.mesh = ring
		strap.rotation.z = PI / 2.0
		strap.position = Vector3(side * .3, .3, -.06)
		strap.material_override = _mat("orange")
		root.add_child(strap)
	var battery := _block(Vector3(.62, .16, .34), "frame")
	battery.position = Vector3(0, .08, .04)
	root.add_child(battery)
	return root

func _block(size: Vector3, role: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(role)
	return mesh

func _mat(role: String) -> StandardMaterial3D:
	var source := StandardMaterial3D.new()
	source.resource_name = role
	return MHPalette.material(source)

# ---------- carrying ----------

func near_lander() -> bool:
	var lander: Node3D = world.lander
	var at := global_position if where != "carried" else (world.player as Node3D).global_position
	return lander != null and Vector2(at.x - lander.global_position.x, at.z - lander.global_position.z).length() < LAY_REACH and not lander.cabin_contains(at)

func interaction_prompt() -> Dictionary:
	match where:
		"laid": return {"label": "Solar blanket · laid out"}
		"ground":
			if near_lander(): return {"label": "Power pack · %d kg" % roundi(kg()), "primary": "Lay out the solar blanket"}
	return {"label": "Power pack · %d kg" % roundi(kg()), "primary": "Pick up"}

func interact(_player: Node = null) -> bool:
	if where == "carried" or where == "laid": return false
	if where == "ground" and near_lander():
		lay_out()
		return true
	pick_up()
	return true

func pick_up() -> void:
	var camera := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null: return
	where = "carried"
	reachable(false)
	get_parent().remove_child(self)
	camera.add_child(self)
	position = HELD_AT
	rotation = Vector3(0, deg_to_rad(80), deg_to_rad(-6))
	world.player.set_meta("load_speed", lerpf(1.0, .6, clampf(kg() / 40.0, 0.0, 1.0)))
	MHAudio.sfx("suit_clamp", -6.0)
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.show_equipment_note("Carrying the power pack", "Q puts it down. Set it down near the lander, then E lays out the blanket.")

func put_down() -> void:
	if where != "carried": return
	var player: Node3D = world.player
	get_parent().remove_child(self)
	site.add_child(self)
	var ahead := player.global_position - player.global_transform.basis.z * .9
	var floor_y := MHSiteTerrain.height(ahead.x, ahead.z)
	if world.lander.cabin_contains(player.global_position): floor_y = player.global_position.y - .9
	global_position = Vector3(ahead.x, floor_y, ahead.z)
	rotation = Vector3(0, player.rotation.y + PI * .5, 0)
	where = "ground"
	reachable(true)
	player.set_meta("load_speed", 1.0)
	MHAudio.sfx("place", -6.0)
	var hud: Node = world.get("explore_hud")
	if hud != null:
		hud.hide_equipment_note("Carrying")
		if near_lander(): hud.show_equipment_note("Power pack", "E lays out the solar blanket and plugs the battery into the lander.")

func _unhandled_input(event: InputEvent) -> void:
	if where != "carried": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		put_down()
		get_viewport().set_input_as_handled()

# ---------- laying it out ----------

## The blanket unrolls beside the lander and the cabin gets its power.
func lay_out() -> void:
	if where == "laid": return
	where = "laid"
	var cabin: Node = world.get("cabin_life")
	if cabin != null: cabin.core.add_power_pack(MHResources.revamp("power_pack_kw", 1.5), MHResources.revamp("power_pack_kwh", 10.0))
	_lay_out(true)
	MHAudio.sfx("place", -4.0)
	MHAudio.moment()
	site.power_laid()

func _lay_out(animate: bool) -> void:
	var lander: Node3D = world.lander
	if lander == null: return
	if get_parent() != site:
		if get_parent() != null: get_parent().remove_child(self)
		site.add_child(self)
	reachable(false)
	_roll.visible = false
	var at := lander.to_global(BLANKET_AT)
	at.y = MHSiteTerrain.height(at.x, at.z)
	global_position = at
	global_basis = lander.global_basis
	var blanket := Node3D.new()
	blanket.name = "Blanket"
	add_child(blanket)
	# Cells in rows, on a thin backing, each laid on the ground.
	var cells := 8
	for i in cells:
		var cell := _block(Vector3(BLANKET.x / cells - .05, .02, BLANKET.y - .1), "dark_glass")
		var local := Vector3(-BLANKET.x * .5 + (i + .5) * BLANKET.x / cells, 0, 0)
		var world_at := to_global(local)
		cell.position = local + Vector3(0, MHSiteTerrain.height(world_at.x, world_at.z) - at.y + .03, 0)
		blanket.add_child(cell)
		if animate:
			cell.scale = Vector3(.01, 1, 1)
			create_tween().tween_property(cell, "scale", Vector3.ONE, .25).set_delay(i * .12)
	var backing := _block(Vector3(BLANKET.x + .1, .015, BLANKET.y), "graphite")
	backing.position = Vector3(0, .015, 0)
	blanket.add_child(backing)
	# The battery at the near end, and its cable to the hull.
	var battery := _block(Vector3(.62, .16, .34), "frame")
	battery.position = Vector3(-BLANKET.x * .5 - .5, .08, 0)
	add_child(battery)
	var hull := lander.to_global(Vector3(3.0, 0, 1.0))
	hull.y = MHSiteTerrain.height(hull.x, hull.z)
	var from := to_global(battery.position)
	var cable := _block(Vector3(.04, .04, 1.0), "rubber")
	var length := Vector2(hull.x - from.x, hull.z - from.z).length()
	cable.scale = Vector3(1, 1, length)
	add_child(cable)
	cable.global_position = (from + hull) * .5 + Vector3(0, .03, 0)
	cable.look_at(hull + Vector3(0, .03, 0), Vector3.UP)
	cable.scale = Vector3(1, 1, length)
	var body := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BLANKET.x, .06, BLANKET.y)
	body.shape = box
	add_child(body)
