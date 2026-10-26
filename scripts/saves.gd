extends RefCounted

## Saves: every base is one named file, any number of them, in
## Documents/Outpost One/Saves. (27 Oct: replaces the six numbered slots and
## the separate habitat library with one system.)
##
## - Save (pause screen, or Ctrl+S) updates the file of the base you're in;
##   the first save of a new colony makes its file, named after the colony.
## - Save a copy makes a separate named file (a checkpoint); you keep playing
##   the original.
## - Each save first moves the file it replaces into Saves/Backups/<id>/,
##   keeping the last five, so a mistake is never fatal.
## - The title screen's Continue opens the newest save; Load opens the Saves
##   screen: cards with a picture, who made it, the mode, site and size, with
##   Play, Tour, Duplicate, Rename and Delete, and a Showcase that tours them
##   all in turn.
## - Moving bases between computers is copying the files. Each file name
##   carries a short unique tag ("Habitat One · 7F3K.save"), so folders from
##   many computers can be merged without one base replacing another.
##
## A file is two stored values: a small header (everything a card shows,
## with the picture as PNG bytes), read to list the saves, then the base's
## full state (as a save slot held it), read only to play or tour it.

const EXTENSION := "save"
const FORMAT := "outpost_one_save"
const VERSION := 2
const THUMB_SIZE := Vector2i(480, 270)
const KEEP_BACKUPS := 5
const TAG_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## Tests point the saves somewhere else, so they never touch the real ones.
static var directory_override := ""
## The file of the base being played ("" until a new colony is first saved).
static var current_path := ""
## Showcase: the saves to tour in turn, and which one is showing.
static var playlist: Array = []
static var playlist_index := 0

static func directory() -> String:
	var path := directory_override
	# Tests set MHGame.save_directory to a folder of their own; saves follow it.
	if path.is_empty() and MHGame.save_directory != MHGame.SAVE_DIRECTORY: path = ProjectSettings.globalize_path(MHGame.save_directory).path_join("named")
	if path.is_empty(): path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Outpost One").path_join("Saves")
	DirAccess.make_dir_recursive_absolute(path)
	return path

static func backups_directory(id: String) -> String:
	var path := directory().path_join("Backups").path_join(id)
	DirAccess.make_dir_recursive_absolute(path)
	return path

static func _new_tag() -> String:
	var bytes := Crypto.new().generate_random_bytes(4)
	var tag := ""
	for b in bytes: tag += TAG_LETTERS[b % TAG_LETTERS.length()]
	return tag

static func _clean(name: String) -> String:
	var clean := name.strip_edges()
	for bad in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*", "·"]: clean = clean.replace(bad, "")
	clean = clean.strip_edges().left(60)
	return clean if not clean.is_empty() else "Habitat"

## "Habitat One · 7F3K.save", made unique if that's taken.
static func _path_for(name: String, id: String) -> String:
	var path := directory().path_join("%s · %s.%s" % [_clean(name), id, EXTENSION])
	var n := 2
	while FileAccess.file_exists(path):
		path = directory().path_join("%s · %s (%d).%s" % [_clean(name), id, n, EXTENSION])
		n += 1
	return path

# ---------- what a card shows ----------

## The header for a base: its name and everything the Saves screen shows.
## extra (from the running game) adds crew, sols, cargo and the mission.
static func make_header(name: String, state: Dictionary, id: String, extra := {}) -> Dictionary:
	var builder: Dictionary = state.get("builder", {})
	var rooms := 0
	for zone in builder.get("zones", []):
		if not str((zone as Dictionary).get("kind", "")) in ["solar", "reactor", "ice_extractor", "regolith_intake", "corridor", "airlock"]: rooms += 1
	var made_by: Dictionary = state.get("made_by", {})
	var header := {"format": FORMAT, "version": VERSION, "id": id, "name": name,
		"saved_at": Time.get_datetime_string_from_system(false), "saved_unix": Time.get_unix_time_from_system(),
		"colony_name": str(state.get("colony_name", "Habitat")), "emblem": str(state.get("emblem", "")),
		"statement": str(state.get("mission_statement", "")),
		"builder": str(made_by.get("name", "")), "group": str(made_by.get("group", "")),
		"site_id": str(state.get("site_id", "")), "site_name": str(state.get("site_name", "Mars")),
		"game_mode": str(state.get("game_mode", "survival")), "rooms": rooms,
		"items": (builder.get("placed_interior", []) as Array).size()}
	header.merge(extra, true)
	return header

static func _picture_bytes(picture: Image) -> PackedByteArray:
	if picture == null or picture.is_empty(): return PackedByteArray()
	var thumb := picture.duplicate() as Image
	thumb.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return thumb.save_png_to_buffer()

static func _write(path: String, header: Dictionary, state: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_var(header)
	file.store_var(state)
	return true

# ---------- saving ----------

## Saves the base being played: updates its file (backing up the old one)
## or, for a colony never saved, makes its file. A null picture keeps the
## last one (autosaves don't hide the HUD to take a new picture). Returns
## the path, or "" if it couldn't be written.
static func save_current(state: Dictionary, picture: Image = null, extra := {}) -> String:
	var old := read_header(current_path) if not current_path.is_empty() and FileAccess.file_exists(current_path) else {}
	var id := str(old.get("id", "")) if not old.is_empty() else _new_tag()
	var name := str(old.get("name", state.get("colony_name", "Habitat"))) if not old.is_empty() else str(state.get("colony_name", "Habitat"))
	var header := make_header(name, state, id, extra)
	var bytes := _picture_bytes(picture)
	if not bytes.is_empty(): header["thumbnail"] = bytes
	elif old.has("thumbnail"): header["thumbnail"] = old.thumbnail
	var path := current_path if not old.is_empty() else _path_for(name, id)
	if not old.is_empty(): _back_up(path, id)
	if not _write(path, header, state): return ""
	current_path = path
	return path

## A separate named copy (a checkpoint). You keep playing the original.
static func save_copy(name: String, state: Dictionary, picture: Image = null, extra := {}) -> String:
	var id := _new_tag()
	var header := make_header(_clean(name), state, id, extra)
	var bytes := _picture_bytes(picture)
	if not bytes.is_empty(): header["thumbnail"] = bytes
	var path := _path_for(name, id)
	return path if _write(path, header, state) else ""

static func _back_up(path: String, id: String) -> void:
	var folder := backups_directory(id)
	DirAccess.copy_absolute(path, folder.path_join("%d.%s" % [Time.get_unix_time_from_system() * 1000.0, EXTENSION]))
	var kept := Array(DirAccess.get_files_at(folder))
	kept.sort()
	while kept.size() > KEEP_BACKUPS:
		DirAccess.remove_absolute(folder.path_join(str(kept.pop_front())))

# ---------- reading ----------

## Every save: its header plus "path" and "modified", newest first.
static func entries() -> Array:
	var out: Array = []
	var dir := directory()
	for file_name in DirAccess.get_files_at(dir):
		if file_name.get_extension().to_lower() != EXTENSION: continue
		var path := dir.path_join(file_name)
		var header := read_header(path)
		if header.is_empty(): continue
		header["path"] = path
		header["modified"] = FileAccess.get_modified_time(path)
		out.append(header)
	out.sort_custom(func(a, b): return float(a.get("saved_unix", a.modified)) > float(b.get("saved_unix", b.modified)))
	return out

## The newest save (of one mode group, "missions" or "free_play", if given).
static func latest(group := "") -> Dictionary:
	for header in entries():
		if group.is_empty() or MHGame.save_set_for_mode(str(header.game_mode)) == group: return header
	return {}

static func read_header(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var header = file.get_var()
	if not header is Dictionary or str(header.get("format", "")) != FORMAT: return {}
	return header

static func read_state(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var header = file.get_var()
	if not header is Dictionary or str(header.get("format", "")) != FORMAT: return {}
	var state = file.get_var()
	return state as Dictionary if state is Dictionary else {}

static func thumbnail(header: Dictionary) -> Texture2D:
	var bytes = header.get("thumbnail", null)
	if not bytes is PackedByteArray or (bytes as PackedByteArray).is_empty(): return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return null
	return ImageTexture.create_from_image(image)

## "Missions · Mission 7 of 10", "Creative"…
static func mode_label(header: Dictionary) -> String:
	var mode := MHGame.normalise_mode(str(header.get("game_mode", "survival")))
	var label := str(MHGame.GAME_MODES.get(mode, "Missions"))
	if mode == "missions" and not str(header.get("mission", "")).is_empty(): label += " · " + str(header.mission)
	return label

# ---------- the Saves screen's actions ----------

## Opens a save: Play (later saves update this file) or Tour (never saved).
static func prepare_load(path: String, tour := false) -> bool:
	var state := read_state(path)
	if state.is_empty(): return false
	MHGame.showcase = tour
	current_path = "" if tour else path
	return MHGame.prepare_state_load(state)

static func remove(path: String) -> bool:
	if current_path == path: current_path = ""
	return DirAccess.remove_absolute(path) == OK

## Gives a save a new name (its file is renamed to match; its tag stays).
static func rename(path: String, new_name: String) -> String:
	var header := read_header(path)
	var state := read_state(path)
	if header.is_empty(): return ""
	header["name"] = _clean(new_name)
	var target := _path_for(new_name, str(header.id))
	if not _write(target, header, state): return ""
	if target != path: DirAccess.remove_absolute(path)
	if current_path == path: current_path = target
	return target

## A copy of a save under "<name> copy", as its own base.
static func duplicate_save(path: String) -> String:
	var header := read_header(path)
	var state := read_state(path)
	if header.is_empty(): return ""
	header["id"] = _new_tag()
	header["name"] = "%s copy" % str(header.get("name", "Habitat"))
	var target := _path_for(str(header.name), str(header.id))
	return target if _write(target, header, state) else ""

# ---------- bringing files in ----------

## Adds dropped files: saves from another computer (copied in, renamed if
## the name's taken), and the older formats: a .habitat from the library
## that came before, or a numbered slot_N.save. Returns how many were added.
static func import_files(paths: PackedStringArray) -> int:
	var added := 0
	for path in paths:
		if path.get_base_dir().simplify_path() == directory().simplify_path(): continue
		var header := read_header(path)
		if not header.is_empty():
			if DirAccess.copy_absolute(path, _path_for(str(header.get("name", "Habitat")), str(header.get("id", _new_tag())))) == OK: added += 1
			continue
		if _import_old(path, ""): added += 1
	return added

## An older file (a library .habitat or a slot .save) as a save. Returns the
## new path, or "".
static func _import_old(path: String, fallback_name: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var first = file.get_var()
	if not first is Dictionary: return ""
	var state := {}
	var name := fallback_name
	var thumb = null
	if str(first.get("format", "")) == "outpost_one_habitat":
		var second = file.get_var()
		if not second is Dictionary: return ""
		state = second
		name = str(first.get("name", name))
		thumb = first.get("thumbnail", null)
	elif first.get("state", null) is Dictionary:
		state = first.state
	else:
		return ""
	if name.is_empty(): name = str(state.get("colony_name", "Habitat"))
	var id := _new_tag()
	var header := make_header(name, state, id)
	if thumb is PackedByteArray: header["thumbnail"] = thumb
	var target := _path_for(name, id)
	return target if _write(target, header, state) else ""

## Once: the old numbered slots and the old habitat library become saves.
## The old files are left where they were.
static func migrate_once() -> int:
	var flag := "user://saves_v2_migrated"
	# Only the real saves: tests use their own folders and must never copy in.
	if FileAccess.file_exists(flag) or not directory_override.is_empty() or MHGame.save_directory != MHGame.SAVE_DIRECTORY: return 0
	var moved := 0
	for save_set in MHGame.SAVE_SETS:
		for slot in range(1, MHGame.SAVE_SLOT_COUNT + 1):
			var path := ProjectSettings.globalize_path(MHGame._save_path(slot, save_set))
			if not FileAccess.file_exists(path): continue
			var payload := MHGame.load_habitat(slot, save_set)
			var colony := str((payload.get("state", {}) as Dictionary).get("colony_name", "Habitat"))
			if not _import_old(path, colony).is_empty(): moved += 1
	var library := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Outpost One").path_join("Habitats")
	if DirAccess.dir_exists_absolute(library):
		for file_name in DirAccess.get_files_at(library):
			if file_name.get_extension() == "habitat" and not _import_old(library.path_join(file_name), "").is_empty(): moved += 1
	var done := FileAccess.open(flag, FileAccess.WRITE)
	if done != null: done.store_string("moved %d" % moved)
	return moved
