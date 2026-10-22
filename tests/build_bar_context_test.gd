extends SceneTree

# The interior build bar: the same tabs in every room (so Q / E and the number
# keys stay put), "This room" first with only what fits, greyed-out cards that
# say where they fit, and the room-rule changes from the equipment audit.
# Run with: godot --headless --path . --script res://tests/build_bar_context_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _room(kind: String, x0: int) -> Dictionary:
	var cells := []
	for x in range(x0, x0 + 4):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	return {"kind": kind, "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600}

func _initialize() -> void:
	MHGame.site_id = "plains"; MHGame.game_mode = "creative"; MHGame.pending_save_state = {}
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 20: await process_frame
	world._intro_stage = "done"
	var builder: BuildController = world.builder
	builder.zones = [_room("galley", 0), _room("hygiene", 10)]
	builder._rebuild()
	var player: CharacterBody3D = world.player
	player.global_position = Vector3(6, builder.habitat_base_y + .2, 4.5)
	var ib = world.interior_builder
	ib.enter()
	await process_frame

	# In the Galley: the bar opens on This room, Galley kit first.
	var galley_tabs: Array = ib._tab_ids()
	_check(galley_tabs[0] == ib.HERE_TAB and galley_tabs[-1] == ib.STRUCTURE_TAB, "This room first, Structure last")
	_check(ib._selector_group == ib.HERE_TAB, "the bar opens on This room")
	var here: Array = ib._visible_ids()
	_check(not here.is_empty() and str(EquipmentCatalog.get_entry(here[0]).get("group", "")) == "galley", "the room's own kit comes first (%s)" % [here.slice(0, 3)])
	_check(here.has("locker") == false and here.has("work_desk"), "only what fits the Galley is listed")
	_check(ib._fits_here(ib.selected_id), "the selected item fits the room")

	# A group tab keeps every card, greying out what doesn't fit.
	ib._select_selector_group("living")
	var living: Array = ib._visible_ids()
	_check(living.has("crew_bunk") and living.has("locker"), "the Living Quarters tab still shows the bunk and locker")
	_check(not ib._fits_here("crew_bunk") and ib._fits_in("crew_bunk") == "Fits in Living Quarters", "the bunk is greyed with where it fits (%s)" % ib._fits_in("crew_bunk"))
	var before: String = ib.selected_id
	ib._pick_card("crew_bunk")
	_check(ib.selected_id == before and ib._blocked_note.contains("LIVING QUARTERS") == false and ib._blocked_note.contains("Living Quarters"), "picking a greyed card explains instead of selecting")

	# Walk into Hygiene: the same tabs, and the bar jumps back to This room.
	player.global_position = Vector3(36, builder.habitat_base_y + .2, 4.5)
	ib._refresh_contextual_selector()
	_check(ib._tab_ids() == galley_tabs, "the tabs stay the same in every room")
	_check(ib._selector_group == ib.HERE_TAB and ib._visible_ids().has("hygiene_shower") and ib._visible_ids().has("locker"), "This room now lists the hygiene kit and the locker")
	_check(not ib._tab_useful("galley") and ib._tab_useful("living"), "tabs with nothing for this room are dimmed")

	# Room-rule changes from the audit.
	for spec in [["microscope_station", "medical"], ["seedling_station", "science"], ["crew_chair", "waste_management"], ["crew_chair", "life_support"]]:
		_check((EquipmentCatalog.get_entry(spec[0]).get("valid_zones", []) as Array).has(spec[1]), "%s now fits in %s" % spec)
	ib.exit()
	if failures == 0:
		print("Build bar context test passed: fixed tabs, This room, greyed cards and the new room rules.")
	quit(1 if failures > 0 else 0)
