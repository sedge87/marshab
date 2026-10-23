extends StaticBody3D

## A solar array you can walk up to: how clean its cells are, and E to brush
## the dust off (weather_wear.gd). A thin solid slab over the panels, built by
## BuildController._build_solar, which also hands over the array's dust and
## frost overlay to keep up to date.

const WEATHER_WEAR := preload("res://scripts/weather_wear.gd")

var builder: Node
var key := ""
var overlay: ShaderMaterial

func setup(target_builder: Node, array_key: String, panel_overlay: ShaderMaterial) -> void:
	builder = target_builder
	key = array_key
	overlay = panel_overlay
	set_meta("interaction_target", self)
	add_to_group("solar_array")

func _sim() -> RefCounted:
	return builder.simulation()

func dust() -> float:
	return float(_sim().panel_dust.get(key, 0.0)) if _sim().weather_wear else 0.0

func interaction_prompt() -> Dictionary:
	var clean := roundi(100.0 * float(_sim().solar_clean(key, MHGame.sol_hour)))
	var prompt := {"label": "Solar array · %d%% of its light reaching the cells" % clean, "info": "About"}
	if dust() >= .03: prompt["primary"] = "Brush off the dust"
	return prompt

func interact(_actor: Node = null) -> bool:
	if dust() < .03: return false
	var gained := roundi(100.0 * float(_sim().clean_array(key)) * WEATHER_WEAR.DUST_LOSS)
	MHAudio.sfx("remove", -6.0, .1)
	_puff()
	refresh(MHGame.sol_hour)
	builder.habitat_changed.emit()
	var world := builder.get_parent()
	if world != null and world.get("weather") != null:
		world.weather.toast("Panels brushed clean", "That array makes about %d%% more power now." % gained, MHStyle.VALID)
	return true

func interact_info(_actor: Node = null) -> bool:
	get_tree().call_group("explore_hud", "show_equipment_note", "Solar array",
		"Mars dust is finer than flour and settles on everything. Dusty cells make less power: InSight's lander shut down in 2022 when its panels were too dusty. Dust devils and gusts sometimes blow panels clean (NASA calls these cleaning events), or you can brush them off. On cold nights frost forms on the cells too, and it sublimates in the morning sun.")
	return true

## Keep the overlay in step with the simulation (site_weather.gd calls this).
func refresh(hour: float) -> void:
	if overlay == null: return
	var on: bool = _sim().weather_wear and bool(MHGame.setting("weather"))
	overlay.set_shader_parameter("dust", dust() if on else 0.0)
	overlay.set_shader_parameter("frost", WEATHER_WEAR.frost(MHGame.site_id, hour) if on else 0.0)

## A small cloud of dust off the panels.
func _puff() -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = .85
	puff.amount = 40
	puff.lifetime = 1.6
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	puff.emission_box_extents = Vector3(1.3, .1, .5)
	puff.direction = Vector3(0, 1, 0)
	puff.spread = 60.0
	puff.initial_velocity_min = .4
	puff.initial_velocity_max = 1.2
	puff.gravity = Vector3(0, -.4, 0)
	puff.scale_amount_min = .15
	puff.scale_amount_max = .4
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(.74, .55, .4, .45)
	quad.material = material
	puff.mesh = quad
	add_child(puff)
	puff.emitting = true
	get_tree().create_timer(2.0).timeout.connect(puff.queue_free)
