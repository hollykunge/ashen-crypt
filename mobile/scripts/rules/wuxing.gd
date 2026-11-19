extends RefCounted

const WUXING := ["jin", "mu", "shui", "huo", "tu"]
const ELEMENT_NAMES := {"jin": "金", "mu": "木", "shui": "水", "huo": "火", "tu": "土"}
const STEMS := ["jia", "yi", "bing", "ding", "wu", "ji", "geng", "xin", "ren", "gui"]
const STEM_NAMES := ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
const STEM_ELEMENTS := ["mu", "huo", "tu", "jin", "shui"]
const BRANCH_ORDER := ["zi", "chou", "yin", "mao", "chen", "si", "wu", "wei", "shen", "you", "xu", "hai"]
const BRANCHES := {
	"zi": {"name": "子", "element": "shui", "yin_yang": 1.0, "hours": [23, 1]},
	"chou": {"name": "丑", "element": "tu", "yin_yang": -1.0, "hours": [1, 3]},
	"yin": {"name": "寅", "element": "mu", "yin_yang": 1.0, "hours": [3, 5]},
	"mao": {"name": "卯", "element": "mu", "yin_yang": -1.0, "hours": [5, 7]},
	"chen": {"name": "辰", "element": "tu", "yin_yang": 1.0, "hours": [7, 9]},
	"si": {"name": "巳", "element": "huo", "yin_yang": -1.0, "hours": [9, 11]},
	"wu": {"name": "午", "element": "huo", "yin_yang": 1.0, "hours": [11, 13]},
	"wei": {"name": "未", "element": "tu", "yin_yang": -1.0, "hours": [13, 15]},
	"shen": {"name": "申", "element": "jin", "yin_yang": 1.0, "hours": [15, 17]},
	"you": {"name": "酉", "element": "jin", "yin_yang": -1.0, "hours": [17, 19]},
	"xu": {"name": "戌", "element": "tu", "yin_yang": 1.0, "hours": [19, 21]},
	"hai": {"name": "亥", "element": "shui", "yin_yang": -1.0, "hours": [21, 23]}
}

const SHENG := {"mu": "huo", "huo": "tu", "tu": "jin", "jin": "shui", "shui": "mu"}
const KE := {"mu": "tu", "tu": "shui", "shui": "huo", "huo": "jin", "jin": "mu"}
const JINGYU := {"wang": 1.30, "xiang": 1.12, "xiu": 0.98, "qiu": 0.85, "si": 0.75}
const JINGYU_NAMES := {"wang": "旺", "xiang": "相", "xiu": "休", "qiu": "囚", "si": "死"}
const SHI := {"de": 1.10, "shi": 0.90}
const CLASH := {"ke": 1.40, "shou_ke": 0.80, "de_sheng": 1.12, "wei_yang": 0.80, "tong_qi": 0.88}
const YINYANG := {"cross": 1.20, "same": 0.88, "taiji": 1.00}
const TAIJI_LIMIT := 0.15
const FEED_HEAL_RATIO := 0.15

static func ling_of(layer: int) -> String:
	return STEMS[posmod(layer - 1, STEMS.size())] if layer > 0 else ""

static func branch_of(layer: int) -> String:
	return BRANCH_ORDER[posmod(layer - 1, BRANCH_ORDER.size())] if layer > 0 else ""

static func stem_element(stem: String) -> String:
	var index := STEMS.find(stem)
	return STEM_ELEMENTS[index >> 1] if index >= 0 else ""

static func stem_polarity(stem: String) -> float:
	var index := STEMS.find(stem)
	if index < 0:
		return 0.0
	return 1.0 if index % 2 == 0 else -1.0

static func stem_for(element: String, polarity: float) -> String:
	var index := STEM_ELEMENTS.find(element)
	return STEMS[index * 2 + int(polarity < 0.0)] if index >= 0 else ""

static func jingyu(element: String, ling_element: String) -> String:
	if not SHENG.has(element) or not SHENG.has(ling_element):
		return ""
	if element == ling_element:
		return "wang"
	if SHENG[ling_element] == element:
		return "xiang"
	if SHENG[element] == ling_element:
		return "xiu"
	return "qiu" if KE[element] == ling_element else "si"

static func clash_relation(src: String, dst: String) -> String:
	if not SHENG.has(src) or not SHENG.has(dst):
		return ""
	if src == dst:
		return "tong_qi"
	if KE[src] == dst:
		return "ke"
	if KE[dst] == src:
		return "shou_ke"
	return "de_sheng" if SHENG[dst] == src else "wei_yang"

static func clash(src: String, dst: String) -> float:
	return CLASH.get(clash_relation(src, dst), 1.0)

# 行向量使用归一化权重，目标为单一行。
static func weighted_clash(weights: Dictionary, dst: String) -> float:
	if weights.is_empty():
		return 1.0
	var result := 0.0
	for element in WUXING:
		result += float(weights.get(element, 0.0)) * clash(element, dst)
	return result

static func is_taiji(polarity: float) -> bool:
	return absf(polarity) <= TAIJI_LIMIT

static func yin_yang(a: float, b: float) -> float:
	if is_taiji(a) or is_taiji(b):
		return YINYANG.taiji
	return YINYANG.cross if a * b < 0.0 else YINYANG.same

static func shi(polarity: float, ling: String) -> float:
	var ling_polarity := stem_polarity(ling)
	if ling_polarity == 0.0 or is_taiji(polarity):
		return 1.0
	return SHI.de if polarity * ling_polarity > 0.0 else SHI.shi
