extends RefCounted

const STREET = preload("res://art/side/shrine-courtyard.webp")
const SNOW_PASS = preload("res://art/side/kunlun-snow-pass.webp")
const PORTRAITS := [preload("res://art/side/portrait-male.webp"), preload("res://art/side/portrait-female.webp")]
const SPRITES := [preload("res://art/side/frames-male.png"), preload("res://art/side/frames-female.png")]
const CELL := Vector2(96, 96)
const PIVOT := Vector2(47, 89)
const FLOOR := 0.76
const SNOW_FLOOR := 0.79
# 每一个人物像素占背景高度的比例，按山门石阶和雪道前景标定。
# 使用原画比例，导入时降低纹理分辨率也会保持同样的人物大小。
const STREET_ACTOR_SCALE := 1.64 / 887.0
const SNOW_ACTOR_SCALE := 1.52 / 887.0
const KNEE_Y := 70.0
# 支撑脚从前脚跟滚到后脚尖。坐标在各自的 96 像素分格内。
const SOLES := [
	{1: Vector2(65, 88), 11: Vector2(54, 89), 2: Vector2(34, 88)},
	{1: Vector2(62, 88), 11: Vector2(53, 89), 2: Vector2(33, 88)},
]
const FRAMES := {&"ready": 0, &"guard": 3, &"windup": 4, &"strike": 5, &"follow": 6,
	&"recover": 7, &"dodge": 8, &"hurt": 9, &"cast": 10}

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
