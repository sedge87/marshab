extends StaticBody3D

## One station on the lander's lifepod bench (scripts/lifepod_bench.gd):
## - "melter": a small heated hopper. Carrying ice: "Melt the ice" fills the
##   lander's water tank.
## - "printer": the lander's tiny printer. Salvage parts in, small things out.
##   E prints the plan shown; I shows the next plan.
## - "study": the fold-down bench with a hand lens. Carrying a sample or ice:
##   "Look closer", and it becomes a Journal page.

var lifepod: Node
var kind := "melter"

func setup(target_lifepod: Node, station_kind: String, size: Vector3) -> void:
	lifepod = target_lifepod
	kind = station_kind
	name = "Station_%s" % kind
	add_to_group("lifepod_station")
	set_meta("interaction_target", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * .5, 0)
	add_child(shape)

func interaction_prompt() -> Dictionary:
	match kind:
		"melter":
			return {"label": "Ice melter · tank %.1f of %.0f L" % [lifepod.water_l(), lifepod.water_cap()]}
		"printer":
			return lifepod.printer_prompt()
		_:
			return {"label": "Bench · a hand lens and a lamp"}

func interact(_player: Node = null) -> bool:
	if kind == "printer": return lifepod.print_now()
	return false

func interact_info(_player: Node = null) -> bool:
	if kind == "printer":
		lifepod.next_plan()
		return true
	return false

## What a carried find can do here ("" if nothing).
func takes(find: Node) -> String:
	match kind:
		"melter": return "Melt the ice" if str(find.kind) == "ice" else ""
		"study": return "Look closer"
	return ""

func take(find: Node) -> bool:
	match kind:
		"melter": return lifepod.melt(find)
		"study": return lifepod.study(find)
	return false
