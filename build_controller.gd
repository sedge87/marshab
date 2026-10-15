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

var kind := "living"
var airlock_direction := Vector2i(0,-1)
var zones: Array = []
var dragging := false
var drag_start := Vector2i.ZERO
var hover := Vector2i.ZERO
var build_mode := false
var root: Node3D
var preview: Node3D
var pivot: Node3D
var camera: Camera3D
var grid: MeshInstance3D
var zoom := 54.0
var habitat_base_y := 0.35
var ui: PanelContainer
var budget_label: Label
var summary_panel: PanelContainer
var summary_label: Label
var systems_panel: PanelContainer
var crew_meter: Dictionary = {}
var food_meter: Dictionary = {}
var life_meter: Dictionary = {}
var berth_label: Label
var research_label: Label
var power_label: Label
var status_label: Label
@onready var world := get_parent()

func _ready() -> void:
	root=Node3D.new(); root.name="StudentHabitat"; world.add_child(root)
	preview=Node3D.new(); preview.name="ZonePreview"; world.add_child(preview)
	_camera(); _grid(); _ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B: _toggle()
		elif build_mode and event.keycode==KEY_R and (kind=="airlock" or kind=="vehicle_bay" or kind=="solar"): _rotate_airlock()
		elif build_mode and event.keycode==KEY_ESCAPE: dragging=false; _draw_preview([],false)
		elif build_mode and event.keycode==KEY_DELETE: _remove_at(hover)
	if not build_mode or not event is InputEventMouseButton: return
	if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=maxf(20.0,zoom-4.0); _zoom()
	elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(90.0,zoom+4.0); _zoom()
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: dragging=true; drag_start=hover
		elif dragging:
			dragging=false
			var cells := _cells(drag_start,hover)
			if _valid(cells):
				if zones.is_empty(): habitat_base_y=_proposed_base_y(cells)
				zones.append({"kind":kind,"cells":cells,"door_direction":airlock_direction,"cost":_zone_cost(cells)})
				_rebuild()
			_draw_preview([],false)

func _process(delta: float) -> void:
	if not build_mode: return
	hover=_cell_at_mouse()
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
	_draw_preview(_cells(drag_start if dragging else hover,hover),_valid(_cells(drag_start if dragging else hover,hover)))

func _toggle() -> void:
	build_mode=!build_mode; ui.visible=build_mode; summary_panel.visible=build_mode; grid.visible=build_mode; camera.current=build_mode
	world.get_node("Player/Head/Camera3D").current=!build_mode
	var explore_hud:=world.get_node_or_null("ExploreHUD") as CanvasLayer
	if explore_hud!=null: explore_hud.visible=not build_mode
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
	if cells.is_empty() or _used_cargo()+_zone_cost(cells)>CARGO_BUDGET: return false
	for cell in cells:
		if abs(cell.x)>LIMIT/CELL or abs(cell.y)>LIMIT/CELL or _occupied(cell): return false
	if kind=="airlock" and not _valid_airlock(cells): return false
	if kind=="vehicle_bay" and not _valid_vehicle_bay(cells): return false
	if kind=="solar" and not _valid_solar(cells): return false
	# Build on a local, reasonably flat patch. A short foundation can bridge a
	# shallow dip, but we reject hills and deep drops instead of making towers.
	if is_inside_tree() and not zones.is_empty():
		for cell in cells:
			var terrain:=_cell_highest_terrain(cell)
			if terrain>habitat_base_y-.18 or terrain<habitat_base_y-1.55: return false
	return true

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
	for child in preview.get_children(): child.queue_free()
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.1,1,.3,.38) if valid else Color(1,.08,.08,.32); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for cell in cells:
		var tile:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(CELL,.08,CELL); tile.mesh=mesh; tile.material_override=material; tile.position=Vector3(cell.x*CELL,.12,cell.y*CELL); preview.add_child(tile)
	if kind=="airlock" and not cells.is_empty(): _airlock_arrow(_airlock_end(cells,airlock_direction,true),"OUTSIDE")
	if kind=="vehicle_bay" and not cells.is_empty(): _airlock_arrow(_face_preview_cell(cells,airlock_direction),"HANGAR")
	if kind=="solar" and not cells.is_empty(): _airlock_arrow(cells[0],"SOLAR %d%%" % roundi(_solar_efficiency(airlock_direction)*100.0))

func _airlock_arrow(cell: Vector2i,label_text := "OUTSIDE") -> void:
	var arrow:=MeshInstance3D.new(); var mesh:=ImmediateMesh.new(); var material:=StandardMaterial3D.new()
	material.albedo_color=Color(1,.38,.05,.95); material.emission_enabled=true; material.emission=Color(1,.16,.01); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material); mesh.surface_add_vertex(Vector3(0,.22,-1.20)); mesh.surface_add_vertex(Vector3(-.65,.22,-.35)); mesh.surface_add_vertex(Vector3(.65,.22,-.35)); mesh.surface_end()
	arrow.mesh=mesh; arrow.position=Vector3(cell.x*CELL,0,cell.y*CELL); arrow.rotation.y=_direction_yaw(airlock_direction); preview.add_child(arrow)
	var label:=Label3D.new(); label.text=label_text; label.font_size=52; label.outline_size=8; label.modulate=Color(1,.5,.12); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.position=arrow.position+Vector3(airlock_direction.x,.65,airlock_direction.y)*1.2; preview.add_child(label)

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
	grid.position.y=habitat_base_y+.09
	for zone in zones: _add_zone_label(zone)
	_set_build_view(build_mode); _update_budget(); _update_summary(); _update_systems()

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
		else: _add_box(centre+Vector3(0,habitat_base_y+2.9,0),Vector3(size_x,.15,size_z),Color(.64,.68,.69),true,"habitat_roof",show_generated_surface)
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
			else: _add_box(local_centre+Vector3(0,habitat_base_y+2.9,0),Vector3(CELL,.15,CELL),Color(.64,.68,.69),true,"habitat_roof")

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
	_add_box(position+Vector3(0,.08,0),Vector3(1.75,.16,1.45),Color(.12,.16,.18),true,"solar_base",true)
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
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.08,.34,.48); material.emission_enabled=true; material.emission=Color(.015,.10,.18); material.roughness=.35; cable.material_override=material
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
	_add_box(wall_position,wall_size,Color(.83,.85,.84),true,"habitat_wall",not corridor_side)

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
	var label:=Label3D.new(); label.text=str(ZONE_TYPES[zone.kind].label).to_upper()+"\n%d CELLS • %d kg" % [cells.size(),int(zone.cost)]; label.position=centre+Vector3(0,habitat_base_y+.35,0); label.font_size=48; label.outline_size=8; label.modulate=ZONE_TYPES[zone.kind].colour; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.visible=build_mode; label.add_to_group("zone_label"); root.add_child(label)

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
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.13,.16,.17); material.metallic=.65; material.roughness=.35; visual.material_override=material; support.add_child(visual)
	var collision:=CollisionShape3D.new(); var shape:=CylinderShape3D.new(); shape.radius=.30; shape.height=height; collision.shape=shape; support.add_child(collision)
	_add_box(Vector3(point.x,habitat_base_y-.08,point.z),Vector3(.78,.16,.78),Color(.25,.29,.30),true,"habitat_support")
	_add_box(Vector3(point.x,ground+.08,point.z),Vector3(.62,.16,.62),Color(.10,.12,.13),true,"habitat_support")

func _remove_at(cell: Vector2i) -> void:
	for index in range(zones.size()-1,-1,-1):
		if cell in zones[index].cells:
			zones.remove_at(index)
			if zones.is_empty(): habitat_base_y=.35
			_rebuild()
			return

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
	if budget_label!=null: budget_label.text="Cargo: %d / %d kg" % [_used_cargo(),CARGO_BUDGET]
func _update_summary() -> void:
	if summary_label==null: return
	if zones.is_empty(): summary_label.text="HABITAT STATUS\nNo rooms planned\nAdd an airlock beside a room."; return
	var total_cells:=0
	for zone in zones: total_cells+=zone.cells.size()
	summary_label.text="HABITAT STATUS\n%d cells • %d kg\nAirlock route: %d / %d cells" % [total_cells,_used_cargo(),_airlock_connected_cells().size(),total_cells]

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

func _set_meter(meter: Dictionary,title: String,value: int,maximum: int) -> void:
	if meter.is_empty(): return
	meter.label.text="%s  %d / %d" % [title,value,maximum]
	meter.bar.max_value=maxi(1,maximum)
	meter.bar.value=clampi(value,0,maximum)

func _update_systems() -> void:
	if systems_panel==null: return
	var systems:=_systems()
	# The bar answers "can the planned crew live here?"; excess room is useful
	# information, but it must not look like eighteen people are currently aboard.
	_set_meter(crew_meter,"CREW READY",int(systems.crew),CREW_TARGET)
	berth_label.text="BERTH CAPACITY: %d" % int(systems.crew_capacity)
	_set_meter(food_meter,"FOOD",int(systems.food),int(systems.crew))
	_set_meter(life_meter,"LIFE SUPPORT",int(systems.life),int(systems.crew))
	research_label.text="RESEARCH CAPABILITY: %d" % int(systems.research)
	power_label.text="POWER: %d GEN / %d USE" % [int(systems.generation),int(systems.draw)]
	power_label.modulate=Color(.42,1.0,.64) if int(systems.generation)>=int(systems.draw) else Color(1.0,.40,.18)
	var warnings:Array[String]=[]
	if int(systems.crew_capacity)<CREW_TARGET: warnings.append("Need crew quarters")
	if int(systems.food)<int(systems.crew): warnings.append("Food shortfall")
	if int(systems.life)<int(systems.crew): warnings.append("Life support shortfall")
	if int(systems.generation)<int(systems.draw): warnings.append("Power deficit")
	status_label.text="HABITAT VIABLE" if warnings.is_empty() and int(systems.crew)>0 else " • ".join(warnings)
	status_label.modulate=Color(.38,1.0,.58) if warnings.is_empty() and int(systems.crew)>0 else Color(1.0,.58,.22)

func _camera() -> void:
	pivot=Node3D.new(); world.add_child(pivot); camera=Camera3D.new(); camera.rotation_degrees=Vector3(-50,0,0); camera.fov=55; pivot.add_child(camera); _zoom()
func _zoom() -> void: camera.position=Vector3(0,.77,.64).normalized()*zoom
func _rotate_airlock() -> void: airlock_direction=Vector2i(-airlock_direction.y,airlock_direction.x)
func _direction_yaw(direction: Vector2i) -> float:
	if direction==Vector2i(0,-1): return 0.0
	if direction==Vector2i(1,0): return PI*.5
	if direction==Vector2i(0,1): return PI
	return -PI*.5

func _grid() -> void:
	var immediate:=ImmediateMesh.new(); var material:=StandardMaterial3D.new(); material.albedo_color=Color(.95,.56,.25,.5); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate.surface_begin(Mesh.PRIMITIVE_LINES,material)
	for line in range(-20,21):
		immediate.surface_add_vertex(Vector3(line*CELL,.09,-LIMIT)); immediate.surface_add_vertex(Vector3(line*CELL,.09,LIMIT)); immediate.surface_add_vertex(Vector3(-LIMIT,.09,line*CELL)); immediate.surface_add_vertex(Vector3(LIMIT,.09,line*CELL))
	immediate.surface_end(); grid=MeshInstance3D.new(); grid.mesh=immediate; grid.visible=false; world.add_child(grid)

func _ui() -> void:
	var layer:=CanvasLayer.new(); add_child(layer)
	ui=PanelContainer.new(); ui.position=Vector2(14,14); ui.size=Vector2(270,242); ui.visible=false; ui.add_theme_stylebox_override("panel",_overlay_style()); layer.add_child(ui)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",5); ui.add_child(box)
	var title:=Label.new(); title.text="BUILD MODE"; title.add_theme_font_size_override("font_size",18); box.add_child(title)
	budget_label=Label.new(); budget_label.add_theme_font_size_override("font_size",15); box.add_child(budget_label); _update_budget()
	var picker:=OptionButton.new(); picker.tooltip_text="Choose a zone type, then click or drag cells"; box.add_child(picker)
	var zone_ids:=["living","science","storage","hydroponics","life_support","corridor","airlock","vehicle_bay","solar","glass_room"]
	for id in zone_ids: picker.add_item(str(ZONE_TYPES[id].label))
	picker.item_selected.connect(func(index:int): kind=str(zone_ids[index]); dragging=false)
	var help:=Label.new(); help.text="Drag rooms • 50 kg/cell • green = valid\nAirlocks: 1–3 cells straight; Vehicle Bays: 2–4 cells\nSolar Arrays: outside, within cable range\nR rotates outside/hangar/solar face • WASD pan\nWheel zoom • Q/E orbit • B explore"; help.add_theme_font_size_override("font_size",13); box.add_child(help)
	summary_panel=PanelContainer.new(); summary_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT); summary_panel.offset_left=-258; summary_panel.offset_top=14; summary_panel.offset_right=-14; summary_panel.offset_bottom=102; summary_panel.visible=false; summary_panel.add_theme_stylebox_override("panel",_overlay_style()); layer.add_child(summary_panel)
	summary_label=Label.new(); summary_label.add_theme_font_size_override("font_size",15); summary_panel.add_child(summary_label); _update_summary()
	_systems_ui(layer)
	_update_systems()

func _systems_ui(layer: CanvasLayer) -> void:
	systems_panel=PanelContainer.new()
	systems_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	systems_panel.offset_left=-274; systems_panel.offset_top=-236; systems_panel.offset_right=-14; systems_panel.offset_bottom=-14
	systems_panel.add_theme_stylebox_override("panel",_overlay_style())
	layer.add_child(systems_panel)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",5); systems_panel.add_child(box)
	var title:=Label.new(); title.text="HABITAT SYSTEMS"; title.add_theme_font_size_override("font_size",16); box.add_child(title)
	crew_meter=_meter(box,Color(.24,.72,1.0))
	berth_label=Label.new(); berth_label.add_theme_font_size_override("font_size",11); berth_label.modulate=Color(.68,.76,.82); box.add_child(berth_label)
	food_meter=_meter(box,Color(.37,.95,.22))
	life_meter=_meter(box,Color(.18,.85,.83))
	research_label=Label.new(); research_label.add_theme_font_size_override("font_size",13); research_label.modulate=Color(.72,.48,1.0); box.add_child(research_label)
	power_label=Label.new(); power_label.add_theme_font_size_override("font_size",16); power_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(power_label)
	status_label=Label.new(); status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status_label.add_theme_font_size_override("font_size",12); status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(status_label)

func _meter(parent: Control,colour: Color) -> Dictionary:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",12); parent.add_child(label)
	var bar:=ProgressBar.new(); bar.show_percentage=false; bar.custom_minimum_size=Vector2(236,10)
	var background:=StyleBoxFlat.new(); background.bg_color=Color(.035,.045,.055,.9); background.border_color=Color(.34,.37,.40); background.set_border_width_all(1); background.set_corner_radius_all(2)
	var fill:=StyleBoxFlat.new(); fill.bg_color=colour; fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",background); bar.add_theme_stylebox_override("fill",fill); parent.add_child(bar)
	return {"label":label,"bar":bar}

func _overlay_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=Color(.035,.045,.055,.82); style.border_color=Color(.55,.29,.13,.75); style.set_border_width_all(1); style.set_corner_radius_all(6); style.content_margin_left=12; style.content_margin_right=12; style.content_margin_top=9; style.content_margin_bottom=9; return style
