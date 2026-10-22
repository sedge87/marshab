extends SceneTree

# Outside camera masts (backlog 28): placed outdoors (up to 4), the head pans
# and tilts and the aim is saved, the view comes from up high at the lens,
# the Cameras view opens live and aims/switches masts, wall screens have a
# camera mode, and Mission 4 delivers them.
# Run with: godot --headless --path . --script res://tests/camera_mast_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _place(b: BuildController, at: Vector3) -> bool:
	at.y = b._terrain_height(at)
	if not b.surface_invalid_reason("camera_mast", at).is_empty(): return false
	var visual := b.surface_visual("camera_mast", at, 0.0)
	return b.place_surface_equipment("camera_mast", at, 0.0, visual)

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	var b: BuildController = world.builder
	_check(not b.surface_entry("camera_mast").is_empty(), "the camera mast is an outdoor item")
	_check(_place(b, Vector3(20, 0, 20)), "a mast can be placed outside")
	for i in 3: await process_frame
	var masts: Array = get_nodes_in_group("camera_mast")
	_check(masts.size() == 1, "it has a pan-tilt head (%d)" % masts.size())
	var mast = masts[0] if not masts.is_empty() else null
	if mast == null:
		quit(1)
		return

	# Aim: the head turns, and the aim is saved with the base.
	mast.set_aim(1.0, -.3)
	_check(is_equal_approx((mast._cam.yaw as Node3D).rotation.y, 1.0) and is_equal_approx((mast._cam.tilt as Node3D).rotation.x, -.3), "the head pans and tilts")
	var placement_id: String = mast._placement_id()
	var saved: Dictionary = b.interior_state(placement_id)
	_check(is_equal_approx(float(saved.get("cam_yaw", 0.0)), 1.0), "the aim is saved (%s)" % [saved])
	mast.set_aim(0.0, 1.5)
	_check(mast.aim().y <= deg_to_rad(35.0) + .001, "tilt is limited")
	# The view is from up high, and turns with the head.
	mast.set_aim(0.0, 0.0)
	var view: Transform3D = mast.camera_view()
	_check(view.origin.y - b._terrain_height(Vector3(20, 0, 20)) > 5.5, "the view is from the top of the pole (%.1f m)" % (view.origin.y - b._terrain_height(Vector3(20, 0, 20))))
	var ahead := -view.basis.z
	mast.set_aim(PI * .5, 0.0)
	var turned: Vector3 = -(mast.camera_view() as Transform3D).basis.z
	_check(absf(ahead.dot(turned)) < .1, "a quarter turn faces a quarter round")

	# Up to four per base.
	for x in [26, 32, 38]: _place(b, Vector3(x, 0, 20))
	_check(b.surface_invalid_reason("camera_mast", Vector3(44, b._terrain_height(Vector3(44, 0, 20)), 20)).contains("Up to 4"), "a fifth mast isn't allowed")

	# The Cameras view: live, aims the mast, switches masts.
	world.open_cameras(mast)
	await process_frame
	await process_frame
	var cams = world.monitor
	_check(cams != null and not paused and bool(world.player.get_meta("ui_freeze", false)), "the Cameras view opens live, you standing still")
	var before: Vector2 = mast.aim()
	cams._turn(.5, 0.0)
	_check(absf(mast.aim().x - before.x - .5) < .01, "aiming in the view turns the mast")
	mast.set_camera_setting("cam_sweep", true)
	cams._turn(.1, 0.0)
	_check(not bool(mast.camera_setting("cam_sweep", true)), "aiming stops auto-sweep")
	var tab := InputEventKey.new(); tab.keycode = KEY_TAB; tab.pressed = true
	cams._unhandled_input(tab)
	_check(cams.mast != mast, "Tab moves to the next mast")
	cams._close()
	await process_frame
	await process_frame
	_check(world.monitor == null and not bool(world.player.get_meta("ui_freeze", false)), "closing frees you")

	# Wall screens and missions.
	var modes: Array = EquipmentCatalog.rig("wall_screen").actions[0].modes
	_check(modes.has("camera"), "wall screens have a camera mode")
	_check((MHMissions.get_mission("crew_land").get("unlock_items", []) as Array).has("camera_mast"), "Mission 4 delivers camera masts")
	_check(EquipmentCatalog.rig("camera_mast").actions[0].type == "camera", "E on a mast looks through it")

	if failures == 0:
		print("Camera mast test passed: placing (up to 4), pan/tilt and saved aim, view from the top, live Cameras view, wall screens, Mission 4.")
	quit(1 if failures > 0 else 0)
