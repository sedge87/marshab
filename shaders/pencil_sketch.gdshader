shader_type canvas_item;

// A journal sketch (docs/samples-lab-journal.md §7): the saved snapshot of
// the view drawn as pencil on paper. Edges from the picture's light and
// dark (Sobel), hatching where it's dark (one direction, then a second
// across it in the shadows), and the paper's grain.

uniform vec4 paper : source_color = vec4(0.93, 0.9, 0.84, 1.0);
uniform vec4 lead : source_color = vec4(0.22, 0.21, 0.2, 1.0);
uniform float hatch_scale = 110.0;

float lum(sampler2D tex, vec2 uv) {
	return dot(texture(tex, uv).rgb, vec3(0.3, 0.59, 0.11));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 1.4;
	float tl = lum(TEXTURE, UV + px * vec2(-1, -1)), t = lum(TEXTURE, UV + px * vec2(0, -1)), tr = lum(TEXTURE, UV + px * vec2(1, -1));
	float l = lum(TEXTURE, UV + px * vec2(-1, 0)), r = lum(TEXTURE, UV + px * vec2(1, 0));
	float bl = lum(TEXTURE, UV + px * vec2(-1, 1)), b = lum(TEXTURE, UV + px * vec2(0, 1)), br = lum(TEXTURE, UV + px * vec2(1, 1));
	float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
	float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	float edge = smoothstep(0.08, 0.35, length(vec2(gx, gy)));
	// Tone, pushed apart so the sketch reads (Mars views are mid-grey).
	float tone = smoothstep(0.05, 0.75, lum(TEXTURE, UV));
	vec2 aspect = vec2(TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x, 1.0);
	vec2 p = UV * aspect * hatch_scale;
	float wobble = hash(floor(p * 0.25)) * 0.3;
	float one = step(0.55 + wobble * 0.2, fract(p.x + p.y));
	float two = step(0.6, fract(p.x - p.y + 0.5));
	float hatch = (1.0 - one) * (1.0 - smoothstep(0.35, 0.6, tone)) * 0.55
		+ (1.0 - two) * (1.0 - smoothstep(0.1, 0.35, tone)) * 0.5;
	float grain = hash(UV * 900.0) * 0.06;
	float ink = clamp(edge * 0.9 + hatch, 0.0, 1.0);
	// Pencil fades towards the edges of the sketch, as if drawn freehand.
	vec2 c = abs(UV - 0.5) * 2.0;
	ink *= 1.0 - smoothstep(0.75, 1.0, max(c.x, c.y)) * 0.85;
	COLOR = vec4(mix(paper.rgb - grain, lead.rgb, ink), 1.0);
}
