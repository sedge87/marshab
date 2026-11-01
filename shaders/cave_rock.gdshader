shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Cave walls, floors and portals (scripts/caves.gd): rock in world space, as
// in shaders/mars_rock.gdshader, with dust on what faces up, layers in the
// canyon cave's walls, ice in the ice cave and a ropy lava floor in the tube.
// Drawn from both sides (the tunnels are seen from inside and out).

uniform vec3 rock_colour : source_color = vec3(0.34, 0.2, 0.14);
uniform vec3 dust_colour : source_color = vec3(0.6, 0.37, 0.24);
uniform float strata = 0.0;   // the canyon cave: the canyon's layers from inside
uniform float ice = 0.0;      // the ice cave

varying vec3 world_pos;
varying vec3 world_normal;
varying float depth;   // how far in (vertex colour red: 0 at the mouth, 1 at the back)

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	depth = COLOR.r;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

void fragment() {
	vec3 n = FRONT_FACING ? world_normal : -world_normal;
	float mottle = noise3(world_pos * 1.1) * 0.6 + noise3(world_pos * 4.2) * 0.4;
	vec3 colour = rock_colour * mix(0.7, 1.15, mottle);
	colour *= mix(1.0, 0.8, smoothstep(0.78, 0.86, noise3(world_pos * 8.0)));   // vesicles and pits
	// Layers: pale and dark bands, gently wavy.
	float band = sin(world_pos.y * 2.6 + noise3(world_pos * 0.25) * 5.0);
	colour *= 1.0 + strata * 0.16 * band;
	colour = mix(colour, rock_colour * vec3(1.5, 1.32, 1.15), strata * smoothstep(0.55, 0.95, band) * 0.45);
	// Floors: dust, and in the tube the old flow's ropy folds (pahoehoe).
	float up = smoothstep(0.55, 0.92, n.y);
	float ropes = smoothstep(0.3, 0.7, sin(world_pos.x * 3.0 + world_pos.z * 1.7 + noise3(world_pos * 0.7) * 6.0)) * (1.0 - strata) * (1.0 - ice);
	colour = mix(colour, colour * 0.82, up * ropes * 0.6);
	colour = mix(colour, dust_colour * mix(0.8, 1.05, mottle), up * 0.45);
	// Ice: a glassy coat in patches from a few metres in, all over at the back.
	float frozen = ice * smoothstep(0.45, 0.6, noise3(world_pos * 0.7) * 0.6 + depth * 0.8 - 0.35);
	colour = mix(colour, vec3(0.74, 0.8, 0.86) * mix(0.85, 1.05, mottle), frozen);
	ALBEDO = colour;
	ROUGHNESS = mix(1.0, 0.25, frozen);
}
