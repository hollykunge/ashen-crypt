extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Origins = preload("res://scripts/rules/origins.gd")

# TODO: 接入新档案时，将 v3 的旧材料折算为等值天干材料。
const SAVE_VERSION := 4
const STARTING_AGE := 20
const BASE_LIFESPAN := 70
const ZHOUTIAN_BASELINE := 1.0
const JIE_THRESHOLD_RATIO := 0.95
const JIE_THRESHOLD := ZHOUTIAN_BASELINE * JIE_THRESHOLD_RATIO

const REALMS := [
	{"name": "炼气", "layers": [1, 10], "jie": "mu", "yuan_qi": "木气归元", "forge_cap": 2, "sockets": 0, "lifespan_bonus": 20},
	{"name": "筑基", "layers": [11, 20], "jie": "huo", "yuan_qi": "火气归元", "forge_cap": 3, "sockets": 1, "lifespan_bonus": 20},
	{"name": "结丹", "layers": [21, 30], "jie": "tu", "yuan_qi": "土气归元", "forge_cap": 4, "sockets": 1, "lifespan_bonus": 20},
	{"name": "炼神", "layers": [31, 40], "jie": "jin", "yuan_qi": "金气归元", "forge_cap": 5, "sockets": 2, "lifespan_bonus": 20},
	{"name": "还虚", "layers": [41, 50], "jie": "shui", "yuan_qi": "水气归元", "forge_cap": 6, "sockets": 2, "lifespan_bonus": 20}
]
const WAITING := {"name": "待诏", "layers": [51, 60], "yuan_qi": "五气俱足", "forge_cap": 6, "sockets": 2}
const RULES := {
	"no_aid": {"realm": 1, "name": "不得以仙法济凡人", "penalty": {"realm_delta": -1}},
	"no_lifespan": {"realm": 2, "name": "不得延凡人之寿", "penalty": {"realm_delta": -1, "next_jie_threshold_bonus": 0.10}},
	"no_teach": {"realm": 3, "name": "不得泄露天机", "penalty": {"realm_delta": -1}},
	"no_refuse": {"realm": 4, "name": "不得抗敕", "penalty": {"harder_edict": true}},
	"sever": {"realm": 5, "name": "断绝尘缘", "penalty": {"blocks_ascension": true}}
}
const REBIRTH := {
	"realm_delta": -1, "equipment_refund": 1.0, "keep_materials": true, "keep_silver": true,
	"keep_year": true, "can_choose_destiny": true, "can_choose_origin": true, "voluntary": true,
	"wisdom_per_rebirth": 0.02, "wisdom_cap": 0.10
}
const FAMILY := {
	"father": {"name": "父亲", "death_layer": 18},
	"mother": {"name": "母亲", "death_layer": 26},
	"wife": {"name": "妻子", "death_layer": 44},
	"brother": {"name": "弟弟"}
}

static func lifespan(realms_completed: int) -> int:
	var years := BASE_LIFESPAN
	for index in range(clampi(realms_completed, 0, REALMS.size())):
		years += int(REALMS[index].lifespan_bonus)
	return years

static func jie_ling_of(layer: int) -> String:
	for realm in REALMS:
		if layer == realm.layers[1]:
			return WuXing.stem_for(realm.jie, 1.0)
	return ""

static func jie_threshold(baseline: float = ZHOUTIAN_BASELINE) -> float:
	return baseline * JIE_THRESHOLD_RATIO

# 生成 v4 档案数据，由调用方决定何时持久化。
static func new_profile(gender: String, day_stem: String, month_branch: String,
		hour_branch: String, origin: String) -> Dictionary:
	if gender not in ["male", "female"] or not WuXing.STEMS.has(day_stem) \
			or not WuXing.BRANCHES.has(month_branch) or not WuXing.BRANCHES.has(hour_branch) \
			or not Origins.ORIGINS.has(origin):
		return {}
	return {"version": SAVE_VERSION, "gender": gender, "day_stem": day_stem,
		"month_branch": month_branch, "hour_branch": hour_branch, "origin": origin,
		"silver": Origins.ORIGINS[origin].starting_silver, "realm": 1, "layer": 1,
		"rebirths": 0, "lifespan": BASE_LIFESPAN, "narrative": _new_narrative()}

# 每个新档案建立独立的叙事记录。
static func _new_narrative() -> Dictionary:
	return {
		"rules_broken": {"no_aid": [], "no_lifespan": [], "no_teach": [], "no_refuse": [], "sever": false},
		"years_at_home": 0,
		"deathbed_present": {"father": false, "mother": false, "wife": false, "brother": false},
		"edicts_refused": [],
		"beast_spared": false,
		"ending": ""
	}
