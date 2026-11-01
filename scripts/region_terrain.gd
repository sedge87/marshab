extends RefCounted

## A region: one large heightmap shared by several landing zones (gameplay
## loop prototype, docs/gameplay-loop-brief.md §5.1). Made by
## tools/generate_region.py into assets/terrain/<id>/. A site whose terrain
## shape is "region" names the region and its landing zone; the world is
## centred on that zone, with its level pad at height 0.
##
## The game's own height questions (building, landing, GAR-Y) are answered
## here from the heightmap; Terrain3D draws the same heightmap and gives it
## collision (original_mars_environment.gd), so the two always agree.

const DIRECTORY := "res://assets/terrain/"

static var _id := ""
static var _meta: Dictionary = {}
static var _heights: Image       # FORMAT_R16, 0..1 across the height range
static var _size := 0
static var _spacing := 2.0
static var _half := 0.0
static var _low := 0.0
static var _range := 1.0
static var _rocks: Image         # rocks.png: red how thickly rocks lie, green how big
static var _geology: Image       # geology.png: a unit index per pixel (meta "geology")

## Load a region (once; later calls for the same id are free).
static func use(id: String) -> bool:
	if id == _id and _heights != null: return true
	var folder := DIRECTORY + id + "/"
	var meta_text := FileAccess.get_file_as_string(folder + "region.json")
	if meta_text.is_empty():
		push_warning("Region %s is missing (run tools/generate_region.py)" % id)
		return false
	_meta = JSON.parse_string(meta_text)
	_size = int(_meta.size)
	_spacing = float(_meta.spacing)
	_half = float(_meta.half)
	_low = float(_meta.height_min)
	_range = float(_meta.height_max) - _low
	var packed := FileAccess.get_file_as_bytes(folder + "height.r16.gz")
	var raw := packed.decompress(_size * _size * 2, FileAccess.COMPRESSION_GZIP)
	_heights = Image.create_from_data(_size, _size, false, Image.FORMAT_R16, raw)
	_rocks = _image(folder + "rocks.png")
	_geology = _image(folder + "geology.png")
	_id = id
	return true

static func meta() -> Dictionary:
	return _meta

## A landing zone's centre (region metres) and its level.
static func zone(zone_id: String) -> Dictionary:
	return (_meta.get("zones", {}) as Dictionary).get(zone_id, {})

## Height in region coordinates (metres, as generated), bilinear between points.
static func height(rx: float, rz: float) -> float:
	if _heights == null: return 0.0
	var gx := clampf((rx + _half) / _spacing, 0.0, _size - 1.001)
	var gz := clampf((rz + _half) / _spacing, 0.0, _size - 1.001)
	var x0 := int(gx)
	var z0 := int(gz)
	var tx := gx - x0
	var tz := gz - z0
	var a := _heights.get_pixel(x0, z0).r
	var b := _heights.get_pixel(x0 + 1, z0).r
	var c := _heights.get_pixel(x0, z0 + 1).r
	var d := _heights.get_pixel(x0 + 1, z0 + 1).r
	return _low + lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz) * _range

## The heightmap for Terrain3D: 32-bit floats, 0..1 (on import, height =
## value × scale + offset).
static func import_image() -> Image:
	var copy := _heights.duplicate() as Image
	copy.convert(Image.FORMAT_RF)
	return copy

## How thickly rocks lie here (x, 0..1) and how big they run (y, 0..1),
## from the generator's rock map: thick under cliffs, on fresh ejecta and in
## boulder fields, sparse on dusty plains, none on dunes.
static func rock_density(rx: float, rz: float) -> Vector2:
	if _rocks == null: return Vector2(.1, .2)
	var c := _rocks.get_pixel(_map_pixel(rx, _rocks.get_width()), _map_pixel(rz, _rocks.get_height()))
	return Vector2(c.r, c.g)

## The geology unit here (one of meta "geology", e.g. "plains_basalt",
## "canyon_layers"): what rock and soil you'd find, for samples.
static func geology(rx: float, rz: float) -> String:
	var units: Array = _meta.get("geology", [])
	if _geology == null or units.is_empty(): return ""
	var index := roundi(_geology.get_pixel(_map_pixel(rx, _geology.get_width()), _map_pixel(rz, _geology.get_height())).r * 255.0)
	return str(units[clampi(index, 0, units.size() - 1)])

static func _map_pixel(r: float, pixels: int) -> int:
	return clampi(int((r + _half) / (_half * 2.0) * pixels), 0, pixels - 1)

static func _image(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null: return null
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	return image

## Terrain3D's control map: which ground texture is where (packed bits in a
## float image, as Terrain3D stores it; see tools/generate_region.py).
static func control_image() -> Image:
	var packed := FileAccess.get_file_as_bytes(DIRECTORY + _id + "/control.u32.gz")
	if packed.is_empty(): return null
	return Image.create_from_data(_size, _size, false, Image.FORMAT_RF, packed.decompress(_size * _size * 4, FileAccess.COMPRESSION_GZIP))

## Terrain3D's colour map: a gentle large-scale tint, stored at half size.
static func colour_image() -> Image:
	var texture := load(DIRECTORY + _id + "/colour.png") as Texture2D
	if texture == null: return null
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(_size, _size, Image.INTERPOLATE_BILINEAR)
	return image

## The ground textures, in Terrain3D slot order.
static func texture_names() -> Array:
	return _meta.get("textures", ["dust", "bedrock"])

## Terrain3D import values for a world centred on (origin, level): the
## heightmap's corner, and the offset and scale that make heights metres.
static func import_placement(origin: Vector2, level: float) -> Dictionary:
	return {
		"corner": Vector3(-_half - origin.x, 0.0, -_half - origin.y),
		"offset": _low - level,   # metres, added after the scale
		"scale": _range,
	}

## The region's edge in world coordinates (for its boundary).
static func world_bounds(origin: Vector2) -> Rect2:
	return Rect2(-_half - origin.x, -_half - origin.y, _half * 2.0, _half * 2.0)
