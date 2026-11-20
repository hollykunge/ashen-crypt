extends RefCounted

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Pigments = preload("res://scripts/pigments.gd")
# 五行字色与边色，取自 pigments.gd 的敦煌矿物色。
const ELEMENT_TINTS = Pigments.LIGHT
const ELEMENT_GLOW = Pigments.GLOW

const NAMES := ["二郎神", "九天玄女", "后羿", "青鸟仙子", "雷部天师", "电母"]
const CONFIRM_TIME := 0.55

const PORTRAITS := [
	preload("res://art/immortals/portrait-0.webp"),
	preload("res://art/immortals/portrait-1.webp"),
	preload("res://art/immortals/portrait-2.webp"),
	preload("res://art/immortals/portrait-3.webp"),
	preload("res://art/immortals/portrait-4.webp"),
	preload("res://art/immortals/portrait-5.webp")
]

const READY := [
	preload("res://art/immortals/ready-0.webp"),
	preload("res://art/immortals/ready-1.webp"),
	preload("res://art/immortals/ready-2.webp"),
	preload("res://art/immortals/ready-3.webp"),
	preload("res://art/immortals/ready-4.webp"),
	preload("res://art/immortals/ready-5.webp")
]

const STRIKE := [
	preload("res://art/immortals/strike-0.webp"),
	preload("res://art/immortals/strike-1.webp"),
	preload("res://art/immortals/strike-2.webp"),
	preload("res://art/immortals/strike-3.webp"),
	preload("res://art/immortals/strike-4.webp"),
	preload("res://art/immortals/strike-5.webp")
]

const ALT_READY := [
	preload("res://art/immortals/alt-ready-0.webp"),
	preload("res://art/immortals/alt-ready-1.webp"),
	preload("res://art/immortals/alt-ready-2.webp"),
	preload("res://art/immortals/alt-ready-3.webp"),
	preload("res://art/immortals/alt-ready-4.webp"),
	preload("res://art/immortals/alt-ready-5.webp")
]

const ALT_STRIKE := [
	preload("res://art/immortals/alt-strike-0.webp"),
	preload("res://art/immortals/alt-strike-1.webp"),
	preload("res://art/immortals/alt-strike-2.webp"),
	preload("res://art/immortals/alt-strike-3.webp"),
	preload("res://art/immortals/alt-strike-4.webp"),
	preload("res://art/immortals/alt-strike-5.webp")
]

static func id(role: int, style: int) -> int:
	return role * 2 + style

static func portrait_id(day_stem: String, female: bool) -> int:
	var element := WuXing.stem_element(day_stem)
	var base := 2 if element == "mu" else (4 if element == "shui" else 0)
	return base + int(female)

# 兵器形制 → 立绘用哪一套。双持类走替换装，其余走正装。
# 想给某件兵器单独配图，就按 <形制>-<动作>-<神仙序号>.webp 丢进 art/immortals，这里会自动优先用它。
const FORM_SETS := {
	"sword": "", "spear": "", "bow": ""
}
# 动作名的回退链：没有这一格的画，就退到上一格，最后一定能落到待机或出招。
const FRAME_FALLBACK := {
	&"windup": &"ready", &"recover": &"ready", &"guard": &"ready", &"dodge": &"ready",
	&"hurt": &"ready", &"cast": &"strike", &"follow": &"strike", &"victory": &"strike"
}
# 出招类的画面更宽（兵器甩在身前），轴心要往左挪才站得稳。
const FRAME_PIVOTS := {&"strike": 0.37, &"cast": 0.37, &"follow": 0.37, &"victory": 0.42}

static var _art_cache := {}

static func frame_pivot(frame: StringName) -> float:
	return float(FRAME_PIVOTS.get(frame, 0.5))

static func battle_art(hero: int, weapon_form: String, frame: StringName) -> Texture2D:
	return _resolve(hero, weapon_form, frame).art

static func _resolve(hero: int, weapon_form: String, frame: StringName) -> Dictionary:
	var key := "%d|%s|%s" % [hero, weapon_form, frame]
	if not _art_cache.has(key):
		_art_cache[key] = _locate(hero, weapon_form, frame)
	return _art_cache[key]

static func _locate(hero: int, weapon_form: String, frame: StringName) -> Dictionary:
	var set_name: String = FORM_SETS.get(weapon_form, "")
	var current := frame
	var guard := 0
	while current != &"" and guard < 6:
		guard += 1
		var candidates := PackedStringArray(["%s-%s" % [weapon_form, current]])
		if not set_name.is_empty():
			candidates.append("%s-%s" % [set_name, current])
		candidates.append(String(current))
		for stem in candidates:
			var path := "res://art/immortals/%s-%d.webp" % [stem, hero]
			if ResourceLoader.exists(path):
				return {"art": load(path), "stem": stem}
		current = FRAME_FALLBACK.get(current, &"")
	if set_name == "alt":
		return {"art": ALT_READY[hero], "stem": "alt-ready"}
	return {"art": READY[hero], "stem": "ready"}
