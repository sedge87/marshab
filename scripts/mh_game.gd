class_name MHGame
extends RefCounted

# Session-wide state that survives scene changes: colony identity chosen on the
# setup screens, the shared accent material, lighting palettes and graphics
# settings. Static so it needs no autoload and still works in headless tests.

const SITES_PATH := "res://data/sites.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_DIRECTORY := "user://habitats"
const SAVE_SLOT_COUNT := 3
const EMBLEMS := ["rocket", "orbit", "satellite", "mountain-snow", "sun", "atom"]

# Lighting presets from the reference scene (mars-scene.js PAL). sun is the
# direction towards the sun; energies are tuned for Godot's Compatibility renderer.
const PALETTES := {
	"day": {"sky_top": Color("#A06C49"), "sky_horizon": Color("#E6B98F"), "glow": Color("#FFF0D8"), "sun": Vector3(.62, .52, .58), "sun_colour": Color("#FFE9CF"), "sun_energy": 0.8, "ambient": Color("#E8C3A0"), "ambient_energy": 0.38, "ground": Color("#996142"), "fog": Color("#D5A07A"), "fog_density": .0024, "exposure": 0.85, "window": .9},
	"cold": {"sky_top": Color("#8E7466"), "sky_horizon": Color("#E2CDBB"), "glow": Color("#FFF6EA"), "sun": Vector3(.55, .45, .65), "sun_colour": Color("#FFF1E2"), "sun_energy": 0.78, "ambient": Color("#E6D6C8"), "ambient_energy": 0.42, "ground": Color("#9C7A66"), "fog": Color("#D8C0AC"), "fog_density": .0026, "exposure": 0.85, "window": .9},
	"golden": {"sky_top": Color("#563427"), "sky_horizon": Color("#D58E5E"), "glow": Color("#FFD6A2"), "sun": Vector3(.92, .14, .32), "sun_colour": Color("#FFC08A"), "sun_energy": 0.85, "ambient": Color("#C98B5F"), "ambient_energy": 0.3, "ground": Color("#814835"), "fog": Color("#B87550"), "fog_density": .003, "exposure": 0.82, "window": 1.8},
	"dusk": {"sky_top": Color("#120E10"), "sky_horizon": Color("#6A4334"), "glow": Color("#9CCBE0"), "sun": Vector3(.95, .06, -.45), "sun_colour": Color("#DCE8EC"), "sun_energy": 0.65, "ambient": Color("#8C7E7A"), "ambient_energy": 0.42, "ground": Color("#3A2420"), "fog": Color("#4E3328"), "fog_density": .0034, "exposure": 1.05, "window": 3.6}
}

# Audio levels (0–100) live in the same settings file, under [audio].
const VOLUME_KEYS := ["vol_master", "vol_music", "vol_ambience", "vol_sfx"]

const PRESETS := {
	"low": {"shadows": false, "dust": false, "glow": false, "render_scale": 0.75},
	"medium": {"shadows": true, "dust": true, "glow": false, "render_scale": 1.0},
	"high": {"shadows": true, "dust": true, "glow": true, "render_scale": 1.0}
}

# One list of controls feeds the pause sheet and Settings → Controls.
const CONTROLS := [
	["Move", [[["W", "A", "S", "D"], "Walk"], [["Mouse"], "Look around"], [["Shift"], "Sprint"], [["Space"], "Jump"], [["E"], "Context action"], [["Esc"], "Pause · free the mouse"]]],
	["Build", [[["B"], "Build ⇄ Explore"], [["LMB"], "Click or drag to place"], [["R"], "Rotate outside face"], [["RMB"], "Cancel placement"], [["X"], "Remove tool · full refund"], [["Ctrl", "Z"], "Undo last placement"]]],
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

static func formatted_sol_time() -> String:
	var whole_hour := int(floor(sol_hour))
	var minutes := int(round((sol_hour - float(whole_hour)) * 60.0))
	if minutes >= 60:
		whole_hour = (whole_hour + 1) % 24
		minutes = 0
	return "%02d:%02d" % [whole_hour, minutes]

# ---------- habitat saves ----------
static func _save_path(slot: int) -> String:
	return "%s/slot_%d.save" % [SAVE_DIRECTORY, clampi(slot, 1, SAVE_SLOT_COUNT)]

static func save_habitat(slot: int, state: Dictionary) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(SAVE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"version": 1, "saved_at": Time.get_datetime_string_from_system(true), "state": state})
	return OK

static func load_habitat(slot: int) -> Dictionary:
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var payload = file.get_var()
	if not payload is Dictionary:
		return {}
	return payload as Dictionary

static func save_slot_summary(slot: int) -> Dictionary:
	var payload := load_habitat(slot)
	if payload.is_empty():
		return {"slot": slot, "exists": false}
	var state: Dictionary = payload.get("state", {})
	return {"slot": slot, "exists": true, "saved_at": str(payload.get("saved_at", "")), "colony_name": str(state.get("colony_name", "Habitat")), "site_name": str(state.get("site_name", "Mars"))}

static func prepare_habitat_load(slot: int) -> bool:
	var payload := load_habitat(slot)
	var state: Dictionary = payload.get("state", {})
	if state.is_empty():
		return false
	pending_save_state = state
	site_id = str(state.get("site_id", site_id))
	colony_name = str(state.get("colony_name", colony_name))
	mission_statement = str(state.get("mission_statement", mission_statement))
	emblem = str(state.get("emblem", emblem))
	set_accent(int(state.get("accent_index", accent_index)))
	return true

static func accent() -> Color: return MHStyle.COLONY_ACCENTS[accent_index].colour

static func set_accent(index: int) -> void:
	accent_index = clampi(index, 0, MHStyle.COLONY_ACCENTS.size() - 1)
	MHStyle.set_accent(accent())
	accent_material().albedo_color = accent()

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
		"hull": m.albedo_color = MHStyle.STRUCTURAL_WHITE; m.roughness = .48; m.metallic = .05
		"panel": m.albedo_color = Color("#C6CCCF"); m.roughness = .6; m.metallic = .05
		"seal": m.albedo_color = MHStyle.SEAL_DARK; m.roughness = .55; m.metallic = .25
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
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 46.0 if str(setting("preset")) != "high" else 80.0

# ---------- settings ----------
static var _settings := {}

static func defaults() -> Dictionary:
	var d: Dictionary = PRESETS["medium"].duplicate()
	d["preset"] = "medium"
	d["fov"] = 70
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
