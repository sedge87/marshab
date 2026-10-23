extends RefCounted

## The marks Mars weather leaves behind, and how they wear off (Batch D).
##
##   Dust      Every solar array gathers dust: a little each sol (more where
##             the wind lifts dust), a lot in a dust storm. Dusty cells make
##             less power: Spirit and Opportunity slowly lost power this way,
##             and InSight shut down in 2022 under its dust. It comes off three
##             ways: a dust devil passing over (NASA's "cleaning events",
##             which kept the rovers going for years), a lucky gust now and
##             then, or a crew member brushing it off (E on the array).
##             After a storm the hull is coated orange too, fading over a few
##             sols as the wind scours it.
##   Frost     Water and carbon dioxide frost forms on cold nights and
##             sublimates in the morning sun (Viking 2 photographed it in
##             Utopia Planitia). It covers the panels, hull and windows until
##             it's gone, so the first hours of sun make less power. Heaviest
##             on the Ice Fields; light in the canyon's morning cloud; a trace
##             elsewhere.
##
## The simulation (habitat_sim.gd) keeps the numbers and charges the power;
## site_weather.gd draws the marks and sends dust devils over the arrays.
## Only in Survival and Freedom, and in Missions from Mission 5 (when storms
## arrive). Creative and the mission Tests stay clean.

const MHMissions := preload("res://scripts/mh_missions.gd")

## Dust gathered per sol in calm weather, and in a storm.
const DUST_PER_SOL := {"plains": .02, "crater": .016, "ridge": .025, "ice": .008}
const STORM_DUST_PER_SOL := .3
const MAX_DUST := .8
## Share of a dusty array's power lost (at full dust); frost at full cover.
const DUST_LOSS := .85
const FROST_LOSS := .45
## A gust cleaning an array: chance per array per sol, and what it leaves.
const GUST_CLEAN_PER_SOL := .06
const GUST_LEAVES := .5
## The hull's dust coat halves every this many sols.
const HULL_HALF_LIFE_SOLS := 2.5
## Peak frost cover on each site, and when it forms and goes (hours).
const FROST_PEAK := {"ice": 1.0, "ridge": .45, "crater": .25, "plains": .12}

static func enabled() -> bool:
	match MHGame.game_mode:
		"survival", "freedom": return true
		"missions": return int(MHMissions.current().get("number", 0)) >= 5 if MHMissions.active() else false
	return false

## Frost cover (0-1) at this hour: builds from late evening, peaks before
## dawn, sublimates through the morning (the same timing the Ice Fields'
## ground frost uses).
static func frost(site_id: String, hour: float) -> float:
	var peak := float(FROST_PEAK.get(site_id, .12))
	var cover := 0.0
	if hour >= 20.0 or hour < 5.5: cover = clampf(fposmod(hour - 20.0, 24.0) / 9.0, 0.0, 1.0)
	elif hour < 10.5: cover = 1.0 - smoothstep(5.5, 10.5, hour)
	return cover * peak

# ---------- how the marks look ----------

## On the solar cells: fine orange dust thickening from the lower edge up
## (it slides down the tilted panel), and white frost crystals.
const PANEL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform float dust = 0.0;
uniform float frost = 0.0;
varying vec3 wpos;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz + vec2(wpos.y * 0.7);
	float grain = vnoise(p * 9.0) * 0.6 + vnoise(p * 31.0) * 0.4;
	// Lower on the panel collects more.
	float low = 1.0 - smoothstep(1.05, 1.8, wpos.y);
	float d = smoothstep(0.0, 1.0, dust * (0.75 + 0.6 * low) + (grain - 0.5) * 0.35);
	float crystals = smoothstep(0.55, 0.9, vnoise(p * 48.0) * 0.5 + vnoise(p * 13.0) * 0.5);
	float f = clamp(frost * 1.6 - (1.0 - crystals) * 0.3, 0.0, 1.0);
	vec3 dust_colour = vec3(0.74, 0.5, 0.33) * mix(0.85, 1.1, grain);
	vec3 frost_colour = vec3(0.92, 0.95, 1.0);
	float frosty = f / max(f + d, 0.001);
	ALBEDO = mix(dust_colour, frost_colour, frosty);
	EMISSION = frost_colour * f * frosty * (0.18 + 0.25 * crystals);
	ROUGHNESS = mix(0.95, 0.4, frosty);
	ALPHA = clamp(max(d * 0.92, f * 0.85), 0.0, 1.0);
}
"""

## On the outside of the hull: dust banked up from the ground and lying on
## top surfaces, and frost on everything facing the sky. A next pass over the
## kit's hull, panel and seal materials, so every module shares one material.
const HULL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform float dust = 0.0;
uniform float frost = 0.0;
uniform float base_y = 0.0;
// 0 while you're inside: the same boxes make the inner faces of the walls.
uniform float outside = 1.0;
varying vec3 wpos;
varying vec3 wnormal;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float h = wpos.y - base_y;
	vec2 p = vec2(wpos.x + wpos.z, wpos.y);
	float grain = vnoise(p * vec2(2.5, 6.0)) * 0.6 + vnoise(wpos.xz * 4.0 + vec2(h * 3.0)) * 0.4;
	float up = smoothstep(0.35, 0.9, wnormal.y);
	// Banked against the walls from the ground up, streaked by the wind, and
	// lying on anything flat.
	float bank = 1.0 - smoothstep(0.0, 0.4 + 2.2 * dust, h + (grain - 0.5) * 0.8);
	float d = clamp(dust * 1.4 * max(bank, up * 0.9) + (grain - 0.55) * 0.3 * dust, 0.0, 1.0);
	float crystals = vnoise(wpos.xz * 22.0 + vec2(wpos.y * 9.0));
	float f = clamp(frost * (0.35 + 0.65 * up) * 1.4 - (1.0 - crystals) * 0.45, 0.0, 1.0);
	vec3 dust_colour = vec3(0.82, 0.58, 0.4) * mix(0.88, 1.06, grain);
	ALBEDO = mix(dust_colour, vec3(0.9, 0.93, 0.97), f / max(f + d, 0.001));
	ROUGHNESS = 0.95;
	ALPHA = clamp(max(d * 0.72, f * 0.75), 0.0, 1.0) * outside;
}
"""

## On window glass: frost creeping in from the corners and dust from the
## bottom edge, so you can see it from inside too.
const WINDOW_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;
uniform float dust = 0.0;
uniform float frost = 0.0;
uniform vec2 half_size = vec2(1.0, 0.6);
varying vec3 lpos;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void vertex() { lpos = VERTEX; }
void fragment() {
	// Across the pane, 0-1 each way (the pane is a thin box, centred).
	vec2 uv = clamp(lpos.xy / (half_size * 2.0) + 0.5, 0.0, 1.0);
	uv.y = 1.0 - uv.y;
	vec2 e = min(uv, 1.0 - uv);
	float edge = 1.0 - smoothstep(0.0, 0.5, min(e.x, e.y) * 2.0);
	float fern = vnoise(uv * vec2(40.0, 26.0)) * 0.6 + vnoise(uv * 110.0) * 0.4;
	float f = smoothstep(0.0, 0.35, frost * (edge * edge * 1.5 + 0.05) - (1.0 - fern) * 0.6);
	float bottom = 1.0 - smoothstep(0.0, 0.25 + 0.5 * dust, 1.0 - uv.y + (fern - 0.5) * 0.15);
	float d = clamp(dust * (0.25 + bottom), 0.0, 1.0);
	ALBEDO = mix(vec3(0.72, 0.5, 0.36), vec3(0.88, 0.92, 0.97), f / max(f + d, 0.001));
	ALPHA = clamp(max(d * 0.5, f * 0.6), 0.0, 1.0);
}
"""

static var _hull_material: ShaderMaterial

static func panel_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(PANEL_SHADER)
	return material

## One shared material for every hull module's dust and frost.
static func hull_material() -> ShaderMaterial:
	if _hull_material == null:
		_hull_material = ShaderMaterial.new()
		_hull_material.shader = _shader(HULL_SHADER)
	return _hull_material

## One per pane: it needs the pane's size.
static func window_material(size: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(WINDOW_SHADER)
	material.set_shader_parameter("half_size", size * .5)
	return material

static var _shaders := {}
static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var shader := Shader.new()
		shader.code = code
		_shaders[code] = shader
	return _shaders[code]
