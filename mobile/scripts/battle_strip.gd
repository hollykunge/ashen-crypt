extends Control

# 连战顶栏，不写字：日、暮、月三个记号就是三波，和战场的天色同一套（白天、黄昏、入夜）。
# 走过的记号实心发暗，眼下这一波亮着，还没到的只描边；跑图时一颗光点沿着连线走向下一个记号。
# 记号下面一排小点是这一波还剩几只精怪，层主那波换成一条血。单场冲层只有一个月。

const GOLD := Color("#e0b76c")
const BRIGHT := Color("#f1dfb4")
const FAINT := Color("#c7bc9f")
const BLOOD := Color("#b8321f")
const SPACING := 40.0
const MARK := 9.0

var waves := 3
var current := 0
var single := false
var advancing := false
var foes := 0
var foes_total := 0
# 层主剩余血量占比；小于 0 表示这一波没有层主。
var boss_name := ""
var boss_ratio := -1.0
# 层主正在蓄力（地上有红圈）时，血条描一圈闪烁的红边。
var warning := false
var _time := 0.0
# 与装备条共用薄边云纹幕框。
const PLAQUE = preload("res://art/ui-icons/plaque.png")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(178.0, 26.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time = fposmod(_time + delta, 60.0)
	queue_redraw()

func _draw() -> void:
	if boss_ratio >= 0.0:
		var wide := get_viewport_rect().size.aspect() > 1.17
		draw_set_transform(Vector2(0, -57 if wide else 0))
		draw_texture_rect(PLAQUE, Rect2(12, -4, size.x - 24, 27), false)
		draw_string(get_theme_default_font(), Vector2(19, 14), boss_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 38, 15, BRIGHT)
		var width := get_viewport_rect().size.x * (0.48 if wide else 0.76)
		var bar := Rect2((size.x - width) * 0.5, 23.0, width, 6.0)
		draw_texture_rect(PLAQUE, bar.grow_individual(13, 3, 13, 3), false)
		draw_rect(bar.grow(1.0), GOLD)
		draw_rect(bar, Color("#39251e"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(boss_ratio, 0.0, 1.0), bar.size.y)), BLOOD)
		if warning:
			draw_rect(bar.grow(2.5), Color(BLOOD, 0.45 + 0.45 * sin(_time * 14.0)), false, 1.5)
		return
	var count := 1 if single else waves
	var row := 8.0
	var start := size.x * 0.5 - (count - 1) * SPACING * 0.5
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
		var center := Vector2(start + SPACING * i, row)
		var ink := GOLD if i == current else Color(FAINT, 0.62)
		draw_circle(center, 3.5, ink, i <= current, -1.0 if i <= current else 1.0, true)
	var below := 21.0
	for i in range(foes_total):
		var dot := Vector2(size.x * 0.5 + (i - (foes_total - 1) * 0.5) * 9.0, below)
		if i < foes:
			draw_circle(dot, 3.0, BLOOD, true, -1.0, true)
		else:
			draw_arc(dot, 2.6, 0.0, TAU, 12, Color(FAINT, 0.35), 1.0, true)
