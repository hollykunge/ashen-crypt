extends Control

const Roster = preload("res://scripts/roster.gd")
const TINTS := [Color("#f7b477"), Color("#9ee8c9"), Color("#c5b6ff")]
const SIGNATURES := [
	[0, 2, 2, 2, 2, 2, 2, 0],
	[0, 3, 2, 2, 2, 2, 2, 0],
	[0, 2, 2, 2, 2, 2, 1, 0],
	[0, 2, 3, 3, 4, 4, 2, 0],
	[0, 0, 2, 2, 2, 2, 2, 0],
	[0, 3, 2, 2, 2, 2, 2, 0]
]

var hero := 0
var artwork: Texture2D = Roster.STAGES[0]
var idle_time := 0.0
var gesture_time := -1.0
var confirming := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func select_hero(id: int, gesture: bool, weapon: String = "") -> void:
	hero = id
	artwork = Roster.stage_art(hero, weapon)
	idle_time = 0.0
	gesture_time = 0.0 if gesture else -1.0
	confirming = false
	queue_redraw()

func confirm() -> void:
	gesture_time = 0.0
	confirming = true

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	idle_time = fposmod(idle_time + delta, 128.0)
	if gesture_time >= 0.0:
		gesture_time += delta
		if gesture_time >= Roster.CONFIRM_TIME and not confirming:
			gesture_time = -1.0
	queue_redraw()

func _draw() -> void:
	var zoom := minf(size.x / 106.0, size.y / 108.0)
	var foot := Vector2(size.x * 0.5 + zoom * 3.0, size.y - zoom * 7.0).round()
	var tint: Color = TINTS[hero >> 1]
	var phase := clampf(gesture_time / Roster.CONFIRM_TIME, 0.0, 1.0)
	var glow := sin(phase * PI)
	draw_set_transform(foot, 0.0, Vector2(2.5, 0.43))
	draw_circle(Vector2.ZERO, 15.0 * zoom, Color(0.03, 0.018, 0.015, 0.75))
	draw_arc(Vector2.ZERO, (14.0 + glow * 4.0) * zoom, 0, TAU, 48, Color(tint, 0.30 + glow * 0.36), 1.1, true)
	var breath := sin(idle_time * TAU / Roster.IDLE_TIME[hero] - PI / 2.0)
	var pose := 1 if breath > 0.1 else 0
	var lean := breath * 0.013
	if gesture_time >= 0.0:
		pose = SIGNATURES[hero][mini(7, floori(phase * 8.0))]
		lean = sin(phase * TAU) * 0.045
	var draw_scale := zoom * lerpf(1.0, 0.90, glow)
	draw_set_transform(foot, lean, Vector2.ONE * draw_scale)
	draw_texture_rect_region(artwork, Rect2(-Roster.FEET, Roster.CELL), Roster.stage_region(pose), Color(1.14, 1.14, 1.14))
	draw_set_transform(Vector2.ZERO)
	for i in range(14):
		var drift := fposmod(idle_time * (0.18 + (i % 4) * 0.032) + i * 0.377, 1.0)
		var x := sin(i * 2.93 + drift * 1.95) * (25.0 + drift * 24.0) * zoom
		var point := (foot + Vector2(x, -drift * (55.0 + 24.0 * glow) * zoom)).round()
		var alpha := sin(PI * drift) * (0.28 + 0.62 * glow)
		draw_rect(Rect2(point, Vector2.ONE * (2 if i % 3 == 0 else 1)), Color(tint, alpha))
