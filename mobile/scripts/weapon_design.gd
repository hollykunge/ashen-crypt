extends RefCounted

# 每件兵器自己的样子。
#
# 兵器只有剑、长枪、弓三种，都由零件拼成（零件图见 art/side/pack_parts.py）：剑是刃、护手、握柄、柄首加一挂穗子，
# 长枪换枪头和杆色，弓是弓臂加握把缠绳。这里只决定「这一件用哪几样零件、上什么色」，
# 怎么拼、怎么握在 held_weapon.gd 里。
#
# 挑法全由装备推导结果决定，同一件装备每次都拼成同一个样子：
#   主行     → 刃形、枪头或弓臂（每样零件有偏好的五行），布条绳穗的颜色，钢上淡淡偏一点，杆漆
#   次行     → 护手形制、穗子与缠绳的颜色
#   阴阳     → 钢色偏亮还是偏沉，缠绳是暖色还是冷色；太极取黑白两色穗
#   功率     → 够足的兵器刃上亮起一道灵光血槽
#   uid      → 在合乎五行的几样里挑哪一样，打两把同行的刀也长得不一样
# 没装兵器时手里也是零件拼的一件，挑最朴素的那几样。

const Atlas = preload("res://scripts/weapon_parts_atlas.gd")
const Pigments = preload("res://scripts/pigments.gd")
const ELEMENTS := ["jin", "mu", "shui", "huo", "tu"]
const PAINTED := "painted"

# 每种形制能用的刃或杆头（弓是弓臂），以及它们偏好的五行。旧的整张原画兵器风格对不上，不再参加挑选。
const BLADES := {
	"sword": {"jian": ["jin", "shui", "tu"], "qixing": ["mu", "shui", "jin"], "bolang": ["huo", "tu", "mu"]},
}
const HEADS := {
	"spear": {"leaf": ["jin", "mu", "shui"], "snake": ["shui", "huo"], "ji": ["tu", "jin", "huo"]},
	"bow": {"fanqu": ["mu", "huo", "tu"], "jiao": ["tu", "jin", "shui"],
		"chang": ["mu", "shui"], "yun": ["jin", "shui", "huo"]},
}
const GUARDS := {"ruyi": ["jin", "tu"], "disc": ["shui", "tu"], "bar": ["jin", "mu"], "crescent": ["huo", "shui"]}
const GRIPS := ["cord", "bands", "ray"]
const POMMELS := {"hex": ["jin", "tu"], "ring": ["huo", "tu", "jin"], "knob": ["shui", "mu"], "cloud": ["mu", "shui", "huo"]}

# 颜色都从 pigments.gd 取：底子是暗铁、旧铜、黑漆，五行只落在纹饰、穗子、缠绳和杆漆上。
# 原画（零件图）里朱红的布条绳穗打包时已分到 accent 一层，这里给它换成主行的颜料色。
const CINNABAR := Color("#9b4a36")
const BONE := Color("#ece2c9")
# 杆色：本色木、朱漆、黑漆、白蜡木，箍一律旧铜。
const POLES := {
	"mu": {"wood": Color("#7c5a3c"), "core": Color("#2e2219"), "cap": Color("#a58a5e")},
	"tu": {"wood": Color("#8a6a42"), "core": Color("#2f2316"), "cap": Color("#a58a5e")},
	"shui": {"wood": Color("#34313a"), "core": Color("#121014"), "cap": Color("#8f8a80")},
	"huo": {"wood": Color("#7e3424"), "core": Color("#2c120d"), "cap": Color("#a58a5e")},
	"jin": {"wood": Color("#a08a66"), "core": Color("#352a1c"), "cap": Color("#b8a682")},
}
# 没装兵器时手里那一件：各形制挑一样最朴素的。
const PLAIN_BLADE := {"sword": "jian"}
const PLAIN_HEAD := {"spear": "leaf", "bow": "chang"}

# 没装兵器、或者推导结果没有五行时的样子：最朴素的零件，朱红保持本色。
static func plain(form: String) -> Dictionary:
	return {"form": form, "blade": PLAIN_BLADE.get(form, PAINTED), "head": PLAIN_HEAD.get(form, PAINTED),
		"guard": "disc", "grip": "cord", "pommel": "knob",
		"steel": Pigments.IRON, "trim": Pigments.BRONZE, "accent": CINNABAR, "wrap": CINNABAR.darkened(0.25),
		"bone": BONE, "glow": Pigments.GLOW.jin,
		"tassel": Color.TRANSPARENT, "tassel_alt": Color.TRANSPARENT, "pole": POLES.mu, "inlay": 0.0}

# entry 是一件兵器的推导结果（Derive.derive），amount 是它的外观强度（Appearance.amount_of）。
static func pick(entry: Dictionary, form: String, amount: float = 0.0) -> Dictionary:
	if form == "jian":
		form = "sword"
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
	var steel: Color = Pigments.IRON.lerp(Pigments.PIGMENT[main], 0.10)
	design.steel = steel.lightened(0.06 * polarity) if polarity > 0.0 else steel.darkened(0.14 * -polarity)
	design.trim = Pigments.BRONZE.lerp(Pigments.PIGMENT[second], 0.15)
	design.accent = Pigments.PIGMENT[main]
	# 缠绳：阳偏次行的染色、褐麻、本色麻，阴偏黑绳、次行染色、灰麻。
	var wraps: Array = [Pigments.DYE[second], Color("#5a4632"), Color("#cfc5b0")] if polarity >= 0.0 \
		else [Color("#2b2729"), Pigments.DYE[second], Color("#4a4440")]
	design.wrap = wraps[_roll(seed + "wrap", wraps.size())]
	design.bone = BONE.darkened(0.12 * maxf(0.0, -polarity))
	design.glow = Color("#f4f1ea") if taiji else Pigments.GLOW[main]
	design.pole = POLES[main]
	# 环首一定挂穗；别的柄首四成不挂，看着不至于每把都一样。
	if design.pommel == "ring" or _roll(seed + "tassel", 10) < 6:
		design.tassel = Pigments.PIGMENT[second]
		design.tassel_alt = Pigments.PIGMENT[second]
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
