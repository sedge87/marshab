class_name OriginalMarsEnvironment
extends Node3D
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# Sky, lighting and the selected site's generated landscape (MHSiteTerrain).
# This node owns only scenery, lighting and collision; gameplay systems
# remain in Outpost One: Mars.
const PREVIEW_ROCKS := 500.0   # metres round the pad that the menu's backdrop scatters rocks
const MODEL_DIRECTORY := "res://assets/original_mars/models/"
const CELESTIAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 body_colour : source_color = vec4(1.0);
uniform vec4 crater_colour : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float glow = 0.0;
uniform float crater_strength = 1.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = length(p);
	if (edge > 0.5) { discard; }
	float craters = smoothstep(0.085, 0.045, length(p - vec2(-0.16, 0.10)));
	craters += smoothstep(0.052, 0.023, length(p - vec2(0.13, -0.12)));
	craters += smoothstep(0.040, 0.017, length(p - vec2(0.05, 0.18)));
	vec3 colour = mix(body_colour.rgb * (0.92 - edge * 0.5), crater_colour.rgb, craters * crater_strength);
	ALBEDO = colour;
	EMISSION = body_colour.rgb * glow;
	ALPHA = smoothstep(0.5, 0.46, edge);
}
"""
const SOLAR_CORONA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;
uniform vec4 core_colour : source_color = vec4(1.0, 0.93, 0.73, 1.0);
uniform vec4 corona_colour : source_color = vec4(1.0, 0.50, 0.20, 1.0);
void fragment() {
	vec2 p = UV - vec2(0.5);
	float radius = length(p) * 2.0;
	float core = 1.0 - smoothstep(0.20, 0.31, radius);
	float corona = 1.0 - smoothstep(0.28, 1.0, radius);
	vec3 colour = mix(corona_colour.rgb, core_colour.rgb, core);
	ALBEDO = colour;
	EMISSION = core_colour.rgb * core * 3.5 + corona_colour.rgb * corona * 0.55;
	ALPHA = max(core * 0.98, corona * 0.52);
}
"""

var _terrain_body: StaticBody3D
# Everything that depends on the chosen site, so the menu can swap it.
var _site_root: Node3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var palette_name := "day"
var _palette_values: Dictionary = {}
var _sky_material: ProceduralSkyMaterial
var _sun_corona: MeshInstance3D
var _phobos: MeshInstance3D
var _deimos: MeshInstance3D
var _show_celestials := true
## The main menu's backdrop: a region site is drawn without caves, collision
## or the far rocks, so switching sites there doesn't stall.
var preview := false

func build(palette := "") -> void:
	name = "OriginalMarsEnvironment"
	_show_celestials = palette.is_empty()
	palette_name = palette if not palette.is_empty() else MHGame.palette_name()
	_build_sky_and_lighting()
	_site_root = Node3D.new()
	_site_root.name = "SiteLandscape"
	add_child(_site_root)
	_build_terrain()
	_build_boundary()

func _ready() -> void:
	_build_decor()
	_build_pebbles()

## Replace the landscape with the currently selected site's (menu preview).
func rebuild_site() -> void:
	_site_root.free()
	_site_root = Node3D.new()
	_site_root.name = "SiteLandscape"
	add_child(_site_root)
	_build_terrain()
	_build_decor()
	_build_pebbles()

func _build_sky_and_lighting() -> void:
	# The built-in procedural sky is the background (the Sky3D addon stays
	# installed but unused).
	world_environment = WorldEnvironment.new()
	add_child(world_environment)
	# Auto exposure, like eyes adjusting: dim interiors brighten a little,
	# bright Mars daylight comes down, and the change takes a moment.
	var attributes := CameraAttributesPractical.new()
	attributes.auto_exposure_enabled = true
	attributes.auto_exposure_scale = .32
	attributes.auto_exposure_speed = .7
	attributes.auto_exposure_min_sensitivity = 90.0
	attributes.auto_exposure_max_sensitivity = 220.0
	world_environment.camera_attributes = attributes
	sun = DirectionalLight3D.new()
	sun.name = "OriginalSun"
	sun.position = Vector3(0.0, 30.0, 0.0)
	add_child(sun)
	if _show_celestials:
		_build_celestial_bodies()
	apply_palette(palette_name)

func _build_celestial_bodies() -> void:
	# The corona is only a visual counterpart for the directional sun: its
	# position is calculated from the same vector that controls all lighting.
	_sun_corona = _solar_corona()
	# Phobos and Deimos are small teaching aids with visibly different periods.
	_phobos = _celestial_disc("Phobos", 10.0, Color("#B8AA98"), .16)
	_deimos = _celestial_disc("Deimos", 5.5, Color("#9B9086"), .11)

func _solar_corona() -> MeshInstance3D:
	var corona := MeshInstance3D.new()
	corona.name = "DirectionalSunCorona"
	var mesh := QuadMesh.new()
	# 16m at 760m reads as a restrained ~1.2° solar disc: intentionally legible
	# through dust haze, but never large enough to resemble a nearby moon.
	mesh.size = Vector2(16.0, 16.0)
	corona.mesh = mesh
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SOLAR_CORONA_SHADER
	corona.material_override = material
	add_child(corona)
	return corona

func _celestial_disc(body_name: String, diameter: float, colour: Color, emission: float, crater_strength := 1.0) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = body_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2(diameter, diameter)
	body.mesh = mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = CELESTIAL_SHADER
	material.set_shader_parameter("body_colour", colour)
	material.set_shader_parameter("crater_colour", colour.darkened(.58))
	material.set_shader_parameter("glow", emission)
	material.set_shader_parameter("crater_strength", crater_strength)
	body.material_override = material
	add_child(body)
	return body

func apply_palette(palette: String) -> void:
	palette_name = palette if MHGame.PALETTES.has(palette) else "day"
	var values: Dictionary = MHGame.PALETTES[palette_name]
	_palette_values = values
	world_environment.environment = MHGame.build_environment(values)
	_sky_material = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	MHGame.configure_sun(sun, values)
	MHGame.set_window_glow(float(values.window))
# Soft fill while the player is inside a lit habitat: stands in for light
# bouncing off the white walls, so faces turned away from the ceiling lights
# are not pitch black at night. Set by the world each tick.
var cabin_dim := false
var interior_fill := false
var inside_habitat := false
## How far underground you are in a cave, 0 to 1 (MHCaves.darkness): the
## sky's light fades out. Set by the world each tick.
var cave_dark := 0.0
const INTERIOR_FILL_ENERGY := .1   # the ceiling lights do the main work now
const INDOOR_AMBIENT := .55          # share of the outdoor ambient left indoors
const INTERIOR_DARK_ENERGY := .05   # power off: only what spills from screens and the head lamp
const INDOOR_SUN := .3              # sunlight that leaks through walls (no shadows on low settings)
const INTERIOR_FILL_COLOUR := Color("#E9E2D6")
const NIGHT_FLOOR := .34                # share of the day's ambient left at midnight
const NIGHT_TINT := Color("#8792AE")     # cool starlight
## Fill lights for the inside of the habitat: from above (two angles) and a
## softer bounce from below. They light only visual layer 2 (the habitat).
const INTERIOR_FILLS := [[Vector3(-.4, -1.0, -.3), 1.0], [Vector3(.5, -1.0, .45), .8], [Vector3(.2, 1.0, -.35), .45]]
var _interior_fills: Array[DirectionalLight3D] = []

func _update_interior_fills(strength: float) -> void:
	if _interior_fills.is_empty():
		for spec in INTERIOR_FILLS:
			var fill := DirectionalLight3D.new()
			fill.name = "InteriorFill"
			fill.light_cull_mask = 2
			fill.shadow_enabled = false
			fill.light_color = INTERIOR_FILL_COLOUR
			fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
			add_child(fill)
			fill.look_at_from_position(Vector3.ZERO, Vector3(spec[0]), Vector3.FORWARD if absf((spec[0] as Vector3).normalized().y) > .99 else Vector3.UP)
			_interior_fills.append(fill)
	for i in range(_interior_fills.size()):
		var fill := _interior_fills[i]
		fill.visible = strength > .001
		fill.light_energy = strength * float(INTERIOR_FILLS[i][1]) * 2.2
## Dust storm haze, 0 (clear) to 1 (full storm): a dimmer, browner sun, a
## sky the colour of the ground and thick ochre fog. Set by MHWeather (only
## when Weather effects are on; the storm itself happens either way).
var storm := 0.0
var _indoor_blend := 0.0      # 0 outdoors, 1 indoors; eases across the threshold
var _cabin_blend := 0.0
var _indoor_energy := INTERIOR_FILL_ENERGY
const STORM_SKY := Color("#6E4A34")
const STORM_FOG := Color("#9A6A48")

func apply_daylight(sunlight: float) -> void:
	# Keep the art-direction palette, but let the simulated sun visibly set. A
	# small ambient floor preserves safe readability on low-end devices.
	if _palette_values.is_empty() or sun == null or world_environment == null:
		return
	var level := clampf(sunlight, 0.0, 1.0)
	_apply_martian_sun_direction(level)
	sun.light_energy = float(_palette_values.get("sun_energy", 0.8)) * lerpf(0.025, 1.0, level)
	# Night is dark but never pitch black: a faint, cool starlight floor, so
	# shapes still read outside without the helmet light.
	world_environment.environment.ambient_light_energy = float(_palette_values.get("ambient_energy", 0.35)) * lerpf(NIGHT_FLOOR, 1.0, level)
	world_environment.environment.ambient_light_color = NIGHT_TINT.lerp(_palette_values.get("ambient", Color.WHITE), smoothstep(0.0, .35, level))
	# Inside the lander: a dim, enclosed cabin, so stepping out into the
	# sunlight is a moment (eased the same way as the habitat threshold).
	_cabin_blend = move_toward(_cabin_blend, 1.0 if cabin_dim else 0.0, (get_process_delta_time() if is_inside_tree() else 1.0) / 1.5)
	if _cabin_blend > 0.0: world_environment.environment.ambient_light_energy *= lerpf(1.0, .3, smoothstep(0.0, 1.0, _cabin_blend))
	# Indoors the room's own lamps do the work: a flat, neutral fill (dim when
	# the power is off), and the sun no longer floods the interior. Crossing
	# the threshold blends between the two like eyes adjusting: about 2.5 s
	# stepping out into the night, about a second coming back in.
	var delta := get_process_delta_time() if is_inside_tree() else 1.0
	var toward := 1.0 if inside_habitat else 0.0
	_indoor_blend = move_toward(_indoor_blend, toward, delta / (1.0 if toward > _indoor_blend else 2.5))
	# The indoor level only changes while you're inside (lights switching), so
	# stepping out fades from the room you actually left.
	if inside_habitat: _indoor_energy = move_toward(_indoor_energy, INTERIOR_FILL_ENERGY if interior_fill else INTERIOR_DARK_ENERGY, delta * .4)
	# The indoor fill lights only touch the habitat (visual layer 2), so the
	# world outside keeps its own light: dark at night, seen from a doorway.
	var eased := smoothstep(0.0, 1.0, _indoor_blend)
	# With bounce light (SDFGI) the rooms light themselves: no flat fills.
	_update_interior_fills(0.0 if bool(MHGame.setting("sdfgi")) else _indoor_energy * eased)
	world_environment.environment.ambient_light_energy *= lerpf(1.0, INDOOR_AMBIENT, eased)
	if _indoor_blend > 0.0: sun.light_energy *= lerpf(1.0, INDOOR_SUN, eased)
	# In a cave the sky's light fades with the way in behind you. (Shadows
	# can't be trusted to keep the sun out under metres of ground.)
	if cave_dark > 0.0:
		world_environment.environment.ambient_light_energy *= lerpf(1.0, .03, cave_dark)
		sun.light_energy *= 1.0 - cave_dark
	if _sky_material != null:
		# Mars has a thin atmosphere, but midnight is still a true, dark sky—not
		# the washed-out daytime procedural sky from the initial implementation.
		_sky_material.sky_top_color = (Color("#080B16") as Color).lerp(_palette_values.get("sky_top", Color("#A06C49")) as Color, level)
		_sky_material.sky_horizon_color = (Color("#17121A") as Color).lerp(_palette_values.get("sky_horizon", Color("#E6B98F")) as Color, level)
		_sky_material.ground_horizon_color = (Color("#0D0A0C") as Color).lerp((_palette_values.get("sky_horizon", Color("#E6B98F")) as Color).darkened(.12), level)
		_sky_material.ground_bottom_color = (Color("#070609") as Color).lerp(_palette_values.get("ground", Color("#996142")) as Color, level)
		world_environment.environment.fog_light_color = (Color("#100D16") as Color).lerp(_palette_values.get("fog", Color("#D5A07A")) as Color, level)
		# Regions are kilometres across: thinner haze, so far landforms read as
		# silhouettes instead of vanishing (storms still thicken it).
		var fog_scale := .3 if MHSiteTerrain.shape() == "region" else 1.0
		world_environment.environment.fog_density = lerpf(.0008, float(_palette_values.get("fog_density", .0024)), level) * fog_scale
	# When the base grid is online its window strips are deliberately brighter at
	# night, providing a clear warm navigational cue without lifting the sky.
	if storm > .001: _apply_storm(level)
	elif world_environment.environment.fog_mode != Environment.FOG_MODE_EXPONENTIAL: world_environment.environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	MHGame.set_window_glow(float(_palette_values.get("window", .9)) * lerpf(1.75, .9, level))
	_update_volumetric_fog(eased)
	_update_celestial_bodies(level)

## Volumetric dust: a light haze outside that thickens into a wall of dust in
## a storm, and thins indoors. Settings: on, storms only, or off.
func _update_volumetric_fog(indoors: float) -> void:
	var env := world_environment.environment
	var mode := str(MHGame.setting("volumetric_fog"))
	var on := mode == "on" or (mode == "storms" and storm > .05)
	if env.volumetric_fog_enabled != on: env.volumetric_fog_enabled = on
	if not on: return
	var haze := clampf(storm, 0.0, 1.0)
	env.volumetric_fog_density = lerpf(.004, .045, haze) * lerpf(1.0, .08, indoors)
	env.volumetric_fog_albedo = env.fog_light_color

func _apply_storm(level: float) -> void:
	var haze := clampf(storm, 0.0, 1.0)
	sun.light_energy *= lerpf(1.0, .22, haze)
	sun.light_color = sun.light_color.lerp(Color("#D9A57C"), haze * .6)
	if not inside_habitat and not cabin_dim:
		world_environment.environment.ambient_light_color = (world_environment.environment.ambient_light_color as Color).lerp(STORM_FOG, haze * .5)
	if _sky_material != null:
		var dim := lerpf(.15, 1.0, level)
		_sky_material.sky_top_color = _sky_material.sky_top_color.lerp(STORM_SKY * dim, haze * .85)
		_sky_material.sky_horizon_color = _sky_material.sky_horizon_color.lerp(STORM_FOG * dim, haze * .9)
		_sky_material.ground_horizon_color = _sky_material.ground_horizon_color.lerp(STORM_FOG * dim, haze * .8)
		world_environment.environment.fog_light_color = world_environment.environment.fog_light_color.lerp(STORM_FOG * dim, haze)
		world_environment.environment.fog_density *= lerpf(1.0, 24.0, haze)
	# Indoors: fog that begins a few metres out, so the room stays clear while
	# the storm fills the windows.
	var env := world_environment.environment
	if inside_habitat or cabin_dim:
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = 7.0
		env.fog_depth_end = lerpf(420.0, 38.0, haze)
		env.fog_depth_curve = 1.4
	else:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL

func _apply_martian_sun_direction(sunlight: float) -> void:
	# The directional light is the actual solar source: it rises in the east,
	# crosses the southern sky at noon, sets in the west, changes the direction
	# of every shadow, and drops below the horizon at night. A reduced 55° noon
	# altitude is a clear Mars-like teaching approximation rather than a marker.
	var toward_sun := _martian_sun_vector(sunlight)
	sun.basis = MHGame.sun_basis({"sun": toward_sun})
	var noon_colour: Color = _palette_values.get("sun_colour", Color.WHITE)
	sun.light_color = Color("#FFAC7B").lerp(noon_colour, clampf(sunlight * 1.3, 0.0, 1.0))

func _martian_sun_vector(sunlight: float) -> Vector3:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var daylight_progress := clampf((MHGame.sol_hour - sunrise) / maxf(.1, sunset - sunrise), 0.0, 1.0)
	var altitude := sin(daylight_progress * PI) * MHGame.sun_noon_altitude()
	if sunlight <= .015:
		altitude = -deg_to_rad(18.0)
	var horizontal := cos(altitude)
	# World -Z is the compass north. This produces E → S → W across the sky.
	return Vector3(cos(daylight_progress * PI) * horizontal, sin(altitude), sin(daylight_progress * PI) * horizontal)

func _update_celestial_bodies(sunlight: float) -> void:
	if not _show_celestials or _sun_corona == null or _phobos == null:
		return
	# The corona uses the identical vector as the DirectionalLight3D, while the
	# two actual Martian moons appear only in low-light conditions.
	var hour := MHGame.sol_hour
	var toward_sun := _martian_sun_vector(sunlight)
	_sky_directions[_sun_corona] = toward_sun
	_sun_corona.visible = sunlight > .015
	# Actual orbital periods: Phobos 7 h 39 m, Deimos ~30 h 18 m. Phobos moves
	# west-to-east as seen from Mars; Deimos follows the slower opposite drift.
	var phobos_angle := -PI * .45 + TAU * hour / 7.653
	var deimos_angle := PI * .22 - TAU * hour / 30.30
	_place_celestial(_phobos, sin(phobos_angle) * PI * .48, phobos_angle * .35)
	_place_celestial(_deimos, sin(deimos_angle) * PI * .40, deimos_angle * .22 + .65)
	_phobos.visible = sunlight < .18 and (_sky_directions[_phobos] as Vector3).y > .006
	_deimos.visible = sunlight < .18 and (_sky_directions[_deimos] as Vector3).y > .006
	_follow_camera()

func _place_celestial(body: MeshInstance3D, altitude: float, azimuth: float) -> void:
	if body == null:
		return
	var horizontal := cos(altitude)
	_sky_directions[body] = Vector3(sin(azimuth) * horizontal, sin(altitude), -cos(azimuth) * horizontal)

## The sun and moons sit in their direction from the camera, just inside how
## far it sees, and scaled to match: so a hill between you and the sun hides it
## (they used to sit 760 m from the site's centre, nearer than a region's
## far hills, which then showed the sun through them).
var _sky_directions: Dictionary = {}   # body -> unit direction
const SKY_BASE_DISTANCE := 760.0       # the distance the bodies' sizes were made for

func _process(_delta: float) -> void:
	_follow_camera()

func _follow_camera() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null: return
	var distance := camera.far * .92
	for body in _sky_directions:
		if not is_instance_valid(body): continue
		var mesh := body as MeshInstance3D
		mesh.global_position = camera.global_position + (_sky_directions[body] as Vector3) * distance
		mesh.scale = Vector3.ONE * distance / SKY_BASE_DISTANCE
		mesh.look_at(camera.global_position, Vector3.UP, true)

func _build_terrain() -> void:
	_terrain_body = StaticBody3D.new()
	_terrain_body.name = "SiteWalkableTerrain"
	# Build equipment samples only this collider when it needs a ground height.
	# Keeping it identifiable prevents a newly placed object from ever becoming
	# the "ground" for the next one.
	_terrain_body.add_to_group("mars_terrain")
	_terrain_body.collision_layer = 1
	_terrain_body.collision_mask = 0
	_site_root.add_child(_terrain_body)
	if MHSiteTerrain.shape() == "region":
		_build_region_terrain()
		return
	MHSiteTerrain.build_ground(_terrain_body)
	_site_root.add_child(MHSiteTerrain.build_horizon())

## A region (gameplay loop prototype): Terrain3D draws the shared heightmap,
## kilometres of it, with distance detail and full collision, textured by
## zone and slope (its control map) and gently tinted (its colour map).
func _build_region_terrain() -> void:
	var zone := MHSiteTerrain.region_zone()
	if zone.is_empty(): return
	var region_id := str(MHSiteTerrain.settings().get("region", ""))
	var terrain := Terrain3D.new()
	terrain.name = "RegionTerrain3D"
	terrain.add_to_group("region_terrain")   # trenches cut holes in it (scripts/trenches.gd)
	terrain.vertex_spacing = float(MHSiteTerrain.RegionTerrain.meta().spacing)
	terrain.collision_layer = 1
	terrain.free_editor_textures = false
	# Its material and assets are set before it enters the scene (the
	# landscape is built before the world is); the heightmap goes in once
	# it's ready, when its data exists.
	var material := Terrain3DMaterial.new()
	material.world_background = Terrain3DMaterial.NONE
	material.set_shader_param("blend_sharpness", .85)
	# Steep ground (cliffs, the mound's terrace risers) takes its textures
	# from the side, not stretched down from above.
	material.projection_enabled = true
	terrain.material = material
	# Ground textures by zone (dust, bedrock on slopes, dune sand, frost,
	# crater clay, gravel), painted by the region's control map.
	var assets := Terrain3DAssets.new()
	var folder := MHSiteTerrain.RegionTerrain.DIRECTORY + region_id + "/"
	var names: Array = MHSiteTerrain.RegionTerrain.texture_names()
	for index in names.size():
		var texture_name := str(names[index])
		assets.set_texture_asset(index, _region_texture(texture_name.capitalize(), folder + "ground_" + texture_name, {"bedrock": .14, "talus": .18}.get(texture_name, .22)))
	for index in MHSiteTerrain.ROCK_MODELS.size():
		var rock := Terrain3DMeshAsset.new()
		rock.name = str(MHSiteTerrain.ROCK_MODELS[index])
		rock.scene_file = load(MODEL_DIRECTORY + rock.name + ".glb")
		rock.material_override = _rock_material()
		rock.lod0_range = 260.0
		rock.fade_margin = 30.0
		assets.set_mesh_asset(index, rock)
	terrain.assets = assets
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	var place: Dictionary = MHSiteTerrain.RegionTerrain.import_placement(origin, float(zone.height))
	terrain.ready.connect(func() -> void:
		terrain.region_size = Terrain3D.SIZE_1024   # 2 km regions: about 16 for the whole map (set once it's ready)
		terrain.data.import_images(_region_images(region_id), place.corner, float(place.offset), float(place.scale))
		if preview:
			_scatter_region_rocks(terrain, Rect2(-PREVIEW_ROCKS, -PREVIEW_ROCKS, PREVIEW_ROCKS * 2.0, PREVIEW_ROCKS * 2.0))
			return
		# Caves and the lava tube: built over the imported ground, which they
		# sink beneath them (before its collision is built).
		if not MHCaves.caves().is_empty():
			var caves := MHCaves.new()
			caves.build(terrain, self)
			_site_root.add_child.call_deferred(caves)
		# Collision over the whole region, not just round the camera: GAR-Y and
		# the rover roam out of view, and the rover's ground rays need it ahead
		# of a fast drive. Switched on after the import (set earlier it reverts
		# to dynamic, or is built from the flat ground before the heights).
		terrain.collision_mode = Terrain3DCollision.FULL_GAME
		_scatter_region_rocks(terrain, MHSiteTerrain.RegionTerrain.world_bounds(origin).grow(-500.0)), CONNECT_ONE_SHOT)
	_site_root.add_child(terrain)

## The heightmap, control map and colour map for Terrain3D. The menu's
## backdrop keeps them while sites are switched; the game reads them once.
static var _preview_images := {}

func _region_images(region_id: String) -> Array:
	if _preview_images.has(region_id): return _preview_images[region_id]
	var images := [MHSiteTerrain.RegionTerrain.import_image(), MHSiteTerrain.RegionTerrain.control_image(), MHSiteTerrain.RegionTerrain.colour_image()]
	_preview_images.clear()
	if preview: _preview_images[region_id] = images
	return images

## Rocks across the whole region (the base's own boulders, with collision,
## come from _build_decor), placed by the region's rock map: thick under
## cliffs, on fresh ejecta and in boulder fields (with corridors through),
## sparse on the dusty plains, none on dunes or the build pad. Drawn by Terrain3D's
## instancer, which fades them out with distance; the bigger ones are solid
## near the player, the rover and GAR-Y (region_rock_collision.gd).
func _scatter_region_rocks(terrain: Terrain3D, area: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var by_mesh: Array = []
	for index in MHSiteTerrain.ROCK_MODELS.size(): by_mesh.append([] as Array[Transform3D])
	var pad := float(MHSiteTerrain.settings().get("pad_half", 60.0)) + 40.0
	# Each model's footprint, for the rocks' collision (bigger rocks only).
	var reach: Array = []
	for model_name in MHSiteTerrain.ROCK_MODELS:
		var mesh := _load_model_mesh(str(model_name))
		var bounds := mesh.get_aabb() if mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
		reach.append(Vector2(maxf(bounds.size.x, bounds.size.z) * .42, bounds.size.y * .45))
	var solid: Array = []
	var zone := MHSiteTerrain.region_zone()
	var origin := Vector2(float(zone.centre[0]), float(zone.centre[1]))
	# About 4500 tries a square kilometre (120,000 over the whole region).
	for attempt in roundi(area.get_area() * .0045):
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		if absf(x) < pad and absf(z) < pad: continue
		var here := MHSiteTerrain.RegionTerrain.rock_density(x + origin.x, z + origin.y)
		if rng.randf() > here.x: continue
		var y := MHSiteTerrain.height(x, z)
		# Many small rocks, few big ones; bigger where they've fallen from cliffs or been thrown out by impacts.
		var size := rng.randf_range(.35, 1.1) * (1.0 + 1.2 * here.y * rng.randf()) * (2.2 if rng.randf() < .03 + .08 * here.y else 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-.25, .25), rng.randf() * TAU, rng.randf_range(-.25, .25))).scaled(Vector3.ONE * size)
		var mesh_index := rng.randi() % by_mesh.size()
		(by_mesh[mesh_index] as Array[Transform3D]).append(Transform3D(basis, Vector3(x, y - .15 * size, z)))
		var radius: float = (reach[mesh_index] as Vector2).x * size
		if radius > .3: solid.append(Vector4(x, y - .15 * size + (reach[mesh_index] as Vector2).y * size, z, radius))
	for index in by_mesh.size():
		terrain.instancer.add_transforms(index, by_mesh[index])
	if preview: return
	var collision := preload("res://scripts/region_rock_collision.gd").new()
	collision.setup(solid)
	_site_root.add_child.call_deferred(collision)   # the landscape is still being set up

func _region_texture(texture_name: String, path: String, uv_scale: float) -> Terrain3DTextureAsset:
	var asset := Terrain3DTextureAsset.new()
	asset.name = texture_name
	asset.albedo_texture = _mipmapped(path + "_albedo_height.png")
	asset.normal_texture = _mipmapped(path + "_normal_roughness.png")
	asset.uv_scale = uv_scale
	asset.detiling_rotation = .3
	asset.detiling_shift = .3
	return asset

## Kept once made (the region's ground textures take seconds to mipmap, and
## every region site and the menu's backdrop use the same ones).
static var _mipmapped_cache := {}

func _mipmapped(path: String) -> ImageTexture:
	if _mipmapped_cache.has(path): return _mipmapped_cache[path]
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	_mipmapped_cache[path] = ImageTexture.create_from_image(image)
	return _mipmapped_cache[path]

func _build_boundary() -> void:
	if MHSiteTerrain.shape() == "region":
		_build_region_boundary()
		return
	# Original invisible safety ring, just inside its visible boundary hills.
	var radius := 126.0
	var segments := 40
	var height := 80.0
	var segment_length := TAU * radius / segments * 1.15
	var boundary := StaticBody3D.new()
	boundary.name = "OriginalBoundarySafetyRing"
	boundary.collision_layer = 1
	boundary.collision_mask = 0
	add_child(boundary)
	for index in range(segments):
		var angle := TAU * index / segments
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(segment_length, height, 2.0)
		shape.shape = box
		shape.position = Vector3(cos(angle) * radius, height * 0.5 - 20.0, sin(angle) * radius)
		shape.rotation.y = -angle + PI * 0.5
		boundary.add_child(shape)

## A region's edge: four invisible walls in the framing hills.
func _build_region_boundary() -> void:
	var zone := MHSiteTerrain.region_zone()
	if zone.is_empty(): return
	var bounds: Rect2 = MHSiteTerrain.RegionTerrain.world_bounds(Vector2(float(zone.centre[0]), float(zone.centre[1]))).grow(-420.0)
	var boundary := StaticBody3D.new()
	boundary.name = "RegionBoundary"
	boundary.collision_layer = 1
	boundary.collision_mask = 0
	add_child(boundary)
	var centre := bounds.get_center()
	for wall in [[Vector3(centre.x, 0, bounds.position.y), Vector3(bounds.size.x, 2000, 4)], [Vector3(centre.x, 0, bounds.end.y), Vector3(bounds.size.x, 2000, 4)],
			[Vector3(bounds.position.x, 0, centre.y), Vector3(4, 2000, bounds.size.y)], [Vector3(bounds.end.x, 0, centre.y), Vector3(4, 2000, bounds.size.y)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		shape.position = wall[0]
		boundary.add_child(shape)

func _build_decor() -> void:
	var transforms_by_mesh := {}
	for placement in MHSiteTerrain.rock_placements():
		var model_name := str(placement.mesh)
		var scale_amount := float(placement.scale)
		var tilt: Vector2 = placement.get("tilt", Vector2.ZERO)
		var stretch: Vector3 = placement.get("stretch", Vector3.ONE)
		var transform := Transform3D(Basis.from_euler(Vector3(tilt.x, deg_to_rad(float(placement.yaw)), tilt.y)).scaled(stretch * scale_amount), placement.position)
		if not transforms_by_mesh.has(model_name):
			transforms_by_mesh[model_name] = []
		transforms_by_mesh[model_name].append(transform)
	for model_name in transforms_by_mesh:
		var mesh := _load_model_mesh(str(model_name))
		if mesh == null:
			continue
		var transforms: Array = transforms_by_mesh[model_name]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for index in transforms.size():
			multimesh.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = str(model_name)
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		instance.material_override = _rock_material()
		_site_root.add_child(instance)
		_add_decor_colliders(mesh, transforms)

## Boulders in the site's own ground colour, darker, with dust on top.
## Thousands of small stones (one batched draw, no collision or shadows).
func _build_pebbles() -> void:
	var transforms: Array = MHSiteTerrain.pebble_transforms()
	if transforms.is_empty(): return
	# A very low-poly stone (about 30 triangles): thousands of them stay cheap.
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = .5
	mesh.height = .7
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size(): multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Pebbles"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 70.0
	instance.material_override = _rock_material()
	_site_root.add_child(instance)

func _rock_material() -> ShaderMaterial:
	var ground := Color(str(MHSiteTerrain.settings().get("ground", "#A9603E")))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/mars_rock.gdshader")
	material.set_shader_parameter("rock_colour", ground.darkened(.28))
	material.set_shader_parameter("dust_colour", ground.lightened(.06))
	return material

func _load_model_mesh(model_name: String) -> Mesh:
	var scene_path := MODEL_DIRECTORY + model_name + ".glb"
	if not ResourceLoader.exists(scene_path):
		return null
	var scene: PackedScene = load(scene_path)
	var model_root := scene.instantiate()
	var mesh_nodes := model_root.find_children("*", "MeshInstance3D", true, false)
	var result: Mesh = null
	if mesh_nodes.size() > 0:
		result = (mesh_nodes[0] as MeshInstance3D).mesh
	model_root.free()
	return result

func _add_decor_colliders(mesh: Mesh, transforms: Array) -> void:
	var bounds := mesh.get_aabb()
	for transform in transforms:
		var body := StaticBody3D.new()
		body.name = "DecorCollider"
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(bounds.size.x, bounds.size.z) * 0.42 * transform.basis.get_scale().x
		collision.shape = sphere
		collision.position = Vector3(0.0, bounds.size.y * 0.45 * transform.basis.get_scale().y, 0.0)
		body.add_child(collision)
		body.position = transform.origin
		body.rotation.y = transform.basis.get_euler().y
		_site_root.add_child(body)
