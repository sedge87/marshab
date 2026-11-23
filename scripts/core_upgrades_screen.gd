extends "res://scripts/small_screen.gd"

## The core's upgrades (docs/rooms-and-equipment.md, "Core upgrades open
## room types"; scripts/room_types.gd), on the panel beside the core rack's
## switches. Each one is a plan you've been sent or found, plus feedstock,
## fitted here; it opens room types on this base's build bar. No limit.

func _eyebrow() -> String: return "CORE · UPGRADES"
func _title() -> String: return "Open room types"

## Refolding (A4): a second press confirms.
var _refold_asked := false

func _signature() -> String:
	return "%s|%s|%s|%s" % [str(MHRoomTypes.fitted), str(MHChapterOne.known.keys()), str(floori(MHChapterOne.feedstock_kg)), _refold_asked]

func _fill(into: VBoxContainer) -> void:
	if not MHRoomTypes.gated():
		into.add_child(MHStyle.body("Every room type is open in this game.", 15, MHStyle.TEXT_SECONDARY))
		_refold_row(into)
		return
	var open: Array = MHRoomTypes.ROOMS.keys().filter(func(k): return MHRoomTypes.upgrade_for(str(k)).is_empty())
	var line := MHStyle.body("Open from the start: %s. Regolith: %s." % [", ".join(open.map(func(k): return MHRoomTypes.label(str(k)))), MHStyle.kg(floori(MHChapterOne.feedstock_kg))], 15, MHStyle.TEXT_SECONDARY)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(line)
	for id in MHRoomTypes.UPGRADES:
		var up: Dictionary = MHRoomTypes.UPGRADES[id]
		var sub := "Opens %s. %s" % [MHRoomTypes.opens_text(str(id)), str(up.says)]
		if MHRoomTypes.is_fitted(str(id)):
			into.add_child(row(str(up.icon), str(up.label), sub, "FITTED", MHStyle.VALID))
			continue
		if not MHRoomTypes.plan_known(str(id)):
			into.add_child(row(str(up.icon), str(up.label), sub, "NO PLAN", MHStyle.TEXT_MUTED, "", Callable(), false, false))
			continue
		var why := MHRoomTypes.fit_reason(str(id))
		into.add_child(row(str(up.icon), str(up.label), sub if why.is_empty() else sub + " " + why + ".", MHStyle.kg(roundi(MHRoomTypes.cost(str(id)))), MHStyle.TEXT_SECONDARY,
			"Fit", func() -> void: _fit(str(id)), true, why.is_empty()))
	_refold_row(into)

## Refold this core (A4, docs/bases-and-vehicles.md "Moving a base"): the
## walker stands up with everything back in the store, ready for a new spot.
func _refold_row(into: VBoxContainer) -> void:
	var builder: Node = world.get("builder")
	var walkers: Dictionary = world.get("walkers") if world.get("walkers") != null else {}
	var mover: Node = walkers.get(MHRoomTypes.here)
	if builder == null or mover == null: return
	var why: String = builder.refold_reason(MHRoomTypes.here)
	var sub := "Its walker stands up and carries it to a new spot you mark on the Map. Rooms, kit and materials go back into the store; the printed pads stay."
	if _refold_asked: sub = "Sure? Everything here packs away. Press again to refold."
	into.add_child(row("rotate-cw", "Refold this core", sub if why.is_empty() else why + ".", "MOVE", MHStyle.WARN if _refold_asked else MHStyle.TEXT_MUTED,
		"Refold", func() -> void: _refold(mover), _refold_asked, why.is_empty()))

func _refold(mover: Node) -> void:
	if not _refold_asked:
		_refold_asked = true
		return
	_refold_asked = false
	_close()
	mover.refold()

func _fit(id: String) -> void:
	if not MHRoomTypes.fit(id): return
	MHAudio.sfx("place")
	MHNotices.post("valid", "Core upgrade fitted: %s" % str(MHRoomTypes.UPGRADES[id].label), "%s now on the build bar's Rooms tab." % MHRoomTypes.opens_text(id), "log")
	var builder: Node = world.get("builder")
	if builder != null and builder.has_method("_refresh_catalogue"): builder.call("_refresh_catalogue")
