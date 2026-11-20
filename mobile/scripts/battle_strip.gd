extends Control

# 连战顶栏，不写字：日、暮、月三个记号就是三波，和战场的天色同一套（白天、黄昏、入夜）。
# 走过的记号实心发暗，眼下这一波亮着，还没到的只描边；跑图时一颗光点沿着连线走向下一个记号。
# 记号下面一排小点是这一波还剩几只精怪，层主那波换成一条血。单场冲层只有一个月。

const GOLD := Color("#c4a582")
const BRIGHT := Color("#f2d9a6")
const FAINT := Color("#c0b7ad")
const BLOOD := Color("#d8705c")
const SPACING := 40.0
const MARK := 9.0

var waves := 3
var current := 0
var single := false
var advancing := false
var foes := 0
var foes_total := 0
# 层主剩余血量占比；小于 0 表示这一波没有层主。
var boss_ratio := -1.0
# 层主正在蓄力（地上有红圈）时，血条描一圈闪烁的红边。
var warning := false
var _time := 0.0
var _plate := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150.0, 54.0)
	_plate.bg_color = Color("#151315b0")
	_plate.set_corner_radius_all(14)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time = fposmod(_time + delta, 60.0)
	queue_redraw()

func _draw() -> void:
	var count := 1 if single else waves
	var width := maxf(SPACING * (count - 1) + 34.0, 122.0 if boss_ratio >= 0.0 else foes_total * 9.0 + 26.0)
	draw_style_box(_plate, Rect2(Vector2.ZERO, Vector2(width, size.y)))
	var row := 19.0
	var start := 17.0
	for i in range(count - 1):
		var a := Vector2(start + SPACING * i + MARK + 3.0, row)
		var b := Vector2(start + SPACING * (i + 1) - MARK - 3.0, row)
		draw_line(a, b, Color(FAINT, 0.45 if i >= current else 0.75), 1.2, true)
		if advancing and i == current:
			var t := fposmod(_time * 0.9, 1.0)
			var point := a.lerp(b, t)
			draw_circle(point, 4.5, Color(BRIGHT, 0.25), true, -1.0, true)
			draw_circle(point, 2.2, BRIGHT, true, -1.0, true)
	for i in range(count):
		var phase := 1.0 if single else float(i) / maxf(count - 1, 1)
		var center := Vector2(start + SPACING * i, row)
		var state := 0 if (i < current and not single) else (1 if i == current or single else 2)
		if state == 1 and not advancing:
			var breathe := 0.5 + 0.5 * sin(_time * 2.4)
			draw_circle(center, MARK + 5.0 + breathe, Color(BRIGHT, 0.10 + 0.06 * breathe), true, -1.0, true)
		var ink := BRIGHT if state == 1 else (Color(GOLD, 0.62) if state == 0 else Color(FAINT, 0.55))
		_draw_sky(center, phase, ink, state != 2)
	var below := 41.0
	if boss_ratio >= 0.0:
		var bar := Rect2(start - 5.0, below - 3.0, 104.0, 6.0)
		draw_rect(bar.grow(1.0), Color("#241b1b"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(boss_ratio, 0.0, 1.0), bar.size.y)), BLOOD)
		if warning:
			draw_rect(bar.grow(2.5), Color(BLOOD, 0.45 + 0.45 * sin(_time * 14.0)), false, 1.5)
		return
	for i in range(foes_total):
		var dot := Vector2(start - 4.0 + i * 9.0, below)
		if i < foes:
			draw_circle(dot, 3.0, BLOOD, true, -1.0, true)
		else:
			draw_arc(dot, 2.6, 0.0, TAU, 12, Color(FAINT, 0.35), 1.0, true)

# 0 是日，0.5 是落到地平线上的暮日，1 是月。filled 为 false 时只描边。
func _draw_sky(center: Vector2, phase: float, ink: Color, filled: bool) -> void:
	if phase < 0.25:
		_disc(center, MARK * 0.55, ink, filled)
		for k in range(8):
			var direction := Vector2.from_angle(k * TAU / 8.0)
			draw_line(center + direction * MARK * 0.8, center + direction * MARK * 1.12, ink, 1.4, true)
	elif phase < 0.75:
		var horizon := center.y + 3.0
		var points := PackedVector2Array()
		for k in range(13):
			points.append(Vector2(center.x, horizon) + Vector2.from_angle(PI + PI * k / 12.0) * MARK * 0.72)
		if filled:
			draw_colored_polygon(points, ink)
		else:
			draw_polyline(points, ink, 1.3, true)
		draw_line(Vector2(center.x - MARK * 1.15, horizon), Vector2(center.x + MARK * 1.15, horizon), ink, 1.3, true)
		for k in range(3):
			var direction := Vector2.from_angle(PI * (1.25 + 0.25 * k))
			draw_line(Vector2(center.x, horizon) + direction * MARK * 0.95, Vector2(center.x, horizon) + direction * MARK * 1.25, ink, 1.3, true)
	else:
		# 月牙：外圆的左半边加上内圆的左半边，围出一弯。
		var crescent := PackedVector2Array()
		for k in range(17):
			crescent.append(center + Vector2.from_angle(PI * 0.5 + PI * k / 16.0) * MARK * 0.85)
		var inner := center + Vector2(MARK * 0.42, -MARK * 0.12)
		for k in range(17):
			var angle := PI * 1.5 - PI * k / 16.0
			crescent.append(inner + Vector2.from_angle(angle) * MARK * 0.72)
		if filled:
			draw_colored_polygon(crescent, ink)
		else:
			crescent.append(crescent[0])
			draw_polyline(crescent, ink, 1.3, true)

func _disc(center: Vector2, radius: float, ink: Color, filled: bool) -> void:
	if filled:
		draw_circle(center, radius, ink, true, -1.0, true)
	else:
		draw_arc(center, radius, 0.0, TAU, 24, ink, 1.3, true)
