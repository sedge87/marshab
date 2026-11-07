class_name MHJournal
extends RefCounted

## The crew journal (core-loop step 5, docs/samples-lab-journal.md §7):
## written for you, a few first-person lines a sol, from what the game
## already says (chapter one's news, samples, leads, discoveries, Earth's
## replies, plans). A sol with something worth drawing outside gets a pencil
## sketch: a quiet snapshot of the view (journal_keeper.gd), drawn as pencil
## in the book by shaders/pencil_sketch.gdshader. Sketches are PNGs in
## user://journal/<id>/; the text is saved with the game.
##
## Runs with chapter one's rules, like the samples.

const DATA_PATH := "res://data/journal.json"
const SKETCHES_PER_SOL := 2
const LINES_PER_SOL := 8

static var id := ""                # this game's journal folder
static var entries: Array = []     # [{sol, lines: [String], sketches: [{path, caption}]}], oldest first
static var _written: Dictionary = {}   # "sol:event" -> true, for once-a-sol events
static var _units_seen: Dictionary = {}   # ground sampled before (a new place is worth a sketch)
static var wants_sketch := ""      # a caption, when the next quiet moment outside should be drawn
static var _data: Dictionary = {}

static func on() -> bool:
	return MHChapterOne.on()

static func reset() -> void:
	id = "%d%04d" % [Time.get_unix_time_from_system(), randi() % 10000]
	entries = []; _written = {}; _units_seen = {}; wants_sketch = ""

static func export_state() -> Dictionary:
	return {"id": id, "entries": entries.duplicate(true), "written": _written.duplicate(), "units": _units_seen.duplicate()}

static func load_state(state: Dictionary) -> void:
	reset()
	if state.is_empty(): return   # an older save: the journal starts on the sol you load it
	id = str(state.get("id", id))
	entries = (state.get("entries", []) as Array).duplicate(true)
	_written = (state.get("written", {}) as Dictionary).duplicate()
	_units_seen = (state.get("units", {}) as Dictionary).duplicate()

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data = parsed
	return _data

static func folder() -> String:
	return "user://journal/%s/" % id

static func _entry(sol: int) -> Dictionary:
	if entries.is_empty() or int(entries.back().sol) != sol: entries.append({"sol": sol, "lines": [], "sketches": []})
	return entries.back()

## Write an event's line for this sol (a variant picked by the sol).
static func write(event: String, sol: int, fills := {}) -> void:
	if not on(): return
	var spec: Dictionary = (data().get("events", {}) as Dictionary).get(event, {})
	var lines: Array = spec.get("lines", [])
	if lines.is_empty(): return
	var key := "%d:%s" % [sol, event]
	if bool(spec.get("once", false)) and _written.has(key): return
	var entry := _entry(sol)
	if (entry.lines as Array).size() >= LINES_PER_SOL: return
	_written[key] = true
	var line := str(lines[posmod(hash(key), lines.size())])
	for field in fills: line = line.replace("{%s}" % field, str(fills[field]))
	if not (entry.lines as Array).has(line): (entry.lines as Array).append(line)

## A line in your own words (an answered thought, scripts/notes.gd).
static func note(sol: int, line: String) -> void:
	if not on() or line.is_empty(): return
	var entry := _entry(sol)
	if not (entry.lines as Array).has(line): (entry.lines as Array).append(line)

## The game's messages for this sol, as journal lines; a sample from new
## ground or a cave asks for a sketch.
static func from_messages(messages: Array, sol: int) -> void:
	if not on(): return
	for message in messages:
		var title := str(message.get("title", ""))
		match str(message.get("id", "")):
			"made": write("made", sol, {"what": title.trim_prefix("Print Shop: ").trim_suffix(" printed").trim_suffix(" ready").to_lower()})
			"step", "soil", "emergency_landed": write(str(message.id), sol, {"title": title})
			"chapter_one":
				write("chapter_one", sol)
				ask_sketch("Self-sufficient")
			"plan": write("plan", sol, {"title": title, "what": title.trim_prefix("New plan: ")})
			"lead": write("lead", sol, {"title": title.trim_prefix("Lead: ").to_lower()})
			"discovery":
				var what := title.trim_prefix("Discovery: ")
				write("discovery", sol, {"what": what.to_lower()})
				ask_sketch(what)
			"reply": write("reply", sol, {"title": title.trim_prefix("Mission Control · ")})
			"sample":
				var record: Dictionary = message.get("sample", {})
				if record.is_empty(): continue
				var unit := str(record.get("unit", ""))
				var where := MHSamples.unit_label(unit)
				if bool(record.get("in_cave", false)): write("cave_sample", sol, {"where": where})
				else: write("samples", sol, {"what": MHSamples.sample_label(record), "where": where})
				if not unit.is_empty() and not _units_seen.has(unit):
					_units_seen[unit] = true
					ask_sketch(where.capitalize())

## Ask for a sketch of the view at the next quiet moment outside (at most
## SKETCHES_PER_SOL a sol).
static func ask_sketch(caption: String) -> void:
	if wants_sketch.is_empty(): wants_sketch = caption

static func sketches_on(sol: int) -> int:
	if entries.is_empty() or int(entries.back().sol) != sol: return 0
	return (entries.back().sketches as Array).size()

## A sketch was saved: put it on its sol's page.
static func add_sketch(sol: int, path: String, caption: String) -> void:
	(_entry(sol).sketches as Array).append({"path": path, "caption": caption})

# ---------- photos and your own words (the slate's camera, scripts/slate_camera.gd) ----------

static func photos_on(sol: int) -> int:
	if entries.is_empty() or int(entries.back().sol) != sol: return 0
	return (entries.back().get("photos", []) as Array).size()

## A photo from the slate: on its sol's page in colour, with a caption you can
## change, and what was in frame (`subjects`, ids).
static func add_photo(sol: int, path: String, caption: String, subjects: Array) -> Dictionary:
	var entry := _entry(sol)
	if not entry.has("photos"): entry["photos"] = []
	var record := {"path": path, "caption": caption, "subjects": subjects.duplicate()}
	(entry.photos as Array).append(record)
	return record

## Whether you've photographed this (an id from slate_camera.gd subjects()).
static func photographed(subject: String) -> bool:
	for entry in entries:
		for photo in entry.get("photos", []):
			if (photo.get("subjects", []) as Array).has(subject): return true
	return false

## Your own note on a page (typed in the book), kept with the game.
static func set_own(index: int, text: String) -> void:
	if index < 0 or index >= entries.size(): return
	entries[index]["own"] = text

static func set_caption(index: int, photo: int, text: String) -> void:
	if index < 0 or index >= entries.size(): return
	var photos: Array = entries[index].get("photos", [])
	if photo >= 0 and photo < photos.size(): photos[photo]["caption"] = text

## Today's page, so there's somewhere to write even on a quiet sol.
static func today(sol: int) -> int:
	if not on(): return entries.size() - 1
	_entry(sol)
	return entries.size() - 1
