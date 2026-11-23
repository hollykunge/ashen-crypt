shader_type canvas_item;
// 给整个人物（SubViewport 里拼好的一张，预乘透明度）打光：冷色环境光压暗、降饱和、加对比，
// 火把那一侧沿轮廓加一圈暖色边光。边光按「往光源方向挪几个像素就出了人物」判断，不需要法线。
uniform vec3 ambient = vec3(0.70, 0.71, 0.82);
uniform vec2 light_dir = vec2(-1.0, -0.5);
uniform vec3 light_color = vec3(1.0, 0.58, 0.26);
uniform float light_amount = 1.0;
uniform float rim_width = 10.0;
uniform float desaturate = 0.35;
uniform float contrast = 1.18;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec3 col = c.rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturate);
	col = (col - 0.5) * contrast + 0.5;
	// 环境光 + 朝光一侧整体略亮
	vec2 dir = normalize(light_dir);
	vec3 lit = col * ambient;
	float rim = 0.0;
	for (int i = 1; i <= 3; i++) {
		float a = texture(TEXTURE, UV + dir * TEXTURE_PIXEL_SIZE * rim_width * float(i) / 3.0).a;
		rim += (1.0 - a) / 3.0;
	}
	rim = smoothstep(0.15, 0.9, rim);
	lit += col * light_color * light_amount * (0.22 + 1.3 * rim);
	COLOR = vec4(clamp(lit, 0.0, 1.0), c.a);
}
