extends StaticBody3D

## The cabin wall's air port (scripts/lander_cabin_life.gd): a dial that
## shows how good the cabin air is (power + hull, 21 Nov: there's no tank),
## and the cradle an older game's cartridge plugs into (scripts/o2_cartridge.gd).
## No lettering: the needle, a green tick at fresh and a dark one at unsafe.

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
	if core == null: return 0.0
	return clampf(float(core.air_fraction()), 0.0, 1.0)

func interaction_prompt() -> Dictionary:
	var core: RefCounted = cabin.core if cabin != null else null
	var label := "Cabin air"
	if core != null:
		var ahead: Dictionary = cabin.ahead
		var h := float(ahead.get("air", -1.0))
		var thin := float(ahead.get("oxygen", -1.0))
		if thin >= 0.0 and (h < 0.0 or thin < h): h = thin
		if not bool(core.life_on()): label += " · life support %s" % ("off" if core.powered() else "has no power")
		elif h >= 0.0: label += " · stale in about %d h" % maxi(1, roundi(h))
		else: label += " · fresh"
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
