shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Cave walls, floors and portals (scripts/caves.gd): rock in world space, as
// in shaders/mars_rock.gdshader, with a bumpy surface (pits, cracks, ropy
// lava underfoot in the tube), dust settled on what faces up, darker
// crevices, the canyon's layers in the canyon cave, pale mineral crusts
// further in, and ice in the ice cave. Drawn from both sides (the tunnels
// are seen from inside and out).

uniform vec3 rock_colour : source_color = vec3(0.34, 0.2, 0.14);
uniform vec3 dust_colour : source_color = vec3(0.6, 0.37, 0.24);
uniform vec3 crust_colour : source_color = vec3(0.78, 0.72, 0.6);   // sulfate and opal crusts
uniform float strata = 0.0;   // the canyon cave: the canyon's layers from inside
uniform float ice = 0.0;      // the ice cave
uniform float bump = 0.14;    // metres of surface relief

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

// Cracks: thin dark lines where a noise crosses its middle value.
float cracks(vec3 p) {
	float n = noise3(p) - 0.5;
	return 1.0 - smoothstep(0.0, 0.035, abs(n));
}

void fragment() {
	vec3 n = FRONT_FACING ? world_normal : -world_normal;
	float up = smoothstep(0.55, 0.92, n.y);
	// The surface's relief: lumps at three scales, pits, cracks; ropy folds
	// on the tube's floor; ledges in the canyon cave.
	float lumps = noise3(world_pos * 1.6) * 0.45 + noise3(world_pos * 4.3) * 0.3 + noise3(world_pos * 11.0) * 0.25;
	float pits = smoothstep(0.74, 0.86, noise3(world_pos * 6.0 + 13.0));
	float crack = cracks(world_pos * 0.9 + 4.0) * (1.0 - up * 0.6);
	float ropes = sin(world_pos.x * 4.0 + world_pos.z * 2.3 + noise3(world_pos * 0.8) * 7.0) * 0.5 + 0.5;
	ropes *= up * (1.0 - strata) * (1.0 - ice);
	float band = sin(world_pos.y * 4.4 + noise3(world_pos * 0.25) * 4.0);
	float h = lumps - pits * 0.5 - crack * 0.6 + ropes * 0.6 + strata * smoothstep(-0.3, 0.3, band) * 0.5;
	h *= mix(1.0, 0.35, ice * depth);   // ice smooths it over
	// Bump mapping from the relief's screen-space slope.
	float hb = h * bump;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(hb) * r1 + dFdy(hb) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);

	float mottle = noise3(world_pos * 1.1) * 0.6 + noise3(world_pos * 4.2) * 0.4;
	vec3 colour = rock_colour * mix(0.68, 1.18, mottle);
	// Hollows, pits and cracks hold shadow.
	colour *= mix(0.6, 1.08, smoothstep(0.15, 0.75, lumps)) * mix(1.0, 0.7, pits) * mix(1.0, 0.45, crack);
	// Layers: pale and dark bands.
	colour *= 1.0 + strata * 0.18 * band;
	colour = mix(colour, rock_colour * vec3(1.55, 1.35, 1.15), strata * smoothstep(0.55, 0.95, band) * 0.5);
	// Old flow lines on a lava tube's walls.
	float wall = 1.0 - smoothstep(0.3, 0.7, abs(n.y));
	colour *= 1.0 - (1.0 - strata) * (1.0 - ice) * wall * 0.12 * smoothstep(0.6, 1.0, sin(world_pos.y * 9.0 + noise3(world_pos * 0.5) * 3.0));
	// Floors: dust in the low parts, ropes dark in their troughs.
	colour = mix(colour, colour * 0.8, ropes * 0.5);
	colour = mix(colour, dust_colour * mix(0.75, 1.05, mottle), up * (0.3 + 0.35 * (1.0 - lumps)));
	// Mineral crusts on the walls and roof, in patches, more further in.
	float crust = (1.0 - ice) * (1.0 - up) * smoothstep(0.8, 0.88, noise3(world_pos * 2.2 + 31.0) * 0.7 + noise3(world_pos * 0.4) * 0.3 + depth * 0.15);
	crust *= smoothstep(0.35, 0.7, lumps);   // on the raised bits, broken up
	colour = mix(colour, crust_colour * mix(0.75, 1.0, mottle), crust * 0.4);
	// Ice: a glassy coat in patches from a few metres in, all over at the back.
	float frozen = ice * smoothstep(0.35, 0.75, noise3(world_pos * 0.7) * 0.6 + depth * 0.8 - 0.35);
	// Dirty ice: grey-blue, the rock showing through where it is thin.
	vec3 ice_colour = vec3(0.5, 0.55, 0.6) * mix(0.75, 1.05, mottle) * mix(0.8, 1.0, smoothstep(0.2, 0.7, lumps));
	colour = mix(colour, ice_colour, frozen * mix(0.65, 0.92, noise3(world_pos * 2.6 + 7.0)));
	ALBEDO = colour;
	ROUGHNESS = mix(mix(1.0, 0.82, (1.0 - strata) * wall * 0.4), 0.38, frozen);
}
