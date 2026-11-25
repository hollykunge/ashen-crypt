// 3D 角色卡通着色：烘好的底色贴图 + 两阶硬明暗（平涂），暗部偏冷青，受光那侧边缘一道暖色轮廓光（街机格斗的动漫画风）。
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
// 头发、眉毛：贴图是灰白的，在这里换成深棕（与 style_lib 的 HAIR 一致）
uniform float hair = 0.0;
uniform vec4 hair_color : source_color = vec4(0.18, 0.125, 0.094, 1.0);
// 暗部偏冷青（和战场调色的青蓝阴影一致），别发灰
uniform vec4 shade_color : source_color = vec4(0.50, 0.58, 0.74, 1.0);
// 轮廓光：受光那侧边缘一道暖光
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.58, 1.0);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, hair_color.rgb * (0.55 + 0.9 * lum), hair);
	ALBEDO = c * tint.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// 两阶：亮面整片一个色，暗面整片偏冷，交界硬切
	float lit = ndl > 0.12 ? 1.0 : 0.0;
	vec3 band = mix(shade_color.rgb * 0.62, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
	// 轮廓光：掠射角的边缘，只在受光那侧
	float rim = smoothstep(0.62, 0.70, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * step(0.0, ndl);
	DIFFUSE_LIGHT += rim_color.rgb * LIGHT_COLOR * ATTENUATION * rim * 0.55 / PI;
}
