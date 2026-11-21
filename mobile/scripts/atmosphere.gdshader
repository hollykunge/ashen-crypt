shader_type canvas_item;

// 战场最上面的一层天光：读回已经画好的画面。
// 先做常开的暗黑调色：压饱和、压暗部、拉对比，阴影偏冷灰、亮部偏旧黄，红色（血、朱穗）和火光保留饱和；
// 四角压暗把视线收向中间。再叠天色：黄昏偏暖，入夜压暗发蓝。
// 亮处（火星、打击光、法术）不跟着暗；主角身边留一圈暖光，夜里人还看得清。
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float grade = 1.0;
uniform float vignette = 0.6;
uniform float warm = 0.0;
uniform float night = 0.0;
// 主角身边那圈光：中心是本层 UV，半径按本层高度算，aspect 是宽高比。
uniform vec2 lamp = vec2(0.5, 0.7);
uniform float lamp_radius = 0.2;
uniform float aspect = 1.0;

vec3 gothic(vec3 color, float glow) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	// 真正的朱红（血、布穗、火）留住颜色；土黄、木色这类暖褐不算，一并去掉大半饱和。
	float red = smoothstep(0.30, 0.55, (color.r - max(color.g, color.b)) / max(color.r, 0.001));
	float keep = mix(0.30, 1.0, max(red, glow));
	vec3 graded = mix(vec3(luma), color, keep);
	// 对比：中灰往两头推，暗部压实但不死黑。
	graded = clamp((graded - 0.42) * 1.25 + 0.34, 0.0, 1.0);
	graded = mix(graded, graded * graded * 1.6, 0.30);
	// 分离色调：阴影冷灰青，亮部旧骨黄；整体再压一档曝光。
	float tone = smoothstep(0.12, 0.75, luma);
	graded *= mix(vec3(0.74, 0.82, 0.88), vec3(1.0, 0.95, 0.86), tone) * 0.9;
	return mix(graded, color * 1.05, glow * 0.6);
}

void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb;
	float glow = smoothstep(0.72, 0.97, max(color.r, max(color.g, color.b)));
	color = mix(color, gothic(color, glow), grade);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec2 offset = (UV - lamp) * vec2(aspect, 1.0);
	float lit = 1.0 - smoothstep(0.0, lamp_radius, length(offset));
	lit *= lit;
	vec3 dusk = color * vec3(1.07, 0.88, 0.72) + vec3(0.06, 0.025, 0.0) * (1.0 - UV.y);
	vec3 dark = mix(vec3(luma), color, 0.55) * vec3(0.34, 0.42, 0.66);
	vec3 graded = mix(color, dusk, warm * (1.0 - glow * 0.5));
	graded = mix(graded, dark, night * (1.0 - glow * 0.8) * (1.0 - lit * 0.7));
	graded += vec3(1.0, 0.62, 0.30) * lit * night * 0.05;
	// 四角压暗：按画面比例算成椭圆，中间一大片不动。
	vec2 centered = (UV - vec2(0.5, 0.46)) * vec2(aspect, 1.0) / max(aspect, 1.0);
	float edge = smoothstep(0.32, 0.92, length(centered) * 1.35);
	graded *= 1.0 - vignette * edge * (1.0 - glow * 0.5);
	COLOR = vec4(graded, 1.0);
}
