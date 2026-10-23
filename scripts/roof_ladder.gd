extends StaticBody3D

## A roof ladder on an outside wall (a wall upgrade, scripts/wall_upgrades.gd).
## E climbs up onto the roof, or back down when you're up there. The body
## covers the ladder from the ground to the hoops above the roof edge, so you
## can aim at it from below or from the roof.

var builder: Node
var mid := Vector2.ZERO
var outward := Vector2.ZERO
var _busy := false

func setup(target_builder: Node, wall_mid: Vector2, wall_outward: Vector2) -> void:
	builder = target_builder
	mid = wall_mid
	outward = wall_outward
	set_meta("interaction_target", self)
	add_to_group("roof_ladder")

func roof_top() -> float:
	return float(builder.habitat_base_y) + 2.975

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _on_roof() -> bool:
	var player := _player()
	return player != null and player.global_position.y > roof_top() - .5

func interaction_prompt() -> Dictionary:
	return {"label": "Roof ladder", "primary": "Climb down" if _on_roof() else "Climb up", "info": "About"}

func interact(_actor: Node = null) -> bool:
	var player := _player()
	if player == null or _busy: return false
	var to: Vector3
	if _on_roof():
		var foot := mid + outward * 1.1
		to = Vector3(foot.x, float(builder._terrain_height(Vector3(foot.x, 0, foot.y))) + .05, foot.y)
	else:
		to = _landing(mid - outward * .9)
	_climb(player, to)
	return true

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "Roof ladder",
		"A way onto the roof: for the view, checking roof shielding and kit, and spotting a dust storm coming. The rail keeps you from walking off the edge.")
	return true

## The surface to stand on at this spot on the roof (bare roof or shielding).
func _landing(at: Vector2) -> Vector3:
	var from := Vector3(at.x, roof_top() + 3.0, at.y)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0)
	query.exclude = [get_rid()]
	var player := _player()
	if player is CollisionObject3D: query.exclude.append((player as CollisionObject3D).get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var y := float((hit.position as Vector3).y) if not hit.is_empty() else roof_top()
	return Vector3(at.x, y + .05, at.y)

## Up or down the ladder: a short climb along the rungs, then a step off.
func _climb(player: Node3D, to: Vector3) -> void:
	_busy = true
	player.set_meta("ui_freeze", true)
	MHAudio.sfx("place", -10.0, .1)
	var rung := Vector3(mid.x + outward.x * .45, to.y, mid.y + outward.y * .45)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "global_position", Vector3(rung.x, player.global_position.y, rung.z), .25)
	tween.tween_property(player, "global_position", rung, .9)
	tween.tween_property(player, "global_position", to, .3)
	await tween.finished
	if "safe_position" in player: player.safe_position = to
	player.set_meta("ui_freeze", false)
	_busy = false
