extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Bazi = preload("res://scripts/rules/bazi.gd")

const ORIGINS := {
	"official": {"name": "官宦", "attack_multiplier": 0.70, "hp_multiplier": 0.90, "starting_silver": 0,
		"unlocks": ["summon_companions", "stipend"], "stipend_tiers": [3, 4], "stipend_period": 10},
	"merchant": {"name": "富商", "attack_multiplier": 1.00, "hp_multiplier": 0.90, "starting_silver": 2000,
		"silver_drop_multiplier": 2.0, "material_drop_multiplier": 0.75,
		"unlocks": ["buy_materials", "exchange_stems", "buy_intel"]},
	"commoner": {"name": "普通人", "attack_multiplier": 0.85, "hp_multiplier": 1.20, "starting_silver": 0,
		"strength_multiplier": 0.60, "zhoutian_max": 0.40, "taiji_max_abs": 0.22,
		"starting_materials": {}, "unlocks": []},
	"pauper": {"name": "穷人", "attack_multiplier": 1.25, "hp_multiplier": 0.80, "starting_silver": 0,
		"residue_refund": 1.00, "rotation_wear": 0, "silver_drop_multiplier": 0.0,
		"blocked": ["shop", "summon_companions", "hire"], "unlocks": []}
}
const COMPANION_COUNT := {"guansha": 3, "yin": 2, "bi": 1, "shishang": 1, "cai": 0}
const COMPANION_MAX := 3
const COMPANION_DPS_RATIO := 0.38
const LONE_BONUS := 1.25
const SILVER_PRICES := {
	1: {"buy": 10, "sell": 4}, 2: {"buy": 25, "sell": 10}, 3: {"buy": 70, "sell": 28},
	4: {"buy": 200, "sell": 80}, 5: {"buy": 600, "sell": 240}
}
const SILVER_BUY_CAP := 6

# 随侍数看本层地气相对日干的十神；十层走满十干，所以各日干的分布完全一致。
# morale 为真时 +1（上限不变）—— 上一层驻留行善换来的士气。
static func companions(day_stem: String, layer: int, morale: bool = false) -> int:
	var group := Bazi.element_group(WuXing.stem_element(day_stem), WuXing.stem_element(WuXing.ling_of(layer)))
	var count: int = COMPANION_COUNT.get(group, 0)
	return mini(COMPANION_MAX, count + 1) if morale else count
