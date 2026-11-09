extends SceneTree

# A robot run through the guided days, version 2 (docs/opening-days.md):
# day 1 the cargo and the sunset rise, day 2 GAR-Y and the spares crate,
# day 3 Walker 1's photo hunt, the seal and the module's mark, day 4 the
# module set down and furnished, then day 5 opens. Real systems, the clock
# sped up, logging what a player would see: notices, captions, Castellanos's
# calls, replies, thoughts. Not pass/fail: it writes a timeline to
# .claude_tmp/guided_playthrough_log.txt, with STUCK lines for anything that
# went wrong (THOUGHT-EARLY: a thought before anyone's spoken).
# godot --headless --path . --script res://tests/guided_playthrough.gd
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const RULES := preload("res://scripts/build_rules.gd")
const SPEED := 8.0          # Engine.time_scale while it runs
const WALK := 4.0           # m/s, a player walking with pauses to look
const STEP := 20.0          # metres per teleport hop
const LOG_PATH := "res://.claude_tmp/guided_playthrough_log.txt"

# Thoughts set off by what you see or do, not by a call: fine before anyone speaks.
const SEEN_OR_DONE := ["slate", "cradle_empty", "chutes", "module_air", "bed", "cold", "water", "rations_low", "photo", "sunset_gary", "tools", "power_pallet"]
var day_start := {}             # day -> play seconds when it began

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
		var id := str(r._shown.id) + "|" + "|".join((r._shown.replies as Array).map(func(x): return str(x.text)))
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
			if not (_last.get("open", []) as Array).has(id):
				log_line("THINK+", "%s: %s" % [id, notes.text_of(notes.open[notes._find(id)])])
				var radio_now = world.get("radio")
				if not SEEN_OR_DONE.has(id) and radio_now != null and (radio_now.heard as Dictionary).is_empty(): got_stuck("THOUGHT-EARLY: '%s' before anyone's spoken" % id)
		for id in _last.get("open", []):
			if not ids.has(id): log_line("THINK-", "%s%s" % [id, " (settled)" if notes.is_settled(id) else " (let go)"])
		_last["open"] = ids
		var top: Array = notes.thoughts()
		var top_id := str(top[0].id) if not top.is_empty() else ""
		if top_id != str(_last.get("top", "")): log_line("TOP", top_id)
		_last["top"] = top_id
	var radio = world.get("radio")
	if radio != null:
		var on := str(radio.playing)
		if on != str(_last.get("radio", "")):
			if not str(_last.get("radio", "")).is_empty(): log_line("RADIO-", str(_last.get("radio", "")))
			if not on.is_empty(): log_line("RADIO+", on)
		_last["radio"] = on
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
	if int(world.opening_version) < 2: got_stuck("a new game isn't on the guided days, version 2")
	else: await run()
	Engine.time_scale = 1.0
	lines.append("")
	lines.append("DAYS (play minutes):")
	for day in day_start: lines.append("  day %d started at %.1f min" % [int(day), float(day_start[day]) / 60.0])
	lines.append("  ended at %.1f min" % (play_s / 60.0))
	lines.append("")
	lines.append("STUCK (%d):" % stuck.size())
	lines.append_array(stuck)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.claude_tmp"))
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("guided playthrough done: %d lines, %d stuck" % [lines.size(), stuck.size()])
	quit(0)

func _day(n: int, what: String) -> void:
	day_start[n] = play_s
	step("DAY %d: %s" % [n, what])

## Waits until a call has been heard and is over (or `limit` seconds of play).
func call_done(section: String, limit := 300.0) -> bool:
	var radio: Node = world.radio
	var t := 0.0
	while (not radio.heard.has(section) or str(radio.playing) == section) and t < limit:
		await wait(1.0)
		t += 1.0
	if not radio.heard.has(section): got_stuck("no '%s' call within %.0f s (queue %s, playing '%s')" % [section, limit, str(radio.queue), str(radio.playing)])
	return radio.heard.has(section)

func carry_home(item: Node3D, what: String) -> void:
	var lander: Node3D = world.lander
	await ready_for("before the " + what)
	await go(item.global_position, "to the " + what, 1.5)
	item.interact(player)
	if str(item.where) != "carried":
		got_stuck("couldn't pick up the %s (%s)" % [what, str(item.where)])
		return
	await go(lander.global_position + lander.global_basis.z * -9.0, "carrying the %s home" % what, 0.0)
	item.put_down()
	await wait(2.0)
	if not world.lifepod.staged(item): got_stuck("the %s doesn't count as staged by the lander" % what)

func photo(at: Vector3, what: String, pitch := 0.0) -> Dictionary:
	face(at)
	var eye := _eye()
	if eye != null and pitch != 0.0:
		var to := at - eye.global_position
		pitch = atan2(to.y, Vector2(to.x, to.z).length())
	(player.get_node("Head") as Node3D).rotation.x = pitch
	await wait(.2)
	log_line("STATE", "aimed at: %s" % str(world.walker.aimed_part(_eye())))
	var cam: Node = world.slate_camera
	var shot: Dictionary = await cam.take() if cam != null else {}
	log_line("PHOTO", "%s: %s" % [what, str(shot.get("caption", "(none)"))])
	return shot

func _eye() -> Camera3D:
	return player.get_viewport().get_camera_3d()

func run() -> void:
	var lander: Node3D = world.lander
	var days: Node = world.opening_days
	var radio: Node = world.radio
	var notes: Node = world.notes
	var drop: Node = world.storm_drop
	var field: Node = world.drop_field
	var pod: Node = world.lifepod
	var known: Node = world.known

	# ---------------- Day 1 ----------------
	_day(1, "the cargo")
	await wait(12.0)
	if world.slate_cradle != null and is_instance_valid(world.slate_cradle):
		step("Pick up the slate")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		world.slate_cradle.interact()
		await wait(8.0)
		world.pda.close()
	else: got_stuck("no slate on the console")
	await call_done("d1_relock", 400.0)
	if not notes.is_open("air") or not notes.is_open("parachute"): got_stuck("after the first call: air %s, parachute %s" % [notes.is_open("air"), notes.is_open("parachute")])
	step("Open the hatch, step out")
	lander.set_hatch(true)
	world._update_lander_intro()
	await wait(6.0)
	player.global_position = ground(lander.ramp_foot(4.0))
	await wait(4.0)
	if world.scout_rover != null: got_stuck("GAR-Y exists on day 1")
	await go(drop.ridge, "to the parachute ridge")
	await wait(4.0)
	step("Open pallet 1")
	drop.pallet.open(false)
	await wait(4.0)
	await carry_home(drop.cartridge, "air cartridge")
	if not known.knows(field.sites.power.id()): got_stuck("pallets 2 and 4 not known after the ridge")
	await ready_for("before pallet 2")
	await go(field.sites.power.pallet.global_position, "to pallet 2 (power)")
	step("Open pallet 2")
	field.sites.power.pallet.open(false)
	await wait(4.0)
	await carry_home(field.sites.power.pack, "power pack")
	await ready_for("before pallet 4")
	await go(field.sites.tools.pallet.global_position, "to pallet 4 (field kit)")
	step("Open pallet 4")
	field.sites.tools.pallet.open(false)
	await wait(4.0)
	await go(lander.ramp_foot(4.0), "home", 0.0)
	await call_done("d1_cargo")
	if is_inf(days.sunset_spot.x): got_stuck("no sunset rise marked")
	else:
		log_line("STATE", "the rise: %.0f m out" % lander.global_position.distance_to(days.sunset_spot))
		await go(days.sunset_spot, "to Rao's sunset rise", 3.0)
	var t := 0.0
	while not (str(radio.playing) == "d1_sunset" and notes.is_open("photo")) and t < 600.0 and not radio.heard.has("d2_wake"):
		await wait(1.0)
		t += 1.0
	if notes.is_open("photo"):
		await photo(player.global_position + field.sunset.sun_direction() * 50.0, "the sunset", .05)
	else: got_stuck("Castellanos never asked for the sunset photo")
	await call_done("d1_sunset", 400.0)
	if radio.flag("sunset_photo"): log_line("STATE", "she got the photo")
	else: got_stuck("the sunset photo didn't count")
	await _bed_and_sleep()

	# ---------------- Day 2 ----------------
	_day(2, "GAR-Y")
	lander.set_hatch(true)
	player.global_position = ground(lander.ramp_foot(4.0))
	await call_done("d2_wake")
	var gary: Node3D = world.scout_rover
	if gary == null: got_stuck("no GAR-Y after the wake call")
	await ready_for("before the cradle")
	await go(field.sites.gary.pallet.global_position, "to the open cradle", 4.0)
	await wait(4.0)
	if not radio.heard.has("d2_cradle"): got_stuck("no call at the empty cradle")
	if gary != null:
		await go(gary.global_position, "following the tracks to GAR-Y", 6.0)
		t = 0.0
		while (field.gary_working or field.meeting != null) and t < 200.0:
			await wait(1.0)
			t += 1.0
		if field.gary_working: got_stuck("GAR-Y never noticed you")
	await call_done("d2_found", 400.0)
	if not notes.is_open("salvage"): got_stuck("no salvage thought after Castellanos's call")
	var crate: Node3D = field.crate
	if crate == null: got_stuck("no spares crate")
	await refill("before the salvage")
	var handles: Array = world.get_tree().get_nodes_in_group("salvage_piece")
	handles.sort_custom(func(a, b): return a.global_position.distance_to(lander.global_position) < b.global_position.distance_to(lander.global_position))
	for i in mini(3, handles.size()):
		await go(handles[i].global_position, "to storm debris %d" % (i + 1))
		handles[i].interact(player)
		await wait(2.0)
	await go(lander.global_position, "back to the printer", 4.0)
	var printer: Node = pod.bench.stations.printer
	log_line("STATE", "printer says: %s" % str(pod.printer_prompt()))
	printer.interact(player)
	if str(pod.printing) != "hitch": got_stuck("the printer didn't start the hitch (%s, %d parts)" % [str(pod.printing), pod.parts])
	t = 0.0
	while str(pod.printing) != "" and t < 600.0:
		await wait(5.0)
		t += 5.0
	if crate != null and gary != null:
		await ready_for("before the crate")
		await go(crate.global_position, "back out to the crate with GAR-Y", 3.0)
		gary.global_position = crate.global_position + Vector3(2.5, .3, 0)
		log_line("STATE", "crate says: %s" % str(crate.interaction_prompt()))
		if not crate.interact(player): got_stuck("couldn't hitch the crate")
		await go(lander.ramp_foot(4.0), "home with the crate", 0.0)
		gary.global_position = lander.ramp_foot(3.0)
		await wait(2.0)
		log_line("STATE", "GAR-Y says: %s" % str(gary.interaction_prompt()))
		gary.interact(player)
		await wait(2.0)
		log_line("STATE", "crate says: %s" % str(crate.interaction_prompt()))
		if not crate.interact(player): got_stuck("couldn't open the crate at home (%s)" % str(crate.where))
		await call_done("d2_crate")
	if gary != null and not pod.walker_due:
		step("GAR-Y: survey there")
		var why: String = gary.order("survey", lander.global_position + Vector3(0, 0, 25))
		if why != "": got_stuck("survey refused: %s" % why)
		t = 0.0
		while not pod.walker_due and t < 400.0:
			await wait(5.0)
			t += 5.0
	log_line("STATE", "jobs %s, walker due %s, day 2 done %s" % [str(pod.jobs), str(pod.walker_due), str(days.day_done(2))])
	await call_done("d2_sunset", 900.0)
	await _bed_and_sleep()

	# ---------------- Day 3 ----------------
	_day(3, "Walker 1")
	var walker: Node3D = world.walker
	lander.set_hatch(true)
	player.global_position = ground(lander.ramp_foot(4.0))
	await call_done("d3_wake")
	await refill("before the walker")
	var target: Vector3 = walker.global_position
	var hops := 0
	while not walker.seen and hops < 250:
		var dir := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z).normalized()
		player.global_position = ground(player.global_position + dir * STEP)
		face(target)
		await wait(STEP / WALK)
		hops += 1
	log_line("STATE", "walker seen at %.0f m, %.0f m from home" % [Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length(), lander.global_position.distance_to(target)])
	await go(walker.to_global(walker.STEP_OFF), "up to Walker 1's ladder", 0.0)
	player.global_position = walker.to_global(walker.STEP_OFF) + Vector3(0, .1, 0)
	if not walker.get_node("Ladder").interact(): got_stuck("couldn't climb aboard")
	await wait(3.0)
	if not walker.open_nav(): got_stuck("the nav screen didn't open")
	var nav: Node = walker._nav
	await wait(3.0)
	nav.sight_fixed()
	await wait(3.0)
	for m in nav.landmarks:
		if str(nav.step) != "fix": break
		if bool(m.known):
			nav.pick(str(m.id))
			await wait(2.0)
	if str(nav.step) != "home": got_stuck("the nav never locked (%d known landmarks)" % nav.landmarks.filter(func(m): return bool(m.known)).size())
	else: nav.set_home()
	await wait(3.0)
	if str(walker.state) != "coming": got_stuck("set right, but not 'coming' (%s)" % str(walker.state))
	if walker.riding:
		walker.climb_down()
		await wait(4.0)
	await call_done("d3_fixed", 400.0)
	# The photo hunt: a knee, then the front-left wheel.
	var knee: Node3D = walker._knees[3] if walker._knees.size() > 3 else null
	if knee == null: got_stuck("the walker model has no Knee_4: knee photos can't be told apart")
	else:
		player.global_position = ground(knee.global_position + walker.global_basis.x * 5.0)
		face(knee.global_position)
		log_line("STATE", "aiming at: %s" % walker.aimed_part(_eye()))
		await photo(knee.global_position, "a knee", -.3)
		await call_done("d3_photo_knee", 120.0)
	var wheel: Vector3 = walker.to_global(Vector3(-7.7, .8, -5.0))
	player.global_position = ground(wheel + walker.global_basis.x * -4.5)
	face(wheel)
	await photo(wheel, "the front-left wheel", -.35)
	if not walker.fault_found: got_stuck("the front-left wheel photo didn't find the fault (aimed at %s)" % walker.aimed_part(_eye()))
	await call_done("d3_fault", 400.0)
	await refill("home to print the seal")
	await go(lander.global_position, "to the printer", 4.0)
	log_line("STATE", "printer says: %s" % str(pod.printer_prompt()))
	printer.interact(player)
	if str(pod.printing) != "seal": got_stuck("the printer didn't start the seal (%s)" % str(pod.printing))
	t = 0.0
	while str(pod.printing) != "" and t < 600.0:
		await wait(5.0)
		t += 5.0
	await call_done("d3_seal")
	var builder: Node = world.builder
	step("B: mark the module's spot")
	log_line("STATE", "B says: '%s'" % RULES.b_reason(builder))
	var cells := _module_spot(builder, lander.global_position)
	if cells.is_empty(): got_stuck("no spot for the module near the lander")
	else:
		builder._toggle()
		_place(builder, cells)
		builder.kind = "airlock"
		var placed_airlock := false
		for c in cells:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if placed_airlock: break
				builder.airlock_direction = d
				if builder._invalid_reason([c + d]).is_empty():
					_place(builder, [c + d])
					placed_airlock = true
		if not placed_airlock: got_stuck("no airlock spot on the module (%s)" % builder._invalid_reason([cells[0] + Vector2i(1, 0)]))
		await wait(3.0)
		builder._toggle()
		await wait(2.0)
		if not walker.marked: got_stuck("closing the plan didn't mark the spot")
	await call_done("d3_marked")
	await call_done("d3_sunset", 900.0)
	await _bed_and_sleep()

	# ---------------- Day 4 ----------------
	_day(4, "making it home")
	await call_done("d4_wake")
	log_line("STATE", "walker at dawn: %s" % str(walker.state))
	lander.set_hatch(true)
	player.global_position = ground(lander.ramp_foot(4.0))
	await wait(20.0)
	log_line("STATE", "walker 20 s after you step out: %s" % str(walker.state))
	t = 0.0
	while str(walker.state) != "done" and t < 900.0:
		await wait(5.0)
		t += 5.0
	if str(walker.state) != "done": got_stuck("the module never came down (%s)" % str(walker.state))
	log_line("STATE", "set-down took %.0f s of play" % t)
	await call_done("d4_down")
	if not cells.is_empty():
		var module: Node = world.module_life
		if module == null: got_stuck("no module life")
		else:
			var socket: Vector3 = module.socket_spot()
			player.global_position = ground(drop.cartridge.global_position)
			drop.cartridge.interact(player)
			if str(drop.cartridge.where) == "carried":
				await go(socket, "the cartridge to the socket", 1.5)
				if not drop.cartridge.claim(module, "interact"): got_stuck("the socket wouldn't take the cartridge")
			else: got_stuck("couldn't pick up the staged cartridge (%s)" % str(drop.cartridge.where))
			var pack: Node = field.sites.power.pack
			player.global_position = ground(pack.global_position)
			pack.interact(player)
			if str(pack.where) == "carried":
				await go(socket, "the power pack to the socket", 3.0)
				pack.put_down()
				pack.interact(player)
				if str(pack.where) != "laid": got_stuck("the blanket wasn't laid (%s)" % str(pack.where))
			else: got_stuck("couldn't pick up the staged pack (%s)" % str(pack.where))
		step("Into the module: the fit-out kit")
		var inside: Vector2i = cells[2]
		player.global_position = Vector3(inside.x * builder.CELL, builder.habitat_base_y + 1.0, inside.y * builder.CELL)
		await wait(4.0)
		for id in RULES.KIT:
			var spot := _free_spot(builder, str(id), cells)
			if spot.is_empty():
				got_stuck("no spot for %s: %s" % [id, _why(builder, str(id), cells)])
				continue
			var visual := Node3D.new()
			if builder.place_free_interior_equipment(str(id), spot.at, spot.rot, spot.cell, visual): log_line("PLACED", str(id))
			else: got_stuck("placing %s refused" % id)
			await wait(2.0)
	await call_done("d4_home", 300.0)
	await call_done("d4_sunset", 900.0)
	step("Bed in the module")
	if not cells.is_empty():
		var inside: Vector2i = cells[2]
		player.global_position = Vector3(inside.x * builder.CELL, builder.habitat_base_y + 1.0, inside.y * builder.CELL)
	await wait(3.0)
	await _sleep_to_dawn()

	# ---------------- Day 5 ----------------
	_day(5, "open")
	log_line("STATE", "guided %s, hold %.2f, clock x%.1f" % [str(days.guided()), float(world.day_night.hold_at), float(world.day_night.time_scale)])
	if days.guided(): got_stuck("day 5 is still guided")
	if float(world.day_night.hold_at) >= 0.0: got_stuck("day 5's clock is still held")
	await wait(20.0)
	step("End")

## A careful player: home to the cabin, hatch shut, suit full, a ration if hungry.
func refill(why := "") -> void:
	var lander: Node3D = world.lander
	await go(lander.ramp_foot(2.0), "home to refill%s" % ("" if why.is_empty() else " (" + why + ")"), 0.0)
	player.global_position = lander.cabin_start().position
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
	if float(world.suit.o2) < need or float(world.suit.power) < .5: await refill(trip)

## The opening days: wait for "bed", go home, check the hatch holds at night, sleep.
func _bed_and_sleep() -> void:
	var lander: Node3D = world.lander
	var notes: Node = world.notes
	step("Waiting for the day's end")
	var t := 0.0
	while not notes.is_open("bed") and t < 3000.0:
		await wait(10.0)
		t += 10.0
	if not notes.is_open("bed"): got_stuck("no bed thought by %02d:%02d" % [int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60)])
	log_line("STATE", "bed (%s) at %02d:%02d" % [notes.stage("bed"), int(MHGame.sol_hour), int(fmod(MHGame.sol_hour, 1.0) * 60)])
	await go(lander.ramp_foot(2.0), "home for bed", 0.0)
	player.global_position = lander.cabin_start().position
	lander.set_hatch(false, true)
	t = 0.0
	while not lander.sealed_cabin() and t < 60.0:
		await wait(1.0)
		t += 1.0
	var body: Node = world.get("body")
	if body != null and body.peckish() and world.lifepod != null and world.lifepod.eat_ration(): log_line("EAT", "a ration")
	var days: Node = world.get("opening_days")
	if days != null and days.is_night():
		lander.interact()
		log_line("STATE", "hatch at night from inside: %s" % ("held shut" if not lander.hatch_open() else "OPENED"))
	await _sleep_to_dawn()

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
