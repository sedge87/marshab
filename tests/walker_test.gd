extends SceneTree

# Step 3c, Walker 1 and the General Module (scripts/walker.gd,
# scripts/build_rules.gd; systems-and-items §14 step 3c):
# - the walker stands stalled about 2 km out, its fault lamp blinking;
# - B does nothing before the module's home;
# - the night it moves it leaves tracks; near them, a Notes thought;
# - a photo of the tracks sent up brings Castellanos's text and puts it on
#   the orbiter's record (and the Cargo app's);
# - digging the dust out wakes it; it walks home and parks by the lander;
# - the Site plan then offers only the module (a fixed 2 × 3 cells, free)
#   and its airlock, only on explored ground;
# - closing the plan sends it to carry and lower the module; the real rooms
#   show once it's down; the fit-out kit is all the Interior view offers;
# - the module's plans; the first night in a real room;
# - saved and loaded.
# godot --headless --path . --script res://tests/walker_test.gd
const RULES := preload("res://scripts/build_rules.gd")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _new_world(state := {}) -> Node:
	MHGame.site_id = "region"; MHGame.game_mode = "survival"; MHGame.pending_save_state = state; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	if state.is_empty(): MHChapterOne.reset()
	var world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world._intro_stage = "done"
	world.day_night.frozen = true
	return world

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _press_b(builder: Node) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	builder._unhandled_input(key)

## Runs the walker on until `done` holds (or about `seconds` of its time).
func _run(walker: Node, seconds: float, done: Callable) -> bool:
	var t := 0.0
	while t < seconds:
		walker._process(.5)
		t += .5
		if done.call(): return true
	return false

## The first spot near the lander where the module can go.
func _module_spot(builder: Node, lander: Vector3) -> Array:
	builder.kind = "general"
	for r in [30.0, 42.0, 55.0, 70.0]:
		for step in 16:
			var a := step * TAU / 16.0
			var p: Vector3 = lander + Vector3(sin(a), 0, cos(a)) * float(r)
			var cell := Vector2i(roundi(p.x / builder.CELL), roundi(p.z / builder.CELL))
			var cells: Array = builder._cells(cell, cell)
			if builder._invalid_reason(cells).is_empty(): return cells
	return []

func _place(builder: Node, cells: Array) -> Dictionary:
	if builder.zones.is_empty(): builder.habitat_base_y = builder._proposed_base_y(cells)
	var zone := {"kind": builder.kind, "cells": cells, "door_direction": builder.airlock_direction, "cost": builder._zone_cost(cells)}
	RULES.placed(builder, zone)
	builder.zones.append(zone)
	builder._history.append({"type": "zone", "zone": zone})
	builder._rebuild()
	return zone

func _initialize() -> void:
	var world = await _new_world()
	var walker: Node3D = world.walker
	_check(walker != null, "a new game has Walker 1")
	if walker == null:
		quit(1)
		return
	var builder: Node = world.builder
	var lander: Vector3 = world.lander.global_position
	var player: Node3D = world.player
	var far := _flat(walker.global_position, lander)
	_check(far > 1800.0 and far < 2250.0, "it stands about 2 km out (%.0f m)" % far)
	_check(walker.state == "stalled" and walker._dust.visible, "stalled, its wheel packed with dust")
	var lit := false
	for i in 30:
		walker._process(.1)
		if walker._light.visible: lit = true
	_check(lit, "its fault lamp blinks")

	# B before the module is home.
	_check(RULES.b_reason(builder) == "Nothing to build with yet", "B: nothing to build with yet")
	_press_b(builder)
	_check(not builder.build_mode, "and the Site plan stays shut")

	# The night it moves: tracks.
	world.lifepod.walker_night()
	var marks: Array = world.get_tree().get_nodes_in_group("walker_tracks")
	_check(walker.tracks_laid and marks.size() > 15, "it left tracks (%d marks)" % marks.size())
	var nearest: float = marks.map(func(m): return _flat(m.global_position, lander)).min()
	_check(nearest < 260.0, "they start in the near ring (%.0f m)" % nearest)
	player.global_position = (marks[3] as Node3D).global_position + Vector3(0, 1.5, 0)
	walker._look()
	_check(world.notes.is_open("tracks"), "near them: a thought about the tracks")

	# A photo of them, sent up.
	_check(not walker.can_send(), "nothing to send before a picture")
	MHJournal.add_photo(2, "", "Sol 2 · Walker tracks", ["walker_tracks"])
	_check(walker.can_send() and walker.send_up(), "a picture of the tracks goes up to the orbiter")
	walker._text_left = .2
	walker._process(.5)
	_check(world.orbiter_texts.has("walker_photo"), "on the next pass Castellanos texts Rao's photo")
	_check(world.known.knows(walker.ID, "orbiter") and not world.known.knows(walker.ID), "the orbiter knows where it is; you haven't seen it yet")
	var screen: Control = world.pda.screen
	var walkers: Array = screen._manifest_data().walkers
	_check(screen.cargo_state(walkers[0]) == "seen", "Cargo: Walker 1 seen")

	# Finding it, digging it out.
	player.global_position = walker.global_position + Vector3(0, 1.5, 600.0)
	walker._look()
	_check(walker.seen and world.known.knows(walker.ID) and world.notes.is_open("walker_seen") and world.notes.is_settled("tracks"), "within sight: you see it")
	player.global_position = walker.to_global(walker.FORK) + Vector3(0, 0, 1.0)
	var prompt: Dictionary = walker.interaction_prompt()
	_check(str(prompt.get("primary", "")).begins_with("Hold"), "the jammed wheel: hold to dig it out")
	_check(not walker.dig_for(2.0), "it takes a while")
	_check(walker.dig_for(2.5) and walker.state == "walking" and not walker._dust.visible, "dug out: it wakes and walks home")
	_check(screen.cargo_state(walkers[0]) == "recovered", "Cargo: Walker 1 recovered")
	_check(RULES.b_reason(builder) == "Nothing to build with yet", "still nothing to build with on the way")
	var home_in := _run(walker, 2400.0, func(): return walker.state == "parked")
	_check(home_in, "it walks all the way home")
	_check(_flat(walker.global_position, lander) < 60.0, "and parks by the lander (%.0f m)" % _flat(walker.global_position, lander))
	_check(world.notes.is_open("walker_home") and int(MHChapterOne.stock.get("airlock", 0)) == 1, "home: a thought, and its airlock kit")

	# The Site plan's first lesson.
	_check(RULES.b_reason(builder) == "" and RULES.stage(builder) == "set_down", "B opens the Site plan now")
	_check(RULES.offered(builder, "general") and RULES.offered(builder, "airlock") and not RULES.offered(builder, "living") and not RULES.offered(builder, "solar"), "only the module and its airlock on the bar")
	builder.kind = "general"
	var far_cell := Vector2i(roundi((lander.x + 1600.0) / builder.CELL), roundi(lander.z / builder.CELL))
	_check(builder._cells(far_cell, far_cell).size() == 6, "the module is a fixed 2 × 3 cells")
	_check(RULES.zone_reason(builder, "general", builder._cells(far_cell, far_cell)).begins_with("Only where you've explored"), "not on ground you haven't explored")
	_check(builder._zone_cost(builder._cells(far_cell, far_cell)) == 0, "and it's free: it came whole")
	var cells := _module_spot(builder, lander)
	_check(cells.size() == 6, "somewhere explored near the lander takes it")
	var module := _place(builder, cells)
	_check(bool(module.get("carried", false)) and int(module.cost) == 0, "placed: the carried module")
	_check(builder._invalid_reason(builder._cells(cells[0], cells[0])) != "", "only the one module")
	# Its airlock on an outside wall.
	builder.kind = "airlock"
	var airlock_cells: Array = []
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not airlock_cells.is_empty(): break
			builder.airlock_direction = d
			var try: Array = [c + d]
			if builder._invalid_reason(try).is_empty(): airlock_cells = try
	_check(not airlock_cells.is_empty(), "an airlock fits on its outside wall")
	_place(builder, airlock_cells)

	# Close the plan: it carries the module there and lowers it.
	builder._toggle()
	_check(builder.build_mode, "the plan opens")
	builder._toggle()
	_check(walker.state == "carrying" and not builder.root.visible, "plan closed: it picks the module up; the rooms wait")
	_check(RULES.b_reason(builder) != "", "B waits while it works")
	var down := _run(walker, 600.0, func(): return walker.state == "done")
	_check(down, "it carries it there and lowers it")
	_check(builder.root.visible and is_zero_approx(builder.root.position.y) and not walker._module.visible, "down: the real module is there")
	_check(builder._history.is_empty(), "set down for good: undo won't take it back")
	_check(RULES.stage(builder) == "", "the Site plan's open as usual now")
	_check(RULES.kit_left(builder).size() == 5, "the fit-out kit is yours to place (%d)" % RULES.kit_left(builder).size())
	var interior: Node = world.get_node_or_null("InteriorBuild")
	if interior == null:
		for child in world.get_children(): if child.has_method("_tab_ids"): interior = child
	_check(interior != null and interior._tab_ids() == [interior.UNPACKED_TAB], "inside, only the kit on the bar")
	if interior != null and interior._catalog_items.is_empty(): interior._catalog_items.assign(interior._catalogue_ids())
	_check(interior != null and interior._unpacked_ids().size() == 5, "all five pieces of it (%s)" % str(interior._unpacked_ids() if interior != null else []))
	_check(MHChapterOne.known.has("ice_drill") and world.notes.is_open("module_plans") and world.notes.is_settled("walker_home"), "its plans: an ice extractor")

	# The first night in a real room.
	var inside_cell: Vector2i = cells[2]
	player.global_position = Vector3(inside_cell.x * builder.CELL, builder.habitat_base_y + 1.0, inside_cell.y * builder.CELL)
	MHGame.sol_hour = 22.0
	walker._look()
	_check(walker.first_night and world.notes.is_settled("first_room"), "the first night in a real room goes in the journal")

	# Keeping it alive: its own life support, on its own battery.
	var life: Node = world.module_life
	_check(life != null and life.running(), "the module runs its own life support")
	_check(world.notes.is_open("module_power"), "and a thought: it won't see out a heated night alone")
	_check(life != null and life.player_inside() and world.body.surroundings() == life.conditions(), "inside, you breathe the module's air")
	var alone: Dictionary = life.core.runway(18.0, 14.0)
	_check(float(alone.power) > 0.0, "alone, its battery runs out in the night (after %.1f h)" % float(alone.power))
	# The blanket: laid by the lander, rolled up, carried, laid by the socket.
	var pack: Node = world.drop_field.sites.power.pack
	pack.where = "ground"
	pack.lay_out("lander")
	_check(float(world.cabin_life.core.pack_kwh) > 0.0, "the blanket powers the lander")
	_check(str(pack.interaction_prompt().get("primary", "")) == "Roll it up", "with the module down, it can be rolled up")
	pack.interact()
	_check(pack.where == "carried" and is_zero_approx(float(world.cabin_life.core.pack_kwh)), "rolled up and carried: the lander's back on its own panels")
	var socket: Vector3 = life.socket_spot()
	var out := Vector3(socket.x - life._centre().x, 0, socket.z - life._centre().z).normalized()
	player.global_position = socket + out * 3.0
	pack.put_down()
	_check(str(pack.interaction_prompt().get("primary", "")).ends_with("by the module"), "by the socket: lay it out there")
	pack.interact()
	_check(pack.where == "laid" and pack.laid_at == "module" and life.has_blanket(), "laid by the module and plugged in")
	_check(world.notes.is_settled("module_power"), "the thought's answered")
	life.core.battery_kwh = life.core.battery_cap
	var with_blanket: Dictionary = life.core.runway(18.0, 14.0)
	_check(float(with_blanket.power) < 0.0, "with the blanket, it holds a heated night (%.1f)" % float(with_blanket.power))

	# Saved and loaded.
	var at: Vector3 = walker.global_position
	var state: Dictionary = world.current_state()
	world.queue_free()
	await process_frame
	var again = await _new_world(state)
	var walker2: Node3D = again.walker
	_check(walker2 != null and walker2.state == "done" and walker2.global_position.distance_to(at) < .5 and walker2.tracks_laid, "the walker's kept")
	var kept: Array = again.builder.zones.filter(func(z): return bool(z.get("carried", false)))
	_check(kept.size() == 1 and int(kept[0].cost) == 0, "the module's kept, still free")
	_check(not walker2._module.visible, "and isn't on the walker's back again")
	_check(again.module_life != null and again.module_life.has_blanket(), "its life support and the blanket are kept")
	var pack2: Node = again.drop_field.sites.power.pack
	_check(pack2.where == "laid" and pack2.laid_at == "module", "the blanket's still by the module")
	again.queue_free()
	await process_frame
	if failures == 0:
		print("Walker test passed: stalled 2 km out, lamp blinking; B waits; tracks and their thought; the photo sent up and Castellanos's text; seen, dug out, walked home and parked; the plan's first lesson (the module and its airlock, explored ground, free); carried and lowered; the fit-out kit; its plans; the first night; saved and loaded.")
	quit(1 if failures > 0 else 0)
