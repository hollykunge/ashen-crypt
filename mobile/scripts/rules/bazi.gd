extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")
const BRANCHES := WuXing.BRANCHES
# 所有人共用的本命柱，不代表年份，只为身强度提供一份固定的干支底色。
const BASE_PILLAR := ["jia", "zi"]
const HOUR_TALENTS := {
	"zi": {"forge_level": 1}, "chou": {"material_slots": 1}, "yin": {"starting_equipment_stem": "jia"},
	"mao": {"material_drop_bonus": 0.10}, "chen": {"unlocks": ["quench"]}, "si": {"unlocks": ["harmonize"]},
	"wu": {"unlocks": ["forge_yang"]}, "wei": {"residue_refund_bonus": 0.20}, "shen": {"unlocks": ["forge_fine"]},
	"you": {"crit_bonus": 0.03}, "xu": {"hp_bonus": 0.10}, "hai": {"unlocks": ["rotate"]}
}
const HOUR_STEM_BASE := {
	"jia": "jia", "ji": "jia", "yi": "bing", "geng": "bing", "bing": "wu",
	"xin": "wu", "ding": "geng", "ren": "geng", "wu": "ren", "gui": "ren"
}

# 同性、异性；生克的方向以日干为主体。
const TEN_GODS := {
	"bi": ["bijian", "jiecai"], "shishang": ["shishen", "shangguan"], "cai": ["piancai", "zhengcai"],
	"guansha": ["qisha", "zhengguan"], "yin": ["pianyin", "zhengyin"]
}
const F_WEAK := {"yin": 1.25, "bi": 1.18, "shishang": 0.90, "cai": 0.85, "guansha": 0.82}
const F_STRONG := {"yin": 0.70, "bi": 0.82, "shishang": 1.08, "cai": 1.15, "guansha": 1.25}
const ZHONGHE_K := 0.14
const MONTH_STRENGTH := {"bi": 1.00, "yin": 0.50, "cai": -0.30, "guansha": -0.50, "shishang": -0.70}
const PILLAR_STRENGTH := {"bi": 0.15, "yin": 0.15, "cai": 0.0, "guansha": -0.15, "shishang": -0.15}

const GOD_EFFECTS := {
	"bijian": {"name": "比肩", "stat_bonus": 0.08, "sockets_allowed": false},
	"jiecai": {"name": "劫财", "attack_bonus": 0.18, "mana_per_kill": -2},
	"shishen": {"name": "食神", "dot_bonus": 0.20, "recovery_bonus": 0.20},
	"shangguan": {"name": "伤官", "crit_damage_bonus": 0.25, "incoming_damage_bonus": 0.08},
	"zhengcai": {"name": "正财", "material_drop_bonus": 0.15, "lifesteal_bonus": 0.10},
	"piancai": {"name": "偏财", "crit_drop_multiplier": 2.0, "luck_bonus": 0.20, "volatile_drops": true},
	"zhengguan": {"name": "正官", "armor_bonus": 0.12, "attack_speed_bonus": -0.08},
	"qisha": {"name": "七杀", "attack_bonus": 0.25, "hp_bonus": -0.10},
	"zhengyin": {"name": "正印", "healing_bonus": 0.20, "shield_bonus": 0.20, "mana_regen_bonus": 0.15},
	"pianyin": {"name": "偏印", "cooldown_bonus": -0.12, "mana_bonus": 0.15, "incoming_healing_bonus": -0.15}
}
# 本层地气相对日干的十神，决定这一层的遭遇类型。
const LING_GODS := {
	"bi": {"name": "比劫", "more_same_element_foes": true},
	"shishang": {"name": "食伤", "more_foes": true, "fragile_foes": true},
	"cai": {"name": "财", "more_drops": true, "treasure_foes": true},
	"guansha": {"name": "官杀", "elite_foes": true, "foe_armor_break": true},
	"yin": {"name": "印", "healer_foes": true, "higher_material_tier": true}
}

static func element_group(day_element: String, other_element: String) -> String:
	match WuXing.clash_relation(day_element, other_element):
		"tong_qi": return "bi"
		"wei_yang": return "shishang"
		"ke": return "cai"
		"shou_ke": return "guansha"
		"de_sheng": return "yin"
	return ""

static func ten_god(day_stem: String, other_stem: String) -> String:
	var group := element_group(WuXing.stem_element(day_stem), WuXing.stem_element(other_stem))
	if group.is_empty():
		return ""
	var same := WuXing.stem_polarity(day_stem) == WuXing.stem_polarity(other_stem)
	return TEN_GODS[group][0 if same else 1]

static func hour_stem(day_stem: String, hour_branch: String) -> String:
	var branch_index := WuXing.BRANCH_ORDER.find(hour_branch)
	if not HOUR_STEM_BASE.has(day_stem) or branch_index < 0:
		return ""
	var base := WuXing.STEMS.find(HOUR_STEM_BASE[day_stem])
	return WuXing.STEMS[(base + branch_index) % WuXing.STEMS.size()]

static func body_strength(day_stem: String, month_branch: String, hour_branch: String) -> float:
	var day_element := WuXing.stem_element(day_stem)
	var month: Dictionary = BRANCHES.get(month_branch, {})
	var hour: Dictionary = BRANCHES.get(hour_branch, {})
	if day_element.is_empty() or month.is_empty() or hour.is_empty():
		return 0.0
	var strength: float = MONTH_STRENGTH[element_group(day_element, month.element)]
	for element in [WuXing.stem_element(BASE_PILLAR[0]), BRANCHES[BASE_PILLAR[1]].element,
			WuXing.stem_element(hour_stem(day_stem, hour_branch)), hour.element]:
		strength += float(PILLAR_STRENGTH[element_group(day_element, element)])
	return clampf(strength, -1.0, 1.0)

static func affinity(weights: Dictionary, day_stem: String, strength: float) -> float:
	var day_element := WuXing.stem_element(day_stem)
	if weights.is_empty() or day_element.is_empty():
		return 1.0
	var s := clampf(strength, -1.0, 1.0)
	var endpoints := F_WEAK if s < 0.0 else F_STRONG
	var result := 0.0
	var uniform := true
	for element in WuXing.WUXING:
		var weight: float = weights.get(element, 0.0)
		uniform = uniform and is_equal_approx(weight, 1.0 / WuXing.WUXING.size())
		result += weight * lerpf(1.0, endpoints[element_group(day_element, element)], absf(s))
	# 五行均分遵循契合守恒，其余装备吃中和补偿。
	return 1.0 if uniform else result * (1.0 + ZHONGHE_K * (1.0 - absf(s)))
