extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")
const Appearance = preload("res://scripts/appearance.gd")
const Equipment = preload("res://scripts/equipment.gd")

# 每一行对应原图集的一格。坐标依次是近肩、腰带、近肘、近腕、两只脚踝。
# 保留原图的脸和手，将衣片贴在这些关节之间，再将整张图交给原来的动作系统。
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
const LAYERS := ["armor", "gloves", "boots", "charm", "ring"]
# 素材坐标在各自的 128 像素图标内，分别取胸襟、下摆和肩部。
const ARMOR_CUTS := {
	7: [Rect2i(40,20,52,57), Rect2i(28,82,76,36), Rect2i(20,12,26,30)],
	4: [Rect2i(42,22,48,53), Rect2i(36,82,57,33), Rect2i(18,20,24,25)],
	15: [Rect2i(36,21,52,58), Rect2i(31,90,65,27), Rect2i(27,17,15,36)],
	16: [Rect2i(39,19,52,60), Rect2i(35,85,65,34), Rect2i(30,28,22,31)],
}
const BRACERS := {17: Rect2i(22,22,29,78), 18: Rect2i(23,25,33,69), 19: Rect2i(18,25,36,58)}
const BOOTS := {20: Rect2i(32,17,30,71), 21: Rect2i(31,17,30,67), 22: Rect2i(71,52,29,43)}
const CACHE_LIMIT := 4
static var cache := {}
static var materials: Image

static func texture(female: bool, look: Dictionary) -> Texture2D:
	var key := "f" if female else "m"
	var pieces: Dictionary = look.pieces
	for slot in LAYERS:
		var piece: Dictionary = pieces.get(slot, {})
		key += "/%s%d" % [piece.get("element", ""), piece.get("polarity", 0)]
	var source: Texture2D = SideArt.SPRITES[int(female)]
	if pieces.is_empty() or (pieces.size() == 1 and pieces.has("weapon")):
		return source
	if cache.has(key):
		return cache[key]
	if materials == null:
		materials = ForgeArt.ATLAS.get_image()
		if materials.is_compressed():
			materials.decompress()
		# 图标原画较大，先缩小可以保留织物、甲片纹理，避免在人物上出现杂色噪点。
		materials.resize(384, 320, Image.INTERPOLATE_LANCZOS)
	var painter := Composer.new()
	painter.atlas = materials
	var texture_out := painter.compose(source, female, pieces)
	if cache.size() >= CACHE_LIMIT:
		cache.erase(cache.keys()[0])
	cache[key] = texture_out
	return texture_out

class Composer:
	var atlas: Image
	var base: Image
	var sheet: Image
	var origin: Vector2i
	var styles := {}

	func compose(source: Texture2D, female: bool, pieces: Dictionary) -> Texture2D:
		base = source.get_image()
		if base.is_compressed():
			base.decompress()
		base.convert(Image.FORMAT_RGBA8)
		sheet = base.duplicate()
		for slot in LAYERS:
			if pieces.has(slot):
				var piece: Dictionary = pieces[slot]
				var trim: Color = Appearance.YIN_TRIM if piece.polarity < 0 else Appearance.YANG_TRIM
				styles[slot] = {
					"icon": ForgeArt.item_index(Equipment.SLOTS.find(slot), piece.element, female),
					"dye": Appearance.ROBE_TINTS[piece.element], "trim": trim,
					"gem": Appearance.EDGE_TINTS[piece.element]
				}
		var poses := FEMALE if female else MALE
		for frame in range(poses.size()):
			origin = Vector2i(SideArt.frame_region(frame).position)
			_dress(poses[frame], FAR_ARMS[int(female)][frame])
		return ImageTexture.create_from_image(sheet)

	func _dress(pose: Array, far_arm: Array) -> void:
		var shoulder: Vector2 = pose[0]
		var belt: Vector2 = pose[1]
		var elbow: Vector2 = pose[2]
		var wrist: Vector2 = pose[3]
		if styles.has("boots"):
			for ankle: Vector2 in [pose[4], pose[5]]:
				_boot(ankle, belt, styles.boots)
		if styles.has("gloves"):
			_bracer(far_arm[0], far_arm[1])
		if styles.has("armor"):
			var armor: Dictionary = styles.armor
			var cuts: Array = ARMOR_CUTS[armor.icon]
			var metal: bool = armor.icon in [4, 7]
			var robe: bool = armor.icon == 16
			var drape := belt + Vector2(-10, -5)
			var tail := drape + Vector2(-6, 19 if robe else 12)
			_wrap(shoulder, drape, 3, 4, armor, cuts[1], false, true)
			_wrap(drape, tail, 4, 1, armor, cuts[1], false, true)
			for leg in [0, 1]:
				var ankle: Vector2 = pose[4 + leg]
				var end := belt.lerp(ankle, 0.69 if robe else (0.50 if metal else 0.38))
				var hem: Rect2i = cuts[1]
				hem.size.x /= 2
				hem.position.x += leg * hem.size.x
				_wrap(belt + Vector2(leg * 7 - 4, -1), end, 5, 7 if robe else 5, armor, hem)
			_wrap(shoulder + Vector2(4, 0), belt + Vector2(1, 2), 9 if metal else 7, 7, armor, cuts[0])
			var buckle := belt + Vector2(1, -1)
			_wrap(buckle, buckle + Vector2(0, 3), 8, 8, armor, Rect2i(42,71,47,11))
		if styles.has("charm"):
			var charm_at := (shoulder + Vector2(5, 0)).lerp(belt, 0.46) + Vector2(3, 0)
			_jewel(charm_at, styles.charm, true)
		if styles.has("armor") or styles.has("charm"):
			# 抡刀、施法时，靠近镜头的原画衣袖和手会从胸甲前划过。
			_wrap(shoulder, elbow, 4, 3, {}, Rect2i())
			_wrap(elbow, wrist, 3, 2, {}, Rect2i())
		if styles.has("armor"):
			var armor: Dictionary = styles.armor
			var heavy: bool = armor.icon in [4, 7]
			_wrap(shoulder - Vector2(0, 1), shoulder.lerp(elbow, 0.58), 6 if heavy else 4, 5 if heavy else 3,
				armor, ARMOR_CUTS[armor.icon][2])
		if styles.has("gloves"):
			_bracer(elbow, wrist)
		if styles.has("ring"):
			_jewel(wrist + Vector2(1, 0), styles.ring, false)

	func _bracer(elbow: Vector2, wrist: Vector2) -> void:
		var style: Dictionary = styles.gloves
		_wrap(elbow.lerp(wrist, 0.15), wrist, 3.6, 2.5, style, BRACERS[style.icon], true)

	func _boot(ankle: Vector2, belt: Vector2, style: Dictionary) -> void:
		var shin := Vector2(lerpf(ankle.x, belt.x, 0.18), ankle.y - (7 if style.icon == 22 else 11))
		var leather: Rect2i = BOOTS[style.icon]
		_wrap(shin, ankle + Vector2(0, 1), 3.7, 2.8, style, leather, true)
		_wrap(ankle - Vector2(0, 1), ankle + Vector2(6, 2), 3, 1.6, style, leather, true)

	func _jewel(at: Vector2, style: Dictionary, pendant: bool) -> void:
		var point := origin + Vector2i(at.round())
		var trim: Color = style.trim
		if pendant:
			for i in range(4):
				sheet.set_pixelv(point + Vector2i(-i, -i - 1), trim.darkened(0.30))
				sheet.set_pixelv(point + Vector2i(i / 2, -i - 1), trim.darkened(0.42))
			sheet.fill_rect(Rect2i(point - Vector2i(1, 1), Vector2i(3, 5)), trim.darkened(0.38))
		sheet.set_pixelv(point, style.gem)
		sheet.set_pixelv(point + Vector2i.DOWN, style.dye)
		sheet.set_pixelv(point + Vector2i.RIGHT, trim)

	# 将一段原画包在两关节之间。空 style 表示从底图恢复前景衣袖，鞋履须贴合脚的剪影。
	func _wrap(start: Vector2, end: Vector2, top: float, bottom: float,
			style: Dictionary, cut: Rect2i, clip_to_body := false, behind_body := false) -> void:
		var direction := end - start
		var length := direction.length()
		if length < 0.1:
			return
		direction /= length
		var across := Vector2(direction.y, -direction.x)
		var pad := Vector2.ONE * maxf(top, bottom)
		var lo := Vector2i((start.min(end) - pad).floor()).max(Vector2i.ZERO)
		var hi := Vector2i((start.max(end) + pad).ceil()).min(Vector2i(SideArt.CELL))
		var restore := style.is_empty()
		var source := Vector2.ZERO
		var sample_size := Vector2(cut.size) * 0.5
		if not restore:
			source = (ForgeArt.region(style.icon).position + Vector2(cut.position)) * 0.5
		for y in range(lo.y, hi.y):
			for x in range(lo.x, hi.x):
				var offset := Vector2(x + 0.5, y + 0.5) - start
				var v := offset.dot(direction) / length
				if v < 0.0 or v >= 1.0:
					continue
				var u := 0.5 + offset.dot(across) / (2.0 * lerpf(top, bottom, v))
				if u < 0.0 or u >= 1.0:
					continue
				var pixel := origin + Vector2i(x, y)
				if behind_body and base.get_pixelv(pixel).a > 0.3:
					continue
				if restore or clip_to_body:
					var skin := base.get_pixelv(pixel)
					if skin.a < 0.4:
						continue
					if restore:
						sheet.set_pixelv(pixel, skin)
						continue
				var texel := atlas.get_pixelv(Vector2i(source + Vector2(u, v) * sample_size))
				if texel.r8 < 18 and texel.g8 < 32 and texel.b8 < 32:
					continue
				var dye: Color = style.dye
				var lit := clampf(0.16 + texel.get_luminance() * 1.45, 0.0, 1.0)
				var color := texel.lerp(dye * lit, 0.48)
				color.a = 1.0
				if v < 0.08:
					color = color.lerp(style.trim, 0.55)
				sheet.set_pixelv(pixel, color.darkened(0.32) if behind_body else color)
