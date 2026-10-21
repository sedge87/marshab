extends SceneTree

# Indoor heaters and the exterior packs: heaters cycle Off / Low / High, draw
# power by setting and warm their room only while powered; every outdoor prop
# loads its rig; the reactor isolator and ice drill switch change the habitat.
# Run with: godot --headless --path . --script res://tests/final_assets_test.gd
const HEATERS := ["wall_cabin_heater", "portable_utility_heater"]
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _parts_found(id: String, rig: Node) -> void:
	_check(rig != null and rig.has_method("interaction_prompt"), "%s has the interaction rig" % id)
	if rig == null: return
	_check(not str(EquipmentCatalog.get_entry(id).get("system_note", "")).is_empty(), "%s has an info card" % id)
	for index in range((rig.get("_actions") as Array).size()):
		var action: Dictionary = rig.get("_actions")[index]
		var found := not (rig.get("_pivots").get(index, []) as Array).is_empty() or (rig.get("_lights") as Dictionary).has(index) or not (action.get("observations", []) as Array).is_empty() or not (rig.get("_spinners").get(index, []) as Array).is_empty()
		_check(found, "%s action %d (%s) found its parts" % [id, index, str(action.get("type", ""))])

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	MHGame.outside_temperature_c = -60.0
	MHGame.debug_free_power = true

	# Heaters: a living room with no Life Support, so only heaters can warm it.
	var cells := []
	for x in range(-3, 4):
		for z in range(-1, 2): cells.append(Vector2i(x, z))
	builder.zones = [{"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 700}]
	builder._rebuild()
	var rigs := {}
	var x := -6.0
	for id in HEATERS:
		_check(str(EquipmentCatalog.get_entry(id).get("group", "")) == "general", "%s is general equipment" % id)
		var at := Vector3(x, builder.habitat_base_y, 0)
		var visual := builder.free_interior_visual(id, at, 0.0)
		builder.place_free_interior_equipment(id, at, 0.0, Vector2i(roundi(at.x / 3), 0), visual)
		await process_frame
		rigs[id] = visual.get_node_or_null("Model")
		_parts_found(id, rigs[id])
		x += 4.0
	var point := Vector3(0, builder.habitat_base_y + 1.0, 0)
	var sim: RefCounted = builder.simulation()
	var room: Dictionary = builder.zones[0]
	# Rooms warm gradually: let half a sol pass at each setting.
	sim.run_hours(12.0, 20.0)
	var cold: float = sim.room_temperature(room)
	var draw_off := int(builder._systems().draw)
	var heater: Node = rigs.portable_utility_heater
	heater.interact()
	_check(str(heater.interaction_prompt().primary).begins_with("Heater LOW"), "one press sets Low: %s" % heater.interaction_prompt().primary)
	var draw_low := int(builder._systems().draw)
	sim.run_hours(12.0, 20.0)
	var warm_low: float = sim.room_temperature(room)
	heater.interact()
	var draw_high := int(builder._systems().draw)
	sim.run_hours(12.0, 20.0)
	var warm_high: float = sim.room_temperature(room)
	_check(draw_off < draw_low and draw_low < draw_high, "power draw rises with the setting: %d / %d / %d" % [draw_off, draw_low, draw_high])
	_check(cold < warm_low and warm_low < warm_high, "the room warms with the setting: %.1f / %.1f / %.1f °C" % [cold, warm_low, warm_high])
	_check(is_equal_approx(float(builder.climate_at(point).temperature), warm_high), "the explorer readout shows the room's simulated temperature")
	var saved := builder.export_habitat_state()
	heater.interact()
	_check(int(builder._systems().draw) == draw_off, "a third press switches it off")
	var level_saved := false
	for item in saved.placed_interior:
		if str(item.id) == "portable_utility_heater": level_saved = int((item.get("state", {}) as Dictionary).get("heat", 0)) == 2
	_check(level_saved, "the heater setting is saved")
	MHGame.debug_free_power = false
	heater.interact()
	builder.simulation().invalidate()
	_check(str(heater.interaction_prompt().primary).contains("NO POWER"), "with no power the heater says so: %s" % heater.interaction_prompt().primary)
	MHGame.debug_free_power = true

	# Outdoor props: each loads the new model with its rig.
	for id in BuildController.SURFACE_EQUIPMENT:
		var path := str(BuildController.SURFACE_EQUIPMENT[id].asset)
		_check(path.contains("mars_exterior"), "%s uses the new exterior model" % id)
		var at := Vector3(40.0 + x, 0, 30.0)
		x += 4.0
		var visual := builder.surface_visual(id, at, 0.0)
		_check(builder.place_surface_equipment(id, at, 0.0, visual), "%s can be placed" % id)
		await process_frame
		var rig := visual.get_node_or_null("Model")
		_parts_found(id, rig)
		var body := visual.get_node_or_null("SurfaceCollision")
		_check(body != null and body.get_meta("interaction_target", null) == rig, "%s can be interacted with" % id)
	var crate: Node = (builder.surface_furnishing.get_children().filter(func(n): return str(n.get_meta("surface_equipment_id", "")) == "cargo_crate_large")[0] as Node).get_node("Model")
	crate.interact()
	_check(bool(crate.call("_state_on", "lid")), "outdoor crate opens")
	var surface_saved := false
	for item in builder.export_habitat_state().placed_surface:
		if str(item.id) == "cargo_crate_large": surface_saved = bool((item.get("state", {}) as Dictionary).get("lid", false))
	_check(surface_saved, "outdoor prop state is saved")

	# Reactor isolator and ice drill switch.
	builder.zones.append({"kind": "reactor", "cells": [Vector2i(6, 0)], "cost": 1200})
	builder._rebuild()
	await process_frame
	var reactor: Node = null
	var drill: Node = null
	for node in builder.root.get_children():
		if str(node.name).begins_with("SiteMachine_surface_reactor"): reactor = node.get_node_or_null("Model")
	_parts_found("surface_reactor", reactor)
	MHGame.debug_free_power = false
	var with_reactor := int(builder._systems().generation)
	reactor.interact()
	var isolated := int(builder._systems().generation)
	_check(with_reactor > isolated, "isolating the reactor cuts its power: %d -> %d" % [with_reactor, isolated])
	builder._rebuild()
	await process_frame
	_check(int(builder._systems().generation) == isolated, "the isolator setting survives a rebuild")
	MHGame.debug_free_power = true
	var ice := Vector2i.ZERO
	var richest := 0.0
	for cx in range(-20, 21):
		for cz in range(-20, 21):
			if absi(cx) < 6 and absi(cz) < 3: continue
			var richness := float(builder._ice_richness_at(Vector2i(cx, cz)))
			if richness > richest: richest = richness; ice = Vector2i(cx, cz)
	builder.zones.append({"kind": "ice_extractor", "cells": [ice], "cost": 450})
	builder._rebuild()
	await process_frame
	for node in builder.root.get_children():
		if str(node.name).begins_with("SiteMachine_ice_drill"): drill = node.get_node_or_null("Model")
	_parts_found("ice_drill", drill)
	var water_on := int(builder._systems().water)
	drill.interact()
	_check(int(builder._systems().water) == 0 and water_on >= 0, "a stopped drill pumps no water (was %d)" % water_on)

	MHGame.debug_free_power = false
	if failures == 0:
		print("Final assets test passed: heaters, outdoor props, reactor isolator and ice drill.")
	quit(1 if failures > 0 else 0)
