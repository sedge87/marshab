shader_type spatial;
render_mode diffuse_lambert;

// Mars ground (playtest, 21 Oct: "environment textures are bland and blocky").
// Keeps each site's own vertex colouring (strata, frost over ice, polygon
// ground) and adds procedural detail in world space at three scales:
// broad colour drifts, wind-blown dust ripples on flat ground, and fine grit
// and pebbles that fade out with distance. Steep faces get layered rock.
// Cheap value noise only, for school laptops (Compatibility renderer).

uniform float detail_distance = 70.0;   // fine detail fades out by here
uniform vec2 wind = vec2(0.82, 0.57);   // ripple crests run across this
uniform int style = 0;                  // 0 = dusty ground, 1 = ice fields
uniform vec3 frost_colour : source_color = vec3(0.86, 0.90, 0.95);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amplitude * value_noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

// The frozen polygon pattern, exactly as MHSiteTerrain._polygon_edge_distance
// (~9 m cells), so drawn cracks line up with the terrain's real troughs.
// Returns (distance to the nearest crack, a 0-1 shade for this polygon).
vec2 polygons(vec2 p, float size) {
	vec2 cell = floor(p / size);
	float nearest = 1e9;
	float second = 1e9;
	float shade = 0.0;
	for (int dx = -1; dx <= 1; dx++) {
		for (int dz = -1; dz <= 1; dz++) {
			vec2 c = cell + vec2(float(dx), float(dz));
			vec2 jitter = vec2(fract(sin(c.x * 12.99 + c.y * 78.23) * 437.5), fract(sin(c.x * 39.35 + c.y * 11.13) * 921.7));
			float d = distance(p, (c + jitter * 0.8 + vec2(0.1)) * size);
			if (d < nearest) {
				second = nearest;
				nearest = d;
				shade = fract(sin(c.x * 7.13 + c.y * 3.71) * 158.3);
			} else if (d < second) {
				second = d;
			}
		}
	}
	return vec2((second - nearest) * 0.5, shade);
}

void ice_ground(inout vec3 colour, vec2 p, float near, float flatness) {
	// Each frozen polygon its own shade; dark troughs between them, with
	// frost caught along their rims.
	vec2 poly = polygons(p, 9.0);
	colour *= mix(0.94, 1.06, poly.y);
	float trough = 1.0 - smoothstep(0.12, 0.45, poly.x);
	float rim = smoothstep(0.3, 0.55, poly.x) * (1.0 - smoothstep(0.55, 1.2, poly.x));
	colour = mix(colour, colour * vec3(0.62, 0.6, 0.64), trough * 0.85);
	colour = mix(colour, frost_colour, rim * 0.35);
	// Hairline cracks inside each polygon, up close.
	// Warped and patchy, so they read as fractures, not paving.
	vec2 warped = p + vec2(fbm(p * 0.9), fbm(p * 0.9 + 9.0)) * 0.9 + vec2(41.0, 17.0);
	vec2 fine = polygons(warped, 2.3);
	float hairline = (1.0 - smoothstep(0.015, 0.045, fine.x)) * smoothstep(0.4, 0.65, value_noise(p * 0.35));
	colour *= 1.0 - 0.14 * hairline * near;
	// Frost drifts: pale blue-white patches, heavier on level ground.
	float drift = smoothstep(0.48, 0.7, fbm(p * 0.07 + 5.0)) * (0.5 + 0.5 * flatness);
	float sparkle = value_noise(p * 18.0) * near;
	colour = mix(colour, frost_colour, clamp(drift * 0.5 + sparkle * drift * 0.2, 0.0, 0.58));
}

void fragment() {
	vec3 colour = COLOR.rgb;
	vec2 p = world_pos.xz;
	float near = 1.0 - smoothstep(detail_distance * 0.35, detail_distance, length(VERTEX));
	float flatness = smoothstep(0.86, 0.98, world_normal.y);
	float steep = 1.0 - smoothstep(0.55, 0.85, world_normal.y);

	// Broad drifts (tens of metres) and mid patches (a few metres).
	colour *= mix(0.86, 1.12, fbm(p * 0.025));
	colour *= mix(0.93, 1.06, fbm(p * 0.22 + 31.0));

	if (style == 1) {
		ice_ground(colour, p, near, flatness);
	} else {
		// Dust ripples: wavy crests about 0.7 m apart, only on level ground.
		float phase = dot(p, wind) * 9.0 + fbm(p * 0.6) * 6.0;
		float crest = pow(sin(phase) * 0.5 + 0.5, 3.0);
		colour *= 1.0 - 0.12 * crest * flatness * near;
	}

	// Fine grit: smooth noise, no hard pixels.
	float grit = value_noise(p * 9.0) * 0.6 + value_noise(p * 23.0) * 0.4;
	colour *= mix(1.0, mix(0.9, 1.07, grit), near);

	// Pebbles: about one in six 0.8 m cells holds a small round stone.
	vec2 cell = floor(p * 1.25);
	vec2 local = fract(p * 1.25);
	vec2 centre = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
	float radius = mix(0.05, 0.14, hash(cell + 11.3));
	float stone = step(style == 1 ? 0.95 : 0.84, hash(cell + 17.0)) * (1.0 - smoothstep(radius * 0.65, radius, length(local - centre)));
	colour = mix(colour, colour * 0.58, stone * near * 0.85);

	// Steep faces: darker rock in wavy horizontal layers.
	float strata = sin(world_pos.y * 5.0 + fbm(p * 0.3) * 3.0) * 0.5 + 0.5;
	colour = mix(colour, colour * mix(0.68, 0.88, strata), steep);

	ALBEDO = colour;
	// Ice catches a faint sheen; dust doesn't.
	ROUGHNESS = style == 1 ? 0.7 : 1.0;
	SPECULAR = style == 1 ? 0.25 : 0.0;
}
