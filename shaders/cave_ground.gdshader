shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// The ground laid back over a cave (scripts/caves.gd): Terrain3D's own
// texture arrays, picked and blended by the region's control map and tinted
// by its colour map (both cropped round the caves), projected from above the
// way Terrain3D does, so it matches the ground round it.

uniform highp sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform highp sampler2DArray normal_array : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scales[32];
uniform highp sampler2D control_map : filter_nearest, repeat_disable;   // one texel per ground point
uniform sampler2D colour_map : source_color, filter_linear, repeat_disable;
uniform vec2 corner;     // site position of the crops' first texel
uniform float spacing = 2.0;
uniform vec2 crop_size;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Terrain3D's tangent frame.
	TANGENT = normalize(cross(NORMAL, vec3(0.0, 0.0, 1.0)));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}

void fragment() {
	vec2 g = (world_pos.xz - corner) / spacing;
	ivec2 g0 = ivec2(floor(g));
	vec2 f = fract(g);
	vec3 albedo = vec3(0.0);
	vec4 normal_rough = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		ivec2 o = ivec2(i & 1, i >> 1);
		float w = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
		uint c = floatBitsToUint(texelFetch(control_map, clamp(g0 + o, ivec2(0), ivec2(crop_size) - 1), 0).r);
		uint base = c >> 27u & 31u;
		uint over = c >> 22u & 31u;
		float blend = float(c >> 14u & 255u) / 255.0;
		vec2 uv_base = world_pos.xz * uv_scales[int(base)] * 0.5 + 0.5;
		vec2 uv_over = world_pos.xz * uv_scales[int(over)] * 0.5 + 0.5;
		albedo += mix(texture(albedo_array, vec3(uv_base, float(base))).rgb, texture(albedo_array, vec3(uv_over, float(over))).rgb, blend) * w;
		normal_rough += mix(texture(normal_array, vec3(uv_base, float(base))), texture(normal_array, vec3(uv_over, float(over))), blend) * w;
	}
	vec4 tint = texture(colour_map, (g + 0.5) / crop_size);
	ALBEDO = albedo * tint.rgb;
	float roughness = clamp((tint.a - 0.5) * 2.0 + normal_rough.a, 0.0, 1.0);
	ROUGHNESS = roughness;
	SPECULAR = 1.0 - roughness;   // as Terrain3D
	NORMAL_MAP = normal_rough.rgb;
}
