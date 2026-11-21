extends Control

# 行装页正中的人物：正面全身像，从头顶到靴底一整个人，不用横版战斗贴图，也不裁成半身。
# 原画（art/side/source/fullbody）按人物设定的四面图里的正面那一个出的，透明底；
# 这里按格子的高宽等比放进去，脚踩在格子底边，左右居中。
# 身上的衣袍、镶边、绑腕、靴子和符牌按穿着的装备由 dye.gdshader 现染，用色与战斗里一致（WornSprites.dyes）；
# 在背包里点开一件还没穿的装备时，人物先换上它给你看（试穿），角上标一个「试穿」。
# 底色按日干五行微微偏色，和立命籍那张像一致。

const Roster = preload("res://scripts/roster.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const Appearance = preload("res://scripts/appearance.gd")
const WornSprites = preload("res://scripts/worn_sprites.gd")
const DYE = preload("res://scripts/dye.gdshader")
const FULL_BODY := [preload("res://art/side/fullbody-male.webp"), preload("res://art/side/fullbody-female.webp")]
# 头顶和脚下各留这么一点空（占格子高度的比例）。
const MARGIN := 0.03
# 男女身高比：女角色比男角色矮一些，脚仍踩在同一条线上。
const HEIGHT := [1.0, 0.9]

var figure: Texture2D
var stature := 1.0
var tint := Color.WHITE
var sex := -1
var trying_label: Label

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var paint := ShaderMaterial.new()
	paint.shader = DYE
	material = paint
	# 字另放一个节点：染色着色器只管人物，不能拿图层去取样字形贴图。
	trying_label = Label.new()
	trying_label.text = "试穿"
	trying_label.position = Vector2(4, 0)
	trying_label.add_theme_font_size_override("font_size", 13)
	trying_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.66, 0.85))
	trying_label.visible = false
	add_child(trying_label)

# config 是 Gear.loadout() 的结果；试穿时传换上那件之后的 loadout，preview 为真。
func display(config: Dictionary, person: Dictionary, form: String, preview := false) -> void:
	var female := int(person.get("gender") == "female")
	if female != sex:
		sex = female
		figure = FULL_BODY[sex]
		for layer in WornSprites.LAYERS:
			material.set_shader_parameter(layer + "_layer",
				load("res://art/side/dye/fullbody-%s-%s.png" % ["female" if sex else "male", layer]))
	var colors := WornSprites.dyes(Appearance.build(config.get("entries", {}), config.get("patterns", {}), form))
	for layer in WornSprites.LAYERS:
		material.set_shader_parameter(layer + "_dye", colors.get(layer, Color.TRANSPARENT))
	stature = HEIGHT[sex]
	trying_label.visible = preview
	var stem: String = person.get("day_stem", "")
	if not stem.is_empty():
		tint = Roster.ELEMENT_TINTS[WuXing.stem_element(stem)].lerp(Color.WHITE, 0.8)
	queue_redraw()

func _draw() -> void:
	if figure == null or size.x < 1 or size.y < 1:
		return
	var art := figure.get_size()
	var room := Vector2(size.x, size.y * (1.0 - MARGIN * 2.0) * stature)
	var factor := minf(room.x / art.x, room.y / art.y)
	var shown := art * factor
	var at := Vector2((size.x - shown.x) * 0.5, size.y * (1.0 - MARGIN) - shown.y)
	draw_texture_rect(figure, Rect2(at, shown), false, tint)
