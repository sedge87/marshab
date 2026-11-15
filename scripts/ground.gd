extends RefCounted

## What's under your boots or wheels (A7; traversal phase 2 will grow it):
## the ground kind at a point, read from the region's ground.png (red is the
## kind's index in region.json "ground_kinds", made by tools/generate_region.py).
## Region sites only; elsewhere, and off the map, it's "dust".
##
## The vehicles read it (scripts/crew_rover.gd): the pressurised rover bogs on
## sand and ripples, and its wheels wear on sharp boulders and platy lava.

const RegionTerrain := preload("res://scripts/region_terrain.gd")

static var _id := ""
static var _image: Image
static var _kinds: Array = []
static var _half := 0.0

static func _ready_for_region() -> bool:
	if RegionTerrain.meta().is_empty(): return false
	if _id == RegionTerrain._id and _image != null: return true
	_id = RegionTerrain._id
	_kinds = RegionTerrain.meta().get("ground_kinds", [])
	_half = float(RegionTerrain.meta().get("half", 3000.0))
	var texture := load(RegionTerrain.DIRECTORY + _id + "/ground.png") as Texture2D
	_image = texture.get_image() if texture != null else null
	if _image != null and _image.is_compressed(): _image.decompress()
	return _image != null

## The kind at region metres (rx east, rz south): "dust", "sand", "ripples",
## "sharp_boulders" and so on.
static func kind(rx: float, rz: float) -> String:
	if not _ready_for_region() or _kinds.is_empty(): return "dust"
	var w := _image.get_width()
	var h := _image.get_height()
	var px := clampi(int((rx + _half) / (_half * 2.0) * w), 0, w - 1)
	var py := clampi(int((rz + _half) / (_half * 2.0) * h), 0, h - 1)
	var index := roundi(_image.get_pixel(px, py).r * 255.0)
	return str(_kinds[clampi(index, 0, _kinds.size() - 1)])

## The kind under a point in site metres (world x, z) on a region site.
static func kind_at(x: float, z: float) -> String:
	var zone := MHSiteTerrainRef.region_zone()
	if zone.is_empty(): return "dust"
	return kind(x + float(zone.centre[0]), z + float(zone.centre[1]))

const MHSiteTerrainRef := preload("res://scripts/site_terrain.gd")

## Loose ground a heavy rover sinks into.
static func loose(ground_kind: String) -> bool:
	return ground_kind == "sand" or ground_kind == "ripples"

## Ground that cuts wheels.
static func sharp(ground_kind: String) -> bool:
	return ground_kind == "sharp_boulders" or ground_kind == "platy_lava"
