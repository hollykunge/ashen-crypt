extends Control

const BUS_NAMES := ["Master", "Music", "SFX"]
var ui
var tab := 0
var outer: VBoxContainer
var columns: BoxContainer
var categories: BoxContainer
var content: VBoxContainer
var buttons: Array[Button] = []
var backdrop: TextureRect
var thumb: ImageTexture

func _ready() -> void:
	thumb = ImageTexture.create_from_image(preload("res://art/piying/v4/knob.png").get_image())
	thumb.set_size_override(Vector2i(22, 22))
	mouse_filter = MOUSE_FILTER_STOP
	backdrop = ui._image(preload("res://art/piying/v4/river.webp"))
	add_child(backdrop)
	ui._fill(backdrop)
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	outer = ui._vbox(10)
	add_child(outer)
	var heading: Label = ui._label("设 置", 26, ui.INK)
	heading.custom_minimum_size = Vector2(185, 40)
	heading.size_flags_horizontal = SIZE_SHRINK_CENTER
	ui.heading_plate(heading)
	outer.add_child(heading)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	var frame: ArtPlate = ui.paper_box(0.96, 16)
	frame.texture = preload("res://art/piying/v4/settings-panel.png")
	frame.corner_limit = 28
	panel.add_theme_stylebox_override("panel", frame)
	outer.add_child(panel)
	var stack: VBoxContainer = ui._vbox(10)
	panel.add_child(stack)
	columns = BoxContainer.new()
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	stack.add_child(columns)
	categories = BoxContainer.new()
	categories.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(categories)
	for name_text in ["声音", "画面", "操作"]:
		var button: Button = ui._button(name_text, false, 40)
		button.custom_minimum_size.x = 90
		button.pressed.connect(show_tab.bind(buttons.size()))
		categories.add_child(button)
		buttons.append(button)
	content = ui._vbox(12)
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(content)
	var footer: HBoxContainer = ui._hbox(10)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(footer)
	for caption in ["恢复默认", "返回"]:
		var button: Button = ui._button(caption, false, 40)
		button.custom_minimum_size.x = 108
		footer.add_child(button)
		button.pressed.connect(_reset if caption == "恢复默认" else ui._close_settings)
	resized.connect(_layout)
	_layout()
	show_tab(0)

func _layout() -> void:
	var wide := size.x > size.y
	var usable: Rect2 = ui.safe_content_rect()
	var room := Vector2(usable.size.x * (0.76 if wide else 0.94), usable.size.y * (0.83 if wide else 0.60))
	room.x = maxf(room.x, minf(usable.size.x, outer.get_combined_minimum_size().x))
	outer.position = usable.position + (usable.size - room) * 0.5
	outer.size = room
	for b in buttons:
		b.custom_minimum_size.x = minf(140, room.x * 0.23) if wide else 88
	columns.vertical = not wide
	categories.vertical = wide
	backdrop.texture = preload("res://art/piying/v4/river.webp") if wide else preload("res://art/piying/stage/river-portrait.webp")

func show_tab(index: int) -> void:
	tab = index
	for i in buttons.size():
		ui._restyle(buttons[i], i == tab)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if tab == 0:
		for i in BUS_NAMES.size():
			var row: HBoxContainer = ui._hbox(8)
			content.add_child(row)
			var label: Label = ui._label(["主音量", "音乐", "音效"][i], 16, ui.INK)
			label.custom_minimum_size.x = 54
			row.add_child(label)
			var slider := HSlider.new()
			slider.accessibility_name = label.text
			slider.custom_minimum_size.y = 38
			slider.size_flags_horizontal = SIZE_EXPAND_FILL
			slider.max_value = 1
			slider.step = 0.01
			var bus: String = BUS_NAMES[i]
			slider.value = ui.preferences.get_value("audio", bus, 0.0 if bus == "SFX" else 1.0)
			for style in ["slider", "grabber_area", "grabber_area_highlight"]:
				var rail: StyleBoxFlat = ui._box(Color("#30201a") if style == "slider" else Color("#f4ae42"), ui.GOLD, 1, 3)
				rail.set_corner_radius_all(4)
				slider.add_theme_stylebox_override(style, rail)
			for icon in ["grabber", "grabber_highlight"]:
				slider.add_theme_icon_override(icon, thumb)
			slider.value_changed.connect(_volume.bind(bus))
			row.add_theme_constant_override("separation", 0)
			row.add_child(_terminal(preload("res://art/piying/v4/rail-left.png")))
			row.add_child(slider)
			row.add_child(_terminal(preload("res://art/piying/v4/rail-right.png")))
	else:
		content.add_child(ui._label("战斗倍速" if tab == 1 else "操控方式", 18, ui.GOLD))
		var options := ["一倍", "二倍", "三倍"] if tab == 1 else ["手动", "辅助", "全自动"]
		var row := HFlowContainer.new()
		content.add_child(row)
		for i in options.size():
			var chosen: bool = i == (ui.battle_speed - 1 if tab == 1 else int(ui.control_mode))
			var choice: Button = ui._button(options[i], chosen, 42)
			choice.custom_minimum_size.x = 72
			row.add_child(choice)
			choice.pressed.connect(_choose.bind(i))

func _volume(amount: float, bus: String) -> void:
	ui.sounds.set_volume(bus, amount)
	ui.save_preference("audio", bus, amount)
	if bus == "SFX":
		ui.sounds.play(&"pickup")

func _choose(i: int) -> void:
	if tab == 1:
		ui.battle_speed = i + 1
		ui.save_preference("battle", "speed", i + 1)
	else:
		ui.control_mode = i
		ui.save_preference("battle", "mode", i)
	ui._update_control_labels()
	show_tab(tab)

func _reset() -> void:
	for bus in BUS_NAMES:
		ui.save_preference("audio", bus, 0.0 if bus == "SFX" else 1.0)
	ui.save_preference("battle", "speed", 1)
	ui.save_preference("battle", "mode", 1)
	ui._load_preferences()
	ui._update_control_labels()
	show_tab(tab)

func _terminal(texture: Texture2D) -> TextureRect:
	var ornament: TextureRect = ui._image(texture)
	ornament.custom_minimum_size = Vector2(16, 16)
	ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return ornament
