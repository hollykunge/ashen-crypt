shader_type canvas_item;

uniform float curve_pixels;
uniform float texture_margin;
uniform vec2 spine_span;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float y = UV.y / TEXTURE_PIXEL_SIZE.y - texture_margin;
	float height = (y - spine_span.x) / (spine_span.y - spine_span.x);
	// 肩接点和腰带保持原位，上背略向后，腰窝略向前。
	float upper = smoothstep(0.0, 0.24, height) * (1.0 - smoothstep(0.24, 0.59, height));
	float lower = smoothstep(0.34, 0.72, height) * (1.0 - smoothstep(0.72, 1.0, height));
	float offset = (lower - 0.8 * upper) * curve_pixels;
	vec2 source = UV - vec2(offset * TEXTURE_PIXEL_SIZE.x, 0.0);
	float inside = step(0.0, source.x) * step(source.x, 1.0);
	COLOR = texture(TEXTURE, source) * tint * vec4(1.0, 1.0, 1.0, inside);
}
