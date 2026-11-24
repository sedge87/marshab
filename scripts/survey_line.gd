extends Node

## The survey line (opening slice chunk 2, docs/opening-slice.md §4a Scenes
## 10–11 and §5): you plant the two end stakes by hand, and GAR-Y drives
## between them, reading the ground as it goes. The slate draws the profile:
## solid, faint, void, or no reading where GAR-Y couldn't get.
##
## With the survey stakes in hand (key 4), E plants a stake where you stand,
## about a metre ahead. The second stake is the far end (8–60 m away); GAR-Y
## then runs the line. Where you stand matters: the reading only knows the
## ground along the line, and at the Collapse pit a line close to the lip
## reads clearly while one further back is mush.
##
## The ground's void is a model, not a scan of the terrain: a buried tube
## from the pit, under the planned pad and on past it, plus the undercut all
## round the pit (scripts/pad_site.gd says where those are). Every line is
## saved, and the slate's Map page has a Lines tab with each profile.

signal line_done(line: Dictionary)

const MHPalette := preload("res://scripts/mh_palette.gd")
const FIELD_KIT := preload("res://scripts/field_kit.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const STAKE_MODEL := "res://assets/models/chunk2/survey_stake.glb"
const STAKE_SUNK := .12       # pushed this far into the ground
const BUNDLE := preload("res://scripts/stake_bundle.gd")
const AHEAD := 1.1            # m in front of you a stake goes in
const MIN_LENGTH := 8.0
const MAX_LENGTH := 60.0
const STEP := 1.5             # m between readings
const MIN_READINGS := 8
const MAX_READINGS := 32
const STUCK_SECONDS := 40.0   # GAR-Y makes no headway this long: the rest is unresolved
const VOID := .5              # a reading this strong is a void
const FAINT := .25
const PAD_REACH := 7.0        # a line within this of the pad's centre crosses it
const PIT_REACH := 22.0       # within this of the pit's centre, it's a line at the pit
const PIT_KEEP := 9.5         # GAR-Y won't run a line closer than this to the pit's centre
const TUBE_IN := 4.5
const TUBE_OUT := 9.0
const PIT_IN := 10.0          # the undercut reads fully this close to the pit's centre
const PIT_OUT := 22.0
const SHOW_FOR := 14.0        # seconds the profile stays on screen after a run

var world: Node
var pad: Node                 # scripts/pad_site.gd: where the pad, the pit and the void are
var lines: Array = []         # [{a: [x,z], b: [x,z], kind, readings: [float, -1 = no reading], verdict}]
var first := Vector3.INF      # the first stake of the line being laid
var running := {}             # the line GAR-Y is driving, while it runs
var _stakes: Array = []       # stake nodes (both ends of every line)
var _was_down := false
var _overlay: Control
var _panel: Control
var _overlay_until := 0.0
var _clock := 0.0
var _progress_at := 0.0
var _best_t := -1.0
var _stage := ""              # "", "to_start", "run"
var _via: Array = []          # waypoints round the pit on the way to the start
var bundle_taken := false     # the stakes bundle out of the stores pallet
var _bundle: Node

func setup(target_world: Node, target_pad: Node, saved: Dictionary) -> void:
	world = target_world
	pad = target_pad
	name = "SurveyLine"
	add_to_group("survey_line")
	lines = (saved.get("lines", []) as Array).duplicate(true)
	bundle_taken = bool(saved.get("bundle_taken", false))
	_build_overlay.call_deferred()
	_plant_saved.call_deferred()

func export_state() -> Dictionary:
	return {"lines": lines.duplicate(true), "bundle_taken": bundle_taken}

## The stakes come in the stores pallet (pallet 1): a bundle you take out by hand.
func have_stakes() -> bool:
	var drop: Node = world.get("storm_drop")
	if drop == null or drop.pallet == null: return true
	return bundle_taken

## Once the stores pallet's open, the bundle lies across its open top.
func _place_bundle() -> void:
	if bundle_taken or (_bundle != null and is_instance_valid(_bundle)): return
	var drop: Node = world.get("storm_drop")
	if drop == null or drop.pallet == null or not bool(drop.pallet.opened): return
	var pallet: Node3D = drop.pallet
	var at := Transform3D(pallet.global_basis, pallet.global_transform * Vector3(0.0, pallet.SIZE.y - .06, .12))
	_bundle = BUNDLE.new()
	_bundle.setup(self, at)
	_bundle.taken.connect(func() -> void: bundle_taken = true)

# ---------- the ground ----------

## How strongly the ground at a point (site metres) reads as hollow, 0–1.
func void_at(p: Vector2) -> float:
	if pad == null: return 0.0
	var strength := 0.0
	var path: Array = pad.void_path()
	for i in path.size() - 1:
		var d := _to_segment(p, path[i], path[i + 1])
		strength = maxf(strength, 1.0 - smoothstep(TUBE_IN, TUBE_OUT, d))
	var pit: Vector2 = pad.pit_centre()
	if not is_inf(pit.x): strength = maxf(strength, 1.0 - smoothstep(PIT_IN, PIT_OUT, p.distance_to(pit)))
	return strength

## One reading: the ground plus a little noise that's the same every time.
func reading_at(p: Vector2) -> float:
	var n := sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453
	n = (n - floorf(n)) * 2.0 - 1.0
	return clampf(void_at(p) + n * .07, 0.0, 1.0)

static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < .001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## What a line is of: "pad" (it crosses the planned pad), "pit" (by the
## Collapse pit) or "line".
func kind_of(a: Vector2, b: Vector2) -> String:
	var four: Node = get_tree().get_first_node_in_group("chunk_four") if is_inside_tree() else null
	if four != null and bool(four.near_bench(a, b)): return "bench"   # chunk 4: a line at the bench
	if pad == null: return "line"
	if _to_segment(pad.centre_2d(), a, b) <= PAD_REACH: return "pad"
	var pit: Vector2 = pad.pit_centre()
	if not is_inf(pit.x) and _to_segment(pit, a, b) <= PIT_REACH: return "pit"
	return "line"

static func verdict_of(readings: Array) -> String:
	var voids := 0
	var strongest := 0.0
	for r in readings:
		if float(r) >= VOID: voids += 1
		strongest = maxf(strongest, float(r))
	if voids >= 3: return "void"
	if strongest >= FAINT: return "faint"
	return "solid"

## Have we a finished line of this kind with this verdict?
func has_line(kind: String, verdict := "void") -> bool:
	return lines.any(func(l: Dictionary) -> bool: return str(l.kind) == kind and str(l.verdict) == verdict)

# ---------- planting ----------

## Where E would plant a stake now, or INF if it can't.
func _spot() -> Vector3:
	var player: Node3D = world.get("player")
	if player == null or not running.is_empty(): return Vector3.INF
	if not FIELD_KIT.holding_in(world, "stakes") or not have_stakes(): return Vector3.INF
	if bool(player.get_meta("driving", false)) or bool(player.get_meta("riding", false)) or player._any_build_mode_active(): return Vector3.INF
	var suit: Node = world.get("suit")
	if suit != null and str(suit.get("where")) != "outside": return Vector3.INF
	if world.lander != null and world.lander.cabin_contains(player.global_position): return Vector3.INF
	if not gary_with_you(): return Vector3.INF
	var at := player.global_position - player.global_transform.basis.z * AHEAD
	at.y = MHSiteTerrain.height(at.x, at.z)
	return at

## Why the far stake can't go here, or "".
func far_reason(at: Vector3) -> String:
	if is_inf(first.x): return ""
	var length := Vector2(at.x - first.x, at.z - first.z).length()
	if length < MIN_LENGTH: return "Too short: walk further from the first stake"
	if length > MAX_LENGTH: return "Too long: GAR-Y reads up to %d m at a time" % int(MAX_LENGTH)
	if pad != null:
		var pit: Vector2 = pad.pit_centre()
		if not is_inf(pit.x) and _to_segment(pit, Vector2(first.x, first.z), Vector2(at.x, at.z)) < PIT_KEEP: return "That line runs over the edge: GAR-Y can't drive it"
	var four: Node = get_tree().get_first_node_in_group("chunk_four") if is_inside_tree() else null
	if four != null and bool(four.near_bench(Vector2(first.x, first.z), Vector2(at.x, at.z))):
		var c3: Node = four.call("_chunk3")
		if c3 == null or not bool(c3.sled_fitted()): return "That deep needs the sled on GAR-Y's hitch"
	return ""

## A line is GAR-Y reading the ground between two stakes: no line until it's
## met and free (22 Nov playtest: stakes went in before GAR-Y was found, and
## the prompt said it was on its way).
func gary_with_you() -> bool:
	var field: Node = world.get("drop_field")
	if field != null and "gary_greeted" in field and not bool(field.gary_greeted): return false
	return _gary() != null

## What E does here, for the HUD (scripts/explore_hud.gd), or "".
func prompt_text() -> String:
	if not running.is_empty():
		if _gary() == null: return "The line's staked: GAR-Y will run it when it can"
		return "GAR-Y's running the line" if _stage == "run" else "GAR-Y's heading for the first stake"
	if FIELD_KIT.holding_in(world, "stakes") and have_stakes() and not gary_with_you():
		return "GAR-Y reads the ground between the stakes: find it first"
	var at := _spot()
	if is_inf(at.x): return ""
	if is_inf(first.x): return "Plant the first stake"
	var why := far_reason(at)
	if not why.is_empty(): return why
	return "Plant the far stake (%d m)" % roundi(Vector2(at.x - first.x, at.z - first.z).length())

func _process(delta: float) -> void:
	_clock += delta
	if not bundle_taken and int(_clock * 2.0) != int((_clock - delta) * 2.0): _place_bundle()
	var down := MHInput.held("use") and not world.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var press := down and not _was_down
	_was_down = down
	if press and running.is_empty() and not _looking_at_something():
		var at := _spot()
		if not is_inf(at.x): plant(at)
	if not running.is_empty(): _run(delta)
	if _panel != null: _panel.visible = not running.is_empty() or _clock < _overlay_until

func _looking_at_something() -> bool:
	var hud: Node = world.get("explore_hud")
	return hud != null and hud.has_method("_looked_at_interactable") and hud.call("_looked_at_interactable") != null

## A stake goes in at `at`. The second one starts GAR-Y's run. Returns
## whether it went in.
func plant(at: Vector3) -> bool:
	if is_inf(first.x):
		first = at
		_stakes.append(_stake(at))
		MHAudio.sfx("place", -6.0, .8)
		_hint("First stake in", "Walk to where the line should end, and plant the far stake.")
		return true
	var why := far_reason(at)
	if not why.is_empty():
		MHAudio.sfx("invalid", -8.0)
		_hint("Not there", why)
		return false
	_stakes.append(_stake(at))
	MHAudio.sfx("place", -6.0, .9)
	var a := Vector2(first.x, first.z)
	var b := Vector2(at.x, at.z)
	first = Vector3.INF
	var count := clampi(roundi(a.distance_to(b) / STEP) + 1, MIN_READINGS, MAX_READINGS)
	var readings := []
	readings.resize(count)
	readings.fill(null)
	running = {"a": [a.x, a.y], "b": [b.x, b.y], "kind": kind_of(a, b), "readings": readings, "verdict": ""}
	if str(running.kind) == "bench":
		# Chunk 4: the sled can't take the bench's edge step; GAR-Y stops short of it.
		var four := get_tree().get_first_node_in_group("chunk_four")
		running["stop_t"] = float(four.step_cross(a, b)) if four != null else -1.0
	_start_run()
	return true

func _stake(at: Vector3) -> Node3D:
	var stake := PlantedStake.new()
	stake.name = "LineStake"
	stake.line = self
	world.add_child(stake)
	stake.global_position = at
	var scene: PackedScene = load(STAKE_MODEL) if ResourceLoader.exists(STAKE_MODEL) else null
	if scene != null:
		# The pack's stake (Survey_Stakes): origin at its tip, so it's pushed in
		# a little; the amber head's lit while the line's being read.
		var model := scene.instantiate() as Node3D
		stake.add_child(model)
		MHPalette.apply(model)
		model.position.y = -STAKE_SUNK
		model.rotation.y = randf() * TAU
		var head := model.find_child("Head", true, false) as MeshInstance3D
		var source := head.get_active_material(0) as StandardMaterial3D if head != null else null
		if source != null:
			var lens := source.duplicate() as StandardMaterial3D
			lens.emission_enabled = true
			lens.emission = Color(1.0, .5, .13)
			lens.emission_energy_multiplier = 1.4
			head.material_override = lens
		return stake
	for part in [[Vector3(.025, .9, .025), Vector3(0, .45, 0), "orange"], [Vector3(.07, .07, .07), Vector3(0, .92, 0), "lamp_amber"], [Vector3(.16, .1, .005), Vector3(.08, .78, 0), "orange"]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		var source := StandardMaterial3D.new()
		source.resource_name = str(part[2])
		mesh.material_override = MHPalette.material(source)
		mesh.position = part[1]
		stake.add_child(mesh)
	return stake

func _plant_saved() -> void:
	for line in lines:
		var pulled: Array = line.get("pulled", [])
		for key in ["a", "b"]:
			if key in pulled: continue
			var end: Array = line[key]
			var p := Vector3(float(end[0]), 0, float(end[1]))
			p.y = MHSiteTerrain.height(p.x, p.z)
			_stakes.append(_stake(p))

## E on a planted stake: you pull it up (22 Nov playtest). The line's
## reading stays on the slate; only the stake comes out. Not while GAR-Y's
## running that line.
func pull(stake: Node3D) -> bool:
	var at := Vector2(stake.global_position.x, stake.global_position.z)
	if not running.is_empty():
		for key in ["a", "b"]:
			var end: Array = running[key]
			if at.distance_to(Vector2(float(end[0]), float(end[1]))) < .3:
				_hint("Not yet", "GAR-Y's reading this line. Leave the stakes in till it's done.")
				MHAudio.sfx("invalid", -8.0)
				return false
	if not is_inf(first.x) and at.distance_to(Vector2(first.x, first.z)) < .3: first = Vector3.INF   # the line you'd started: begun again
	for line in lines:
		for key in ["a", "b"]:
			var end: Array = line[key]
			if at.distance_to(Vector2(float(end[0]), float(end[1]))) < .3:
				if not line.has("pulled"): line["pulled"] = []
				if not key in line.pulled: (line.pulled as Array).append(key)
	_stakes.erase(stake)
	stake.queue_free()
	MHAudio.sfx("suit_clamp", -8.0)
	return true

class PlantedStake extends StaticBody3D:
	var line: Node
	func _ready() -> void:
		set_meta("interaction_target", self)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(.14, .95, .14)
		shape.shape = box
		shape.position.y = .4
		add_child(shape)
		collision_layer = 1
	func interaction_prompt() -> Dictionary:
		return {"label": "Survey stake", "primary": "Pull it up"}
	func interact(_actor: Node = null) -> bool:
		return line != null and line.pull(self)

# ---------- GAR-Y runs it ----------

func _gary() -> Node3D:
	var gary: Node3D = world.get("scout_rover")
	if gary == null or not is_instance_valid(gary) or bool(gary.get("rescuing")): return null
	return gary

func _start_run() -> void:
	_stage = "to_start"
	_best_t = -1.0
	_progress_at = _clock
	var gary := _gary()
	if gary == null:
		_hint("GAR-Y runs the line", "It isn't here. It'll come and run it when it can.")
		return
	_via = _detour(Vector2(gary.global_position.x, gary.global_position.z), _end("a"))
	_drive(_via.pop_front() if not _via.is_empty() else _end("a"))
	MHAudio.sfx_at("place", gary, -10.0, 1.7)

## Waypoints round the pit if the way from `from` to `to` would cross it.
func _detour(from: Vector2, to: Vector2) -> Array:
	if pad == null: return []
	var pit: Vector2 = pad.pit_centre()
	if is_inf(pit.x) or _to_segment(pit, from, to) > PIT_KEEP + 3.0: return []
	var along := (to - from).normalized()
	var side := Vector2(-along.y, along.x)
	if (from - pit).dot(side) < 0.0: side = -side
	return [pit + side * (PIT_KEEP + 8.0)]

func _end(which: String) -> Vector2:
	var p: Array = running[which]
	return Vector2(float(p[0]), float(p[1]))

func _drive(to: Vector2) -> void:
	var gary := _gary()
	if gary == null: return
	if not str(gary.task).is_empty(): gary.call("_end_task")
	gary.set("staying", false)
	gary.set("napping", false)
	gary.call("_start", "goto", Vector3(to.x, gary.global_position.y, to.y), {"quiet": true})
	gary.set("_ordered", true)

func _run(_delta: float) -> void:
	var gary := _gary()
	if gary == null:
		if _clock - _progress_at > STUCK_SECONDS: _finish()
		return
	var at := Vector2(gary.global_position.x, gary.global_position.z)
	var a := _end("a")
	var b := _end("b")
	match _stage:
		"to_start":
			if at.distance_to(a) < 2.0 or (str(gary.task).is_empty() and _via.is_empty() and at.distance_to(a) < 5.0):
				_stage = "run"
				_progress_at = _clock
				_drive(b)
			elif str(gary.task).is_empty():
				if not _via.is_empty(): _drive(_via.pop_front())
				elif at.distance_to(a) >= 5.0: _drive(a)
			if _clock - _progress_at > STUCK_SECONDS * 2.0:
				_stage = "run"   # never reached the start: everything's unresolved
				_finish()
		"run":
			var ab := b - a
			var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), .001), 0.0, 1.0)
			var off := _to_segment(at, a, b)
			if t > _best_t + .01 and off < 4.0:
				_best_t = t
				_progress_at = _clock
				_read_up_to(t)
			var stop_t := float(running.get("stop_t", -1.0))
			if stop_t >= 0.0 and t >= stop_t - .03 and off < 4.0:
				# Scene 22: the sled tips its nose at the step, GAR-Y chirps and stops.
				running["stalled"] = true
				_read_up_to(maxf(stop_t - .03, 0.0))
				gary.call("_end_task")
				gary.call("_say", "worried")
				_finish()
			elif t > .97 or at.distance_to(b) < 2.0 or (str(gary.task).is_empty() and at.distance_to(b) < 4.0):
				_read_up_to(1.0)
				_finish()
			elif str(gary.task).is_empty():
				_drive(b)
			if _clock - _progress_at > STUCK_SECONDS: _finish()
	if _overlay != null: _overlay.queue_redraw()

func _read_up_to(t: float) -> void:
	var readings: Array = running.readings
	var a := _end("a")
	var b := _end("b")
	var last := floori(t * (readings.size() - 1) + .001)
	for i in range(0, last + 1):
		if readings[i] != null: continue
		readings[i] = snappedf(reading_at(a.lerp(b, float(i) / float(readings.size() - 1))), .01)

## The line's done: whatever wasn't reached is unresolved.
func _finish() -> void:
	var readings: Array = running.readings
	for i in readings.size():
		if readings[i] == null: readings[i] = -1.0
	running.verdict = verdict_of(readings)
	var line := running.duplicate(true)
	lines.append(line)
	running = {}
	_stage = ""
	_overlay_until = _clock + SHOW_FOR
	if _overlay != null:
		_overlay.line = line
		_overlay.queue_redraw()
	var gary := _gary()
	if gary != null:
		gary.call("_say", "happy")
		if str(gary.task) == "goto": gary.call("_end_task")
	MHAudio.sfx("ui_click", -6.0)
	_hint("Line done", "The profile's on your slate: Map, Lines.")
	line_done.emit(line)

func _hint(title: String, text: String) -> void:
	var hud: Node = world.get("explore_hud")
	if hud != null and hud.has_method("show_equipment_note"): hud.show_equipment_note(title, text)

# ---------- the profile ----------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.name = "LineProfile"
	add_child(layer)
	var panel := MHStyle.hud_panel(12)
	panel.anchor_left = .5
	panel.anchor_right = .5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -230
	panel.offset_bottom = -130
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_overlay = Profile.new()
	_overlay.lines = self
	_overlay.live = true
	_overlay.custom_minimum_size = Vector2(436, 76)
	panel.add_child(_overlay)
	_panel = panel
	panel.visible = false

## A profile for the slate (or anywhere): one line's readings as bars.
func profile_for(line: Dictionary, size := Vector2(520, 84)) -> Control:
	var p := Profile.new()
	p.lines = self
	p.line = line
	p.custom_minimum_size = size
	return p

static func label_for(line: Dictionary) -> String:
	match str(line.get("kind", "")):
		"pad": return "Across the planned pad"
		"pit": return "At the Collapse pit"
		"bench": return "Across the bench"
	return "Survey line"

static func verdict_text(line: Dictionary) -> String:
	if bool(line.get("stalled", false)): return "solid to the step; unresolved past it"
	match str(line.get("verdict", "")):
		"void": return "a void band"
		"faint": return "faint: hard to read"
		"solid": return "solid all the way"
	return ""

class Profile extends Control:
	var lines: Node
	var line: Dictionary = {}
	var live := false   # the on-screen one: shows the line being run

	func _draw() -> void:
		var shown: Dictionary = line
		if live and lines != null and not (lines.running as Dictionary).is_empty(): shown = lines.running
		if shown.is_empty(): return
		var readings: Array = shown.readings
		var n := readings.size()
		if n == 0: return
		var font := get_theme_default_font()
		var top := 18.0
		var h := size.y - top - 4.0
		draw_string(font, Vector2(0, 13), str(lines.label_for(shown)) + ("" if str(shown.verdict).is_empty() else " · " + str(lines.verdict_text(shown))), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MHStyle.TEXT_MUTED)
		var w := size.x / n
		for i in n:
			var rect := Rect2(i * w + 1.0, top, w - 2.0, h)
			var r = readings[i]
			if r == null:
				draw_rect(rect, Color(1, 1, 1, .04))
				continue
			var v := float(r)
			if v < 0.0:
				# No reading: hatched.
				draw_rect(rect, Color(1, 1, 1, .06))
				var x := rect.position.x
				while x < rect.end.x:
					draw_line(Vector2(x, rect.end.y), Vector2(minf(x + 8.0, rect.end.x), rect.end.y - minf(8.0, rect.end.x - x)), Color(1, 1, 1, .25), 1.0)
					x += 6.0
				continue
			# Solid ground fills the bar from the top; a void eats it from below.
			var colour := Color("#8C9AA3") if v < lines.FAINT else (Color("#F2B84B") if v < lines.VOID else Color("#E0663A"))
			var hollow := h * clampf(v, 0.0, 1.0) * .85
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, h - hollow)), Color("#6E5A4A"))
			draw_rect(Rect2(rect.position + Vector2(0, h - hollow), Vector2(rect.size.x, hollow)), colour)
