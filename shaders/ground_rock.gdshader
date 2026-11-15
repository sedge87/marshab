shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Rocks that belong to the ground they sit on (B5 step 7, docs/terrain-design.md
// §13): MHPalette's "ground_rock" role. Built on shaders/mars_rock.gdshader:
// world-space mottling and pits (3D noise in world space reads the same on
// every face, as triplanar does, so nothing streaks on steep sides; the lesson
// of e9aea1c), dust settled on upward faces, and the foot of the rock blended
// into the ground colour where windblown dust and soil bank up against it.
// The foot is measured from the rock's own origin (rocks are placed with their
// origin on the ground: the region's scatter, scripts/tools/rock_path.gd), so
// it needs no terrain lookup in the shader.

uniform vec3 rock_colour : source_color = vec3(0.45, 0.24, 0.16);
uniform vec3 dust_colour : source_color = vec3(0.72, 0.42, 0.27);
uniform vec3 ground_colour : source_color = vec3(0.66, 0.38, 0.24);
uniform float foot_height = 0.25;   // metres of banked dust at the foot, for a rock of 1 m
uniform float frost_cover = 0.0;    // dawn frost (scripts/site_weather.gd)

varying vec3 world_pos;
varying vec3 world_normal;
varying float base_y;
varying float rock_scale;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	base_y = MODEL_MATRIX[3].y;
	rock_scale = length(MODEL_MATRIX[1].xyz);
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
	// Thin hard layers in the rock, level across every face.
	colour *= mix(0.94, 1.04, smoothstep(0.3, 0.7, sin(world_pos.y * 9.0 + noise3(world_pos * 0.7) * 3.0) * 0.5 + 0.5));
	// Small dark pits.
	colour *= mix(1.0, 0.82, smoothstep(0.8, 0.88, noise3(world_pos * 9.0)));
	// Dust settles on upward faces.
	colour = mix(colour, dust_colour, smoothstep(0.55, 0.95, world_normal.y) * 0.55);
	// The foot: ground-coloured dust banked against it, ragged at its top edge.
	float above = world_pos.y - base_y;
	float foot = foot_height * max(rock_scale, 0.2) * (0.7 + 0.6 * noise3(world_pos * 3.0));
	colour = mix(colour, ground_colour, (1.0 - smoothstep(foot * 0.4, foot, above)) * 0.85);
	// Frost on the shaded sides and tops at dawn.
	colour = mix(colour, vec3(0.84, 0.88, 0.92), frost_cover * smoothstep(0.1, 0.6, world_normal.y - world_normal.x * 0.5) * 0.45);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
