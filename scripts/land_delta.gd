class_name MHLandDelta
extends RefCounted

## The sculpt layer's file (.landdelta, B5 step 6; the format is in
## tools/land_delta.py, which reads and writes the same bytes): height
## differences on the region's 2 m grid, in tiles so only the edited parts
## are stored, gzipped. data/region_sculpt.landdelta is the hand-sculpted
## layer the generator applies last (tools/sculpt_region.tscn writes it); the
## per-save layer (trenches, dug ground) will reuse this class.

const MAGIC := "LDLT"
const VERSION := 1
const TILE := 64
const EPSILON := .005

var size := 0
var spacing := 2.0
var tile := TILE
var tiles: Dictionary = {}       # Vector2i(tx, tz) -> PackedFloat32Array, tile * tile, row by row

func _init(grid_size := 0, grid_spacing := 2.0, tile_size := TILE) -> void:
	size = grid_size
	spacing = grid_spacing
	tile = tile_size

## The difference at a grid point (i east, j south), 0 where no tile is kept.
func at(i: int, j: int) -> float:
	var key := Vector2i(i / tile, j / tile)
	if not tiles.has(key): return 0.0
	return (tiles[key] as PackedFloat32Array)[(j % tile) * tile + (i % tile)]

## Set a difference; a tile is made when needed.
func set_at(i: int, j: int, value: float) -> void:
	var key := Vector2i(i / tile, j / tile)
	if not tiles.has(key):
		if absf(value) <= EPSILON: return
		var block := PackedFloat32Array()
		block.resize(tile * tile)
		tiles[key] = block
	var arr: PackedFloat32Array = tiles[key]
	arr[(j % tile) * tile + (i % tile)] = value
	tiles[key] = arr

## Drop tiles with nothing left in them.
func prune() -> void:
	for key in tiles.keys():
		var keep := false
		for v in (tiles[key] as PackedFloat32Array):
			if absf(v) > EPSILON:
				keep = true
				break
		if not keep: tiles.erase(key)

## Region metres (x east, z south, origin the region's centre) to the difference there (bilinear).
func height_at(x: float, z: float) -> float:
	var half := size * spacing * .5
	var fx := (x + half) / spacing
	var fz := (z + half) / spacing
	var i := floori(fx)
	var j := floori(fz)
	if i < 0 or j < 0 or i >= size - 1 or j >= size - 1: return 0.0
	var tx := fx - i
	var tz := fz - j
	return lerpf(lerpf(at(i, j), at(i + 1, j), tx), lerpf(at(i, j + 1), at(i + 1, j + 1), tx), tz)

func to_bytes() -> PackedByteArray:
	var raw := PackedByteArray()
	raw.append_array(MAGIC.to_ascii_buffer())
	var head := PackedByteArray()
	head.resize(16)
	head.encode_u16(0, VERSION)
	head.encode_u32(2, size)
	head.encode_float(6, spacing)
	head.encode_u16(10, tile)
	head.encode_u32(12, tiles.size())
	raw.append_array(head)
	var keys := tiles.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for key in keys:
		var block := PackedByteArray()
		block.resize(4 + tile * tile * 2)
		block.encode_u16(0, (key as Vector2i).x)
		block.encode_u16(2, (key as Vector2i).y)
		var arr: PackedFloat32Array = tiles[key]
		for k in tile * tile:
			block.encode_half(4 + k * 2, arr[k])
		raw.append_array(block)
	return raw.compress(FileAccess.COMPRESSION_GZIP)

static func from_bytes(data: PackedByteArray) -> MHLandDelta:
	var raw := data.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if raw.size() < 20 or raw.slice(0, 4).get_string_from_ascii() != MAGIC: return null
	if raw.decode_u16(4) != VERSION: return null
	var out := MHLandDelta.new(raw.decode_u32(6), raw.decode_float(10), raw.decode_u16(14))
	var count := raw.decode_u32(16)
	var at_byte := 20
	var n := out.tile * out.tile
	for c in count:
		var key := Vector2i(raw.decode_u16(at_byte), raw.decode_u16(at_byte + 2))
		at_byte += 4
		var arr := PackedFloat32Array()
		arr.resize(n)
		for k in n:
			arr[k] = raw.decode_half(at_byte + k * 2)
		at_byte += n * 2
		out.tiles[key] = arr
	return out

static func read(path: String) -> MHLandDelta:
	if not FileAccess.file_exists(path): return null
	return from_bytes(FileAccess.get_file_as_bytes(path))

func write(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_buffer(to_bytes())
	return true
