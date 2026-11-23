extends Node3D

## One of the storm's later pallets (scripts/drop_field.gd places them; step
## 3a of docs/systems-and-items.md §14): a parachute laid on the ground, the
## pallet beside its hem, and a short trail of debris leading in. What's
## inside depends on the kind:
## - "power" (pallet 2): the solar blanket and battery (scripts/power_pack.gd);
## - "gary" (pallet 4, in a boulder field): GAR-Y, folded up and asleep;
## - "tools" (pallet 3, in a frost hollow): the rock hammer, a headlamp and a
##   patch kit.

const PARACHUTE := preload("res://assets/models/storm_cargo/parachute.glb")
const DEBRIS := [
	preload("res://assets/models/storm_cargo/debris_strip.glb"),
	preload("res://assets/models/storm_cargo/debris_strap.glb"),
	preload("res://assets/models/storm_cargo/debris_lid.glb"),
	preload("res://assets/models/storm_cargo/debris_foam.glb"),
]
const BOULDERS := [
	preload("res://assets/models/mars_boulder_round.glb"),
	preload("res://assets/models/mars_boulder_dark.glb"),
	preload("res://assets/models/mars_boulder_flat.glb"),
	preload("res://assets/models/mars_rock_cluster.glb"),
]
const PALLET := preload("res://scripts/cargo_pallet.gd")
const POWER_PACK := preload("res://scripts/power_pack.gd")
const POWER_MODULE := preload("res://scripts/power_module.gd")
const SPARES_IN_TOOLS := 2   # version 3: two spares kits in the tools pallet
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHResources := preload("res://scripts/mh_resources.gd")

const CANOPY_SCALE := 1.2
const PALLET_LOCAL := Vector3(-11.0, 0, 1.4)
const DEBRIS_STOPS := [-120.0, -85.0, -55.0, -30.0]   # metres out from the pallet, towards home
const SEEN_FROM := 200.0
const NEAR := 25.0
const LABELS := {"power": "Pallet 2", "tools": "Pallet 3", "gary": "Pallet 4", "print_shop": "Pallet 6"}   # 14 Nov: tools 3, GAR-Y 4; chapter 5: 6
const NAMES := {"power": "Pallet 2 · power", "tools": "Pallet 3 · field tools", "gary": "Pallet 4 · GAR-Y", "print_shop": "Pallet 6 · Survey sled"}   # 23 Nov: the Print Shop moved to the kit box

var field: Node
var world: Node
var kind := ""
var at := Vector3.INF          # the canopy's crown, world
var yaw := 0.0
var pallet: StaticBody3D
var pack: StaticBody3D         # pallet 2's power pack (versions 1-2)
var module: StaticBody3D       # pallet 2's power module (version 3, scripts/power_module.gd)
var empty := false             # pallet 4 after GAR-Y left it to look for you
var _check := 0.0

func setup(target_field: Node, site_kind: String, where: Vector3, turn: float, saved: Dictionary) -> void:
	field = target_field
	world = field.world
	kind = site_kind
	at = where
	yaw = turn
	name = "Drop_" + kind
	add_to_group("storm_drop_site")
	empty = bool(saved.get("empty", false))
	_build(saved)

func id() -> String:
	return "find:pallet_" + kind

func label() -> String:
	return str(LABELS.get(kind, "Pallet"))

func pallet_spot() -> Vector3:
	return local_to_world(PALLET_LOCAL)

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, MHSiteTerrain.height(p.x, p.z), p.z)

func local_to_world(local: Vector3) -> Vector3:
	return _ground(at + Basis(Vector3.UP, yaw) * local)

# ---------- building it ----------

func _build(saved: Dictionary) -> void:
	var chute: Node3D = PARACHUTE.instantiate()
	chute.name = "Parachute"
	add_child(chute)
	chute.global_position = at
	chute.rotation.y = yaw
	chute.scale = Vector3(CANOPY_SCALE, 1.0, CANOPY_SCALE)
	MHPalette.apply(chute)
	for mesh in chute.find_children("*", "MeshInstance3D", true, false): _drape(mesh as MeshInstance3D)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(at.x), roundi(at.z)))
	# The trail in, from the way home.
	var home: Vector3 = field.home_for(kind) if field.has_method("home_for") else world.lander.global_position
	var towards := (home - at) * Vector3(1, 0, 1)
	towards = towards.normalized() if towards.length() > 1.0 else Vector3.BACK
	var across := towards.cross(Vector3.UP)
	for i in DEBRIS_STOPS.size():
		var piece: Node3D = DEBRIS[(i + kind.length()) % DEBRIS.size()].instantiate()
		piece.name = "Debris%d" % i
		add_child(piece)
		var side := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(2.0, 9.0)
		piece.global_position = _ground(at - towards * float(DEBRIS_STOPS[i]) + across * side)
		piece.rotation.y = rng.randf_range(0.0, TAU)
		MHPalette.apply(piece)
		piece.add_to_group("drop_debris")
	# A boulder field round GAR-Y's pallet.
	if kind == "gary":
		for i in 9:
			var rock: Node3D = BOULDERS[i % BOULDERS.size()].instantiate()
			add_child(rock)
			var offset := Vector3(rng.randf_range(9.0, 28.0), 0, 0).rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			var p := _ground(at + offset)
			# Clear of the pallet, so you can watch GAR-Y wake.
			var cradle := pallet_spot()
			var away := Vector3(p.x - cradle.x, 0, p.z - cradle.z)
			if away.length() < 8.0:
				p = _ground(cradle + (away.normalized() if away.length() > .1 else Vector3.RIGHT) * 8.0)
			rock.global_position = p + Vector3(0, -.2, 0)
			rock.rotation.y = rng.randf_range(0.0, TAU)
			var size := rng.randf_range(1.2, 2.6)
			rock.scale = Vector3.ONE * size
			rock.add_to_group("drop_debris")
	pallet = PALLET.new()
	add_child(pallet)
	pallet.global_basis = _on_ground(pallet_spot(), yaw + .35)
	pallet.global_position = Vector3(pallet_spot().x, _footprint_height(pallet_spot()) - .04, pallet_spot().z)
	pallet.setup(self, bool(saved.get("opened", false)), label())
	if kind == "power" and field.v3():
		module = POWER_MODULE.new()
		add_child(module)
		var where := str(saved.get("module", "pallet"))
		if where == "ground" and saved.has("module_at"):
			var p: Array = saved.module_at
			module.setup(self, "ground")
			module.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		else:
			module.setup(self, "plugged" if where == "plugged" else "pallet")
	elif kind == "power":
		pack = POWER_PACK.new()
		add_child(pack)
		var where := str(saved.get("pack", "pallet"))
		if where == "ground" and saved.has("pack_at"):
			var p: Array = saved.pack_at
			pack.setup(self, "ground")
			pack.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		else:
			pack.laid_at = str(saved.get("pack_laid_at", "lander"))
			pack.setup(self, where if where == "laid" else "pallet")

## Tilted to the ground under its whole footprint (not just the middle),
## and never more than about 10°, so it lies on the ground, not in it.
func _on_ground(p: Vector3, turn: float) -> Basis:
	var dx: float = MHSiteTerrain.height(p.x + 1.6, p.z) - MHSiteTerrain.height(p.x - 1.6, p.z)
	var dz: float = MHSiteTerrain.height(p.x, p.z + 1.6) - MHSiteTerrain.height(p.x, p.z - 1.6)
	var tilt := Vector2(-dx / 3.2, -dz / 3.2).limit_length(tan(deg_to_rad(10.0)))
	var up := Vector3(tilt.x, 1.0, tilt.y).normalized()
	var forward := Basis(Vector3.UP, turn).z
	var right := up.cross(forward).normalized()
	return Basis(right, up, right.cross(up).normalized())

## Mean height under the pallet's middle and corners, but no lower than the
## middle less a hand: so a hump under one end doesn't swallow the other.
func _footprint_height(p: Vector3) -> float:
	var middle: float = MHSiteTerrain.height(p.x, p.z)
	var total := middle
	for d in [Vector2(1.6, 1.6), Vector2(-1.6, 1.6), Vector2(1.6, -1.6), Vector2(-1.6, -1.6)]:
		total += MHSiteTerrain.height(p.x + d.x, p.z + d.y)
	return maxf(total / 5.0, middle - .1)

## The canopy's heights are offsets above the ground: lay each vertex on it.
func _drape(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if source == null: return
	var to_world := mesh_instance.global_transform
	var to_local := to_world.affine_inverse()
	var draped := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in points.size():
			var p := to_world * points[i]
			p.y = MHSiteTerrain.height(p.x, p.z) + (p.y - at.y)
			points[i] = to_local * p
		arrays[Mesh.ARRAY_VERTEX] = points
		draped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draped.surface_set_material(s, mesh_instance.get_active_material(s))
	mesh_instance.mesh = draped
	mesh_instance.extra_cull_margin = 4.0

# ---------- the pallet ----------

## What looking into the open pallet reaches (scripts/cargo_pallet.gd).
func inside_of() -> Node:
	if pack != null and pack.where == "pallet": return pack
	if module != null and module.where == "pallet": return module
	if kind == "gary" and bool(field.get("gary_in_cradle")):
		var gary: Variant = world.get("scout_rover")
		if gary != null and is_instance_valid(gary): return gary
	return null

func pallet_opened() -> void:
	var known: Node = world.get("known")
	if known != null:
		known.tell(id(), "you")
		known.rename(id(), str(NAMES.get(kind, label())))
		known.finish(id())
	var notes: Node = world.get("notes")
	match kind:
		"power" when module != null:
			module.reachable(true)
			MHNotices.post("valid", "Pallet 2: power", "One power module, %d kg, with a keyed socket face. Heavy to carry far." % roundi(module.kg()), "log")
		"power":
			pack.reachable(true)
			if notes != null: notes.think("power_pallet", "open")
			MHNotices.post("valid", "Pallet 2: power", "A rolled solar blanket and a battery pack: the core's power. It waits by the lander, packed, until the core's down.", "log")
		"gary":
			if empty and int(world.get("opening_version")) >= 2:
				pass   # it opened itself in the storm (scripts/drop_field.gd gary_out)
			elif empty:
				MHNotices.post("info", "Pallet 4", "GAR-Y's cradle, empty. It came looking for you.", "log")
			else:
				field.wake_gary(self)
		"tools" when field.v3():
			field.got_tools()
			if notes != null: notes.answer("tools")
			MHChapterOne.stock[MHChapterOne.SPARES_KIT] = int(MHChapterOne.stock.get(MHChapterOne.SPARES_KIT, 0)) + SPARES_IN_TOOLS
			if field.hitch != null: field.hitch.found()
			MHNotices.post("valid", "Pallet 3: field tools", "A rock hammer, a headlamp (F), %d spares kits, and a hitch bracket that fits GAR-Y's rear mount (E on GAR-Y)." % SPARES_IN_TOOLS, "log")
			var suit: Node = world.get("suit")
			if suit != null and suit.has_method("give_addon"): suit.give_addon("lamp")
		"tools":
			field.got_tools()
			if notes != null: notes.answer("tools")
			MHNotices.post("valid", "Pallet 3: field tools", "A rock hammer, a headlamp (F: brighter and wider than the suit lamp) and a patch kit for split seals.", "log")
			var suit: Node = world.get("suit")
			if suit != null and suit.has_method("give_addon"): suit.give_addon("lamp")
			# 15 Nov playtest: no plan cartridges here any more. The battery and
			# heater plans are found later, when the cold starts to push.
		"print_shop":
			MHNotices.post("valid", "Pallet 6: the survey sled", "Tamsin's deep-radar sled, in a crate too heavy to carry. Bring GAR-Y close and hitch it to the sled.", "log")
			var radio: Node = world.get("radio")
			if radio != null: radio.ring("d5_pallet")
	field.pallet_opened(self)
	MHAudio.moment()

## Pallet 2's blanket is laid out by the lander (scripts/power_pack.gd).
func power_laid() -> void:
	var notes: Node = world.get("notes")
	if notes != null:
		notes.answer("power_pallet")
		notes.answer("power", {"how": "The solar blanket and the new battery kept the heater going."})
	MHNotices.post("valid", "Solar blanket laid out", "The cabin now has %.1f kW more sunlight and a %d kWh battery: enough to run life support and the lights all night." % [MHResources.revamp("power_pack_kw", 1.5), roundi(MHResources.revamp("power_pack_kwh", 10.0))], "log")
	var hud: Node = world.get("explore_hud")
	if hud != null: hud.hide_equipment_note("Power pack")

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null: return
	_check = .5
	var you: Vector3 = world.player.global_position
	var known: Node = world.get("known")
	if known != null and you.distance_to(at) < SEEN_FROM: known.tell(id(), "you")
	var notes: Node = world.get("notes")
	# Version 2, day 2: GAR-Y's cradle, open and empty, and its tracks.
	if notes != null and kind == "gary" and bool(field.get("gary_working")) and you.distance_to(pallet.global_position) < NEAR:
		if not notes.is_settled("cradle_empty") and not notes.is_open("cradle_empty"): notes.think("cradle_empty")
		var radio: Node = world.get("radio")
		if radio != null: radio.ring("d2_cradle")
	if notes != null and not pallet.opened and you.distance_to(pallet.global_position) < NEAR:
		match kind:
			"power": notes.think("power_pallet", "near")
			"gary": if not empty: notes.think("gary")
			"tools": notes.think("tools", "near")

func export_state() -> Dictionary:
	var out := {"at": [at.x, at.y, at.z], "yaw": yaw, "opened": pallet.opened, "empty": empty}
	if module != null:
		out["module"] = module.where if not module.where in ["carried", "sled"] else "ground"
		var m: Vector3 = module.global_position if module.where != "carried" else _ground(world.player.global_position)
		out["module_at"] = [m.x, m.y, m.z]
	if pack != null:
		out["pack"] = pack.where if not pack.where in ["carried", "sled"] else "ground"
		var p: Vector3 = pack.global_position if pack.where != "carried" else _ground(world.player.global_position)
		out["pack_at"] = [p.x, p.y, p.z]
		out["pack_laid_at"] = pack.laid_at
	return out
