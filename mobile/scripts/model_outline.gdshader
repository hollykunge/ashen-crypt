// 3D 角色描边：背面沿法线外扩一圈，填墨色（#3a2c22，与 Blender 出图一致）。作为卡通材质的 next_pass。
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 ink : source_color = vec4(0.227, 0.173, 0.133, 1.0);
uniform float width = 0.006;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
