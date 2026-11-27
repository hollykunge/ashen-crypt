extends Control

signal start_requested
var ui
var ledge := TextureRect.new()
var hero := TextureRect.new()
var title: Label
var enter: Button
var hint: Label

func build(main) -> void:
	ui = main
	ledge.texture = preload("res://art/piying/stage/title-ledge.png")
	ledge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ledge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ledge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ledge)
	hero.texture = preload("res://art/piying/v4/title-hero.png")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero)
	title = ui._label("吾行", 96, Color("#ffdc92"))
	title.add_theme_font_override("font", preload("res://art/fonts/title.ttf"))
	var foil := ShaderMaterial.new()
	foil.shader = preload("res://art/piying/v4/title-foil.gdshader")
	title.material = foil
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	enter = ui._button("进入游戏", false, 40)
	enter.add_theme_font_override("font", ui.HEADING_FONT)
	enter.pressed.connect(func() -> void: start_requested.emit())
	add_child(enter)
	hint = ui._label("", 11, ui.INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var settings: Button = ui._sound_button()
	add_child(settings)
	settings.set_anchors_preset(PRESET_TOP_RIGHT)
	settings.offset_left = -50
	settings.offset_right = -6
	settings.offset_top = 4
	settings.offset_bottom = 48
	resized.connect(_layout)

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var wide := size.x > size.y
	var portrait_y := lerpf(0.25, 0.19, smoothstep(0.46, 0.75, size.aspect()))
	var center := Vector2(size.x * (0.32 if wide else 0.48), size.y * (0.43 if wide else portrait_y))
	var pixels := clampi(roundi(minf(size.x, size.y) * 0.28), 68, 138)
	title.add_theme_font_size_override("font_size", pixels)
	title.size = title.get_combined_minimum_size()
	title.position = (center - title.size * 0.5).round()
	var y := center.y + pixels * 0.62
	for cell in [enter, hint]:
		cell.size = Vector2(202, cell.get_combined_minimum_size().y)
		cell.position = Vector2(center.x - cell.size.x * 0.5, y).round()
		y += cell.size.y + 5

	var top := size.y * 0.12 if wide else maxf(y + 4, size.y * 0.43)
	var left := size.x * (0.55 if wide else 0.30)
	hero.position = Vector2(left, top).round()
	hero.size = Vector2(size.x - left, maxf(1, size.y * 0.93 - top)).round()

	var native := hero.texture.get_size()
	var art := native * minf(hero.size.x / native.x, hero.size.y / native.y)
	var foot := hero.position + (hero.size + Vector2(0, art.y)) * 0.5
	var width := size.x * (0.60 if wide else 0.94)
	ledge.size = (ledge.texture.get_size() * (width / ledge.texture.get_width())).round()
	ledge.position = (foot - ledge.size * Vector2(0.55, 0.52)).round()

func refresh(count: int) -> void:
	hint.text = "本机命籍 · %d 位角色" % count if count else ""
	_layout()
