extends RefCounted

# 装备外观。
#
# 六个槽位各自有主导五行、阴阳与功率预算，这三样已经决定了数值，这里让它们同样决定画面：
# 换一件护甲就换一身袍色，换一把兵器就换一色刃光，成格还会在脚下多一圈光环。
# 规则与 docs/crafting-rules.md 同源，外观只读推导结果，不自己造数值。
#
# 槽位 → 画面：
#   weapon 武器 → 刃光、斩击与弹道的颜色
#   armor  护甲 → 袍色、披风
#   gloves 护手 → 出手时的腕光
#   charm  项链 → 胸前悬浮的符牌
#   ring   戒指 → 绕身旋转的符环
#   boots  鞋子 → 脚下尘土与步痕
#   格局     → 脚下法阵的环数

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Loadout = preload("res://scripts/loadout.gd")

# 袍色比图标色深一档，才压得住工笔立绘；刃光则要亮过立绘才看得见。
const ROBE_TINTS := {
	"jin": Color("#cdb87f"), "mu": Color("#6f9c63"), "shui": Color("#5d87b8"),
	"huo": Color("#b05a3c"), "tu": Color("#9a7a4c")
}
const EDGE_TINTS := {
	"jin": Color("#ffeeb4"), "mu": Color("#b6f7a4"), "shui": Color("#a8d8ff"),
	"huo": Color("#ffb07a"), "tu": Color("#f0cf94")
}
const YANG_TRIM := Color("#ffd89a")
const YIN_TRIM := Color("#9fc8d8")
const NEUTRAL := Color("#c9bda4")
# 预算到视觉强度的换算：六档炉温上限为 18~135，48 以上按满算。
const FULL_BUDGET := 48.0

static func element_of(entry: Dictionary) -> String:
	return Loadout.dominant(entry.get("wuxing", {}))

static func amount_of(entry: Dictionary) -> float:
	return clampf(float(entry.get("budget", 0.0)) / FULL_BUDGET, 0.0, 1.0)

# 由当前装备推出一份外观描述。entries 为 Gear.loadout().entries，patterns 为同一次推导的格局。
static func build(entries: Dictionary, patterns: Dictionary, weapon_form: String) -> Dictionary:
	var look := {
		"form": weapon_form,
		"dressed": false,
		"polarity": 0.0,
		"robe": NEUTRAL, "robe_amount": 0.0,
		"trim": NEUTRAL,
		"cape": false, "cape_color": NEUTRAL, "cape_length": 0.0,
		"rim": NEUTRAL, "rim_amount": 0.0,
		"weapon": Color("#f4e3bc"), "weapon_amount": 0.0,
		"trail": Color("#eaffd3"),
		"hands": NEUTRAL, "hands_amount": 0.0,
		"charm": false, "charm_color": NEUTRAL,
		"ring": false, "ring_color": NEUTRAL,
		"boots": NEUTRAL, "boots_amount": 0.0,
		"halo": 0, "halo_color": NEUTRAL,
		"marks": []
	}
	var carried := 0.0
	var polarity := 0.0
	for slot in entries:
		var entry: Dictionary = entries[slot]
		var element := element_of(entry)
		if element.is_empty():
			continue
		var amount := amount_of(entry)
		var weight: float = float(entry.get("budget", 0.0))
		carried += weight
		polarity += float(entry.get("yin_yang", 0.0)) * weight
		look.dressed = true
		var glow: Color = EDGE_TINTS[element]
		var dye: Color = ROBE_TINTS[element]
		match slot:
			"weapon":
				look.weapon = glow
				look.weapon_amount = amount
				look.trail = glow.lerp(Color.WHITE, 0.22)
			"armor":
				look.robe = dye
				look.robe_amount = amount
				look.cape = true
				look.cape_color = dye.lerp(glow, 0.22)
				look.cape_length = 0.45 + amount * 0.55
			"gloves":
				look.hands = glow
				look.hands_amount = amount
			"charm":
				look.charm = true
				look.charm_color = glow
			"ring":
				look.ring = true
				look.ring_color = glow
			"boots":
				look.boots = glow
				look.boots_amount = amount
	if carried > 0.0:
		polarity /= carried
	look.polarity = polarity
	look.trim = YANG_TRIM.lerp(YIN_TRIM, clampf((1.0 - polarity) * 0.5, 0.0, 1.0))
	# 阴阳偏得越狠，边光越明显：纯阳镶金，纯阴泛青。
	look.rim = YANG_TRIM if polarity >= 0.0 else YIN_TRIM
	look.rim_amount = clampf(absf(polarity), 0.0, 1.0)
	look.halo = _halo_rings(patterns)
	look.halo_color = _halo_color(patterns, look)
	look.marks = _marks(patterns)
	return look

# 没有装备时的素身外观，创角直后与读档失败都走这里。
static func bare(weapon_form: String = "long_blade") -> Dictionary:
	return build({}, {}, weapon_form)

static func _halo_rings(patterns: Dictionary) -> int:
	if patterns.has("zhoutian"):
		return 3
	if patterns.has("xiangsheng"):
		return 2
	if patterns.has("yiqi") or patterns.has("xiangzhan") or patterns.has("taiji") \
			or patterns.has("chunyang") or patterns.has("chunyin"):
		return 1
	return 0

static func _halo_color(patterns: Dictionary, look: Dictionary) -> Color:
	if patterns.has("zhoutian"):
		return Color("#f3e7c0")
	if patterns.has("xiangzhan"):
		return Color("#ef8a6a")
	if patterns.has("chunyang"):
		return YANG_TRIM
	if patterns.has("chunyin"):
		return YIN_TRIM
	var first: Array = patterns.get("yiqi", patterns.get("xiangsheng", []))
	if not first.is_empty():
		return EDGE_TINTS.get(first[0], look.trim)
	return look.trim

static func _marks(patterns: Dictionary) -> Array:
	var names := []
	for key in patterns:
		names.append(key)
	return names
