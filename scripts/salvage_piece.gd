extends StaticBody3D

## A piece of storm debris you can strip for parts (step 3b,
## scripts/lifepod.gd): wiring, brackets, a cracked panel's cells. Each piece
## gives a couple of parts once, for the lander's tiny printer.

var lifepod: Node
var index := 0                  # its place in the lifepod's list (saved)
var stripped := false

func setup(target_lifepod: Node, piece_index: int, done: bool) -> void:
	lifepod = target_lifepod
	index = piece_index
	stripped = done
	name = "Salvage"
	add_to_group("salvage_piece")
	set_meta("interaction_target", self)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .7
	shape.shape = sphere
	shape.position = Vector3(0, .35, 0)
	add_child(shape)

func interaction_prompt() -> Dictionary:
	if stripped: return {"label": "Storm debris · stripped"}
	return {"label": "Storm debris", "primary": "Strip for parts"}

func interact(_player: Node = null) -> bool:
	if stripped: return false
	stripped = true
	MHAudio.sfx_at("suit_clamp", self, -6.0, 1.2)
	lifepod.stripped(self)
	return true
