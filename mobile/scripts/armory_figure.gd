extends Control

# 行装页正中的人物：正面全身像，从头顶到靴底一整个人，不用横版战斗贴图，也不裁成半身。
# 原画（art/side/source/fullbody）按人物设定的四面图里的正面那一个出的，透明底；
# 这里按格子的高宽等比放进去，脚踩在格子底边，左右居中。
# 底色按日干五行微微偏色，和立命籍那张像一致。

const Roster = preload("res://scripts/roster.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const FULL_BODY := [preload("res://art/side/fullbody-male.webp"), preload("res://art/side/fullbody-female.webp")]
# 头顶和脚下各留这么一点空（占格子高度的比例）。
const MARGIN := 0.03

var figure: Texture2D
var tint := Color.WHITE

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func display(_config: Dictionary, person: Dictionary, _form: String) -> void:
	figure = FULL_BODY[int(person.get("gender") == "female")]
	var stem: String = person.get("day_stem", "")
	if not stem.is_empty():
		tint = Roster.ELEMENT_TINTS[WuXing.stem_element(stem)].lerp(Color.WHITE, 0.8)
	queue_redraw()

func _draw() -> void:
	if figure == null or size.x < 1 or size.y < 1:
		return
	var art := figure.get_size()
	var room := Vector2(size.x, size.y * (1.0 - MARGIN * 2.0))
	var factor := minf(room.x / art.x, room.y / art.y)
	var shown := art * factor
	var at := Vector2((size.x - shown.x) * 0.5, size.y * (1.0 - MARGIN) - shown.y)
	draw_texture_rect(figure, Rect2(at, shown), false, tint)
