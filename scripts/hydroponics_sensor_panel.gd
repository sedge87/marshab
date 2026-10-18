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
	_update_readout()

func _process(_delta: float) -> void:
	_update_readout()

func interact(actor: Node = null) -> bool:
	var climate := _climate()
	if not climate.is_empty():
		educational_note = "HYDROPONICS SENSOR PANEL\nAir temperature: %.1f °C\n%s" % [float(climate.temperature), str(climate.context)]
	return super.interact(actor)

func _update_readout() -> void:
	if temperature_display == null:
		return
	var climate := _climate()
	if climate.is_empty():
		temperature_display.text = "--.- °C"
		return
	var temperature := float(climate.temperature)
	var context := str(climate.context)
	if is_equal_approx(temperature, _last_temperature) and context == _last_context:
		return
	_last_temperature = temperature
	_last_context = context
	temperature_display.text = "%.1f °C" % temperature
	temperature_display.modulate = Color("#8CFFE0") if str(climate.state) == "climate" else Color("#FFC27A")

func _climate() -> Dictionary:
	var builder := get_tree().get_first_node_in_group("habitat_builder") as BuildController
	return builder.climate_at(global_position) if builder != null else {}
