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

# 每一行对应原图集的一格。坐标依次是近肩、腰带、近肘、近腕、两只脚踝，单位是 96 像素的逻辑分格。
# pack_frames.py 按这些关节划分染色区，改了这里要重新出图。
const MALE := [
	[Vector2(46,34),Vector2(50,57),Vector2(43,46),Vector2(45,56),Vector2(43,85),Vector2(53,85)],
	[Vector2(48,34),Vector2(48,58),Vector2(45,44),Vector2(41,55),Vector2(35,85),Vector2(64,84)],
	[Vector2(46,35),Vector2(49,58),Vector2(52,45),Vector2(61,52),Vector2(32,83),Vector2(51,85)],
	[Vector2(48,42),Vector2(48,61),Vector2(36,49),Vector2(40,57),Vector2(25,85),Vector2(67,84)],
	[Vector2(53,38),Vector2(49,57),Vector2(37,43),Vector2(37,34),Vector2(30,84),Vector2(68,85)],
	[Vector2(50,40),Vector2(43,58),Vector2(62,43),Vector2(76,41),Vector2(18,85),Vector2(65,85)],
	[Vector2(54,44),Vector2(46,61),Vector2(57,55),Vector2(65,59),Vector2(19,85),Vector2(63,85)],
	[Vector2(47,35),Vector2(49,57),Vector2(45,46),Vector2(56,46),Vector2(38,84),Vector2(62,85)],
	[Vector2(28,42),Vector2(44,61),Vector2(30,52),Vector2(40,58),Vector2(37,84),Vector2(59,85)],
	[Vector2(37,39),Vector2(49,58),Vector2(28,47),Vector2(34,52),Vector2(34,85),Vector2(61,85)],
	[Vector2(45,34),Vector2(46,55),Vector2(35,43),Vector2(42,51),Vector2(30,84),Vector2(65,85)],
	[Vector2(48,34),Vector2(50,55),Vector2(47,45),Vector2(49,53),Vector2(42,81),Vector2(52,85)],
]
const FEMALE := [
	[Vector2(46,34),Vector2(49,56),Vector2(43,46),Vector2(44,55),Vector2(42,84),Vector2(51,85)],
	[Vector2(47,35),Vector2(48,57),Vector2(41,47),Vector2(37,55),Vector2(32,83),Vector2(63,84)],
	[Vector2(47,35),Vector2(48,57),Vector2(41,46),Vector2(36,55),Vector2(32,85),Vector2(61,83)],
	[Vector2(51,41),Vector2(48,61),Vector2(37,49),Vector2(42,57),Vector2(27,84),Vector2(62,85)],
	[Vector2(51,40),Vector2(48,57),Vector2(31,44),Vector2(34,35),Vector2(30,84),Vector2(67,85)],
	[Vector2(51,43),Vector2(45,60),Vector2(60,46),Vector2(72,45),Vector2(16,85),Vector2(61,85)],
	[Vector2(48,44),Vector2(45,61),Vector2(54,56),Vector2(63,63),Vector2(20,84),Vector2(59,85)],
	[Vector2(46,36),Vector2(49,58),Vector2(38,47),Vector2(48,48),Vector2(32,84),Vector2(62,85)],
	[Vector2(30,44),Vector2(43,61),Vector2(24,55),Vector2(32,57),Vector2(28,84),Vector2(57,85)],
	[Vector2(31,39),Vector2(47,59),Vector2(25,48),Vector2(32,51),Vector2(38,85),Vector2(56,85)],
	[Vector2(47,37),Vector2(46,57),Vector2(35,50),Vector2(42,53),Vector2(24,84),Vector2(63,85)],
	[Vector2(48,34),Vector2(50,57),Vector2(46,46),Vector2(50,55),Vector2(38,84),Vector2(57,85)],
]
# 远侧的肘腕，用来贴合背面的护臂。
const FAR_ARMS := [
	[[Vector2(57,46),Vector2(59,56)], [Vector2(59,49),Vector2(65,53)], [Vector2(39,46),Vector2(37,54)],
	 [Vector2(57,55),Vector2(64,59)], [Vector2(48,42),Vector2(40,36)], [Vector2(58,45),Vector2(69,43)],
	 [Vector2(61,58),Vector2(70,64)], [Vector2(55,47),Vector2(62,43)], [Vector2(44,51),Vector2(51,51)],
	 [Vector2(53,46),Vector2(61,46)], [Vector2(65,35),Vector2(79,33)], [Vector2(55,47),Vector2(62,52)]],
	[[Vector2(57,46),Vector2(59,55)], [Vector2(56,49),Vector2(62,53)], [Vector2(55,47),Vector2(61,56)],
	 [Vector2(53,57),Vector2(63,58)], [Vector2(48,42),Vector2(39,36)], [Vector2(57,48),Vector2(68,46)],
	 [Vector2(57,61),Vector2(66,64)], [Vector2(55,49),Vector2(60,49)], [Vector2(45,56),Vector2(53,57)],
	 [Vector2(50,43),Vector2(60,42)], [Vector2(62,40),Vector2(77,37)], [Vector2(55,49),Vector2(60,55)]]
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

static func texture(female: bool, look: Dictionary) -> Texture2D:
	var colors := dyes(look)
	if colors.is_empty():
		return SideArt.SPRITES[int(female)]
	var key := "f" if female else "m"
	for layer in LAYERS + ["ring"]:
		key += "/" + (colors[layer].to_html(false) if colors.has(layer) else "")
	if cache.has(key):
		return cache[key]
	var texture_out := _compose(female, colors)
	if cache.size() >= CACHE_LIMIT:
		cache.erase(cache.keys()[0])
	cache[key] = texture_out
	return texture_out

static func _compose(female: bool, colors: Dictionary) -> Texture2D:
	var sheet := SideArt.pixels(SideArt.SPRITES[int(female)])
	var area := Rect2i(Vector2i.ZERO, sheet.get_size())
	var flat := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for layer in LAYERS:
		if not colors.has(layer):
			continue
		# 图层只在换装时用一下，不常驻内存。
		var shade := SideArt.pixels(load("res://art/side/dye/%s-%s.png" % ["female" if female else "male", layer]))
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
