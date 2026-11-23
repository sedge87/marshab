extends Node3D

## The Site Plan Terminal's screen (asset_packs/outpost_chunk1_v1/
## Site_Plan_Terminal): the model ships it as dark glass on its own "Screen"
## mesh. Placed in a core it's powered, so it shows a plain soft glow, like
## the other screens on models (docs/house-style.md: no baked readouts).
## The plan itself opens full-screen when you use it (equipment_rig "site_plan").

func _ready() -> void:
	var screen := get_parent().find_child("Screen", true, false) as MeshInstance3D
	if screen == null: return
	var glow := StandardMaterial3D.new()
	glow.resource_name = "display_screen_glow"
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#123A44")
	glow.emission_enabled = true
	glow.emission = Color("#2A8C9C")
	glow.emission_energy_multiplier = .6
	screen.material_override = glow
	_glow = glow

## 23 Nov playtest: nothing said you could plan a room here. Until the first
## Quarters is planned, the screen breathes brighter.
var _glow: StandardMaterial3D
var _t := 0.0
func _process(delta: float) -> void:
	if _glow == null: return
	_t += delta
	var world := get_tree().get_first_node_in_group("habitat_world")
	var builder: Node = world.get("builder") if world != null else null
	var waiting := builder != null and int(world.get("opening_version")) >= 3
	if waiting:
		for zone in builder.get("zones"):
			if str(zone.get("kind", "")) == "living":
				waiting = false
				break
	_glow.emission_energy_multiplier = (.6 + .9 * (.5 + .5 * sin(_t * 3.0))) if waiting else .6
	if not waiting and _t > 1.0: set_process(false)
