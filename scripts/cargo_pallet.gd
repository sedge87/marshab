extends StaticBody3D

## A cargo pallet from the storm (scripts/storm_drop.gd). Four latches hold
## its lid down; hold E to free them one by one (a clunk each), and the lid
## swings open on its hinge. What's inside is the drop's business.

const BODY := preload("res://assets/models/storm_cargo/pallet.glb")
const LID := preload("res://assets/models/storm_cargo/pallet_lid.glb")
const MHPalette := preload("res://scripts/mh_palette.gd")
const SIZE := Vector3(1.6, .95, 1.2)
const HOLD := 1.8              # seconds of holding E to free all four latches
const LATCHES := 4
const OPEN_DEGREES := 112.0

var drop: Node
var opened := false
var _lid_pivot: Node3D
var _held := 0.0
var _holding := false
var _freed := 0

func setup(target_drop: Node, is_open: bool) -> void:
	drop = target_drop
	name = "Pallet1"
	add_to_group("cargo_pallet")
	set_meta("interaction_target", self)
	var body: Node3D = BODY.instantiate()
	add_child(body)
	MHPalette.apply(body)
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "LidHinge"
	_lid_pivot.position = Vector3(0, SIZE.y, -SIZE.z * .5)   # hinged on the far side: it opens away from you
	add_child(_lid_pivot)
	var lid: Node3D = LID.instantiate()
	lid.rotation.y = PI
	_lid_pivot.add_child(lid)
	MHPalette.apply(lid)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector3(0, SIZE.y * .5, 0)
	add_child(shape)
	opened = is_open
	if opened:
		_lid_pivot.rotation.x = -deg_to_rad(OPEN_DEGREES)
		_freed = LATCHES

func interaction_prompt() -> Dictionary:
	if opened:
		var inside := _inside()
		return inside.interaction_prompt() if inside != null else {"label": "Pallet 1 · open"}
	if _holding and _freed > 0: return {"label": "Cargo pallet", "primary": "Freeing the latches · %d of %d" % [_freed, LATCHES]}
	return {"label": "Cargo pallet", "primary": "Hold to free the latches"}

## The cartridge, while it still lies in the open pallet. The pallet's
## solid box surrounds it, so looking into the pallet reaches it through here.
func _inside() -> Node:
	var cartridge: Node = drop.get("cartridge") if drop != null else null
	return cartridge if cartridge != null and str(cartridge.where) == "pallet" else null

func interact(_player: Node = null) -> bool:
	if opened:
		var inside := _inside()
		return inside.interact(_player) if inside != null else false
	_holding = true
	return true

func _process(delta: float) -> void:
	if not _holding: return
	var player: Node3D = drop.world.player if drop != null else null
	var still_on := Input.is_key_pressed(KEY_E) and player != null and player.global_position.distance_to(global_position) < 3.6
	if not still_on:
		_holding = false
		_held = 0.0
		_freed = 0
		return
	_held += delta
	var now := mini(LATCHES, floori(_held / HOLD * LATCHES))
	while _freed < now:
		_freed += 1
		MHAudio.sfx_at("suit_clamp", self, -4.0, .9)
	if _held >= HOLD: open()

## All four latches free: the lid swings up and back.
func open(animate := true) -> void:
	if opened: return
	opened = true
	_holding = false
	_freed = LATCHES
	if animate:
		var tween := create_tween()
		tween.tween_property(_lid_pivot, "rotation:x", -deg_to_rad(OPEN_DEGREES), 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		MHAudio.sfx_at("door_open", self, -4.0, .9)
	else:
		_lid_pivot.rotation.x = -deg_to_rad(OPEN_DEGREES)
	if drop != null: drop.pallet_opened()

## Where its contents sit, world (the cartridge rests here until taken).
func inside_point() -> Vector3:
	return to_global(Vector3(0, .52, .25))   # across the foam cradles, in front of the kit bags
