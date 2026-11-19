shader_type canvas_item;
render_mode unshaded;

uniform bool camp_view = false;

void fragment() {
	float distance_from_floor = 1.0 - smoothstep(0.27, 0.68, UV.y);
	float lod = camp_view ? 2.15 * distance_from_floor : 0.0;
	vec3 stone = textureLod(TEXTURE, UV, lod).rgb;
	float mist_line = 0.42 + 0.035 * sin(UV.x * 8.0 + TIME * 0.23);
	float mist = 1.0 - smoothstep(0.0, 0.19, abs(UV.y - mist_line));
	mist *= 0.06 + 0.065 * (0.5 + 0.5 * sin(UV.x * 13.0 - TIME * 0.41));
	vec2 edge = abs(UV - 0.5) * vec2(1.20, 0.79);
	float vignette = smoothstep(0.31, 0.68, length(edge));
	COLOR = vec4(mix(stone, vec3(0.50, 0.52, 0.55), mist) * (1.0 - 0.32 * vignette), 1.0);
}
