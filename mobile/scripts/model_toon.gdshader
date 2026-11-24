// 3D 角色卡通着色：烘好的底色贴图 + 三阶明暗，接近 Blender 出图的 V4 画风（gen-out/model/scripts/style_lib.py）。
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
// 头发、眉毛：贴图是灰白的，在这里换成深棕（与 style_lib 的 HAIR 一致）
uniform float hair = 0.0;
uniform vec4 hair_color : source_color = vec4(0.18, 0.125, 0.094, 1.0);
// 暗部往暖土色偏一点，别发灰
uniform vec4 shade_color : source_color = vec4(0.62, 0.52, 0.47, 1.0);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, hair_color.rgb * (0.55 + 0.9 * lum), hair);
	ALBEDO = c * tint.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float step3 = ndl > 0.30 ? 1.0 : (ndl > -0.10 ? 0.66 : 0.42);
	vec3 band = mix(shade_color.rgb, vec3(1.0), step3);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band * step3 / PI;
}
