class_name BuildController
extends Node
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# One floorplan is the source of truth for plan tiles, visible shell and collision.
const CELL := 3.0
const LIMIT := 60
const MHResources := preload("res://scripts/mh_resources.gd")
const HABITAT_SIM := preload("res://scripts/habitat_sim.gd")
const MHMissions := preload("res://scripts/mh_missions.gd")
const ModelThumbnails := preload("res://scripts/model_thumbnails.gd")
const PARTITION_DOOR_SCRIPT := preload("res://scripts/partition_door.gd")
const ROOM_LIGHT_PANEL := preload("res://scripts/room_light_panel.gd")
const ICE_SURVEY_SHADER := preload("res://shaders/ice_survey.gdshader")
const ROOM_IDENTITY := preload("res://scripts/room_identity.gd")
## Interior partition walls: 1.5 m segments on the half-cell grid inside a
## room (bedrooms, toilet cubicles). The room stays one zone for the simulation.
const PARTITION_STEP := 1.5
const PARTITION_THICKNESS := .1
var partitions: Array = []
var mars_made_label: Label   # [{"a": Vector2, "b": Vector2, "door": bool}]
const MODEL_PREVIEW := preload("res://scripts/model_preview.gd")
## Site-plan parts that have a real model (for thumbnails and the 3D preview).
const PART_MODELS := {"reactor": "surface_reactor", "ice_extractor": "ice_drill", "regolith_intake": "regolith_intake"}
## Single-cell outdoor machines (not rooms): power sources, drills, intakes.
const SITE_MACHINES := ["solar", "reactor", "ice_extractor", "regolith_intake"]
## Not ordinary rooms: connectors, the bay, and the outdoor machines.
const NON_ROOM_KINDS := ["airlock", "corridor", "vehicle_bay", "solar", "reactor", "ice_extractor", "regolith_intake"]
## Room shells Mars-made (printed) material can pay for. Airlocks keep
## Earth-made seals and mechanisms; outdoor machines are all Earth-made.
const PRINTABLE_ZONE_EXCLUDES := ["airlock", "solar", "reactor", "ice_extractor", "regolith_intake"]
var catalogue_preview: SubViewportContainer
var catalogue_stage: PanelContainer
var catalogue_details: PanelContainer
var _sim: RefCounted
## The crew lander (scripts/crew_lander.gd): nothing can be built on top of it.
var lander: Node3D

## The habitat's life-support simulation (scripts/habitat_sim.gd).
func simulation() -> RefCounted:
	if _sim == null: _sim = HABITAT_SIM.new(self)
	return _sim

## Game hours passing (the day/night clock calls this every frame).
func advance_simulation(hours: float, start_hour: float) -> void:
	if not MHGame.simulation_on() or hours <= 0.0: return
	simulation().advance(hours, start_hour)
const CELL_COST := 50
const ANGLED_CORNER_CLEARANCE := 0.6
# CELL / √2: the spacing between parallel 45° wall lines on the cell-corner
# lattice. DIAGONAL_CELL (CELL·√2) is one cell crossed corner to corner, the
# length of each stretch of a 45° wall between lattice corners.
const DIAGONAL_STEP := 2.1213203
# How close to a 45° wall the cursor must be before Corridor/Airlock switches
# to an angled connector; anywhere else places ordinary grid pieces.
const ANGLED_MOUNT_REACH := 1.6
const DIAGONAL_CELL := 4.2426407
const AIRLOCK_DOOR := preload("res://scripts/airlock_door.gd")
const SHOWCASE_WALL := preload("res://assets/showcase_modules/mh_wall_bay.glb")
const SHOWCASE_CORNER := preload("res://assets/showcase_modules/mh_corner_post.glb")
const SHOWCASE_AIRLOCK := preload("res://assets/showcase_modules/mh_airlock_surround.glb")
const SHOWCASE_CORRIDOR := preload("res://assets/showcase_modules/mh_corridor_bay.glb")
const SHOWCASE_SOLAR := preload("res://assets/showcase_modules/mh_solar_array.glb")
const ROOF_ACCESSORY_SCENES := {
	"living": preload("res://assets/structural_kit/roof_living_comms_mast.glb"),
	"science": preload("res://assets/structural_kit/roof_science_dish.glb"),
	"hydroponics": preload("res://assets/structural_kit/roof_hydroponics_vent_bank.glb"),
	"life_support": preload("res://assets/structural_kit/roof_life_support_exhaust.glb"),
	"engineering": preload("res://assets/structural_kit/roof_engineering_radiator.glb"),
	"communications": preload("res://assets/structural_kit/roof_communications_array.glb")
}
const SOLAR_POWER_RADIUS := 30.0
const REACTOR_POWER_RADIUS := 42.0
const SOLAR_OUTPUT := 24
# Heating: each pressurised cell needs this much power per degree C that Mars
# is colder than the habitat, so cold sites and nights cost more to keep warm.
const HABITAT_TEMPERATURE_C := 20.0
const HEATING_PER_CELL_DEGREE := 1.0 / 60.0
# Hull windows: a framed glazed band swapped into one Mars-facing 3 m wall
# bay. Glass loses heat faster than the insulated hull.
const WINDOW_HEAT_LOSS_CELLS := 1.5 # heat loss of one window, in cells of hull
const WINDOW_SILL := .9
const WINDOW_HEAD := 2.3
const REACTOR_OUTPUT := 360
const CREW_TARGET := 6
const RESEARCH_TARGET := 6
const ZONE_TYPES := {
	"living":{"label":"Living Quarters","colour":Color(.22,.48,.78),"cost":CELL_COST},
	"science":{"label":"Science Lab","colour":Color(.55,.26,.74),"cost":CELL_COST},
	"storage":{"label":"Storage","colour":Color(.62,.46,.18),"cost":CELL_COST},
	"hydroponics":{"label":"Hydroponics","colour":Color(.18,.62,.31),"cost":CELL_COST},
	"life_support":{"label":"Life Support","colour":Color(.12,.63,.67),"cost":CELL_COST},
	"engineering":{"label":"Power & Engineering","colour":Color(.88,.30,.16),"cost":CELL_COST},
	"galley":{"label":"Galley","colour":Color(.90,.53,.16),"cost":CELL_COST},
	"hygiene":{"label":"Hygiene","colour":Color(.18,.56,.75),"cost":CELL_COST},
	"medical":{"label":"Medical Bay","colour":Color(.78,.26,.34),"cost":CELL_COST},
	"waste_management":{"label":"Waste Management","colour":Color(.38,.45,.27),"cost":CELL_COST},
	"communications":{"label":"Mission Operations","colour":Color(.25,.45,.80),"cost":CELL_COST},
	"corridor":{"label":"Corridor","colour":Color(.76,.30,.08),"plan_colour":Color("#8FA3AD"),"cost":CELL_COST},
	"airlock":{"label":"Airlock","colour":Color(.95,.43,.08),"cost":CELL_COST},
	"vehicle_bay":{"label":"Vehicle Bay","colour":Color(.88,.62,.12),"cost":CELL_COST},
	"solar":{"label":"Solar Array","colour":Color(.18,.64,.94),"cost":CELL_COST},
	"reactor":{"label":"Compact Reactor","colour":Color(.88,.30,.16),"cost":1200},
	"ice_extractor":{"label":"Ice Extractor","colour":Color(.20,.82,.92),"cost":450},
	"regolith_intake":{"label":"Regolith Intake","colour":Color(.78,.48,.28),"cost":900}
}

# Catalogue metadata for the build HUD. Gameplay values stay in ZONE_TYPES.
const ZONE_INFO := {
	"living":{"cat":"rooms","icon":"bed-double","rule":"Drag an area","desc":"Makes space for bunks, lockers and personal areas. Furnish it to house crew."},
	"science":{"cat":"rooms","icon":"flask-conical","rule":"Drag an area","desc":"Makes space for benches and instruments. Furnish it to conduct research."},
	"storage":{"cat":"rooms","icon":"package","rule":"Drag an area","desc":"Racks for spares, tools and supplies."},
	"hydroponics":{"cat":"rooms","icon":"sprout","rule":"Drag an area","desc":"Makes space for grow equipment. Furnish it to produce food."},
	"life_support":{"cat":"rooms","icon":"wind","rule":"Drag an area","desc":"Makes space for air and water recyclers. Furnish it to support crew."},
	"engineering":{"cat":"rooms","icon":"zap","rule":"Drag an area","desc":"A dedicated engineering room for electrical distribution, batteries and thermal hardware."},
	"galley":{"cat":"rooms","icon":"utensils","rule":"Drag an area","desc":"A compact food-preparation and crew-meal space."},
	"hygiene":{"cat":"rooms","icon":"droplets","rule":"Drag an area","desc":"A private washroom for hygiene and daily routines."},
	"medical":{"cat":"rooms","icon":"heart-pulse","rule":"Drag an area","desc":"A small clinical bay for examination and medical supplies."},
	"waste_management":{"cat":"rooms","icon":"recycle","rule":"Drag an area","desc":"A dedicated room for sorting and processing habitat waste."},
	"communications":{"cat":"rooms","icon":"radio","rule":"Drag an area","desc":"Plan missions, map the site and keep in touch with Earth and the rovers."},
	"corridor":{"cat":"structure","icon":"move-vertical","rule":"Straight runs · R rotates · click 45° wall","desc":"Creates a sealed passage. Click an exact 45° free-form wall for a rotated connector."},
	"airlock":{"cat":"structure","icon":"door-closed","rule":"1–3 cells · R rotates · click 45° wall","desc":"The way in and out. Click an exact 45° free-form wall for a rotated airlock; otherwise the inner end must touch a room."},
	"vehicle_bay":{"cat":"structure","icon":"truck","rule":"2–4 cells · R rotates","desc":"A hangar for rovers. Its wide door must face outside."},
	"solar":{"cat":"power","icon":"sun","rule":"One cell · R aims","desc":"Cabled to the grid wherever it stands. Facing north gives full output."},
	"reactor":{"cat":"power","icon":"atom","rule":"One cell","desc":"A compact fission reactor, cabled to the grid. High output, day and night, but a high cargo cost."},
	"ice_extractor":{"cat":"power","icon":"drill","rule":"One cell","desc":"Drills into buried ice. Choose it to survey blue ice-rich ground."},
	"regolith_intake":{"cat":"power","icon":"mountain-snow","rule":"One cell","desc":"Digs Martian soil and feeds it to a regolith printer indoors, which turns it into building material."}
}
# Exterior construction deliberately excludes furnishing. Interior equipment is
# selected only through the first-person construction controller.
const CATEGORIES := [["rooms","Rooms","bed-double"],["structure","Structure","box"],["power","Resources","sun"],["surface","Surface gear","package"]]
const SURFACE_EQUIPMENT := {
	"cargo_crate_small": {"label":"Small Cargo Crate", "icon":"package", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/cargo_crate_small.tscn", "radius":0.4, "height":0.45, "stackable":true, "top":0.41, "top_radius":0.3},
	"cargo_crate_large": {"label":"Large Cargo Crate", "icon":"package", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/cargo_crate_large.tscn", "radius":0.6, "height":0.7, "stackable":true, "top":0.66, "top_radius":0.45},
	"equipment_pallet": {"label":"Loaded Cargo Pallet", "icon":"package", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/equipment_pallet.tscn", "radius":1.0, "height":1.1, "top":1.05, "top_radius":0.7},
	"comms_antenna": {"label":"Communications Mast", "icon":"satellite", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/comms_antenna.tscn", "radius":0.95, "height":4.5},
	"exterior_workbench": {"label":"Outdoor Workbench", "icon":"wrench", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/exterior_workbench.tscn", "radius":0.95, "height":1.8, "top":0.96, "top_radius":0.5},
	"high_light_post": {"label":"Tall Light Post", "icon":"lightbulb", "asset":"res://assets/equipment/mars_exterior_hero_refresh_martian_hailmary_v1/high_light_post.tscn", "radius":0.4, "height":3.7},
	"path_beacon": {"label":"Path Beacon", "icon":"map-pin", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/path_beacon.tscn", "radius":0.22, "height":1.1},
	"portable_work_light": {"label":"Portable Floodlight", "icon":"lightbulb", "asset":"res://assets/equipment/mars_exterior_hero_refresh_martian_hailmary_v1/portable_work_light.tscn", "radius":0.42, "height":2.0},
	"safety_barrier": {"label":"Safety Barrier", "icon":"shield", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/safety_barrier.tscn", "radius":0.9, "height":1.1},
	"solar_floodlight": {"label":"Solar Floodlight", "icon":"sun", "asset":"res://assets/equipment/mars_exterior_hero_refresh_martian_hailmary_v1/solar_floodlight.tscn", "radius":0.4, "height":2.9},
	"hazard_bollard": {"label":"Hazard Bollard", "icon":"triangle-alert", "asset":"res://assets/equipment/mars_exterior_support_martian_hailmary_v2/hazard_bollard.tscn", "radius":0.2, "height":1.0},
}
const HALF_CELL := 1.5
# Plan tiles are unshaded and tone-mapped; darken them so white zone labels stay readable.
const PLAN_TILE_SHADE := .35
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
## Generation or draw changed with the sun or temperature (not the layout).
signal power_changed
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
# Deliberate openings between two completed, adjacent rooms.  Unlike the old
# automatic join behaviour, these are player-built interior structures.
var interior_doors: Array = []
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
var angled_corridor_mount: Dictionary = {}
## Free-form rooms are intentionally a second, isolated placement path.  They
## have their own outline and never participate in the old cell-wall logic.
var room_draw_mode := "rectangle"
var freeform_points := PackedVector2Array()
# The footprint editor grows an existing ordinary room one cell at a time.
# A zone already stores an arbitrary cell array, so this is deliberately a
# lightweight editing layer rather than a second room representation.
var footprint_zone_index := -1
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
var catalogue_grid: HBoxContainer
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
var _debug_backings_visible := true
var _mode_switcher: Dictionary = {}
## Saved windows: {"mid": Vector2, "dir": Vector2} for each glazed hull bay.
var hull_windows: Array = []
## Every Mars-facing wall bay built this rebuild, where a window may go:
## {mid, dir, tangent, outward, length, zone_kind}.
var _hull_bays: Array = []
var _windows_built: Dictionary = {}
@onready var world := get_parent()

## Colour a zone is drawn in on the site plan. Defaults to its deck colour;
## corridors use steel so they read apart from the rust terrain and orange airlocks.
static func plan_colour(zone_kind: String) -> Color:
	var info: Dictionary = ZONE_TYPES.get(zone_kind, {})
	return info.get("plan_colour", info.get("colour", Color.WHITE)) as Color

func _site_build_limit() -> float:
	# Most regions retain the standard 120 m-wide construction area. Individual
	# maps can offer a different surveyed landing field without changing cell size.
	return float(MHGame.site().get("build_limit", LIMIT))

func _ready() -> void:
	add_to_group("habitat_builder")
	habitat_changed.connect(_refresh_mode_switcher)
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
			if active_player != null and bool(active_player.get_meta("surface_build_active", false)):
				return
			# B opens the view that fits where the player stands (Interior inside a
			# room, Site plan outside) and closes either. Shift+B swaps between the
			# two views; from Explore it always opens the Site plan, so a player
			# inside the habitat can still add rooms or an airlock.
			if build_mode:
				if event.shift_pressed: _switch_to_interior()
				else: _toggle()
			elif not event.shift_pressed and player_can_furnish():
				interior_build_requested.emit()
			else:
				_toggle()
		elif event.keycode == KEY_F9:
			_toggle_backing_debug_visibility()
		elif build_mode and event.keycode==KEY_V and _freeform_mode_available():
			room_draw_mode = "freeform" if room_draw_mode == "rectangle" else "rectangle"
			_cancel_freeform()
			_refresh_catalogue()
		elif build_mode and _freeform_active() and event.keycode == KEY_ENTER:
			_finish_freeform()
		elif build_mode and _freeform_active() and event.keycode == KEY_BACKSPACE:
			if not freeform_points.is_empty(): freeform_points.remove_at(freeform_points.size() - 1)
		elif build_mode and catalogue!=null and catalogue.visible and event.keycode>=KEY_1 and event.keycode<=KEY_9 and not event.ctrl_pressed:
			# 1-9 pick a card in the build bar's current tab.
			for card in catalogue_grid.get_children():
				if int(card.get_meta("pick_index",0))==int(event.keycode)-int(KEY_0): (card as Button).pressed.emit()
		elif build_mode and event.keycode==KEY_R and (not equipment_id.is_empty() or kind=="airlock" or kind=="vehicle_bay" or kind=="solar" or kind=="corridor"): _rotate_airlock(); _refresh_catalogue()
		elif build_mode and event.keycode==KEY_ESCAPE:
			# Escape first cancels an in-progress placement; only an idle planner
			# lets it through to open the pause screen.
			if _freeform_active() and not freeform_points.is_empty():
				_cancel_freeform(); get_viewport().set_input_as_handled()
			elif dragging or not angled_corridor_mount.is_empty():
				dragging=false; angled_corridor_mount={}; _draw_preview([],false); get_viewport().set_input_as_handled()
		elif build_mode and event.keycode==KEY_DELETE: _remove_at(hover)
		elif build_mode and event.keycode==KEY_X: _set_tool("place" if tool=="remove" else "remove")
		elif build_mode and event.keycode==KEY_Z and event.ctrl_pressed: _undo()
		elif build_mode and event.keycode==KEY_TAB: _set_catalogue_open(not catalogue.visible); get_viewport().set_input_as_handled()
	if not build_mode or not event is InputEventMouseButton: return
	# Wheel notches arrive as a press and a release; zoom once per notch.
	if event.button_index==MOUSE_BUTTON_WHEEL_UP:
		if event.pressed: zoom=maxf(20.0,zoom-4.0); _zoom()
	elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
		if event.pressed: zoom=minf(90.0,zoom+4.0); _zoom()
	elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		if _freeform_active(): _cancel_freeform()
		else: dragging=false; angled_corridor_mount={}; _set_tool("place"); _draw_preview([],false)
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if tool=="remove":
			if event.pressed: _remove_at(hover)
			return
		if tool=="footprint":
			if event.pressed and not _pointer_over_ui(): _edit_room_footprint(hover, event.ctrl_pressed)
			return
		if not equipment_id.is_empty():
			if event.pressed and not _pointer_over_ui(): _place_selected_equipment(hover)
			return
		if _freeform_active():
			if event.pressed and not _pointer_over_ui(): _add_freeform_point()
			return
		if event.pressed and not _pointer_over_ui() and kind in ["airlock", "corridor"]:
			if kind == "corridor" and _begin_angled_corridor_drag(): return
			if _try_place_angled_outline_connector(): return
		if not event.pressed and not angled_corridor_mount.is_empty():
			_finish_angled_corridor_drag()
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
				_after_room_placed()
				MHAudio.sfx("place")
				var left := MHGame.cargo_budget()-_used_cargo()
				if left<MHGame.cargo_budget()*.1: _flash_notice("warn","Cargo is getting tight","%s left — about %d more cells." % [MHStyle.kg(left),left/cell_cost("living")])
			elif not _pointer_over_ui():
				_flash_notice("invalid","Can't place here",reason+".")
			_draw_preview([],false)

var _r_held := 0.0
var _r_repeat := 0.0

var _budget_refresh := 0.0

func _process(delta: float) -> void:
	if not build_mode: return
	# Printing and resupplies change the cargo over time, not only on edits.
	_budget_refresh -= delta
	if _budget_refresh <= 0.0:
		_budget_refresh = .5
		_update_budget()
	_hold_rotate_plan(delta)
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
	if tool=="footprint":
		_draw_footprint_preview()
		_update_hologram_ui([] if hover.x == 999 else [hover], _footprint_hover_reason(hover))
		return
	if not equipment_id.is_empty():
		var equipment_reason:=equipment_invalid_reason(equipment_id,hover)
		_draw_equipment_preview(hover,equipment_reason.is_empty())
		_update_hologram_ui([] if hover.x==999 else [hover],equipment_reason)
		return
	if _freeform_active():
		var cursor_point := _freeform_cursor_point()
		var freeform_reason := freeform_invalid_reason(freeform_points) if freeform_points.size() >= 3 else "Place at least 3 points"
		_draw_freeform_preview(cursor_point, freeform_reason)
		_update_hologram_ui([], freeform_reason)
		return
	if kind in ["airlock", "corridor"]:
		var mouse_point := _world_point_at_mouse(habitat_base_y)
		if not is_inf(mouse_point.x):
			if kind == "corridor" and not angled_corridor_mount.is_empty():
				var dragged_mount: Dictionary = angled_corridor_mount.duplicate(true)
				dragged_mount["length"] = _angled_corridor_length(dragged_mount, Vector2(mouse_point.x, mouse_point.z))
				var dragged_reason := _angled_outline_mount_invalid_reason(dragged_mount)
				_draw_angled_outline_connector_preview(dragged_mount, dragged_reason.is_empty())
				_update_hologram_ui([], dragged_reason, dragged_mount)
				return
			var angled_mount := _angled_outline_mount_at(Vector2(mouse_point.x, mouse_point.z))
			if not angled_mount.is_empty():
				var mount_reason := _angled_outline_mount_invalid_reason(angled_mount)
				_draw_angled_outline_connector_preview(angled_mount, mount_reason.is_empty())
				_update_hologram_ui([], mount_reason, angled_mount)
				return
	var cells:=_cells(drag_start if dragging else hover,hover)
	var reason:=_invalid_reason(cells)
	_draw_preview(cells,reason.is_empty())
	_update_hologram_ui(cells,reason)

## Holding R in the site plan keeps rotating, one 90° step about every third
## of a second after a short delay (a tap is still one step).
func _hold_rotate_plan(delta: float) -> void:
	if not Input.is_physical_key_pressed(KEY_R) or not (not equipment_id.is_empty() or kind in ["airlock", "vehicle_bay", "solar", "corridor"]):
		_r_held = 0.0
		return
	_r_held += delta
	if _r_held < .4: return
	_r_repeat -= delta
	if _r_repeat <= 0.0:
		_r_repeat = .33
		_rotate_airlock()
		_refresh_catalogue()

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
	_refresh_mode_switcher()
	var player:=world.get_node("Player"); player.set_meta("build_mode_active",build_mode)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if build_mode else Input.MOUSE_MODE_CAPTURED
	if not build_mode:
		dragging=false; _draw_preview([],false)
		# Leave the player exactly where they were when the plan view was opened.
		# Build mode is a camera/tool mode, not a teleport or respawn.
		player.velocity=Vector3.ZERO

## True when the player stands inside a habitat zone, where Interior build works.
func player_can_furnish() -> bool:
	var player := world.get_node_or_null("Player") as Node3D
	return player != null and is_inside(player.global_position)

## Name of the room the player stands in ("" outside), for build-mode banners.
func player_room_label() -> String:
	if not player_can_furnish(): return ""
	var player := world.get_node("Player") as Node3D
	var zone := _zone_at_point(Vector2(player.global_position.x, player.global_position.z))
	return str(ZONE_TYPES.get(str(zone.get("kind", "")), {}).get("label", "Habitat"))

## Site plan → Interior. Leaves the plan view and hands over to the interior
## builder, or explains why it can't from here.
func _switch_to_interior() -> void:
	if not player_can_furnish():
		_flash_notice("warn", "Interior needs a room", "Your astronaut is outside. Walk into a room, then press B to furnish it.")
		return
	if build_mode: _toggle()
	interior_build_requested.emit()

func _refresh_mode_switcher() -> void:
	if _mode_switcher.is_empty(): return
	var interior_tab := _mode_switcher.interior as Button
	interior_tab.disabled = not player_can_furnish()
	interior_tab.tooltip_text = "Furnish the room your astronaut is standing in" if not interior_tab.disabled else "Your astronaut is outside. Walk into a room to furnish it."

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

func _world_point_at_mouse(plane_y := 0.0) -> Vector3:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(direction.y) < .001: return Vector3.INF
	return origin + direction * ((plane_y - origin.y) / direction.y)

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
	if kind in SITE_MACHINES: return [b]
	if kind=="corridor" and a.x!=b.x and a.y!=b.y: return out
	for x in range(mini(a.x,b.x),maxi(a.x,b.x)+1):
		for z in range(mini(a.y,b.y),maxi(a.y,b.y)+1): out.append(Vector2i(x,z))
	return out

func _freeform_mode_available() -> bool:
	return equipment_id.is_empty() and category == "rooms" and _is_ordinary_room_kind(kind)

func _freeform_active() -> bool:
	return tool == "place" and room_draw_mode == "freeform" and _freeform_mode_available()

func _is_ordinary_room_kind(zone_kind: String) -> bool:
	return zone_kind not in NON_ROOM_KINDS

func _try_place_angled_outline_connector() -> bool:
	var world_point := _world_point_at_mouse(habitat_base_y)
	if is_inf(world_point.x): return false
	var mount := _angled_outline_mount_at(Vector2(world_point.x, world_point.z))
	if mount.is_empty(): return false
	var reason := _angled_outline_mount_invalid_reason(mount)
	if not reason.is_empty():
		_flash_notice("invalid", "Can't place here", reason + ".")
		return true
	var zone := {"kind": kind, "cells": [], "angled_mount": mount, "door_direction": airlock_direction, "cost": cell_cost(kind)}
	zones.append(zone)
	_history.append({"type": "zone", "zone": zone})
	_rebuild()
	MHAudio.sfx("place")
	return true

func _begin_angled_corridor_drag() -> bool:
	var world_point := _world_point_at_mouse(habitat_base_y)
	if is_inf(world_point.x): return false
	var mount := _angled_outline_mount_at(Vector2(world_point.x, world_point.z))
	if mount.is_empty(): return false
	angled_corridor_mount = mount
	dragging = true
	return true

func _angled_corridor_length(mount: Dictionary, point: Vector2) -> float:
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	# Whole diagonal cells (4.24 m): starting from the middle of a diagonal
	# cell, the far end then lands on the middle of another, where a one-cell
	# 45° wall of the next room fits exactly.
	var raw_length := (point - position).dot(outward)
	return float(clampi(roundi(raw_length / DIAGONAL_CELL), 1, 5)) * DIAGONAL_CELL

## Cargo bays an angled corridor of this length is charged as (3 m each).
func _angled_corridor_bays(length: float) -> int:
	return maxi(1, ceili(length / CELL - .01))

func _finish_angled_corridor_drag() -> void:
	var mount: Dictionary = angled_corridor_mount.duplicate(true)
	angled_corridor_mount = {}
	dragging = false
	var world_point := _world_point_at_mouse(habitat_base_y)
	if is_inf(world_point.x): return
	mount["length"] = _angled_corridor_length(mount, Vector2(world_point.x, world_point.z))
	var reason := _angled_outline_mount_invalid_reason(mount)
	if not reason.is_empty():
		_flash_notice("invalid", "Can't place here", reason + ".")
		return
	var bays := _angled_corridor_bays(float(mount.get("length", CELL)))
	var zone := {"kind": "corridor", "cells": [], "angled_mount": mount, "door_direction": airlock_direction, "cost": cell_cost("corridor") * bays}
	zones.append(zone)
	_history.append({"type": "zone", "zone": zone})
	_rebuild()
	MHAudio.sfx("place")

func _outline_outward_at(outline: PackedVector2Array, point: Vector2, tangent: Vector2) -> Vector2:
	var normal := Vector2(-tangent.y, tangent.x)
	var side_a := Geometry2D.is_point_in_polygon(point + normal * .15, outline)
	var side_b := Geometry2D.is_point_in_polygon(point - normal * .15, outline)
	if side_a == side_b:
		return Vector2.ZERO
	return -normal if side_a else normal

func _angled_outline_mount_at(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := ANGLED_MOUNT_REACH
	for zone_index in range(zones.size()):
		var zone: Dictionary = zones[zone_index]
		if not zone.has("outline"): continue
		var outline := zone_outline(zone)
		for edge_index in range(outline.size()):
			var start := outline[edge_index]
			var finish := outline[(edge_index + 1) % outline.size()]
			var edge := finish - start
			var length := edge.length()
			if length < CELL - .01: continue
			var tangent := edge / length
			if absf(absf(tangent.x) - absf(tangent.y)) > .01: continue
			# Only alongside this 45° wall: past either end the cursor is beside
			# the neighbouring wall, where grid pieces belong.
			var raw_along := (point - start).dot(tangent)
			if raw_along < 0.0 or raw_along > length: continue
			var along := raw_along
			var distance := point.distance_to(start + tangent * along)
			if distance >= best_distance: continue
			# Centre the doorway on the middle of the diagonal cell under the cursor,
			# so it always clears the corners and lines up with the cell lattice.
			var cells_along := roundi(length / DIAGONAL_CELL)
			var doorway_centre := clampf(along, CELL * .5, length - CELL * .5)
			if cells_along >= 1 and absf(length - cells_along * DIAGONAL_CELL) < .05:
				doorway_centre = (float(clampi(floori(along / DIAGONAL_CELL), 0, cells_along - 1)) + .5) * DIAGONAL_CELL
			var outward := _outline_outward_at(outline, start + tangent * doorway_centre, tangent)
			if outward == Vector2.ZERO: continue
			best_distance = distance
			best = {"host_zone": zone_index, "edge_index": edge_index, "edge_start": start, "edge_finish": finish, "position": start + tangent * doorway_centre, "tangent": tangent, "outward": outward, "opening_start": doorway_centre - CELL * .5, "opening_end": doorway_centre + CELL * .5}
	return best

func _angled_outline_mount_invalid_reason(mount: Dictionary) -> String:
	var mount_length := float(mount.get("length", CELL))
	var mount_cost := cell_cost(kind) * (_angled_corridor_bays(mount_length) if kind == "corridor" else 1)
	if _used_cargo() + earth_cost(mount_cost, zone_printable(kind)) > MHGame.cargo_budget(): return "Not enough cargo left"
	for sample in _outline_site_samples(_angled_mount_outline(mount)):
		var site_reason := MHSiteTerrain.unbuildable_reason(sample)
		if not site_reason.is_empty(): return site_reason
	var host_index := int(mount.get("host_zone", -1))
	if host_index < 0 or host_index >= zones.size(): return "No room to attach to"
	var host_outline := zone_outline(zones[host_index])
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT)
	var outward: Vector2 = mount.get("outward", Vector2.ZERO)
	var edge_start: Vector2 = mount.get("edge_start", Vector2.ZERO)
	var edge_finish: Vector2 = mount.get("edge_finish", Vector2.ZERO)
	var edge_length := edge_start.distance_to(edge_finish)
	if float(mount.get("opening_start", 0.0)) < ANGLED_CORNER_CLEARANCE or float(mount.get("opening_end", 0.0)) > edge_length - ANGLED_CORNER_CLEARANCE:
		return "Too close to a corner"
	for offset in [-1.0, 0.0, 1.0]:
		var p: Vector2 = position + tangent * (CELL * .5 * float(offset))
		if not Geometry2D.is_point_in_polygon(p - outward * .3, host_outline): return "Doorway must sit fully on one wall"
		if Geometry2D.is_point_in_polygon(p + outward * .3, host_outline): return "Door would lead outside to outside"
	var proposed_outline := _angled_mount_outline(mount)
	if _polygons_overlap_area(proposed_outline, host_outline): return "Connector overlaps its own room"
	var far_beyond := position + outward * (mount_length + .3)
	if kind == "corridor":
		# A corridor may run on into another room, but only by meeting one of
		# its 45° walls square-on, clear of the corners.
		if _angled_far_end_target(mount).is_empty() and not _zone_at_point(far_beyond).is_empty(): return "Corridor end must meet a 45° wall square-on, clear of its corners"
	elif not _zone_at_point(far_beyond).is_empty(): return "Outer door would open into another room"
	for index in range(zones.size()):
		if index == host_index: continue
		var zone: Dictionary = zones[index]
		if zone.has("angled_mount"):
			if _polygons_overlap_area(proposed_outline, _angled_mount_outline(zone.get("angled_mount", {}))): return "Overlaps an angled connector"
			continue
		if zone.has("outline"):
			if _polygons_overlap_area(proposed_outline, zone_outline(zone)): return "Connector overlaps another room"
			continue
		for cell in zone.get("cells", []):
			if _polygons_overlap_area(proposed_outline, _freeform_cell_polygon(cell)): return "Connector overlaps existing habitat"
	return ""

## The mount with host_zone/edge_index/opening refreshed from the free-form
## wall its doorway actually sits on; empty when no such wall remains.
func _resolve_angled_host(mount: Dictionary) -> Dictionary:
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	for zone_index in range(zones.size()):
		if not zones[zone_index].has("outline"): continue
		var outline := zone_outline(zones[zone_index])
		if not Geometry2D.is_point_in_polygon(position - outward * .3, outline): continue
		for edge_index in range(outline.size()):
			var a := outline[edge_index]
			var b := outline[(edge_index + 1) % outline.size()]
			var length := a.distance_to(b)
			if length < .01: continue
			var t := (b - a) / length
			if absf(t.cross(tangent)) > .01 or absf(t.cross(position - a)) > .05: continue
			var along := (position - a).dot(t)
			if along < -.01 or along > length + .01: continue
			var resolved := mount.duplicate(true)
			resolved.merge({"host_zone": zone_index, "edge_index": edge_index, "edge_start": a, "edge_finish": b, "opening_start": along - HALF_CELL, "opening_end": along + HALF_CELL}, true)
			return resolved
	return {}

## The free-form 45° wall an angled corridor's far end meets square-on, as a
## doorway {zone_index, edge_index, opening_start, opening_end}; empty if none.
func _angled_far_end_target(mount: Dictionary) -> Dictionary:
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	var far := position + outward * float(mount.get("length", CELL))
	for zone_index in range(zones.size()):
		if zone_index == int(mount.get("host_zone", -1)) or not zones[zone_index].has("outline"): continue
		var outline := zone_outline(zones[zone_index])
		if not Geometry2D.is_point_in_polygon(far + outward * .3, outline): continue
		for edge_index in range(outline.size()):
			var a := outline[edge_index]
			var b := outline[(edge_index + 1) % outline.size()]
			var length := a.distance_to(b)
			if length < .01: continue
			var t := (b - a) / length
			if absf(t.cross(tangent)) > .01 or absf(t.cross(far - a)) > .05: continue
			var along := (far - a).dot(t)
			if along - HALF_CELL < ANGLED_CORNER_CLEARANCE - .01 or along + HALF_CELL > length - ANGLED_CORNER_CLEARANCE + .01: continue
			return {"zone_index": zone_index, "edge_index": edge_index, "opening_start": along - HALF_CELL, "opening_end": along + HALF_CELL}
	return {}

func _angled_mount_outline(mount: Dictionary) -> PackedVector2Array:
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT).normalized()
	var outward: Vector2 = mount.get("outward", Vector2.UP).normalized()
	var length := float(mount.get("length", CELL))
	return PackedVector2Array([
		position - tangent * CELL * .5,
		position + tangent * CELL * .5,
		position + tangent * CELL * .5 + outward * length,
		position - tangent * CELL * .5 + outward * length
	])

func _cancel_freeform() -> void:
	freeform_points = PackedVector2Array()
	dragging = false
	_preview_key = ""
	_draw_preview([], false)

## Nearest construction-cell corner. Free-form corners live only on this 3 m
## lattice, so every straight wall lies on a cell face (where grid corridors,
## airlocks and rooms can meet it) and every diagonal runs corner to corner.
static func snap_to_cell_corner(point: Vector2) -> Vector2:
	return Vector2(roundf((point.x - HALF_CELL) / CELL) * CELL + HALF_CELL, roundf((point.y - HALF_CELL) / CELL) * CELL + HALF_CELL)

func _freeform_cursor_point() -> Vector2:
	var world_point := _world_point_at_mouse(habitat_base_y if not zones.is_empty() else 0.0)
	if is_inf(world_point.x): return Vector2.INF
	var raw := Vector2(world_point.x, world_point.z)
	var point := snap_to_cell_corner(raw)
	if freeform_points.is_empty(): return point
	# Walls run straight or at exactly 45°: offer the horizontal, vertical and
	# diagonal corners from the last point and take the one nearest the cursor.
	var last := freeform_points[freeform_points.size() - 1]
	var steps := Vector2i(roundi((point.x - last.x) / CELL), roundi((point.y - last.y) / CELL))
	var diagonal := maxi(absi(steps.x), absi(steps.y))
	var direction := Vector2(1.0 if steps.x >= 0 else -1.0, 1.0 if steps.y >= 0 else -1.0)
	var candidates := PackedVector2Array([Vector2(point.x, last.y), Vector2(last.x, point.y), last + direction * diagonal * CELL])
	var closest := candidates[0]
	for candidate in candidates:
		if raw.distance_squared_to(candidate) < raw.distance_squared_to(closest): closest = candidate
	return closest

func _freeform_wall_angle(cursor: Vector2) -> String:
	if freeform_points.is_empty() or is_inf(cursor.x): return "0°"
	var delta := cursor - freeform_points[freeform_points.size() - 1]
	if delta.length_squared() < .0001: return "0°"
	var degrees := roundi(rad_to_deg(atan2(delta.y, delta.x)))
	if degrees < 0: degrees += 360
	if degrees > 180: degrees = 360 - degrees
	return "%d°" % degrees

func _add_freeform_point() -> void:
	var point := _freeform_cursor_point()
	if is_inf(point.x): return
	if freeform_points.size() >= 3 and point.distance_to(freeform_points[0]) < .01:
		_finish_freeform()
		return
	if not freeform_points.is_empty() and point.distance_to(freeform_points[freeform_points.size() - 1]) < .01:
		return
	freeform_points.append(point)

func _finish_freeform() -> void:
	var reason := freeform_invalid_reason(freeform_points)
	if not reason.is_empty():
		_flash_notice("invalid", "Can't place here", reason + ".")
		return
	var cells := _freeform_cells(freeform_points)
	if zones.is_empty(): habitat_base_y = _proposed_freeform_base_y(freeform_points)
	var zone := {"kind": kind, "cells": cells, "outline": freeform_points.duplicate(), "door_direction": airlock_direction, "cost": _freeform_cost(freeform_points)}
	zones.append(zone)
	_history.append({"type": "zone", "zone": zone})
	_cancel_freeform()
	_rebuild()
	_after_room_placed()
	MHAudio.sfx("place")

func _freeform_area(points: PackedVector2Array) -> float:
	if points.size() < 3: return 0.0
	var twice_area := 0.0
	for index in range(points.size()):
		var next := points[(index + 1) % points.size()]
		twice_area += points[index].x * next.y - next.x * points[index].y
	return absf(twice_area) * .5

func _freeform_perimeter(points: PackedVector2Array) -> float:
	if points.size() < 2: return 0.0
	var length := 0.0
	for index in range(points.size() - 1): length += points[index].distance_to(points[index + 1])
	if points.size() >= 3: length += points[points.size() - 1].distance_to(points[0])
	return length

func _freeform_current_wall_length(cursor: Vector2) -> float:
	if freeform_points.is_empty() or is_inf(cursor.x): return 0.0
	return freeform_points[freeform_points.size() - 1].distance_to(cursor)

func _freeform_cost(points: PackedVector2Array) -> int:
	return ceili(_freeform_area(points) * cell_cost(kind) / (CELL * CELL))

func _freeform_cells(points: PackedVector2Array) -> Array:
	var cells: Array = []
	if points.size() < 3: return cells
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	for x in range(floori(bounds.position.x / CELL) - 1, ceili(bounds.end.x / CELL) + 2):
		for z in range(floori(bounds.position.y / CELL) - 1, ceili(bounds.end.y / CELL) + 2):
			var cell := Vector2i(x, z)
			if Geometry2D.is_point_in_polygon(Vector2(cell.x * CELL, cell.y * CELL), points): cells.append(cell)
	return cells

func _freeform_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var half := CELL * .5
	var centre := Vector2(cell.x * CELL, cell.y * CELL)
	return PackedVector2Array([centre + Vector2(-half, -half), centre + Vector2(half, -half), centre + Vector2(half, half), centre + Vector2(-half, half)])

func freeform_invalid_reason(points: PackedVector2Array) -> String:
	if points.size() < 3: return "Place at least 3 points"
	for index in range(points.size()):
		if points[index].distance_to(points[(index + 1) % points.size()]) < 2.0: return "Each wall must be at least 2 m"
	for first in range(points.size()):
		var first_end := (first + 1) % points.size()
		for second in range(first + 1, points.size()):
			var second_end := (second + 1) % points.size()
			if first == second or first_end == second or second_end == first: continue
			if Geometry2D.segment_intersects_segment(points[first], points[first_end], points[second], points[second_end]) != null: return "Walls cannot cross"
	var area := _freeform_area(points)
	if area < 9.0: return "Room must be at least 9 m²"
	for sample in _outline_site_samples(points):
		var site_reason := MHSiteTerrain.unbuildable_reason(sample)
		if not site_reason.is_empty(): return site_reason
	var player := world.get_node_or_null("Player") as Node3D
	if player != null and Geometry2D.is_point_in_polygon(Vector2(roundi(player.global_position.x / CELL) * CELL, roundi(player.global_position.z / CELL) * CELL), points): return "Move clear of the player before building"
	# Rooms may share walls with anything; corners all sit on the cell lattice,
	# so touching walls line up exactly. Only real floor overlap is rejected.
	for zone in zones:
		if zone.has("angled_mount"):
			if _polygons_overlap_area(points, _angled_mount_outline(zone.get("angled_mount", {}))): return "Overlaps an angled corridor or airlock"
		elif zone.has("outline"):
			if _polygons_overlap_area(points, zone_outline(zone)): return "Overlaps existing habitat"
		else:
			for cell in zone.get("cells", []):
				if _polygons_overlap_area(points, _freeform_cell_polygon(cell)): return "Overlaps existing habitat"
	if _used_cargo() + earth_cost(_freeform_cost(points), zone_printable(kind)) > MHGame.cargo_budget(): return "Not enough cargo left"
	if is_inside_tree():
		var base_y := habitat_base_y if not zones.is_empty() else _proposed_freeform_base_y(points)
		var samples := points.duplicate()
		var centre := Vector2.ZERO
		for point in points: centre += point
		centre /= points.size()
		samples.append(centre)
		for sample in samples:
			var terrain := _terrain_height(Vector3(sample.x, 0, sample.y))
			if terrain > base_y + .12: return "Ground is too high here"
			if terrain < base_y - 1.85: return "Ground drops away too far"
	return ""

## Points checked against the site's build area for an outline: corners, every
## 1.5 m along each wall, and every cell centre inside.
func _outline_site_samples(points: PackedVector2Array) -> PackedVector2Array:
	var samples := PackedVector2Array()
	for index in range(points.size()):
		var start := points[index]
		var finish := points[(index + 1) % points.size()]
		var steps := maxi(1, ceili(start.distance_to(finish) / HALF_CELL))
		for step in range(steps): samples.append(start.lerp(finish, float(step) / float(steps)))
	for cell in _freeform_cells(points): samples.append(Vector2(cell.x * CELL, cell.y * CELL))
	return samples

func _proposed_freeform_base_y(points: PackedVector2Array) -> float:
	if not is_inside_tree(): return .35
	var highest := -.50
	for point in points: highest = maxf(highest, _terrain_height(Vector3(point.x, 0, point.y)))
	var centre := Vector2.ZERO
	for point in points: centre += point
	if not points.is_empty(): highest = maxf(highest, _terrain_height(Vector3(centre.x / points.size(), 0, centre.y / points.size())))
	return highest + .35

func _occupied(cell: Vector2i) -> bool:
	for zone in zones:
		if zone.has("outline"): continue
		if cell in zone.cells: return true
	return false

func _zone_at(cell: Vector2i) -> Dictionary:
	for zone in zones:
		if zone.has("outline"): continue
		if cell in zone.cells: return zone
	return {}

func _zone_at_point(point: Vector2) -> Dictionary:
	for zone in zones:
		if _point_in_zone(point, zone): return zone
	return {}

func _point_in_zone(point: Vector2, zone: Dictionary) -> bool:
	if zone.has("angled_mount"): return _point_in_angled_mount(point, zone.get("angled_mount", {}))
	if zone.has("outline"): return Geometry2D.is_point_in_polygon(point, zone_outline(zone))
	return Vector2i(roundi(point.x / CELL), roundi(point.y / CELL)) in zone.get("cells", [])

func _point_in_angled_mount(point: Vector2, mount: Dictionary) -> bool:
	var origin: Vector2 = mount.get("position", Vector2.ZERO)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT)
	var length := float(mount.get("length", CELL))
	var relative := point - (origin + outward * length * .5)
	return absf(relative.dot(outward)) <= length * .5 and absf(relative.dot(tangent)) <= CELL * .5

func _is_habitat_zone(zone: Dictionary) -> bool:
	if zone.is_empty(): return false
	var zone_kind := str(zone.kind)
	# Power sources sit outside the pressure hull.  They must not erase an
	# exterior wall simply because their build cell touches one.
	return not zone_kind in SITE_MACHINES

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
	if entry.is_empty() or _used_cargo() + earth_cost(int(entry.get("cargo_cost", 0)), item_printable(id)) > MHGame.cargo_budget():
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
		# Whatever stood on it comes off with it.
		for resting in items_resting_on(item):
			remove_free_interior_equipment(str(resting.get("placement_id", "")))
		index = placed_interior.find(item)
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

## Why an already-placed item couldn't sit at a new spot ("" if it can),
## judged as if it weren't where it is now (GAR-Y moving clutter).
func free_interior_move_reason(placement_id: String, world_position: Vector3, rotation_y: float) -> String:
	var index := placed_interior.find_custom(func(item): return str(item.get("placement_id", "")) == placement_id)
	if index < 0: return "Not placed"
	var item: Dictionary = placed_interior[index]
	placed_interior.remove_at(index)
	var reason := free_interior_invalid_reason(str(item.id), world_position, Vector3.UP, rotation_y)
	placed_interior.insert(index, item)
	return reason

## Moves a placed item (and its visual) to a new legal spot; saved like any change.
func move_free_interior_equipment(placement_id: String, world_position: Vector3, rotation_y: float) -> bool:
	if not free_interior_move_reason(placement_id, world_position, rotation_y).is_empty(): return false
	for item in placed_interior:
		if str(item.get("placement_id", "")) != placement_id: continue
		item.position = world_position
		item.rotation_y = rotation_y
		item.zone_cell = Vector2i(roundi(world_position.x / CELL), roundi(world_position.z / CELL))
	for child in furnishing.get_children():
		if str(child.get_meta("interior_placement_id", "")) == placement_id:
			(child as Node3D).global_position = world_position
			(child as Node3D).rotation = Vector3(0, rotation_y, 0)
	habitat_changed.emit()
	return true

func free_interior_invalid_reason(id: String, world_position: Vector3, surface_normal: Vector3, rotation_y := 0.0) -> String:
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty(): return "Unknown interior item"
	if not MHMissions.item_unlocked(id): return "Not delivered yet: this arrives in a later mission"
	var sample := world_position + Vector3.UP * .35
	if not is_inside(sample): return "Must be placed inside a completed habitat room"
	var zone := _zone_at_point(Vector2(world_position.x, world_position.z))
	var valid_zones: Array = entry.get("valid_zones", [])
	if not valid_zones.has(str(zone.get("kind", ""))): return "Fits in %s" % _zone_list_text(valid_zones)
	var placement := str(entry.get("placement", "floor"))
	if placement == "floor" and surface_normal.dot(Vector3.UP) < .82: return "Place this on the floor"
	if placement == "wall" and absf(surface_normal.dot(Vector3.UP)) > .28: return "Mount this on an interior wall"
	if placement == "ceiling" and surface_normal.dot(Vector3.UP) > -.82: return "Mount this on the ceiling"
	# Above the floor: only small items, and only on a table, desk, counter,
	# shelf or crate, with room under the shelf above.
	var support := {}
	if placement in ["floor", "floor_wall"] and world_position.y > habitat_base_y + .2:
		if not bool(entry.get("stackable", false)): return "Place this on the floor"
		support = stack_support(id, world_position, rotation_y)
		if support.is_empty(): return "Set this on a table, desk, counter, shelf or crate"
		if world_position.y + _free_interior_size(entry).y > _headroom(support, world_position.y): return "Too tall for this shelf"
	if _used_cargo() + earth_cost(int(entry.get("cargo_cost", 0)), item_printable(id)) > MHGame.cargo_budget(): return "Not enough cargo left"
	# A free-positioned item must fit wholly inside valid room cells. Checking the
	# four footprint corners prevents a player from burying it in the shell wall
	# or bleeding it across into an incompatible room.
	if placement == "floor" or placement == "floor_wall":
		# Catalogue footprints describe a coarse grid slot.  Free placement needs a
		# closer approximation to the delivered model, otherwise a clear gap reads
		# as a collision to the player.
		var size := _free_interior_size(entry)
		var footprint := Vector2(size.x * .5, size.z * .5)
		var facing := Vector2(cos(rotation_y), -sin(rotation_y))   # node rotation.y: local x -> (cos, -sin) on the ground
		var side := Vector2(-facing.y, facing.x)
		for sign_x in [-1.0, 1.0]:
			for sign_z in [-1.0, 1.0]:
				var corner: Vector2 = Vector2(world_position.x, world_position.z) + facing * footprint.x * sign_x + side * footprint.y * sign_z
				var corner_in_valid_room := false
				for candidate in zones:
					var candidate_kind := str(candidate.get("kind", ""))
					if candidate_kind in SITE_MACHINES:
						continue
					# Bays, airlocks and corridors are cells (or angled mounts), not outlines.
					var inside := _point_in_zone(corner, candidate) if candidate_kind in ["airlock", "corridor", "vehicle_bay"] else Geometry2D.is_point_in_polygon(corner, zone_outline(candidate))
					if valid_zones.has(candidate_kind) and inside:
						corner_in_valid_room = true
						break
				if not corner_in_valid_room:
					return "Doesn't fit inside this room"
		for item in placed_interior:
			var other_entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
			var other_size := _free_interior_size(other_entry)
			var other_position: Vector3 = item.get("position", Vector3.ZERO)
			var other_rotation := float(item.get("rotation_y", 0.0))
			if item == support: continue
			# Stacked: one sits on top of the other, so their heights don't meet.
			if world_position.y >= other_position.y + _occupied_height(other_entry) - .03 or world_position.y + size.y <= other_position.y + .03:
				continue
			# Test the actual rotated floor footprints rather than a circular
			# approximation. It permits neat adjacent rows but catches the visual
			# intersections that the previous forgiving radius allowed.
			if _interior_footprints_overlap(world_position, size, rotation_y, other_position, other_size, other_rotation):
				return "Too close to existing equipment"
		if _partition_crossing(world_position, size, rotation_y) >= 0:
			return "Blocked by a partition wall"
	return ""

## How high an item fills: up to its working top for tables, desks and
## crates (things stand on that), otherwise its full height. Shelving fills
## its full height: things go on its shelves, not beside them.
func _occupied_height(entry: Dictionary) -> float:
	var tops := surface_tops(entry)
	return tops[0] if tops.size() == 1 else _free_interior_size(entry).y

## Heights (above its base) that things can stand on: one working top, or
## every shelf of a shelving unit.
func surface_tops(entry: Dictionary) -> Array:
	if entry.has("surface_heights"): return entry.surface_heights
	var top := float(entry.get("surface_height", 0.0))
	return [top] if top > 0.0 else []

## The top of anything standing on this surface at height y: the underside
## of the next shelf up (shelves are 2.5 cm thick), or no limit.
func _headroom(support: Dictionary, y: float) -> float:
	var base := (support.get("position", Vector3.ZERO) as Vector3).y
	var limit := INF
	for top in surface_tops(EquipmentCatalog.get_entry(str(support.get("id", "")))):
		if base + float(top) > y + .05: limit = minf(limit, base + float(top) - .025 + .01)
	return limit

## The table, desk, counter or crate a small item would rest on at this spot,
## or {} if none. Its whole footprint has to sit on that top.
func stack_support(id: String, world_position: Vector3, rotation_y: float) -> Dictionary:
	var size := _free_interior_size(EquipmentCatalog.get_entry(id))
	for item in placed_interior:
		var other := EquipmentCatalog.get_entry(str(item.get("id", "")))
		var at: Vector3 = item.get("position", Vector3.ZERO)
		for top in surface_tops(other):
			if absf(at.y + float(top) - world_position.y) > .05: continue
			if _rests_within(world_position, size, rotation_y, at, _surface_size(other), float(item.get("rotation_y", 0.0))):
				return item
	return {}

## Items resting on this one (placed on its top).
func items_resting_on(item: Dictionary) -> Array:
	var resting: Array = []
	var other := EquipmentCatalog.get_entry(str(item.get("id", "")))
	var at: Vector3 = item.get("position", Vector3.ZERO)
	for top in surface_tops(other):
		for candidate in placed_interior:
			var position: Vector3 = candidate.get("position", Vector3.ZERO)
			if candidate == item or absf(at.y + float(top) - position.y) > .05: continue
			if _rests_within(position, Vector3(.02, 0, .02), 0.0, at, _surface_size(other), float(item.get("rotation_y", 0.0))):
				resting.append(candidate)
	return resting

## The usable top of a surface item (width, depth), centred on it.
func _surface_size(entry: Dictionary) -> Vector2:
	var given: Array = entry.get("surface_size", [])
	if given.size() == 2: return Vector2(float(given[0]), float(given[1]))
	var size := _free_interior_size(entry)
	return Vector2(size.x, size.z)

## True when a rotated footprint lies on a rotated top (with a little overhang).
func _rests_within(at: Vector3, size: Vector3, rotation_y: float, top_at: Vector3, top_size: Vector2, top_rotation: float) -> bool:
	var facing := Vector2(cos(rotation_y), -sin(rotation_y))
	var side := Vector2(-facing.y, facing.x)
	var top_facing := Vector2(cos(top_rotation), -sin(top_rotation))
	var top_side := Vector2(-top_facing.y, top_facing.x)
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			var corner: Vector2 = Vector2(at.x - top_at.x, at.z - top_at.z) + facing * size.x * .5 * sign_x + side * size.z * .5 * sign_z
			if absf(corner.dot(top_facing)) > top_size.x * .5 + .06 or absf(corner.dot(top_side)) > top_size.y * .5 + .06:
				return false
	return true

## Index of the first partition whose panel overlaps a rotated floor footprint, or -1.
func _partition_crossing(at: Vector3, size: Vector3, rotation_y: float) -> int:
	for index in range(partitions.size()):
		var segment: Dictionary = partitions[index]
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var mid := (a + b) * .5
		if _interior_footprints_overlap(at, size, rotation_y, Vector3(mid.x, 0, mid.y), Vector3((b - a).length(), 0, PARTITION_THICKNESS), -atan2((b - a).y, (b - a).x)):
			return index
	return -1

func _interior_footprints_overlap(first_position: Vector3, first_size: Vector3, first_rotation: float, second_position: Vector3, second_size: Vector3, second_rotation: float) -> bool:
	var first_forward := Vector2(cos(first_rotation), -sin(first_rotation))
	var first_side := Vector2(-first_forward.y, first_forward.x)
	var second_forward := Vector2(cos(second_rotation), -sin(second_rotation))
	var second_side := Vector2(-second_forward.y, second_forward.x)
	var offset := Vector2(second_position.x - first_position.x, second_position.z - first_position.z)
	# A small practical breathing gap avoids z-fighting and makes removal sane,
	# without wasting the several metres imposed by the old distance test.
	for axis in [first_forward, first_side, second_forward, second_side]:
		var first_radius := absf(axis.dot(first_forward)) * first_size.x * .5 + absf(axis.dot(first_side)) * first_size.z * .5
		var second_radius := absf(axis.dot(second_forward)) * second_size.x * .5 + absf(axis.dot(second_side)) * second_size.z * .5
		if absf(offset.dot(axis)) >= first_radius + second_radius + .02:
			return false
	return true

## Room culling: furniture is the biggest drawing cost (about 40 meshes an
## item), so only what you could see is drawn. Inside, that's your room, any
## room seen through an open interior door, and anything within a few metres;
## outside, what's near enough to glimpse through a window; in the site plan,
## everything. MarsWorld calls this a few times a second.
const FURNITURE_NEAR := 5.0
const FURNITURE_OUTSIDE := 18.0

func update_furniture_visibility(eye: Vector3) -> void:
	if furnishing == null: return
	if build_mode:
		for child in furnishing.get_children(): (child as Node3D).visible = true
		return
	var here: Dictionary = _zone_at_point(Vector2(eye.x, eye.z)) if is_inside(eye) else {}
	var rooms := {}
	if not here.is_empty():
		rooms[zones.find(here)] = true
		# Through open doors (twice, to see a room beyond a corridor).
		for pass_index in 2:
			for node in get_tree().get_nodes_in_group("airlock_door"):
				var door := node as AirlockDoor
				if door == null or door.is_closed(): continue
				var at := door.global_position
				for axis in [Vector2(1.2, 0), Vector2(0, 1.2)]:
					var a: Dictionary = _zone_at_point(Vector2(at.x, at.z) - axis)
					var b: Dictionary = _zone_at_point(Vector2(at.x, at.z) + axis)
					if a.is_empty() or b.is_empty() or a == b: continue
					if rooms.has(zones.find(a)) or rooms.has(zones.find(b)):
						rooms[zones.find(a)] = true
						rooms[zones.find(b)] = true
	var item_rooms := {}
	for item in placed_interior:
		var at: Vector3 = item.get("position", Vector3.ZERO)
		item_rooms[str(item.get("placement_id", ""))] = zones.find(_zone_at_point(Vector2(at.x, at.z)))
	for child in furnishing.get_children():
		var visual := child as Node3D
		var distance := visual.global_position.distance_to(eye)
		var show := distance < FURNITURE_NEAR
		if not show:
			show = rooms.has(item_rooms.get(str(visual.get_meta("interior_placement_id", "")), -2)) if not here.is_empty() else distance < FURNITURE_OUTSIDE
		visual.visible = show

## Furniture is only drawn within this distance of the camera: across the
## base or behind walls it costs nothing (outdoor props get further).
const INTERIOR_DRAW_DISTANCE := 30.0
const SURFACE_DRAW_DISTANCE := 90.0

static func set_draw_distance(node: Node, distance: float) -> void:
	for geometry in node.find_children("*", "GeometryInstance3D", true, false):
		var instance := geometry as GeometryInstance3D
		instance.visibility_range_end = distance
		instance.visibility_range_end_margin = 2.0

func free_interior_visual(id: String, position: Vector3, rotation_y: float) -> Node3D:
	var entry := EquipmentCatalog.get_entry(id)
	var size := _free_interior_size(entry)
	var holder := Node3D.new()
	holder.position = position
	holder.rotation.y = rotation_y
	var body := StaticBody3D.new()
	body.name = "InteriorCollision"
	# Wall items hang centred on the aimed point and stand out from the wall.
	body.position = Vector3(0, 0, -size.z * .5) if str(entry.get("placement", "floor")) == "wall" else Vector3(0, size.y * .5, 0)
	body.collision_layer = 1
	holder.add_child(body)
	var model_loaded := false
	var model_has_collision := false
	var asset_path := str(entry.get("asset_scene", ""))
	if not asset_path.is_empty() and (ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)):
		var resource := load(asset_path)
		if resource is PackedScene:
			var model := (resource as PackedScene).instantiate() as Node3D
			if model != null:
				model.name = "Model"
				model.rotation.x = float(entry.get("model_rotation_x", 0.0))
				model.rotation.z = float(entry.get("model_rotation_z", 0.0))
				# Lets one model serve a second mounting (a floor kit hung on a wall).
				var model_offset: Array = entry.get("model_offset", [])
				if model_offset.size() == 3: model.position = Vector3(float(model_offset[0]), float(model_offset[1]), float(model_offset[2]))
				# Items with an interaction rig (asset packs) handle themselves; the
				# generic inspect wrapper is only for older un-rigged models.
				var interaction_note := str(entry.get("interaction_note", "")) if EquipmentCatalog.rig(id).is_empty() else ""
				if not interaction_note.is_empty():
					var interactable := MHEquipmentInteractable.new()
					interactable.display_name = str(entry.get("label", id))
					interactable.primary_action = str(entry.get("primary_action", "Read"))
					interactable.educational_note = interaction_note
					holder.add_child(interactable)
					interactable.add_child(model)
					body.set_meta("interaction_target", interactable)
				else:
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
	# Rigged items show power through their own lamps; the status lamp is for un-rigged models.
	if EquipmentCatalog.rig(id).is_empty() and int(EquipmentCatalog.effects(id).get("power_draw", 0)) > 0 and (not model_loaded or not _bind_equipment_power_visuals(holder)):
		_add_equipment_power_lamp(body, size)
	set_draw_distance(holder, INTERIOR_DRAW_DISTANCE)
	return holder

## The first-person palette is an art-facing build surface. Do not advertise a
## catalogue plan whose final scene has not arrived yet; greybox fallback stays
## available for automated systems and future development only.
func interior_asset_available(id: String) -> bool:
	var entry := EquipmentCatalog.get_entry(id)
	var asset_path := str(entry.get("asset_scene", ""))
	# ResourceLoader only recognises imported scenes in some headless startup
	# orders. The source file check keeps delivered GLBs selectable while their
	# import is being indexed; load() still guards instantiation below.
	return not asset_path.is_empty() and (ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path))

## Empty when `id` can be placed in `cell`; otherwise a short hologram reason.
func equipment_invalid_reason(id: String, cell: Vector2i) -> String:
	var entry := EquipmentCatalog.get_entry(id)
	if entry.is_empty(): return "Unknown equipment"
	var zone := _zone_at(cell)
	if not _is_habitat_zone(zone): return "Point at a room"
	var valid_zones: Array = entry.get("valid_zones", [])
	if not valid_zones.has(str(zone.kind)): return "Fits in %s" % _zone_list_text(valid_zones)
	if not equipment_at(cell).is_empty(): return "This cell is already furnished"
	if _used_cargo() + earth_cost(int(entry.get("cargo_cost", 0)), item_printable(id)) > MHGame.cargo_budget(): return "Not enough cargo left"
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
	var left := MHGame.cargo_budget() - _used_cargo()
	if left < MHGame.cargo_budget() * .1: _flash_notice("warn", "Cargo is getting tight", "%s left." % MHStyle.kg(left))

# Equipment whose room was removed goes with it, so its cargo is refunded too.
func _prune_equipment() -> int:
	var refund := 0
	for index in range(placed_equipment.size() - 1, -1, -1):
		var item: Dictionary = placed_equipment[index]
		var cell: Vector2i = item.get("cell", Vector2i(9999, 9999))
		var zone := _zone_at_point(Vector2(cell.x * CELL, cell.y * CELL))
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
		# Use the item's own position: beside a 45° wall its grid cell's centre
		# can fall outside an angled room even though the item is inside.
		var item_position: Vector3 = item.get("position", Vector3(cell.x * CELL, 0, cell.y * CELL))
		var zone := _zone_at_point(Vector2(item_position.x, item_position.z))
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		var valid_zones: Array = entry.get("valid_zones", [])
		var wall_lost := false
		if str(entry.get("placement", "floor")) == "wall" and item.has("anchor_normal"):
			# A wall mount remains valid while a physical wall occupies its boundary.
			# A neighbouring sealed room still supplies that wall; an explicit
			# interior door replaces it and correctly releases the mounted item.
			var anchor: Vector3 = item.get("anchor_normal", Vector3.ZERO) as Vector3
			var outward := Vector2i(-roundi(anchor.x), -roundi(anchor.z))
			if abs(outward.x) + abs(outward.y) != 1:
				wall_lost = true
			else:
				var other_cell := cell + outward
				wall_lost = not (_should_build_wall(cell, outward) or _should_build_wall(other_cell, -outward))
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

func _free_interior_size(entry: Dictionary) -> Vector3:
	# Delivered packs give the model's real size; use it as the footprint.
	var measured: Array = entry.get("size_m", [])
	if measured.size() == 3: return Vector3(float(measured[0]), float(measured[1]), float(measured[2]))
	var size := _equipment_size(entry)
	# Models occupy about three quarters of their old half-cell proxy.  Keep the
	# shell clearance check above, but allow deliberate, tidy rows of furniture.
	if str(entry.get("placement", "floor")) in ["floor", "floor_wall"]:
		size.x = maxf(.38, size.x * .74)
		size.z = maxf(.30, size.z * .74)
	return size

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
	if not asset_path.is_empty() and (ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)):
		var resource := load(asset_path)
		if resource is PackedScene:
			var model := (resource as PackedScene).instantiate() as Node3D
			if model != null:
				model.name = "Model"
				model.rotation.x = float(entry.get("model_rotation_x", 0.0))
				model.rotation.z = float(entry.get("model_rotation_z", 0.0))
				# Lets one model serve a second mounting (a floor kit hung on a wall).
				var model_offset: Array = entry.get("model_offset", [])
				if model_offset.size() == 3: model.position = Vector3(float(model_offset[0]), float(model_offset[1]), float(model_offset[2]))
				# Items with an interaction rig (asset packs) handle themselves; the
				# generic inspect wrapper is only for older un-rigged models.
				var interaction_note := str(entry.get("interaction_note", "")) if EquipmentCatalog.rig(id).is_empty() else ""
				if not interaction_note.is_empty():
					# GLB-only deliveries still get a compact, reticle-based readout.
					# Keeping the adapter as the model's parent also applies its
					# compatibility material pass to the delivered mesh hierarchy.
					var interactable := MHEquipmentInteractable.new()
					interactable.display_name = str(entry.get("label", id))
					interactable.primary_action = str(entry.get("primary_action", "Read"))
					interactable.educational_note = interaction_note
					interactable.position = offset
					holder.add_child(interactable)
					interactable.add_child(model)
					body.set_meta("interaction_target", interactable)
				else:
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
	# Rigged items show power through their own lamps; the status lamp is for un-rigged models.
	if EquipmentCatalog.rig(id).is_empty() and int(EquipmentCatalog.effects(id).get("power_draw", 0)) > 0 and (not model_loaded or not _bind_equipment_power_visuals(holder)):
		_add_equipment_power_lamp(body, size)
	set_draw_distance(holder, INTERIOR_DRAW_DISTANCE)
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
		var item_id := str(item.get("id", ""))
		var effects := EquipmentCatalog.effects(item_id)
		# Switched items: a lamp draws power only while on; a machine (scope
		# "all") produces and draws nothing while switched off.
		var gate := EquipmentCatalog.effect_gate(item_id)
		var switched_off := not gate.is_empty() and not bool((item.get("state", {}) as Dictionary).get(gate.key, gate.default))
		for effect in totals:
			if switched_off and (gate.scope == "all" or effect == "power_draw"):
				continue
			totals[effect] += int(effects.get(effect, 0))
		# Heaters draw power by their Off / Low / High setting.
		var levels := EquipmentCatalog.levels(item_id)
		if not levels.is_empty():
			var level := int((item.get("state", {}) as Dictionary).get(levels.key, 0))
			if level >= 0 and level < (levels.power as Array).size(): totals.power_draw += int(levels.power[level])
	return totals

## Extra warmth (degrees C) from heaters switched on in a zone. Heaters run on
## grid power; Life Support's climate control stays the main heating.
func _heater_warmth(zone: Dictionary) -> float:
	var warmth := 0.0
	for item in placed_interior:
		var levels := EquipmentCatalog.levels(str(item.get("id", "")))
		if levels.is_empty() or not (zone.get("cells", []) as Array).has(item.get("zone_cell", Vector2i(999999, 0))): continue
		var level := int((item.get("state", {}) as Dictionary).get(levels.key, 0))
		if level > 0 and level < (levels.heat as Array).size(): warmth += float(levels.heat[level])
	return warmth

## Saved interaction state of a placed interior item (curtain, light, doors…).
func interior_state(placement_id: String) -> Dictionary:
	for list in [placed_interior, placed_surface, zones]:
		for item in list:
			if str(item.get("placement_id", "")) == placement_id: return (item.get("state", {}) as Dictionary).duplicate()
	return {}

## Record an interaction so it is saved, and update power if a light changed.
func set_interior_state(placement_id: String, key: String, value: Variant) -> void:
	simulation().invalidate()
	# Outdoor props, the reactor and the ice extractor save their switches too.
	for item in placed_surface + zones:
		if str(item.get("placement_id", "")) != placement_id: continue
		var outdoor_state: Dictionary = item.get("state", {})
		outdoor_state[key] = value
		item["state"] = outdoor_state
		if item.has("kind"): _update_systems()
		return
	for item in placed_interior:
		if str(item.get("placement_id", "")) != placement_id: continue
		var state: Dictionary = item.get("state", {})
		state[key] = value
		item["state"] = state
		var item_id := str(item.get("id", ""))
		if key == str(EquipmentCatalog.effect_gate(item_id).get("key", "light")) or key == EquipmentCatalog.grid_isolator_key(item_id) or key == str(EquipmentCatalog.levels(item_id).get("key", "")):
			_update_systems()
			_apply_grid_power()
			refresh_power_grid()
		return

func _is_habitat_cell(cell: Vector2i) -> bool:
	return _is_habitat_zone(_zone_at(cell))

func _valid(cells: Array) -> bool:
	return _invalid_reason(cells).is_empty()

func _edit_room_footprint(cell: Vector2i, remove_cell: bool) -> void:
	if cell.x == 999:
		return
	var hit_zone := _zone_at(cell)
	if not hit_zone.is_empty():
		var hit_index := zones.find(hit_zone)
		if hit_index < 0 or not _footprint_zone_is_editable(hit_zone):
			_flash_notice("invalid", "Can't edit this footprint", "Choose an ordinary sealed room, not a specialised structure.")
			return
		if hit_index != footprint_zone_index:
			footprint_zone_index = hit_index
			_refresh_footprint_selection_overlay()
			_flash_notice("info", "Room footprint selected", "Click adjacent empty cells to grow it. Ctrl-click a selected edge cell to remove it.")
			return
		if remove_cell:
			_remove_footprint_cell(cell)
		else:
			_flash_notice("info", "Room footprint selected", "Click an adjacent empty cell to add it. Ctrl-click an edge cell to remove it.")
		return
	if footprint_zone_index < 0 or footprint_zone_index >= zones.size():
		_flash_notice("info", "Select a room first", "Then click an adjacent empty cell to grow its footprint.")
		return
	var reason := _footprint_add_reason(cell)
	if not reason.is_empty():
		_flash_notice("invalid", "Can't extend this room", reason + ".")
		return
	var zone: Dictionary = zones[footprint_zone_index]
	var cells: Array = (zone.get("cells", []) as Array).duplicate()
	cells.append(cell)
	zone["cells"] = cells
	zone["cost"] = cell_cost(str(zone.kind)) * cells.size()
	zones[footprint_zone_index] = zone
	_rebuild()
	_refresh_footprint_selection_overlay()
	MHAudio.sfx("place")
	_flash_notice("valid", "Room extended", "%s is now %d cells." % [str(ZONE_TYPES[str(zone.kind)].label), cells.size()])

func _footprint_zone_is_editable(zone: Dictionary) -> bool:
	return not zone.has("outline") and _is_habitat_zone(zone) and str(zone.kind) not in ["airlock", "vehicle_bay", "corridor"]

func _footprint_add_reason(cell: Vector2i) -> String:
	if _occupied(cell): return "That cell is already part of the habitat"
	var zone: Dictionary = zones[footprint_zone_index]
	var connected := false
	for side in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if cell + side in zone.get("cells", []):
			connected = true
	if not connected: return "New cells must touch the selected room"
	var site_reason := MHSiteTerrain.cell_unbuildable_reason(cell, CELL)
	if not site_reason.is_empty(): return site_reason
	if _used_cargo() + earth_cost(cell_cost(str(zone.kind)), zone_printable(str(zone.kind))) > MHGame.cargo_budget(): return "Not enough cargo left"
	var player := world.get_node_or_null("Player") as Node3D
	if player != null and cell == Vector2i(roundi(player.global_position.x / CELL), roundi(player.global_position.z / CELL)):
		return "Move clear of the player before building"
	if is_inside_tree() and not zones.is_empty():
		var terrain := _cell_highest_terrain(cell)
		if terrain > habitat_base_y + .12: return "Ground is too high here"
		if terrain < habitat_base_y - 1.85: return "Ground drops away too far"
	return ""

func _remove_footprint_cell(cell: Vector2i) -> void:
	if footprint_zone_index < 0 or footprint_zone_index >= zones.size():
		return
	var zone: Dictionary = zones[footprint_zone_index]
	var cells: Array = zone.get("cells", [])
	if cell not in cells:
		_flash_notice("invalid", "Choose this room", "Ctrl-click a selected room cell to remove it.")
		return
	if cells.size() <= 1:
		_flash_notice("invalid", "Keep one cell", "Remove the room with the remove tool instead.")
		return
	if not _footprint_cell_is_edge(cell, cells):
		_flash_notice("invalid", "Keep the room connected", "Only an outer edge cell can be removed.")
		return
	for item in placed_equipment:
		if item.get("cell", Vector2i.ZERO) == cell:
			_flash_notice("invalid", "Clear this cell first", "Remove its equipment before reshaping the room.")
			return
	for item in placed_interior:
		if item.get("zone_cell", Vector2i.ZERO) == cell:
			_flash_notice("invalid", "Clear this cell first", "Remove its equipment before reshaping the room.")
			return
	var next_cells := cells.duplicate()
	next_cells.erase(cell)
	if not _cells_are_connected(next_cells):
		_flash_notice("invalid", "Keep the room connected", "That cell would split the room into separate spaces.")
		return
	zone["cells"] = next_cells
	zone["cost"] = cell_cost(str(zone.kind)) * next_cells.size()
	zones[footprint_zone_index] = zone
	_rebuild()
	_refresh_footprint_selection_overlay()
	_flash_notice("valid", "Cell removed", "%s is now %d cells." % [str(ZONE_TYPES[str(zone.kind)].label), next_cells.size()])

func _footprint_cell_is_edge(cell: Vector2i, cells: Array) -> bool:
	for side in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if cell + side not in cells:
			return true
	return false

func _cells_are_connected(cells: Array) -> bool:
	if cells.is_empty(): return false
	var seen: Array = [cells[0]]
	var open: Array = [cells[0]]
	while not open.is_empty():
		var current: Vector2i = open.pop_back()
		for side in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var neighbour: Vector2i = current + side
			if neighbour in cells and neighbour not in seen:
				seen.append(neighbour)
				open.append(neighbour)
	return seen.size() == cells.size()

func _footprint_hover_reason(cell: Vector2i) -> String:
	if footprint_zone_index < 0 or footprint_zone_index >= zones.size():
		return "Click an ordinary room to edit its footprint"
	if not _zone_at(cell).is_empty():
		return "Ctrl-click a selected edge cell to remove it"
	return _footprint_add_reason(cell)

func _draw_footprint_preview() -> void:
	if footprint_zone_index < 0 or footprint_zone_index >= zones.size() or hover.x == 999:
		_draw_preview([], false)
		return
	var zone: Dictionary = zones[footprint_zone_index]
	if not _zone_at(hover).is_empty():
		_draw_preview([], false)
		return
	var valid := _footprint_add_reason(hover).is_empty()
	_draw_preview([hover], valid)

func _refresh_footprint_selection_overlay() -> void:
	for node in get_tree().get_nodes_in_group("footprint_selection_overlay"):
		node.queue_free()
	if not build_mode or tool != "footprint" or footprint_zone_index < 0 or footprint_zone_index >= zones.size():
		return
	var zone: Dictionary = zones[footprint_zone_index]
	var overlay := Node3D.new()
	overlay.name = "SelectedRoomFootprint"
	overlay.add_to_group("footprint_selection_overlay")
	overlay.add_to_group("habitat_plan")
	root.add_child(overlay)
	var material := StandardMaterial3D.new()
	material.albedo_color = (ZONE_TYPES[str(zone.kind)].colour as Color).lightened(.45)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for cell in zone.get("cells", []):
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(CELL - .08, .035, CELL - .08)
		visual.mesh = mesh
		visual.material_override = material
		visual.position = Vector3(cell.x * CELL, habitat_base_y + .18, cell.y * CELL)
		overlay.add_child(visual)

# Empty when the cells can be placed; otherwise a short reason for the
# hologram status ("Can't place here · Overlaps a room").
func _invalid_reason(cells: Array) -> String:
	if cells.is_empty():
		if kind=="airlock": return "Airlocks are 1–3 cells in a straight line"
		if kind=="corridor": return "Corridors run in straight lines"
		return "Point at the ground"
	for cell in cells:
		var site_reason := MHSiteTerrain.cell_unbuildable_reason(cell, CELL)
		if not site_reason.is_empty(): return site_reason
	if not MHMissions.zone_unlocked(kind): return "Not delivered yet: this arrives in a later mission"
	for cell in cells:
		if lander != null and lander.keeps_clear(Vector2(cell.x * CELL, cell.y * CELL), CELL * .5): return "Too close to the lander"
		if MHMissions.in_blast_zone(Vector2(cell.x * CELL, cell.y * CELL)): return "Inside the landing zone: engine blast would damage it"
	for cell in cells:
		if _occupied(cell): return "Overlaps existing habitat"
		for zone in zones:
			if zone.has("angled_mount") and _cell_overlaps_outline_area(cell, _angled_mount_outline(zone.get("angled_mount", {}))):
				return "Overlaps an angled airlock or corridor"
			if zone.has("outline") and _cell_overlaps_outline_area(cell, zone_outline(zone)):
				return "Overlaps free-form habitat"
	var player := world.get_node_or_null("Player") as Node3D
	if player != null:
		var player_cell := Vector2i(roundi(player.global_position.x / CELL), roundi(player.global_position.z / CELL))
		for cell in cells:
			if cell == player_cell:
				return "Move clear of the player before building"
	if kind=="airlock":
		var airlock_reason := _airlock_invalid_reason(cells)
		if not airlock_reason.is_empty(): return airlock_reason
	if kind=="vehicle_bay" and not _valid_vehicle_bay(cells): return "2–4 cells each way, door facing outside, beside a room"
	if kind=="ice_extractor" and _ice_richness_at(cells[0])<.12: return "No recoverable subsurface ice here"
	if _used_cargo()+earth_cost(_zone_cost(cells), zone_printable(kind))>MHGame.cargo_budget(): return "Not enough cargo left"
	# Build on a local, reasonably flat patch. A short foundation can bridge a
	# shallow dip, but we reject hills and deep drops instead of making towers.
	if is_inside_tree() and not zones.is_empty():
		for cell in cells:
			var terrain:=_cell_highest_terrain(cell)
			# The habitat deck is deliberately raised above the initial survey point.
			# Permit shallow undulations beneath its skirt; only reject a terrain
			# ridge that would visibly break through the finished floor.
			if terrain > habitat_base_y + .12: return "Ground is too high here"
			if terrain < habitat_base_y - 1.85: return "Ground drops away too far"
	return ""

# A cell sharing only an edge with an outline is adjacent, not overlapping.
# That distinction lets a grid airlock meet a qualifying free-form wall while
# still rejecting a grid room or structure that occupies the outlined floor.
func _cell_overlaps_outline_area(cell: Vector2i, outline: PackedVector2Array) -> bool:
	return _polygons_overlap_area(_freeform_cell_polygon(cell), outline)

func _polygons_overlap_area(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	for intersection in Geometry2D.intersect_polygons(first, second):
		if absf(_outline_area(intersection)) > .001: return true
	return false

func _outline_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(points.size()):
		var first := points[index]
		var second := points[(index + 1) % points.size()]
		area += first.x * second.y - second.x * first.y
	return area * .5

func _valid_airlock(cells: Array) -> bool:
	return _airlock_invalid_reason(cells).is_empty()

func _airlock_invalid_reason(cells: Array) -> String:
	if cells.size()<1 or cells.size()>3: return "Airlocks are 1–3 cells in a straight line"
	var outside_cell:=_airlock_end(cells,airlock_direction,true)
	var inner_cell:=_airlock_end(cells,airlock_direction,false)
	# The outer end must face Mars; the far end must join an existing habitat.
	if _occupied(outside_cell + airlock_direction): return "Outer end must face Mars"
	var outer_point := Vector2((outside_cell.x + airlock_direction.x) * CELL, (outside_cell.y + airlock_direction.y) * CELL)
	if not _zone_at_point(outer_point).is_empty(): return "Outer end must face Mars"
	if _is_habitat_cell(inner_cell - airlock_direction): return ""
	var attachment := _outline_attachment_for_face(inner_cell, -airlock_direction)
	if bool(attachment.get("valid", false)): return ""
	return str(attachment.get("reason", "Inner end must touch a room"))

# Checks a 3 m grid structure face against free-form room outlines. The
# structure remains wholly outside; only its end face is allowed to meet a
# qualifying straight wall. Later corridor and vehicle-bay work reuses this.
func _outline_attachment_for_face(end_cell: Vector2i, toward_room: Vector2i) -> Dictionary:
	var face_centre := Vector2(end_cell.x * CELL + toward_room.x * HALF_CELL, end_cell.y * CELL + toward_room.y * HALF_CELL)
	var face_normal := Vector2(toward_room.x, toward_room.y)
	var saw_straight_edge := false
	var saw_off_grid_edge := false
	var saw_short_edge := false
	for zone_index in range(zones.size()):
		var zone: Dictionary = zones[zone_index]
		if not zone.has("outline"): continue
		var outline := zone_outline(zone)
		for edge_index in range(outline.size()):
			var start := outline[edge_index]
			var finish := outline[(edge_index + 1) % outline.size()]
			var edge := finish - start
			var length := edge.length()
			if length < .01: continue
			var tangent := edge / length
			var axis_aligned := absf(tangent.x) < .001 or absf(tangent.y) < .001
			if not axis_aligned: continue
			if absf(tangent.dot(face_normal)) > .001: continue
			saw_straight_edge = true
			var wall_coordinate := start.x if absf(face_normal.x) > .5 else start.y
			if not _is_cell_face_line(wall_coordinate):
				saw_off_grid_edge = true
				continue
			if absf(face_centre.x - start.x) > .10 and absf(face_centre.y - start.y) > .10:
				continue
			var along := (face_centre - start).dot(tangent)
			if along - HALF_CELL < -.10 or along + HALF_CELL > length + .10:
				saw_short_edge = true
				continue
			if not _cell_is_outside_outline(end_cell, outline):
				return {"valid": false, "reason": "Structure end must stay outside the room"}
			return {"valid": true, "zone_index": zone_index, "edge_index": edge_index, "opening_start": clampf(along - HALF_CELL, 0.0, length), "opening_end": clampf(along + HALF_CELL, 0.0, length)}
	if saw_off_grid_edge: return {"valid": false, "reason": "Wall is half a cell off the grid - move the room 1.5 m"}
	if saw_short_edge: return {"valid": false, "reason": "Wall is too short for a 3 m doorway"}
	if saw_straight_edge: return {"valid": false, "reason": "Inner end must meet the straight wall"}
	return {"valid": false, "reason": "Attach to a straight wall"}

func _is_cell_face_line(value: float) -> bool:
	var remainder := fposmod(value - HALF_CELL, CELL)
	return remainder < .10 or remainder > CELL - .10

func _cell_is_outside_outline(cell: Vector2i, outline: PackedVector2Array) -> bool:
	var centre := Vector2(cell.x * CELL, cell.y * CELL)
	if Geometry2D.is_point_in_polygon(centre, outline): return false
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			if Geometry2D.is_point_in_polygon(centre + Vector2(x_sign * (HALF_CELL - .01), z_sign * (HALF_CELL - .01)), outline): return false
	return true

func _valid_vehicle_bay(cells: Array) -> bool:
	var min_x: int=cells[0].x; var max_x: int=cells[0].x; var min_z: int=cells[0].y; var max_z: int=cells[0].y
	for cell in cells:
		min_x=mini(min_x,cell.x); max_x=maxi(max_x,cell.x); min_z=mini(min_z,cell.y); max_z=maxi(max_z,cell.y)
	var width: int=max_x-min_x+1; var depth: int=max_z-min_z+1
	# Keep the hangar legible and modest: 2–4 cells each way, rectangular only.
	if cells.size()!=width*depth or width<2 or depth<2 or width>4 or depth>4: return false
	var connected:=false
	for cell in cells:
		if not (cell+airlock_direction in cells) and not _zone_across(cell,airlock_direction).is_empty(): return false # Keep the hangar face outside.
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side!=airlock_direction and not (cell+side in cells) and _is_habitat_zone(_zone_across(cell,side)): connected=true
	return connected

func _power_radius(source_kind: String) -> float:
	return REACTOR_POWER_RADIUS if source_kind == "reactor" else SOLAR_POWER_RADIUS

func _valid_power_source(cells: Array) -> bool:
	if cells.size()!=1 or zones.is_empty(): return false
	return _power_source_connected({"kind": kind, "cells": cells})

## Power sources are cabled to the grid wherever they stand (real plans put
## reactors a kilometre or more away), so any placed source is connected.
## The old range-field check is kept below for reference but not used.
func _power_source_connected(source: Dictionary) -> bool:
	return not (source.get("cells", []) as Array).is_empty()

func _power_source_in_field(source: Dictionary) -> bool:
	var cells: Array = source.get("cells", [])
	if cells.is_empty(): return false
	var cell: Vector2i = cells[0]
	var radius := _power_radius(str(source.get("kind", "solar")))
	# A StarCraft-style field reaches the shell directly—no visible cable and no
	# requirement to place hardware immediately beside a wall.
	var source_point := Vector2(cell.x * CELL, cell.y * CELL)
	for zone in zones:
		if not _is_habitat_zone(zone): continue
		# Free-form rooms and angled connectors are reached at their nearest wall.
		var shape := _angled_mount_outline(zone.get("angled_mount", {})) if zone.has("angled_mount") else (zone_outline(zone) if zone.has("outline") else PackedVector2Array())
		if not shape.is_empty():
			for index in range(shape.size()):
				if source_point.distance_to(Geometry2D.get_closest_point_to_segment(source_point, shape[index], shape[(index + 1) % shape.size()])) <= radius: return true
			continue
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

## Litres of water a sol a drill makes here: the simulation's own figure.
func _ice_yield(cell: Vector2i) -> int:
	return roundi(MHResources.setting("ice_drill_l", 120.0) * _ice_richness_at(cell))

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
	var height:=2.9 if not kind in SITE_MACHINES else (2.25 if kind=="reactor" else 1.6)
	var volume_size:=Vector3(bounds.size.x*CELL,height,bounds.size.y*CELL)
	var volume_centre:=Vector3((bounds.position.x+bounds.size.x*.5-.5)*CELL,base_y+height*.5,(bounds.position.y+bounds.size.y*.5-.5)*CELL)
	if kind=="solar": volume_size=Vector3(2.4,height,1.6)
	if kind=="reactor": volume_size=Vector3(2.1,height,2.1)
	if kind=="ice_extractor": volume_size=Vector3(1.7,height,1.7)
	if kind=="regolith_intake": volume_size=Vector3(2.0,1.2,2.4)
	var ghost:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=volume_size; ghost.mesh=box; ghost.material_override=fill; ghost.position=volume_centre; ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(ghost)
	preview.add_child(_box_edges(volume_centre,volume_size,edge))
	if kind=="airlock": _airlock_arrow(_airlock_end(cells,airlock_direction,true),"OUTSIDE")
	if kind=="vehicle_bay": _airlock_arrow(_face_preview_cell(cells,airlock_direction),"HANGAR")
	if kind=="corridor" and cells.size()==1: _airlock_arrow(cells[0],"OPEN ENDS")
	if kind=="solar": _airlock_arrow(cells[0],"SOLAR %d%% AT NOON" % roundi(_solar_efficiency(airlock_direction, Vector2(0, 1))*100.0))
	if kind=="ice_extractor":
		var ice_here := _ice_richness_at(cells[0])
		_ice_tag(cells[0], ice_here)

func _draw_angled_outline_connector_preview(mount: Dictionary, valid: bool) -> void:
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	var basis: Basis = _angled_mount_basis(mount)
	var length := float(mount.get("length", CELL))
	var key := "angled-preview|%s|%s|%s|%s" % [position, outward, length, valid]
	if key == _preview_key: return
	_preview_key = key
	for child in preview.get_children(): child.queue_free()
	_ensure_preview_materials()
	var fill := _preview_valid_material if valid else _preview_invalid_material
	var edge := _line_valid_material if valid else _line_invalid_material
	var base_y := habitat_base_y if not zones.is_empty() else .35
	# The local X axis runs along the diagonal wall and local -Z points outside.
	# Showing the ghost from the wall centre makes its outside placement explicit.
	var holder := Node3D.new()
	holder.position = Vector3(position.x + outward.x * length * .5, base_y, position.y + outward.y * length * .5)
	holder.basis = basis
	preview.add_child(holder)
	var tile := MeshInstance3D.new()
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(CELL - .06, .04, length - .06)
	tile.mesh = tile_mesh
	tile.material_override = fill
	tile.position = Vector3(0, .05, 0)
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(tile)
	var height := 2.9
	var ghost := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CELL, height, length)
	ghost.mesh = box
	ghost.material_override = fill
	ghost.position = Vector3(0, height * .5, 0)
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ghost)
	holder.add_child(_box_edges(Vector3(0, height * .5, 0), Vector3(CELL, height, length), edge))
	var direction := _label3d("45° WALL · OUTSIDE", 24, MHStyle.INK_100, 500)
	direction.position = Vector3(0, height + .35, 0)
	direction.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	direction.visible = true
	holder.add_child(direction)

func _draw_freeform_preview(cursor: Vector2, reason: String) -> void:
	var key := "freeform|%s|%s|%s" % [freeform_points, cursor, reason]
	if key == _preview_key: return
	_preview_key = key
	for child in preview.get_children(): child.queue_free()
	_ensure_preview_materials()
	var valid := reason.is_empty()
	var fill := _preview_valid_material if valid else _preview_invalid_material
	# Bold, always-on-top line with a dark border so it reads on bright ground
	# and over the grid lines.
	var edge := _freeform_marker_material(MHStyle.HOLO_VALID if valid else MHStyle.HOLO_INVALID)
	var base_y := habitat_base_y if not zones.is_empty() else _proposed_freeform_base_y(freeform_points)
	var outline_mesh := ImmediateMesh.new()
	outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES, edge)
	for index in range(freeform_points.size() - 1):
		outline_mesh.surface_add_vertex(Vector3(freeform_points[index].x, base_y + .08, freeform_points[index].y))
		outline_mesh.surface_add_vertex(Vector3(freeform_points[index + 1].x, base_y + .08, freeform_points[index + 1].y))
		_add_freeform_preview_strip(freeform_points[index], freeform_points[index + 1], base_y, edge)
	if not freeform_points.is_empty() and not is_inf(cursor.x):
		outline_mesh.surface_add_vertex(Vector3(freeform_points[freeform_points.size() - 1].x, base_y + .08, freeform_points[freeform_points.size() - 1].y))
		outline_mesh.surface_add_vertex(Vector3(cursor.x, base_y + .08, cursor.y))
		_add_freeform_preview_strip(freeform_points[freeform_points.size() - 1], cursor, base_y, edge)
	outline_mesh.surface_end()
	var lines := MeshInstance3D.new(); lines.mesh = outline_mesh; lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(lines)
	for point in freeform_points:
		var marker := MeshInstance3D.new(); var marker_mesh := SphereMesh.new(); marker_mesh.radius = .32; marker_mesh.height = .64; marker.mesh = marker_mesh
		marker.material_override = edge; marker.position = Vector3(point.x, base_y + .11, point.y); marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(marker)
	if not is_inf(cursor.x):
		_add_freeform_snap_dot(cursor, base_y, valid)
	for index in range(freeform_points.size() - 1):
		var start := freeform_points[index]
		var finish := freeform_points[index + 1]
		if _is_door_ready_preview_edge(start, finish): _add_door_ready_preview_marker((start + finish) * .5, base_y)
	if freeform_points.size() >= 3:
		var fill_mesh := ImmediateMesh.new(); fill_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill)
		var triangles := Geometry2D.triangulate_polygon(freeform_points)
		for index in triangles: fill_mesh.surface_add_vertex(Vector3(freeform_points[index].x, base_y + .045, freeform_points[index].y))
		fill_mesh.surface_end()
		var polygon := MeshInstance3D.new(); polygon.mesh = fill_mesh; polygon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; preview.add_child(polygon)
	var label_point := cursor if freeform_points.is_empty() else freeform_points[freeform_points.size() - 1]
	if not is_inf(label_point.x):
		var label := _label3d("%s · %.1f m wall · %.1f m²" % [_freeform_wall_angle(cursor), _freeform_current_wall_length(cursor), _freeform_area(freeform_points)], 24, MHStyle.HOLO_VALID if valid else MHStyle.HOLO_INVALID, 600)
		label.position = Vector3(label_point.x, base_y + .32, label_point.y); preview.add_child(label)

func _add_freeform_snap_dot(point: Vector2, base_y: float, valid: bool) -> void:
	# A bright ring around the snapped corner under the cursor, so you can see
	# exactly which cell corner the next click will use.
	var colour: Color = MHStyle.HOLO_VALID if valid else MHStyle.HOLO_INVALID
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new(); torus.inner_radius = .42; torus.outer_radius = .62; torus.rings = 32
	ring.mesh = torus
	ring.scale = Vector3(1, .25, 1)
	ring.material_override = _freeform_marker_material(colour)
	ring.position = Vector3(point.x, base_y + .1, point.y)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(ring)
	var dot := MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius = .16; mesh.height = .32; dot.mesh = mesh
	dot.material_override = _freeform_marker_material(colour)
	dot.position = Vector3(point.x, base_y + .12, point.y)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(dot)

func _is_door_ready_preview_edge(start: Vector2, finish: Vector2) -> bool:
	var edge := finish - start
	if edge.length() < CELL - .01: return false
	if absf(edge.x) < .01: return _is_cell_face_line(start.x)
	if absf(edge.y) < .01: return _is_cell_face_line(start.y)
	return false

func _add_door_ready_preview_marker(point: Vector2, base_y: float) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new(); mesh.top_radius = .11; mesh.bottom_radius = .11; mesh.height = .08; marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(MHStyle.SAFETY_ORANGE.r, MHStyle.SAFETY_ORANGE.g, MHStyle.SAFETY_ORANGE.b, .72)
	material.emission_enabled = true; material.emission = MHStyle.SAFETY_ORANGE; material.emission_energy_multiplier = .7
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	marker.position = Vector3(point.x, base_y + .1, point.y)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(marker)

func _add_freeform_preview_strip(start: Vector2, finish: Vector2, base_y: float, material: Material) -> void:
	var length := start.distance_to(finish)
	if length < .01: return
	var tangent := (finish - start) / length
	# A dark border strip under the coloured line keeps it legible on bright
	# terrain; both draw on top of the grid.
	for layer in [[.56, _freeform_marker_material(Color("#0A0F12"), .8), 0], [.32, material, 1]]:
		var strip := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(length + float(layer[0]), .04, float(layer[0])); strip.mesh = mesh
		strip.material_override = layer[1]
		strip.sorting_offset = float(layer[2])
		strip.position = Vector3((start.x + finish.x) * .5, base_y + .09, (start.y + finish.y) * .5)
		strip.rotation.y = atan2(-tangent.y, tangent.x)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preview.add_child(strip)

var _freeform_materials := {}
## Unshaded marker colour drawn over the terrain and grid (cached per colour).
func _freeform_marker_material(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s" % [colour.to_html(), alpha]
	if _freeform_materials.has(key): return _freeform_materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.no_depth_test = true
	material.render_priority = 1 if alpha < 1.0 else 2
	material.disable_fog = true
	_freeform_materials[key] = material
	return material

## Whole-site subsurface ice survey: a smooth field with contour lines,
## drawn by shaders/ice_survey.gdshader from the site's deposits.
func _add_ice_heatmap() -> void:
	var limit := _site_build_limit()
	var plane := PlaneMesh.new()
	plane.size = Vector2(limit * 2.0, limit * 2.0)
	var field := MeshInstance3D.new()
	field.name = "SubsurfaceIceSurvey"
	field.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = ICE_SURVEY_SHADER
	var packed := PackedVector4Array()
	for deposit in MHGame.site().get("ice_deposits", []):
		if packed.size() >= 8: break
		packed.append(Vector4(float(deposit.get("x", 0.0)), float(deposit.get("z", 0.0)), float(deposit.get("radius", 1.0)), float(deposit.get("richness", 0.0))))
	var count := packed.size()
	while packed.size() < 8: packed.append(Vector4.ZERO)
	material.set_shader_parameter("deposits", packed)
	material.set_shader_parameter("deposit_count", count)
	field.material_override = material
	field.position.y = habitat_base_y + .07
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(field)

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
	# Draw directly in world X/Z. The old rotated local triangle used a different
	# sign convention from the label on east/west sides, so the two disagreed.
	var direction := Vector2(float(airlock_direction.x), float(airlock_direction.y))
	var sideways := Vector2(-direction.y, direction.x)
	var centre := Vector2(cell.x * CELL, cell.y * CELL)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	mesh.surface_add_vertex(Vector3(centre.x + direction.x * 1.20, y, centre.y + direction.y * 1.20))
	mesh.surface_add_vertex(Vector3(centre.x - direction.x * .35 + sideways.x * .65, y, centre.y - direction.y * .35 + sideways.y * .65))
	mesh.surface_add_vertex(Vector3(centre.x - direction.x * .35 - sideways.x * .65, y, centre.y - direction.y * .35 - sideways.y * .65))
	mesh.surface_end()
	arrow.mesh=mesh; preview.add_child(arrow)
	var label:=_label3d(label_text,44,MHStyle.accent); label.position=Vector3(centre.x + direction.x*1.4,y+.9,centre.y + direction.y*1.4); preview.add_child(label)

## Ice readout above the drill ghost: richness, and the water it would make.
func _ice_tag(cell: Vector2i, richness: float) -> void:
	var y := (habitat_base_y if not zones.is_empty() else .35) + 2.9
	var at := Vector3(cell.x * CELL, y, cell.y * CELL)
	if richness < .12:
		var none := _label3d("NO DRILLABLE ICE", 40, MHStyle.TEXT_SECONDARY)
		none.position = at
		preview.add_child(none)
		return
	var head := _label3d("%d%% ICE" % roundi(richness * 100.0), 58, Color("#8FE6FF"))
	head.position = at + Vector3.UP * .45
	preview.add_child(head)
	var water := _label3d("≈ %d L of water a sol" % _ice_yield(cell), 30, MHStyle.TEXT_PRIMARY, 600)
	water.position = at
	preview.add_child(water)

func _label3d(text: String,size: int,colour: Color,weight := 800) -> Label3D:
	var label:=Label3D.new(); label.text=text; label.font=MHStyle.font(weight,false,2); label.font_size=size; label.outline_size=10; label.outline_modulate=Color(MHStyle.INK_950,.85); label.modulate=colour; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true; label.render_priority=2; label.pixel_size=.013
	return label

func _rebuild() -> void:
	_merge_touching_same_type_rooms()
	_prune_angled_outline_connectors()
	var attachment_refund := _prune_equipment()
	_prune_interior_doors()
	_prune_partitions()
	if attachment_refund > 0:
		_flash_notice("info", "Mounted equipment removed", "+%s cargo returned — its wall changed." % MHStyle.kg(attachment_refund))
	for child in root.get_children(): child.queue_free()
	_hull_bays = []
	_windows_built = {}
	for zone in zones:
		if zone.has("angled_mount"):
			_build_angled_outline_connector(zone)
			continue
		if zone.has("outline"):
			_build_freeform_zone(zone)
			_build_outline_walls(zone)
			_add_zone_lighting(zone)
			_add_zone_roof_accessory(zone)
			continue
		_zone_surfaces(zone)
		if str(zone.kind)=="airlock": _build_airlock_zone(zone)
		elif str(zone.kind)=="vehicle_bay": _build_vehicle_bay(zone)
		elif str(zone.kind)=="solar": _build_solar(zone)
		elif str(zone.kind)=="reactor": _build_reactor(zone)
		elif str(zone.kind)=="ice_extractor": _build_ice_extractor(zone)
		elif str(zone.kind)=="regolith_intake": _build_regolith_intake(zone)
		else:
			for cell in zone.cells: _cell_walls(cell,zone)
	for door_data in interior_doors:
		if door_data.has("wall_a"):
			var door_transform := interior_door_target_transform(door_data)
			_add_angled_door(door_transform.origin, door_transform.basis, "INTERIOR", true)
			continue
		if door_data.has("outline_grid_cell"):
			var outline_grid_cell: Vector2i = door_data.get("outline_grid_cell", Vector2i.ZERO)
			var outline_grid_side: Vector2i = door_data.get("outline_grid_side", Vector2i.ZERO)
			_add_door(Vector3(outline_grid_cell.x * CELL, 0, outline_grid_cell.y * CELL), outline_grid_side, "INTERIOR", true)
			continue
		var door_cell: Vector2i = door_data.get("cell", Vector2i.ZERO)
		var door_side: Vector2i = door_data.get("side", Vector2i.ZERO)
		var first_zone := _zone_at(door_cell)
		var second_zone := _zone_at(door_cell + door_side)
		# Vehicle bays build their own interlocked personnel hatch below, rather
		# than adding a second generic door into the same wall opening.
		if str(first_zone.get("kind", "")) == "vehicle_bay" or str(second_zone.get("kind", "")) == "vehicle_bay":
			continue
		# The framed hatch fills the complete 3 m shared wall bay. The unframed
		# shutter is deliberately narrower and left visible slits at either edge.
		_add_door(Vector3(door_cell.x * CELL, 0, door_cell.y * CELL), door_side, "INTERIOR", true)
	_build_partitions()
	ROOM_IDENTITY.build(self)   # colour bands, door signs, per-room overhead detail
	_add_room_fills()
	_add_light_panels()
	_prune_hull_windows()
	_build_foundation_supports()
	if grid!=null: grid.position.y=habitat_base_y+.09
	for zone in zones: _add_zone_label(zone)
	_set_build_view(build_mode); _update_budget(); _update_summary(); _update_systems(); _apply_grid_power()
	update_room_lights(true)
	habitat_changed.emit()

# ---------- room lighting ----------
# Each room is on, dim or off (HabitatSim.light_state: the crew's schedule,
# where you are, and wall-panel overrides). A lit room gets one soft fill
# light (one per 3x3 cells in big rooms) instead of a light per fixture, so a
# whole base needs a couple of dozen real lights; fixtures glow to match.

const FILL_ON := Color("#FFE7B2")
const FILL_DIM := Color("#8FA6CF")

func _room_key_at(point: Vector2) -> String:
	var zone := _zone_at_point(point)
	return simulation()._room_key(zone) if not zone.is_empty() else ""

## Clusters of a room's floor (centre, radius) for its fill lights.
func _fill_spots(zone: Dictionary) -> Array:
	if zone.has("outline"):
		var outline := zone_outline(zone)
		var middle := _outline_centroid(outline)
		var reach := 0.0
		for point in outline: reach = maxf(reach, point.distance_to(middle))
		return [[middle, minf(reach * .85 + 1.0, 11.0)]]
	var blocks := {}
	for cell in zone.get("cells", []):
		var block := Vector2i(floori(float(cell.x) / 3.0), floori(float(cell.y) / 3.0))
		if not blocks.has(block): blocks[block] = []
		blocks[block].append(cell)
	var spots: Array = []
	for block in blocks:
		var middle := Vector2.ZERO
		for cell in blocks[block]: middle += Vector2(cell.x, cell.y) * CELL
		middle /= float(blocks[block].size())
		var reach := 0.0
		for cell in blocks[block]: reach = maxf(reach, (Vector2(cell.x, cell.y) * CELL).distance_to(middle))
		spots.append([middle, reach + 2.6])
	return spots

func _add_room_fills() -> void:
	for zone in zones:
		if not _is_habitat_zone(zone): continue
		var key: String = simulation()._room_key(zone)
		for spot in _fill_spots(zone):
			var light := OmniLight3D.new()
			light.name = "RoomFill"
			light.position = Vector3(spot[0].x, habitat_base_y + 2.45, spot[0].y)
			light.omni_range = float(spot[1])
			light.omni_attenuation = 1.15
			light.shadow_enabled = false
			light.light_energy = 0.0
			light.visible = false
			light.set_meta("room_key", key)
			light.set_meta("budget_exempt", true)
			light.set_meta("full_energy", 1.9 if str(zone.kind) == "hydroponics" else 1.45)
			light.add_to_group("room_fill")
			root.add_child(light)

## One light panel per room, on a solid wall (not a window), preferring the
## wall nearest a door so it's by the way in.
func _add_light_panels() -> void:
	var doors: Array = get_tree().get_nodes_in_group("airlock_door").map(func(d): return Vector2((d as Node3D).global_position.x, (d as Node3D).global_position.z))
	for zone in zones:
		if not _is_habitat_zone(zone): continue
		var best := {}
		var best_score := INF
		for wall in _room_walls(zone):
			var mid: Vector2 = wall.mid
			var score := 999.0
			for door in doors: score = minf(score, mid.distance_to(door))
			if score < 1.0: continue   # the doorway itself
			if score < best_score:
				best_score = score
				best = wall
		if best.is_empty(): continue
		var inward: Vector2 = best.inward
		var at: Vector2 = best.mid + inward * .1
		var panel := StaticBody3D.new()
		panel.set_script(ROOM_LIGHT_PANEL)
		panel.name = "LightPanel"
		panel.collision_layer = 1
		panel.position = Vector3(at.x, habitat_base_y + 1.3, at.y)
		panel.rotation.y = atan2(-inward.x, -inward.y) + PI
		var plate := MeshInstance3D.new(); var plate_mesh := BoxMesh.new(); plate_mesh.size = Vector3(.16, .24, .04); plate.mesh = plate_mesh
		var plate_material := StandardMaterial3D.new(); plate_material.albedo_color = MHStyle.SEAL_DARK.lightened(.1); plate.material_override = plate_material
		panel.add_child(plate)
		var lamp := MeshInstance3D.new(); var lamp_mesh := BoxMesh.new(); lamp_mesh.size = Vector3(.1, .03, .01); lamp.mesh = lamp_mesh
		lamp.position = Vector3(0, .06, -.025)
		var lamp_material := StandardMaterial3D.new(); lamp_material.emission_enabled = true; lamp_material.emission_energy_multiplier = 1.2
		lamp.material_override = lamp_material
		panel.add_child(lamp)
		var key_plate := MeshInstance3D.new(); var key_mesh := BoxMesh.new(); key_mesh.size = Vector3(.08, .08, .015); key_plate.mesh = key_mesh
		key_plate.position = Vector3(0, -.04, -.025)
		var key_material := StandardMaterial3D.new(); key_material.albedo_color = Color("#D8DDDF"); key_plate.material_override = key_material
		panel.add_child(key_plate)
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(.2, .28, .08); shape.shape = box
		panel.add_child(shape)
		root.add_child(panel)
		panel.call("setup", self, simulation()._room_key(zone), str(ZONE_TYPES.get(str(zone.kind), {}).get("label", zone.kind)), lamp_material)

## A room's solid walls: [{mid: Vector2, inward: Vector2}].
func _room_walls(zone: Dictionary) -> Array:
	var walls: Array = []
	if zone.has("outline"):
		var outline := zone_outline(zone)
		var middle := _outline_centroid(outline)
		for index in range(outline.size()):
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index + 1) % outline.size()]
			if a.distance_to(b) < 1.5: continue
			var mid := (a + b) * .5
			var inward := (b - a).orthogonal().normalized()
			if inward.dot(middle - mid) < 0.0: inward = -inward
			walls.append({"mid": mid, "inward": inward})
		return walls
	for cell in zone.get("cells", []):
		for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not _should_build_wall(cell, side): continue
			var mid := Vector2(cell.x, cell.y) * CELL + Vector2(side) * CELL * .5
			if _window_index_at(mid, Vector2(side)) >= 0: continue
			walls.append({"mid": mid, "inward": -Vector2(side)})
	return walls

## The light state of a room right now ("on", "dim" or "off").
func room_light_state(key: String) -> String:
	if not grid_power_online(): return "off"
	return str(simulation().room_light_states(MHGame.sol_hour).get(key, "dim"))

## Sets every fill light and fixture to its room's state; fades changes.
func update_room_lights(force := false) -> void:
	if not is_inside_tree(): return
	var online := grid_power_online()
	var states: Dictionary = simulation().room_light_states(MHGame.sol_hour) if online else {}
	if not force and states == _last_light_states and online == _last_lights_online: return
	_last_light_states = states
	_last_lights_online = online
	for node in get_tree().get_nodes_in_group("room_fill"):
		var light := node as OmniLight3D
		var state := str(states.get(str(light.get_meta("room_key", "")), "off"))
		# Only lit rooms get a real light: in this renderer every light redraws
		# what it touches, so dim rooms are just their glowing night strips.
		var energy := float(light.get_meta("full_energy", 1.45)) if state == "on" else 0.0
		light.light_color = FILL_ON if state == "on" else FILL_DIM
		if energy > 0.0: light.visible = true
		var fade := light.create_tween()   # dies with the light if a rebuild removes it
		fade.tween_property(light, "light_energy", energy, .8 if not force else .01)
		if energy <= 0.0: fade.tween_callback(func() -> void: light.visible = false)
	for node in get_tree().get_nodes_in_group("room_fixture"):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null: continue
		var state := str(states.get(str(mesh.get_meta("room_key", "")), "off"))
		material.emission_enabled = state != "off"
		material.albedo_color = Color("#F3E4C6") if state == "on" else (Color("#A9B6CC") if state == "dim" else Color("#293034"))
		material.emission = Color("#FFE7B2") if state == "on" else Color("#5E7FB8")
		material.emission_energy_multiplier = 1.7 if state == "on" else .45
	for node in get_tree().get_nodes_in_group("room_light_panel"): node.refresh()

var _last_light_states := {}
var _last_lights_online := false

func _merge_touching_same_type_rooms() -> void:
	# Rooms of the same purpose that share a wall are one continuous volume,
	# whatever their shape: grid rooms merge cell by cell, and a pair involving
	# a free-form room merges into one outline. A 3×3 Living Quarters drawn
	# against an angled Living Quarters becomes one room, one label, no wall.
	var merged_any := true
	while merged_any:
		merged_any = false
		for first_index in range(zones.size()):
			if merged_any: break
			var first: Dictionary = zones[first_index]
			if not _mergeable_room(first) and not _is_grid_corridor(first): continue
			for second_index in range(first_index + 1, zones.size()):
				var second: Dictionary = zones[second_index]
				if str(first.kind) != str(second.kind) or not (_mergeable_room(second) or _is_grid_corridor(second)): continue
				var combined := _merged_room(first, second)
				if combined.is_empty(): continue
				# Undo of the later placement restores the earlier room as it was.
				var restore := first.duplicate(true)
				combined["undo_restore"] = restore
				for step in _history:
					if step.get("zone") == second: step["zone"] = combined
					elif step.get("zone") == first: step["zone"] = restore
				zones[first_index] = combined
				zones.remove_at(second_index)
				merged_any = true
				break

func _is_grid_corridor(zone: Dictionary) -> bool:
	return str(zone.get("kind", "")) == "corridor" and not zone.has("angled_mount") and not zone.has("outline")

func _mergeable_room(zone: Dictionary) -> bool:
	return not zone.has("angled_mount") and _is_ordinary_room_kind(str(zone.get("kind", ""))) and _is_habitat_zone(zone)

## The single room two same-kind rooms become, or {} if they do not share a
## wall (or would enclose a courtyard, which one outline cannot describe).
func _merged_room(first: Dictionary, second: Dictionary) -> Dictionary:
	if _is_grid_corridor(first):
		# Corridor pieces laid end to end in one line become one corridor; side
		# by side or at an angle they stay separate (a T or a bend).
		var run: Array = (first.cells as Array).duplicate()
		for cell in second.cells:
			if cell not in run: run.append(cell)
		var same_x := true
		var same_z := true
		for cell in run:
			same_x = same_x and cell.x == run[0].x
			same_z = same_z and cell.y == run[0].y
		if not (same_x or same_z): return {}
		run.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
		for index in range(1, run.size()):
			if absi(run[index].x - run[index - 1].x) + absi(run[index].y - run[index - 1].y) != 1: return {}
		var corridor := first.duplicate(true)
		corridor.erase("undo_restore")
		corridor["cells"] = run
		corridor["cost"] = int(first.cost) + int(second.cost)
		return corridor
	if not first.has("outline") and not second.has("outline"):
		if not _zones_touch(first, second): return {}
		var cells: Array = (first.get("cells", []) as Array).duplicate()
		for cell in second.get("cells", []):
			if cell not in cells: cells.append(cell)
		var grid_room := first.duplicate(true)
		grid_room.erase("undo_restore")
		grid_room["cells"] = cells
		grid_room["cost"] = int(first.cost) + int(second.cost)
		return grid_room
	var first_outline := zone_outline(first)
	var second_outline := zone_outline(second)
	var shared := 0.0
	for index in range(first_outline.size()):
		for interval in _collinear_overlaps(first_outline[index], first_outline[(index + 1) % first_outline.size()], second_outline):
			shared += interval.y - interval.x
	if shared < 1.0: return {}
	var union: Array = Geometry2D.merge_polygons(first_outline, second_outline)
	if union.size() != 1: return {}
	var outline := _clean_outline(union[0])
	if outline.size() < 3: return {}
	return {"kind": first.kind, "cells": _freeform_cells(outline), "outline": outline, "door_direction": first.get("door_direction", Vector2i(0, -1)), "cost": int(first.cost) + int(second.cost)}

## Outline with coordinates rounded to the centimetre, duplicate corners and
## straight-through corners removed, so merged walls run as single edges.
func _clean_outline(points: PackedVector2Array) -> PackedVector2Array:
	var rounded := PackedVector2Array()
	for point in points:
		var snapped := Vector2(snappedf(point.x, .01), snappedf(point.y, .01))
		if rounded.is_empty() or rounded[rounded.size() - 1].distance_to(snapped) > .01: rounded.append(snapped)
	if rounded.size() > 1 and rounded[0].distance_to(rounded[rounded.size() - 1]) < .01: rounded.remove_at(rounded.size() - 1)
	var changed := true
	while changed and rounded.size() > 3:
		changed = false
		for index in range(rounded.size()):
			var before := rounded[posmod(index - 1, rounded.size())]
			var after := rounded[(index + 1) % rounded.size()]
			if absf((rounded[index] - before).cross(after - rounded[index])) < .001:
				rounded.remove_at(index)
				changed = true
				break
	return rounded

func _zones_touch(first: Dictionary, second: Dictionary) -> bool:
	for cell in first.get("cells", []):
		for side in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if cell + side in second.get("cells", []):
				return true
	return false

func _zone_surfaces(zone: Dictionary) -> void:
	var cells:Array=zone.cells
	var zone_kind:=str(zone.kind)
	if zone_kind in SITE_MACHINES: return
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
	if _zone_is_rectangle(zone):
		_add_box(centre+Vector3(0,habitat_base_y-.1,0),Vector3(size_x,.2,size_z),colour.darkened(.48),true,"habitat_floor",show_generated_surface)
		_add_box(centre+Vector3(0,habitat_base_y+2.9,0),Vector3(size_x,.15,size_z),MHStyle.STRUCTURAL_WHITE.darkened(.08),true,"habitat_roof",show_generated_surface)
		if zone_kind!="corridor" and zone_kind!="airlock":
			for corner in [Vector2i(min_x,min_z),Vector2i(max_x+1,min_z),Vector2i(max_x+1,max_z+1),Vector2i(min_x,max_z+1)]:
				_add_showcase(SHOWCASE_CORNER,Vector3(corner.x*CELL-CELL*.5,habitat_base_y,corner.y*CELL-CELL*.5))
		if zone_kind=="corridor":
			_add_corridor_understructure(cells)
	else:
		for cell in cells:
			var local_centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
			_add_box(local_centre+Vector3(0,habitat_base_y-.1,0),Vector3(CELL,.2,CELL),colour.darkened(.48),true,"habitat_floor")
			_add_box(local_centre+Vector3(0,habitat_base_y+2.9,0),Vector3(CELL,.15,CELL),MHStyle.STRUCTURAL_WHITE.darkened(.08),true,"habitat_roof")
	_add_zone_lighting(zone)
	_add_zone_roof_accessory(zone)

func _build_freeform_zone(zone: Dictionary) -> void:
	# The floor/roof are deliberately separate from the outline wall kit so a
	# future editor can replace one without touching the other.
	var outline := zone_outline(zone)
	if outline.size() < 3: return
	var colour: Color = ZONE_TYPES[str(zone.get("kind", "living"))].colour
	_add_freeform_slab(outline, habitat_base_y - .1, .2, colour.darkened(.48), "habitat_floor")
	_add_freeform_slab(outline, habitat_base_y + 2.9, .15, MHStyle.STRUCTURAL_WHITE.darkened(.08), "habitat_roof")
	_add_freeform_plan_polygon(outline, colour, str(zone.get("kind", "room")))

func _angled_mount_basis(mount: Dictionary) -> Basis:
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	var tangent_3d := Vector3(tangent.x, 0, tangent.y).normalized()
	var basis := Basis(tangent_3d, Vector3.UP, tangent_3d.cross(Vector3.UP))
	var outward_3d := Vector3(outward.x, 0, outward.y).normalized()
	if (-basis.z).dot(outward_3d) < 0.0:
		tangent_3d = -tangent_3d
		basis = Basis(tangent_3d, Vector3.UP, tangent_3d.cross(Vector3.UP))
	return basis

func _build_angled_outline_connector(zone: Dictionary) -> void:
	var mount: Dictionary = zone.get("angled_mount", {})
	var position: Vector2 = mount.get("position", Vector2.ZERO)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	var tangent: Vector2 = mount.get("tangent", Vector2.RIGHT)
	var basis := _angled_mount_basis(mount)
	var length := float(mount.get("length", CELL))
	var centre_2d := position + outward * length * .5
	var centre := Vector3(centre_2d.x, habitat_base_y, centre_2d.y)
	var zone_kind := str(zone.get("kind", "corridor"))
	var colour: Color = ZONE_TYPES[zone_kind].colour
	_add_rotated_box(centre + Vector3.UP * -.1, Vector3(CELL, .2, length), basis, colour.darkened(.48), true, "habitat_floor")
	_add_rotated_box(centre + Vector3.UP * 2.9, Vector3(CELL, .15, length), basis, MHStyle.STRUCTURAL_WHITE.darkened(.08), true, "habitat_roof")
	# The two long sides use the same detailed wall kit as rooms; the two ends
	# stay open so the host-wall hatch and outer/corridor end own the thresholds.
	var travel: Vector3 = Vector3(outward.x, 0, outward.y).normalized()
	var side_basis: Basis = Basis(travel, Vector3.UP, travel.cross(Vector3.UP))
	for raw_sign_value in [-1.0, 1.0]:
		var sign_value: float = float(raw_sign_value)
		var side_position: Vector3 = centre + Vector3(tangent.x, 0, tangent.y) * (CELL * .5 * sign_value)
		# Panel bays of about 3 m, like room walls, rather than one stretched panel.
		var bay_count := maxi(1, roundi(length / CELL))
		for bay_index in range(bay_count):
			var bay_centre := side_position + travel * (length * ((float(bay_index) + .5) / float(bay_count) - .5))
			_add_showcase_basis(SHOWCASE_WALL, Vector3(bay_centre.x, habitat_base_y, bay_centre.z), side_basis, Vector3(length / float(bay_count) / CELL, 1.0, 1.0))
		_add_rotated_box(side_position - Vector3(tangent.x, 0, tangent.y) * (.035 * sign_value) + Vector3.UP * (ROOM_HEIGHT * .5), Vector3(length, ROOM_HEIGHT, .16), side_basis, MHStyle.STRUCTURAL_WHITE, true, "habitat_wall")
	if zone_kind == "airlock":
		# The host-room hatch faces back into the room; the exterior hatch faces
		# Mars. Reusing the exterior basis for both made the inner frame appear as
		# a detached, outward-facing panel.
		var inner_basis: Basis = basis.rotated(Vector3.UP, PI)
		# Give the inner frame a tiny overlap into the 3 m wall opening. This hides
		# the hairline light seam without closing the doorway itself.
		var inner := _add_angled_door(Vector3(position.x, habitat_base_y, position.y), inner_basis, "INNER", false, 2.84)
		var outer_position := position + outward * length
		var outer := _add_angled_door(Vector3(outer_position.x, habitat_base_y, outer_position.y), basis, "OUTER", true)
		inner.set_partner(outer)
		outer.set_partner(inner)
	else:
		# The imported corridor bay includes its own shell and clashes with the
		# angled side panels. The generated shell above is clean and modular.
		# A far end that lands on another room's wall stays open into that room.
		if _angled_far_end_target(mount).is_empty():
			var end_position := position + outward * length
			_add_showcase_basis(SHOWCASE_WALL, Vector3(end_position.x, habitat_base_y, end_position.y), basis, Vector3.ONE)
			_add_rotated_box(Vector3(end_position.x, habitat_base_y + ROOM_HEIGHT * .5, end_position.y) - Vector3(outward.x * .035, 0, outward.y * .035), Vector3(CELL, ROOM_HEIGHT, .16), basis, MHStyle.STRUCTURAL_WHITE, true, "habitat_wall")
		# Ceiling strips along the run, like grid corridors (one per ~6 m).
		var light_count := maxi(1, roundi(length / 6.0))
		for light_index in range(light_count):
			var at := position + outward * (length * (float(light_index) + .5) / float(light_count))
			_add_powered_fixture(Vector3(at.x, habitat_base_y + 2.81, at.y), zone_kind, basis)
	_add_outline_connector_plan(centre_2d, basis, plan_colour(zone_kind), zone_kind, length)

func _add_angled_door(position: Vector3, basis: Basis, door_name: String, show_surround: bool, shutter_width := 2.64) -> AirlockDoor:
	if show_surround: _add_showcase_basis(SHOWCASE_AIRLOCK, position, basis, Vector3.ONE)
	var door := AIRLOCK_DOOR.new()
	door.transform = Transform3D(basis, position)
	root.add_child(door)
	door.setup(door_name, not show_surround, shutter_width)
	_add_door_plan_marker(door, door_name, shutter_width - .2)
	return door

func _add_outline_connector_plan(centre: Vector2, basis: Basis, colour: Color, zone_kind: String, length := CELL) -> void:
	var tile := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(CELL - .08, .035, length - .08); tile.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = colour.darkened(PLAN_TILE_SHADE); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; tile.material_override = material
	tile.transform = Transform3D(basis, Vector3(centre.x, habitat_base_y + .12, centre.y))
	tile.add_to_group("habitat_plan")
	tile.set_meta("zone_kind", zone_kind)
	root.add_child(tile)

func _build_outline_walls(zone: Dictionary) -> void:
	var outline := zone_outline(zone)
	if outline.size() < 3: return
	var zone_index := zones.find(zone)
	# Doorways, plus stretches another structure already walls: a grid zone
	# owns any cell face it shares, and of two free-form rooms sharing a wall
	# the earlier one builds it. Both leave a gap in this room's own wall kit.
	var doorways := _outline_wall_doorways(zone)
	var gaps := doorways + _outline_wall_owned_elsewhere(zone_index, outline)
	var passages: Array = doorways.duplicate()
	for gap in gaps:
		if bool(gap.get("open", false)): passages.append(gap)
	var support_points: Dictionary = {}
	for index in range(outline.size()):
		var start := outline[index]
		var finish := outline[(index + 1) % outline.size()]
		var edge := finish - start
		var length := edge.length()
		if length < .01: continue
		var tangent := edge / length
		# Decide outward by testing which side is inside the room. Winding order
		# is unreliable here (it put every exterior light inside the room).
		var outward := _outline_outward_at(outline, start + edge * .5, tangent)
		if outward == Vector2.ZERO: outward = Vector2(tangent.y, -tangent.x)
		var along := Vector3(tangent.x, 0, tangent.y)
		# Local X runs along the edge, local Y up, and local -Z faces Mars,
		# whichever direction the room was drawn in.
		var x_axis := along if (-along.cross(Vector3.UP)).dot(Vector3(outward.x, 0, outward.y)) > 0.0 else -along
		var basis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))
		for piece in _outline_wall_pieces(length, gaps, index):
			var piece_start: float = float(piece.get("start", 0.0))
			var piece_end: float = float(piece.get("end", 0.0))
			var piece_length: float = piece_end - piece_start
			if piece_length < .01: continue
			var bay_count := maxi(1, ceili(piece_length / CELL - .01))
			var bay_length := piece_length / float(bay_count)
			for bay_index in range(bay_count):
				var centre_2d := start + tangent * (piece_start + (float(bay_index) + .5) * bay_length)
				var wall_centre := Vector3(centre_2d.x, habitat_base_y + ROOM_HEIGHT * .5, centre_2d.y)
				var faces_mars := not _is_habitat_zone(_zone_at_point(centre_2d + outward * .4))
				if faces_mars and _hull_bay_can_glaze(str(zone.kind)) and _register_hull_bay(centre_2d, tangent, outward, bay_length, str(zone.kind)):
					_add_outline_safety_light(Vector3(centre_2d.x, 0, centre_2d.y), outward, basis)
					continue
				# The wall GLB is 3 m wide on its local X axis. Scaling only X
				# preserves panel height, thickness and the imported details.
				_add_showcase_basis(SHOWCASE_WALL, Vector3(centre_2d.x, habitat_base_y, centre_2d.y), basis, Vector3(bay_length / CELL, 1.0, 1.0))
				# Match the grid kit exactly: the backing is 0.16 m thick and sits 0.035 m
				# inside the detailed panel. It may overlap ordinary bay joins, but never a
				# doorway edge: that leaves the full 3 m opening free of hidden collision.
				var overlap_before := .0 if bay_index == 0 and piece_start > .01 else .07
				var overlap_after := .0 if bay_index == bay_count - 1 and piece_end < length - .01 else .07
				var backing_centre := wall_centre + along * ((overlap_after - overlap_before) * .5) - Vector3(outward.x * .035, 0, outward.y * .035)
				_add_rotated_box(backing_centre, Vector3(bay_length + overlap_before + overlap_after, ROOM_HEIGHT, .16), basis, MHStyle.STRUCTURAL_WHITE, true, "habitat_wall")
				# Outdoor flood lights only on bays that actually face Mars.
				if faces_mars:
					_add_outline_safety_light(Vector3(centre_2d.x, 0, centre_2d.y), outward, basis)
		var vertex_key := Vector2i(roundi(start.x * 100.0), roundi(start.y * 100.0))
		support_points[vertex_key] = start
		var support_steps := maxi(1, ceili(length / 6.0))
		for step in range(1, support_steps):
			var support_point := start + tangent * (length * float(step) / float(support_steps))
			support_points[Vector2i(roundi(support_point.x * 100.0), roundi(support_point.y * 100.0))] = support_point
	for index in range(outline.size()):
		# A corner post where a doorway meets the corner would stand in the
		# opening as a walk-through visual, so leave it out there.
		if not _passage_touches_vertex(outline, index, passages):
			_add_showcase(SHOWCASE_CORNER, Vector3(outline[index].x, habitat_base_y, outline[index].y))
	for point in support_points.values():
		var support_position := Vector3(point.x, 0, point.y)
		var ground := _terrain_height(support_position)
		if habitat_base_y - ground > .42: _add_support(support_position, ground)

func _passage_touches_vertex(outline: PackedVector2Array, vertex: int, passages: Array) -> bool:
	var previous := posmod(vertex - 1, outline.size())
	var previous_length := outline[previous].distance_to(outline[vertex])
	for passage in passages:
		var edge := int(passage.get("edge_index", -1))
		if edge == vertex and float(passage.get("opening_start", 1.0)) < .05: return true
		if edge == previous and float(passage.get("opening_end", 0.0)) > previous_length - .05: return true
	return false

## Stretches of a free-form room's outline that something else walls, as
## {edge_index, opening_start, opening_end} gaps in this room's own wall kit.
func _outline_wall_owned_elsewhere(zone_index: int, outline: PackedVector2Array) -> Array:
	var gaps: Array = []
	for index in range(outline.size()):
		var start := outline[index]
		var finish := outline[(index + 1) % outline.size()]
		var length := start.distance_to(finish)
		if length < .01: continue
		var tangent := (finish - start) / length
		# Grid zones own every 3 m cell face they share with this wall.
		var axis_aligned := absf(tangent.x) < .001 or absf(tangent.y) < .001
		var line := start.x if absf(tangent.x) < .001 else start.y
		if axis_aligned and _is_cell_face_line(line) and _is_cell_face_line(start.x if absf(tangent.y) < .001 else start.y):
			var outward := _outline_outward_at(outline, start + tangent * minf(HALF_CELL, length * .5), tangent)
			for chunk in range(roundi(length / CELL)):
				var middle := start + tangent * ((float(chunk) + .5) * CELL)
				var outside := middle + outward * HALF_CELL
				var grid_cell := Vector2i(roundi(outside.x / CELL), roundi(outside.y / CELL))
				if _is_habitat_zone(_zone_at(grid_cell)):
					# "open" when the grid side leaves a passage (corridor end, airlock
					# inner hatch or interior door) rather than a wall.
					var toward_room := Vector2i(roundi(-outward.x), roundi(-outward.y))
					gaps.append({"edge_index": index, "opening_start": float(chunk) * CELL, "opening_end": float(chunk + 1) * CELL, "open": not _should_build_wall(grid_cell, toward_room)})
		# Of two free-form rooms sharing a wall, the earlier one builds it.
		for other_index in range(zone_index):
			var other: Dictionary = zones[other_index]
			if not other.has("outline"): continue
			for interval in _collinear_overlaps(start, finish, zone_outline(other)):
				gaps.append({"edge_index": index, "opening_start": interval.x, "opening_end": interval.y})
	return gaps

## Distances along start→finish that lie on a collinear edge of `outline`.
func _collinear_overlaps(start: Vector2, finish: Vector2, outline: PackedVector2Array) -> Array:
	var out: Array = []
	var length := start.distance_to(finish)
	if length < .01: return out
	var tangent := (finish - start) / length
	for index in range(outline.size()):
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if absf(tangent.cross(b - a)) > .01 * a.distance_to(b) + .001: continue
		if absf(tangent.cross(a - start)) > .02: continue
		var from := clampf(minf((a - start).dot(tangent), (b - start).dot(tangent)), 0.0, length)
		var to := clampf(maxf((a - start).dot(tangent), (b - start).dot(tangent)), 0.0, length)
		if to - from > .05: out.append(Vector2(from, to))
	return out

func _outline_airlock_doorways(outline_zone: Dictionary) -> Array:
	var doorways: Array = []
	var outline_zone_index := zones.find(outline_zone)
	for structure in zones:
		if str(structure.get("kind", "")) != "airlock": continue
		if structure.has("angled_mount"): continue
		var cells: Array = structure.get("cells", [])
		if cells.is_empty(): continue
		var outside := _airlock_side(structure)
		var inner := _airlock_end(cells, outside, false)
		var attachment := _outline_attachment_for_face(inner, -outside)
		if bool(attachment.get("valid", false)) and int(attachment.get("zone_index", -1)) == outline_zone_index:
			doorways.append(attachment)
	return doorways

func _outline_wall_doorways(outline_zone: Dictionary) -> Array:
	var doorways := _outline_airlock_doorways(outline_zone)
	var outline_zone_index := zones.find(outline_zone)
	for connector in zones:
		if not connector.has("angled_mount"): continue
		var mount: Dictionary = connector.get("angled_mount", {})
		if int(mount.get("host_zone", -1)) != outline_zone_index: continue
		doorways.append({"edge_index": int(mount.get("edge_index", -1)), "opening_start": float(mount.get("opening_start", 0.0)), "opening_end": float(mount.get("opening_end", 0.0))})
	# Angled corridors whose far end arrives on one of this room's walls.
	for connector in zones:
		if not connector.has("angled_mount") or str(connector.get("kind", "")) != "corridor": continue
		var target := _angled_far_end_target(connector.get("angled_mount", {}))
		if int(target.get("zone_index", -1)) == outline_zone_index: doorways.append(target)
	var outline := zone_outline(outline_zone)
	for door_data in interior_doors:
		if door_data.has("wall_a"):
			for edge_index in range(outline.size()):
				for interval in _collinear_overlaps(outline[edge_index], outline[(edge_index + 1) % outline.size()], PackedVector2Array([door_data.wall_a, door_data.wall_b])):
					doorways.append({"edge_index": edge_index, "opening_start": interval.x, "opening_end": interval.y})
			continue
		if not door_data.has("outline_grid_cell"): continue
		var grid_cell: Vector2i = door_data.get("outline_grid_cell", Vector2i.ZERO)
		var grid_side: Vector2i = door_data.get("outline_grid_side", Vector2i.ZERO)
		var attachment := _outline_attachment_for_face(grid_cell, grid_side)
		if bool(attachment.get("valid", false)) and int(attachment.get("zone_index", -1)) == outline_zone_index:
			doorways.append(attachment)
	return doorways

func _prune_angled_outline_connectors() -> void:
	for index in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[index]
		if not zone.has("angled_mount"): continue
		# Find the host wall by position every rebuild. Stored indices go stale
		# as soon as an earlier zone is removed.
		var mount := _resolve_angled_host(zone.get("angled_mount", {}))
		if mount.is_empty():
			zones.remove_at(index)
			continue
		zone["angled_mount"] = mount
		var host_index := int(mount.host_zone)
		var edge_index := int(mount.edge_index)
		var outline := zone_outline(zones[host_index])
		var start: Vector2 = outline[edge_index]
		var finish: Vector2 = outline[(edge_index + 1) % outline.size()]
		var edge_length := start.distance_to(finish)
		var opening_start := float(mount.get("opening_start", 0.0))
		var opening_end := float(mount.get("opening_end", 0.0))
		if opening_start < ANGLED_CORNER_CLEARANCE or opening_end > edge_length - ANGLED_CORNER_CLEARANCE:
			zones.remove_at(index)
			continue
		var correct := _outline_outward_at(outline, mount.get("position", Vector2.ZERO), mount.get("tangent", Vector2.RIGHT))
		if correct == Vector2.ZERO:
			zones.remove_at(index)
		elif correct.dot(mount.get("outward", correct)) < 0.0:
			mount["outward"] = correct
			zone["angled_mount"] = mount
			zones[index] = zone

func _outline_wall_pieces(edge_length: float, doorways: Array, edge_index: int) -> Array:
	var openings: Array = []
	for doorway in doorways:
		if int(doorway.get("edge_index", -1)) == edge_index:
			openings.append(doorway)
	openings.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.get("opening_start", 0.0)) < float(second.get("opening_start", 0.0)))
	var pieces: Array = []
	var cursor := 0.0
	for opening in openings:
		var opening_start := clampf(float(opening.get("opening_start", 0.0)), 0.0, edge_length)
		var opening_end := clampf(float(opening.get("opening_end", 0.0)), 0.0, edge_length)
		if opening_start > cursor + .01: pieces.append({"start": cursor, "end": opening_start})
		cursor = maxf(cursor, opening_end)
	if cursor < edge_length - .01: pieces.append({"start": cursor, "end": edge_length})
	return pieces

func _add_rotated_box(position: Vector3, size: Vector3, basis: Basis, colour: Color, solid: bool, group := "") -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, position)
	body.collision_layer = 1
	body.collision_mask = 1
	if not group.is_empty(): body.add_to_group(group)
	root.add_child(body)
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; visual.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = .70; visual.material_override = material
	body.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)

func _add_outline_safety_light(wall_centre: Vector3, outward: Vector2, basis: Basis) -> void:
	var fixture := Node3D.new()
	fixture.name = "OutlineExteriorSafetyLight"
	# wall_centre is on the wall line itself; match the grid lamp offset from its face.
	fixture.transform = Transform3D(basis, wall_centre + Vector3(outward.x * .06, habitat_base_y + 2.36, outward.y * .06))
	root.add_child(fixture)
	var lens := MeshInstance3D.new(); var lens_mesh := BoxMesh.new(); lens_mesh.size = Vector3(.50, .16, .07); lens.mesh = lens_mesh
	var lens_material := StandardMaterial3D.new(); lens_material.albedo_color = Color("#F6E6B9"); lens_material.emission_enabled = true; lens_material.emission = Color("#FFE7AC"); lens_material.emission_energy_multiplier = 2.0; lens.material_override = lens_material
	lens.add_to_group("build_hidden_light_fixture"); lens.add_to_group("grid_powered_light"); lens.set_meta("grid_emission_on", Color("#FFE7AC")); lens.set_meta("grid_emission_off", Color("#293034")); fixture.add_child(lens)
	var flood := OmniLight3D.new(); flood.light_color = Color("#FFE2A1"); flood.light_energy = 2.2; flood.omni_range = 5.4; flood.shadow_enabled = false
	flood.add_to_group("grid_powered_light"); flood.set_meta("grid_light_energy", 2.2); fixture.add_child(flood)

# Verifies the same transform used by both the kit and its rotated backing.
# Run with `godot --headless --path . --script res://tests/outline_wall_layout_test.gd`.
func run_outline_wall_layout_self_test() -> bool:
	var angles: PackedFloat32Array = PackedFloat32Array([0.0, 30.0, 45.0, 60.0, 90.0, 120.0, 135.0, 180.0, 225.0, 270.0, 315.0])
	var passed := true
	for degrees in angles:
		var edge_angle: float = deg_to_rad(degrees)
		var tangent_2d := Vector2(cos(edge_angle), sin(edge_angle))
		var tangent := Vector3(tangent_2d.x, 0, tangent_2d.y)
		var wall_basis := Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP))
		var transformed_x := (wall_basis * Vector3.RIGHT).normalized()
		var transformed_negative_z := (wall_basis * Vector3.FORWARD).normalized()
		# _add_rotated_box uses this exact same basis; its long dimension is local X.
		var backing_long_axis := (wall_basis * Vector3.RIGHT).normalized()
		var x_matches_edge := transformed_x.is_equal_approx(tangent)
		var negative_z_perpendicular := absf(transformed_negative_z.dot(tangent)) < .0001
		var backing_matches_edge := backing_long_axis.is_equal_approx(tangent)
		var angle_passed := x_matches_edge and negative_z_perpendicular and backing_matches_edge
		passed = passed and angle_passed
		print("outline wall transform · %3d° | local X=%s edge=%s backing X=%s | %s" % [roundi(degrees), transformed_x, tangent, backing_long_axis, "PASS" if angle_passed else "FAIL"])
	if not passed:
		push_error("outline wall transform self-test FAILED")
		assert(false, "Free-form wall transform must keep local X and the backing long axis along the edge")
	print("outline wall transform self-test: PASS")
	return true

func _toggle_backing_debug_visibility() -> void:
	_debug_backings_visible = not _debug_backings_visible
	for backing in get_tree().get_nodes_in_group("habitat_wall"):
		_set_visual_children(backing, _debug_backings_visible)
	_flash_notice("info", "Wall backing debug", "Backing boxes %s · F9 toggles them." % ["visible" if _debug_backings_visible else "hidden"])

func _add_showcase_basis(scene: PackedScene, position: Vector3, basis: Basis, model_scale: Vector3) -> Node3D:
	var asset := scene.instantiate() as Node3D
	# Scale the model along its own axes (stretch along the wall). Basis.scaled()
	# scales along world axes instead, which skews any panel not facing N/S/E/W.
	asset.transform = Transform3D(Basis(basis.x * model_scale.x, basis.y * model_scale.y, basis.z * model_scale.z), position)
	asset.add_to_group("habitat_showcase_visual")
	MHGame.apply_kit_materials(asset)
	root.add_child(asset)
	return asset

func _add_freeform_slab(outline: PackedVector2Array, y: float, thickness: float, colour: Color, group: String) -> void:
	var triangles := Geometry2D.triangulate_polygon(outline)
	if triangles.is_empty(): return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var top_y := y + thickness * .5
	var bottom_y := y - thickness * .5
	for index in range(0, triangles.size(), 3):
		var a := Vector3(outline[triangles[index]].x, top_y, outline[triangles[index]].y)
		var b := Vector3(outline[triangles[index + 1]].x, top_y, outline[triangles[index + 1]].y)
		var c := Vector3(outline[triangles[index + 2]].x, top_y, outline[triangles[index + 2]].y)
		var below_a := Vector3(a.x, bottom_y, a.z); var below_b := Vector3(b.x, bottom_y, b.z); var below_c := Vector3(c.x, bottom_y, c.z)
		surface.add_vertex(a); surface.add_vertex(b); surface.add_vertex(c); surface.add_vertex(below_c); surface.add_vertex(below_b); surface.add_vertex(below_a)
		faces.append_array([a, b, c, below_c, below_b, below_a])
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		var top_a := Vector3(outline[index].x, top_y, outline[index].y); var top_b := Vector3(outline[next].x, top_y, outline[next].y)
		var bottom_a := Vector3(top_a.x, bottom_y, top_a.z); var bottom_b := Vector3(top_b.x, bottom_y, top_b.z)
		surface.add_vertex(top_a); surface.add_vertex(bottom_a); surface.add_vertex(bottom_b); surface.add_vertex(top_a); surface.add_vertex(bottom_b); surface.add_vertex(top_b)
		faces.append_array([top_a, bottom_a, bottom_b, top_a, bottom_b, top_b])
	var mesh := surface.commit()
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 1; body.add_to_group(group); root.add_child(body)
	var visual := MeshInstance3D.new(); visual.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = .70; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material; body.add_child(visual)
	var collision := CollisionShape3D.new(); var shape := ConcavePolygonShape3D.new(); shape.set_faces(faces); collision.shape = shape; body.add_child(collision)

func _add_freeform_plan_polygon(outline: PackedVector2Array, colour: Color, zone_kind: String) -> void:
	var triangles := Geometry2D.triangulate_polygon(outline)
	if triangles.is_empty(): return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new(); material.albedo_color = colour.darkened(PLAN_TILE_SHADE); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for index in triangles: mesh.surface_add_vertex(Vector3(outline[index].x, habitat_base_y + .025, outline[index].y))
	mesh.surface_end()
	var visual := MeshInstance3D.new(); visual.mesh = mesh; visual.name = zone_kind + "PlanPolygon"; visual.add_to_group("habitat_plan"); visual.visible = build_mode; visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(visual)

# Roof fittings give each room family a readable silhouette without becoming a
# second construction system. They are separate children of the generated
# shell and carry explicit metadata: when upper-storey construction arrives it
# can simply omit or remove these nodes rather than editing model geometry.
func _add_zone_roof_accessory(zone: Dictionary) -> void:
	var zone_kind := str(zone.get("kind", ""))
	if not ROOF_ACCESSORY_SCENES.has(zone_kind) or _zone_has_upper_storey(zone):
		return
	var cells: Array = _fitout_cells(zone)
	if cells.is_empty():
		return
	# Tiny single-cell spaces retain a clean roof. Larger connected rooms get a
	# small number of evenly spaced fittings, each snapped to a real roof cell.
	# Using the old average position could put a fitting over the missing square
	# in an L-shaped room.
	if cells.size() < 2:
		return
	var fitting_count := clampi(ceili(float(cells.size()) / 6.0), 1, 3)
	var used_indices: Dictionary = {}
	for fitting_index in range(fitting_count):
		var cell_index := clampi(roundi((float(fitting_index) + .5) * float(cells.size()) / float(fitting_count) - .5), 0, cells.size() - 1)
		while used_indices.has(cell_index) and cell_index < cells.size() - 1:
			cell_index += 1
		used_indices[cell_index] = true
		var roof_cell: Vector2i = cells[cell_index]
		var accessory := Node3D.new()
		accessory.name = "RemovableRoofAccessory_%s_%d" % [zone_kind, fitting_index + 1]
		accessory.position = Vector3(roof_cell.x * CELL, habitat_base_y + 2.98, roof_cell.y * CELL)
		accessory.set_meta("mh_roof_accessory", true)
		accessory.set_meta("remove_before_upper_storey", true)
		accessory.set_meta("zone_kind", zone_kind)
		root.add_child(accessory)
		var model: Node3D = (ROOF_ACCESSORY_SCENES[zone_kind] as PackedScene).instantiate()
		model.name = "%sRoofFitting" % zone_kind.capitalize()
		accessory.add_child(model)
		_seat_roof_accessory_on_roof(model)

func _seat_roof_accessory_on_roof(model: Node3D) -> void:
	# Blender assets do not all share the same origin. Find the lowest visible
	# point and place it on the roof, instead of assuming the origin is the base.
	var lowest := INF
	for raw_mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var bounds := mesh_instance.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point := model.to_local(mesh_instance.to_global(Vector3(x, y, z)))
					lowest = minf(lowest, point.y)
	if lowest != INF:
		model.position.y -= lowest - .01

func _zone_has_upper_storey(zone: Dictionary) -> bool:
	# Storeys are not buildable yet, but persisting this rule now makes roof
	# accessories forward-compatible. Any future zone one storey above an
	# overlapping footprint owns the roof and suppresses the removable fitting.
	var storey := int(zone.get("storey", 0))
	for other in zones:
		if other == zone or int(other.get("storey", 0)) <= storey:
			continue
		for cell in zone.get("cells", []):
			if cell in other.get("cells", []):
				return true
	return false

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
	var cells: Array = _fitout_cells(zone)
	# A small or narrow free-form room may have no cell well clear of its walls;
	# light it from the middle of its floor instead.
	if cells.is_empty() and zone.has("outline"):
		var middle := _outline_centroid(zone_outline(zone))
		if Geometry2D.is_point_in_polygon(middle, zone_outline(zone)):
			_add_powered_fixture(Vector3(middle.x, habitat_base_y + 2.81, middle.y), zone_kind)
		return
	for index in range(0, cells.size(), 2):
		var cell: Vector2i = cells[index]
		# The fixture housing is recessed into the roof slab rather than hovering
		# below it as a free-floating light strip.
		_add_powered_fixture(Vector3(cell.x * CELL, habitat_base_y + 2.81, cell.y * CELL), zone_kind)

## Cells whose centres sit well inside a zone, for ceiling lights and roof
## fittings. A free-form diagonal can pass straight through a cell centre.
func _fitout_cells(zone: Dictionary) -> Array:
	var cells: Array = zone.get("cells", [])
	if not zone.has("outline"): return cells
	var outline := zone_outline(zone)
	var clear_cells: Array = []
	for cell in cells:
		var centre := Vector2(cell.x * CELL, cell.y * CELL)
		if not Geometry2D.is_point_in_polygon(centre, outline): continue
		var clear := true
		for index in range(outline.size()):
			if centre.distance_to(Geometry2D.get_closest_point_to_segment(centre, outline[index], outline[(index + 1) % outline.size()])) < 1.0:
				clear = false
				break
		if clear: clear_cells.append(cell)
	return clear_cells

func _outline_centroid(outline: PackedVector2Array) -> Vector2:
	var middle := Vector2.ZERO
	for point in outline: middle += point
	return middle / maxf(1.0, float(outline.size()))

func _add_powered_fixture(position: Vector3, zone_kind: String, basis := Basis.IDENTITY) -> void:
	var fixture := Node3D.new()
	fixture.name = "CeilingLight"
	fixture.transform = Transform3D(basis, position)
	root.add_child(fixture)
	var housing := MeshInstance3D.new()
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(1.08, .14, .38)
	housing.mesh = housing_mesh
	var housing_material := StandardMaterial3D.new()
	housing_material.albedo_color = MHStyle.SEAL_DARK.lightened(.08)
	housing_material.metallic = .45
	housing_material.roughness = .42
	housing.material_override = housing_material
	fixture.add_child(housing)
	var diffuser := MeshInstance3D.new()
	var diffuser_mesh := BoxMesh.new()
	diffuser_mesh.size = Vector3(.84, .035, .18)
	diffuser.mesh = diffuser_mesh
	diffuser.position.y = -.08
	var diffuser_material := StandardMaterial3D.new()
	diffuser_material.albedo_color = Color("#F3E4C6")
	diffuser_material.emission_enabled = true
	diffuser_material.emission = Color("#FFE7B2")
	diffuser_material.emission_energy_multiplier = 1.7
	diffuser.material_override = diffuser_material
	# Lit by its room's state (update_room_lights), not by a light of its own:
	# each room has one soft fill light instead of one light per fixture.
	diffuser.add_to_group("room_fixture")
	diffuser.set_meta("room_key", _room_key_at(Vector2(position.x, position.z)))
	fixture.add_child(diffuser)

func _cell_walls(cell: Vector2i,zone: Dictionary) -> void:
	var zone_kind:=str(zone.kind); var colour:Color=ZONE_TYPES[zone_kind].colour; var centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
	_add_plan_tile(centre,plan_colour(zone_kind),zone_kind)
	for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		# Shared walls between two habitat spaces get no outdoor flood light.
		if _should_build_wall(cell,side): _add_exterior_wall(centre,side,zone_kind,zone,not _is_habitat_zone(_zone_across(cell,side)))

## The habitat on the far side of a grid cell face: the grid zone in the next
## cell, or a free-form room whose straight wall runs along that whole face.
## Every grid wall, corridor end and bay door decision goes through this, so
## angled rooms connect exactly like grid rooms do.
func _zone_across(cell: Vector2i, side: Vector2i) -> Dictionary:
	var grid_zone := _zone_at(cell + side)
	if not grid_zone.is_empty(): return grid_zone
	var attachment := _outline_attachment_for_face(cell, side)
	if bool(attachment.get("valid", false)): return zones[int(attachment.zone_index)]
	return {}

func _should_build_wall(cell: Vector2i,side: Vector2i) -> bool:
	# The airlock owns its inner threshold. This must win regardless of whether
	# the attached room, corridor or the airlock itself was placed first.
	if _is_airlock_inner_doorway(cell,side): return false
	# This also covers a grid room's deliberate doorway into a free-form room.
	if _has_interior_door(cell, side): return false
	# A corridor is a sealed tube until an end reaches another habitat space.
	# When that happens, remove the wall on both sides of that one end only;
	# its two long sides always remain solid.
	if _corridor_end_connects(cell, side): return false
	var current_zone := _zone_at(cell)
	var neighbour_zone := _zone_across(cell, side)
	if not _is_habitat_zone(neighbour_zone):
		return true
	# A free-form room never builds wall bays along a face that a grid zone
	# owns, so the grid side always draws this shared wall.
	if neighbour_zone.has("outline"):
		return true
	# Cells painted as part of one room remain a single open interior volume.
	if current_zone == neighbour_zone or (str(current_zone.get("kind", "")) == str(neighbour_zone.get("kind", "")) and _footprint_zone_is_editable(current_zone) and _footprint_zone_is_editable(neighbour_zone)):
		return false
	# Different room volumes are sealed. Render the shared wall exactly once so
	# two coplanar wall kits cannot fight each other visually.
	return _is_canonical_shared_edge(cell, side)

func _corridor_end_connects(cell: Vector2i, side: Vector2i) -> bool:
	var current_zone := _zone_at(cell)
	var neighbour_zone := _zone_across(cell, side)
	if not current_zone.is_empty() and str(current_zone.get("kind", "")) == "corridor":
		if not _is_corridor_side(current_zone, side) and _is_habitat_zone(neighbour_zone) and neighbour_zone != current_zone:
			return true
	if not neighbour_zone.is_empty() and str(neighbour_zone.get("kind", "")) == "corridor":
		if not _is_corridor_side(neighbour_zone, -side) and not current_zone.is_empty() and current_zone != neighbour_zone:
			return true
	return false

func _is_canonical_shared_edge(cell: Vector2i, side: Vector2i) -> bool:
	var neighbour := cell + side
	return cell.x < neighbour.x or (cell.x == neighbour.x and cell.y < neighbour.y)

func _canonical_interior_door(cell: Vector2i, side: Vector2i) -> Dictionary:
	if side.x < 0 or side.y < 0:
		return {"cell": cell + side, "side": -side}
	return {"cell": cell, "side": side}

func _has_interior_door(cell: Vector2i, side: Vector2i) -> bool:
	var canonical := _canonical_interior_door(cell, side)
	for data in interior_doors:
		if data.has("outline_grid_cell") and data.get("outline_grid_cell", Vector2i.ZERO) == cell and data.get("outline_grid_side", Vector2i.ZERO) == side:
			return true
		if data.get("cell", Vector2i.ZERO) == canonical.cell and data.get("side", Vector2i.ZERO) == canonical.side:
			return true
	return false

func _zone_is_rectangle(zone: Dictionary) -> bool:
	var cells: Array = zone.get("cells", [])
	if cells.is_empty(): return false
	var min_x: int = cells[0].x
	var max_x: int = cells[0].x
	var min_z: int = cells[0].y
	var max_z: int = cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x); max_x = maxi(max_x, cell.x)
		min_z = mini(min_z, cell.y); max_z = maxi(max_z, cell.y)
	return cells.size() == (max_x - min_x + 1) * (max_z - min_z + 1)

## Interior door targets come in three shapes: {"cell","side"} between grid
## zones (or a grid room and a free-form wall), and {"wall_a","wall_b"} for a
## 3 m opening on a wall shared by two free-form rooms. The interior builder
## only ever passes these dictionaries around.
func interior_door_target_invalid_reason(target: Dictionary) -> String:
	if target.has("wall_a"):
		if target.has("invalid"): return str(target.invalid)
		var middle: Vector2 = (target.wall_a + target.wall_b) * .5
		for data in interior_doors:
			if data.has("wall_a") and middle.distance_to((data.wall_a + data.wall_b) * .5) < CELL - .05: return "Interior door already installed"
		return ""
	if target.is_empty(): return "Aim at a shared room wall"
	return interior_door_invalid_reason(target.get("cell", Vector2i.ZERO), target.get("side", Vector2i.ZERO))

func place_interior_door_target(target: Dictionary) -> bool:
	if not interior_door_target_invalid_reason(target).is_empty(): return false
	if target.has("wall_a"):
		interior_doors.append({"wall_a": target.wall_a, "wall_b": target.wall_b})
		_rebuild()
		return true
	return place_interior_door(target.get("cell", Vector2i.ZERO), target.get("side", Vector2i.ZERO))

## Centre of a target's opening at deck level, with local X along the wall.
func interior_door_target_transform(target: Dictionary) -> Transform3D:
	if target.has("wall_a"):
		var a: Vector2 = target.wall_a
		var b: Vector2 = target.wall_b
		var along := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
		return Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3((a.x + b.x) * .5, habitat_base_y, (a.y + b.y) * .5))
	var cell: Vector2i = target.get("cell", Vector2i.ZERO)
	var side: Vector2i = target.get("side", Vector2i.ZERO)
	var x_axis := Vector3(0, 0, 1) if side.x != 0 else Vector3(1, 0, 0)
	return Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), Vector3(cell.x * CELL + side.x * HALF_CELL, habitat_base_y, cell.y * CELL + side.y * HALF_CELL))

## A 3 m doorway centred as near `point` as fits on a wall shared by two
## free-form rooms, as {"wall_a","wall_b"} (plus "invalid" when it cannot
## fit); empty when no shared free-form wall is there.
func _shared_outline_wall_at(point: Vector2) -> Dictionary:
	for first_index in range(zones.size()):
		if not zones[first_index].has("outline"): continue
		var outline := zone_outline(zones[first_index])
		for edge_index in range(outline.size()):
			var a := outline[edge_index]
			var b := outline[(edge_index + 1) % outline.size()]
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) > .35: continue
			var length := a.distance_to(b)
			var tangent := (b - a) / length
			var along := (point - a).dot(tangent)
			for second_index in range(first_index + 1, zones.size()):
				if not zones[second_index].has("outline"): continue
				for interval in _collinear_overlaps(a, b, zone_outline(zones[second_index])):
					if along < interval.x - .05 or along > interval.y + .05: continue
					if interval.y - interval.x < CELL - .01:
						return {"wall_a": a + tangent * interval.x, "wall_b": a + tangent * interval.y, "invalid": "Shared wall is too short for a 3 m doorway"}
					var centre := clampf(along, interval.x + HALF_CELL, interval.y - HALF_CELL)
					return {"wall_a": a + tangent * (centre - HALF_CELL), "wall_b": a + tangent * (centre + HALF_CELL)}
	return {}

func interior_door_invalid_reason(cell: Vector2i, side: Vector2i) -> String:
	if abs(side.x) + abs(side.y) != 1:
		return "Aim at a shared room wall"
	var first := _zone_at(cell)
	var outline_attachment := _outline_attachment_for_face(cell, side)
	if not first.is_empty() and _is_ordinary_room_kind(str(first.kind)) and bool(outline_attachment.get("valid", false)):
		if _has_interior_door(cell, side): return "Interior door already installed"
		return ""
	var neighbour := cell + side
	var second := _zone_at(neighbour)
	if first.is_empty() or second.is_empty() or not _is_habitat_zone(first) or not _is_habitat_zone(second):
		return "Doorways join two completed rooms"
	if first == second:
		return "This is already part of one room"
	if str(first.kind) == "airlock" or str(second.kind) == "airlock":
		return "Use an airlock hatch here"
	if _has_interior_door(cell, side):
		return "Interior door already installed"
	return ""

func place_interior_door(cell: Vector2i, side: Vector2i) -> bool:
	if not interior_door_invalid_reason(cell, side).is_empty():
		return false
	_store_interior_door({"cell": cell, "side": side})
	_rebuild()
	return true

# ---------- hull windows ----------

func _hull_bay_can_glaze(zone_kind: String) -> bool:
	# Rooms and corridors take windows; airlocks and vehicle bays stay solid.
	return zone_kind not in ["airlock", "vehicle_bay"] + SITE_MACHINES

## Same direction for a wall whichever way it was walked.
static func _canonical_wall_dir(tangent: Vector2) -> Vector2:
	var t := tangent.normalized()
	return t if t.x > .001 or (absf(t.x) <= .001 and t.y > 0.0) else -t

func _window_index_at(mid: Vector2, dir: Vector2) -> int:
	for index in range(hull_windows.size()):
		var data: Dictionary = hull_windows[index]
		if (data.mid as Vector2).distance_to(mid) < .6 and absf((data.dir as Vector2).dot(dir)) > .99: return index
	return -1

## Record a Mars-facing bay and, if it is glazed, build the window there.
## Returns true when a window was built (the caller then skips its wall).
func _register_hull_bay(mid: Vector2, tangent: Vector2, outward: Vector2, length: float, zone_kind: String) -> bool:
	var dir := _canonical_wall_dir(tangent)
	_hull_bays.append({"mid": mid, "dir": dir, "tangent": tangent.normalized(), "outward": outward.normalized(), "length": length, "zone_kind": zone_kind})
	var index := _window_index_at(mid, dir)
	if index < 0: return false
	_windows_built[index] = true
	_add_window_bay(mid, tangent.normalized(), outward.normalized(), length)
	return true

## Wall-bay transform: local X along the wall, Y up, -Z facing Mars.
func _bay_basis(tangent: Vector2, outward: Vector2) -> Basis:
	var along := Vector3(tangent.x, 0, tangent.y)
	var x_axis := along if (-along.cross(Vector3.UP)).dot(Vector3(outward.x, 0, outward.y)) > 0.0 else -along
	return Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))

var _window_glass_material: StandardMaterial3D
## Placeholder window bay: solid lower panel and header, two jambs and a
## glazed band from WINDOW_SILL to WINDOW_HEAD. Every part collides, so the
## hull stays sealed; real art can replace it bay for bay later.
func _add_window_bay(mid: Vector2, tangent: Vector2, outward: Vector2, length: float) -> void:
	var basis := _bay_basis(tangent, outward)
	var inset := Vector3(outward.x, 0, outward.y) * -.035
	var base := Vector3(mid.x, habitat_base_y, mid.y) + inset
	var along := basis.x
	var frame := MHStyle.STRUCTURAL_WHITE
	var glass_height := WINDOW_HEAD - WINDOW_SILL
	_add_rotated_box(base + Vector3.UP * WINDOW_SILL * .5, Vector3(length + .07, WINDOW_SILL, .2), basis, frame.darkened(.06), true, "habitat_wall")
	_add_rotated_box(base + Vector3.UP * (WINDOW_HEAD + (ROOM_HEIGHT - WINDOW_HEAD) * .5), Vector3(length + .07, ROOM_HEIGHT - WINDOW_HEAD, .2), basis, frame, true, "habitat_wall")
	for side in [-1.0, 1.0]:
		_add_rotated_box(base + along * (side * (length * .5 - .14)) + Vector3.UP * (WINDOW_SILL + glass_height * .5), Vector3(.28, glass_height, .24), basis, MHStyle.FRAME_STEEL, true, "habitat_wall")
	# Sill and head trims in the colony accent, so windows read from outside.
	for height in [WINDOW_SILL, WINDOW_HEAD]:
		var trim := MeshInstance3D.new(); var trim_mesh := BoxMesh.new(); trim_mesh.size = Vector3(length - .3, .06, .3); trim.mesh = trim_mesh
		trim.material_override = MHGame.accent_material()
		trim.transform = Transform3D(basis, base + Vector3.UP * height)
		root.add_child(trim)
	if _window_glass_material == null:
		_window_glass_material = StandardMaterial3D.new()
		_window_glass_material.albedo_color = Color(.62, .78, .86, .22)
		_window_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_window_glass_material.roughness = .05
		_window_glass_material.metallic = .3
		_window_glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := StaticBody3D.new()
	glass.name = "WindowGlass"
	glass.transform = Transform3D(basis, base + Vector3.UP * (WINDOW_SILL + glass_height * .5))
	glass.add_to_group("habitat_wall")
	glass.add_to_group("hull_window_glass")
	root.add_child(glass)
	var pane := MeshInstance3D.new(); var pane_mesh := BoxMesh.new(); pane_mesh.size = Vector3(length - .5, glass_height, .04); pane.mesh = pane_mesh
	pane.material_override = _window_glass_material
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.add_child(pane)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(length - .5, glass_height, .06); collision.shape = shape
	glass.add_child(collision)
	# Site-plan marker: a pale blue bar along the wall.
	var marker := MeshInstance3D.new(); marker.name = "WindowPlanMarker"
	var marker_mesh := BoxMesh.new(); marker_mesh.size = Vector3(length - .5, .06, .4); marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new(); marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; marker_material.albedo_color = Color("#8FD8FF")
	marker.material_override = marker_material
	marker.transform = Transform3D(basis, Vector3(mid.x, habitat_base_y + .14, mid.y))
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_to_group("habitat_plan")
	marker.visible = build_mode
	root.add_child(marker)

## Windows whose wall bay no longer faces Mars (room removed, wall now
## shared or opened) are taken out and their cargo refunded.
func _prune_hull_windows() -> void:
	var refund := 0
	for index in range(hull_windows.size() - 1, -1, -1):
		if _windows_built.has(index): continue
		hull_windows.remove_at(index)
		refund += window_cargo()
	if refund > 0:
		_windows_built = {}
		for bay_index in range(hull_windows.size()): _windows_built[bay_index] = true
		_flash_notice("info", "Windows removed", "+%s cargo returned · their wall no longer faces Mars." % MHStyle.kg(refund), false)

## The Mars-facing wall bay a first-person aim point is on; {} if none.
func window_target_at(point: Vector3) -> Dictionary:
	if point.y < habitat_base_y or point.y > habitat_base_y + ROOM_HEIGHT: return {}
	var flat := Vector2(point.x, point.z)
	for bay in _hull_bays:
		var half_length: float = float(bay.length) * .5
		var relative: Vector2 = flat - (bay.mid as Vector2)
		if absf(relative.dot(bay.tangent)) <= half_length and absf(relative.dot(bay.outward)) < .45: return bay
	return {}

func window_invalid_reason(target: Dictionary) -> String:
	if target.is_empty(): return "Aim at an outside wall of a room or corridor"
	if _window_index_at(target.mid, target.dir) >= 0: return "This wall bay already has a window"
	if _used_cargo() + window_cargo() > MHGame.cargo_budget(): return "Not enough cargo left"
	return ""

## Centre of a bay's wall at mid-height, local X along the wall.
func window_target_transform(target: Dictionary) -> Transform3D:
	return Transform3D(_bay_basis(target.tangent, target.outward), Vector3(target.mid.x, habitat_base_y + ROOM_HEIGHT * .5, target.mid.y))

func place_window(target: Dictionary) -> bool:
	if not window_invalid_reason(target).is_empty(): return false
	var data := {"mid": target.mid, "dir": target.dir}
	hull_windows.append(data)
	_history.append({"type": "window", "window": data})
	_rebuild()
	return true

## Index of the window an aim point is on; -1 if none.
func window_index_near(point: Vector3) -> int:
	var bay := window_target_at(point)
	return -1 if bay.is_empty() else _window_index_at(bay.mid, bay.dir)

func remove_window(index: int) -> void:
	if index < 0 or index >= hull_windows.size(): return
	hull_windows.remove_at(index)
	_rebuild()

## Undo the most recent interior structure change (Ctrl+Z in Interior mode),
## leaving rooms alone.
func undo_last_structure() -> bool:
	for step_index in range(_history.size() - 1, -1, -1):
		var step: Dictionary = _history[step_index]
		if str(step.get("type", "")) == "partition":
			_history.remove_at(step_index)
			var index := partition_index(step.segment)
			if index < 0: continue
			if step.has("was_door"):   # a changed panel goes back
				partitions[index].door = bool(step.was_door)
				partitions[index].glass = bool(step.get("was_glass", false))
			else: partitions.remove_at(index)   # a new panel is removed
			_rebuild()
			_flash_notice("info", "Undone", "Partition change undone.")
			return true
		if str(step.get("type", "")) != "window": continue
		_history.remove_at(step_index)
		var index := _window_index_at(step.window.mid, step.window.dir)
		if index < 0: continue
		hull_windows.remove_at(index)
		_rebuild()
		_flash_notice("info", "Undone", "Window removed · +%s cargo returned." % MHStyle.kg(window_cargo()))
		return true
	return false

# ---------- interior partition walls ----------

static func partition_cargo() -> int:
	return int(MHResources.setting("partition_cargo_kg", 60.0))

## The 1.5 m partition segment nearest a floor point: on the half-cell grid,
## along whichever grid line is closest. {a, b} on the ground plane.
func partition_segment_at(point: Vector3) -> Dictionary:
	var p := Vector2(point.x, point.z)
	var step := PARTITION_STEP
	var gx := roundf(p.x / step) * step
	var gz := roundf(p.y / step) * step
	if absf(p.x - gx) < absf(p.y - gz):
		var z0 := floorf(p.y / step) * step
		return {"a": Vector2(gx, z0), "b": Vector2(gx, z0 + step)}
	var x0 := floorf(p.x / step) * step
	return {"a": Vector2(x0, gz), "b": Vector2(x0 + step, gz)}

func partition_index(segment: Dictionary) -> int:
	if segment.is_empty(): return -1
	for index in range(partitions.size()):
		var other: Dictionary = partitions[index]
		var a: Vector2 = other.a
		var b: Vector2 = other.b
		if (a.is_equal_approx(segment.a) and b.is_equal_approx(segment.b)) or (a.is_equal_approx(segment.b) and b.is_equal_approx(segment.a)): return index
	return -1

## The room a segment sits inside, or {} if it runs along an outer wall,
## crosses into another room or isn't in a room at all.
func _partition_room(segment: Dictionary) -> Dictionary:
	var a: Vector2 = segment.a
	var b: Vector2 = segment.b
	var mid := (a + b) * .5
	var along := (b - a).normalized()
	var normal := Vector2(-along.y, along.x)
	var first := _zone_at_point(mid + normal * .4)
	var second := _zone_at_point(mid - normal * .4)
	if first.is_empty() or not is_same(first, second): return {}
	# Both ends must be in the same room too (not poking through a wall).
	for end in [a + along * .3, b - along * .3]:
		if not is_same(_zone_at_point(end + normal * .2), first): return {}
	return first

func partition_invalid_reason(segment: Dictionary, door := false, glass := false) -> String:
	if segment.is_empty(): return "Aim at the floor of a room"
	var room := _partition_room(segment)
	if room.is_empty(): return "Partitions go inside a room, not along its outer walls"
	if not _is_habitat_zone(room) or str(room.kind) in ["corridor", "airlock", "vehicle_bay"]: return "Partitions go in rooms, not corridors, airlocks or the vehicle bay"
	var index := partition_index(segment)
	if index >= 0:
		if bool(partitions[index].door) == door and bool(partitions[index].get("glass", false)) == glass: return "There's already a %s here" % ("door" if door else ("glass panel" if glass else "wall"))
		return ""   # a panel changes type (wall, glass or door)
	# Floor-standing equipment in the way.
	for item in placed_interior:
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		if str(entry.get("placement", "floor")) == "wall": continue
		if str(entry.get("placement", "floor")) == "ceiling": continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var mid := (a + b) * .5
		if _interior_footprints_overlap(at, _free_interior_size(entry), float(item.get("rotation_y", 0.0)), Vector3(mid.x, 0, mid.y), Vector3((b - a).length(), 0, PARTITION_THICKNESS), -atan2((b - a).y, (b - a).x)):
			return "Blocked by the %s" % str(entry.get("label", "equipment")).to_lower()
	if _used_cargo() + earth_cost(partition_cargo(), true) > MHGame.cargo_budget(): return "Not enough cargo left"
	return ""

## Add a wall, glass or door segment (or change a panel's type). Undo with Ctrl+Z.
func place_partition(segment: Dictionary, door := false, glass := false) -> bool:
	if not partition_invalid_reason(segment, door, glass).is_empty(): return false
	var index := partition_index(segment)
	if index >= 0:
		_history.append({"type": "partition", "segment": {"a": segment.a, "b": segment.b}, "was_door": bool(partitions[index].door), "was_glass": bool(partitions[index].get("glass", false))})
		partitions[index].door = door
		partitions[index].glass = glass and not door
	else:
		partitions.append({"a": segment.a, "b": segment.b, "door": door, "glass": glass and not door})
		_history.append({"type": "partition", "segment": {"a": segment.a, "b": segment.b}})
	_rebuild()
	habitat_changed.emit()
	return true

func remove_partition(index: int) -> void:
	if index < 0 or index >= partitions.size(): return
	# Anything hung on this panel comes down with it.
	var segment: Dictionary = partitions[index]
	for item in placed_interior.duplicate():
		if str(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("placement", "floor")) != "wall": continue
		var at: Vector3 = item.get("position", Vector3.ZERO)
		var flat := Vector2(at.x, at.z)
		if Geometry2D.get_closest_point_to_segment(flat, segment.a, segment.b).distance_to(flat) < .2:
			remove_free_interior_equipment(str(item.get("placement_id", "")))
	partitions.remove_at(index)
	_rebuild()
	habitat_changed.emit()
	_flash_notice("valid", "Removed", "Partition removed · +%s cargo returned." % MHStyle.kg(partition_cargo()))

## The partition segment a world point is on or next to, or -1.
func partition_index_near(point: Vector3) -> int:
	var p := Vector2(point.x, point.z)
	for index in range(partitions.size()):
		var segment: Dictionary = partitions[index]
		if Geometry2D.get_closest_point_to_segment(p, segment.a, segment.b).distance_to(p) < .2: return index
	return -1

## Standing transform for a segment's wall: centred on it, facing across it.
func partition_transform(segment: Dictionary) -> Transform3D:
	var a: Vector2 = segment.a
	var b: Vector2 = segment.b
	var mid := (a + b) * .5
	var along := b - a
	return Transform3D(Basis(Vector3.UP, -atan2(along.y, along.x)), Vector3(mid.x, habitat_base_y, mid.y))

## Partitions whose room has gone (or changed shape) are removed.
func _prune_partitions() -> void:
	for index in range(partitions.size() - 1, -1, -1):
		var room := _partition_room(partitions[index])
		if room.is_empty() or str(room.kind) in ["corridor", "airlock", "vehicle_bay"]: partitions.remove_at(index)

func _build_partitions() -> void:
	var height := ROOM_HEIGHT - .12
	var panel := StandardMaterial3D.new(); panel.albedo_color = Color("#E6E4DC"); panel.roughness = .82
	var trim := StandardMaterial3D.new(); trim.albedo_color = Color("#2F3639"); trim.roughness = .6
	var accent := StandardMaterial3D.new(); accent.albedo_color = MHStyle.accent; accent.roughness = .5
	var frame := StandardMaterial3D.new(); frame.albedo_color = Color("#9AA3A8"); frame.metallic = .8; frame.roughness = .35
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(.72, .88, .95, .22)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.roughness = .05
	glass_material.metallic_specular = .9
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in range(partitions.size()):
		var segment: Dictionary = partitions[index]
		var holder := Node3D.new()
		holder.name = "Partition_%d" % index
		holder.transform = partition_transform(segment)
		root.add_child(holder)
		var length := PARTITION_STEP + .02
		if bool(segment.get("glass", false)) and not bool(segment.door):
			# Glass: a brushed metal frame (posts, sill, head and a mid rail) round
			# two panes. Still solid to walk into.
			var frame_w := .06
			for side in [-1.0, 1.0]:
				_partition_box(holder, Vector3(frame_w, height, PARTITION_THICKNESS + .02), Vector3(side * (length - frame_w) * .5, height * .5, 0), frame, index, false)
			for rail_y in [.05, 1.0, height - .03]:
				_partition_box(holder, Vector3(length, .06 if rail_y > .1 else .1, PARTITION_THICKNESS + .02), Vector3(0, rail_y, 0), frame, index, false)
			_partition_box(holder, Vector3(length - frame_w * 2.0, height - .1, .03), Vector3(0, height * .5, 0), glass_material, index, true)
		elif not bool(segment.door):
			_partition_box(holder, Vector3(length, height, PARTITION_THICKNESS), Vector3(0, height * .5, 0), panel, index, true)
			_partition_box(holder, Vector3(length, .12, PARTITION_THICKNESS + .02), Vector3(0, .06, 0), trim, index, false)
		else:
			# Door: two thin posts, a header, and a leaf that swings on its hinge.
			var post := .1
			var opening := length - post * 2.0
			for side in [-1.0, 1.0]:
				_partition_box(holder, Vector3(post, height, PARTITION_THICKNESS + .02), Vector3(side * (length - post) * .5, height * .5, 0), trim, index, true)
			_partition_box(holder, Vector3(opening, height - 2.1, PARTITION_THICKNESS), Vector3(0, 2.1 + (height - 2.1) * .5, 0), panel, index, true)
			var door := Node3D.new()
			door.set_script(PARTITION_DOOR_SCRIPT)
			door.position = Vector3(-opening * .5, 0, 0)   # hinge at one post
			holder.add_child(door)
			var leaf := Node3D.new()
			door.add_child(leaf)
			door.call("setup", leaf)
			var leaf_body := _partition_box(leaf, Vector3(opening - .02, 2.06, .05), Vector3(opening * .5, 1.04, 0), panel, index, true)
			leaf_body.set_meta("interaction_target", door)
			_partition_box(leaf, Vector3(.04, .3, .09), Vector3(opening - .12, 1.0, 0), accent, index, false)
		# Site plan: a dark line (orange for doors).
		var plan := MeshInstance3D.new()
		var plan_mesh := BoxMesh.new(); plan_mesh.size = Vector3(PARTITION_STEP, .04, .14); plan.mesh = plan_mesh
		var plan_material := StandardMaterial3D.new(); plan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plan_material.albedo_color = MHStyle.accent if bool(segment.door) else Color("#0E1417")
		plan.material_override = plan_material
		plan.position = Vector3(0, .12, 0)
		plan.add_to_group("habitat_plan")
		plan.visible = build_mode
		holder.add_child(plan)

func _partition_box(parent: Node3D, size: Vector3, at: Vector3, material: Material, index: int, solid: bool) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = at
	body.set_meta("partition_index", index)
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = size; mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		(body as StaticBody3D).collision_layer = 1
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new(); box_shape.size = size; shape.shape = box_shape
		body.add_child(shape)
	return body

## Record a valid door target in the shape the rebuild understands.
func _store_interior_door(target: Dictionary) -> void:
	if target.has("wall_a"):
		interior_doors.append({"wall_a": target.wall_a, "wall_b": target.wall_b})
		return
	var cell: Vector2i = target.get("cell", Vector2i.ZERO)
	var side: Vector2i = target.get("side", Vector2i.ZERO)
	if bool(_outline_attachment_for_face(cell, side).get("valid", false)):
		interior_doors.append({"outline_grid_cell": cell, "outline_grid_side": side})
	else:
		interior_doors.append(_canonical_interior_door(cell, side))

## Centre of a stored interior door on the ground plane.
func _interior_door_centre(data: Dictionary) -> Vector2:
	if data.has("wall_a"): return (data.wall_a + data.wall_b) * .5
	var cell: Vector2i = data.get("outline_grid_cell", data.get("cell", Vector2i.ZERO))
	var side: Vector2i = data.get("outline_grid_side", data.get("side", Vector2i.ZERO))
	return Vector2(cell.x * CELL + side.x * HALF_CELL, cell.y * CELL + side.y * HALF_CELL)

## Index of the interior door whose opening is within reach of a world
## point (aiming at the hatch or the wall right beside it); -1 if none.
func interior_door_index_near(point: Vector3) -> int:
	if point.y > habitat_base_y + ROOM_HEIGHT: return -1
	for index in range(interior_doors.size()):
		if _interior_door_centre(interior_doors[index]).distance_to(Vector2(point.x, point.z)) < 1.6: return index
	return -1

func remove_interior_door(index: int) -> void:
	if index < 0 or index >= interior_doors.size(): return
	interior_doors.remove_at(index)
	_rebuild()

## True when an interior door already joins rooms `first` and `second`.
func _rooms_have_door(first: Dictionary, second: Dictionary) -> bool:
	for data in interior_doors:
		var centre := _interior_door_centre(data)
		var touches_first := false
		var touches_second := false
		for offset in [Vector2(.6, 0), Vector2(-.6, 0), Vector2(0, .6), Vector2(0, -.6), Vector2(.45, .45), Vector2(-.45, -.45), Vector2(.45, -.45), Vector2(-.45, .45)]:
			var zone := _zone_at_point(centre + offset)
			if zone == first: touches_first = true
			elif zone == second: touches_second = true
		if touches_first and touches_second: return true
	return false

## After a room is placed: every room of a different purpose it now touches
## gets one door in the middle of their longest shared wall, so a new layout
## works without a trip to Interior mode. Returns the labels of rooms joined.
## Runs only on placement, so a door the player removes stays removed.
func _add_doors_for_new_room(zone: Dictionary) -> Array:
	# One door to get a new room connected: none if it already has a door to
	# something, otherwise the best neighbour (a corridor first, then the
	# longest shared wall). Any more doors are the player's choice (the
	# Interior door tool), as is moving this one (remove it, place another).
	var joined: Array = []
	if zones.find(zone) < 0 or not _mergeable_room(zone): return joined
	var mine := zone_outline(zone)
	var best := {}
	var best_score := -1.0
	for other in zones:
		if other == zone or not _mergeable_room(other) or str(other.kind) == str(zone.kind): continue
		if _rooms_have_door(zone, other): return joined
		var theirs := zone_outline(other)
		var best_length := 0.0
		var best_from := Vector2.ZERO
		var best_to := Vector2.ZERO
		for index in range(mine.size()):
			var a := mine[index]
			var b := mine[(index + 1) % mine.size()]
			var tangent := (b - a).normalized()
			for interval in _collinear_overlaps(a, b, theirs):
				if interval.y - interval.x > best_length:
					best_length = interval.y - interval.x
					best_from = a + tangent * interval.x
					best_to = a + tangent * interval.y
		if best_length < CELL - .01: continue
		var target := _door_target_on_wall(best_from, best_to)
		if target.is_empty(): continue
		var score := best_length + (100.0 if str(other.kind) == "corridor" else 0.0)
		if score > best_score:
			best_score = score
			best = {"target": target, "label": str(ZONE_TYPES[str(other.kind)].label)}
	if not best.is_empty():
		_store_interior_door(best.target)
		joined.append(best.label)
	return joined

## A valid 3 m door target on a shared wall from→to, as near its middle as
## the wall's cells allow; {} if none fits.
func _door_target_on_wall(from: Vector2, to: Vector2) -> Dictionary:
	var length := from.distance_to(to)
	var tangent := (to - from) / length
	var normal := Vector2(-tangent.y, tangent.x)
	var offsets: Array = [0.0]
	for step in range(1, ceili(length / CELL) + 1):
		offsets.append(step * CELL)
		offsets.append(-step * CELL)
	for offset in offsets:
		var along := length * .5 + float(offset)
		if along < HALF_CELL - .01 or along > length - HALF_CELL + .01: continue
		var point := from + tangent * along
		for face in [normal, -normal]:
			var on_face: Vector2 = point + face * .08
			var target := interior_door_from_world_point(Vector3(on_face.x, habitat_base_y + 1.4, on_face.y), Vector3(face.x, 0, face.y))
			if not target.is_empty() and interior_door_target_invalid_reason(target).is_empty(): return target
	return {}

## Placement follow-up: join the newest room to different neighbours.
func _after_room_placed() -> void:
	if _history.is_empty(): return
	var joined := _add_doors_for_new_room(_history.back().get("zone", {}))
	if joined.is_empty(): return
	_rebuild()
	_flash_notice("info", "Door added", "Joined to %s. Remove it in Interior mode (X) if you want this wall sealed." % ", ".join(joined), false)

func interior_door_from_world_point(point: Vector3, normal: Vector3) -> Dictionary:
	var shared := _shared_outline_wall_at(Vector2(point.x, point.z))
	if not shared.is_empty(): return shared
	# A rendered wall has thickness, so its two faces return slightly different
	# hit positions. Use the hit face normal to identify the room-side cell first,
	# then canonicalise it; this makes aiming from either room target one opening.
	if absf(normal.x) >= absf(normal.z):
		var hit_cell := Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))
		if normal.x > 0.0:
			return {"cell": hit_cell + Vector2i(-1, 0), "side": Vector2i(1, 0)}
		return {"cell": hit_cell, "side": Vector2i(1, 0)}
	var hit_cell := Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))
	if normal.z > 0.0:
		return {"cell": hit_cell + Vector2i(0, -1), "side": Vector2i(0, 1)}
	return {"cell": hit_cell, "side": Vector2i(0, 1)}

func _prune_interior_doors() -> void:
	for index in range(interior_doors.size() - 1, -1, -1):
		var data := interior_doors[index] as Dictionary
		if data.has("wall_a"):
			var still_shared := _shared_outline_wall_at((data.wall_a + data.wall_b) * .5)
			if still_shared.is_empty() or still_shared.has("invalid"): interior_doors.remove_at(index)
			continue
		if data.has("outline_grid_cell"):
			var grid_cell: Vector2i = data.get("outline_grid_cell", Vector2i.ZERO)
			var grid_side: Vector2i = data.get("outline_grid_side", Vector2i.ZERO)
			var grid_zone := _zone_at(grid_cell)
			var attachment := _outline_attachment_for_face(grid_cell, grid_side)
			if grid_zone.is_empty() or not _is_ordinary_room_kind(str(grid_zone.kind)) or not bool(attachment.get("valid", false)):
				interior_doors.remove_at(index)
			continue
		var cell: Vector2i = data.get("cell", Vector2i.ZERO)
		var side: Vector2i = data.get("side", Vector2i.ZERO)
		var first := _zone_at(cell)
		var second := _zone_at(cell + side)
		if first.is_empty() or second.is_empty() or not _is_habitat_zone(first) or not _is_habitat_zone(second) or first == second or str(first.kind) == "airlock" or str(second.kind) == "airlock":
			interior_doors.remove_at(index)

func _is_airlock_inner_doorway(cell: Vector2i,side: Vector2i) -> bool:
	for zone in zones:
		if str(zone.kind)!="airlock": continue
		if zone.has("angled_mount"): continue
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
			if side!=outside and side!=-outside: _add_exterior_wall(centre,side,"airlock",zone,not _is_habitat_zone(_zone_across(cell,side)))

func _build_vehicle_bay(zone: Dictionary) -> void:
	var outside:=_airlock_side(zone)
	var cells:Array=zone.cells
	# Find real zone-to-zone edges first.  Edges between cells in this same bay
	# are just its interior floorplan, never connections and never doors.
	var connection_edges:Array=[]
	for cell in cells:
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side!=outside and not (cell+side in cells) and _is_habitat_zone(_zone_across(cell,side)):
				connection_edges.append({"cell":cell,"side":side})
	# One deliberately placed personnel bulkhead is clearer and safer than a
	# door on every cell of a shared edge.  Other edges remain solid wall.
	var explicit_edges: Array = []
	# A corridor end butting onto the bay is a deliberate route in, so it always
	# gets its own bulkhead (the corridor has already opened its end wall).
	var corridor_edges: Array = []
	var room_edges: Array = []
	for edge in connection_edges:
		if _has_interior_door(edge.cell, edge.side):
			explicit_edges.append(edge)
		if _corridor_end_connects(edge.cell, edge.side): corridor_edges.append(edge)
		else: room_edges.append(edge)
	var access_edge: Dictionary={}
	# Preserve the original convenient bay hatch for existing saves, but once
	# players choose an explicit interior door they own exactly which edge opens.
	if explicit_edges.is_empty() and not room_edges.is_empty(): access_edge=room_edges[room_edges.size()/2]
	var bay_doors: Array[AirlockDoor] = []
	for cell in zone.cells:
		var centre:=Vector3(cell.x*CELL,0,cell.y*CELL)
		_add_plan_tile(centre,ZONE_TYPES["vehicle_bay"].colour,"vehicle_bay")
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if side==outside: continue # The sealed, opening hangar door owns this face.
			if cell+side in cells: continue
			if _has_interior_door(cell, side):
				bay_doors.append(_add_door(centre,side,"BAY",true))
				continue
			# A bay never opens directly into the habitat: sealed personnel
			# bulkheads are the only routes between them.
			if {"cell":cell,"side":side} in corridor_edges or (not access_edge.is_empty() and cell==access_edge.cell and side==access_edge.side):
				bay_doors.append(_add_door(centre,side,"BAY",false))
				continue
			_add_exterior_wall(centre,side,"vehicle_bay",zone,not _is_habitat_zone(_zone_across(cell,side)))
	var face:=_zone_face(zone,outside)
	var hangar:=AIRLOCK_DOOR.new(); hangar.position=face.position; hangar.rotation.y=_direction_yaw(outside); root.add_child(hangar)
	# The wide exterior hatch is interlocked with every internal bay door.
	# Internal doors may share the pressurised habitat, but all must close before
	# the hangar can open to Mars.
	hangar.setup("HANGAR",true,face.width,2.58); _add_door_plan_marker(hangar,"HANGAR",face.width-.4)
	for bay_door in bay_doors:
		hangar.add_partner(bay_door)
		bay_door.add_partner(hangar)

func _build_solar(zone: Dictionary) -> void:
	var cell:Vector2i=zone.cells[0]
	var position:=Vector3(cell.x*CELL,_terrain_height(Vector3(cell.x*CELL,0,cell.y*CELL)),cell.y*CELL)
	_add_showcase(SHOWCASE_SOLAR,position,_direction_yaw(_airlock_side(zone)))
	# The visual comes from Blender; this small base prevents the player walking
	# through the mast without giving the solar panel an oversized collider. A
	# larger pad also makes its ground contact clear on uneven Mars terrain.
	_add_box(position+Vector3(0,.08,0),Vector3(1.75,.16,1.45),MHStyle.SEAL_DARK,true,"solar_base",true)
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["solar"].colour,"solar")

func _build_reactor(zone: Dictionary) -> void:
	var cell: Vector2i = zone.cells[0]
	var position := Vector3(cell.x * CELL, _terrain_height(Vector3(cell.x * CELL, 0, cell.y * CELL)), cell.y * CELL)
	_add_site_machine(zone, "surface_reactor", position, Vector3(2.3, 2.1, 1.7))
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["reactor"].colour,"reactor")

func _build_ice_extractor(zone: Dictionary) -> void:
	var cell: Vector2i = zone.cells[0]
	var position := Vector3(cell.x * CELL, _terrain_height(Vector3(cell.x * CELL, 0, cell.y * CELL)), cell.y * CELL)
	_add_site_machine(zone, "ice_drill", position, Vector3(2.2, 2.6, 1.5))
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["ice_extractor"].colour,"ice_extractor")

func _build_regolith_intake(zone: Dictionary) -> void:
	var cell: Vector2i = zone.cells[0]
	var position := Vector3(cell.x * CELL, _terrain_height(Vector3(cell.x * CELL, 0, cell.y * CELL)), cell.y * CELL)
	_add_site_machine(zone, "regolith_intake", position, Vector3(2.0, 1.2, 2.4))
	_add_plan_tile(Vector3(cell.x*CELL,0,cell.y*CELL),ZONE_TYPES["regolith_intake"].colour,"regolith_intake")

## A reactor or ice extractor model on its cell, with a solid box to walk
## around and its interaction rig (switch state saved in the zone).
func _add_site_machine(zone: Dictionary, model_id: String, position: Vector3, size: Vector3) -> void:
	if not zone.has("placement_id"): zone["placement_id"] = "zone_%s_%d_%d" % [str(zone.kind), (zone.cells[0] as Vector2i).x, (zone.cells[0] as Vector2i).y]
	var holder := Node3D.new()
	holder.name = "SiteMachine_%s" % model_id
	holder.position = position
	# Controls on the front (-Z) face the habitat, where the crew walk out from.
	var centre := Vector2.ZERO
	var count := 0
	for other in zones:
		if not _is_habitat_zone(other): continue
		for cell in other.get("cells", []):
			centre += Vector2(cell.x * CELL, cell.y * CELL); count += 1
	if count > 0:
		var towards := centre / count - Vector2(position.x, position.z)
		if towards.length() > .1: holder.rotation.y = atan2(-towards.x, -towards.y)
	holder.set_meta("zone_placement_id", str(zone.placement_id))
	root.add_child(holder)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_to_group(str(zone.kind))
	holder.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = size
	collision.shape = shape; collision.position.y = size.y * .5
	body.add_child(collision)
	var path := str(EquipmentCatalog.get_entry(model_id).get("asset_scene", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		holder.add_child(model)
		if model.has_method("interaction_prompt"): body.set_meta("interaction_target", model)

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

func _add_exterior_wall(centre: Vector3,side: Vector2i,zone_kind: String,zone: Dictionary,facing_mars := true) -> void:
	if facing_mars and _hull_bay_can_glaze(zone_kind):
		var mid := Vector2(centre.x + side.x * HALF_CELL, centre.z + side.y * HALF_CELL)
		if _register_hull_bay(mid, Vector2(-side.y, side.x), Vector2(side.x, side.y), CELL, zone_kind):
			_add_exterior_safety_light(centre, side)
			return
	var wall_position:=centre+Vector3(side.x*CELL*.5,habitat_base_y+1.45,side.y*CELL*.5)
	var wall_size:=Vector3(.16,2.9,CELL) if side.x!=0 else Vector3(CELL,2.9,.16)
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
	if facing_mars: _add_exterior_safety_light(centre, side)

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
	# The physical fixture is useful in exploration but reads as noisy loose
	# rectangles in the blueprint view. Keep the actual OmniLight active while
	# hiding only this visible lens in build mode.
	lens.add_to_group("build_hidden_light_fixture")
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

## A short bar across the wall at every door, shown only on the site plan, so
## the plan says which spaces connect.
func _add_door_plan_marker(door: Node3D, door_name: String, width := CELL - .6) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "DoorPlanMarker"
	var mesh := BoxMesh.new(); mesh.size = Vector3(width, .06, .5); marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MHStyle.accent if door_name in ["OUTER", "HANGAR"] else (MHStyle.BEACON_YELLOW if door_name in ["INNER", "BAY"] else Color("#F2F4F5"))
	marker.material_override = material
	marker.position = Vector3(0, .14, 0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_to_group("habitat_plan")
	marker.visible = build_mode
	door.add_child(marker)

func _add_door(centre: Vector3,side: Vector2i,door_name := "AIRLOCK",show_surround := true) -> AirlockDoor:
	var position:=centre+Vector3(side.x*CELL*.5,habitat_base_y,side.y*CELL*.5)
	if show_surround: _add_showcase(SHOWCASE_AIRLOCK,position,_direction_yaw(side))
	var door:=AIRLOCK_DOOR.new(); door.position=position; door.rotation.y=_direction_yaw(side); root.add_child(door)
	# The exterior has the Blender surround. Give the far/inner threshold a
	# compact frame of its own so it is visibly an actual hatch, not a panel.
	door.setup(door_name,not show_surround)
	_add_door_plan_marker(door, door_name)
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

func _add_showcase(scene: PackedScene,position: Vector3,yaw := 0.0,model_scale := Vector3.ONE) -> void:
	var asset:=scene.instantiate()
	asset.position=position
	asset.rotation.y=yaw
	asset.scale=model_scale
	asset.add_to_group("habitat_showcase_visual")
	MHGame.apply_kit_materials(asset)
	root.add_child(asset)

func _add_plan_tile(centre: Vector3,colour: Color,zone_kind: String) -> void:
	var tile:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=Vector3(CELL-.28,.045,CELL-.28); tile.mesh=mesh
	var material:=StandardMaterial3D.new(); material.albedo_color=colour.darkened(PLAN_TILE_SHADE); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
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
	if zone.has("angled_mount"):
		var mount: Dictionary = zone.get("angled_mount", {})
		var mount_position: Vector2 = mount.get("position", Vector2.ZERO)
		var outward: Vector2 = mount.get("outward", Vector2.UP)
		var run := float(mount.get("length", CELL)) * .5
		centre = Vector3(mount_position.x + outward.x * run, 0, mount_position.y + outward.y * run)
	elif zone.has("outline"):
		var outline := zone_outline(zone)
		for point in outline: centre += Vector3(point.x, 0, point.y)
		centre /= outline.size()
	else:
		for cell in cells: centre+=Vector3(cell.x*CELL,0,cell.y*CELL)
		centre/=cells.size()
	var label:=_label3d(str(ZONE_TYPES[zone.kind].label).to_upper(),40,MHStyle.INK_100); label.position=centre+Vector3(0,habitat_base_y+.4,0); label.offset=Vector2(0,22); label.visible=build_mode; label.add_to_group("zone_label"); root.add_child(label)
	var size_text := "%d CELLS" % cells.size() if not zone.has("angled_mount") else "ANGLED · %.1f m" % float(zone.angled_mount.get("length", CELL))
	var detail:=_label3d("%s · %s" % [size_text,MHStyle.kg(int(zone.cost))],28,plan_colour(str(zone.kind)).lightened(.35),600); detail.font=MHStyle.font(600,true,1); detail.position=centre+Vector3(0,habitat_base_y+.4,0); detail.offset=Vector2(0,-24); detail.visible=build_mode; detail.add_to_group("zone_label"); root.add_child(detail)

func _set_build_view(show_plan: bool) -> void:
	# Exterior build is deliberately schematic. Hide every rendered habitat,
	# interior-equipment and surface-prop visual first; only plan layers below
	# are allowed back in. This avoids slowly accumulating exceptions such as
	# wall lamps, supports, doors or imported model parts leaking into the map.
	for visual_root in [root, furnishing, surface_furnishing]:
		_set_visual_children(visual_root, not show_plan)
	for plan in get_tree().get_nodes_in_group("habitat_plan"):
		plan.visible=show_plan
		_set_visual_children(plan,show_plan)
	for label in get_tree().get_nodes_in_group("zone_label"): label.visible=show_plan
	for field in get_tree().get_nodes_in_group("power_field_visual"): field.visible=show_plan
	for overlay in get_tree().get_nodes_in_group("site_plan_overlay"): overlay.visible=show_plan

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
	# The site ground is generated from MHSiteTerrain's height function, so
	# read it directly: exact, and never fooled by placed equipment or by a
	# ray slipping through a mesh vertex.
	return MHSiteTerrain.height(point.x, point.z)

func _build_foundation_supports() -> void:
	# Purposeful pylons only at exposed outer corners, rather than a post under
	# every cell. They appear only where the raised platform needs them.
	var points:Dictionary={}
	for zone in zones:
		if zone.has("outline"): continue
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
	var mouse_point := _world_point_at_mouse(habitat_base_y)
	var selected_zone := _zone_at_point(Vector2(mouse_point.x, mouse_point.z)) if not is_inf(mouse_point.x) else _zone_at(cell)
	for index in range(zones.size()-1,-1,-1):
		if zones[index] == selected_zone:
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
		if step.type=="window":
			var window_index:=_window_index_at(step.window.mid,step.window.dir)
			if window_index<0: continue
			hull_windows.remove_at(window_index)
			_rebuild()
			_flash_notice("info","Undone","Window removed · +%s cargo returned." % MHStyle.kg(window_cargo()))
			return
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
	if zone.has("undo_restore"):
		# This room grew by merging; undo returns it to its earlier shape.
		var restored: Dictionary = zone.undo_restore
		zones[index] = restored
		var merge_refund := int(zone.cost) - int(restored.cost)
		_rebuild()
		_flash_notice("info","Undone","%s returned to its earlier shape · +%s cargo returned." % [ZONE_TYPES[zone.kind].label,MHStyle.kg(merge_refund)])
		return
	zones.remove_at(index)
	if zones.is_empty(): habitat_base_y=.35
	var refund:=int(zone.cost)+_prune_equipment()
	_rebuild()
	_flash_notice("info","Undone","%s removed · +%s cargo returned." % [ZONE_TYPES[zone.kind].label,MHStyle.kg(refund)])

func _zone_cost(cells: Array) -> int: return cell_cost(kind)*cells.size()

## Landed cargo (kg) for one 3 x 3 m cell of a room type, or one solar array,
## reactor or ice extractor, from the balance spreadsheet.
func cell_cost(zone_kind: String) -> int:
	var site_item: String = {"solar": "solar_array", "reactor": "surface_reactor", "ice_extractor": "ice_drill", "regolith_intake": "regolith_intake"}.get(zone_kind, "")
	if not site_item.is_empty(): return int(MHResources.item_value(site_item, "cargo_kg", 300.0))
	return int(MHResources.room(zone_kind).get("cargo_kg_per_cell", 800.0))

static func window_cargo() -> int:
	return int(MHResources.setting("window_cargo_kg", 150.0))

## A saved zone's cargo at today's balance numbers (older saves used other costs).
func _recompute_zone_cost(zone: Dictionary) -> void:
	var zone_kind := str(zone.get("kind", ""))
	if zone.has("angled_mount"):
		zone["cost"] = cell_cost(zone_kind) * (_angled_corridor_bays(float(zone.angled_mount.get("length", CELL))) if zone_kind == "corridor" else 1)
	elif zone.has("outline") and (zone.outline as Array).size() >= 3:
		zone["cost"] = ceili(_freeform_area(PackedVector2Array(zone.outline)) * cell_cost(zone_kind) / (CELL * CELL))
	else:
		zone["cost"] = cell_cost(zone_kind) * (zone.get("cells", []) as Array).size()
## Earth cargo in use. Mars-made (printed) material pays for printable
## things first, so it never needs tracking per item: removing a printed
## wall simply frees the material again.
func _used_cargo() -> int:
	return _total_cargo() - mars_made_used()

## Mars-made material made so far (printed by regolith printers).
func mars_made_total() -> int:
	return int(simulation().printed_kg)

## The cost of everything printable that's placed: room shells, corridors,
## partitions and printable furniture.
func printable_cargo() -> int:
	var total := 0
	for zone in zones:
		if not str(zone.kind) in PRINTABLE_ZONE_EXCLUDES: total += int(zone.cost)
	for item in placed_interior:
		var entry := EquipmentCatalog.get_entry(str(item.get("id", "")))
		if bool(entry.get("printable", false)): total += int(entry.get("cargo_cost", 0))
	total += partitions.size() * partition_cargo()
	return total

func mars_made_used() -> int: return mini(mars_made_total(), printable_cargo())
func mars_made_left() -> int: return mars_made_total() - mars_made_used()

## How much Earth cargo a new thing costing `cost` would take.
func earth_cost(cost: int, printable: bool) -> int:
	return maxi(0, cost - mars_made_left()) if printable else cost

func zone_printable(zone_kind: String) -> bool: return not zone_kind in PRINTABLE_ZONE_EXCLUDES
func item_printable(id: String) -> bool: return bool(EquipmentCatalog.get_entry(id).get("printable", false))

func _total_cargo() -> int:
	var total:=0
	for zone in zones: total+=int(zone.cost)
	for item in placed_equipment:
		total += int(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("cargo_cost", 0))
	for item in placed_interior:
		total += int(EquipmentCatalog.get_entry(str(item.get("id", ""))).get("cargo_cost", 0))
	total += hull_windows.size() * window_cargo()
	total += partitions.size() * partition_cargo()
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
	if MHGame.cargo_unlimited():
		# Sandbox (or the debug cheat): show what is used, not a limit.
		cargo_meter.value=cargo_meter.max_value
		cargo_meter.value_label="Unlimited · %s used" % MHStyle.kg(_used_cargo())
		cargo_meter.tone="info"
		return
	var remaining:=MHGame.cargo_budget()-_used_cargo()
	cargo_meter.max_value=MHGame.cargo_budget()
	cargo_meter.value_label=""
	cargo_meter.value=remaining
	cargo_meter.tone="accent" if remaining>MHGame.cargo_budget()*.1 else "warn"
	if mars_made_label != null:
		var printed := mars_made_total()
		mars_made_label.visible = printed > 0 or simulation().print_rate(simulation().inventory()) > 0.0
		mars_made_label.text = "MARS-MADE  %s in stock · %s used" % [MHStyle.kg(mars_made_left()), MHStyle.kg(mars_made_used())]

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
		counts[str(zone.kind)] += 1 if zone.has("angled_mount") else zone.cells.size()
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
		if str(zone.kind)=="solar" and _power_source_connected(zone): generation+=SOLAR_OUTPUT*_solar_efficiency(_airlock_side(zone))*MHGame.solar_irradiance(MHGame.sol_hour)
		elif str(zone.kind)=="reactor" and _power_source_connected(zone) and _zone_running(zone): generation+=REACTOR_OUTPUT
	var draw:int=counts.living+counts.storage+counts.corridor+counts.airlock*2+counts.hydroponics*5+counts.life_support*3+counts.engineering*4+counts.science*5+counts.vehicle_bay*4+counts.galley*3+counts.hygiene*2+counts.medical*3+counts.waste_management*3+counts.communications*2+counts.ice_extractor*8+int(equipment.power_draw)
	for zone in zones:
		if str(zone.kind)=="ice_extractor" and not _zone_running(zone): draw -= 8 # a stopped drill draws nothing
	var heated_cells := 0
	for zone in zones:
		if not _is_habitat_zone(zone): continue
		if zone.has("angled_mount"): heated_cells += _angled_corridor_bays(float(zone.angled_mount.get("length", CELL))) if str(zone.kind) == "corridor" else 1
		else: heated_cells += (zone.cells as Array).size()
	# Each window leaks heat like WINDOW_HEAT_LOSS_CELLS cells of hull.
	var heating := roundi((float(heated_cells) + hull_windows.size() * WINDOW_HEAT_LOSS_CELLS) * maxf(0.0, HABITAT_TEMPERATURE_C - MHGame.outside_temperature_c) * HEATING_PER_CELL_DEGREE)
	draw += heating
	# A distribution cabinet's main isolator switched off cuts the habitat off
	# from its generators: nothing reaches the grid until it is switched back on.
	var isolated := false
	for item in placed_interior:
		var isolator := EquipmentCatalog.grid_isolator_key(str(item.get("id", "")))
		if not isolator.is_empty() and not bool((item.get("state", {}) as Dictionary).get(isolator, true)): isolated = true
	if isolated: generation = 0.0
	if MHGame.debug_free_power: generation = maxf(generation, float(draw) + 1000.0)
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
			if str(zone.kind)=="ice_extractor" and _zone_running(zone): water += _ice_yield(zone.cells[0])
	return {"crew":crew,"crew_requirement":crew_requirement,"crew_capacity":crew_capacity,"berths":berths,"food":food,"food_capacity":food_capacity,"life":life_support,"life_capacity":life_capacity,"water":water,"research":research,"research_capacity":research_capacity,"happiness":int(equipment.happiness),"water_draw":int(equipment.water_draw),"generation":roundi(generation),"draw":draw,"heating":heating,"isolated":isolated}

## The reactor's master isolator / the ice extractor's run switch (saved in
## the zone's state; both start on).
func _zone_running(zone: Dictionary) -> bool:
	var key: String = {"reactor": "isolator", "regolith_intake": "intake"}.get(str(zone.get("kind", "")), "drill")
	return bool((zone.get("state", {}) as Dictionary).get(key, true))

func grid_power_online() -> bool:
	if not MHGame.simulation_on(): return true
	return simulation().tier_powered(HABITAT_SIM.TIER_LIGHT, MHGame.sol_hour)

var _last_power_key := ""
func refresh_power_grid() -> void:
	# Public hook for the day/night cycle and future equipment after it joins
	# the power groups.
	_apply_grid_power()
	var key := str(grid_power_online()) + str((simulation().last.get("tiers", {}) as Dictionary).values())
	if key != _last_power_key:
		_last_power_key = key
		if not display_only: _update_systems(); _update_summary()
		power_changed.emit()

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
	update_room_lights()

func _solar_efficiency(direction: Vector2i, sun_heading := Vector2.INF) -> float:
	# Panels catch most light facing the sun. It crosses the southern sky, so a
	# south-facing panel peaks at noon; east and west favour morning and evening.
	var heading := MHGame.sun_heading(MHGame.sol_hour) if is_inf(sun_heading.x) else sun_heading
	return .55 + .45 * Vector2(direction).dot(heading)

# ---------- save / restore ----------
# Only simulation records are serialised.  Meshes, colliders and HUD are rebuilt
# from those records so saves remain valid when presentation assets are updated.
func surface_entry(id: String) -> Dictionary:
	return SURFACE_EQUIPMENT.get(id, {}) as Dictionary

func surface_invalid_reason(id: String, position: Vector3) -> String:
	var entry := surface_entry(id)
	if entry.is_empty(): return "Unknown surface equipment"
	if is_inside(position): return "Keep surface equipment outside the habitat"
	if lander != null and lander.keeps_clear(Vector2(position.x, position.z), float(entry.get("radius", .6))): return "Too close to the lander"
	if MHMissions.active() and not MHMissions.item_unlocked(id): return "Not delivered yet: this arrives in a later mission"
	if MHMissions.in_blast_zone(Vector2(position.x, position.z)): return "Inside the landing zone: engine blast would damage it"
	var radius := float(entry.get("radius", .6))
	# Off the ground: crates only, on a pallet, a workbench or another crate.
	if position.y > _terrain_height(position) + .2:
		if not bool(entry.get("stackable", false)): return "Place this on level ground"
		if surface_stack_support(id, position).is_empty(): return "Set this on a pallet, workbench or crate"
	for item in placed_surface:
		var other: Dictionary = item as Dictionary
		var other_entry := surface_entry(str(other.get("id", "")))
		var other_position: Vector3 = other.get("position", Vector3.ZERO)
		# Stacked: one sits on top of the other, so their heights don't meet.
		var other_top := float(other_entry.get("top", other_entry.get("height", 1.2)))
		if position.y >= other_position.y + other_top - .03 or position.y + float(entry.get("height", 1.2)) <= other_position.y + .03:
			continue
		if Vector2(position.x, position.z).distance_to(Vector2(other_position.x, other_position.z)) < radius + float(other_entry.get("radius", .6)) + .25:
			return "Too close to surface equipment"
	return ""

## The pallet, workbench or crate an outdoor crate would rest on here, or {}.
func surface_stack_support(id: String, position: Vector3) -> Dictionary:
	if not bool(surface_entry(id).get("stackable", false)): return {}
	for item in placed_surface:
		var other_entry := surface_entry(str(item.get("id", "")))
		var at: Vector3 = item.get("position", Vector3.ZERO)
		if not other_entry.has("top") or absf(at.y + float(other_entry.top) - position.y) > .05: continue
		if Vector2(position.x - at.x, position.z - at.z).length() <= float(other_entry.get("top_radius", .3)):
			return item
	return {}

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
	var rig := holder.get_node_or_null("Model")
	if rig != null and rig.has_method("interaction_prompt"): collision_body.set_meta("interaction_target", rig)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(entry.get("radius", .6))
	shape.height = float(entry.get("height", 1.2))
	collision.shape = shape
	collision.position.y = shape.height * .5
	collision_body.add_child(collision)
	holder.add_child(collision_body)
	set_draw_distance(holder, SURFACE_DRAW_DISTANCE)
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
		var item: Dictionary = placed_surface[index]
		if str(item.get("placement_id", "")) != placement_id:
			continue
		# Crates stacked on it come off with it.
		var top := float(surface_entry(str(item.get("id", ""))).get("top", 0.0))
		var reach := float(surface_entry(str(item.get("id", ""))).get("top_radius", .3))
		var at: Vector3 = item.get("position", Vector3.ZERO)
		for other in placed_surface.duplicate():
			var other_at: Vector3 = other.get("position", Vector3.ZERO)
			if top > 0.0 and other != item and absf(at.y + top - other_at.y) < .05 and Vector2(other_at.x - at.x, other_at.z - at.z).length() <= reach:
				remove_surface_equipment(str(other.get("placement_id", "")))
		placed_surface.remove_at(placed_surface.find(item))
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
		"interior_doors": interior_doors.duplicate(true),
		"hull_windows": hull_windows.duplicate(true),
		"partitions": partitions.duplicate(true),
		"placed_surface": placed_surface.duplicate(true),
		"simulation": simulation().save(),
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
		# Glass Greenhouse has been retired: Mars-facing transparent walls are not
		# credible pressure-habitat construction. Preserve a player's layout by
		# turning older saves into sealed Hydroponics instead of dropping cells.
		if str(saved_zone.get("kind", "")) == "glass_room":
			saved_zone["kind"] = "hydroponics"
		if not saved_zone.has("door_direction"):
			saved_zone["door_direction"] = Vector2i(0, -1)
		_recompute_zone_cost(saved_zone)
		zones[index] = saved_zone
	placed_equipment = (state.get("placed_equipment", []) as Array).duplicate(true)
	placed_interior.clear()
	interior_doors = (state.get("interior_doors", []) as Array).duplicate(true)
	hull_windows = (state.get("hull_windows", []) as Array).duplicate(true)
	partitions = (state.get("partitions", []) as Array).duplicate(true)
	# Older saves may contain the retired room_shape_modifiers key. It is
	# deliberately ignored so those saves load as ordinary modular rooms.
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
		# Record first, so an interaction rig can read its saved state on _ready.
		placed_interior.append(item.duplicate(true))
		furnishing.add_child(visual)
	for raw_item in state.get("placed_surface", []) as Array:
		var surface_item: Dictionary = raw_item as Dictionary
		var surface_id := str(surface_item.get("id", ""))
		var surface_visual_instance := surface_visual(surface_id, surface_item.get("position", Vector3.ZERO) as Vector3, float(surface_item.get("rotation_y", 0.0)))
		if surface_entry(surface_id).is_empty():
			surface_visual_instance.queue_free()
			continue
		surface_visual_instance.name = "Surface_%s" % str(surface_item.get("placement_id", surface_id))
		surface_visual_instance.set_meta("surface_placement_id", str(surface_item.get("placement_id", "")))
		# Record first, so its interaction rig reads the saved switches on _ready.
		placed_surface.append(surface_item.duplicate(true))
		surface_furnishing.add_child(surface_visual_instance)
	_history.clear()
	_sim = HABITAT_SIM.new(self)
	simulation().load(state.get("simulation", {}) as Dictionary)
	_rebuild()

func _update_systems() -> void:
	simulation().invalidate()
	_update_summary()
	_refresh_catalogue()

# ---------- readiness (Mission Control, explore HUD) ----------
# Simple aggregate checks for the target crew; game-balance estimates only.
func readiness() -> Array:
	var systems:=_systems()
	var habitat_cells:=0; var airlock_cells:=0; var reachable:=0
	var route:=_airlock_connected_cells()
	for zone in zones:
		if str(zone.kind) in SITE_MACHINES: continue
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
	# Life support from the simulation's numbers (docs/resource-model.md).
	var flows: Dictionary = simulation().daily_flows()
	var crew := int(flows.crew)
	var sim: RefCounted = simulation()
	items.append(_ratio_item("beds", "Crew bunks", float(flows.berths), float(crew), "bed-double", "%d / %d bunks" % [int(flows.berths), crew]))
	var air_ok := minf(float(flows.co2_removed) / maxf(.01, float(flows.co2_made)), float(flows.o2_made) / maxf(.01, float(flows.o2_need)))
	items.append(_ratio_item("life", "Air", air_ok, 1.0, "wind", "CO₂ %d/%d · O₂ %d/%d kg" % [roundi(flows.co2_removed), roundi(flows.co2_made), roundi(flows.o2_made), roundi(flows.o2_need)]))
	items.append(_ratio_item("water", "Water", float(flows.water_made), float(flows.water_used), "droplets", "%d L made / %d L used a sol" % [roundi(flows.water_made), roundi(flows.water_used)]))
	var food_sols := float(sim.food_kg) / maxf(.01, float(flows.food_eaten) - float(flows.food_grown))
	var food_detail := "Grows %.1f of %.1f kg a sol" % [flows.food_grown, flows.food_eaten] + (" · %d sols stored" % floori(food_sols) if float(sim.food_kg) > 0.0 and float(flows.food_grown) < float(flows.food_eaten) else "")
	items.append({"id": "food", "label": "Food", "detail": food_detail, "status": "met" if food_sols >= 30.0 or float(flows.food_grown) >= float(flows.food_eaten) else ("partial" if float(sim.food_kg) > 0.0 or float(flows.food_grown) > 0.0 else "unmet"), "icon": "wheat"})
	var rooms: Array = sim.crewed_rooms()
	var warm := 0
	for room in rooms:
		if float(sim.room_temp.get(room.key, 20.0)) >= 18.0: warm += 1
	items.append({"id": "heat", "label": "Heating", "detail": "%d / %d rooms comfortable" % [warm, rooms.size()] if MHGame.simulation_on() else "Off in Creative", "status": "met" if warm == rooms.size() and not rooms.is_empty() else ("partial" if warm > 0 else "unmet"), "icon": "sun"})
	items.append(_fitted_target_item("research","Research capability",int(systems.research),int(systems.research_capacity),RESEARCH_TARGET,"flask-conical"))
	var power_status := "met"
	var power_detail := "Unlimited in Creative"
	if MHGame.simulation_on():
		var last: Dictionary = sim.last if not sim.last.is_empty() else {}
		var capacity_kwh := float(sim.inventory().capacity.kwh)
		var tiers: Dictionary = last.get("tiers", {})
		power_status = "met" if bool(tiers.get(4, false)) else ("partial" if bool(tiers.get(1, false)) else "unmet")
		power_detail = "%.1f kW made · %.1f kW used" % [float(last.get("generation_kw", 0.0)), float(last.get("demand_kw", last.get("load_kw", 0.0)))] + (" · battery %d%%" % roundi(100.0 * float(sim.battery_kwh) / capacity_kwh) if capacity_kwh > 0.0 else " · no battery")
	items.append({"id":"power","label":"Power","detail":power_detail,"status":power_status,"icon":"zap"})
	return items

func _ratio_item(id: String, item_label: String, have: float, need: float, icon_name: String, detail: String) -> Dictionary:
	var status := "met" if have >= need - .001 and need > 0.0 else ("partial" if have > 0.0 else "unmet")
	return {"id": id, "label": item_label, "detail": detail, "status": status, "icon": icon_name}

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
		if str(zone.kind)==zone_kind: total += 1 if zone.has("angled_mount") else zone.cells.size()
	return total

func readiness_met() -> int:
	var met:=0
	for item in readiness():
		if item.status=="met": met+=1
	return met

func suggestion() -> String:
	var left:=MHStyle.kg(MHGame.cargo_budget()-_used_cargo())
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
			"power": return "Add Solar Arrays on open ground. Aim them north (R) for full output. You have %s left." % left
	return "Every system is ready for a crew of %d. Spend spare cargo on science or storage — %s left." % [CREW_TARGET,left]

func cargo_by_category() -> Dictionary:
	var out:={"rooms":0,"structure":0,"power":0,"equipment":0}
	for zone in zones: out[str(ZONE_INFO[zone.kind].cat)]+=int(zone.cost)
	for item in placed_equipment: out.equipment+=int(EquipmentCatalog.get_entry(str(item.get("id",""))).get("cargo_cost",0))
	for item in placed_interior: out.equipment+=int(EquipmentCatalog.get_entry(str(item.get("id",""))).get("cargo_cost",0))
	out.structure+=hull_windows.size()*window_cargo()+partitions.size()*partition_cargo()
	return out

func used_cargo() -> int: return _used_cargo()

func zone_outline(zone: Dictionary) -> PackedVector2Array:
	# Future room tools may store an explicit outline. Use it exactly as saved;
	# ordinary rooms without one build their outline from their occupied cells.
	var saved_outline: Variant = zone.get("outline", null)
	if saved_outline != null:
		var supplied := PackedVector2Array()
		for raw_point in saved_outline:
			if raw_point is Vector2:
				supplied.append(raw_point as Vector2)
		return supplied
	var zone_kind := str(zone.get("kind", ""))
	if zone_kind in NON_ROOM_KINDS:
		return PackedVector2Array()
	var edges: Dictionary = {}
	for raw_cell in zone.get("cells", []):
		var cell := raw_cell as Vector2i
		var top_left := Vector2i(cell.x * 2 - 1, cell.y * 2 - 1)
		var top_right := Vector2i(cell.x * 2 + 1, cell.y * 2 - 1)
		var bottom_right := Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)
		var bottom_left := Vector2i(cell.x * 2 - 1, cell.y * 2 + 1)
		for edge in [[top_left, top_right], [top_right, bottom_right], [bottom_right, bottom_left], [bottom_left, top_left]]:
			var start: Vector2i = edge[0]
			var finish: Vector2i = edge[1]
			var forward_key := "%d,%d>%d,%d" % [start.x, start.y, finish.x, finish.y]
			var reverse_key := "%d,%d>%d,%d" % [finish.x, finish.y, start.x, start.y]
			if edges.has(reverse_key):
				edges.erase(reverse_key)
			else:
				edges[forward_key] = {"start": start, "finish": finish}
	if edges.is_empty():
		return PackedVector2Array()
	var first_start := Vector2i(2147483647, 2147483647)
	for raw_edge in edges.values():
		var start: Vector2i = (raw_edge as Dictionary).get("start", Vector2i.ZERO)
		if start.y < first_start.y or (start.y == first_start.y and start.x < first_start.x):
			first_start = start
	var outline := PackedVector2Array()
	var current := first_start
	var remaining := edges.size() + 1
	while remaining > 0:
		outline.append(Vector2(current.x * HALF_CELL, current.y * HALF_CELL))
		var next_edge: Dictionary = {}
		for raw_edge in edges.values():
			var edge: Dictionary = raw_edge as Dictionary
			if edge.get("start", Vector2i.ZERO) == current:
				next_edge = edge
				break
		if next_edge.is_empty():
			break
		current = next_edge.get("finish", current) as Vector2i
		if current == first_start:
			break
		remaining -= 1
	return outline

# True when a world point is on the deck of a habitat zone (drives the interior hum).
func is_inside(point: Vector3) -> bool:
	if point.y<habitat_base_y-.6 or point.y>habitat_base_y+4.0: return false
	var cell:=Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
	for zone in zones:
		var zone_kind := str(zone.kind)
		if zone.has("angled_mount"):
			if _point_in_angled_mount(Vector2(point.x, point.z), zone.get("angled_mount", {})): return true
		elif zone_kind in NON_ROOM_KINDS:
			if zone_kind not in SITE_MACHINES and cell in zone.cells:
				return true
		elif Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), zone_outline(zone)):
			return true
	return false

func run_zone_outline_self_test() -> bool:
	var saved_zones: Array = zones
	var y := habitat_base_y + 1.0
	var rectangle := {"kind": "living", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)]}
	zones = [rectangle]
	var rectangle_inside := is_inside(Vector3(3.0, y, 3.0))
	var rectangle_outside := not is_inside(Vector3(8.0, y, 3.0))
	print("zone_outline self-test · 3x3 inside: ", "PASS" if rectangle_inside else "FAIL")
	print("zone_outline self-test · 3x3 outside: ", "PASS" if rectangle_outside else "FAIL")
	var l_shape := {"kind": "living", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)]}
	zones = [l_shape]
	var l_inside := is_inside(Vector3(0.0, y, 0.0))
	var l_outside := not is_inside(Vector3(3.0, y, 3.0))
	print("zone_outline self-test · L-shape inside: ", "PASS" if l_inside else "FAIL")
	print("zone_outline self-test · L-shape outside: ", "PASS" if l_outside else "FAIL")
	zones = saved_zones
	return rectangle_inside and rectangle_outside and l_inside and l_outside

# Logic-only coverage for the first free-form attachment step. It deliberately
# does not touch the world or rebuild meshes, so it is safe to run headlessly.
func run_outline_airlock_attachment_self_test() -> bool:
	var saved_zones: Array = zones
	var saved_direction := airlock_direction
	var outline := PackedVector2Array([Vector2(-1.5, -1.5), Vector2(4.5, -1.5), Vector2(4.5, 7.5), Vector2(-1.5, 7.5)])
	var airlock := {"kind": "airlock", "cells": [Vector2i(0, -1)], "door_direction": Vector2i(0, -1)}
	zones = [{"kind": "living", "cells": [], "outline": outline}, airlock]
	airlock_direction = Vector2i(0, -1)
	var attachment := _outline_attachment_for_face(Vector2i(0, -1), Vector2i(0, 1))
	var attached := bool(attachment.get("valid", false)) and _valid_airlock(airlock.cells)
	var doorway_clear := attached
	if attached:
		for piece in _outline_wall_pieces(6.0, [attachment], int(attachment.get("edge_index", -1))):
			var start: float = float(piece.get("start", 0.0))
			var finish: float = float(piece.get("end", 0.0))
			if start < float(attachment.get("opening_end", 0.0)) - .001 and finish > float(attachment.get("opening_start", 0.0)) + .001:
				doorway_clear = false
	var off_grid_outline := PackedVector2Array([Vector2(-1.5, -1.0), Vector2(4.5, -1.0), Vector2(4.5, 8.0), Vector2(-1.5, 8.0)])
	zones = [{"kind": "living", "cells": [], "outline": off_grid_outline}]
	var off_grid_reason := str(_outline_attachment_for_face(Vector2i(0, -1), Vector2i(0, 1)).get("reason", ""))
	var off_grid_rejected := off_grid_reason.contains("half a cell")
	zones = [{"kind": "living", "cells": [Vector2i(0, 0)]}]
	var grid_airlock_unchanged := _valid_airlock([Vector2i(0, -1)])
	print("outline airlock self-test · aligned attachment: ", "PASS" if attached else "FAIL")
	print("outline airlock self-test · doorway has no solid wall piece: ", "PASS" if doorway_clear else "FAIL")
	print("outline airlock self-test · off-grid wall message: ", "PASS" if off_grid_rejected else "FAIL")
	print("outline airlock self-test · grid airlock unchanged: ", "PASS" if grid_airlock_unchanged else "FAIL")
	zones = saved_zones
	airlock_direction = saved_direction
	return attached and doorway_clear and off_grid_rejected and grid_airlock_unchanged

func run_outline_grid_door_self_test() -> bool:
	var saved_zones: Array = zones
	var saved_doors: Array = interior_doors
	var outline := PackedVector2Array([Vector2(1.5, -1.5), Vector2(7.5, -1.5), Vector2(7.5, 1.5), Vector2(1.5, 1.5)])
	zones = [{"kind": "living", "cells": [Vector2i(0, 0)]}, {"kind": "science", "cells": [], "outline": outline}]
	interior_doors = []
	var grid_cell := Vector2i(0, 0)
	var side := Vector2i(1, 0)
	var attachment := _outline_attachment_for_face(grid_cell, side)
	var can_attach := bool(attachment.get("valid", false))
	var can_install_door := interior_door_invalid_reason(grid_cell, side).is_empty()
	interior_doors.append({"outline_grid_cell": grid_cell, "outline_grid_side": side})
	var grid_wall_removed := not _should_build_wall(grid_cell, side)
	var outline_opening := false
	for doorway in _outline_wall_doorways(zones[1]):
		if int(doorway.get("edge_index", -1)) == int(attachment.get("edge_index", -2)) and absf(float(doorway.get("opening_end", 0.0)) - float(doorway.get("opening_start", 0.0)) - CELL) < .01:
			outline_opening = true
	print("outline/grid door self-test · shared wall detected: ", "PASS" if can_attach else "FAIL")
	print("outline/grid door self-test · doorway accepted: ", "PASS" if can_install_door else "FAIL")
	print("outline/grid door self-test · grid wall removed: ", "PASS" if grid_wall_removed else "FAIL")
	print("outline/grid door self-test · outline opening supplied: ", "PASS" if outline_opening else "FAIL")
	zones = saved_zones
	interior_doors = saved_doors
	return can_attach and can_install_door and grid_wall_removed and outline_opening

func run_angled_outline_connector_self_test() -> bool:
	var saved_zones: Array = zones
	var saved_kind := kind
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(6, 6), Vector2(9, 3), Vector2(3, -3)])
	zones = [{"kind": "living", "cells": [], "outline": outline, "cost": 0}]
	kind = "airlock"
	var mount := _angled_outline_mount_at(Vector2(3, 3))
	var mount_valid := not mount.is_empty() and _angled_outline_mount_invalid_reason(mount).is_empty()
	var basis := _angled_mount_basis(mount)
	var outward: Vector2 = mount.get("outward", Vector2.UP)
	var axis_matches := (-basis.z).normalized().dot(Vector3(outward.x, 0, outward.y).normalized()) > .999
	var connector := {"kind": "airlock", "cells": [], "angled_mount": mount, "cost": CELL_COST}
	zones.append(connector)
	var doorway_present := false
	for doorway in _outline_wall_doorways(zones[0]):
		if absf(float(doorway.get("opening_end", 0.0)) - float(doorway.get("opening_start", 0.0)) - CELL) < .01: doorway_present = true
	var mount_position: Vector2 = mount.get("position", Vector2.ZERO)
	var inside_mount := _point_in_angled_mount(mount_position + outward * CELL * .5, mount)
	var outward_points_out := not Geometry2D.is_point_in_polygon(mount_position + outward * 1.0, outline) and Geometry2D.is_point_in_polygon(mount_position - outward * 1.0, outline)
	var corner_mount: Dictionary = mount.duplicate()
	corner_mount["opening_start"] = ANGLED_CORNER_CLEARANCE - .01
	var corner_rejected := _angled_outline_mount_invalid_reason(corner_mount) == "Too close to a corner"
	print("angled connector self-test · 45° edge selected: ", "PASS" if mount_valid else "FAIL")
	print("angled connector self-test · rotated outward axis: ", "PASS" if axis_matches else "FAIL")
	print("angled connector self-test · 3 m wall opening: ", "PASS" if doorway_present else "FAIL")
	print("angled connector self-test · interior hit area: ", "PASS" if inside_mount else "FAIL")
	print("angled connector self-test · outward points outside: ", "PASS" if outward_points_out else "FAIL")
	print("angled connector self-test · corner mount rejected: ", "PASS" if corner_rejected else "FAIL")
	zones = saved_zones
	kind = saved_kind
	return mount_valid and axis_matches and doorway_present and inside_mount and outward_points_out and corner_rejected

# Environmental readout for the explorer HUD. The outdoor baseline comes from
# the selected site; sealed rooms only become truly habitable once generated
# power can run Life Support. Future first-person equipment can add a local
# heat value here without changing the HUD or site data contracts.
func climate_at(point: Vector3) -> Dictionary:
	if lander != null and lander.cabin_contains(point):
		return {"temperature": 18.0, "radiation": "Sheltered", "context": "Lander cabin", "state": "climate"}
	var telemetry: Dictionary = MHGame.site().get("telemetry", {})
	var outside_temp := MHGame.outside_temperature_c if MHGame.outside_temperature_c != 0.0 else float(telemetry.get("outside_temp_c", -30.0))
	var cell := Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))
	var zone_kind := ""
	var here: Dictionary = {}
	for zone in zones:
		if not str(zone.kind) in SITE_MACHINES and cell in zone.cells:
			zone_kind = str(zone.kind)
			here = zone
			break
	if zone_kind.is_empty() or point.y < habitat_base_y - .6 or point.y > habitat_base_y + 4.0:
		return {"temperature": outside_temp, "radiation": str(telemetry.get("radiation", "High")), "context": "Outside · EVA exposure", "state": "outside"}
	if MHGame.simulation_on() and not here.is_empty():
		var room_c: float = simulation().room_temperature(here)
		var room_label := str(ZONE_TYPES.get(zone_kind, {}).get("label", "Habitat"))
		var room_state := "climate" if room_c >= 18.0 else ("unheated" if room_c < 5.0 else "cool")
		return {"temperature": room_c, "radiation": "Sheltered", "context": "%s · %d °C" % [room_label, roundi(room_c)], "state": room_state}
	var systems := _systems()
	var powered := grid_power_online()
	var climate_controlled := powered and int(systems.life) > 0
	var temperature := outside_temp + 8.0 # A sealed but unheated shell slows heat loss.
	var context := str(ZONE_TYPES.get(zone_kind, {}).get("label", "Habitat"))
	var radiation := "Sheltered"
	var state := "unheated"
	if climate_controlled:
		var targets := {"living": 20.0, "hydroponics": 24.0, "science": 21.0, "storage": 12.0, "engineering": 18.0, "galley": 20.0, "hygiene": 21.0, "medical": 21.0, "waste_management": 16.0, "communications": 20.0, "corridor": 16.0, "airlock": 8.0, "vehicle_bay": 6.0}
		temperature = float(targets.get(zone_kind, 18.0))
		state = "climate"
		context += " · climate control"
	elif powered:
		temperature = minf(outside_temp + 12.0, 4.0)
		state = "powered_shell"
		# Heaters warm their own room, up to a comfortable 20 degrees C.
		var warmth := _heater_warmth(here)
		if warmth > 0.0:
			temperature = minf(temperature + warmth, maxf(temperature, 20.0))
			state = "heater"
			context += " · heater running"
		else:
			context += " · powered, no heater"
	else:
		context += " · unheated shell"
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
	# Blueprint grid: one line per 3 m cell face in cell-line blue, added on top
	# of the terrain and fading out around the camera target. Everything snaps
	# to these lines and their corners, so there are no finer guide lines.
	var immediate:=ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	var grid_limit := roundi(_site_build_limit())
	for n in range(-grid_limit,grid_limit):
		var at:=float(n)+.5
		if posmod(n-1,int(CELL))!=0: continue
		var colour:=Color(MHStyle.CELL_LINE,.55)
		for points in [[Vector3(at,.09,-grid_limit),Vector3(at,.09,grid_limit)],[Vector3(-grid_limit,.09,at),Vector3(grid_limit,.09,at)]]:
			immediate.surface_set_color(colour); immediate.surface_add_vertex(points[0])
			immediate.surface_set_color(colour); immediate.surface_add_vertex(points[1])
	immediate.surface_end()
	var shader:=Shader.new(); shader.code=GRID_SHADER
	var material:=ShaderMaterial.new(); material.shader=shader
	grid=MeshInstance3D.new(); grid.mesh=immediate; grid.material_override=material; grid.visible=false; grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(grid)
	# Sit on the deck datum from the start (not only after the first room), or
	# the wash below the lines is hidden under a level build pad.
	grid.position.y=habitat_base_y+.09
	# Dark blueprint wash under the lines so the cyan grid reads against bright terrain.
	# It sits just above the deck datum but below the zone plan tiles (top at
	# +.0475), so it dims the ground without dimming the zones into it.
	var wash:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(grid_limit*2.0,grid_limit*2.0); wash.mesh=plane; wash.position.y=-.08; wash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wash_shader:=Shader.new(); wash_shader.code=GRID_WASH_SHADER; var wash_material:=ShaderMaterial.new(); wash_material.shader=wash_shader; wash.material_override=wash_material; wash.name="BlueprintWash"; grid.add_child(wash)
	_add_unbuildable_overlay(grid_limit)

## Dark tint draped over every plan cell that cannot carry habitat (canyon
## walls, crater wall and mound), so the site's limits show before a click.
func _add_unbuildable_overlay(grid_limit: int) -> void:
	var vertices := PackedVector3Array()
	var cells := int(float(grid_limit) / CELL)
	for x in range(-cells, cells + 1):
		for z in range(-cells, cells + 1):
			if MHSiteTerrain.cell_unbuildable_reason(Vector2i(x, z), CELL).is_empty(): continue
			var corners: Array[Vector3] = []
			for offset in [Vector2(-HALF_CELL, -HALF_CELL), Vector2(HALF_CELL, -HALF_CELL), Vector2(HALF_CELL, HALF_CELL), Vector2(-HALF_CELL, HALF_CELL)]:
				var at: Vector2 = Vector2(x * CELL, z * CELL) + offset
				corners.append(Vector3(at.x, MHSiteTerrain.height(at.x, at.y) + .15, at.y))
			vertices.append_array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
	if vertices.is_empty(): return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("#1A0604", .55)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for vertex in vertices: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var overlay := MeshInstance3D.new()
	overlay.name = "UnbuildableOverlay"
	overlay.mesh = mesh
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.visible = false
	overlay.add_to_group("site_plan_overlay")
	world.add_child(overlay)

# ---------- build HUD (shots 1e / 1f) ----------
func _ui() -> void:
	hud_layer=CanvasLayer.new(); hud_layer.name="BuildHUD"; hud_layer.layer=5; add_child(hud_layer)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.theme=MHStyle.theme(); ui.visible=false; hud_layer.add_child(ui)
	ui.add_child(MHStyle.hint_strip([[["LMB"],"Place · drag","accent"],[["V"],"Room shape"],[["R"],"Rotate"],[["RMB"],"Cancel"],[["X"],"Remove"],[["Q","E"],"Orbit"],[["Wheel"],"Zoom"],[["Tab"],"Catalogue"],[["M"],"Mission Control"],[["B"],"Explore"]]))
	# Top-left: colony + cargo
	var left:=MHStyle.vbox(12); left.position=Vector2(32,32); left.size=Vector2(440,0); left.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(left)
	left.add_child(MHStyle.colony_chip(MHGame.site_name()))
	var cargo_panel:=MHStyle.hud_panel(20); cargo_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; left.add_child(cargo_panel)
	var cargo_box:=MHStyle.vbox(12); cargo_panel.add_child(cargo_box)
	cargo_meter=MHWidgets.Meter.new().setup("Cargo remaining",MHGame.mission_cargo_budget(),MHGame.mission_cargo_budget(),"kg","accent",true); cargo_box.add_child(cargo_meter)
	mars_made_label=MHStyle.mono("",13,Color("#E0A070"),600); mars_made_label.visible=false; cargo_box.add_child(mars_made_label)
	var placing_row:=MHStyle.hbox(8); cargo_box.add_child(placing_row)
	placing_label=MHStyle.mono("",14,MHStyle.TEXT_MUTED); placing_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; placing_label.clip_text=true; placing_row.add_child(placing_label)
	placing_delta=MHStyle.mono("",14,MHStyle.accent,600); placing_row.add_child(placing_delta)
	notice_column=MHStyle.vbox(12); notice_column.position=Vector2(32,0); notice_column.mouse_filter=Control.MOUSE_FILTER_IGNORE; left.add_child(notice_column)
	# Top-centre: Site plan | Interior | Explore switch over the free viewport
	_mode_switcher=MHStyle.build_mode_switcher("site","Site plan · rooms, corridors, airlocks and power",func() -> void: pass,_switch_to_interior,_toggle)
	(_mode_switcher.root as Control).offset_right=-472; ui.add_child(_mode_switcher.root)
	# Top-right: readiness + Mission Control
	var top_right:=MHStyle.hbox(12); top_right.anchor_left=1; top_right.anchor_right=1; top_right.offset_left=-620; top_right.offset_right=-32; top_right.offset_top=32; top_right.offset_bottom=84; top_right.alignment=BoxContainer.ALIGNMENT_END; top_right.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(top_right)
	ready_badge_slot=CenterContainer.new(); ready_badge_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE; top_right.add_child(ready_badge_slot)
	var mc:=MHStyle.button("Mission Control","secondary","clipboard-check"); mc.focus_mode=Control.FOCUS_NONE; mc.pressed.connect(func() -> void: mission_control_requested.emit()); top_right.add_child(mc)
	_build_catalogue()
	_build_tool_bar()
	hologram_pill=Control.new(); hologram_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE; hologram_pill.visible=false; ui.add_child(hologram_pill)
	_update_budget(); _update_summary(); _select_kind(kind)

## Site plan build bar (same layout as furnishing): category tabs and picture
## cards along the bottom, details with a turning 3D preview on the right.
func _build_catalogue() -> void:
	catalogue=PanelContainer.new()
	catalogue.anchor_left=.5; catalogue.anchor_right=.5; catalogue.anchor_top=1; catalogue.anchor_bottom=1
	catalogue.offset_left=-780; catalogue.offset_right=780; catalogue.offset_top=-330; catalogue.offset_bottom=-92
	catalogue.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.SURFACE_HUD_STRONG,MHStyle.BORDER_SUBTLE,8,1,Vector4(18,16,18,16)))
	catalogue.mouse_filter=Control.MOUSE_FILTER_STOP; MHStyle.add_rail(catalogue,28); ui.add_child(catalogue)
	var column:=MHStyle.vbox(12); catalogue.add_child(column)
	var head:=MHStyle.hbox(6); column.add_child(head)
	for entry in CATEGORIES:
		var tab:=Button.new(); tab.text="  "+str(entry[1]); tab.set_meta("label",tab.text); tab.icon=MHIcons.texture(entry[2],18); tab.custom_minimum_size=Vector2(0,40); tab.focus_mode=Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size",15); tab.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		tab.pressed.connect(func() -> void: category=str(entry[0]); MHAudio.sfx("ui_click",-6.0); _refresh_catalogue())
		head.add_child(tab); category_buttons[entry[0]]=tab
	head.add_child(MHStyle.spacer())
	catalogue_count=MHStyle.mono("",12,MHStyle.TEXT_MUTED); catalogue_count.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head.add_child(catalogue_count)
	var hint:=MHStyle.mono("   1-9  PICK    TAB  HIDE",12,MHStyle.TEXT_SECONDARY); hint.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head.add_child(hint)
	var scroll:=ScrollContainer.new(); scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.custom_minimum_size=Vector2(0,168); column.add_child(scroll)
	catalogue_grid=HBoxContainer.new(); catalogue_grid.add_theme_constant_override("separation",10); scroll.add_child(catalogue_grid)
	equipment_list=MHStyle.vbox(12); equipment_list.visible=false; column.add_child(equipment_list)
	# Details: preview stage (model or blueprint tile), then text and numbers.
	catalogue_details=PanelContainer.new()
	catalogue_details.anchor_left=1; catalogue_details.anchor_right=1
	catalogue_details.offset_left=-470; catalogue_details.offset_right=-48; catalogue_details.offset_top=110; catalogue_details.offset_bottom=110
	catalogue_details.mouse_filter=Control.MOUSE_FILTER_PASS
	catalogue_details.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.SURFACE_HUD,MHStyle.BORDER_SUBTLE,8,1,Vector4(18,18,18,18)))
	MHStyle.add_rail(catalogue_details,28); ui.add_child(catalogue_details)
	var details_column:=MHStyle.vbox(8); catalogue_details.add_child(details_column)
	catalogue_stage=PanelContainer.new(); catalogue_stage.custom_minimum_size=Vector2(0,200); catalogue_stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	details_column.add_child(catalogue_stage)
	catalogue_preview=MODEL_PREVIEW.new(); catalogue_stage.add_child(catalogue_preview)
	catalogue_detail=MHStyle.vbox(8); details_column.add_child(catalogue_detail)

func _set_catalogue_open(open: bool) -> void:
	catalogue.visible=open
	if catalogue_details!=null: catalogue_details.visible=open
	if open: _refresh_catalogue()

func _select_kind(id: String) -> void:
	# Solar panels start facing the noon sun (south); R still turns them.
	if id=="solar" and kind!="solar": airlock_direction=Vector2i(0,1)
	kind=id; equipment_id=""; dragging=false; category=str(ZONE_INFO[id].cat); _set_tool("place"); _preview_key=""
	if not _freeform_mode_available(): _cancel_freeform()
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
		var style:=MHStyle.box(MHStyle.tint(MHStyle.accent,.22) if active else MHStyle.SURFACE_CONTROL,MHStyle.accent if active else MHStyle.BORDER_SUBTLE,6,1,Vector4(14,6,16,6))
		for state in ["normal","pressed","hover_pressed","focus"]: tab.add_theme_stylebox_override(state,style)
		tab.add_theme_stylebox_override("hover",MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER,MHStyle.BORDER_STRONG,6,1,Vector4(14,6,16,6)))
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]: tab.add_theme_color_override(state,MHStyle.TEXT_PRIMARY if active else MHStyle.TEXT_SECONDARY)
	for child in catalogue_grid.get_children(): child.queue_free()
	for child in equipment_list.get_children(): child.queue_free()
	for child in catalogue_detail.get_children(): child.queue_free()
	var remaining:=MHGame.cargo_budget()-_used_cargo()
	catalogue_grid.visible=category!="equipment"; equipment_list.visible=category=="equipment"
	if category=="equipment":
		catalogue_count.text="%d items" % EquipmentCatalog.entries().size()
		_refresh_equipment_list(remaining)
	elif category=="surface":
		catalogue_count.text="%d PROPS" % SURFACE_EQUIPMENT.size()
		var index:=0
		for id in SURFACE_EQUIPMENT:
			index+=1
			catalogue_grid.add_child(_surface_equipment_card(id,index))
		_show_stage("")
		catalogue_detail.add_child(MHStyle.eyebrow("SURFACE GEAR",MHStyle.accent,12))
		catalogue_detail.add_child(MHStyle.title("Outdoor props",26))
		var surface_text:=MHStyle.body("Pick a prop, then place it freely from first person on open ground. Lights and markers switch on and off; they don't change the habitat's resources yet.",15); surface_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		catalogue_detail.add_child(surface_text)
		return
	else:
		var shown:=0
		# Missions: never leave a part selected that this payload didn't bring.
		if not MHMissions.zone_unlocked(kind) and equipment_id.is_empty():
			for id in ZONE_TYPES:
				if str(ZONE_INFO[id].cat)==category and MHMissions.zone_unlocked(id): kind=id; break
		for id in ZONE_TYPES:
			if str(ZONE_INFO[id].cat)!=category: continue
			if not MHMissions.zone_unlocked(id): continue   # Missions: only this payload's parts
			shown+=1
			var card:=_part_card(id,id==kind and equipment_id.is_empty(),remaining<cell_cost(id))
			card.set_meta("pick_index",shown)
			(card.get_meta("number_label") as Label).text="%d  ·  %s" % [shown,str((card.get_meta("number_label") as Label).text)]
			catalogue_grid.add_child(card)
		catalogue_count.text="%d PARTS" % shown
	if not equipment_id.is_empty():
		_refresh_equipment_detail()
		return
	var info:Dictionary=ZONE_INFO[kind]
	_show_stage(kind)
	catalogue_detail.add_child(MHStyle.eyebrow(str({"rooms":"ROOM","structure":"STRUCTURE","power":"RESOURCES"}.get(str(info.cat),"PART")),MHStyle.accent,12))
	catalogue_detail.add_child(MHStyle.title(str(ZONE_TYPES[kind].label),26))
	var desc:=MHStyle.body(str(info.desc),15); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; catalogue_detail.add_child(desc)
	var chips:=HFlowContainer.new(); chips.add_theme_constant_override("h_separation",6); chips.add_theme_constant_override("v_separation",6); catalogue_detail.add_child(chips)
	for chip in _part_chips(kind): chips.add_child(_chip(str(chip[0]),chip[1]))
	if _freeform_mode_available():
		var mode_button := MHStyle.button("Draw mode: %s  [V]" % ("Free-form" if room_draw_mode == "freeform" else "Rectangle"), "secondary", "pentagon", 40)
		mode_button.tooltip_text = "Rectangle: drag as usual. Free-form: click snapped points, Enter to close, Backspace to undo a point. Walls lock to straight or 45° angles."
		mode_button.pressed.connect(func() -> void:
			room_draw_mode = "freeform" if room_draw_mode == "rectangle" else "rectangle"
			_cancel_freeform()
			_refresh_catalogue())
		catalogue_detail.add_child(mode_button)

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
	var card:=_bar_card(selected)
	card.pressed.connect(func() -> void: MHAudio.sfx("ui_click",-6.0); _select_kind(id))
	var column:=card.get_meta("column") as VBoxContainer
	column.add_child(_part_picture(id))
	var name_label:=MHStyle.label(str(ZONE_TYPES[id].label),14,MHStyle.TEXT_PRIMARY,600); name_label.clip_text=true; name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; column.add_child(name_label)
	var mass:=MHStyle.mono(("%s / cell" % MHStyle.kg(cell_cost(id))) if str(ZONE_INFO[id].cat)!="power" else MHStyle.kg(cell_cost(id)),11,MHStyle.DANGER if unaffordable else MHStyle.TEXT_MUTED); column.add_child(mass)
	card.set_meta("number_label",mass)
	return card

## A card in the build bar: picture on top, then name and numbers.
func _bar_card(selected: bool) -> Button:
	var card:=Button.new(); card.custom_minimum_size=Vector2(186,164); card.focus_mode=Control.FOCUS_NONE; card.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal",MHStyle.box(MHStyle.tint(MHStyle.accent,.16) if selected else MHStyle.SURFACE_CONTROL,MHStyle.accent if selected else MHStyle.BORDER_SUBTLE,8,2 if selected else 1,Vector4(8,8,8,8)))
	card.add_theme_stylebox_override("hover",MHStyle.box(MHStyle.SURFACE_CONTROL_HOVER,MHStyle.accent if selected else MHStyle.BORDER_STRONG,8,2 if selected else 1,Vector4(8,8,8,8)))
	card.add_theme_stylebox_override("pressed",card.get_theme_stylebox("hover"))
	var column:=MHStyle.vbox(4); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); column.offset_left=8; column.offset_top=8; column.offset_right=-8; column.offset_bottom=-8; column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_child(column); card.set_meta("column",column)
	return card

## A part's picture: its real model where it has one, otherwise a blueprint
## tile in the part's plan colour with its icon.
func _part_picture(id: String) -> Control:
	var colour:Color=plan_colour(id)
	if PART_MODELS.has(id):
		var picture:=TextureRect.new(); picture.custom_minimum_size=Vector2(170,104); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var part_ref: WeakRef=weakref(picture)   # the card may be rebuilt before its picture is ready
		ModelThumbnails.request(get_tree(),str(PART_MODELS[id]),func(texture: Texture2D) -> void:
			var shown:=part_ref.get_ref() as TextureRect
			if shown!=null: shown.texture=texture)
		return picture
	var tile:=PanelContainer.new(); tile.custom_minimum_size=Vector2(170,104); tile.mouse_filter=Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.BLUEPRINT.lerp(colour,.32),colour.lightened(.1),6,1))
	var icon:=MHStyle.icon(str(ZONE_INFO[id].icon),46,colour.lightened(.5)); icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER; icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER; tile.add_child(icon)
	return tile

## The details panel's top: a turning model, or the part's blueprint tile.
func _show_stage(id: String) -> void:
	if catalogue_stage==null: return
	for child in catalogue_stage.get_children():
		if child!=catalogue_preview: child.queue_free()
	var model:=str(PART_MODELS.get(id,""))
	catalogue_preview.visible=not model.is_empty()
	catalogue_stage.add_theme_stylebox_override("panel",MHStyle.box(Color(1,1,1,.035),Color(0,0,0,0),6,0))
	if not model.is_empty():
		catalogue_preview.show_item(model)
	elif not id.is_empty():
		var tile:=_part_picture(id); tile.size_flags_horizontal=Control.SIZE_FILL; catalogue_stage.add_child(tile)
	catalogue_stage.visible=not id.is_empty()

func _chip(text: String,colour: Color) -> PanelContainer:
	var pill:=PanelContainer.new(); pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.tint(colour,.14),MHStyle.tint(colour,.45),12,1,Vector4(10,3,10,3)))
	pill.add_child(MHStyle.mono(text,12,colour,600))
	return pill

## A part's cost and what it does, from the balance spreadsheet.
func _part_chips(id: String) -> Array:
	var chips:Array=[[("%s / cell" % MHStyle.kg(cell_cost(id))) if str(ZONE_INFO[id].cat)!="power" else MHStyle.kg(cell_cost(id)),MHStyle.TEXT_SECONDARY],[str(ZONE_INFO[id].rule),MHStyle.INFO]]
	match id:
		"solar": chips.append(["up to %s kW at noon" % str(int(MHResources.setting("solar_peak_kw",10.0))),MHStyle.VALID])
		"reactor": chips.append(["%s kW day and night" % str(int(MHResources.setting("reactor_kw",10.0))),MHStyle.VALID])
		"ice_extractor":
			chips.append(["up to %s L water a sol" % str(int(MHResources.setting("ice_drill_l",120.0))),MHStyle.VALID])
			chips.append(["-%s kW" % str(MHResources.item_value("ice_drill","power_kw",3.0)),MHStyle.WARN])
		"regolith_intake":
			chips.append(["feeds the regolith printer",MHStyle.VALID])
			chips.append(["-%s kW" % str(MHResources.item_value("regolith_intake","power_kw",1.5)),MHStyle.WARN])
	if zone_printable(id) and str(ZONE_INFO[id].cat)!="power": chips.append(["can be printed",MHStyle.VALID])
	var target:=float(MHResources.room(id).get("target_c",0.0))
	if target>0.0 and str(ZONE_INFO[id].cat)=="rooms": chips.append(["kept at %d °C" % int(target),MHStyle.INFO])
	if id in ["airlock","vehicle_bay","solar","corridor"]: chips.append(["Facing %s" % _facing_name(),MHStyle.TEXT_SECONDARY])
	return chips

func _surface_equipment_card(id: String,index := 0) -> Button:
	var entry: Dictionary = SURFACE_EQUIPMENT[id]
	var card:=_bar_card(false)
	card.tooltip_text="%s\nPlace freely on outdoor ground in first person" % str(entry.label)
	var column:=card.get_meta("column") as VBoxContainer
	var picture:=TextureRect.new(); picture.custom_minimum_size=Vector2(170,104); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture.texture=MHIcons.texture(str(entry.icon),48); picture.modulate=Color(1,1,1,.35)
	var picture_ref: WeakRef=weakref(picture)   # the card may be rebuilt before its picture is ready
	ModelThumbnails.request(get_tree(),id,func(texture: Texture2D) -> void:
		var shown:=picture_ref.get_ref() as TextureRect
		if shown!=null and texture!=null:
			shown.texture=texture; shown.modulate=Color.WHITE)
	column.add_child(picture)
	var name_label:=MHStyle.label(str(entry.label),14,MHStyle.TEXT_PRIMARY,600); name_label.clip_text=true; name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; column.add_child(name_label)
	column.add_child(MHStyle.mono("%d  ·  %s" % [index,MHStyle.kg(int(EquipmentCatalog.get_entry(id).get("cargo_cost",0)))],11,MHStyle.TEXT_MUTED))
	card.set_meta("pick_index",index)
	card.pressed.connect(func() -> void: MHAudio.sfx("ui_click",-6.0); _select_surface_equipment(id))
	return card

func _build_tool_bar() -> void:
	var band:=CenterContainer.new(); band.anchor_top=1; band.anchor_bottom=1; band.anchor_right=1; band.offset_top=-436; band.offset_bottom=-340; band.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(band)
	var bar:=PanelContainer.new(); bar.add_theme_stylebox_override("panel",MHStyle.box(MHStyle.SURFACE_HUD,MHStyle.BORDER_SUBTLE,MHStyle.RADIUS_MD,1,Vector4(8,8,8,8))); band.add_child(bar)
	var row:=MHStyle.hbox(8); bar.add_child(row)
	for entry in [["place","box","Place","LMB"],["footprint","git-branch","Footprint","Edit"],["rotate","rotate-cw","Rotate","R"],["remove","trash-2","Remove","X"],["undo","undo-2","Undo","Ctrl Z"]]:
		var item:=MHStyle.vbox(6); item.alignment=BoxContainer.ALIGNMENT_CENTER; row.add_child(item)
		var b:=Button.new(); b.icon=MHIcons.texture(entry[1],22); b.tooltip_text=str(entry[2]); b.custom_minimum_size=Vector2(52,48); b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER; b.focus_mode=Control.FOCUS_NONE; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		b.theme_type_variation="GhostButton"; item.add_child(b)
		var cap:=MHStyle.keycap(str(entry[3]),true); cap.size_flags_horizontal=Control.SIZE_SHRINK_CENTER; item.add_child(cap)
		match str(entry[0]):
			"place": b.pressed.connect(_set_tool.bind("place"))
			"footprint": b.pressed.connect(_set_tool.bind("footprint"))
			"rotate": b.pressed.connect(func() -> void: _rotate_airlock(); _refresh_catalogue())
			"remove": b.pressed.connect(func() -> void: _set_tool("place" if tool=="remove" else "remove"))
			"undo": b.pressed.connect(_undo)
		tool_buttons[entry[0]]=b
	_set_tool(tool)

func _set_tool(next_tool: String) -> void:
	tool=next_tool; dragging=false
	if tool=="footprint":
		equipment_id=""
	else:
		footprint_zone_index=-1
	for id in tool_buttons:
		var active:bool=id==tool
		var b:Button=tool_buttons[id]
		b.theme_type_variation="SelectedButton" if active else "GhostButton"
		if id=="remove" and active: b.theme_type_variation="DangerButton"
	if is_inside_tree(): _refresh_footprint_selection_overlay()

func _update_hologram_ui(cells: Array,reason: String, angled_mount: Dictionary = {}) -> void:
	if hologram_pill==null: return
	var message:=""; var state:=""
	var placing_name:String=str(ZONE_TYPES[kind].label) if equipment_id.is_empty() else str(EquipmentCatalog.get_entry(equipment_id).get("label",equipment_id))
	if tool=="remove":
		state="remove"; message="Click equipment or a zone to remove it · full refund"
		placing_label.text="Remove tool"; placing_delta.text=""
	elif tool=="footprint":
		placing_label.text="Edit room footprint"
		placing_delta.text=""
		if footprint_zone_index < 0 or footprint_zone_index >= zones.size():
			state="info"; message="Click an ordinary room to select it"
		else:
			var edit_zone: Dictionary = zones[footprint_zone_index]
			state="valid" if reason.is_empty() else "invalid"
			message="%s · click adjacent empty cells to add · Ctrl-click edge cells to remove" % str(ZONE_TYPES[str(edit_zone.kind)].label)
			if not reason.is_empty(): message=reason
	elif _pointer_over_ui():
		placing_label.text="Placing %s" % placing_name; placing_delta.text=""
	elif not equipment_id.is_empty():
		var item_cost:=int(EquipmentCatalog.get_entry(equipment_id).get("cargo_cost",0))
		var left:=MHGame.cargo_budget()-_used_cargo()-earth_cost(item_cost, item_printable(equipment_id))
		placing_label.text="Placing %s" % placing_name
		placing_delta.text="−%s → %s" % [MHStyle.kg(item_cost),MHStyle.kg(left)] if not cells.is_empty() else ""
		placing_delta.add_theme_color_override("font_color",MHStyle.DANGER if left<0 else (MHStyle.WARN if left<MHGame.cargo_budget()*.1 else MHStyle.accent))
		if not reason.is_empty(): state="invalid"; message=reason
		elif not cells.is_empty():
			var effects:=EquipmentCatalog.effects_text(equipment_id)
			state="valid"; message="%s · %s" % [ZONE_TYPES[_zone_at(cells[0]).kind].label,effects if not effects.is_empty() else "no resource effect"]
	elif _freeform_active():
		var area := _freeform_area(freeform_points)
		var freeform_cost := _freeform_cost(freeform_points)
		var freeform_after := MHGame.cargo_budget() - _used_cargo() - earth_cost(freeform_cost, zone_printable(kind))
		placing_label.text = "Drawing %s" % ZONE_TYPES[kind].label
		placing_delta.text = "−%s → %s" % [MHStyle.kg(freeform_cost), MHStyle.kg(freeform_after)] if freeform_points.size() >= 3 else ""
		placing_delta.add_theme_color_override("font_color", MHStyle.DANGER if freeform_after < 0 else (MHStyle.WARN if freeform_after < MHGame.cargo_budget() * .1 else MHStyle.accent))
		state = "valid" if reason.is_empty() else "invalid"
		message = "%.1f m wall · %.1f m² · click first point or Enter to close" % [_freeform_current_wall_length(_freeform_cursor_point()), area]
		if not reason.is_empty(): message = reason
		# Too few corners yet is a step to take, not an error.
		if freeform_points.is_empty():
			state = "valid"; message = "Angled room · click a cell corner to start (V: rectangle)"
		elif freeform_points.size() < 3:
			state = "valid"; message = "%.1f m wall · click the next corner" % _freeform_current_wall_length(_freeform_cursor_point())
	elif not angled_mount.is_empty():
		var angled_length := float(angled_mount.get("length", CELL))
		var angled_cost := cell_cost(kind) * (_angled_corridor_bays(angled_length) if kind == "corridor" else 1)
		var angled_after := MHGame.cargo_budget() - _used_cargo() - earth_cost(angled_cost, zone_printable(kind))
		placing_label.text = "Placing %s · 45° wall" % placing_name
		placing_delta.text = "−%s → %s" % [MHStyle.kg(angled_cost), MHStyle.kg(angled_after)]
		placing_delta.add_theme_color_override("font_color", MHStyle.DANGER if angled_after < 0 else (MHStyle.WARN if angled_after < MHGame.cargo_budget() * .1 else MHStyle.accent))
		state = "valid" if reason.is_empty() else "invalid"
		message = "45° wall mount · drag outward for corridor length" if kind == "corridor" else "45° wall mount · connector will face outside · click from either side"
		if not reason.is_empty(): message = reason
	else:
		var cost:=_zone_cost(cells)
		var earth := earth_cost(cost, zone_printable(kind))
		var after:=MHGame.cargo_budget()-_used_cargo()-earth
		placing_label.text="Placing %s" % ZONE_TYPES[kind].label
		placing_delta.text=("−%s → %s" % [MHStyle.kg(earth),MHStyle.kg(after)] + ("  (%s printed)" % MHStyle.kg(cost - earth) if earth < cost else "")) if not cells.is_empty() else ""
		placing_delta.add_theme_color_override("font_color",MHStyle.DANGER if after<0 else (MHStyle.WARN if after<MHGame.cargo_budget()*.1 else MHStyle.accent))
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

func _flash_notice(tone: String,heading: String,text: String,play_sound := true) -> void:
	if notice_column==null: return
	# Each notice tone has its own sound; "valid" notices are removals.
	var sound:String={"invalid":"invalid","warn":"warn","valid":"remove","info":"undo"}.get(tone,"")
	if play_sound and not sound.is_empty(): MHAudio.sfx(sound)
	while notice_column.get_child_count()>=2: var oldest:=notice_column.get_child(0); notice_column.remove_child(oldest); oldest.queue_free()
	var item:=MHStyle.notice(tone,heading,text); notice_column.add_child(item)
	var fade:=item.create_tween(); fade.tween_interval(3.2); fade.tween_property(item,"modulate:a",0.0,.3); fade.tween_callback(item.queue_free)
