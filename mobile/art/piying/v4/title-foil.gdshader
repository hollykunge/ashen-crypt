shader_type canvas_item;
render_mode unshaded;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(17.13, 91.7))) * 4375.17);
}

void fragment() {
	float fleck = grain(floor(FRAGCOORD.xy));
	float cloud = grain(floor(FRAGCOORD.xy / 3.0));
	float gold = smoothstep(0.04, 0.86, fleck * 0.48 + cloud * 0.52);
	COLOR.rgb = mix(vec3(0.76, 0.49, 0.19), vec3(1.0, 0.89, 0.64), gold);
}
