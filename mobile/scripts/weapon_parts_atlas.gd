extends RefCounted

# 由 art/side/pack_parts.py 生成，别手改。
# 每格 128×128 素材空间，零件竖着画，接口在 BASE，朝上长出去。length 是沿轴长度，width 是半宽，
# groove 是血槽走线（以接口为原点、沿轴为 +y），hold 是短杖从柄尾到握点的距离。
# layers 每层是 [格序, 染色]：steel 钢色、trim 饰色、wrap 缠绳、bone 骨色、glow 灵光，空串不染。

const SHEET = preload("res://art/side/weapon-parts.png")
const GRID := Vector2(8, 5)
const BASE := Vector2(64.0, 124.0)
const PARTS := {
	"liuye": {"kind": "blade", "length": 82.0, "width": 6.0, "layers": [[0, "steel"], [1, ""]], "groove": [Vector2(1.5, 8.5), Vector2(1.4, 13.7), Vector2(1.2, 18.8), Vector2(1.0, 23.9), Vector2(0.7, 29.0), Vector2(0.3, 34.2), Vector2(-0.2, 39.3), Vector2(-0.7, 44.4), Vector2(-1.3, 49.5), Vector2(-2.0, 54.7), Vector2(-2.9, 59.8)]},
	"yanling": {"kind": "blade", "length": 80.0, "width": 5.5, "layers": [[2, "steel"], [3, ""]], "groove": [Vector2(1.0, 8.3), Vector2(1.0, 13.3), Vector2(1.0, 18.3), Vector2(1.0, 23.3), Vector2(1.0, 28.3), Vector2(1.0, 33.3), Vector2(1.0, 38.3), Vector2(1.0, 43.3), Vector2(1.0, 48.3), Vector2(0.8, 53.3), Vector2(0.2, 58.3)]},
	"guitou": {"kind": "blade", "length": 76.0, "width": 9.0, "layers": [[4, "steel"], [5, ""]], "groove": [Vector2(0.5, 7.9), Vector2(0.4, 12.7), Vector2(0.3, 17.4)]},
	"jian": {"kind": "blade", "length": 84.0, "width": 3.6, "layers": [[6, "steel"], [7, ""]], "groove": [Vector2(0.0, 7.0), Vector2(0.0, 12.2), Vector2(0.0, 17.5), Vector2(0.0, 22.8), Vector2(0.0, 28.0), Vector2(0.0, 33.2), Vector2(0.0, 38.5), Vector2(0.0, 43.8), Vector2(0.0, 49.0), Vector2(0.0, 54.2), Vector2(0.0, 59.5), Vector2(0.0, 64.8)]},
	"qixing": {"kind": "blade", "length": 84.0, "width": 3.6, "layers": [[8, "steel"], [9, ""], [10, "glow"]], "groove": [Vector2(0.0, 7.0), Vector2(0.0, 12.2), Vector2(0.0, 17.5), Vector2(0.0, 22.8), Vector2(0.0, 28.0), Vector2(0.0, 33.2), Vector2(0.0, 38.5), Vector2(0.0, 43.8), Vector2(0.0, 49.0), Vector2(0.0, 54.2), Vector2(0.0, 59.5), Vector2(0.0, 64.8)]},
	"bolang": {"kind": "blade", "length": 84.0, "width": 4.0, "layers": [[11, "steel"], [12, ""]], "groove": [Vector2(0.0, 7.0), Vector2(0.0, 12.2), Vector2(0.0, 17.5), Vector2(0.0, 22.8), Vector2(0.0, 28.0), Vector2(0.0, 33.2), Vector2(0.0, 38.5), Vector2(0.0, 43.8), Vector2(0.0, 49.0), Vector2(0.0, 54.2), Vector2(0.0, 59.5), Vector2(0.0, 64.8)]},
	"ruyi": {"kind": "guard", "length": 7.8, "width": 12.5, "layers": [[13, "trim"], [14, "glow"]]},
	"disc": {"kind": "guard", "length": 6.6, "width": 9.0, "layers": [[15, "trim"]]},
	"bar": {"kind": "guard", "length": 5.2, "width": 13.4, "layers": [[16, "trim"]]},
	"crescent": {"kind": "guard", "length": 5.0, "width": 12.5, "layers": [[17, "trim"]]},
	"cord": {"kind": "grip", "length": 18.0, "width": 2.9, "layers": [[18, "wrap"]]},
	"bands": {"kind": "grip", "length": 18.0, "width": 3.1, "layers": [[19, "wrap"]]},
	"ray": {"kind": "grip", "length": 18.0, "width": 3.2, "layers": [[20, "wrap"]]},
	"hex": {"kind": "pommel", "length": 7.0, "width": 5.0, "layers": [[21, "trim"]]},
	"ring": {"kind": "pommel", "length": 14.4, "width": 5.4, "layers": [[22, "trim"]]},
	"knob": {"kind": "pommel", "length": 9.3, "width": 3.7, "layers": [[23, "trim"]]},
	"cloud": {"kind": "pommel", "length": 10.2, "width": 5.8, "layers": [[24, "trim"]]},
	"leaf": {"kind": "head", "length": 56.0, "width": 6.2, "layers": [[25, "steel"]]},
	"snake": {"kind": "head", "length": 60.0, "width": 6.0, "layers": [[26, "steel"]]},
	"ji": {"kind": "head", "length": 54.0, "width": 13.5, "layers": [[27, "steel"]]},
	"gua": {"kind": "head", "length": 46.0, "width": 15.0, "layers": [[28, "steel"]]},
	"fang": {"kind": "head", "length": 43.0, "width": 13.8, "layers": [[29, "steel"]]},
	"orb": {"kind": "head", "length": 36.0, "width": 9.5, "layers": [[30, "trim"], [31, "glow"]]},
	"moon": {"kind": "head", "length": 31.0, "width": 14.0, "layers": [[32, "steel"]]},
	"bone": {"kind": "wand", "length": 61.0, "width": 5.6, "layers": [[33, "bone"], [34, ""], [35, "glow"]], "hold": 13.0},
	"ruyi_wand": {"kind": "wand", "length": 56.0, "width": 9.0, "layers": [[36, "trim"], [37, "glow"]], "hold": 9.0},
}
