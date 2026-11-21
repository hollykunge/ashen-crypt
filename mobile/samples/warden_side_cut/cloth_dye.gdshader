shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D pose_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D pieces : filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_cell;
uniform vec4 body_dye : source_color;
uniform vec4 near_sleeve_dye : source_color;
uniform vec4 far_sleeve_dye : source_color;

void fragment() {
	vec4 base = texture(pose_texture, UV);
	vec2 cell_size = vec2(448.0, 512.0);
	vec2 pixel = UV * vec2(textureSize(pose_texture, 0)) - vec2(400.0, 325.0);
	vec2 mask_uv = (atlas_cell * cell_size + pixel) / vec2(textureSize(pieces, 0));
	vec3 masks = texture(pieces, mask_uv).rgb;
	if (any(lessThan(pixel, vec2(0.0))) || any(greaterThanEqual(pixel, cell_size))) {
		masks = vec3(0.0);
	}
	float coverage = min(dot(masks, vec3(1.0)), 1.0);
	float value = dot(base.rgb, vec3(0.30, 0.59, 0.11));
	float reference = OUTPUT_IS_SRGB ? 0.205 : 0.0347;
	vec3 dye = masks.r * body_dye.rgb + masks.g * near_sleeve_dye.rgb + masks.b * far_sleeve_dye.rgb;
	ALBEDO = base.rgb * (1.0 - coverage) + dye * value / reference;
	ALPHA = base.a;
}
