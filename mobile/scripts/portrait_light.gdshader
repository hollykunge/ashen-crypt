shader_type canvas_item;
render_mode unshaded;

uniform bool soften_edges = false;
uniform float fade_bottom = 0.0;
varying vec4 portrait_tint;

void vertex() {
	portrait_tint = COLOR;
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	float light = dot(artwork.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 ink = mix(vec3(0.84, 0.88, 0.94), vec3(1.07, 1.0, 0.88), smoothstep(0.32, 0.72, light));
	vec3 washed = mix(vec3(light) * ink, artwork.rgb, 0.72);
	vec2 edge = (UV - vec2(0.53, 0.34)) * vec2(1.3, 0.92);
	float vignette = smoothstep(0.20, 0.76, length(edge));
	float alpha = artwork.a;
	if (soften_edges) {
		alpha *= smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
		alpha *= smoothstep(0.0, 0.06, UV.y);
	}
	if (fade_bottom > 0.0) {
		alpha *= 1.0 - smoothstep(1.0 - fade_bottom, 1.0, UV.y);
	}
	COLOR = vec4(washed * (1.0 - 0.3 * vignette), alpha) * portrait_tint;
}
