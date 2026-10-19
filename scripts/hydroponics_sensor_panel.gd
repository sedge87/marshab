class_name MHHydroponicsSensorPanel
extends MHEquipmentInteractable

## The panel reads the same room-climate calculation as the player HUD.  It
## never owns temperature simulation itself, so its display cannot drift from
## the actual habitat state.

@onready var temperature_display: Label3D = $TemperatureDisplay

var _last_temperature := INF
var _last_context := ""

func _ready() -> void:
	super._ready()
	# World-space labels ignore room walls and become huge at grazing camera
	# angles. The live value is shown in the player's compact inspection HUD.
	if temperature_display != null:
		temperature_display.visible = false

func interact(actor: Node = null) -> bool:
	var climate := _climate()
	if not climate.is_empty():
		educational_note = "HYDROPONICS SENSOR PANEL\nAir temperature: %.1f °C\n%s" % [float(climate.temperature), str(climate.context)]
	return super.interact(actor)

func _climate() -> Dictionary:
	var builder := get_tree().get_first_node_in_group("habitat_builder") as BuildController
	return builder.climate_at(global_position) if builder != null else {}
