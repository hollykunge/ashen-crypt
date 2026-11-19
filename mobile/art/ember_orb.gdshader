shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 light_ink : source_color = vec4(0.71, 0.12, 0.17, 1.0);
uniform vec4 deep_ink : source_color = vec4(0.18, 0.025, 0.05, 1.0);
uniform vec4 glint_ink : source_color = vec4(0.95, 0.46, 0.33, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float edge = 1.0 - smoothstep(0.95, 0.985, r);
	vec3 color = vec3(0.045, 0.03, 0.026);

	float metal_angle = 0.55 + 0.45 * dot(normalize(p + vec2(0.0001)), normalize(vec2(-0.64, -0.77)));
	float metal = smoothstep(0.78, 0.81, r) * (1.0 - smoothstep(0.921, 0.95, r));
	color = mix(color, mix(vec3(0.14, 0.105, 0.069), vec3(0.50, 0.39, 0.26), metal_angle), metal);
	float engraving = (1.0 - smoothstep(0.007, 0.025, abs(r - 0.888))) * (0.35 + 0.65 * pow(metal_angle, 3.0));
	color += vec3(0.22, 0.15, 0.09) * engraving;

	float glass_r = r / 0.79;
	float glass = 1.0 - smoothstep(0.98, 1.0, glass_r);
	float surface = 0.79 - 1.58 * amount + 0.018 * sin(p.x * 11.0 + TIME * 1.4) * sin(3.14159 * amount);
	float filled = smoothstep(surface - 0.014, surface + 0.014, p.y);
	float internal_glow = pow(max(0.0, 1.0 - length(p - vec2(-0.19, -0.14)) / 1.03), 2.4);
	float refraction = 0.07 * sin(p.x * 15.0 + p.y * 19.0 + TIME * 0.85) + 0.06 * sin(p.x * 20.0 - p.y * 8.0);
	vec3 liquid = mix(deep_ink.rgb, light_ink.rgb, clamp(0.22 + 0.88 * internal_glow + refraction, 0.0, 1.0));
	float lip = 1.0 - smoothstep(0.008, 0.040, abs(p.y - surface));
	liquid += glint_ink.rgb * lip * 0.40 * (1.0 - smoothstep(0.62, 0.77, abs(p.x)));
	float empty_rim = smoothstep(0.51, 0.90, glass_r) * 0.04;
	vec3 interior = mix(vec3(0.048, 0.038, 0.033) + empty_rim, liquid, filled);
	float sheen = exp(-dot((p - vec2(-0.27, -0.39)) * vec2(5.4, 17.0), (p - vec2(-0.27, -0.39)) * vec2(5.4, 17.0)));
	float rim_light = smoothstep(0.81, 0.97, glass_r) * (1.0 - smoothstep(0.975, 1.0, glass_r)) * pow(metal_angle, 5.0);
	interior += vec3(0.92, 0.85, 0.73) * (0.45 * sheen + 0.25 * rim_light);
	color = mix(color, interior, glass);
	COLOR = vec4(color, edge);
}
