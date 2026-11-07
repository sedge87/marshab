extends Node

## Texts from the orbiter crew (data/orbiter_crew.json), once the high-gain
## antenna has lost lock at touchdown (scripts/descent.gd): short messages
## sent on the orbiter's passes, some with a photo taken from orbit. Shown at
## the top of the slate's Comms app, newest first, above Earth's messages.
##
## A photo is named, not stored: "parachute" is the storm drop's picture
## (scripts/storm_drop.gd photo()), taken again whenever the game loads.

const CREW_FILE := "res://data/orbiter_crew.json"

var world: Node
var messages: Array = []     # {id, who, text, photo, sol, hour}, oldest first
var version := 0             # bumps with each new text (the Comms page redraws)

func _ready() -> void:
	name = "OrbiterTexts"
	add_to_group("orbiter_texts")

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	messages = (saved.get("messages", []) as Array).duplicate(true)

## Sends one text, once (by id): an unread dot on Comms and a notice.
func send(id: String, who: String, text: String, photo := "") -> void:
	if has(id): return
	messages.append({"id": id, "who": who, "text": text, "photo": photo, "sol": _sol(), "hour": MHGame.sol_hour})
	version += 1
	var person := person_of(who)
	MHNotices.post("info", "%s, from orbit" % str(person.get("short", who)), text, "comms")
	MHAudio.sfx("suit_beep", -10.0)

func _sol() -> int:
	var builder: Variant = world.get("builder") if world != null else null
	if builder != null and builder.has_method("simulation"): return floori(float(builder.simulation().hours_run) / 24.0) + 1
	return 1

func has(id: String) -> bool:
	return messages.any(func(m): return str(m.id) == id)

## The newest text with a photo, or {}.
func latest_photo() -> Dictionary:
	for i in range(messages.size() - 1, -1, -1):
		if not str(messages[i].get("photo", "")).is_empty(): return messages[i]
	return {}

## A photo by name, or null while it's being taken (or with no renderer).
func photo(photo_name: String) -> Texture2D:
	if photo_name == "parachute" and world != null and world.get("storm_drop") != null:
		return world.storm_drop.photo
	if photo_name == "walker" and world != null and world.get("walker") != null:
		if world.walker.photo == null: world.walker.take_photo()   # after a load
		return world.walker.photo
	return null

static var _crew: Dictionary = {}
static func person_of(id: String) -> Dictionary:
	if _crew.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(CREW_FILE))
		if data is Dictionary:
			for person in data.get("people", []): _crew[str(person.id)] = person
	return _crew.get(id, {})

func export_state() -> Dictionary:
	return {"messages": messages.duplicate(true)}
