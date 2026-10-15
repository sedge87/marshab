class_name BuildController
extends Node

# One floorplan is the source of truth for plan tiles, visible shell and collision.
const CELL := 3.0
const LIMIT := 60
const CARGO_BUDGET := 8000
const CELL_COST := 50
const AIRLOCK_DOOR := preload("res://scripts/airlock_door.gd")
const SHOWCASE_WALL := preload("res://assets/showcase_modules/mh_wall_bay.glb")
const SHOWCASE_CORNER := preload("res://assets/showcase_modules/mh_corner_post.glb")
const SHOWCASE_AIRLOCK := preload("res://assets/showcase_modules/mh_airlock_surround.glb")
const SHOWCASE_CORRIDOR := preload("res://assets/showcase_modules/mh_corridor_bay.glb")
const SHOWCASE_SOLAR := preload("res://assets/showcase_modules/mh_solar_array.glb")
const SOLAR_CONNECTION_RANGE := 12.0
const SOLAR_OUTPUT := 24
const CREW_TARGET := 6
const ZONE_TYPES := {
	"living":{"label":"Living Quarters","colour":Color(.22,.48,.78),"cost":CELL_COST},
	"science":{"label":"Science Lab","colour":Color(.55,.26,.74),"cost":CELL_COST},
	"storage":{"label":"Storage","colour":Color(.62,.46,.18),"cost":CELL_COST},
	"hydroponics":{"label":"Hydroponics","colour":Color(.18,.62,.31),"cost":CELL_COST},
	"life_support":{"label":"Life Support","colour":Color(.12,.63,.67),"cost":CELL_COST},
	"corridor":{"label":"Corridor","colour":Color(.76,.30,.08),"cost":CELL_COST},
	"airlock":{"label":"Airlock","colour":Color(.95,.43,.08),"cost":CELL_COST},
	"vehicle_bay":{"label":"Vehicle Bay","colour":Color(.88,.62,.12),"cost":CELL_COST},
	"solar":{"label":"Solar Array","colour":Color(.18,.64,.94),"cost":CELL_COST},
	"glass_room":{"label":"Glass Greenhouse","colour":Color(.22,.78,.82),"cost":CELL_COST}
}

# Catalogue metadata for the build HUD. Gameplay values stay in ZONE_TYPES.
const ZONE_INFO := {
	"living":{"cat":"rooms","icon":"bed-double","rule":"Drag an area","desc":"Bunks, lockers and privacy. Every three cells house two crew."},
	"science":{"cat":"rooms","icon":"flask-conical","rule":"Drag an area","desc":"Benches and instruments. Adds research capability."},
	"storage":{"cat":"rooms","icon":"package","rule":"Drag an area","desc":"Racks for spares, tools and supplies."},
	"hydroponics":{"cat":"rooms","icon":"sprout","rule":"Drag an area","desc":"Grow beds. Each cell grows food for five crew."},
	"life_support":{"cat":"rooms","icon":"wind","rule":"Drag an area","desc":"Air and water recycling. Each cell supports four crew."},
	"glass_room":{"cat":"rooms","icon":"flower-2","rule":"Drag an area","desc":"A glazed room with a view of Mars. Uses extra power."},
	"corridor":{"cat":"structure","icon":"move-vertical","rule":"Straight runs","desc":"Joins rooms together. Walkable and open at both ends."},
	"airlock":{"cat":"structure","icon":"door-closed","rule":"1–3 cells · R rotates","desc":"The way in and out. The outer end faces Mars; the inner end must touch a room."},
	"vehicle_bay":{"cat":"structure","icon":"truck","rule":"2–4 cells · R rotates","desc":"A hangar for rovers. Its wide door must face outside."},
	"solar":{"cat":"power","icon":"sun","rule":"One cell · R aims","desc":"Place within 12 m of the habitat. Facing north gives full output."}
}
const CATEGORIES := [["rooms","Rooms","bed-double"],["structure","Structure","box"],["power","Power","sun"]]
const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec3 centre;
uniform float radius = 46.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fade = clamp(1.0 - distance(world_pos.xz, centre.xz) / radius, 0.0, 1.0);
	ALBEDO = COLOR.rgb * COLOR.a * fade;
}
"""

const GRID_WASH_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec3 centre;
uniform float radius = 58.0;
uniform vec4 ink : source_color = vec4(0.063, 0.125, 0.169, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fade = clamp(1.0 - distance(world_pos.xz, centre.xz) / radius, 0.0, 1.0);
	ALBEDO = ink.rgb;
	ALPHA = 0.62 * smoothstep(0.0, 0.5, fade);
}
"""

signal habitat_changed
signal mission_control_requested

var kind := "living"
var airlock_direction := Vector2i(0,-1)
var zones: Array = []
var dragging := false
var drag_start := Vector2i.ZERO
var hover := Vector2i.ZERO
var build_mode := false
var tool := "place"
# Display-only builders (menu backdrop) skip the camera, grid and HUD.
var display_only := false
var root: Node3D
var preview: Node3D
var pivot: Node3D
var camera: Camera3D
var grid: MeshInstance3D
var zoom := 54.0
var habitat_base_y := 0.35
var ui: Control
var hud_layer: CanvasLayer
var cargo_meter: MHWidgets.Meter
var placing_label: Label
var placing_delta: Label
var ready_badge_slot: Control
var catalogue: PanelContainer
var catalogue_rail: PanelContainer
var catalogue_grid: GridContainer
var catalogue_detail: VBoxContainer
var category := "rooms"
var category_buttons := {}
var tool_buttons := {}
var hologram_pill: Control
var notice_column: VBoxContainer
var _last_reason := ""
var _preview_valid_material: StandardMaterial3D
var _preview_invalid_material: StandardMaterial3D
var _line_valid_material: StandardMaterial3D
var _line_invalid_material: StandardMaterial3D
var _preview_key := ""
@onready var world := get_parent()

func _ready() -> void:
	root=Node3D.new(); root.name="StudentHabitat"; world.add_child(root)
	preview=Node3D.new(); preview.name="ZonePreview"; world.add_child(preview)
	if display_only: return
	_camera(); _grid(); _ui()

func _unhandled_input(event: InputEvent) -> void:
	if display_only: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B: _toggle()
		elif build_mode and event.keycode==KEY_R and (kind=="airlock" or kind=="vehicle_bay" or kind=="solar"): _rotate_airlock()
		elif build_mode and event.keycode==KEY_ESCAPE: dragging=false; _draw_preview([],false)
		elif build_mode and event.keycode==KEY_DELETE: _remove_at(hover)
		elif build_mode and event.keycode==KEY_X: _set_tool("place" if tool=="remove" else "remove")
		elif build_mode and event.keycode==KEY_Z and event.ctrl_pressed: _undo()
		elif build_mode and event.keycode==KEY_TAB: _set_catalogue_open(not catalogue.visible); get_viewport().set_input_as_handled()
	if not build_mode or not event is InputEventMouseButton: return
	if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=maxf(20.0,zoom-4.0); _zoom()
	elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(90.0,zoom+4.0); _zoom()
	elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		dragging=false; _set_tool("place"); _draw_preview([],false)
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if tool=="remove":
			if event.pressed: _remove_at(hover)
			return
		if event.pressed: dragging=true; drag_start=hover
		elif dragging:
			dragging=false
			var cells := _cells(drag_start,hover)
			var reason := _invalid_reason(cells)
			if reason.is_empty():
				if zones.is_empty(): habitat_base_y=_proposed_base_y(cells)
				zones.append({"kind":kind,"cells":cells,"door_direction":airlock_direction,"cost":_zone_cost(cells)})
				_rebuild()
				MHAudio.sfx("place")
				var left := CARGO_BUDGET-_used_cargo()
				if left<CARGO_BUDGET*.1: _flash_notice("warn","Cargo is getting tight","%s left — about %d more cells." % [MHStyle.kg(left),left/CELL_COST])
			elif not _pointer_over_ui():
				_flash_notice("invalid","Can't place here",reason+".")
			_draw_preview([],false)

func _process(delta: float) -> void:
	if not build_mode: return
	hover=_cell_at_mouse()
	if grid!=null:
		(grid.material_override as ShaderMaterial).set_shader_parameter("centre",pivot.position)
		((grid.get_child(0) as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("centre",pivot.position)
	var move:=Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z-=1
	if Input.is_key_pressed(KEY_S): move.z+=1
	if Input.is_key_pressed(KEY_A): move.x-=1
	if Input.is_key_pressed(KEY_D): move.x+=1
	if Input.is_key_pressed(KEY_Q): pivot.rotate_y(1.4*delta)
	if Input.is_key_pressed(KEY_E): pivot.rotate_y(-1.4*delta)
	if move.length()>0:
		pivot.position+=pivot.basis*move.normalized()*16.0*delta
		pivot.position.x=clampf(pivot.position.x,-LIMIT,LIMIT); pivot.position.z=clampf(pivot.position.z,-LIMIT,LIMIT)
	if tool=="remove" or _pointer_over_ui():
		_draw_preview([],false); _update_hologram_ui([],"")
		return
	var cells:=_cells(drag_start if dragging else hover,hover)
	var reason:=_invalid_reason(cells)
	_draw_preview(cells,reason.is_empty())
	_update_hologram_ui(cells,reason)

func _pointer_over_ui() -> bool:
	var hovered:=get_viewport().gui_get_hovered_control()
	return hovered!=null and hovered.mouse_filter!=Control.MOUSE_FILTER_IGNORE

func _toggle() -> void:
	build_mode=!build_mode; ui.visible=build_mode; grid.visible=build_mode; camera.current=build_mode
	MHAudio.sfx("mode_build" if build_mode else "mode_explore",0.0,0.0); MHAudio.build_layer(build_mode)
	world.get_node("Player/Head/Camera3D").current=!build_mode
	var explore_hud:=world.get_node_or_null("ExploreHUD") as CanvasLayer
	if explore_hud!=null: explore_hud.visible=not build_mode
	if not build_mode: _set_tool("place"); _update_hologram_ui([],"")
	_set_build_view(build_mode)
	var player:=world.get_node("Player"); player.set_meta("build_mode_active",build_mode)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if build_mode else Input.MOUSE_MODE_CAPTURED
	if not build_mode:
		dragging=false; _draw_preview([],false)
		player.global_position=Vector3(12,3,18); player.safe_position=player.global_position; player.velocity=Vector3.ZERO

func _cell_at_mouse() -> Vector2i:
	var origin:=camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction:=camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(direction.y)<.001: return Vector2i(999,999)
	var point:=origin+direction*((0.0-origin.y)/direction.y)
	return Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))

func _cells(a: Vector2i,b: Vector2i) -> Array:
	var out:Array=[]
	if a.x==999 or b.x==999: return out
	if kind=="airlock":
		# Airlocks are short, straight chambers: drag along their orange outside arrow.
		if airlock_direction.x!=0 and a.y!=b.y: return out
		if airlock_direction.y!=0 and a.x!=b.x: return out
		var length:=absi(b.x-a.x)+absi(b.y-a.y)+1
		if length>3: return out
		for x in range(mini(a.x,b.x),maxi(a.x,b.x)+1):
			for z in range(mini(a.y,b.y),maxi(a.y,b.y)+1): out.append(Vector2i(x,z))
		return out
	if kind=="solar": return [b]
	if kind=="corridor" and a.x!=b.x and a.y!=b.y: return out
	for x in range(mini(a.x,b.x),maxi(a.x,b.x)+1):
		for z in range(mini(a.y,b.y),maxi(a.y,b.y)+1): out.append(Vector2i(x,z))
	return out

func _occupied(cell: Vector2i) -> bool:
	for zone in zones:
		if cell in zone.cells: return true
	return false

func _valid(cells: Array) -> bool:
	return _invalid_reason(cells).is_empty()

# Empty when the cells can be placed; otherwise a short reason for the
# hologram status ("Can't place here · Overlaps a room").
func _invalid_reason(cells: Array) -> String:
	if cells.is_empty():
		if kind=="airlock": return "Airlocks are 1–3 cells in a straight line"
		if kind=="corridor": return "Corridors run in straight lines"
		return "Point at the ground"
	for cell in cells:
		if abs(cell.x)>LIMIT/CELL or abs(cell.y)>LIMIT/CELL: return "Outside the build area"
	for cell in cells:
		if _occupied(cell): return "Overlaps existing habitat"
	if kind=="airlock" and not _valid_airlock(cells): return "Inner end must touch a room; outer end faces Mars"
	if kind=="vehicle_bay" and not _valid_vehicle_bay(cells): return "2–4 cells each way, door facing outside, beside a room"
	if kind=="solar" and not _valid_solar(cells): return "Must be within 12 m of the habitat"
	if _used_cargo()+_zone_cost(cells)>CARGO_BUDGET: return "Not enough cargo left"
	# Build on a local, reasonably flat patch. A short foundation can bridge a
	# shallow dip, but we reject hills and deep drops instead of making towers.
	if is_inside_tree() and not zones.is_empty():
		for cell in cells:
			var terrain:=_cell_highest_terrain(cell)
			if terrain>habitat_base_y-.18: return "Ground is too high here"
			if terrain<habitat_base_y-1.55: return "Ground drops away too far"
	return ""

func _valid_airlock(cells: Array) -> bool:
	if cells.size()<1 or cells.size()>3: return false
	var outside_cell:=_airlock_end(cells,airlock_direction,true)
	var inner_cell:=_airlock_end(cells,airlock_direction,false)
	# The outer end must face Mars; the far end must join an existing habitat.
	return not _occupied(outside_cell+airlock_direction) and _occupied(inner_cell-airlock_direction)

func _valid_vehicle_bay(cells: Array) -> bool:
	var min_x: int=cells[0].x; var max_x: int=cells[0].x; var min_z: int=cells[0].y; var max_z: int=cells[0].y
	for cell in cells:
		min_x=mini(min_x,cell.x); max_x=maxi(max_x,cell.x); min_z=mini(min_z,cell.y); max_z=maxi(max_z,cell.y)
	var width: int=max_x-min_x+1; var depth: int=max_z-min_z+1
	# Keep the hangar legible and modest: 2–4 cells each way, rectangular only.
	if cells.size()!=width*depth or width<2 or depth<2 or width>4 or depth>4: return false
	var connected:=false
	for cell in cells:
		if _occupied(cell+airlock_direction): return false # Keep the hangar face outside.
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side!=airlock_direction and _occupied(cell+side): connected=true
	return connected

func _valid_solar(cells: Array) -> bool:
	if cells.size()!=1 or zones.is_empty(): return false
	var cell:Vector2i=cells[0]
	# Power hardware stays outside the shell, but can cable to any nearby habitat cell.
	for zone in zones:
		if str(zone.kind)=="solar": continue
		for habitat_cell in zone.cells:
			if Vector2(cell.x-habitat_cell.x,cell.y-habitat_cell.y).length()*CELL<=SOLAR_CONNECTION_RANGE: return true
	return false

func _draw_preview(cells: Array,valid: bool) -> void:
	# The ghost only changes when the footprint, validity or facing changes.
	var key:="%s|%s|%s|%s" % [str(cells),valid,airlock_direction,kind]
	if key==_preview_key: return
	_preview_key=key
	for child in preview.get_children(): child.queue_free()
	if cells.is_empty(): return
	_ensure_preview_materials()
	var fill:=_preview_valid_material if valid else _preview_invalid_material
	var edge:=_line_valid_material if valid else _line_invalid_material
	var base_y:=habitat_base_y if not zones.is_empty() else .35
	# Footprint quad on the ground, one per cell so L-shaped drags still read.
	for cell in cells:
		var tile:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(CELL-.06,.04,CELL-.06); tile.mesh=mesh; tile.material_override=fill; tile.position=Vector3(cell.x*CELL,base_y+.05,cell.y*CELL); tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(tile)
	# Hologram volume: translucent shell with bright edges (unlit #3EE58A / #FF4D4D).
	var bounds:=_cell_bounds(cells)
	var height:=2.9 if kind!="solar" else 1.6
	var volume_size:=Vector3(bounds.size.x*CELL,height,bounds.size.y*CELL)
	var volume_centre:=Vector3((bounds.position.x+bounds.size.x*.5-.5)*CELL,base_y+height*.5,(bounds.position.y+bounds.size.y*.5-.5)*CELL)
	if kind=="solar": volume_size=Vector3(2.4,height,1.6)
	var ghost:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=volume_size; ghost.mesh=box; ghost.material_override=fill; ghost.position=volume_centre; ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(ghost)
	preview.add_child(_box_edges(volume_centre,volume_size,edge))
	if kind=="airlock": _airlock_arrow(_airlock_end(cells,airlock_direction,true),"OUTSIDE")
	if kind=="vehicle_bay": _airlock_arrow(_face_preview_cell(cells,airlock_direction),"HANGAR")
	if kind=="solar": _airlock_arrow(cells[0],"SOLAR %d%%" % roundi(_solar_efficiency(airlock_direction)*100.0))

func _ensure_preview_materials() -> void:
	if _preview_valid_material!=null: return
	_preview_valid_material=_holo_material(MHStyle.HOLO_VALID,.2)
	_preview_invalid_material=_holo_material(MHStyle.HOLO_INVALID,.2)
	_line_valid_material=_holo_material(MHStyle.HOLO_VALID,.95)
	_line_invalid_material=_holo_material(MHStyle.HOLO_INVALID,.95)

func _holo_material(colour: Color,alpha: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(colour,alpha)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.no_depth_test=false
	material.disable_fog=true
	return material

func _cell_bounds(cells: Array) -> Rect2i:
	var min_x: int=cells[0].x; var max_x: int=cells[0].x; var min_z: int=cells[0].y; var max_z: int=cells[0].y
	for cell in cells:
		min_x=mini(min_x,cell.x); max_x=maxi(max_x,cell.x); min_z=mini(min_z,cell.y); max_z=maxi(max_z,cell.y)
	return Rect2i(min_x,min_z,max_x-min_x+1,max_z-min_z+1)

func _box_edges(centre: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var h:=size*.5
	var corners:=[]
	for y in [-1,1]:
		for c in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]: corners.append(Vector3(c.x*h.x,y*h.y,c.y*h.z))
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
	for i in 4:
		for pair in [[i,(i+1)%4],[i+4,(i+1)%4+4],[i,i+4]]:
			mesh.surface_add_vertex(corners[pair[0]]); mesh.surface_add_vertex(corners[pair[1]])
	mesh.surface_end()
	var lines:=MeshInstance3D.new(); lines.mesh=mesh; lines.position=centre; lines.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lines

func _airlock_arrow(cell: Vector2i,label_text := "OUTSIDE") -> void:
	var arrow:=MeshInstance3D.new(); var mesh:=ImmediateMesh.new(); var material:=StandardMaterial3D.new()
	material.albedo_color=MHStyle.accent; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var y:=(habitat_base_y if not zones.is_empty() else .35)+.12
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material); mesh.surface_add_vertex(Vector3(0,y,-1.20)); mesh.surface_add_vertex(Vector3(-.65,y,-.35)); mesh.surface_add_vertex(Vector3(.65,y,-.35)); mesh.surface_end()
	arrow.mesh=mesh; arrow.position=Vector3(cell.x*CELL,0,cell.y*CELL); arrow.rotation.y=_direction_yaw(airlock_direction); preview.add_child(arrow)
	var label:=_label3d(label_text,44,MHStyle.accent); label.position=arrow.position+Vector3(airlock_direction.x*1.4,y+.9,airlock_direction.y*1.4); preview.add_child(label)

func _label3d(text: String,size: int,colour: Color,weight := 800) -> Label3D:
	var label:=Label3D.new(); label.text=text; label.font=MHStyle.font(weight,false,2); label.font_size=size; label.outline_size=10; label.outline_modulate=Color(MHStyle.INK_950,.85); label.modulate=colour; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true; label.render_priority=2; label.pixel_size=.013
	return label

func _rebuild() -> void:
	for child in root.get_children(): child.queue_free()
	for zone in zones:
		_zone_surfaces(zone)
		if str(zone.kind)=="airlock": _build_airlock_zone(zone)
		elif str(zone.kind)=="vehicle_bay": _build_vehicle_bay(zone)
		elif str(zone.kind)=="solar": _build_solar(zone)
		else:
			for cell in zone.cells: _cell_walls(cell,zone)
	_build_foundation_supports()
	if grid!=null: grid.position.y=habitat_base_y+.09
	for zone in zones: _add_zone_label(zone)
	_set_build_view(build_mode); _update_budget(); _update_summary(); _update_systems()
	habitat_changed.emit()

func _zone_surfaces(zone: Dictionary) -> void:
	var cells:Array=zone.cells
	var zone_kind:=str(zone.kind)
	if zone_kind=="solar": return
	var colour:Color=ZONE_TYPES[zone_kind].colour
	var min_x: int=cells[0].x; var max_x: int=cells[0].x; var min_z: int=cells[0].y; var max_z: int=cells[0].y
	for cell in cells:
		min_x=mini(min_x,cell.x); max_x=maxi(max_x,cell.x); min_z=mini(min_z,cell.y); max_z=maxi(max_z,cell.y)
	var size_x:=float(max_x-min_x+1)*CELL
	var size_z:=float(max_z-min_z+1)*CELL
	var centre:=Vector3((float(min_x+max_x)*.5)*CELL,0,(float(min_z+max_z)*.5)*CELL)
	var show_generated_surface:=zone_kind!="corridor"
	# A drag rectangle is one continuous interior slab and one continuous roof.
	# For a future irregular paint shape, individual cells remain a safe fallback.
	if cells.size()==(max_x-min_x+1)*(max_z-min_z+1):
		_add_box(centre+Vector3(0,habitat_base_y-.1,0),Vector3(size_x,.2,size_z),colour.darkened(.48),true,"habitat_floor",show_generated_surface)
		if zone_kind=="glass_room": _add_glass_box(centre+Vector3(0,habitat_base_y+2.9,0),Vector3(size_x,.15,size_z),Color(.36,.86,.92,.35),true,"habitat_roof")
		else: _add_box(centre+Vector3(0,habitat_base_y+2.9,0),Vector3(size_x,.15,size_z),MHStyle.STRUCTURAL_WHITE.darkened(.08),true,"habitat_roof",show_generated_surface)
		if zone_kind!="glass_room" and zone_kind!="corridor" and zone_kind!="airlock":
			for corner in [Vector2i(min_x,min_z),Vector2i(max_x+1,min_z),Vector2i(max_x+1,max_z+1),Vector2i(min_x,max_z+1)]:
				_add_showcase(SHOWCASE_CORNER,Vector3(corner.x*CELL-CELL*.5,habitat_base_y,corner.y*CELL-CELL*.5))
		if zone_kind=="corridor":
			var yaw:=_corridor_yaw(cells)
			for cell in cells: _add_showcase(SHOWCASE_CORRIDOR,Vector3(cell.x*CELL,habitat_base_y,cell.y*CELL),yaw)
	else:
		for cell in cells:
			var local_centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
			_add_box(local_centre+Vector3(0,habitat_base_y-.1,0),Vector3(CELL,.2,CELL),colour.darkened(.48),true,"habitat_floor")
			if zone_kind=="glass_room": _add_glass_box(local_centre+Vector3(0,habitat_base_y+2.9,0),Vector3(CELL,.15,CELL),Color(.36,.86,.92,.35),true,"habitat_roof")
			else: _add_box(local_centre+Vector3(0,habitat_base_y+2.9,0),Vector3(CELL,.15,CELL),MHStyle.STRUCTURAL_WHITE.darkened(.08),true,"habitat_roof")

func _cell_walls(cell: Vector2i,zone: Dictionary) -> void:
	var zone_kind:=str(zone.kind); var colour:Color=ZONE_TYPES[zone_kind].colour; var centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
	_add_plan_tile(centre,colour,zone_kind)
	for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		var adjacent: Vector2i=cell+side
		if _occupied(adjacent):
			# Shared grid edges are real openings: neither wall nor collision is created.
			continue
		_add_exterior_wall(centre,side,zone_kind,zone)

func _build_airlock_zone(zone: Dictionary) -> void:
	var outside:=_airlock_side(zone)
	var cells:Array=zone.cells
	var outer_cell:=_airlock_end(cells,outside,true)
	var inner_cell:=_airlock_end(cells,outside,false)
	# Only the exterior threshold gets the showcase portal. The far end is a
	# compact framed inner hatch; together they form a sealed chamber up to 3 cells long.
	var outer_door:=_add_door(Vector3(outer_cell.x*CELL,0,outer_cell.y*CELL),outside,"OUTER",true)
	var inner_door:=_add_door(Vector3(inner_cell.x*CELL,0,inner_cell.y*CELL),-outside,"INNER",false)
	outer_door.set_partner(inner_door)
	inner_door.set_partner(outer_door)
	for cell in cells:
		var centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
		_add_plan_tile(centre,ZONE_TYPES["airlock"].colour,"airlock")
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side!=outside and side!=-outside: _add_exterior_wall(centre,side,"airlock",zone)

func _build_vehicle_bay(zone: Dictionary) -> void:
	var outside:=_airlock_side(zone)
	var cells:Array=zone.cells
	# Find real zone-to-zone edges first.  Edges between cells in this same bay
	# are just its interior floorplan, never connections and never doors.
	var connection_edges:Array=[]
	for cell in cells:
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side!=outside and not (cell+side in cells) and _occupied(cell+side):
				connection_edges.append({"cell":cell,"side":side})
	# One deliberately placed personnel bulkhead is clearer and safer than a
	# door on every cell of a shared edge.  Other edges remain solid wall.
	var access_edge: Dictionary={}
	if not connection_edges.is_empty(): access_edge=connection_edges[connection_edges.size()/2]
	var habitat_door: AirlockDoor
	for cell in zone.cells:
		var centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
		_add_plan_tile(centre,ZONE_TYPES["vehicle_bay"].colour,"vehicle_bay")
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side==outside: continue # The sealed, opening hangar door owns this face.
			if cell+side in cells: continue
			if not access_edge.is_empty() and cell==access_edge.cell and side==access_edge.side:
				# A bay never opens directly into the habitat: this sealed personnel
				# bulkhead is the only route between them.
				habitat_door=_add_door(centre,side,"BAY",false)
				continue
			_add_exterior_wall(centre,side,"vehicle_bay",zone)
	var face:=_zone_face(zone,outside)
	var hangar:=AIRLOCK_DOOR.new(); hangar.position=face.position; hangar.rotation.y=_direction_yaw(outside); root.add_child(hangar)
	# The wide exterior hatch is interlocked with every internal bay door.
	# Internal doors may share the pressurised habitat, but all must close before
	# the hangar can open to Mars.
	hangar.setup("HANGAR",true,face.width,2.58)
	if habitat_door!=null:
		hangar.add_partner(habitat_door)
		habitat_door.add_partner(hangar)

func _build_solar(zone: Dictionary) -> void:
	var cell:Vector2i=zone.cells[0]
	var position:=Vector3(cell.x*CELL,_terrain_height(Vector3(cell.x*CELL,0,cell.y*CELL)),cell.y*CELL)
	_add_showcase(SHOWCASE_SOLAR,position,_direction_yaw(_airlock_side(zone)))
	# The visual comes from Blender; this small base prevents the player walking
	# through the mast without giving the solar panel an oversized collider. A
	# larger pad also makes its ground contact clear on uneven Mars terrain.
	_add_box(position+Vector3(0,.08,0),Vector3(1.75,.16,1.45),MHStyle.SEAL_DARK,true,"solar_base",true)
	_add_solar_cable(position,_nearest_habitat_point(cell))
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["solar"].colour,"solar")

func _nearest_habitat_point(solar_cell: Vector2i) -> Vector3:
	var solar_point:=Vector3(solar_cell.x*CELL,habitat_base_y,solar_cell.y*CELL)
	var closest:=solar_point
	var closest_distance:=INF
	for zone in zones:
		if str(zone.kind)=="solar": continue
		for cell in zone.cells:
			var candidate:=Vector3(cell.x*CELL,habitat_base_y,cell.y*CELL)
			var distance:=candidate.distance_squared_to(solar_point)
			if distance<closest_distance:
				closest_distance=distance
				closest=candidate
	return closest

func _add_solar_cable(from: Vector3,to: Vector3) -> void:
	var start:=from+Vector3(0,.10,0)
	var end:=to+Vector3(0,.12,0)
	var direction:=end-start
	if direction.length()<.1: return
	var cable:=MeshInstance3D.new(); var cylinder:=CylinderMesh.new(); cylinder.top_radius=.035; cylinder.bottom_radius=.035; cylinder.height=direction.length(); cable.mesh=cylinder
	var material:=StandardMaterial3D.new(); material.albedo_color=MHStyle.SOLAR_CELL; material.emission_enabled=true; material.emission=MHStyle.CELL_LINE*.18; material.roughness=.35; cable.material_override=material
	cable.position=(start+end)*.5; cable.basis=Basis(Quaternion(Vector3.UP,direction.normalized())); root.add_child(cable)

func _airlock_end(cells: Array,direction: Vector2i,outside: bool) -> Vector2i:
	var chosen:Vector2i=cells[0]
	for cell in cells:
		var dot: int=cell.x*direction.x+cell.y*direction.y
		var chosen_dot: int=chosen.x*direction.x+chosen.y*direction.y
		if (outside and dot>chosen_dot) or (not outside and dot<chosen_dot): chosen=cell
	return chosen

func _face_preview_cell(cells: Array,direction: Vector2i) -> Vector2i:
	return _airlock_end(cells,direction,true)

func _zone_face(zone: Dictionary,direction: Vector2i) -> Dictionary:
	var cells:Array=zone.cells; var min_x: int=cells[0].x; var max_x: int=cells[0].x; var min_z: int=cells[0].y; var max_z: int=cells[0].y
	for cell in cells:
		min_x=mini(min_x,cell.x); max_x=maxi(max_x,cell.x); min_z=mini(min_z,cell.y); max_z=maxi(max_z,cell.y)
	if direction.x!=0:
		return {"position":Vector3((max_x if direction.x>0 else min_x)*CELL+direction.x*CELL*.5,habitat_base_y,(float(min_z+max_z)*.5)*CELL),"width":float(max_z-min_z+1)*CELL-.28}
	return {"position":Vector3((float(min_x+max_x)*.5)*CELL,habitat_base_y,(max_z if direction.y>0 else min_z)*CELL+direction.y*CELL*.5),"width":float(max_x-min_x+1)*CELL-.28}

func _add_exterior_wall(centre: Vector3,side: Vector2i,zone_kind: String,zone: Dictionary) -> void:
	var wall_position:=centre+Vector3(side.x*CELL*.5,habitat_base_y+1.45,side.y*CELL*.5)
	var wall_size:=Vector3(.16,2.9,CELL) if side.x!=0 else Vector3(CELL,2.9,.16)
	if zone_kind=="glass_room":
		_add_glass_box(wall_position,wall_size,Color(.35,.86,.92,.30),true,"habitat_wall")
		return
	var corridor_side:=zone_kind=="corridor" and _is_corridor_side(zone,side)
	# The collision box is centred at half wall height, while the Blender wall
	# kit is exported with its base at y=0.  Giving both the same position was
	# lifting the visible panel by 1.45 m above its collision and the roof.
	if not corridor_side:
		_add_showcase(SHOWCASE_WALL,Vector3(wall_position.x,habitat_base_y,wall_position.z),_wall_yaw(side))
	# Collision only: the Blender wall bay is the visible surface (a visible box
	# here sat on top of it and hid its panels, seals and windows).
	_add_box(wall_position,wall_size,MHStyle.STRUCTURAL_WHITE,true,"habitat_wall",false)

func _airlock_side(zone: Dictionary) -> Vector2i:
	return zone.get("door_direction",Vector2i(0,-1))

func _add_door(centre: Vector3,side: Vector2i,door_name := "AIRLOCK",show_surround := true) -> AirlockDoor:
	var position:=centre+Vector3(side.x*CELL*.5,habitat_base_y,side.y*CELL*.5)
	if show_surround: _add_showcase(SHOWCASE_AIRLOCK,position,_direction_yaw(side))
	var door:=AIRLOCK_DOOR.new(); door.position=position; door.rotation.y=_direction_yaw(side); root.add_child(door)
	# The exterior has the Blender surround. Give the far/inner threshold a
	# compact frame of its own so it is visibly an actual hatch, not a panel.
	door.setup(door_name,not show_surround)
	return door

func _corridor_yaw(cells: Array) -> float:
	if cells.size()>1 and cells[0].x!=cells[cells.size()-1].x: return PI*.5
	return 0.0

func _is_corridor_side(zone: Dictionary,side: Vector2i) -> bool:
	var cells:Array=zone.cells
	var runs_x: bool=cells.size()>1 and cells[0].x!=cells[cells.size()-1].x
	return side.y!=0 if runs_x else side.x!=0

func _wall_yaw(side: Vector2i) -> float:
	# The Blender wall has an exterior face. Opposite boundaries need an actual
	# 180-degree reversal, not merely the same yaw, or half the base shows its
	# plain interior back panel.
	if side==Vector2i(0,-1): return 0.0
	if side==Vector2i(1,0): return PI*.5
	if side==Vector2i(0,1): return PI
	return -PI*.5

func _add_showcase(scene: PackedScene,position: Vector3,yaw := 0.0) -> void:
	var asset:=scene.instantiate()
	asset.position=position
	asset.rotation.y=yaw
	asset.add_to_group("habitat_showcase_visual")
	MHGame.apply_kit_materials(asset)
	root.add_child(asset)

func _add_plan_tile(centre: Vector3,colour: Color,zone_kind: String) -> void:
	var tile:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(CELL-.28,.045,CELL-.28); tile.mesh=mesh
	var material:=StandardMaterial3D.new(); material.albedo_color=colour.lightened(.16); material.emission_enabled=true; material.emission=colour.darkened(.25); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	tile.material_override=material; tile.position=centre+Vector3(0,habitat_base_y+.025,0); tile.name=zone_kind+"PlanTile"; tile.add_to_group("habitat_plan"); tile.visible=build_mode; root.add_child(tile)

func _add_box(position: Vector3,size: Vector3,colour: Color,solid: bool,group := "",show_visual := true) -> void:
	var body:=StaticBody3D.new(); body.position=position; body.collision_layer=1; body.collision_mask=1; if not group.is_empty(): body.add_to_group(group); root.add_child(body)
	if show_visual:
		var visual:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; visual.mesh=mesh; var material:=StandardMaterial3D.new(); material.albedo_color=colour; material.roughness=.70; visual.material_override=material; body.add_child(visual)
	if solid: var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape; body.add_child(collision)

func _add_glass_box(position: Vector3,size: Vector3,colour: Color,solid: bool,group := "") -> void:
	var body:=StaticBody3D.new(); body.position=position; body.collision_layer=1; if not group.is_empty(): body.add_to_group(group); root.add_child(body)
	var visual:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; visual.mesh=mesh; var material:=StandardMaterial3D.new(); material.albedo_color=colour; material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.roughness=.18; material.metallic=.15; visual.material_override=material; body.add_child(visual)
	if solid: var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape; body.add_child(collision)

func _add_zone_label(zone: Dictionary) -> void:
	var cells:Array=zone.cells; var centre:=Vector3.ZERO
	for cell in cells: centre+=Vector3(cell.x*CELL,0,cell.y*CELL)
	centre/=cells.size()
	var label:=_label3d(str(ZONE_TYPES[zone.kind].label).to_upper(),40,MHStyle.INK_100); label.position=centre+Vector3(0,habitat_base_y+.4,0); label.offset=Vector2(0,22); label.visible=build_mode; label.add_to_group("zone_label"); root.add_child(label)
	var detail:=_label3d("%d CELLS · %s" % [cells.size(),MHStyle.kg(int(zone.cost))],28,(ZONE_TYPES[zone.kind].colour as Color).lightened(.35),600); detail.font=MHStyle.font(600,true,1); detail.position=centre+Vector3(0,habitat_base_y+.4,0); detail.offset=Vector2(0,-24); detail.visible=build_mode; detail.add_to_group("zone_label"); root.add_child(detail)

func _set_build_view(show_plan: bool) -> void:
	for roof in get_tree().get_nodes_in_group("habitat_roof"):
		_set_visual_children(roof,not show_plan)
	for floor in get_tree().get_nodes_in_group("habitat_floor"):
		_set_visual_children(floor,not show_plan)
	for wall in get_tree().get_nodes_in_group("habitat_wall"):
		_set_visual_children(wall,not show_plan)
	for asset in get_tree().get_nodes_in_group("habitat_showcase_visual"):
		_set_visual_children(asset,not show_plan)
	for door in get_tree().get_nodes_in_group("airlock_door"):
		_set_visual_children(door,not show_plan)
	for plan in get_tree().get_nodes_in_group("habitat_plan"): plan.visible=show_plan
	for label in get_tree().get_nodes_in_group("zone_label"): label.visible=show_plan

func _set_visual_children(node: Node,visible: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible=visible
	for child in node.get_children():
		_set_visual_children(child,visible)

func _proposed_base_y(cells: Array) -> float:
	# The first painted area sets the level datum. We use its highest sampled
	# point, then later validate additions against that datum.
	if not is_inside_tree():
		return .35
	var highest := -.50
	for cell in cells:
		highest=maxf(highest,_cell_highest_terrain(cell))
	return highest+.35

func _cell_highest_terrain(cell: Vector2i) -> float:
	var highest := -.50
	var centre := Vector3(cell.x*CELL,0,cell.y*CELL)
	for offset in [Vector3.ZERO,Vector3(1.32,0,1.32),Vector3(1.32,0,-1.32),Vector3(-1.32,0,1.32),Vector3(-1.32,0,-1.32)]:
		highest=maxf(highest,_terrain_height(centre+offset))
	return highest

func _terrain_height(point: Vector3) -> float:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*80.0,point+Vector3.DOWN*80.0,1)
	# A rebuild can leave old habitat colliders in physics for one frame. Exclude
	# them so supports always reach original Mars terrain.
	for collider in root.find_children("*","CollisionObject3D",true,false):
		if collider is CollisionObject3D: query.exclude.append(collider.get_rid())
	var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else -.25

func _build_foundation_supports() -> void:
	# Purposeful pylons only at exposed outer corners, rather than a post under
	# every cell. They appear only where the raised platform needs them.
	var points:Dictionary={}
	for zone in zones:
		for cell in zone.cells:
			for x_sign in [-1,1]:
				for z_sign in [-1,1]: points[Vector2i(cell.x*2+x_sign,cell.y*2+z_sign)]=true
	for key in points:
		var point:Vector2i=key
		var low_x:=floori(float(point.x)/2.0); var high_x:=ceili(float(point.x)/2.0)
		var low_z:=floori(float(point.y)/2.0); var high_z:=ceili(float(point.y)/2.0)
		var around=[Vector2i(low_x,low_z),Vector2i(low_x,high_z),Vector2i(high_x,low_z),Vector2i(high_x,high_z)]
		var count:=0
		for cell in around:
			if _occupied(cell): count+=1
		if count==1 or count==3:
			var position:=Vector3(point.x*CELL*.5,0,point.y*CELL*.5)
			var ground:=_terrain_height(position)
			if habitat_base_y-ground>.42: _add_support(position,ground)

func _add_support(point: Vector3,ground: float) -> void:
	var height:=habitat_base_y-ground
	var support:=StaticBody3D.new()
	support.position=Vector3(point.x,ground+height*.5,point.z)
	support.collision_layer=1
	root.add_child(support)
	var pylon:=CylinderMesh.new(); pylon.top_radius=.17; pylon.bottom_radius=.30; pylon.height=height
	var visual:=MeshInstance3D.new(); visual.mesh=pylon
	var material:=StandardMaterial3D.new(); material.albedo_color=MHStyle.FRAME_STEEL; material.metallic=.65; material.roughness=.38; visual.material_override=material; support.add_child(visual)
	var collision:=CollisionShape3D.new(); var shape:=CylinderShape3D.new(); shape.radius=.30; shape.height=height; collision.shape=shape; support.add_child(collision)
	_add_box(Vector3(point.x,habitat_base_y-.08,point.z),Vector3(.78,.16,.78),MHStyle.SEAL_DARK,true,"habitat_support")
	_add_box(Vector3(point.x,ground+.08,point.z),Vector3(.62,.16,.62),MHStyle.SEAL_DARK.darkened(.3),true,"habitat_support")

func _remove_at(cell: Vector2i) -> void:
	for index in range(zones.size()-1,-1,-1):
		if cell in zones[index].cells:
			var refund:=int(zones[index].cost)
			zones.remove_at(index)
			if zones.is_empty(): habitat_base_y=.35
			_rebuild()
			_flash_notice("valid","Removed","+%s cargo returned." % MHStyle.kg(refund))
			return

func _undo() -> void:
	if zones.is_empty(): return
	var zone:Dictionary=zones.pop_back()
	if zones.is_empty(): habitat_base_y=.35
	_rebuild()
	_flash_notice("info","Undone","%s removed · +%s cargo returned." % [ZONE_TYPES[zone.kind].label,MHStyle.kg(int(zone.cost))])

func _zone_cost(cells: Array) -> int: return int(ZONE_TYPES[kind].cost)*cells.size()
func _used_cargo() -> int:
	var total:=0
	for zone in zones: total+=int(zone.cost)
	return total

func _airlock_connected_cells() -> Dictionary:
	var reachable:Dictionary={}; var pending:Array=[]
	for zone in zones:
		if str(zone.kind)=="airlock":
			for cell in zone.cells: reachable[cell]=true; pending.append(cell)
	while not pending.is_empty():
		var cell:Vector2i=pending.pop_front()
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next_cell: Vector2i=cell+side
			if _occupied(next_cell) and not reachable.has(next_cell): reachable[next_cell]=true; pending.append(next_cell)
	return reachable

func _update_budget() -> void:
	if cargo_meter==null: return
	var remaining:=CARGO_BUDGET-_used_cargo()
	cargo_meter.value=remaining
	cargo_meter.tone="accent" if remaining>CARGO_BUDGET*.1 else "warn"

func _update_summary() -> void:
	if ready_badge_slot==null: return
	for child in ready_badge_slot.get_children(): child.queue_free()
	var total:=readiness().size()
	var met:=readiness_met()
	ready_badge_slot.add_child(MHStyle.badge("%d / %d ready" % [met,total],"valid" if met==total else "warn",true))

func _systems() -> Dictionary:
	var counts:Dictionary={}
	for id in ZONE_TYPES: counts[id]=0
	for zone in zones:
		counts[str(zone.kind)]+=zone.cells.size()
	# Each grid cell is only 3m × 3m.  Accommodation includes bunks, lockers,
	# circulation and privacy, so roughly three cells support two crew members.
	# A 3×3 Living Quarters therefore supports six crew; a 2×2 supports three.
	var crew_capacity:int=ceili(float(counts.living)*2.0/3.0)
	var crew:int=mini(CREW_TARGET,crew_capacity)
	var food:int=counts.hydroponics*5
	var life_support:int=counts.life_support*4
	var research:int=counts.science*4
	var generation:=0.0
	for zone in zones:
		if str(zone.kind)=="solar": generation+=SOLAR_OUTPUT*_solar_efficiency(_airlock_side(zone))
	var draw:int=counts.living+counts.storage+counts.corridor+counts.airlock*2+counts.glass_room*2+counts.hydroponics*5+counts.life_support*3+counts.science*5+counts.vehicle_bay*4
	return {"crew":crew,"crew_capacity":crew_capacity,"food":food,"life":life_support,"research":research,"generation":roundi(generation),"draw":draw}

func _solar_efficiency(direction: Vector2i) -> float:
	# The level's sun is treated as a fixed teaching-friendly direction.  Facing
	# it produces full output; a side-on panel is useful but less effective.
	var sunlight:=Vector2i(0,-1)
	var alignment:=direction.x*sunlight.x+direction.y*sunlight.y
	if alignment>0: return 1.0
	if alignment==0: return .55
	return .15

func _update_systems() -> void:
	_refresh_catalogue()

# ---------- readiness (Mission Control, explore HUD) ----------
# Simple aggregate checks for the target crew; game-balance estimates only.
func readiness() -> Array:
	var systems:=_systems()
	var habitat_cells:=0; var airlock_cells:=0; var reachable:=0
	var route:=_airlock_connected_cells()
	for zone in zones:
		if str(zone.kind)=="solar": continue
		habitat_cells+=zone.cells.size()
		if str(zone.kind)=="airlock": airlock_cells+=zone.cells.size()
		for cell in zone.cells:
			if route.has(cell): reachable+=1
	var shelter_status:="unmet"; var shelter_detail:="No airlock"
	if airlock_cells>0 and habitat_cells>airlock_cells:
		shelter_status="met" if reachable==habitat_cells else "partial"
		shelter_detail="Connected" if reachable==habitat_cells else "%d / %d cells" % [reachable,habitat_cells]
	elif airlock_cells>0: shelter_status="partial"; shelter_detail="No rooms yet"
	var items:Array=[{"id":"shelter","label":"Shelter + airlock","detail":shelter_detail,"status":shelter_status,"icon":"door-closed"}]
	items.append(_target_item("beds","Crew quarters",int(systems.crew_capacity),"bed-double","%d / %d berths"))
	items.append(_target_item("food","Food",int(systems.food),"wheat","%d / %d crew"))
	items.append(_target_item("life","Air + water",int(systems.life),"wind","%d / %d crew"))
	var generation:=int(systems.generation); var draw:=int(systems.draw)
	var power_status:="unmet"
	if generation>0 and generation>=draw: power_status="met"
	elif generation>0: power_status="partial"
	items.append({"id":"power","label":"Power","detail":"%d / %d units" % [generation,draw],"status":power_status,"icon":"zap"})
	return items

func _target_item(id: String,item_label: String,value: int,icon_name: String,detail_format: String) -> Dictionary:
	var status:="met" if value>=CREW_TARGET else ("partial" if value>0 else "unmet")
	return {"id":id,"label":item_label,"detail":detail_format % [value,CREW_TARGET],"status":status,"icon":icon_name}

func readiness_met() -> int:
	var met:=0
	for item in readiness():
		if item.status=="met": met+=1
	return met

func suggestion() -> String:
	var left:=MHStyle.kg(CARGO_BUDGET-_used_cargo())
	for item in readiness():
		if item.status=="met": continue
		match str(item.id):
			"shelter":
				if item.status=="unmet": return "Add an Airlock beside a room. Its inner end must touch the room and its outer end must face Mars. You have %s left." % left
				return "Some rooms aren't connected to an airlock. Join them with a Corridor. You have %s left." % left
			"beds": return "Add Living Quarters — every three cells house two crew. You have %s left." % left
			"food": return "Add Hydroponics — each cell grows food for five crew. You have %s left." % left
			"life": return "Add Life Support — each cell supports four crew. You have %s left." % left
			"power": return "Add Solar Arrays within 12 m of the habitat. Aim them north (R) for full output. You have %s left." % left
	return "Every system is ready for a crew of %d. Spend spare cargo on science or storage — %s left." % [CREW_TARGET,left]

func cargo_by_category() -> Dictionary:
	var out:={"rooms":0,"structure":0,"power":0}
	for zone in zones: out[str(ZONE_INFO[zone.kind].cat)]+=int(zone.cost)
	return out

func used_cargo() -> int: return _used_cargo()

# True when a world point is on the deck of a habitat zone (drives the interior hum).
func is_inside(point: Vector3) -> bool:
	if point.y<habitat_base_y-.6 or point.y>habitat_base_y+4.0: return false
	var cell:=Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
	for zone in zones:
		if str(zone.kind)!="solar" and cell in zone.cells: return true
	return false

# ---------- camera + grid ----------
func _camera() -> void:
	pivot=Node3D.new(); world.add_child(pivot); camera=Camera3D.new(); camera.rotation_degrees=Vector3(-50,0,0); camera.fov=55; pivot.add_child(camera); _zoom()
func _zoom() -> void: camera.position=Vector3(0,.77,.64).normalized()*zoom
func _rotate_airlock() -> void: airlock_direction=Vector2i(-airlock_direction.y,airlock_direction.x); MHAudio.sfx("rotate")
func _direction_yaw(direction: Vector2i) -> float:
	if direction==Vector2i(0,-1): return 0.0
	if direction==Vector2i(1,0): return PI*.5
	if direction==Vector2i(0,1): return PI
	return -PI*.5

func _grid() -> void:
	# Blueprint grid: 1 m minor lines and brighter 3 m cell lines in cell-line
	# blue, added on top of the terrain and fading out around the camera target.
	var immediate:=ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for n in range(-LIMIT,LIMIT):
		var at:=float(n)+.5
		var major:=posmod(n-1,int(CELL))==0
		var colour:=Color(MHStyle.CELL_LINE,.55) if major else Color(MHStyle.CELL_LINE,.16)
		for points in [[Vector3(at,.09,-LIMIT),Vector3(at,.09,LIMIT)],[Vector3(-LIMIT,.09,at),Vector3(LIMIT,.09,at)]]:
			immediate.surface_set_color(colour); immediate.surface_add_vertex(points[0])
			immediate.surface_set_color(colour); immediate.surface_add_vertex(points[1])
	immediate.surface_end()
	var shader:=Shader.new(); shader.code=GRID_SHADER
	var material:=ShaderMaterial.new(); material.shader=shader
	grid=MeshInstance3D.new(); grid.mesh=immediate; grid.material_override=material; grid.visible=false; grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(grid)
	# Dark blueprint wash under the lines so the cyan grid reads against bright terrain.
	var wash:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(LIMIT*2.0,LIMIT*2.0); wash.mesh=plane; wash.position.y=-.02; wash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wash_shader:=Shader.new(); wash_shader.code=GRID_WASH_SHADER; var wash_material:=ShaderMaterial.new(); wash_material.shader=wash_shader; wash.material_override=wash_material; wash.name="BlueprintWash"; grid.add_child(wash)

# ---------- build HUD (shots 1e / 1f) ----------
func _ui() -> void:
	hud_layer=CanvasLayer.new(); hud_layer.name="BuildHUD"; hud_layer.layer=5; add_child(hud_layer)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.theme=MHStyle.theme(); ui.visible=false; hud_layer.add_child(ui)
	ui.add_child(MHStyle.hint_strip([[["LMB"],"Place · drag","accent"],[["R"],"Rotate"],[["RMB"],"Cancel"],[["X"],"Remove"],[["Q","E"],"Orbit"],[["Wheel"],"Zoom"],[["Tab"],"Catalogue"],[["M"],"Mission Control"],[["B"],"Explore"]]))
	# Top-left: colony + cargo
	var left:=MHStyle.vbox(12); left.position=Vector2(32,32); left.size=Vector2(440,0); left.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(left)
	left.add_child(MHStyle.colony_chip(MHGame.site_name()))
	var cargo_panel:=MHStyle.hud_panel(20); cargo_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; left.add_child(cargo_panel)
	var cargo_box:=MHStyle.vbox(12); cargo_panel.add_child(cargo_box)
	cargo_meter=MHWidgets.Meter.new().setup("Cargo remaining",CARGO_BUDGET,CARGO_BUDGET,"kg","accent",true); cargo_box.add_child(cargo_meter)
	var placing_row:=MHStyle.hbox(8); cargo_box.add_child(placing_row)
	placing_label=MHStyle.mono("",14,MHStyle.TEXT_MUTED); placing_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; placing_label.clip_text=true; placing_row.add_child(placing_label)
	placing_delta=MHStyle.mono("",14,MHStyle.accent,600); placing_row.add_child(placing_delta)
	notice_column=MHStyle.vbox(12); notice_column.position=Vector2(32,0); notice_column.mouse_filter=Control.MOUSE_FILTER_IGNORE; left.add_child(notice_column)
	# Top-centre: Build / Explore switch over the free viewport
	var top_band:=CenterContainer.new(); top_band.anchor_right=1; top_band.offset_right=-472; top_band.offset_top=32; top_band.offset_bottom=88; top_band.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(top_band)
	var switch_panel:=PanelContainer.new(); switch_panel.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.SURFACE_HUD,MHStyle.BORDER_SUBTLE,MHStyle.RADIUS_MD,1,Vector4(4,4,12,4))); top_band.add_child(switch_panel)
	var switch_row:=MHStyle.hbox(4); switch_panel.add_child(switch_row)
	var build_tab:=MHStyle.button("Build","primary","hammer",48); build_tab.focus_mode=Control.FOCUS_NONE; build_tab.mouse_default_cursor_shape=Control.CURSOR_ARROW; switch_row.add_child(build_tab)
	var explore_tab:=MHStyle.button("Explore","ghost","footprints",48); explore_tab.focus_mode=Control.FOCUS_NONE; explore_tab.pressed.connect(_toggle); switch_row.add_child(explore_tab)
	var b_key:=MHStyle.keycap("B"); b_key.size_flags_vertical=Control.SIZE_SHRINK_CENTER; switch_row.add_child(b_key)
	# Top-right: readiness + Mission Control
	var top_right:=MHStyle.hbox(12); top_right.anchor_left=1; top_right.anchor_right=1; top_right.offset_left=-620; top_right.offset_right=-32; top_right.offset_top=32; top_right.offset_bottom=84; top_right.alignment=BoxContainer.ALIGNMENT_END; top_right.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(top_right)
	ready_badge_slot=CenterContainer.new(); ready_badge_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE; top_right.add_child(ready_badge_slot)
	var mc:=MHStyle.button("Mission Control","secondary","clipboard-check"); mc.focus_mode=Control.FOCUS_NONE; mc.pressed.connect(func() -> void: mission_control_requested.emit()); top_right.add_child(mc)
	_build_catalogue()
	_build_tool_bar()
	hologram_pill=Control.new(); hologram_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE; hologram_pill.visible=false; ui.add_child(hologram_pill)
	_update_budget(); _update_summary(); _select_kind(kind)

func _build_catalogue() -> void:
	catalogue=PanelContainer.new(); catalogue.add_theme_stylebox_override("panel",MHStyle.hud_box(0,true))
	catalogue.anchor_left=1; catalogue.anchor_right=1; catalogue.anchor_bottom=1; catalogue.offset_left=-472; catalogue.offset_right=-32; catalogue.offset_top=116; catalogue.offset_bottom=-96
	catalogue.mouse_filter=Control.MOUSE_FILTER_STOP; MHStyle.add_rail(catalogue,24); ui.add_child(catalogue)
	var column:=MHStyle.vbox(0); catalogue.add_child(column)
	var head:=MarginContainer.new(); for side in ["left","right"]: head.add_theme_constant_override("margin_"+side,24)
	head.add_theme_constant_override("margin_top",22); head.add_theme_constant_override("margin_bottom",12); column.add_child(head)
	var head_row:=MHStyle.hbox(8); head.add_child(head_row)
	head_row.add_child(MHStyle.title("Catalogue",26)); head_row.add_child(MHStyle.spacer())
	var count:=MHStyle.eyebrow("%d zones" % ZONE_TYPES.size()); count.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head_row.add_child(count)
	var tabs:=MHStyle.hbox(0); var tabs_margin:=MarginContainer.new(); tabs_margin.add_theme_constant_override("margin_left",16); tabs_margin.add_theme_constant_override("margin_right",16); tabs_margin.add_child(tabs); column.add_child(tabs_margin)
	for entry in CATEGORIES:
		var tab:=Button.new(); tab.text=str(entry[1]).to_upper(); tab.icon=MHIcons.texture(entry[2],18); tab.custom_minimum_size.y=44; tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tab.focus_mode=Control.FOCUS_NONE
		tab.add_theme_font_override("font",MHStyle.font(700,false,1)); tab.add_theme_font_size_override("font_size",14); tab.add_theme_constant_override("icon_max_width",18); tab.add_theme_constant_override("h_separation",8); tab.alignment=HORIZONTAL_ALIGNMENT_LEFT
		tab.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		tab.pressed.connect(func() -> void: category=str(entry[0]); _refresh_catalogue())
		tabs.add_child(tab); category_buttons[entry[0]]=tab
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	var grid_margin:=MarginContainer.new(); grid_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: grid_margin.add_theme_constant_override("margin_"+side,16)
	scroll.add_child(grid_margin)
	catalogue_grid=GridContainer.new(); catalogue_grid.columns=2; catalogue_grid.add_theme_constant_override("h_separation",12); catalogue_grid.add_theme_constant_override("v_separation",12); grid_margin.add_child(catalogue_grid)
	var detail_panel:=PanelContainer.new(); var detail_style:=MHStyle.box(MHStyle.INK_950,Color(0,0,0,0),0,0,Vector4(24,20,24,22)); detail_style.border_width_top=1; detail_style.border_color=MHStyle.BORDER_SUBTLE; detail_style.corner_radius_bottom_left=MHStyle.RADIUS_MD; detail_style.corner_radius_bottom_right=MHStyle.RADIUS_MD
	detail_panel.add_theme_stylebox_override("panel",detail_style); column.add_child(detail_panel)
	catalogue_detail=MHStyle.vbox(10); detail_panel.add_child(catalogue_detail)
	# Collapsed rail (Tab)
	catalogue_rail=PanelContainer.new(); catalogue_rail.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.SURFACE_HUD_STRONG,MHStyle.BORDER_SUBTLE,MHStyle.RADIUS_MD,1,Vector4(12,12,12,12)))
	catalogue_rail.anchor_left=1; catalogue_rail.anchor_right=1; catalogue_rail.anchor_bottom=1; catalogue_rail.offset_left=-104; catalogue_rail.offset_right=-32; catalogue_rail.offset_top=116; catalogue_rail.offset_bottom=-96; catalogue_rail.visible=false; ui.add_child(catalogue_rail)
	var rail_col:=MHStyle.vbox(8); catalogue_rail.add_child(rail_col)
	for entry in CATEGORIES:
		var b:=Button.new(); b.icon=MHIcons.texture(entry[2],22); b.tooltip_text=str(entry[1]); b.custom_minimum_size=Vector2(48,48); b.theme_type_variation="GhostButton"; b.focus_mode=Control.FOCUS_NONE; b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func() -> void: category=str(entry[0]); _set_catalogue_open(true)); rail_col.add_child(b)
	var grow:=Control.new(); grow.size_flags_vertical=Control.SIZE_EXPAND_FILL; rail_col.add_child(grow)
	var tab_key:=MHStyle.keycap("Tab",true); tab_key.size_flags_horizontal=Control.SIZE_SHRINK_CENTER; rail_col.add_child(tab_key)
	var open_label:=MHStyle.eyebrow("Open",MHStyle.TEXT_MUTED,11); open_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; rail_col.add_child(open_label)

func _set_catalogue_open(open: bool) -> void:
	catalogue.visible=open; catalogue_rail.visible=not open
	if open: _refresh_catalogue()

func _select_kind(id: String) -> void:
	kind=id; dragging=false; category=str(ZONE_INFO[id].cat); _set_tool("place"); _preview_key=""
	_refresh_catalogue()

func _refresh_catalogue() -> void:
	if catalogue_grid==null: return
	for id in category_buttons:
		var tab:Button=category_buttons[id]; var active:bool=id==category
		var style:=MHStyle.box(Color(0,0,0,0),Color(0,0,0,0),0,0,Vector4(12,0,8,0)); style.border_width_bottom=2 if active else 1; style.border_color=MHStyle.accent if active else MHStyle.BORDER_SUBTLE
		for state in ["normal","hover","pressed","hover_pressed","focus"]: tab.add_theme_stylebox_override(state,style)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]: tab.add_theme_color_override(state,MHStyle.TEXT_PRIMARY if active else MHStyle.TEXT_SECONDARY)
	for child in catalogue_grid.get_children(): child.queue_free()
	var remaining:=CARGO_BUDGET-_used_cargo()
	for id in ZONE_TYPES:
		if str(ZONE_INFO[id].cat)!=category: continue
		catalogue_grid.add_child(_part_card(id,id==kind,remaining<CELL_COST))
	for child in catalogue_detail.get_children(): child.queue_free()
	var info:Dictionary=ZONE_INFO[kind]
	var head:=MHStyle.hbox(8); catalogue_detail.add_child(head)
	head.add_child(MHStyle.title(str(ZONE_TYPES[kind].label),20)); head.add_child(MHStyle.spacer())
	var cost:=MHStyle.mono("%s / cell" % MHStyle.kg(int(ZONE_TYPES[kind].cost)),14,MHStyle.accent,600); cost.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head.add_child(cost)
	catalogue_detail.add_child(MHStyle.body(str(info.desc),16))
	var badges:=MHStyle.hbox(8); catalogue_detail.add_child(badges)
	badges.add_child(MHStyle.badge(str(info.rule),"info"))
	if kind in ["airlock","vehicle_bay","solar"]: badges.add_child(MHStyle.badge("Facing: %s" % _facing_name(),"neutral"))

func _facing_name() -> String:
	return {Vector2i(0,-1):"North",Vector2i(1,0):"East",Vector2i(0,1):"South",Vector2i(-1,0):"West"}.get(airlock_direction,"North")

func _part_card(id: String,selected: bool,unaffordable: bool) -> Button:
	var card:=Button.new(); card.custom_minimum_size=Vector2(196,172); card.focus_mode=Control.FOCUS_NONE; card.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var normal:=MHStyle.selected_box(0) if selected else MHStyle.control_box(0)
	for state in ["normal","pressed","hover_pressed","focus"]: card.add_theme_stylebox_override(state,normal)
	card.add_theme_stylebox_override("hover",normal if selected else MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER,MHStyle.BORDER_STRONG))
	card.pressed.connect(_select_kind.bind(id))
	var colour:Color=ZONE_TYPES[id].colour
	var column:=MHStyle.vbox(0); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; card.add_child(column)
	# Thumbnail: the zone's plan colour on blueprint ink, with its catalogue icon.
	var thumb:=PanelContainer.new(); var thumb_style:=MHStyle.box(MHStyle.BLUEPRINT.lerp(colour,.28),Color(0,0,0,0),MHStyle.RADIUS_MD,0); thumb_style.corner_radius_bottom_left=0; thumb_style.corner_radius_bottom_right=0
	thumb.add_theme_stylebox_override("panel",thumb_style); thumb.custom_minimum_size.y=92; thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(thumb)
	thumb.add_child(MHStyle.icon(str(ZONE_INFO[id].icon),40,colour.lightened(.45)))
	var text:=MarginContainer.new(); text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side in ["left","right"]: text.add_theme_constant_override("margin_"+side,12)
	text.add_theme_constant_override("margin_top",10); column.add_child(text)
	var lines:=MHStyle.vbox(4); text.add_child(lines)
	var name_label:=MHStyle.label(str(ZONE_TYPES[id].label),16,MHStyle.TEXT_PRIMARY,600); name_label.clip_text=true; lines.add_child(name_label)
	var mass_colour:=MHStyle.DANGER if unaffordable else (MHStyle.accent if selected else MHStyle.TEXT_SECONDARY)
	lines.add_child(MHStyle.mono("%s / cell" % MHStyle.kg(int(ZONE_TYPES[id].cost)),12,mass_colour,600))
	var rule:=MHStyle.mono(str(ZONE_INFO[id].rule),12,MHStyle.TEXT_MUTED); rule.clip_text=true; lines.add_child(rule)
	return card

func _build_tool_bar() -> void:
	var band:=CenterContainer.new(); band.anchor_top=1; band.anchor_bottom=1; band.anchor_right=1; band.offset_right=-472; band.offset_top=-176; band.offset_bottom=-80; band.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(band)
	var bar:=PanelContainer.new(); bar.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.SURFACE_HUD,MHStyle.BORDER_SUBTLE,MHStyle.RADIUS_MD,1,Vector4(8,8,8,8))); band.add_child(bar)
	var row:=MHStyle.hbox(8); bar.add_child(row)
	for entry in [["place","box","Place","LMB"],["rotate","rotate-cw","Rotate","R"],["remove","trash-2","Remove","X"],["undo","undo-2","Undo","Ctrl Z"]]:
		var item:=MHStyle.vbox(6); item.alignment=BoxContainer.ALIGNMENT_CENTER; row.add_child(item)
		var b:=Button.new(); b.icon=MHIcons.texture(entry[1],22); b.tooltip_text=str(entry[2]); b.custom_minimum_size=Vector2(52,48); b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER; b.focus_mode=Control.FOCUS_NONE; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		b.theme_type_variation="GhostButton"; item.add_child(b)
		var cap:=MHStyle.keycap(str(entry[3]),true); cap.size_flags_horizontal=Control.SIZE_SHRINK_CENTER; item.add_child(cap)
		match str(entry[0]):
			"place": b.pressed.connect(_set_tool.bind("place"))
			"rotate": b.pressed.connect(func() -> void: _rotate_airlock(); _refresh_catalogue())
			"remove": b.pressed.connect(func() -> void: _set_tool("place" if tool=="remove" else "remove"))
			"undo": b.pressed.connect(_undo)
		tool_buttons[entry[0]]=b
	_set_tool(tool)

func _set_tool(next_tool: String) -> void:
	tool=next_tool; dragging=false
	for id in tool_buttons:
		var active:bool=id==tool
		var b:Button=tool_buttons[id]
		b.theme_type_variation="SelectedButton" if active else "GhostButton"
		if id=="remove" and active: b.theme_type_variation="DangerButton"

func _update_hologram_ui(cells: Array,reason: String) -> void:
	if hologram_pill==null: return
	var message:=""; var state:=""
	if tool=="remove":
		state="remove"; message="Click a zone to remove it · full refund"
		placing_label.text="Remove tool"; placing_delta.text=""
	elif _pointer_over_ui():
		placing_label.text="Placing %s" % ZONE_TYPES[kind].label; placing_delta.text=""
	else:
		var cost:=_zone_cost(cells)
		var after:=CARGO_BUDGET-_used_cargo()-cost
		placing_label.text="Placing %s" % ZONE_TYPES[kind].label
		placing_delta.text="−%s → %s" % [MHStyle.kg(cost),MHStyle.kg(after)] if not cells.is_empty() else ""
		placing_delta.add_theme_color_override("font_color",MHStyle.DANGER if after<0 else (MHStyle.WARN if after<CARGO_BUDGET*.1 else MHStyle.accent))
		if not reason.is_empty(): state="invalid"; message=reason
		elif not cells.is_empty():
			var bounds:=_cell_bounds(cells)
			state="valid"; message="%d %s · %d × %d m" % [cells.size(),"cell" if cells.size()==1 else "cells",bounds.size.x*int(CELL),bounds.size.y*int(CELL)]
	var key:=state+message
	if key!=_last_reason:
		_last_reason=key
		for child in hologram_pill.get_children(): child.queue_free()
		if not state.is_empty(): hologram_pill.add_child(MHStyle.hologram_status(state,message))
	hologram_pill.visible=build_mode and not state.is_empty()
	if hologram_pill.visible:
		var mouse:=ui.get_local_mouse_position()
		var pill_width:=(hologram_pill.get_child(0) as Control).size.x if hologram_pill.get_child_count()>0 else 360.0
		var right_edge:=ui.size.x-(504.0 if catalogue.visible else 136.0)
		hologram_pill.position=Vector2(clampf(mouse.x+22,24,maxf(24.0,right_edge-pill_width)),clampf(mouse.y-64,24,ui.size.y))

func _flash_notice(tone: String,heading: String,text: String) -> void:
	if notice_column==null: return
	# Each notice tone has its own sound; "valid" notices are removals.
	var sound:String={"invalid":"invalid","warn":"warn","valid":"remove","info":"undo"}.get(tone,"")
	if not sound.is_empty(): MHAudio.sfx(sound)
	while notice_column.get_child_count()>=2: var oldest:=notice_column.get_child(0); notice_column.remove_child(oldest); oldest.queue_free()
	var item:=MHStyle.notice(tone,heading,text); notice_column.add_child(item)
	var fade:=item.create_tween(); fade.tween_interval(3.2); fade.tween_property(item,"modulate:a",0.0,.3); fade.tween_callback(item.queue_free)
