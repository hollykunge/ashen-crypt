extends Control

# 浮动摇杆。
#
# 原来手操只有「前进 / 后退」两个按钮，纵向走位只能靠键盘，手机上根本躲不开层主的红圈。
# 这里按手游的常规做法：在画面左下的走位区里按下就地生出摇杆，松手即收，不占固定版面。

const RADIUS := 48.0
const KNOB := 17.0
const DEADZONE := 8.0

var pointer := -2
var origin := Vector2.ZERO
var aim := Vector2.ZERO
var zone := Rect2()
var fade := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	var target := 1.0 if active() else 0.0
	if absf(fade - target) < 0.01:
		return
	fade = move_toward(fade, target, delta * 6.0)
	queue_redraw()

func active() -> bool:
	return pointer != -2

# 走位区：左侧大半幅、HUD 以下、技能坞以上。点在这儿才生摇杆。
func set_zone(area: Rect2) -> void:
	zone = area

func accepts(at: Vector2) -> bool:
	return zone.has_point(at)

func begin(index: int, at: Vector2) -> void:
	pointer = index
	origin = at
	aim = at
	queue_redraw()

func drag(index: int, at: Vector2) -> void:
	if index != pointer:
		return
	aim = at
	# 推到边缘之外时把基座跟着拖，手指不会跑出摇杆范围。
	var reach: Vector2 = aim - origin
	if reach.length() > RADIUS:
		origin = aim - reach.normalized() * RADIUS
	queue_redraw()

func release(index: int) -> bool:
	if index != pointer:
		return false
	pointer = -2
	queue_redraw()
	return true

func clear() -> void:
	pointer = -2
	queue_redraw()

func value() -> Vector2:
	if not active():
		return Vector2.ZERO
	var reach: Vector2 = aim - origin
	if reach.length() <= DEADZONE:
		return Vector2.ZERO
	return (reach / RADIUS).limit_length(1.0)

func _draw() -> void:
	if fade <= 0.01 and not active():
		return
	var alpha := maxf(fade, 1.0 if active() else 0.0)
	var knob := origin + value() * RADIUS
	draw_circle(origin, RADIUS, Color(0.06, 0.09, 0.08, 0.17 * alpha), true, -1.0, true)
	draw_arc(origin, RADIUS, 0.0, TAU, 40, Color(0.80, 0.69, 0.47, 0.38 * alpha), 1.3, true)
	draw_arc(origin, RADIUS * 0.34, 0.0, TAU, 24, Color(0.80, 0.69, 0.47, 0.22 * alpha), 1.0, true)
	for i in range(4):
		var tick := Vector2.from_angle(i * TAU / 4.0)
		draw_line(origin + tick * (RADIUS - 9.0), origin + tick * (RADIUS - 3.0),
			Color(0.80, 0.69, 0.47, 0.35 * alpha), 1.0, true)
	draw_circle(knob, KNOB, Color(0.14, 0.21, 0.18, 0.62 * alpha), true, -1.0, true)
	draw_circle(knob, KNOB, Color(0.91, 0.83, 0.65, 0.75 * alpha), false, 1.5, true)
	draw_circle(knob, KNOB * 0.32, Color(0.95, 0.88, 0.72, 0.55 * alpha), true, -1.0, true)
