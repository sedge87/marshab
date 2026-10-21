shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

// Subsurface ice survey for the site plan: a smooth richness field from the
// site's deposits, with survey contour lines. The bright line is the edge of
// drillable ice (12%). Matches BuildController._ice_richness_at_point.
uniform vec4 deposits[8];          // x, z, radius, richness
uniform int deposit_count = 0;
uniform float usable = 0.12;
uniform vec3 rich_colour : source_color = vec3(0.04, 0.20, 0.70);
uniform vec3 trace_colour : source_color = vec3(0.30, 0.72, 0.95);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float richness_at(vec2 p) {
	float strongest = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= deposit_count) break;
		vec4 d = deposits[i];
		float falloff = clamp(1.0 - distance(p, d.xy) / max(1.0, d.z), 0.0, 1.0);
		strongest = max(strongest, d.w * falloff);
	}
	return strongest;
}

float contour(float value, float level, float width) {
	float w = fwidth(value) * width;
	return 1.0 - smoothstep(0.0, w, abs(value - level));
}

void fragment() {
	float r = richness_at(world_xz);
	// Fill: nothing on dry ground, a pale trace ring, then deepening blue.
	float t = clamp((r - usable) / 0.3, 0.0, 1.0);
	vec3 colour = mix(trace_colour, rich_colour, t);
	float alpha = r < 0.02 ? 0.0 : (r < usable ? 0.04 + 0.08 * (r / usable) : 0.40 + 0.35 * t);
	// Contours every 8% above the usable edge, and a bright usable edge.
	float lines = 0.0;
	for (int i = 1; i < 6; i++) lines = max(lines, contour(r, usable + float(i) * 0.08, 1.2) * 0.45);
	float edge = contour(r, usable, 2.2);
	colour = mix(colour, vec3(0.85, 0.97, 1.0), max(lines, edge));
	alpha = max(alpha, max(lines * 0.55, edge * 0.9));
	ALBEDO = colour;
	ALPHA = alpha;
}
