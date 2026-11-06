extends SceneTree

# Run with: godot --headless --path . --script res://tests/region_map_test.gd
# The region map (scripts/region_map.gd): your trail since the airlock is
# recorded while you're out and cleared when you're back in, saved with the
# colony; the map zooms towards a point, pans, and gives X/Y coordinates.

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

func _initialize() -> void:
	MHGame.site_id = "region_plains"; MHGame.game_mode = "creative"
	MHGame.base_site = {}
	MHGame.pending_save_state = {}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 30: await process_frame
	var map = world.region_map
	assert(map != null, "A region site has the region map.")
	var player: Node3D = world.player
	# Walk out: a trail point every few metres.
	map.trail.clear()
	var start := Vector3(60.0, 0.0, 60.0)
	for step in 12:
		player.global_position = start + Vector3(step * 10.0, MHSiteTerrain.height(start.x + step * 10.0, start.z) + 1.0, 0.0)
		map._trail_check = 0.0
		map._record_trail(0.1)
	assert(map.trail.size() == 12, "Twelve points for twelve 10 m steps (%d)." % map.trail.size())
	assert(absf(map._trail_length() - 110.0) < 1.0, "The trail is 110 m long (%.1f)." % map._trail_length())
	var saved: Dictionary = world.current_state()
	assert((saved.trail as PackedVector2Array).size() == 12, "The trail is saved.")
	# The map: open, zoom towards a point, pan, coordinates.
	map._open()
	assert(map.visible and bool(player.get_meta("ui_freeze", false)), "Open: you're held still.")
	var span: float = map._span
	var corner := Vector2(100.0, 100.0)
	var under: Vector2 = map._map_to_region(corner)
	map._zoom(0.5, corner)
	assert(absf(map._span - span * 0.5) < 1.0, "Zoomed in to half the width.")
	assert(map._map_to_region(corner).distance_to(under) < 1.0, "The point under the cursor stays put.")
	var centre: Vector2 = map._centre
	map._centre += Vector2(200.0, 0.0)
	map._set_view()
	assert(map._centre.x > centre.x, "It pans.")
	assert(map._coordinates(Vector2(120.0, -340.0)) == "X  +120  Y  +340", "X east, Y north (%s)." % map._coordinates(Vector2(120.0, -340.0)))
	map._process(0.016)
	assert(str(map._readout.text).begins_with("YOU  X"), "Your coordinates are on the map (%s)." % map._readout.text)
	map._markers.queue_redraw()
	await process_frame   # draws the trail without errors
	map._close()
	assert(not map.visible and not bool(player.get_meta("ui_freeze", false)), "Closed: you can move again.")
	# Back in through an airlock: the trail starts again.
	player.global_position = world.lander.global_position
	var inside: bool = map._indoors(player.global_position)
	if not inside:
		# The cabin may not be at the lander's origin: stand in a habitat room instead.
		world.builder.zones = [{"kind": "living", "cells": [Vector2i(0, 0)], "door_direction": Vector2i(0, -1), "cost": 0}]
		world.builder._rebuild()
		player.global_position = Vector3(0.0, world.builder.habitat_base_y + 0.5, 0.0)
	map._trail_check = 0.0
	map._record_trail(0.1)
	assert(map.trail.is_empty(), "Inside again: the trail is cleared.")
	print("Region map test passed: the trail out and back, saving it, zoom to the cursor, panning and coordinates.")
	quit(0)
