extends Control

# 挂机时左上角那只袋子，替掉原来那张写满字的信息卡。
# 袋口是本层掉的材料（图标外圈是当令五行的颜色），旁边是这种材料的库存；捡到一份袋子跳一下。
# 底下一条细血条是挂机时的生命。行善换来的蒙荫在身时，右边多一顶小伞盖。
# 读屏和长按提示用 accessibility_name / tooltip_text 讲全话。

const ForgeArt = preload("res://scripts/forge_art.gd")
const INK := Color("#eee5d6")
const PLATE := Color("#151315b8")
const LIFE := Color("#8cb286")
const SHADE := Color("#a9cb93")
const ICON := 34.0

var drop: Dictionary = {}
var stock := 0
var health := 1.0
var relief := false
var _bump := 0.0
var _plate := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(124.0, 54.0)
	_plate.bg_color = PLATE
	_plate.set_corner_radius_all(14)

func show_state(next_material: Dictionary, next_stock: int, current: int, total: int, shaded: bool) -> void:
	drop = next_material
	stock = next_stock
	health = clampf(float(current) / maxf(total, 1), 0.0, 1.0)
	relief = shaded
	var name: String = drop.get("name", "")
	tooltip_text = "本层材料 %s · 库存 %d · 生命 %d/%d%s" % [name, stock, current, total, " · 蒙荫（死位按囚位）" if relief else ""]
	accessibility_name = tooltip_text
	queue_redraw()

func bump() -> void:
	_bump = 1.0

func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 3.2)
		queue_redraw()

func _draw() -> void:
	draw_style_box(_plate, Rect2(Vector2.ZERO, size))
	if drop.is_empty():
		return
	var tint: Color = drop.tint
	var lift := sin(_bump * PI) * 4.0
	var center := Vector2(10.0 + ICON * 0.5, 6.0 + ICON * 0.5 - lift)
	var swell := 1.0 + sin(_bump * PI) * 0.12
	draw_circle(center, ICON * 0.5 * swell + 1.5, Color(tint, 0.20 + 0.35 * _bump), true, -1.0, true)
	draw_arc(center, ICON * 0.5 * swell + 1.5, 0.0, TAU, 32, Color(tint, 0.85), 1.6, true)
	var side := ICON * 0.84 * swell
	draw_texture_rect_region(ForgeArt.ATLAS, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side),
		ForgeArt.region(int(drop.icon)))
	var font := get_theme_default_font()
	var digits := str(stock)
	var baseline := Vector2(10.0 + ICON + 8.0, 6.0 + ICON * 0.5 + 7.0)
	draw_string_outline(font, baseline, digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 4, Color("#151315"))
	draw_string(font, baseline, digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK.lerp(tint, 0.35 + 0.4 * _bump))
	if relief:
		var shade := Vector2(size.x - 16.0, 17.0)
		draw_arc(shade, 8.0, PI, TAU, 16, SHADE, 2.0, true)
		draw_line(shade, shade + Vector2(0.0, 11.0), SHADE, 1.6, true)
		draw_arc(shade + Vector2(-2.5, 11.0), 2.5, 0.0, PI, 8, SHADE, 1.6, true)
	var bar := Rect2(10.0, size.y - 8.0, size.x - 20.0, 3.0)
	draw_rect(bar, Color("#2a2622"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * health, bar.size.y)), LIFE)
