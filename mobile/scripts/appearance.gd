extends RefCounted

# 装备外观。
#
# 五个槽位各自有主导五行、阴阳与功率预算，这三样已经决定了数值，这里让它们同样决定画面：
# 换一件护甲就换一身袍色，换一把兵器就换一色刃光，成格还会在脚下多一圈光环。
# 规则与 docs/crafting-rules.md 同源，外观只读推导结果，不自己造数值。
#
# 槽位 → 画面：
#   weapon 武器 → 刃光、斩击的颜色
#   armor  护甲 → 胸甲、肩甲、衣摆和披帛
#   gloves 护手 → 随腕移动的护臂、出手时的腕光
#   greaves 护腿 → 随小腿移动的腿甲
#   boots  鞋子 → 靴筒、鞋面和步痕
#   格局     → 脚下法阵的环数

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Loadout = preload("res://scripts/loadout.gd")
const Pigments = preload("res://scripts/pigments.gd")

# 五行用色统一在 pigments.gd：袍色用染布那一档，才压得住立绘；刃光用光那一档，要亮过立绘才看得见。
const ROBE_TINTS = Pigments.DYE
const EDGE_TINTS = Pigments.GLOW
const YANG_TRIM = Pigments.YANG
const YIN_TRIM = Pigments.YIN
const NEUTRAL := Color("#c9bda4")
# 预算到视觉强度的换算：六档炉温上限为 18~135，48 以上按满算。
const FULL_BUDGET := 48.0

static func element_of(entry: Dictionary) -> String:
	return Loadout.dominant(entry.get("wuxing", {}))

static func amount_of(entry: Dictionary) -> float:
	return clampf(float(entry.get("budget", 0.0)) / FULL_BUDGET, 0.0, 1.0)

# 由当前装备推出一份外观描述。entries 为 Gear.loadout().entries，patterns 为同一次推导的格局。
static func build(entries: Dictionary, patterns: Dictionary, weapon_form: String, gender: String = "") -> Dictionary:
	var look := {
		"form": weapon_form,
		"gender": gender, "armed": entries.has("weapon"),
		"dressed": false,
		"pieces": {},
		"polarity": 0.0,
		"robe": NEUTRAL, "robe_amount": 0.0,
		"trim": NEUTRAL,
		"cape": false, "cape_color": NEUTRAL, "cape_length": 0.0,
		"rim": NEUTRAL, "rim_amount": 0.0,
		"weapon": Color("#f4e3bc"), "weapon_amount": 0.0,
		"trail": Color("#eaffd3"),
		"hands": NEUTRAL, "hands_amount": 0.0,
		"greaves": NEUTRAL, "greaves_amount": 0.0,
		"boots": NEUTRAL, "boots_amount": 0.0,
		"halo": 0, "halo_color": NEUTRAL,
		"marks": [],
		# 上衣、护腕、护腿、靴子各是哪一款（款式名，空的不写），皮影主角按它换这一槽的部件图（gear_styles.gd）
		"dyes": {}, "styles": {},
		# 护甲四槽在模型上乘的颜色（garment_tint），没穿的槽不写，模型按原色
		"tints": {}
	}
	var carried := 0.0
	var polarity := 0.0
	for slot in entries:
		var entry: Dictionary = entries[slot]
		if slot in ["armor", "gloves", "greaves", "boots"]:
			var dye_id: String = entry.get("dye", "本色")
			if dye_id != "本色" and Pigments.GARMENT_DYES.has(dye_id):
				look.dyes[slot] = Pigments.GARMENT_DYES[dye_id]
			var style: String = entry.get("style", "")
			if not style.is_empty():
				look.styles[slot] = style
			look.tints[slot] = garment_tint(slot, entry)
		var element := element_of(entry)
		if element.is_empty():
			continue
		var amount := amount_of(entry)
		var weight: float = float(entry.get("budget", 0.0))
		carried += weight
		polarity += float(entry.get("yin_yang", 0.0)) * weight
		look.dressed = true
		look.pieces[slot] = {"element": element, "polarity": int(signf(float(entry.get("yin_yang", 0.0))))}
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
			"greaves":
				look.greaves = dye
				look.greaves_amount = amount
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
	var weapon: Dictionary = entries.get("weapon", {})
	return look

# 护甲四槽的那件衣服在模型上乘的颜色：染过色用染料色；没染按主行淡淡偏一点，炉温越高越偏。
# 主角模型（cutout_hero.gd）和装备格图标（equipment_slot.gd）都用它，图标才和身上那件同色。
const GARMENT_SHIFT := 0.32

static func garment_tint(slot: String, entry: Dictionary) -> Color:
	var dye_id: String = entry.get("dye", "本色")
	if dye_id != "本色" and Pigments.GARMENT_DYES.has(dye_id):
		return Pigments.GARMENT_DYES[dye_id]
	var element := element_of(entry)
	if element.is_empty():
		return Color.WHITE
	var color: Color = (ROBE_TINTS if slot in ["armor", "greaves"] else EDGE_TINTS)[element]
	return Color.WHITE.lerp(color, amount_of(entry) * GARMENT_SHIFT)

# 没有装备时的素身外观，创角直后与读档失败都走这里。
static func bare(weapon_form: String = "sword") -> Dictionary:
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
