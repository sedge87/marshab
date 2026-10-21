shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Scattered boulders: the site's ground colour, darker, with world-space
// mottling, pits and a dusty top, so rocks sit in the scene instead of
// reading as flat grey shapes. Matches shaders/mars_ground.gdshader.

uniform vec3 rock_colour : source_color = vec3(0.45, 0.24, 0.16);
uniform vec3 dust_colour : source_color = vec3(0.72, 0.42, 0.27);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	float mottle = noise3(world_pos * 1.4) * 0.6 + noise3(world_pos * 5.0) * 0.4;
	vec3 colour = rock_colour * mix(0.75, 1.15, mottle);
	// Small dark pits.
	colour *= mix(1.0, 0.7, smoothstep(0.78, 0.86, noise3(world_pos * 9.0)));
	// Dust settles on upward faces.
	colour = mix(colour, dust_colour, smoothstep(0.55, 0.95, world_normal.y) * 0.55);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
