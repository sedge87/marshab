extends SceneTree

# A robot run through the opening, landing to a furnished General Module,
# with the real systems and the real clock (sped up), logging everything the
# player would see: notices, ARDEN's captions, hints, replies, thoughts, the
# sol and part, and anything the robot got stuck on. Not a pass/fail test:
# it writes a timeline to .claude_tmp/playthrough_log.txt for the beat sheet.
# godot --headless --path . --script res://tests/opening_playthrough.gd
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const RULES := preload("res://scripts/build_rules.gd")
const SPEED := 8.0          # Engine.time_scale while it runs
const WALK := 4.0           # m/s, a player walking with pauses to look
const STEP := 20.0          # metres per teleport hop
const LOG_PATH := "res://.claude_tmp/playthrough_log.txt"

var world: Node
var player: Node3D
var lines: PackedStringArray = []
var stuck: PackedStringArray = []
var play_s := 0.0
var _last := {}
var _reply_seen := 0.0
var _voice_since := 0.0
var _voice_len := 0.0

func _stamp() -> String:
	var sol := 1
	if world != null and world.get("builder") != null: sol = floori(float(world.builder.simulation().hours_run) / 24.0) + 1
	var h := MHGame.sol_hour
	return "%6.0fs  S%d %02d:%02d  P%d" % [play_s, sol, int(h), int(fmod(h, 1.0) * 60.0), world.opening_part() if world != null and world.has_method("opening_part") else 0]

func log_line(kind: String, text: String) -> void:
	var line := "%s  %-8s %s" % [_stamp(), kind, text.replace("\n", " / ")]
	lines.append(line)
	print(line)

func step(text: String) -> void:
	log_line("----", text)

func got_stuck(text: String) -> void:
	stuck.append("%s  %s" % [_stamp(), text])
	log_line("STUCK", text)

# ---------- watching the screen ----------

func _watch(delta: float) -> void:
	play_s += delta
	if world == null or not is_instance_valid(world): return
	# Notices under the compass.
	var line = MHNotices._line
	if line != null and is_instance_valid(line):
		var e: Dictionary = line._shown_entry
		var key := "%s|%s" % [str(e.get("heading", "")), str(e.get("text", ""))]
		if not e.is_empty() and key != str(_last.get("notice", "")):
			log_line("NOTICE", "%s%s: %s  (queue %d)" % ["[!] " if bool(e.get("pressing", false)) else "", str(e.get("heading", "")), str(e.get("text", "")), line._queue.size()])
		_last["notice"] = key if not e.is_empty() else ""
		if line._queue.size() >= 3 and not bool(_last.get("pile", false)): log_line("PILEUP", "%d notices waiting" % line._queue.size())
		_last["pile"] = line._queue.size() >= 3
	# ARDEN / cast captions.
	var d = MHAudio.director()
	if d != null:
		var cap = d.get("_caption")
		if cap != null and is_instance_valid(cap) and cap != _last.get("caption"):
			var words: Array = (cap as Node).find_children("*", "Label", true, false).map(func(l): return str(l.text))
			log_line("VOICE", " · ".join(words))
		_last["caption"] = cap
		# Headless audio never finishes a line: end it after its length.
		var v: AudioStreamPlayer = d.get("_voice")
		if v != null and v.playing:
			if _voice_since == 0.0: _voice_len = v.stream.get_length() if v.stream != null else 3.0
			_voice_since += delta
			if _voice_since > _voice_len + .3:
				v.stop()
				_voice_since = 0.0
				v.finished.emit()
		else: _voice_since = 0.0
	# Hints (the equipment note panel).
	var hud = world.get("explore_hud")
	if hud != null and is_instance_valid(hud) and hud.get("_note_title") != null:
		var t := float(hud._note_time_left)
		if t > float(_last.get("hint_t", 0.0)) + .5: log_line("HINT", "%s: %s" % [hud._note_title.text, hud._note_body.text])
		_last["hint_t"] = t
	# Replies: the robot answers 1 after two seconds.
	var r = world.get("replies")
	if r != null and r.showing():
		var id := str(r._shown.id)
		if id != str(_last.get("reply", "")):
			var opts: Array = (r._shown.replies as Array).map(func(x): return str(x.text))
			log_line("REPLY?", "%s: %s  -> [%s]" % [str(r._shown.who), str(r._shown.line).left(70), " | ".join(opts)])
			_reply_seen = 0.0
		_last["reply"] = id
		_reply_seen += delta
		if _reply_seen > 2.0:
			log_line("SAY", str((r._shown.replies as Array)[0].text))
			r.choose(0)
	# Thoughts: new ones and the top one.
	var notes = world.get("notes")
	if notes != null:
		var ids: Array = notes.open.map(func(t): return str(t.id))
		for id in ids:
			if not (_last.get("open", []) as Array).has(id): log_line("THINK+", "%s: %s" % [id, notes.text_of(notes.open[notes._find(id)])])
		for id in _last.get("open", []):
			if not ids.has(id): log_line("THINK-", "%s%s" % [id, " (settled)" if notes.is_settled(id) else " (let go)"])
		_last["open"] = ids
		var top: Array = notes.thoughts()
		var top_id := str(top[0].id) if not top.is_empty() else ""
		if top_id != str(_last.get("top", "")): log_line("TOP", top_id)
		_last["top"] = top_id
	var card := int(world.get("sol_card_shown")) if world.get("sol_card_shown") != null else -1
	if card != int(_last.get("card", -1)) and card > 1: log_line("CARD", "SOL %d" % card)
	_last["card"] = card
	# Held still (cut-scenes, the slate, riding).
	if player != null and is_instance_valid(player):
		var frozen := bool(player.get_meta("ui_freeze", false))
		if frozen != bool(_last.get("freeze", false)): log_line("FREEZE", "on" if frozen else "off")
		_last["freeze"] = frozen

# ---------- moving about ----------

func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var before := Time.get_ticks_usec()
		await process_frame
		left -= maxf(.001, (Time.get_ticks_usec() - before) / 1000000.0 * Engine.time_scale)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + 1.0, at.z)

## Walks (hops) to `to`, letting the play time a walk takes go by.
func go(to: Vector3, what: String, stop_short := 2.5) -> void:
	var from := player.global_position
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var dist := flat.length() - stop_short
	if dist <= 0.0: return
	log_line("WALK", "%s (%.0f m)" % [what, dist])
	var dir := flat.normalized()
	var done := 0.0
	while done < dist:
		var hop := minf(STEP, dist - done)
		done += hop
		var p := from + dir * done
		player.global_position = ground(p)
		player.velocity = Vector3.ZERO
		var gary = world.get("scout_rover")
		if gary != null and is_instance_valid(gary) and not bool(gary.get("rescuing")) and (gary as Node3D).global_position.distance_to(player.global_position) > 40.0:
			(gary as Node3D).global_position = ground(player.global_position + Vector3(4, 0, 4))
		player.look_at(Vector3(to.x, player.global_position.y, to.z), Vector3.UP)
		await wait(hop / WALK)

func face(at: Vector3) -> void:
	player.look_at(Vector3(at.x, player.global_position.y, at.z), Vector3.UP)

# ---------- the run ----------

func _initialize() -> void:
	MHGame.site_id = "region"; MHGame.set_mode("survival"); MHGame.pending_save_state = {}; MHGame.landing_target = Vector2.INF
	MHGame.tutorial_mode = MHGame.default_tutorial_mode()
	MHGame.start_new_challenge()
	MHChapterOne.reset()
	world = load("res://scenes/mars_world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	player = world.player
	Engine.time_scale = SPEED
	process_frame.connect(func(): _watch(root.get_process_delta_time()))
	await run()
	Engine.time_scale = 1.0
	lines.append("")
	lines.append("STUCK (%d):" % stuck.size())
	lines.append_array(stuck)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.claude_tmp"))
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("playthrough done: %d lines, %d stuck" % [lines.size(), stuck.size()])
	quit(0)

func run() -> void:
	var lander: Node3D = world.lander
	# ---- Part 1: down ----
	step("Touchdown, in the seat")
	await wait(12.0)
	if world.slate_cradle != null and is_instance_valid(world.slate_cradle):
		if not world.slate_cradle.waiting: got_stuck("the slate hadn't lit up after 12 s")
		step("Pick up the slate, look through it")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		world.slate_cradle.interact()
		await wait(8.0)
		world.pda.close()
	else: got_stuck("no slate on the console")
	await wait(20.0)
	step("Open the hatch, step out")
	lander.set_hatch(true)
	world._update_lander_intro()
	await wait(6.0)
	player.global_position = ground(lander.ramp_foot(4.0))
	await wait(4.0)

	var drop: Node = world.storm_drop
	await go(drop.ridge, "to the parachute ridge")
	await wait(4.0)
	step("Open pallet 1")
	drop.pallet.open(false)
	await wait(5.0)
	drop.cartridge.interact(player)
	if str(drop.cartridge.where) != "carried": got_stuck("couldn't pick up the cartridge")
	await go(lander.global_position, "carrying the cartridge home", 4.0)
	var port: Node = world.cabin_life.port
	player.global_position = ground(lander.ramp_foot(1.0))
	if not drop.cartridge.claim(port, "interact"): got_stuck("the port wouldn't take the cartridge")
	await wait(6.0)

	var field: Node = world.drop_field
	# Back to the ridge's view of pallets 2 and 3 if they aren't known.
	var known: Node = world.known
	if not known.knows(field.sites.power.id()): got_stuck("pallets 2-3 not known after the ridge")
	await ready_for("before pallet 2")
	await go(field.sites.power.pallet.global_position, "to pallet 2 (power)")
	step("Open pallet 2, carry the blanket home")
	field.sites.power.pallet.open(false)
	await wait(4.0)
	field.sites.power.pallet.interact(player)
	var pack: Node = field.sites.power.pack
	if str(pack.where) != "carried": got_stuck("couldn't pick up the power pack")
	await go(lander.to_global(Vector3(5, 0, 3)), "carrying the power pack home", 0.0)
	pack.put_down()
	pack.interact(player)
	if str(pack.where) != "laid": got_stuck("the blanket wasn't laid out")
	await wait(5.0)

	await ready_for("before pallet 3")
	await go(field.sites.gary.pallet.global_position, "to pallet 3 (GAR-Y)")
	step("Open pallet 3, lift GAR-Y out")
	field.sites.gary.pallet.open(false)
	await wait(3.0)
	field.sites.gary.pallet.interact(player)
	var t := 0.0
	while field.meeting != null and t < 120.0:
		await wait(1.0)
		t += 1.0
	if field.meeting != null: got_stuck("GAR-Y's wake-up never ended")
	await wait(4.0)
	if not known.knows(field.sites.tools.id()): got_stuck("pallet 4 not known after GAR-Y")
	await refill("before pallet 4")
	await go(field.sites.tools.pallet.global_position, "to pallet 4 (tools)")
	step("Open pallet 4")
	field.sites.tools.pallet.open(false)
	await wait(5.0)
	await go(lander.ramp_foot(4.0), "home to the lander", 0.0)

	# The afternoon: wait about near GAR-Y for the sunset.
	var sunset := float((MHGame.site().get("day_cycle", {}) as Dictionary).get("sunset_hour", 19.0))
	step("Waiting out the afternoon by the lander (%02d:%02d now)" % [int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60)])
	var gary: Node3D = world.scout_rover
	t = 0.0
	while MHGame.sol_hour < sunset - .2 and MHGame.sol_hour > 6.0 and t < 2000.0:
		await wait(5.0)
		t += 5.0
		if gary != null and gary.has_meta("sunset_offer"): break
	if gary != null:
		player.global_position = ground(gary.global_position + Vector3(3, 0, 0))
		await wait(2.0)
		if gary.has_meta("sunset_offer"):
			step("GAR-Y asks to watch the sunset: yes")
			gary.interact(player)
			t = 0.0
			while bool(player.get_meta("ui_freeze", false)) and t < 200.0:
				await wait(1.0)
				t += 1.0
		else: got_stuck("no sunset offer from GAR-Y")
	step("Into the cabin for the night")
	player.global_position = lander.to_global(Vector3(0, 1.2, .5))
	lander.set_hatch(false)
	await wait(20.0)
	await _sleep_to_dawn()

	# ---- Part 2: the lifepod days ----
	var pod: Node = world.lifepod
	step("Sol 2: the jobs")
	await wait(10.0)
	lander.set_hatch(true)
	player.global_position = ground(lander.ramp_foot(4.0))
	await wait(3.0)
	# Salvage near the lander.
	var handles: Array = world.get_tree().get_nodes_in_group("salvage_piece")
	handles.sort_custom(func(a, b): return a.global_position.distance_to(lander.global_position) < b.global_position.distance_to(lander.global_position))
	for i in mini(5, handles.size()):
		await go(handles[i].global_position, "to storm debris %d" % (i + 1))
		handles[i].interact(player)
		await wait(3.0)
	await go(lander.global_position, "back to the bench", 4.0)
	var printer: Node = pod.bench.stations.printer
	step("Print the hitch")
	printer.interact(player)
	if str(pod.printing) == "": got_stuck("the printer didn't start (%d parts)" % pod.parts)
	t = 0.0
	while str(pod.printing) != "" and t < 600.0:
		await wait(5.0)
		t += 5.0
	# The frost patch by pallet 4: ice by hand.
	var frost: Node = pod.sites.frost
	await ready_for("before the frost")
	await go(frost.global_position, "to the frost patch")
	step("Chip ice, carry it home, melt it")
	frost.chip_for(2.0)
	await wait(4.0)
	var ice := _carried(pod)
	if ice == null: got_stuck("no ice chunk from the frost")
	await go(lander.global_position, "carrying ice home", 4.0)
	if ice != null and not ice.claim(pod.bench.stations.melter, "interact"): got_stuck("the melter wouldn't take the ice")
	await wait(4.0)
	# The iron outcrop: a sample for the bench.
	var iron: Node = pod.sites.iron
	await refill("before the iron")
	await go(iron.global_position, "to the iron outcrop", 20.0)
	await wait(3.0)
	var cam: Node = world.slate_camera
	face(iron.global_position)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	await wait(1.0)
	var shot: Dictionary = await cam.take() if cam != null else {}
	log_line("PHOTO", str(shot.get("caption", "(none)")))
	await go(iron.global_position, "up to the outcrop", 2.0)
	iron.interact(player)
	iron.chip_for(2.0)
	await wait(3.0)
	var sample := _carried(pod)
	if sample == null: got_stuck("no rock sample from the iron")
	await go(lander.global_position, "carrying the sample home", 4.0)
	if sample != null and not sample.claim(pod.bench.stations.study, "interact"): got_stuck("the bench wouldn't take the sample")
	await wait(6.0)
	# GAR-Y's sled, with the hitch.
	if gary != null and pod.prints.has("hitch"):
		await refill("before the sled run")
		await go(frost.global_position, "to the frost patch with GAR-Y")
		gary.global_position = frost.global_position + Vector3(3, .3, 0)
		frost.chip_for(2.0)
		await wait(3.0)
		if float(pod.sled_kg) <= 0.0: got_stuck("no ice on GAR-Y's sled")
		await go(lander.ramp_foot(4.0), "home with GAR-Y's sled", 0.0)
		gary.global_position = lander.ramp_foot(3.0)
		await wait(2.0)
		gary.interact(player)
	log_line("STATE", "jobs %s, walker due %s" % [str(pod.jobs), str(pod.walker_due)])
	# Evening, then the night the walker moves.
	step("Evening by the lander")
	t = 0.0
	while MHGame.sol_hour < sunset + .5 and MHGame.sol_hour > 6.0 and t < 3000.0:
		await wait(10.0)
		t += 10.0
	player.global_position = lander.to_global(Vector3(0, 1.2, .5))
	lander.set_hatch(false)
	await wait(10.0)
	await _sleep_to_dawn()
	if not pod.walker_moved: got_stuck("the walker didn't move in the night (due %s)" % str(pod.walker_due))

	# ---- Part 3: Walker 1 ----
	var walker: Node3D = world.walker
	step("Sol 3: out to the tracks")
	lander.set_hatch(true)
	player.global_position = ground(lander.ramp_foot(4.0))
	await wait(4.0)
	var marks: Array = world.get_tree().get_nodes_in_group("walker_tracks")
	marks.sort_custom(func(a, b): return a.global_position.distance_to(lander.global_position) < b.global_position.distance_to(lander.global_position))
	if marks.is_empty(): got_stuck("no tracks")
	else:
		await go(marks[2].global_position, "to the nearest tracks", 6.0)
		await wait(3.0)
		face(marks[2].global_position)
		(player.get_node("Head") as Node3D).rotation.x = -0.5
		await wait(1.0)
		shot = await cam.take() if cam != null else {}
		log_line("PHOTO", str(shot.get("caption", "(none)")))
		if not walker.can_send():
			got_stuck("the photo of the tracks doesn't count to send up")
			MHJournal.add_photo(MHJournal.today(3), "", "Walker tracks", ["walker_tracks"])
		if walker.can_send(): walker.send_up()
		await wait(4.0)
	await refill("before following the tracks")
	# Follow the tracks out until it's in sight.
	var target: Vector3 = walker.global_position
	var out_dir := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z)
	var hops := 0
	while not walker.seen and hops < 200:
		var p := player.global_position + out_dir.normalized() * STEP
		player.global_position = ground(p)
		face(target)
		await wait(STEP / WALK)
		hops += 1
	log_line("STATE", "walker seen at %.0f m" % Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length())
	await go(walker.to_global(walker.STEP_OFF), "up to Walker 1's ladder", 0.0)
	player.global_position = walker.to_global(walker.STEP_OFF) + Vector3(0, .1, 0)
	step("Climb aboard")
	if not walker.get_node("Ladder").interact(): got_stuck("couldn't climb aboard")
	await wait(3.0)
	if not walker.open_nav(): got_stuck("the nav screen didn't open")
	var nav: Node = walker._nav
	await wait(3.0)
	log_line("NAV", "need %d landmarks; known: %s" % [nav.need, str(nav.landmarks.filter(func(m): return bool(m.known)).map(func(m): return str(m.get("name", m.id))))])
	nav.sight_fixed()
	await wait(3.0)
	for m in nav.landmarks:
		if str(nav.step) != "fix": break
		if bool(m.known):
			nav.pick(str(m.id))
			await wait(2.0)
	if str(nav.step) != "home": got_stuck("the nav never locked (%d known landmarks)" % nav.landmarks.filter(func(m): return bool(m.known)).size())
	else: nav.set_home()
	step("Riding it home")
	t = 0.0
	while str(walker.state) != "parked" and t < 2400.0:
		await wait(5.0)
		t += 5.0
	if str(walker.state) != "parked": got_stuck("the walker never parked (%s)" % str(walker.state))
	log_line("STATE", "ride home took %.0f s of play" % t)
	if walker.riding:
		walker.climb_down()
		await wait(4.0)
	await wait(4.0)

	# The Site plan: the module and its airlock.
	var builder: Node = world.builder
	step("B: place the General Module and its airlock")
	log_line("STATE", "B says: '%s'" % RULES.b_reason(builder))
	var cells := _module_spot(builder, lander.global_position)
	if cells.is_empty(): got_stuck("no spot for the module near the lander")
	else:
		builder._toggle()
		_place(builder, cells)
		builder.kind = "airlock"
		var placed_airlock := false
		for c in cells:
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if placed_airlock: break
				builder.airlock_direction = dir
				if builder._invalid_reason([c + dir]).is_empty():
					_place(builder, [c + dir])
					placed_airlock = true
		if not placed_airlock: got_stuck("no airlock spot on the module")
		await wait(5.0)
		builder._toggle()
		t = 0.0
		while str(walker.state) != "done" and t < 900.0:
			await wait(5.0)
			t += 5.0
		if str(walker.state) != "done": got_stuck("the module never came down (%s)" % str(walker.state))
		log_line("STATE", "carry and set-down took %.0f s of play" % t)

		# Inside: the fit-out kit.
		step("Into the module: the fit-out kit")
		var inside: Vector2i = cells[2]
		player.global_position = Vector3(inside.x * builder.CELL, builder.habitat_base_y + 1.0, inside.y * builder.CELL)
		await wait(4.0)
		for id in RULES.KIT:
			var spot := _free_spot(builder, str(id), cells)
			if spot.is_empty():
				got_stuck("no spot found for %s: %s" % [id, _why(builder, str(id), cells)])
				continue
			var visual := Node3D.new()
			if builder.place_free_interior_equipment(str(id), spot.at, spot.rot, spot.cell, visual): log_line("PLACED", str(id))
			else: got_stuck("placing %s refused" % id)
			await wait(3.0)
		log_line("STATE", "kit left: %s" % str(RULES.kit_left(builder)))
	step("The first night in the module")
	t = 0.0
	while MHGame.sol_hour < 21.0 and MHGame.sol_hour > 6.0 and t < 3000.0:
		await wait(10.0)
		t += 10.0
	await wait(20.0)
	step("End")

## A careful player: home to the cabin, hatch shut, suit full, a ration if hungry.
func refill(why := "") -> void:
	var lander: Node3D = world.lander
	await go(lander.ramp_foot(2.0), "home to refill%s" % ("" if why.is_empty() else " (" + why + ")"), 0.0)
	player.global_position = lander.to_global(Vector3(0, 1.2, .5))
	lander.set_hatch(false, true)
	var t := 0.0
	while not (lander.sealed_cabin() and world.suit.full()) and t < 120.0:
		await wait(1.0)
		t += 1.0
	if not world.suit.full(): got_stuck("the suit didn't fill in the cabin (o2 %.2f, power %.2f, where %s, seal %s, in cabin %s, hatch open %s, cabin o2 %.2f kg, battery %.2f kWh)" % [float(world.suit.o2), float(world.suit.power), str(world.suit.where), str(lander.seal_state), str(lander.cabin_contains(player.global_position)), str(lander.hatch_open()), float(world.cabin_life.core.tank_o2_kg), float(world.cabin_life.core.battery_kwh)])
	var body: Node = world.get("body")
	if body != null and body.peckish() and world.lifepod != null:
		if world.lifepod.eat_ration(): log_line("EAT", "a ration")
	log_line("STATE", "refilled in %.0f s" % t)
	lander.set_hatch(true)
	player.global_position = ground(lander.ramp_foot(4.0))
	await wait(2.0)

## Tops up first when the suit's under `need` of a tank.
func ready_for(trip: String, need := .8) -> void:
	if float(world.suit.o2) < need: await refill(trip)

func _sleep_to_dawn() -> void:
	var sleep: Node = world.get("sleep")
	if sleep == null:
		got_stuck("no sleep")
		return
	step("Sleep until dawn (%s)" % sleep.blocked_reason())
	if not sleep.blocked_reason().is_empty():
		got_stuck("can't sleep: %s" % sleep.blocked_reason())
	sleep.sleep(sleep._until_sunrise())
	var t := 0.0
	while bool(sleep.asleep) and t < 600.0:
		await wait(2.0)
		t += 2.0
	log_line("STATE", "woke: %s" % sleep.summary())
	await wait(5.0)

func _carried(pod: Node) -> Node:
	for find in pod.get_tree().get_nodes_in_group("carried_find"):
		if str(find.where) == "carried" and not find.is_queued_for_deletion(): return find
	return null

func _module_spot(builder: Node, lander: Vector3) -> Array:
	builder.kind = "general"
	for r in [30.0, 42.0, 55.0, 70.0]:
		for s in 16:
			var a := s * TAU / 16.0
			var p: Vector3 = lander + Vector3(sin(a), 0, cos(a)) * float(r)
			var cell := Vector2i(roundi(p.x / builder.CELL), roundi(p.z / builder.CELL))
			var cells: Array = builder._cells(cell, cell)
			if builder._invalid_reason(cells).is_empty(): return cells
	return []

func _place(builder: Node, cells: Array) -> void:
	if builder.zones.is_empty(): builder.habitat_base_y = builder._proposed_base_y(cells)
	var zone := {"kind": builder.kind, "cells": cells, "door_direction": builder.airlock_direction, "cost": builder._zone_cost(cells)}
	RULES.placed(builder, zone)
	builder.zones.append(zone)
	builder._history.append({"type": "zone", "zone": zone})
	builder._rebuild()

## A floor spot in the module where `id` is allowed, scanning a 0.5 m grid.
func _free_spot(builder: Node, id: String, cells: Array) -> Dictionary:
	for cell in cells:
		for dx in [-1.0, -.5, 0.0, .5, 1.0]:
			for dz in [-1.0, -.5, 0.0, .5, 1.0]:
				for rot in [0.0, PI * .5]:
					var at := Vector3(cell.x * builder.CELL + dx, builder.habitat_base_y, cell.y * builder.CELL + dz)
					if builder.free_interior_invalid_reason(id, at, Vector3.UP, rot).is_empty(): return {"at": at, "rot": rot, "cell": cell}
	return {}

func _why(builder: Node, id: String, cells: Array) -> String:
	var c: Vector2i = cells[2]
	return builder.free_interior_invalid_reason(id, Vector3(c.x * builder.CELL, builder.habitat_base_y, c.y * builder.CELL), Vector3.UP, 0.0)
