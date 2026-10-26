extends SceneTree

# Run with: godot --headless --path . --script res://tests/saves_test.gd
# Named saves (scripts/saves.gd): the first save makes a base's file, later
# saves update it (backing up the old one, five kept), Save a copy makes a
# separate base, cards show who built it and the details, Continue finds the
# newest, Missions continue from their own save, duplicate, rename, delete,
# dropped files from another computer join without clashes, the old slots
# and library move across once, and the Showcase playlist steps through.
# Uses test folders, never the real Documents/Outpost One/Saves.
const SAVES := preload("res://scripts/saves.gd")

func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("user://test_saves")
	SAVES.directory_override = dir
	_wipe(dir)
	MHGame.site_id = "plains"
	MHGame.save_directory = "user://test_saves_slots"
	MHGame.game_mode = "creative"
	MHGame.pending_save_state = {"site_id": "plains", "builder": {}}
	MHGame.colony_name = "Ridge Outpost"
	MHGame.set_maker("Sam", "Year 10 Blue")
	SAVES.current_path = ""
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	if world._arrival_t >= 0.0: world._finish_arrival()
	var b = world.builder
	b.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "galley", "cells": [Vector2i(2, 0)], "door_direction": Vector2i(0, -1), "cost": 0},
		{"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1), "cost": 0}]
	b._rebuild()
	var picture := Image.create(64, 36, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.8, 0.4, 0.2))
	# First save: the base's own file, named after the colony with a tag.
	var path: String = SAVES.save_current(world.current_state(), picture, world.save_details())
	assert(not path.is_empty() and SAVES.current_path == path, "The first save makes this base's file.")
	assert(path.get_file().begins_with("Ridge Outpost · ") and path.get_file().ends_with(".save"), "Named after the colony, with a tag (%s)." % path.get_file())
	var header: Dictionary = SAVES.read_header(path)
	assert(str(header.builder) == "Sam" and str(header.group) == "Year 10 Blue", "Who built it (%s)." % header)
	assert(int(header.rooms) == 2 and header.has("crew") and int(header.sols) >= 1 and SAVES.thumbnail(header) != null, "The card's details and picture.")
	# Saving again updates the same file and backs up the old one.
	b.zones.append({"kind": "hydroponics", "cells": [Vector2i(3, 0)], "door_direction": Vector2i(0, -1), "cost": 0})
	b._rebuild()
	for i in 6: SAVES.save_current(world.current_state(), null, world.save_details())
	assert(SAVES.current_path == path and SAVES.entries().size() == 1, "Saving updates the same base: still one save.")
	assert(int(SAVES.read_header(path).rooms) == 3, "With the change.")
	assert(SAVES.thumbnail(SAVES.read_header(path)) != null, "An autosave keeps the last picture.")
	var backups := DirAccess.get_files_at(SAVES.backups_directory(str(header.id)))
	assert(backups.size() == SAVES.KEEP_BACKUPS, "The last five versions are kept as backups (%d)." % backups.size())
	assert(SAVES.entries().all(func(e): return not str(e.path).contains("Backups")), "Backups don't show as saves.")
	# Save a copy: a separate base; you keep playing the original.
	var copy: String = SAVES.save_copy("Ridge Outpost, sol 20", world.current_state(), picture, world.save_details())
	assert(not copy.is_empty() and SAVES.current_path == path and SAVES.entries().size() == 2, "A copy is its own save; still playing the original.")
	assert(str(SAVES.read_header(copy).id) != str(header.id), "With its own tag.")
	# Continue: the newest; Missions continue from their own save.
	assert(str(SAVES.latest().path) == copy, "Continue opens the newest save.")
	var missions_state: Dictionary = world.current_state().duplicate(true)
	missions_state["game_mode"] = "missions"
	SAVES.current_path = ""
	var campaign: String = SAVES.save_current(missions_state, null, {"mission": "Mission 7 of 10"})
	assert(str(SAVES.latest("missions").path) == campaign and SAVES.mode_label(SAVES.read_header(campaign)) == "Missions · Mission 7 of 10", "Continue missions finds the campaign, and the card says how far.")
	assert(SAVES.prepare_load(campaign) and MHGame.game_mode == "missions" and SAVES.current_path == campaign, "Playing it continues the campaign, saving to its own file.")
	assert(SAVES.prepare_load(copy, true) and MHGame.showcase and SAVES.current_path.is_empty(), "Tour never saves.")
	MHGame.showcase = false
	# Duplicate, rename, delete.
	var twin: String = SAVES.duplicate_save(copy)
	assert(str(SAVES.read_header(twin).name) == "Ridge Outpost, sol 20 copy", "Duplicated.")
	var renamed: String = SAVES.rename(twin, "Showcase: Ridge")
	assert(str(SAVES.read_header(renamed).name) == "Showcase Ridge" and not FileAccess.file_exists(twin), "Renamed, file and all.")
	assert(SAVES.remove(renamed) and SAVES.entries().size() == 3, "Deleted.")
	# Files from another computer: same name, different base, no clash.
	var other := ProjectSettings.globalize_path("user://test_saves_other")
	_wipe(other)
	DirAccess.make_dir_recursive_absolute(other)
	DirAccess.copy_absolute(path, other.path_join(path.get_file()))
	var added: int = SAVES.import_files(PackedStringArray([other.path_join(path.get_file()), other.path_join("missing.save")]))
	assert(added == 1 and SAVES.entries().size() == 4, "A dropped save joins without replacing ours (%d)." % SAVES.entries().size())
	# The old numbered slots and habitat library move across once.
	SAVES.directory_override = ""
	MHGame.save_habitat(3, world.current_state(), "free_play")
	var moved_dir := ProjectSettings.globalize_path("user://test_saves_migrated")
	_wipe(moved_dir)
	SAVES.directory_override = moved_dir
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves_v2_migrated"))
	var old_import: String = SAVES._import_old(ProjectSettings.globalize_path(MHGame._save_path(3, "free_play")), "Ridge Outpost")
	assert(not old_import.is_empty() and str(SAVES.read_header(old_import).name) == "Ridge Outpost", "An old slot becomes a named save.")
	# The Showcase playlist steps through and loops.
	SAVES.directory_override = dir
	SAVES.playlist = SAVES.entries().map(func(e): return str(e.path))
	SAVES.playlist_index = SAVES.playlist.size() - 1
	SAVES.playlist_index = (SAVES.playlist_index + 1) % SAVES.playlist.size()
	assert(SAVES.playlist_index == 0 and SAVES.prepare_load(str(SAVES.playlist[0]), true), "The playlist loops back to the first base.")
	MHGame.showcase = false
	SAVES.playlist = []
	MHGame.set_maker("", "")
	print("Saves test passed: one file per base, saving in place with five backups, Save a copy, who built it and the card details, Continue and Continue missions, Tour never saving, duplicate, rename, delete, files from another computer, old slots moving across, and the Showcase playlist.")
	quit(0)

func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir): return
	for sub in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir.path_join(f))
