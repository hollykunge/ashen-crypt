shader_type canvas_item;
uniform sampler2D panel_mask : filter_linear, repeat_disable;
uniform int style = 0;
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 panel = texture(panel_mask, UV);
	float value = dot(original.rgb, vec3(0.30, 0.59, 0.11));
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	vec3 paint = original.rgb;
	if (style == 1) {
		paint = vec3(0.18, 0.63, 0.70) * (0.20 + value * 2.65);
	} else if (style == 2) {
		vec2 tile = mod(p + vec2(6.0 * mod(floor(p.y / 12.0), 2.0), 0.0), vec2(16.0,12.0));
		float seam = smoothstep(0.0, 1.7, min(tile.x,tile.y));
		float stud = 1.0 - smoothstep(0.65,1.5,length(tile-vec2(4.0,3.0)));
		vec3 leather = vec3(0.58,0.31,0.14) * (0.63+0.37*seam) + vec3(0.26,0.17,0.05)*stud;
		paint = mix(leather,vec3(0.24,0.12,0.065),panel.g) * (0.27 + 2.7 * value);
	} else if (style == 3) {
		vec2 tile = mod(p + vec2(3.5 * mod(floor(p.y / 5.0),2.0),0.0),vec2(7.0,5.0));
		float ring = 1.0 - smoothstep(0.35,1.2,abs(length((tile-vec2(3.5,2.5))*vec2(0.88,1.0))-2.0));
		paint = (vec3(0.30,0.35,0.37)+ring*vec3(0.29,0.30,0.30)) * (0.32 + 2.55*value);
	}
	COLOR = vec4(mix(original.rgb, paint, panel.a),original.a);
}
