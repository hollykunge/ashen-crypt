extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")

# 放箭格的前臂已经伸直。将靠镜头的衣袖、护腕和手从原格中取出，折回面颊。
# 六个关节分别是原肩、肘、拳心，以及满弓时的肩、肘、拳心。
const JOINTS := [
	[Vector2(33, 37), Vector2(29, 47), Vector2(38, 53), Vector2(35, 38), Vector2(25, 33), Vector2(44, 32)],
	[Vector2(39, 40), Vector2(36, 49), Vector2(41, 53), Vector2(40, 40), Vector2(29, 36), Vector2(43, 34)]
]
const UPPER := [
	[Vector2(28, 33), Vector2(36, 33), Vector2(38, 39), Vector2(36, 46), Vector2(30, 49), Vector2(25, 46), Vector2(25, 38)],
	[Vector2(36, 38), Vector2(42, 39), Vector2(41, 45), Vector2(38, 50), Vector2(33, 50), Vector2(33, 44)]
]
const LOWER := [
	[Vector2(26, 44), Vector2(34, 42), Vector2(38, 47), Vector2(42, 50), Vector2(42, 56), Vector2(37, 58), Vector2(31, 54), Vector2(26, 49)],
	[Vector2(32, 47), Vector2(38, 47), Vector2(43, 50), Vector2(44, 56), Vector2(41, 57), Vector2(36, 55), Vector2(32, 51)]
]
# 抽走手臂后留下的洞：缝线以左挖空（那里本是手臂伸出轮廓的部分），以右用洞右边的袍料对折补上，
# 腰带、衣襟这类横线就顺着接过去。缝线随高度从 top 斜到 bottom。男角膀大，手臂整个压在背上，缝线要往后放。
const SEAM := [{"top": 30.0, "bottom": 28.0}, {"top": 38.0, "bottom": 35.0}]
static var cache := {}

static func nock_hand(sex: int, release: bool) -> Vector2:
	return Vector2(JOINTS[sex][5]) - Vector2(4 if release else 0, 0)

static func texture(sprite: Texture2D, sex: int, release: bool) -> Texture2D:
	if cache.has(sprite):
		return cache[sprite][int(release)]
	var source := SideArt.pixels(sprite).get_region(Rect2i(SideArt.frame_region(10)))
	if cache.size() >= 4:
		cache.erase(cache.keys()[0])
	cache[sprite] = [_pose(source, sex, false), _pose(source, sex, true)]
	return cache[sprite][int(release)]

# 关节和袖片都标在 96 像素的逻辑分格里，贴图是它的 TEXEL 倍：逐贴图像素扫，换回逻辑坐标去判断。
static func _pose(source: Image, sex: int, release: bool) -> Texture2D:
	var k := SideArt.TEXEL
	var frame: Image = source.duplicate()
	var sleeve := PackedVector2Array(UPPER[sex])
	var forearm := PackedVector2Array(LOWER[sex])
	var cut: Dictionary = SEAM[sex]
	var left := 22 * k
	var right := 48 * k
	for y in range(30 * k, 59 * k):
		var hole := PackedByteArray()
		hole.resize(right - left + 1)
		for x in range(left, right):
			var at := Vector2(x + 0.5, y + 0.5) / k
			hole[x - left] = int(Geometry2D.is_point_in_polygon(at, sleeve) or Geometry2D.is_point_in_polygon(at, forearm))
		var edge := right
		for x in range(right - 1, left - 1, -1):
			if hole[x - left] == 0:
				edge = x
				continue
			var at := Vector2(x + 0.5, y + 0.5) / k
			var seam := lerpf(cut.top, cut.bottom, clampf((at.y - 34.0) / 21.0, 0.0, 1.0))
			if at.x < seam:
				frame.set_pixel(x, y, Color.TRANSPARENT)
				continue
			# 以洞的右沿为轴对折取料，取到六格以外就折回来，免得借到太远的衣襟和符牌。
			var reach := (edge - x) % (6 * k)
			frame.set_pixel(x, y, source.get_pixel(mini(edge + reach, source.get_width() - 1), y))
	var j: Array = JOINTS[sex]
	_move_sleeve(frame, source, sleeve, j[0], j[1], j[3], j[4])
	_move_sleeve(frame, source, forearm, j[1], j[2], j[4], nock_hand(sex, release))
	return SideArt.texture_from(frame)

static func _move_sleeve(frame: Image, source: Image, shape: PackedVector2Array,
		start: Vector2, end: Vector2, posed_start: Vector2, posed_end: Vector2) -> void:
	var k := SideArt.TEXEL
	var old_axis := end - start
	var new_axis := posed_end - posed_start
	var src := Transform2D(old_axis, old_axis.normalized().orthogonal(), start)
	var dst := Transform2D(new_axis, new_axis.normalized().orthogonal(), posed_start)
	var to_source := src * dst.affine_inverse()
	var posed := to_source.affine_inverse() * shape
	var bounds := Rect2(posed[0], Vector2.ZERO)
	for vertex in posed:
		bounds = bounds.expand(vertex)
	var limit := source.get_size()
	for y in range(floori(bounds.position.y * k), ceili(bounds.end.y * k)):
		for x in range(floori(bounds.position.x * k), ceili(bounds.end.x * k)):
			var uv := to_source * (Vector2(x + 0.5, y + 0.5) / k)
			if Geometry2D.is_point_in_polygon(uv, shape):
				var texel := Vector2i((uv * k).floor()).clamp(Vector2i.ZERO, limit - Vector2i.ONE)
				frame.set_pixel(x, y, frame.get_pixel(x, y).blend(source.get_pixelv(texel)))
