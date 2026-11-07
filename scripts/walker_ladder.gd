extends StaticBody3D

## The ladder up Walker 1's back (scripts/walker.gd): E climbs aboard to
## ride on its rear deck, E again climbs down.

var walker: Node

func interaction_prompt() -> Dictionary:
	return walker.ladder_prompt()

func interact(_actor: Node = null) -> bool:
	return walker.climb()
