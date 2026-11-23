extends RefCounted

const SLOTS := ["weapon", "armor", "gloves", "greaves", "boots"]
const SLOT_NAMES := ["武器", "上衣", "护腕", "护腿", "靴子"]
const EMPTY_ICONS := [9, 7, 17, 17, 20]
const ITEMS: Array[Dictionary] = [
	{"id": "chain_mail", "slot": "armor", "name": "锁环甲", "icon": 4, "cost": {"iron": 2, "bone": 3}, "stats": {"hp": 24}},
	{"id": "tomb_plate", "slot": "armor", "name": "镇岳山文甲", "icon": 7, "cost": {"iron": 5, "bone": 5, "ember": 1}, "stats": {"hp": 49, "armor": 12}, "set": "stonewatch"},
	{"id": "ranger_leather", "slot": "armor", "name": "青羽皮甲", "icon": 15, "cost": {"iron": 2, "bone": 5}, "stats": {"hp": 22, "speed": 8}, "set": "hunting"},
	{"id": "ritual_robe", "slot": "armor", "name": "雷府道袍", "icon": 16, "cost": {"bone": 5, "ember": 1}, "stats": {"mana": 22, "regen": 2}, "set": "ritual"},

	{"id": "plate_gauntlets", "slot": "gloves", "name": "镇岳铁护手", "icon": 17, "cost": {"iron": 4, "bone": 1}, "stats": {"attack": 4, "armor": 4}, "set": "stonewatch"},
	{"id": "ranger_gloves", "slot": "gloves", "name": "行猎手套", "icon": 18, "cost": {"iron": 1, "bone": 4}, "stats": {"attack": 3, "crit": 7}, "set": "hunting"},
	{"id": "ritual_wraps", "slot": "gloves", "name": "燃纹护手", "icon": 19, "cost": {"bone": 3, "ember": 1}, "stats": {"attack": 3, "regen": 2}, "set": "ritual"},

	{"id": "blue_pendant", "slot": "charm", "name": "青玉佩", "icon": 5, "cost": {"bone": 2, "ember": 1}, "stats": {"mana": 18}},
	{"id": "ember_charm", "slot": "charm", "name": "护身符箓", "icon": 8, "cost": {"iron": 2, "bone": 4, "ember": 2}, "stats": {"mana": 8, "regen": 4}, "set": "ritual"},
	{"id": "bone_amulet", "slot": "charm", "name": "龙牙璎珞", "icon": 26, "cost": {"iron": 1, "bone": 6}, "stats": {"crit": 4, "kill_heal": 4}},

	{"id": "stone_ring", "slot": "ring", "name": "镇岳印戒", "icon": 23, "cost": {"iron": 4, "ember": 1}, "stats": {"hp": 14, "armor": 5}, "set": "stonewatch"},
	{"id": "hunter_ring", "slot": "ring", "name": "青枝戒指", "icon": 24, "cost": {"bone": 4, "ember": 1}, "stats": {"crit": 9, "kill_heal": 2}, "set": "hunting"},
	{"id": "spark_ring", "slot": "ring", "name": "引火戒指", "icon": 25, "cost": {"iron": 2, "bone": 1, "ember": 1}, "stats": {"mana": 11, "regen": 2}, "set": "ritual"},

	{"id": "plate_boots", "slot": "boots", "name": "镇岳铁靴", "icon": 20, "cost": {"iron": 4, "bone": 2}, "stats": {"hp": 18, "armor": 6}, "set": "stonewatch"},
	{"id": "hunter_boots", "slot": "boots", "name": "踏影皮靴", "icon": 21, "cost": {"iron": 1, "bone": 5}, "stats": {"speed": 12, "dodge_ms": 220}, "set": "hunting"},
	{"id": "ashwoven_boots", "slot": "boots", "name": "云纹履", "icon": 22, "cost": {"bone": 3, "ember": 1}, "stats": {"speed": 7, "regen": 2}}
]
const SETS := {
	"stonewatch": {"name": "镇岳神将", "color": Color("#eac181"),
		"two": {"armor": 8}, "three": {"thorns": 14},
		"two_text": "减伤 +8%", "three_text": "受击时对攻击者反伤 14"},
	"hunting": {"name": "青羽行猎", "color": Color("#add5a8"),
		"two": {"crit": 8}, "three": {"dodge_crit": 1},
		"two_text": "普攻暴击率 +8%", "three_text": "后撤后下一轮普攻必暴击"},
	"ritual": {"name": "雷府秘仪", "color": Color("#cfb3f0"),
		"two": {"regen": 3}, "three": {"mana_discount": 20},
		"two_text": "每秒回蓝 +3", "three_text": "技能耗蓝 -20%"}
}
const AFFIXES := {
	"sturdy": {"name": "坚韧", "stats": {"hp": 10}},
	"warded": {"name": "铁壁", "stats": {"armor": 3}},
	"keen": {"name": "锐意", "stats": {"crit": 4}},
	"quick": {"name": "轻盈", "stats": {"speed": 4}},
	"surge": {"name": "聚能", "stats": {"regen": 1}},
	"vital": {"name": "汲生", "stats": {"kill_heal": 2}}
}
const STAT_FORMATS := {
	"attack": "攻击 +%d", "hp": "生命上限 +%d", "mana": "灵力上限 +%d", "regen": "每秒回蓝 +%d",
	"armor": "减伤 +%d%%", "crit": "暴击率 +%d%%", "speed": "移速 +%d%%",
	"dodge_ms": "后撤冷却 -%.2f 秒", "kill_heal": "击杀回血 +%d"
}

static func describe(stats: Dictionary) -> String:
	var lines := PackedStringArray()
	for key in stats:
		var pattern: String = STAT_FORMATS.get(key, "")
		if not pattern.is_empty():
			lines.append(pattern % (float(stats[key]) / 1000.0 if key == "dodge_ms" else stats[key]))
	return " · ".join(lines)
