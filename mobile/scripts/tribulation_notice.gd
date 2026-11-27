extends ColorRect

signal prepare_requested
signal challenge_requested
signal stay_requested

const Gear = preload("res://scripts/gear.gd")
const EquipmentSlot = preload("res://scripts/equipment_slot.gd")

@onready var table: GridContainer = %Comparison
@onready var center: CenterContainer = $Center

func configure(ui) -> void:
	color = Color(ui.NIGHT, 0.55)
	$Center/Panel.add_theme_stylebox_override("panel", ui.paper_box(1.0, 14))
	ui.heading_plate(%Title)
	%Layer.add_theme_color_override("font_color", ui.GOLD)
	%Description.add_theme_color_override("font_color", ui.INK)
	%Empty.add_theme_color_override("font_color", ui.MUTED)
	ui._restyle(%Prepare, false)
	ui._restyle(%Begin, true)
	ui._restyle(%Stay, false)
	%Prepare.pressed.connect(prepare_requested.emit)
	%Begin.pressed.connect(challenge_requested.emit)
	%Stay.pressed.connect(stay_requested.emit)
	center.resized.connect(_fit_dialog)
	_fit_dialog()

func _fit_dialog() -> void:
	# 主视口按竖屏拉伸。按短边换算，让横屏上的字和按钮保持可读大小。
	var short_edge := minf(center.size.x, center.size.y)
	var design_width := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	center.pivot_offset = center.size * 0.5
	center.scale = Vector2.ONE * maxf(1.0, short_edge / design_width)

func present(profile: Gear, tribulation: String) -> void:
	var element := Gear.WuXing.stem_element(tribulation)
	var counter := String(Gear.WuXing.KE.find_key(element))
	var fortune := Gear.WuXing.jingyu(counter, element)
	var tint: Color = Gear.MATERIAL_COLORS[element]
	%Title.text = "%s劫当前" % Gear.WuXing.ELEMENT_NAMES[element]
	%Title.add_theme_color_override("font_color", tint)
	%Layer.text = "第 %d 层 · %s" % [profile.layer(), profile.realm().name]
	%Description.text = "入劫后%s当令，%s行落%s位。" % [Gear.ling_caption(tribulation),
		Gear.WuXing.ELEMENT_NAMES[counter], Gear.WuXing.JINGYU_NAMES[fortune]]

	for cell in table.get_children():
		cell.free()
	var current: Dictionary = profile.loadout().entries
	var projected: Dictionary = profile.loadout({}, true, tribulation).entries
	table.visible = not current.is_empty()
	%Empty.visible = current.is_empty()
	if table.visible:
		_add_cell("境遇倍率", EquipmentSlot.INK)
		_add_cell("本层 · %s" % Gear.ling_caption(profile.ling()), EquipmentSlot.INK)
		_add_cell("渡劫 · %s" % Gear.ling_caption(tribulation), tint)
		for i in range(Gear.SLOTS.size()):
			var slot: String = Gear.SLOTS[i]
			if not current.has(slot):
				continue
			var before: Dictionary = current[slot]
			var after: Dictionary = projected[slot]
			var main := Gear.Loadout.dominant(after.wuxing)
			var ink := EquipmentSlot.INK
			if not is_equal_approx(before.q, after.q):
				ink = EquipmentSlot.GOOD if after.q > before.q else EquipmentSlot.BAD
			_add_cell("%s · %s" % [Gear.SLOT_NAMES[i], Gear.WuXing.ELEMENT_NAMES.get(main, "—")], EquipmentSlot.INK)
			_add_cell("%s  %.2f" % [before.jingyu.get(main, "—"), before.q], EquipmentSlot.INK)
			_add_cell("%s  %.2f" % [after.jingyu.get(main, "—"), after.q], ink)
	show()
	%Begin.grab_focus()

func _add_cell(caption: String, ink: Color) -> void:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = caption
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ink)
	table.add_child(label)
