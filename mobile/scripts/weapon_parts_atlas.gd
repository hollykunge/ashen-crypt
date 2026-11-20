extends RefCounted

# 由 art/side/pack_parts.py 生成，别手改。
# 每格 128×128 素材空间，零件竖着画，接口在 BASE，朝上长出去。length 是沿轴长度，width 是半宽，
# groove 是血槽走线（以接口为原点、沿轴为 +y），hold 是短杖从柄尾到握点的距离，tip 是弓弰挂弦处（同一坐标）。
# 弓只画上半张，下半张由游戏沿弓把镜像。
# layers 每层是 [格序, 染色]：steel 钢色、trim 饰色、wrap 缠绳、bone 骨色、wood 弓臂与杆的漆色、glow 灵光，空串不染。

const SHEET = preload("res://art/side/weapon-parts.png")
const GRID := Vector2(8, 6)
const BASE := Vector2(64.0, 124.0)
const PARTS := {
	"liuye": {"kind": "blade", "length": 82.0, "width": 6.4, "layers": [[0, "steel"], [1, "trim"]]},
	"yanling": {"kind": "blade", "length": 80.0, "width": 5.5, "layers": [[2, "steel"], [3, "trim"]]},
	"guitou": {"kind": "blade", "length": 76.0, "width": 12.6, "layers": [[4, "steel"], [5, "trim"]]},
	"jian": {"kind": "blade", "length": 84.0, "width": 3.6, "layers": [[6, "steel"], [7, "trim"]]},
	"qixing": {"kind": "blade", "length": 84.0, "width": 3.6, "layers": [[8, "steel"], [9, "trim"], [10, "glow"]]},
	"bolang": {"kind": "blade", "length": 84.0, "width": 4.0, "layers": [[11, "steel"], [12, "trim"]]},
	"ruyi": {"kind": "guard", "length": 9.2, "width": 12.5, "layers": [[13, "trim"]]},
	"disc": {"kind": "guard", "length": 5.2, "width": 9.0, "layers": [[14, "trim"]]},
	"bar": {"kind": "guard", "length": 5.2, "width": 13.4, "layers": [[15, "trim"]]},
	"crescent": {"kind": "guard", "length": 13.2, "width": 12.5, "layers": [[16, "trim"]]},
	"cord": {"kind": "grip", "length": 18.0, "width": 2.9, "layers": [[17, "wrap"]]},
	"bands": {"kind": "grip", "length": 18.0, "width": 3.1, "layers": [[18, "wrap"]]},
	"ray": {"kind": "grip", "length": 18.0, "width": 3.2, "layers": [[19, "wrap"]]},
	"hex": {"kind": "pommel", "length": 6.2, "width": 5.0, "layers": [[20, "trim"]]},
	"ring": {"kind": "pommel", "length": 16.3, "width": 5.4, "layers": [[21, "trim"]]},
	"knob": {"kind": "pommel", "length": 11.8, "width": 3.7, "layers": [[22, "trim"]]},
	"cloud": {"kind": "pommel", "length": 9.7, "width": 5.8, "layers": [[23, "trim"]]},
	"leaf": {"kind": "head", "length": 56.0, "width": 6.9, "layers": [[24, "steel"], [25, "trim"]]},
	"snake": {"kind": "head", "length": 60.0, "width": 6.0, "layers": [[26, "steel"], [27, "trim"]]},
	"ji": {"kind": "head", "length": 54.0, "width": 13.5, "layers": [[28, "steel"], [29, "trim"]]},
	"gua": {"kind": "head", "length": 46.0, "width": 15.0, "layers": [[30, "steel"], [31, "trim"]]},
	"fang": {"kind": "head", "length": 43.0, "width": 13.8, "layers": [[32, "steel"], [33, "trim"]]},
	"orb": {"kind": "head", "length": 36.0, "width": 9.5, "layers": [[34, "trim"], [35, "glow"]]},
	"moon": {"kind": "head", "length": 31.0, "width": 14.0, "layers": [[36, "steel"], [37, "trim"]]},
	"bone": {"kind": "wand", "length": 61.0, "width": 5.6, "layers": [[38, "bone"], [39, "trim"]], "hold": 13.0},
	"ruyi_wand": {"kind": "wand", "length": 56.0, "width": 9.0, "layers": [[40, "trim"]], "hold": 9.0},
	"fanqu": {"kind": "bow", "length": 62.0, "width": 16.7, "layers": [[41, "wood"]], "tip": Vector2(-7.0, 60.0)},
	"jiao": {"kind": "bow", "length": 54.0, "width": 14.6, "layers": [[42, "wood"]], "tip": Vector2(-6.0, 52.0)},
	"chang": {"kind": "bow", "length": 68.0, "width": 16.6, "layers": [[43, "wood"]], "tip": Vector2(-12.0, 66.0)},
	"yun": {"kind": "bow", "length": 60.0, "width": 15.9, "layers": [[44, "wood"]], "tip": Vector2(-6.0, 58.0)},
}
