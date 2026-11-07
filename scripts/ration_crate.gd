extends Node

## The cabin's ration crate (step 4a, docs/systems-and-items.md §1.5): the
## small supply crate by the airlock. Its packs are counted by the lifepod
## (scripts/lifepod.gd, saved with it): two from the descent, and pallet 1's
## ten once you've brought them home. E eats one; hunger (scripts/body.gd)
## starts again from nothing. Suiting up at the lander takes one more as the
## suit's food bar (scripts/suit.gd).

var lifepod: Node

func setup(target_lifepod: Node, crate: Node) -> void:
	lifepod = target_lifepod
	name = "RationCrate"
	add_to_group("ration_crate")
	crate.add_child(self)
	crate.set_meta("interaction_target", self)
	for body in crate.find_children("*", "StaticBody3D", true, false): body.set_meta("interaction_target", self)

func interaction_prompt() -> Dictionary:
	var packs := int(lifepod.rations)
	if packs <= 0: return {"label": "Ration crate · empty"}
	var out := {"label": "Ration crate · %d pack%s" % [packs, "" if packs == 1 else "s"]}
	if MHGame.needs_food_water(): out["primary"] = "Eat a ration"
	return out

func interact(_actor: Node = null) -> bool:
	return lifepod.eat_ration()
