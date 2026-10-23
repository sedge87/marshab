class_name MHGame
extends RefCounted
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# Session-wide state that survives scene changes: colony identity chosen on the
# setup screens, the shared accent material, lighting palettes and graphics
# settings. Static so it needs no autoload and still works in headless tests.

const SITES_PATH := "res://data/sites.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_DIRECTORY := "user://habitats"
# Tests point this at their own folder so they never overwrite real saves.
static var save_directory := SAVE_DIRECTORY
const SAVE_SLOT_COUNT := 3
const EMBLEMS := ["rocket", "orbit", "satellite", "mountain-snow", "sun", "atom"]

# Lighting presets from the reference scene (mars-scene.js PAL). sun is the
# direction towards the sun; energies are tuned for Godot's Compatibility renderer.
const PALETTES := {
	"day": {"sky_top": Color("#A06C49"), "sky_horizon": Color("#E6B98F"), "glow": Color("#FFF0D8"), "sun": Vector3(.62, .52, .58), "sun_colour": Color("#FFE9CF"), "sun_energy": 0.8, "ambient": Color("#E8C3A0"), "ambient_energy": 0.38, "ground": Color("#996142"), "fog": Color("#D5A07A"), "fog_density": .0024, "exposure": 0.85, "window": .9},
	# Open Plains (realistic pass): butterscotch sky, thicker haze toward the
	# horizon, a stronger sun and less fill, so the ground has shape.
	"plains": {"sky_top": Color("#9A7155"), "sky_horizon": Color("#E2BC97"), "glow": Color("#FFF0D8"), "sun": Vector3(.62, .52, .58), "sun_colour": Color("#FFF2E6"), "sun_energy": 1.0, "ambient": Color("#C7AC98"), "ambient_energy": 0.3, "ground": Color("#BF9474"), "fog": Color("#BD9272"), "fog_density": .0019, "exposure": 0.8, "window": .9},
	"cold": {"sky_top": Color("#8E7466"), "sky_horizon": Color("#E2CDBB"), "glow": Color("#FFF6EA"), "sun": Vector3(.55, .45, .65), "sun_colour": Color("#FFF1E2"), "sun_energy": 0.78, "ambient": Color("#E6D6C8"), "ambient_energy": 0.42, "ground": Color("#9C7A66"), "fog": Color("#D8C0AC"), "fog_density": .0026, "exposure": 0.85, "window": .9},
	"golden": {"sky_top": Color("#563427"), "sky_horizon": Color("#D58E5E"), "glow": Color("#FFD6A2"), "sun": Vector3(.92, .14, .32), "sun_colour": Color("#FFC08A"), "sun_energy": 0.85, "ambient": Color("#C98B5F"), "ambient_energy": 0.3, "ground": Color("#814835"), "fog": Color("#B87550"), "fog_density": .003, "exposure": 0.82, "window": 1.8},
	"dusk": {"sky_top": Color("#120E10"), "sky_horizon": Color("#6A4334"), "glow": Color("#9CCBE0"), "sun": Vector3(.95, .06, -.45), "sun_colour": Color("#DCE8EC"), "sun_energy": 0.65, "ambient": Color("#8C7E7A"), "ambient_energy": 0.42, "ground": Color("#3A2420"), "fog": Color("#4E3328"), "fog_density": .0034, "exposure": 1.05, "window": 3.6}
}

# Audio levels (0–100) live in the same settings file, under [audio].
const VOLUME_KEYS := ["vol_master", "vol_music", "vol_ambience", "vol_sfx", "vol_voice"]

const PRESETS := {
	"low": {"shadows": false, "dust": false, "weather": false, "glow": false, "render_scale": 0.75},
	"medium": {"shadows": true, "dust": true, "weather": true, "glow": false, "render_scale": 1.0},
	"high": {"shadows": true, "dust": true, "weather": true, "glow": true, "render_scale": 1.0}
}

# One list of controls feeds the pause sheet and Settings → Controls.
const CONTROLS := [
	["Move", [[["W", "A", "S", "D"], "Walk"], [["Mouse"], "Look around"], [["Shift"], "Sprint"], [["Space"], "Jump"], [["E"], "Context action"], [["F"], "Head lamp · no grid power"], [["Esc"], "Pause · free the mouse"]]],
	["Build", [[["B"], "Build ⇄ Explore · room or site plan"], [["Shift", "B"], "Site plan ⇄ Interior"],[["LMB"], "Click or drag to place"], [["R"], "Rotate outside face"], [["RMB"], "Cancel placement"], [["X"], "Remove tool · full refund"], [["Ctrl", "Z"], "Undo last placement"]]],
	["Camera & menus", [[["W", "A", "S", "D"], "Pan (build)"], [["Q", "E"], "Orbit (build)"], [["Wheel"], "Zoom (build)"], [["Tab"], "Catalogue"], [["M"], "Mission Control"]]]
]

# ---------- colony ----------
static var colony_name := "Habitat One"
static var mission_statement := ""
static var emblem := "rocket"
static var accent_index := 0
static var site_id := "plains"

# The currently simulated site conditions.  The day/night controller owns these
# values at runtime; keeping them here means HUD, climate and power simulation
# all read the exact same clock rather than approximating it independently.
static var sol_hour := 8.0
static var sunlight_fraction := 1.0
static var outside_temperature_c := -25.0
static var pending_save_state: Dictionary = {}

# ---------- game mode ----------
# Like Subnautica: "survival" runs the full habitat simulation with a cargo
# limit and the crew can come to harm; "freedom" runs the simulation with
# warnings only; "creative" turns the simulation and cargo limit off.
# ("missions", the Understand > Design > Test > Improve mode, comes next.)
const MHResources := preload("res://scripts/mh_resources.gd")
const GAME_MODES := {"survival": "Survival", "freedom": "Freedom", "creative": "Creative"}
const GAME_MODE_NOTES := {
	"survival": "The full challenge: power, heat, air, water and food all run, and the crew can come to harm.",
	"freedom": "Everything runs and warns you, but the crew never come to harm. Experiment safely.",
	"creative": "No simulation and unlimited cargo: build anything.",
}
static var game_mode := "survival"
## Showcase mode (scripts/showcase.gd): a save presenting itself. Nothing is saved.
static var showcase := false
## Where the student chose to land (site x, z in metres), set on the menu's
## Land step; INF means "let the game pick" (quick start, loaded games).
static var landing_target := Vector2.INF
# Hidden debug cheats (Ctrl+Shift+F12 in a colony); session only, never saved.
static var debug_unlimited_cargo := false
static var debug_free_power := false

static func cargo_unlimited() -> bool:
	return game_mode == "creative" or debug_unlimited_cargo

## Whether the habitat simulation runs (every mode but Creative).
static func simulation_on() -> bool:
	return game_mode != "creative"

## Whether shortages can harm the crew (not in Freedom).
static func crew_can_be_harmed() -> bool:
	return game_mode == "survival" or game_mode == "missions"

## Old save names: "mission" was the cargo challenge, "sandbox" free building.
static func normalise_mode(mode: String) -> String:
	if mode == "mission": return "survival"
	if mode == "sandbox": return "creative"
	return mode if GAME_MODES.has(mode) or mode == "missions" else "survival"

## The landed cargo this site allows: the balance budget plus the site's
## landing bonus (low sites have thicker air for parachutes).
static func mission_cargo_budget() -> int:
	if game_mode == "missions": return preload("res://scripts/mh_missions.gd").cargo_budget()
	var start := MHResources.setting("freedom_cargo_budget_kg", 140000.0) if game_mode == "freedom" else MHResources.setting("cargo_budget_kg", 100000.0)
	return roundi(start * (1.0 + float(MHResources.site(site_id).get("cargo_bonus", 0.0)))) + resupply_kg

# ---------- resupply landers (Survival and Freedom) ----------
## Cargo delivered by resupply landers so far, and how many have landed.
## Saved with the base; reset for a new game.
static var resupply_kg := 0
static var resupply_count := 0

## Switched off in the balance sheet (resupply_enabled): the regolith printer
## is how the base grows now. The landers stay in the code to switch back on.
static func resupplies_on() -> bool:
	return game_mode in ["survival", "freedom"] and MHResources.setting("resupply_enabled", 0.0) > 0.0

## Sols between launch windows (compressed: real ones are ~26 months apart).
static func resupply_interval_sols() -> float:
	return MHResources.setting("resupply_sols_freedom", 2.0) if game_mode == "freedom" else MHResources.setting("resupply_sols_survival", 3.0)

static func resupply_size_kg() -> int:
	return int(MHResources.setting("resupply_kg_freedom", 20000.0) if game_mode == "freedom" else MHResources.setting("resupply_kg_survival", 15000.0))

## Game hours (of simulation time) until the next resupply lands.
static func resupply_due_in_hours(hours_run: float) -> float:
	return (resupply_count + 1) * resupply_interval_sols() * 24.0 - hours_run

## The cargo limit every placement checks against.
static func cargo_budget() -> int:
	return 100000000 if cargo_unlimited() else mission_cargo_budget()

static var _sites: Array = []
static var _accent_material: StandardMaterial3D
static var _window_glow := .9
static var _habitat_lights_online := true

static func sites() -> Array:
	if _sites.is_empty() and FileAccess.file_exists(SITES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SITES_PATH))
		if parsed is Dictionary: _sites = parsed.get("sites", [])
	return _sites

static func site() -> Dictionary:
	for entry in sites():
		if str(entry.get("id", "")) == site_id: return entry
	return {"id": "plains", "name": "Open Plains", "palette": "day", "icon": "sun"}

static func site_name() -> String: return str(site().get("name", "Open Plains"))
static func palette_name() -> String: return str(site().get("palette", "day"))

static func set_site_conditions(hour: float, sunlight: float, temperature: float) -> void:
	sol_hour = wrapf(hour, 0.0, 24.0)
	sunlight_fraction = clampf(sunlight, 0.0, 1.0)
	outside_temperature_c = temperature

# ---------- sun ----------
# One sun model for lighting and power. It rises in the east, crosses the
# southern sky (+Z) at the site's noon altitude and sets in the west. Each site
# also hides a band of low sky behind its terrain (canyon walls, crater rim).

static func sun_noon_altitude() -> float:
	return deg_to_rad(float(site().get("sun", {}).get("noon_altitude", 55.0)))

## 0 at sunrise (east) to 1 at sunset (west); -1 while the sun is down.
static func daylight_progress(hour: float) -> float:
	var cycle: Dictionary = site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	if hour < sunrise or hour > sunset: return -1.0
	return (hour - sunrise) / maxf(.1, sunset - sunrise)

## Sun height above the flat horizon, radians (0 while it is down).
static func sun_altitude(hour: float) -> float:
	var progress := daylight_progress(hour)
	return 0.0 if progress < 0.0 else sin(progress * PI) * sun_noon_altitude()

## Compass direction towards the sun on the ground plane (x east, y = +Z south).
static func sun_heading(hour: float) -> Vector2:
	var progress := clampf(daylight_progress(hour), 0.0, 1.0)
	return Vector2(cos(progress * PI), sin(progress * PI))

## Share of full solar output available now (0 at night, 1 for a high sun on
## open ground). It follows the sun's height, so output builds through the
## morning and fades in the evening; terrain hides the sun below the site's
## horizon angle.
static func solar_irradiance(hour: float) -> float:
	var altitude := sun_altitude(hour)
	if altitude <= 0.0: return 0.0
	var horizon := deg_to_rad(float(site().get("sun", {}).get("horizon", 0.0)))
	var visible := smoothstep(horizon, horizon + deg_to_rad(6.0), altitude)
	return visible * sin(altitude) / sin(deg_to_rad(62.0))

## Average solar output over a whole sol in real play time, 0–1, used for the
## site cards. Night counts, so long nights lower it.
static func average_solar(site_entry: Dictionary) -> float:
	var saved := site_id
	site_id = str(site_entry.get("id", site_id))
	var cycle: Dictionary = site().get("day_cycle", {})
	var day_seconds := float(cycle.get("daylight_minutes", 15.0)) * 60.0
	var night_seconds := float(cycle.get("night_minutes", 5.0)) * 60.0
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var total := 0.0
	var samples := 96
	for index in range(samples):
		total += solar_irradiance(lerpf(sunrise, sunset, (float(index) + .5) / samples))
	site_id = saved
	return total / samples * day_seconds / maxf(1.0, day_seconds + night_seconds)

## Buildable area of a site in m² (3 m cells its terrain allows).
static func buildable_area(site_entry: Dictionary) -> float:
	var saved := site_id
	site_id = str(site_entry.get("id", site_id))
	var limit := int(float(site().get("build_limit", 60.0)) / 3.0)
	var cells := 0
	for x in range(-limit, limit + 1):
		for z in range(-limit, limit + 1):
			if MHSiteTerrain.cell_unbuildable_reason(Vector2i(x, z)).is_empty(): cells += 1
	site_id = saved
	return cells * 9.0

## Site-card badges and condition meters, computed from the same values the
## simulation uses and ranked across all sites, so the cards cannot drift
## from what the game does. {badges: [[text, tone]], conditions: [[label, 0–10, value text, tone]]}
static func site_card(site_entry: Dictionary) -> Dictionary:
	var stats := {}
	for entry in sites():
		var water := 0.0
		for deposit in entry.get("ice_deposits", []): water = maxf(water, float(deposit.richness))
		stats[str(entry.id)] = {"solar": average_solar(entry), "area": buildable_area(entry), "water": water, "night": float(entry.get("day_cycle", {}).get("night_temp_c", -60.0))}
	var mine: Dictionary = stats[str(site_entry.id)]
	var best := {"solar": 0.0, "area": 0.0}
	var extremes := {"solar_min": INF, "area_min": INF, "night_min": INF, "night_max": -INF}
	for key in stats:
		var s: Dictionary = stats[key]
		best.solar = maxf(best.solar, s.solar); best.area = maxf(best.area, s.area)
		extremes.solar_min = minf(extremes.solar_min, s.solar); extremes.area_min = minf(extremes.area_min, s.area)
		extremes.night_min = minf(extremes.night_min, s.night); extremes.night_max = maxf(extremes.night_max, s.night)
	var badges: Array = []
	if is_equal_approx(mine.solar, best.solar): badges.append(["+ Solar", "valid"])
	elif is_equal_approx(mine.solar, extremes.solar_min): badges.append(["− Solar", "warn"])
	if mine.water >= .75: badges.append(["+ Water", "info"])
	elif mine.water < .4: badges.append(["− Water", "warn"])
	if is_equal_approx(mine.area, extremes.area_min): badges.append(["Tight space", "warn"])
	elif is_equal_approx(mine.area, best.area): badges.append(["Wide space", "valid"])
	if is_equal_approx(mine.night, extremes.night_max): badges.append(["Mild nights", "valid"])
	elif is_equal_approx(mine.night, extremes.night_min): badges.append(["Bitter nights", "warn"])
	# Three badges fit on a card; the build-space badge goes first (its meter
	# already shows it).
	if badges.size() > 3:
		for index in range(badges.size()):
			if str(badges[index][0]).ends_with("space"):
				badges.remove_at(index)
				break
	var heating_per_cell: float = maxf(0.0, BuildController.HABITAT_TEMPERATURE_C - mine.night) * BuildController.HEATING_PER_CELL_DEGREE
	var water_text := "High" if mine.water >= .75 else ("Fair" if mine.water >= .45 else "Low")
	return {"badges": badges, "conditions": [
		["Solar output", clampf(10.0 * mine.solar / maxf(.001, best.solar), 0.0, 10.0), "%d%% of peak, all sol" % roundi(mine.solar * 100.0), "info"],
		["Build space", clampf(10.0 * mine.area / maxf(1.0, best.area), 0.0, 10.0), "%s m²" % roundi(mine.area), "valid" if mine.area > best.area * .6 else "warn"],
		["Water ice", clampf(mine.water * 10.0, 0.0, 10.0), water_text, "valid" if mine.water >= .45 else "warn"],
		["Night heating", clampf(heating_per_cell * 6.0, 0.0, 10.0), "%d °C · %.1f per cell" % [roundi(mine.night), heating_per_cell], "warn" if heating_per_cell > 1.4 else "info"]
	]}

static func formatted_sol_time() -> String:
	var whole_hour := int(floor(sol_hour))
	var minutes := int(round((sol_hour - float(whole_hour)) * 60.0))
	if minutes >= 60:
		whole_hour = (whole_hour + 1) % 24
		minutes = 0
	return "%02d:%02d" % [whole_hour, minutes]

# ---------- habitat saves ----------
# Two separate sets of save slots: Missions keeps a student's mission progress,
# and Free play is shared by Survival, Freedom and Creative, so playing or
# testing in another mode never touches mission saves.
const SAVE_SETS := {"free_play": "Free play", "missions": "Missions"}

static func save_set_for_mode(mode: String) -> String:
	return "missions" if mode == "missions" else "free_play"

## The save set in use: the one for the current game mode unless named.
static func _save_set(save_set := "") -> String:
	return save_set if SAVE_SETS.has(save_set) else save_set_for_mode(game_mode)

static func _save_path(slot: int, save_set := "") -> String:
	_move_old_saves()
	return "%s/%s/slot_%d.save" % [save_directory, _save_set(save_set), clampi(slot, 1, SAVE_SLOT_COUNT)]

## Saves from before the split lived straight in the save folder: they were
## all free play, so move them into the Free play set (once, never overwriting).
static func _move_old_saves() -> void:
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		var old_path := "%s/slot_%d.save" % [save_directory, slot]
		if not FileAccess.file_exists(old_path): continue
		var new_path := "%s/free_play/slot_%d.save" % [save_directory, slot]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/free_play" % save_directory))
		if not FileAccess.file_exists(new_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old_path), ProjectSettings.globalize_path(new_path))

static func save_habitat(slot: int, state: Dictionary, save_set := "") -> Error:
	if showcase: return OK   # a showcase plays a copy and never writes the student's save
	var absolute_directory := ProjectSettings.globalize_path("%s/%s" % [save_directory, _save_set(save_set)])
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(_save_path(slot, save_set), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"version": 1, "saved_at": Time.get_datetime_string_from_system(true), "save_set": _save_set(save_set), "state": state})
	return OK

## Deletes a save (main menu, after a second click to confirm).
static func delete_habitat(slot: int, save_set := "") -> bool:
	var path := _save_path(slot, save_set)
	if not FileAccess.file_exists(path): return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

static func load_habitat(slot: int, save_set := "") -> Dictionary:
	var path := _save_path(slot, save_set)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var payload = file.get_var()
	if not payload is Dictionary:
		return {}
	return payload as Dictionary

static func save_slot_summary(slot: int, save_set := "") -> Dictionary:
	var payload := load_habitat(slot, save_set)
	if payload.is_empty():
		return {"slot": slot, "exists": false}
	var state: Dictionary = payload.get("state", {})
	return {"slot": slot, "exists": true, "saved_at": str(payload.get("saved_at", "")), "colony_name": str(state.get("colony_name", "Habitat")), "site_name": str(state.get("site_name", "Mars")),
		"mode": str(GAME_MODES.get(normalise_mode(str(state.get("game_mode", "survival"))), "Missions"))}

static func prepare_habitat_load(slot: int, save_set := "") -> bool:
	var payload := load_habitat(slot, save_set)
	var state: Dictionary = payload.get("state", {})
	if state.is_empty():
		return false
	pending_save_state = state
	site_id = str(state.get("site_id", site_id))
	colony_name = str(state.get("colony_name", colony_name))
	mission_statement = str(state.get("mission_statement", mission_statement))
	emblem = str(state.get("emblem", emblem))
	set_accent(int(state.get("accent_index", accent_index)))
	game_mode = normalise_mode(str(state.get("game_mode", "survival")))
	return true

static func accent() -> Color: return MHStyle.COLONY_ACCENTS[accent_index].colour

static func set_accent(index: int) -> void:
	accent_index = clampi(index, 0, MHStyle.COLONY_ACCENTS.size() - 1)
	MHStyle.set_accent(accent())
	accent_material().albedo_color = accent()
	MHPalette.set_accent()

# One material shared by every rail, lintel, airlock band and beacon, so the
# colony accent recolours the whole base in one frame.
static func accent_material() -> StandardMaterial3D:
	if _accent_material == null:
		_accent_material = StandardMaterial3D.new()
		_accent_material.resource_name = "Colony accent"
		_accent_material.albedo_color = accent()
		_accent_material.roughness = .42
		_accent_material.metallic = .05
	return _accent_material

# Shared kit materials from the design asset sheet. One material per colour
# role, shared by every part, never per-instance.
static var _kit := {}

static func kit_material(role: String) -> StandardMaterial3D:
	if role == "accent": return accent_material()
	if _kit.has(role): return _kit[role]
	var m := StandardMaterial3D.new()
	m.resource_name = "Kit " + role
	match role:
		# The house palette (docs/house-style.md): white hull, shell panels, graphite seals.
		"hull": m.albedo_color = Color("#F2F3F0"); m.roughness = .55; m.metallic = 0.0
		"panel": m.albedo_color = Color("#E3E7E5"); m.roughness = .58; m.metallic = 0.0
		"seal": m.albedo_color = Color("#4C5A61"); m.roughness = .55; m.metallic = .15
		"steel": m.albedo_color = MHStyle.FRAME_STEEL; m.roughness = .38; m.metallic = .65
		"glass":
			m.albedo_color = Color("#121a1f"); m.roughness = .12; m.metallic = .4
			m.emission_enabled = true; m.emission = Color("#FFC48A"); m.emission_energy_multiplier = .9
	_kit[role] = m
	return m

# The Blender exports carry flat grey materials, so parts are dressed with the
# kit by material name. Solar cells keep their own (correct) materials.
static func apply_kit_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(surface)
				if material == null: continue
				var role := _kit_role(material.resource_name)
				if not role.is_empty(): mesh_instance.set_surface_override_material(surface, kit_material(role))
	for child in node.get_children(): apply_kit_materials(child)

static func _kit_role(material_name: String) -> String:
	var lowered := material_name.to_lower()
	if lowered.contains("orange") or lowered.contains("accent"): return "accent"
	if lowered.contains("pressure hull"): return "hull"
	if lowered.contains("pale panel"): return "panel"
	if lowered.contains("seal"): return "seal"
	if lowered.contains("interior light"): return "glass"
	if lowered.contains("solar frame"): return "steel"
	return ""

# Lit windows glow brighter at golden hour and dusk. BuildController can then
# switch all normal habitat fixtures off without touching emergency beacons.
static func set_window_glow(energy: float) -> void:
	_window_glow = energy
	kit_material("glass").emission_energy_multiplier = _window_glow if _habitat_lights_online else 0.0

static func set_habitat_lights_online(online: bool) -> void:
	_habitat_lights_online = online
	kit_material("glass").emission_energy_multiplier = _window_glow if online else 0.0

# ---------- lighting ----------
static func sun_basis(palette: Dictionary) -> Basis:
	var toward_sun: Vector3 = (palette.sun as Vector3).normalized()
	# DirectionalLight3D shines along its -Z axis.
	return Basis.looking_at(-toward_sun, Vector3.UP if absf(toward_sun.y) < .99 else Vector3.FORWARD)

static func build_environment(palette: Dictionary) -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette.sky_top
	sky_material.sky_horizon_color = palette.sky_horizon
	sky_material.sky_curve = 0.18
	sky_material.ground_horizon_color = (palette.sky_horizon as Color).darkened(.12)
	sky_material.ground_bottom_color = palette.ground
	sky_material.ground_curve = 0.04
	# The Compatibility renderer does not reliably draw ProceduralSky's built-in
	# sun disc in this project. OriginalMarsEnvironment supplies a renderer-safe
	# corona tied to this same directional light instead.
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = palette.ambient
	environment.ambient_light_energy = palette.ambient_energy
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = palette.exposure
	environment.fog_enabled = true
	environment.fog_light_color = palette.fog
	environment.fog_density = palette.fog_density
	environment.fog_sky_affect = 0.12
	environment.glow_enabled = bool(setting("glow"))
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	return environment

static func configure_sun(sun: DirectionalLight3D, palette: Dictionary) -> void:
	sun.basis = sun_basis(palette)
	sun.light_color = palette.sun_colour
	sun.light_energy = palette.sun_energy
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.shadow_enabled = bool(setting("shadows"))
	sun.shadow_bias = 0.04
	# Pushes shadow sampling off gently sloping ground, so it doesn't stripe
	# into rings ("shadow acne") around you.
	sun.shadow_normal_bias = 2.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 46.0 if str(setting("preset")) != "high" else 80.0

# ---------- settings ----------
static var _settings := {}

static func defaults() -> Dictionary:
	var d: Dictionary = PRESETS["medium"].duplicate()
	d["preset"] = "medium"
	d["fov"] = 70
	d["gary_autonomy"] = true
	d["alert_advisories"] = true
	d["tutorial_cards"] = true
	d["live_hazards"] = true
	for key in VOLUME_KEYS: d[key] = 80 if key != "vol_master" else 100
	return d

static func setting(key: String):
	if _settings.is_empty(): load_settings()
	return _settings.get(key, defaults().get(key))

static func settings() -> Dictionary:
	if _settings.is_empty(): load_settings()
	return _settings.duplicate()

static func load_settings() -> void:
	_settings = defaults()
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK: return
	for key in _settings.keys():
		_settings[key] = file.get_value(_section(key), key, _settings[key])

static func save_settings(values: Dictionary) -> void:
	_settings = values.duplicate()
	var file := ConfigFile.new()
	for key in _settings.keys(): file.set_value(_section(key), key, _settings[key])
	file.save(SETTINGS_PATH)

static func _section(key: String) -> String:
	return "audio" if key in VOLUME_KEYS else "graphics"

static func matching_preset(values: Dictionary) -> String:
	for preset_name in PRESETS:
		var preset: Dictionary = PRESETS[preset_name]
		var same := true
		for key in preset:
			if values.get(key) != preset[key]: same = false
		if same: return preset_name
	return "custom"

# Applies graphics settings to a running scene.
static func apply_settings(viewport: Viewport, environment: Environment, sun: DirectionalLight3D, cameras: Array) -> void:
	if viewport != null:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = float(setting("render_scale"))
	if environment != null: environment.glow_enabled = bool(setting("glow"))
	if sun != null:
		sun.shadow_enabled = bool(setting("shadows"))
		sun.directional_shadow_max_distance = 46.0 if str(setting("preset")) != "high" else 80.0
	for camera in cameras:
		if camera is Camera3D and camera.has_meta("first_person"): (camera as Camera3D).fov = float(setting("fov"))
