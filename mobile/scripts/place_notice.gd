extends ColorRect

# 进层前的那一屏：这是什么地方、正在死多少人、仙界派你来做什么。
# 叙事口径见 docs/story.md §1.1 与 §3.1 —— 灾情客观陈述，不评判；敕令从不提灾。

signal accept_requested
signal aid_requested
signal refuse_requested

const Gear = preload("res://scripts/gear.gd")
const EquipmentSlot = preload("res://scripts/equipment_slot.gd")

@onready var center: CenterContainer = $Center

func configure(ui) -> void:
	color = Color(ui.NIGHT, 0.55)
	$Center/Panel.add_theme_stylebox_override("panel", ui.paper_box(1.0, 14))
	ui.heading_plate(%Title)
	%Title.add_theme_color_override("font_color", ui.INK)
	%Layer.add_theme_color_override("font_color", ui.GOLD)
	%Sight.add_theme_color_override("font_color", ui.INK)
	%Edict.add_theme_color_override("font_color", ui.GOLD)
	%Rules.add_theme_color_override("font_color", ui.MUTED)
	%Cost.add_theme_color_override("font_color", EquipmentSlot.BAD)
	ui._restyle(%Accept, true)
	ui._restyle(%Aid, false)
	ui._restyle(%Refuse, false)
	%Accept.pressed.connect(accept_requested.emit)
	%Aid.pressed.connect(aid_requested.emit)
	%Refuse.pressed.connect(refuse_requested.emit)
	center.resized.connect(_fit_dialog)
	_fit_dialog()

func _fit_dialog() -> void:
	# 和渡劫告示同一套换算：按短边放大，横屏上字和按钮才读得清。
	var short_edge := minf(center.size.x, center.size.y)
	var design_width := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	center.pivot_offset = center.size * 0.5
	center.scale = Vector2.ONE * maxf(1.0, short_edge / design_width)

func present(profile: Gear) -> void:
	var place := profile.place()
	var toll := int(place.get("toll", 0))
	if profile.harder_edict():
		# 抗过敕的，下一道改派更重者。
		toll = roundi(toll * 1.5)
	%Title.text = String(place.name)
	%Layer.text = "第 %d 层 · %s" % [profile.layer(), place.region]
	%Sight.text = String(place.sight)
	if toll > 0:
		%Sight.text += "\n待救者约 %d 口。" % toll
	%Edict.text = "敕：%s" % place.edict

	var names := PackedStringArray()
	for key in profile.unlocked_rules():
		names.append(String(Gear.Realm.RULES[key].name))
	%Rules.visible = names.size() > 0
	%Rules.text = "在身的规矩：" + "、".join(names) if %Rules.visible else ""

	var can_aid: bool = not String(place.get("aid", "")).is_empty()
	var aid_breaks: bool = can_aid and profile.rule_unlocked("no_aid")
	var refuse_breaks: bool = profile.rule_unlocked("no_refuse")
	%Aid.visible = can_aid
	%Aid.text = "驻留 · %s" % place.aid if can_aid else "驻留行善"
	# 抗敕要到炼神才做得到 —— 在那之前你连说不的身份都没有。
	%Refuse.visible = refuse_breaks

	var warnings := PackedStringArray()
	if aid_breaks:
		warnings.append("驻留行善违「不得以仙法济凡人」：境界 −1（炉温掉一档）")
	if refuse_breaks:
		warnings.append("抗敕违「不得抗敕」：下一道敕令改派更重者")
	%Cost.visible = warnings.size() > 0
	%Cost.text = "\n".join(warnings)

	show()
	%Accept.grab_focus()
