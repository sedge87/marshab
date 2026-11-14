extends "res://scripts/small_screen.gd"

## The core's upgrades (docs/rooms-and-equipment.md, "Core upgrades open
## room types"; scripts/room_types.gd), on the panel beside the core rack's
## switches. Each one is a plan you've been sent or found, plus feedstock,
## fitted here; it opens room types on this base's build bar. No limit.

func _eyebrow() -> String: return "CORE · UPGRADES"
func _title() -> String: return "Open room types"

func _signature() -> String:
	return "%s|%s|%s" % [str(MHRoomTypes.fitted), str(MHChapterOne.known.keys()), str(floori(MHChapterOne.feedstock_kg))]

func _fill(into: VBoxContainer) -> void:
	if not MHRoomTypes.gated():
		into.add_child(MHStyle.body("Every room type is open in this game.", 15, MHStyle.TEXT_SECONDARY))
		return
	var open: Array = MHRoomTypes.ROOMS.keys().filter(func(k): return MHRoomTypes.upgrade_for(str(k)).is_empty())
	var line := MHStyle.body("Open from the start: %s. Feedstock: %s." % [", ".join(open.map(func(k): return MHRoomTypes.label(str(k)))), MHStyle.kg(floori(MHChapterOne.feedstock_kg))], 15, MHStyle.TEXT_SECONDARY)
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

func _fit(id: String) -> void:
	if not MHRoomTypes.fit(id): return
	MHAudio.sfx("place")
	MHNotices.post("valid", "Core upgrade fitted: %s" % str(MHRoomTypes.UPGRADES[id].label), "%s now on the build bar's Rooms tab." % MHRoomTypes.opens_text(id), "log")
	var builder: Node = world.get("builder")
	if builder != null and builder.has_method("_refresh_catalogue"): builder.call("_refresh_catalogue")
