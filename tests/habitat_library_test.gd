extends SceneTree

# Run with: godot --headless --path . --script res://tests/habitat_library_test.gd
# The habitat library: export a base under a name, list it (header only),
# read it back, import dropped files (.habitat and a slot's .save), play a
# copy (always free play, even from Missions), copy one to a free-play slot,
# and remove one. Uses a test folder, never the real Documents library.
const LIBRARY := preload("res://scripts/habitat_library.gd")

func _initialize() -> void:
	var test_dir := ProjectSettings.globalize_path("user://test_library")
	LIBRARY.directory_override = test_dir
	for file_name in DirAccess.get_files_at(test_dir): DirAccess.remove_absolute(test_dir.path_join(file_name))
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_library_saves"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "galley", "cells": [Vector2i(2, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var state: Dictionary = world.current_state()
	var picture := Image.create(64, 36, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.8, 0.4, 0.2))
	var path: String = LIBRARY.export_habitat("Ridge: Outpost/v2?", state, picture)
	assert(not path.is_empty() and FileAccess.file_exists(path), "Exported to a file.")
	assert(path.get_file() == "Ridge Outpostv2.habitat", "A safe file name (%s)." % path.get_file())
	var second: String = LIBRARY.export_habitat("Ridge: Outpost/v2?", state, null)
	assert(second.get_file() == "Ridge Outpostv2 (2).habitat", "The same name again doesn't overwrite (%s)." % second.get_file())
	var entries: Array = LIBRARY.entries()
	assert(entries.size() == 2, "Both are in the library.")
	var header: Dictionary = entries.filter(func(e): return str(e.path) == path)[0]
	assert(int(header.rooms) == 2 and str(header.site_id) == "plains" and str(header.name) == "Ridge: Outpost/v2?", "The card's summary: 2 rooms on the plains (%s)." % header)
	assert(LIBRARY.thumbnail(header) != null, "With its picture.")
	var back: Dictionary = LIBRARY.read_state(path)
	assert((back.builder.zones as Array).size() == 3, "The whole base reads back.")
	# Removing one.
	assert(LIBRARY.remove(second) and LIBRARY.entries().size() == 1, "Removed.")
	# Importing: a .habitat from elsewhere, and a game's slot save.
	var elsewhere := ProjectSettings.globalize_path("user://test_library_drop")
	DirAccess.make_dir_recursive_absolute(elsewhere)
	DirAccess.copy_absolute(path, elsewhere.path_join("from a friend.habitat"))
	MHGame.save_habitat(2, state, "free_play")
	var slot_file := ProjectSettings.globalize_path(MHGame._save_path(2, "free_play"))
	var added: int = LIBRARY.import_files(PackedStringArray([elsewhere.path_join("from a friend.habitat"), slot_file, elsewhere.path_join("notes.txt")]))
	assert(added == 2 and LIBRARY.entries().size() == 3, "Dropped files join the library (%d added)." % added)
	# A Missions base plays as free play, so it can't touch the campaign.
	var missions_state := state.duplicate(true)
	missions_state["game_mode"] = "missions"
	missions_state["missions_progress"] = {"current": "solar_shelter"}
	var missions_path: String = LIBRARY.export_habitat("Campaign base", missions_state)
	assert(LIBRARY.prepare_play(missions_path), "Ready to play.")
	assert(MHGame.game_mode == "survival" and not MHGame.pending_save_state.has("missions_progress") and not MHGame.showcase, "As free play, not Missions.")
	assert(LIBRARY.prepare_play(path, true) and MHGame.showcase, "Tour plays a copy that's never saved.")
	MHGame.showcase = false
	# Copy to the first empty free-play slot.
	for slot in range(1, MHGame.SAVE_SLOT_COUNT + 1): MHGame.delete_habitat(slot, "free_play")
	MHGame.save_habitat(1, state, "free_play")
	assert(LIBRARY.copy_to_slot(path) == 2, "Copied to slot 2, the first empty one.")
	# Loading it for real: the world rebuilds the exported base.
	MHGame.game_mode = "creative"
	assert(LIBRARY.prepare_play(path))
	world.queue_free()
	for i in 3: await process_frame
	var again = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(again)
	for i in 10: await process_frame
	assert((again.builder.zones as Array).size() == 3, "Playing it opens the same base (%d zones)." % again.builder.zones.size())
	print("Habitat library test passed: export with a safe unique name, the card summary and picture, reading back, removing, importing .habitat and .save files, Missions bases as free play, Tour, copying to a slot, and playing it.")
	quit(0)
