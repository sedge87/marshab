extends Node3D

## A Garage's drone dock (A7, docs/bases-and-vehicles.md "As built (A7)"):
## a printed pad beside the hangar door, with a charging cradle, a windsock
## and a pilot's console. The scout drone (scripts/scout_drone.gd) lives
## here: it charges on the cradle, and you fly it from the console. Stand at
## the console and press E: your view becomes the drone's camera feed on
## the console's screen, and you fly it actively. Every Garage has one; the
## drone uses the nearest.

const MODEL := preload("res://scripts/vehicle_model.gd")
const CRADLE := Vector3(0, .2, 0)
const CONSOLE := Vector3(-.7, 0, -1.25)

var zone_key := ""          # which Garage it belongs to (its first cell)

func _ready() -> void:
	add_to_group("drone_dock")
	var model := MODEL.new()
	model.kind = "drone_dock"
	add_child(model)
	# The console is what you look at to fly; the pad is solid underfoot.
	var console := StaticBody3D.new()
	console.set_meta("interaction_target", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.7, 1.3, .4)
	shape.shape = box
	shape.position = CONSOLE + Vector3(0, .65, 0)
	console.add_child(shape)
	add_child(console)
	var pad := StaticBody3D.new()
	var pad_shape := CollisionShape3D.new()
	var pad_box := BoxShape3D.new()
	pad_box.size = Vector3(2.2, .1, 2.2)
	pad_shape.shape = pad_box
	pad_shape.position = Vector3(0, .05, 0)
	pad.add_child(pad_shape)
	add_child(pad)

func cradle() -> Vector3:
	return global_transform * CRADLE

func _drone() -> Node:
	return get_tree().get_first_node_in_group("scout_drone")

func interaction_prompt() -> Dictionary:
	var drone := _drone()
	if drone == null or str(drone.state) == "wrecked": return {"label": "Drone dock · empty", "info": "About"}
	var head := "Drone dock · drone %s · battery %d%%" % [drone.state_words(), roundi(float(drone.battery))]
	if drone.dock != self and str(drone.state) == "docked": return {"label": head + " (at another dock)", "info": "About"}
	return {"label": head, "primary": "Fly the drone", "info": "About"}

func interact(_actor: Node = null) -> bool:
	var drone := _drone()
	if drone == null: return false
	return bool(drone.fly_from(self))

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "Drone dock",
		"The scout drone's home: it charges on the cradle, and you fly it from this console. A few minutes of battery a flight and about 800 m of radio link from the dock. Wherever it flies sharpens your Map, and F logs a route marker there. It reads the wind: gusts (strongest just after sunrise, and in storms) can bring it down, and then you go and fetch it.")
	return true
