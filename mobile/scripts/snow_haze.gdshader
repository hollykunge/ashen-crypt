shader_type canvas_item;

// 雪道远景的空气透视：地面线以上逐渐褪色、压低反差、蒙一层雪雾，
// 前景石路保持原样，深色的人物和精怪因此从背景里跳出来。
uniform float floor_line = 0.79;
uniform vec4 haze_color : source_color = vec4(0.80, 0.85, 0.89, 1.0);
uniform float haze = 0.24;
uniform float flatten = 0.16;
uniform float desaturate = 0.24;
// The scenic cloth already contains the painted moonlit colours.
uniform float screen = 0.0;
void fragment() {
	vec4 art = COLOR;
	float far = 1.0 - smoothstep(floor_line - 0.32, floor_line - 0.03, UV.y);
	float luma = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(mix(art.rgb, vec3(luma), desaturate), haze_color.rgb, haze);
	vec3 base = mix(art.rgb, muted, far * flatten);
	float edge = smoothstep(0.26, 0.73, distance(SCREEN_UV, vec2(0.50, 0.44)));
	COLOR = vec4(base * (1.0 - screen * 0.23 * edge), art.a);
}
