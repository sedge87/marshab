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
uniform int style = 0;                  // 0 = dusty ground, 1 = ice fields, 2 = realistic plains
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

// ---------- realistic Open Plains (style 2, 24 Oct) ----------
// Modelled on rover photos of Mars plains: butterscotch dust, patches of dark
// basaltic sand with ripples, cracked pale bedrock showing through, pebbles
// that catch the light. Small bumps tilt the lighting (not just the colour),
// so the ground has texture up close, and fade with distance so nothing
// shimmers far away.

vec2 cells(vec2 p) {
	vec2 cell = floor(p);
	float nearest = 1e9;
	float second = 1e9;
	for (int dx = -1; dx <= 1; dx++) {
		for (int dz = -1; dz <= 1; dz++) {
			vec2 c = cell + vec2(float(dx), float(dz));
			vec2 o = vec2(hash(c + 1.7), hash(c + 9.2));
			float d = distance(p, c + o);
			if (d < nearest) { second = nearest; nearest = d; }
			else if (d < second) { second = d; }
		}
	}
	return vec2(nearest, second - nearest);
}

float sand_mask(vec2 p) {
	return smoothstep(0.5, 0.66, fbm(p * 0.016 + vec2(3.0, 11.0)));
}

float bedrock_mask(vec2 p) {
	return smoothstep(0.58, 0.7, fbm(p * 0.03 + vec2(17.0, 5.0)));
}

// Small-scale height (metres) for the lighting: grit and sand ripples.
float plains_bumps(vec2 p, float sand) {
	float h = (value_noise(p * 5.0) - 0.5) * 0.014;
	// (Pebbles are real 3D stones: site_terrain.gd pebble_transforms.)
	// Ripples in the sand: crests about 0.5 m apart, bending with the wind.
	float phase = dot(p, wind) * 12.0 + fbm(p * 0.4) * 9.0;
	h += sand * 0.02 * pow(sin(phase) * 0.5 + 0.5, 2.0);
	return h;
}

void plains_ground(inout vec3 colour, inout vec3 normal_out, vec2 p, float near, float flatness, float steep, mat4 view) {
	// Detail only up close: beyond ~20 m it would shimmer into rings.
	float dist = near;
	near = 1.0 - smoothstep(4.0, 20.0, near);
	float sand = sand_mask(p) * flatness;
	float rock = bedrock_mask(p) * (1.0 - sand) * flatness;
	// Colour zones: dust (the vertex colour), dark sand, pale cracked bedrock.
	vec3 sand_colour = vec3(0.33, 0.24, 0.2) * mix(0.9, 1.1, value_noise(p * 0.7));
	colour = mix(colour, sand_colour, sand * 0.75);
	vec3 rock_colour = mix(vec3(0.62, 0.5, 0.41), vec3(0.55, 0.43, 0.35), value_noise(p * 0.3));
	// Fine cracks, only on bedrock up close (the costly part, skipped elsewhere).
	if (rock > 0.01 && dist < 25.0) {
		vec2 plates = cells(p * 1.6 + vec2(value_noise(p * 0.8), value_noise(p * 0.8 + 5.0)) * 0.8);
		rock_colour *= 1.0 - 0.2 * (1.0 - smoothstep(0.015, 0.05, plates.y)) * (1.0 - smoothstep(6.0, 25.0, dist));
	}
	colour = mix(colour, rock_colour, rock * 0.8);
	// Pebbles slightly darker and greyer than the dust round them.
	if (near > 0.0) {
		vec2 cell = floor(p * 1.7);
		vec2 local = fract(p * 1.7);
		vec2 centre = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
		float radius = mix(0.06, 0.2, hash(cell + 11.3));
		float stone = step(0.88 + sand * 0.1, hash(cell + 17.0)) * (1.0 - smoothstep(radius * 0.5, radius, length(local - centre)));
		colour = mix(colour, colour * vec3(0.94, 0.92, 0.94), stone * near * 0.4);
	}
	// Bumps tilt the lighting up close (not computed further away).
	if (near > 0.0) {
		float e = 0.04;
		float h0 = plains_bumps(p, sand);
		float hx = plains_bumps(p + vec2(e, 0.0), sand);
		float hz = plains_bumps(p + vec2(0.0, e), sand);
		vec3 bumped = normalize(vec3(-(hx - h0) / e, 1.0, -(hz - h0) / e));
		vec3 world_n = normalize(mix(world_normal, normalize(world_normal + vec3(bumped.x, 0.0, bumped.z) * 1.6), near * (1.0 - steep)));
		normal_out = normalize((view * vec4(world_n, 0.0)).xyz);
	}
	// Broad light and dark drifts of dust.
	colour *= mix(0.88, 1.1, fbm(p * 0.05 + 40.0));
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

	if (style == 2) {
		vec3 n = NORMAL;
		plains_ground(colour, n, p, length(VERTEX), flatness, steep, VIEW_MATRIX);
		NORMAL = n;
	} else if (style == 1) {
		ice_ground(colour, p, near, flatness);
	} else {
		// Dust ripples: wavy crests about 0.7 m apart, only on level ground.
		float phase = dot(p, wind) * 9.0 + fbm(p * 0.6) * 6.0;
		float crest = pow(sin(phase) * 0.5 + 0.5, 3.0);
		colour *= 1.0 - 0.12 * crest * flatness * near;
	}

	// Fine grit: smooth noise, no hard pixels.
	if (style != 2) {
		float grit = value_noise(p * 9.0) * 0.6 + value_noise(p * 23.0) * 0.4;
		colour *= mix(1.0, mix(0.9, 1.07, grit), near);
	} else {
		float grit = value_noise(p * 4.0);
		colour *= mix(1.0, mix(0.94, 1.05, grit), 1.0 - smoothstep(3.0, 16.0, length(VERTEX)));
	}

	if (style != 2) {
		// Pebbles: about one in six 0.8 m cells holds a small round stone.
		vec2 cell = floor(p * 1.25);
		vec2 local = fract(p * 1.25);
		vec2 centre = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
		float radius = mix(0.05, 0.14, hash(cell + 11.3));
		float stone = step(style == 1 ? 0.95 : 0.84, hash(cell + 17.0)) * (1.0 - smoothstep(radius * 0.65, radius, length(local - centre)));
		colour = mix(colour, colour * 0.58, stone * near * 0.85);
	}

	// Steep faces: darker rock in wavy horizontal layers.
	if (style == 2) {
		// Broad layers of greyer rock in the mesa cliffs.
		float layers = sin(world_pos.y * 1.3 + fbm(p * 0.06) * 2.5) * 0.5 + 0.5;
		vec3 cliff = mix(vec3(0.42, 0.33, 0.28), vec3(0.58, 0.46, 0.38), layers);
		colour = mix(colour, cliff * mix(0.85, 1.1, fbm(world_pos.xy * 0.4 + world_pos.zy * 0.4)), steep * 0.85);
	} else {
		float strata = sin(world_pos.y * 5.0 + fbm(p * 0.3) * 3.0) * 0.5 + 0.5;
		colour = mix(colour, colour * mix(0.68, 0.88, strata), steep);
	}

	ALBEDO = colour;
	// Ice catches a faint sheen; dust doesn't.
	ROUGHNESS = style == 1 ? 0.7 : 1.0;
	SPECULAR = style == 1 ? 0.25 : 0.0;
}
