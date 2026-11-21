extends Node

## GAR-Y's hitch bracket (opening slice, docs/opening-slice.md §4a Scene 3):
## the first GAR-Y fitting, found in the tools pallet. With it in your kit, E
## on GAR-Y fits it to its rear mount, and from then on it shows there and
## GAR-Y can tow (scripts/lifepod.gd sled_takes reads prints["hitch"]).
## A stand-in bracket until the model arrives (docs/assets-chunk1.md §2);
## it looks for a "RearMount" node on GAR-Y's model first.

const MHPalette := preload("res://scripts/mh_palette.gd")
const REAR_FALLBACK := Vector3(0, .32, .62)   # behind GAR-Y (its front is -Z)

var world: Node
var have := false        # in your kit, not fitted yet
var fitted := false
var _shown: Node3D

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "HitchBracket"
	add_to_group("interaction_claims")
	have = bool(saved.get("have", false))
	fitted = bool(saved.get("fitted", false))
	if fitted: _show_on_gary.call_deferred()

func export_state() -> Dictionary:
	return {"have": have, "fitted": fitted}

func found() -> void:
	if fitted: return
	have = true

func claim(target: Node, method_name: String) -> bool:
	if method_name != "interact" or not have or fitted or target == null or not target.is_in_group("gar_y"): return false
	fit()
	return true

func claim_label(target: Node) -> String:
	return "Fit the hitch bracket" if have and not fitted and target != null and target.is_in_group("gar_y") else ""

func fit() -> void:
	have = false
	fitted = true
	var pod: Node = world.get("lifepod")
	if pod != null: pod.prints["hitch"] = true
	_show_on_gary()
	MHAudio.sfx("suit_clamp", -4.0)
	var gary: Node3D = world.get("scout_rover")
	if gary != null: gary.call("_say", "happy")

func _show_on_gary() -> void:
	var gary: Node3D = world.get("scout_rover")
	if gary == null or not is_instance_valid(gary) or (_shown != null and is_instance_valid(_shown)): return
	var mount: Node3D = gary.find_child("RearMount", true, false) as Node3D
	_shown = MeshInstance3D.new()
	_shown.name = "HitchBracket"
	var box := BoxMesh.new()
	box.size = Vector3(.3, .2, .2)
	(_shown as MeshInstance3D).mesh = box
	var source := StandardMaterial3D.new()
	source.resource_name = "orange"
	(_shown as MeshInstance3D).material_override = MHPalette.material(source)
	if mount != null:
		mount.add_child(_shown)
	else:
		gary.add_child(_shown)
		_shown.position = REAR_FALLBACK
