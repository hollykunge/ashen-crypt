extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")

# 基础材料用天干作键，高阶材料用独立键。
const MATERIALS := {
	"jia": {"name": "甲木心", "stem": "jia", "tier": 1, "purity": 3, "wuxing": {"mu": 1.0}, "yin_yang": 1.0},
	"yi": {"name": "乙藤筋", "stem": "yi", "tier": 2, "purity": 5, "wuxing": {"mu": 1.0}, "yin_yang": -1.0},
	"bing": {"name": "丙焰砂", "stem": "bing", "tier": 2, "purity": 5, "wuxing": {"huo": 1.0}, "yin_yang": 1.0},
	"ding": {"name": "丁烬粉", "stem": "ding", "tier": 2, "purity": 5, "wuxing": {"huo": 1.0}, "yin_yang": -1.0},
	"wu": {"name": "戊岩骨", "stem": "wu", "tier": 1, "purity": 3, "wuxing": {"tu": 1.0}, "yin_yang": 1.0},
	"ji": {"name": "己壤髓", "stem": "ji", "tier": 2, "purity": 4, "wuxing": {"tu": 1.0}, "yin_yang": -1.0},
	"geng": {"name": "庚铁", "stem": "geng", "tier": 1, "purity": 3, "wuxing": {"jin": 1.0}, "yin_yang": 1.0},
	"xin": {"name": "辛刃屑", "stem": "xin", "tier": 2, "purity": 4, "wuxing": {"jin": 1.0}, "yin_yang": -1.0},
	"ren": {"name": "壬流晶", "stem": "ren", "tier": 2, "purity": 5, "wuxing": {"shui": 1.0}, "yin_yang": 1.0},
	"gui": {"name": "癸霜核", "stem": "gui", "tier": 2, "purity": 5, "wuxing": {"shui": 1.0}, "yin_yang": -1.0},
	"zhengyue_ingot": {"name": "镇岳铁锭", "stem": "geng", "tier": 3, "purity": 9, "wuxing": {"jin": 0.9, "shui": 0.1}, "yin_yang": 0.8},
	"dragon_bone": {"name": "龙骨", "stem": "jia", "tier": 3, "purity": 9, "wuxing": {"mu": 0.7, "tu": 0.3}, "yin_yang": 0.6},
	"xuanming_sand": {"name": "玄冥砂", "stem": "gui", "tier": 3, "purity": 9, "wuxing": {"shui": 0.8, "jin": 0.2}, "yin_yang": -0.9},
	"geng_jing": {"name": "庚精", "stem": "geng", "tier": 4, "purity": 14, "wuxing": {"jin": 1.0}, "yin_yang": 1.0},
	"taiji_pill": {"name": "太极丹", "stem": "", "tier": 4, "purity": 14,
		"wuxing": {"jin": 0.2, "mu": 0.2, "shui": 0.2, "huo": 0.2, "tu": 0.2}, "yin_yang": 0.0},
	"relic_core": {"name": "遗物核", "stem": "", "tier": 5, "purity": 20, "wuxing": {}, "yin_yang": 0.0}
}

static func key_of(id: String) -> String:
	if MATERIALS.has(id):
		return id
	for key in MATERIALS:
		if MATERIALS[key].name == id:
			return key
	var stem_index := WuXing.STEM_NAMES.find(id)
	return WuXing.STEMS[stem_index] if stem_index >= 0 else ""
