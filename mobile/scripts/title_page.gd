extends Control

signal start_requested
var ui
var title: Label
var enter: Button
var preview: Button
var hint: Label

func build(main) -> void:
	ui = main
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
	preview = ui._button("试演 · 动作与换装", false, 30)
	preview.add_theme_font_size_override("font_size", 13)
	preview.visible = OS.is_debug_build()
	preview.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ink_preview.tscn"))
	add_child(preview)
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
	var wide := size.x > size.y
	var center := Vector2(size.x * (0.32 if wide else 0.48), size.y * (0.43 if wide else 0.28))
	var pixels := clampi(roundi(minf(size.x, size.y) * 0.28), 68, 138)
	title.add_theme_font_size_override("font_size", pixels)
	title.size = title.get_combined_minimum_size()
	title.position = center - title.size * 0.5
	var y := center.y + pixels * 0.62
	for cell in [enter, preview, hint]:
		cell.size = Vector2(202 if cell != preview else 164, cell.get_combined_minimum_size().y)
		cell.position = Vector2(center.x - cell.size.x * 0.5, y)
		y += cell.size.y + 5

func refresh(count: int) -> void:
	hint.text = "本机命籍 · %d 位角色" % count if count else ""
	_layout()
