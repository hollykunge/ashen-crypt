extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")
const BowPose = preload("res://scripts/bow_pose.gd")
# 手持兵器图集由 art/side/pack_weapons.py 从法器原画抠出，4 列 × 2 行。
const ATLAS_SHEET = preload("res://art/side/held-weapons.png")
const ATLAS_GRID := Vector2(4, 2)
static var ATLAS: CanvasTexture = SideArt.smooth(ATLAS_SHEET)

# 两手取自男女各自动作原画里的拳心。第一只手领招，第二只手持副刀或拉弦。
const LEAD := [
	[Vector2(59, 56), Vector2(66, 53), Vector2(63, 53), Vector2(65, 59), Vector2(38, 33), Vector2(78, 41),
	 Vector2(70, 64), Vector2(61, 43), Vector2(51, 50), Vector2(61, 45), Vector2(79, 32), Vector2(63, 52)],
	[Vector2(59, 55), Vector2(62, 52), Vector2(61, 55), Vector2(63, 58), Vector2(34, 33), Vector2(75, 45),
	 Vector2(65, 64), Vector2(60, 50), Vector2(53, 56), Vector2(59, 42), Vector2(77, 37), Vector2(60, 55)]
]
const SUPPORT := [
	[Vector2(46, 57), Vector2(41, 55), Vector2(36, 55), Vector2(40, 56), Vector2(36, 35), Vector2(75, 42),
	 Vector2(67, 62), Vector2(57, 46), Vector2(39, 59), Vector2(34, 52), Vector2(42, 50), Vector2(51, 54)],
	[Vector2(44, 56), Vector2(36, 56), Vector2(36, 56), Vector2(42, 58), Vector2(35, 35), Vector2(72, 46),
	 Vector2(63, 64), Vector2(47, 49), Vector2(33, 58), Vector2(32, 51), Vector2(40, 54), Vector2(51, 54)]
]
# 刀由近手持握，依每一格衣袖的走向选拳心。迈步时前后手会交替出现在轮廓外。
const NEAR_IS_LEAD := [
	[false, false, true, false, true, true, true, false, false, false, false, false],
	[false, false, false, false, true, true, true, false, false, false, false, false]
]
const SWING := [-0.76, 0.18, -0.12, -0.34, -2.04, -0.16, 0.55, -0.74, -0.48, -0.24, -0.42, 0.09]
const OFFHAND_SWING := [-0.94, -0.85, -0.91, -0.94, -1.57, -0.72, 0.02, -0.95, -1.12, -0.89, -0.96, -0.84]

# 素材空间为 128 × 128，一格原画。沿柄从握点看向护手或兵器头；横向翻转让刀的亮刃迎着下斩方向。
const FORMS := {
	"long_blade": {"cell": 0, "grip": Vector2(90, 17), "forward": Vector2(78, 33), "scale": Vector2(0.30, -0.29)},
	"dual_blades": {"cell": 0, "grip": Vector2(90, 17), "forward": Vector2(78, 33), "scale": Vector2(0.205, -0.22)},
	"hammer": {"cell": 1, "grip": Vector2(52, 70), "forward": Vector2(76, 33), "scale": Vector2(0.24, 0.21)},
	"staff": {"cell": 2, "grip": Vector2(66, 70), "forward": Vector2(66, 4), "scale": Vector2(0.22, 0.17)},
	"bow": {"cell": 3, "grip": Vector2(56, 60), "forward": Vector2(120, 8), "scale": Vector2(0.36, -0.36)},
	"spear": {"cell": 4, "grip": Vector2(52.7, 70.7), "forward": Vector2(107.5, 12.5), "scale": Vector2(0.27, 0.27)},
	"wand": {"cell": 5, "grip": Vector2(39, 87), "forward": Vector2(94.7, 18.7), "scale": Vector2(0.21, 0.21)},
	"sword": {"cell": 6, "grip": Vector2(64, 89), "forward": Vector2(64, 20), "scale": Vector2(0.31, 0.31)}
}
# 长柄兵器的杆由这里画：butt 是后手之后露出的柄尾，socket 是兵器头接在后手之前多远，
# clip 是原画只取上面多高（下面那截短柄让给画出来的长杆）。单位是人物的逻辑像素。
const POLES := {
	"hammer": {"butt": -5.5, "socket": 24.5, "clip": 78.0,
		"wood": Color("#a4774e"), "core": Color("#40302b"), "cap": Color("#d0ab73")},
	"staff": {"butt": -23.0, "socket": 25.5, "clip": 74.0,
		"wood": Color("#a4774e"), "core": Color("#40302b"), "cap": Color("#d0ab73")},
	"spear": {"butt": -17.0, "socket": 33.0, "clip": 128.0,
		"wood": Color("#5a5560"), "core": Color("#1d1a1c"), "cap": Color("#d0ab73")}
}
const STAFF_SOCKET := 25.5
# 双拳并在一起的那几格看不出杆的朝向，长枪按出枪的路线单独给：收在肩后、平刺、枪尖略沉、收回。
const SPEAR_AIM := {4: -0.07, 5: -0.03, 6: 0.16, 7: -0.46}
# 握拳处从人物贴图上再盖一小块回来，半径是逻辑像素。
const FIST := 3.2

static func placement(form: String, grip: Vector2, angle: float) -> Transform2D:
	var spec: Dictionary = FORMS[form]
	var source_axis: Vector2 = spec.forward - spec.grip
	var axes := Transform2D(angle, Vector2.ZERO).scaled_local(spec.scale)
	var pose := axes * Transform2D(-source_axis.angle(), Vector2.ZERO)
	pose.origin = grip - pose.basis_xform(spec.grip)
	return pose

static func _draw_art(canvas: CanvasItem, form: String, grip: Vector2, angle: float, ink: Color, height := 128.0) -> void:
	var pose := placement(form, grip, angle)
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(128, 0), Vector2(128, height), Vector2(0, height)])
	var cell: int = FORMS[form].cell
	var column := Vector2(cell % int(ATLAS_GRID.x), floori(cell / ATLAS_GRID.x))
	var uvs := PackedVector2Array()
	for p in corners:
		uvs.append((column + p / 128.0) / ATLAS_GRID)
	canvas.draw_polygon(pose * corners, PackedColorArray([ink]), uvs, ATLAS)

# 出手格的箭尖、杖头或短杖尖，坐标原点在角色脚底。
static func release_point(sex: int, magic: bool, wand := false) -> Vector2:
	var palm: Vector2 = LEAD[sex][10] - SideArt.PIVOT
	if not magic:
		return palm + Vector2(8, 0)
	var angle: float = SWING[10]
	if wand:
		return placement("wand", palm, angle) * Vector2(FORMS.wand.forward)
	var socket := palm + Vector2.from_angle(angle) * STAFF_SOCKET
	return placement("staff", socket, angle) * Vector2(FORMS.staff.forward)

static func arrow_length(sex: int) -> float:
	return release_point(sex, false).distance_to(BowPose.nock_hand(sex, false) - SideArt.PIVOT)

static func body_frame(form: String, frame: int) -> int:
	if frame == 0:
		return 3 if form in ["dual_blades", "hammer", "bow", "spear"] else 7
	if form == "bow" and frame in [4, 5]:
		return 10
	return frame

static func blade_hand(sex: int, body: int, offhand := false) -> Vector2:
	return LEAD[sex][body] if NEAR_IS_LEAD[sex][body] != offhand else SUPPORT[sex][body]

# 兵器画在身体上面，握柄的那只手得再盖回来：从同一张人物贴图上取拳头那一小圆，
# 换装后的护手、戒指也就跟着在柄前面了。hand 是分格内的逻辑坐标。
static func _fist(canvas: CanvasItem, sprite: Texture2D, source: Vector2, origin: Vector2, hand: Vector2, ink: Color) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var size := sprite.get_size()
	for i in range(14):
		var at := hand + Vector2.from_angle(i * TAU / 14.0) * FIST
		points.append(origin + at)
		uvs.append((source + at * SideArt.TEXEL) / size)
	canvas.draw_polygon(points, PackedColorArray([ink]), uvs, sprite)

static func _draw_pole(canvas: CanvasItem, form: String, origin: Vector2, angle: float, ink: Color) -> void:
	var t := Transform2D(angle, origin)
	var pole: Dictionary = POLES[form]
	var axis := t.x
	var across := t.y
	var start: Vector2 = origin + axis * float(pole.butt)
	var socket: Vector2 = origin + axis * float(pole.socket)
	var wood: Color = pole.wood
	var core: Color = pole.core
	var cap: Color = pole.cap
	# 杆：一道深色的芯勾出轮廓，上沿压一条受光的木色，两头各箍一道铜。
	canvas.draw_line(start, socket, core * ink, 2.9, true)
	canvas.draw_line(start - across * 0.45, socket - across * 0.45, wood * ink, 1.3, true)
	canvas.draw_line(start - across * 0.9, socket - across * 0.9, wood.lightened(0.35) * ink, 0.45, true)
	canvas.draw_line(start, start + axis * 2.4, cap * ink, 3.1, true)
	canvas.draw_line(start + axis * 2.4, start + axis * 3.0, core * ink, 3.1, true)
	canvas.draw_line(socket - axis * 2.2, socket + axis, cap.darkened(0.08) * ink, 3.3, true)
	if form == "spear":
		var band := start.lerp(socket, 0.30)
		canvas.draw_line(band, band + axis * 1.8, cap * ink, 3.1, true)
	_draw_art(canvas, form, socket, angle, ink, float(pole.clip))

static func _draw_bow(canvas: CanvasItem, palm: Vector2, nock: Vector2, drawing: bool, horizontal: bool, ink: Color) -> void:
	var angle := -PI / 2 if horizontal else -1.20
	var pose := placement("bow", palm, angle)
	var top := pose * Vector2(120, 8)
	var bottom := pose * Vector2(9, 119)
	var string_center := nock if drawing else (top + bottom) * 0.5
	canvas.draw_polyline(PackedVector2Array([top, string_center, bottom]), Color("#d4c4a5") * ink, 0.7, true)
	if drawing:
		var aim := (palm - nock).normalized()
		var tip := palm + aim * 8
		canvas.draw_line(nock, tip, Color("#ba8c58") * ink, 1.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([tip + aim * 2.5, tip + aim.orthogonal() * 1.25,
			tip - aim.orthogonal() * 1.25]), Color("#c4cbd0") * ink)
	_draw_art(canvas, "bow", palm, angle, ink)

static func draw_actor(canvas: CanvasItem, sprite: Texture2D, sex: int, frame: int, look: Dictionary,
		ink := Color.WHITE, gait := {}, foot_shift := Vector2.ZERO, offset := Vector2.ZERO) -> void:
	var form: String = look.form if FORMS.has(look.form) else "long_blade"
	var body := body_frame(form, frame)
	var origin := offset - SideArt.PIVOT
	var lead: Vector2 = origin + LEAD[sex][body]
	var rear: Vector2 = origin + SUPPORT[sex][body]
	var primary := origin + blade_hand(sex, body)
	var secondary := origin + blade_hand(sex, body, true)
	var angle: float = SWING[frame]
	if form == "dual_blades" and frame in [0, 3, 7, 8]:
		angle = 0.09
	var metal: Color = ink * Color.WHITE.lerp(look.weapon, 0.34)
	var drawn_bow := form == "bow" and frame in [4, 5]
	# 握拳那一小块从哪张贴图、哪一格取：满弓格用的是改过袖子的单格贴图。
	var hand_sprite := sprite
	var hand_source := SideArt.frame_region(body).position
	if form == "dual_blades":
		_draw_art(canvas, form, secondary, OFFHAND_SWING[frame], metal.darkened(0.12))
	# 长枪收到肩后的那一格，枪杆在头的另一侧：先画杆再画人，不然杆会横在脸上。
	var shouldered := form == "spear" and frame == 4
	if shouldered:
		_draw_pole(canvas, form, lead - Vector2.from_angle(SPEAR_AIM[4]) * 5.5, SPEAR_AIM[4], metal)
	if drawn_bow:
		hand_sprite = BowPose.texture(sprite, sex, frame == 5)
		hand_source = Vector2.ZERO
		canvas.draw_texture_rect(hand_sprite, Rect2(origin, SideArt.CELL), false, ink)
	elif gait.is_empty():
		canvas.draw_texture_rect_region(sprite, Rect2(origin, SideArt.CELL), SideArt.frame_region(body), ink)
	else:
		SideArt.draw_gait(canvas, sprite, gait, foot_shift, ink)
	var hands := [lead]
	match form:
		"bow":
			var nock := origin + BowPose.nock_hand(sex, frame == 5)
			_draw_bow(canvas, lead, nock, frame == 4, drawn_bow, metal)
		"hammer", "spear":
			# 架着的时候两拳夹住长柄，挥击格双拳已在身前并拢。
			var rear_grip := lead
			var two_handed := frame in [0, 3, 4, 5, 6, 7]
			if two_handed:
				hands.append(rear)
				if lead.distance_to(rear) >= 7.0:
					angle = (lead - rear).angle()
					rear_grip = rear
				else:
					if form == "spear":
						angle = SPEAR_AIM.get(frame, angle)
					rear_grip = lead - Vector2.from_angle(angle) * 5.5
			elif frame in [1, 2, 11]:
				angle = -0.98
			if not shouldered:
				_draw_pole(canvas, form, rear_grip, angle, metal)
		"staff":
			if frame in [0, 1, 2, 3, 7, 11]:
				angle = -1.40
			_draw_pole(canvas, form, lead, angle, metal)
		"wand":
			if frame in [0, 1, 2, 3, 7, 11]:
				angle = -1.02
			_draw_art(canvas, form, lead, angle, metal)
		_:
			hands = [primary]
			_draw_art(canvas, form, primary, angle, metal)
	for hand: Vector2 in hands:
		_fist(canvas, hand_sprite, hand_source, origin, hand - origin, ink)
