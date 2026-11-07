extends StaticBody3D

## The cabin wall's oxygen port (scripts/lander_cabin_life.gd): a dial that
## shows how much is left in the cabin's oxygen tank, and the cradle a
## cartridge plugs into (scripts/o2_cartridge.gd). No lettering: the needle,
## a green tick at full and a dark one at empty say it all.

const MODEL := preload("res://assets/models/storm_cargo/cabin_o2_port.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
## Where a plugged-in cartridge lies, in the port's frame (the cradle).
const CRADLE := Vector3(-.05, -.12, .18)
const SWEEP := 135.0      # degrees either side of straight up: empty to full

var cabin: Node
var _needle: Node3D
var _shown := -1.0

func setup(target_cabin: Node) -> void:
	cabin = target_cabin
	name = "CabinO2Port"
	add_to_group("cabin_o2_port")
	set_meta("interaction_target", self)
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	MHPalette.apply(model)
	_needle = model.find_child("dial_needle_pivot", true, false) as Node3D
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.66, .66, .12)
	shape.shape = box
	shape.position = Vector3(0, .12, .06)
	add_child(shape)

func fraction() -> float:
	var core: RefCounted = cabin.core if cabin != null else null
	if core == null or float(core.tank_cap) <= 0.0: return 0.0
	return clampf(float(core.tank_o2_kg) / float(core.tank_cap), 0.0, 1.0)

func interaction_prompt() -> Dictionary:
	var core: RefCounted = cabin.core if cabin != null else null
	var label := "Cabin oxygen"
	if core != null:
		var hours := float(core.tank_o2_kg) / maxf(.001, MHResources.setting("o2_per_person", .84) / 24.0)
		label += " · about %s" % ("%d h" % roundi(hours) if hours < 48.0 else "%.0f sols" % (hours / 24.0))
	return {"label": label}

func interact(_player: Node = null) -> bool:
	return false

func plugged() -> void:
	_shown = -1.0   # the needle sweeps to the new reading

## The needle follows the tank, easing like a real gauge.
func _process(delta: float) -> void:
	if _needle == null: return
	var target := fraction()
	_shown = move_toward(maxf(_shown, 0.0), target, delta * .6)   # from empty on first sight: the gauge wakes
	_needle.rotation.z = deg_to_rad(lerpf(SWEEP, -SWEEP, _shown))
