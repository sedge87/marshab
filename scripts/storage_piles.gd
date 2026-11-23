extends Node3D

## What's in store, shown in the Storage rooms (23 Nov; systems-and-items §3
## "Storage: holds stock; shows it"). Each Storage cell has four corners of
## slots: regolith sacks, iron bars on a pallet, salvage crates and ore bins.
## Stock fills the Storage cells first, one cell after another, and the
## shelves fill as it grows; what's over goes in the core, out of sight.
## One cell's slots hold exactly what the cell adds to the cap
## (scripts/stores.gd PER_CELL), so a full room means a full store.
##
## Stand-in shapes in house colours until the models arrive
## (docs/assets-chunk3.md "Storage stock"): the slot positions stay the same
## when they do. A slot near furniture you've placed is left empty.

const MHPalette := preload("res://scripts/mh_palette.gd")
const CELL := 3.0
const REFRESH := 2.0
const CLEAR := .85               # metres a slot keeps from placed furniture

## kind -> [kg per item, model path, slots in a cell's corner as [x, y, z]].
## Corners: sacks (-,-), iron (+,-), crates (-,+), ore bins (+,+).
const KINDS := {
	"regolith": [125.0, "res://assets/models/storage/regolith_sack.glb", [[-1.0, 0.0, -1.05], [-.4, 0.0, -1.05], [-1.0, .36, -1.05], [-.4, .36, -1.05]]],
	"iron": [10.0, "res://assets/models/storage/iron_bar.glb", []],
	"salvage": [25.0, "res://assets/models/storage/salvage_crate.glb", [[-1.0, 0.0, 1.0], [-.45, 0.0, 1.0], [-1.0, .5, 1.0], [-.45, .5, 1.0]]],
	"ore": [50.0, "res://assets/models/storage/ore_bin.glb", [[.5, 0.0, .55], [1.05, 0.0, .55], [.5, 0.0, 1.05], [1.05, 0.0, 1.05]]],
}

var builder: Node
var _t := 0.0
var _last := ""

func setup(target_builder: Node) -> void:
	builder = target_builder
	name = "StoragePiles"

## Iron: ten bars on a low pallet in the (+,-) corner, two to a layer.
static func _iron_slots() -> Array:
	var slots: Array = []
	for layer in 5:
		for side in 2:
			slots.append([.75 + side * .14, layer * .09, -1.0])
	return slots

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0: return
	_t = REFRESH
	refresh()

func refresh(force := false) -> void:
	if builder == null: return
	var cells := _storage_cells()
	var key := "%s|%d|%d|%d|%d|%d" % [str(cells), roundi(MHStores.amount("regolith")), roundi(MHStores.amount("iron")), roundi(MHStores.amount("salvage")), roundi(MHStores.amount("ore")), (builder.placed_interior as Array).size()]
	if key == _last and not force: return
	_last = key
	for child in get_children(): child.queue_free()
	if cells.is_empty(): return
	var taken := _furniture_spots()
	for kind in KINDS:
		var spec: Array = KINDS[kind]
		var each: float = spec[0]
		var slots: Array = _iron_slots() if kind == "iron" else spec[2]
		var items := floori(MHStores.amount(kind) / each)
		for cell in cells:
			if items <= 0: break
			var centre := Vector3(cell.x * CELL, float(builder.habitat_base_y), cell.y * CELL)
			for slot in slots:
				if items <= 0: break
				var at: Vector3 = centre + Vector3(slot[0], slot[1], slot[2])
				if _near(at, taken): continue
				_add(kind, at, str(spec[1]))
				items -= 1

func _storage_cells() -> Array:
	var cells: Array = []
	for zone in builder.zones:
		if str(zone.get("kind", "")) != "storage" or zone.has("angled_mount"): continue
		for cell in zone.get("cells", []): cells.append(Vector2i(cell))
	cells.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	return cells

func _furniture_spots() -> Array:
	var spots: Array = []
	for item in builder.placed_interior:
		var p: Variant = item.get("position", null)
		if p is Vector3: spots.append(p)
	return spots

func _near(at: Vector3, spots: Array) -> bool:
	for p in spots:
		if Vector2(p.x - at.x, p.z - at.z).length() < CLEAR: return true
	return false

func _add(kind: String, at: Vector3, model_path: String) -> void:
	var node: Node3D
	if ResourceLoader.exists(model_path):
		node = (load(model_path) as PackedScene).instantiate() as Node3D
		MHPalette.apply(node)
	else:
		node = _stand_in(kind)
	node.position = at
	add_child(node)

## Plain shapes until the models come.
func _stand_in(kind: String) -> Node3D:
	match kind:
		"regolith": return _block(Vector3(.55, .34, .42), "fabric_tan", Color(.62, .5, .38))
		"iron": return _block(Vector3(.12, .08, .6), "dark_alloy", Color(.3, .29, .28))
		"salvage": return _block(Vector3(.5, .48, .5), "graphite", Color(.25, .26, .27))
	var bin := _block(Vector3(.5, .36, .45), "dark_alloy", Color(.35, .35, .36))
	var rock := _block(Vector3(.42, .1, .38), "regolith", Color(.42, .2, .14))
	rock.position.y = .33
	bin.add_child(rock)
	return bin

func _block(size: Vector3, role: String, colour: Color) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = .9
	mat.set_meta("mh_role", role)
	mesh.material_override = mat
	var holder := Node3D.new()
	mesh.position.y = size.y * .5
	holder.add_child(mesh)
	return holder
