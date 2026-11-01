extends StaticBody3D

## One crate of the precursor cargo (docs/start-and-chapter-one.md §2),
## standing by its cargo lander. E unpacks it onto the build bar's Unpacked
## tab; I shows its manifest. No lettering: crates differ only by size.

const MHPalette := preload("res://scripts/mh_palette.gd")
## The HQ crates (asset_packs/mars_chapter_one_v1) and their outside sizes (m).
const MODELS := {
	"small": ["res://assets/equipment/mars_chapter_one_v1/models/precursor_crate_small.glb", Vector3(1.3, .95, 1.02)],
	"long": ["res://assets/equipment/mars_chapter_one_v1/models/precursor_crate_long.glb", Vector3(2.7, 1.15, 1.22)],
	"tall": ["res://assets/equipment/mars_chapter_one_v1/models/precursor_crate_tall.glb", Vector3(1.4, 2.45, 1.32)],
}

var crate_id := ""

func setup(id: String) -> StaticBody3D:
	crate_id = id
	name = "Crate_" + id
	return self

func _ready() -> void:
	collision_layer = 1
	var spec: Array = MODELS.get(str(MHChapterOne.crate(crate_id).get("size", "small")), MODELS.small)
	if ResourceLoader.exists(str(spec[0])):
		var model := (load(str(spec[0])) as PackedScene).instantiate() as Node3D
		MHPalette.apply(model)
		add_child(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = spec[1]
	shape.shape = box
	shape.position.y = box.size.y * .5
	add_child(shape)

func _manifest_text() -> String:
	var crate := MHChapterOne.crate(crate_id)
	var lines: Array = MHChapterOne.manifest_lines(crate_id)
	if crate.has("note"): lines.append(str(crate.note))
	return "\n".join(lines)

func interaction_prompt() -> Dictionary:
	return {"primary": "Unpack", "secondary": "", "label": "Crate · %s" % str(MHChapterOne.crate(crate_id).get("label", "cargo")), "info": "Manifest"}

func interact(_actor: Node = null) -> bool:
	if not MHChapterOne.unpack(crate_id): return false
	MHAudio.sfx("ui_click")
	var builder := get_tree().get_first_node_in_group("habitat_builder")
	if builder != null:
		builder.call("_flash_notice", "valid", "Unpacked: %s" % str(MHChapterOne.crate(crate_id).get("label", "crate")), ", ".join(MHChapterOne.manifest_lines(crate_id)) + ". On the build bar's Unpacked tab.")
		builder.call("_update_budget")
	queue_free()
	return true

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "Crate · %s" % str(MHChapterOne.crate(crate_id).get("label", "cargo")), _manifest_text())
	return true
