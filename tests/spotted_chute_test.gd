extends SceneTree

# Rao's parachute (scripts/descent.gd, storm_drop.gd, crew_lander.gd): when he
# spots it on the way down it's picked on high ground 300–480 m ahead of the
# landing point; the landed game puts the storm drop at that same spot and
# turns the lander's hatch to face it. Run with:
# godot --headless --path . --script res://tests/spotted_chute_test.gd

const DESCENT := preload("res://scripts/descent.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	# The descent's frame: its site origin is the landing oval's centre.
	var centre := Vector2(300.0, -200.0)
	var terrain := preload("res://scripts/site_terrain.gd")
	MHGame.base_site = {"centre": [centre.x, centre.y], "height": terrain.RegionTerrain.height(centre.x, centre.y), "label": "descent"}
	var spot: Vector3 = DESCENT.pick_chute(Vector2.ZERO)
	var flat := Vector2(spot.x, spot.z)
	_check(not is_inf(spot.x) and flat.length() >= 290.0 and flat.length() <= 490.0, "the chute is 300–480 m from the landing point (%.0f m)" % flat.length())
	_check(spot.z < 0.0 and absf(spot.x) < -spot.z * 1.1, "on the side the descent camera looks towards")

	# Land 50 m from the oval's centre: the world's site origin is the touchdown.
	var touchdown := centre + Vector2(50, 0)
	MHGame.spotted_chute = Vector3(spot.x + centre.x, 0.0, spot.z + centre.y)
	MHGame.base_site = MHBaseSite.make(touchdown.x, touchdown.y, "Chute")
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	var drop = world.storm_drop
	if drop == null:
		print("FAIL no storm drop"); quit(1); return
	var expected := Vector2(spot.x + centre.x, spot.z + centre.y) - touchdown
	_check(drop != null and Vector2(drop.ridge.x, drop.ridge.z).distance_to(expected) < 1.0, "the storm drop lies where Rao spotted it (%s vs %s)" % [str(Vector2(drop.ridge.x, drop.ridge.z)), str(expected)])
	var lander: Node3D = world.lander
	var facing := -lander.global_transform.basis.z
	var to_chute: Vector3 = (drop.ridge - lander.global_position) * Vector3(1, 0, 1)
	_check(Vector2(facing.x, facing.z).normalized().dot(Vector2(to_chute.x, to_chute.z).normalized()) > .99, "the hatch faces the parachute")
	_check(is_inf(MHGame.spotted_chute.x), "the spot is used once")
	if failures == 0:
		print("Spotted chute test passed: picked ahead of the landing point, the storm drop lies there in the game, and the hatch faces it.")
	quit(1 if failures > 0 else 0)
