extends SceneTree
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# Each build site's generated map, build area, sun and heating.
# Run with: godot --headless --path . --script res://tests/site_maps_test.gd
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var builder := BuildController.new()
	builder.display_only = true
	world.add_child(builder)
	await process_frame

	var average := {}
	for entry in MHGame.sites():
		var id := str(entry.id)
		MHGame.site_id = id
		var limit := int(builder._site_build_limit() / BuildController.CELL)
		# The whole build area is level, so the first room never locks the rest out.
		var level := true
		var buildable := 0
		for x in range(-limit, limit + 1):
			for z in range(-limit, limit + 1):
				if not MHSiteTerrain.cell_unbuildable_reason(Vector2i(x, z)).is_empty(): continue
				buildable += 1
				for offset in [Vector2.ZERO, Vector2(1.5, 1.5), Vector2(-1.5, -1.5)]:
					var at: Vector2 = Vector2(x * 3.0, z * 3.0) + offset
					if absf(MHSiteTerrain.height(at.x, at.y)) > .001: level = false
		_check(level, "%s: every buildable cell is level" % id)
		_check(buildable > 400, "%s: has a usable build area (%d cells)" % [id, buildable])
		# Spawn, the menu's display colony and every ice deposit sit in the build area.
		_check(MHSiteTerrain.is_buildable(Vector2(6, 10)), "%s: player spawn is in the build area" % id)
		for cell in [Vector2i(0, -3), Vector2i(7, -1), Vector2i(5, 1), Vector2i(0, 1)]:
			_check(MHSiteTerrain.cell_unbuildable_reason(cell).is_empty(), "%s: menu colony cell %s is buildable" % [id, cell])
		for deposit in entry.get("ice_deposits", []):
			_check(MHSiteTerrain.is_buildable(Vector2(float(deposit.x), float(deposit.z))), "%s: ice deposit centre is buildable" % id)
		# Rocks never land where habitat can go.
		var rocks_on_pad := 0
		for rock in MHSiteTerrain.rock_placements():
			if MHSiteTerrain.is_buildable(Vector2(rock.position.x, rock.position.z)): rocks_on_pad += 1
		_check(rocks_on_pad == 0, "%s: %d rocks sit in the build area" % [id, rocks_on_pad])
		# The site plan rejects cells outside the build area with the reason.
		builder.zones = []
		builder.kind = "living"
		_check(builder._invalid_reason([Vector2i(limit + 1, 0)]) != "", "%s: a cell beyond the build area is rejected" % id)
		# Solar: nothing at night, strongest around noon.
		_check(MHGame.solar_irradiance(1.0) == 0.0, "%s: no solar at night" % id)
		_check(MHGame.solar_irradiance(12.0) > MHGame.solar_irradiance(7.0), "%s: solar builds towards noon" % id)
		average[id] = MHGame.average_solar(entry)

	# Shape-specific rules.
	MHGame.site_id = "ridge"
	_check(MHSiteTerrain.cell_unbuildable_reason(Vector2i(9, 0)).contains("canyon"), "ridge: cells at the cliffs are walled off")
	_check(MHSiteTerrain.height(55.0, 0.0) > 30.0, "ridge: canyon walls rise high")
	MHGame.site_id = "crater"
	_check(MHSiteTerrain.cell_unbuildable_reason(Vector2i(-5, -4)).contains("mound"), "crater: the central mound is off limits")
	_check(not MHSiteTerrain.cell_unbuildable_reason(Vector2i(16, 0)).is_empty(), "crater: the crater wall is off limits")
	_check(MHSiteTerrain.height(76.0, 0.0) > 15.0, "crater: the rim stands tall")

	# Sites differ in a way the cards report.
	_check(average.plains > average.crater and average.crater > average.ridge and average.ridge > average.ice, "solar ranks plains > crater > ridge > ice: %s" % average)
	MHGame.site_id = "plains"
	_check(MHGame.site_card(MHGame.site()).badges.has(["+ Solar", "valid"]), "plains card shows its solar advantage")

	# Panels facing the noon sun beat those facing away.
	_check(builder._solar_efficiency(Vector2i(0, 1), Vector2(0, 1)) > builder._solar_efficiency(Vector2i(0, -1), Vector2(0, 1)), "south-facing panel wins at noon")

	# Heating grows as Mars gets colder.
	builder.zones = [{"kind": "living", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "door_direction": Vector2i(0, -1), "cost": 200}]
	MHGame.outside_temperature_c = -20.0
	var mild := int(builder._systems().heating)
	MHGame.outside_temperature_c = -80.0
	var bitter := int(builder._systems().heating)
	_check(bitter > mild and mild > 0, "heating rises with cold (%d at -20 °C, %d at -80 °C)" % [mild, bitter])

	if failures == 0:
		print("Site maps test passed: level build areas, site limits, rocks, solar curves, cards and heating.")
	quit(1 if failures > 0 else 0)
