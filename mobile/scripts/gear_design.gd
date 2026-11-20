extends RefCounted

# 护甲、护手、项链、戒指、鞋子的图标，和兵器一样每件各有样子。
#
# 图标是 art/side/pack_parts.py 打进零件图集的 gear 格（原画出自 parts-prompts.json）。每格两层：
# 底子保留原画的锈铁、旧铜、旧骨、皮革，只乘一层接近白、淡淡偏主行的底色；朱红布条绳穗那层
# 换成主行的颜料色（pigments.gd）。护甲、护手、鞋子按炉坊里选的甲型（布衣、皮甲、链甲）分款，
# 项链、戒指按主行合哪几款；最后都用 uid 定一款。

const Atlas = preload("res://scripts/weapon_parts_atlas.gd")
const Pigments = preload("res://scripts/pigments.gd")
const SideArt = preload("res://scripts/side_art.gd")
const WeaponDesign = preload("res://scripts/weapon_design.gd")

static var SHEET: CanvasTexture = SideArt.smooth(Atlas.SHEET)
const LIFT := 1.22
# 项链、戒指每一款偏好的五行；护甲、护手、鞋子按甲型分款，同一甲型里用 uid 定一款。
const AFFINITY := {
	"charm_taofu": ["mu", "huo"], "charm_yupei": ["shui", "jin"], "charm_shouya": ["huo", "tu"],
	"charm_tongling": ["jin", "tu"],
	"ring_banzhi": ["tu", "huo"], "ring_tiejie": ["jin", "shui"], "ring_yuhuan": ["mu", "shui"],
}
const ARMOR_TYPES := ["cloth", "leather", "chain"]

# 这一槽有哪几款。护甲分男女：女角色只用标了 female 的几款（丝衣、皮衣、盔甲），男角色用没标的；
# 某一性别还没有图时退回另一套。
static func pieces(slot: String, female := false) -> Array:
	var names: Array = []
	var other: Array = []
	for name: String in Atlas.PARTS:
		var spec: Dictionary = Atlas.PARTS[name]
		if spec.kind != "gear" or spec.get("slot", "") != slot:
			continue
		if (spec.get("sex", "") == "female") == female or not _gendered(slot):
			names.append(name)
		else:
			other.append(name)
	return names if not names.is_empty() else other

static func _gendered(slot: String) -> bool:
	for name: String in Atlas.PARTS:
		var spec: Dictionary = Atlas.PARTS[name]
		if spec.kind == "gear" and spec.get("slot", "") == slot and spec.has("sex"):
			return true
	return false

# 空槽和没有五行时的样子：这一槽的第一款，朱红保持本色。没有图标时返回空字典。
static func plain(slot: String, female := false) -> Dictionary:
	var names := pieces(slot, female)
	if names.is_empty():
		return {}
	return {"piece": names[0], "steel": Pigments.IRON, "accent": WeaponDesign.CINNABAR}

# entry 是一件装备的推导结果（Derive.derive）。
static func pick(entry: Dictionary, slot: String, female := false) -> Dictionary:
	var names := pieces(slot, female)
	var ranked := WeaponDesign._ranked(entry.get("wuxing", {}))
	if names.is_empty() or ranked.is_empty():
		return plain(slot, female)
	var main: String = ranked[0]
	var polarity := float(entry.get("yin_yang", 0.0))
	var seed := String(entry.get("uid", "")) + "|" + String(entry.get("name", "")) + "|" + slot
	# 有甲型的槽位只在同甲型的几款里挑；旧存档的装备没记甲型，按 uid 定一个，往后不变。
	var typed: Array = names.filter(func(name: String) -> bool: return Atlas.PARTS[name].has("armor_type"))
	if not typed.is_empty():
		var kind: String = entry.get("armor_type", "")
		if kind not in ARMOR_TYPES:
			kind = ARMOR_TYPES[WeaponDesign._roll(seed + "type", ARMOR_TYPES.size())]
		names = typed.filter(func(name: String) -> bool: return Atlas.PARTS[name].armor_type == kind)
		if names.is_empty():
			names = typed
	var options := {}
	for name: String in names:
		options[name] = AFFINITY.get(name, [])
	var steel: Color = Pigments.IRON.lerp(Pigments.PIGMENT[main], 0.08)
	return {"piece": WeaponDesign._choose(options, main, seed),
		"steel": steel.lightened(0.05 * polarity) if polarity > 0.0 else steel.darkened(0.12 * -polarity),
		"accent": Pigments.PIGMENT[main]}

# 把图标按原比例放进 rect 正中。
static func draw(canvas: CanvasItem, design: Dictionary, rect: Rect2, ink := Color.WHITE) -> void:
	var spec: Dictionary = Atlas.PARTS[design.piece]
	var box: Rect2 = spec.box
	var scale := minf(rect.size.x / box.size.x, rect.size.y / box.size.y)
	var target := Rect2(rect.get_center() - box.size * scale * 0.5, box.size * scale)
	var cell_pixels := SHEET.get_size() / Atlas.GRID
	var texel := cell_pixels / 128.0
	for layer: Array in spec.layers:
		var cell: int = layer[0]
		var origin := Vector2(cell % int(Atlas.GRID.x), floori(cell / Atlas.GRID.x)) * cell_pixels
		var source := Rect2(origin + box.position * texel, box.size * texel)
		# 做旧的底子在暗色格子里压得太死，底子那层提亮一点（Godot 的调色允许过曝）。
		var tint: Color = design.get(layer[1], Color.WHITE)
		if layer[1] == "steel":
			tint = Color(tint.r * LIFT, tint.g * LIFT, tint.b * LIFT, tint.a)
		canvas.draw_texture_rect_region(SHEET, target, source, tint * ink)
