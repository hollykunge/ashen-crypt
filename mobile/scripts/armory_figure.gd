extends Control

# 行装页正中的人物：用正面半身像，不用横版战斗贴图。
# 像按高度铺满，头顶对齐上沿，左右多出来的裁掉；两侧和底边用 portrait_light 的柔边淡出。
# 底色按日干五行微微偏色，和立命籍那张像一致。

const SideArt = preload("res://scripts/side_art.gd")
const Roster = preload("res://scripts/roster.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const PORTRAIT_LIGHT = preload("res://scripts/portrait_light.gdshader")
# 半身像的脸在原画上大约这个横向位置，窄框裁两侧时以它为中心。
const FACE_X := 0.53

var portrait: Texture2D
var tint := Color.WHITE

func _init() -> void:
	var light := ShaderMaterial.new()
	light.shader = PORTRAIT_LIGHT
	light.set_shader_parameter("soften_edges", true)
	light.set_shader_parameter("fade_bottom", 0.22)
	material = light
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func display(_config: Dictionary, person: Dictionary, _form: String) -> void:
	var female: bool = person.get("gender") == "female"
	portrait = SideArt.PORTRAITS[int(female)]
	var stem: String = person.get("day_stem", "")
	if not stem.is_empty():
		tint = Roster.ELEMENT_TINTS[WuXing.stem_element(stem)].lerp(Color.WHITE, 0.67)
	queue_redraw()

func _draw() -> void:
	if portrait == null or size.x < 1 or size.y < 1:
		return
	var art := portrait.get_size()
	var factor := maxf(size.x / art.x, size.y / art.y)
	var shown := size / factor
	var left := clampf(art.x * FACE_X - shown.x * 0.5, 0.0, art.x - shown.x)
	draw_texture_rect_region(portrait, Rect2(Vector2.ZERO, size), Rect2(Vector2(left, 0.0), shown), tint)
