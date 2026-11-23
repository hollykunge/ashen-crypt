shader_type canvas_item;
// 整屏：暗角、轻微降饱和、胶片颗粒
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.85;
uniform float grain = 0.045;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.15);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.15, 1.0);
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, length(d));
	col += (hash(SCREEN_UV * 1000.0 + fract(TIME) * 37.0) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
