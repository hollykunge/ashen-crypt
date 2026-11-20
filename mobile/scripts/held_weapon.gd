extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")
const BowPose = preload("res://scripts/bow_pose.gd")
const ATLAS = preload("res://art/side/held-weapons.png")

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

# 素材空间为 128 × 128。沿柄从握点看向护手或兵器头；横向翻转让刀的亮刃迎着下斩方向。
const STAFF_SOCKET := 25.5
const FORMS := {
	"long_blade": {"cell": 0, "grip": Vector2(90, 17), "forward": Vector2(78, 33), "scale": Vector2(0.30, -0.29)},
	"dual_blades": {"cell": 0, "grip": Vector2(90, 17), "forward": Vector2(78, 33), "scale": Vector2(0.205, -0.22)},
	"hammer": {"cell": 1, "grip": Vector2(52, 70), "forward": Vector2(76, 33), "scale": Vector2(0.24, 0.21)},
	"staff": {"cell": 2, "grip": Vector2(66, 70), "forward": Vector2(66, 4), "scale": Vector2(0.22, 0.17)},
	"bow": {"cell": 3, "grip": Vector2(56, 60), "forward": Vector2(120, 8), "scale": Vector2(0.36, -0.36)}
}

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
	var uvs := PackedVector2Array()
	for p in corners:
		uvs.append(Vector2((FORMS[form].cell + p.x / 128.0) * 0.25, p.y / 128.0))
	canvas.draw_polygon(pose * corners, PackedColorArray([ink]), uvs, ATLAS)

# 出手格的箭尖或杖头，坐标原点在角色脚底。
static func release_point(sex: int, magic: bool) -> Vector2:
	var palm: Vector2 = LEAD[sex][10] - SideArt.PIVOT
	if not magic:
		return palm + Vector2(8, 0)
	var angle: float = SWING[10]
	var socket := palm + Vector2.from_angle(angle) * STAFF_SOCKET
	return placement("staff", socket, angle) * Vector2(FORMS.staff.forward)

static func arrow_length(sex: int) -> float:
	return release_point(sex, false).distance_to(BowPose.nock_hand(sex, false) - SideArt.PIVOT)

static func body_frame(form: String, frame: int) -> int:
	if frame == 0:
		return 3 if form in ["dual_blades", "hammer", "bow"] else 7
	if form == "bow" and frame in [4, 5]:
		return 10
	return frame

static func blade_hand(sex: int, body: int, offhand := false) -> Vector2:
	return LEAD[sex][body] if NEAR_IS_LEAD[sex][body] != offhand else SUPPORT[sex][body]

# 用人物像素绘出扣在握柄前的指节，拇指朝护手，护手和尾帽在拳头两侧露出。
static func _grasp(canvas: CanvasItem, center: Vector2, angle: float, ink: Color) -> void:
	var t := Transform2D(angle, center)
	var knuckles := PackedVector2Array([Vector2(-2.4, -1.3), Vector2(1.1, -2.1), Vector2(2.1, -0.8),
		Vector2(1.4, 1.7), Vector2(-1.5, 1.9), Vector2(-2.5, 0.8)])
	canvas.draw_colored_polygon(t * knuckles, Color("#a57f64") * ink)
	canvas.draw_line(t * Vector2(-1.6, 1.1), t * Vector2(0.7, 1.4), Color("#735749") * ink, 0.85)
	canvas.draw_line(t * Vector2(1.6, -1.0), t * Vector2(0.6, 0.35), Color("#d5af88") * ink, 1.15)

static func _draw_pole(canvas: CanvasItem, form: String, origin: Vector2, angle: float, ink: Color) -> void:
	var t := Transform2D(angle, origin)
	var staff := form == "staff"
	var end := STAFF_SOCKET if staff else 24.5
	var butt := -23.0 if staff else -5.5
	var axis := t.x
	var across := t.y
	var start := origin + axis * butt
	var socket := origin + axis * end
	canvas.draw_line(start, socket, Color("#40302b") * ink, 2.8)
	canvas.draw_line(start - across * 0.4, socket - across * 0.4, Color("#a4774e") * ink, 1.35)
	canvas.draw_line(start, start + axis * 2.2, Color("#d0ab73") * ink, 2.8)
	canvas.draw_line(socket - axis * 2.0, socket + axis, Color("#c39959") * ink, 3.1)
	_draw_art(canvas, form, socket, angle, ink, 74.0 if staff else 78.0)

static func _draw_bow(canvas: CanvasItem, palm: Vector2, nock: Vector2, drawing: bool, horizontal: bool, ink: Color) -> void:
	var angle := -PI / 2 if horizontal else -1.20
	var pose := placement("bow", palm, angle)
	var top := pose * Vector2(120, 8)
	var bottom := pose * Vector2(9, 119)
	var string_center := nock if drawing else (top + bottom) * 0.5
	canvas.draw_polyline(PackedVector2Array([top, string_center, bottom]), Color("#d4c4a5") * ink, 0.85)
	if drawing:
		var aim := (palm - nock).normalized()
		var tip := palm + aim * 8
		canvas.draw_line(nock, tip, Color("#ba8c58") * ink, 1.1)
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
	var metal: Color = ink * Color.WHITE.lerp(look.weapon, 0.42)
	var drawn_bow := form == "bow" and frame in [4, 5]
	if form == "dual_blades":
		_draw_art(canvas, form, secondary, OFFHAND_SWING[frame], metal.darkened(0.12))
	if drawn_bow:
		canvas.draw_texture(BowPose.texture(sprite, sex, frame == 5), origin, ink)
	elif gait.is_empty():
		canvas.draw_texture_rect_region(sprite, Rect2(origin, SideArt.CELL), SideArt.frame_region(body), ink)
	else:
		SideArt.draw_gait(canvas, sprite, gait, foot_shift, ink)
	match form:
		"bow":
			var nock := origin + BowPose.nock_hand(sex, frame == 5)
			_draw_bow(canvas, lead, nock, frame == 4, drawn_bow, metal)
			_grasp(canvas, lead, -PI / 2, ink)
		"hammer":
			# 架锤时两拳夹住长柄，挥击格双拳已在身前并拢。
			var rear_grip := lead
			var two_handed := frame in [0, 3, 4, 5, 6, 7]
			if two_handed:
				if lead.distance_to(rear) >= 7.0:
					angle = (lead - rear).angle()
					rear_grip = rear
				else:
					rear_grip = lead - Vector2.from_angle(angle) * 5.5
			elif frame in [1, 2, 11]:
				angle = -0.98
			_draw_pole(canvas, form, rear_grip, angle, metal)
			if two_handed:
				_grasp(canvas, rear_grip, angle, ink)
			_grasp(canvas, lead, angle, ink)
		"staff":
			if frame in [0, 1, 2, 3, 7, 11]:
				angle = -1.40
			_draw_pole(canvas, form, lead, angle, metal)
			_grasp(canvas, lead, angle, ink)
		_:
			_draw_art(canvas, form, primary, angle, metal)
			_grasp(canvas, primary, angle, ink)
