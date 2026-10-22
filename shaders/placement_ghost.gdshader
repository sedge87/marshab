shader_type spatial;
// The placement hologram: a faint fill so you can see what's behind and under
// it, with a brighter rim that keeps the item's shape readable.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 tint : source_color = vec4(0.34, 0.96, 0.70, 1.0);
uniform float fill = 0.07;
uniform float rim = 0.6;

void fragment() {
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	// Slow scan lines, faint, so the fill reads as a hologram rather than glass.
	float scan = 0.5 + 0.5 * sin((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y * 34.0 - TIME * 2.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(fill + rim * edge + 0.035 * scan, 0.0, 0.8);
}
