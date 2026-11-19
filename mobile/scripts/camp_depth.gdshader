shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float distance_from_floor = 1.0 - smoothstep(0.25, 0.70, UV.y);
	COLOR = textureLod(TEXTURE, UV, mix(1.0, 3.7, distance_from_floor));
}
