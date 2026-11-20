shader_type canvas_item;

// 雪道远景的空气透视：地面线以上逐渐褪色、压低反差、蒙一层雪雾，
// 前景石路保持原样，深色的人物和精怪因此从背景里跳出来。
uniform float floor_line = 0.79;
uniform vec4 haze_color : source_color = vec4(0.80, 0.85, 0.89, 1.0);
uniform float haze = 0.24;
uniform float flatten = 0.16;
uniform float desaturate = 0.24;

void fragment() {
	// 进 fragment 时 COLOR 已经乘过贴图和 modulate。
	vec4 art = COLOR;
	float far = 1.0 - smoothstep(floor_line - 0.32, floor_line - 0.03, UV.y);
	vec3 color = art.rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(color, vec3(luma), desaturate);
	muted = mix(muted, vec3(0.62), flatten);
	muted = mix(muted, haze_color.rgb, haze);
	COLOR = vec4(mix(color, muted, far), art.a);
}
