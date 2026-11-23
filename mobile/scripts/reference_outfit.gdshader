shader_type canvas_item;
uniform sampler2D glove_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D greave_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D boot_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D pose_slots : filter_linear, repeat_disable;
varying vec4 color_modulation;

void vertex() {
	color_modulation = COLOR;
}

void fragment() {
	vec3 slots = texture(pose_slots, UV).rgb;
	vec4 garment = mix(texture(TEXTURE, UV), texture(glove_texture, UV), slots.r);
	COLOR = color_modulation * (garment * max(0.0, 1.0 - slots.g - slots.b)
		+ texture(boot_texture, UV) * slots.g + texture(greave_texture, UV) * slots.b);
}
