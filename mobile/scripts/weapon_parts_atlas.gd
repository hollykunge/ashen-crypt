extends RefCounted

# 由 art/side/pack_parts.py 生成，别手改。
# 每格 128×128 素材空间，零件竖着画，接口在 BASE，朝上长出去。length 是沿轴长度，width 是半宽，
# groove 是血槽走线（以接口为原点、沿轴为 +y），hold 是短杖从柄尾到握点的距离，tip 是弓弰挂弦处（同一坐标）。
# 弓只画上半张，下半张由游戏沿弓把镜像。
# layers 每层是 [格序, 染色]：steel 底子（近白，淡淡偏五行）、accent 朱砂纹饰换成的五行颜料色、trim 饰色、wrap 缠绳、bone 骨色、wood 弓臂漆色、glow 灵光，空串不染。gear 是装备图标，box 是它在格子里的范围。

const SHEET = preload("res://art/side/weapon-parts.png")
const GRID := Vector2(8, 13)
const BASE := Vector2(64.0, 124.0)
const PARTS := {
	"jian": {"kind": "blade", "length": 84.0, "width": 4.2, "layers": [[0, "steel"], [1, "accent"]]},
	"qixing": {"kind": "blade", "length": 84.0, "width": 4.3, "layers": [[2, "steel"], [3, "accent"], [4, "glow"]]},
	"bolang": {"kind": "blade", "length": 84.0, "width": 5.8, "layers": [[5, "steel"]]},
	"ruyi": {"kind": "guard", "length": 11.5, "width": 12.5, "layers": [[6, "steel"], [7, "accent"]]},
	"disc": {"kind": "guard", "length": 1.7, "width": 9.0, "layers": [[8, "steel"]]},
	"bar": {"kind": "guard", "length": 9.5, "width": 13.4, "layers": [[9, "steel"], [10, "accent"]]},
	"crescent": {"kind": "guard", "length": 20.7, "width": 12.5, "layers": [[11, "steel"], [12, "accent"]]},
	"cord": {"kind": "grip", "length": 18.0, "width": 2.9, "layers": [[13, "steel"], [14, "wrap"]]},
	"bands": {"kind": "grip", "length": 18.0, "width": 3.1, "layers": [[15, "steel"], [16, "wrap"]]},
	"ray": {"kind": "grip", "length": 18.0, "width": 3.2, "layers": [[17, "steel"], [18, "wrap"]]},
	"hex": {"kind": "pommel", "length": 9.3, "width": 5.0, "layers": [[19, "steel"], [20, "accent"]]},
	"ring": {"kind": "pommel", "length": 18.7, "width": 5.4, "layers": [[21, "steel"], [22, "accent"]]},
	"knob": {"kind": "pommel", "length": 13.7, "width": 3.7, "layers": [[23, "steel"], [24, "accent"]]},
	"cloud": {"kind": "pommel", "length": 12.0, "width": 5.8, "layers": [[25, "steel"], [26, "accent"]]},
	"leaf": {"kind": "head", "length": 56.0, "width": 8.8, "layers": [[27, "steel"], [28, "accent"]]},
	"snake": {"kind": "head", "length": 60.0, "width": 6.0, "layers": [[29, "steel"], [30, "accent"]]},
	"ji": {"kind": "head", "length": 54.0, "width": 13.5, "layers": [[31, "steel"], [32, "accent"]]},
	"fanqu": {"kind": "bow", "length": 62.0, "width": 17.3, "layers": [[33, "steel"], [34, "accent"]], "tip": Vector2(-7.0, 60.0)},
	"jiao": {"kind": "bow", "length": 54.0, "width": 17.6, "layers": [[35, "steel"], [36, "accent"]], "tip": Vector2(-6.0, 52.0)},
	"chang": {"kind": "bow", "length": 68.0, "width": 19.7, "layers": [[37, "steel"], [38, "accent"]], "tip": Vector2(-12.0, 66.0)},
	"yun": {"kind": "bow", "length": 60.0, "width": 19.2, "layers": [[39, "steel"], [40, "accent"]], "tip": Vector2(-6.0, 58.0)},
	"charm_taofu": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[41, "steel"], [42, "accent"]], "slot": "charm", "box": Rect2(41.5, 4.0, 45.0, 120.0)},
	"charm_yupei": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[43, "steel"], [44, "accent"]], "slot": "charm", "box": Rect2(40.7, 4.0, 46.5, 120.0)},
	"charm_shouya": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[45, "steel"], [46, "accent"]], "slot": "charm", "box": Rect2(33.0, 4.0, 62.0, 120.0)},
	"charm_tongling": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[47, "steel"], [48, "accent"]], "slot": "charm", "box": Rect2(39.0, 4.0, 50.2, 120.0)},
	"ring_banzhi": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[49, "steel"], [50, "accent"]], "slot": "ring", "box": Rect2(8.7, 4.0, 110.8, 120.0)},
	"ring_tiejie": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[51, "steel"], [52, "accent"]], "slot": "ring", "box": Rect2(13.3, 4.0, 101.3, 120.0)},
	"ring_yuhuan": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[53, "steel"], [54, "accent"]], "slot": "ring", "box": Rect2(22.7, 4.0, 82.7, 120.0)},
	"armor_cloth_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[55, "steel"], [56, "accent"]], "slot": "armor", "armor_type": "cloth", "box": Rect2(24.7, 4.0, 78.8, 120.0)},
	"gloves_cloth_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[57, "steel"], [58, "accent"]], "slot": "gloves", "armor_type": "cloth", "box": Rect2(26.0, 4.0, 76.2, 120.0)},
	"gloves_leather_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[59, "steel"], [60, "accent"]], "slot": "gloves", "armor_type": "leather", "box": Rect2(23.3, 4.0, 81.3, 120.0)},
	"boots_cloth_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[61, "steel"], [62, "accent"]], "slot": "boots", "armor_type": "cloth", "box": Rect2(19.0, 4.0, 90.0, 120.0)},
	"boots_leather_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[63, "steel"], [64, "accent"]], "slot": "boots", "armor_type": "leather", "box": Rect2(25.7, 4.0, 76.8, 120.0)},
	"armor_cloth_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[65, "steel"], [66, "accent"]], "slot": "armor", "armor_type": "cloth", "box": Rect2(36.3, 4.0, 55.5, 120.0)},
	"armor_leather_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[67, "steel"], [68, "accent"]], "slot": "armor", "armor_type": "leather", "box": Rect2(24.3, 4.0, 79.5, 120.0)},
	"armor_leather_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[69, "steel"], [70, "accent"]], "slot": "armor", "armor_type": "leather", "box": Rect2(27.2, 4.0, 73.7, 120.0)},
	"armor_chain_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[71, "steel"], [72, "accent"]], "slot": "armor", "armor_type": "chain", "box": Rect2(30.7, 4.0, 66.7, 120.0)},
	"armor_chain_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[73, "steel"], [74, "accent"]], "slot": "armor", "armor_type": "chain", "box": Rect2(25.3, 4.0, 77.3, 120.0)},
	"gloves_cloth_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[75, "steel"], [76, "accent"]], "slot": "gloves", "armor_type": "cloth", "box": Rect2(16.0, 4.0, 96.2, 120.0)},
	"gloves_leather_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[77, "steel"], [78, "accent"]], "slot": "gloves", "armor_type": "leather", "box": Rect2(20.3, 4.0, 87.5, 120.0)},
	"gloves_chain_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[79, "steel"], [80, "accent"]], "slot": "gloves", "armor_type": "chain", "box": Rect2(17.7, 4.0, 92.8, 120.0)},
	"gloves_chain_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[81, "steel"], [82, "accent"]], "slot": "gloves", "armor_type": "chain", "box": Rect2(15.8, 4.0, 96.3, 120.0)},
	"boots_cloth_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[83, "steel"], [84, "accent"]], "slot": "boots", "armor_type": "cloth", "box": Rect2(24.3, 4.0, 79.5, 120.0)},
	"boots_leather_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[85, "steel"], [86, "accent"]], "slot": "boots", "armor_type": "leather", "box": Rect2(16.2, 4.0, 95.7, 120.0)},
	"boots_chain_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[87, "steel"], [88, "accent"]], "slot": "boots", "armor_type": "chain", "box": Rect2(25.3, 4.0, 77.5, 120.0)},
	"boots_chain_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[89, "steel"], [90, "accent"]], "slot": "boots", "armor_type": "chain", "box": Rect2(26.5, 4.0, 75.0, 120.0)},
	"armor_f_silk_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[91, "steel"], [92, "accent"]], "slot": "armor", "armor_type": "cloth", "sex": "female", "box": Rect2(35.0, 4.0, 58.2, 120.0)},
	"armor_f_silk_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[93, "steel"], [94, "accent"]], "slot": "armor", "armor_type": "cloth", "sex": "female", "box": Rect2(24.7, 4.0, 78.5, 120.0)},
	"armor_f_leather_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[95, "steel"], [96, "accent"]], "slot": "armor", "armor_type": "leather", "sex": "female", "box": Rect2(29.7, 4.0, 68.8, 120.0)},
	"armor_f_leather_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[97, "steel"], [98, "accent"]], "slot": "armor", "armor_type": "leather", "sex": "female", "box": Rect2(24.5, 4.0, 79.0, 120.0)},
	"armor_f_plate_a": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[99, "steel"], [100, "accent"]], "slot": "armor", "armor_type": "chain", "sex": "female", "box": Rect2(25.5, 4.0, 77.0, 120.0)},
	"armor_f_plate_b": {"kind": "gear", "length": 120.0, "width": 12.0, "layers": [[101, "steel"], [102, "accent"]], "slot": "armor", "armor_type": "chain", "sex": "female", "box": Rect2(24.3, 4.0, 79.3, 120.0)},
}
