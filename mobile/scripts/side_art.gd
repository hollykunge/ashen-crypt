extends RefCounted

const STREET = preload("res://art/side/shrine-street.webp")
const SNOW_PASS = preload("res://art/side/kunlun-snow-pass.webp")
const PORTRAITS := [preload("res://art/side/portrait-male.webp"), preload("res://art/side/portrait-female.webp")]
const SPRITES := [preload("res://art/side/frames-male.png"), preload("res://art/side/frames-female.png")]
const CELL := Vector2(96, 96)
const PIVOT := Vector2(47, 89)
const FLOOR := 0.747
const SNOW_FLOOR := 0.79
const KNEE_Y := 70.0
# 支撑脚从前脚跟滚到后脚尖。坐标在各自的 96 像素分格内。
const SOLES := [
	{1: Vector2(65, 88), 11: Vector2(54, 89), 2: Vector2(34, 88)},
	{1: Vector2(62, 88), 11: Vector2(53, 89), 2: Vector2(33, 88)},
]
const FRAMES := {&"ready": 0, &"guard": 3, &"windup": 4, &"strike": 5, &"follow": 6,
	&"recover": 7, &"dodge": 8, &"hurt": 9, &"cast": 10}

# 每个挂点跟着该格握柄的手，脚底在所有格里共用同一个锚点。
const GRIPS := [Vector2(59, 56), Vector2(63, 52), Vector2(62, 54), Vector2(63, 59),
	Vector2(37, 33), Vector2(77, 43), Vector2(69, 64), Vector2(60, 48),
	Vector2(52, 54), Vector2(61, 44), Vector2(79, 35), Vector2(61, 56)]
const ANGLES := [-0.58, -0.68, -0.49, -0.86, -2.20, -0.12, 0.40, -0.72, -0.71, 0.18, -0.67, -0.62]

static func frame_for(pose: StringName) -> int:
	return FRAMES.get(pose, 0)

static func gait(distance: float, actor_scale: float, sprite: int, running: bool) -> Dictionary:
	var step_length := (33.0 if running else 22.0) * actor_scale
	var phase := fposmod(distance / step_length, 1.0)
	var frame := 1 if phase < 0.29 else (11 if phase < 0.70 else 2)
	return {"frame": frame, "sole": SOLES[sprite][frame] - PIVOT,
		"plant": (0.5 - phase) * step_length, "phase": phase, "step_length": step_length}

static func draw_gait(canvas: CanvasItem, sprite: Texture2D, gait_pose: Dictionary,
		foot_shift: Vector2, ink: Color) -> void:
	var source := frame_region(gait_pose.frame)
	var upper := Vector2(CELL.x, KNEE_Y)
	canvas.draw_texture_rect_region(sprite, Rect2(-PIVOT, upper), Rect2(source.position, upper), ink)
	# 只让膝盖以下跟随落脚点，肩、腰和武器仍随角色位置连续移动。
	var top := Vector2(0.0, KNEE_Y) - PIVOT
	var sole_height := float(gait_pose.sole.y) + PIVOT.y - KNEE_Y
	var bottom := Vector2(0.0, CELL.y) - PIVOT + foot_shift * ((CELL.y - KNEE_Y) / sole_height)
	var right := Vector2(CELL.x, 0.0)
	var points := PackedVector2Array([top, top + right, bottom + right, bottom])
	var tex_size := sprite.get_size()
	var uv_top := (source.position + Vector2(0.0, KNEE_Y)) / tex_size
	var uv_bottom := (source.position + Vector2(0.0, CELL.y)) / tex_size
	var uv_right := right / tex_size
	canvas.draw_polygon(points, PackedColorArray([ink]),
		PackedVector2Array([uv_top, uv_top + uv_right, uv_bottom + uv_right, uv_bottom]), sprite)

static func frame_region(frame: int) -> Rect2:
	var cell := Vector2(frame % 4, floori(frame / 4.0))
	return Rect2(cell * CELL, CELL)

static func draw_weapon(canvas: CanvasItem, form: String, frame: int, metal: Color) -> void:
	var hand := Vector2(GRIPS[frame]) - PIVOT
	var axis := Vector2.from_angle(ANGLES[frame])
	var normal := axis.orthogonal()
	var wood := Color("#664b3b")
	match form:
		"bow":
			var upper := hand + Vector2(2.0, -16.0)
			var lower := hand + Vector2(1.0, 16.0)
			var draw_back := 11.0 if frame == 4 else 1.0
			canvas.draw_polyline(PackedVector2Array([upper, hand + Vector2(7.0, 0.0), lower]), metal, 2.0)
			canvas.draw_polyline(PackedVector2Array([upper, hand - Vector2(draw_back, 0.0), lower]), Color("#c9bfa2"), 1.0)
		"staff", "hammer":
			canvas.draw_line(hand - axis * 16.0, hand + axis * 23.0, wood, 3.0)
			if form == "hammer":
				canvas.draw_line(hand + axis * 21.0 - normal * 8.0, hand + axis * 21.0 + normal * 8.0, metal, 7.0)
			else:
				canvas.draw_circle(hand + axis * 23.0, 3.8, metal)
		"dual_blades":
			canvas.draw_line(hand - normal * 7.0, hand + axis * 17.0 - normal * 7.0, metal.darkened(0.30), 2.0)
			_draw_blade(canvas, hand, axis, normal, 21.0, metal)
		_:
			_draw_blade(canvas, hand, axis, normal, 27.0, metal)

static func _draw_blade(canvas: CanvasItem, grip: Vector2, axis: Vector2, normal: Vector2,
		length: float, metal: Color) -> void:
	canvas.draw_line(grip - axis * 5.0, grip + axis * 5.0, Color("#574139"), 3.0)
	canvas.draw_line(grip + axis * 4.0 - normal * 3.0, grip + axis * 4.0 + normal * 3.0, Color("#a08361"), 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([grip + axis * 5.0 - normal, grip + axis * length,
		grip + axis * (length - 4.0) + normal * 2.0, grip + axis * 5.0 + normal * 2.0]), metal)
