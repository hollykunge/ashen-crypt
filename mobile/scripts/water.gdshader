shader_type canvas_item;

// 石路前那片水面，画在长卷之上、人物之下：读回刚画好的长卷，把水线以上倒过来、晃一晃、往水色里压，
// 越往下越淡。人物、精怪和地上的预警圈都画在它上面，站进水里也看得清。
uniform sampler2D screen : hint_screen_texture, filter_linear;
// 水线是本层的 UV 纵坐标（0 在上，1 在下）。
uniform float water_line = 1.0;
uniform float water = 0.0;
uniform vec4 water_tint : source_color = vec4(0.24, 0.32, 0.34, 1.0);

void fragment() {
	// 本层 UV 和屏幕 UV 之间是同一个比例，取导数就不用管视口拉伸和摆放位置。导数要在分支外取。
	float to_screen = dFdy(SCREEN_UV.y) / max(abs(dFdy(UV.y)), 1e-6) * sign(dFdy(UV.y));
	// 岸线不是一条直线，沿横向起伏一点。
	float shore = water_line + 0.006 * sin(UV.x * 23.0) + 0.004 * sin(UV.x * 61.0 + 1.3);
	float below = UV.y - shore;
	if (below <= 0.0) {
		discard;
	}
	float wave = sin(below * 240.0 - TIME * 2.2 + sin(UV.x * 7.0 + TIME * 0.6) * 1.6);
	float smear = (0.0018 + below * 0.022) * wave;
	vec2 mirror = vec2(SCREEN_UV.x + smear, SCREEN_UV.y - 2.0 * below * to_screen);
	float spread = 0.0015 + below * 0.01;
	vec3 image = texture(screen, mirror).rgb * 0.5
		+ texture(screen, mirror + vec2(spread, 0.0)).rgb * 0.25
		+ texture(screen, mirror - vec2(spread, 0.0)).rgb * 0.25;
	float fade = exp(-below * 5.0);
	image = mix(image, water_tint.rgb, 0.28 + 0.42 * (1.0 - fade));
	// 水面上一道道横向的亮纹，随波起落。
	image += vec3(smoothstep(0.86, 1.0, wave) * fade * 0.09);
	float bank = smoothstep(0.0, 0.012, below);
	COLOR = vec4(image, water * bank);
}
