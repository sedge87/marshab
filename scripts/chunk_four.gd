extends Node

## Chunk 4 of the opening slice (docs/opening-slice.md §4a Scenes 19–24;
## docs/assets-chunk4.md): the bench across the Dry channel. Owned by
## scripts/opening_slice.gd, like chunk 3, and saved with it. What lives here:
##
## - where the bench, the two crossings and the edge step are (a terrain
##   sample, 24 Nov), and what the survey line and the corer ask about them;
## - the wind logger: printed after Devan's ask, held in kit slot 5, set down
##   by hand. Its two traces read calm in the bench's lee (wrong, plausible),
##   disagree on the exposed rim, and agree on the approach's shoulder;
## - the pad's beacon: unbolted from the pad, towed on GAR-Y's hitch (one load
##   at a time), stood at the bench, its printed connector fitted, lit. Devan
##   locks on from orbit. The feet-setting step is folded into standing it up.
##
## Stand-ins stand where the logger model isn't made yet.

const PAD_SITE := preload("res://scripts/pad_site.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const FIELD_KIT := preload("res://scripts/field_kit.gd")
const BEACON := "res://assets/models/chunk2/pad_beacon.glb"

## Region metres (a 24 Nov terrain sample, docs/opening-slice.md).
const BENCH := Vector2(-832.0, 1181.0)
const CROSSING_NORTH := Vector2(-890.2, 1055.5)
const CROSSING_SOUTH := Vector2(-872.8, 1450.3)
const STEP_X := -880.0               # the edge step runs north-south here, about 48 m west of the bench
const STEP_Z := Vector2(1100.0, 1262.0)
const SOFT_REACH := 8.0              # a core this close to the step goes through a soft layer
const BENCH_REACH := 80.0            # a survey line this close to the bench is a line at the bench
const CORE_REACH := 90.0
const STAND_SECONDS := 3.0
const FIT_SECONDS := 2.0
const LOGGER_SECONDS := 4.0          # standing this long before its two traces are read out
const CROSSING_REACH := 70.0

var world: Node
var beacon_state := "pad"            # pad -> carried -> bench -> lit
var logger_at := Vector2.INF         # site metres
var logger_seen := {}                # "calm", "split", "good": read out once each
var _logger: Node3D
var _label: Label3D
var _spot: Node3D
var _beacon: Node3D
var _beacon_label: Label3D
var _lenses: Array = []
var _stood := 0.0
var _zone := ""
var _was_down := false
var _check := 0.0
var _clock := 0.0
var _crossing_said := false

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "ChunkFour"
	add_to_group("chunk_four")
	beacon_state = str(saved.get("beacon", "pad"))
	var l: Array = saved.get("logger_at", [])
	if l.size() == 2: logger_at = Vector2(float(l[0]), float(l[1]))
	logger_seen = (saved.get("logger_seen", {}) as Dictionary).duplicate()
	_crossing_said = bool(saved.get("crossing_said", false))
	_restore.call_deferred()

func export_state() -> Dictionary:
	return {"beacon": beacon_state, "logger_at": [] if is_inf(logger_at.x) else [logger_at.x, logger_at.y],
		"logger_seen": logger_seen.duplicate(), "crossing_said": _crossing_said}

func _restore() -> void:
	if not is_inf(logger_at.x): _show_logger()
	if ready_done(): _build_spot()
	if beacon_state == "bench" or beacon_state == "lit": _stand_beacon(beacon_state == "lit")

# ---------- where ----------

static func _centre() -> Vector2:
	var zone: Dictionary = MHSiteTerrain.region_zone()
	if zone.is_empty(): return Vector2.INF
	return Vector2(float(zone.centre[0]), float(zone.centre[1]))

## Region metres to site metres (INF off a region site).
static func site_of(region: Vector2) -> Vector2:
	var c := _centre()
	return Vector2.INF if is_inf(c.x) else region - c

static func bench_site() -> Vector2:
	return site_of(BENCH)

## The two crossings, site metres: {"north": Vector2, "south": Vector2} (empty off a region site).
static func crossings_site() -> Dictionary:
	var n := site_of(CROSSING_NORTH)
	if is_inf(n.x): return {}
	return {"north": n, "south": site_of(CROSSING_SOUTH)}

func ready_done() -> bool:
	var opening := get_parent()
	return opening != null and (opening.reached as Array).has("ready")

func _gary() -> Node3D:
	var g: Node3D = world.get("scout_rover")
	return g if g != null and is_instance_valid(g) else null

func _player() -> Node3D:
	return world.get("player") as Node3D

func _outside() -> bool:
	var suit: Node = world.get("suit")
	return suit == null or str(suit.get("where")) == "outside"

func _chunk3() -> Node:
	return get_parent().get("chunk3") if get_parent() != null else null

# ---------- what the survey line and the corer ask ----------

## A survey line this close to the bench is a line at the bench.
func near_bench(a: Vector2, b: Vector2) -> bool:
	var at := bench_site()
	if is_inf(at.x): return false
	var ab := b - a
	var t := 0.0 if ab.length_squared() < .001 else clampf((at - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return at.distance_to(a + ab * t) <= BENCH_REACH

## Where along a→b (0–1) the line crosses the edge step, or -1.
func step_cross(a: Vector2, b: Vector2) -> float:
	var c := _centre()
	if is_inf(c.x): return -1.0
	var sx := STEP_X - c.x
	if (a.x - sx) * (b.x - sx) > 0.0 or is_equal_approx(a.x, b.x): return -1.0
	var t := (sx - a.x) / (b.x - a.x)
	var z := lerpf(a.y, b.y, t)
	return t if z >= STEP_Z.x - c.y and z <= STEP_Z.y - c.y else -1.0

## A core here goes through a soft layer (the step's lip).
func soft_at(p: Vector2) -> bool:
	var c := _centre()
	if is_inf(c.x): return false
	return absf(p.x - (STEP_X - c.x)) <= SOFT_REACH and p.y >= STEP_Z.x - c.y and p.y <= STEP_Z.y - c.y

## Kai's optional core at the bench needs no GAR-Y survey of its own: the
## bench line is the survey, and the corer only asks for one.
func allows_core(p: Vector2) -> bool:
	var at := bench_site()
	return not is_inf(at.x) and bench_survey_done() and p.distance_to(at) <= CORE_REACH

func _lines() -> Array:
	var node: Node = get_tree().get_first_node_in_group("survey_line")
	return (node.lines as Array) if node != null else []

func bench_survey_done() -> bool:
	return _lines().any(func(l: Dictionary) -> bool: return str(l.get("kind", "")) == "bench")

func stall_seen() -> bool:
	return _lines().any(func(l: Dictionary) -> bool: return bool(l.get("stalled", false)))

func through_seen() -> bool:
	return (MHChapterOne.cores as Array).any(func(c: Dictionary) -> bool: return bool(c.get("through", false)))

## Scene 22: the sled stalled at the step.
func ring_stall() -> void:
	_ring("s4_stall")

func logger_printed() -> bool:
	return MHChapterOne.parts.has("wind_logger") or not is_inf(logger_at.x)

# ---------- the tick ----------

func _process(delta: float) -> void:
	if world == null or _player() == null or get_tree().paused: return
	_clock += delta
	var down := MHInput.held("use") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var press := down and not _was_down
	_was_down = down
	if press and _holding_logger() and not _looking_at_something(): _logger_press()
	if _logger != null: _tick_logger(delta)
	_check -= delta
	if _check > 0.0: return
	_check = .5
	if not ready_done(): return
	_build_spot()
	_tick_crossing()

func _looking_at_something() -> bool:
	var hud: Node = world.get("explore_hud")
	return hud != null and hud.has_method("_looked_at_interactable") and hud.call("_looked_at_interactable") != null

func _ring(section: String) -> void:
	var radio: Node = world.get("radio")
	if radio != null and radio.has_method("ring"): radio.ring(section)

## Scene 20: the first time you're on a crossing's bank.
func _tick_crossing() -> void:
	if _crossing_said or not _outside(): return
	var crossings := crossings_site()
	if crossings.is_empty(): return
	var me := _player().global_position
	for key in crossings:
		var at: Vector2 = crossings[key]
		if Vector2(me.x - at.x, me.z - at.y).length() <= CROSSING_REACH:
			_crossing_said = true
			_ring("s4_crossing")
			return

# ---------- the wind logger ----------

func _holding_logger() -> bool:
	return FIELD_KIT.gates(world) and FIELD_KIT.holding_in(world, "logger") and MHChapterOne.parts.has("wind_logger") and _outside()

## What E does with the logger in hand, for the HUD (explore_hud.gd), or "".
func prompt_text() -> String:
	if not _holding_logger(): return ""
	if is_inf(logger_at.x): return "Plant the wind logger"
	var me := _player().global_position
	if Vector2(me.x - logger_at.x, me.z - logger_at.y).length() <= 3.5: return "Plant it, or pick the logger up (E at it)"
	return ""

func _logger_press() -> void:
	var me := _player().global_position
	if not is_inf(logger_at.x) and Vector2(me.x - logger_at.x, me.z - logger_at.y).length() <= 3.5:
		_pick_up()
		return
	if not is_inf(logger_at.x): return   # one logger: it's out there
	var ahead := me - _player().global_transform.basis.z * 1.6
	logger_at = Vector2(ahead.x, ahead.z)
	_show_logger()
	MHAudio.sfx("place", -6.0, .85)
	_stood = 0.0
	_zone = ""

func _pick_up() -> void:
	logger_at = Vector2.INF
	if _logger != null: _logger.queue_free()
	_logger = null
	_label = null
	_zone = ""
	_stood = 0.0
	MHAudio.sfx("suit_clamp", -8.0)

func _show_logger() -> void:
	if _logger != null: return
	_logger = Node3D.new()
	_logger.name = "WindLogger"
	world.add_child(_logger)
	var y := MHSiteTerrain.height(logger_at.x, logger_at.y)
	_logger.global_position = Vector3(logger_at.x, y, logger_at.y)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var leg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = .012; cyl.bottom_radius = .014; cyl.height = 1.1
		leg.mesh = cyl
		leg.material_override = _material("dark_alloy")
		_logger.add_child(leg)
		leg.position = Vector3(cos(a) * .22, .55, sin(a) * .22)
		leg.rotation = Vector3(sin(a) * .2, 0.0, -cos(a) * .2)
	var mast := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = .014; m.bottom_radius = .014; m.height = 1.5
	mast.mesh = m
	mast.material_override = _material("white_painted")
	_logger.add_child(mast)
	mast.position.y = .75
	var box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(.26, .2, .12)
	box.mesh = b
	box.material_override = _material("graphite")
	_logger.add_child(box)
	box.position = Vector3(0, 1.0, .1)
	var cups := Node3D.new()
	cups.name = "Cups"
	_logger.add_child(cups)
	cups.position.y = 1.55
	for i in 3:
		var cup := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = .045; s.height = .09
		cup.mesh = s
		cup.material_override = _material("white_painted")
		cups.add_child(cup)
		var a := TAU * float(i) / 3.0
		cup.position = Vector3(cos(a) * .15, 0, sin(a) * .15)
	_label = Label3D.new()
	_label.pixel_size = .0016
	_label.font_size = 36
	_label.outline_size = 0
	_label.modulate = Color("#9FE7B2")
	_label.text = "LOG\n--"
	_logger.add_child(_label)
	_label.position = Vector3(0, 1.0, .165)

func _material(role: String) -> Material:
	var source := StandardMaterial3D.new()
	source.resource_name = role
	return MHPalette.material(source)

## Which wind this spot has: calm in the bench's lee, split on the exposed
## rim, true on the approach's shoulder.
func _logger_zone(at: Vector2) -> String:
	var c := _centre()
	var bench := bench_site()
	if is_inf(c.x) or is_inf(bench.x) or at.distance_to(bench) > 160.0: return ""
	var dist := (at.x + c.x) - STEP_X   # east of the step, metres
	if dist < -6.0: return "calm"       # down the slope, out of the wind
	if dist < 12.0: return "split"      # the rim: gusts and eddies
	if dist < 30.0: return "good"       # the approach's shoulder
	return "calm"                       # the bench's lee

func _tick_logger(delta: float) -> void:
	var cups := _logger.get_node_or_null("Cups") as Node3D
	var zone := _logger_zone(logger_at)
	if cups != null: cups.rotation.y += delta * (1.0 if zone == "calm" else (9.0 if zone == "split" else 5.0))
	if zone != _zone:
		_zone = zone
		_stood = 0.0
	_stood += delta
	if _label != null and int(_stood * 2.0) != int((_stood - delta) * 2.0): _label.text = _trace_text(zone)
	if zone.is_empty() or _stood < LOGGER_SECONDS or logger_seen.has(zone): return
	logger_seen[zone] = true
	match zone:
		"calm": _ring("s4_logger_calm")
		"split": _ring("s4_logger_split")
		"good": _ring("s4_logger_good")

func _trace_text(zone: String) -> String:
	var wobble := sin(_clock * 1.7) * .5
	match zone:
		"calm": return "TOP %.1f\nLOW %.1f" % [1.4 + wobble * .2, 1.1 + wobble * .1]
		"split": return "TOP %.1f\nLOW %.1f" % [8.6 + wobble * 3.0, 3.1 - wobble]
		"good": return "TOP %.1f\nLOW %.1f" % [5.2 + wobble * .4, 4.9 + wobble * .3]
	return "TOP --\nLOW --"

# ---------- the bench ----------

## A small orange marker where the beacon's three feet go.
func _build_spot() -> void:
	if _spot != null: return
	var at := bench_site()
	if is_inf(at.x): return
	_spot = Node3D.new()
	_spot.name = "BenchSpot"
	world.add_child(_spot)
	_spot.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y), at.y)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var slab := MeshInstance3D.new()
		var s := BoxMesh.new()
		s.size = Vector3(.5, .04, .5)
		slab.mesh = s
		slab.material_override = _material("orange")
		_spot.add_child(slab)
		slab.position = Vector3(cos(a) * 1.3, .02, sin(a) * 1.3)
		slab.rotation.y = a
	_add_point("stand", _spot, Vector3(0, .5, 0), 1.7)

func _add_point(id: String, parent: Node3D, at: Vector3, radius: float) -> void:
	var point := PAD_SITE.HoldPoint.new()
	point.site = self
	point.id = id
	point.radius = radius
	point.name = "Point_" + id
	parent.add_child(point)
	point.position = at

## Scene 24, the pad's end: the beacon's unbolted and goes on GAR-Y's hitch.
func can_take() -> bool:
	return ready_done() and beacon_state == "pad" and _gary() != null

func beacon_taken() -> void:
	beacon_state = "carried"
	var c3 := _chunk3()
	if c3 != null:
		c3.loadout["hitch"] = "beacon"
		c3.on_gary["hitch"] = "beacon"
		c3.call("_refresh_gary")
	get_tree().call_group("eva_station", "refresh")
	MHAudio.sfx("suit_clamp", -4.0)
	MHNotices.post("valid", "The beacon's on GAR-Y's hitch", "Same beacon, the torn lead and all. Walk it across the Dry channel to the bench: one load at a time, so the sled stays at the station for now.", "log")

func prompt_for(id: String, holding: bool) -> Dictionary:
	match id:
		"stand":
			if beacon_state == "bench" or beacon_state == "lit":
				return {"label": "The beacon's standing here", "primary": ""}
			if beacon_state != "carried": return {"label": "Where the beacon will stand", "primary": ""}
			var gary := _gary()
			var me := _player().global_position
			if gary == null or gary.global_position.distance_to(me) > 14.0:
				return {"label": "The beacon's on GAR-Y's hitch", "primary": "GAR-Y has to be here"}
			return {"label": "Three feet, flat ground, a clear sky", "primary": "Standing it up…" if holding else "Hold to stand the beacon up"}
		"fit":
			if beacon_state == "lit": return {"label": "The beacon's lit", "primary": ""}
			if not MHChapterOne.parts.has("beacon_connector"):
				return {"label": "The power lead's torn out of the box", "primary": "It needs the printed connector"}
			return {"label": "The torn lead", "primary": "Fitting it…" if holding else "Hold to fit the connector"}
	return {}

func press(id: String) -> Dictionary:
	match id:
		"stand":
			if beacon_state != "carried": return {"ok": false, "hold": 0.0}
			var gary := _gary()
			if gary == null or gary.global_position.distance_to(_player().global_position) > 14.0:
				MHAudio.sfx("invalid", -8.0)
				return {"ok": false, "hold": 0.0}
			return {"ok": true, "hold": STAND_SECONDS}
		"fit":
			if beacon_state != "bench" or not MHChapterOne.parts.has("beacon_connector"):
				MHAudio.sfx("invalid", -8.0)
				return {"ok": false, "hold": 0.0}
			return {"ok": true, "hold": FIT_SECONDS}
	return {"ok": false, "hold": 0.0}

func held_done(id: String) -> void:
	match id:
		"stand": stand_up()
		"fit": fit_connector()

## The mast goes up at the bench; GAR-Y's hitch is free again.
func stand_up() -> void:
	if beacon_state != "carried": return
	beacon_state = "bench"
	var c3 := _chunk3()
	if c3 != null:
		c3.loadout["hitch"] = ""
		c3.on_gary["hitch"] = ""
		c3.call("_refresh_gary")
	get_tree().call_group("eva_station", "refresh")
	_stand_beacon(false)
	MHAudio.sfx_at("land", _spot if _spot != null else self, -4.0, .7)
	MHNotices.post("valid", "The beacon's up", "Its lead's still torn. Fit the printed connector.", "log")

func _stand_beacon(lit: bool) -> void:
	if _beacon != null or not ResourceLoader.exists(BEACON): return
	var at := bench_site()
	if is_inf(at.x): return
	_beacon = (load(BEACON) as PackedScene).instantiate() as Node3D
	_beacon.name = "BenchBeacon"
	world.add_child(_beacon)
	MHPalette.apply(_beacon)
	_beacon.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.y), at.y)
	_beacon.rotation.y = PI * .5   # its front (-Z) to the channel
	var root := _beacon.get_node_or_null("LandingBeacon") as Node3D
	var mast := root.get_node_or_null("Mast") as Node3D if root != null else null
	if mast != null:
		for part in ["Lead", "Connector"]:
			var node := mast.get_node_or_null(part) as Node3D
			if node != null:
				node.scale = Vector3.ONE
				node.visible = lit
		for part in ["LeadLoose", "LeadTorn"]:
			var node := mast.get_node_or_null(part) as Node3D
			if node != null: node.visible = not lit
		var lamp := mast.get_node_or_null("Lamp")
		if lamp != null:
			for mesh in lamp.find_children("*", "MeshInstance3D", true, false):
				var m := mesh as MeshInstance3D
				var source := m.get_active_material(0) as StandardMaterial3D
				if source == null: continue
				var lens := source.duplicate() as StandardMaterial3D
				m.material_override = lens
				lens.emission_enabled = lit
				lens.emission = Color("#FFB34A")
				lens.emission_energy_multiplier = 2.2
				_lenses.append(lens)
	_beacon_label = Label3D.new()
	_beacon_label.pixel_size = .0013
	_beacon_label.font_size = 36
	_beacon_label.outline_size = 0
	_beacon_label.modulate = Color("#9FE7B2")
	_beacon.add_child(_beacon_label)
	_beacon_label.position = Vector3(0, 1.05, -.34)
	_beacon_label.rotation.y = PI
	_beacon_label.text = "LEAD  OK\nPOWER  ON" if lit else "LEAD  OPEN"
	if not lit: _add_point("fit", _beacon, Vector3(0, .55, -.25), .55)

## The printed connector joins the lead and the lamp comes on.
func fit_connector() -> void:
	if beacon_state != "bench" or not MHChapterOne.parts.has("beacon_connector"): return
	MHChapterOne.parts.erase("beacon_connector")
	beacon_state = "lit"
	var root := _beacon.get_node_or_null("LandingBeacon") as Node3D if _beacon != null else null
	var mast := root.get_node_or_null("Mast") as Node3D if root != null else null
	if mast != null:
		for part in ["Lead", "Connector"]:
			var node := mast.get_node_or_null(part) as Node3D
			if node != null: node.visible = true
		for part in ["LeadLoose", "LeadTorn"]:
			var node := mast.get_node_or_null(part) as Node3D
			if node != null: node.visible = false
	for lens in _lenses: (lens as StandardMaterial3D).emission_enabled = true
	if _beacon_label != null: _beacon_label.text = "LEAD  OK\nPOWER  ON"
	var point := _beacon.get_node_or_null("Point_fit") if _beacon != null else null
	if point != null: point.queue_free()
	MHAudio.sfx("ui_confirm", -4.0)
	MHNotices.post("valid", "The beacon's lit", "The lamp's on and the lead's whole. Devan has a tone.", "log")
	_ring("s4_lit")
