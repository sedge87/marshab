extends "res://scripts/suit_rack_screen.gd"

## The EVA station's screen (chunk 3, docs/assets-chunk3-review.md §5): two
## halves. You: the suit's add-on slots, the suit rack's own logic. GAR-Y:
## its mast, front and hitch, one fitting each or nothing. Lamps and scoop
## share the front mount. A change goes on as you next go out through the
## airlock (scripts/chunk_three.gd), so the screen says what's set and
## what's on now. The hand tools stay in your field kit; the suit bay stays
## empty for now (the suit design is still open).

func _chunk() -> Node: return world.get_tree().get_first_node_in_group("chunk_three")

func _eyebrow() -> String: return "GENERAL MODULE · EVA STATION"
func _title() -> String: return "Ready to go out"

func _signature() -> String:
	var chunk := _chunk()
	return super() + ("" if chunk == null else "|%s|%s|%s" % [str(chunk.loadout), str(chunk.on_gary), str(chunk.sled_built)])

const SLOT_TITLES := {"mast": "Mast", "front": "Front mount", "hitch": "Hitch"}
const ICONS_GARY := {"radar": "satellite", "lamps": "lightbulb", "scoop": "shovel", "sled": "truck"}

func _fill(into: VBoxContainer) -> void:
	into.add_child(MHStyle.eyebrow("YOU", MHStyle.accent))
	super(into)
	var chunk := _chunk()
	into.add_child(HSeparator.new())
	into.add_child(MHStyle.eyebrow("GAR-Y", MHStyle.accent))
	if chunk == null:
		into.add_child(MHStyle.body("GAR-Y's fittings come with the survey sled.", 15, MHStyle.TEXT_MUTED))
		return
	for slot in chunk.SLOTS:
		var choices := []
		for id in chunk.FITTINGS:
			if str(chunk.FITTINGS[id].slot) == slot and chunk.have(id): choices.append(id)
		var set_to := str(chunk.loadout[slot])
		var now := str(chunk.on_gary[slot])
		var status := "Nothing fitted" if now.is_empty() else "On GAR-Y: %s" % str(chunk.FITTINGS[now].label).to_lower()
		if set_to != now: status += " · %s at the airlock" % ("comes off" if set_to.is_empty() else "%s goes on" % str(chunk.FITTINGS[set_to].label).to_lower())
		into.add_child(MHStyle.label("%s · %s" % [str(SLOT_TITLES[slot]), status], 16, MHStyle.TEXT_SECONDARY, 700))
		if choices.is_empty():
			var none := "Nothing for it yet. The radar head comes with the survey sled." if slot == "mast" else ("The sled's still waiting for its printed fittings." if slot == "hitch" else "Nothing for it yet.")
			into.add_child(MHStyle.body(none, 14, MHStyle.TEXT_MUTED))
			continue
		for id in choices:
			var info: Dictionary = chunk.FITTINGS[id]
			var chosen: bool = set_to == id
			into.add_child(row(str(ICONS_GARY.get(id, "box")), str(info.label), str(info.says), "SET" if chosen else "", MHStyle.VALID,
				"Stow it" if chosen else "Fit it", func() -> void: chunk.choose(slot, "" if chosen else id), not chosen))
	var note := MHStyle.body("Changes go on as you step out through the airlock with GAR-Y. The hand tools stay in your field kit (1–4).", 14, MHStyle.TEXT_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(note)
