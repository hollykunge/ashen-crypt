extends VBoxContainer

# 开机第一屏：题名、一句引子、「进入游戏」。存档都在本机，不要账号。

signal start_requested

var ui
var hint: Label

func build(main) -> void:
	ui = main
	add_theme_constant_override("separation", 0)
	var corner: HBoxContainer = ui._hbox(0)
	corner.alignment = BoxContainer.ALIGNMENT_END
	add_child(corner)
	corner.add_child(ui._sound_button())

	var upper := Control.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.size_flags_stretch_ratio = 0.8
	add_child(upper)

	var seal: Label = ui._label("昆仑山门 · 成仙之路", 15, ui.GOLD)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.add_theme_constant_override("outline_size", 5)
	seal.add_theme_color_override("font_outline_color", Color(ui.NIGHT, 0.9))
	add_child(seal)
	var title: Label = ui._label("余烬地牢", 58, Color("#f2d9a6"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(ui.NIGHT, 0.9))
	add_child(title)
	var line: Label = ui._label("见人间疾苦而求仙，成了仙才知苦从何来。", 14, ui.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_constant_override("outline_size", 5)
	line.add_theme_color_override("font_outline_color", Color(ui.NIGHT, 0.85))
	add_child(line)

	var lower := Control.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lower)

	var enter: Button = ui._button("进入游戏", true, 58)
	enter.add_theme_font_override("font", ui.HEADING_FONT)
	enter.add_theme_font_size_override("font_size", 24)
	enter.custom_minimum_size.x = 240.0
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter.pressed.connect(func() -> void: start_requested.emit())
	add_child(enter)
	add_child(ui._space(14))
	hint = ui._label("", 12, ui.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	add_child(ui._space(18))

func refresh(count: int) -> void:
	hint.text = "存档保存在本机 · 已有 %d 位角色" % count if count > 0 else "存档保存在本机 · 尚未立下命籍"
