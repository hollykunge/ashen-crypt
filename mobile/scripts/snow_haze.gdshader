shader_type canvas_item;

// 雪道远景的空气透视：地面线以上逐渐褪色、压低反差、蒙一层雪雾，
// 前景石路保持原样，深色的人物和精怪因此从背景里跳出来。
uniform float floor_line = 0.79;
uniform vec4 haze_color : source_color = vec4(0.80, 0.85, 0.89, 1.0);
uniform float haze = 0.24;
uniform float flatten = 0.16;
uniform float desaturate = 0.24;
// 皮影戏幕布（screen 为 1 时）：长卷按明暗换成幕布上的两种颜色，亮处是被灯照透的暖琥珀，
// 暗处（墨线、山石、房屋）是深褐的影子；灯在幕后中间偏上，中间最亮，四边烧暗。
// 按屏幕位置算灯，长卷怎么卷动，亮的始终是画面中间
uniform float screen = 0.0;
uniform vec4 screen_light : source_color = vec4(0.99, 0.80, 0.50, 1.0);
uniform vec4 screen_ink : source_color = vec4(0.30, 0.12, 0.04, 1.0);

void fragment() {
	// 进 fragment 时 COLOR 已经乘过贴图和 modulate。
	vec4 art = COLOR;
	float far = 1.0 - smoothstep(floor_line - 0.32, floor_line - 0.03, UV.y);
	vec3 color = art.rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(color, vec3(luma), desaturate);
	muted = mix(muted, vec3(0.62), flatten);
	muted = mix(muted, haze_color.rgb, haze);
	vec3 base = mix(color, muted, far);
	if (screen > 0.0) {
		float l = dot(base, vec3(0.299, 0.587, 0.114));
		float ink = 1.0 - smoothstep(0.2, 0.86, l);
		vec3 lit = mix(screen_light.rgb, screen_ink.rgb, ink);
		float glow = 1.0 - smoothstep(0.22, 0.95, length((SCREEN_UV - vec2(0.5, 0.40)) * vec2(1.25, 1.0)));
		lit *= mix(0.5, 1.1, glow);
		base = mix(base, lit, screen);
	}
	COLOR = vec4(base, art.a);
}
