extends RefCounted

## The habitat library: any number of named bases kept as files, apart from
## the six save slots. Export from the pause screen; browse, play, tour or
## copy one to a slot from the title screen's Library. Moving a base to
## another computer is just sending its file.
##
## Files live in Documents/Outpost One/Habitats as <name>.habitat:
##   1. a small header (name, site, mode, rooms, crew, cargo, when, a
##      picture as PNG bytes): all the Library reads to draw its cards;
##   2. the base's full saved state (the same as a save slot holds), read
##      only when it's played, toured or copied.
## Dropping .habitat files, or old slot_N.save files, on the title screen
## adds them to the library.

const EXTENSION := "habitat"
const FORMAT := "outpost_one_habitat"
const VERSION := 1
const THUMB_SIZE := Vector2i(480, 270)

## Tests point the library somewhere else, so they never touch the real one.
static var directory_override := ""

## Where the library lives (made if missing).
static func directory() -> String:
	var path := directory_override if not directory_override.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Outpost One").path_join("Habitats")
	DirAccess.make_dir_recursive_absolute(path)
	return path

## A file name that's safe on Windows and not already taken.
static func _free_path(name: String) -> String:
	var clean := name.strip_edges()
	for bad in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]: clean = clean.replace(bad, "")
	clean = clean.strip_edges().left(60)
	if clean.is_empty(): clean = "Habitat"
	var path := directory().path_join("%s.%s" % [clean, EXTENSION])
	var n := 2
	while FileAccess.file_exists(path):
		path = directory().path_join("%s (%d).%s" % [clean, n, EXTENSION])
		n += 1
	return path

## The summary shown on a library card, worked out from a saved state.
static func summarise(name: String, state: Dictionary) -> Dictionary:
	var builder: Dictionary = state.get("builder", {})
	var rooms := 0
	for zone in builder.get("zones", []):
		var kind := str((zone as Dictionary).get("kind", ""))
		if not kind in ["solar", "reactor", "ice_extractor", "regolith_intake", "corridor", "airlock"]: rooms += 1
	return {"format": FORMAT, "version": VERSION, "name": name,
		"saved_at": Time.get_datetime_string_from_system(false),
		"colony_name": str(state.get("colony_name", "Habitat")), "site_id": str(state.get("site_id", "")), "site_name": str(state.get("site_name", "Mars")),
		"game_mode": str(state.get("game_mode", "survival")), "rooms": rooms,
		"items": (builder.get("placed_interior", []) as Array).size()}

## Writes a base to the library; returns the file's path ("" if it failed).
static func export_habitat(name: String, state: Dictionary, picture: Image = null) -> String:
	var header := summarise(name, state)
	if picture != null and not picture.is_empty():
		var thumb := picture.duplicate() as Image
		thumb.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_LANCZOS)
		header["thumbnail"] = thumb.save_png_to_buffer()
	return _write(_free_path(name), header, state)

static func _write(path: String, header: Dictionary, state: Dictionary) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return ""
	file.store_var(header)
	file.store_var(state)
	return path

## Every habitat in the library: its header plus "path" and "modified".
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
	return out

static func read_header(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var header = file.get_var()
	if not header is Dictionary or str(header.get("format", "")) != FORMAT: return {}
	return header

## The base's saved state ({} if the file is missing or not a habitat).
static func read_state(path: String) -> Dictionary:
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

static func remove(path: String) -> bool:
	return DirAccess.remove_absolute(path) == OK

## Adds dropped files to the library: .habitat files are copied in, and a
## game's slot_N.save is turned into a habitat. Returns how many were added.
static func import_files(paths: PackedStringArray) -> int:
	var added := 0
	for path in paths:
		match path.get_extension().to_lower():
			EXTENSION:
				var header := read_header(path)
				if header.is_empty(): continue
				if path.get_base_dir().simplify_path() == directory().simplify_path(): continue
				if DirAccess.copy_absolute(path, _free_path(str(header.get("name", path.get_file().get_basename())))) == OK: added += 1
			"save":
				var file := FileAccess.open(path, FileAccess.READ)
				if file == null: continue
				var payload = file.get_var()
				if not payload is Dictionary or not (payload.get("state", null) is Dictionary): continue
				var state: Dictionary = payload.state
				var name := "%s (%s)" % [str(state.get("colony_name", "Habitat")), path.get_file().get_basename().replace("_", " ")]
				if not _write(_free_path(name), summarise(name, state), state).is_empty(): added += 1
	return added

## Gets the game ready to open a library base. It's always free play, even
## if it was exported from a Missions campaign, so playing it can never
## touch your campaign. Tour shows it without ever saving.
static func prepare_play(path: String, tour := false) -> bool:
	var state := read_state(path)
	if state.is_empty(): return false
	state = state.duplicate(true)
	if MHGame.normalise_mode(str(state.get("game_mode", "survival"))) == "missions":
		state["game_mode"] = "survival"
		state.erase("missions_progress")
	MHGame.showcase = tour
	return MHGame.prepare_state_load(state)

## Copies a library base into the first empty free-play slot. Returns the
## slot, or 0 if all six are full.
static func copy_to_slot(path: String) -> int:
	var state := read_state(path)
	if state.is_empty(): return 0
	state = state.duplicate(true)
	if MHGame.normalise_mode(str(state.get("game_mode", "survival"))) == "missions":
		state["game_mode"] = "survival"
		state.erase("missions_progress")
	for slot in range(1, MHGame.SAVE_SLOT_COUNT + 1):
		if not bool(MHGame.save_slot_summary(slot, "free_play").get("exists", false)):
			return slot if MHGame.save_habitat(slot, state, "free_play") == OK else 0
	return 0
