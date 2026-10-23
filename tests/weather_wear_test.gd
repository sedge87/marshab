extends SceneTree

# Run with: godot --headless --path . --script res://tests/weather_wear_test.gd
# Batch D: weather leaves a mark that wears off. Dust settles on the solar
# arrays (much faster in a storm) and costs power; brushing or a dust devil
# cleans it; the hull's storm dust fades; frost covers the panels at dawn and
# sublimates by late morning; it's all saved; and it's only on where it
# should be (never in Creative or a mission Test's own simulation).
const WEAR := preload("res://scripts/weather_wear.gd")

func _initialize() -> void:
	MHGame.site_id = "plains"
	MHGame.game_mode = "survival"
	var builder := BuildController.new()
	builder.display_only = true
	var world := Node3D.new()
	root.add_child(world)
	world.call_deferred("add_child", builder)
	await process_frame
	await process_frame
	builder.zones = [{"kind": "living", "cells": [Vector2i(0, 0)], "cost": 0, "door_direction": Vector2i(0, -1)},
		{"kind": "solar", "cells": [Vector2i(-2, 0)], "cost": 0, "door_direction": Vector2i(0, 1)}]
	builder._rebuild()
	var sim: RefCounted = builder.simulation()
	var key: String = sim._room_key(builder.zones[1])
	assert(not sim.weather_wear, "Off until the world switches it on.")
	assert(WEAR.enabled(), "On in Survival.")
	MHGame.game_mode = "creative"
	assert(not WEAR.enabled(), "Never in Creative.")
	MHGame.game_mode = "survival"
	# Clean panels make full power; dust costs power.
	sim.weather_wear = true
	var clean_kw: float = sim._solar_kw(sim.inventory().solar, 12.0, sim.inventory().solar_keys)
	assert(clean_kw > 0.0, "The array makes power at noon.")
	sim.panel_dust[key] = .5
	var dusty_kw: float = sim._solar_kw(sim.inventory().solar, 12.0, sim.inventory().solar_keys)
	assert(absf(dusty_kw / clean_kw - (1.0 - .5 * WEAR.DUST_LOSS)) < .01, "Half-dusty cells lose about %d%% (%.2f)." % [roundi(50.0 * WEAR.DUST_LOSS), dusty_kw / clean_kw])
	# Dust settles slowly in calm weather, fast in a storm (capped).
	sim.panel_dust[key] = 0.0
	sim._rng.seed = 1
	var calm := 0.0
	for i in 24: sim._wear(1.0)
	calm = float(sim.panel_dust[key])
	assert(calm > .005 and calm < .05, "A calm sol adds a little dust (%.3f)." % calm)
	sim.storm_hours_left = 72.0
	for i in 72: sim._wear(1.0)
	assert(float(sim.panel_dust[key]) > .5 and float(sim.panel_dust[key]) <= WEAR.MAX_DUST, "A three-sol storm leaves the panels thick with dust (%.2f)." % float(sim.panel_dust[key]))
	assert(sim.hull_dust > .9, "And coats the hull (%.2f)." % sim.hull_dust)
	sim.storm_hours_left = 0.0
	var coated: float = sim.hull_dust
	for i in 24 * 5: sim._wear(1.0)
	assert(sim.hull_dust < coated * .3, "The hull's coat wears off over a few sols (%.2f)." % sim.hull_dust)
	# Brushing cleans it.
	var removed: float = sim.clean_array(key)
	assert(removed > .4 and is_zero_approx(float(sim.panel_dust[key])), "Brushing takes the dust off.")
	# Frost: heavy before dawn on the Ice Fields, gone by late morning, light elsewhere.
	assert(WEAR.frost("ice", 5.0) > .9 and WEAR.frost("ice", 11.0) == 0.0 and WEAR.frost("ice", 14.0) == 0.0, "Ice Fields frost forms overnight and sublimates by late morning.")
	assert(WEAR.frost("plains", 5.0) < .2, "Only a trace of frost on the plains.")
	MHGame.site_id = "ice"
	var dawn: float = sim.solar_clean(key, 7.0)
	var noon: float = sim.solar_clean(key, 12.0)
	assert(dawn < noon and is_equal_approx(noon, 1.0), "Morning frost costs power until it's gone (%.2f at 07:00)." % dawn)
	MHGame.site_id = "plains"
	# Saved and loaded.
	sim.panel_dust[key] = .33
	sim.hull_dust = .4
	var state: Dictionary = sim.save()
	sim.panel_dust = {}
	sim.hull_dust = 0.0
	sim.load(state)
	assert(is_equal_approx(float(sim.panel_dust[key]), .33) and is_equal_approx(sim.hull_dust, .4), "Dust is saved with the colony.")
	# The array you walk up to: shows the dust and brushes it off.
	var panels := root.get_tree().get_nodes_in_group("solar_array")
	assert(panels.size() == 1, "The array has its brushable slab.")
	var panel: Node = panels[0]
	assert(str(panel.interaction_prompt().get("primary", "")) == "Brush off the dust", "Dusty arrays offer a brush.")
	panel.call("_sim").panel_dust[key] = .33
	assert(panel.call("dust") > .3, "It reads the array's dust.")
	sim.panel_dust[key] = 0.0
	assert(not panel.interaction_prompt().has("primary"), "Clean arrays don't.")
	# A mission Test's own simulation starts clean.
	var fresh: RefCounted = load("res://scripts/habitat_sim.gd").new(builder)
	assert(not fresh.weather_wear, "A fresh simulation (the mission Test) has no weather wear.")
	print("Weather wear test passed: dust and storms, cleaning, the hull fading, frost, power, saving, the brush and where it's on.")
	quit(0)
