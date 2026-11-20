extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Materials = preload("res://scripts/rules/materials.gd")
const Forge = preload("res://scripts/rules/forge_rules.gd")
const Bazi = preload("res://scripts/rules/bazi.gd")
const Origins = preload("res://scripts/rules/origins.gd")
const PARAMS := Forge.SHENG_KE_PARAMS

# 只求值。物料消耗、炉格校验和实际退款由调用方处理。
static func derive(item: Dictionary, forge_level: int,
		ling: String = "", character: Dictionary = {}) -> Dictionary:
	var slot: String = item.get("slot", "weapon")
	var result := {
		"stats": {}, "triggers": [], "clash": {}, "wuxing": {}, "yin_yang": 0.0, "purity": 0.0,
		"budget": 0.0, "jingyu": {}, "q": 1.0, "shi": 1.0, "f": 1.0, "name": item.get("name", ""), "steps": []
	}
	if not Forge.FORM_MATRIX.has(slot) or not Forge.FORGE_TIERS.has(forge_level):
		return result

	var process: Array = item.get("process", [])
	var merged: Dictionary = item.get("merged", {})
	var charge := _charge(item) if merged.is_empty() else merged
	var input_purity: float = charge.purity
	if input_purity <= 0.0:
		return result
	var tier: Dictionary = Forge.FORGE_TIERS[forge_level]
	var capped := minf(input_purity, tier.cap)
	var fine := process.has("forge_fine")
	var budget_scale: float = Forge.PROCESSES.forge_fine.budget if fine else Forge.PROCESSES.forge_rough.budget
	var p0 := capped * budget_scale
	var rotation := posmod(int(item.get("rotation", 0)), WuXing.WUXING.size())
	var original_weights := _normalize(_rotate(charge.wuxing, rotation))
	var weights := _remove_impurities(original_weights, item.get("sealed_element", "") if process.has("seal") else "")
	var residue := maxf(input_purity - capped, 0.0) * float(PARAMS.overflow_refund)
	for element in original_weights:
		if not weights.has(element):
			residue += capped * float(original_weights[element])
	result.steps.append({"id": "charge", "purity": input_purity, "cap": tier.cap, "base_budget": p0, "residue": residue})
	if weights.is_empty():
		return result

	var y := _processed_polarity(charge.yin_yang, process)
	var highest: float = weights.values().max()
	var zhou := weights.size() == WuXing.WUXING.size() and highest <= float(PARAMS.zhoutian_max)
	var chain := _chain_length(weights)
	var interactions := {"weights": weights, "loss": 0.0, "share": 0.0, "source": ""}
	if merged.is_empty():
		interactions = _settle(weights, process.has("harmonize"), zhou)
	weights = interactions.weights
	var dominant := _dominant_element(weights)
	var purity: float = weights[dominant]
	var m := 1.0 if zhou else 0.70 + 0.60 * purity
	var a := 0.95 + 0.30 * absf(y)
	var b: float = Forge.CHAIN_BONUS[5 if zhou else chain]
	if WuXing.is_taiji(y):
		b *= Forge.TAIJI_BONUS
	var roll := 1.0
	if process.has("forge_rough") and not fine:
		var uid: String = item.get("uid", "")
		var variance: float = Forge.PROCESSES.forge_rough.variance
		roll = 1.0 + lerpf(-variance, variance, float(uid.hash() & 0xffff) / 65535.0)
	result.steps.append({"id": "interactions", "wuxing": weights.duplicate(), "chain": chain,
		"zhoutian": zhou, "loss": interactions.loss, "clash_share": interactions.share})

	var environment := _environment(weights, ling, bool(character.get("relief", false)))
	var s := WuXing.shi(y, ling)
	var f := _affinity(weights, character)
	var contextual: float = f * environment.q * s
	var quality := m * a * b * roll * contextual
	var budget := p0 * (1.0 - float(interactions.loss))
	var alloc := budget * (1.0 - float(interactions.share))
	result.steps.append({"id": "multipliers", "m": m, "a": a, "b": b, "f": f, "q": environment.q, "shi": s, "roll": roll})

	var sockets: Array = item.get("sockets", [])
	var etched := process.has("engrave")
	var triggers := _triggers(sockets, slot, dominant, y, alloc, etched)
	var stat_budget := alloc
	for trigger in triggers:
		stat_budget -= float(trigger.budget)
	var stats := _stats(slot, weights, y, stat_budget * quality, float(tier.cap) * 1.30 * 1.25 * contextual)
	if etched and not stats.is_empty():
		var removed: String = item.get("engraved_stat", "")
		if not stats.has(removed):
			removed = stats.find_key(stats.values().min())
		stats.erase(removed)
	var clash := {}
	if interactions.share > 0.0:
		var source: String = interactions.source
		clash = Forge.CLASH_EFFECTS[source].duplicate()
		clash.merge({"source": source, "target": WuXing.KE[source],
			"strength": budget * float(interactions.share) * quality * float(PARAMS.clash_power)})

	result.steps.append({"id": "allocation", "budget": budget, "clash_budget": budget - alloc,
		"socket_budget": alloc - stat_budget, "stat_budget": stat_budget})
	result.merge({"stats": stats, "triggers": triggers, "clash": clash, "wuxing": weights,
		"yin_yang": y, "purity": purity, "budget": budget, "jingyu": environment.jingyu,
		"q": environment.q, "shi": s, "f": f}, true)
	if result.name.is_empty():
		result.name = _name(item, slot, weights, dominant, purity, y, chain, zhou, clash, triggers)
	return result

static func _charge(item: Dictionary) -> Dictionary:
	var quantities: Dictionary = item.get("materials", {})
	var energy := {}
	var purity := 0.0
	var polarity := 0.0
	# 固定遍历顺序，避免投料字典顺序改变浮点结算。
	var ids := quantities.keys()
	ids.sort()
	for id in ids:
		var key := Materials.key_of(id)
		var count: float = quantities[id]
		if key.is_empty() or count <= 0.0 or not is_finite(count):
			continue
		var material: Dictionary = Materials.MATERIALS[key]
		var vector: Dictionary = material.wuxing
		var material_y: float = material.yin_yang
		if key == "relic_core":
			var core: Dictionary = item.get("relic_core", {})
			vector = _normalize(core.get("wuxing", {}))
			material_y = clampf(core.get("yin_yang", 0.0), -1.0, 1.0)
		if vector.is_empty():
			continue
		var amount := float(material.purity) * count
		purity += amount
		polarity += amount * material_y
		for element in vector:
			energy[element] = float(energy.get(element, 0.0)) + amount * float(vector[element])
	return {"purity": purity, "wuxing": energy, "yin_yang": polarity / purity if purity > 0.0 else 0.0}

static func _normalize(vector: Dictionary) -> Dictionary:
	var weights := {}
	var total := 0.0
	for element in WuXing.WUXING:
		var value: float = vector.get(element, 0.0)
		if value > 0.0 and is_finite(value):
			weights[element] = value
			total += value
	for element in weights:
		weights[element] /= total
	return weights

static func _rotate(vector: Dictionary, count: int) -> Dictionary:
	var rotated := {}
	for element in vector:
		var target: String = element
		for step in range(count):
			target = WuXing.SHENG[target]
		rotated[target] = vector[element]
	return rotated

static func _remove_impurities(weights: Dictionary, sealed_element: String) -> Dictionary:
	var kept := {}
	for element in weights:
		if element != sealed_element and float(weights[element]) >= float(PARAMS.impurity):
			kept[element] = weights[element]
	return _normalize(kept)

static func _processed_polarity(value: float, process: Array) -> float:
	for id in process:
		match id:
			"forge_yang", "quench_yin":
				value = clampf(value + float(Forge.PROCESSES[id].yin_yang_delta), -1.0, 1.0)
			"reverse_yin_yang":
				value *= float(Forge.PROCESSES[id].yin_yang_multiplier)
	return value

static func _chain_length(weights: Dictionary) -> int:
	var longest := 1
	for start in weights:
		var length := 0
		var element: String = start
		for step in range(WuXing.WUXING.size()):
			if float(weights.get(element, 0.0)) < float(PARAMS.pair_min):
				break
			length += 1
			element = WuXing.SHENG[element]
		longest = maxi(longest, length)
	return longest

static func _settle(weights: Dictionary, harmonize: bool, zhou: bool) -> Dictionary:
	# 同一轮的生对共享同一快照，克对用相生归一化后的权重。
	var generated := weights.duplicate()
	for mother in WuXing.WUXING:
		var child: String = WuXing.SHENG[mother]
		var pair := minf(weights.get(mother, 0.0), weights.get(child, 0.0))
		if pair >= float(PARAMS.pair_min):
			generated[child] += pair * float(PARAMS.child_gain)
			generated[mother] -= pair * float(PARAMS.mother_loss)
	generated = _normalize(generated)
	var suppressed := generated.duplicate()
	var loss := 0.0
	var strongest := 0.0
	var source := ""
	for attacker in WuXing.WUXING:
		var victim: String = WuXing.KE[attacker]
		var pair := minf(generated.get(attacker, 0.0), generated.get(victim, 0.0))
		if pair < float(PARAMS.pair_min):
			continue
		suppressed[victim] -= pair * float(PARAMS.ke_loss)
		if zhou:
			continue
		if harmonize:
			if pair > strongest:
				strongest = pair
				source = attacker
		else:
			loss += pair * float(PARAMS.dissipation)
	return {"weights": _normalize(suppressed), "loss": loss,
		"share": strongest * float(PARAMS.harmonize_share), "source": source}

# relief 为真时死位按囚位计 —— 驻留行善换来的下一层减益豁免（docs/story.md §1.2）。
static func _environment(weights: Dictionary, ling: String, relief: bool = false) -> Dictionary:
	var element := WuXing.stem_element(ling)
	if element.is_empty():
		return {"jingyu": {}, "q": 1.0}
	var states := {}
	var q := 0.0
	for key in WuXing.WUXING:
		var state := WuXing.jingyu(key, element)
		if relief and state == "si":
			state = "qiu"
		states[key] = WuXing.JINGYU_NAMES[state]
		q += float(weights.get(key, 0.0)) * float(WuXing.JINGYU[state])
	return {"jingyu": states, "q": q}

static func _affinity(weights: Dictionary, character: Dictionary) -> float:
	var stem: String = character.get("day_stem", "")
	if stem.is_empty():
		return 1.0
	if character.has("s"):
		return Bazi.affinity(weights, stem, character.s)
	var strength := Bazi.body_strength(stem, character.get("month_branch", ""), character.get("hour_branch", ""))
	var origin: Dictionary = Origins.ORIGINS.get(character.get("origin", ""), {})
	return Bazi.affinity(weights, stem, strength * float(origin.get("strength_multiplier", 1.0)))

static func _dominant_element(weights: Dictionary) -> String:
	var dominant: String = weights.keys()[0]
	for element in weights:
		if float(weights[element]) > float(weights[dominant]):
			dominant = element
	return dominant

static func _triggers(sockets: Array, slot: String, element: String, polarity: float,
		alloc: float, etched: bool) -> Array[Dictionary]:
	var triggers: Array[Dictionary] = []
	var stems: Array[String] = []
	for socket in sockets:
		if triggers.size() >= Forge.SOCKET_TAX.size():
			break
		if not Forge.TRIGGER_ACTIONS.has(socket) or stems.has(socket):
			continue
		var tax := alloc * float(Forge.SOCKET_TAX[triggers.size()])
		var conditions: Array = Forge.TRIGGER_CONDITIONS[slot][element]
		var action: Dictionary = Forge.TRIGGER_ACTIONS[socket]
		var boost: float = Forge.PROCESSES.engrave.trigger_multiplier if etched else 1.0
		triggers.append({"stem": socket, "condition": conditions[0 if polarity >= 0.0 else 1],
			"action": action.duplicate(), "budget": tax, "strength": tax * boost})
		stems.append(socket)
	return triggers

static func _stats(slot: String, weights: Dictionary, y: float, scaled_budget: float,
		pure_stat_budget: float) -> Dictionary:
	var raw := {}
	var yin_yang_split := [(1.0 + y) * 0.5, (1.0 - y) * 0.5]
	for element in weights:
		var forms: Array = Forge.FORM_MATRIX[slot][element]
		for index in range(forms.size()):
			var stat: String = forms[index]
			var k := float(Forge.STAT_WEIGHTS.get(stat, 1.0))
			var value := scaled_budget * float(weights[element]) * float(yin_yang_split[index]) * k
			raw[stat] = float(raw.get(stat, 0.0)) + value
	var stats := {}
	for stat in raw:
		var value: float = raw[stat]
		assert(value <= 1.5 * pure_stat_budget * float(Forge.STAT_WEIGHTS.get(stat, 1.0)),
			"装备属性超过炉温理论上限：%s" % stat)
		# §9 的锐形攻击、攻速点和吸血保留一位，太极的双形条目取整。
		var decimal_points: bool = not WuXing.is_taiji(y) and stat in ["attack", "attack_speed", "lifesteal"]
		var points := snappedf(value, 0.1) if decimal_points else roundf(value)
		if points > 0.0:
			stats[stat] = points
	return stats

static func _name(item: Dictionary, slot: String, weights: Dictionary, dominant: String, purity: float,
		y: float, chain: int, zhou: bool, clash: Dictionary, triggers: Array[Dictionary]) -> String:
	var parts := Forge.NAME_PARTS
	var form: String = parts.slots[slot]
	if slot == "weapon":
		form = parts.weapons.get(item.get("weapon_form", ""), form)
	var prefix := ""
	if zhou:
		prefix = parts.zhoutian + "·"
	if WuXing.is_taiji(y):
		prefix += parts.taiji + "·"
	var body := ""
	if purity >= float(parts.pure_min):
		# 名字里只写阴阳与行，不写天干 —— 天干是内部索引，玩家不该靠认字读装备。
		body = parts.pure
		if not WuXing.is_taiji(y):
			body += "阳" if y > 0.0 else "阴"
		body += WuXing.ELEMENT_NAMES[dominant]
	elif not zhou:
		var ordered := weights.keys()
		ordered.sort_custom(func(left: String, right: String) -> bool: return weights[left] > weights[right])
		for element in ordered:
			body += WuXing.ELEMENT_NAMES[element]
	if not clash.is_empty():
		return prefix + body + parts.clash + form + "·" + clash.name
	if chain > 1 and not zhou:
		body += parts.sheng
	var suffix := "·" + String(triggers[0].action.name) if not triggers.is_empty() else ""
	return prefix + body + form + suffix

# 产出新的装备输入。熔合混合成品行向量，磨损沿双方较高值累积。
static func merge_items(a: Dictionary, b: Dictionary, forge_level: int, sockets: Array = []) -> Dictionary:
	var first := derive(a, forge_level)
	var second := derive(b, forge_level)
	if first.budget <= 0.0 or second.budget <= 0.0:
		return {}
	var process: Dictionary = Forge.PROCESSES["merge"]
	var wear := maxi(0, maxi(int(a.get("wear", 0)), int(b.get("wear", 0))))
	var total: float = first.budget + second.budget
	var energy := {}
	for element in WuXing.WUXING:
		energy[element] = float(first.wuxing.get(element, 0.0)) * float(first.budget) \
			+ float(second.wuxing.get(element, 0.0)) * float(second.budget)
	var cap: float = Forge.FORGE_TIERS[forge_level].cap
	var budget := minf(cap, maxf(first.budget, second.budget)
		+ float(process.secondary_budget) * minf(first.budget, second.budget) * pow(process.decay, wear))
	var retained: Array[String] = []
	for socket in sockets:
		if retained.size() == Forge.SOCKET_TAX.size():
			break
		if retained.has(socket):
			continue
		for trigger in first.triggers + second.triggers:
			if trigger.stem == socket:
				retained.append(socket)
				break
	return {"slot": a.get("slot", "weapon"), "weapon_form": a.get("weapon_form", ""), "wear": wear + int(process.wear),
		"sockets": retained, "merged": {"purity": budget, "wuxing": _normalize(energy),
			"yin_yang": (float(first.yin_yang) * float(first.budget) + float(second.yin_yang) * float(second.budget)) / total}}
