extends RefCounted

# 每格按阳形、阴形排列。stats 返回点数，软上限在汇总装备后应用。
const FORM_MATRIX := {
	"weapon": {"jin": ["attack", "crit"], "mu": ["lifesteal", "venom"], "shui": ["impact", "chill"],
		"huo": ["attack_speed", "burn"], "tu": ["armor_break", "pressure"]},
	"armor": {"jin": ["armor", "deflect"], "mu": ["hp", "regeneration"], "shui": ["mana", "dodge"],
		"huo": ["fire_resist", "scorch_armor"], "tu": ["shield", "mitigation"]},
	"gloves": {"jin": ["attack", "crit_damage"], "mu": ["healing", "spread"], "shui": ["cooldown", "mana_regen"],
		"huo": ["skill_damage", "ignite"], "tu": ["stability", "thorns"]},
	"charm": {"jin": ["block", "keen_sight"], "mu": ["hp", "vitality"], "shui": ["mana", "mana_regen"],
		"huo": ["elemental_power", "burn_damage"], "tu": ["armor", "encumbrance"]},
	"ring": {"jin": ["penetration", "crit"], "mu": ["kill_heal", "drain"], "shui": ["move_speed", "slow_power"],
		"huo": ["crit_damage", "ignite_cap"], "tu": ["hp", "energy_absorb"]},
	"boots": {"jin": ["stability", "keen_step"], "mu": ["hp", "run_heal"], "shui": ["move_speed", "dodge_cooldown"],
		"huo": ["dash_distance", "fire_trail"], "tu": ["knockback_resist", "stomp"]}
}
const STAT_WEIGHTS := {
	"attack": 1.00, "hp": 3.00, "mana": 2.50, "shield": 2.20, "regeneration": 0.45,
	"armor": 1.20, "stability": 0.80, "elemental_power": 0.50,
	"burn": 0.80, "venom": 0.70, "armor_break": 0.70, "impact": 0.60, "pressure": 0.55,
	"chill": 0.50, "move_speed": 0.50, "dodge": 0.30,
	"thorns": 1.20, "lifesteal": 0.15, "kill_heal": 0.30, "crit": 0.40, "crit_damage": 1.50,
	"attack_speed": 0.45, "cooldown": 0.40, "block": 0.40
}
const STAT_CURVES := {
	"armor": [120.0, 0.75], "crit": [100.0, 0.75], "attack_speed": [60.0, 0.60],
	"move_speed": [80.0, 0.60], "armor_break": [100.0, 0.60], "penetration": [100.0, 0.60],
	"block": [110.0, 0.60], "dodge": [140.0, 0.50], "cooldown": [150.0, 0.50],
	"dodge_cooldown": [150.0, 0.50]
}
const FORGE_TIERS := {
	1: {"cap": 18, "slots": 6}, 2: {"cap": 30, "slots": 8}, 3: {"cap": 48, "slots": 10},
	4: {"cap": 72, "slots": 12}, 5: {"cap": 100, "slots": 12}, 6: {"cap": 135, "slots": 12}
}
const SHENG_KE_PARAMS := {
	"impurity": 0.08, "pair_min": 0.15, "zhoutian_max": 0.35, "overflow_refund": 0.60,
	"child_gain": 0.50, "mother_loss": 0.15, "ke_loss": 0.60, "dissipation": 0.25,
	"harmonize_share": 0.85, "clash_power": 1.50
}
const CHAIN_BONUS := {1: 1.00, 2: 1.08, 3: 1.15, 4: 1.25, 5: 1.35}
const TAIJI_BONUS := 1.22
const SOCKET_TAX := [0.15, 0.25]

# 相激按克者索引，受克行从 KE 表推出。
const CLASH_EFFECTS := {
	"shui": {"id": "steam", "name": "蒸汽", "chance": 0.20, "aoe_damage_scale": 2.5, "blind_seconds": 1.0},
	"huo": {"id": "corrode", "name": "熔蚀", "armor_loss_scale": 0.0015, "max_stacks": 5, "dispellable": false},
	"jin": {"id": "rend", "name": "裂伐", "moving_bleed_per_second_scale": 0.35},
	"mu": {"id": "root", "name": "根裂", "chance": 0.15, "root_seconds": 1.2, "life_drain_scale": 0.5},
	"tu": {"id": "mire", "name": "淤塞", "slow": 0.45, "blocks_recovery": true, "duration_scale": 0.06}
}
const TRIGGER_CONDITIONS := {
	"weapon": {"jin": ["每第 3 击", "暴击时"], "mu": ["击杀时", "目标中毒时"],
		"shui": ["击退目标时", "命中被减速目标时"], "huo": ["攻速满时", "目标燃烧时"],
		"tu": ["破甲命中时", "目标被重压时"]},
	"armor": {"jin": ["受击时", "格挡成功时"], "mu": ["生命回满时", "再生中时"],
		"shui": ["灵力满时", "闪避成功时"], "huo": ["受火伤时", "周身 3 敌时"],
		"tu": ["护盾破裂时", "受致命伤时（每局 1 次）"]},
	"gloves": {"jin": ["连续命中 5 次", "背击时"], "mu": ["治疗生效时", "蔓延时"],
		"shui": ["冷却结束时", "灵力低于 30%"], "huo": ["释放技能时", "引燃时"],
		"tu": ["抗住打断时", "荆棘触发时"]},
	"charm": {"jin": ["战斗开始时", "首次命中时"], "mu": ["拾取材料时", "脱战 1 秒后"],
		"shui": ["消耗灵力时", "回蓝时"], "huo": ["暴击时", "点燃叠满时"],
		"tu": ["生命低于 50%", "受击累计 10 次"]},
	"ring": {"jin": ["穿甲生效时", "连续暴击 2 次"], "mu": ["击杀回血时", "汲取生效时"],
		"shui": ["冲刺时", "目标被减速时"], "huo": ["暴伤触发时", "目标燃烧 3 层"],
		"tu": ["生命回复时", "受击回蓝时"]},
	"boots": {"jin": ["被击退时", "背后接近敌人时"], "mu": ["奔跑 2 秒后", "静止 1 秒后"],
		"shui": ["移速满时", "后撤后"], "huo": ["冲刺穿敌时", "踩过燃迹时"],
		"tu": ["落地时", "脱离定身时"]}
}
const TRIGGER_ACTIONS := {
	"jia": {"id": "heal", "name": "回复生命", "heal_scale": 1.8},
	"yi": {"id": "entangle", "name": "缠绕", "slow": 0.60, "drain_per_second_scale": 0.5, "seconds": 3.0},
	"bing": {"id": "flare", "name": "爆燃", "aoe_damage_scale": 2.2},
	"ding": {"id": "ignite", "name": "点燃", "damage_per_second_scale": 0.6, "seconds": 3.0},
	"wu": {"id": "shield", "name": "获得护盾", "shield_scale": 2.5},
	"ji": {"id": "absorb", "name": "化伤为灵力", "absorb_scale": 1.2},
	"geng": {"id": "armor_break", "name": "破甲", "armor_loss_scale": 0.008},
	"xin": {"id": "pierce", "name": "穿刺", "damage_scale": 0.04, "guaranteed_crit": true},
	"ren": {"id": "flush", "name": "冲刷", "knockback_scale": 1.0, "dispels_buffs": true},
	"gui": {"id": "freeze", "name": "冰缓／冻结", "slow": 0.40, "duration_scale": 0.05}
}

const PATTERNS := {
	"yiqi": {"name": "一气格", "min_weight": 0.55, "element_bonus": 0.15, "wang_bonus": 0.10, "si_bonus": -0.10},
	"xiangsheng": {"name": "相生格", "min_chain": 3, "min_weight": 0.15, "element_bonus": 0.08, "damage_to_mana": 0.10},
	"zhoutian": {"name": "周天格", "min_weight": 0.08, "max_weight": 0.35, "stat_bonus": 0.10, "feeding_multiplier": 0.50},
	"xiangzhan": {"name": "相战格", "min_weight": 0.30, "clash_bonus": 0.40, "hp_bonus": -0.10},
	"chunyang": {"name": "纯阳格", "min_yin_yang": 0.60, "form_bonus": 0.12, "crit_damage_bonus": 0.15, "incoming_yin_dot": 0.15},
	"chunyin": {"name": "纯阴格", "max_yin_yang": -0.60, "form_bonus": 0.12, "dot_bonus": 0.20, "incoming_yang_burst": 0.15},
	"taiji": {"name": "太极格", "max_abs_yin_yang": 0.15, "stat_bonus": 0.08, "yin_yang_damage_floor": 1.00}
}
const PROCESSES := {
	"forge_rough": {"name": "粗锻", "budget": 1.0, "variance": 0.20},
	"forge_fine": {"name": "精锻", "budget": 0.90, "extra_matching_high_tier": 1},
	"harmonize": {"name": "调和", "max_clashes": 1},
	"seal": {"name": "封印", "fixed_fee": true},
	"forge_yang": {"name": "刚锻", "yin_yang_delta": 0.25},
	"quench_yin": {"name": "柔淬", "yin_yang_delta": -0.25},
	"reverse_yin_yang": {"name": "阴阳返", "yin_yang_multiplier": -1.0, "relic_core_cost": 1},
	"rotate": {"name": "五行轮转", "wear": 1},
	"merge": {"name": "合炉", "wear": 1, "secondary_budget": 0.45, "decay": 0.80},
	"engrave": {"name": "刻纹", "trigger_multiplier": 1.50, "removed_stats": 1, "relic_core_cost": 1}
}
const NAME_PARTS := {
	"pure": "纯", "pure_min": 0.80, "sheng": "相生", "clash": "相激",
	"taiji": "太极", "zhoutian": "周天", "xiangzhan": "相战",
	"slots": {"weapon": "刃", "armor": "甲", "gloves": "护手", "charm": "佩", "ring": "戒", "boots": "履"},
	"weapons": {"long_blade": "长刃", "hammer": "重锤", "bow": "长弓", "staff": "法杖", "dual_blades": "双刀"}
}

static func stat_value(stat: String, points: float) -> float:
	if not STAT_CURVES.has(stat):
		return points
	var curve: Array = STAT_CURVES[stat]
	var positive := maxf(0.0, points)
	return minf(positive / (positive + float(curve[0])), float(curve[1]))
