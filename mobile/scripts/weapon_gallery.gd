extends Control

const Art = preload("res://scripts/forge_art.gd")
const SCENE = preload("res://art/piying/v4/banners.webp")
const IDS := ["sword", "jian", "spear", "bow"]
var forge
var selected: String
var heading: Label
var cards: Array[Button] = []
var footer: HBoxContainer

func _ready() -> void:
	var ui = forge.ui
	selected = forge.draft.weapon_form
	mouse_filter = MOUSE_FILTER_STOP
	var back: Button = ui._icon_button(&"back", "返回锻造", false, Vector2(44, 44))
	ui.portrait_back(back, str(forge.profile.character().get("gender", "")))
	back.pressed.connect(_finish.bind(false))
	add_child(back)
	back.position = Vector2(8, 5)
	var settings: Button = ui._sound_button()
	add_child(settings)
	settings.set_anchors_preset(PRESET_TOP_RIGHT)
	settings.offset_left = -50
	settings.offset_right = -6
	settings.offset_top = 4
	settings.offset_bottom = 48
	heading = ui._label("兵 器", 26, ui.INK)
	ui.heading_plate(heading)
	add_child(heading)
	for id in IDS:
		var card := Button.new()
		card.flat = true
		for style in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		card.accessibility_name = "枪" if id == "spear" else forge.Rules.NAME_PARTS.weapons[id]
		card.pressed.connect(_select.bind(id))
		cards.append(card)
		add_child(card)
		var label: Label = ui._label(card.accessibility_name, 18, ui.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_stylebox_override("normal", ui._brush(ui.WASH))
		card.add_child(label)
		var item: TextureRect = ui._image(Art.weapon_icon(id))
		item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(item)
	footer = ui._hbox(10)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(footer)
	for caption in ["返回", "选用"]:
		var b: Button = ui._button(caption, caption == "选用", 38)
		b.custom_minimum_size.x = 94
		b.pressed.connect(_finish.bind(caption == "选用"))
		footer.add_child(b)
	resized.connect(_layout)
	_layout()

func _select(id: String) -> void:
	selected = id
	queue_redraw()

func _finish(apply: bool) -> void:
	if apply:
		forge.draft.weapon_form = selected
		forge._changed()
	forge.ui.weapon_gallery = null
	forge.ui._fit_forge()
	queue_free()

func _layout() -> void:
	var wide := size.x > size.y
	heading.size = Vector2(180, 36)
	heading.position = Vector2((size.x - heading.size.x) / 2, size.y * 0.008)
	for i in cards.size():
		var card := cards[i]
		if wide:
			card.position = size * Vector2(0.143 + 0.187 * i, 0.236)
			card.size = size * Vector2(0.158, 0.54)
		else:
			card.position = size * Vector2(0.17 + 0.403 * (i % 2), 0.167 + 0.355 * floori(i / 2.0))
			card.size = size * Vector2(0.26, 0.255)
		var label: Label = card.get_child(0)
		label.size = Vector2(minf(card.size.x, 110), 30)
		label.position = Vector2((card.size.x - label.size.x) * 0.5, 0)
		var item: TextureRect = card.get_child(1)
		item.position = Vector2(4, 42)
		item.size = card.size - Vector2(8, 52)
		item.pivot_offset = item.size * 0.5
		item.rotation = -0.55
		item.scale = Vector2.ONE * 1.13
	footer.alignment = BoxContainer.ALIGNMENT_END if wide else BoxContainer.ALIGNMENT_CENTER
	footer.size = Vector2(size.x - (16 if wide else 0), 40)
	footer.position = Vector2(0, size.y - 49)
	queue_redraw()

func _draw() -> void:
	if size.x > size.y:
		draw_texture_rect(SCENE, Rect2(Vector2.ZERO, size), false)
	else:
		draw_texture_rect(preload("res://art/piying/v4/banners-tall.webp"), Rect2(Vector2.ZERO, size), false)
	if cards.size() == 4:
		var c := cards[IDS.find(selected)]
		var frame := Rect2(c.position, c.size)
		var left := frame.position.x
		var right := frame.end.x
		var top := frame.position.y
		var bottom := frame.end.y
		var hem := Vector2(frame.get_center().x, bottom + frame.size.y * 0.09)
		var outline := PackedVector2Array([frame.position, Vector2(right, top), frame.end, hem, Vector2(left, bottom), frame.position])
		draw_colored_polygon(outline, Color(1, 0.65, 0.12, 0.12))
		for width in [7.0, 4.0, 1.4]:
			draw_polyline(outline, Color(1, 0.72, 0.20, 0.98 / width), width, true)
