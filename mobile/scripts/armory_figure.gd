extends Control

const Roster = preload("res://scripts/roster.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const Appearance = preload("res://scripts/appearance.gd")
const CutoutHero = preload("res://scripts/cutout_hero.gd")
const MARGIN := 0.03

var actor := CutoutHero.new()
var stature := 1.0
var tint := Color.WHITE
var trying_label: Label


func _init() -> void:
	add_child(actor)
	trying_label = Label.new()
	trying_label.text = "试穿"
	trying_label.position = Vector2(4, 0)
	trying_label.add_theme_font_size_override("font_size", 13)
	trying_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.66, 0.85))
	trying_label.visible = false
	add_child(trying_label)


func display(config: Dictionary, person: Dictionary, form: String, preview := false) -> void:
	actor.dress(Appearance.build(config.get("entries", {}), config.get("patterns", {}), form, person.get("gender", "")))
	actor.present_outfit()
	stature = 1.0
	# 皮影女将竖端的月牙长刀比头高，人缩一点，刀头不顶出格子
	if actor.puppet.who == "nvjiang":
		stature = 0.84
	trying_label.visible = preview
	var stem: String = person.get("day_stem", "")
	tint = Color.WHITE if stem.is_empty() else Roster.ELEMENT_TINTS[WuXing.stem_element(stem)].lerp(Color.WHITE, 0.8)
	queue_redraw()


func _draw() -> void:
	if actor.puppet == null or size.x < 1 or size.y < 1:
		return
	var height := minf(size.x * 2.0, size.y * 0.89 * stature)
	var feet_x := size.x * 0.45
	var feet_y := size.y * 0.90
	if actor.puppet.who == "piying":
		# 备战架势的刀伸向右上方，按人和刀的合计宽度取景。
		height = minf(height, size.x * 1.10)
		feet_x = size.x * 0.30
		feet_y = size.y * 0.90
	actor.fit(height / CutoutHero.SPRITE_HEIGHT, get_viewport().get_final_transform().get_scale().x)
	actor.draw(self, Vector2(feet_x, feet_y), 1.0, tint)
