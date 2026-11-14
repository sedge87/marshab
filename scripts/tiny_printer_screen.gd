extends "res://scripts/small_screen.gd"

## The lander's tiny printer (scripts/lifepod.gd), E on it: what it can make
## from salvage parts, one at a time. Suit add-on plans you haven't found
## the cartridge for show greyed out, so you know they're out there.

const ICONS := {"hitch": "truck", "pick": "hammer", "bladder": "droplets", "seal": "wrench", "battery": "zap", "heater": "flame", "air_pack": "wind"}

func _pod() -> Node: return world.get("lifepod")

func _eyebrow() -> String: return "LANDER · TINY PRINTER"
func _title() -> String: return "Print from salvage"

func _signature() -> String:
	var pod := _pod()
	if pod == null: return ""
	return "%d|%s|%s|%d" % [int(pod.parts), str(pod.printing), str(pod.printer_rows().map(func(r): return str(r.state))), roundi(float(pod._print_left) * 4.0) if str(pod.printing) != "" else 0]

func _fill(into: VBoxContainer) -> void:
	var pod := _pod()
	if pod == null: return
	var stock := MHStyle.mono("%d PARTS IN THE HOPPER" % int(pod.parts), 15, MHStyle.TEXT_SECONDARY, 600)
	into.add_child(stock)
	if str(pod.printing) != "":
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = float(pod.PRINT_SECONDS)
		bar.value = float(pod.PRINT_SECONDS) - float(pod._print_left)
		into.add_child(MHStyle.mono("PRINTING %s" % pod._plan_name(str(pod.printing)).to_upper(), 14, MHStyle.accent, 600))
		into.add_child(bar)
	var rows: Array = pod.printer_rows()
	if rows.is_empty():
		into.add_child(MHStyle.body("Nothing left to print. Plan cartridges you find in the field add more.", 16, MHStyle.TEXT_MUTED))
		return
	var busy := str(pod.printing) != ""
	for r in rows:
		var id := str(r.id)
		var icon := str(ICONS.get(id, "box"))
		var title := str(r.name).capitalize() if str(r.name).begins_with("the ") == false else str(r.name).substr(4).capitalize()
		match str(r.state):
			"locked":
				into.add_child(row(icon, title, "Needs its plan cartridge. Look for it in the field.", "NO PLAN", MHStyle.TEXT_MUTED, "", Callable(), false, false))
			"printing":
				into.add_child(row(icon, title, "%d parts" % int(r.cost), "PRINTING", MHStyle.accent))
			"short":
				into.add_child(row(icon, title, "%d parts · you have %d. Strip storm debris for more." % [int(r.cost), int(pod.parts)], "", MHStyle.TEXT_MUTED, "Print", Callable(), false, false))
			_:
				into.add_child(row(icon, title, "%d parts" % int(r.cost), "", MHStyle.TEXT_MUTED, "Print", func() -> void: pod.print_plan(id), true, not busy))
