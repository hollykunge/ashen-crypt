extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")
const Appearance = preload("res://scripts/appearance.gd")
const HeldWeapon = preload("res://scripts/held_weapon.gd")

# 换装：在原画上按装备给衣料染色，脸、手和头发不动。
#
# art/side/pack_frames.py 把每张人物图集分成五个染色区，各出一张图层（art/side/dye）：
#   cloth   袍、裤、袖       ← 护甲的五行袍色
#   trim    衣领、镶边、腰带 ← 护甲的阴阳镶边色
#   bracers 前臂             ← 护手
#   boots   靴               ← 鞋子
#   charm   腰间符牌         ← 项链
# 图层的不透明处就是「染哪里」，图层本身是「原画的明暗」：先在范围内平涂染料，再把图层叠回去，
# 暗处压暗、亮处提亮，等于染料乘上原画的褶皱和勾线。两步都是引擎自带的整图混合，换一身不卡顿。
# 戒指太小，直接在领招的那只拳头（HeldWeapon.LEAD）上点一道。
# 哪块布属于哪一区，以 art/side/masks 里手修的分区遮罩为准，pack_frames.py 按遮罩出图层。
# 行装页的正面全身像用同一套颜色（dyes），但由 dye.gdshader 每帧现染，不走这里的合成。

# 每一行对应原图集的一格。坐标依次是近肩、腰带、近肘、近腕、两只脚踝，单位是 96 像素的逻辑分格。
# pack_frames.py 按这些关节划分染色区，改了这里要重新出图。
const MALE := [
	[Vector2(41,34),Vector2(48,52),Vector2(36,44),Vector2(38,53),Vector2(39,84),Vector2(57,84)],
	[Vector2(42,34),Vector2(50,53),Vector2(38,44),Vector2(36,53),Vector2(36,83),Vector2(68,83)],
	[Vector2(49,35),Vector2(50,53),Vector2(56,44),Vector2(60,50),Vector2(36,82),Vector2(50,84)],
	[Vector2(44,42),Vector2(47,57),Vector2(30,50),Vector2(32,58),Vector2(25,84),Vector2(69,84)],
	[Vector2(53,38),Vector2(48,54),Vector2(28,34),Vector2(33,26),Vector2(29,84),Vector2(70,84)],
	[Vector2(51,38),Vector2(47,57),Vector2(65,42),Vector2(76,42),Vector2(19,84),Vector2(68,84)],
	[Vector2(48,42),Vector2(44,58),Vector2(58,53),Vector2(67,59),Vector2(21,84),Vector2(66,84)],
	[Vector2(38,37),Vector2(46,55),Vector2(30,44),Vector2(44,48),Vector2(32,84),Vector2(65,84)],
	[Vector2(25,40),Vector2(42,52),Vector2(21,53),Vector2(31,58),Vector2(25,84),Vector2(60,84)],
	[Vector2(30,38),Vector2(47,50),Vector2(23,47),Vector2(36,50),Vector2(33,84),Vector2(70,84)],
	[Vector2(35,37),Vector2(48,53),Vector2(30,48),Vector2(36,53),Vector2(31,84),Vector2(68,84)],
	[Vector2(41,36),Vector2(49,51),Vector2(41,43),Vector2(46,53),Vector2(44,83),Vector2(60,84)],
]
const FEMALE := [
	[Vector2(42,35),Vector2(48,47),Vector2(39,47),Vector2(40,55),Vector2(40,84),Vector2(52,84)],
	[Vector2(43,35),Vector2(49,47),Vector2(40,46),Vector2(38,53),Vector2(35,84),Vector2(64,84)],
	[Vector2(44,35),Vector2(48,48),Vector2(40,47),Vector2(38,54),Vector2(36,83),Vector2(48,84)],
	[Vector2(45,42),Vector2(47,58),Vector2(34,50),Vector2(38,57),Vector2(29,84),Vector2(69,84)],
	[Vector2(50,36),Vector2(46,50),Vector2(29,34),Vector2(34,30),Vector2(28,84),Vector2(68,84)],
	[Vector2(49,39),Vector2(47,54),Vector2(61,42),Vector2(70,42),Vector2(17,84),Vector2(69,84)],
	[Vector2(48,44),Vector2(43,58),Vector2(57,53),Vector2(63,58),Vector2(21,84),Vector2(64,84)],
	[Vector2(42,38),Vector2(47,53),Vector2(38,48),Vector2(46,50),Vector2(30,84),Vector2(65,84)],
	[Vector2(28,43),Vector2(41,53),Vector2(26,55),Vector2(35,57),Vector2(28,84),Vector2(57,84)],
	[Vector2(31,38),Vector2(42,46),Vector2(26,48),Vector2(34,50),Vector2(28,84),Vector2(65,84)],
	[Vector2(39,40),Vector2(48,50),Vector2(36,49),Vector2(40,53),Vector2(33,84),Vector2(68,84)],
	[Vector2(44,36),Vector2(49,46),Vector2(41,48),Vector2(42,55),Vector2(40,83),Vector2(58,84)],
]
# 远侧的肘腕，用来贴合背面的护臂。
const FAR_ARMS := [
	[[Vector2(62,45),Vector2(62,53)], [Vector2(62,45),Vector2(66,52)], [Vector2(37,44),Vector2(36,52)],
	 [Vector2(64,51),Vector2(69,57)], [Vector2(45,40),Vector2(38,28)], [Vector2(66,43),Vector2(76,43)],
	 [Vector2(59,54),Vector2(68,60)], [Vector2(57,45),Vector2(62,46)], [Vector2(48,52),Vector2(53,53)],
	 [Vector2(55,45),Vector2(61,44)], [Vector2(70,34),Vector2(80,33)], [Vector2(60,47),Vector2(62,53)]],
	[[Vector2(55,48),Vector2(57,55)], [Vector2(58,48),Vector2(62,53)], [Vector2(55,50),Vector2(57,53)],
	 [Vector2(59,53),Vector2(62,58)], [Vector2(38,38),Vector2(38,30)], [Vector2(61,43),Vector2(70,44)],
	 [Vector2(58,54),Vector2(64,59)], [Vector2(53,49),Vector2(56,49)], [Vector2(48,53),Vector2(52,54)],
	 [Vector2(49,47),Vector2(53,45)], [Vector2(66,36),Vector2(74,35)], [Vector2(55,50),Vector2(57,56)]]
]
const LAYERS := ["cloth", "trim", "bracers", "boots", "charm"]
const CACHE_LIMIT := 4
static var cache := {}

# 由外观推出每个染色区用什么颜色。没穿的槽位不出现在结果里，那一区保持原画。
static func dyes(look: Dictionary) -> Dictionary:
	var pieces: Dictionary = look.get("pieces", {})
	var out := {}
	if pieces.has("armor"):
		var armor: Dictionary = pieces.armor
		out["cloth"] = Appearance.ROBE_TINTS[armor.element]
		out["trim"] = Appearance.YIN_TRIM if armor.polarity < 0 else Appearance.YANG_TRIM
	if pieces.has("gloves"):
		var element: String = pieces.gloves.element
		out["bracers"] = Appearance.EDGE_TINTS[element].lerp(Appearance.ROBE_TINTS[element], 0.45)
	if pieces.has("boots"):
		out["boots"] = Appearance.ROBE_TINTS[pieces.boots.element].darkened(0.22)
	if pieces.has("charm"):
		out["charm"] = Appearance.EDGE_TINTS[pieces.charm.element]
	if pieces.has("ring"):
		out["ring"] = Appearance.EDGE_TINTS[pieces.ring.element]
	return out

# 战斗用的人物图集（4×3 格），按身上的装备染好。
static func texture(female: bool, look: Dictionary) -> Texture2D:
	return _dressed(SideArt.SPRITES[int(female)], "female" if female else "male", female, dyes(look))

static func _dressed(base: Texture2D, stem: String, female: bool, colors: Dictionary) -> Texture2D:
	if colors.is_empty():
		return base
	var key := stem
	for layer in LAYERS + ["ring"]:
		key += "/" + (colors[layer].to_html(false) if colors.has(layer) else "")
	if cache.has(key):
		return cache[key]
	var texture_out := _compose(base, stem, female, colors)
	if cache.size() >= CACHE_LIMIT:
		cache.erase(cache.keys()[0])
	cache[key] = texture_out
	return texture_out

static func _compose(base: Texture2D, stem: String, female: bool, colors: Dictionary) -> Texture2D:
	var sheet := SideArt.pixels(base)
	var area := Rect2i(Vector2i.ZERO, sheet.get_size())
	var flat := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for layer in LAYERS:
		if not colors.has(layer):
			continue
		# 图层只在换装时用一下，不常驻内存。
		var shade := SideArt.pixels(load("res://art/side/dye/%s-%s.png" % [stem, layer]))
		flat.fill(colors[layer])
		sheet.blend_rect_mask(flat, shade, area, Vector2i.ZERO)
		sheet.blend_rect(shade, area, Vector2i.ZERO)
	if colors.has("ring"):
		var fists: Array = HeldWeapon.LEAD[int(female)]
		for frame in range(fists.size()):
			_ring(sheet, Vector2i(SideArt.frame_region(frame).position), fists[frame], colors.ring)
	return SideArt.texture_from(sheet)

# 一圈指环：拳头上细细的一道，朝光的一侧亮、背光的一侧暗。只画在已有的手上，不改轮廓。
static func _ring(sheet: Image, origin: Vector2i, fist: Vector2, gem: Color) -> void:
	var k := SideArt.TEXEL
	var band := Rect2i(origin + Vector2i((fist + Vector2(-1.3, -1.2)) * k), Vector2i(k, roundi(2.4 * k)))
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			if sheet.get_pixel(x, y).a < 0.9:
				continue
			var across := float(x - band.position.x) / float(band.size.x - 1)
			sheet.set_pixel(x, y, gem.lightened(0.25).lerp(gem.darkened(0.45), across))
