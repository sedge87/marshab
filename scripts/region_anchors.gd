class_name MHRegion
extends RefCounted

## Named anchors on the land (docs/terrain-design.md §13): points the generator
## (tools/generate_region.py) writes into region.json "anchors", one or more for
## every landform, e.g. "far_mesa.top", "east_front.pass_2", "tube.mouth".
## Story things and placed objects name an anchor, never raw coordinates, so
## they follow the land when the land editor (tools/edit_land.bat) moves it.
##
## Positions are region metres (x east, z south, as region.json); `height` is
## the ground there after the build; `ring` is 1, 2 or 3 (0 past ring 3).

const RegionTerrain := preload("res://scripts/region_terrain.gd")
const DEFAULT_REGION := "test_region"

static var _by_id: Dictionary = {}
static var _meta_seen: Dictionary = {}

static func _index() -> Dictionary:
	var meta := RegionTerrain.meta()
	if meta.is_empty():
		RegionTerrain.use(DEFAULT_REGION)
		meta = RegionTerrain.meta()
	if not is_same(meta, _meta_seen):
		_meta_seen = meta
		_by_id = {}
		for a in meta.get("anchors", []):
			_by_id[str(a.id)] = a
	return _by_id

## The anchor's record ({id, position: [x, z], height, ring, landform}), or {} if there's none.
static func anchor(id: String) -> Dictionary:
	return _index().get(id, {})

static func has_anchor(id: String) -> bool:
	return _index().has(id)

## Where the anchor is, in region metres (x, z); Vector2.INF if there's none.
static func anchor_position(id: String) -> Vector2:
	var a := anchor(id)
	if a.is_empty(): return Vector2.INF
	return Vector2(float(a.position[0]), float(a.position[1]))

## The anchor as a region-metre point on the ground (x, height, z); Vector3.INF if there's none.
static func anchor_point(id: String) -> Vector3:
	var a := anchor(id)
	if a.is_empty(): return Vector3.INF
	return Vector3(float(a.position[0]), float(a.height), float(a.position[1]))

## Every anchor id, optionally only those of one landform.
static func anchors(landform := "") -> PackedStringArray:
	var out := PackedStringArray()
	for id in _index():
		if landform.is_empty() or str(_index()[id].get("landform", "")) == landform:
			out.append(id)
	return out

## The area a region point is in (T4, §14: each its own ground palette, sound
## and haze): {id, label, palette, sound, haze, weight}, where weight (0..1)
## eases across the area's soft edge; {} outside every area. Where two
## overlap, the one you're deeper in.
static func area_at(x: float, z: float) -> Dictionary:
	var meta := RegionTerrain.meta()
	if meta.is_empty(): return {}
	var best := {}
	var best_w := 0.0
	for a in meta.get("areas", []):
		var d := Vector2(x - float(a.centre[0]), z - float(a.centre[1])).length() / maxf(float(a.radius), 1.0)
		var w := 1.0 - smoothstep(.72, 1.02, d)
		if w > best_w:
			best_w = w
			best = {"id": str(a.id), "label": str(a.get("label", a.id)), "palette": str(a.get("palette", "")),
				"sound": str(a.get("sound", "wind")), "haze": float(a.get("haze", 1.0)), "weight": w}
	return best
