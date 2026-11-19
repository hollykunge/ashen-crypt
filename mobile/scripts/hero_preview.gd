extends Control

const Roster = preload("res://scripts/roster.gd")
var hero := 0
var confirming := false
var gesture := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func select_hero(id: int, changed: bool) -> void:
	hero = id
	gesture = 0.0 if changed else 1.0
	confirming = false
	queue_redraw()

func confirm() -> void:
	confirming = true
	gesture = 0.0

func _process(delta: float) -> void:
	if is_visible_in_tree() and gesture < 1.0:
		gesture = minf(1.0, gesture + delta / Roster.CONFIRM_TIME)
		queue_redraw()

func _draw() -> void:
	var side := minf(size.x - 10.0, size.y - 12.0)
	var rect := Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)
	draw_rect(rect.grow(5), Color("#243c32"))
	draw_rect(rect.grow(5), Color("#c4a575"), false, 1.0)
	draw_texture_rect(Roster.PORTRAITS[hero], rect, false, Color(1, 1, 1, 0.75 + 0.25 * gesture))
	var band := Rect2(rect.position.x, rect.end.y - 40, side, 40)
	draw_rect(band, Color("#152c25df"))
	draw_line(band.position, band.position + Vector2(side, 0), Color("#bf9e65"))
	draw_string(get_theme_default_font(), band.position + Vector2(0, 28), Roster.NAMES[hero], HORIZONTAL_ALIGNMENT_CENTER, side, 23, Color("#f8e8c7"))
