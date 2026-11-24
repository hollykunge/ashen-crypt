// 主角描边（屏幕空间）：在主角画布上沿人物轮廓描一圈墨线（#3a2c22），一次绘制。
// 取代原来每个部件一份外扩背面的描边（model_outline.gdshader），后者在战斗里每帧要多一百来次绘制。
// 只描外轮廓；手臂压在身体前面这类内部的线靠卡通明暗分开。
shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.227, 0.173, 0.133, 1.0);
uniform float width = 2.0;   // 描边宽度，画布像素

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float near_a = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;  // 30°
		near_a = max(near_a, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px).a);
		near_a = max(near_a, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px * 0.5).a);
	}
	// 人物内部保持原色；人物外、但贴着人物的一圈画成墨色
	float edge = clamp(near_a - c.a, 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, ink.rgb, edge * (1.0 - c.a)), max(c.a, edge * ink.a));
}
