shader_type canvas_item;

uniform float grade_weight = 0.79;
uniform float exposure = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.30, 0.55, 0.15));
	vec3 ink = mix(vec3(0.064, 0.060, 0.057), vec3(0.78, 0.63, 0.47), pow(value, 1.08));
	vec3 color = mix(source.rgb * vec3(0.70, 0.66, 0.58), ink, grade_weight);
	COLOR = vec4(color * exposure, source.a);
}
