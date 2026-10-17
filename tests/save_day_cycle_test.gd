extends SceneTree

# Contract test for the compressed site clock and serialisable three-slot saves.
func _initialize() -> void:
	MHGame.site_id = "plains"
	var cycle := MHSiteDayNight.new()
	root.add_child(cycle)
	cycle.hour = 3.8
	assert(is_equal_approx(cycle._sunlight_at(3.8, MHGame.site().get("day_cycle", {})), 0.0), "Night should have no solar resource.")
	assert(cycle._sunlight_at(4.5, MHGame.site().get("day_cycle", {})) > 0.0, "Dawn should ramp sunlight in.")
	assert(is_equal_approx(cycle._sunlight_at(12.0, MHGame.site().get("day_cycle", {})), 1.0), "Daylight should provide full sunlight.")
	assert(is_equal_approx(cycle._sunlight_at(21.0, MHGame.site().get("day_cycle", {})), 0.0), "Night should resume after dusk.")
	var state := {"site_id": "ice", "site_name": "Ice Fields", "colony_name": "Save Test", "accent_index": 0, "builder": {"zones": [{"kind": "living", "cells": [Vector2i.ZERO]}]}, "player_position": Vector3(2, 1, 3), "day_night": {"hour": 18.5}}
	assert(MHGame.save_habitat(3, state) == OK, "Slot 3 should be writable.")
	var loaded := MHGame.load_habitat(3)
	assert(not loaded.is_empty(), "Saved slot should be readable.")
	assert(MHGame.prepare_habitat_load(3), "Saved slot should prepare a scene load.")
	assert(MHGame.site_id == "ice" and MHGame.pending_save_state.get("player_position") is Vector3, "Save must preserve site and vector positions.")
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame
	builder.restore_habitat_state(MHGame.pending_save_state.get("builder", {}) as Dictionary)
	assert(builder.zones.size() == 1 and str((builder.zones[0] as Dictionary).get("kind")) == "living", "Builder must reconstruct saved zones from records.")
	print("Save/day-cycle test passed: dawn, night, persistent slot and vector state.")
	quit(0)
