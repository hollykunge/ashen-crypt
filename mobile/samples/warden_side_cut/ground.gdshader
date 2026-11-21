shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D earth : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Continue the village painting at the far edge. The texture stays fixed in
	// world space while the inspection camera moves past the dimensional front set.
	vec3 reference_eye = vec3(0.0, 2.84, 10.7);
	vec3 ray = world_point - reference_eye;
	vec3 on_backdrop = reference_eye + ray * ((-12.0 - reference_eye.z) / ray.z);
	vec2 uv = vec2(0.143 + on_backdrop.x / 143.8, 0.735 - on_backdrop.y / 13.2);
	uv.y = 0.735 + 0.26 * (1.0 - abs(mod((uv.y - 0.735) / 0.26, 2.0) - 1.0));
	vec3 paint = texture(panorama, uv).rgb;
	vec3 detail = texture(earth, vec2(world_point.x / 8.2, world_point.z / 9.0)).rgb;
	ALBEDO = mix(paint, detail, 0.12 * smoothstep(-12.0, -5.0, world_point.z));
}
void light() {
	DIFFUSE_LIGHT += vec3(1.0) * mix(0.55, 1.0, ATTENUATION);
}
