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
const SOLAR_POWER_RADIUS := 30.0
const REACTOR_POWER_RADIUS := 42.0
const SOLAR_OUTPUT := 24
const REACTOR_OUTPUT := 360
const CREW_TARGET := 6
const RESEARCH_TARGET := 6
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
	"reactor":{"label":"Compact Reactor","colour":Color(.88,.30,.16),"cost":1200},
	"ice_extractor":{"label":"Ice Extractor","colour":Color(.20,.82,.92),"cost":450},
	"glass_room":{"label":"Glass Greenhouse","colour":Color(.22,.78,.82),"cost":CELL_COST}
}

# Catalogue metadata for the build HUD. Gameplay values stay in ZONE_TYPES.
const ZONE_INFO := {
	"living":{"cat":"rooms","icon":"bed-double","rule":"Drag an area","desc":"Makes space for bunks, lockers and personal areas. Furnish it to house crew."},
	"science":{"cat":"rooms","icon":"flask-conical","rule":"Drag an area","desc":"Makes space for benches and instruments. Furnish it to conduct research."},
	"storage":{"cat":"rooms","icon":"package","rule":"Drag an area","desc":"Racks for spares, tools and supplies."},
	"hydroponics":{"cat":"rooms","icon":"sprout","rule":"Drag an area","desc":"Makes space for grow equipment. Furnish it to produce food."},
	"life_support":{"cat":"rooms","icon":"wind","rule":"Drag an area","desc":"Makes space for air and water recyclers. Furnish it to support crew."},
	"glass_room":{"cat":"rooms","icon":"flower-2","rule":"Drag an area","desc":"A glazed room with a view of Mars. Uses extra power."},
	"corridor":{"cat":"structure","icon":"move-vertical","rule":"Straight runs · R rotates","desc":"Joins rooms together. A one-cell corridor opens along its selected axis."},
	"airlock":{"cat":"structure","icon":"door-closed","rule":"1–3 cells · R rotates","desc":"The way in and out. The outer end faces Mars; the inner end must touch a room."},
	"vehicle_bay":{"cat":"structure","icon":"truck","rule":"2–4 cells · R rotates","desc":"A hangar for rovers. Its wide door must face outside."},
	"solar":{"cat":"power","icon":"sun","rule":"One cell · R aims","desc":"A 30 m power field. Facing north gives full output."},
	"reactor":{"cat":"power","icon":"atom","rule":"One cell · 1,200 kg","desc":"A compact fission reactor. 42 m power field; high output and high cargo cost."},
	"ice_extractor":{"cat":"power","icon":"drill","rule":"One cell · 450 kg","desc":"Drills into buried ice. Choose it to survey blue ice-rich ground."}
}
# Exterior construction deliberately excludes furnishing. Interior equipment is
# selected only through the first-person construction controller.
const CATEGORIES := [["rooms","Rooms","bed-double"],["structure","Structure","box"],["power","Resources","sun"],["surface","Surface gear","package"]]
const SURFACE_EQUIPMENT := {
	"cargo_crate_small": {"label":"Small Cargo Crate", "icon":"package", "asset":"res://assets/surface_equipment_phase12/cargo_crate_small.glb", "radius":.65},
	"cargo_crate_large": {"label":"Large Cargo Crate", "icon":"package", "asset":"res://assets/surface_equipment_phase12/cargo_crate_large.glb", "radius":1.1},
	"equipment_pallet": {"label":"Equipment Pallet", "icon":"package", "asset":"res://assets/surface_equipment_phase12/equipment_pallet.glb", "radius":1.15},
	"comms_antenna": {"label":"Comms Antenna", "icon":"satellite", "asset":"res://assets/surface_equipment_phase12/comms_antenna.glb", "radius":.8},
	"exterior_workbench": {"label":"Field Workbench", "icon":"wrench", "asset":"res://assets/surface_equipment_phase12/exterior_workbench.glb", "radius":1.0},
	"high_light_post": {"label":"High Light Post", "icon":"lightbulb", "asset":"res://assets/surface_equipment_phase12/high_light_post.glb", "radius":.45},
	"path_beacon": {"label":"Path Beacon", "icon":"map-pin", "asset":"res://assets/surface_equipment_phase12/path_beacon.glb", "radius":.35},
	"portable_work_light": {"label":"Portable Work Light", "icon":"lightbulb", "asset":"res://assets/surface_equipment_phase12/portable_work_light.glb", "radius":.45},
	"safety_barrier": {"label":"Safety Barrier", "icon":"shield", "asset":"res://assets/surface_equipment_phase12/safety_barrier.glb", "radius":1.0},
	"solar_floodlight": {"label":"Solar Floodlight", "icon":"sun", "asset":"res://assets/surface_equipment_phase12/solar_floodlight.glb", "radius":.55},
}
const HALF_CELL := 1.5
const ROOM_HEIGHT := 2.9
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
signal interior_build_requested
signal surface_build_requested(id: String)

var kind := "living"
var airlock_direction := Vector2i(0,-1)
var zones: Array = []
# First-person furnishing controllers own their visual instances. This lightweight
# record is the simulation state used by the resource and wellbeing systems.
var placed_equipment: Array = []
# Free-positioned first-person furnishings are intentionally separate from the
# legacy top-down, cell-keyed equipment records.  They share the catalogue's
# effects and cargo cost, but do not participate in exterior grid snapping.
var placed_interior: Array = []
# Free ground props are deliberately separate from grid zones and interior
# furnishings. They carry no resource effects until a gameplay design is added.
var placed_surface: Array = []
# Selected interior item; empty while a zone is selected.
var equipment_id := ""
# Greybox stand-ins for placed equipment, keyed by cell, until final art lands.
var furnishing: Node3D
var surface_furnishing: Node3D
var _equipment_visuals := {}
# Undo order across zones and equipment: {"type":"zone","zone":…} / {"type":"equipment","id":…,"cell":…}.
var _history: Array = []
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
var player_marker: Node3D
var player_marker_label: Label3D
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
var equipment_list: VBoxContainer
var catalogue_count: Label
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

func _site_build_limit() -> float:
	# Most regions retain the standard 120 m-wide construction area. Individual
	# maps can offer a different surveyed landing field without changing cell size.
	return float(MHGame.site().get("build_limit", LIMIT))

func _ready() -> void:
	root=Node3D.new(); root.name="StudentHabitat"; world.add_child(root)
	preview=Node3D.new(); preview.name="ZonePreview"; world.add_child(preview)
	furnishing=Node3D.new(); furnishing.name="HabitatEquipment"; world.add_child(furnishing)
	surface_furnishing=Node3D.new(); surface_furnishing.name="SurfaceEquipment"; world.add_child(surface_furnishing)
	if display_only: return
	_camera(); _grid(); _ui(); _create_player_marker()

func _unhandled_input(event: InputEvent) -> void:
	if display_only: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B:
			var active_player := world.get_node_or_null("Player") as Node
			if active_player != null and bool(active_player.get_meta("interior_build_active", false)):
				return
			var player := world.get_node_or_null("Player") as Node3D
			if active_player != null and bool(active_player.get_meta("surface_build_active", false)):
				return
			if not build_mode and player != null and is_inside(player.global_position):
				interior_build_requested.emit()
			else:
				_toggle()
		elif build_mode and event.keycode==KEY_R and (not equipment_id.is_empty() or kind=="airlock" or kind=="vehicle_bay" or kind=="solar" or kind=="corridor"): _rotate_airlock(); _refresh_catalogue()
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
		if not equipment_id.is_empty():
			if event.pressed and not _pointer_over_ui(): _place_selected_equipment(hover)
			return
		if event.pressed: dragging=true; drag_start=hover
		elif dragging:
			dragging=false
			var cells := _cells(drag_start,hover)
			var reason := _invalid_reason(cells)
			if reason.is_empty():
				if zones.is_empty(): habitat_base_y=_proposed_base_y(cells)
				var zone := {"kind":kind,"cells":cells,"door_direction":airlock_direction,"cost":_zone_cost(cells)}
				zones.append(zone); _history.append({"type":"zone","zone":zone})
				_rebuild()
				MHAudio.sfx("place")
				var left := CARGO_BUDGET-_used_cargo()
				if left<CARGO_BUDGET*.1: _flash_notice("warn","Cargo is getting tight","%s left — about %d more cells." % [MHStyle.kg(left),left/CELL_COST])
			elif not _pointer_over_ui():
				_flash_notice("invalid","Can't place here",reason+".")
			_draw_preview([],false)

func _process(delta: float) -> void:
	if not build_mode: return
	_update_player_marker()
	# Removing and furnishing pick against the deck the player sees, not the ground.
	hover=_cell_at_mouse(habitat_base_y if tool=="remove" or not equipment_id.is_empty() else 0.0)
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
		var site_limit := _site_build_limit()
		pivot.position.x=clampf(pivot.position.x,-site_limit,site_limit); pivot.position.z=clampf(pivot.position.z,-site_limit,site_limit)
	_update_player_marker()
	if tool=="remove" or _pointer_over_ui():
		_draw_preview([],false); _update_hologram_ui([],"")
		return
	if not equipment_id.is_empty():
		var equipment_reason:=equipment_invalid_reason(equipment_id,hover)
		_draw_equipment_preview(hover,equipment_reason.is_empty())
		_update_hologram_ui([] if hover.x==999 else [hover],equipment_reason)
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
	if not build_mode: _set_tool("place"); _update_hologram_ui([],""); _preview_key=""; _draw_preview([],false)
	_set_build_view(build_mode)
	_update_player_marker()
	var player:=world.get_node("Player"); player.set_meta("build_mode_active",build_mode)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if build_mode else Input.MOUSE_MODE_CAPTURED
	if not build_mode:
		dragging=false; _draw_preview([],false)
		# Leave the player exactly where they were when the plan view was opened.
		# Build mode is a camera/tool mode, not a teleport or respawn.
		player.velocity=Vector3.ZERO

func _create_player_marker() -> void:
	player_marker = Node3D.new()
	player_marker.name = "BuildModePlayerMarker"
	player_marker.visible = false
	world.add_child(player_marker)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .22
	mesh.bottom_radius = .34
	mesh.height = .08
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#FF8A3D")
	material.emission_enabled = true
	material.emission = Color("#FF5C22")
	material.emission_energy_multiplier = 1.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	mesh_instance.position.y = .14
	player_marker.add_child(mesh_instance)
	var arrow := MeshInstance3D.new()
	var arrow_mesh := CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = .16
	arrow_mesh.height = .34
	arrow.mesh = arrow_mesh
	arrow.rotation.x = PI * .5
	arrow.position = Vector3(0, .16, -.28)
	arrow.material_override = material
	player_marker.add_child(arrow)
	player_marker_label = _label3d("PLAYER CELL", 28, Color("#FFE2B4"), 800)
	player_marker_label.position = Vector3(0, .55, 0)
	player_marker.add_child(player_marker_label)

func _update_player_marker() -> void:
	if player_marker == null:
		return
	var player := world.get_node_or_null("Player") as Node3D
	player_marker.visible = build_mode and player != null
	if player != null:
		var cell := Vector2i(roundi(player.global_position.x / CELL), roundi(player.global_position.z / CELL))
		# The planner communicates occupancy at construction-cell resolution. Keep
		# the marker on the blueprint plane instead of following the player's body
		# height over uneven terrain or a raised deck.
		player_marker.global_position = Vector3(cell.x * CELL, habitat_base_y + .13, cell.y * CELL)
		player_marker_label.text = "PLAYER CELL\n(%d, %d)" % [cell.x, cell.y]

# Equipment sits on the raised deck, so it projects onto the floor height
# rather than the ground plane the zone painter uses.
func _cell_at_mouse(plane_y := 0.0) -> Vector2i:
	var origin:=camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction:=camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(direction.y)<.001: return Vector2i(999,999)
	var point:=origin+direction*((plane_y-origin.y)/direction.y)
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
	if kind=="solar" or kind=="reactor" or kind=="ice_extractor": return [b]
	if kind=="corridor" and a.x!=b.x and a.y!=b.y: return out
	for x in range(mini(a.x,b.x),maxi(a.x,b.x)+1):
		for z in range(mini(a.y,b.y),maxi(a.y,b.y)+1): out.append(Vector2i(x,z))
	return out

func _occupied(cell: Vector2i) -> bool:
	for zone in zones:
		if cell in zone.cells: return true
	return false

func _zone_at(cell: Vector2i) -> Dictionary:
	for zone in zones:
		if cell in zone.cells: return zone
	return {}

func _is_habitat_zone(zone: Dictionary) -> bool:
	if zone.is_empty(): return false
	var zone_kind := str(zone.kind)
	# Power sources sit outside the pressure hull.  They must not erase an
	# exterior wall simply because their build cell touches one.
	return zone_kind != "solar" and zone_kind != "reactor" and zone_kind != "ice_extractor"

## Public placement API (Build-mode inventory, tests and any future first-person
## furnishing).  `visual` is optional so the systems can be tested without art;
## a caller that passes one keeps ownership of it.
func place_equipment(id: String, cell: Vector2i, visual: Node3D = null, facing := Vector2i(0, -1)) -> bool:
	if not equipment_invalid_reason(id, cell).is_empty():
		return false
	placed_equipment.append({"id": id, "cell": cell, "facing": facing})
	if visual != null:
		visual.set_meta("equipment_id", id)
	_update_budget()
	_update_systems()
	_apply_grid_power()
	habitat_changed.emit()
	return true

## First-person interior construction records exact metres rather than cells.
## Only the interior controller calls this API; the exterior planner remains
## grid based.  `zone_cell` keeps room restrictions and safe pruning explicit.
func place_free_interior_equipment(id: String, position: Vector3, rotation_y: float, zone_cell: Vector2i, visual: Node3D, anchor_normal := Vector3.UP) -> bool:
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty() or _used_cargo() + int(entry.get("cargo_cost", 0)) > CARGO_BUDGET:
		return false
	var placement_id := "interior_%d" % Time.get_ticks_usec()
	placed_interior.append({"placement_id": placement_id, "id": id, "position": position, "rotation_y": rotation_y, "zone_cell": zone_cell, "anchor_normal": anchor_normal})
	visual.name = "Interior_%s" % placement_id
	visual.set_meta("equipment_id", id)
	visual.set_meta("interior_placement_id", placement_id)
	furnishing.add_child(visual)
	_update_budget()
	_update_systems()
	_apply_grid_power()
	habitat_changed.emit()
	return true

func remove_free_interior_equipment(placement_id: String) -> Dictionary:
	for index in range(placed_interior.size() - 1, -1, -1):
		var item: Dictionary = placed_interior[index]
		if str(item.get("placement_id", "")) != placement_id:
			continue
		placed_interior.remove_at(index)
		for child in furnishing.get_children():
			if str(child.get_meta("interior_placement_id", "")) == placement_id:
				child.queue_free()
				break
		_update_budget()
		_update_systems()
		_apply_grid_power()
		habitat_changed.emit()
		return item
	return {}

func free_interior_invalid_reason(id: String, world_position: Vector3, surface_normal: Vector3, rotation_y := 0.0) -> String:
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty(): return "Unknown interior item"
	var sample := world_position + Vector3.UP * .35
	if not is_inside(sample): return "Must be placed inside a completed habitat room"
	var zone := _zone_at(Vector2i(roundi(world_position.x / CELL), roundi(world_position.z / CELL)))
	var valid_zones: Array = entry.get("valid_zones", [])
	if not valid_zones.has(str(zone.get("kind", ""))): return "Fits in %s" % _zone_list_text(valid_zones)
	var placement := str(entry.get("placement", "floor"))
	if placement == "floor" and surface_normal.dot(Vector3.UP) < .82: return "Place this on the floor"
	if placement == "wall" and absf(surface_normal.dot(Vector3.UP)) > .28: return "Mount this on an interior wall"
	if placement == "ceiling" and surface_normal.dot(Vector3.UP) > -.82: return "Mount this on the ceiling"
	if _used_cargo() + int(entry.get("cargo_cost", 0)) > CARGO_BUDGET: return "Not enough cargo left"
	# A free-positioned item must fit wholly inside valid room cells. Checking the
	# four footprint corners prevents a player from burying it in the shell wall
	# or bleeding it across into an incompatible room.
	if placement == "floor" or placement == "floor_wall":
		var size := _equipment_size(entry)
		var footprint := Vector2(size.x * .5, size.z * .5)
		var facing := Vector2(cos(rotation_y), sin(rotation_y))
		var side := Vector2(-facing.y, facing.x)
		for sign_x in [-1.0, 1.0]:
			for sign_z in [-1.0, 1.0]:
				var corner: Vector2 = Vector2(world_position.x, world_position.z) + facing * footprint.x * sign_x + side * footprint.y * sign_z
				var corner_cell := Vector2i(roundi(corner.x / CELL), roundi(corner.y / CELL))
				var corner_zone := _zone_at(corner_cell)
				if corner_zone.is_empty() or not valid_zones.has(str(corner_zone.get("kind", ""))):
					return "Doesn't fit inside this room"
		var candidate_radius := maxf(size.x, size.z) * .5
		for item in placed_interior:
			var other_entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
			var other_size := _equipment_size(other_entry)
			var other_position: Vector3 = item.get("position", Vector3.ZERO)
			if Vector2(world_position.x - other_position.x, world_position.z - other_position.z).length() < candidate_radius + maxf(other_size.x, other_size.z) * .38:
				return "Too close to existing equipment"
	return ""

func free_interior_visual(id: String, position: Vector3, rotation_y: float) -> Node3D:
	var entry := EquipmentCatalog.get_entry(id)
	var size := _equipment_size(entry)
	var holder := Node3D.new()
	holder.position = position
	holder.rotation.y = rotation_y
	var body := StaticBody3D.new()
	body.name = "InteriorCollision"
	body.position = Vector3(0, size.y * .5, 0)
	body.collision_layer = 1
	holder.add_child(body)
	var model_loaded := false
	var model_has_collision := false
	var asset_path := str(entry.get("asset_scene", ""))
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		var resource := load(asset_path)
		if resource is PackedScene:
			var model := (resource as PackedScene).instantiate() as Node3D
			if model != null:
				model.name = "Model"
				holder.add_child(model)
				if model.has_method("interaction_prompt"):
					body.set_meta("interaction_target", model)
				model_loaded = true
				model_has_collision = not model.find_children("*", "CollisionShape3D", true, false).is_empty()
	if not bool(entry.get("walkthrough", false)) and size.y > .15 and not model_has_collision:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = size
		collision.shape = shape
		body.add_child(collision)
	if not model_loaded:
		var tint: Color = (ZONE_TYPES.get(str((entry.get("valid_zones", ["storage"]) as Array)[0]), ZONE_TYPES.storage).colour as Color)
		_add_equipment_placeholder(body, size, tint)
	if int(EquipmentCatalog.effects(id).get("power_draw", 0)) > 0 and (not model_loaded or not _bind_equipment_power_visuals(holder)):
		_add_equipment_power_lamp(body, size)
	return holder

## Empty when `id` can be placed in `cell`; otherwise a short hologram reason.
func equipment_invalid_reason(id: String, cell: Vector2i) -> String:
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty(): return "Unknown equipment"
	var zone := _zone_at(cell)
	if not _is_habitat_zone(zone): return "Point at a room"
	var valid_zones: Array = entry.get("valid_zones", [])
	if not valid_zones.has(str(zone.kind)): return "Fits in %s" % _zone_list_text(valid_zones)
	if not equipment_at(cell).is_empty(): return "This cell is already furnished"
	if _used_cargo() + int(entry.get("cargo_cost", 0)) > CARGO_BUDGET: return "Not enough cargo left"
	return ""

func equipment_at(cell: Vector2i) -> Dictionary:
	for item in placed_equipment:
		if item.get("cell", Vector2i(9999, 9999)) == cell:
			return item
	return {}

func remove_equipment_at(cell: Vector2i) -> Dictionary:
	for index in range(placed_equipment.size() - 1, -1, -1):
		var item: Dictionary = placed_equipment[index]
		if item.get("cell", Vector2i(9999, 9999)) == cell:
			placed_equipment.remove_at(index)
			if _equipment_visuals.has(cell):
				(_equipment_visuals[cell] as Node).queue_free()
				_equipment_visuals.erase(cell)
			_update_budget()
			_update_systems()
			_apply_grid_power()
			habitat_changed.emit()
			return item
	return {}

func _zone_list_text(zone_kinds: Array) -> String:
	var names: Array = []
	for zone_kind in zone_kinds: names.append(str(ZONE_TYPES.get(zone_kind, {}).get("label", zone_kind)))
	if names.size() <= 1: return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " or " + str(names[-1])

func _place_selected_equipment(cell: Vector2i) -> void:
	var reason := equipment_invalid_reason(equipment_id, cell)
	if not reason.is_empty():
		_flash_notice("invalid", "Can't place here", reason + ".")
		return
	var visual := _equipment_visual(equipment_id, cell, airlock_direction)
	if not place_equipment(equipment_id, cell, visual, airlock_direction):
		visual.queue_free()
		return
	furnishing.add_child(visual)
	_equipment_visuals[cell] = visual
	_apply_grid_power() # The new status lamp joins the grid bus only once it is in the tree.
	_history.append({"type": "equipment", "id": equipment_id, "cell": cell})
	_preview_key = ""
	MHAudio.sfx("place")
	var left := CARGO_BUDGET - _used_cargo()
	if left < CARGO_BUDGET * .1: _flash_notice("warn", "Cargo is getting tight", "%s left." % MHStyle.kg(left))

# Equipment whose room was removed goes with it, so its cargo is refunded too.
func _prune_equipment() -> int:
	var refund := 0
	for index in range(placed_equipment.size() - 1, -1, -1):
		var item: Dictionary = placed_equipment[index]
		var cell: Vector2i = item.get("cell", Vector2i(9999, 9999))
		var zone := _zone_at(cell)
		var valid_zones: Array = EquipmentCatalog.get_entry(str(item.get("id", ""))).get("valid_zones", [])
		if zone.is_empty() or not valid_zones.has(str(zone.kind)):
			refund += int(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("cargo_cost", 0))
			placed_equipment.remove_at(index)
			if _equipment_visuals.has(cell):
				(_equipment_visuals[cell] as Node).queue_free()
				_equipment_visuals.erase(cell)
	for index in range(placed_interior.size() - 1, -1, -1):
		var item: Dictionary = placed_interior[index]
		var cell: Vector2i = item.get("zone_cell", Vector2i(9999, 9999))
		var zone := _zone_at(cell)
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		var valid_zones: Array = entry.get("valid_zones", [])
		var wall_lost := false
		if str(entry.get("placement", "floor")) == "wall" and item.has("anchor_normal"):
			# A wall mount remains valid only while one side is pressurised habitat
			# and the far side is outside. Adding a room across that wall removes the
			# attachment surface, so remove and refund the mounted asset.
			var anchor: Vector3 = item.get("anchor_normal", Vector3.ZERO) as Vector3
			var point: Vector3 = item.get("position", Vector3.ZERO) as Vector3
			wall_lost = not is_inside(point + anchor * .18) or is_inside(point - anchor * .18)
		if zone.is_empty() or not valid_zones.has(str(zone.kind)) or wall_lost:
			refund += int(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("cargo_cost", 0))
			remove_free_interior_equipment(str(item.get("placement_id", "")))
	return refund

# Footprint in metres from the catalogue's 1.5 m half-cell footprint.
func _equipment_size(entry: Dictionary) -> Vector3:
	var footprint: Array = entry.get("footprint", [1, 1])
	var placement := str(entry.get("placement", "floor"))
	var width := float(footprint[0]) * HALF_CELL - .2
	var depth := float(footprint[1]) * HALF_CELL - .2
	if placement == "wall": depth = minf(depth, .22)
	return Vector3(width, maxf(.04, float(entry.get("height", 1.0))), depth)

# Local transform inside a cell: floor items centre, wall items back onto the
# far side of the cell from their facing, ceiling items hang from the roof.
func _equipment_offset(entry: Dictionary, size: Vector3) -> Vector3:
	var placement := str(entry.get("placement", "floor"))
	var y := 0.0
	match placement:
		"wall": y = float(entry.get("mount_height", 1.0))
		"ceiling": y = ROOM_HEIGHT - .15 - size.y
	var back := 0.0
	if placement == "wall" or placement == "floor_wall": back = CELL * .5 - size.z * .5 - .12
	return Vector3(0, y, back)

func _equipment_visual(id: String, cell: Vector2i, facing: Vector2i) -> Node3D:
	# The catalogue remains authoritative for placement, collision and game effects.
	# Verified GLB art is presentation-only; the original sized proxy is retained as
	# an explicit fallback when an external asset is unavailable or fails to instantiate.
	var entry := EquipmentCatalog.get_entry(id)
	var size := _equipment_size(entry)
	var offset := _equipment_offset(entry, size)
	var holder := Node3D.new()
	holder.name = "Equipment_%s" % id
	holder.position = Vector3(cell.x * CELL, habitat_base_y, cell.y * CELL)
	holder.rotation.y = _direction_yaw(facing)
	holder.set_meta("equipment_id", id)
	var tint: Color = (ZONE_TYPES.get(str((entry.get("valid_zones", ["storage"]) as Array)[0]), ZONE_TYPES.storage).colour as Color)
	var body := StaticBody3D.new()
	body.position = offset + Vector3(0, size.y * .5, 0)
	body.collision_layer = 1
	holder.add_child(body)
	var model_loaded := false
	var model_has_collision := false
	var asset_path := str(entry.get("asset_scene", ""))
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		var resource := load(asset_path)
		if resource is PackedScene:
			var model := (resource as PackedScene).instantiate() as Node3D
			if model != null:
				model.name = "Model"
				model.position = offset
				holder.add_child(model)
				if model.has_method("interaction_prompt"):
					body.set_meta("interaction_target", model)
				model_loaded = true
				model_has_collision = not model.find_children("*", "CollisionShape3D", true, false).is_empty()
	if not bool(entry.get("walkthrough", false)) and size.y > .15 and not model_has_collision:
		var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)
	if not model_loaded:
		_add_equipment_placeholder(body, size, tint)
	# Generated model indicator meshes remain linked to the existing grid bus.
	# If a model has no named status mesh, preserve the legacy visible lamp.
	if int(EquipmentCatalog.effects(id).get("power_draw", 0)) > 0 and (not model_loaded or not _bind_equipment_power_visuals(holder)):
		_add_equipment_power_lamp(body, size)
	return holder

func _add_equipment_placeholder(body: StaticBody3D, size: Vector3, tint: Color) -> void:
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; visual.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = MHStyle.STRUCTURAL_WHITE.lerp(tint, .38).darkened(.12); material.roughness = .62
	visual.material_override = material
	body.add_child(visual)
	# Dark seal band and an orange service marker on the front face (−Z).
	if size.y > .3:
		var band := MeshInstance3D.new(); var band_mesh := BoxMesh.new(); band_mesh.size = Vector3(size.x + .02, minf(.08, size.y * .2), size.z + .02); band.mesh = band_mesh
		var seal := StandardMaterial3D.new(); seal.albedo_color = MHStyle.SEAL_DARK; seal.roughness = .5; band.material_override = seal
		band.position = Vector3(0, -size.y * .5 + band_mesh.size.y * .5, 0); body.add_child(band)
	var marker := MeshInstance3D.new(); var marker_mesh := BoxMesh.new(); marker_mesh.size = Vector3(minf(.3, size.x * .4), minf(.06, size.y * .5), .02); marker.mesh = marker_mesh
	var orange := StandardMaterial3D.new(); orange.albedo_color = MHStyle.SAFETY_ORANGE; marker.material_override = orange
	marker.position = Vector3(-size.x * .5 + marker_mesh.size.x * .5 + .08, size.y * .5 - marker_mesh.size.y - .04, -size.z * .5 - .011); body.add_child(marker)

func _add_equipment_power_lamp(body: StaticBody3D, size: Vector3) -> void:
	var lamp := MeshInstance3D.new(); var lamp_mesh := BoxMesh.new(); lamp_mesh.size = Vector3(.14, minf(.06, size.y * .5), .02); lamp.mesh = lamp_mesh
	var glow := StandardMaterial3D.new(); glow.emission_enabled = true; glow.emission = MHStyle.HOLO_VALID; glow.albedo_color = Color("#F3E4C6"); lamp.material_override = glow
	lamp.add_to_group("grid_powered_light"); lamp.set_meta("grid_emission_on", MHStyle.HOLO_VALID); lamp.set_meta("grid_emission_off", Color("#293034"))
	lamp.position = Vector3(size.x * .5 - .14, size.y * .5 - lamp_mesh.size.y - .04, -size.z * .5 - .011); body.add_child(lamp)

func _bind_equipment_power_visuals(holder: Node) -> bool:
	var bound := false
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not (mesh.name.begins_with("Light_") or mesh.name.begins_with("Screen_") or mesh.name.begins_with("Status_")):
			continue
		var source := mesh.get_active_material(0) as StandardMaterial3D
		var material := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
		material.emission_enabled = true
		if material.emission == Color.BLACK:
			material.emission = MHStyle.HOLO_VALID
		mesh.material_override = material
		mesh.add_to_group("grid_powered_light")
		mesh.set_meta("grid_emission_on", material.emission)
		mesh.set_meta("grid_emission_off", Color("#293034"))
		bound = true
	return bound

func _draw_equipment_preview(cell: Vector2i, valid: bool) -> void:
	var key := "equip|%s|%s|%s|%s" % [equipment_id, cell, valid, airlock_direction]
	if key == _preview_key: return
	_preview_key = key
	for child in preview.get_children(): child.queue_free()
	if cell.x == 999: return
	_ensure_preview_materials()
	var entry := EquipmentCatalog.get_entry(equipment_id)
	var size := _equipment_size(entry)
	var holder := Node3D.new()
	holder.position = Vector3(cell.x * CELL, habitat_base_y, cell.y * CELL)
	holder.rotation.y = _direction_yaw(airlock_direction)
	preview.add_child(holder)
	var tile := MeshInstance3D.new(); var tile_mesh := BoxMesh.new(); tile_mesh.size = Vector3(CELL - .06, .04, CELL - .06); tile.mesh = tile_mesh
	tile.material_override = _preview_valid_material if valid else _preview_invalid_material; tile.position.y = .05; tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; holder.add_child(tile)
	var centre := _equipment_offset(entry, size) + Vector3(0, size.y * .5, 0)
	var ghost := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = size; ghost.mesh = box
	ghost.material_override = _preview_valid_material if valid else _preview_invalid_material; ghost.position = centre; ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; holder.add_child(ghost)
	holder.add_child(_box_edges(centre, size, _line_valid_material if valid else _line_invalid_material))
	# Facing arrow on the floor shows where the front panel will point.
	_airlock_arrow(cell, str(entry.get("label", equipment_id)).to_upper())

func _equipment_effects() -> Dictionary:
	var totals := {"berths": 0, "food": 0, "life": 0, "research": 0, "happiness": 0, "storage": 0, "power_draw": 0, "water_draw": 0}
	for item in placed_equipment:
		var effects := EquipmentCatalog.effects(str(item.get("id", "")))
		for effect in totals:
			totals[effect] += int(effects.get(effect, 0))
	for item in placed_interior:
		var effects := EquipmentCatalog.effects(str(item.get("id", "")))
		for effect in totals:
			totals[effect] += int(effects.get(effect, 0))
	return totals

func _is_habitat_cell(cell: Vector2i) -> bool:
	return _is_habitat_zone(_zone_at(cell))

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
		var site_limit := _site_build_limit()
		if abs(cell.x)>site_limit/CELL or abs(cell.y)>site_limit/CELL: return "Outside the surveyed build area"
	for cell in cells:
		if _occupied(cell): return "Overlaps existing habitat"
	var player := world.get_node_or_null("Player") as Node3D
	if player != null:
		var player_cell := Vector2i(roundi(player.global_position.x / CELL), roundi(player.global_position.z / CELL))
		for cell in cells:
			if cell == player_cell:
				return "Move clear of the player before building"
	if kind=="airlock" and not _valid_airlock(cells): return "Inner end must touch a room; outer end faces Mars"
	if kind=="vehicle_bay" and not _valid_vehicle_bay(cells): return "2–4 cells each way, door facing outside, beside a room"
	if (kind=="solar" or kind=="reactor") and not _valid_power_source(cells): return "Power field must reach the habitat"
	if kind=="ice_extractor" and _ice_richness_at(cells[0])<.12: return "No recoverable subsurface ice here"
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
	return not _occupied(outside_cell+airlock_direction) and _is_habitat_cell(inner_cell-airlock_direction)

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
			if side!=airlock_direction and _is_habitat_cell(cell+side): connected=true
	return connected

func _power_radius(source_kind: String) -> float:
	return REACTOR_POWER_RADIUS if source_kind == "reactor" else SOLAR_POWER_RADIUS

func _valid_power_source(cells: Array) -> bool:
	if cells.size()!=1 or zones.is_empty(): return false
	return _power_source_connected({"kind": kind, "cells": cells})

func _power_source_connected(source: Dictionary) -> bool:
	var cells: Array = source.get("cells", [])
	if cells.is_empty(): return false
	var cell: Vector2i = cells[0]
	var radius := _power_radius(str(source.get("kind", "solar")))
	# A StarCraft-style field reaches the shell directly—no visible cable and no
	# requirement to place hardware immediately beside a wall.
	for zone in zones:
		if str(zone.kind)=="solar" or str(zone.kind)=="reactor" or str(zone.kind)=="ice_extractor": continue
		for habitat_cell in zone.cells:
			if Vector2(cell.x-habitat_cell.x,cell.y-habitat_cell.y).length()*CELL<=radius: return true
	return false

func _ice_richness_at(cell: Vector2i) -> float:
	return _ice_richness_at_point(Vector2(cell.x * CELL, cell.y * CELL))

func _ice_richness_at_point(point: Vector2) -> float:
	var strongest := 0.0
	for deposit in MHGame.site().get("ice_deposits", []):
		var centre := Vector2(float(deposit.get("x", 0.0)), float(deposit.get("z", 0.0)))
		var radius := maxf(1.0, float(deposit.get("radius", 1.0)))
		var falloff := clampf(1.0 - point.distance_to(centre) / radius, 0.0, 1.0)
		strongest = maxf(strongest, float(deposit.get("richness", 0.0)) * falloff)
	return strongest

func _ice_yield(cell: Vector2i) -> int:
	# A readable learning-scale output: deposits are not literal kilograms or
	# percentages of ice, but a local prospecting estimate.
	return roundi(_ice_richness_at(cell) * 12.0)

func _draw_preview(cells: Array,valid: bool) -> void:
	# The ghost only changes when the footprint, validity or facing changes.
	var key:="%s|%s|%s|%s" % [str(cells),valid,airlock_direction,kind]
	if key==_preview_key: return
	_preview_key=key
	for child in preview.get_children(): child.queue_free()
	if cells.is_empty(): return
	_ensure_preview_materials()
	if kind=="ice_extractor": _add_ice_heatmap()
	var fill:=_preview_valid_material if valid else _preview_invalid_material
	var edge:=_line_valid_material if valid else _line_invalid_material
	var base_y:=habitat_base_y if not zones.is_empty() else .35
	# Footprint quad on the ground, one per cell so L-shaped drags still read.
	for cell in cells:
		var tile:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(CELL-.06,.04,CELL-.06); tile.mesh=mesh; tile.material_override=fill; tile.position=Vector3(cell.x*CELL,base_y+.05,cell.y*CELL); tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(tile)
	# Hologram volume: translucent shell with bright edges (unlit #3EE58A / #FF4D4D).
	var bounds:=_cell_bounds(cells)
	var height:=2.9 if kind!="solar" and kind!="reactor" and kind!="ice_extractor" else (2.25 if kind=="reactor" else 1.6)
	var volume_size:=Vector3(bounds.size.x*CELL,height,bounds.size.y*CELL)
	var volume_centre:=Vector3((bounds.position.x+bounds.size.x*.5-.5)*CELL,base_y+height*.5,(bounds.position.y+bounds.size.y*.5-.5)*CELL)
	if kind=="solar": volume_size=Vector3(2.4,height,1.6)
	if kind=="reactor": volume_size=Vector3(2.1,height,2.1)
	if kind=="ice_extractor": volume_size=Vector3(1.7,height,1.7)
	var ghost:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=volume_size; ghost.mesh=box; ghost.material_override=fill; ghost.position=volume_centre; ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(ghost)
	preview.add_child(_box_edges(volume_centre,volume_size,edge))
	if kind=="airlock": _airlock_arrow(_airlock_end(cells,airlock_direction,true),"OUTSIDE")
	if kind=="vehicle_bay": _airlock_arrow(_face_preview_cell(cells,airlock_direction),"HANGAR")
	if kind=="corridor" and cells.size()==1: _airlock_arrow(cells[0],"OPEN ENDS")
	if kind=="solar": _airlock_arrow(cells[0],"SOLAR %d%%" % roundi(_solar_efficiency(airlock_direction)*100.0))
	if kind=="ice_extractor":
		var ice_here := _ice_richness_at(cells[0])
		if ice_here < .12:
			_airlock_arrow(cells[0], "NO RECOVERABLE ICE · DRILL UNAVAILABLE")
		else:
			_airlock_arrow(cells[0],"ICE %d%%  ·  WATER %d" % [roundi(ice_here*100.0), _ice_yield(cells[0])])
	if kind=="solar" or kind=="reactor": _add_power_field_visual(cells[0],_power_radius(kind),valid,preview)

func _add_ice_heatmap() -> void:
	# A whole-map survey, not a collection of "drill here" circles. Vertex
	# colours make buried ice read as a continuous, imperfect survey field:
	# dark navy is strong evidence, pale cyan is weak/uncertain evidence.
	var limit := _site_build_limit()
	var step := 3.0
	var divisions := int(limit * 2.0 / step)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_index in range(divisions):
		for x_index in range(divisions):
			var x0 := -limit + x_index * step
			var x1 := x0 + step
			var z0 := -limit + z_index * step
			var z1 := z0 + step
			_add_ice_heatmap_quad(surface, Vector2(x0,z0), Vector2(x1,z0), Vector2(x1,z1))
			_add_ice_heatmap_quad(surface, Vector2(x0,z0), Vector2(x1,z1), Vector2(x0,z1))
	var field := MeshInstance3D.new()
	field.name = "SubsurfaceIceSurvey"
	field.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	field.material_override = material
	field.position.y = habitat_base_y + .07
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(field)

func _add_ice_heatmap_quad(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	for point in [a,b,c]:
		var richness := _ice_richness_at_point(point)
		# A faint non-resource survey background stops the field looking like a
		# handful of perfect circles, without changing extractor yields.
		var uncertainty := (sin(point.x * .071 + point.y * .043) + 1.0) * .018
		var display := clampf(richness + uncertainty, 0.0, 1.0)
		# Four deliberately distinct survey bands: neutral grey = no usable ice,
		# pale cyan = trace, blue = recoverable and deep navy = rich ice.
		var colour: Color
		if display < .04: colour = Color(.08, .11, .15, .20)
		elif display < .12: colour = Color(.36, .86, 1.0, .38)
		elif display < .38: colour = Color(.08, .42, .82, .62)
		else: colour = Color(.015, .04, .24, .88)
		surface.set_color(colour)
		surface.add_vertex(Vector3(point.x, 0.0, point.y))

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
	var attachment_refund := _prune_equipment()
	if attachment_refund > 0:
		_flash_notice("info", "Mounted equipment removed", "+%s cargo returned — its wall changed." % MHStyle.kg(attachment_refund))
	for child in root.get_children(): child.queue_free()
	for zone in zones:
		_zone_surfaces(zone)
		if str(zone.kind)=="airlock": _build_airlock_zone(zone)
		elif str(zone.kind)=="vehicle_bay": _build_vehicle_bay(zone)
		elif str(zone.kind)=="solar": _build_solar(zone)
		elif str(zone.kind)=="reactor": _build_reactor(zone)
		elif str(zone.kind)=="ice_extractor": _build_ice_extractor(zone)
		else:
			for cell in zone.cells: _cell_walls(cell,zone)
	_build_foundation_supports()
	if grid!=null: grid.position.y=habitat_base_y+.09
	for zone in zones: _add_zone_label(zone)
	_set_build_view(build_mode); _update_budget(); _update_summary(); _update_systems(); _apply_grid_power()
	habitat_changed.emit()

func _zone_surfaces(zone: Dictionary) -> void:
	var cells:Array=zone.cells
	var zone_kind:=str(zone.kind)
	if zone_kind=="solar" or zone_kind=="reactor" or zone_kind=="ice_extractor": return
	var colour:Color=ZONE_TYPES[zone_kind].colour
	var min_x: int=cells[0].x; var max_x: int=cells[0].x; var min_z: int=cells[0].y; var max_z: int=cells[0].y
	for cell in cells:
		min_x=mini(min_x,cell.x); max_x=maxi(max_x,cell.x); min_z=mini(min_z,cell.y); max_z=maxi(max_z,cell.y)
	var size_x:=float(max_x-min_x+1)*CELL
	var size_z:=float(max_z-min_z+1)*CELL
	var centre:=Vector3((float(min_x+max_x)*.5)*CELL,0,(float(min_z+max_z)*.5)*CELL)
	# Corridors use the same complete structural floor and roof as rooms.  Their
	# former presentation-only kit left the deck underside and outside walls bare.
	var show_generated_surface := true
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
			_add_corridor_understructure(cells)
	else:
		for cell in cells:
			var local_centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
			_add_box(local_centre+Vector3(0,habitat_base_y-.1,0),Vector3(CELL,.2,CELL),colour.darkened(.48),true,"habitat_floor")
			if zone_kind=="glass_room": _add_glass_box(local_centre+Vector3(0,habitat_base_y+2.9,0),Vector3(CELL,.15,CELL),Color(.36,.86,.92,.35),true,"habitat_roof")
			else: _add_box(local_centre+Vector3(0,habitat_base_y+2.9,0),Vector3(CELL,.15,CELL),MHStyle.STRUCTURAL_WHITE.darkened(.08),true,"habitat_roof")
	_add_zone_lighting(zone)

func _add_corridor_understructure(cells: Array) -> void:
	# A continuous dark service pan beneath the corridor makes the raised deck
	# read as a supported pressurised passage even on the flat landing pad.
	for cell in cells:
		var centre := Vector3(cell.x * CELL, habitat_base_y - .22, cell.y * CELL)
		_add_box(centre, Vector3(CELL - .14, .24, CELL - .14), MHStyle.SEAL_DARK, true, "corridor_understructure")

func _add_zone_lighting(zone: Dictionary) -> void:
	# Fixed ceiling strips are ordinary grid-powered consumers. Equipment placed
	# later can use the same group/meta contract and will switch with this bus.
	var zone_kind := str(zone.kind)
	if zone_kind == "solar":
		return
	var cells: Array = zone.cells
	for index in range(0, cells.size(), 2):
		var cell: Vector2i = cells[index]
		_add_powered_fixture(Vector3(cell.x * CELL, habitat_base_y + 2.62, cell.y * CELL), zone_kind)

func _add_powered_fixture(position: Vector3, zone_kind: String) -> void:
	var fixture := Node3D.new()
	fixture.name = "CeilingLight"
	fixture.position = position
	root.add_child(fixture)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.88, .07, .22)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#F3E4C6")
	material.emission_enabled = true
	material.emission = Color("#FFE7B2")
	material.emission_energy_multiplier = 2.6
	visual.material_override = material
	visual.add_to_group("grid_powered_light")
	visual.set_meta("grid_emission_on", Color("#FFE7B2"))
	visual.set_meta("grid_emission_off", Color("#293034"))
	fixture.add_child(visual)
	var light := OmniLight3D.new()
	light.position = Vector3(0, -.16, 0)
	light.light_color = Color("#FFE7B2")
	light.light_energy = 3.0 if zone_kind != "hydroponics" else 3.8
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.add_to_group("grid_powered_light")
	light.set_meta("grid_light_energy", light.light_energy)
	fixture.add_child(light)

func _cell_walls(cell: Vector2i,zone: Dictionary) -> void:
	var zone_kind:=str(zone.kind); var colour:Color=ZONE_TYPES[zone_kind].colour; var centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
	_add_plan_tile(centre,colour,zone_kind)
	for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		if _should_build_wall(cell,side): _add_exterior_wall(centre,side,zone_kind,zone)

func _should_build_wall(cell: Vector2i,side: Vector2i) -> bool:
	# The airlock owns its inner threshold. This must win regardless of whether
	# the attached room, corridor or the airlock itself was placed first.
	if _is_airlock_inner_doorway(cell,side): return false
	# Only pressurised habitat cells form an open internal connection. External
	# equipment is adjacent to the shell, never part of its floor plan.
	return not _is_habitat_cell(cell+side)

func _is_airlock_inner_doorway(cell: Vector2i,side: Vector2i) -> bool:
	for zone in zones:
		if str(zone.kind)!="airlock": continue
		var outside:=_airlock_side(zone)
		var inner_cell:=_airlock_end(zone.cells,outside,false)
		# Check both directions so it remains correct even if construction order
		# or rendering order changes in the future.
		if cell==inner_cell-outside and side==outside: return true
		if cell==inner_cell and side==-outside: return true
	return false

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
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["solar"].colour,"solar")
	_add_power_field_visual(cell,SOLAR_POWER_RADIUS,_power_source_connected(zone),root)

func _build_reactor(zone: Dictionary) -> void:
	var cell: Vector2i = zone.cells[0]
	var position := Vector3(cell.x * CELL, _terrain_height(Vector3(cell.x * CELL, 0, cell.y * CELL)), cell.y * CELL)
	# Purpose-built low-poly reactor: broad plinth, shielded vessel and a small
	# status cap. It is deliberately compact beside the larger solar arrays.
	_add_box(position + Vector3(0,.12,0),Vector3(2.25,.24,2.25),MHStyle.SEAL_DARK,true,"reactor_base",true)
	var vessel := MeshInstance3D.new()
	var vessel_mesh := CylinderMesh.new()
	vessel_mesh.top_radius = .62; vessel_mesh.bottom_radius = .78; vessel_mesh.height = 1.42
	vessel.mesh = vessel_mesh
	var vessel_material := StandardMaterial3D.new()
	vessel_material.albedo_color = Color("#59666A"); vessel_material.metallic = .72; vessel_material.roughness = .28
	vessel.material_override = vessel_material
	vessel.position = position + Vector3(0,.93,0)
	root.add_child(vessel)
	var core := OmniLight3D.new()
	core.position = position + Vector3(0,1.42,0)
	core.light_color = MHStyle.SAFETY_ORANGE
	core.light_energy = .8
	core.omni_range = 3.0
	core.add_to_group("grid_powered_light")
	core.set_meta("grid_light_energy", .8)
	root.add_child(core)
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["reactor"].colour,"reactor")
	_add_power_field_visual(cell,REACTOR_POWER_RADIUS,_power_source_connected(zone),root)

func _build_ice_extractor(zone: Dictionary) -> void:
	var cell: Vector2i = zone.cells[0]
	var position := Vector3(cell.x * CELL, _terrain_height(Vector3(cell.x * CELL, 0, cell.y * CELL)), cell.y * CELL)
	_add_box(position + Vector3(0,.10,0), Vector3(1.7,.20,1.7), MHStyle.SEAL_DARK, true, "ice_extractor", true)
	var mast := MeshInstance3D.new(); var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius=.13; mast_mesh.bottom_radius=.20; mast_mesh.height=1.35; mast.mesh=mast_mesh
	var steel := StandardMaterial3D.new(); steel.albedo_color=MHStyle.FRAME_STEEL; steel.metallic=.72; steel.roughness=.3; mast.material_override=steel
	mast.position=position+Vector3(0,.78,0); root.add_child(mast)
	var head := MeshInstance3D.new(); var head_mesh := CylinderMesh.new()
	head_mesh.top_radius=.30; head_mesh.bottom_radius=.18; head_mesh.height=.28; head.mesh=head_mesh
	var ice_material := StandardMaterial3D.new(); ice_material.albedo_color=Color(.22,.85,.96); ice_material.emission_enabled=true; ice_material.emission=Color(.05,.35,.46); head.material_override=ice_material
	head.position=position+Vector3(0,1.58,0); root.add_child(head)
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["ice_extractor"].colour,"ice_extractor")

func _add_power_field_visual(cell: Vector2i, radius: float, connected: bool, parent: Node3D) -> void:
	# Visible only in build mode: a light, readable field boundary rather than a
	# physical cable. Existing source fields and the placement preview share it.
	var field := Node3D.new()
	field.name = "PowerField"
	field.position = Vector3(cell.x * CELL, _terrain_height(Vector3(cell.x * CELL, 0, cell.y * CELL)) + .11, cell.y * CELL)
	field.add_to_group("power_field_visual")
	field.visible = build_mode
	var tone := MHStyle.HOLO_VALID if connected else MHStyle.HOLO_INVALID
	var ring_mesh := ImmediateMesh.new()
	var ring_material := _holo_material(tone,.72)
	ring_mesh.surface_begin(Mesh.PRIMITIVE_LINES,ring_material)
	var segments := 72
	for index in range(segments):
		var a0 := TAU * float(index) / segments
		var a1 := TAU * float(index + 1) / segments
		ring_mesh.surface_add_vertex(Vector3(cos(a0) * radius,0,sin(a0) * radius))
		ring_mesh.surface_add_vertex(Vector3(cos(a1) * radius,0,sin(a1) * radius))
	ring_mesh.surface_end()
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(ring)
	var label := _label3d("POWER FIELD · %dm" % roundi(radius),20,tone,600)
	label.position = Vector3(0,.15,-radius)
	field.add_child(label)
	parent.add_child(field)

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
	# The collision box is centred at half wall height, while the Blender wall
	# kit is exported with its base at y=0.  Giving both the same position was
	# lifting the visible panel by 1.45 m above its collision and the roof.
	# Corridors need the same exterior panel bays as rooms.  Skipping them was
	# leaving their long outer faces as untextured backing boxes.
	_add_showcase(SHOWCASE_WALL,Vector3(wall_position.x,habitat_base_y,wall_position.z),_wall_yaw(side))
	# A slightly-overlapping backing closes the tiny seams between independently
	# placed wall bays. It sits behind the kit surface, so panels and windows stay
	# visible while there is never a line of exposed Mars through the hull.
	var backing_size:=wall_size
	if side.x!=0: backing_size.z+=.14
	else: backing_size.x+=.14
	var backing_position:=wall_position-Vector3(side.x*.035,0,side.y*.035)
	_add_box(backing_position,backing_size,MHStyle.STRUCTURAL_WHITE,true,"habitat_wall",true)
	_add_exterior_safety_light(centre, side)

func _add_exterior_safety_light(centre: Vector3, side: Vector2i) -> void:
	# A modest no-shadow flood on every exposed wall bay gives an even perimeter
	# wash. The earlier alternating pattern made light look direction-dependent.
	var fixture := Node3D.new()
	fixture.name = "ExteriorSafetyLight"
	fixture.position = centre + Vector3(side.x * (CELL * .5 + .06), habitat_base_y + 2.36, side.y * (CELL * .5 + .06))
	root.add_child(fixture)
	var lens := MeshInstance3D.new()
	var lens_mesh := BoxMesh.new()
	lens_mesh.size = Vector3(.50, .16, .07) if side.x == 0 else Vector3(.07, .16, .50)
	lens.mesh = lens_mesh
	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color("#F6E6B9")
	lens_material.emission_enabled = true
	lens_material.emission = Color("#FFE7AC")
	lens_material.emission_energy_multiplier = 2.0
	lens.material_override = lens_material
	lens.add_to_group("grid_powered_light")
	lens.set_meta("grid_emission_on", Color("#FFE7AC"))
	lens.set_meta("grid_emission_off", Color("#293034"))
	fixture.add_child(lens)
	var flood := OmniLight3D.new()
	flood.light_color = Color("#FFE2A1")
	flood.light_energy = 2.2
	flood.omni_range = 5.4
	flood.shadow_enabled = false
	flood.add_to_group("grid_powered_light")
	flood.set_meta("grid_light_energy", flood.light_energy)
	fixture.add_child(flood)

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

func _corridor_yaw(zone: Dictionary) -> float:
	# The imported corridor kit opens at its local front/back (north/south when
	# yaw is zero). A one-cell run has no drag axis, so it deliberately uses the
	# selected R-facing stored on the zone; longer runs still infer their axis.
	return PI*.5 if _corridor_axis(zone).x != 0 else 0.0

func _corridor_axis(zone: Dictionary) -> Vector2i:
	var cells: Array = zone.cells
	if cells.size()>1:
		return Vector2i(1,0) if cells[0].x != cells[cells.size()-1].x else Vector2i(0,1)
	var direction: Vector2i = zone.get("door_direction", Vector2i(0,-1))
	return Vector2i(1,0) if direction.x != 0 else Vector2i(0,1)

func _is_corridor_side(zone: Dictionary,side: Vector2i) -> bool:
	# The sides perpendicular to the corridor axis are solid; its two ends are
	# deliberately open, allowing a one-cell corridor to join facing rooms.
	var axis := _corridor_axis(zone)
	return side.x * axis.x + side.y * axis.y == 0

func _corridor_touches_airlock(cells: Array) -> bool:
	for cell in cells:
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if _is_airlock_inner_doorway(cell,side): return true
	return false

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
	for field in get_tree().get_nodes_in_group("power_field_visual"): field.visible=show_plan

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
	# Never use generic "the first thing below this point" here. During a rebuild,
	# equipment may still be registered in physics for a frame; that used to make
	# each subsequent solar array treat the one before it as ground and climb
	# higher. Keep stepping through hits until we reach the named Mars terrain.
	for attempt in range(64):
		var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		var collider:=hit.get("collider") as CollisionObject3D
		if collider!=null and collider.is_in_group("mars_terrain"):
			return float(hit.position.y)
		if collider==null: break
		query.exclude.append(collider.get_rid())
	return -.25

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
	_add_box(Vector3(point.x,habitat_base_y-.17,point.z),Vector3(.78,.12,.78),MHStyle.SEAL_DARK,true,"habitat_support")
	_add_box(Vector3(point.x,ground+.08,point.z),Vector3(.62,.16,.62),MHStyle.SEAL_DARK.darkened(.3),true,"habitat_support")

func _remove_at(cell: Vector2i) -> void:
	# Furniture comes out before the room around it.
	var item:=remove_equipment_at(cell)
	if not item.is_empty():
		var entry:=EquipmentCatalog.get_entry(str(item.id))
		_flash_notice("valid","Removed","%s · +%s cargo returned." % [entry.get("label",item.id),MHStyle.kg(int(entry.get("cargo_cost",0)))])
		return
	for index in range(zones.size()-1,-1,-1):
		if cell in zones[index].cells:
			var refund:=int(zones[index].cost)
			zones.remove_at(index)
			if zones.is_empty(): habitat_base_y=.35
			refund+=_prune_equipment()
			_rebuild()
			_flash_notice("valid","Removed","+%s cargo returned." % MHStyle.kg(refund))
			return

func _undo() -> void:
	# Walk back through placements, skipping any already removed by hand.
	while not _history.is_empty():
		var step:Dictionary=_history.pop_back()
		if step.type=="equipment":
			var item:=equipment_at(step.cell)
			if item.is_empty() or str(item.id)!=str(step.id): continue
			remove_equipment_at(step.cell)
			var entry:=EquipmentCatalog.get_entry(str(step.id))
			_flash_notice("info","Undone","%s removed · +%s cargo returned." % [entry.get("label",step.id),MHStyle.kg(int(entry.get("cargo_cost",0)))])
			return
		var index:=zones.find(step.zone)
		if index<0: continue
		_undo_zone(index)
		return
	if not zones.is_empty(): _undo_zone(zones.size()-1)

func _undo_zone(index: int) -> void:
	var zone:Dictionary=zones[index]
	zones.remove_at(index)
	if zones.is_empty(): habitat_base_y=.35
	var refund:=int(zone.cost)+_prune_equipment()
	_rebuild()
	_flash_notice("info","Undone","%s removed · +%s cargo returned." % [ZONE_TYPES[zone.kind].label,MHStyle.kg(refund)])

func _zone_cost(cells: Array) -> int: return int(ZONE_TYPES[kind].cost)*cells.size()
func _used_cargo() -> int:
	var total:=0
	for zone in zones: total+=int(zone.cost)
	for item in placed_equipment:
		total += int(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("cargo_cost", 0))
	for item in placed_interior:
		total += int(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("cargo_cost", 0))
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
			if _is_habitat_cell(next_cell) and not reachable.has(next_cell): reachable[next_cell]=true; pending.append(next_cell)
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
	var equipment := _equipment_effects()
	# Zones are empty shells: they establish the maximum a player *can* support.
	# Furnishings are what actually provide berths, food and research output.
	# Every three 3×3 m Living cells make room for two crew members.
	var crew_capacity:int=ceili(float(counts.living)*2.0/3.0)
	# The mission starts with six crew, but building room for more people is a
	# commitment: food, water and oxygen requirements grow with that capacity.
	var crew_requirement:int=maxi(CREW_TARGET,crew_capacity)
	var berths:int=mini(crew_capacity,int(equipment.berths))
	var crew:int=mini(crew_requirement,berths)
	var food_capacity:int=counts.hydroponics*5
	var food:int=mini(food_capacity,int(equipment.food))
	var life_capacity:int=counts.life_support*4
	var life_support:int=mini(life_capacity,int(equipment.life))
	var research_capacity:int=counts.science*4
	var research:int=mini(research_capacity,int(equipment.research))
	var generation:=0.0
	for zone in zones:
		if str(zone.kind)=="solar" and _power_source_connected(zone): generation+=SOLAR_OUTPUT*_solar_efficiency(_airlock_side(zone))*MHGame.sunlight_fraction
		elif str(zone.kind)=="reactor" and _power_source_connected(zone): generation+=REACTOR_OUTPUT
	var draw:int=counts.living+counts.storage+counts.corridor+counts.airlock*2+counts.glass_room*2+counts.hydroponics*5+counts.life_support*3+counts.science*5+counts.vehicle_bay*4+counts.ice_extractor*8+int(equipment.power_draw)
	# Dynamic non-catalogue devices can opt into the grid by joining this group
	# and setting power_draw metadata. Catalogue equipment is already counted
	# above, so it must not also join this group.
	for consumer in get_tree().get_nodes_in_group("grid_power_consumer"):
		draw += maxi(0, int(consumer.get_meta("power_draw", 0)))
	# Extracting and melting buried ice takes power. An underpowered base may
	# still show the deposit survey, but its drills do not supply water until the
	# available generation can cover the complete load.
	var water := 0
	if generation > 0.0 and generation >= draw:
		for zone in zones:
			if str(zone.kind)=="ice_extractor": water += _ice_yield(zone.cells[0])
	return {"crew":crew,"crew_requirement":crew_requirement,"crew_capacity":crew_capacity,"berths":berths,"food":food,"food_capacity":food_capacity,"life":life_support,"life_capacity":life_capacity,"water":water,"research":research,"research_capacity":research_capacity,"happiness":int(equipment.happiness),"water_draw":int(equipment.water_draw),"generation":roundi(generation),"draw":draw}

func grid_power_online() -> bool:
	var systems := _systems()
	return int(systems.generation) > 0 and int(systems.generation) >= int(systems.draw)

func refresh_power_grid() -> void:
	# Public hook for future placeable equipment after it joins the power groups.
	_apply_grid_power()

func _apply_grid_power() -> void:
	var online := grid_power_online()
	MHGame.set_habitat_lights_online(online)
	for device in get_tree().get_nodes_in_group("grid_powered_light"):
		if device is Light3D:
			(device as Light3D).light_energy = float(device.get_meta("grid_light_energy", 0.0)) if online else 0.0
		elif device is MeshInstance3D:
			var material := (device as MeshInstance3D).material_override as StandardMaterial3D
			if material == null:
				continue
			material.emission_enabled = online
			material.albedo_color = Color("#F3E4C6") if online else Color("#293034")
			material.emission = device.get_meta("grid_emission_on", Color.WHITE) if online else device.get_meta("grid_emission_off", Color("#293034"))

func _solar_efficiency(direction: Vector2i) -> float:
	# The level's sun is treated as a fixed teaching-friendly direction.  Facing
	# it produces full output; a side-on panel is useful but less effective.
	var sunlight:=Vector2i(0,-1)
	var alignment:=direction.x*sunlight.x+direction.y*sunlight.y
	if alignment>0: return 1.0
	if alignment==0: return .55
	return .15

# ---------- save / restore ----------
# Only simulation records are serialised.  Meshes, colliders and HUD are rebuilt
# from those records so saves remain valid when presentation assets are updated.
func surface_entry(id: String) -> Dictionary:
	return SURFACE_EQUIPMENT.get(id, {}) as Dictionary

func surface_invalid_reason(id: String, position: Vector3) -> String:
	var entry := surface_entry(id)
	if entry.is_empty(): return "Unknown surface equipment"
	if is_inside(position): return "Keep surface equipment outside the habitat"
	var radius := float(entry.get("radius", .6))
	for item in placed_surface:
		var other: Dictionary = item as Dictionary
		var other_entry := surface_entry(str(other.get("id", "")))
		if position.distance_to(other.get("position", Vector3.ZERO) as Vector3) < radius + float(other_entry.get("radius", .6)) + .25:
			return "Too close to surface equipment"
	return ""

func surface_visual(id: String, position: Vector3, rotation_y: float) -> Node3D:
	var entry := surface_entry(id)
	var holder := Node3D.new()
	holder.name = "Surface_%s" % id
	holder.position = position
	holder.rotation.y = rotation_y
	var path := str(entry.get("asset", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var scene := load(path)
		if scene is PackedScene:
			var model := (scene as PackedScene).instantiate() as Node3D
			if model != null:
				model.name = "Model"
				holder.add_child(model)
	var collision_body := StaticBody3D.new()
	collision_body.name = "SurfaceCollision"
	collision_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(entry.get("radius", .6))
	shape.height = 1.0
	collision.shape = shape
	collision_body.add_child(collision)
	holder.add_child(collision_body)
	return holder

func place_surface_equipment(id: String, position: Vector3, rotation_y: float, visual: Node3D) -> bool:
	if not surface_invalid_reason(id, position).is_empty() or visual == null:
		return false
	var placement_id := "surface_%d" % Time.get_ticks_usec()
	placed_surface.append({"placement_id": placement_id, "id": id, "position": position, "rotation_y": rotation_y})
	visual.name = "Surface_%s" % placement_id
	visual.set_meta("surface_placement_id", placement_id)
	visual.set_meta("surface_equipment_id", id)
	surface_furnishing.add_child(visual)
	habitat_changed.emit()
	return true

func remove_surface_equipment(placement_id: String) -> bool:
	for index in range(placed_surface.size() - 1, -1, -1):
		if str((placed_surface[index] as Dictionary).get("placement_id", "")) != placement_id:
			continue
		placed_surface.remove_at(index)
		for child in surface_furnishing.get_children():
			if str(child.get_meta("surface_placement_id", "")) == placement_id:
				child.queue_free()
		habitat_changed.emit()
		return true
	return false

func export_habitat_state() -> Dictionary:
	return {
		"zones": zones.duplicate(true),
		"placed_equipment": placed_equipment.duplicate(true),
		"placed_interior": placed_interior.duplicate(true),
		"placed_surface": placed_surface.duplicate(true),
		"habitat_base_y": habitat_base_y,
		"kind": kind,
		"airlock_direction": airlock_direction
	}

func restore_habitat_state(state: Dictionary) -> void:
	for child in root.get_children(): child.free()
	for child in furnishing.get_children(): child.free()
	for child in surface_furnishing.get_children(): child.free()
	zones = (state.get("zones", []) as Array).duplicate(true)
	# Older saves or hand-authored test records may not carry display fields.
	# Recreate only those derivable fields; never change a valid saved layout.
	for index in range(zones.size()):
		var saved_zone: Dictionary = zones[index] as Dictionary
		if not saved_zone.has("door_direction"):
			saved_zone["door_direction"] = Vector2i(0, -1)
		if not saved_zone.has("cost"):
			saved_zone["cost"] = _zone_cost(saved_zone.get("cells", []) as Array)
		zones[index] = saved_zone
	placed_equipment = (state.get("placed_equipment", []) as Array).duplicate(true)
	placed_interior.clear()
	placed_surface.clear()
	habitat_base_y = float(state.get("habitat_base_y", habitat_base_y))
	kind = str(state.get("kind", kind))
	airlock_direction = state.get("airlock_direction", airlock_direction) as Vector2i
	for raw_item in state.get("placed_interior", []) as Array:
		var item: Dictionary = raw_item as Dictionary
		var item_id := str(item.get("id", ""))
		var position: Vector3 = item.get("position", Vector3.ZERO) as Vector3
		var visual := free_interior_visual(item_id, position, float(item.get("rotation_y", 0.0)))
		visual.name = "Interior_%s" % str(item.get("placement_id", item_id))
		visual.set_meta("equipment_id", item_id)
		visual.set_meta("interior_placement_id", str(item.get("placement_id", "")))
		furnishing.add_child(visual)
		placed_interior.append(item.duplicate(true))
	for raw_item in state.get("placed_surface", []) as Array:
		var surface_item: Dictionary = raw_item as Dictionary
		var surface_id := str(surface_item.get("id", ""))
		var surface_visual_instance := surface_visual(surface_id, surface_item.get("position", Vector3.ZERO) as Vector3, float(surface_item.get("rotation_y", 0.0)))
		if surface_entry(surface_id).is_empty():
			surface_visual_instance.queue_free()
			continue
		surface_visual_instance.name = "Surface_%s" % str(surface_item.get("placement_id", surface_id))
		surface_visual_instance.set_meta("surface_placement_id", str(surface_item.get("placement_id", "")))
		surface_furnishing.add_child(surface_visual_instance)
		placed_surface.append(surface_item.duplicate(true))
	_history.clear()
	_rebuild()

func _update_systems() -> void:
	_update_summary()
	_refresh_catalogue()

# ---------- readiness (Mission Control, explore HUD) ----------
# Simple aggregate checks for the target crew; game-balance estimates only.
func readiness() -> Array:
	var systems:=_systems()
	var habitat_cells:=0; var airlock_cells:=0; var reachable:=0
	var route:=_airlock_connected_cells()
	for zone in zones:
		if str(zone.kind)=="solar" or str(zone.kind)=="reactor" or str(zone.kind)=="ice_extractor": continue
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
	var crew_requirement := int(systems.crew_requirement)
	items.append(_fitted_target_item("beds","Crew berths",int(systems.berths),int(systems.crew_capacity),crew_requirement,"bed-double"))
	items.append(_fitted_target_item("food","Food production",int(systems.food),int(systems.food_capacity),crew_requirement,"wheat"))
	var water_need := crew_requirement + ceili(float(counts_of("hydroponics")) * 1.5) + int(systems.water_draw)
	items.append(_demand_item("water","Water from ice",int(systems.water),water_need,"droplets","%d / %d supply"))
	items.append(_fitted_target_item("life","Air + water",int(systems.life),int(systems.life_capacity),crew_requirement,"wind"))
	items.append(_fitted_target_item("research","Research capability",int(systems.research),int(systems.research_capacity),RESEARCH_TARGET,"flask-conical"))
	var generation:=int(systems.generation); var draw:=int(systems.draw)
	var power_status:="unmet"
	if generation>0 and generation>=draw: power_status="met"
	elif generation>0: power_status="partial"
	items.append({"id":"power","label":"Power","detail":"%d / %d units" % [generation,draw],"status":power_status,"icon":"zap"})
	return items

func _target_item(id: String,item_label: String,value: int,icon_name: String,detail_format: String) -> Dictionary:
	var status:="met" if value>=CREW_TARGET else ("partial" if value>0 else "unmet")
	return {"id":id,"label":item_label,"detail":detail_format % [value,CREW_TARGET],"status":status,"icon":icon_name}

func _fitted_item(id: String, item_label: String, output: int, room_capacity: int, icon_name: String) -> Dictionary:
	return _fitted_target_item(id,item_label,output,room_capacity,CREW_TARGET,icon_name)

func _fitted_target_item(id: String, item_label: String, output: int, room_capacity: int, target: int, icon_name: String) -> Dictionary:
	var status := "met" if output >= target else ("partial" if output > 0 else "unmet")
	return {"id":id,"label":item_label,"detail":"%d / %d equipped · room for %d" % [output, target, room_capacity],"status":status,"icon":icon_name}

func _demand_item(id: String,item_label: String,value: int,demand: int,icon_name: String,detail_format: String) -> Dictionary:
	if demand<=0: return {"id":id,"label":item_label,"detail":"Not needed yet","status":"met","icon":icon_name}
	var status := "met" if value>=demand else ("partial" if value>0 else "unmet")
	return {"id":id,"label":item_label,"detail":detail_format % [value,demand],"status":status,"icon":icon_name}

func counts_of(zone_kind: String) -> int:
	var total := 0
	for zone in zones:
		if str(zone.kind)==zone_kind: total += zone.cells.size()
	return total

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
			"beds": return "Build enough Living Quarters, then add Crew Bunks from the Interior tab. You have %s left." % left
			"food": return "Build Hydroponics, then add Grow Trays from the Interior tab to produce food. You have %s left." % left
			"water": return "Choose Ice Extractor in Resources, then place it over a blue subsurface-ice survey area. You have %s left." % left
			"life": return "Build Life Support, then add an Air Recycler from the Interior tab. You have %s left." % left
			"research": return "Build a Science Lab, then add a Science Workbench from the Interior tab. You have %s left." % left
			"power": return "Add Solar Arrays within 30 m of the habitat. Aim them north (R) for full output. You have %s left." % left
	return "Every system is ready for a crew of %d. Spend spare cargo on science or storage — %s left." % [CREW_TARGET,left]

func cargo_by_category() -> Dictionary:
	var out:={"rooms":0,"structure":0,"power":0,"equipment":0}
	for zone in zones: out[str(ZONE_INFO[zone.kind].cat)]+=int(zone.cost)
	for item in placed_equipment: out.equipment+=int(EquipmentCatalog.get_entry(str(item.get("id",""))).get("cargo_cost",0))
	for item in placed_interior: out.equipment+=int(EquipmentCatalog.get_entry(str(item.get("id",""))).get("cargo_cost",0))
	return out

func used_cargo() -> int: return _used_cargo()

# True when a world point is on the deck of a habitat zone (drives the interior hum).
func is_inside(point: Vector3) -> bool:
	if point.y<habitat_base_y-.6 or point.y>habitat_base_y+4.0: return false
	var cell:=Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
	for zone in zones:
		if str(zone.kind)!="solar" and str(zone.kind)!="reactor" and str(zone.kind)!="ice_extractor" and cell in zone.cells: return true
	return false

# Environmental readout for the explorer HUD. The outdoor baseline comes from
# the selected site; sealed rooms only become truly habitable once generated
# power can run Life Support. Future first-person equipment can add a local
# heat value here without changing the HUD or site data contracts.
func climate_at(point: Vector3) -> Dictionary:
	var telemetry: Dictionary = MHGame.site().get("telemetry", {})
	var outside_temp := MHGame.outside_temperature_c if MHGame.outside_temperature_c != 0.0 else float(telemetry.get("outside_temp_c", -30.0))
	var cell := Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))
	var zone_kind := ""
	for zone in zones:
		if str(zone.kind) != "solar" and str(zone.kind) != "reactor" and str(zone.kind) != "ice_extractor" and cell in zone.cells:
			zone_kind = str(zone.kind)
			break
	if zone_kind.is_empty() or point.y < habitat_base_y - .6 or point.y > habitat_base_y + 4.0:
		return {"temperature": outside_temp, "radiation": str(telemetry.get("radiation", "High")), "context": "Outside · EVA exposure", "state": "outside"}
	var systems := _systems()
	var powered := grid_power_online()
	var climate_controlled := powered and int(systems.life) > 0
	var temperature := outside_temp + 8.0 # A sealed but unheated shell slows heat loss.
	var context := str(ZONE_TYPES.get(zone_kind, {}).get("label", "Habitat"))
	var radiation := "Sheltered"
	var state := "unheated"
	if climate_controlled:
		var targets := {"living": 20.0, "hydroponics": 24.0, "science": 21.0, "storage": 12.0, "corridor": 16.0, "airlock": 8.0, "vehicle_bay": 6.0, "glass_room": 22.0}
		temperature = float(targets.get(zone_kind, 18.0))
		state = "climate"
		context += " · climate control"
	elif powered:
		temperature = minf(outside_temp + 12.0, 4.0)
		state = "powered_shell"
		context += " · powered, no heater"
	else:
		context += " · unheated shell"
	if zone_kind == "glass_room":
		radiation = "Moderate"
	return {"temperature": temperature, "radiation": radiation, "context": context, "state": state}

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
	var grid_limit := roundi(_site_build_limit())
	for n in range(-grid_limit,grid_limit):
		var at:=float(n)+.5
		var major:=posmod(n-1,int(CELL))==0
		var colour:=Color(MHStyle.CELL_LINE,.55) if major else Color(MHStyle.CELL_LINE,.16)
		for points in [[Vector3(at,.09,-grid_limit),Vector3(at,.09,grid_limit)],[Vector3(-grid_limit,.09,at),Vector3(grid_limit,.09,at)]]:
			immediate.surface_set_color(colour); immediate.surface_add_vertex(points[0])
			immediate.surface_set_color(colour); immediate.surface_add_vertex(points[1])
	immediate.surface_end()
	var shader:=Shader.new(); shader.code=GRID_SHADER
	var material:=ShaderMaterial.new(); material.shader=shader
	grid=MeshInstance3D.new(); grid.mesh=immediate; grid.material_override=material; grid.visible=false; grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(grid)
	# Dark blueprint wash under the lines so the cyan grid reads against bright terrain.
	var wash:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(grid_limit*2.0,grid_limit*2.0); wash.mesh=plane; wash.position.y=-.02; wash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	catalogue_count=MHStyle.eyebrow("%d zones" % ZONE_TYPES.size()); catalogue_count.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head_row.add_child(catalogue_count)
	var tabs:=MHStyle.hbox(0); var tabs_margin:=MarginContainer.new(); tabs_margin.add_theme_constant_override("margin_left",16); tabs_margin.add_theme_constant_override("margin_right",16); tabs_margin.add_child(tabs); column.add_child(tabs_margin)
	for entry in CATEGORIES:
		var tab:=Button.new(); tab.text=str(entry[1]).to_upper(); tab.set_meta("label",tab.text); tab.tooltip_text=str(entry[1]); tab.icon=MHIcons.texture(entry[2],18); tab.custom_minimum_size.y=44; tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tab.focus_mode=Control.FOCUS_NONE
		tab.add_theme_font_override("font",MHStyle.font(700,false,1)); tab.add_theme_font_size_override("font_size",14); tab.add_theme_constant_override("icon_max_width",18); tab.add_theme_constant_override("h_separation",8); tab.alignment=HORIZONTAL_ALIGNMENT_LEFT
		tab.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		tab.pressed.connect(func() -> void: category=str(entry[0]); _refresh_catalogue())
		tabs.add_child(tab); category_buttons[entry[0]]=tab
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	var grid_margin:=MarginContainer.new(); grid_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: grid_margin.add_theme_constant_override("margin_"+side,16)
	scroll.add_child(grid_margin)
	var lists:=MHStyle.vbox(0); grid_margin.add_child(lists)
	catalogue_grid=GridContainer.new(); catalogue_grid.columns=2; catalogue_grid.add_theme_constant_override("h_separation",12); catalogue_grid.add_theme_constant_override("v_separation",12); lists.add_child(catalogue_grid)
	# Interior inventory: one titled section per zone family.
	equipment_list=MHStyle.vbox(12); equipment_list.visible=false; lists.add_child(equipment_list)
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
	kind=id; equipment_id=""; dragging=false; category=str(ZONE_INFO[id].cat); _set_tool("place"); _preview_key=""
	_refresh_catalogue()

func _select_equipment(id: String) -> void:
	equipment_id=id; dragging=false; category="equipment"; _set_tool("place"); _preview_key=""
	_refresh_catalogue()

func _select_surface_equipment(id: String) -> void:
	if not SURFACE_EQUIPMENT.has(id):
		return
	# Ground props are selected in the familiar exterior catalogue, then placed
	# in first person on actual terrain rather than snapped to construction cells.
	surface_build_requested.emit(id)
	if build_mode:
		_toggle()

func _refresh_catalogue() -> void:
	if catalogue_grid==null: return
	for id in category_buttons:
		var tab:Button=category_buttons[id]; var active:bool=id==category
		var style:=MHStyle.box(Color(0,0,0,0),Color(0,0,0,0),0,0,Vector4(12,0,8,0)); style.border_width_bottom=2 if active else 1; style.border_color=MHStyle.accent if active else MHStyle.BORDER_SUBTLE
		for state in ["normal","hover","pressed","hover_pressed","focus"]: tab.add_theme_stylebox_override(state,style)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]: tab.add_theme_color_override(state,MHStyle.TEXT_PRIMARY if active else MHStyle.TEXT_SECONDARY)
		# Four tabs only fit when the inactive ones collapse to their icon.
		tab.text=str(tab.get_meta("label")) if active else ""
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL if active else Control.SIZE_FILL
		tab.custom_minimum_size.x=0.0 if active else 52.0
	for child in catalogue_grid.get_children(): child.queue_free()
	for child in equipment_list.get_children(): child.queue_free()
	for child in catalogue_detail.get_children(): child.queue_free()
	var remaining:=CARGO_BUDGET-_used_cargo()
	catalogue_grid.visible=category!="equipment"; equipment_list.visible=category=="equipment"
	if category=="equipment":
		catalogue_count.text="%d items" % EquipmentCatalog.entries().size()
		_refresh_equipment_list(remaining)
	elif category=="surface":
		catalogue_count.text="%d props" % SURFACE_EQUIPMENT.size()
		for id in SURFACE_EQUIPMENT:
			catalogue_grid.add_child(_surface_equipment_card(id))
		var surface_head:=MHStyle.hbox(8); catalogue_detail.add_child(surface_head)
		surface_head.add_child(MHStyle.title("Surface equipment",20)); surface_head.add_child(MHStyle.spacer())
		catalogue_detail.add_child(MHStyle.body("Select a non-structural prop, then place it freely from first person on outdoor ground. These props do not replace the grid-based reactor or ice extractor and have no simulation effect yet.",14))
		return
	else:
		catalogue_count.text="%d zones" % ZONE_TYPES.size()
		for id in ZONE_TYPES:
			if str(ZONE_INFO[id].cat)!=category: continue
			catalogue_grid.add_child(_part_card(id,id==kind and equipment_id.is_empty(),remaining<int(ZONE_TYPES[id].cost)))
	if not equipment_id.is_empty():
		_refresh_equipment_detail()
		return
	var info:Dictionary=ZONE_INFO[kind]
	var head:=MHStyle.hbox(8); catalogue_detail.add_child(head)
	head.add_child(MHStyle.title(str(ZONE_TYPES[kind].label),20)); head.add_child(MHStyle.spacer())
	var cost:=MHStyle.mono("%s / cell" % MHStyle.kg(int(ZONE_TYPES[kind].cost)),14,MHStyle.accent,600); cost.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head.add_child(cost)
	catalogue_detail.add_child(MHStyle.body(str(info.desc),16))
	var badges:=MHStyle.hbox(8); catalogue_detail.add_child(badges)
	badges.add_child(MHStyle.badge(str(info.rule),"info"))
	if kind in ["airlock","vehicle_bay","solar","corridor"]: badges.add_child(MHStyle.badge("Facing: %s" % _facing_name(),"neutral"))

func _refresh_equipment_list(remaining: int) -> void:
	for group in EquipmentCatalog.groups():
		var ids:=EquipmentCatalog.ids_in_group(str(group.id))
		if ids.is_empty(): continue
		var head:=MHStyle.hbox(8); equipment_list.add_child(head)
		head.add_child(MHStyle.icon(str(group.get("icon","box")),16,MHStyle.TEXT_SECONDARY))
		var title:=MHStyle.eyebrow(str(group.label),MHStyle.TEXT_SECONDARY); head.add_child(title)
		head.add_child(MHStyle.spacer())
		# A section reads as "ready" once a room that accepts its items exists.
		var has_room:=false
		for id in ids:
			for zone_kind in EquipmentCatalog.get_entry(id).get("valid_zones",[]):
				if counts_of(str(zone_kind))>0: has_room=true
		head.add_child(MHStyle.mono("%d" % ids.size() if has_room else "No room yet",12,MHStyle.TEXT_MUTED))
		var grid:=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); equipment_list.add_child(grid)
		for id in ids:
			grid.add_child(_equipment_card(id,id==equipment_id,remaining<int(EquipmentCatalog.get_entry(id).get("cargo_cost",0))))

func _equipment_card(id: String,selected: bool,unaffordable: bool) -> Button:
	var entry:=EquipmentCatalog.get_entry(id)
	var card:=Button.new(); card.custom_minimum_size=Vector2(196,128); card.focus_mode=Control.FOCUS_NONE; card.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var normal:=MHStyle.selected_box(0) if selected else MHStyle.control_box(0)
	for state in ["normal","pressed","hover_pressed","focus"]: card.add_theme_stylebox_override(state,normal)
	card.add_theme_stylebox_override("hover",normal if selected else MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER,MHStyle.BORDER_STRONG))
	card.pressed.connect(_select_equipment.bind(id))
	var colour:Color=ZONE_TYPES.get(str((entry.get("valid_zones",["storage"]) as Array)[0]),ZONE_TYPES.storage).colour
	var column:=MHStyle.vbox(0); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; card.add_child(column)
	var thumb:=PanelContainer.new(); var thumb_style:=MHStyle.box(MHStyle.BLUEPRINT.lerp(colour,.22),Color(0,0,0,0),MHStyle.RADIUS_MD,0); thumb_style.corner_radius_bottom_left=0; thumb_style.corner_radius_bottom_right=0
	thumb.add_theme_stylebox_override("panel",thumb_style); thumb.custom_minimum_size.y=52; thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(thumb)
	thumb.add_child(MHStyle.icon(str(entry.get("icon","box")),26,colour.lightened(.45)))
	var text:=MarginContainer.new(); text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side in ["left","right"]: text.add_theme_constant_override("margin_"+side,12)
	text.add_theme_constant_override("margin_top",8); column.add_child(text)
	var lines:=MHStyle.vbox(4); text.add_child(lines)
	var name_label:=MHStyle.label(str(entry.get("label",id)),15,MHStyle.TEXT_PRIMARY,600); name_label.clip_text=true; lines.add_child(name_label)
	var row:=MHStyle.hbox(6); lines.add_child(row)
	var mass_colour:=MHStyle.DANGER if unaffordable else (MHStyle.accent if selected else MHStyle.TEXT_SECONDARY)
	row.add_child(MHStyle.mono(MHStyle.kg(int(entry.get("cargo_cost",0))),12,mass_colour,600)); row.add_child(MHStyle.spacer())
	var status:Array=EquipmentCatalog.STATUS_BADGES.get(str(entry.get("status","future")),EquipmentCatalog.STATUS_BADGES.future)
	row.add_child(MHStyle.mono(str(status[0]),11,MHStyle.tone_colour(str(status[1]))))
	return card

func _refresh_equipment_detail() -> void:
	var entry:=EquipmentCatalog.get_entry(equipment_id)
	var head:=MHStyle.hbox(8); catalogue_detail.add_child(head)
	var title:=MHStyle.title(str(entry.get("label",equipment_id)),20); title.clip_text=true; title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(title)
	var cost:=MHStyle.mono(MHStyle.kg(int(entry.get("cargo_cost",0))),14,MHStyle.accent,600); cost.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head.add_child(cost)
	var desc:=MHStyle.body(str(entry.get("description","")),15); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; catalogue_detail.add_child(desc)
	var effects:=EquipmentCatalog.effects_text(equipment_id)
	catalogue_detail.add_child(MHStyle.mono(effects if not effects.is_empty() else str(entry.get("role","No resource effect")),13,MHStyle.VALID if not effects.is_empty() else MHStyle.TEXT_MUTED))
	var fits:=MHStyle.mono("Fits: %s" % _zone_list_text(entry.get("valid_zones",[])),12,MHStyle.TEXT_SECONDARY); fits.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; catalogue_detail.add_child(fits)
	var badges:=MHStyle.hbox(8); catalogue_detail.add_child(badges)
	var status:Array=EquipmentCatalog.STATUS_BADGES.get(str(entry.get("status","future")),EquipmentCatalog.STATUS_BADGES.future)
	if bool(entry.get("batch",false)): badges.add_child(MHStyle.badge("Batch 1","accent"))
	badges.add_child(MHStyle.badge(str(status[0]),str(status[1])))
	badges.add_child(MHStyle.badge("Facing: %s" % _facing_name(),"neutral"))

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

func _surface_equipment_card(id: String) -> Button:
	var entry: Dictionary = SURFACE_EQUIPMENT[id]
	var card := Button.new()
	card.custom_minimum_size = Vector2(196, 142)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s\nFree placement on outdoor ground" % str(entry.label)
	card.add_theme_stylebox_override("normal", MHStyle.control_box(0))
	card.add_theme_stylebox_override("hover", MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER, MHStyle.BORDER_STRONG, MHStyle.RADIUS_MD, 1, Vector4(12, 12, 12, 12)))
	var column := MHStyle.vbox(5)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_row := MHStyle.hbox(8)
	icon_row.add_child(MHStyle.icon(str(entry.icon), 22, MHStyle.accent))
	icon_row.add_child(MHStyle.eyebrow("SURFACE", MHStyle.accent, 10))
	column.add_child(icon_row)
	column.add_child(MHStyle.label(str(entry.label), 16, MHStyle.TEXT_PRIMARY, 600))
	column.add_child(MHStyle.mono("FIRST-PERSON · FREE GROUND", 10, MHStyle.TEXT_MUTED))
	card.add_child(column)
	card.pressed.connect(_select_surface_equipment.bind(id))
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
	var placing_name:String=str(ZONE_TYPES[kind].label) if equipment_id.is_empty() else str(EquipmentCatalog.get_entry(equipment_id).get("label",equipment_id))
	if tool=="remove":
		state="remove"; message="Click equipment or a zone to remove it · full refund"
		placing_label.text="Remove tool"; placing_delta.text=""
	elif _pointer_over_ui():
		placing_label.text="Placing %s" % placing_name; placing_delta.text=""
	elif not equipment_id.is_empty():
		var item_cost:=int(EquipmentCatalog.get_entry(equipment_id).get("cargo_cost",0))
		var left:=CARGO_BUDGET-_used_cargo()-item_cost
		placing_label.text="Placing %s" % placing_name
		placing_delta.text="−%s → %s" % [MHStyle.kg(item_cost),MHStyle.kg(left)] if not cells.is_empty() else ""
		placing_delta.add_theme_color_override("font_color",MHStyle.DANGER if left<0 else (MHStyle.WARN if left<CARGO_BUDGET*.1 else MHStyle.accent))
		if not reason.is_empty(): state="invalid"; message=reason
		elif not cells.is_empty():
			var effects:=EquipmentCatalog.effects_text(equipment_id)
			state="valid"; message="%s · %s" % [ZONE_TYPES[_zone_at(cells[0]).kind].label,effects if not effects.is_empty() else "no resource effect"]
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
