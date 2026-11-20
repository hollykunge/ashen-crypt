extends RefCounted

# 每件兵器自己的样子。
#
# 兵器由零件拼成（零件图见 art/side/pack_parts.py）：刀剑是刃、护手、握柄、柄首加一挂穗子，
# 长柄兵器换杆头和杆色，短杖整根一件，弓是弓臂加握把缠绳，弓臂按杆色上漆。这里只决定「这一件用哪几样零件、上什么色」，
# 怎么拼、怎么握在 held_weapon.gd 里。
#
# 挑法全由装备推导结果决定，同一件装备每次都拼成同一个样子：
#   主行     → 刃形或杆头（每样零件有偏好的五行），以及钢色、饰色、杆色
#   次行     → 护手和穗子的颜色
#   阴阳     → 钢色偏亮还是偏沉，缠绳是暖色还是冷色；太极取黑白两色穗
#   功率     → 够足的兵器刃上亮起一道灵光血槽
#   uid      → 在合乎五行的几样里挑哪一样，打两把同行的刀也长得不一样
# 「原画」也是一个选项，与零件一起参加挑选；没装兵器时就是原画。

const Atlas = preload("res://scripts/weapon_parts_atlas.gd")
const ELEMENTS := ["jin", "mu", "shui", "huo", "tu"]
const PAINTED := "painted"

# 每种形制能用的刃或杆头（弓是弓臂），以及它们偏好的五行。原画也是一样，按原画的配色只合两行。
const BLADES := {
	"long_blade": {"painted": ["jin", "huo"], "liuye": ["shui", "mu"], "yanling": ["jin", "tu", "shui"], "guitou": ["tu", "huo"]},
	"dual_blades": {"painted": ["huo", "jin"], "liuye": ["shui", "mu", "huo"], "yanling": ["jin", "tu"]},
	"sword": {"painted": ["jin", "huo"], "jian": ["jin", "shui", "tu"], "qixing": ["mu", "shui", "jin"], "bolang": ["huo", "tu", "mu"]},
}
const HEADS := {
	"spear": {"painted": ["huo", "jin"], "leaf": ["jin", "mu", "shui"], "snake": ["shui", "huo"], "ji": ["tu", "jin", "huo"]},
	"hammer": {"painted": ["tu", "jin"], "gua": ["mu", "huo", "shui"], "fang": ["tu", "jin"]},
	"staff": {"painted": ["tu", "mu"], "orb": ["shui", "mu", "huo"], "moon": ["jin", "tu"]},
	"wand": {"painted": ["mu"], "bone": ["huo", "tu", "shui"], "ruyi_wand": ["mu", "jin"]},
	"bow": {"painted": ["huo", "jin"], "fanqu": ["mu", "huo", "tu"], "jiao": ["tu", "jin", "shui"],
		"chang": ["mu", "shui"], "yun": ["jin", "shui", "huo"]},
}
const GUARDS := {"ruyi": ["jin", "tu"], "disc": ["shui", "tu"], "bar": ["jin", "mu"], "crescent": ["huo", "shui"]}
const GRIPS := ["cord", "bands", "ray"]
const POMMELS := {"hex": ["jin", "tu"], "ring": ["huo", "tu", "jin"], "knob": ["shui", "mu"], "cloud": ["mu", "shui", "huo"]}

const STEEL := {"jin": Color("#eef1f3"), "mu": Color("#c9d4ae"), "shui": Color("#adc2de"),
	"huo": Color("#f2c6a8"), "tu": Color("#d8c39c")}
const TRIM := {"jin": Color("#f2cd78"), "mu": Color("#98d0a0"), "shui": Color("#c6d8ec"),
	"huo": Color("#ef8f60"), "tu": Color("#cb9b58")}
const TASSELS := {"jin": Color("#e0b85a"), "mu": Color("#4f9a58"), "shui": Color("#3f6fb8"),
	"huo": Color("#c43c2c"), "tu": Color("#a8742e")}
const GLOWS := {"jin": Color("#ffeeb4"), "mu": Color("#b6f7a4"), "shui": Color("#a8d8ff"),
	"huo": Color("#ffb07a"), "tu": Color("#f0cf94")}
const WARM_WRAPS := [Color("#a8392f"), Color("#7a5232"), Color("#d6cdb8")]
const COOL_WRAPS := [Color("#2f2a2e"), Color("#3a4e86"), Color("#4b7a46")]
const BONE := Color("#ece2c9")
# 杆色：木、黑漆、朱漆、铜。
const POLES := {
	"mu": {"wood": Color("#a4774e"), "core": Color("#40302b"), "cap": Color("#d0ab73")},
	"tu": {"wood": Color("#8c6a45"), "core": Color("#352619"), "cap": Color("#c99856")},
	"shui": {"wood": Color("#4a4550"), "core": Color("#151216"), "cap": Color("#b9c7d6")},
	"huo": {"wood": Color("#93402f"), "core": Color("#3a1612"), "cap": Color("#e7b06c")},
	"jin": {"wood": Color("#a88a52"), "core": Color("#3e2f1a"), "cap": Color("#f0d48a")},
}

# 没装兵器、或者推导结果没有五行时的样子：原画。
static func plain(form: String) -> Dictionary:
	return {"form": form, "blade": PAINTED, "head": PAINTED, "guard": "ruyi", "grip": "cord", "pommel": "hex",
		"steel": STEEL.jin, "trim": TRIM.jin, "wrap": WARM_WRAPS[0], "bone": BONE, "glow": GLOWS.jin,
		"tassel": Color.TRANSPARENT, "tassel_alt": Color.TRANSPARENT, "pole": {}, "inlay": 0.0}

# entry 是一件兵器的推导结果（Derive.derive），amount 是它的外观强度（Appearance.amount_of）。
static func pick(entry: Dictionary, form: String, amount: float = 0.0) -> Dictionary:
	var ranked := _ranked(entry.get("wuxing", {}))
	if ranked.is_empty():
		return plain(form)
	var main: String = ranked[0]
	var second: String = ranked[1] if ranked.size() > 1 and float(entry.wuxing[ranked[1]]) >= 0.2 else main
	var polarity := float(entry.get("yin_yang", 0.0))
	var taiji := absf(polarity) < 0.05
	var seed := String(entry.get("uid", "")) + "|" + String(entry.get("name", "")) + "|" + form
	var design := plain(form)
	design.blade = _choose(BLADES.get(form, {PAINTED: []}), main, seed + "blade")
	design.head = _choose(HEADS.get(form, {PAINTED: []}), main, seed + "head")
	design.guard = _choose(GUARDS, second, seed + "guard")
	design.grip = GRIPS[_roll(seed + "grip", GRIPS.size())]
	design.pommel = _choose(POMMELS, main, seed + "pommel")
	var steel: Color = STEEL[main]
	design.steel = steel.lightened(0.10 * polarity) if polarity > 0.0 else steel.darkened(0.16 * -polarity)
	design.trim = TRIM[second]
	var wraps: Array = WARM_WRAPS if polarity >= 0.0 else COOL_WRAPS
	design.wrap = wraps[_roll(seed + "wrap", wraps.size())]
	design.bone = BONE.darkened(0.12 * maxf(0.0, -polarity))
	design.glow = Color("#f4f1ea") if taiji else GLOWS[main]
	design.pole = POLES[main]
	# 环首一定挂穗；别的柄首四成不挂，看着不至于每把都一样。
	if design.pommel == "ring" or _roll(seed + "tassel", 10) < 6:
		design.tassel = TASSELS[second]
		design.tassel_alt = TASSELS[second]
		if taiji:
			design.tassel = Color("#ece6da")
			design.tassel_alt = Color("#1e1b1d")
	design.inlay = clampf((amount - 0.45) / 0.4, 0.0, 1.0)
	return design

static func painted_blade(design: Dictionary) -> bool:
	return design.get("blade", PAINTED) == PAINTED

static func painted_head(design: Dictionary) -> bool:
	return design.get("head", PAINTED) == PAINTED

static func _ranked(weights: Dictionary) -> Array:
	var ranked: Array = []
	for element in ELEMENTS:
		if float(weights.get(element, 0.0)) > 0.0:
			ranked.append(element)
	ranked.sort_custom(func(a: String, b: String) -> bool:
		return float(weights[a]) > float(weights[b]) or (is_equal_approx(float(weights[a]), float(weights[b]))
			and ELEMENTS.find(a) < ELEMENTS.find(b)))
	return ranked

# 合乎这一行的几样里按 uid 挑一样；偏好表为空的对哪一行都合。
static func _choose(options: Dictionary, element: String, seed: String) -> String:
	var fitting: Array = []
	for name in options:
		var likes: Array = options[name]
		if likes.is_empty() or likes.has(element):
			fitting.append(name)
	if fitting.is_empty():
		fitting = options.keys()
	return fitting[_roll(seed, fitting.size())]

# 稳定的伪随机：同一串字符永远落在同一个数上，不受引擎版本的 hash 实现影响。
static func _roll(seed: String, count: int) -> int:
	var value := 2166136261
	for byte in seed.to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
	return value % count
