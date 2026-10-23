extends Node3D

## Each site's own weather, from what NASA has actually seen there (realistic
## pass, 24 Oct). Visual and sound only: nothing here changes the simulation.
## Settings → Weather effects turns it all off. Dust storms stay in weather.gd.
##   Every site    blue sunsets: fine dust lets blue light through near the Sun
##                 (Curiosity, Gale Crater, 2015).
##   Ice Fields    dawn frost that sublimates through the morning, last in the
##                 shade (Viking 2, Utopia Planitia, 1977); snow at night from
##                 ice clouds, mostly vanishing as it falls (Phoenix lidar,
##                 2008); low ice fog at dawn.
##   Canyon Ridge  morning cloud filling the canyon, burning off by late morning
##                 (Viking Orbiter 1 over Valles Marineris, 1976); dust blowing
##                 down the canyon in the afternoon; the odd distant rockfall.
##   Crater Basin  dust devils on summer afternoons (Curiosity, Gale, 2017);
##                 iridescent twilight clouds and sun rays at sunset
##                 (Curiosity, 2023); thin morning ice clouds.
##   Open Plains   dust devils that leave dark tracks (InSight, Elysium Planitia:
##                 thousands detected, tracks seen from orbit); rare marsquakes
##                 (InSight recorded 1,319); dust lifting in the morning gusts.

const TERRAIN := preload("res://scripts/site_terrain.gd")
const MAX_TRACKS := 16

var world: Node
var site := ""
var _rng := RandomNumberGenerator.new()
var _fog: Array[MeshInstance3D] = []
var _fog_heights: Array = []
var _snow: CPUParticles3D
var _streaks: CPUParticles3D
var _clouds: MeshInstance3D
var _rays: MeshInstance3D
var _halo: MeshInstance3D
var _devils: Array = []          # {node, velocity, life, last}
var _devil_wait := 30.0
var _tracks: Array = []          # [Vector4(x1, z1, x2, z2), age (hours)]
var _ground_materials: Array = []
var _rock_materials: Array = []
var _quake_left := 0.0
var _quake_wait := 0.0
var _rockfall_wait := 0.0
var _last_hour := -1.0

func setup(target_world: Node) -> void:
	world = target_world
	site = str(MHGame.site().get("id", "plains"))
	name = "SiteWeather"
	_rng.randomize()
	_devil_wait = _rng.randf_range(20.0, 60.0)
	_quake_wait = _rng.randf_range(600.0, 2400.0)
	_rockfall_wait = _rng.randf_range(300.0, 900.0)
	match site:
		"ice":
			_build_fog(Vector2(320.0, 320.0), [.4, 1.2, 2.2], Color("#DCE2E6"), .035)
			_build_snow()
		"ridge":
			_build_fog(Vector2(56.0, 900.0), [1.5, 3.5, 5.5, 7.5, 9.5, 11.5, 13.5, 15.5], Color("#DCCFC4"), .022, true)
			_build_streaks(Vector3(0, 0, 1))
		"crater":
			_build_clouds()
			_build_rays()
		_:
			_build_streaks(Vector3(1, 0, 0))
	_build_halo()

# ---------- each frame ----------

func _process(delta: float) -> void:
	var on := bool(MHGame.setting("weather"))
	var inside := false
	var env = world.get("environment")
	if env != null: inside = bool(env.get("inside_habitat"))
	var hour := MHGame.sol_hour
	var sun := _sun_altitude(hour)
	if _ground_materials.is_empty(): _find_materials()
	_update_halo(on and not inside, sun)
	match site:
		"ice": _update_ice(on and not inside, hour, sun)
		"ridge": _update_canyon(on and not inside, hour, delta)
		"crater":
			_update_crater_sky(on, hour, sun)
			_update_devils(on, hour, delta, false)
		_:
			_update_devils(on, hour, delta, true)
			_update_gusts(on and not inside, hour)
			_update_quake(on, delta)
	if _last_hour >= 0.0:
		var passed := fposmod(hour - _last_hour, 24.0)
		if passed < 2.0: _age_tracks(passed)
	_last_hour = hour

## Degrees above the horizon (negative after sunset), from the site's day.
func _sun_altitude(hour: float) -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var rise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var progress := (hour - rise) / maxf(.1, sunset - rise)
	if progress >= 0.0 and progress <= 1.0: return sin(progress * PI) * rad_to_deg(MHGame.sun_noon_altitude())
	var after := hour - sunset if hour > sunset else hour + 24.0 - sunset
	var before := rise - hour if hour < rise else rise + 24.0 - hour
	return -minf(after, before) * 12.0

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

func _find_materials() -> void:
	var env = world.get("environment")
	if env == null: return
	for node in (env as Node).find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override
		if material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			if shader != null and shader.resource_path.ends_with("mars_ground.gdshader"): _ground_materials.append(material)
	for node in (env as Node).find_children("*", "MultiMeshInstance3D", true, false):
		var material := (node as MultiMeshInstance3D).material_override
		if material is ShaderMaterial: _rock_materials.append(material)

func _set_ground(param: String, value: Variant) -> void:
	for material in _ground_materials: (material as ShaderMaterial).set_shader_parameter(param, value)
	for material in _rock_materials: (material as ShaderMaterial).set_shader_parameter(param, value)

# ---------- fog layers (canyon cloud, ice fog) ----------

const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.9, 0.86, 0.82, 1.0);
uniform float density = 0.0;
uniform float scale = 0.025;
uniform vec2 drift = vec2(0.6, 0.25);
varying vec3 wpos;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float t = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { t += a * vnoise(p); p *= 2.03; a *= 0.5; } return t; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * scale + drift * TIME * 0.004;
	float n = fbm(p + vec2(wpos.y * 0.37));
	float near = smoothstep(1.5, 14.0, length(wpos - CAMERA_POSITION_WORLD));
	// Soft edges all round (no hard line where a layer ends or meets a wall).
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.18, e.x) * smoothstep(0.0, 0.04, e.y);
	ALBEDO = tint.rgb;
	ALPHA = clamp(density * smoothstep(0.32, 0.72, n) * near * edge, 0.0, 1.0);
}
"""

func _build_fog(size: Vector2, heights: Array, tint: Color, scale: float, canyon := false) -> void:
	var shader := Shader.new()
	shader.code = FOG_SHADER
	for height in heights:
		var layer := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = size
		if canyon: mesh.size.x = 2.0 * (26.0 + float(height) * .9)   # the canyon widens upward
		layer.mesh = mesh
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("scale", scale)
		material.set_shader_parameter("drift", Vector2(_rng.randf_range(-.8, .8), _rng.randf_range(.3, 1.0)))
		layer.material_override = material
		layer.position.y = float(height)
		layer.visible = false
		add_child(layer)
		_fog.append(layer)
		_fog_heights.append(float(height))

func _set_fog(amount: float, lift := 0.0) -> void:
	for i in range(_fog.size()):
		var layer := _fog[i]
		layer.visible = amount > .01
		if not layer.visible: continue
		# Lower layers are thicker; the whole bank rises as it burns off.
		var thick := amount * lerpf(1.0, .45, float(i) / maxf(1.0, _fog.size() - 1.0))
		(layer.material_override as ShaderMaterial).set_shader_parameter("density", thick)
		layer.position.y = float(_fog_heights[i]) + lift

# ---------- Ice Fields ----------

func _build_snow() -> void:
	_snow = CPUParticles3D.new()
	_snow.amount = 700
	_snow.lifetime = 9.0
	_snow.preprocess = 9.0
	_snow.local_coords = false
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(22.0, .5, 22.0)
	_snow.direction = Vector3(.15, -1.0, .05)
	_snow.spread = 12.0
	_snow.gravity = Vector3(0, -.35, 0)
	_snow.initial_velocity_min = .4
	_snow.initial_velocity_max = .9
	_snow.scale_amount_min = .5
	_snow.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(.035, .035)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(.92, .95, 1.0, .9)
	material.emission_enabled = true
	material.emission = Color(.75, .8, .9)
	material.emission_energy_multiplier = 1.6
	quad.material = material
	_snow.mesh = quad
	_snow.emitting = false
	_snow.visible = false
	add_child(_snow)

func _update_ice(on: bool, hour: float, sun: float) -> void:
	# Frost: builds through the night, sublimates through the morning.
	var frost := 0.0
	if hour >= 20.0 or hour < 5.5: frost = clampf((fposmod(hour - 20.0, 24.0)) / 9.0, 0.0, 1.0)
	elif hour < 10.5: frost = 1.0 - smoothstep(5.5, 10.5, hour)
	_set_ground("frost_cover", frost if on else 0.0)
	# Night snow from the ice clouds (after midnight, until just before dawn).
	var snowing := on and (hour >= .5 and hour < 4.5)
	if _snow != null:
		_snow.visible = snowing
		_snow.emitting = snowing
		var cam := _camera()
		if snowing and cam != null: _snow.global_position = cam.global_position + Vector3(0, 9.0, 0)
	# Low ice fog at dawn, lifting as the sun climbs.
	var fog := 0.0
	if hour >= 4.5 and hour < 9.0: fog = smoothstep(4.5, 6.0, hour) * (1.0 - smoothstep(7.0, 9.0, hour))
	_set_fog(fog * .22 if on else 0.0, smoothstep(6.5, 9.0, hour) * 2.0)

# ---------- Canyon Ridge ----------

func _update_canyon(on: bool, hour: float, delta: float) -> void:
	# Morning cloud fills the canyon at dawn, rises and burns off by late morning.
	var fog := 0.0
	if hour >= 4.0 and hour < 11.0: fog = smoothstep(4.0, 5.5, hour) * (1.0 - smoothstep(8.0, 11.0, hour))
	_set_fog(fog * .38 if on else 0.0, smoothstep(7.0, 11.0, hour) * 10.0)
	_set_streaks(on and hour >= 13.0 and hour < 17.5, .8)
	# The odd rockfall, high on a wall, far from the base.
	if on and MHGame.sunlight_fraction > .1:
		_rockfall_wait -= delta
		if _rockfall_wait <= 0.0:
			_rockfall_wait = _rng.randf_range(400.0, 1100.0)
			_rockfall()

func _rockfall() -> void:
	var side := -1.0 if _rng.randf() < .5 else 1.0
	var z := _rng.randf_range(70.0, 150.0) * (-1.0 if _rng.randf() < .5 else 1.0)
	var x := side * (TERRAIN._canyon_foot(z, side) + _rng.randf_range(6.0, 16.0))
	var at := Vector3(x, TERRAIN.height(x, z), z)
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = 90
	puff.lifetime = 6.0
	puff.explosiveness = .6
	puff.local_coords = false
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 2.0
	puff.direction = Vector3(-side, -.6, 0)
	puff.spread = 40.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 4.0
	puff.gravity = Vector3(0, -1.2, 0)
	puff.scale_amount_min = 1.5
	puff.scale_amount_max = 4.0
	puff.mesh = _dust_quad(Color(.62, .48, .38, .35))
	add_child(puff)
	puff.global_position = at
	puff.emitting = true
	MHAudio.sfx_at("rockfall", puff, -4.0, 0.0)
	get_tree().create_timer(8.0).timeout.connect(puff.queue_free)

# ---------- blowing dust (canyon afternoons, plains mornings) ----------

func _build_streaks(direction: Vector3) -> void:
	_streaks = CPUParticles3D.new()
	_streaks.amount = 160
	_streaks.lifetime = 3.0
	_streaks.local_coords = false
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(26.0, 1.2, 26.0)
	_streaks.direction = direction
	_streaks.spread = 8.0
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 6.0
	_streaks.initial_velocity_max = 10.0
	_streaks.particle_flag_align_y = true
	_streaks.scale_amount_min = .6
	_streaks.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(.06, 1.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(.78, .62, .48, .18)
	quad.material = material
	_streaks.mesh = quad
	_streaks.emitting = false
	_streaks.visible = false
	add_child(_streaks)

func _set_streaks(on: bool, _strength: float) -> void:
	if _streaks == null: return
	_streaks.visible = on
	_streaks.emitting = on
	var cam := _camera()
	if on and cam != null: _streaks.global_position = cam.global_position + Vector3(0, -.6, 0)

func _update_gusts(on: bool, hour: float) -> void:
	# InSight: the wind is strongest just after sunrise.
	_set_streaks(on and hour >= 5.5 and hour < 8.5, .6)

# ---------- dust devils (plains and crater) ----------

const DEVIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.76, 0.6, 0.47, 1.0);
uniform float opacity = 0.0;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void fragment() {
	// Dust swirling up and round the funnel; thickest low down.
	float swirl = vnoise(vec2(UV.x * 10.0 + TIME * 2.4 + UV.y * 5.0, UV.y * 7.0 - TIME * 1.6));
	swirl = swirl * 0.7 + vnoise(vec2(UV.x * 23.0 + TIME * 3.1, UV.y * 15.0 - TIME * 2.0)) * 0.3;
	float body = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.35, 1.0, UV.y)) * 0.6 + (1.0 - smoothstep(0.0, 0.25, UV.y)) * 0.4;
	ALBEDO = tint.rgb * mix(0.85, 1.1, swirl);
	ALPHA = clamp(opacity * body * smoothstep(0.25, 0.75, swirl), 0.0, 1.0);
}
"""

func _spawn_devil(avoid_pad: bool) -> void:
	var cam := _camera()
	if cam == null: return
	var at := Vector2.ZERO
	for attempt in 20:
		var angle := _rng.randf() * TAU
		at = Vector2(cam.global_position.x, cam.global_position.z) + Vector2.from_angle(angle) * _rng.randf_range(35.0, 90.0)
		if at.length() > 118.0: continue
		if avoid_pad and absf(at.x) < 64.0 and absf(at.y) < 64.0: continue
		break
	var devil := Node3D.new()
	var funnel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var height := _rng.randf_range(25.0, 60.0)
	mesh.height = height
	mesh.bottom_radius = _rng.randf_range(.8, 1.6)
	mesh.top_radius = mesh.bottom_radius * _rng.randf_range(3.0, 5.0)
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 20
	mesh.rings = 6
	funnel.mesh = mesh
	funnel.position.y = height * .5
	funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = DEVIL_SHADER
	funnel.material_override = material
	devil.add_child(funnel)
	var skirt := CPUParticles3D.new()
	skirt.amount = 40
	skirt.lifetime = 2.5
	skirt.local_coords = false
	skirt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	skirt.emission_sphere_radius = 2.0
	skirt.direction = Vector3.UP
	skirt.spread = 40.0
	skirt.initial_velocity_min = 1.0
	skirt.initial_velocity_max = 2.5
	skirt.gravity = Vector3(0, -.3, 0)
	skirt.scale_amount_min = 1.0
	skirt.scale_amount_max = 2.2
	skirt.mesh = _dust_quad(Color(.74, .58, .45, .25))
	devil.add_child(skirt)
	add_child(devil)
	devil.global_position = Vector3(at.x, TERRAIN.height(at.x, at.y), at.y)
	var heading := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, 4.5)
	_devils.append({"node": devil, "material": material, "velocity": heading, "life": _rng.randf_range(50.0, 110.0), "age": 0.0, "last": at})

func _update_devils(on: bool, hour: float, delta: float, avoid_pad: bool) -> void:
	var season := hour >= 11.5 and hour < 16.5
	if on and season:
		_devil_wait -= delta
		if _devil_wait <= 0.0 and _devils.size() < 2:
			_devil_wait = _rng.randf_range(45.0, 120.0)
			_spawn_devil(avoid_pad)
	for devil in _devils.duplicate():
		var node: Node3D = devil.node
		devil.age = float(devil.age) + delta
		var fade := smoothstep(0.0, 6.0, float(devil.age)) * (1.0 - smoothstep(float(devil.life) - 8.0, float(devil.life), float(devil.age)))
		(devil.material as ShaderMaterial).set_shader_parameter("opacity", fade * .55 if on else 0.0)
		node.visible = on
		# Wander, staying on site.
		var v: Vector2 = devil.velocity
		v = v.rotated(_rng.randf_range(-.3, .3) * delta)
		var here := Vector2(node.global_position.x, node.global_position.z) + v * delta
		if here.length() > 120.0: v = -v
		devil.velocity = v
		node.global_position = Vector3(here.x, TERRAIN.height(here.x, here.y), here.y)
		# Leave a dark track (Open Plains), a segment every few metres.
		if site == "plains" and here.distance_to(devil.last) > 6.0:
			_add_track(devil.last, here)
			devil.last = here
		if float(devil.age) >= float(devil.life):
			node.queue_free()
			_devils.erase(devil)

func _add_track(a: Vector2, b: Vector2) -> void:
	_tracks.append([Vector4(a.x, a.y, b.x, b.y), 0.0])
	while _tracks.size() > MAX_TRACKS: _tracks.pop_front()
	_push_tracks()

func _age_tracks(hours: float) -> void:
	if _tracks.is_empty(): return
	for track in _tracks: track[1] = float(track[1]) + hours
	# Tracks fade over a few sols as fresh dust settles.
	_tracks = _tracks.filter(func(t): return float(t[1]) < 72.0)
	_push_tracks()

func _push_tracks() -> void:
	var segments: Array = []
	for i in range(MAX_TRACKS):
		if i < _tracks.size():
			var t: Array = _tracks[i]
			segments.append(t[0])
			segments.append(Vector4(1.0 - float(t[1]) / 72.0, 0, 0, 0))
		else:
			segments.append(Vector4.ZERO)
			segments.append(Vector4.ZERO)
	for material in _ground_materials: (material as ShaderMaterial).set_shader_parameter("tracks", segments)

# ---------- marsquakes (Open Plains) ----------

func _update_quake(on: bool, delta: float) -> void:
	var cam := _camera()
	if _quake_left > 0.0:
		_quake_left -= delta
		var strength := clampf(_quake_left / 5.0, 0.0, 1.0) * .045
		if cam != null:
			cam.h_offset = _rng.randf_range(-strength, strength)
			cam.v_offset = _rng.randf_range(-strength, strength)
		if _quake_left <= 0.0 and cam != null:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
		return
	if not on: return
	_quake_wait -= delta
	if _quake_wait <= 0.0:
		_quake_wait = _rng.randf_range(1500.0, 3600.0)
		marsquake()

## A gentle marsquake: the ground trembles for a few seconds.
func marsquake() -> void:
	_quake_left = 5.5
	MHAudio.sfx("quake_rumble", -2.0, 0.0)
	MHAudio.voice("seismic_activity")
	var weather = world.get("weather")
	if weather != null and weather.has_method("toast"):
		weather.toast("Marsquake", "The ground is trembling. NASA's InSight lander recorded 1,319 marsquakes here on Elysium Planitia. The largest, in May 2022, was magnitude 4.7.", MHStyle.INFO)

# ---------- Crater Basin sky: twilight clouds, sun rays, morning ice clouds ----------

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float twilight = 0.0;   // iridescent clouds lit after sunset
uniform float morning = 0.0;    // thin white ice clouds
varying vec3 wpos;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float t = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { t += a * vnoise(p); p *= 2.03; a *= 0.5; } return t; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Streaky high clouds, stretched along the wind.
	vec2 p = vec2(wpos.x * 0.004, wpos.z * 0.012) + vec2(TIME * 0.002, 0.0);
	float n = fbm(p);
	float wisp = smoothstep(0.48, 0.75, n);
	float edge = 1.0 - smoothstep(500.0, 900.0, length(wpos.xz));
	// Iridescence: pastel colours shifting with the particle size (Curiosity, 2023).
	float hue = fbm(p * 2.3 + 4.0) * 3.0;
	vec3 iri = 0.84 + 0.12 * cos(6.2831 * (hue + vec3(0.0, 0.33, 0.67)));
	vec3 colour = mix(vec3(0.95, 0.93, 0.9), iri, twilight);
	ALBEDO = colour;
	ALPHA = clamp(wisp * edge * max(twilight * 0.5, morning * 0.35), 0.0, 1.0);
}
"""

const RAYS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
float hash(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	// Beams fanning up from the Sun just below the horizon (Curiosity, Feb 2023).
	vec2 p = UV - vec2(0.5, 1.0);
	float angle = atan(p.x, -p.y);
	float beams = 0.0;
	for (int i = 0; i < 9; i++) {
		float centre = (hash(float(i)) - 0.5) * 1.6;
		float width = 0.02 + hash(float(i) + 7.0) * 0.05;
		beams += (1.0 - smoothstep(0.0, width, abs(angle - centre))) * (0.5 + hash(float(i) + 3.0) * 0.5);
	}
	float fade = (1.0 - smoothstep(0.1, 1.0, length(p))) * smoothstep(0.0, 0.05, -p.y);
	ALBEDO = vec3(1.0, 0.86, 0.7);
	ALPHA = clamp(beams * fade * strength, 0.0, 0.6);
}
"""

func _build_clouds() -> void:
	_clouds = MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1800.0, 1800.0)
	_clouds.mesh = mesh
	_clouds.position.y = 260.0
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = CLOUD_SHADER
	_clouds.material_override = material
	_clouds.visible = false
	add_child(_clouds)

func _build_rays() -> void:
	_rays = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(900.0, 450.0)
	_rays.mesh = mesh
	_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = RAYS_SHADER
	_rays.material_override = material
	_rays.visible = false
	add_child(_rays)

func _update_crater_sky(on: bool, hour: float, sun: float) -> void:
	var evening := hour > 12.0
	# Twilight: from the sun touching the horizon until about 1.5 hours after sunset.
	var twilight := 0.0
	if evening: twilight = smoothstep(4.0, -1.0, sun) * (1.0 - smoothstep(-12.0, -20.0, sun))
	var morning := 0.0
	if not evening and sun > 0.0: morning = smoothstep(0.0, 8.0, sun) * (1.0 - smoothstep(25.0, 40.0, sun))
	if _clouds != null:
		_clouds.visible = on and (twilight > .01 or morning > .01)
		var material := _clouds.material_override as ShaderMaterial
		material.set_shader_parameter("twilight", twilight)
		material.set_shader_parameter("morning", morning)
		var cam := _camera()
		if cam != null: _clouds.global_position = Vector3(cam.global_position.x, 260.0, cam.global_position.z)
	# Sun rays: as the sun sets.
	var rays := 0.0
	if evening: rays = smoothstep(9.0, 2.0, sun) * (1.0 - smoothstep(-2.0, -7.0, sun))
	if _rays != null:
		_rays.visible = on and rays > .01
		if _rays.visible: _place_on_sky(_rays, hour, 700.0, -40.0)
		(_rays.material_override as ShaderMaterial).set_shader_parameter("strength", rays)

## Put a quad on the sky toward the setting/rising sun, facing the camera.
func _place_on_sky(node: Node3D, hour: float, distance: float, drop: float) -> void:
	var cam := _camera()
	if cam == null: return
	var west := hour > 12.0
	# Sunrise in the east (+x), sunset in the west (-x), crossing the south (+z).
	var dir := Vector3(-1.0 if west else 1.0, 0.0, .15).normalized()
	node.global_position = cam.global_position + dir * distance + Vector3(0, drop + 210.0, 0)
	node.look_at(cam.global_position, Vector3.UP, true)

# ---------- blue sunsets (every site) ----------

const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_add;
uniform float strength = 0.0;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	// Blue light scattered close around the low Sun (Curiosity, Gale, 2015).
	vec3 blue = vec3(0.42, 0.62, 0.9);
	float glow = pow(1.0 - smoothstep(0.0, 1.0, r), 2.2);
	ALBEDO = blue * glow * strength;
}
"""

func _build_halo() -> void:
	_halo = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(260.0, 260.0)
	_halo.mesh = mesh
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = HALO_SHADER
	_halo.material_override = material
	_halo.visible = false
	add_child(_halo)

func _update_halo(on: bool, sun: float) -> void:
	if _halo == null: return
	var env = world.get("environment")
	var corona: MeshInstance3D = env.get("_sun_corona") if env != null else null
	var strength := smoothstep(22.0, 7.0, sun) * (1.0 - smoothstep(2.0, -2.0, sun))
	_halo.visible = on and strength > .01 and corona != null and corona.visible
	if not _halo.visible: return
	var cam := _camera()
	_halo.global_position = corona.global_position * .985 if cam == null else cam.global_position + (corona.global_position - cam.global_position) * .985
	if cam != null: _halo.look_at(cam.global_position, Vector3.UP, true)
	(_halo.material_override as ShaderMaterial).set_shader_parameter("strength", strength * .9)
	# The sun's own corona turns blue-white too.
	var material := corona.material_override as ShaderMaterial
	if material != null: material.set_shader_parameter("corona_colour", Color(1.0, .5, .2).lerp(Color(.55, .72, .95), strength))

# ---------- shared ----------

func _dust_quad(colour: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.albedo_texture = _soft_dot()
	quad.material = material
	return quad

static var _dot: ImageTexture
static func _soft_dot() -> ImageTexture:
	if _dot != null: return _dot
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2.0))
	_dot = ImageTexture.create_from_image(image)
	return _dot
