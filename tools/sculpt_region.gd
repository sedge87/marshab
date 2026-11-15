@tool
extends Node3D

## Sculpt the region by hand in the Godot editor (B5 step 6,
## docs/terrain-design.md §13). Open tools/sculpt_region.tscn, press "Load
## generated land" in the Inspector, then sculpt the Terrain3D node it makes
## with Terrain3D's own brushes (raise, lower, smooth, flatten). Press "Save
## sculpt": the difference from the generated land goes into
## data/region_sculpt.landdelta (tools/land_delta.py has the format), and the
## next build (tools/generate_region.py, or Regenerate in the land editor)
## adds it last of all, except over the caves. Don't save the scene with the
## terrain in it; the sculpt file is what counts.
##
## The land is placed in region metres (x east, z south from the centre) at
## its true heights, so what you see matches the land editor's map.

const RegionTerrain := preload("res://scripts/region_terrain.gd")
const SCULPT_PATH := "res://data/region_sculpt.landdelta"

@export var region_id := "test_region"
@export var sculpt_path := SCULPT_PATH
@export_tool_button("Load generated land") var load_land_button := load_land
@export_tool_button("Save sculpt") var save_sculpt_button := save_sculpt
@export_multiline var status := ""

var terrain: Terrain3D

func load_land() -> void:
	if not RegionTerrain.use(region_id):
		status = "No region %s in %s" % [region_id, RegionTerrain.DIRECTORY]
		return
	var old := get_node_or_null("SculptTerrain")
	if old != null:
		remove_child(old)
		old.queue_free()
	terrain = Terrain3D.new()
	terrain.name = "SculptTerrain"
	terrain.vertex_spacing = float(RegionTerrain.meta().spacing)
	terrain.collision_mode = Terrain3DCollision.DYNAMIC_EDITOR   # the brushes need it
	add_child(terrain)
	terrain.owner = get_tree().edited_scene_root if Engine.is_editor_hint() and get_tree() != null else null
	terrain.region_size = Terrain3D.SIZE_1024
	var place: Dictionary = RegionTerrain.import_placement(Vector2.ZERO, 0.0)
	terrain.data.import_images([RegionTerrain.import_image(), null, null], place.corner, float(place.offset), float(place.scale))
	for region in terrain.data.get_regions_active(): (region as Terrain3DRegion).set_modified(false)
	status = "Loaded %s: sculpt it, then Save sculpt." % region_id

## The sculpted heights minus the generated ones, for every region you've
## touched, plus what the sculpt file held already (the generated land has it
## in, so it's taken out first).
func save_sculpt() -> void:
	if terrain == null or terrain.data == null:
		status = "Load the generated land first."
		return
	var meta := RegionTerrain.meta()
	var size := int(meta.size)
	var spacing := float(meta.spacing)
	var half := float(meta.half)
	var old: MHLandDelta = MHLandDelta.read(sculpt_path)
	var delta: MHLandDelta = old if old != null else MHLandDelta.new(size, spacing)
	var touched := 0
	for region in terrain.data.get_regions_active():
		var r := region as Terrain3DRegion
		if not r.is_modified(): continue
		touched += 1
		var img: Image = r.get_height_map()
		var rs := r.get_region_size()
		var loc := r.get_location()
		for py in rs:
			for px in rs:
				var wx := (loc.x * rs + px) * spacing
				var wz := (loc.y * rs + py) * spacing
				var i := roundi((wx + half) / spacing)
				var j := roundi((wz + half) / spacing)
				if i < 0 or j < 0 or i >= size or j >= size: continue
				var base := RegionTerrain.height(wx, wz) - (old.at(i, j) if old != null else 0.0)
				var d := img.get_pixel(px, py).r - base
				if absf(d) > MHLandDelta.EPSILON or delta.at(i, j) != 0.0: delta.set_at(i, j, d)
	delta.prune()
	if not delta.write(sculpt_path):
		status = "Couldn't write %s" % sculpt_path
		return
	for region in terrain.data.get_regions_active(): (region as Terrain3DRegion).set_modified(false)
	status = "Saved %d tiles (%d regions touched) to %s. Regenerate to build it in." % [delta.tiles.size(), touched, sculpt_path]
