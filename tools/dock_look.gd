extends SceneTree

## 21 Nov: the docking port on a living room's outside wall, from inside the
## room and from outside with the HabRover backed on to it.
##   godot --path . --resolution 1280x800 --script res://tools/dock_look.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_habitats"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "vehicle_bay", "cells": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)], "door_direction": Vector2i(0, 1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	world._sync_crew_rover()
	var port: Node3D = (load("res://assets/equipment/mars_docking_port_v1/docking_port.tscn") as PackedScene).instantiate()
	world.add_child(port)
	port.global_position = Vector3(0, b._terrain_height(Vector3(0, 0, 1.3)), 1.3)
	for i in 5: await process_frame
	world.crew_rover.park_at_home(false)
	world.day_night.set_hour(10.0); world.day_night.frozen = true
	for i in 20: await physics_frame
	world.player.visible = false
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.make_current()
	var y: float = port.global_position.y
	cam.look_at_from_position(Vector3(1.6, y + 1.6, -1.0), Vector3(0, y + 1.0, 1.3))
	await _shot(out + "dock_port_inside.png")
	cam.look_at_from_position(Vector3(9.0, y + 4.0, 9.0), Vector3(0, y + 1.2, 4.0))
	await _shot(out + "dock_habrover_outside.png")
	quit()

func _shot(path: String) -> void:
	for i in 12: await process_frame
	root.get_texture().get_image().save_png(path)
