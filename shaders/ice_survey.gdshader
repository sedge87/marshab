shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

// The site plan's ice overlay: only what the colony knows (scripts/ice_knowledge.gd).
// Entries are x, z, radius, richness. Richness -1 is a likely zone from orbit:
// a faint, hatched wash (an estimate, not a measurement). Anything else is a
// spot GAR-Y surveyed: a crisp disc showing the ice it measured there, dusty
// where it found none worth drilling, deepening blue the richer it is.
uniform vec4 deposits[48];
uniform int deposit_count = 0;
uniform float usable = 0.12;
uniform vec3 rich_colour : source_color = vec3(0.04, 0.20, 0.70);
uniform vec3 trace_colour : source_color = vec3(0.30, 0.72, 0.95);
uniform vec3 dry_colour : source_color = vec3(0.55, 0.42, 0.34);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = world_xz;
	float likely = 0.0;
	float measured = -1.0;
	float rim = 0.0;
	for (int i = 0; i < 48; i++) {
		if (i >= deposit_count) break;
		vec4 d = deposits[i];
		float dist = distance(p, d.xy);
		if (d.w < 0.0) {
			likely = max(likely, 1.0 - smoothstep(d.z * 0.35, d.z, dist));
		} else if (dist < d.z) {
			measured = max(measured, d.w);
			rim = max(rim, smoothstep(d.z - 0.35, d.z, dist));
		}
	}
	vec3 colour;
	float alpha;
	if (measured >= 0.0) {
		float t = clamp((measured - usable) / 0.3, 0.0, 1.0);
		colour = measured < usable ? dry_colour : mix(trace_colour, rich_colour, t);
		alpha = measured < usable ? 0.38 : 0.5 + 0.3 * t;
		colour = mix(colour, vec3(0.9, 0.97, 1.0), rim);
		alpha = max(alpha, rim * 0.9);
	} else {
		// Diagonal hatching: this is a guess from orbit.
		float hatch = step(0.5, fract((p.x + p.y) * 0.35));
		colour = trace_colour;
		alpha = likely * mix(0.14, 0.32, hatch);
	}
	ALBEDO = colour;
	ALPHA = alpha;
}
