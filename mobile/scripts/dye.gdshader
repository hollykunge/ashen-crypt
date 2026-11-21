shader_type canvas_item;

// 按装备给人物原画染色，每帧现算：换一件就是改几个颜色参数，不用重新合成贴图。
// 五张染色图层（art/side/dye/fullbody-*，由 pack_portraits.py 按分区遮罩出）各管一块布：
//   A 在不在这一区   R 压暗多少（向 SHADOW）   G 提亮多少（向 HIGHLIGHT，满格是 LIGHTEN_MAX）
// 先在范围内平涂染料，再按原画的明暗压暗、提亮，等于染料乘上原画的褶皱和勾线。
// 和 worn_sprites.gd 合成战斗图集是同一套算法，常数与 pack_frames.py 的 shade_layer 一致。
// 某一区的颜色 alpha 为 0 就是那一区没穿装备，保持原画。

const vec3 SHADOW = vec3(0.070, 0.040, 0.085);
const vec3 HIGHLIGHT = vec3(1.0, 0.97, 0.9);
const float LIGHTEN_MAX = 0.30;

uniform sampler2D cloth_layer : filter_linear_mipmap;
uniform sampler2D trim_layer : filter_linear_mipmap;
uniform sampler2D bracers_layer : filter_linear_mipmap;
uniform sampler2D boots_layer : filter_linear_mipmap;
uniform sampler2D charm_layer : filter_linear_mipmap;
uniform vec4 cloth_dye = vec4(0.0);
uniform vec4 trim_dye = vec4(0.0);
uniform vec4 bracers_dye = vec4(0.0);
uniform vec4 boots_dye = vec4(0.0);
uniform vec4 charm_dye = vec4(0.0);

varying vec4 ink;

void vertex() {
	ink = COLOR;
}

// 一区的贡献：在这区里占多少（weight），染好之后是什么颜色（没穿就是原画）。
// 五区互不重叠。缩小取样时相邻两区的边上各占一部分，按占比把两区染好的颜色平均，
// 不能一区接一区地往上叠，否则边上会透出原画那一截浅色或黑色，染出一圈细边。
void dye(sampler2D layer, vec4 color, vec2 uv, vec3 base, inout vec3 sum, inout float weight) {
	vec4 shade = texture(layer, uv);
	float inside = shade.a;
	vec3 dyed = mix(color.rgb, SHADOW, shade.r);
	dyed = mix(dyed, HIGHLIGHT, shade.g * LIGHTEN_MAX);
	sum += inside * mix(base, dyed, color.a);
	weight += inside;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	dye(cloth_layer, cloth_dye, UV, base.rgb, sum, weight);
	dye(trim_layer, trim_dye, UV, base.rgb, sum, weight);
	dye(bracers_layer, bracers_dye, UV, base.rgb, sum, weight);
	dye(boots_layer, boots_dye, UV, base.rgb, sum, weight);
	dye(charm_layer, charm_dye, UV, base.rgb, sum, weight);
	vec3 rgb = weight > 0.0 ? mix(base.rgb, sum / weight, min(weight, 1.0)) : base.rgb;
	COLOR = vec4(rgb, base.a) * ink;
}
