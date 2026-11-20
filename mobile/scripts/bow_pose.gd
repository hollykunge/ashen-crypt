extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")

# 放箭格的前臂已经伸直。将靠镜头的衣袖、护腕和手从原格中取出，折回面颊。
# 六个关节分别是原肩、肘、拳心，以及满弓时的肩、肘、拳心。
const JOINTS := [
	[Vector2(44, 34), Vector2(34, 44), Vector2(42, 51), Vector2(44, 34), Vector2(31, 35), Vector2(49, 32)],
	[Vector2(44, 38), Vector2(35, 50), Vector2(41, 54), Vector2(44, 38), Vector2(31, 40), Vector2(49, 37)]
]
const UPPER := [
	[Vector2(40, 30), Vector2(46, 32), Vector2(46, 37), Vector2(39, 46), Vector2(34, 48), Vector2(30, 45), Vector2(30, 41)],
	[Vector2(41, 35), Vector2(47, 36), Vector2(46, 41), Vector2(40, 50), Vector2(38, 54), Vector2(32, 54), Vector2(32, 49)]
]
const LOWER := [
	[Vector2(31, 42), Vector2(36, 42), Vector2(40, 46), Vector2(45, 48), Vector2(45, 52), Vector2(42, 54), Vector2(38, 52), Vector2(31, 47)],
	[Vector2(32, 48), Vector2(38, 48), Vector2(41, 51), Vector2(44, 51), Vector2(44, 55), Vector2(41, 58), Vector2(37, 56), Vector2(32, 54)]
]
static var cache := {}

static func nock_hand(sex: int, release: bool) -> Vector2:
	return Vector2(JOINTS[sex][5]) - Vector2(4 if release else 0, 0)

static func texture(sprite: Texture2D, sex: int, release: bool) -> Texture2D:
	if cache.has(sprite):
		return cache[sprite][int(release)]
	var source := sprite.get_image().get_region(Rect2i(SideArt.frame_region(10)))
	source.convert(Image.FORMAT_RGBA8)
	if cache.size() >= 4:
		cache.erase(cache.keys()[0])
	cache[sprite] = [_pose(source, sex, false), _pose(source, sex, true)]
	return cache[sprite][int(release)]

static func _pose(source: Image, sex: int, release: bool) -> Texture2D:
	var frame: Image = source.duplicate()
	var sleeve := PackedVector2Array(UPPER[sex])
	var forearm := PackedVector2Array(LOWER[sex])
	for y in range(30, 59):
		for x in range(29, 48):
			var at := Vector2(x + 0.5, y + 0.5)
			if not (Geometry2D.is_point_in_polygon(at, sleeve) or Geometry2D.is_point_in_polygon(at, forearm)):
				continue
			# 在旧手臂遮住腰身的部分接回相邻的袍料或腰带。
			var seam := lerpf(43.0, 38.0, clampf((at.y - 34.0) / 21.0, 0.0, 1.0))
			frame.set_pixel(x, y, source.get_pixel(47 + x % 3, y) if at.x >= seam else Color.TRANSPARENT)
	var j: Array = JOINTS[sex]
	_move_sleeve(frame, source, sleeve, j[0], j[1], j[3], j[4])
	_move_sleeve(frame, source, forearm, j[1], j[2], j[4], nock_hand(sex, release))
	return ImageTexture.create_from_image(frame)

static func _move_sleeve(frame: Image, source: Image, shape: PackedVector2Array,
		start: Vector2, end: Vector2, posed_start: Vector2, posed_end: Vector2) -> void:
	var old_axis := end - start
	var new_axis := posed_end - posed_start
	var src := Transform2D(old_axis, old_axis.normalized().orthogonal(), start)
	var dst := Transform2D(new_axis, new_axis.normalized().orthogonal(), posed_start)
	var to_source := src * dst.affine_inverse()
	var posed := to_source.affine_inverse() * shape
	var bounds := Rect2(posed[0], Vector2.ZERO)
	for vertex in posed:
		bounds = bounds.expand(vertex)
	for y in range(floori(bounds.position.y), ceili(bounds.end.y)):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x)):
			var uv := to_source * Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(uv, shape):
				var pixel := source.get_pixelv(Vector2i(uv.floor()))
				frame.set_pixel(x, y, frame.get_pixel(x, y).blend(pixel))
