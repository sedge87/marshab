extends SceneTree

# The mission dossier (backlog 27): versions keep checks, graphs, prediction
# and note; "what fixed it"; the student name; the HTML export; and the
# Dossier view in Mission Control.
# Run with: godot --headless --path . --script res://tests/dossier_test.gd
const MHMissions := preload("res://scripts/mh_missions.gd")
const PICKER := preload("res://scripts/landing_picker.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	MHGame.save_directory = "user://test_habitats"
	MHGame.site_id = "plains"; MHGame.game_mode = "missions"; MHGame.pending_save_state = {}
	MHGame.colony_name = "Kestrel Base"
	MHMissions.reset()
	_check(MHMissions.progress.has("campaign_id") and MHMissions.student_name() == "", "a new campaign has an id and no name yet")
	MHMissions.set_student_name("  Sam Rivers  ")
	_check(MHMissions.student_name() == "Sam Rivers", "the student name is kept (trimmed)")
	var target: Vector2 = PICKER.suggested()
	MHMissions.progress.landing_target = target
	MHMissions.progress.base_site = target + Vector2(30, 0)
	for id in ["landing_zones", "cargo_power_water", "cargo_habitat"]: (MHMissions.progress.completed as Array).append(id)
	for id in ["cargo_power_water", "cargo_habitat", "crew_land"]: MHMissions.set_arrived(id)
	MHMissions.progress.current = "crew_land"
	var world: Node = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await process_frame
	var b = world.builder
	var cells := []
	for x in range(10, 14):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones.append({"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600})
	b._rebuild()

	# Two Tests: the first with a prediction, a note added after.
	MHMissions.pending_prediction = "The crew will get cold on the first night."
	var first: Dictionary = MHMissions.run_test(b)
	MHMissions.set_version_note("crew_land", int(first.version), "Add bunks and heating next.")
	for i in 4:
		var at := Vector3(31.0 + i * 1.6, b.habitat_base_y, 3.0)
		b.place_free_interior_equipment("crew_bunk", at, 0.0, Vector2i(10 + i, 1), b.free_interior_visual("crew_bunk", at, 0.0))
	var second: Dictionary = MHMissions.run_test(b)
	var list := MHMissions.versions("crew_land")
	_check(list.size() == 2, "two versions recorded")
	var v1: Dictionary = list[0]
	_check(str(v1.prediction).begins_with("The crew will get cold"), "version 1 keeps its prediction")
	_check(str(v1.note) == "Add bunks and heating next.", "and its note")
	_check(str(list[1].prediction).is_empty(), "the prediction isn't carried into the next version")
	_check(not (v1.checks as Array).is_empty() and (v1.checks[0] as Dictionary).has("detail"), "each check keeps its reason")
	_check((v1.samples as Array).size() > 1 and (v1.samples as Array).size() <= MHMissions.DOSSIER_POINTS + 1, "graphs are kept, downsampled (%d points)" % (v1.samples as Array).size())
	_check(MHMissions.design_changes_full(v1.design, list[1].design).contains("+4 crew bunks"), "changes name the furniture (%s)" % MHMissions.design_changes_full(v1.design, list[1].design))

	# What fixed it: a check that failed in v1 and passed in v2.
	var aboard_fixed := MHMissions.fixes("crew_land").filter(func(f): return f.id == "aboard" or str(f.text).contains("bunk") or str(f.text).to_lower().contains("crew"))
	_check(not MHMissions.fixes("crew_land").is_empty(), "something was fixed between versions (%s)" % [MHMissions.fixes("crew_land")])
	if not aboard_fixed.is_empty(): _check(str(aboard_fixed[0].changes).contains("crew bunk"), "and the fix names the bunks")

	# The HTML export.
	var page := MHDossier.html(["crew_land"])
	_check(page.begins_with("<!doctype html>") and page.contains("Kestrel Base") and page.contains("Sam Rivers"), "the page has the colony and student name")
	_check(page.contains("Version 1") and page.contains("Version 2") and page.contains("<svg"), "every version with its charts")
	_check(page.contains("Prediction:") and page.contains("Note:"), "the prediction and note")
	_check(page.contains("What failed, and what fixed it"), "and what fixed it")
	MHMissions.set_student_name("")
	_check(not MHDossier.html(["crew_land"]).contains("Engineer:"), "no name, no name line")

	# Mission Control's Dossier view.
	world._open_mission_control()
	await process_frame
	world.mission_control._show_dossier()
	await process_frame
	await process_frame
	var text := ""
	for label in world.mission_control.find_children("*", "Label", true, false): text += label.text + " "
	for button in world.mission_control.find_children("*", "Button", true, false): text += (button as Button).text + " "
	_check(text.to_lower().contains("mission dossier") and text.contains("V1") and text.contains("V2"), "the Dossier view lists the versions")
	world.mission_control._dossier_mission("crew_land", 1)
	await process_frame
	text = ""
	for label in world.mission_control.find_children("*", "Label", true, false): text += label.text + " "
	_check(text.contains("Version 1") and text.contains("Prediction"), "clicking a version shows it")
	world.mission_control._close()

	if failures == 0:
		print("Dossier test passed: versions, prediction and note, fixes, names, HTML export and the Mission Control view.")
	quit(1 if failures > 0 else 0)
