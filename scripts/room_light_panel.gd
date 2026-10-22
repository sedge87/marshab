extends StaticBody3D

## A room's light panel, on a wall near its entrance. E cycles the room's
## lights: Auto (on where the crew are or where you are, dim otherwise),
## On, Dim and Off. Built by BuildController._add_light_panels.

const MODES := ["", "on", "dim", "off"]   # "" is Auto
const NAMES := {"": "Auto", "on": "On", "dim": "Dim", "off": "Off"}

var builder: Node
var room_key := ""
var room_label := ""
var _lamp_material: StandardMaterial3D

func setup(target_builder: Node, key: String, label: String, lamp_material: StandardMaterial3D) -> void:
	builder = target_builder
	room_key = key
	room_label = label
	_lamp_material = lamp_material
	set_meta("interaction_target", self)
	add_to_group("room_light_panel")
	refresh()

func _mode() -> String:
	return str(builder.simulation().light_overrides.get(room_key, ""))

func interaction_prompt() -> Dictionary:
	var state := str(builder.room_light_state(room_key))
	return {"label": "%s lights · %s (%s)" % [room_label, NAMES[_mode()], state], "primary": "Lights: %s" % NAMES[MODES[(MODES.find(_mode()) + 1) % MODES.size()]], "info": "About"}

func interact(_actor: Node = null) -> bool:
	var next: String = MODES[(MODES.find(_mode()) + 1) % MODES.size()]
	if next.is_empty(): builder.simulation().light_overrides.erase(room_key)
	else: builder.simulation().light_overrides[room_key] = next
	MHAudio.sfx("ui_click", -4.0)
	builder.simulation().invalidate()
	builder.update_room_lights(true)
	builder.habitat_changed.emit()
	return true

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "Room lights", "Lighting is part of the power budget. On Auto a room's lights come on where the crew are scheduled to be and where you are, and drop to dim night strips elsewhere. Dim uses about an eighth of the power; Off uses none.")
	return true

## The little status lamp: green on Auto, white On, blue Dim, red Off.
func refresh() -> void:
	if _lamp_material == null: return
	var colour: Color = {"": Color("#5BE38C"), "on": Color("#FFF1D6"), "dim": Color("#6E8FD8"), "off": Color("#E5484D")}[_mode()]
	_lamp_material.albedo_color = colour
	_lamp_material.emission = colour
