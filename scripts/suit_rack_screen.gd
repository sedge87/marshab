extends "res://scripts/small_screen.gd"

## The suit rack (scripts/suit.gd add-ons; docs/build-plan-2026-11-14.md A2):
## the suit's three slots and what's on the rack beside them. Take one off
## to make room, fit another for the next trip: the heater for a night walk,
## the lamp for a cave. New add-ons still clip on by themselves at a refill
## while there's a free slot; ones you've taken off stay here.

const ICONS := {"air_pack": "wind", "battery": "zap", "heater": "flame", "lamp": "lightbulb"}

func _suit() -> Node: return world.get("suit")

func _eyebrow() -> String: return "LANDER · SUIT RACK"
func _title() -> String: return "Suit add-ons"

func _signature() -> String:
	var suit := _suit()
	if suit == null: return ""
	return "%s|%s|%s" % [str(suit.addons), str(suit.waiting), str(suit.stowed)]

func _fill(into: VBoxContainer) -> void:
	var suit := _suit()
	if suit == null: return
	var fitted: Array = suit.addons
	into.add_child(MHStyle.eyebrow("ON THE SUIT · %d OF %d SLOTS" % [fitted.size(), int(suit.SLOTS)], MHStyle.TEXT_SECONDARY))
	for id in fitted:
		var info: Dictionary = suit.ADDONS[id]
		into.add_child(row(str(ICONS.get(id, "box")), str(info.name).capitalize(), str(info.says), "", MHStyle.VALID, "Take off", func() -> void: suit.take_off(id)))
	for i in int(suit.SLOTS) - fitted.size():
		into.add_child(row("circle-dashed", "Empty slot", "Fit something from the rack below.", "", MHStyle.TEXT_MUTED, "", Callable(), false, false))
	var spare: Array = (suit.waiting as Array) + (suit.stowed as Array).filter(func(id): return not (suit.waiting as Array).has(id))
	into.add_child(HSeparator.new())
	into.add_child(MHStyle.eyebrow("ON THE RACK", MHStyle.TEXT_SECONDARY))
	if spare.is_empty():
		into.add_child(MHStyle.body("Nothing spare. Print add-ons on the tiny printer once you've found their plans.", 15, MHStyle.TEXT_MUTED))
	var full := fitted.size() >= int(suit.SLOTS)
	for id in spare:
		var info: Dictionary = suit.ADDONS[id]
		var sub := str(info.says) + (" Take one off first: the slots are full." if full else "")
		into.add_child(row(str(ICONS.get(id, "box")), str(info.name).capitalize(), sub, "", MHStyle.TEXT_MUTED, "Fit", func() -> void: suit.fit_from_rack(id), true, not full))
	var bare := MHStyle.body("Bare, the suit holds about %.0f h of air and a dim lamp; nights cost more battery without the heater." % (float(suit.O2_HOURS) - float(suit.AIR_PACK_HOURS)), 14, MHStyle.TEXT_MUTED)
	bare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(bare)
