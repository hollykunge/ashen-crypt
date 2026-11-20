extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")

# 键沿用天干，玩家看到的只有白话材质名；阴阳与五行靠 UI 角标讲。
const MATERIALS := {
	"jia": {"name": "硬木心", "stem": "jia", "tier": 1, "purity": 3, "wuxing": {"mu": 1.0}, "yin_yang": 1.0},
	"yi": {"name": "藤筋", "stem": "yi", "tier": 2, "purity": 5, "wuxing": {"mu": 1.0}, "yin_yang": -1.0},
	"bing": {"name": "火砂", "stem": "bing", "tier": 2, "purity": 5, "wuxing": {"huo": 1.0}, "yin_yang": 1.0},
	"ding": {"name": "炭灰", "stem": "ding", "tier": 2, "purity": 5, "wuxing": {"huo": 1.0}, "yin_yang": -1.0},
	"wu": {"name": "岩块", "stem": "wu", "tier": 1, "purity": 3, "wuxing": {"tu": 1.0}, "yin_yang": 1.0},
	"ji": {"name": "黏土", "stem": "ji", "tier": 2, "purity": 4, "wuxing": {"tu": 1.0}, "yin_yang": -1.0},
	"geng": {"name": "生铁", "stem": "geng", "tier": 1, "purity": 3, "wuxing": {"jin": 1.0}, "yin_yang": 1.0},
	"xin": {"name": "铁屑", "stem": "xin", "tier": 2, "purity": 4, "wuxing": {"jin": 1.0}, "yin_yang": -1.0},
	"ren": {"name": "水晶", "stem": "ren", "tier": 2, "purity": 5, "wuxing": {"shui": 1.0}, "yin_yang": 1.0},
	"gui": {"name": "冰核", "stem": "gui", "tier": 2, "purity": 5, "wuxing": {"shui": 1.0}, "yin_yang": -1.0},
	"zhengyue_ingot": {"name": "精铁锭", "stem": "geng", "tier": 3, "purity": 9, "wuxing": {"jin": 0.9, "shui": 0.1}, "yin_yang": 0.8},
	"dragon_bone": {"name": "龙骨", "stem": "jia", "tier": 3, "purity": 9, "wuxing": {"mu": 0.7, "tu": 0.3}, "yin_yang": 0.6},
	"xuanming_sand": {"name": "寒冰砂", "stem": "gui", "tier": 3, "purity": 9, "wuxing": {"shui": 0.8, "jin": 0.2}, "yin_yang": -0.9},
	"geng_jing": {"name": "纯钢", "stem": "geng", "tier": 4, "purity": 14, "wuxing": {"jin": 1.0}, "yin_yang": 1.0},
	"taiji_pill": {"name": "五行丹", "stem": "", "tier": 4, "purity": 14,
		"wuxing": {"jin": 0.2, "mu": 0.2, "shui": 0.2, "huo": 0.2, "tu": 0.2}, "yin_yang": 0.0},
	"relic_core": {"name": "首领核心", "stem": "", "tier": 5, "purity": 20, "wuxing": {}, "yin_yang": 0.0}
}

static func key_of(id: String) -> String:
	if MATERIALS.has(id):
		return id
	for key in MATERIALS:
		if MATERIALS[key].name == id:
			return key
	var stem_index := WuXing.STEM_NAMES.find(id)
	return WuXing.STEMS[stem_index] if stem_index >= 0 else ""
