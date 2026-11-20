shader_type canvas_item;

// 战场最上面的一层天光：读回已经画好的画面，白天不动，黄昏偏暖，入夜压暗发蓝。
// 亮处（火星、打击光、法术）不跟着暗；主角身边留一圈暖光，夜里人还看得清。
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float warm = 0.0;
uniform float night = 0.0;
// 主角身边那圈光：中心是本层 UV，半径按本层高度算，aspect 是宽高比。
uniform vec2 lamp = vec2(0.5, 0.7);
uniform float lamp_radius = 0.2;
uniform float aspect = 1.0;

void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float glow = smoothstep(0.72, 0.97, max(color.r, max(color.g, color.b)));
	vec2 offset = (UV - lamp) * vec2(aspect, 1.0);
	float lit = 1.0 - smoothstep(0.0, lamp_radius, length(offset));
	lit *= lit;
	vec3 dusk = color * vec3(1.07, 0.88, 0.72) + vec3(0.06, 0.025, 0.0) * (1.0 - UV.y);
	vec3 dark = mix(vec3(luma), color, 0.55) * vec3(0.34, 0.42, 0.66);
	vec3 graded = mix(color, dusk, warm * (1.0 - glow * 0.5));
	graded = mix(graded, dark, night * (1.0 - glow * 0.8) * (1.0 - lit * 0.7));
	graded += vec3(1.0, 0.62, 0.30) * lit * night * 0.05;
	COLOR = vec4(graded, 1.0);
}
