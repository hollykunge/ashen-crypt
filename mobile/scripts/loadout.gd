extends RefCounted

const Rules = preload("res://scripts/rules/forge_rules.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const Bazi = preload("res://scripts/rules/bazi.gd")
const Origins = preload("res://scripts/rules/origins.gd")

const STAT_NAMES := {
	"attack": "物理攻击", "crit": "暴击", "lifesteal": "吸血", "venom": "中毒", "impact": "冲击", "chill": "冰冻减速",
	"attack_speed": "攻速", "burn": "灼烧", "armor_break": "破甲", "pressure": "重压", "armor": "减伤",
	"deflect": "反击", "hp": "生命上限", "regeneration": "生命再生", "mana": "灵力上限", "dodge": "闪避",
	"fire_resist": "抗火", "scorch_armor": "反烧", "shield": "护盾", "mitigation": "免伤", "crit_damage": "暴击伤害",
	"healing": "治疗效果", "spread": "治疗扩散", "cooldown": "冷却缩减", "mana_regen": "灵力回复",
	"skill_damage": "技能伤害", "ignite": "引燃", "stability": "抗打断", "thorns": "荆棘", "block": "格挡",
	"keen_sight": "视野", "vitality": "体质", "elemental_power": "元素强度", "burn_damage": "燃伤加成",
	"encumbrance": "负重", "penetration": "穿甲", "kill_heal": "击杀回血", "drain": "吸取生命", "move_speed": "移速",
	"slow_power": "减速强度", "ignite_cap": "点燃上限", "energy_absorb": "吸取灵力", "keen_step": "稳步",
	"run_heal": "奔跑回血", "dodge_cooldown": "后撤冷却", "dash_distance": "冲刺距离", "fire_trail": "火焰足迹",
	"knockback_resist": "抗击退", "stomp": "踩踏"
}
const GROUP_NAMES := {"bi": "比劫", "yin": "印", "shishang": "食伤", "cai": "财", "guansha": "官杀"}

static func strength(character: Dictionary) -> float:
	var origin: Dictionary = Origins.ORIGINS.get(character.get("origin", ""), {})
	return Bazi.body_strength(character.get("day_stem", ""), character.get("month_branch", ""),
		character.get("hour_branch", "")) * float(origin.get("strength_multiplier", 1.0))

static func dominant(weights: Dictionary) -> String:
	var key := ""
	for element in WuXing.WUXING:
		if float(weights.get(element, 0.0)) > float(weights.get(key, 0.0)):
			key = element
	return key

static func fit_group(stem: String, element: String, power: float) -> int:
	var group := Bazi.element_group(WuXing.stem_element(stem), element)
	if is_zero_approx(power) or not Bazi.F_WEAK.has(group):
		return 0
	var endpoints := Bazi.F_WEAK if power < 0.0 else Bazi.F_STRONG
	return 1 if float(endpoints[group]) > 1.0 else -1

static func badge(derived: Dictionary, person: Dictionary) -> Dictionary:
	var element := dominant(derived.wuxing)
	if element.is_empty():
		return {"text": "—", "fit": 0}
	var day_stem: String = person.day_stem
	var stem := WuXing.stem_for(element, derived.yin_yang)
	var god: Dictionary = Bazi.GOD_EFFECTS[Bazi.ten_god(day_stem, stem)]
	var fit := fit_group(day_stem, element, strength(person))
	return {"text": "%s  Q %.2f  ·  %s  F %.2f" % [derived.jingyu[element], derived.q, god.name, derived.f],
		"fit": fit, "danger": derived.jingyu[element] == "死"}

static func summarize(entries: Dictionary, character: Dictionary, ling: String) -> Dictionary:
	var total := 0.0
	var polarity := 0.0
	var weights := {}
	for element in WuXing.WUXING:
		weights[element] = 0.0
	for entry in entries.values():
		var weight: float = entry.budget
		total += weight
		polarity += float(entry.yin_yang) * weight
		for element in entry.wuxing:
			weights[element] += float(entry.wuxing[element]) * weight
	if total > 0.0:
		polarity /= total
		for element in weights:
			weights[element] /= total
	var pattern: Dictionary = _patterns(weights, polarity, character) if total > 0.0 else {}
	return {"entries": entries, "weights": weights, "yin_yang": polarity, "patterns": pattern, "ling": ling}

static func _patterns(weights: Dictionary, y: float, character: Dictionary) -> Dictionary:
	var rules := Rules.PATTERNS
	var origin: Dictionary = Origins.ORIGINS.get(character.get("origin", ""), {})
	var result := {}
	var main := dominant(weights)
	if weights[main] >= rules.yiqi.min_weight:
		result["yiqi"] = [main]
	var longest: Array[String] = []
	for start in WuXing.WUXING:
		var chain: Array[String] = []
		var element: String = start
		for step in range(WuXing.WUXING.size()):
			if weights[element] < rules.xiangsheng.min_weight:
				break
			chain.append(element)
			element = WuXing.SHENG[element]
		if chain.size() > longest.size():
			longest = chain
	if longest.size() >= rules.xiangsheng.min_chain:
		result["xiangsheng"] = longest
	if weights.values().min() >= rules.zhoutian.min_weight and weights[main] <= origin.get("zhoutian_max", rules.zhoutian.max_weight):
		result["zhoutian"] = []
	for attacker in WuXing.WUXING:
		if minf(weights[attacker], weights[WuXing.KE[attacker]]) >= rules.xiangzhan.min_weight:
			result["xiangzhan"] = [attacker, WuXing.KE[attacker]]
			break
	if y >= rules.chunyang.min_yin_yang:
		result["chunyang"] = []
	elif y <= rules.chunyin.max_yin_yang:
		result["chunyin"] = []
	elif absf(y) <= origin.get("taiji_max_abs", rules.taiji.max_abs_yin_yang):
		result["taiji"] = []
	return result

static func pattern_names(patterns: Dictionary) -> String:
	var names := PackedStringArray()
	for key in patterns:
		names.append(Rules.PATTERNS[key].name)
	return " · ".join(names) if not names.is_empty() else "未成格"

static func _stat_pattern_bonus(stat: String, slot: String, entry: Dictionary, patterns: Dictionary,
		ling_element: String) -> float:
	var rules := Rules.PATTERNS
	var common := 0.0
	if patterns.has("zhoutian"):
		common += float(rules.zhoutian.stat_bonus)
	if patterns.has("taiji"):
		common += float(rules.taiji.stat_bonus)
	var total := 0.0
	var adjusted := 0.0
	for element in entry.wuxing:
		var forms: Array = Rules.FORM_MATRIX[slot][element]
		for index in range(2):
			if forms[index] != stat:
				continue
			var fraction := (1.0 + float(entry.yin_yang) * (1.0 if index == 0 else -1.0)) * 0.5
			var weight := float(entry.wuxing[element]) * fraction
			var bonus := common
			if patterns.get("yiqi", []).has(element):
				bonus += float(rules.yiqi.element_bonus)
				match WuXing.jingyu(element, ling_element):
					"wang": bonus += float(rules.yiqi.wang_bonus)
					"si": bonus += float(rules.yiqi.si_bonus)
			if patterns.get("xiangsheng", []).has(element):
				bonus += float(rules.xiangsheng.element_bonus)
			if index == 0 and patterns.has("chunyang"):
				bonus += float(rules.chunyang.form_bonus)
			if index == 1 and patterns.has("chunyin"):
				bonus += float(rules.chunyin.form_bonus)
			adjusted += weight * (1.0 + bonus)
			total += weight
	return adjusted / total if total > 0.0 else 1.0

static func bonuses(loadout: Dictionary, person: Dictionary, layer: int) -> Dictionary:
	var points := {}
	var clash: Array[Dictionary] = []
	var triggers: Array[Dictionary] = []
	var ling_element := WuXing.stem_element(loadout.ling)
	var patterns: Dictionary = loadout.patterns
	for slot in loadout.entries:
		var entry: Dictionary = loadout.entries[slot]
		for stat in entry.stats:
			var contribution := float(entry.stats[stat]) * _stat_pattern_bonus(stat, slot, entry, patterns, ling_element)
			points[stat] = float(points.get(stat, 0.0)) + contribution
		if not entry.clash.is_empty():
			var effect: Dictionary = entry.clash.duplicate()
			if patterns.has("xiangzhan"):
				effect.strength *= 1.0 + float(Rules.PATTERNS.xiangzhan.clash_bonus)
			clash.append(effect)
		for trigger in entry.triggers:
			var effect: Dictionary = trigger.duplicate()
			effect.slot = slot
			triggers.append(effect)

	var stats := {}
	for stat in points:
		var value := Rules.stat_value(stat, points[stat])
		stats[stat] = value * 100.0 if Rules.STAT_CURVES.has(stat) else value
	stats.speed = stats.get("move_speed", 0.0)
	stats.regen = stats.get("mana_regen", 0.0)
	stats.dodge_ms = float(stats.get("dodge_cooldown", 0.0)) * 13.5
	stats.clashes = clash
	stats.triggers = triggers
	var weapon: Dictionary = loadout.entries.get("weapon", {})
	var weapon_weights: Dictionary = weapon.get("wuxing", {})
	stats.weapon_matchup = WuXing.weighted_clash(weapon_weights, ling_element) * WuXing.yin_yang(
		float(weapon.get("yin_yang", 0.0)), WuXing.stem_polarity(loadout.ling))
	var feeding_source := String(WuXing.SHENG.find_key(ling_element)) if WuXing.SHENG.values().has(ling_element) else ""
	var feeding_multiplier: float = Rules.PATTERNS.zhoutian.feeding_multiplier if patterns.has("zhoutian") else 1.0
	stats.feed_enemy_ratio = float(weapon_weights.get(feeding_source, 0.0)) * WuXing.FEED_HEAL_RATIO * feeding_multiplier
	stats.hp_multiplier = Origins.ORIGINS.get(person.get("origin", ""), {}).get("hp_multiplier", 1.0)
	stats.attack_multiplier = Origins.ORIGINS.get(person.get("origin", ""), {}).get("attack_multiplier", 1.0)
	if patterns.has("xiangzhan"):
		stats.hp_multiplier *= 1.0 + float(Rules.PATTERNS.xiangzhan.hp_bonus)
	var talent: Dictionary = Bazi.HOUR_TALENTS.get(person.get("hour_branch", ""), {})
	stats.crit = float(stats.get("crit", 0.0)) + 100.0 * float(talent.get("crit_bonus", 0.0))
	stats.hp_multiplier *= 1.0 + float(talent.get("hp_bonus", 0.0))
	stats.material_drop_multiplier = (1.0 + float(talent.get("material_drop_bonus", 0.0))) * float(
		Origins.ORIGINS.get(person.get("origin", ""), {}).get("material_drop_multiplier", 1.0))
	if person.get("origin", "") == "official":
		stats.companions = Origins.companions(person.day_stem, layer, bool(person.get("relief", false)))
		if stats.companions == 0:
			stats.attack_multiplier *= Origins.LONE_BONUS
	if patterns.has("chunyang"):
		stats.crit_damage = float(stats.get("crit_damage", 0.0)) + 100.0 * float(Rules.PATTERNS.chunyang.crit_damage_bonus)
	if patterns.has("chunyin"):
		stats.burn = float(stats.get("burn", 0.0)) * (1.0 + float(Rules.PATTERNS.chunyin.dot_bonus))
	return stats
