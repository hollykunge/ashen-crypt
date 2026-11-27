shader_type canvas_item;
// 透明底的离屏画布画出来是「预乘」的：半透明边上的颜色已经乘过一次透明度。
// 直接贴到战场上会再乘一次，边缘发黑发脏（细的剑几乎全是边，整把变成灰黑）。
// 这块盖在画布最上面，把画好的内容读回来、除掉透明度再原样写回（不混合），画布输出就是正常的直通透明度。
render_mode blend_disabled;
uniform sampler2D screen : hint_screen_texture, filter_nearest;

uniform bool puppet_light = false;
void fragment() {
	vec4 c = textureLod(screen, SCREEN_UV, 0.0);
	vec3 pigment = c.rgb / max(c.a, 0.002);
	if (puppet_light && c.a > 0.002) {
		float adjacent = textureLod(screen, SCREEN_UV - SCREEN_PIXEL_SIZE, 0.0).a;
		float rim = clamp(c.a - adjacent, 0.0, 1.0);
		pigment = min(vec3(1.0), pigment * vec3(1.23, 1.18, 1.08) + vec3(0.70, 0.41, 0.14) * rim * 0.53);
	}
	COLOR = c.a > 0.002 ? vec4(pigment, c.a) : vec4(0.0);
}
