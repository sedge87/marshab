extends SceneTree

# Habitat alerts (backlog 26): levels from the live sim, a voice line for every
# alert and clear, raise -> repeat -> all clear, the advisories setting, the
# Mission Control log and alerts replayed in the Test report.
# Run with: godot --headless --path . --script res://tests/habitat_alerts_test.gd
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
	MHMissions.reset()
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
	var alerts = world.alerts
	var cells := []
	for x in range(10, 14):
		for z in range(0, 3): cells.append(Vector2i(x, z))
	b.zones.append({"kind": "living", "cells": cells, "door_direction": Vector2i(0, -1), "cost": 600})
	b._rebuild()
	for i in 4:
		var at := Vector3(31.0 + i * 1.6, b.habitat_base_y, 3.0)
		b.place_free_interior_equipment("crew_bunk", at, 0.0, Vector2i(10 + i, 1), b.free_interior_visual("crew_bunk", at, 0.0))
	var sim = b.simulation()
	sim.invalidate()

	# Every alert id/level and every clear has a voice line.
	for id in alerts.EXPLAIN:
		for level in ["warning", "critical", "resolved"]:
			if level == "warning" and id == "life_support_power": continue
			if level == "critical" and id in ["power", "battery_sunset"]: continue
			if id == "battery_sunset" and level != "advisory": continue
			_check(ResourceLoader.exists("res://assets/audio/voice/%s.wav" % alerts.voice_line(id, level)), "voice line for %s %s" % [id, level])
	_check(ResourceLoader.exists("res://assets/audio/voice/battery_sunset_advisory.wav"), "voice line for the sunset advisory")

	# Levels follow the readings.
	sim.o2_pct = 19.8
	var found: Array = alerts.evaluate()
	_check(found.any(func(a): return a.id == "o2" and a.level == "warning"), "O₂ 19.8% is a warning")
	sim.o2_pct = 19.2
	found = alerts.evaluate()
	var o2: Array = found.filter(func(a): return a.id == "o2")
	_check(not o2.is_empty() and o2[0].level == "critical", "O₂ 19.2% is critical")
	_check(not o2.is_empty() and (o2[0].chain as Array).size() >= 2, "it comes with a cause chain")
	sim.co2_pct = 1.4
	_check(alerts.evaluate().any(func(a): return a.id == "co2" and a.level == "critical"), "CO₂ 1.4% is critical")

	# Raised once (with its explainer the first time), then cleared.
	var before: int = alerts.history.size()
	alerts._update(alerts.evaluate())
	_check(alerts._active.has("o2") and alerts.history.size() > before, "the alert is raised and logged")
	_check(alerts._explained.has(str(alerts.history[before].id)), "the first one explains why it matters")
	var logged: int = alerts.history.size()
	alerts._update(alerts.evaluate())
	_check(alerts.history.size() == logged, "it isn't raised again straight away")
	sim.o2_pct = 21.0
	sim.co2_pct = 0.1
	alerts._update(alerts.evaluate())
	_check(not alerts._active.has("o2") and alerts.history.any(func(e): return e.level == "resolved" and e.id == "o2"), "fixing it gives an all clear")

	# Mission Control shows the log.
	world._open_mission_control()
	await process_frame
	world.mission_control._show_alert_log()
	await process_frame
	var text := ""
	for label in world.mission_control.find_children("*", "Label", true, false): text += label.text + " "
	_check(text.to_lower().contains("alert log") and text.to_lower().contains("all clear"), "Mission Control's alert log lists them")
	world.mission_control._close()

	# The Test replays the alerts on its run.
	var report: Dictionary = MHMissions.run_test(b)
	_check(report.has("alerts") and report.alerts is Array, "the test report has the alerts it would have raised (%d)" % (report.get("alerts", []) as Array).size())

	if failures == 0:
		print("Habitat alerts test passed: levels, cause chains, voice lines, raise/clear, explainers, log and test report.")
	quit(1 if failures > 0 else 0)
