// 主角描边（屏幕空间）：在主角画布上沿人物轮廓描一圈粗墨线（近黑的深蓝，街机格斗那种粗描边），一次绘制。
// 取代原来每个部件一份外扩背面的描边（model_outline.gdshader），后者在战斗里每帧要多一百来次绘制。
// 只描外轮廓；手臂压在身体前面这类内部的线靠卡通明暗分开。
shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.09, 1.0);
uniform float width = 2.0;   // 描边宽度基数，画布像素（主角画布按人物大小给）
const float THICK = 1.9;     // 粗描边：在基数上再加粗

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width * THICK;
	float near_a = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;  // 30°
		vec2 d = vec2(cos(a), sin(a)) * px;
		near_a = max(near_a, texture(TEXTURE, UV + d).a);
		near_a = max(near_a, texture(TEXTURE, UV + d * 0.66).a);
		near_a = max(near_a, texture(TEXTURE, UV + d * 0.33).a);
	}
	// 人物内部保持原色；人物外、但贴着人物的一圈画成墨色
	float edge = clamp(near_a - c.a, 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, ink.rgb, edge * (1.0 - c.a)), max(c.a, edge * ink.a));
}
