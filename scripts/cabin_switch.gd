extends StaticBody3D

## One of the lander cabin's wall switches (heater, lights, scrubber): a small
## panel with a lamp that shows its state (green on, amber low, dark off). E
## changes it. No lettering on the model: the prompt names it.

var cabin: Node                  # scripts/lander_cabin_life.gd
var which := ""                  # "heater", "lights" or "scrubber"
var _lamp: StandardMaterial3D

func setup(target_cabin: Node, kind: String) -> void:
	cabin = target_cabin
	which = kind
	name = "CabinSwitch_" + kind
	set_meta("interaction_target", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.16, .22, .08)
	shape.shape = box
	add_child(shape)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(.14, .2, .03)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color("#3A3F45")
	plate_mat.roughness = .6
	plate_mesh.material = plate_mat
	plate.mesh = plate_mesh
	add_child(plate)
	var toggle := MeshInstance3D.new()
	var toggle_mesh := BoxMesh.new()
	toggle_mesh.size = Vector3(.04, .07, .04)
	var toggle_mat := StandardMaterial3D.new()
	toggle_mat.albedo_color = Color("#C9CDD2")
	toggle_mesh.material = toggle_mat
	toggle.mesh = toggle_mesh
	toggle.position = Vector3(0, -.03, -.025)
	add_child(toggle)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = .015; lamp_mesh.height = .03
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	lamp_mesh.material = _lamp
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, .06, -.02)
	add_child(lamp)
	refresh()

func _state() -> String:
	var core: RefCounted = cabin.core
	match which:
		"heater": return core.heater_mode
		"lights": return "on" if core.lights_on else "off"
		"scrubber": return "on" if core.scrubber_on else "off"
	return "off"

## The lamp: green on (warm), amber low, dark off; dull with no power.
func refresh() -> void:
	var state := _state()
	var colour := Color("#5BE38A") if state in ["on", "warm"] else (Color("#F2B544") if state == "low" else Color("#222222"))
	var lit: bool = cabin.core.powered() and state != "off"
	_lamp.albedo_color = colour.darkened(.3)
	_lamp.emission = colour
	_lamp.emission_energy_multiplier = 2.2 if lit else 0.0

func interaction_prompt() -> Dictionary:
	var core: RefCounted = cabin.core
	match which:
		"heater":
			var next: String = {"warm": "low", "low": "off", "off": "warm"}[core.heater_mode]
			var words: Dictionary = {"warm": "Warm (%d °C)" % roundi(core.n("cabin_warm_c", 20.0)), "low": "Low (%d °C)" % roundi(core.n("cabin_low_c", 10.0)), "off": "Off"}
			return {"label": "Cabin heater · " + words[core.heater_mode], "primary": "Set to " + str(words[next]).split(" (")[0]}
		"lights":
			return {"label": "Cabin lights · " + ("On" if core.lights_on else "Off"), "primary": "Switch off" if core.lights_on else "Switch on"}
		"scrubber":
			return {"label": "CO₂ scrubber · " + ("On" if core.scrubber_on else "Off"), "primary": "Switch off" if core.scrubber_on else "Switch on"}
	return {}

func interact(_actor: Node = null) -> bool:
	cabin.toggle(which)
	return true
