extends Node

## The known-things record (docs/master-design.md §5, systems-and-items §10f):
## one list of what is known, by whom. The Map, the compass and the slate all
## read it, and the voices check it before they speak, so nobody talks about
## something they couldn't know.
##
## Two parts:
## - Where you've been: a coarse grid over the region that clears around you
##   as you walk or drive (the Map's fog). It starts dark.
## - Things: named places, finds, the lander and your own pins, each with who
##   knows it ("you", "gary", "earth", "orbiter"), where it came from and when.
##   A place joins the record when you come within sight of it.
##
## Positions are region metres (x east, y south, as region.json), so they stay
## put whichever landing zone the world is centred on.

const RegionTerrain := preload("res://scripts/region_terrain.gd")

signal learned(id: String, who: String)
signal changed

const GRID := 256              # cells across the region (24 m each on a 6 km region)
const SIGHT := 200.0           # metres around you that clear on the Map
const SIGHT_HIGH := 120.0      # extra sight per 100 m you stand above the ground round you
const PLACE_SIGHT := 600.0     # a named place joins the record within this
const CHECK := .5              # seconds between looks
const WHO := ["you", "gary", "earth", "orbiter"]

var world: Node
var origin := Vector2.ZERO      # the landing zone's centre, region metres
var half := 3072.0
## id -> {kind, at: Vector2, name, who: Array, source, sol, hour}
var things: Dictionary = {}
var _seen := PackedByteArray()
var version := 0                # bumps whenever the fog clears
var _pin_count := 0
var _check := 0.0
var _fog_image: Image

func _init() -> void:
	_seen.resize(GRID * GRID)

func _ready() -> void:
	add_to_group("known_things")

func setup(target_world: Node, zone_origin: Vector2, region_half: float) -> void:
	world = target_world
	origin = zone_origin
	half = region_half

## Looks around twice a second: clears the fog and spots named places.
func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or world == null or world.get("player") == null: return
	_check = CHECK
	look_from(you())

func you() -> Vector2:
	var at: Vector3 = (world.player as Node3D).global_position
	return Vector2(at.x, at.z) + origin

## Everything you can see from `at` (region metres): the fog clears round you
## (further from high ground) and named places in sight join the record.
func look_from(at: Vector2) -> void:
	var sight := SIGHT
	if RegionTerrain.meta().has("half"):
		var here := RegionTerrain.height(at.x, at.y)
		var around := 0.0
		for d in [Vector2(150, 0), Vector2(-150, 0), Vector2(0, 150), Vector2(0, -150)]:
			around += RegionTerrain.height(at.x + d.x, at.y + d.y)
		sight += clampf((here - around * .25) / 100.0, 0.0, 3.0) * SIGHT_HIGH
	reveal(at, sight)
	for feature in RegionTerrain.meta().get("features", []):
		var spot := Vector2(float(feature.position[0]), float(feature.position[1]))
		if spot.distance_to(at) <= PLACE_SIGHT:
			learn(place_id(str(feature.name), spot), "place", spot, str(feature.name))

static func place_id(place_name: String, spot: Vector2) -> String:
	return "place:%s@%d,%d" % [place_name.to_lower().replace(" ", "_"), roundi(spot.x / 50.0), roundi(spot.y / 50.0)]

# ---------- the fog ----------

func _cell_size() -> float:
	return half * 2.0 / GRID

## Clears a soft-edged circle of `radius` metres round `at` (region metres).
func reveal(at: Vector2, radius: float) -> void:
	var cell := _cell_size()
	var gx := (at.x + half) / cell
	var gy := (at.y + half) / cell
	var r := radius / cell
	var any := false
	for y in range(maxi(0, floori(gy - r - 1)), mini(GRID, ceili(gy + r + 1))):
		for x in range(maxi(0, floori(gx - r - 1)), mini(GRID, ceili(gx + r + 1))):
			var d := Vector2(x + .5 - gx, y + .5 - gy).length()
			if d > r: continue
			var value := int(clampf((r - d) / maxf(1.0, r * .35), 0.0, 1.0) * 255.0)
			var i := y * GRID + x
			if value > _seen[i]:
				_seen[i] = value
				any = true
	if any:
		version += 1
		_fog_image = null

## How well you've seen a spot, 0 (never) to 1.
func seen_at(at: Vector2) -> float:
	var cell := _cell_size()
	var x := int((at.x + half) / cell)
	var y := int((at.y + half) / cell)
	if x < 0 or y < 0 or x >= GRID or y >= GRID: return 0.0
	return _seen[y * GRID + x] / 255.0

## Share of the region you've seen.
func seen_share() -> float:
	var total := 0
	for value in _seen: if value > 127: total += 1
	return float(total) / (GRID * GRID)

func reveal_all() -> void:
	_seen.fill(255)
	version += 1
	_fog_image = null
	for feature in RegionTerrain.meta().get("features", []):
		var spot := Vector2(float(feature.position[0]), float(feature.position[1]))
		learn(place_id(str(feature.name), spot), "place", spot, str(feature.name))

## The fog for the Map: dark where you haven't been, clear where you have.
func fog_image() -> Image:
	if _fog_image != null: return _fog_image
	var bytes := PackedByteArray()
	bytes.resize(GRID * GRID * 4)
	for i in GRID * GRID:
		bytes[i * 4] = 12
		bytes[i * 4 + 1] = 10
		bytes[i * 4 + 2] = 9
		bytes[i * 4 + 3] = int((255 - _seen[i]) * .93)
	_fog_image = Image.create_from_data(GRID, GRID, false, Image.FORMAT_RGBA8, bytes)
	return _fog_image

# ---------- things ----------

## Adds what `who` now knows. True when it's new to them.
func learn(id: String, kind: String, at: Vector2, thing_name: String, who := "you", source := "") -> bool:
	var thing: Dictionary = things.get(id, {})
	if thing.is_empty():
		var now := _now()
		thing = {"kind": kind, "at": at, "name": thing_name, "who": [], "source": source if not source.is_empty() else who, "sol": now.x, "hour": now.y}
		things[id] = thing
	if who in thing.who: return false
	(thing.who as Array).append(who)
	learned.emit(id, who)
	changed.emit()
	return true

## `who` hears about something already in the record (a reply, a photo).
func tell(id: String, who: String) -> bool:
	if not things.has(id): return false
	var thing: Dictionary = things[id]
	return learn(id, str(thing.kind), thing.at, str(thing.name), who)

func knows(id: String, who := "you") -> bool:
	return things.has(id) and who in (things[id].who as Array)

func thing(id: String) -> Dictionary:
	return things.get(id, {})

## Your words name the map: a place you describe gets that name.
func rename(id: String, new_name: String) -> void:
	if not things.has(id) or new_name.strip_edges().is_empty(): return
	things[id].name = new_name.strip_edges()
	changed.emit()

## What `who` knows, optionally only of one kind: [{id, kind, at, name, ...}].
func known(who := "you", kind := "") -> Array:
	var out: Array = []
	for id in things:
		var entry: Dictionary = things[id]
		if not who in (entry.who as Array): continue
		if not kind.is_empty() and str(entry.kind) != kind: continue
		var copy := entry.duplicate()
		copy["id"] = id
		out.append(copy)
	return out

# ---------- your pins ----------

func add_pin(at: Vector2, pin_name := "") -> String:
	_pin_count += 1
	var id := "pin:%d" % _pin_count
	learn(id, "pin", at, pin_name if not pin_name.is_empty() else "Pin %d" % _pin_count)
	return id

func remove_pin(id: String) -> void:
	if not things.has(id) or str(things[id].kind) != "pin": return
	things.erase(id)
	changed.emit()

## The pin nearest `at` within `reach` metres, or "".
func pin_near(at: Vector2, reach: float) -> String:
	var best := ""
	var best_d := reach
	for id in things:
		if str(things[id].kind) != "pin": continue
		var d: float = (things[id].at as Vector2).distance_to(at)
		if d <= best_d:
			best = id
			best_d = d
	return best

# ---------- the compass ----------

const COMPASS_KINDS := {"pin": 3000.0, "find": 1500.0, "place": 1200.0}

## Your pins, finds and nearby places for a compass: [{bearing, label, distance, colour}].
func compass_markers(from_world: Vector3) -> Array:
	var out: Array = []
	var here := Vector2(from_world.x, from_world.z) + origin
	for id in things:
		var entry: Dictionary = things[id]
		if not "you" in (entry.who as Array) or not COMPASS_KINDS.has(str(entry.kind)): continue
		var offset: Vector2 = (entry.at as Vector2) - here
		var distance := offset.length()
		if distance > float(COMPASS_KINDS[str(entry.kind)]) or distance < 4.0: continue
		var colour := MHStyle.accent if str(entry.kind) == "pin" else (MHStyle.WARN if str(entry.kind) == "find" else MHStyle.INK_100)
		out.append({"bearing": wrapf(rad_to_deg(atan2(offset.x, -offset.y)), 0.0, 360.0), "label": str(entry.name), "distance": distance, "colour": colour, "kind": str(entry.kind)})
	return out

# ---------- saving ----------

func _now() -> Vector2:
	var hours := 0.0
	var builder: Variant = world.get("builder") if world != null else null
	if builder != null and builder.has_method("simulation"): hours = float(builder.simulation().hours_run)
	return Vector2(floorf(hours / 24.0) + 1.0, MHGame.sol_hour)

func export_state() -> Dictionary:
	var list: Array = []
	for id in things:
		var entry: Dictionary = things[id]
		list.append({"id": id, "kind": entry.kind, "at": [entry.at.x, entry.at.y], "name": entry.name, "who": entry.who, "source": entry.source, "sol": entry.sol, "hour": entry.hour})
	return {"fog": Marshalls.raw_to_base64(_seen.compress(FileAccess.COMPRESSION_DEFLATE)), "things": list, "pins": _pin_count}

func load_state(state: Dictionary) -> void:
	things.clear()
	var fog := str(state.get("fog", ""))
	if not fog.is_empty():
		var raw := Marshalls.base64_to_raw(fog).decompress(GRID * GRID, FileAccess.COMPRESSION_DEFLATE)
		if raw.size() == GRID * GRID: _seen = raw
	for entry in state.get("things", []):
		var at: Array = entry.get("at", [0, 0])
		things[str(entry.id)] = {"kind": str(entry.get("kind", "find")), "at": Vector2(float(at[0]), float(at[1])), "name": str(entry.get("name", "")), "who": Array(entry.get("who", ["you"])), "source": str(entry.get("source", "you")), "sol": float(entry.get("sol", 1)), "hour": float(entry.get("hour", 0))}
	_pin_count = int(state.get("pins", 0))
	version += 1
	_fog_image = null
	changed.emit()

## A save from before the record: clear the fog along your trail and round
## where you stand, so the Map isn't dark over ground you've walked.
func from_trail(trail: PackedVector2Array) -> void:
	for point in trail: reveal(point + origin, SIGHT)
