extends SceneTree

## Frame-rate benchmark for the graphics presets (26 Oct): a furnished base,
## measured inside a room and outside, for each preset, with a screenshot of
## each. Settings are changed in memory only (never saved).
##   godot --path . --script res://tools/graphics_bench.gd -- [out_dir] [presets...]
## Run windowed at the size to test (override.cfg for 1920×1080).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
var out_dir := "user://bench/"

func _put(b, id: String, at: Vector3, yaw := 0.0) -> void:
	b.place_free_interior_equipment(id, at, yaw, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), b.free_interior_visual(id, at, yaw))

func _room(kind: String, x0: int, z0: int, w: int, h: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + h): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, 1), "cost": 0}

func _measure(seconds: float) -> Dictionary:
	for i in 60: await process_frame   # settle (shaders, probes)
	var frames := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	return {"fps": frames / elapsed, "worst_ms": worst}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out_dir = args[0].trim_suffix("/") + "/"
	var presets: Array = args.slice(1) if args.size() > 1 else ["low", "medium", "high", "ultra"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	world.set_tutorial_mode("off")
	world.lander.place_at(Vector2(-24, -20))
	var b = world.builder
	b.zones = [_room("living", 4, -2, 3, 2), _room("galley", 7, -2, 3, 2), _room("medical", 10, -2, 2, 2),
		_room("life_support", 4, 0, 3, 2), _room("engineering", 7, 0, 3, 2), _room("hydroponics", 10, 0, 2, 2),
		{"kind": "airlock", "cells": [Vector2i(8, 2)], "door_direction": Vector2i(0, 1), "cost": 0}]
	for i in 6: b.zones.append({"kind": "solar", "cells": [Vector2i(3 + (i % 3) * 2, 5 + (i / 3) * 2)], "door_direction": Vector2i(0, 1), "cost": 0})
	b._rebuild()
	for door in [[Vector2i(6, -1), Vector2i(1, 0)], [Vector2i(9, -1), Vector2i(1, 0)], [Vector2i(8, -1), Vector2i(0, 1)], [Vector2i(5, -1), Vector2i(0, 1)], [Vector2i(9, 1), Vector2i(1, 0)]]:
		b.place_interior_door(door[0], door[1])
	var y: float = b.habitat_base_y
	_put(b, "galley_table_set", Vector3(24.0, y, -4.2))
	_put(b, "galley_kitchenette", Vector3(24.0, y, -6.9), PI)
	_put(b, "crew_bunk", Vector3(11.6, y, -6.6), PI)
	_put(b, "crew_bunk", Vector3(14.6, y, -6.6), PI)
	_put(b, "lounge_sofa", Vector3(15.5, y, -3.0), 0.0)
	_put(b, "arcade_cabinet", Vector3(18.0, y, -6.9), PI)
	for i in 3: _put(b, "grow_tray", Vector3(29.8 + i * 1.9, y, 0.2))
	_put(b, "battery_bank", Vector3(20.5, y, 3.8))
	world.day_night.set_hour(16.0); world.day_night.frozen = true
	var p: Node3D = world.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var views := {
		"inside": [Vector3(13.0, y + .2, -2.4), deg_to_rad(-30), -6.0],
		"outside": [Vector3(30.0, MHSiteTerrain.height(30, 22) + 1.0, 22.0), deg_to_rad(32), -4.0],
		"airlock": [Vector3(24.0, y + .2, 4.6), PI, -50.0],
	}
	var report := []
	for preset in presets:
		# "low+ssao+reflections=probes": a preset with some settings changed.
		var parts: Array = str(preset).split("+")
		var values: Dictionary = MHGame.settings()
		for key in MHGame.PRESETS[parts[0]]: values[key] = MHGame.PRESETS[parts[0]][key]
		values["preset"] = parts[0]
		for change in parts.slice(1):
			if str(change).begins_with("!"): continue
			if str(change).contains("="):
				var kv: Array = str(change).split("=")
				var v = kv[1]
				if str(v).is_valid_float(): v = float(v)
				values[kv[0]] = v
			else: values[change] = true
		values["dynamic_resolution"] = false
		MHGame._settings = values   # in memory only
		world._apply_settings()
		# Look-development switches: "!aces" (old tone mapping), "!noae" (no
		# auto exposure).
		var env: Environment = world.environment.world_environment.environment
		env.tonemap_mode = Environment.TONE_MAPPER_ACES if parts.has("!aces") else Environment.TONE_MAPPER_AGX
		(world.environment.world_environment.camera_attributes as CameraAttributesPractical).auto_exposure_enabled = not parts.has("!noae")
		if parts.has("!storm"):
			world.weather.set_process(false)
			world.environment.storm = 1.0
		if parts.has("!noocc"): env.sdfgi_use_occlusion = false
		if parts.has("!lowgi"): env.sdfgi_energy = .15
		if parts.has("!cell"): env.sdfgi_min_cell_size = .1
		for view in views:
			p.global_position = views[view][0]
			p.rotation.y = views[view][1]
			(p.get_node("Head") as Node3D).rotation.x = deg_to_rad(views[view][2])
			var result := await _measure(4.0)
			root.get_texture().get_image().save_png(out_dir + "%s_%s.png" % [str(preset).replace("=", "-").replace("!", "x"), view])
			var lit := get_nodes_in_group("room_fixture_light").filter(func(l): return l.visible and l.light_energy > .5).size()
			var line := "%-7s %-8s %6.1f fps   worst frame %5.1f ms   ceiling lights on %d" % [preset, view, result.fps, result.worst_ms, lit]
			print("BENCH ", line)
			report.append(line)
	print("ADAPTER ", RenderingServer.get_video_adapter_name())
	quit()
