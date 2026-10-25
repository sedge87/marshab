extends SceneTree

# Run with: godot --headless --path . --script res://tests/gary_snap_test.gd
# 25 Oct playtest batch: GAR-Y tidies (floor clutter onto a free table or
# shelf), goes to look at the trouble when an alert goes up and at new things
# placed nearby; holding Shift snaps furniture to a 25 cm grid and right
# angles; Ctrl+Z in Interior takes furniture back; the compact reactor makes
# 8 kW.

const MHResources := preload("res://scripts/mh_resources.gd")

var failures := 0

func _check(ok: bool, what: String) -> void:
	if ok: return
	failures += 1
	print("FAIL ", what)

func _put(b, id: String, at: Vector3) -> Dictionary:
	b.place_free_interior_equipment(id, at, 0.0, Vector2i(roundi(at.x / 3), roundi(at.z / 3)), b.free_interior_visual(id, at, 0.0))
	return b.placed_interior.back()

func _shift(on: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT; key.physical_keycode = KEY_SHIFT; key.pressed = on
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.save_directory = "user://test_habitats"; MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	world.player.global_position = Vector3(-40, 5, -40)

	_check(is_equal_approx(MHResources.setting("reactor_kw"), 8.0) and is_equal_approx(MHResources.item_value("surface_reactor", "makes_power_kw"), 8.0), "the compact reactor makes 8 kW")

	var cells := []
	for x in range(4, 8):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "life_support", "cells": [Vector2i(8, 0), Vector2i(9, 0), Vector2i(8, 1), Vector2i(9, 1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var y: float = b.habitat_base_y
	var gary = world.scout_rover
	_check(gary != null, "GAR-Y is here")
	if gary == null:
		quit(1)
		return
	gary.global_position = Vector3(16.0, y + .05, 3.0)
	gary.task = ""
	gary._seen_items = b.placed_interior.size()

	# Tidying: a mug on the floor goes onto the table.
	_put(b, "common_table", Vector3(14.0, y, 1.0))
	gary._seen_items = b.placed_interior.size()
	var mug := _put(b, "crew_mug", Vector3(18.0, y, 4.0))
	gary._seen_items = b.placed_interior.size()
	_check(gary._clutter_candidates().any(func(i): return str(i.id) == "crew_mug"), "a mug on the floor counts as clutter")
	var spot: Dictionary = gary._tidy_spot(str(mug.placement_id), mug.position)
	_check((spot.position as Vector3).y > y + .5, "the tidy spot is up on the table, not the floor (%s)" % spot.position)
	_check(b.free_interior_move_reason(str(mug.placement_id), spot.position, float(spot.yaw)).is_empty(), "and it's a legal spot")
	_check(gary.start_fetch() and str(gary.task) == "fetch", "a tidy-up starts with the floor clutter")
	gary._end_task()

	# Reacting: an oxygen alert sends it to the oxygen generator.
	var generator := _put(b, "oxygen_generator", Vector3(25.5, y, 1.5))
	gary._seen_items = b.placed_interior.size()
	gary.on_habitat_alert("o2", "critical")
	_check(str(gary.task) == "inspect" and (gary.task_data.at as Vector3).distance_to(generator.position) < .01, "an oxygen alert sends GAR-Y to the oxygen generator (%s)" % gary.task)
	_check(str(gary.status_text()).contains("oxygen generator"), "and it says so (%s)" % gary.status_text())
	gary.on_habitat_alert("o2", "critical")
	gary._end_task()
	gary.on_habitat_alert("o2", "critical")
	_check(str(gary.task) == "", "it doesn't rush back for the same alert straight away")
	gary._inspected.clear()
	gary.on_habitat_alert("power", "advisory")
	_check(str(gary.task) == "", "advisories don't send it anywhere")

	# Something new placed nearby: it goes to look.
	_put(b, "crew_bunk", Vector3(14.0, y, 5.0))
	_check(gary._look_at_new_thing() and str(gary.task) == "look", "a new bunk nearby: GAR-Y goes to look")
	gary._end_task()

	# Shift snaps furniture: 25 cm grid on the floor and along walls, right angles.
	var ib = world.interior_builder
	_shift(true)
	_check(ib.snapping(), "holding Shift snaps")
	var snapped: Vector3 = ib._grid_point(Vector3(14.13, y, 2.61), Vector3.UP)
	_check(is_equal_approx(snapped.x, 14.25) and is_equal_approx(snapped.z, 2.5), "floor points land on the 25 cm grid (%s)" % snapped)
	var on_wall: Vector3 = ib._grid_point(Vector3(10.6, y + 1.43, 2.61), Vector3(1, 0, 0))
	_check(is_equal_approx(on_wall.x, 10.6) and is_equal_approx(on_wall.y, snappedf(y + 1.43, .25)) and is_equal_approx(on_wall.z, 2.5), "wall points snap along and up the wall, not into it (%s)" % on_wall)
	ib.selected_id = "crew_bunk"
	world.player.rotation.y = .4
	var yaw: float = ib._placement_yaw(Vector3.UP)
	_check(absf(fmod(absf(yaw), PI * .5)) < .001 or absf(fmod(absf(yaw), PI * .5) - PI * .5) < .001, "floor items turn in right angles (%.3f)" % yaw)
	_shift(false)
	_check(not ib.snapping(), "letting go stops snapping")

	# Ctrl+Z in Interior takes furniture back.
	var before: int = b.placed_interior.size()
	var lamp := _put(b, "task_light", Vector3(20.0, y, 0.0))
	b._history.append({"type": "interior", "placement_id": str(lamp.placement_id)})
	_check(b.undo_last_structure() and b.placed_interior.size() == before, "Ctrl+Z in Interior removes the last thing placed")

	if failures == 0:
		print("GAR-Y and snapping test passed: the 8 kW reactor, tidying onto a table, going to the trouble, looking at new things, Shift-snap and furniture undo.")
	quit(1 if failures > 0 else 0)
