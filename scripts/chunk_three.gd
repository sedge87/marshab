extends Node

## Chunk 3 of the opening slice (docs/opening-slice.md §4a Scenes 13–18,
## §10c as built; docs/assets-chunk3-review.md): the free stretch after the
## new job. Owned by scripts/opening_slice.gd, like the pad and the lines,
## and saved with it. What lives here is what's in the world:
##
## - the iron-rich outcrop Tamsin points you to (a dark rock that reads as
##   hematite for the hammer, scripts/samples.gd placed_rocks);
## - one crew effects case on the plain near the storm pallets, Kai's
##   niece's plush inside;
## - the survey sled, once its printed fittings are bolted to the frame;
## - GAR-Y's fittings: what the EVA station has set for the mast, the front
##   and the hitch (`loadout`), and what's actually on GAR-Y (`on_gary`).
##   They swap over as you go out through the airlock, with a servo clunk.
##   Lamps and scoop share the front mount: one or the other, never both.

const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const SLED := "res://assets/models/chunk3/radar_sled.glb"
const CASE := "res://assets/models/chunk3/effects_case.glb"
const ROCK := "res://assets/original_mars/models/decor_rock_03.glb"
const FITTINGS := {
	"radar": {"label": "Radar head", "model": "res://assets/models/chunk3/gary_radar_head.glb", "mount": "MastMount", "slot": "mast",
		"says": "The survey sled's antenna reads through it. Needed for deep lines."},
	"lamps": {"label": "Lamp bar", "model": "res://assets/models/chunk3/gary_worklights.glb", "mount": "FrontMount", "slot": "front",
		"says": "Two work lamps: GAR-Y lights the ground ahead after dark."},
	"scoop": {"label": "Scoop", "model": "res://assets/models/chunk3/gary_scoop.glb", "mount": "FrontMount", "slot": "front",
		"says": "A small regolith scoop. Not used in the rehearsal yet."},
	"sled": {"label": "Survey sled", "model": SLED, "mount": "RearMount", "slot": "hitch",
		"says": "Tamsin's deep-radar sled, towed on the hitch's cable."},
	# Chunk 4: the pad's beacon, towed to the bench. The hitch holds one load at a time.
	"beacon": {"label": "Pad beacon", "model": "res://assets/models/chunk2/pad_beacon.glb", "mount": "RearMount", "slot": "hitch",
		"says": "The pad's beacon, unbolted and laid on the hitch. It goes up at the bench."},
}
const SLOTS := ["mast", "front", "hitch"]
const OUTCROP_RADIUS := 1.8
const OUTCROP_FROM_CORE := 38.0
const CASE_FROM_PALLET := 7.0

var world: Node
var loadout := {"mast": "", "front": "", "hitch": ""}   # set at the EVA station
var on_gary := {"mast": "", "front": "", "hitch": ""}   # what's fitted now
var sled_built := false
var outcrop := Vector2.INF
var case_at := Vector3.INF
var case_opened := false
var plush_taken := false
var _was_outside := false
var _shown := {}                 # slot -> Node3D on GAR-Y
var _outcrop_node: Node3D
var _case: Node3D
var _check := 0.0

func setup(target_world: Node, saved: Dictionary) -> void:
	world = target_world
	name = "ChunkThree"
	add_to_group("chunk_three")
	add_to_group("interaction_claims")
	for slot in SLOTS:
		loadout[slot] = str((saved.get("loadout", {}) as Dictionary).get(slot, ""))
		on_gary[slot] = str((saved.get("on_gary", {}) as Dictionary).get(slot, ""))
	sled_built = bool(saved.get("sled_built", false))
	var o: Array = saved.get("outcrop", [])
	if o.size() == 2: outcrop = Vector2(float(o[0]), float(o[1]))
	var c: Array = saved.get("case_at", [])
	if c.size() == 3: case_at = Vector3(float(c[0]), float(c[1]), float(c[2]))
	case_opened = bool(saved.get("case_opened", false))
	plush_taken = bool(saved.get("plush_taken", false))
	_restore.call_deferred()

func export_state() -> Dictionary:
	return {"loadout": loadout.duplicate(), "on_gary": on_gary.duplicate(), "sled_built": sled_built,
		"outcrop": [] if is_inf(outcrop.x) else [outcrop.x, outcrop.y],
		"case_at": [] if is_inf(case_at.x) else [case_at.x, case_at.y, case_at.z],
		"case_opened": case_opened, "plush_taken": plush_taken}

func _restore() -> void:
	if not is_inf(outcrop.x): _show_outcrop()
	if not is_inf(case_at.x): _show_case()
	_was_outside = _outside()
	_refresh_gary()

# ---------- what's available ----------

## A fitting you have (one of each): the radar head came with pallet 6, the
## lamp bar and scoop with the EVA station, the sled once it's built.
func have(fitting: String) -> bool:
	match fitting:
		"radar": return MHChapterOne.unpacked.has("radar_sled_frame")
		"lamps", "scoop": return MHChapterOne.unpacked.has("eva_station") or MHChapterOne.placed_count("eva_station", _builder()) > 0
		"sled": return sled_built
		"beacon":
			var four := get_tree().get_first_node_in_group("chunk_four")
			return four != null and str(four.beacon_state) == "carried"
	return false

## The station's choice for a slot (one fitting or nothing). The front's
## lamps and scoop share one mount, so choosing one stows the other.
func choose(slot: String, fitting: String) -> void:
	if not SLOTS.has(slot): return
	if not fitting.is_empty() and (not have(fitting) or str(FITTINGS[fitting].slot) != slot): return
	loadout[slot] = fitting
	MHAudio.sfx("ui_click", -6.0)

## Where a fitting is now: "gary", "station", or "" (you haven't got it).
func where(fitting: String) -> String:
	if not have(fitting): return ""
	for slot in SLOTS:
		if on_gary[slot] == fitting: return "gary"
	return "station"

## Waiting to go on (or come off) at the next trip out.
func pending() -> bool:
	for slot in SLOTS:
		if str(loadout[slot]) != str(on_gary[slot]): return true
	return false

func sled_fitted() -> bool:
	return on_gary.hitch == "sled"

# ---------- the sled ----------

## The printed fittings out of the drawer, onto the frame (pallet 6's).
func build_sled() -> bool:
	if sled_built or not MHChapterOne.unpacked.has("radar_sled_frame"): return false
	sled_built = true
	MHAudio.sfx("suit_clamp", -4.0)
	MHNotices.post("valid", "The survey sled", "The electronics box on its frame and the skid shoes on. It waits at the EVA station: set GAR-Y's hitch to it there.", "log")
	get_tree().call_group("eva_station", "refresh")
	return true

# ---------- the tick ----------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null: return
	_check = .4
	var outside := _outside()
	# Out through the airlock: what the station set goes on GAR-Y.
	if outside and not _was_outside and pending():
		for slot in SLOTS: on_gary[slot] = loadout[slot]
		_refresh_gary()
		var gary: Node3D = world.get("scout_rover")
		if gary != null:
			MHAudio.sfx_at("mode_build", gary, -8.0, .7)
			gary.call("_say", "happy")
		get_tree().call_group("eva_station", "refresh")
	_was_outside = outside
	_animate()

var _t := 0.0
func _animate() -> void:
	_t += .4
	var radar: Node3D = _shown.get("mast")
	if radar != null and is_instance_valid(radar):
		var head := radar.find_child("Head", true, false) as Node3D
		if head != null: create_tween().tween_property(head, "rotation:y", sin(_t * .35) * .9, .4)
	var lamps: Node3D = _shown.get("front")
	if lamps != null and is_instance_valid(lamps):
		var gary: Node3D = world.get("scout_rover")
		var own: Light3D = gary.get("_lamp") if gary != null else null
		for light in lamps.find_children("*", "SpotLight3D", true, false):
			(light as SpotLight3D).light_energy = 1.4 if own != null and own.light_energy > .01 else 0.0

func _refresh_gary() -> void:
	var gary: Node3D = world.get("scout_rover") if world != null else null
	if gary == null or not is_instance_valid(gary): return
	for slot in SLOTS:
		var want := str(on_gary[slot])
		var node: Node3D = _shown.get(slot)
		if node != null and is_instance_valid(node):
			if str(node.get_meta("gar_y_fitting")) == want: continue
			node.queue_free()
		_shown.erase(slot)
		if want.is_empty() or not FITTINGS.has(want): continue
		var info: Dictionary = FITTINGS[want]
		var mount := gary.find_child(str(info.mount), true, false) as Node3D
		if mount == null or not ResourceLoader.exists(str(info.model)): continue
		var model := (load(str(info.model)) as PackedScene).instantiate() as Node3D
		model.name = "Fitting_%s" % want
		model.set_meta("gar_y_fitting", want)
		MHPalette.apply(model)
		mount.add_child(model)
		_shown[slot] = model
		if want == "sled": _trail(model, mount)
		if want == "beacon":
			# Laid along GAR-Y's back, its foot to the rear.
			model.rotation_degrees = Vector3(-90, 0, 0)
			model.scale = Vector3.ONE * .85
			model.position = Vector3(0, .25, -.2)
		if want == "lamps": _lamp_lights(model)

## The sled trails behind the hitch: its tow point on the cable's end, on
## the ground, its front (-Z) to GAR-Y's back.
func _trail(sled: Node3D, mount: Node3D) -> void:
	var tow := sled.find_child("TowPoint", true, false) as Node3D
	var tow_at := tow.position if tow != null else Vector3(0, .18, -.6)
	var gary: Node3D = world.get("scout_rover")
	var ground_y := -mount.global_position.y + gary.global_position.y if gary != null else -.3
	sled.position = Vector3(0, ground_y, .55) - Vector3(tow_at.x, 0, tow_at.z)

func _lamp_lights(model: Node3D) -> void:
	for lamp_name in ["Lamp_L", "Lamp_R"]:
		var at := model.find_child(lamp_name, true, false) as Node3D
		if at == null: continue
		var light := SpotLight3D.new()
		light.light_color = Color("#FFE7C4")
		light.spot_range = 8.0
		light.spot_angle = 34.0
		light.light_energy = 0.0
		at.add_child(light)
		light.rotation.x = deg_to_rad(-14.0)

# ---------- the outcrop ----------

## Tamsin's teaching call (sol3.txt s3_teach): a dark outcrop near the core,
## marked on the Map. It reads as hematite to the hammer.
func place_outcrop() -> void:
	if not is_inf(outcrop.x): return
	var core := _core()
	if is_inf(core.x): return
	var best := Vector2.INF
	for i in 12:
		var a := TAU * float(i) / 12.0 + .4
		var p := core + Vector2(cos(a), sin(a)) * OUTCROP_FROM_CORE
		if _clear(p):
			best = p
			break
	outcrop = best if not is_inf(best.x) else core + Vector2(OUTCROP_FROM_CORE, 0)
	_show_outcrop()
	var known: Node = world.get("known")
	var field: Node = world.get("drop_field")
	if known != null and field != null and field.has_method("region_at"):
		known.learn("iron_outcrop", "find", field.region_at(Vector3(outcrop.x, 0, outcrop.y)), "Dark outcrop · iron-rich rock", "you", "achterberg")
		known.track("iron_outcrop")

## Flat enough for the outcrop to sit (not on a slope or in a hollow).
func _clear(p: Vector2) -> bool:
	var h: float = MHSiteTerrain.height(p.x, p.y)
	for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(MHSiteTerrain.height(p.x + d.x, p.y + d.y) - h) > .9: return false
	return true

func _show_outcrop() -> void:
	if _outcrop_node != null: return
	MHSamples.placed_rocks.append([outcrop, OUTCROP_RADIUS, "hematite"])
	var tools: Node = get_tree().get_first_node_in_group("sample_tools")
	if tools != null and tools.has_method("add_rock"): tools.add_rock(outcrop, OUTCROP_RADIUS)
	_outcrop_node = Node3D.new()
	_outcrop_node.name = "IronOutcrop"
	world.add_child(_outcrop_node)
	_outcrop_node.global_position = Vector3(outcrop.x, MHSiteTerrain.height(outcrop.x, outcrop.y) - .15, outcrop.y)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#4A3B40")   # hematite's dark, purplish grey (discoveries.json)
	dark.roughness = .78
	dark.metallic = .25
	for i in 4:
		var rock: Node3D
		if ResourceLoader.exists(ROCK):
			rock = (load(ROCK) as PackedScene).instantiate() as Node3D
			for mesh in rock.find_children("*", "MeshInstance3D", true, false): (mesh as MeshInstance3D).material_override = dark
		else:
			var m := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = .5; sphere.height = .7
			m.mesh = sphere
			m.material_override = dark
			rock = m
		_outcrop_node.add_child(rock)
		var a := float(i) * 1.7
		rock.position = Vector3(cos(a), 0, sin(a)) * (.2 + .45 * float(i % 3))
		rock.rotation.y = a
		rock.scale = Vector3.ONE * (1.25 - .2 * float(i))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0; cyl.height = .8
	shape.shape = cyl
	shape.position.y = .4
	body.add_child(shape)
	_outcrop_node.add_child(body)

# ---------- the effects case ----------

## One crew effects case on the plain, by the storm pallets: a find, not a
## job (the manifest listed it as corrupted).
func place_case() -> void:
	if not is_inf(case_at.x): return
	var drop: Node = world.get("storm_drop")
	var base := Vector3.INF
	if drop != null and drop.get("pallet") != null: base = (drop.pallet as Node3D).global_position
	if is_inf(base.x):
		var core := _core()
		if is_inf(core.x): return
		base = Vector3(core.x - 60.0, 0, core.y + 20.0)
	var p := Vector2(base.x + CASE_FROM_PALLET, base.z - CASE_FROM_PALLET * .6)
	case_at = Vector3(p.x, MHSiteTerrain.height(p.x, p.y), p.y)
	_show_case()

func _show_case() -> void:
	if _case != null: return
	_case = load("res://scripts/effects_case.gd").new()
	world.add_child(_case)
	_case.setup(self, case_at)

func plush_found() -> void:
	plush_taken = true
	MHChapterOne.stock["zero_g_plush"] = int(MHChapterOne.stock.get("zero_g_plush", 0)) + 1
	MHNotices.post("valid", "Kai's niece's bear", "A plush bear in a little suit, with a luggage tag in a child's writing. It's on B's Unpacked tab: put it somewhere it can see out.", "log")

# ---------- helpers ----------

func _builder() -> Node:
	return world.get("builder") if world != null else null

## The core (Walker 1, folded down where it's home).
func _core() -> Vector2:
	var walker: Node3D = world.get("walker")
	if walker != null: return Vector2(walker.global_position.x, walker.global_position.z)
	var me: Node3D = world.get("player")
	return Vector2(me.global_position.x, me.global_position.z) if me != null else Vector2.INF

func _outside() -> bool:
	var suit: Node = world.get("suit") if world != null else null
	return suit == null or str(suit.get("where")) == "outside"

# Nothing claims E for now (the case and station have their own prompts).
func claim(_target: Node, _method_name: String) -> bool: return false
func claim_label(_target: Node) -> String: return ""
