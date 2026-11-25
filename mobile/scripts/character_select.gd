extends VBoxContainer

# 列仙图录：三个角色位。有人的格子能「入山」或删掉，空格子「立下命籍」去创角。

signal play_requested(slot: int)
signal create_requested(slot: int)
signal back_requested

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const SideArt = preload("res://scripts/side_art.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")

var ui
var save_base := Gear.SAVE_PATH
var list: VBoxContainer
var notice: Label
# 删人要按两下：第一下把按钮换成「确认删除」，再按才删。
var armed_delete := -1

func build(main) -> void:
	ui = main
	add_theme_constant_override("separation", 10)
	var row: HBoxContainer = ui._hbox(6)
	add_child(row)
	var back: Button = ui._button("返回", false, 39)
	back.add_theme_font_size_override("font_size", 13)
	back.custom_minimum_size.x = 64.0
	back.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back)
	var stack: VBoxContainer = ui._vbox(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	stack.add_child(ui._label("选择角色 · 最多 %d 位" % Gear.MAX_CHARACTERS, 12, ui.GOLD))
	var nameplate: Label = ui._label("列仙图录", 34, ui.INK)
	nameplate.add_theme_constant_override("outline_size", 6)
	nameplate.add_theme_color_override("font_outline_color", ui.NIGHT)
	stack.add_child(nameplate)
	row.add_child(ui._sound_button())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	list = ui._vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	notice = ui._label("", 12, Color("#a13f32"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.hide()
	add_child(notice)

func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for slot in range(Gear.MAX_CHARACTERS):
		var profile = Gear.peek(slot, save_base)
		if profile.has_character():
			_person_card(slot, profile)
		elif profile.storage_error.is_empty():
			_empty_card(slot)
		else:
			_broken_card(slot, profile.storage_error)

func count() -> int:
	var total := 0
	for slot in range(Gear.MAX_CHARACTERS):
		if Gear.peek(slot, save_base).has_character():
			total += 1
	return total

func show_error(text: String) -> void:
	notice.text = text
	notice.visible = not text.is_empty()

func _frame() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui._box(Color(ui.NIGHT, 0.94), ui.BORDER, 1, 10))
	panel.custom_minimum_size.y = 128.0
	list.add_child(panel)
	var row: HBoxContainer = ui._hbox(12)
	panel.add_child(row)
	return row

func _person_card(slot: int, profile) -> void:
	var row := _frame()
	var person: Dictionary = profile.character()
	var female: bool = person.get("gender") == "female"
	var stem := String(person.get("day_stem", "geng"))
	var element := WuXing.stem_element(stem)
	var face: TextureRect = ui._image(SideArt.portrait(person.get("gender", "")))
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.custom_minimum_size = Vector2(80, 106)
	face.modulate = Roster.ELEMENT_TINTS[element].lerp(Color.WHITE, 0.67)
	row.add_child(face)

	var facts: VBoxContainer = ui._vbox(2)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(facts)
	facts.add_child(ui._label(profile.display_name(), 22, ui.INK))
	facts.add_child(_line("%s · %s · %s" % ["女" if female else "男", Gear.fate_caption(stem),
		String(profile.origin().get("name", ""))], ui.GOLD))
	facts.add_child(_line("%s · 第 %d 层 · %s" % [profile.realm().name, profile.layer(),
		String(profile.place().get("name", ""))], ui.MUTED))
	var seen: float = profile.last_seen()
	facts.add_child(_line("灵砂 %d%s" % [profile.silver(), " · " + _ago(seen) if seen > 0.0 else ""], ui.MUTED))

	var actions: VBoxContainer = ui._vbox(6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(actions)
	var play: Button = ui._button("入山", true, 46)
	play.custom_minimum_size.x = 76.0
	play.add_theme_font_size_override("font_size", 17)
	play.pressed.connect(_play.bind(slot))
	actions.add_child(play)
	actions.add_child(_delete_button(slot))

func _empty_card(slot: int) -> void:
	var row := _frame()
	var facts: VBoxContainer = ui._vbox(3)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(facts)
	facts.add_child(ui._label("空位 · 第 %d 格" % (slot + 1), 18, ui.MUTED))
	facts.add_child(_line("选性别、日干、月令、时辰与出身，立下一位新角色。", ui.MUTED))
	var create: Button = ui._button("创建角色", false, 46)
	create.custom_minimum_size.x = 96.0
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(_create.bind(slot))
	row.add_child(create)

func _broken_card(slot: int, error: String) -> void:
	var row := _frame()
	var facts: VBoxContainer = ui._vbox(3)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(facts)
	facts.add_child(ui._label("第 %d 格 · %s" % [slot + 1, error], 18, Color("#a13f32")))
	facts.add_child(_line("这份存档读不出来。删掉之后这一格可以重新创角。", ui.MUTED))
	var actions: VBoxContainer = ui._vbox(6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(actions)
	actions.add_child(_delete_button(slot))

func _delete_button(slot: int) -> Button:
	var armed := armed_delete == slot
	var remove: Button = ui._button("确认删除" if armed else "删除", false, 36)
	remove.add_theme_font_size_override("font_size", 13)
	remove.custom_minimum_size.x = 76.0
	if armed:
		remove.add_theme_color_override("font_color", Color("#a13f32"))
	remove.pressed.connect(_delete.bind(slot))
	return remove

func _line(text: String, color: Color) -> Label:
	var label: Label = ui._label(text, 13, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _play(slot: int) -> void:
	armed_delete = -1
	play_requested.emit(slot)

func _create(slot: int) -> void:
	armed_delete = -1
	create_requested.emit(slot)

func _delete(slot: int) -> void:
	if armed_delete != slot:
		armed_delete = slot
		show_error("再按一次「确认删除」：角色、装备和材料都会删掉，不能恢复。")
		refresh()
		return
	armed_delete = -1
	if Gear.delete_slot(slot, save_base):
		show_error("")
	else:
		show_error("删除失败，请稍后再试")
	refresh()

static func _ago(seen: float) -> String:
	var gap := maxf(0.0, Time.get_unix_time_from_system() - seen)
	if gap < 60.0:
		return "刚刚在线"
	if gap < 3600.0:
		return "%d 分钟前" % floori(gap / 60.0)
	if gap < 86400.0:
		return "%d 小时前" % floori(gap / 3600.0)
	return "%d 天前" % floori(gap / 86400.0)
